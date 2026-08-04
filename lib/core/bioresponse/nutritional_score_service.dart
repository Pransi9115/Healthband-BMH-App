// ─────────────────────────────────────────────────────────
//  BIORESPONSE — NUTRITIONAL SCORE ENGINE
//
//  A direct port of the BioResponse provider dashboard engine
//  (biomedical-diet-watch.html). Same criteria, same weights,
//  same thresholds, same wording — so a grade shown in the app
//  and a grade shown on the provider dashboard can never differ.
//
//  STRUCTURE
//    7 categories  → the tab row, Regular first and default
//    36 profiles   → the chip row under the selected tab
//
//  HOW A GRADE IS BUILT
//  Every profile is a short list of weighted criteria. A criterion
//  is one nutrient with a rule:
//
//    min       reach it   — 0 at the floor, 100 at "good", linear between
//    max       stay under — 100 at or below "good", 0 at the ceiling
//    hardMax   safety ceiling — pass or fail, no ramp
//    hardMin   safety minimum — pass or fail (may be per kg body weight)
//
//  Profile score = weighted mean of criterion scores, 0–100.
//  Any hard limit breached caps the whole score at 35 and flags
//  the day to the assigned provider.
//
//  DATA SOURCE
//  Logged meals + active supplements for the day. When nothing has
//  been logged the engine falls back to the reference day (member
//  4471, 79 kg) so the screen renders identically to the dashboard
//  rather than showing an empty shell.
// ─────────────────────────────────────────────────────────

import '../diet/diet_models.dart';
import '../diet/diet_service.dart';
import 'supplement_service.dart';

// ── RANGE (kept for the screens that already use it) ──────
enum ScoreRange { day, week }

extension ScoreRangeX on ScoreRange {
  String get label => this == ScoreRange.day ? 'Per day' : 'Per week';
  String get shortLabel => this == ScoreRange.day ? 'Day' : 'Week';
  int get days => this == ScoreRange.day ? 1 : 7;
}

// ─────────────────────────────────────────────────────────
//  NUTRIENT REGISTRY  (mirrors META in the dashboard)
// ─────────────────────────────────────────────────────────
class NutrientMeta {
  final String key;
  final String label;
  final String unit;

  /// Name used inside FoodItem.micros / Supplement.nutrients.
  /// Null for the four macros, which have their own accessors.
  final String? microName;

  const NutrientMeta(this.key, this.label, this.unit, [this.microName]);
}

class Nutrients {
  Nutrients._();

  static const all = <NutrientMeta>[
    NutrientMeta('energy', 'Energy', 'kcal'),
    NutrientMeta('protein', 'Protein', 'g'),
    NutrientMeta('carb', 'Carbohydrate', 'g'),
    NutrientMeta('fat', 'Fat', 'g'),
    NutrientMeta('satfat', 'Saturated fat', 'g', 'Saturated fat'),
    NutrientMeta('addsugar', 'Added sugar', 'g', 'Added sugar'),
    NutrientMeta('fibre', 'Fibre', 'g', 'Fibre'),
    NutrientMeta('sodium', 'Sodium', 'mg', 'Sodium'),
    NutrientMeta('potassium', 'Potassium', 'mg', 'Potassium'),
    NutrientMeta('phosphorus', 'Phosphorus', 'mg', 'Phosphorus'),
    NutrientMeta('calcium', 'Calcium', 'mg', 'Calcium'),
    NutrientMeta('iron', 'Iron', 'mg', 'Iron'),
    NutrientMeta('magnesium', 'Magnesium', 'mg', 'Magnesium'),
    NutrientMeta('omega3', 'Omega 3', 'g', 'Omega-3'),
    NutrientMeta('vitd', 'Vitamin D', 'mcg', 'Vitamin D'),
    NutrientMeta('folate', 'Folate', 'mcg', 'Folate'),
    NutrientMeta('b12', 'Vitamin B12', 'mcg', 'Vitamin B12'),
    NutrientMeta('iodine', 'Iodine', 'mcg', 'Iodine'),
    NutrientMeta('choline', 'Choline', 'mg', 'Choline'),
    NutrientMeta('vitA', 'Vitamin A', 'mcg', 'Vitamin A'),
    NutrientMeta('vitc', 'Vitamin C', 'mg', 'Vitamin C'),
    NutrientMeta('zinc', 'Zinc', 'mg', 'Zinc'),
  ];

  static final Map<String, NutrientMeta> _byKey = {
    for (final n in all) n.key: n,
  };

  static NutrientMeta of(String key) =>
      _byKey[key] ?? const NutrientMeta('?', '?', '');

  /// The seven chips shown in the day summary strip, in order.
  static const summaryKeys = <String>[
    'energy', 'protein', 'carb', 'fat', 'fibre', 'sodium', 'potassium',
  ];
}

// ─────────────────────────────────────────────────────────
//  REFERENCE DAY — member 4471, 79 kg
//  Used when the patient has logged nothing, so the screen
//  matches the provider dashboard exactly instead of sitting empty.
// ─────────────────────────────────────────────────────────
const double kReferenceWeightKg = 79;

const Map<String, double> kReferenceDay = {
  'energy': 1725, 'protein': 138.5, 'carb': 151.5, 'fat': 62.8,
  'satfat': 15, 'addsugar': 28, 'fibre': 22, 'sodium': 2600,
  'potassium': 3400, 'phosphorus': 1200, 'calcium': 900, 'iron': 14,
  'magnesium': 320, 'omega3': 0.4, 'vitd': 12, 'folate': 400,
  'b12': 4, 'iodine': 150, 'choline': 320, 'vitA': 900,
  'vitc': 75, 'zinc': 11,
};

// ─────────────────────────────────────────────────────────
//  CRITERION
// ─────────────────────────────────────────────────────────
enum CriterionKind { min, max, hardMax, hardMin }

class Criterion {
  final CriterionKind kind;
  final String nutrient;
  final int weight;

  /// min: the value that earns 100.  max: the value up to which
  /// full marks are kept.  Unused by the hard kinds.
  final double good;

  /// min: the floor that earns 0.  max: the ceiling that earns 0.
  final double bound;

  /// hardMax / hardMin: the pass-fail line.
  final double limit;

  /// Set when the hard minimum is expressed per kg of body weight.
  final double? perKg;

  const Criterion._({
    required this.kind,
    required this.nutrient,
    required this.weight,
    this.good = 0,
    this.bound = 0,
    this.limit = 0,
    this.perKg,
  });

  const Criterion.min(String nutrient, double good, double floor, int weight)
      : this._(kind: CriterionKind.min, nutrient: nutrient,
            good: good, bound: floor, weight: weight);

  const Criterion.max(String nutrient, double good, double ceiling, int weight)
      : this._(kind: CriterionKind.max, nutrient: nutrient,
            good: good, bound: ceiling, weight: weight);

  const Criterion.hardMax(String nutrient, double limit, int weight)
      : this._(kind: CriterionKind.hardMax, nutrient: nutrient,
            limit: limit, weight: weight);

  const Criterion.hardMin(String nutrient, double limit, int weight)
      : this._(kind: CriterionKind.hardMin, nutrient: nutrient,
            limit: limit, weight: weight);

  /// A safety minimum scaled by the patient's own body weight,
  /// e.g. 1.2 g of protein per kg.
  const Criterion.hardMinPerKg(String nutrient, double perKg, int weight)
      : this._(kind: CriterionKind.hardMin, nutrient: nutrient,
            perKg: perKg, weight: weight);

  NutrientMeta get meta => Nutrients.of(nutrient);

  /// Resolves the per-kg form against the patient's weight.
  double limitFor(double bodyWeightKg) =>
      perKg != null ? (perKg! * bodyWeightKg).roundToDouble() : limit;

  /// 0–100 for this criterion against a measured value.
  double scoreOn(double v, double bodyWeightKg) {
    switch (kind) {
      case CriterionKind.min:
        if (v >= good) return 100;
        if (v <= bound) return 0;
        return (v - bound) / (good - bound) * 100;
      case CriterionKind.max:
        if (v <= good) return 100;
        if (v >= bound) return 0;
        return (bound - v) / (bound - good) * 100;
      case CriterionKind.hardMax:
        return v > limitFor(bodyWeightKg) ? 0 : 100;
      case CriterionKind.hardMin:
        return v < limitFor(bodyWeightKg) ? 0 : 100;
    }
  }

  bool breachedOn(double v, double bodyWeightKg) {
    if (kind == CriterionKind.hardMax) return v > limitFor(bodyWeightKg);
    if (kind == CriterionKind.hardMin) return v < limitFor(bodyWeightKg);
    return false;
  }

  /// "aim over 126 g" / "keep under 2000 mg" / "ceiling 3000 mcg" /
  /// "minimum 95 g (1.2 g/kg) required"
  String targetText(double bodyWeightKg) {
    final u = meta.unit;
    switch (kind) {
      case CriterionKind.min:
        return 'aim over ${_num(good)} $u';
      case CriterionKind.max:
        return 'keep under ${_num(good)} $u';
      case CriterionKind.hardMin:
        final l = _num(limitFor(bodyWeightKg));
        final per = perKg != null ? ' (${_num(perKg!)} g/kg)' : '';
        return 'minimum $l $u$per required';
      case CriterionKind.hardMax:
        return 'ceiling ${_num(limitFor(bodyWeightKg))} $u';
    }
  }

  /// Sentence used in the safety banner when this criterion fails.
  String breachText(double v, double bodyWeightKg) {
    final l = _num(limitFor(bodyWeightKg));
    final word = kind == CriterionKind.hardMin
        ? 'below the $l ${meta.unit} minimum'
        : 'over the $l ${meta.unit} ceiling';
    return '${meta.label} ${_num(v)} $word';
  }
}

/// Prints 126 as "126" and 2.4 as "2.4" — never "126.0".
String _num(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble()
      ? r.toInt().toString()
      : r.toString();
}

// ─────────────────────────────────────────────────────────
//  RESULT TYPES
// ─────────────────────────────────────────────────────────
class CriterionRow {
  final String label;
  final double value;
  final String unit;
  final int score;        // 0–100
  final int weight;
  final String target;

  const CriterionRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.score,
    required this.weight,
    required this.target,
  });

  String get valueText => _num(value);
}

enum GradeBand { good, moderate, poor }

class Grade {
  final int score;              // 0–100
  final String letter;          // A–F
  final GradeBand band;
  final String desc;            // Good / Moderate / Poor / Not suitable
  final String verdict;         // "Poor for Bodybuilding and muscle"
  final List<String> breaches;
  final List<CriterionRow> criteria;
  final List<String> helped;
  final List<String> heldBack;

  const Grade({
    required this.score,
    required this.letter,
    required this.band,
    required this.desc,
    required this.verdict,
    required this.breaches,
    required this.criteria,
    required this.helped,
    required this.heldBack,
  });

  bool get hasBreach => breaches.isNotEmpty;

  /// "grade F, out of 100"
  String get scoreLine => 'grade $letter, out of 100';
}

// ─────────────────────────────────────────────────────────
//  CATEGORIES AND PROFILES
// ─────────────────────────────────────────────────────────
class GoalCategory {
  final String key;
  final String name;
  const GoalCategory(this.key, this.name);
}

class GoalProfile {
  final String key;
  final String categoryKey;
  final String name;
  final String note;
  final List<Criterion> criteria;

  const GoalProfile({
    required this.key,
    required this.categoryKey,
    required this.name,
    required this.note,
    required this.criteria,
  });

  /// Name without any parenthesised qualifier, used in the verdict.
  String get plainName => name.replaceAll(RegExp(r'\s*\(.*\)'), '');
}

// ── THE TABS ──────────────────────────────────────────────
// Regular comes first and is the default. Everything after it grades
// the day against a goal; Regular grades the day against ordinary
// good eating, so there is always a meaningful number even for
// someone who has not chosen a goal and never will.
const List<GoalCategory> kCategories = [
  GoalCategory('regular', 'Regular'),
  GoalCategory('sport', 'Sports and performance'),
  GoalCategory('diet', 'Weight loss and diets'),
  GoalCategory('beauty', 'Beauty'),
  GoalCategory('mind', 'Mind and wellness'),
  GoalCategory('stage', 'Life stage'),
  GoalCategory('watch', 'Conditions'),
];

/// The profile behind the headline number on the BioResponse hub.
const String kRegularProfileKey = 'everyday_balance';

// ── THE 33 PROFILES ───────────────────────────────────────
// Declaration order is the chip order within each tab.
const List<GoalProfile> kProfiles = [
  // ── Regular ─────────────────────────────────────────────
  // No goal, no plan — just whether the day was nutritionally sound.
  // Thresholds follow general dietary reference values rather than
  // any single protocol, so the number means the same thing for
  // everybody.
  GoalProfile(
    key: 'everyday_balance', categoryKey: 'regular',
    name: 'Everyday balance',
    note: 'Enough protein and fibre, added sugar, sodium and saturated '
        'fat kept in check, and the micronutrients most commonly '
        'found low.',
    criteria: [
      Criterion.min('protein', 63, 40, 2),
      Criterion.min('fibre', 30, 15, 2),
      Criterion.max('addsugar', 25, 60, 1),
      Criterion.max('sodium', 2000, 3500, 1),
      Criterion.max('satfat', 20, 35, 1),
      Criterion.min('energy', 1800, 1200, 1),
      Criterion.min('vitd', 15, 5, 1),
      Criterion.min('b12', 2.4, 1, 1),
      Criterion.min('iron', 14, 8, 1),
      Criterion.min('calcium', 1000, 600, 1),
    ]),
  GoalProfile(
    key: 'heart_regular', categoryKey: 'regular',
    name: 'Heart',
    note: 'Sodium and saturated fat low, fibre and potassium high, '
        'omega 3 present. The everyday pattern associated with lower '
        'cardiovascular risk.',
    criteria: [
      Criterion.max('sodium', 1500, 3000, 3),
      Criterion.max('satfat', 15, 30, 2),
      Criterion.min('fibre', 30, 15, 2),
      Criterion.min('potassium', 3500, 2000, 1),
      Criterion.min('omega3', 1, 0.2, 1),
      Criterion.max('addsugar', 25, 60, 1),
    ]),
  GoalProfile(
    key: 'immunity_regular', categoryKey: 'regular',
    name: 'Immunity',
    note: 'Vitamin C, vitamin D and zinc at target, protein for '
        'antibodies, vitamin A within its safety ceiling.',
    criteria: [
      Criterion.min('vitc', 90, 40, 2),
      Criterion.min('vitd', 15, 5, 2),
      Criterion.min('zinc', 11, 6, 2),
      Criterion.min('protein', 90, 60, 1),
      Criterion.min('vitA', 900, 400, 1),
      Criterion.min('fibre', 30, 15, 1),
      Criterion.hardMax('vitA', 3000, 1),
    ]),

  // ── Sports and performance ──────────────────────────────
  GoalProfile(
    key: 'muscle_building', categoryKey: 'sport',
    name: 'Bodybuilding and muscle',
    note: 'Protein 1.6 to 2.2 g per kg spread across meals, energy at '
        'or above maintenance, carbohydrate to train.',
    criteria: [
      Criterion.min('protein', 126, 63, 3),
      Criterion.min('energy', 2690, 2200, 2),
      Criterion.min('carb', 237, 120, 1),
    ]),
  GoalProfile(
    key: 'endurance', categoryKey: 'sport',
    name: 'Running and stamina',
    note: 'High carbohydrate for glycogen, iron and electrolytes, '
        'with moderate protein.',
    criteria: [
      Criterion.min('carb', 395, 200, 3),
      Criterion.min('energy', 2690, 2000, 1),
      Criterion.min('iron', 18, 8, 1),
    ]),
  GoalProfile(
    key: 'bone_muscle', categoryKey: 'sport',
    name: 'Bone and muscle maintenance',
    note: 'Protein each meal, calcium, vitamin D and magnesium to '
        'protect bone and lean mass.',
    criteria: [
      Criterion.min('protein', 95, 63, 2),
      Criterion.min('calcium', 1000, 600, 2),
      Criterion.min('vitd', 15, 5, 1),
      Criterion.min('magnesium', 320, 200, 1),
    ]),
  GoalProfile(
    key: 'strength', categoryKey: 'sport',
    name: 'Strength and power',
    note: 'High protein and enough energy to lift heavy, with '
        'carbohydrate to fuel sessions.',
    criteria: [
      Criterion.min('protein', 120, 63, 2),
      Criterion.min('energy', 2600, 2100, 2),
      Criterion.min('carb', 200, 100, 1),
    ]),
  GoalProfile(
    key: 'injury', categoryKey: 'sport',
    name: 'Injury recovery',
    note: 'More protein to rebuild tissue, vitamin C and zinc for '
        'repair, omega 3 to calm inflammation, and enough energy to heal.',
    criteria: [
      Criterion.min('protein', 110, 70, 2),
      Criterion.min('vitc', 90, 40, 1),
      Criterion.min('zinc', 11, 6, 1),
      Criterion.min('omega3', 1, 0.2, 1),
      Criterion.min('vitd', 15, 5, 1),
      Criterion.min('energy', 2400, 1800, 1),
    ]),

  // ── Weight loss and diets ───────────────────────────────
  GoalProfile(
    key: 'fat_loss', categoryKey: 'diet',
    name: 'Fat loss',
    note: 'An energy deficit with high protein to hold muscle, '
        'plenty of fibre, low added sugar.',
    criteria: [
      Criterion.max('energy', 2287, 2690, 2),
      Criterion.min('protein', 126, 63, 2),
      Criterion.min('fibre', 30, 15, 1),
      Criterion.max('addsugar', 25, 60, 1),
    ]),
  GoalProfile(
    key: 'weightloss_med', categoryKey: 'diet',
    name: 'Weight loss with medication',
    note: 'On appetite reducing medication the risk is eating too '
        'little. Protein is held at a body weight based minimum, about '
        '1.2 g per kg, for muscle, with a deficit, fibre and hydration.',
    criteria: [
      Criterion.hardMinPerKg('protein', 1.2, 2),
      Criterion.min('protein', 96, 63, 1),
      Criterion.max('energy', 2287, 2690, 1),
      Criterion.min('fibre', 25, 12, 1),
    ]),
  GoalProfile(
    key: 'keto', categoryKey: 'diet',
    name: 'Keto',
    note: 'Very low carbohydrate and high fat, with protein held at a '
        'body weight based minimum, about 1.2 g per kg, so muscle is '
        'maintained.',
    criteria: [
      Criterion.max('carb', 50, 130, 3),
      Criterion.hardMinPerKg('protein', 1.2, 2),
      Criterion.min('fibre', 20, 10, 1),
    ]),
  GoalProfile(
    key: 'fasting', categoryKey: 'diet',
    name: 'Intermittent fasting',
    note: 'Energy kept within the eating window, protein and nutrients '
        'kept up, low added sugar, good hydration during the fast.',
    criteria: [
      Criterion.min('protein', 96, 63, 2),
      Criterion.max('addsugar', 25, 60, 1),
      Criterion.max('energy', 2500, 2900, 1),
      Criterion.min('fibre', 25, 12, 1),
    ]),
  GoalProfile(
    key: 'vegan', categoryKey: 'diet',
    name: 'Vegan',
    note: 'Plant based, watching protein, B12 which is usually '
        'supplemented, iron, zinc, omega 3, calcium and iodine.',
    criteria: [
      Criterion.min('protein', 96, 63, 2),
      Criterion.min('b12', 2.4, 1, 2),
      Criterion.min('iron', 18, 8, 1),
      Criterion.min('zinc', 11, 6, 1),
      Criterion.min('omega3', 1, 0.2, 1),
      Criterion.min('calcium', 1000, 600, 1),
      Criterion.min('iodine', 150, 80, 1),
    ]),
  GoalProfile(
    key: 'vegetarian', categoryKey: 'diet',
    name: 'Vegetarian',
    note: 'Plant based with dairy and eggs, watching protein, iron, '
        'B12, zinc and omega 3.',
    criteria: [
      Criterion.min('protein', 96, 63, 2),
      Criterion.min('iron', 16, 8, 1),
      Criterion.min('b12', 2.4, 1, 1),
      Criterion.min('zinc', 11, 6, 1),
      Criterion.min('omega3', 1, 0.2, 1),
    ]),
  GoalProfile(
    key: 'mediterranean', categoryKey: 'diet',
    name: 'Mediterranean',
    note: 'Unsaturated fats and omega 3, high fibre, low saturated fat '
        'and added sugar, moderate protein.',
    criteria: [
      Criterion.min('fibre', 30, 15, 2),
      Criterion.max('satfat', 15, 30, 1),
      Criterion.min('omega3', 1, 0.2, 1),
      Criterion.max('addsugar', 25, 60, 1),
    ]),
  GoalProfile(
    key: 'lowcarb', categoryKey: 'diet',
    name: 'Low carbohydrate',
    note: 'Moderately reduced carbohydrate, higher protein and fibre, '
        'low added sugar. Less strict than keto.',
    criteria: [
      Criterion.max('carb', 130, 260, 2),
      Criterion.min('protein', 110, 63, 1),
      Criterion.min('fibre', 25, 12, 1),
      Criterion.max('addsugar', 25, 60, 1),
    ]),
  GoalProfile(
    key: 'paleo', categoryKey: 'diet',
    name: 'Paleo',
    note: 'Whole foods, no added sugar, good protein, carbohydrate '
        'from vegetables and fruit.',
    criteria: [
      Criterion.max('addsugar', 10, 40, 2),
      Criterion.min('protein', 110, 63, 1),
      Criterion.min('fibre', 25, 12, 1),
    ]),
  GoalProfile(
    key: 'muscle_maintenance', categoryKey: 'diet',
    name: 'Muscle maintenance',
    note: 'Enough protein to hold muscle in a deficit or on a low '
        'carbohydrate plan, held at a body weight based minimum, about '
        '1.2 g per kg, with resistance training support.',
    criteria: [
      Criterion.hardMinPerKg('protein', 1.2, 3),
      Criterion.min('protein', 110, 63, 1),
      Criterion.min('energy', 2200, 1600, 1),
    ]),

  // ── Beauty ──────────────────────────────────────────────
  GoalProfile(
    key: 'skincare', categoryKey: 'beauty',
    name: 'Skin',
    note: 'Protein for collagen, vitamin C and zinc for repair, '
        'omega 3, vitamin A within its ceiling, low added sugar to '
        'limit glycation.',
    criteria: [
      Criterion.min('protein', 90, 60, 2),
      Criterion.min('vitc', 75, 30, 1),
      Criterion.min('zinc', 11, 6, 1),
      Criterion.min('omega3', 1, 0.2, 1),
      Criterion.max('addsugar', 25, 60, 1),
      Criterion.hardMax('vitA', 3000, 1),
    ]),
  GoalProfile(
    key: 'hair', categoryKey: 'beauty',
    name: 'Hair',
    note: 'Protein for keratin, iron and zinc, vitamin D and omega 3. '
        'Biotin can be added when tracked.',
    criteria: [
      Criterion.min('protein', 100, 60, 2),
      Criterion.min('iron', 14, 7, 1),
      Criterion.min('zinc', 11, 6, 1),
      Criterion.min('vitd', 15, 5, 1),
      Criterion.min('omega3', 1, 0.2, 1),
    ]),
  GoalProfile(
    key: 'nails', categoryKey: 'beauty',
    name: 'Nails',
    note: 'Protein, zinc and iron for strong nail growth. Biotin can '
        'be added when tracked.',
    criteria: [
      Criterion.min('protein', 90, 60, 2),
      Criterion.min('zinc', 11, 6, 1),
      Criterion.min('iron', 14, 7, 1),
    ]),
  GoalProfile(
    key: 'surgery', categoryKey: 'beauty',
    name: 'Plastic surgery recovery',
    note: 'Raised protein for wound healing, vitamin C and zinc for '
        'collagen, adequate vitamin A, and enough energy to recover.',
    criteria: [
      Criterion.min('protein', 110, 70, 2),
      Criterion.min('vitc', 90, 40, 1),
      Criterion.min('zinc', 11, 6, 1),
      Criterion.min('vitA', 700, 300, 1),
      Criterion.min('energy', 2200, 1700, 1),
      Criterion.min('omega3', 0.5, 0.2, 1),
    ]),

  // ── Mind and wellness ───────────────────────────────────
  GoalProfile(
    key: 'cognitive', categoryKey: 'mind',
    name: 'Cognitive and focus',
    note: 'Omega 3 DHA, polyphenols, B vitamins, low added sugar, '
        'a Mediterranean pattern.',
    criteria: [
      Criterion.min('omega3', 1.0, 0.2, 2),
      Criterion.max('addsugar', 25, 60, 1),
      Criterion.min('fibre', 30, 15, 1),
      Criterion.min('b12', 2.4, 1, 1),
      Criterion.min('folate', 400, 200, 1),
    ]),
  GoalProfile(
    key: 'stress', categoryKey: 'mind',
    name: 'Stress and calm',
    note: 'Magnesium, omega 3 and B vitamins, steadier blood sugar, '
        'and limited caffeine and alcohol.',
    criteria: [
      Criterion.min('magnesium', 350, 200, 2),
      Criterion.min('omega3', 1, 0.2, 1),
      Criterion.max('addsugar', 25, 60, 1),
      Criterion.min('b12', 2.4, 1, 1),
      Criterion.min('folate', 400, 200, 1),
    ]),
  GoalProfile(
    key: 'sleep', categoryKey: 'mind',
    name: 'Sleep',
    note: 'Magnesium and steady blood sugar, no late heavy meals, '
        'and limited evening caffeine and alcohol.',
    criteria: [
      Criterion.min('magnesium', 350, 200, 2),
      Criterion.max('addsugar', 20, 50, 2),
      Criterion.min('calcium', 800, 500, 1),
    ]),

  // ── Life stage ──────────────────────────────────────────
  GoalProfile(
    key: 'pregnancy', categoryKey: 'stage',
    name: 'Pregnancy (prenatal)',
    note: 'Folate, iron, iodine, choline and DHA raised, vitamin A '
        'capped as a safety ceiling, no alcohol.',
    criteria: [
      Criterion.min('folate', 600, 300, 2),
      Criterion.min('iron', 27, 14, 2),
      Criterion.min('iodine', 220, 100, 1),
      Criterion.min('choline', 450, 250, 1),
      Criterion.min('omega3', 0.3, 0.1, 1),
      Criterion.min('protein', 95, 63, 1),
      Criterion.hardMax('vitA', 3000, 1),
    ]),
  GoalProfile(
    key: 'postnatal', categoryKey: 'stage',
    name: 'Postnatal and breastfeeding',
    note: 'Higher energy and iodine, with choline, DHA and good '
        'hydration.',
    criteria: [
      Criterion.min('energy', 2990, 2200, 2),
      Criterion.min('iodine', 290, 120, 1),
      Criterion.min('choline', 550, 300, 1),
      Criterion.min('protein', 110, 70, 1),
      Criterion.min('omega3', 0.3, 0.1, 1),
    ]),
  GoalProfile(
    key: 'premenopause', categoryKey: 'stage',
    name: 'Premenopause',
    note: 'Iron and folate for the reproductive years, with calcium '
        'and fibre.',
    criteria: [
      Criterion.min('iron', 18, 8, 2),
      Criterion.min('folate', 400, 200, 1),
      Criterion.min('calcium', 1000, 600, 1),
      Criterion.min('fibre', 25, 12, 1),
    ]),
  GoalProfile(
    key: 'perimenopause', categoryKey: 'stage',
    name: 'Perimenopause',
    note: 'Calcium, vitamin D, protein and magnesium, steadier blood '
        'sugar, more fibre.',
    criteria: [
      Criterion.min('calcium', 1000, 600, 1),
      Criterion.min('vitd', 15, 5, 1),
      Criterion.min('protein', 95, 63, 2),
      Criterion.min('magnesium', 320, 200, 1),
      Criterion.max('addsugar', 25, 60, 1),
      Criterion.min('fibre', 25, 12, 1),
    ]),
  GoalProfile(
    key: 'menopause', categoryKey: 'stage',
    name: 'Menopause',
    note: 'Calcium and vitamin D raised for bone, protein for muscle, '
        'lower sodium.',
    criteria: [
      Criterion.min('calcium', 1200, 700, 2),
      Criterion.min('vitd', 15, 5, 1),
      Criterion.min('protein', 95, 63, 1),
      Criterion.max('sodium', 2000, 3500, 1),
      Criterion.min('magnesium', 320, 200, 1),
      Criterion.min('fibre', 25, 12, 1),
    ]),

  // ── Conditions ──────────────────────────────────────────
  GoalProfile(
    key: 'cardiovascular', categoryKey: 'watch',
    name: 'Cardiovascular',
    note: 'Low saturated fat and sodium, high fibre, omega 3 and '
        'unsaturated fats.',
    criteria: [
      Criterion.max('satfat', 13, 25, 1),
      Criterion.max('sodium', 2000, 3500, 2),
      Criterion.min('fibre', 30, 15, 1),
      Criterion.max('addsugar', 25, 60, 1),
      Criterion.min('omega3', 1, 0.2, 1),
    ]),
  GoalProfile(
    key: 'hypertension', categoryKey: 'watch',
    name: 'Blood pressure (DASH)',
    note: 'Low sodium with higher potassium, magnesium and calcium.',
    criteria: [
      Criterion.max('sodium', 1500, 3000, 3),
      Criterion.min('potassium', 3500, 2500, 2),
      Criterion.min('magnesium', 350, 200, 1),
      Criterion.min('calcium', 1000, 600, 1),
    ]),
  GoalProfile(
    key: 'diabetes', categoryKey: 'watch',
    name: 'Diabetes and glycaemic',
    note: 'Low glycaemic load, high fibre, good protein, low added '
        'sugar.',
    criteria: [
      Criterion.max('addsugar', 20, 50, 2),
      Criterion.min('fibre', 30, 15, 2),
      Criterion.max('satfat', 15, 30, 1),
      Criterion.min('protein', 95, 63, 1),
    ]),
  GoalProfile(
    key: 'renal', categoryKey: 'watch',
    name: 'Renal and dialysis',
    note: 'Potassium and phosphorus ceilings as safety limits, sodium '
        'controlled, protein set by stage.',
    criteria: [
      Criterion.hardMax('potassium', 3000, 2),
      Criterion.hardMax('phosphorus', 1000, 2),
      Criterion.max('sodium', 2000, 3500, 1),
      Criterion.min('protein', 95, 63, 1),
    ]),
  GoalProfile(
    key: 'liver', categoryKey: 'watch',
    name: 'Liver and fatty liver',
    note: 'Low added sugar and fructose, controlled energy, little or '
        'no alcohol, with fibre and omega 3.',
    criteria: [
      Criterion.max('addsugar', 20, 50, 3),
      Criterion.max('satfat', 15, 30, 1),
      Criterion.min('fibre', 30, 15, 1),
      Criterion.max('energy', 2421, 2690, 1),
      Criterion.min('omega3', 1, 0.2, 1),
    ]),
  GoalProfile(
    key: 'eyesight', categoryKey: 'watch',
    name: 'Eye health',
    note: 'Omega 3 DHA for the retina, vitamin A, vitamin C, zinc and '
        'low added sugar. Lutein and zeaxanthin can be added when tracked.',
    criteria: [
      Criterion.min('omega3', 1, 0.2, 2),
      Criterion.min('vitA', 700, 300, 1),
      Criterion.min('vitc', 75, 30, 1),
      Criterion.min('zinc', 11, 6, 1),
      Criterion.max('addsugar', 25, 60, 1),
    ]),
];

// ─────────────────────────────────────────────────────────
//  DAY TOTALS
// ─────────────────────────────────────────────────────────
class DayTotals {
  /// nutrient key → amount, in that nutrient's own unit
  final Map<String, double> values;
  final double weightKg;

  /// True when nothing was logged and the reference day is standing in.
  final bool isReference;

  final DateTime date;

  const DayTotals({
    required this.values,
    required this.weightKg,
    required this.isReference,
    required this.date,
  });

  double operator [](String key) => values[key] ?? 0;

  /// "sample data" / "live data" — the badge on the day strip.
  String get sourceLabel => isReference ? 'sample data' : 'live data';
}

// ─────────────────────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────────────────────
class NutritionalScoreService {
  NutritionalScoreService._();
  static final NutritionalScoreService instance = NutritionalScoreService._();

  final _diet = DietService.instance;
  final _supps = SupplementService.instance;

  /// Patient body weight, used by the per kg safety minimums.
  /// Set from the profile once it is loaded; falls back to the
  /// reference member's weight so grades stay reproducible.
  double bodyWeightKg = kReferenceWeightKg;

  // ── CATEGORIES AND PROFILES ─────────────────────────────
  List<GoalCategory> get categories => kCategories;

  List<GoalProfile> profilesIn(String categoryKey) =>
      kProfiles.where((p) => p.categoryKey == categoryKey).toList();

  GoalProfile? profileByKey(String key) {
    for (final p in kProfiles) {
      if (p.key == key) return p;
    }
    return null;
  }

  // ── HAS THE PATIENT LOGGED ANYTHING? ────────────────────
  bool hasLoggedFood(DateTime day) =>
      _diet.mealsFor(day).any((m) => !m.planned && m.foods.isNotEmpty);

  bool hasDataOn(DateTime day) =>
      hasLoggedFood(day) || _supps.hasDataOn(day);

  // ── TOTALS FOR ONE DAY ──────────────────────────────────
  /// Food plus every supplement actually taken that day. Falls back
  /// to the reference day when the patient has logged nothing, so the
  /// screen shows a worked example rather than a row of zeroes.
  DayTotals totalsFor(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);

    if (!hasDataOn(d)) {
      return DayTotals(
        values: Map<String, double>.from(kReferenceDay),
        weightKg: kReferenceWeightKg,
        isReference: true,
        date: d,
      );
    }

    final foodMicros = _diet.microsFor(d);
    final suppMicros = _supps.microsFor(d);

    final out = <String, double>{};
    for (final n in Nutrients.all) {
      switch (n.key) {
        case 'energy':
          out[n.key] = _diet.kcalFor(d);
          break;
        case 'protein':
          out[n.key] = _diet.proteinFor(d);
          break;
        case 'carb':
          out[n.key] = _diet.carbsFor(d);
          break;
        case 'fat':
          out[n.key] = _diet.fatFor(d);
          break;
        default:
          final name = n.microName;
          if (name == null) {
            out[n.key] = 0;
          } else {
            out[n.key] =
                (foodMicros[name] ?? 0) + (suppMicros[name] ?? 0);
          }
      }
    }

    return DayTotals(
      values: out,
      weightKg: bodyWeightKg,
      isReference: false,
      date: d,
    );
  }

  // ── GRADE ONE PROFILE ───────────────────────────────────
  Grade gradeFor(GoalProfile p, DayTotals totals) {
    double sum = 0;
    double weightSum = 0;
    final breaches = <String>[];
    final rows = <CriterionRow>[];

    for (final c in p.criteria) {
      final v = totals[c.nutrient];
      final s = c.scoreOn(v, totals.weightKg);

      sum += s * c.weight;
      weightSum += c.weight;

      if (c.breachedOn(v, totals.weightKg)) {
        breaches.add(c.breachText(v, totals.weightKg));
      }

      rows.add(CriterionRow(
        label: c.meta.label,
        value: (v * 10).round() / 10,
        unit: c.meta.unit,
        score: s.round(),
        weight: c.weight,
        target: c.targetText(totals.weightKg),
      ));
    }

    var score = weightSum == 0 ? 0 : (sum / weightSum).round();
    // A breached safety limit caps the grade no matter how well the
    // rest of the day scored.
    if (breaches.isNotEmpty && score > 35) score = 35;

    final letter = score >= 85 ? 'A'
        : score >= 75 ? 'B'
        : score >= 65 ? 'C'
        : score >= 55 ? 'D'
        : 'F';

    final band = breaches.isNotEmpty ? GradeBand.poor
        : score >= 75 ? GradeBand.good
        : score >= 60 ? GradeBand.moderate
        : GradeBand.poor;

    final desc = breaches.isNotEmpty ? 'Not suitable'
        : score >= 75 ? 'Good'
        : score >= 60 ? 'Moderate'
        : 'Poor';

    final verb = breaches.isNotEmpty ? 'Not suitable for'
        : desc == 'Good' ? 'Good for'
        : desc == 'Moderate' ? 'Moderate for'
        : 'Poor for';

    List<String> pick(bool Function(CriterionRow) test) {
      final list = rows.where(test).toList()
        ..sort((a, b) => b.weight.compareTo(a.weight));
      return list.take(3).map((r) => r.label).toList();
    }

    return Grade(
      score: score,
      letter: letter,
      band: band,
      desc: desc,
      verdict: '$verb ${p.plainName}',
      breaches: breaches,
      criteria: rows,
      helped: pick((r) => r.score >= 75),
      heldBack: pick((r) => r.score < 60),
    );
  }

  /// Convenience — grade a profile against a given day.
  Grade gradeOn(GoalProfile p, DateTime day) =>
      gradeFor(p, totalsFor(day));

  // ── ROLL-UPS USED BY THE MODULE HUB ─────────────────────
  /// The Regular profile — everyday balance, no goal required.
  GoalProfile get regularProfile =>
      profileByKey(kRegularProfileKey) ?? kProfiles.first;

  /// Grade of the Regular profile for a day.
  Grade regularGradeFor(DateTime day) =>
      gradeFor(regularProfile, totalsFor(day));

  /// The headline BioResponse number.
  ///
  /// This used to be the mean of all 33 goal profiles, which scored
  /// the patient against goals they had never chosen — a vegan grade
  /// for someone who eats meat dragged the headline down for no
  /// reason. It is now the Regular grade: what ordinary good eating
  /// looks like, which is a number anybody can read.
  double overallFor(DateTime day) =>
      regularGradeFor(day).score.toDouble();

  /// The old behaviour, kept for anything that genuinely wants the
  /// mean across every goal profile.
  double meanAcrossAllProfilesFor(DateTime day) {
    final t = totalsFor(day);
    if (kProfiles.isEmpty) return 0;
    final sum = kProfiles.fold<int>(0, (a, p) => a + gradeFor(p, t).score);
    return sum / kProfiles.length;
  }

  // ── LEGACY SHIMS ────────────────────────────────────────
  // The module hub and biomarkers screen were written against the
  // previous per day / per week API. Kept so they keep compiling
  // while they are migrated.
  List<DateTime> daysIn(ScoreRange range, DateTime endDay) {
    final end = DateTime(endDay.year, endDay.month, endDay.day);
    return List.generate(
      range.days,
      (i) => end.subtract(Duration(days: range.days - 1 - i)),
    );
  }

  int daysLogged(ScoreRange range, {DateTime? endDay}) =>
      daysIn(range, endDay ?? DateTime.now()).where(hasLoggedFood).length;

  double overall(ScoreRange range, {DateTime? endDay}) =>
      overallFor(endDay ?? DateTime.now());
}
