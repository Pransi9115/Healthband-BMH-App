// ─────────────────────────────────────────────────────────
//  BIORESPONSE — NUTRITIONAL SCORE ENGINE
//
//  Turns the food the patient has actually logged in the
//  BioMedical Diet module into a 0–100 score for each of the
//  11 nutrition goals.
//
//  HOW A SCORE IS BUILT
//  Every goal is a weighted list of "drivers". A driver is one
//  nutrient that matters for that goal, with:
//    · a weight  — how much it counts toward the goal
//    · a kind    — target (reach it) or limit (stay under it)
//    · a factor  — multiplies the patient's normal daily need,
//                  e.g. muscle building asks 1.4x the protein
//
//  Attainment per driver:
//    target → consumed / need, capped at 100%
//    limit  → 100% while at or under the ceiling, then falls
//             away, reaching 0% at twice the ceiling
//
//  Goal score = sum(weight x attainment). Range 0–100.
//
//  DATA SOURCE
//  Only meals the patient logged and did not leave planned.
//  Nothing is estimated or invented: a day with no food logged
//  reports "no data", never a zero score.
// ─────────────────────────────────────────────────────────

import '../diet/diet_models.dart';
import '../diet/diet_service.dart';

// ── RANGE ─────────────────────────────────────────────────
enum ScoreRange { day, week }

extension ScoreRangeX on ScoreRange {
  String get label => this == ScoreRange.day ? 'Per day' : 'Per week';
  String get shortLabel => this == ScoreRange.day ? 'Day' : 'Week';
  int get days => this == ScoreRange.day ? 1 : 7;
}

// ── DRIVER ────────────────────────────────────────────────
enum DriverKind { target, limit }

class ScoreDriver {
  /// 'kcal' | 'protein' | 'carbs' | 'fat' | 'sugars'
  /// or an exact Micronutrient name, e.g. 'Vitamin C'.
  final String key;
  final double weight;
  final DriverKind kind;

  /// Multiplies the patient's normal daily need for this goal.
  final double factor;

  const ScoreDriver(
    this.key,
    this.weight, {
    this.kind = DriverKind.target,
    this.factor = 1.0,
  });

  String get label => switch (key) {
        'kcal' => 'Energy',
        'protein' => 'Protein',
        'carbs' => 'Carbohydrate',
        'fat' => 'Fat',
        'sugars' => 'Sugars',
        _ => key,
      };

  String get unit => switch (key) {
        'kcal' => 'kcal',
        'protein' || 'carbs' || 'fat' || 'sugars' => 'g',
        _ => Micronutrient.byName(key)?.unit ?? '',
      };
}

// ── ONE DRIVER'S RESULT ───────────────────────────────────
class DriverResult {
  final ScoreDriver driver;
  final double consumed;     // per day (weekly = daily average)
  final double need;         // per day
  final double attainment;   // 0–100

  const DriverResult({
    required this.driver,
    required this.consumed,
    required this.need,
    required this.attainment,
  });

  bool get isLimit => driver.kind == DriverKind.limit;

  /// Short, factual sentence used in the detail list.
  String get note {
    if (isLimit) {
      return attainment >= 100
          ? 'Within the suggested ceiling'
          : 'Above the suggested ceiling';
    }
    if (attainment >= 90) return 'Well covered';
    if (attainment >= 60) return 'Partly covered';
    return 'Low — the main thing holding this score back';
  }
}

// ── ONE GOAL ──────────────────────────────────────────────
class ScoreCategory {
  final String id;
  final String name;
  final String blurb;
  final List<ScoreDriver> drivers;

  const ScoreCategory({
    required this.id,
    required this.name,
    required this.blurb,
    required this.drivers,
  });
}

// ── RESULT FOR ONE GOAL ───────────────────────────────────
class CategoryScore {
  final ScoreCategory category;
  final double score;              // 0–100
  final List<DriverResult> drivers;
  final int daysWithData;
  final int daysInRange;

  const CategoryScore({
    required this.category,
    required this.score,
    required this.drivers,
    required this.daysWithData,
    required this.daysInRange,
  });

  bool get hasData => daysWithData > 0;

  /// Weakest driver — what the patient should fix first.
  DriverResult? get weakest {
    if (drivers.isEmpty) return null;
    final sorted = [...drivers]
      ..sort((a, b) => a.attainment.compareTo(b.attainment));
    return sorted.first.attainment >= 95 ? null : sorted.first;
  }

  String get band {
    if (!hasData) return 'No data';
    if (score >= 80) return 'Strong';
    if (score >= 60) return 'Moderate';
    if (score >= 40) return 'Building';
    return 'Low';
  }
}

// ─────────────────────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────────────────────
class NutritionalScoreService {
  NutritionalScoreService._();
  static final NutritionalScoreService instance =
      NutritionalScoreService._();

  final _diet = DietService.instance;

  // ── THE 11 GOALS ────────────────────────────────────────
  // Weights are the editable part: they encode which nutrients
  // matter most for each goal. Tune with your clinical team —
  // nothing else in the engine needs to change.
  static const List<ScoreCategory> categories = [
    ScoreCategory(
      id: 'sports',
      name: 'Sports and performance',
      blurb: 'Fuel, oxygen transport and electrolytes for training days',
      drivers: [
        ScoreDriver('carbs', 0.28, factor: 1.15),
        ScoreDriver('protein', 0.22, factor: 1.20),
        ScoreDriver('kcal', 0.15),
        ScoreDriver('Magnesium', 0.13),
        ScoreDriver('Potassium', 0.12),
        ScoreDriver('Iron', 0.10),
      ],
    ),
    ScoreCategory(
      id: 'weight_loss',
      name: 'Weight loss and diets',
      blurb: 'Protein and nutrient density while energy and sugars stay in check',
      drivers: [
        ScoreDriver('protein', 0.30, factor: 1.25),
        ScoreDriver('sugars', 0.22, kind: DriverKind.limit, factor: 0.70),
        ScoreDriver('kcal', 0.20, kind: DriverKind.limit),
        ScoreDriver('fat', 0.10, kind: DriverKind.limit),
        ScoreDriver('Magnesium', 0.09),
        ScoreDriver('Potassium', 0.09),
      ],
    ),
    ScoreCategory(
      id: 'beauty',
      name: 'Beauty',
      blurb: 'Skin, hair and nail support: collagen, repair and barrier nutrients',
      drivers: [
        ScoreDriver('Vitamin C', 0.25),
        ScoreDriver('Zinc', 0.20),
        ScoreDriver('Vitamin A', 0.18),
        ScoreDriver('Omega-3', 0.17),
        ScoreDriver('protein', 0.12),
        ScoreDriver('sugars', 0.08, kind: DriverKind.limit),
      ],
    ),
    ScoreCategory(
      id: 'mind',
      name: 'Mind and wellness',
      blurb: 'Nutrients tied to mood, focus and nervous system function',
      drivers: [
        ScoreDriver('Omega-3', 0.26),
        ScoreDriver('Vitamin B12', 0.20),
        ScoreDriver('Folate', 0.18),
        ScoreDriver('Magnesium', 0.18),
        ScoreDriver('Vitamin D', 0.12),
        ScoreDriver('sugars', 0.06, kind: DriverKind.limit),
      ],
    ),
    ScoreCategory(
      id: 'life_stage',
      name: 'Life stage',
      blurb: 'Broad nutrient adequacy that matters across ageing and life changes',
      drivers: [
        ScoreDriver('Calcium', 0.20),
        ScoreDriver('Vitamin D', 0.20),
        ScoreDriver('Vitamin B12', 0.18),
        ScoreDriver('Folate', 0.15),
        ScoreDriver('Iron', 0.15),
        ScoreDriver('protein', 0.12),
      ],
    ),
    ScoreCategory(
      id: 'conditions',
      name: 'Conditions',
      blurb: 'General dietary balance used alongside a clinician’s plan',
      drivers: [
        ScoreDriver('sugars', 0.25, kind: DriverKind.limit, factor: 0.80),
        ScoreDriver('fat', 0.18, kind: DriverKind.limit),
        ScoreDriver('Potassium', 0.16),
        ScoreDriver('Magnesium', 0.15),
        ScoreDriver('protein', 0.13),
        ScoreDriver('Omega-3', 0.13),
      ],
    ),
    ScoreCategory(
      id: 'muscle',
      name: 'Body building and muscle',
      blurb: 'High protein plus the energy and minerals muscle growth needs',
      drivers: [
        ScoreDriver('protein', 0.36, factor: 1.40),
        ScoreDriver('kcal', 0.20, factor: 1.10),
        ScoreDriver('carbs', 0.14, factor: 1.10),
        ScoreDriver('Zinc', 0.12),
        ScoreDriver('Magnesium', 0.10),
        ScoreDriver('Calcium', 0.08),
      ],
    ),
    ScoreCategory(
      id: 'running',
      name: 'Running and stamina',
      blurb: 'Endurance fuel, oxygen delivery and sweat-loss minerals',
      drivers: [
        ScoreDriver('carbs', 0.30, factor: 1.25),
        ScoreDriver('Iron', 0.20),
        ScoreDriver('Potassium', 0.16),
        ScoreDriver('Magnesium', 0.14),
        ScoreDriver('kcal', 0.12, factor: 1.10),
        ScoreDriver('Vitamin B12', 0.08),
      ],
    ),
    ScoreCategory(
      id: 'bone_muscle',
      name: 'Bone and muscle maintenance',
      blurb: 'Keeping bone density and lean mass steady over time',
      drivers: [
        ScoreDriver('Calcium', 0.26),
        ScoreDriver('Vitamin D', 0.24),
        ScoreDriver('protein', 0.22, factor: 1.15),
        ScoreDriver('Magnesium', 0.16),
        ScoreDriver('Potassium', 0.12),
      ],
    ),
    ScoreCategory(
      id: 'strength',
      name: 'Strength and power',
      blurb: 'Protein, energy and the minerals behind force production',
      drivers: [
        ScoreDriver('protein', 0.34, factor: 1.35),
        ScoreDriver('kcal', 0.18, factor: 1.05),
        ScoreDriver('Zinc', 0.16),
        ScoreDriver('Magnesium', 0.14),
        ScoreDriver('Iron', 0.10),
        ScoreDriver('carbs', 0.08),
      ],
    ),
    ScoreCategory(
      id: 'recovery',
      name: 'Injury recovery',
      blurb: 'Tissue repair: protein, collagen support and anti-inflammatory fats',
      drivers: [
        ScoreDriver('protein', 0.28, factor: 1.30),
        ScoreDriver('Vitamin C', 0.22),
        ScoreDriver('Zinc', 0.18),
        ScoreDriver('Vitamin A', 0.14),
        ScoreDriver('Omega-3', 0.12),
        ScoreDriver('kcal', 0.06),
      ],
    ),
  ];

  static ScoreCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ── DAILY NEED FOR ONE DRIVER ───────────────────────────
  double _needFor(ScoreDriver d) {
    final t = _diet.targets;
    final base = switch (d.key) {
      'kcal' => t.kcal,
      'protein' => t.proteinG,
      'carbs' => t.carbsG,
      'fat' => t.fatG,
      'sugars' => t.sugarsG,
      _ => Micronutrient.byName(d.key)?.rda ?? 0,
    };
    return base * d.factor;
  }

  // ── CONSUMED FOR ONE DRIVER, ONE DAY ────────────────────
  double _consumedFor(ScoreDriver d, DateTime day) => switch (d.key) {
        'kcal' => _diet.kcalFor(day),
        'protein' => _diet.proteinFor(day),
        'carbs' => _diet.carbsFor(day),
        'fat' => _diet.fatFor(day),
        'sugars' => _diet.sugarsFor(day),
        _ => _diet.microsFor(day)[d.key] ?? 0,
      };

  /// A day counts as logged when at least one eaten meal exists.
  bool hasDataOn(DateTime day) =>
      _diet.mealsFor(day).any((m) => !m.planned && m.foods.isNotEmpty);

  /// Days in the range, most recent last.
  List<DateTime> daysIn(ScoreRange range, DateTime endDay) {
    final end = DateTime(endDay.year, endDay.month, endDay.day);
    return List.generate(
      range.days,
      (i) => end.subtract(Duration(days: range.days - 1 - i)),
    );
  }

  double _attainment(ScoreDriver d, double consumed, double need) {
    if (need <= 0) return 0;
    if (d.kind == DriverKind.target) {
      return (consumed / need * 100).clamp(0, 100).toDouble();
    }
    // Limit: full marks at or under the ceiling, zero at twice it.
    if (consumed <= need) return 100;
    final over = (consumed - need) / need;         // 0 → 1 across the ceiling
    return ((1 - over) * 100).clamp(0, 100).toDouble();
  }

  // ── SCORE ONE GOAL ──────────────────────────────────────
  CategoryScore scoreFor(
    ScoreCategory cat,
    ScoreRange range, {
    DateTime? endDay,
  }) {
    final days = daysIn(range, endDay ?? DateTime.now());
    final logged = days.where(hasDataOn).toList();

    if (logged.isEmpty) {
      return CategoryScore(
        category: cat,
        score: 0,
        drivers: [
          for (final d in cat.drivers)
            DriverResult(
              driver: d, consumed: 0, need: _needFor(d), attainment: 0),
        ],
        daysWithData: 0,
        daysInRange: days.length,
      );
    }

    final results = <DriverResult>[];
    double total = 0;
    double weightSum = 0;

    for (final d in cat.drivers) {
      final need = _needFor(d);
      // Average across logged days only, so one unlogged day does
      // not drag a weekly score down as though nothing was eaten.
      final avgConsumed = logged
              .map((day) => _consumedFor(d, day))
              .fold<double>(0, (a, b) => a + b) /
          logged.length;

      final att = _attainment(d, avgConsumed, need);
      results.add(DriverResult(
        driver: d, consumed: avgConsumed, need: need, attainment: att));

      total += att * d.weight;
      weightSum += d.weight;
    }

    return CategoryScore(
      category: cat,
      score: weightSum == 0 ? 0 : (total / weightSum).clamp(0, 100).toDouble(),
      drivers: results,
      daysWithData: logged.length,
      daysInRange: days.length,
    );
  }

  /// All 11 goals, highest score first.
  List<CategoryScore> scoreAll(ScoreRange range, {DateTime? endDay}) {
    final out = categories
        .map((c) => scoreFor(c, range, endDay: endDay))
        .toList();
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  /// Headline BioResponse number — the average across every goal.
  double overall(ScoreRange range, {DateTime? endDay}) {
    final all = scoreAll(range, endDay: endDay);
    if (all.isEmpty || !all.first.hasData) return 0;
    return all.fold<double>(0, (s, c) => s + c.score) / all.length;
  }

  /// How many days in the range actually have logged meals.
  int daysLogged(ScoreRange range, {DateTime? endDay}) =>
      daysIn(range, endDay ?? DateTime.now()).where(hasDataOn).length;
}
