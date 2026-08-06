// ─────────────────────────────────────────────────────────
//  GUT — EatIQ IgG PROFILE
//
//  A food-specific IgG panel: how much IgG antibody is circulating
//  against each of 287 food antigens.
//
//  WHAT THIS TEST IS AND IS NOT
//  Raised food-specific IgG is a record of exposure — it reflects what
//  a person eats, not what harms them. It is not an allergy test, and
//  it does not diagnose intolerance. Major allergy bodies are clear
//  that IgG panels should not be used on their own to cut foods out of
//  a diet. This matters enormously in an app that also owns the diet
//  module: a patient who sees thirteen red dots and removes thirteen
//  food groups can do themselves real nutritional harm.
//
//  So the screen leads with what the result means, keeps the wording
//  neutral — "elevated", never "intolerant" or "avoid" — and points at
//  a supervised elimination trial with the care team rather than at a
//  ban list. Every high reading is framed as a question to ask, not an
//  instruction to follow.
// ─────────────────────────────────────────────────────────

enum IgGLevel { low, intermediate, high }

extension IgGLevelX on IgGLevel {
  /// Dots, as the printed report draws them.
  int get dots => switch (this) {
        IgGLevel.low => 1,
        IgGLevel.intermediate => 2,
        IgGLevel.high => 3,
      };

  String get label => switch (this) {
        IgGLevel.low => 'Low',
        IgGLevel.intermediate => 'Intermediate',
        IgGLevel.high => 'Elevated',
      };

  String get rangeLabel => switch (this) {
        IgGLevel.low => 'under 10 µg/ml',
        IgGLevel.intermediate => '10 to 19.99 µg/ml',
        IgGLevel.high => '20 µg/ml and above',
      };

  static IgGLevel forValue(double v) {
    if (v >= 20) return IgGLevel.high;
    if (v >= 10) return IgGLevel.intermediate;
    return IgGLevel.low;
  }
}

/// One food antigen and its measured concentration.
class IgGItem {
  final String name;
  final double value;      // µg/ml

  /// True when the laboratory reported "< 5.00" rather than a figure.
  final bool belowDetection;

  const IgGItem(this.name, this.value, {this.belowDetection = false});

  IgGLevel get level => IgGLevelX.forValue(value);

  String get valueLabel =>
      belowDetection ? '< 5.00' : value.toStringAsFixed(2);

  /// 0..1 across a 0–30 µg/ml scale, which covers the reporting range
  /// with a little headroom.
  double get barPosition => (value / 30).clamp(0.0, 1.0);
}

class IgGCategory {
  final String name;
  final String icon;          // asset-free identifier, mapped in the UI
  final IgGLevel highest;     // the overview dots
  final List<IgGItem> items;

  /// True when this category is summarised in the panel but its
  /// item-level results were not included in the file we were given.
  final bool detailPending;

  const IgGCategory({
    required this.name,
    required this.icon,
    required this.highest,
    this.items = const [],
    this.detailPending = false,
  });

  List<IgGItem> get elevated {
    final list = items.where((i) => i.level != IgGLevel.low).toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  int get highCount =>
      items.where((i) => i.level == IgGLevel.high).length;
  int get intermediateCount =>
      items.where((i) => i.level == IgGLevel.intermediate).length;
}

class GutReport {
  final String patientName;
  final String patientId;
  final String dateOfBirth;
  final String sampleCode;
  final DateTime analysedOn;
  final int testedAntigens;
  final String method;
  final List<IgGCategory> categories;

  const GutReport({
    required this.patientName,
    required this.patientId,
    required this.dateOfBirth,
    required this.sampleCode,
    required this.analysedOn,
    required this.testedAntigens,
    required this.method,
    required this.categories,
  });

  List<IgGItem> get allItems =>
      [for (final c in categories) ...c.items];

  int get reportedCount => allItems.length;

  /// Everything above the low band, worst first — the short list
  /// worth raising with the care team.
  List<IgGItem> get elevated {
    final list =
        allItems.where((i) => i.level != IgGLevel.low).toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  int get highCount =>
      allItems.where((i) => i.level == IgGLevel.high).length;
  int get intermediateCount =>
      allItems.where((i) => i.level == IgGLevel.intermediate).length;
  int get lowCount =>
      allItems.where((i) => i.level == IgGLevel.low).length;

  bool get hasPendingDetail =>
      categories.any((c) => c.detailPending);
}

// ─────────────────────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────────────────────
class GutReportService {
  GutReportService._();
  static final GutReportService instance = GutReportService._();

  GutReport? _report;
  GutReport? get report => _report ?? _sample;
  bool get isSample => _report == null;

  /// THE SEAM. A real laboratory result replaces the sample.
  void ingest(GutReport r) => _report = r;

  // Values below the laboratory's detection floor are reported as
  // "< 5.00" rather than as a number. Stored as 0 so they sort and
  // colour correctly, with the flag preserving how it was reported.
  static const _bd = true;

  static final _sample = GutReport(
    patientName: 'Emily Rosewood',
    patientId: '6010104874',
    dateOfBirth: '19 September 1977',
    sampleCode: '26010104874',
    analysedOn: DateTime(2026, 1, 16),
    testedAntigens: 287,
    method: 'IgG',
    categories: const [
      IgGCategory(
        name: 'Milk & egg', icon: 'milk', highest: IgGLevel.high,
        items: [
          IgGItem('Buttermilk', 0, belowDetection: _bd),
          IgGItem('Camembert', 6.77),
          IgGItem('Emmental', 5.44),
          IgGItem('Gouda', 7.74),
          IgGItem('Cottage cheese', 6.12),
          IgGItem("Cow's milk", 0, belowDetection: _bd),
          IgGItem('Mozzarella', 8.66),
          IgGItem('Parmesan', 7.31),
          IgGItem("Cow's milk — alpha-lactalbumin", 0,
            belowDetection: _bd),
          IgGItem("Cow's milk — beta-lactoglobulin", 24.35),
          IgGItem("Cow's milk — casein", 0, belowDetection: _bd),
          IgGItem('Buffalo milk', 0, belowDetection: _bd),
          IgGItem('Camel milk', 0, belowDetection: _bd),
          IgGItem('Goat cheese', 6.46),
          IgGItem('Goat milk', 0, belowDetection: _bd),
          IgGItem('Quail egg', 0, belowDetection: _bd),
          IgGItem('Egg white', 7.17),
          IgGItem('Egg yolk', 0, belowDetection: _bd),
          IgGItem('Sheep cheese', 0, belowDetection: _bd),
          IgGItem('Sheep milk', 0, belowDetection: _bd),
        ]),

      IgGCategory(
        name: 'Meat', icon: 'meat', highest: IgGLevel.low,
        items: [
          IgGItem('Duck', 0, belowDetection: _bd),
          IgGItem('Beef', 0, belowDetection: _bd),
          IgGItem('Veal', 0, belowDetection: _bd),
          IgGItem('Venison', 0, belowDetection: _bd),
          IgGItem('Goat', 0, belowDetection: _bd),
          IgGItem('Stag', 0, belowDetection: _bd),
          IgGItem('Horse', 0, belowDetection: _bd),
          IgGItem('Chicken', 0, belowDetection: _bd),
          IgGItem('Turkey', 0, belowDetection: _bd),
          IgGItem('Rabbit', 0, belowDetection: _bd),
          IgGItem('Lamb', 0, belowDetection: _bd),
          IgGItem('Ostrich', 0, belowDetection: _bd),
          IgGItem('Pork', 0, belowDetection: _bd),
          IgGItem('Boar', 0, belowDetection: _bd),
        ]),

      IgGCategory(
        name: 'Fish & seafood', icon: 'fish',
        highest: IgGLevel.intermediate,
        items: [
          IgGItem('Caviar', 0, belowDetection: _bd),
          IgGItem('Eel', 0, belowDetection: _bd),
          IgGItem('Noble crayfish', 5.64),
          IgGItem('Cockle', 13.35),
          IgGItem('Crab', 7.31),
          IgGItem('Atlantic herring', 0, belowDetection: _bd),
          IgGItem('Carp', 0, belowDetection: _bd),
          IgGItem('European anchovy', 0, belowDetection: _bd),
          IgGItem('Northern pike', 0, belowDetection: _bd),
          IgGItem('Atlantic cod', 0, belowDetection: _bd),
          IgGItem('Abalone', 11.90),
          IgGItem('Lobster', 9.19),
          IgGItem('Shrimp mix', 6.32),
          IgGItem('Trout', 0, belowDetection: _bd),
          IgGItem('Oyster', 12.91),
          IgGItem('Northern prawn', 0, belowDetection: _bd),
          IgGItem('Scallop', 7.00),
          IgGItem('Razor shell', 7.15),
          IgGItem('European plaice', 0, belowDetection: _bd),
          IgGItem('Thornback ray', 0, belowDetection: _bd),
          IgGItem('Venus clam', 12.50),
          IgGItem('Salmon', 0, belowDetection: _bd),
          IgGItem('European pilchard', 0, belowDetection: _bd),
          IgGItem('Turbot', 5.90),
          IgGItem('Mackerel', 0, belowDetection: _bd),
          IgGItem('Atlantic redfish', 0, belowDetection: _bd),
        ]),

      // ── Summarised in the panel, item detail not yet supplied ──
      IgGCategory(name: 'Cereals & seeds', icon: 'cereal',
        highest: IgGLevel.high, detailPending: true),
      IgGCategory(name: 'Nuts', icon: 'nuts',
        highest: IgGLevel.intermediate, detailPending: true),
      IgGCategory(name: 'Legumes', icon: 'legume',
        highest: IgGLevel.low, detailPending: true),
      IgGCategory(name: 'Fruits', icon: 'fruit',
        highest: IgGLevel.intermediate, detailPending: true),
      IgGCategory(name: 'Vegetables', icon: 'vegetable',
        highest: IgGLevel.intermediate, detailPending: true),
      IgGCategory(name: 'Spices', icon: 'spice',
        highest: IgGLevel.high, detailPending: true),
      IgGCategory(name: 'Edible mushrooms', icon: 'mushroom',
        highest: IgGLevel.low, detailPending: true),
      IgGCategory(name: 'Novel foods', icon: 'novel',
        highest: IgGLevel.intermediate, detailPending: true),
      IgGCategory(name: 'Coffee & tea', icon: 'coffee',
        highest: IgGLevel.intermediate, detailPending: true),
      IgGCategory(name: 'Others', icon: 'other',
        highest: IgGLevel.high, detailPending: true),
    ]);
}
