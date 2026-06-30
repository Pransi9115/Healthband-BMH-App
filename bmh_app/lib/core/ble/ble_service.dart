import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../health/vital_history_service.dart';

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
  int    _bpSystolic  = 0;
  int    _bpDiastolic = 0;
  int    _stepGoal    = 5000;
  int    _vitalAge    = 0;
  BMHSleepData? _lastSleep;

  // Keep the write characteristic alive — this is what sends commands
  BluetoothCharacteristic? _writeChar;
  // Keep the last connected device for reconnect
  BMHBleDevice? _lastBandDev;

  bool _isReconnecting = false;

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
  int    get heartRate   => _heartRate;
  int    get spo2        => _spo2;
  double get temperature => _temperature;
  int    get steps       => _steps;
  int    get battery     => _battery;
  int    get hrv         => _hrv;
  int    get stressLevel => _stressLevel;
  double get calories    => _calories;
  double get distance    => _distance;
  int    get exerciseMin => _exerciseMin;
  int    get stepGoal    => _stepGoal;
  int    get vitalAge    => _vitalAge;
  BMHSleepData? get lastSleep => _lastSleep;
  int get bpSystolic  => _bpSystolic;
  int get bpDiastolic => _bpDiastolic;
  String get bloodPressure => _bpSystolic > 0
      ? '$_bpSystolic/$_bpDiastolic' : '--/--';
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
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      // Save for auto-reconnect
      if (dev.type != BMHDeviceType.bioScale) _lastBandDev = dev;

      await dev.device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Listen for disconnect — auto-reconnect like SDK (up to 3 times)
      _connStateSub?.cancel();
      _connStateSub = dev.device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          if (dev.type != BMHDeviceType.bioScale) {
            _connectedBand = null;
            _writeChar = null;
            _stopTimers();
            if (_reconnectCount < 3 && _lastBandDev != null) {
              // Show reconnecting state — not fully disconnected yet
              _isReconnecting = true;
              notifyListeners();
              _reconnectCount++;
              _reconnectTimer?.cancel();
              _reconnectTimer = Timer(
                const Duration(seconds: 2), () async {
                  final ok = await connectDevice(_lastBandDev!);
                  if (!ok) {
                    _isReconnecting = false;
                    notifyListeners();
                  }
                });
            } else {
              _isReconnecting = false;
              notifyListeners();
            }
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
    // 6. Get blood oxygen
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
  Future<void> _fetchHistory(int cmd) async {
    if (!isBandConnected || _writeChar == null) return;
    _historyPending[cmd] = true;
    await _write(_cmd([cmd, _MODE_START]));
  }

  Future<void> _continueHistory(int cmd) async {
    if (!isBandConnected || _writeChar == null) return;
    if (_historyPending[cmd] != true) return;
    await _delay(200);
    await _write(_cmd([cmd, _MODE_CONTINUE]));
  }

  void _endHistory(int cmd) => _historyPending[cmd] = false;

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
    const Duration(seconds: 4), (_) async {
    if (!isBandConnected || _writeChar == null) return;

    // existing — keep real-time step+HR+temp stream alive
    await _write(_cmd([_REAL_STEP, 0x01, 0x01]));
    // Send twice — band sometimes needs a second ping to resume stream
    await _delay(200);
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
          case 4: // Temperature — start measurement
            await _write(_cmd([_MEASURE, 0x04, 0x01]));
            break;
          case 5: // Temperature — stop + read result
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

  // Called once after band connects — triggers UI to ask user
  void _startWearDetection() {
    _isWearing      = false;
    _wearAsked      = false;
    _wearScore      = 50; // grace period — starts uncertain
    _lastHr         = 0;
    _hrChangeCount  = 0;
    _noChangeCount  = 0;
    _lastStepCheck  = 0;
    _stepsMoving    = false;
    _lastUpdate     = DateTime.now();
    notifyListeners();
  }

  // Manual confirmation by user (popup)
  void confirmWearing(bool wearing) {
    _isWearing = wearing;
    _wearAsked = true;
    notifyListeners();
  }

  // ── SMART CONFIDENCE SCORE SYSTEM ───────────────────
  // Combines 4 signals like a "virtual sensor"
  // Score > 60 = Wearing, 30-60 = Uncertain, < 30 = Not Wearing
  void _detectWearing() {
    final now = DateTime.now();
    int score = 0;

    // ── SIGNAL 1: Time consistency (20 pts) ──────────────
    final timeDiff = now.difference(_lastUpdate).inSeconds;
    if (timeDiff <= 10) score += 20;
    _lastUpdate = now;

    // ── SIGNAL 2: Heart Rate validity (40 pts) ────────────
    // Valid HR range = band is on skin (sensor works only with contact)
    if (_heartRate >= 40 && _heartRate <= 200) {
      score += 25; // valid HR = strong wear signal

      // HR fluctuation is a bonus — but NOT penalise still HR
      // (user may be sitting still — HR stable is normal)
      if (_heartRate != _lastHr) {
        _hrChangeCount++;
        _noChangeCount = 0;
        if (_hrChangeCount >= 2) score += 15; // changing HR = confirmed real
      } else {
        _noChangeCount++;
        _hrChangeCount = 0;
        // Only penalise if COMPLETELY frozen for very long (20+ ticks = ~3 min)
        if (_noChangeCount > 20) score -= 5;
      }
    }
    _lastHr = _heartRate;

    // ── SIGNAL 3: Movement / Steps (20 pts) ──────────────
    if (_steps > _lastStepCheck) {
      _stepsMoving = true;
      score += 20;
    } else if (_stepsMoving) {
      score += 10; // recently moved — still likely wearing
    }
    _lastStepCheck = _steps;

    // ── SIGNAL 4: SpO2 validity (25 pts) ─────────────────
    // SpO2 sensor REQUIRES skin contact — valid reading = definitely wearing
    if (_spo2 >= 92 && _spo2 <= 100) {
      score += 25; // strongest wear signal — impossible without contact
    } else if (_spo2 > 0 && _spo2 < 92) {
      score += 8;
    }

    // ── SIGNAL 5: Temperature validity (10 pts) ──────────
    // Body temp range — also requires skin contact
    if (_temperature >= 34.0 && _temperature <= 40.0) {
      score += 10;
    }

    // ── FINAL DECISION ────────────────────────────────────
    _wearScore = score.clamp(0, 100);

    // Lowered threshold: 50 (was 60) — more lenient for still users
    if (_wearScore >= 50) {
      _isWearing = true;
      if (!_wearAsked) _wearAsked = true;
    } else if (_wearScore < 25) {
      // Only mark not wearing if score is very low
      _isWearing = false;
    }
    // 25–50 = uncertain — keep last known state
  }

  void _stopTimers() {
    _keepAliveTimer?.cancel(); _refreshTimer?.cancel();
    _measurementTimer?.cancel();
    _keepAliveTimer = null; _refreshTimer = null;
    _measurementTimer = null;
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

  Future<void> startMeasurement(int type) async {
    if (type == 0x03) {
      // SDK: GetBloodOxygen(0) = [0x60, 0x00] reads latest stored SpO2
      await _write(_cmd([_BLOOD_O2, 0x00]));
      // Also send auto SpO2 command 0x66
      await Future.delayed(const Duration(milliseconds: 300));
      await _write(_cmd([0x66, 0x00]));
    } else {
      await _write(_cmd([_MEASURE, type, 0x01]));
    }
  }

  Future<void> stopMeasurement(int type) async {
    if (type == 0x03) return; // SpO2 stops automatically
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
            if (h >= 40 && h <= 200) { _heartRate = h; _calcAge(); }

            if (d.length >= 24) {
              final raw = (d[22] & 0xff) + (d[23] & 0xff) * 256;
              final t = raw / 10.0;
              if (t > 30.0 && t < 42.0) _temperature = t;
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
        case 0x53: // Sleep data from band
          // SDK: getSleepData response
          // d[1..2] = total sleep minutes
          // d[3..4] = deep sleep minutes  
          // d[5..6] = light sleep minutes
          // d[7]    = REM count (x10 = minutes)
          // d[8]    = awake count (x5 = minutes)
          if (d.length >= 6) {
            final total = ((d[1] & 0xff) << 8) | (d[2] & 0xff);
            final deep  = ((d[3] & 0xff) << 8) | (d[4] & 0xff);
            final light = ((d[5] & 0xff) << 8) | (d[6] & 0xff);
            // Valid sleep: 30 min to 12 hours
            if (total >= 30 && total <= 720) {
              final rem   = d.length > 7 ? (d[7] & 0xff) * 10 : 0;
              final awake = d.length > 8 ? (d[8] & 0xff) * 5  : 0;
              _lastSleep = BMHSleepData(
                totalMinutes: total,
                deepMinutes:  deep.clamp(0, total),
                lightMinutes: light.clamp(0, total),
                remMinutes:   rem.clamp(0, total),
                awakeMinutes: awake.clamp(0, total),
                quality: _sleepQ(total),
                date: DateTime.now());
              // Record sleep hours in history
              VitalHistoryService.instance.record(
                'sleep', total / 60.0);
              notifyListeners();
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
                  _bpSystolic = sys; _bpDiastolic = dia;
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
                if (sys > 60 && sys < 200 && dia > 40 && dia < 130) { _bpSystolic = sys; _bpDiastolic = dia; }
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
                  _temperature = t;
                  final dtT = _parseDate(d, base + 3);
                  if (dtT != null) histT.recordAt('temperature', dtT, t);
                  else histT.record('temperature', t);
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
            if (d.length >= 3) {
              final slipHand = d[2] & 0xff;
              if (slipHand == 0x00 && type != 0x00) {
                _isWearing = false; // band not on wrist!
              } else if (slipHand == 0x01) {
                _isWearing = true;  // band confirmed on wrist
              }
            }

            switch (type) {
              case 0x01: // HRV
                if (val > 0 && val < 250) _hrv = val;
                break;
              case 0x02: // HR
                if (val > 30 && val < 220) { _heartRate = val; _calcAge(); }
                break;
              case 0x03: // SpO2
                if (val > 60 && val <= 100) _spo2 = val;
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
                if (t04 > 34.0 && t04 < 42.0) _temperature = t04;
                break;
              case 0x05: // Stress
                if (val > 0 && val <= 100) _stressLevel = val;
                break;
            }
          }
          break;
      }
      // Step 3: detect wearing on every data packet
      _detectWearing();

      // Step 4: persist readings to history (throttled inside service)
      final hist = VitalHistoryService.instance;
      if (_heartRate > 0)   hist.record('heart_rate',     _heartRate.toDouble());
      if (_spo2 > 0)        hist.record('spo2',           _spo2.toDouble());
      if (_hrv > 0)         hist.record('hrv',            _hrv.toDouble());
      if (_temperature > 0) hist.record('temperature',    _temperature);
      if (_steps > 0)       hist.record('steps',          _steps.toDouble());
      if (_calories > 0)    hist.record('calories',       _calories);
      if (_distance > 0)    hist.record('distance',       _distance);
      if (_stressLevel > 0) hist.record('stress',         _stressLevel.toDouble());
      if (_bpSystolic > 0)  hist.record('blood_pressure', _bpSystolic.toDouble());
      if (_bpDiastolic > 0) hist.record('bp_diastolic',   _bpDiastolic.toDouble());

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
    _reconnectCount = 99; // stop auto-reconnect
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
        _stressLevel = 0; _bpSystolic = 0; _bpDiastolic = 0;
        _calories = 0; _distance = 0; _exerciseMin = 0;
        _isWearing      = false;
        _wearAsked      = false;
        _wearScore      = 50; // grace period — starts uncertain
        _lastHr         = 0;
        _hrChangeCount  = 0;
        _noChangeCount  = 0;
        _lastStepCheck  = 0;
        _stepsMoving    = false;
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
