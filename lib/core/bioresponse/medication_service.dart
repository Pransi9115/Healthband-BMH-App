// ─────────────────────────────────────────────────────────
//  BIORESPONSE — MEDICATIONS
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
//  IMPORTANT: the interaction notes below are factual, well
//  documented associations — not advice, and never a reason to stop
//  a prescription. Every message the app builds from them ends by
//  pointing back to the care team.
// ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Medication {
  final String id;
  final String name;
  final String dose;
  final String note;        // free text from the patient or clinician
  final bool daily;
  final bool active;

  /// Nutrients this medication is documented to affect, using the
  /// same Micronutrient names the rest of the app uses.
  final List<String> affects;

  const Medication({
    required this.id,
    required this.name,
    this.dose = '',
    this.note = '',
    this.daily = true,
    this.active = true,
    this.affects = const [],
  });

  Medication copyWith({
    String? name,
    String? dose,
    String? note,
    bool? daily,
    bool? active,
    List<String>? affects,
  }) =>
      Medication(
        id: id,
        name: name ?? this.name,
        dose: dose ?? this.dose,
        note: note ?? this.note,
        daily: daily ?? this.daily,
        active: active ?? this.active,
        affects: affects ?? this.affects,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'dose': dose, 'note': note,
        'daily': daily, 'active': active, 'affects': affects,
      };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        dose: j['dose'] as String? ?? '',
        note: j['note'] as String? ?? '',
        daily: j['daily'] as bool? ?? true,
        active: j['active'] as bool? ?? true,
        affects: ((j['affects'] as List?) ?? []).cast<String>().toList(),
      );
}

// ── COMMON MEDICATIONS AND THEIR DOCUMENTED EFFECTS ───────
// Offered when adding, so the patient does not have to know which
// nutrients their medication touches. All values are editable and
// the list is easy to extend with your clinical team.
class MedicationPreset {
  final String name;
  final String dose;
  final List<String> affects;
  final String note;
  const MedicationPreset(this.name, this.dose, this.affects, this.note);

  static const all = <MedicationPreset>[
    MedicationPreset('Omeprazole', '20 mg', ['Vitamin B12', 'Magnesium'],
        'Proton pump inhibitors reduce stomach acid, which the body '
        'needs to absorb B12 and magnesium from food.'),
    MedicationPreset('Lansoprazole', '30 mg', ['Vitamin B12', 'Magnesium'],
        'Proton pump inhibitors reduce stomach acid, which the body '
        'needs to absorb B12 and magnesium from food.'),
    MedicationPreset('Metformin', '500 mg', ['Vitamin B12'],
        'Long-term metformin use is associated with lower B12 levels.'),
    MedicationPreset('Methotrexate', '', ['Folate'],
        'Works against folate, which is why folic acid is usually '
        'prescribed alongside it.'),
    MedicationPreset('Furosemide', '40 mg', ['Potassium', 'Magnesium'],
        'Loop diuretics increase how much potassium and magnesium is '
        'lost in urine.'),
    MedicationPreset('Prednisolone', '5 mg', ['Calcium', 'Vitamin D'],
        'Long-term steroid use affects calcium balance and bone health.'),
    MedicationPreset('Levothyroxine', '50 mcg', ['Calcium', 'Iron'],
        'Calcium and iron taken at the same time reduce how much '
        'levothyroxine is absorbed — spacing them apart is usual.'),
    MedicationPreset('Atorvastatin', '10 mg', [], ''),
    MedicationPreset('Amlodipine', '5 mg', [], ''),
    MedicationPreset('Ramipril', '5 mg', [], ''),
  ];
}

// ─────────────────────────────────────────────────────────
class MedicationService extends ChangeNotifier {
  MedicationService._();
  static final MedicationService instance = MedicationService._();

  static const _kList = 'bmh_medications_v1';
  static const _kSkip = 'bmh_medications_skipped_v1';
  static const _kTaken = 'bmh_medications_taken_v1';

  SharedPreferences? _prefs;
  List<Medication> _items = [];
  /// dayKey → ids of DAILY medications marked as missed that day.
  final Map<String, Set<String>> _skipped = {};
  /// dayKey → ids of occasional medications ticked that day.
  final Map<String, Set<String>> _taken = {};
  bool _ready = false;

  List<Medication> get all => List.unmodifiable(_items);
  List<Medication> get active =>
      List.unmodifiable(_items.where((m) => m.active));
  bool get isReady => _ready;

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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
    final rawSkip = _prefs!.getString(_kSkip);
    if (rawSkip != null) {
      try {
        (jsonDecode(rawSkip) as Map).forEach((k, v) {
          _skipped[k as String] = (v as List).cast<String>().toSet();
        });
      } catch (_) {/* start clean */}
    }
    final rawTaken = _prefs!.getString(_kTaken);
    if (rawTaken != null) {
      try {
        (jsonDecode(rawTaken) as Map).forEach((k, v) {
          _taken[k as String] = (v as List).cast<String>().toSet();
        });
      } catch (_) {/* start clean */}
    }
    _ready = true;
    notifyListeners();
  }

  // ── TAKEN ───────────────────────────────────────────────
  Medication? _byId(String id) {
    for (final m in _items) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool isTaken(DateTime day, String id) {
    final m = _byId(id);
    if (m == null) return false;
    final k = dayKey(day);
    // Daily medications count unless the patient marked that day as
    // missed. Occasional ones only count on days they are ticked.
    if (m.daily) return !(_skipped[k]?.contains(id) ?? false);
    return _taken[k]?.contains(id) ?? false;
  }

  Future<void> setTaken(DateTime day, String id, bool taken) async {
    final m = _byId(id);
    if (m == null) return;
    final k = dayKey(day);
    if (m.daily) {
      final set = _skipped.putIfAbsent(k, () => <String>{});
      taken ? set.remove(id) : set.add(id);
      if (set.isEmpty) _skipped.remove(k);
      await _saveSkipped();
    } else {
      final set = _taken.putIfAbsent(k, () => <String>{});
      taken ? set.add(id) : set.remove(id);
      if (set.isEmpty) _taken.remove(k);
      await _saveTaken();
    }
    notifyListeners();
  }

  int takenCount(DateTime day) =>
      _items.where((m) => m.active && isTaken(day, m.id)).length;

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
    for (final set in _skipped.values) {
      set.remove(id);
    }
    for (final set in _taken.values) {
      set.remove(id);
    }
    await _save();
    await _saveSkipped();
    await _saveTaken();
    notifyListeners();
  }

  Future<void> _save() async => _prefs?.setString(
      _kList, jsonEncode(_items.map((m) => m.toJson()).toList()));

  Future<void> _saveSkipped() async => _prefs?.setString(
      _kSkip, jsonEncode(_skipped.map((k, v) => MapEntry(k, v.toList()))));

  Future<void> _saveTaken() async => _prefs?.setString(
      _kTaken, jsonEncode(_taken.map((k, v) => MapEntry(k, v.toList()))));
}
