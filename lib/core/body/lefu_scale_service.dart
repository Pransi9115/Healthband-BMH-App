// ─────────────────────────────────────────────────────────
//  LEFU / FITDAYS FFB0 SCALE BRIDGE
//
//  Replaces the Qingniu (QnScaleService) implementation, which could
//  never have worked. The FG2001B-A is not a Yolanda/Qingniu device.
//  The evidence, in order of weight:
//
//    1. It advertises service FFB0. Qingniu scales do not, and their
//       SDK only ever reports Yolanda's own hardware — everything
//       else is discarded silently, with no error. That is exactly
//       the "scanning, nothing found" screen we were stuck on.
//    2. Its manufacturer data begins with the MAC in reverse byte
//       order (3A 1F 46 19 FB 50 → 50:FB:19:46:1F:3A). That is why
//       the Fitdays app can display a MAC address on iOS at all,
//       where CoreBluetooth otherwise hides it.
//    3. Fitdays is published by Guangdong Icomon, not Yolanda.
//
//  So: no appId, no .qn configuration file, no native plugin, no
//  Xcode target surgery. This runs entirely on flutter_blue_plus,
//  which was already a dependency.
//
//  ── PROTOCOL ──
//  Fixed 8-byte frames:   AC 02 | D0 D1 D2 D3 | STATUS | CKSUM
//                         CKSUM = (D0+D1+D2+D3+STATUS) & 0xFF
//  Handshake is written to FFB1; weight streams back on FFB2 (some
//  firmware revisions use FFB3), big-endian tenths of a kilogram.
//  Every constant below was checksum-verified before being written.
//
//  ── WHAT IS MEASURED, AND WHAT IS NOT ──
//  Weight is measured. Everything else on this screen is ESTIMATED
//  from weight, height, age and sex using published equations —
//  Deurenberg for fat, Mifflin-St Jeor for BMR — because the
//  vendor's bioimpedance frame has not been decoded by anyone
//  outside Lefu, and the vendor's own numbers are suspect anyway
//  (their sample report claims 7.3% body fat for a 39 year old
//  woman, which is below the level required to live).
//
//  This distinction must reach the user. [BodyComposition.source]
//  carries it; the UI should show it.
//
//  Unrecognised frames are kept in [unknownFrames] rather than
//  dropped, because that log is the raw material for decoding
//  impedance later. Watch it with bare feet versus socks: a frame
//  that differs between the two is the impedance frame.
// ─────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'body_composition.dart';
import 'body_composition_service.dart';

/// A scale seen during a scan. [mac] is the platform identifier —
/// a MAC on Android, a CoreBluetooth UUID on iOS — matching what
/// BleService reports, so the two can be compared.
class ScaleDevice {
  final BluetoothDevice device;
  final String mac;
  final String name;
  final int rssi;
  final String modelId;

  const ScaleDevice({
    required this.device,
    required this.mac,
    required this.name,
    this.rssi = 0,
    this.modelId = '',
  });
}

enum ScaleState {
  idle, scanning, connecting, connected, measuring, done, error,
}

/// A frame we could not interpret, kept with a timestamp so it can be
/// lined up against what the scale's own display showed at that moment.
class UnknownFrame {
  final DateTime at;
  final String hex;
  final String source;
  const UnknownFrame(this.at, this.hex, this.source);

  @override
  String toString() => '${at.toIso8601String()} [$source] $hex';
}

class LefuScaleService extends ChangeNotifier {
  LefuScaleService._();
  static final LefuScaleService instance = LefuScaleService._();

  // ── PROTOCOL ────────────────────────────────────────────
  static const int _magic0 = 0xAC;
  static const int _magic1 = 0x02;

  static const int _statusUnstable = 0xCE; // still settling
  static const int _statusStable = 0xCA;   // locked reading

  /// Written to FFB1 without response, in order, once FFB2 notify is
  /// live. 0x1FA5 is a fixed config value the scale echoes back.
  static final List<Uint8List> _handshake = [
    Uint8List.fromList([0xAC, 0x02, 0xFA, 0x01, 0x00, 0x00, 0xCC, 0xC7]),
    Uint8List.fromList([0xAC, 0x02, 0xFB, 0x02, 0x1F, 0xA5, 0xCC, 0x8D]),
    Uint8List.fromList([0xAC, 0x02, 0xFD, 0xE2, 0x01, 0x01, 0xCC, 0xAD]),
    Uint8List.fromList([0xAC, 0x02, 0xFC, 0x01, 0x00, 0x00, 0xCC, 0xC9]),
  ];

  /// Poll/keepalive. The vendor app repeats this all session; the
  /// scale sleeps quickly without it.
  static final Uint8List _poll =
      Uint8List.fromList([0xAC, 0x02, 0xFE, 0x06, 0x00, 0x00, 0xCC, 0xD0]);

  // ── STATE ───────────────────────────────────────────────
  ScaleState _state = ScaleState.idle;
  final List<ScaleDevice> _found = [];
  final List<UnknownFrame> _unknown = [];
  double _liveWeight = 0;
  BodyComposition? _last;
  String? _error;
  bool _ready = false;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  final List<StreamSubscription> _notifySubs = [];
  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  Timer? _pollTimer;

  ScaleState get state => _state;
  List<ScaleDevice> get found => List.unmodifiable(_found);
  List<UnknownFrame> get unknownFrames => List.unmodifiable(_unknown);
  double get liveWeight => _liveWeight;
  BodyComposition? get last => _last;
  String? get error => _error;
  bool get isReady => _ready;

  /// There is no SDK that can be absent, so the scale path is always
  /// available. Kept so the pairing screens need no changes.
  bool get isAvailable => true;

  /// Nothing to initialise. Present for API compatibility with the
  /// screens that used to drive the Qingniu SDK.
  Future<void> init() async {
    _ready = true;
    notifyListeners();
  }

  // ── SCAN ────────────────────────────────────────────────
  //
  // Matched on the FFB0 service rather than the device name. The name
  // is editable in Fitdays — ours currently reads MY_SCALE, and the
  // same hardware also ships branded SWAN — so a name match would be
  // fragile. FFB0 is in the firmware.
  Future<void> startScan() async {
    if (!_ready) await init();
    _found.clear();
    _error = null;
    _state = ScaleState.scanning;
    notifyListeners();

    try {
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        _fail('Bluetooth is off. Please turn it on.');
        return;
      }

      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        var added = false;
        for (final r in results) {
          if (!_looksLikeScale(r)) continue;
          final id = r.device.remoteId.str;
          if (_found.any((d) => d.mac == id)) continue;

          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : (r.advertisementData.advName.isNotEmpty
                  ? r.advertisementData.advName
                  : 'Scale');

          _found.add(ScaleDevice(
            device: r.device, mac: id, name: name, rssi: r.rssi));
          added = true;
        }
        if (added) notifyListeners();
      });

      // No withServices filter: some Lefu firmware omits FFB0 from the
      // advertisement and only exposes it after connecting, so we
      // filter ourselves and accept the manufacturer signature too.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 20),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      _fail('Scan failed: $e');
    }
  }

  bool _looksLikeScale(ScanResult r) {
    for (final u in r.advertisementData.serviceUuids) {
      if (u.toString().toLowerCase().contains('ffb0')) return true;
    }
    // Company id 0x02AC on the documented variant; ours advertises
    // 0x28AC. Same protocol family, so both are accepted.
    for (final id in r.advertisementData.manufacturerData.keys) {
      if (id == 0x02AC || id == 0x28AC) return true;
    }
    return false;
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {/* already stopped */}
    await _scanSub?.cancel();
    _scanSub = null;
    if (_state == ScaleState.scanning) {
      _state = ScaleState.idle;
      notifyListeners();
    }
  }

  // ── CONNECT ─────────────────────────────────────────────
  Future<void> connect(String mac) async {
    ScaleDevice? target;
    for (final d in _found) {
      if (d.mac == mac) { target = d; break; }
    }
    if (target == null) {
      _fail('That scale is no longer in range. Scan again.');
      return;
    }

    await stopScan();
    _state = ScaleState.connecting;
    _error = null;
    notifyListeners();

    try {
      _device = target.device;

      await _connSub?.cancel();
      _connSub = target.device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _pollTimer?.cancel();
          if (_state != ScaleState.done) {
            _state = ScaleState.idle;
            notifyListeners();
          }
        }
      });

      await target.device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      final services = await target.device.discoverServices();
      BluetoothCharacteristic? ffb1;
      final notifyChars = <BluetoothCharacteristic>[];

      for (final svc in services) {
        if (!svc.serviceUuid.toString().toLowerCase().contains('ffb0')) {
          continue;
        }
        for (final c in svc.characteristics) {
          if (c.uuid.toString().toLowerCase().contains('ffb1')) ffb1 = c;
          // FFB2 on one firmware revision, FFB3 on another. Subscribe
          // to whatever notifies rather than guessing which shipped.
          if (c.properties.notify || c.properties.indicate) {
            notifyChars.add(c);
          }
        }
      }

      if (ffb1 == null || notifyChars.isEmpty) {
        _fail('This scale does not expose the expected FFB0 '
              'characteristics.');
        return;
      }
      _writeChar = ffb1;

      // Notifications first — the scale discards a handshake that
      // arrives before the subscription is live.
      for (final c in notifyChars) {
        await c.setNotifyValue(true);
        final label = c.uuid.toString().toLowerCase();
        _notifySubs.add(c.lastValueStream.listen((data) {
          if (data.isNotEmpty) _onFrame(Uint8List.fromList(data), label);
        }));
      }

      _state = ScaleState.connected;
      notifyListeners();

      for (final frame in _handshake) {
        await _write(frame);
        await Future.delayed(const Duration(milliseconds: 120));
      }

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 2), (_) => _write(_poll));
    } catch (e) {
      _fail('Connect failed: $e');
    }
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    for (final s in _notifySubs) {
      await s.cancel();
    }
    _notifySubs.clear();
    await _connSub?.cancel();
    try {
      await _device?.disconnect();
    } catch (_) {/* nothing connected */}
    _device = null;
    _writeChar = null;
    _state = ScaleState.idle;
    notifyListeners();
  }

  Future<void> _write(Uint8List data) async {
    final c = _writeChar;
    if (c == null) return;
    try {
      await c.write(data, withoutResponse: c.properties.writeWithoutResponse);
    } catch (e) {
      debugPrint('[LEFU] write failed: $e');
    }
  }

  // ── FRAMES ──────────────────────────────────────────────
  void _onFrame(Uint8List d, String source) {
    final hex = d.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    debugPrint('[LEFU] <- $source  $hex');

    if (d.length != 8 || d[0] != _magic0 || d[1] != _magic1) {
      _record(hex, source);
      return;
    }

    final status = d[6];
    if (((d[2] + d[3] + d[4] + d[5] + status) & 0xFF) != d[7]) {
      debugPrint('[LEFU] checksum mismatch, dropped');
      return;
    }

    final kg = ((d[2] << 8) | d[3]) / 10.0;

    switch (status) {
      case _statusUnstable:
        _liveWeight = kg;
        _state = ScaleState.measuring;
        notifyListeners();
        break;

      case _statusStable:
        // The scale repeats the final frame; ignore the repeats.
        if (_last != null &&
            _state == ScaleState.done &&
            (_last!.weightKg - kg).abs() < 0.05) return;
        _liveWeight = kg;
        _onMeasurement(kg);
        break;

      default:
        // Handshake acknowledgements land here — and so, in all
        // likelihood, does the impedance frame.
        _record(hex, source);
    }
  }

  void _record(String hex, String source) {
    _unknown.add(UnknownFrame(DateTime.now(), hex, source));
    if (_unknown.length > 200) _unknown.removeAt(0);
  }

  // ── MEASUREMENT → BODY COMPOSITION ──────────────────────
  //
  // Weight is the only measured value. Everything else here is an
  // estimate from published equations, and [source] says so.
  Future<void> _onMeasurement(double weightKg) async {
    try {
      final p = await SharedPreferences.getInstance();
      final age = p.getInt('profile_age') ?? 30;
      final isFemale = (p.getString('profile_gender') ?? 'Male')
          .toLowerCase().startsWith('f');
      final heightCm = p.getDouble('profile_height') ?? 170;

      final c = _estimate(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        isFemale: isFemale,
      );

      _last = c;
      _state = ScaleState.done;
      notifyListeners();

      await p.setString('bmh_scale_name', 'BioScale');
      await BodyCompositionService.instance.ingest(c);
    } catch (e) {
      _fail('Could not record the measurement: $e');
    }
  }

  /// Deurenberg (1991) for fat, Mifflin-St Jeor for BMR, standard
  /// fat-free-mass fractions for the rest. These are population
  /// equations, not measurements of this body. They are defensible
  /// and citable, which the vendor's undocumented algorithm is not.
  BodyComposition _estimate({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool isFemale,
  }) {
    final heightM = heightCm / 100;
    final bmi = weightKg / (heightM * heightM);

    // Deurenberg: BF% = 1.20·BMI + 0.23·age − 10.8·sex − 5.4
    // (sex = 1 male, 0 female)
    var fatPct = 1.20 * bmi + 0.23 * age - (isFemale ? 0 : 10.8) - 5.4;
    // Clamped inside the survivable range so a bad profile cannot
    // produce a reading the warnings system would rightly reject.
    fatPct = fatPct.clamp(isFemale ? 12.0 : 5.0, 55.0);

    final fatKg = weightKg * fatPct / 100;
    final ffm = weightKg - fatKg;

    // Fractions of fat free mass, from body composition literature.
    final waterKg = ffm * 0.73;
    final proteinKg = ffm * 0.195;
    final boneKg = ffm * 0.058;
    final muscleKg = ffm - boneKg;
    final skeletalKg = muscleKg * 0.55;

    // Mifflin-St Jeor
    final bmr = isFemale
        ? 10 * weightKg + 6.25 * heightCm - 5 * age - 161
        : 10 * weightKg + 6.25 * heightCm - 5 * age + 5;

    return BodyComposition(
      measuredAt: DateTime.now(),
      // Read by the UI. Do not shorten this — it is the only thing
      // telling the user which numbers were measured.
      source: 'BioScale — weight measured, composition estimated',
      isFemale: isFemale,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      bodyFatKg: fatKg,
      bodyFatPct: fatPct,
      boneMineralKg: boneKg,
      proteinKg: proteinKg,
      bodyWaterKg: waterKg,
      muscleKg: muscleKg,
      skeletalMuscleKg: skeletalKg,
      // No impedance means no honest visceral estimate. Zero rather
      // than a fabricated grade.
      visceralGrade: 0,
      bmrKcal: bmr.roundToDouble(),
      subcutaneousPct: 0,
      smi: skeletalKg / (heightM * heightM),
      bodyAge: math.max(18, age).toInt(),
      whr: 0,
    );
  }

  void _fail(String msg) {
    _error = msg;
    _state = ScaleState.error;
    debugPrint('[LEFU] $msg');
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scanSub?.cancel();
    _connSub?.cancel();
    for (final s in _notifySubs) {
      s.cancel();
    }
    super.dispose();
  }
}
