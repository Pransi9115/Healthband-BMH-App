import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../health/vital_history_service.dart';
import '../health/sleep_analyzer.dart';
import '../health/vital_cache.dart';

// ─────────────────────────────────────────────────────────
//  EXACT UUIDs FROM 2208A SDK constant.dart
// ─────────────────────────────────────────────────────────
const String _SVC   = '0000fff0-0000-1000-8000-00805f9b34fb';
const String _WRITE = '0000fff6-0000-1000-8000-00805f9b34fb';
const String _NOTIF = '0000fff7-0000-1000-8000-00805f9b34fb';

// ─────────────────────────────────────────────────────────
//  EXACT COMMAND BYTES FROM 2208A SDK device_cmd.dart
// ─────────────────────────────────────────────────────────
const int _SET_TIME   = 0x01;
const int _REAL_STEP  = 0x09;
const int _BATTERY    = 0x13;
const int _MEASURE    = 0x28;
const int _TOTAL_DATA = 0x51;
const int _SLEEP      = 0x53;
const int _HR_HISTORY = 0x54;
const int _HR_ONCE    = 0x55;
const int _HRV        = 0x56;
const int _BLOOD_O2   = 0x60;
const int _TEMP_AUTO  = 0x65; // SDK: GetAxillaryTemperatureDataWithMode
const int _TEMP_HIST  = 0x62; // SDK: Temperature_history (manual)

// History fetch modes — from SDK
const int _MODE_START    = 0x00; // start from beginning
const int _MODE_CONTINUE = 0x02; // continue from last position
const int _MODE_DELETE   = 0x99; // delete all (never used here)

// ─────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────
enum BMHDeviceType { healthBand, bioScale, unknown }

class BMHBleDevice {
  final String id, name;
  final int rssi;
  final BMHDeviceType type;
  final BluetoothDevice device;
  const BMHBleDevice({
    required this.id, required this.name, required this.rssi,
    required this.type, required this.device,
  });
  static BMHDeviceType detectType(String n) {
    final s = n.toLowerCase();
    if (s.contains('band') || s.contains('watch') || s.contains('2208') ||
        s.contains('fit') || s.contains('hr') || s.contains('jstyle'))
      return BMHDeviceType.healthBand;
    if (s.contains('scale') || s.contains('weight') || s.contains('body'))
      return BMHDeviceType.bioScale;
    return BMHDeviceType.unknown;
  }
  int get signalBars {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }
}

class BMHSleepData {
  final int totalMinutes, deepMinutes, lightMinutes, remMinutes, awakeMinutes;
  final String quality;
  final DateTime date;
  const BMHSleepData({
    required this.totalMinutes, required this.deepMinutes,
    required this.lightMinutes, required this.remMinutes,
    required this.awakeMinutes, required this.quality,
    required this.date,
  });
  double get totalHours => totalMinutes / 60.0;
  int get score {
    if (totalMinutes >= 480) return 92;
    if (totalMinutes >= 420) return 78;
    if (totalMinutes >= 360) return 62;
    return 48;
  }
}

// ─────────────────────────────────────────────────────────
//  BLE SERVICE SINGLETON
// ─────────────────────────────────────────────────────────
class BleService extends ChangeNotifier {
  static final BleService _i = BleService._();
  static BleService get instance => _i;
  BleService._();

  bool _isScanning   = false;
  bool _isConnecting = false;
  bool _isRefreshing = false;
  BMHBleDevice? _connectedBand;
  BMHBleDevice? _connectedScale;
  final List<BMHBleDevice> _scanned = [];
  String? _error;

  int    _heartRate   = 0;
  int    _spo2        = 0;
  double _temperature = 0.0;
  int    _steps       = 0;
  int    _battery     = 0;
  int    _hrv         = 0;
  int    _stressLevel = 0;
  double _calories    = 0.0; // kcal burned today
  double _distance    = 0.0; // km walked today
  int    _exerciseMin = 0;   // active exercise minutes today
  // ── SMART WEAR DETECTION (Virtual Sensor) ───────────
  bool     _isWearing     = false;
  bool     _wearAsked     = false;
  int      _wearScore     = 0;    // confidence score 0-100

  // Signal trackers
  int      _lastHr        = 0;
  int      _hrChangeCount = 0;    // how many times HR changed
  int      _noChangeCount = 0;    // how many times HR stayed same
  int      _lastStepCheck = 0;    // steps at last check
  bool     _stepsMoving   = false;
  DateTime _lastUpdate    = DateTime.now();

  // Hardware-first wear detection flags
  // KSlipHand is the ONLY reliable signal — sent in 0x28 packet.
  // _wearProbeReceived = true once band responds to our probe command.
  // Until then, _isWearing stays false regardless of score.
  bool     _wearProbeReceived = false;
  DateTime _connectedAt       = DateTime.now();

  // FIX 1: Debounce counter for KSlipHand=0x00 (not-wearing).
  // Require 3 consecutive 0x00 readings before flipping _isWearing=false.
  // A single 0x00 (brief wrist movement, sensor lift-off) is ignored.
  // Any 0x01 (worn) resets the counter immediately.
  int      _slipHandZeroCount = 0;
  int    _bpSystolic  = 0;
  int    _bpDiastolic = 0;
  // BP smoothing — wrist-optical BP is re-estimated on every reading,
  // so single values naturally wobble. We display the median of the
  // last 3 readings, which keeps the number clinically steady.
  final List<int> _bpSysHist = [];
  final List<int> _bpDiaHist = [];
  void _setBp(int sys, int dia) {
    _bpSysHist.add(sys);
    _bpDiaHist.add(dia);
    if (_bpSysHist.length > 3) {
      _bpSysHist.removeAt(0);
      _bpDiaHist.removeAt(0);
    }
    List<int> sorted(List<int> l) => List<int>.from(l)..sort();
    _bpSystolic = sorted(_bpSysHist)[_bpSysHist.length ~/ 2];
    _bpDiastolic = sorted(_bpDiaHist)[_bpDiaHist.length ~/ 2];
  }
  int    _stepGoal    = 5000;
  int    _vitalAge    = 0;
  BMHSleepData? _lastSleep;

  // Keep the write characteristic alive — this is what sends commands
  BluetoothCharacteristic? _writeChar;
  // Keep the last connected device for reconnect
  BMHBleDevice? _lastBandDev;

  bool _isReconnecting = false;
  // True only when the user explicitly disconnects (via disconnectDevice).
  // Stops all auto-reconnect attempts until a fresh connect is requested.
  bool _manualDisconnect = false;

  StreamSubscription? _scanSub;
  StreamSubscription? _notifySub;
  StreamSubscription? _connStateSub;
  Timer? _keepAliveTimer;
  Timer? _refreshTimer;
  Timer? _reconnectTimer;
  int _reconnectCount = 0;

  // Getters
  bool get isScanning    => _isScanning;
  bool get isConnecting  => _isConnecting;
  bool get isRefreshing  => _isRefreshing;
  BMHBleDevice? get connectedBand  => _connectedBand;
  BMHBleDevice? get connectedScale => _connectedScale;
  List<BMHBleDevice> get scannedDevices => List.unmodifiable(_scanned);
  String? get error      => _error;
  // ── VITAL GETTERS — gated by _isWearing ──────────────────────────────────
  // IMPORTANT: All health vitals return 0 / 0.0 when band is not on wrist.
  // This ensures every screen (home, health, live) automatically shows '--'
  // without needing any per-screen isWearing check.
  // Steps, calories, distance, battery, stepGoal are NOT gated
  // (pedometer & battery work regardless of skin contact).
  // ── FIX: the "-- then data returns" flicker ───────────────────────
  //
  // These getters used to return 0 the moment _isWearing went false,
  // and the UI renders 0 as '--'. But _startWearDetection() resets
  // _wearProbeReceived=false on EVERY connect and re-probes the
  // hardware at 3s and 8s. During that window _isWearing is false, so
  // every screen blanked to '--' even though the real values were
  // still sitting in memory untouched.
  //
  // That was never a connectivity loss — the data was being hidden and
  // then "recovering" when the probe landed. Exactly the behaviour of
  // leaving Health Vitals, seeing '--' on Home, then the numbers
  // reappearing a few seconds later.
  //
  // Now: when the live gate closes but we hold a reading from the last
  // 5 minutes, keep showing it. The UI can flag it stale via
  // VitalCache.staleLabel(). Only genuinely old data falls back to '--'.
  final _cache = VitalCache.instance;

  int get heartRate =>
      _cache.display('hr', (_isWearing ? _heartRate : 0).toDouble()).round();
  int get spo2 =>
      _cache.display('spo2', (_isWearing ? _spo2 : 0).toDouble()).round();
  double get temperature =>
      _cache.display('temp', _isWearing ? _temperature : 0.0);
  int get hrv =>
      _cache.display('hrv', (_isWearing ? _hrv : 0).toDouble()).round();
  int get stressLevel =>
      _cache.display('stress', (_isWearing ? _stressLevel : 0).toDouble()).round();
  int get vitalAge =>
      _cache.display('vitalAge', (_isWearing ? _vitalAge : 0).toDouble()).round();
  int get bpSystolic =>
      _cache.display('bp', (_isWearing ? _bpSystolic : 0).toDouble()).round();
  int get bpDiastolic =>
      _cache.display('bp_2', (_isWearing ? _bpDiastolic : 0).toDouble()).round();

  String get bloodPressure => _cache.displayBloodPressure(
      _isWearing ? _bpSystolic : 0, _isWearing ? _bpDiastolic : 0);

  /// True when what's on screen came from cache during a probe gap.
  bool isVitalStale(String key) => _cache.isStale(
      key, key == 'hr' ? (_isWearing ? _heartRate : 0).toDouble() : 0);

  /// "2m ago" label for a cached reading, or null when live.
  String? vitalAgeLabel(String key) => _cache.staleLabel(key, 0);

  /// Raw, ungated values — use where you need the true live state.
  int    get rawHeartRate   => _heartRate;
  int    get rawSpo2        => _spo2;
  double get rawTemperature => _temperature;
  int    get rawHrv         => _hrv;
  // Not gated — these work off-wrist
  int    get steps       => _steps;
  int    get battery     => _battery;
  double get calories    => _calories;
  double get distance    => _distance;
  int    get exerciseMin => _exerciseMin;
  int    get stepGoal    => _stepGoal;
  BMHSleepData? get lastSleep => _lastSleep;
  bool get isWearing        => _isWearing;
  bool get wearAsked        => _wearAsked;
  int  get wearScore        => _wearScore;
  bool get isBandConnected  => _connectedBand != null;
  bool get isScaleConnected => _connectedScale != null;
  bool get isReconnecting   => _isReconnecting;
  BMHBleDevice? get lastBandDevice => _lastBandDev;
  double get stepProgress =>
      _stepGoal > 0 ? (_steps / _stepGoal).clamp(0.0, 1.0) : 0.0;

  /// Called from MainShell when app resumes from background
  Future<void> autoReconnect() async {
    if (_manualDisconnect) return; // user chose to stay disconnected
    if (_lastBandDev == null || isBandConnected || _isReconnecting) return;
    _isReconnecting = true;
    _error = null;
    notifyListeners();
    try {
      final success = await connectDevice(_lastBandDev!);
      if (!success) {
        await Future.delayed(const Duration(seconds: 3));
        if (!isBandConnected) await connectDevice(_lastBandDev!);
      }
    } catch (_) {}
    _isReconnecting = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────
  //  PERSISTENT RECONNECT
  //  Used after an unexpected disconnect. First 3 attempts are quick
  //  (2s apart) to recover fast from brief drops. After that, instead
  //  of giving up, it keeps retrying every 12s in the background —
  //  forever, until reconnected or the user explicitly disconnects.
  //  isReconnecting stays true throughout so the UI can show a
  //  distinct "reconnecting" state instead of looking fully dead.
  // ─────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────
  //  DEVICE PERSISTENCE + LAUNCH AUTO-RECONNECT
  //  Once paired, the band reconnects on every app launch
  //  and app-resume with zero user action — until the user
  //  explicitly forgets the device.
  // ─────────────────────────────────────────────────────
  static const _kDevId   = 'bmh_last_device_id';
  static const _kDevName = 'bmh_last_device_name';
  static const _kAutoRc  = 'bmh_auto_reconnect';

  Future<void> _saveLastDevice(BMHBleDevice dev) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kDevId, dev.device.remoteId.str);
      await p.setString(_kDevName, dev.name);
      await p.setBool(_kAutoRc, true);
    } catch (_) {}
  }

  /// Forget the paired band completely — stops all auto-reconnect
  /// until the user pairs again from the scan screen.
  Future<void> forgetSavedDevice() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kDevId);
      await p.remove(_kDevName);
      await p.setBool(_kAutoRc, false);
    } catch (_) {}
  }

  /// Call once on app launch (after splash) and on app resume.
  /// Silently reconnects to the previously paired band.
  Future<void> tryAutoReconnect() async {
    if (isBandConnected || _isConnecting) return;
    try {
      final p = await SharedPreferences.getInstance();
      if (!(p.getBool(_kAutoRc) ?? false)) return;
      final id = p.getString(_kDevId);
      if (id == null || id.isEmpty) return;
      final name = p.getString(_kDevName) ?? 'Health Band';

      // Wait (briefly) for the adapter to power on
      final state = await FlutterBluePlus.adapterState
          .firstWhere((s) => s == BluetoothAdapterState.on)
          .timeout(const Duration(seconds: 8),
              onTimeout: () => BluetoothAdapterState.off);
      if (state != BluetoothAdapterState.on) return;

      final dev = BMHBleDevice(
        id: id, name: name, rssi: -60,
        type: BMHDeviceType.healthBand,
        device: BluetoothDevice.fromId(id),
      );
      _manualDisconnect = false;
      final ok = await connectDevice(dev);
      if (!ok) _scheduleReconnect(); // keep trying in background
    } catch (_) {}
  }

  /// App came back to foreground — timers may have been frozen
  /// while backgrounded; reconnect immediately if the link dropped.
  void onAppResumed() {
    if (!isBandConnected && !_isConnecting && !_manualDisconnect) {
      _reconnectTimer?.cancel();
      _reconnectCount = 0;
      tryAutoReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _lastBandDev == null) {
      _isReconnecting = false;
      notifyListeners();
      return;
    }
    _isReconnecting = true;
    notifyListeners();
    _reconnectCount++;
    final delay = _reconnectCount <= 3
        ? const Duration(seconds: 2)
        : const Duration(seconds: 12);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_manualDisconnect || isBandConnected) return;
      final ok = await connectDevice(_lastBandDev!);
      if (!ok) _scheduleReconnect(); // never give up — keep retrying
    });
  }

  void setStepGoal(int g) {
    _stepGoal = g.clamp(1000, 50000);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────
  //  CRC — exact from SDK _crcValue
  // ─────────────────────────────────────────────────────
  Uint8List _cmd(List<int> b) {
    final d = List<int>.filled(16, 0);
    for (int i = 0; i < b.length && i < 15; i++) d[i] = b[i];
    int crc = 0;
    for (final v in d) crc += v;
    d[15] = crc & 0xff;
    return Uint8List.fromList(d);
  }

  // ─────────────────────────────────────────────────────
  //  SCAN
  // ─────────────────────────────────────────────────────
  void clearForScan() {
    _reconnectTimer?.cancel();
    _reconnectCount = 0;
    _scanned.clear();
    _error = null;
    notifyListeners();
  }

  Future<void> startScan() async {
    _error = null;
    _scanned.clear();
    _isScanning = true;
    notifyListeners();
    try {
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        _error = 'Bluetooth is off. Please enable it.';
        _isScanning = false;
        notifyListeners();
        return;
      }
      await FlutterBluePlus.stopScan();
      _scanSub?.cancel();
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;
          if (name.isEmpty) continue;
          final dev = BMHBleDevice(
            id: r.device.remoteId.str, name: name, rssi: r.rssi,
            type: BMHBleDevice.detectType(name), device: r.device,
          );
          final idx = _scanned.indexWhere((d) => d.id == dev.id);
          if (idx >= 0) _scanned[idx] = dev; else _scanned.add(dev);
          _scanned.sort((a, b) {
            if (a.type != BMHDeviceType.unknown &&
                b.type == BMHDeviceType.unknown) return -1;
            if (b.type != BMHDeviceType.unknown &&
                a.type == BMHDeviceType.unknown) return 1;
            return b.rssi.compareTo(a.rssi);
          });
          notifyListeners();
        }
      });
      FlutterBluePlus.isScanning.listen((s) {
        if (!s && _isScanning) { _isScanning = false; notifyListeners(); }
      });
    } catch (e) {
      _error = 'Scan failed: $e';
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _isScanning = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────
  //  CONNECT
  // ─────────────────────────────────────────────────────
  Future<bool> connectDevice(BMHBleDevice dev) async {
    // Reentrancy guard — prevents two overlapping connect() calls on the
    // same device (e.g. an app-resume reconnect firing at the same moment
    // as a scheduled retry), which the OS Bluetooth stack handles poorly
    // and was making connections progressively slower/flakier.
    if (_isConnecting) return false;

    _isConnecting = true;
    _error = null;
    // Any deliberate connect attempt (manual pick, auto-reconnect, retry)
    // means we want to be connected — cancel any "user disconnected on
    // purpose" state so auto-reconnect can resume working normally.
    _manualDisconnect = false;
    notifyListeners();

    try {
      // Save for auto-reconnect (in-memory + persisted across restarts)
      if (dev.type != BMHDeviceType.bioScale) {
        _lastBandDev = dev;
        _saveLastDevice(dev);
      }

      await dev.device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Listen for disconnect — keep trying to reconnect (fast at first,
      // then a slower persistent retry) until reconnected or the user
      // explicitly disconnects. Never silently gives up.
      _connStateSub?.cancel();
      _connStateSub = dev.device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          if (dev.type != BMHDeviceType.bioScale) {
            _connectedBand = null;
            _writeChar = null;
            _stopTimers();
            _scheduleReconnect();
          } else {
            _connectedScale = null;
            notifyListeners();
          }
        }
      });

      // Discover services and find FFF0/FFF6/FFF7
      final services = await dev.device.discoverServices();
      BluetoothCharacteristic? writeChar;
      BluetoothCharacteristic? notifyChar;

      for (final svc in services) {
        final sId = svc.serviceUuid.toString().toLowerCase();
        if (!sId.contains('fff0')) continue;

        for (final c in svc.characteristics) {
          final cId = c.uuid.toString().toLowerCase();
          if (cId.contains('fff6')) writeChar = c;
          if (cId.contains('fff7')) notifyChar = c;
        }
        if (writeChar != null) break;
      }

      // Fallback if FFF0 not found
      if (writeChar == null) {
        for (final svc in services) {
          for (final c in svc.characteristics) {
            if (writeChar == null &&
                (c.properties.write || c.properties.writeWithoutResponse)) {
              writeChar = c;
            }
            if (notifyChar == null &&
                (c.properties.notify || c.properties.indicate)) {
              notifyChar = c;
            }
          }
        }
      }

      // Subscribe to notifications (FFF7)
      if (notifyChar != null) {
        await notifyChar.setNotifyValue(true);
        _notifySub?.cancel();
        _notifySub = notifyChar.lastValueStream.listen((data) {
          if (data.isNotEmpty) _parse(data);
        });
      }

      _writeChar = writeChar;

      if (dev.type != BMHDeviceType.bioScale) {
        _connectedBand = dev;
        _reconnectCount = 0;
        _isReconnecting = false;
        await _initBand();
        _startKeepAlive();
        _startRefreshTimer();
        _startMeasurementTimer();
        _startWatchdog();
        _startWearDetection();
        _seedSleep();
        // Sync band's stored history after 3s (band needs to stabilise first)
        Future.delayed(const Duration(seconds: 3), () => _syncBandHistory());
      } else {
        _connectedScale = dev;
      }

      _isConnecting = false;
      notifyListeners();
      return true;

    } catch (e) {
      _error = 'Connection failed. Move closer and try again.';
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────
  //  INIT BAND — exact command sequence from SDK
  // ─────────────────────────────────────────────────────
  Future<void> _initBand() async {
    // 0. Vibrate band to confirm connection (SDK: MotorVibrationWithTimes)
    //    CMD_Set_MOT_SIGN = 0x36, times = 2 (double buzz)
    await _write(_cmd([0x36, 0x02]));
    await _delay(400);
    // 1. Set device time first (SDK requires this)
    await _write(_buildTimeCmd());
    await _delay(300);
    // 2. Start real-time step+HR+temp stream
    await _write(_cmd([_REAL_STEP, 0x01, 0x01]));
    await _delay(300);
    // 3. Get battery level
    await _write(_cmd([_BATTERY]));
    await _delay(200);
    // 4. NOTE: _TOTAL_DATA (0x51) removed — handled by _syncBandHistory()
    //    to avoid overwriting live step count from 0x09
    // 5. Get single HR reading
    await _write(_cmd([_HR_ONCE, 0x00]));
    await _delay(200);
    // 6. WEAR PROBE — send SpO2 command immediately during init.
    //    Band responds with 0x28 packet containing KSlipHand (d[2]):
    //    0x01 = on wrist, 0x00 = off wrist. This is the fastest possible
    //    hardware confirmation — fires as soon as band is ready (~1–2s after connect).
    await _write(_cmd([_BLOOD_O2, 0x00]));
    await _delay(300);
    // 6b. Second immediate probe — band sometimes needs two pings on cold connect
    await _write(_cmd([_BLOOD_O2, 0x00]));
    await _delay(200);
    // 7. Get sleep data from band
    await _write(_cmd([_SLEEP, 0x00]));
    await _delay(500);
    // Request again after 2s - band sometimes needs 2 requests
    Future.delayed(const Duration(seconds: 2), () async {
      if (isBandConnected) await _write(_cmd([_SLEEP, 0x00]));
    });
  }

  // ─────────────────────────────────────────────────────
  //  BAND HISTORY SYNC
  //  Uses SDK pagination: mode 0 (start) → mode 2 (continue)
  //  until band sends 0xff end marker — fetches up to 30 days
  // ─────────────────────────────────────────────────────

  // Tracks pending history fetches — key = command byte
  final Map<int, bool> _historyPending = {};

  // Tracks which measurement types are currently STARTING (not yet complete).
  // Band's 0x28 response immediately after a START command has unreliable
  // KSlipHand (d[2]) because the sensor has not locked onto skin yet.
  // We ignore KSlipHand=0x00 while a measurement is in this set.
  final Set<int> _measurementInProgress = {};

  // Watchdog: timestamp of last real data packet from band (0x09 stream).
  // If no data arrives for 8s, watchdog re-sends REAL_STEP to wake the band.
  DateTime _lastDataTime = DateTime.now();
  Timer?   _watchdogTimer;

  Future<void> _syncBandHistory() async {
    if (!isBandConnected || _writeChar == null) return;

    // 1. HR dynamic history (0x54) — up to 30 days, 15 readings/packet
    await _fetchHistory(_HR_HISTORY);
    await _delay(800);

    // 2. Total steps + calories + distance history (0x51)
    await _fetchHistory(_TOTAL_DATA);
    await _delay(800);

    // 3. SpO2 auto history (0x66)
    await _fetchHistory(0x66);
    await _delay(500);

    // 4. HRV + BP + Stress history (0x56)
    await _fetchHistory(_HRV);
    await _delay(500);

    // 5. Sleep history (0x53)
    await _fetchHistory(_SLEEP);
    await _delay(500);

    // 6. Temperature auto history (0x65)
    await _fetchHistory(_TEMP_AUTO);
    await _delay(500);

    // 7. Temperature manual history (0x62)
    await _fetchHistory(_TEMP_HIST);

    notifyListeners();
  }

  // Send mode=0 (start). _parse() handles mode=2 continuation
  final Map<int, int> _historyContinueCount = {};
  static const int _maxHistoryContinues = 80; // ~30 days of records

  Future<void> _fetchHistory(int cmd) async {
    if (!isBandConnected || _writeChar == null) return;
    _historyPending[cmd] = true;
    _historyContinueCount[cmd] = 0;
    await _write(_cmd([cmd, _MODE_START]));
  }

  Future<void> _continueHistory(int cmd) async {
    if (!isBandConnected || _writeChar == null) return;
    if (_historyPending[cmd] != true) return;
    // HARD SAFETY CAP — if the band's end marker is ever missed,
    // stop after a bounded number of pages instead of flooding the
    // band with continue commands forever (freezes UI, drops link).
    final n = (_historyContinueCount[cmd] ?? 0) + 1;
    _historyContinueCount[cmd] = n;
    if (n > _maxHistoryContinues) {
      _endHistory(cmd);
      return;
    }
    await _delay(200);
    await _write(_cmd([cmd, _MODE_CONTINUE]));
  }

  void _endHistory(int cmd) => _historyPending[cmd] = false;

  /// Public: fetch the HRV history (0x56) which carries the freshest
  /// HRV + Blood Pressure + Stress records. Called by the Measure Now
  /// flow because the band does NOT stream BP in its live measurement
  /// packet — BP results only land in these history records.
  Future<void> syncHrvHistory() => _fetchHistory(_HRV);

  // ── MEASUREMENT COMPLETION SIGNAL ─────────────────────
  // The band streams 0x28 result packets while measuring; a packet
  // with a VALID value for the measured type means the measurement
  // produced its result. Measure Now uses this instead of guessing
  // with timers.
  final Map<int, DateTime> _lastResultAt = {};
  void _markResult(int type) => _lastResultAt[type] = DateTime.now();

  /// When the band last delivered a valid result for a 0x28 type
  /// (0x01 HRV, 0x02 HR, 0x03 SpO2, 0x04 Temp, 0x05 Stress).
  DateTime? lastResultAt(int type) => _lastResultAt[type];

  // ─────────────────────────────────────────────────────
  //  BCD helpers — SDK _bcd2String equivalent
  // ─────────────────────────────────────────────────────
  int _bcd(int b) => ((b & 0xf0) >> 4) * 10 + (b & 0x0f);

  // Parse date from history packet — bytes at offset..offset+5
  // Band format: YY MM DD HH mm ss (all BCD)
  DateTime? _parseDate(List<int> d, int offset) {
    try {
      if (d.length < offset + 6) return null;
      final y  = 2000 + _bcd(d[offset]);
      final mo = _bcd(d[offset + 1]);
      final dy = _bcd(d[offset + 2]);
      final h  = _bcd(d[offset + 3]);
      final mi = _bcd(d[offset + 4]);
      final s  = _bcd(d[offset + 5]);
      if (mo < 1 || mo > 12 || dy < 1 || dy > 31) return null;
      return DateTime(y, mo, dy, h, mi, s);
    } catch (_) { return null; }
  }

  // ─────────────────────────────────────────────────────
  //  KEEP-ALIVE — re-sends RealTimeStep every 4s
  //  The band stops sending data if you stop pinging it
  // ─────────────────────────────────────────────────────
  void _startKeepAlive() {
  _keepAliveTimer?.cancel();
  _keepAliveTimer = Timer.periodic(
    const Duration(seconds: 5), (_) async {
    if (!isBandConnected || _writeChar == null) return;

    // Only ping when the real-time stream has actually gone quiet.
    // Flooding the band with 0x09 every few seconds while data is
    // already flowing congests its command buffer and is a known
    // cause of spontaneous disconnects on JStyle firmware.
    final silentFor = DateTime.now().difference(_lastDataTime);
    if (silentFor < const Duration(seconds: 6)) return;

    await _write(_cmd([_REAL_STEP, 0x01, 0x01]));
    // NOTE: _TOTAL_DATA removed — causes step count flickering
  });
}

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3), (_) async {
      if (!isBandConnected) return;
      _isRefreshing = true; notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      _isRefreshing = false; notifyListeners();
    });
  }

  // Polls SpO2, HRV, Stress every 30s each
  // Runs AFTER band is stable (10s delay)
  Timer? _measurementTimer;
  int _measureTick = 0;

  void _startMeasurementTimer() {
    _measurementTimer?.cancel();
    // Wait 10s for band to stabilise before first measurement
    Future.delayed(const Duration(seconds: 10), () {
      if (!isBandConnected) return;
      _measurementTimer = Timer.periodic(
        const Duration(seconds: 10), (_) async {
        if (!isBandConnected || _writeChar == null) return;
        _measureTick++;
        // Refresh battery every ~5 min so the UI stays truthful
        if (_measureTick % 30 == 0) {
          await _write(_cmd([_BATTERY]));
        }
        switch (_measureTick % 8) {
          case 1: // SpO2 manual
            await _write(_cmd([_BLOOD_O2, 0x00]));
            break;
          case 2: // SpO2 auto
            await _write(_cmd([0x66, 0x00]));
            break;
          case 3: // HRV + Stress + BP in one shot
            await _write(_cmd([0x56, 0x00]));
            break;
          case 4: // Temperature — START measurement
            // Mark in-progress: band's immediate 0x28 reply has unreliable
            // KSlipHand because sensor hasn't locked on yet. Ignore it.
            _measurementInProgress.add(0x04);
            await _write(_cmd([_MEASURE, 0x04, 0x01]));
            break;
          case 5: // Temperature — STOP + read result
            // Measurement completing — KSlipHand now reliable
            _measurementInProgress.remove(0x04);
            await _write(_cmd([_MEASURE, 0x04, 0x00]));
            break;
          case 6: // Keep-alive
            await _write(_cmd([_REAL_STEP, 0x01, 0x01]));
            break;
          case 7: // SpO2 again
            await _write(_cmd([_BLOOD_O2, 0x00]));
            break;
          case 0: // Sleep sync
            await _write(_cmd([_SLEEP, 0x00]));
            break;
        }
      });
    });
  }

  // ─────────────────────────────────────────────────────
  //  WATCHDOG — detects band gone silent and re-wakes it
  //  The JCV5 band sometimes stops sending 0x09 packets even
  //  though BLE is still connected. The watchdog notices when
  //  no data has arrived for 8s and re-sends REAL_STEP to
  //  restart the stream — no disconnect/reconnect needed.
  // ─────────────────────────────────────────────────────
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _lastDataTime = DateTime.now();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!isBandConnected || _writeChar == null) return;
      final silent = DateTime.now().difference(_lastDataTime).inSeconds;
      if (silent >= 8) {
        // Band has gone quiet — re-send REAL_STEP to wake it up
        await _write(_cmd([_REAL_STEP, 0x01, 0x01]));
        await _delay(300);
        await _write(_cmd([_REAL_STEP, 0x01, 0x01]));
        // Also re-probe wear status in case it changed while silent
        await _delay(300);
        await _write(_cmd([_BLOOD_O2, 0x00]));
      }
    });
  }

  // Called once after band connects
  void _startWearDetection() {
    // FIX 3: Preserve _isWearing across reconnects.
    // If the band was confirmed worn before a BLE drop (phone locked,
    // brief range loss, etc.), keep _isWearing = true so data is NOT
    // hidden during the 2-8s re-probe window after reconnect.
    // The incoming 0x28 hardware probe will correct it if the band
    // was actually removed. For a brand-new cold connect (never worn),
    // _isWearing starts false already so nothing changes.
    final preserveWearing = _isWearing && _wearProbeReceived;
    if (!preserveWearing) _isWearing = false;

    _wearAsked          = false;
    _wearScore          = 0;
    _lastHr             = 0;
    _hrChangeCount      = 0;
    _noChangeCount      = 0;
    _lastStepCheck      = 0;
    _stepsMoving        = false;
    _lastUpdate         = DateTime.now();
    _wearProbeReceived  = false;   // reset - must get fresh hardware confirmation
    _slipHandZeroCount  = 0;       // reset debounce counter on every connect
    _connectedAt        = DateTime.now();
    notifyListeners();

    // Send SpO2 probe immediately via _initBand() above — that fires as part of
    // the init sequence (~1–2s after connect) and is the fastest path.
    // Backup probe at 3s — catches cases where _initBand probe was dropped (BLE loss).
    Future.delayed(const Duration(seconds: 3), () async {
      if (!isBandConnected || _writeChar == null) return;
      if (!_wearProbeReceived) {
        await _write(_cmd([_BLOOD_O2, 0x00])); // triggers 0x28 response with KSlipHand
      }
    });

    // Third backup at 8s — belt-and-suspenders for noisy BLE environments
    Future.delayed(const Duration(seconds: 8), () async {
      if (!isBandConnected || _writeChar == null) return;
      if (!_wearProbeReceived) {
        await _write(_cmd([_BLOOD_O2, 0x00]));
      }
    });
  }

  // Manual confirmation by user (popup)
  void confirmWearing(bool wearing) {
    _isWearing = wearing;
    _wearAsked = true;
    notifyListeners();
  }

  // ── WEAR DETECTION — Hardware-first approach ─────────────────────────────
  // PRIMARY: KSlipHand hardware bit from 0x28 packet (set in parser above).
  //   → This is ground truth from the band's own contact sensor.
  //   → Updated every time a measurement result arrives (every 10-20s).
  //
  // SECONDARY: Score system used ONLY when band has been worn and
  //   we need to detect if it was removed between measurements.
  //   Score can only REMOVE worn status, never GRANT it without hardware proof.
  void _detectWearing() {
    final now = DateTime.now();
    _lastUpdate = now;

    // ── PHASE 1: Waiting for hardware probe (first 20 seconds) ───────────
    // Until the 0x28 probe response arrives, we don't touch _isWearing.
    // _isWearing starts false and stays false. No data shown. Period.
    if (!_wearProbeReceived) {
      _wearScore = 0;
      // _isWearing remains false — already set in _startWearDetection
      return;
    }

    // ── PHASE 2: Hardware has responded — track removal only ─────────────
    // KSlipHand already set _isWearing correctly in the 0x28 handler.
    // Here we only check for removal signals between probe intervals.

    // Track HR changes
    if (_heartRate >= 40 && _heartRate <= 200) {
      if (_heartRate != _lastHr) {
        _hrChangeCount++;
        _noChangeCount = 0;
      } else {
        _noChangeCount++;
        _hrChangeCount = 0;
      }
    }
    _lastHr = _heartRate;

    // Track steps
    if (_steps > _lastStepCheck) {
      _stepsMoving = true;
    } else if (_noChangeCount > 15) {
      _stepsMoving = false; // reset after long freeze
    }
    _lastStepCheck = _steps;

    // ── REMOVAL DETECTION ────────────────────────────────
    // Only flip to false if very strong evidence of removal.
    // Conditions: HR completely frozen for 20+ ticks AND zero steps AND
    // temperature dropped below body range.
    // We are conservative here — false negatives (showing -- when worn)
    // are worse UX than waiting for the next hardware probe to correct.
    if (_isWearing) {
      final hrFrozenLong   = _noChangeCount >= 60; // ~3 min frozen (20 pkts/min × 3)
      final noMovement     = !_stepsMoving;
      final tempBelowBody  = _temperature > 0 && _temperature < 35.0; // raised from 33→35

      if (hrFrozenLong && noMovement && tempBelowBody) {
        _isWearing = false; // likely removed — next probe will confirm
      }
    }

    // Update score for UI display only (debug pill)
    int score = 0;
    if (_isWearing) score += 60;
    if (_hrChangeCount > 0) score += 20;
    if (_stepsMoving) score += 20;
    _wearScore = score.clamp(0, 100);
  }

  void _stopTimers() {
    _keepAliveTimer?.cancel();
    _refreshTimer?.cancel();
    _measurementTimer?.cancel();
    _watchdogTimer?.cancel();
    _keepAliveTimer    = null;
    _refreshTimer      = null;
    _measurementTimer  = null;
    _watchdogTimer     = null;
  }

  // ─────────────────────────────────────────────────────
  //  WRITE
  // ─────────────────────────────────────────────────────
  Future<void> _write(Uint8List data) async {
    if (_writeChar == null) return;
    try {
      await _writeChar!.write(
        data,
        withoutResponse: _writeChar!.properties.writeWithoutResponse,
      );
    } catch (_) {}
  }

  Future<void> _delay(int ms) =>
      Future.delayed(Duration(milliseconds: ms));

  Uint8List _buildTimeCmd() {
    final n = DateTime.now();
    int bcd(int v) => int.parse(v.toString().padLeft(2,'0'), radix: 16);
    return _cmd([_SET_TIME,
      bcd(n.year % 100), bcd(n.month), bcd(n.day),
      bcd(n.hour), bcd(n.minute), bcd(n.second)]);
  }

  /// Buzz the band's motor [times] times (SDK CMD_Set_MOT_SIGN 0x36).
  /// Used to signal "measurement starting / finished" like a clinical
  /// device would.
  Future<void> vibrateBand({int times = 2}) async {
    if (!isBandConnected || _writeChar == null) return;
    try {
      await _write(_cmd([0x36, times & 0xff]));
    } catch (_) {}
  }

  Future<void> startMeasurement(int type) async {
    if (type == 0x03) {
      // SDK: GetBloodOxygen(0) = [0x60, 0x00] reads latest stored SpO2
      await _write(_cmd([_BLOOD_O2, 0x00]));
      await Future.delayed(const Duration(milliseconds: 300));
      await _write(_cmd([0x66, 0x00]));
    } else {
      // Mark in-progress so KSlipHand=0x00 on START reply is ignored
      _measurementInProgress.add(type);
      await _write(_cmd([_MEASURE, type, 0x01]));
    }
  }

  Future<void> stopMeasurement(int type) async {
    if (type == 0x03) return; // SpO2 stops automatically
    _measurementInProgress.remove(type); // measurement completing — trust KSlipHand again
    await _write(_cmd([_MEASURE, type, 0x00]));
  }

  Future<void> manualRefresh() async {
    if (!isBandConnected) return;
    _isRefreshing = true; notifyListeners();

    // Send REAL_STEP twice — band sometimes needs second ping to resume stream
    await _write(_cmd([_REAL_STEP, 0x01, 0x01]));
    await _delay(150);
    await _write(_cmd([_REAL_STEP, 0x01, 0x01])); // second ping for reliability
    await _delay(200);
    await _write(_cmd([_BATTERY]));                // Battery
    await _delay(200);
    // NOTE: _TOTAL_DATA (0x51) removed from refresh — it's history data
    // and overwrites live step count. Live steps come from 0x09 above.
    await _write(_cmd([0x56, 0x00]));              // HRV + BP + Stress
    await _delay(300);
    await _write(_cmd([_BLOOD_O2, 0x00]));         // SpO2
    await _delay(300);
    await _write(_cmd([0x66, 0x00]));              // Auto SpO2
    await _delay(300);
    await _write(_cmd([_SLEEP, 0x00]));            // Sleep data

    await Future.delayed(const Duration(milliseconds: 500));
    _isRefreshing = false; notifyListeners();
  }

  // ─────────────────────────────────────────────────────
  //  PARSE — exact from SDK DataParsingWithData + resolve_util
  // ─────────────────────────────────────────────────────
  void _parse(List<int> d) {
    if (d.isEmpty) return;
    try {
      switch (d[0]) {
        case 0x09: // RealTimeStep — steps+HR+temp+calories+distance
          // Update watchdog timestamp — band is alive and sending data
          _lastDataTime = DateTime.now();
          // SDK confirmed byte positions:
          // d[1..4]   = Steps (little-endian 4 bytes)
          // d[5..8]   = Calories * 100 (little-endian)
          // d[9..12]  = Distance * 100 (little-endian)
          // d[13..16] = Exercise minutes
          // d[21]     = Heart Rate
          // d[22..23] = Temperature (raw/10.0)
          if (d.length >= 22) {
            final s = _le4(d, 1);
            if (s >= 0 && s < 100000) _steps = s;

            if (d.length >= 9) {
              final cal = _le4(d, 5);
              if (cal > 0) _calories = cal / 100.0;
            }
            if (d.length >= 13) {
              final dist = _le4(d, 9);
              if (dist > 0) _distance = dist / 100.0;
            }
            if (d.length >= 17) {
              final exMin = _le4(d, 13);
              if (exMin >= 0) _exerciseMin = exMin;
            }

            final h = d[21] & 0xff;
            if (h >= 40 && h <= 200) {
              _heartRate = h;
              _calcAge();
              // IMPLICIT WEAR CONFIRMATION:
              // A valid HR in the 0x09 real-time stream is physiologically
              // impossible without skin contact. If KSlipHand probe (0x28)
              // hasn't arrived yet — e.g. JCV5 band responds slowly — trust
              // the live HR as hardware proof the band is worn on wrist.
              // FIX 1: Also resets the debounce counter — live HR is ground
              // truth that the band is on wrist right now.
              if (!_wearProbeReceived || !_isWearing) {
                _wearProbeReceived = true;
                _isWearing = true;
              }
              _slipHandZeroCount = 0; // live HR = definitely wearing, reset debounce
            }

            if (d.length >= 24) {
              final raw = (d[22] & 0xff) + (d[23] & 0xff) * 256;
              final t = raw / 10.0;
              // Guard raised from 30.0 to 35.0:
              // Band sends warmup/room temps (31-34°C) for first 1-2 min
              // after being put on. Storing these causes _detectWearing()
              // removal logic to see tempBelowBody=true and wrongly flip
              // _isWearing=false. Real body temp is always >= 35.0°C.
              if (t >= 35.0 && t < 42.0) _temperature = (t * 10).roundToDouble() / 10;
            }
          }
          break;
        case 0x13: // Battery
          if (d.length >= 2 && d[1] > 0) _battery = d[1] & 0xff;
          break;
        case 0x18: // Heart package during exercise
          if (d.length >= 2) {
            final h = d[1] & 0xff;
            if (h >= 40 && h <= 200) { _heartRate = h; _calcAge(); }
          }
          break;
        case 0x51: // Total activity history — steps + calories + distance
          // IMPORTANT: 0x51 is HISTORY data — NEVER overwrite live _steps
          // Live steps come ONLY from 0x09 real-time stream
          {
            final hist = VitalHistoryService.instance;
            final bool isEnd = d.isNotEmpty && d[d.length - 1] == 0xff;

            // Record size is 26 or 27 bytes per history record
            final recSize = (d.length % 26 == 0) ? 26 :
                            (d.length % 27 == 0) ? 27 : 0;

            if (recSize > 0 && d.length >= recSize) {
              // History packet — save to VitalHistoryService with past timestamps
              // DO NOT touch _steps, _calories, _distance (those are live values)
              final size = d.length ~/ recSize;
              for (int i = 0; i < size; i++) {
                final base = i * recSize;
                if (base + recSize > d.length) break;
                final dt    = _parseDate(d, base + 2);
                final steps = _le4(d, base + 5);
                double cal  = 0;
                double dist = 0;
                for (int j = 0; j < 4; j++) {
                  cal  += (d[base + 17 + j] & 0xff) * (1 << (j * 8));
                  dist += (d[base + 13 + j] & 0xff) * (1 << (j * 8));
                }
                if (steps > 0 && steps < 100000 && dt != null) {
                  hist.recordAt('steps', dt, steps.toDouble());
                  if (cal  > 0) hist.recordAt('calories', dt, cal / 100.0);
                  if (dist > 0) hist.recordAt('distance', dt, dist / 100.0);
                }
              }
            } else if (d.length >= 5) {
              // Short live response (not a paginated history record)
              // Only update _steps if value is GREATER (steps only go up in a day)
              final s = _le4(d, 1);
              if (s > _steps && s < 100000) _steps = s;
              if (d.length >= 9) { final cal = _le4(d, 5); if (cal > 0) _calories = cal / 100.0; }
              if (d.length >= 13) { final dist = _le4(d, 9); if (dist > 0) _distance = dist / 100.0; }
            }

            if (isEnd) {
              _endHistory(_TOTAL_DATA);
            } else if (_historyPending[_TOTAL_DATA] == true) {
              _continueHistory(_TOTAL_DATA);
            }
          }
          break;
        case 0x53: // Sleep data from band — OFFICIAL JStyle SDK format
          // (verified against blesdk2025_plugin resolve_util.getSleepData)
          //
          // Paginated history. Two packet layouts:
          //  A) Multi-record: 34 bytes per record —
          //     [0]=0x53, [3..8]=BCD date YY MM DD HH mm ss (segment START),
          //     [9]=sample count (≤24), [10..]=per-sample sleep quality,
          //     each sample = 5 minutes.
          //  B) Single long record (length 130, or 132 with end marker):
          //     same header, but each sample = 1 minute.
          //  End of pagination: last byte 0xff AND second-to-last == 0x53.
          //
          // Quality value = movement level in that interval.
          // Stage thresholds (tunable — validate against vendor app):
          //   ≤ deepMax → deep, ≤ lightMax → light, above → awake.
          {
            // End detection: match the other history handlers — a
            // trailing 0xff terminates pagination. (The stricter
            // "0x53 0xff" pair check could miss the band's actual end
            // packet and loop forever, flooding the band with
            // continue commands → frozen UI → watchdog kill.)
            final isEnd53 = d.isNotEmpty && d[d.length - 1] == 0xff;

            void addSegment(int off, int unitMin) {
              final dt = _parseDate(d, off + 3);
              if (dt == null) return;
              final n = d[off + 9] & 0xff;
              for (int j = 0; j < n; j++) {
                final idx = off + 10 + j;
                if (idx >= d.length) break;
                final t = dt.add(Duration(minutes: j * unitMin));
                // Dedupe by minute across repeated syncs
                _sleepSamples[t.millisecondsSinceEpoch ~/ 60000] =
                    (d[idx] & 0xff, unitMin);
              }
            }

            if (d.length == 130 || (isEnd53 && d.length == 132)) {
              addSegment(0, 1); // 1-minute resolution variant
            } else {
              const rec = 34;
              final size = d.length ~/ rec;
              for (int i = 0; i < size; i++) {
                if (i * rec + 34 > d.length) break;
                addSegment(i * rec, 5);
              }
            }

            if (isEnd53) {
              _endHistory(_SLEEP);
              _rebuildSleepFromSamples();
            } else if (_historyPending[_SLEEP] == true) {
              _continueHistory(_SLEEP);
            } else {
              // Live one-shot request (init) — still rebuild
              _rebuildSleepFromSamples();
            }
          }
          break;
        case 0x54: // HR dynamic history — 24 bytes/record
          // SDK getHeartData(): date at [3..8], then 15 HR values at [9..23]
          {
            final hist = VitalHistoryService.instance;
            const recSize = 24;
            final isEnd = d.isNotEmpty && d[d.length - 1] == 0xff;

            if (d.length >= recSize) {
              final size = d.length ~/ recSize;
              for (int i = 0; i < size; i++) {
                final base = i * recSize;
                if (base + recSize > d.length) break;

                // Date: bytes 3..8 within record
                final dt = _parseDate(d, base + 3);
                if (dt == null) continue;

                // 15 HR readings starting at byte 9
                // Each reading = 5 minutes apart
                for (int j = 0; j < 15; j++) {
                  if (base + 9 + j >= d.length) break;
                  final h = d[base + 9 + j] & 0xff;
                  if (h > 30 && h < 220) {
                    final readingTime = dt.add(Duration(minutes: j * 5));
                    hist.recordAt('heart_rate', readingTime, h.toDouble());
                    _heartRate = h;
                  }
                }
              }
            }

            if (isEnd) {
              _endHistory(_HR_HISTORY);
            } else if (_historyPending[_HR_HISTORY] == true) {
              _continueHistory(_HR_HISTORY);
            }
          }
          break;
        case 0x55: // Single HR
          if (d.length >= 10) {
            final h = d[9] & 0xff;
            if (h > 30 && h < 220) { _heartRate = h; _calcAge(); }
          }
          break;
        case 0x56: // HRV + Stress + BP — live and history
          // SDK getHrvTestData(): 15 bytes/record
          // date[3..8], hrv[9], vascular[10], hr[11], stress[12], highBP[13], lowBP[14]
          {
            final hist56 = VitalHistoryService.instance;
            final isEnd56 = d.isNotEmpty && d[d.length - 1] == 0xff;
            const recSize56 = 15;

            if (d.length >= recSize56) {
              final size56 = d.length ~/ recSize56;
              for (int i = 0; i < size56; i++) {
                final base = i * recSize56;
                if (base + recSize56 > d.length) break;
                final hrv    = d[base + 9]  & 0xff;
                final stress = d[base + 12] & 0xff;
                final sys    = d[base + 13] & 0xff;
                final dia    = d[base + 14] & 0xff;
                if (hrv > 0 && hrv < 300)    _hrv = hrv;
                if (stress > 0 && stress <= 100) _stressLevel = stress;
                if (sys > 60 && sys < 200 && dia > 40 && dia < 130) {
                  _setBp(sys, dia);
                }
                final dt56 = _parseDate(d, base + 3);
                if (dt56 != null) {
                  if (hrv > 0)    hist56.recordAt('hrv',            dt56, hrv.toDouble());
                  if (stress > 0) hist56.recordAt('stress',         dt56, stress.toDouble());
                  if (sys > 60)   hist56.recordAt('blood_pressure', dt56, sys.toDouble());
                  if (dia > 40)   hist56.recordAt('bp_diastolic',   dt56, dia.toDouble());
                }
              }
            } else {
              // Short live packet
              if (d.length >= 10) { final hrv = d[9] & 0xff; if (hrv > 0 && hrv < 300) _hrv = hrv; }
              if (d.length >= 13) { final st = d[12] & 0xff; if (st > 0 && st <= 100) _stressLevel = st; }
              if (d.length >= 15) {
                final sys = d[13] & 0xff; final dia = d[14] & 0xff;
                if (sys > 60 && sys < 200 && dia > 40 && dia < 130) { _setBp(sys, dia); }
              }
            }
            if (isEnd56) _endHistory(_HRV);
            else if (_historyPending[_HRV] == true) _continueHistory(_HRV);
          }
          break;
        case 0x60: // Manual SpO2
        case 0x66: // Auto SpO2 — SDK getBloodoxygen(): 10 bytes/record
          // date[3..8], spo2[9]
          {
            final hist60 = VitalHistoryService.instance;
            const recSize60 = 10;
            final cmd60 = d[0];
            final isEnd60 = d.isNotEmpty && d[d.length - 1] == 0xff;

            if (d.length >= recSize60) {
              final size60 = d.length ~/ recSize60;
              for (int i = 0; i < size60; i++) {
                final base = i * recSize60;
                if (base + recSize60 > d.length) break;
                final o = d[base + 9] & 0xff;
                if (o > 60 && o <= 100) {
                  _spo2 = o;
                  final dt60 = _parseDate(d, base + 3);
                  if (dt60 != null) hist60.recordAt('spo2', dt60, o.toDouble());
                  else hist60.record('spo2', o.toDouble());
                }
              }
            } else {
              // Short packet
              for (int i = 1; i < d.length; i++) {
                final o = d[i] & 0xff;
                if (o >= 85 && o <= 100) { _spo2 = o; break; }
              }
            }
            if (isEnd60) _endHistory(cmd60);
            else if (_historyPending[cmd60] == true) _continueHistory(cmd60);
          }
          break;

        case 0x65: // Temperature auto history
        case 0x62: // Temperature manual history
          // SDK getTempData(): 11 bytes/record
          // date[3..8], temp_low[9], temp_high[10] → (low + high*256) * 0.1
          {
            final histT = VitalHistoryService.instance;
            const recSizeT = 11;
            final cmdT = d[0];
            final isEndT = d.isNotEmpty && d[d.length - 1] == 0xff;

            if (d.length >= recSizeT) {
              final sizeT = d.length ~/ recSizeT;
              for (int i = 0; i < sizeT; i++) {
                final base = i * recSizeT;
                if (base + recSizeT > d.length) break;
                final raw = (d[base + 9] & 0xff) + (d[base + 10] & 0xff) * 256;
                final t = raw * 0.1;
                if (t > 34.0 && t < 42.0) {
                  _temperature = (t * 10).roundToDouble() / 10;
                  final dtT = _parseDate(d, base + 3);
                  final tR = (t * 10).roundToDouble() / 10;
                  if (dtT != null) histT.recordAt('temperature', dtT, tR);
                  else histT.record('temperature', tR);
                }
              }
            }
            if (isEndT) _endHistory(cmdT);
            else if (_historyPending[cmdT] == true) _continueHistory(cmdT);
          }
          break;
        case 0x28: // Measurement result
          if (d.length >= 4) {
            final type = d[1] & 0xff;
            final val  = d[3] & 0xff;

            // KSlipHand detection — byte d[2] during measurement
            // 0x01 = wearing on wrist, 0x00 = not wearing
            // SDK DeviceKey.java: KSlipHand: 1=wearing, 0=removed
            // This is HARDWARE ground truth — always trusted over score system
            if (d.length >= 3) {
              final slipHand = d[2] & 0xff;
              _wearProbeReceived = true; // hardware has responded

              // Three-tier KSlipHand trust rules:
              //
              // Tier 1 — Measurement just STARTED (_measurementInProgress):
              //   Sensor hasn't locked on yet → d[2] is unreliable.
              //   Accept worn=true (bonus), ignore not-worn=false entirely.
              //
              // Tier 2 — Init/idle packet (type==0x00):
              //   Band status packet, not a real reading.
              //   Accept worn=true only.
              //
              // Tier 3 — Measurement COMPLETE (not in-progress, type!=0x00):
              //   KSlipHand is fully reliable. Trust both directions.
              final bool measureStarting = _measurementInProgress.contains(type);

              // FIX 2: SpO2 probes (type==0x03) are continuous probes,
              // NOT completed measurements. Their 0x28 reply is unreliable
              // for not-wearing detection — treat them like in-progress measurements.
              // Only accept worn=true from SpO2 probes, never worn=false.
              final bool isSpO2Probe = (type == 0x03);

              if (measureStarting || isSpO2Probe) {
                // Sensor not locked OR SpO2 probe — only accept worn confirmation
                if (slipHand == 0x01) {
                  _slipHandZeroCount = 0; // reset debounce on any worn confirmation
                  _wearProbeReceived = true;
                  _isWearing = true;
                }
                // slipHand==0x00 here is ignored entirely — not reliable

              } else if (type == 0x00) {
                // Init/idle packet — only accept worn confirmation
                if (slipHand == 0x01) {
                  _slipHandZeroCount = 0;
                  _wearProbeReceived = true;
                  _isWearing = true;
                }

              } else {
                // Measurement complete (temp, HRV, BP, stress) — reliable result.
                // FIX 1: Debounce — require 3 consecutive 0x00 before trusting removal.
                // One brief sensor lift-off (wrist rotation, scratching) is ignored.
                // Any 0x01 immediately resets the counter and confirms wearing.
                _wearProbeReceived = true;
                if (slipHand == 0x00) {
                  _slipHandZeroCount++;
                  if (_slipHandZeroCount >= 5) {
                    // 3 consecutive not-wearing readings — genuinely removed
                    _isWearing = false;
                    _slipHandZeroCount = 0;
                    // Re-probe after 2s to confirm (band may have been briefly lifted)
                    Future.delayed(const Duration(seconds: 2), () async {
                      if (isBandConnected && _writeChar != null && !_isWearing) {
                        await _write(_cmd([_BLOOD_O2, 0x00]));
                      }
                    });
                  }
                  // else: 1 or 2 consecutive 0x00 — wait for more evidence
                } else if (slipHand == 0x01) {
                  _slipHandZeroCount = 0; // reset on any worn confirmation
                  _isWearing = true;
                }
              }
              notifyListeners();
            }

            switch (type) {
              case 0x01: // HRV
                if (val > 0 && val < 250) {
                  _hrv = val;
                  _markResult(0x01);
                }
                break;
              case 0x02: // HR
                if (val > 30 && val < 220) { _heartRate = val; _calcAge(); _markResult(0x02); }
                break;
              case 0x03: // SpO2
                if (val > 60 && val <= 100) { _spo2 = val; _markResult(0x03); }
                break;
              case 0x04: // Temperature — 2-byte little-endian like 0x09
                // d[3] alone is wrong (max 255 → 25.5°C)
                // Correct: combine d[3] + d[4] if available
                double t04;
                if (d.length >= 5) {
                  final raw = (d[3] & 0xff) | ((d[4] & 0xff) << 8);
                  t04 = raw / 10.0;
                } else {
                  // fallback: single byte with band calibration offset
                  t04 = (d[3] & 0xff) + 33.0;
                }
                if (t04 > 34.0 && t04 < 42.0) {
                  _temperature = (t04 * 10).roundToDouble() / 10;
                  _markResult(0x04);
                }
                break;
              case 0x05: // Stress
                if (val > 0 && val <= 100) { _stressLevel = val; _markResult(0x05); }
                break;
            }
          }
          break;
      }
      // Step 3: detect wearing on every data packet
      _detectWearing();

      // Step 4: persist readings to history — ONLY when band is confirmed worn.
      // Steps/calories/distance are saved regardless (pedometer works off-wrist).
      // Vitals (HR, SpO2, HRV, temp, BP, stress) require skin contact to be valid.
      final hist = VitalHistoryService.instance;
      if (_steps > 0)       hist.record('steps',          _steps.toDouble());
      if (_calories > 0)    hist.record('calories',       _calories);
      if (_distance > 0)    hist.record('distance',       _distance);
      if (_isWearing) {
        if (_heartRate > 0)   hist.record('heart_rate',     _heartRate.toDouble());
        if (_spo2 > 0)        hist.record('spo2',           _spo2.toDouble());
        if (_hrv > 0)         hist.record('hrv',            _hrv.toDouble());
        if (_temperature > 0) hist.record('temperature',    _temperature);
        if (_stressLevel > 0) hist.record('stress',         _stressLevel.toDouble());
        if (_bpSystolic > 0)  hist.record('blood_pressure', _bpSystolic.toDouble());
        if (_bpDiastolic > 0) hist.record('bp_diastolic',   _bpDiastolic.toDouble());
      }

      notifyListeners();
    } catch (_) {}
  }

  int _le4(List<int> d, int i) =>
      (d[i] & 0xff) | ((d[i+1] & 0xff) << 8) |
      ((d[i+2] & 0xff) << 16) | ((d[i+3] & 0xff) << 24);

  void _calcAge() {
    int adj = 0;
    if (_heartRate >= 55 && _heartRate <= 70) adj -= 4;
    else if (_heartRate > 80) adj += 3;
    if (_spo2 >= 98) adj -= 2;
    else if (_spo2 < 94 && _spo2 > 0) adj += 5;
    if (_hrv >= 40) adj -= 3;
    if (_steps >= 10000) adj -= 3;
    else if (_steps >= 7000) adj -= 1;
    _vitalAge = (34 + adj).clamp(20, 65);
  }

  // ─────────────────────────────────────────────────────
  //  SLEEP ASSEMBLY
  //  Raw per-interval quality samples collected from 0x53
  //  packets. Key = epoch-minute, value = (quality, unitMin).
  // ─────────────────────────────────────────────────────
  final Map<int, (int, int)> _sleepSamples = {};

  // Stage classification now lives in SleepAnalyzer, which detects
  // whether the band is sending ordinal stage codes or movement
  // magnitudes and classifies accordingly. The old fixed thresholds
  // (_deepMax=3 / _lightMax=40) assumed magnitude always, which made
  // ordinal nights come out ~95% "deep".
  //
  // Last night's raw dump, kept for calibration against JCVital.
  SleepDebugReport? _lastSleepDebug;
  SleepDebugReport? get lastSleepDebug => _lastSleepDebug;

  void _rebuildSleepFromSamples() {
    if (_sleepSamples.isEmpty) return;

    // Drop samples older than 7 days to bound memory
    final weekAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch ~/ 60000;
    _sleepSamples.removeWhere((k, _) => k < weekAgo);
    if (_sleepSamples.isEmpty) return;

    // Group samples into "nights": a sample belongs to the night of
    // the calendar date 12h before it (22:00 Jan 5 and 06:30 Jan 6
    // both map to night "Jan 5").
    final Map<int, List<MapEntry<int, (int, int)>>> nights = {};
    for (final e in _sleepSamples.entries) {
      final t = DateTime.fromMillisecondsSinceEpoch(e.key * 60000);
      final shifted = t.subtract(const Duration(hours: 12));
      final nightKey =
          DateTime(shifted.year, shifted.month, shifted.day)
              .millisecondsSinceEpoch;
      nights.putIfAbsent(nightKey, () => []).add(e);
    }

    // Build BMHSleepData for the most recent night with enough data
    final sortedNights = nights.keys.toList()..sort();
    for (final nk in sortedNights.reversed) {
      final samples = nights[nk]!..sort((a, b) => a.key.compareTo(b.key));

      // Hand the raw samples to SleepAnalyzer, which picks the right
      // interpretation and applies physiological guard rails.
      final analyzed = SleepAnalyzer.analyze([
        for (final e in samples)
          SleepSample(
            DateTime.fromMillisecondsSinceEpoch(e.key * 60000),
            e.value.$1,
            e.value.$2),
      ]);
      _lastSleepDebug = SleepAnalyzer.debug([
        for (final e in samples)
          SleepSample(
            DateTime.fromMillisecondsSinceEpoch(e.key * 60000),
            e.value.$1,
            e.value.$2),
      ]);

      final deep  = analyzed.deepMinutes;
      final light = analyzed.lightMinutes;
      final awake = analyzed.awakeMinutes;
      final total = analyzed.asleepMinutes; // asleep (excludes awake)
      // Valid night: 30 min – 16 h of tracked time
      if (total < 30 || total + awake > 960) continue;

      final endTime =
          DateTime.fromMillisecondsSinceEpoch(samples.last.key * 60000)
              .add(Duration(minutes: samples.last.value.$2));

      final isNew = _lastSleep == null ||
          _lastSleep!.date != endTime ||
          _lastSleep!.totalMinutes != total;
      _lastSleep = BMHSleepData(
        totalMinutes: total,
        deepMinutes:  deep,
        lightMinutes: light,
        remMinutes:   0, // band does not report REM in 0x53
        awakeMinutes: awake,
        quality: SleepAnalyzer.quality(total),
        date: endTime);

      if (isNew) {
        // recordAt dedupes within 1 min, so repeated syncs are safe
        VitalHistoryService.instance
            .recordAt('sleep', endTime, total / 60.0);
        notifyListeners();
      }
      break; // only the most recent valid night drives the UI
    }
  }

  void _seedSleep() {
    // Wait for real sleep data from band
    // If no data arrives in 10s, show -- (not placeholder)
    // Real sleep data syncs from band after wearing it overnight
    Future.delayed(const Duration(seconds: 10), () {
      if (_lastSleep != null) return; // real data arrived!
      // Don't seed placeholder — show -- until real data comes
      // User will see -- until they sleep with band and sync
      notifyListeners();
    });
  }

  // Superseded by SleepAnalyzer.quality() — kept for compatibility.
  // ignore: unused_element
  String _sleepQ(int m) {
    if (m >= 480) return 'Excellent';
    if (m >= 420) return 'Good';
    if (m >= 360) return 'Fair';
    return 'Poor';
  }

  // ─────────────────────────────────────────────────────
  //  DISCONNECT
  // ─────────────────────────────────────────────────────
  Future<void> disconnectDevice(BMHDeviceType type) async {
    if (type != BMHDeviceType.bioScale) {
      _manualDisconnect = true;
    VitalCache.instance.clearAll(); // don't show old readings after unpair // user chose this — stop all auto-reconnect
      // Also disable launch auto-reconnect (re-enabled on next connect)
      SharedPreferences.getInstance()
          .then((p) => p.setBool(_kAutoRc, false));
    }
    _reconnectCount = 0;
    _reconnectTimer?.cancel();
    try {
      if (type != BMHDeviceType.bioScale) {
        _stopTimers();
        _notifySub?.cancel();
        _connStateSub?.cancel();
        await _connectedBand?.device.disconnect();
        _connectedBand = null; _writeChar = null;
        _heartRate = 0; _spo2 = 0; _temperature = 0;
        _steps = 0; _battery = 0; _hrv = 0;
        _stressLevel = 0; _bpSystolic = 0; _bpDiastolic = 0; _bpSysHist.clear(); _bpDiaHist.clear();
        _calories = 0; _distance = 0; _exerciseMin = 0;
        _isWearing          = false;
        _wearAsked          = false;
        _wearScore          = 0;
        _wearProbeReceived  = false; // must get hardware confirmation on next connect
        _slipHandZeroCount  = 0;     // reset debounce counter on disconnect
        _lastHr             = 0;
        _hrChangeCount      = 0;
        _noChangeCount      = 0;
        _lastStepCheck      = 0;
        _stepsMoving        = false;
        _isReconnecting     = false;
        _measurementInProgress.clear(); // no measurements in flight after disconnect
      } else {
        await _connectedScale?.device.disconnect();
        _connectedScale = null;
      }
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _scanSub?.cancel(); _notifySub?.cancel();
    _connStateSub?.cancel(); _stopTimers();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}
