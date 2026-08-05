// ─────────────────────────────────────────────────────────
//  HEALTH SHARING
//
//  One job: push what the band measures out to the phone's health
//  store, so the patient's other apps can read it. HealthKit on iOS,
//  Health Connect on Android, same API from the app's side.
//
//  WHY THIS EXISTS SEPARATELY FROM HealthService
//  HealthService grew up as an Android-only, button-driven sync. It
//  wrote to Health Connect and nothing else — on iOS it asked for
//  permission and then never wrote a single sample. This service owns
//  sharing on both platforms, runs automatically, and remembers what
//  it has already sent.
//
//  DEDUPLICATION
//  Every metric carries a high-water mark: the timestamp of the last
//  sample written. Nothing at or before that mark is ever written
//  again. Without it, an app-foreground sync three times an hour
//  would put three identical resting heart rates into Apple Health,
//  and the patient's other apps would average nonsense.
//
//  WHAT IS NEVER SHARED
//  Diet, medication, supplements, biomarkers and lab results stay in
//  BMH. This service moves band-measured vitals only. Sharing a
//  medication list into a general health store is a different consent
//  conversation and is deliberately out of scope.
// ─────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/ble_service.dart';
import 'vital_history_service.dart';

/// One shareable metric, and how each platform names it.
class ShareMetric {
  final String key;          // our own id, also the VitalHistory key
  final String label;
  final String unitLabel;

  /// Null when the platform has no equivalent type.
  final HealthDataType? ios;
  final HealthDataType? android;

  const ShareMetric({
    required this.key,
    required this.label,
    required this.unitLabel,
    this.ios,
    this.android,
  });

  HealthDataType? get type => Platform.isIOS ? ios : android;
  bool get supported => type != null || key == 'blood_pressure';
}

/// Blood pressure is handled specially — see [HealthShareService._writeBp].
const List<ShareMetric> kShareMetrics = [
  ShareMetric(
    key: 'heart_rate', label: 'Heart rate', unitLabel: 'bpm',
    ios: HealthDataType.HEART_RATE,
    android: HealthDataType.HEART_RATE),
  ShareMetric(
    key: 'spo2', label: 'Blood oxygen', unitLabel: '%',
    ios: HealthDataType.BLOOD_OXYGEN,
    android: HealthDataType.BLOOD_OXYGEN),
  ShareMetric(
    key: 'blood_pressure', label: 'Blood pressure', unitLabel: 'mmHg'),
  ShareMetric(
    key: 'temperature', label: 'Body temperature', unitLabel: '°C',
    ios: HealthDataType.BODY_TEMPERATURE,
    android: HealthDataType.BODY_TEMPERATURE),
  // HealthKit only accepts SDNN. Health Connect records RMSSD. Writing
  // the wrong one fails silently, which is why these differ.
  ShareMetric(
    key: 'hrv', label: 'Heart rate variability', unitLabel: 'ms',
    ios: HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    android: HealthDataType.HEART_RATE_VARIABILITY_RMSSD),
  ShareMetric(
    key: 'steps', label: 'Steps', unitLabel: 'steps',
    ios: HealthDataType.STEPS,
    android: HealthDataType.STEPS),
  ShareMetric(
    key: 'calories', label: 'Active energy', unitLabel: 'kcal',
    ios: HealthDataType.ACTIVE_ENERGY_BURNED,
    android: HealthDataType.ACTIVE_ENERGY_BURNED),
  ShareMetric(
    key: 'distance', label: 'Distance', unitLabel: 'm',
    ios: HealthDataType.DISTANCE_WALKING_RUNNING,
    android: HealthDataType.DISTANCE_DELTA),
  ShareMetric(
    key: 'sleep', label: 'Sleep', unitLabel: 'min',
    ios: HealthDataType.SLEEP_ASLEEP,
    android: HealthDataType.SLEEP_ASLEEP),
];

/// Outcome of one push.
class ShareResult {
  final bool ok;
  final int written;
  final int skipped;      // already sent, or nothing new to send
  final String? error;

  const ShareResult({
    required this.ok,
    this.written = 0,
    this.skipped = 0,
    this.error,
  });

  static const idle = ShareResult(ok: true);
}

/// What the phone's health store came back with when we asked for
/// gaps the band could not fill.
class PulledData {
  final int? steps;
  final int? sleepMinutes;
  final String? stepsSource;
  final String? sleepSource;

  const PulledData({
    this.steps, this.sleepMinutes, this.stepsSource, this.sleepSource});

  bool get isEmpty => steps == null && sleepMinutes == null;
}

class HealthShareService extends ChangeNotifier with WidgetsBindingObserver {
  HealthShareService._();
  static final HealthShareService instance = HealthShareService._();

  static final Health _health = Health();
  static bool _configured = false;

  final _ble = BleService.instance;
  SharedPreferences? _prefs;

  static const _kEnabled   = 'hs_enabled';
  static const _kMetric    = 'hs_metric_';       // + metric key
  static const _kMark      = 'hs_mark_';         // + metric key, epoch ms
  static const _kLastSync  = 'hs_last_sync';
  static const _kPullGaps  = 'hs_pull_gaps';
  static const _kBackfill  = 'hs_backfilled_at';

  /// Never auto-push more often than this. Foregrounding the app four
  /// times in ten minutes should not produce four identical samples.
  static const _minAutoGap = Duration(minutes: 15);

  bool _enabled = false;
  bool _pullGaps = true;
  bool _busy = false;
  bool _ready = false;
  bool _permitted = false;
  bool _storeAvailable = false;

  final Map<String, bool> _metricOn = {};
  DateTime? _lastSync;
  DateTime? _lastBackfill;
  ShareResult _last = ShareResult.idle;
  PulledData _pulled = const PulledData();
  bool _wasConnected = false;

  // ── PUBLIC STATE ────────────────────────────────────────
  bool get isReady => _ready;
  bool get isEnabled => _enabled;
  bool get isBusy => _busy;
  bool get hasPermission => _permitted;
  bool get isStoreAvailable => _storeAvailable;
  bool get pullGaps => _pullGaps;
  DateTime? get lastSync => _lastSync;
  DateTime? get lastBackfill => _lastBackfill;
  ShareResult get lastResult => _last;
  PulledData get pulled => _pulled;

  bool metricEnabled(String key) => _metricOn[key] ?? true;

  /// "Apple Health" / "Health Connect" — used throughout the UI so the
  /// copy never says the wrong product name.
  static String get storeName =>
      Platform.isIOS ? 'Apple Health' : 'Health Connect';

  List<ShareMetric> get metrics =>
      kShareMetrics.where((m) => m.supported).toList();

  // ── LIFECYCLE ───────────────────────────────────────────
  Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();

    _enabled = _prefs!.getBool(_kEnabled) ?? false;
    _pullGaps = _prefs!.getBool(_kPullGaps) ?? true;
    for (final m in kShareMetrics) {
      _metricOn[m.key] = _prefs!.getBool('$_kMetric${m.key}') ?? true;
    }
    final ls = _prefs!.getInt(_kLastSync);
    if (ls != null) _lastSync = DateTime.fromMillisecondsSinceEpoch(ls);
    final bf = _prefs!.getInt(_kBackfill);
    if (bf != null) _lastBackfill = DateTime.fromMillisecondsSinceEpoch(bf);

    _ready = true;

    // Watching the band lets us push when a session ends, which is the
    // moment the day's numbers are actually final.
    _wasConnected = _ble.isBandConnected;
    _ble.addListener(_onBle);
    WidgetsBinding.instance.addObserver(this);

    if (_enabled) {
      await refreshAvailability();
      unawaited(_autoSync(reason: 'startup'));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ble.removeListener(_onBle);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App came back to the foreground — a good moment to catch up,
  /// throttled so it cannot spam the store.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_enabled) return;
    unawaited(_autoSync(reason: 'foreground'));
  }

  /// Band disconnected — the session just ended, so push what it left
  /// behind. Also catches up periodically while it stays connected.
  void _onBle() {
    final now = _ble.isBandConnected;
    final ended = _wasConnected && !now;
    _wasConnected = now;
    if (!_enabled) return;
    if (ended) {
      unawaited(_autoSync(reason: 'session end', force: true));
    } else if (now) {
      unawaited(_autoSync(reason: 'connected'));
    }
  }

  Future<void> _autoSync({required String reason, bool force = false}) async {
    if (!_enabled || _busy) return;
    if (!force && _lastSync != null &&
        DateTime.now().difference(_lastSync!) < _minAutoGap) {
      return;
    }
    debugPrint('[HealthShare] auto sync ($reason)');
    await pushNow(silent: true);
  }

  // ── SETTINGS ────────────────────────────────────────────
  Future<bool> setEnabled(bool on) async {
    if (on) {
      await refreshAvailability();
      final granted = await requestPermission();
      if (!granted) {
        notifyListeners();
        return false;
      }
    }
    _enabled = on;
    await _prefs?.setBool(_kEnabled, on);
    notifyListeners();
    if (on) await pushNow(silent: true);
    return on;
  }

  Future<void> setMetric(String key, bool on) async {
    _metricOn[key] = on;
    await _prefs?.setBool('$_kMetric$key', on);
    notifyListeners();
  }

  Future<void> setPullGaps(bool on) async {
    _pullGaps = on;
    await _prefs?.setBool(_kPullGaps, on);
    notifyListeners();
    if (on) unawaited(pullFromOtherApps());
  }

  // ── PERMISSIONS ─────────────────────────────────────────
  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  List<HealthDataType> get _activeTypes {
    final out = <HealthDataType>[];
    for (final m in kShareMetrics) {
      if (m.key == 'blood_pressure') {
        out.add(HealthDataType.BLOOD_PRESSURE_SYSTOLIC);
        out.add(HealthDataType.BLOOD_PRESSURE_DIASTOLIC);
        continue;
      }
      final t = m.type;
      if (t != null) out.add(t);
    }
    return out;
  }

  /// Is there a health store to write to at all? On Android this is
  /// false when Health Connect is missing or needs updating.
  Future<void> refreshAvailability() async {
    try {
      await _ensureConfigured();
      if (Platform.isIOS) {
        _storeAvailable = true;
      } else if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        _storeAvailable = status == HealthConnectSdkStatus.sdkAvailable;
      } else {
        _storeAvailable = false;
      }
      _permitted = await _checkPermission();
    } catch (e) {
      debugPrint('[HealthShare] availability check failed: $e');
      _storeAvailable = false;
      _permitted = false;
    }
    notifyListeners();
  }

  Future<bool> _checkPermission() async {
    try {
      final types = _activeTypes;
      final has = await _health.hasPermissions(
        types,
        permissions: types.map((_) => HealthDataAccess.READ_WRITE).toList());
      // iOS deliberately never reveals read permission, so hasPermissions
      // can return null there. Treat null as "ask and find out".
      return has ?? false;
    } catch (e) {
      debugPrint('[HealthShare] permission check failed: $e');
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      await _ensureConfigured();
      final types = _activeTypes;
      final granted = await _health.requestAuthorization(
        types,
        permissions: types.map((_) => HealthDataAccess.READ_WRITE).toList());
      _permitted = granted;
      notifyListeners();
      return granted;
    } catch (e) {
      debugPrint('[HealthShare] permission request failed: $e');
      _permitted = false;
      notifyListeners();
      return false;
    }
  }

  /// Android only — sends the user to install or update Health Connect.
  Future<void> openStoreInstall() async {
    if (!Platform.isAndroid) return;
    try {
      await _ensureConfigured();
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('[HealthShare] install prompt failed: $e');
    }
  }

  // ── HIGH-WATER MARKS ────────────────────────────────────
  DateTime? _markFor(String key) {
    final ms = _prefs?.getInt('$_kMark$key');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _setMark(String key, DateTime at) async =>
      _prefs?.setInt('$_kMark$key', at.millisecondsSinceEpoch);

  bool _alreadySent(String key, DateTime at) {
    final mark = _markFor(key);
    return mark != null && !at.isAfter(mark);
  }

  /// Clears every mark, so the next push re-sends everything. Exposed
  /// for the "resend everything" escape hatch in settings.
  Future<void> resetMarks() async {
    for (final m in kShareMetrics) {
      await _prefs?.remove('$_kMark${m.key}');
    }
    notifyListeners();
  }

  // ── THE PUSH ────────────────────────────────────────────
  /// Writes the band's current readings out to the health store.
  Future<ShareResult> pushNow({bool silent = false}) async {
    if (!_enabled) {
      return const ShareResult(ok: false, error: 'Sharing is off');
    }
    if (_busy) return _last;

    _busy = true;
    if (!silent) notifyListeners();

    try {
      await _ensureConfigured();
      await refreshAvailability();

      if (!_storeAvailable) {
        return _finish(ShareResult(
          ok: false,
          error: Platform.isAndroid
            ? 'Health Connect is not installed or needs an update'
            : '${storeName} is unavailable on this device'));
      }
      if (!_permitted) {
        final granted = await requestPermission();
        if (!granted) {
          return _finish(const ShareResult(
            ok: false, error: 'Permission not granted'));
        }
      }

      final now = DateTime.now();
      final from = now.subtract(const Duration(seconds: 30));
      var written = 0;
      var skipped = 0;

      Future<void> push(String key, double value, {DateTime? start}) async {
        if (!metricEnabled(key)) return;
        if (value <= 0) return;
        if (_alreadySent(key, now)) { skipped++; return; }
        final ok = await _write(key, value, start: start ?? from, end: now);
        if (ok) {
          written++;
          await _setMark(key, now);
        }
      }

      await push('heart_rate', _ble.heartRate.toDouble());
      await push('spo2', _ble.spo2.toDouble());
      await push('temperature', _ble.temperature);
      await push('hrv', _ble.hrv.toDouble());
      await push('steps', _ble.steps.toDouble(),
        start: DateTime(now.year, now.month, now.day));
      await push('calories', _ble.calories,
        start: DateTime(now.year, now.month, now.day));
      await push('distance', _ble.distance * 1000, // km → m
        start: DateTime(now.year, now.month, now.day));

      // Blood pressure is one reading, not two numbers.
      if (metricEnabled('blood_pressure') &&
          _ble.bpSystolic > 0 && _ble.bpDiastolic > 0) {
        if (_alreadySent('blood_pressure', now)) {
          skipped++;
        } else {
          final ok = await _writeBp(
            _ble.bpSystolic, _ble.bpDiastolic, from, now);
          if (ok) {
            written++;
            await _setMark('blood_pressure', now);
          }
        }
      }

      // Sleep is written across the window it actually covered, not as
      // a number stamped on this instant.
      final sleep = _ble.lastSleep;
      if (metricEnabled('sleep') && sleep != null && sleep.totalMinutes > 0) {
        final end = sleep.date;
        final start = end.subtract(Duration(minutes: sleep.totalMinutes));
        if (_alreadySent('sleep', end)) {
          skipped++;
        } else {
          final ok = await _write('sleep', sleep.totalMinutes.toDouble(),
            start: start, end: end);
          if (ok) {
            written++;
            await _setMark('sleep', end);
          }
        }
      }

      _lastSync = now;
      await _prefs?.setInt(_kLastSync, now.millisecondsSinceEpoch);

      if (_pullGaps) unawaited(pullFromOtherApps());

      return _finish(ShareResult(
        ok: true, written: written, skipped: skipped));
    } catch (e) {
      debugPrint('[HealthShare] push failed: $e');
      return _finish(ShareResult(ok: false, error: '$e'));
    }
  }

  ShareResult _finish(ShareResult r) {
    _last = r;
    _busy = false;
    notifyListeners();
    return r;
  }

  Future<bool> _write(String key, double value,
      {required DateTime start, required DateTime end}) async {
    ShareMetric? spec;
    for (final m in kShareMetrics) {
      if (m.key == key) { spec = m; break; }
    }
    final type = spec?.type;
    if (type == null) return false;
    try {
      return await _health.writeHealthData(
        value: value, type: type, startTime: start, endTime: end);
    } catch (e) {
      debugPrint('[HealthShare] write $key failed: $e');
      return false;
    }
  }

  /// HealthKit needs systolic and diastolic as one correlated sample,
  /// or Apple Health shows two unrelated numbers instead of "120/80".
  /// Health Connect is happy either way, so both go through here.
  Future<bool> _writeBp(
      int systolic, int diastolic, DateTime start, DateTime end) async {
    try {
      return await _health.writeBloodPressure(
        systolic: systolic,
        diastolic: diastolic,
        startTime: start,
        endTime: end);
    } catch (e) {
      debugPrint('[HealthShare] BP correlation write failed, '
          'falling back to separate samples: $e');
      try {
        final a = await _health.writeHealthData(
          value: systolic.toDouble(),
          type: HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
          startTime: start, endTime: end);
        final b = await _health.writeHealthData(
          value: diastolic.toDouble(),
          type: HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
          startTime: start, endTime: end);
        return a && b;
      } catch (e2) {
        debugPrint('[HealthShare] BP fallback failed: $e2');
        return false;
      }
    }
  }

  // ── THE PULL ────────────────────────────────────────────
  /// Fills gaps the band could not. If the band recorded no steps
  /// today — left on the charger, worn late — the phone's own step
  /// counter or another app usually did. This never overwrites band
  /// data; it only fills a zero.
  Future<PulledData> pullFromOtherApps() async {
    if (!_pullGaps || !_enabled) return const PulledData();
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      int? steps;
      String? stepsSource;
      if (_ble.steps <= 0) {
        try {
          final total = await _health.getTotalStepsInInterval(midnight, now);
          if (total != null && total > 0) {
            steps = total;
            stepsSource = storeName;
          }
        } catch (e) {
          debugPrint('[HealthShare] step pull failed: $e');
        }
      }

      int? sleepMinutes;
      String? sleepSource;
      if ((_ble.lastSleep?.totalMinutes ?? 0) <= 0) {
        try {
          final points = await _health.getHealthDataFromTypes(
            types: [HealthDataType.SLEEP_ASLEEP],
            startTime: now.subtract(const Duration(hours: 36)),
            endTime: now);
          var minutes = 0;
          String? src;
          for (final p in points) {
            if (_isOurs(p.sourceName)) continue;
            minutes += p.dateTo.difference(p.dateFrom).inMinutes;
            src ??= p.sourceName;
          }
          if (minutes > 0) {
            sleepMinutes = minutes;
            sleepSource = (src == null || src.isEmpty) ? storeName : src;
          }
        } catch (e) {
          debugPrint('[HealthShare] sleep pull failed: $e');
        }
      }

      _pulled = PulledData(
        steps: steps, sleepMinutes: sleepMinutes,
        stepsSource: stepsSource, sleepSource: sleepSource);
      notifyListeners();
      return _pulled;
    } catch (e) {
      debugPrint('[HealthShare] pull failed: $e');
      return const PulledData();
    }
  }

  /// Recognise our own writes so a pull never reads back what we just
  /// wrote and calls it another app's data.
  static bool _isOurs(String source) {
    final s = source.toLowerCase();
    return s.contains('bmh') ||
           s.contains('biomedical') ||
           s.contains('biohealthcare');
  }

  // ── BACKFILL ────────────────────────────────────────────
  /// Pushes stored history out to the health store. Deliberately a
  /// button rather than something that fires on enable — it can write
  /// hundreds of samples and take a while, and nobody wants a toggle
  /// that hangs.
  Future<ShareResult> backfill({int days = 7,
      void Function(int done, int total)? onProgress}) async {
    if (!_enabled) {
      return const ShareResult(ok: false, error: 'Sharing is off');
    }
    if (_busy) return _last;

    _busy = true;
    notifyListeners();

    try {
      await _ensureConfigured();
      if (!_permitted) {
        final granted = await requestPermission();
        if (!granted) {
          return _finish(const ShareResult(
            ok: false, error: 'Permission not granted'));
        }
      }

      final history = VitalHistoryService.instance;
      final since = DateTime.now().subtract(Duration(days: days));

      // Only metrics that make sense as a time series. Steps, calories
      // and distance are running daily totals — replaying them would
      // add the same day's total many times over.
      const keys = ['heart_rate', 'spo2', 'temperature', 'hrv'];

      final work = <MapEntry<String, VitalReading>>[];
      for (final key in keys) {
        if (!metricEnabled(key)) continue;
        for (final r in history.readingsSince(key, since)) {
          if (r.value <= 0) continue;
          if (_alreadySent(key, r.timestamp)) continue;
          work.add(MapEntry(key, r));
        }
      }
      work.sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

      var written = 0;
      final latest = <String, DateTime>{};
      for (var i = 0; i < work.length; i++) {
        final key = work[i].key;
        final r = work[i].value;
        final ok = await _write(key, r.value,
          start: r.timestamp,
          end: r.timestamp.add(const Duration(seconds: 1)));
        if (ok) {
          written++;
          final prev = latest[key];
          if (prev == null || r.timestamp.isAfter(prev)) {
            latest[key] = r.timestamp;
          }
        }
        onProgress?.call(i + 1, work.length);
      }

      // Marks move only after the whole run, so an interrupted backfill
      // resumes rather than silently skipping what it never sent.
      for (final e in latest.entries) {
        await _setMark(e.key, e.value);
      }

      _lastBackfill = DateTime.now();
      await _prefs?.setInt(
        _kBackfill, _lastBackfill!.millisecondsSinceEpoch);

      return _finish(ShareResult(
        ok: true, written: written,
        skipped: work.length - written));
    } catch (e) {
      debugPrint('[HealthShare] backfill failed: $e');
      return _finish(ShareResult(ok: false, error: '$e'));
    }
  }
}
