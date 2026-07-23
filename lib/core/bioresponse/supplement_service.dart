// ─────────────────────────────────────────────────────────
//  BIORESPONSE — SUPPLEMENTS
//
//  Intake means everything that goes into the body, so the
//  Biomarkers screen needs supplements as well as food. Food
//  comes from DietService; this holds what the patient takes as
//  tablets, capsules, powders and drops.
//
//  A supplement contributes its nutrients on the days it is
//  actually marked as taken — never automatically, because
//  "prescribed" and "swallowed" are not the same thing, and the
//  blood result only reflects the second one.
// ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Supplement {
  final String id;
  final String name;
  final String brand;
  final String dose;                       // free text, e.g. "1 capsule"
  final Map<String, double> nutrients;     // Micronutrient name → amount
  final bool active;

  const Supplement({
    required this.id,
    required this.name,
    this.brand = '',
    this.dose = '',
    this.nutrients = const {},
    this.active = true,
  });

  Supplement copyWith({
    String? name,
    String? brand,
    String? dose,
    Map<String, double>? nutrients,
    bool? active,
  }) =>
      Supplement(
        id: id,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        dose: dose ?? this.dose,
        nutrients: nutrients ?? this.nutrients,
        active: active ?? this.active,
      );

  String get summary {
    if (nutrients.isEmpty) return dose.isEmpty ? 'No nutrients set' : dose;
    return nutrients.entries
        .map((e) => '${e.key} ${fmt(e.value)}')
        .join(' · ');
  }

  static String fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'brand': brand, 'dose': dose,
        'nutrients': nutrients, 'active': active,
      };

  factory Supplement.fromJson(Map<String, dynamic> j) => Supplement(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        brand: j['brand'] as String? ?? '',
        dose: j['dose'] as String? ?? '',
        nutrients: ((j['nutrients'] as Map?) ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble())),
        active: j['active'] as bool? ?? true,
      );
}

// ── COMMON STARTING POINTS ────────────────────────────────
// Offered when adding a supplement so the patient does not have
// to type nutrient amounts. Every value is still editable, and
// nothing is added to the log until the patient saves it.
class SupplementPreset {
  final String name;
  final String dose;
  final Map<String, double> nutrients;
  const SupplementPreset(this.name, this.dose, this.nutrients);

  static const all = <SupplementPreset>[
    SupplementPreset('Vitamin D3', '1 capsule (2,000 IU)',
        {'Vitamin D': 50}),
    SupplementPreset('Vitamin D3 high dose', '1 capsule (4,000 IU)',
        {'Vitamin D': 100}),
    SupplementPreset('Vitamin B12', '1 tablet', {'Vitamin B12': 1000}),
    SupplementPreset('Vitamin C', '1 tablet', {'Vitamin C': 1000}),
    SupplementPreset('Omega-3 fish oil', '2 capsules', {'Omega-3': 1.0}),
    SupplementPreset('Iron', '1 tablet', {'Iron': 14}),
    SupplementPreset('Magnesium', '1 tablet', {'Magnesium': 375}),
    SupplementPreset('Zinc', '1 tablet', {'Zinc': 15}),
    SupplementPreset('Calcium + D3', '1 tablet',
        {'Calcium': 500, 'Vitamin D': 10}),
    SupplementPreset('Folic acid', '1 tablet', {'Folate': 400}),
    SupplementPreset('Multivitamin', '1 tablet', {
      'Vitamin C': 80, 'Vitamin D': 5, 'Vitamin A': 800,
      'Vitamin B12': 2.5, 'Folate': 200, 'Iron': 14,
      'Magnesium': 100, 'Zinc': 10,
    }),
  ];
}

// ─────────────────────────────────────────────────────────
class SupplementService extends ChangeNotifier {
  SupplementService._();
  static final SupplementService instance = SupplementService._();

  static const _kList  = 'bmh_supplements_v1';
  static const _kTaken = 'bmh_supplements_taken_v1';

  SharedPreferences? _prefs;
  List<Supplement> _items = [];
  /// dayKey → set of supplement ids taken that day.
  final Map<String, Set<String>> _taken = {};
  bool _ready = false;

  List<Supplement> get all => List.unmodifiable(_items);
  List<Supplement> get active =>
      List.unmodifiable(_items.where((s) => s.active));
  bool get isReady => _ready;

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();

    final rawList = _prefs!.getString(_kList);
    if (rawList != null) {
      try {
        _items = (jsonDecode(rawList) as List)
            .map((e) =>
                Supplement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        _items = [];
      }
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

  // ── TAKEN LOG ───────────────────────────────────────────
  bool isTaken(DateTime day, String id) =>
      _taken[dayKey(day)]?.contains(id) ?? false;

  Future<void> setTaken(DateTime day, String id, bool taken) async {
    final k = dayKey(day);
    final set = _taken.putIfAbsent(k, () => <String>{});
    taken ? set.add(id) : set.remove(id);
    if (set.isEmpty) _taken.remove(k);
    await _saveTaken();
    notifyListeners();
  }

  int takenCount(DateTime day) => _taken[dayKey(day)]?.length ?? 0;

  /// Nutrients supplied by supplements actually taken on [day].
  Map<String, double> microsFor(DateTime day) {
    final out = <String, double>{};
    final ids = _taken[dayKey(day)] ?? const <String>{};
    for (final s in _items.where((s) => ids.contains(s.id))) {
      s.nutrients.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
    }
    return out;
  }

  /// True if anything at all was taken on [day].
  bool hasDataOn(DateTime day) => (_taken[dayKey(day)] ?? const {}).isNotEmpty;

  // ── CRUD ────────────────────────────────────────────────
  Future<void> add(Supplement s) async {
    _items = [..._items, s];
    await _save();
    notifyListeners();
  }

  Future<void> update(Supplement s) async {
    final i = _items.indexWhere((e) => e.id == s.id);
    if (i < 0) return;
    _items[i] = s;
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items = _items.where((s) => s.id != id).toList();
    for (final set in _taken.values) {
      set.remove(id);
    }
    await _save();
    await _saveTaken();
    notifyListeners();
  }

  Future<void> _save() async =>
      _prefs?.setString(_kList, jsonEncode(_items.map((s) => s.toJson()).toList()));

  Future<void> _saveTaken() async => _prefs?.setString(
      _kTaken, jsonEncode(_taken.map((k, v) => MapEntry(k, v.toList()))));
}
