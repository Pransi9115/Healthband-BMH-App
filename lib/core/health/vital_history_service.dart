import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

// ─────────────────────────────────────────────────────────
//  VITAL READING — one timestamped data point from the band
// ─────────────────────────────────────────────────────────
class VitalReading {
  final DateTime timestamp;
  final double value;

  const VitalReading({required this.timestamp, required this.value});

  Map<String, dynamic> toJson() => {
        't': timestamp.millisecondsSinceEpoch,
        'v': value,
      };

  factory VitalReading.fromJson(Map<String, dynamic> j) => VitalReading(
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
        value: (j['v'] as num).toDouble(),
      );
}

// ─────────────────────────────────────────────────────────
//  VITAL HISTORY SERVICE
//  • Stores readings in SharedPreferences (Hive-ready upgrade path)
//  • Keeps last 90 days of data per vital
//  • Aggregates into Daily / Weekly / Monthly FlSpot lists
// ─────────────────────────────────────────────────────────
class VitalHistoryService extends ChangeNotifier {
  static final VitalHistoryService _i = VitalHistoryService._();
  static VitalHistoryService get instance => _i;
  VitalHistoryService._();

  // In-memory cache: vitalKey → list of readings
  final Map<String, List<VitalReading>> _cache = {};

  // Prefs key prefix
  static const _prefix = 'vh_';

  // Min seconds between saved readings per vital (avoid spam-saving)
  static const _minIntervalSec = 60; // save at most once per minute

  // Track last-save time per vital
  final Map<String, DateTime> _lastSaved = {};

  // Track first-wear date (first time any reading was saved)
  DateTime? _firstWearDate;
  static const _firstWearKey = 'vh_first_wear';

  // ── INIT ─────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // ── ONE-TIME MIGRATION ─────────────────────────────
    // The old 0x53 parser read the record header/date bytes as
    // "total sleep minutes", producing a constant bogus value
    // (e.g. 8.5h) that was persisted here. Purge all sleep
    // readings once so only correctly-parsed data is kept.
    if (!(prefs.getBool('sleep_parser_v2') ?? false)) {
      await prefs.remove('${_prefix}sleep');
      await prefs.setBool('sleep_parser_v2', true);
    }

    // Load first-wear date
    final fw = prefs.getInt(_firstWearKey);
    if (fw != null) {
      _firstWearDate = DateTime.fromMillisecondsSinceEpoch(fw);
    }

    // Load each vital's history
    for (final key in _allKeys) {
      final raw = prefs.getString('$_prefix$key');
      if (raw != null) {
        try {
          final list = (jsonDecode(raw) as List)
              .map((e) => VitalReading.fromJson(e as Map<String, dynamic>))
              .toList();
          _cache[key] = list;
        } catch (_) {
          _cache[key] = [];
        }
      } else {
        _cache[key] = [];
      }
    }
  }

  static const List<String> _allKeys = [
    'heart_rate', 'spo2', 'hrv', 'temperature',
    'blood_pressure', 'bp_diastolic', 'stress',
    'steps', 'calories', 'distance',
    'blood_glucose', 'sleep',
  ];

  // ── RECORD WITH EXACT TIMESTAMP (for band history) ───
  Future<void> recordAt(String key, DateTime timestamp, double value) async {
    if (value <= 0) return;

    // Don't store future timestamps
    if (timestamp.isAfter(DateTime.now())) return;

    _cache.putIfAbsent(key, () => []);

    // Avoid duplicates — check if we already have a reading within 1 min
    final existing = _cache[key]!.any((r) =>
        r.timestamp.difference(timestamp).inSeconds.abs() < 60);
    if (existing) return;

    _cache[key]!.add(VitalReading(timestamp: timestamp, value: value));

    // Sort by timestamp to keep order correct
    _cache[key]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Set first-wear date if this is older than current
    if (_firstWearDate == null || timestamp.isBefore(_firstWearDate!)) {
      _firstWearDate = timestamp;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_firstWearKey, timestamp.millisecondsSinceEpoch);
    }

    // Prune readings older than 90 days
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    _cache[key]!.removeWhere((r) => r.timestamp.isBefore(cutoff));

    await _persist(key);
    notifyListeners();
  }

  // ── RECORD A READING ─────────────────────────────────
  Future<void> record(String key, double value) async {
    if (value <= 0) return;

    final now = DateTime.now();

    // Throttle: don't save more than once per minute per vital
    final last = _lastSaved[key];
    if (last != null &&
        now.difference(last).inSeconds < _minIntervalSec) {
      return;
    }

    _cache.putIfAbsent(key, () => []);
    _cache[key]!.add(VitalReading(timestamp: now, value: value));
    _lastSaved[key] = now;

    // Set first-wear date if not set
    if (_firstWearDate == null) {
      _firstWearDate = now;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_firstWearKey, now.millisecondsSinceEpoch);
    }

    // Prune readings older than 90 days
    final cutoff = now.subtract(const Duration(days: 90));
    _cache[key]!.removeWhere((r) => r.timestamp.isBefore(cutoff));

    await _persist(key);
    notifyListeners();
  }

  Future<void> _persist(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _cache[key] ?? [];
    await prefs.setString(
      '$_prefix$key',
      jsonEncode(list.map((r) => r.toJson()).toList()),
    );
  }

  // ── FIRST WEAR DATE ───────────────────────────────────
  DateTime? get firstWearDate => _firstWearDate;

  bool get hasData => _firstWearDate != null;

  // ── AGGREGATION ───────────────────────────────────────
  // range: 0=Daily, 1=Weekly, 2=Monthly

  List<FlSpot> getSpots(String key, int range) {
    final readings = _cache[key] ?? [];
    if (readings.isEmpty) return [];

    final now = DateTime.now();

    switch (range) {
      case 0: // Daily — 30-minute averages for today (x = half-hour index 0–47)
        return _aggregateHalfHourly(readings, now);
      case 1: // Weekly — daily averages for last 7 days
        return _aggregateDaily(readings, now, 7);
      case 2: // Monthly — weekly averages for last 30 days
        return _aggregateWeekly(readings, now);
      default:
        return [];
    }
  }

  // Daily: group by 30-minute slot (0–47), return slots that have data.
  // x = halfHourIndex → 20 = 10:00am, 21 = 10:30am, etc.
  List<FlSpot> _aggregateHalfHourly(List<VitalReading> readings, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final todayReadings =
        readings.where((r) => r.timestamp.isAfter(today)).toList();

    if (todayReadings.isEmpty) return [];

    final Map<int, List<double>> buckets = {};
    for (final r in todayReadings) {
      final slot = r.timestamp.hour * 2 + (r.timestamp.minute >= 30 ? 1 : 0);
      buckets.putIfAbsent(slot, () => []).add(r.value);
    }

    final spots = buckets.entries
        .map((e) =>
            FlSpot(e.key.toDouble(), _avg(e.value)))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    return spots;
  }

  // Formats a half-hour slot index (0–47) → '10am', '10:30am', '12pm'…
  static String halfHourLabel(int slot) {
    final h = slot ~/ 2;
    final half = slot.isOdd;
    final ampm = h < 12 ? 'am' : 'pm';
    int h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return half ? '$h12:30$ampm' : '$h12$ampm';
  }

  // Weekly: one point per day for last 7 days — ALWAYS 7 spots (null = no data)
  List<FlSpot> _aggregateDaily(
      List<VitalReading> readings, DateTime now, int days) {
    final spots = <FlSpot>[];

    for (int i = days - 1; i >= 0; i--) {
      final day  = DateTime(now.year, now.month, now.day - i);
      final next = day.add(const Duration(days: 1));
      final dayReadings = readings
          .where((r) => r.timestamp.isAfter(day) && r.timestamp.isBefore(next))
          .map((r) => r.value)
          .toList();

      final x = (days - 1 - i).toDouble();
      if (dayReadings.isNotEmpty) {
        spots.add(FlSpot(x, _avg(dayReadings)));
      } else {
        // Use null spot so line breaks but x position stays fixed
        spots.add(FlSpot.nullSpot);
      }
    }

    // Remove leading/trailing null spots — keep internal ones for gaps
    while (spots.isNotEmpty && spots.first.isNull()) spots.removeAt(0);
    while (spots.isNotEmpty && spots.last.isNull())  spots.removeLast();

    // Re-index after trimming so positions are still correct
    // Actually keep original x values — just filter nulls for display
    return spots.where((s) => !s.isNull()).toList();
  }

  // Monthly: ALWAYS 4 spots — one per week, null if no data that week
  List<FlSpot> _aggregateWeekly(
      List<VitalReading> readings, DateTime now) {
    final spots = <FlSpot>[];

    for (int w = 3; w >= 0; w--) {
      final weekStart = now.subtract(Duration(days: (w + 1) * 7));
      final weekEnd   = now.subtract(Duration(days:  w      * 7));
      final weekReadings = readings
          .where((r) =>
              r.timestamp.isAfter(weekStart) &&
              r.timestamp.isBefore(weekEnd))
          .map((r) => r.value)
          .toList();

      final x = (3 - w).toDouble(); // always 0, 1, 2, 3
      if (weekReadings.isNotEmpty) {
        spots.add(FlSpot(x, _avg(weekReadings)));
      }
      // Don't add nullSpot — just skip empty weeks so line connects real data
    }

    return spots;
  }

  double _avg(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  // ── AXIS LABELS ───────────────────────────────────────
  List<String> getLabels(String key, int range) {
    final now = DateTime.now();
    switch (range) {
      case 0: // Daily — show 30-min slots that have data (10am, 10:30am…)
        final spots = getSpots(key, 0);
        if (spots.isEmpty) return _defaultHourLabels();
        return spots.map((s) => halfHourLabel(s.x.toInt())).toList();
      case 1: // Weekly — Mon–Sun relative to today
        return _last7DayLabels(now);
      case 2: // Monthly — W1–W4
        return ['W1', 'W2', 'W3', 'W4'];
      default:
        return [];
    }
  }

  List<String> _defaultHourLabels() =>
      ['12a', '3a', '6a', '9a', '12p', '3p', '6p', '9p', '11p'];

  String _hourLabel(int h) {
    if (h == 0) return '12a';
    if (h == 12) return '12p';
    if (h < 12) return '${h}a';
    return '${h - 12}p';
  }

  List<String> _last7DayLabels(DateTime now) {
    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return dayNames[day.weekday - 1];
    });
  }

  // ── PERIOD LABEL ──────────────────────────────────────
  String getPeriodLabel(int range) {
    final now = DateTime.now();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    switch (range) {
      case 0:
        return 'Today, ${months[now.month - 1]} ${now.day}';
      case 1:
        final from = now.subtract(const Duration(days: 6));
        return '${months[from.month - 1]} ${from.day} – ${months[now.month - 1]} ${now.day}';
      case 2:
        final from = now.subtract(const Duration(days: 29));
        return '${months[from.month - 1]} ${from.day} – ${months[now.month - 1]} ${now.day}';
      default:
        return '';
    }
  }

  // ── ACTIVITY STATS (Steps + Calories + Distance) ─────
  // Returns combined activity summary for selected range
  ({
    double steps, double calories, double distanceKm, double exerciseMin,
    double dailyAvgSteps, double bestDaySteps
  }) getActivityStats(int range) {
    final now = DateTime.now();
    final int days = range == 0 ? 1 : range == 1 ? 7 : 30;
    final cutoff = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    double _sumByDay(String key) {
      final readings = _cache[key] ?? [];
      final inRange = readings.where((r) => r.timestamp.isAfter(cutoff)).toList();
      if (inRange.isEmpty) return 0;
      // Group by day, take max per day (cumulative intraday values)
      final Map<String, double> byDay = {};
      for (final r in inRange) {
        final k = '${r.timestamp.year}-${r.timestamp.month}-${r.timestamp.day}';
        if ((byDay[k] ?? 0) < r.value) byDay[k] = r.value;
      }
      return byDay.values.fold(0.0, (a, b) => a + b);
    }

    final stepsReadings = _cache['steps'] ?? [];
    final inRange = stepsReadings.where((r) => r.timestamp.isAfter(cutoff)).toList();
    final Map<String, double> stepsByDay = {};
    for (final r in inRange) {
      final k = '${r.timestamp.year}-${r.timestamp.month}-${r.timestamp.day}';
      if ((stepsByDay[k] ?? 0) < r.value) stepsByDay[k] = r.value;
    }
    final totalSteps = stepsByDay.values.fold(0.0, (a, b) => a + b);
    final dailyAvg = stepsByDay.isEmpty ? 0.0 : totalSteps / stepsByDay.length;
    final bestDay = stepsByDay.isEmpty ? 0.0 :
        stepsByDay.values.reduce((a, b) => a > b ? a : b);

    return (
      steps:        totalSteps,
      calories:     _sumByDay('calories'),
      distanceKm:   _sumByDay('distance'),
      exerciseMin:  _sumByDay('steps') > 0 ? (totalSteps / 100).clamp(0, 999) : 0,
      dailyAvgSteps: dailyAvg,
      bestDaySteps:  bestDay,
    );
  }

  // ── STEPS SPECIAL STATS ───────────────────────────────
  // Returns (total, dailyAvg, bestDay) for the selected range
  ({double total, double dailyAvg, double bestDay}) getStepsStats(int range) {
    final readings = _cache['steps'] ?? [];
    if (readings.isEmpty) return (total: 0, dailyAvg: 0, bestDay: 0);

    final now = DateTime.now();
    final int days = range == 0 ? 1 : range == 1 ? 7 : 30;
    final cutoff = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    final inRange = readings.where((r) => r.timestamp.isAfter(cutoff)).toList();
    if (inRange.isEmpty) return (total: 0, dailyAvg: 0, bestDay: 0);

    // Group by day, take max per day (steps are cumulative intraday)
    final Map<String, double> byDay = {};
    for (final r in inRange) {
      final key = '${r.timestamp.year}-${r.timestamp.month}-${r.timestamp.day}';
      if ((byDay[key] ?? 0) < r.value) byDay[key] = r.value;
    }

    final dailyTotals = byDay.values.toList();
    final total = dailyTotals.reduce((a, b) => a + b);
    final bestDay = dailyTotals.reduce((a, b) => a > b ? a : b);
    final dailyAvg = total / dailyTotals.length;

    return (total: total, dailyAvg: dailyAvg, bestDay: bestDay);
  }

  // ── SLEEP SPECIAL STATS ───────────────────────────────
  // Returns (avg, best, worst) hours for the selected range
  ({double avg, double best, double worst}) getSleepStats(int range) {
    final readings = _cache['sleep'] ?? [];
    if (readings.isEmpty) return (avg: 0, best: 0, worst: 0);

    final now = DateTime.now();
    final int days = range == 0 ? 1 : range == 1 ? 7 : 30;
    final cutoff = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    final inRange = readings
        .where((r) => r.timestamp.isAfter(cutoff) && r.value > 0)
        .map((r) => r.value)
        .toList();

    if (inRange.isEmpty) return (avg: 0, best: 0, worst: 0);

    final avg = inRange.reduce((a, b) => a + b) / inRange.length;
    final best = inRange.reduce((a, b) => a > b ? a : b);
    final worst = inRange.reduce((a, b) => a < b ? a : b);

    return (avg: avg, best: best, worst: worst);
  }

  // ── BP PAIR AVERAGE ───────────────────────────────────
  // Returns average systolic/diastolic as "120/80" string
  String getBpAvgPair(int range) {
    final sys = getSpots('blood_pressure', range);
    final dia = getSpots('bp_diastolic', range);
    if (sys.isEmpty) return '--/--';
    final avgSys = sys.map((s) => s.y).reduce((a, b) => a + b) / sys.length;
    if (dia.isEmpty) return '${avgSys.round()}/--';
    final avgDia = dia.map((s) => s.y).reduce((a, b) => a + b) / dia.length;
    return '${avgSys.round()}/${avgDia.round()}';
  }

  // ── KEY HELPERS ───────────────────────────────────────
  static const Map<String, String> vitalKeyMap = {
    'Heart Rate':              'heart_rate',
    'SpO₂':                    'spo2',
    'HRV':                     'hrv',
    'Temperature':             'temperature',
    'Blood Pressure':          'blood_pressure',
    'Stress Level':            'stress',
    'Steps Today':             'steps',
    'Blood Glucose':           'blood_glucose',
    'Blood Glucose (Manual)':  'blood_glucose',
    'Sleep Quality':           'sleep',
    'Calories':                'calories',
    'Distance':                'distance',
  };

  static String keyFor(String title) =>
      vitalKeyMap[title] ?? title.toLowerCase().replaceAll(' ', '_');
}
