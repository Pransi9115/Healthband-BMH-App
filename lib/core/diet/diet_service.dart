// ─────────────────────────────────────────────────────────
//  DIET SERVICE
//  Singleton + ChangeNotifier, same pattern as BleService and
//  VitalHistoryService so it drops straight into the app.
//
//  Persists to SharedPreferences (already a dependency), keyed by
//  calendar day, so logged meals survive app restarts.
// ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'diet_models.dart';

class DietService extends ChangeNotifier {
  DietService._();
  static final DietService instance = DietService._();

  static const _kMealsPrefix = 'bmh_diet_meals_';   // + yyyy-MM-dd
  static const _kTargets     = 'bmh_diet_targets';
  static const _kRecent      = 'bmh_diet_recent_foods';
  static const _kSeeded      = 'bmh_diet_seeded_v1';

  SharedPreferences? _prefs;
  bool _ready = false;
  bool get isReady => _ready;

  final Map<String, List<Meal>> _mealsByDay = {};
  DietTargets _targets = const DietTargets();
  List<FoodItem> _recentFoods = [];

  DietTargets get targets => _targets;
  List<FoodItem> get recentFoods => List.unmodifiable(_recentFoods);

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── INIT ───────────────────────────────────────────────
  Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();

    final t = _prefs!.getString(_kTargets);
    if (t != null) {
      try {
        _targets = DietTargets.fromJson(
            Map<String, dynamic>.from(jsonDecode(t) as Map));
      } catch (_) {/* keep defaults */}
    }

    final r = _prefs!.getString(_kRecent);
    if (r != null) {
      try {
        _recentFoods = (jsonDecode(r) as List)
            .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        _recentFoods = [];
      }
    }
    if (_recentFoods.isEmpty) _recentFoods = List.of(FoodLibrary.starterRecents);

    await _loadDay(DateTime.now());

    // First run only: seed today with the sample day from the
    // prototype so the screen is not empty on first open. Any real
    // logging replaces it, and it never re-seeds.
    if (!(_prefs!.getBool(_kSeeded) ?? false)) {
      final key = dayKey(DateTime.now());
      if ((_mealsByDay[key] ?? const []).isEmpty) {
        _mealsByDay[key] = FoodLibrary.sampleDay(DateTime.now());
        await _saveDay(DateTime.now());
      }
      await _prefs!.setBool(_kSeeded, true);
    }

    _ready = true;
    notifyListeners();
  }

  // ── LOAD / SAVE ────────────────────────────────────────
  Future<void> _loadDay(DateTime day) async {
    final key = dayKey(day);
    if (_mealsByDay.containsKey(key)) return;
    final raw = _prefs?.getString('$_kMealsPrefix$key');
    if (raw == null) {
      _mealsByDay[key] = [];
      return;
    }
    try {
      _mealsByDay[key] = (jsonDecode(raw) as List)
          .map((e) => Meal.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      _mealsByDay[key] = [];
    }
  }

  Future<void> _saveDay(DateTime day) async {
    final key = dayKey(day);
    final list = _mealsByDay[key] ?? [];
    await _prefs?.setString(
      '$_kMealsPrefix$key',
      jsonEncode(list.map((m) => m.toJson()).toList()),
    );
  }

  /// Make sure a day is in memory before reading it.
  Future<void> ensureDay(DateTime day) async {
    await _loadDay(day);
    notifyListeners();
  }

  // ── READ ───────────────────────────────────────────────
  List<Meal> mealsFor(DateTime day) {
    final list = List<Meal>.from(_mealsByDay[dayKey(day)] ?? const []);
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  Meal? mealById(DateTime day, String id) {
    for (final m in mealsFor(day)) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Totals for eaten meals only — planned meals do not count yet.
  double kcalFor(DateTime day) => mealsFor(day)
      .where((m) => !m.planned)
      .fold(0.0, (s, m) => s + m.kcal);

  double proteinFor(DateTime day) => mealsFor(day)
      .where((m) => !m.planned)
      .fold(0.0, (s, m) => s + m.proteinG);

  double carbsFor(DateTime day) => mealsFor(day)
      .where((m) => !m.planned)
      .fold(0.0, (s, m) => s + m.carbsG);

  double fatFor(DateTime day) => mealsFor(day)
      .where((m) => !m.planned)
      .fold(0.0, (s, m) => s + m.fatG);

  double sugarsFor(DateTime day) => mealsFor(day)
      .where((m) => !m.planned)
      .fold(0.0, (s, m) => s + m.sugarsG);

  /// Micronutrient totals for the day.
  Map<String, double> microsFor(DateTime day) {
    final out = <String, double>{};
    for (final m in mealsFor(day).where((m) => !m.planned)) {
      m.micros.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
    }
    return out;
  }

  /// Percent of RDA reached for one micronutrient.
  double microPercent(DateTime day, String name) {
    final n = Micronutrient.byName(name);
    if (n == null || n.rda <= 0) return 0;
    final got = microsFor(day)[name] ?? 0;
    return (got / n.rda * 100);
  }

  /// Overall micronutrient score — the "78% OPTIMAL" headline.
  double microScore(DateTime day) {
    final totals = microsFor(day);
    if (totals.isEmpty) return 0;
    double sum = 0;
    int n = 0;
    for (final m in Micronutrient.all) {
      final got = totals[m.name] ?? 0;
      sum += (got / m.rda * 100).clamp(0, 100);
      n++;
    }
    return n == 0 ? 0 : sum / n;
  }

  int optimalCount(DateTime day) => Micronutrient.all
      .where((m) => microPercent(day, m.name) >= 70)
      .length;

  int lowCount(DateTime day) => Micronutrient.all
      .where((m) => microPercent(day, m.name) < 50)
      .length;

  // ── WRITE ──────────────────────────────────────────────
  Future<void> addMeal(DateTime day, Meal meal) async {
    final key = dayKey(day);
    await _loadDay(day);
    _mealsByDay[key] = [...(_mealsByDay[key] ?? []), meal];
    await _saveDay(day);
    for (final f in meal.foods) {
      _pushRecent(f);
    }
    await _saveRecents();
    notifyListeners();
  }

  Future<void> updateMeal(DateTime day, Meal meal) async {
    final key = dayKey(day);
    await _loadDay(day);
    final list = _mealsByDay[key] ?? [];
    final i = list.indexWhere((m) => m.id == meal.id);
    if (i >= 0) {
      list[i] = meal;
    } else {
      list.add(meal);
    }
    _mealsByDay[key] = list;
    await _saveDay(day);
    notifyListeners();
  }

  Future<void> deleteMeal(DateTime day, String id) async {
    final key = dayKey(day);
    await _loadDay(day);
    _mealsByDay[key] =
        (_mealsByDay[key] ?? []).where((m) => m.id != id).toList();
    await _saveDay(day);
    notifyListeners();
  }

  /// Convert a planned meal into an eaten one.
  Future<void> markEaten(DateTime day, String id) async {
    final m = mealById(day, id);
    if (m == null) return;
    await updateMeal(day, m.copyWith(planned: false, time: DateTime.now()));
  }

  Future<void> setTargets(DietTargets t) async {
    _targets = t;
    await _prefs?.setString(_kTargets, jsonEncode(t.toJson()));
    notifyListeners();
  }

  void _pushRecent(FoodItem f) {
    _recentFoods.removeWhere((e) => e.id == f.id);
    _recentFoods.insert(0, f);
    if (_recentFoods.length > 20) {
      _recentFoods = _recentFoods.sublist(0, 20);
    }
  }

  Future<void> _saveRecents() async {
    await _prefs?.setString(
      _kRecent,
      jsonEncode(_recentFoods.map((f) => f.toJson()).toList()),
    );
  }

  /// Wipe everything — used by "clear data" in settings.
  Future<void> clearAll() async {
    final keys = _prefs?.getKeys().where((k) => k.startsWith(_kMealsPrefix)) ?? [];
    for (final k in keys) {
      await _prefs?.remove(k);
    }
    _mealsByDay.clear();
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────
//  FOOD LIBRARY — searchable catalogue + first-run sample day
//  Values are per the stated portion.
// ─────────────────────────────────────────────────────────
class FoodLibrary {
  FoodLibrary._();

  static const catalogue = <FoodItem>[
    FoodItem(
      id: 'chicken_breast', name: 'Grilled chicken breast', portion: '100 g',
      kcal: 165, proteinG: 31, carbsG: 0, fatG: 3.6,
      micros: {'Zinc': 1.0, 'Vitamin B12': 0.3, 'Iron': 1.0, 'Potassium': 256},
    ),
    FoodItem(
      id: 'brown_rice', name: 'Brown rice', portion: '1 cup cooked',
      kcal: 216, proteinG: 5, carbsG: 45, fatG: 1.8, sugarsG: 0.7,
      micros: {'Magnesium': 84, 'Iron': 0.8, 'Potassium': 84},
    ),
    FoodItem(
      id: 'broccoli', name: 'Steamed broccoli', portion: '1 cup',
      kcal: 55, proteinG: 3.7, carbsG: 11, fatG: 0.6, sugarsG: 2.2,
      micros: {'Vitamin C': 81, 'Folate': 57, 'Potassium': 457, 'Calcium': 62},
    ),
    FoodItem(
      id: 'salmon', name: 'Grilled salmon', portion: '6 oz',
      kcal: 312, proteinG: 34, carbsG: 0, fatG: 19,
      micros: {'Omega-3': 1.8, 'Vitamin D': 17, 'Vitamin B12': 4.9, 'Potassium': 700},
    ),
    FoodItem(
      id: 'quinoa', name: 'Quinoa', portion: '1 cup cooked',
      kcal: 160, proteinG: 6, carbsG: 29, fatG: 2.6, sugarsG: 1.6,
      micros: {'Magnesium': 118, 'Iron': 2.8, 'Folate': 78, 'Zinc': 2.0},
    ),
    FoodItem(
      id: 'mixed_greens', name: 'Mixed greens with olive oil', portion: '1 bowl',
      kcal: 68, proteinG: 1.5, carbsG: 4, fatG: 5.4, sugarsG: 1.2,
      micros: {'Vitamin A': 280, 'Vitamin C': 18, 'Folate': 60, 'Iron': 1.2},
    ),
    FoodItem(
      id: 'greek_yogurt', name: 'Greek yogurt', portion: '170 g',
      kcal: 100, proteinG: 17, carbsG: 6, fatG: 0.7, sugarsG: 6,
      micros: {'Calcium': 187, 'Vitamin B12': 1.3, 'Zinc': 0.9},
    ),
    FoodItem(
      id: 'berries', name: 'Mixed berries', portion: '1 cup',
      kcal: 70, proteinG: 1, carbsG: 17, fatG: 0.4, sugarsG: 11,
      micros: {'Vitamin C': 40, 'Folate': 25, 'Potassium': 150},
    ),
    FoodItem(
      id: 'granola', name: 'Granola', portion: '40 g',
      kcal: 150, proteinG: 4, carbsG: 15, fatG: 8, sugarsG: 5,
      micros: {'Magnesium': 40, 'Iron': 1.4, 'Zinc': 1.0},
    ),
    FoodItem(
      id: 'almonds', name: 'Almonds', portion: '28 g',
      kcal: 164, proteinG: 6, carbsG: 6, fatG: 14, sugarsG: 1.2,
      micros: {'Magnesium': 76, 'Calcium': 76, 'Iron': 1.1, 'Zinc': 0.9},
    ),
    FoodItem(
      id: 'green_apple', name: 'Green apple', portion: '1 medium',
      kcal: 46, proteinG: 0.4, carbsG: 16, fatG: 0.2, sugarsG: 13,
      micros: {'Vitamin C': 6, 'Potassium': 160},
    ),
    FoodItem(
      id: 'pumpkin_seeds', name: 'Pumpkin seeds', portion: '28 g',
      kcal: 158, proteinG: 8.5, carbsG: 3, fatG: 13.9,
      micros: {'Magnesium': 156, 'Zinc': 2.2, 'Iron': 2.3},
    ),
    FoodItem(
      id: 'eggs', name: 'Boiled eggs', portion: '2 large',
      kcal: 155, proteinG: 13, carbsG: 1.1, fatG: 11,
      micros: {'Vitamin D': 2.2, 'Vitamin B12': 1.1, 'Folate': 44, 'Iron': 1.2},
    ),
    FoodItem(
      id: 'spinach', name: 'Cooked spinach', portion: '1 cup',
      kcal: 41, proteinG: 5.3, carbsG: 6.8, fatG: 0.5,
      micros: {'Iron': 6.4, 'Magnesium': 157, 'Folate': 263, 'Vitamin A': 943, 'Calcium': 245},
    ),
    FoodItem(
      id: 'lentils', name: 'Lentils', portion: '1 cup cooked',
      kcal: 230, proteinG: 18, carbsG: 40, fatG: 0.8, sugarsG: 3.6,
      micros: {'Iron': 6.6, 'Folate': 358, 'Magnesium': 71, 'Potassium': 731, 'Zinc': 2.5},
    ),
    FoodItem(
      id: 'paneer', name: 'Paneer', portion: '100 g',
      kcal: 265, proteinG: 18, carbsG: 6, fatG: 20, sugarsG: 2,
      micros: {'Calcium': 480, 'Vitamin B12': 1.1, 'Zinc': 1.6},
    ),
    FoodItem(
      id: 'roti', name: 'Whole wheat roti', portion: '2 pieces',
      kcal: 160, proteinG: 6, carbsG: 32, fatG: 1.6,
      micros: {'Iron': 1.8, 'Magnesium': 48, 'Folate': 20},
    ),
    FoodItem(
      id: 'dal', name: 'Yellow dal', portion: '1 bowl',
      kcal: 180, proteinG: 12, carbsG: 28, fatG: 2.4,
      micros: {'Iron': 3.2, 'Folate': 180, 'Magnesium': 50, 'Potassium': 420},
    ),
    FoodItem(
      id: 'banana', name: 'Banana', portion: '1 medium',
      kcal: 105, proteinG: 1.3, carbsG: 27, fatG: 0.4, sugarsG: 14,
      micros: {'Potassium': 422, 'Vitamin C': 10, 'Magnesium': 32},
    ),
    FoodItem(
      id: 'oats', name: 'Rolled oats', portion: '50 g dry',
      kcal: 190, proteinG: 6.5, carbsG: 33, fatG: 3.5, sugarsG: 0.5,
      micros: {'Magnesium': 69, 'Iron': 2.1, 'Zinc': 1.5},
    ),
  ];

  static List<FoodItem> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return catalogue;
    return catalogue
        .where((f) => f.name.toLowerCase().contains(s))
        .toList();
  }

  static FoodItem? byId(String id) {
    for (final f in catalogue) {
      if (f.id == id) return f;
    }
    return null;
  }

  static List<FoodItem> get starterRecents => [
        catalogue.firstWhere((f) => f.id == 'chicken_breast'),
        catalogue.firstWhere((f) => f.id == 'brown_rice'),
        catalogue.firstWhere((f) => f.id == 'broccoli'),
      ];

  /// The sample day from the HTML prototype — used once on first run.
  static List<Meal> sampleDay(DateTime day) {
    DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);
    return [
      Meal(
        id: 'seed_breakfast',
        type: MealType.breakfast,
        time: at(7, 40),
        title: 'Greek yogurt, berries & granola',
        foods: [
          byId('greek_yogurt')!,
          byId('berries')!,
          byId('granola')!,
        ],
      ),
      Meal(
        id: 'seed_snack',
        type: MealType.snack,
        time: at(10, 30),
        title: 'Almonds & green apple',
        foods: [byId('almonds')!, byId('green_apple')!],
      ),
      Meal(
        id: 'seed_lunch',
        type: MealType.lunch,
        time: at(13, 5),
        title: 'Grilled salmon, quinoa & greens',
        foods: [byId('salmon')!, byId('quinoa')!, byId('mixed_greens')!],
      ),
      Meal(
        id: 'seed_dinner',
        type: MealType.dinner,
        time: at(19, 30),
        title: 'Planned · tap to log when eaten',
        foods: const [],
        planned: true,
      ),
    ];
  }
}
