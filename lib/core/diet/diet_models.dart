// ─────────────────────────────────────────────────────────
//  BIOMEDICAL DIET — data models
//  Mirrors the structure of the standalone HTML prototype:
//  meals → foods → macros + micronutrients.
// ─────────────────────────────────────────────────────────

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeX on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch     => 'Lunch',
        MealType.dinner    => 'Dinner',
        MealType.snack     => 'Snack',
      };

  String get upper => label.toUpperCase();

  static MealType fromName(String n) =>
      MealType.values.firstWhere((m) => m.name == n,
          orElse: () => MealType.snack);

  /// Default time-of-day used when planning a meal.
  int get defaultHour => switch (this) {
        MealType.breakfast => 8,
        MealType.lunch     => 13,
        MealType.dinner    => 19,
        MealType.snack     => 16,
      };
}

// ─────────────────────────────────────────────────────────
//  MICRONUTRIENT
// ─────────────────────────────────────────────────────────
enum MicroGroup { vitamin, mineral, essentialFat }

class Micronutrient {
  final String name;
  final String unit;
  final double rda;          // recommended daily amount
  final MicroGroup group;

  const Micronutrient({
    required this.name,
    required this.unit,
    required this.rda,
    required this.group,
  });

  static const all = <Micronutrient>[
    // Vitamins
    Micronutrient(name: 'Vitamin C',   unit: 'mg',  rda: 90,   group: MicroGroup.vitamin),
    Micronutrient(name: 'Vitamin D',   unit: 'mcg', rda: 20,   group: MicroGroup.vitamin),
    Micronutrient(name: 'Vitamin A',   unit: 'mcg', rda: 900,  group: MicroGroup.vitamin),
    Micronutrient(name: 'Vitamin B12', unit: 'mcg', rda: 2.4,  group: MicroGroup.vitamin),
    Micronutrient(name: 'Folate',      unit: 'mcg', rda: 400,  group: MicroGroup.vitamin),
    // Minerals
    Micronutrient(name: 'Iron',        unit: 'mg',  rda: 18,   group: MicroGroup.mineral),
    Micronutrient(name: 'Magnesium',   unit: 'mg',  rda: 400,  group: MicroGroup.mineral),
    Micronutrient(name: 'Zinc',        unit: 'mg',  rda: 11,   group: MicroGroup.mineral),
    Micronutrient(name: 'Potassium',   unit: 'mg',  rda: 4700, group: MicroGroup.mineral),
    Micronutrient(name: 'Calcium',     unit: 'mg',  rda: 1000, group: MicroGroup.mineral),
    // Essential fats
    Micronutrient(name: 'Omega-3',     unit: 'g',   rda: 1.6,  group: MicroGroup.essentialFat),
  ];

  static Micronutrient? byName(String n) {
    for (final m in all) {
      if (m.name == n) return m;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────
//  FOOD ITEM
// ─────────────────────────────────────────────────────────
class FoodItem {
  final String id;
  final String name;
  final String portion;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sugarsG;

  /// micronutrient name → amount in that nutrient's own unit
  final Map<String, double> micros;

  const FoodItem({
    required this.id,
    required this.name,
    required this.portion,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.sugarsG = 0,
    this.micros = const {},
  });

  String get macroSummary =>
      'P${proteinG.round()} C${carbsG.round()} F${fatG.round()}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'portion': portion,
        'kcal': kcal,
        'protein': proteinG,
        'carbs': carbsG,
        'fat': fatG,
        'sugars': sugarsG,
        'micros': micros,
      };

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        id: j['id'] as String,
        name: j['name'] as String,
        portion: j['portion'] as String? ?? '',
        kcal: (j['kcal'] as num).toDouble(),
        proteinG: (j['protein'] as num).toDouble(),
        carbsG: (j['carbs'] as num).toDouble(),
        fatG: (j['fat'] as num).toDouble(),
        sugarsG: (j['sugars'] as num?)?.toDouble() ?? 0,
        micros: (j['micros'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toDouble()),
            ) ??
            const {},
      );
}

// ─────────────────────────────────────────────────────────
//  LOGGED MEAL
// ─────────────────────────────────────────────────────────
class Meal {
  final String id;
  final MealType type;
  final DateTime time;
  final String title;
  final List<FoodItem> foods;

  /// A planned meal is one the user has scheduled but not eaten yet
  /// ("Dinner · tap to log when eaten" in the prototype).
  final bool planned;

  const Meal({
    required this.id,
    required this.type,
    required this.time,
    required this.title,
    required this.foods,
    this.planned = false,
  });

  double get kcal     => foods.fold(0.0, (s, f) => s + f.kcal);
  double get proteinG => foods.fold(0.0, (s, f) => s + f.proteinG);
  double get carbsG   => foods.fold(0.0, (s, f) => s + f.carbsG);
  double get fatG     => foods.fold(0.0, (s, f) => s + f.fatG);
  double get sugarsG  => foods.fold(0.0, (s, f) => s + f.sugarsG);

  Map<String, double> get micros {
    final out = <String, double>{};
    for (final f in foods) {
      f.micros.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
    }
    return out;
  }

  String get timeLabel {
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final m = time.minute.toString().padLeft(2, '0');
    final ap = time.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  Meal copyWith({
    String? title,
    List<FoodItem>? foods,
    bool? planned,
    DateTime? time,
    MealType? type,
  }) =>
      Meal(
        id: id,
        type: type ?? this.type,
        time: time ?? this.time,
        title: title ?? this.title,
        foods: foods ?? this.foods,
        planned: planned ?? this.planned,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'time': time.toIso8601String(),
        'title': title,
        'planned': planned,
        'foods': foods.map((f) => f.toJson()).toList(),
      };

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        id: j['id'] as String,
        type: MealTypeX.fromName(j['type'] as String),
        time: DateTime.parse(j['time'] as String),
        title: j['title'] as String,
        planned: j['planned'] as bool? ?? false,
        foods: (j['foods'] as List)
            .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

// ─────────────────────────────────────────────────────────
//  DAILY TARGETS
// ─────────────────────────────────────────────────────────
class DietTargets {
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double sugarsG;

  const DietTargets({
    this.kcal = 2100,
    this.proteinG = 130,
    this.carbsG = 210,
    this.fatG = 70,
    this.sugarsG = 50,
  });

  Map<String, dynamic> toJson() => {
        'kcal': kcal,
        'protein': proteinG,
        'carbs': carbsG,
        'fat': fatG,
        'sugars': sugarsG,
      };

  factory DietTargets.fromJson(Map<String, dynamic> j) => DietTargets(
        kcal: (j['kcal'] as num?)?.toDouble() ?? 2100,
        proteinG: (j['protein'] as num?)?.toDouble() ?? 130,
        carbsG: (j['carbs'] as num?)?.toDouble() ?? 210,
        fatG: (j['fat'] as num?)?.toDouble() ?? 70,
        sugarsG: (j['sugars'] as num?)?.toDouble() ?? 50,
      );
}
