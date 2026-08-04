// ─────────────────────────────────────────────────────────
//  MEDICATIONS
//
//  Kept deliberately separate from supplements. A supplement adds
//  nutrients to the body; a medication usually does not, but it can
//  change how much of a nutrient the body absorbs or loses. Mixing
//  them into one list would be clinically wrong.
//
//  Medications therefore never contribute to intake totals. What
//  they do is explain a gap: when someone's intake looks adequate
//  but their blood level is still low, a medication known to affect
//  that nutrient is worth surfacing.
//
//  SCHEDULING
//  A medication is a schedule, not a checkbox. Each one carries the
//  number of doses a day and a time for each dose, and every dose is
//  ticked on its own — the morning tablet being taken tells you
//  nothing about the evening one. Adherence that reads "1 of 2" is
//  the whole point.
//
//  IMPORTANT: the interaction notes here are factual, well
//  documented associations — not advice, and never a reason to stop
//  a prescription. Every message the app builds from them ends by
//  pointing back to the care team.
// ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When the dose sits relative to food.
enum FoodTiming { before, after, anytime }

extension FoodTimingX on FoodTiming {
  String get key => switch (this) {
        FoodTiming.before  => 'before',
        FoodTiming.after   => 'after',
        FoodTiming.anytime => 'anytime',
      };

  String get label => switch (this) {
        FoodTiming.before  => 'Before food',
        FoodTiming.after   => 'After food',
        FoodTiming.anytime => 'Anytime',
      };

  String get shortLabel => switch (this) {
        FoodTiming.before  => 'Before',
        FoodTiming.after   => 'After food',
        FoodTiming.anytime => 'Anytime',
      };

  static FoodTiming fromKey(String? k) => switch (k) {
        'before' => FoodTiming.before,
        'after'  => FoodTiming.after,
        _        => FoodTiming.anytime,
      };
}

/// Where a single dose stands right now.
enum DoseStatus { taken, due, upcoming, missed }

/// One scheduled dose on one day.
class DoseSlot {
  final Medication med;
  final int index;
  final int minutes;        // minutes past midnight
  final DoseStatus status;

  const DoseSlot({
    required this.med,
    required this.index,
    required this.minutes,
    required this.status,
  });

  String get timeLabel => Medication.formatMinutes(minutes);
  bool get isTaken => status == DoseStatus.taken;
}

// ─────────────────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────────────────
class Medication {
  final String id;
  final String name;         // generic name, e.g. Metformin
  final String brand;        // what is printed on the strip, e.g. Glycomet
  final String klass;        // drug class, shown as context
  final String strength;     // "500"
  final String unit;         // "mg"
  final String form;         // "Tablet"
  final String quantity;     // "1 tablet"
  final String note;
  final bool daily;          // every day vs as needed
  final bool active;

  /// Doses a day, and the time of each one as minutes past midnight.
  final int timesPerDay;
  final List<int> doseTimes;

  final FoodTiming foodTiming;
  final bool withWater;
  final DateTime? startDate;
  final DateTime? endDate;   // null means ongoing
  final bool remind;

  /// Nutrients this medication is documented to affect, using the
  /// same Micronutrient names the rest of the app uses.
  final List<String> affects;

  const Medication({
    required this.id,
    required this.name,
    this.brand = '',
    this.klass = '',
    this.strength = '',
    this.unit = '',
    this.form = 'Tablet',
    this.quantity = '',
    this.note = '',
    this.daily = true,
    this.active = true,
    this.timesPerDay = 1,
    this.doseTimes = const [480],
    this.foodTiming = FoodTiming.anytime,
    this.withWater = false,
    this.startDate,
    this.endDate,
    this.remind = false,
    this.affects = const [],
  });

  /// Kept so older callers that read a single dose string still work.
  String get dose =>
      [strength, unit].where((s) => s.isNotEmpty).join(' ').trim();

  /// "Metformin 500 mg" / "Metformin (Glycomet) 500 mg"
  String get displayName => brand.isEmpty ? name : '$name ($brand)';

  /// "500 mg · Tablet"
  String get strengthLine =>
      [dose, form].where((s) => s.isNotEmpty).join(' · ');

  /// "After food · with water · twice a day"
  String get scheduleLine {
    final parts = <String>[];
    if (foodTiming != FoodTiming.anytime) parts.add(foodTiming.label);
    if (withWater) parts.add('with water');
    parts.add(switch (timesPerDay) {
      1 => 'once a day',
      2 => 'twice a day',
      3 => 'three times a day',
      4 => 'four times a day',
      _ => '$timesPerDay times a day',
    });
    return parts.join(' · ');
  }

  /// Times sorted and padded so the list always has timesPerDay entries.
  List<int> get resolvedTimes {
    final t = List<int>.from(doseTimes)..sort();
    while (t.length < timesPerDay) {
      t.add(_defaultTimes(timesPerDay)[t.length]);
    }
    return t.take(timesPerDay).toList();
  }

  /// Sensible default clock times for a given frequency.
  static List<int> _defaultTimes(int n) => switch (n) {
        1 => const [480],                       // 8 am
        2 => const [480, 1200],                 // 8 am, 8 pm
        3 => const [480, 840, 1200],            // 8 am, 2 pm, 8 pm
        4 => const [480, 780, 1080, 1320],      // 8 am, 1 pm, 6 pm, 10 pm
        _ => const [480, 720, 960, 1200, 1380],
      };

  static List<int> defaultTimesFor(int n) {
    final base = _defaultTimes(n);
    if (base.length >= n) return base.take(n).toList();
    return [...base, for (var i = base.length; i < n; i++) 480];
  }

  static String formatMinutes(int m) {
    final h24 = (m ~/ 60) % 24;
    final mm = (m % 60).toString().padLeft(2, '0');
    final suffix = h24 < 12 ? 'am' : 'pm';
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:$mm $suffix';
  }

  /// True when this medication is meant to be taken on [day], given
  /// its start and end dates.
  bool activeOn(DateTime day) {
    if (!active) return false;
    final d = DateTime(day.year, day.month, day.day);
    if (startDate != null) {
      final s = DateTime(startDate!.year, startDate!.month, startDate!.day);
      if (d.isBefore(s)) return false;
    }
    if (endDate != null) {
      final e = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (d.isAfter(e)) return false;
    }
    return true;
  }

  /// Course still running, ignoring the day being viewed.
  bool get isOngoing => endDate == null;

  Medication copyWith({
    String? name,
    String? brand,
    String? klass,
    String? strength,
    String? unit,
    String? form,
    String? quantity,
    String? note,
    bool? daily,
    bool? active,
    int? timesPerDay,
    List<int>? doseTimes,
    FoodTiming? foodTiming,
    bool? withWater,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? remind,
    List<String>? affects,
  }) =>
      Medication(
        id: id,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        klass: klass ?? this.klass,
        strength: strength ?? this.strength,
        unit: unit ?? this.unit,
        form: form ?? this.form,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
        daily: daily ?? this.daily,
        active: active ?? this.active,
        timesPerDay: timesPerDay ?? this.timesPerDay,
        doseTimes: doseTimes ?? this.doseTimes,
        foodTiming: foodTiming ?? this.foodTiming,
        withWater: withWater ?? this.withWater,
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        remind: remind ?? this.remind,
        affects: affects ?? this.affects,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'brand': brand, 'klass': klass,
        'strength': strength, 'unit': unit, 'form': form,
        'quantity': quantity, 'note': note,
        'daily': daily, 'active': active,
        'timesPerDay': timesPerDay, 'doseTimes': doseTimes,
        'foodTiming': foodTiming.key, 'withWater': withWater,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'remind': remind, 'affects': affects,
      };

  /// Reads both the new shape and the original one-line `dose` shape,
  /// so medication saved before the schedule existed still loads.
  factory Medication.fromJson(Map<String, dynamic> j) {
    var strength = j['strength'] as String? ?? '';
    var unit = j['unit'] as String? ?? '';

    if (strength.isEmpty && unit.isEmpty) {
      final legacy = (j['dose'] as String? ?? '').trim();
      if (legacy.isNotEmpty) {
        final m = RegExp(r'^([\d.,/]+)\s*(.*)$').firstMatch(legacy);
        if (m != null) {
          strength = m.group(1) ?? '';
          unit = (m.group(2) ?? '').trim();
        } else {
          unit = legacy;
        }
      }
    }

    final times = ((j['doseTimes'] as List?) ?? [])
        .map((e) => (e as num).toInt())
        .toList();
    final tpd = (j['timesPerDay'] as num?)?.toInt() ??
        (times.isEmpty ? 1 : times.length);

    return Medication(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      brand: j['brand'] as String? ?? '',
      klass: j['klass'] as String? ?? '',
      strength: strength,
      unit: unit,
      form: j['form'] as String? ?? 'Tablet',
      quantity: j['quantity'] as String? ?? '',
      note: j['note'] as String? ?? '',
      daily: j['daily'] as bool? ?? true,
      active: j['active'] as bool? ?? true,
      timesPerDay: tpd < 1 ? 1 : tpd,
      doseTimes: times.isEmpty ? Medication.defaultTimesFor(tpd) : times,
      foodTiming: FoodTimingX.fromKey(j['foodTiming'] as String?),
      withWater: j['withWater'] as bool? ?? false,
      startDate: j['startDate'] == null
          ? null : DateTime.tryParse(j['startDate'] as String),
      endDate: j['endDate'] == null
          ? null : DateTime.tryParse(j['endDate'] as String),
      remind: j['remind'] as bool? ?? false,
      affects: ((j['affects'] as List?) ?? []).cast<String>().toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────────────────────
class MedicationService extends ChangeNotifier {
  MedicationService._();
  static final MedicationService instance = MedicationService._();

  static const _kList  = 'bmh_medications_v1';
  static const _kDoses = 'bmh_medication_doses_v2';
  static const _kSkip  = 'bmh_medications_skipped_v1';   // legacy
  static const _kTaken = 'bmh_medications_taken_v1';     // legacy

  SharedPreferences? _prefs;
  List<Medication> _items = [];

  /// dayKey → "medId#doseIndex" for every dose actually ticked.
  final Map<String, Set<String>> _doses = {};
  bool _ready = false;

  /// Grace period before an untaken dose is called missed.
  static const graceMinutes = 60;

  List<Medication> get all => List.unmodifiable(_items);
  List<Medication> get active =>
      List.unmodifiable(_items.where((m) => m.active));
  bool get isReady => _ready;

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _slotKey(String id, int i) => '$id#$i';

  Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();

    final raw = _prefs!.getString(_kList);
    if (raw != null) {
      try {
        _items = (jsonDecode(raw) as List)
            .map((e) =>
                Medication.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        _items = [];
      }
    }

    final rawDoses = _prefs!.getString(_kDoses);
    if (rawDoses != null) {
      try {
        (jsonDecode(rawDoses) as Map).forEach((k, v) {
          _doses[k as String] = (v as List).cast<String>().toSet();
        });
      } catch (_) {/* start clean */}
    } else {
      await _migrateLegacyTicks();
    }

    _ready = true;
    notifyListeners();
  }

  /// The original store recorded one tick per medication per day, and
  /// daily items counted unless explicitly skipped. Those records are
  /// folded into the per-dose store so nobody loses their history.
  Future<void> _migrateLegacyTicks() async {
    final rawSkip = _prefs!.getString(_kSkip);
    final rawTaken = _prefs!.getString(_kTaken);
    if (rawSkip == null && rawTaken == null) return;

    final skipped = <String, Set<String>>{};
    final taken = <String, Set<String>>{};
    try {
      if (rawSkip != null) {
        (jsonDecode(rawSkip) as Map).forEach((k, v) =>
            skipped[k as String] = (v as List).cast<String>().toSet());
      }
      if (rawTaken != null) {
        (jsonDecode(rawTaken) as Map).forEach((k, v) =>
            taken[k as String] = (v as List).cast<String>().toSet());
      }
    } catch (_) {
      return;
    }

    final days = {...skipped.keys, ...taken.keys};
    for (final day in days) {
      final set = _doses.putIfAbsent(day, () => <String>{});
      for (final m in _items) {
        final wasTaken = m.daily
            ? !(skipped[day]?.contains(m.id) ?? false)
            : (taken[day]?.contains(m.id) ?? false);
        if (!wasTaken) continue;
        for (var i = 0; i < m.timesPerDay; i++) {
          set.add(_slotKey(m.id, i));
        }
      }
      if (set.isEmpty) _doses.remove(day);
    }
    await _saveDoses();
  }

  Medication? byId(String id) {
    for (final m in _items) {
      if (m.id == id) return m;
    }
    return null;
  }

  // ── PER-DOSE STATE ──────────────────────────────────────
  bool isDoseTaken(DateTime day, String id, int index) =>
      _doses[dayKey(day)]?.contains(_slotKey(id, index)) ?? false;

  Future<void> setDoseTaken(
      DateTime day, String id, int index, bool taken) async {
    final k = dayKey(day);
    final set = _doses.putIfAbsent(k, () => <String>{});
    taken ? set.add(_slotKey(id, index)) : set.remove(_slotKey(id, index));
    if (set.isEmpty) _doses.remove(k);
    await _saveDoses();
    notifyListeners();
  }

  Future<void> toggleDose(DateTime day, String id, int index) =>
      setDoseTaken(day, id, index, !isDoseTaken(day, id, index));

  /// Status of one dose, taking the clock into account for today.
  DoseStatus doseStatus(DateTime day, Medication m, int index) {
    if (isDoseTaken(day, m.id, index)) return DoseStatus.taken;

    final now = DateTime.now();
    final isToday = day.year == now.year &&
        day.month == now.month && day.day == now.day;
    final isPast = DateTime(day.year, day.month, day.day)
        .isBefore(DateTime(now.year, now.month, now.day));

    if (isPast) return DoseStatus.missed;
    if (!isToday) return DoseStatus.upcoming;

    final times = m.resolvedTimes;
    final at = index < times.length ? times[index] : 0;
    final nowMinutes = now.hour * 60 + now.minute;
    if (nowMinutes > at + graceMinutes) return DoseStatus.missed;
    if (nowMinutes >= at) return DoseStatus.due;
    return DoseStatus.upcoming;
  }

  /// Every dose of every medication scheduled on [day], in time order.
  List<DoseSlot> slotsFor(DateTime day) {
    final out = <DoseSlot>[];
    for (final m in _items) {
      if (!m.activeOn(day)) continue;
      final times = m.resolvedTimes;
      for (var i = 0; i < times.length; i++) {
        out.add(DoseSlot(
          med: m,
          index: i,
          minutes: times[i],
          status: doseStatus(day, m, i)));
      }
    }
    out.sort((a, b) => a.minutes.compareTo(b.minutes));
    return out;
  }

  /// Medications scheduled on [day], in first-dose order.
  List<Medication> scheduledOn(DateTime day) {
    final list = _items.where((m) => m.activeOn(day)).toList();
    list.sort((a, b) {
      final at = a.resolvedTimes.isEmpty ? 0 : a.resolvedTimes.first;
      final bt = b.resolvedTimes.isEmpty ? 0 : b.resolvedTimes.first;
      return at.compareTo(bt);
    });
    return list;
  }

  int dosesTaken(DateTime day) {
    var n = 0;
    for (final m in _items) {
      if (!m.activeOn(day)) continue;
      for (var i = 0; i < m.timesPerDay; i++) {
        if (isDoseTaken(day, m.id, i)) n++;
      }
    }
    return n;
  }

  int dosesTotal(DateTime day) {
    var n = 0;
    for (final m in _items) {
      if (m.activeOn(day)) n += m.timesPerDay;
    }
    return n;
  }

  int dosesMissed(DateTime day) => slotsFor(day)
      .where((s) => s.status == DoseStatus.missed).length;

  /// The next dose still to come today, or null when the day is done.
  DoseSlot? nextDose(DateTime day) {
    for (final s in slotsFor(day)) {
      if (s.status == DoseStatus.due || s.status == DoseStatus.upcoming) {
        return s;
      }
    }
    return null;
  }

  double adherence(DateTime day) {
    final total = dosesTotal(day);
    if (total == 0) return 0;
    return dosesTaken(day) / total;
  }

  // ── COMPATIBILITY ───────────────────────────────────────
  // Older callers ask a yes/no question per medication per day.

  bool isTaken(DateTime day, String id) {
    final m = byId(id);
    if (m == null || !m.activeOn(day)) return false;
    for (var i = 0; i < m.timesPerDay; i++) {
      if (!isDoseTaken(day, id, i)) return false;
    }
    return true;
  }

  Future<void> setTaken(DateTime day, String id, bool taken) async {
    final m = byId(id);
    if (m == null) return;
    final k = dayKey(day);
    final set = _doses.putIfAbsent(k, () => <String>{});
    for (var i = 0; i < m.timesPerDay; i++) {
      taken ? set.add(_slotKey(id, i)) : set.remove(_slotKey(id, i));
    }
    if (set.isEmpty) _doses.remove(k);
    await _saveDoses();
    notifyListeners();
  }

  int takenCount(DateTime day) =>
      _items.where((m) => m.activeOn(day) && isTaken(day, m.id)).length;

  /// Active medications documented to affect [nutrient]. Used to
  /// explain why blood can stay low while intake looks fine.
  List<Medication> affecting(String nutrient) => _items
      .where((m) => m.active && m.affects.contains(nutrient))
      .toList();

  // ── CRUD ────────────────────────────────────────────────
  Future<void> add(Medication m) async {
    _items = [..._items, m];
    await _save();
    notifyListeners();
  }

  Future<void> update(Medication m) async {
    final i = _items.indexWhere((e) => e.id == m.id);
    if (i < 0) return;
    _items[i] = m;
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items = _items.where((m) => m.id != id).toList();
    for (final set in _doses.values) {
      set.removeWhere((k) => k.startsWith('$id#'));
    }
    _doses.removeWhere((_, v) => v.isEmpty);
    await _save();
    await _saveDoses();
    notifyListeners();
  }

  Future<void> _save() async => _prefs?.setString(
      _kList, jsonEncode(_items.map((m) => m.toJson()).toList()));

  Future<void> _saveDoses() async => _prefs?.setString(
      _kDoses, jsonEncode(_doses.map((k, v) => MapEntry(k, v.toList()))));
}
