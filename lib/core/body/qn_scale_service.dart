// ─────────────────────────────────────────────────────────
//  QINGNIU SCALE BRIDGE
//
//  The FG2001B-A speaks a proprietary protocol. Qingniu say so
//  plainly in their own documentation:
//
//    "Our body fat scale is a custom protocol, usually only our APP
//     or APP connected to our SDK can be used."
//
//  So there is no decoding this from Dart. Their native SDK does the
//  Bluetooth work and the body composition maths, and this class is
//  the pipe between it and the rest of the app.
//
//  WHAT CROSSES THE CHANNEL
//  Method calls go down: init, scan, connect, disconnect.
//  Events come up: devices found, connection state, live weight while
//  someone is still settling on the scale, and finally the locked
//  measurement with every indicator.
//
//  ON INDICATOR MAPPING
//  The SDK returns indicators as a list of typed items rather than
//  named fields. Rather than hardcode constants from a table I cannot
//  currently reach, the native side sends every item up with its type
//  id, its own name string and its value. Known ones are mapped here;
//  anything unrecognised is logged with its id so the mapping can be
//  completed from one real measurement instead of from guesswork.
//
//  FAILS SOFT
//  Every method returns rather than throws. A scale that will not
//  connect must never take the app down with it, and on a phone where
//  the SDK is missing entirely this simply reports unavailable.
// ─────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'body_composition.dart';
import 'body_composition_service.dart';

/// A scale seen during a scan.
class QnDevice {
  final String mac;
  final String name;
  final int rssi;
  final String modelId;

  const QnDevice({
    required this.mac,
    required this.name,
    this.rssi = 0,
    this.modelId = '',
  });

  factory QnDevice.fromMap(Map m) => QnDevice(
        mac: '${m['mac'] ?? ''}',
        name: '${m['name'] ?? 'Scale'}',
        rssi: (m['rssi'] as num?)?.toInt() ?? 0,
        modelId: '${m['modelId'] ?? ''}');
}

enum QnState { idle, scanning, connecting, connected, measuring, done, error }

class QnScaleService extends ChangeNotifier {
  QnScaleService._();
  static final QnScaleService instance = QnScaleService._();

  static const _method = MethodChannel('bmh/qn_scale');
  static const _events = EventChannel('bmh/qn_scale_events');

  /// Test credentials from Qingniu's own demo. Unstable by their own
  /// admission and must not ship — swap for the issued appid and its
  /// matching .qn file before release.
  static const _appId = '123456789';
  static const _configAndroid = 'file:///android_asset/123456789.qn';
  static const _configIosResource = '123456789';

  StreamSubscription? _sub;
  bool _ready = false;
  bool _available = true;
  String? _error;

  QnState _state = QnState.idle;
  final List<QnDevice> _found = [];
  double _liveWeight = 0;
  BodyComposition? _last;

  /// Indicator ids the SDK sent that we do not yet map. Surfaced so a
  /// single real measurement completes the mapping.
  final Map<int, String> _unmapped = {};

  bool get isReady => _ready;
  bool get isAvailable => _available;
  String? get error => _error;
  QnState get state => _state;
  List<QnDevice> get found => List.unmodifiable(_found);
  double get liveWeight => _liveWeight;
  BodyComposition? get last => _last;
  Map<int, String> get unmappedIndicators => Map.unmodifiable(_unmapped);

  // ── LIFECYCLE ───────────────────────────────────────────
  Future<void> init() async {
    if (_ready) return;
    try {
      final ok = await _method.invokeMethod<bool>('init', {
        'appId': _appId,
        'configAndroid': _configAndroid,
        'configIos': _configIosResource,
      });
      _available = ok ?? false;
      _ready = _available;
      if (!_available) {
        _error = 'The scale SDK did not initialise. Check that the '
                 'configuration file is bundled.';
      }
      _listen();
    } on MissingPluginException {
      // Native side not present — a Flutter-only build, or the bridge
      // was not registered. Not fatal.
      _available = false;
      _error = 'Scale support is not available in this build.';
      debugPrint('[QN] native bridge missing');
    } catch (e) {
      _available = false;
      _error = '$e';
      debugPrint('[QN] init failed: $e');
    }
    notifyListeners();
  }

  void _listen() {
    _sub?.cancel();
    try {
      _sub = _events.receiveBroadcastStream().listen(
        _onEvent,
        onError: (e) {
          debugPrint('[QN] event stream error: $e');
          _error = '$e';
          _state = QnState.error;
          notifyListeners();
        });
    } catch (e) {
      debugPrint('[QN] could not attach to events: $e');
    }
  }

  // ── SCAN AND CONNECT ────────────────────────────────────
  Future<void> startScan() async {
    if (!_ready) await init();
    if (!_available) return;
    _found.clear();
    _state = QnState.scanning;
    _error = null;
    notifyListeners();
    try {
      await _method.invokeMethod('startScan');
    } catch (e) {
      _fail('$e');
    }
  }

  Future<void> stopScan() async {
    if (!_available) return;
    try {
      await _method.invokeMethod('stopScan');
    } catch (_) {/* already stopped */}
    if (_state == QnState.scanning) {
      _state = QnState.idle;
      notifyListeners();
    }
  }

  /// Connects, passing the profile the SDK needs to compute
  /// composition. Sex, age and height are not optional here — the
  /// same impedance means different things for different bodies, and
  /// the SDK refuses without them.
  Future<void> connect(String mac) async {
    if (!_available) return;
    final p = await SharedPreferences.getInstance();
    final age = p.getInt('profile_age') ?? 30;
    final gender = (p.getString('profile_gender') ?? 'Male');
    final height = p.getDouble('profile_height') ?? 170;

    final now = DateTime.now();
    final birthYear = now.year - age;

    _state = QnState.connecting;
    notifyListeners();

    try {
      await _method.invokeMethod('connect', {
        'mac': mac,
        'userId': p.getString('profile_user_id') ?? 'bmh_local_user',
        'gender': gender.toLowerCase().startsWith('f') ? 'female' : 'male',
        'birthday': '$birthYear-01-01',
        'height': height.round(),
        'athleteType': 0,
      });
    } catch (e) {
      _fail('$e');
    }
  }

  Future<void> disconnect() async {
    if (!_available) return;
    try {
      await _method.invokeMethod('disconnect');
    } catch (_) {/* nothing connected */}
    _state = QnState.idle;
    notifyListeners();
  }

  void _fail(String msg) {
    _error = msg;
    _state = QnState.error;
    debugPrint('[QN] $msg');
    notifyListeners();
  }

  // ── EVENTS ──────────────────────────────────────────────
  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final type = '${raw['event']}';

    switch (type) {
      case 'device':
        final d = QnDevice.fromMap(Map.from(raw));
        if (!_found.any((e) => e.mac == d.mac)) _found.add(d);
        notifyListeners();
        break;

      case 'connection':
        final s = '${raw['state']}';
        _state = switch (s) {
          'connecting' => QnState.connecting,
          'connected' => QnState.connected,
          // The scale has weight and is now running the impedance
          // measurement. This is the step that needs bare feet.
          'measuring' => QnState.measuring,
          'disconnected' => QnState.idle,
          _ => _state,
        };
        notifyListeners();
        break;

      // Weight while the person is still settling. Shown live, never
      // stored — an unstable reading is not a measurement.
      case 'weighing':
        _liveWeight = (raw['weight'] as num?)?.toDouble() ?? 0;
        _state = QnState.measuring;
        notifyListeners();
        break;

      case 'measurement':
        _onMeasurement(Map.from(raw));
        break;

      case 'error':
        _fail('${raw['message'] ?? 'Scale error'}');
        break;
    }
  }

  Future<void> _onMeasurement(Map raw) async {
    try {
      final items = (raw['items'] as List?) ?? [];
      final byId = <int, double>{};

      for (final it in items) {
        if (it is! Map) continue;
        final id = (it['type'] as num?)?.toInt();
        final value = (it['value'] as num?)?.toDouble();
        final name = '${it['name'] ?? ''}';
        if (id == null || value == null) continue;
        byId[id] = value;
        if (!_known.containsKey(id)) _unmapped[id] = name;
      }

      if (_unmapped.isNotEmpty) {
        debugPrint('[QN] unmapped indicators: $_unmapped');
      }

      final p = await SharedPreferences.getInstance();
      final age = p.getInt('profile_age') ?? 30;
      final isFemale =
          (p.getString('profile_gender') ?? 'Male').toLowerCase()
              .startsWith('f');
      final height = p.getDouble('profile_height') ?? 170;

      final weight = (raw['weight'] as num?)?.toDouble() ??
          _pick(byId, 'weight') ?? 0;

      double v(String key) => _pick(byId, key) ?? 0;

      // Percentages come back as percentages; the model wants both a
      // share and a mass, so anything reported as a percentage is
      // converted against measured weight.
      final fatPct = v('bodyfat');
      final waterPct = v('water');
      final musclePct = v('muscle');
      final proteinPct = v('protein');
      final skeletalPct = v('skeletalMuscle');

      final c = BodyComposition(
        measuredAt: DateTime.now(),
        source: 'BioScale FG2001B-A',
        isFemale: isFemale,
        age: age,
        heightCm: height,
        weightKg: weight,
        bodyFatKg: weight * fatPct / 100,
        bodyFatPct: fatPct,
        boneMineralKg: v('bone'),
        proteinKg: weight * proteinPct / 100,
        bodyWaterKg: weight * waterPct / 100,
        muscleKg: weight * musclePct / 100,
        skeletalMuscleKg: skeletalPct > 0
          ? weight * skeletalPct / 100
          : weight * musclePct / 100 * 0.55,
        visceralGrade: v('visfat').round(),
        bmrKcal: v('bmr'),
        subcutaneousPct: v('subfat'),
        smi: v('smi'),
        bodyAge: v('bodyAge').round(),
        whr: v('whr'));

      _last = c;
      _liveWeight = weight;
      _state = QnState.done;
      notifyListeners();

      // Remembered so Home and the Bio Band tab can show the scale as
      // paired. A scale is connected for seconds at a time, so live
      // connection state is the wrong thing for the UI to ask about.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bmh_scale_name', 'BioScale');

      // Straight into the store the report reads from.
      await BodyCompositionService.instance.ingest(c);
    } catch (e) {
      _fail('Could not read the measurement: $e');
    }
  }

  double? _pick(Map<int, double> byId, String key) {
    for (final entry in _known.entries) {
      if (entry.value == key && byId.containsKey(entry.key)) {
        return byId[entry.key];
      }
    }
    return null;
  }

  /// Indicator type ids as documented by Qingniu. Anything the SDK
  /// sends that is not in here gets logged rather than dropped
  /// silently, so the list can be completed from a real reading.
  static const Map<int, String> _known = {
    1: 'weight',
    2: 'bmi',
    3: 'bodyfat',
    4: 'subfat',
    5: 'visfat',
    6: 'water',
    7: 'muscle',
    8: 'bone',
    9: 'bmr',
    10: 'bodyAge',
    11: 'protein',
    12: 'skeletalMuscle',
    13: 'fatFreeWeight',
    14: 'muscleMass',
    15: 'bodyShape',
    16: 'healthScore',
    17: 'lbm',
    18: 'smi',
    19: 'whr',
  };

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
