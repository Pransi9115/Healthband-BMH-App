// ─────────────────────────────────────────────────────────
//  BIORESPONSE — BLOOD REPORT
//
//  Holds the blood panel BMH runs for the patient. In production
//  the super admin dashboard uploads a report and the app pulls
//  it as JSON; the shape it must send is documented in
//  [BloodReport.fromJson] and mirrored by [sampleReport] below.
//
//  Nothing here is computed from the patient's phone — a blood
//  result is a laboratory fact with a test date, not a live
//  reading. That is why the per day / per week range in the
//  Biomarkers screen applies to intake only.
// ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── STATUS ────────────────────────────────────────────────
enum MarkerStatus { low, borderline, inRange, high }

extension MarkerStatusX on MarkerStatus {
  String get label => switch (this) {
        MarkerStatus.low => 'LOW',
        MarkerStatus.borderline => 'BORDERLINE',
        MarkerStatus.inRange => 'IN RANGE',
        MarkerStatus.high => 'HIGH',
      };
}

// ── ONE MARKER ────────────────────────────────────────────
class BloodMarker {
  final String key;
  final String name;
  final double value;
  final String unit;
  final double refLow;
  final double refHigh;
  final String group;
  final String note;

  /// Flagged by the reporting clinician as needing attention.
  final bool priority;

  /// Some markers are good when they sit above the reference top —
  /// HDL is the classic case. Marked so the app never shows a
  /// protective finding as a red alert.
  final bool highIsGood;

  const BloodMarker({
    required this.key,
    required this.name,
    required this.value,
    required this.unit,
    required this.refLow,
    required this.refHigh,
    required this.group,
    this.note = '',
    this.priority = false,
    this.highIsGood = false,
  });

  /// Status is derived from the range, never stored — so a report
  /// can never disagree with its own numbers.
  MarkerStatus get status {
    if (value < refLow) return MarkerStatus.low;
    if (value > refHigh) return MarkerStatus.high;
    final span = refHigh - refLow;
    if (span > 0) {
      final edge = span * 0.05;
      if (value <= refLow + edge || value >= refHigh - edge) {
        return MarkerStatus.borderline;
      }
    }
    return MarkerStatus.inRange;
  }

  /// Out of range AND unwelcome. HDL above range is not a concern.
  bool get isConcern {
    final s = status;
    if (s == MarkerStatus.high && highIsGood) return false;
    return s == MarkerStatus.high || s == MarkerStatus.low;
  }

  /// 0–1 position of the result along the reference bar, with a
  /// margin either side so out-of-range values stay visible.
  double get barPosition {
    final span = refHigh - refLow;
    if (span <= 0) return 0.5;
    final lo = refLow - span * 0.35;
    final hi = refHigh + span * 0.35;
    return ((value - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  double get zoneStart {
    final span = refHigh - refLow;
    final lo = refLow - span * 0.35;
    final hi = refHigh + span * 0.35;
    return ((refLow - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  double get zoneEnd {
    final span = refHigh - refLow;
    final lo = refLow - span * 0.35;
    final hi = refHigh + span * 0.35;
    return ((refHigh - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'key': key, 'name': name, 'value': value, 'unit': unit,
        'ref_low': refLow, 'ref_high': refHigh, 'group': group,
        'note': note, 'priority': priority, 'high_is_good': highIsGood,
      };

  factory BloodMarker.fromJson(Map<String, dynamic> j) => BloodMarker(
        key: j['key'] as String,
        name: j['name'] as String,
        value: (j['value'] as num).toDouble(),
        unit: j['unit'] as String? ?? '',
        refLow: (j['ref_low'] as num?)?.toDouble() ?? 0,
        refHigh: (j['ref_high'] as num?)?.toDouble() ?? 0,
        group: j['group'] as String? ?? 'Other',
        note: j['note'] as String? ?? '',
        priority: j['priority'] as bool? ?? false,
        highIsGood: j['high_is_good'] as bool? ?? false,
      );
}

// ── ONE REPORT ────────────────────────────────────────────
class BloodReport {
  final String id;
  final String testName;
  final DateTime testDate;
  final String clinicalContext;
  final List<BloodMarker> markers;
  final List<String> recommendations;

  const BloodReport({
    required this.id,
    required this.testName,
    required this.testDate,
    required this.markers,
    this.clinicalContext = '',
    this.recommendations = const [],
  });

  int get totalCount => markers.length;
  int get concernCount => markers.where((m) => m.isConcern).length;

  /// Of the out-of-range markers, how many the reporting clinician
  /// flagged as needing attention first.
  int get priorityCount =>
      markers.where((m) => m.isConcern && m.priority).length;

  /// Above range but welcome — HDL is the usual case. Counted
  /// separately so a good finding is never shown as a red alert.
  int get favourableCount => markers
      .where((m) => m.status == MarkerStatus.high && m.highIsGood)
      .length;

  int get borderlineCount =>
      markers.where((m) => m.status == MarkerStatus.borderline).length;
  int get inRangeCount => totalCount - concernCount - borderlineCount;

  List<BloodMarker> get concerns =>
      markers.where((m) => m.isConcern).toList()
        ..sort((a, b) => (b.priority ? 1 : 0).compareTo(a.priority ? 1 : 0));

  List<String> get groups {
    final out = <String>[];
    for (final m in markers) {
      if (!out.contains(m.group)) out.add(m.group);
    }
    return out;
  }

  List<BloodMarker> inGroup(String g) =>
      markers.where((m) => m.group == g).toList();

  BloodMarker? byKey(String k) {
    for (final m in markers) {
      if (m.key == k) return m;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'test_name': testName,
        'test_date': testDate.toIso8601String(),
        'clinical_context': clinicalContext,
        'markers': markers.map((m) => m.toJson()).toList(),
        'recommendations': recommendations,
      };

  /// The exact shape the super admin dashboard should POST:
  /// {
  ///   "id": "rpt_2026_03_11",
  ///   "test_name": "Well Man Blood Profile",
  ///   "test_date": "2026-03-11",
  ///   "clinical_context": "…",
  ///   "markers": [ { "key":"vitamin_d", "name":"Vitamin D",
  ///                  "value":42, "unit":"nmol/L",
  ///                  "ref_low":50, "ref_high":200,
  ///                  "group":"Vitamins & minerals",
  ///                  "note":"…", "priority":true,
  ///                  "high_is_good":false }, … ],
  ///   "recommendations": [ "…", "…" ]
  /// }
  factory BloodReport.fromJson(Map<String, dynamic> j) => BloodReport(
        id: j['id'] as String? ?? 'report',
        testName: j['test_name'] as String? ?? 'Blood profile',
        testDate:
            DateTime.tryParse(j['test_date'] as String? ?? '') ?? DateTime.now(),
        clinicalContext: j['clinical_context'] as String? ?? '',
        markers: ((j['markers'] as List?) ?? [])
            .map((e) => BloodMarker.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        recommendations:
            ((j['recommendations'] as List?) ?? []).cast<String>().toList(),
      );
}

// ─────────────────────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────────────────────
class BloodReportService extends ChangeNotifier {
  BloodReportService._();
  static final BloodReportService instance = BloodReportService._();

  static const _kReport = 'bmh_blood_report_v1';

  SharedPreferences? _prefs;
  BloodReport? _report;
  bool _ready = false;

  BloodReport? get report => _report;
  bool get hasReport => _report != null;
  bool get isReady => _ready;

  /// True while the app is showing the seeded example panel rather
  /// than a report uploaded for this patient. The UI labels it so
  /// nobody mistakes sample data for their own results.
  bool get isSample => _report?.id == sampleReport.id;

  Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_kReport);
    if (raw != null) {
      try {
        _report = BloodReport.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {
        _report = null;
      }
    }
    // Until the admin dashboard upload is live, fall back to the
    // example panel so the feature can be reviewed end to end.
    _report ??= sampleReport;
    _ready = true;
    notifyListeners();
  }

  /// Called when a report arrives from the admin dashboard.
  Future<void> setReport(BloodReport r) async {
    _report = r;
    await _prefs?.setString(_kReport, jsonEncode(r.toJson()));
    notifyListeners();
  }

  Future<void> clear() async {
    await _prefs?.remove(_kReport);
    _report = sampleReport;
    notifyListeners();
  }

  // ── SEED: the Well Man panel supplied by BMH ────────────
  static final BloodReport sampleReport = BloodReport(
    id: 'sample_wellman_2026_03_11',
    testName: 'Well Man Blood Profile',
    testDate: DateTime(2026, 3, 11),
    clinicalContext:
        'Trains seven days per week with high-volume, high-intensity '
        'sessions and a high-protein diet. Presenting complaint is '
        'persistent fatigue. All findings are read in that context.',
    recommendations: [
      'Introduce structured rest days — train a maximum of five days per '
          'week with two full rest or active-recovery days.',
      'Start Vitamin D3 supplementation after GP review; retest in 8–12 weeks.',
      'Review diet to reduce saturated fat; add oily fish, legumes and lentils.',
      'Reduce or pause B12 supplementation and retest in 3 months.',
      'Retest CK and AST after a recovery week to confirm overtraining.',
      'Reassess the full lipid panel in 3–6 months.',
    ],
    markers: const [
      // ── Muscle ──
      BloodMarker(key: 'ck', name: 'CK — Creatine Kinase', value: 937,
        unit: 'IU/L', refLow: 38, refHigh: 204, group: 'Muscle',
        priority: true,
        note: '4.6x the male upper limit. CK leaks from damaged muscle '
            'fibres; training seven days a week keeps muscle in a '
            'catabolic state. Structured rest is urgently required.'),

      // ── Vitamins & minerals ──
      BloodMarker(key: 'vitamin_d', name: 'Vitamin D', value: 42,
        unit: 'nmol/L', refLow: 50, refHigh: 200,
        group: 'Vitamins & minerals', priority: true,
        note: 'Insufficient. Critical for muscle function, immunity and '
            'energy, and a major correctable cause of fatigue.'),
      BloodMarker(key: 'vitamin_b12', name: 'Vitamin B12', value: 211.4,
        unit: 'pmol/L', refLow: 25.1, refHigh: 165,
        group: 'Vitamins & minerals', priority: true,
        note: 'Above the upper limit, almost certainly from '
            'over-supplementation. Reduce or pause and retest in 3 months.'),
      BloodMarker(key: 'folate', name: 'Folate', value: 14.3,
        unit: 'ug/L', refLow: 2.9, refHigh: 20,
        group: 'Vitamins & minerals',
        note: 'Adequate for red blood cell production and DNA repair.'),
      BloodMarker(key: 'magnesium', name: 'Magnesium', value: 0.80,
        unit: 'mmol/L', refLow: 0.6, refHigh: 1.0,
        group: 'Vitamins & minerals',
        note: 'Supports muscle contraction, nerve function and energy '
            'metabolism.'),
      BloodMarker(key: 'calcium', name: 'Calcium', value: 2.46,
        unit: 'mmol/L', refLow: 2.2, refHigh: 2.6,
        group: 'Vitamins & minerals',
        note: 'Bone and muscle calcium signalling is adequate.'),
      BloodMarker(key: 'calcium_corrected', name: 'Corrected Calcium',
        value: 2.47, unit: 'mmol/L', refLow: 2.2, refHigh: 2.6,
        group: 'Vitamins & minerals',
        note: 'Albumin-adjusted — confirms the raw result is accurate.'),

      // ── Iron panel ──
      BloodMarker(key: 'iron', name: 'Iron', value: 13.0,
        unit: 'umol/L', refLow: 10.6, refHigh: 28.3, group: 'Iron panel',
        note: 'Adequate iron for the training load.'),
      BloodMarker(key: 'ferritin', name: 'Ferritin', value: 100,
        unit: 'ug/L', refLow: 30, refHigh: 400, group: 'Iron panel',
        note: 'Iron storage protein well within range.'),
      BloodMarker(key: 'tibc', name: 'T.I.B.C', value: 63,
        unit: 'umol/L', refLow: 41, refHigh: 77, group: 'Iron panel',
        note: 'Iron-binding capacity normal.'),
      BloodMarker(key: 'transferrin_sat', name: 'Transferrin Saturation',
        value: 21, unit: '%', refLow: 20, refHigh: 55, group: 'Iron panel',
        note: 'Just above the lower boundary — iron transport is adequate.'),

      // ── Cardiovascular & lipids ──
      BloodMarker(key: 'cholesterol_total', name: 'Cholesterol (Total)',
        value: 5.6, unit: 'mmol/L', refLow: 0, refHigh: 5,
        group: 'Cardiovascular & lipids',
        note: 'Above the 5.0 target, likely diet-related saturated fat.'),
      BloodMarker(key: 'ldl', name: 'LDL Cholesterol', value: 3.5,
        unit: 'mmol/L', refLow: 0, refHigh: 3,
        group: 'Cardiovascular & lipids',
        note: 'Above target. Reduce red meat, increase oily fish and '
            'plant protein.'),
      BloodMarker(key: 'hdl', name: 'HDL Cholesterol', value: 1.8,
        unit: 'mmol/L', refLow: 0.9, refHigh: 1.5,
        group: 'Cardiovascular & lipids', highIsGood: true,
        note: 'Above the reference top, and that is a positive finding. '
            'High HDL is common in trained athletes and protects the heart.'),
      BloodMarker(key: 'non_hdl', name: 'Non-HDL Cholesterol', value: 3.8,
        unit: 'mmol/L', refLow: 0, refHigh: 3.9,
        group: 'Cardiovascular & lipids',
        note: 'Just within range; improves alongside LDL with diet change.'),
      BloodMarker(key: 'triglycerides', name: 'Triglycerides', value: 0.6,
        unit: 'mmol/L', refLow: 0, refHigh: 2.3,
        group: 'Cardiovascular & lipids',
        note: 'Very low — efficient fat metabolism, typical of fit athletes.'),
      BloodMarker(key: 'hs_crp', name: 'hs-CRP', value: 0.3,
        unit: 'mg/L', refLow: 0, refHigh: 5,
        group: 'Cardiovascular & lipids',
        note: 'Inflammation very low despite heavy training.'),

      // ── Liver ──
      BloodMarker(key: 'alt', name: 'Alanine Transferase (ALT)', value: 39,
        unit: 'IU/L', refLow: 10, refHigh: 50, group: 'Liver',
        note: 'Within the male range. No evidence of liver stress.'),
      BloodMarker(key: 'alp', name: 'Alkaline Phosphatase (ALP)', value: 67,
        unit: 'IU/L', refLow: 40, refHigh: 129, group: 'Liver',
        note: 'Bone/liver enzyme in range.'),
      BloodMarker(key: 'ast', name: 'Aspartate Aminotransferase (AST)',
        value: 49, unit: 'IU/L', refLow: 0, refHigh: 37, group: 'Liver',
        priority: true,
        note: 'Elevated, but with CK at 937 this almost certainly reflects '
            'muscle-origin AST, not liver damage. Retest after rest.'),
      BloodMarker(key: 'ggt', name: 'Gamma GT', value: 27,
        unit: 'IU/L', refLow: 10, refHigh: 71, group: 'Liver',
        note: 'Well within range.'),
      BloodMarker(key: 'bilirubin', name: 'Bilirubin', value: 8,
        unit: 'umol/L', refLow: 0, refHigh: 20, group: 'Liver',
        note: 'Normal red blood cell breakdown product.'),
      BloodMarker(key: 'albumin', name: 'Albumin', value: 45,
        unit: 'g/L', refLow: 35, refHigh: 50, group: 'Liver',
        note: 'Good nutritional and liver function indicator.'),
      BloodMarker(key: 'globulin', name: 'Globulin', value: 30,
        unit: 'g/L', refLow: 19, refHigh: 35, group: 'Liver',
        note: 'Immune and transport proteins within range.'),
      BloodMarker(key: 'total_protein', name: 'Total Protein', value: 75,
        unit: 'g/L', refLow: 63, refHigh: 83, group: 'Liver',
        note: 'Adequate protein status confirmed.'),

      // ── Kidney ──
      BloodMarker(key: 'creatinine', name: 'Creatinine', value: 105,
        unit: 'umol/L', refLow: 59, refHigh: 104, group: 'Kidney',
        note: 'Just above the male upper limit. In an athlete with high '
            'muscle mass and protein intake this is expected; eGFR of 78 '
            'confirms adequate filtering.'),
      BloodMarker(key: 'egfr', name: 'eGFR', value: 78,
        unit: 'ml/min/1.73m2', refLow: 60, refHigh: 120, group: 'Kidney',
        note: 'Kidney filtration adequate.'),
      BloodMarker(key: 'urea', name: 'Urea', value: 5.8,
        unit: 'mmol/L', refLow: 1.7, refHigh: 8.3, group: 'Kidney',
        note: 'High protein intake is not straining the kidneys.'),
      BloodMarker(key: 'uric_acid', name: 'Uric Acid', value: 315,
        unit: 'umol/L', refLow: 266, refHigh: 474, group: 'Kidney',
        note: 'Normal. No gout risk at this level.'),

      // ── Thyroid ──
      BloodMarker(key: 'tsh', name: 'TSH', value: 3.01,
        unit: 'mIU/L', refLow: 0.27, refHigh: 4.2, group: 'Thyroid',
        note: 'Normal. Not contributing to fatigue.'),
      BloodMarker(key: 'ft4', name: 'FT4 (Free Thyroxine)', value: 15.2,
        unit: 'pmol/L', refLow: 12, refHigh: 22, group: 'Thyroid',
        note: 'Thyroid hormone output is normal.'),

      // ── Blood sugar ──
      BloodMarker(key: 'hba1c', name: 'HbA1c', value: 39,
        unit: 'mmol/mol', refLow: 20, refHigh: 41, group: 'Blood sugar',
        note: 'Well within the non-diabetic range.'),

      // ── Hormones ──
      BloodMarker(key: 'testosterone', name: 'Testosterone', value: 22.6,
        unit: 'nmol/L', refLow: 7.6, refHigh: 31.4, group: 'Hormones',
        note: 'Upper half of the male range. No hormonal suppression.'),

      // ── Red blood cells ──
      BloodMarker(key: 'haemoglobin', name: 'Haemoglobin', value: 164,
        unit: 'g/L', refLow: 130, refHigh: 170, group: 'Red blood cells',
        note: 'Oxygen-carrying protein healthy. No anaemia.'),
      BloodMarker(key: 'rbc', name: 'Red Blood Cells (RBC)', value: 5.48,
        unit: 'x10^12/L', refLow: 4.4, refHigh: 5.8,
        group: 'Red blood cells', note: 'Good oxygen delivery capacity.'),
      BloodMarker(key: 'hct', name: 'HCT — Haematocrit', value: 0.475,
        unit: '', refLow: 0.38, refHigh: 0.5, group: 'Red blood cells',
        note: 'Normal male range.'),
      BloodMarker(key: 'mcv', name: 'MCV', value: 86.7,
        unit: 'fl', refLow: 80, refHigh: 99, group: 'Red blood cells',
        note: 'Average red cell size normal.'),
      BloodMarker(key: 'mch', name: 'MCH', value: 29.9,
        unit: 'pg', refLow: 27, refHigh: 33.5, group: 'Red blood cells',
        note: 'Average haemoglobin per cell normal.'),
      BloodMarker(key: 'mchc', name: 'MCHC', value: 345,
        unit: 'g/L', refLow: 300, refHigh: 350, group: 'Red blood cells',
        note: 'Haemoglobin concentration within cells normal.'),
      BloodMarker(key: 'rdw', name: 'RDW', value: 11.9,
        unit: '', refLow: 11.5, refHigh: 15, group: 'Red blood cells',
        note: 'Red cell size variability normal.'),
      BloodMarker(key: 'platelets', name: 'Platelets', value: 271,
        unit: 'x10^9/L', refLow: 150, refHigh: 400,
        group: 'Red blood cells', note: 'Clotting function adequate.'),
      BloodMarker(key: 'mpv', name: 'MPV', value: 9.8,
        unit: 'fl', refLow: 7, refHigh: 13, group: 'Red blood cells',
        note: 'Mean platelet volume normal.'),

      // ── White blood cells ──
      BloodMarker(key: 'wbc', name: 'White Blood Cells (WBC)', value: 4.95,
        unit: 'x10^9/L', refLow: 3, refHigh: 10,
        group: 'White blood cells', note: 'Total white cell count normal.'),
      BloodMarker(key: 'neutrophils', name: 'Neutrophils', value: 1.91,
        unit: 'x10^9/L', refLow: 2, refHigh: 7.5,
        group: 'White blood cells', priority: true,
        note: 'Below the lower limit. Neutropenia in high-volume athletes '
            'is a recognised marker of overtraining and should normalise '
            'with structured rest.'),
      BloodMarker(key: 'lymphocytes', name: 'Lymphocytes', value: 2.28,
        unit: 'x10^9/L', refLow: 1.2, refHigh: 3.65,
        group: 'White blood cells', note: 'Adaptive immune cells in range.'),
      BloodMarker(key: 'monocytes', name: 'Monocytes', value: 0.42,
        unit: 'x10^9/L', refLow: 0.2, refHigh: 1,
        group: 'White blood cells', note: 'Monocyte count normal.'),
      BloodMarker(key: 'eosinophils', name: 'Eosinophils', value: 0.26,
        unit: 'x10^9/L', refLow: 0, refHigh: 0.4,
        group: 'White blood cells',
        note: 'No allergic or parasitic response indicated.'),
      BloodMarker(key: 'basophils', name: 'Basophils', value: 0.08,
        unit: 'x10^9/L', refLow: 0, refHigh: 0.1,
        group: 'White blood cells', note: 'No mast cell disorder indicated.'),
    ],
  );
}
