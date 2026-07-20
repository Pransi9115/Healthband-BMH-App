// ─────────────────────────────────────────────────────────
//  USDA FOODDATA CENTRAL SERVICE
//  Place at: lib/core/diet/usda_food_service.dart
//
//  Live food search backed by https://api.nal.usda.gov/fdc/v1
//  Maps FDC search results straight into the app's FoodItem
//  model (macros + the 11 tracked micronutrients), so results
//  flow through DietService, daily totals and the micronutrient
//  screen with zero model changes.
//
//  API key:
//    Run / build with:
//      flutter run --dart-define=FDC_API_KEY=YOUR_KEY_HERE
//    Get a free key: https://fdc.nal.usda.gov/api-key-signup
//    (Do NOT hardcode the key or commit it — USDA deactivates
//     keys found in public repos.)
//
//  Rate limit: 1,000 requests/hour/IP. The in-memory cache +
//  UI debounce keep normal usage far below this.
// ─────────────────────────────────────────────────────────

import 'package:dio/dio.dart';
import 'diet_models.dart';

class UsdaFoodService {
  UsdaFoodService._();
  static final UsdaFoodService instance = UsdaFoodService._();

  static const _apiKey =
      String.fromEnvironment('FDC_API_KEY', defaultValue: 'DEMO_KEY');

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.nal.usda.gov/fdc/v1',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// Simple session cache: query → results. Cleared on app restart.
  final Map<String, List<FoodItem>> _cache = {};

  /// Search FDC. Returns [] on any failure so the caller can fall
  /// back to the local FoodLibrary without try/catch noise.
  Future<List<FoodItem>> search(String query, {int pageSize = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    final cached = _cache[q];
    if (cached != null) return cached;

    try {
      final res = await _dio.get('/foods/search', queryParameters: {
        'api_key': _apiKey,
        'query': q,
        'pageSize': pageSize,
        // Prefer curated generic data first, then branded products.
        'dataType': 'Foundation,SR Legacy,Branded',
      });

      final foods = (res.data['foods'] as List? ?? const [])
          .map((f) => _toFoodItem(Map<String, dynamic>.from(f as Map)))
          .whereType<FoodItem>()
          .toList();

      _cache[q] = foods;
      return foods;
    } catch (_) {
      return []; // offline / rate-limited / bad key → caller falls back
    }
  }

  // ── MAPPING ────────────────────────────────────────────

  /// FDC nutrient IDs → the micronutrient names used in
  /// Micronutrient.all (diet_models.dart).
  static const _microByNutrientId = <int, String>{
    1162: 'Vitamin C',   // mg
    1114: 'Vitamin D',   // mcg (D2+D3)
    1106: 'Vitamin A',   // mcg RAE
    1178: 'Vitamin B12', // mcg
    1177: 'Folate',      // mcg
    1089: 'Iron',        // mg
    1090: 'Magnesium',   // mg
    1095: 'Zinc',        // mg
    1092: 'Potassium',   // mg
    1087: 'Calcium',     // mg
  };

  // Omega-3 = ALA (18:3 n-3) + EPA (20:5 n-3) + DHA (22:6 n-3), grams.
  static const _omega3Ids = <int>{1404, 1278, 1272};

  FoodItem? _toFoodItem(Map<String, dynamic> f) {
    final fdcId = f['fdcId'];
    final rawName = (f['description'] as String? ?? '').trim();
    if (fdcId == null || rawName.isEmpty) return null;

    double kcal = 0, protein = 0, carbs = 0, fat = 0, sugars = 0, omega3 = 0;
    final micros = <String, double>{};

    for (final n in (f['foodNutrients'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(n as Map);
      final id = m['nutrientId'] as int? ?? -1;
      final value = (m['value'] as num?)?.toDouble() ?? 0;
      final unit = (m['unitName'] as String? ?? '').toUpperCase();

      switch (id) {
        case 1008: // Energy
          if (unit == 'KCAL') kcal = value;
          break;
        case 2047: // Energy (Atwater) — fallback if 1008 missing
          if (kcal == 0) kcal = value;
          break;
        case 1003: protein = value; break;
        case 1005: carbs   = value; break;
        case 1004: fat     = value; break;
        case 2000: sugars  = value; break;
        default:
          if (_omega3Ids.contains(id)) {
            // FDC reports fatty acids in grams.
            omega3 += value;
          } else {
            final micro = _microByNutrientId[id];
            if (micro != null && value > 0) {
              micros[micro] = (micros[micro] ?? 0) + value;
            }
          }
      }
    }
    if (omega3 > 0) micros['Omega-3'] = omega3;

    // Search results report nutrients per 100 g for all data types.
    // Branded foods additionally carry a labelled serving size; if
    // present, scale everything to one serving so the numbers match
    // what the user sees on the package.
    var portion = '100 g';
    final servingSize = (f['servingSize'] as num?)?.toDouble();
    final servingUnit = (f['servingSizeUnit'] as String? ?? '').toLowerCase();
    if (servingSize != null &&
        servingSize > 0 &&
        (servingUnit == 'g' || servingUnit == 'ml')) {
      final k = servingSize / 100.0;
      kcal *= k; protein *= k; carbs *= k; fat *= k; sugars *= k;
      micros.updateAll((_, v) => v * k);
      portion = '${servingSize.round()} $servingUnit serving';
    }

    final brand = (f['brandOwner'] as String? ?? '').trim();
    final name = _titleCase(rawName) + (brand.isNotEmpty ? ' · $brand' : '');

    return FoodItem(
      id: 'fdc_$fdcId', // never collides with local FoodLibrary ids
      name: name,
      portion: portion,
      kcal: _r(kcal),
      proteinG: _r(protein),
      carbsG: _r(carbs),
      fatG: _r(fat),
      sugarsG: _r(sugars),
      micros: micros.map((k, v) => MapEntry(k, _r(v))),
    );
  }

  static double _r(double v) => (v * 10).roundToDouble() / 10;

  static String _titleCase(String s) {
    final lower = s.toLowerCase();
    return lower.isEmpty ? s : lower[0].toUpperCase() + lower.substring(1);
  }
}
