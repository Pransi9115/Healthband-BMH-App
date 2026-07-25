// ─────────────────────────────────────────────────────────
//  BIORESPONSE — BLOOD REPORT
//
//  Holds the blood panel BMH runs for the patient. In production
//  the super admin dashboard uploads a report and the app pulls
//  it as JSON; the shape it must send is documented in
//  [BloodReport.fromJson] and mirrored by [sampleReport] below.
//
//  The seeded panel is the real 48-marker Well Man profile of
//  11 March 2026, carried across from the printed "Blood results
//  explained" report so the app and the document read the same:
//  same values, same reference text, same plain-English meaning,
//  same next steps.
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

  /// The wording the printed report uses, which is gentler than
  /// the bare status and is what the patient actually reads.
  String get reportLabel => switch (this) {
        MarkerStatus.low => 'Below the range',
        MarkerStatus.borderline => 'Keep an eye on',
        MarkerStatus.inRange => 'In range',
        MarkerStatus.high => 'Above the range',
      };
}

// ── ONE MARKER ────────────────────────────────────────────
class BloodMarker {
  final String key;
  final String name;

  /// One-line plain-English gloss printed under the marker name in
  /// the report, e.g. "The oxygen carrying protein".
  final String alias;

  final double value;
  final String unit;
  final double refLow;
  final double refHigh;

  /// The reference range exactly as the laboratory printed it —
  /// "Up to 3.0", "60 and above", "130 to 170". Shown verbatim so
  /// an open-ended range is never redrawn as a two-sided one.
  final String refText;

  final String group;

  /// The plain-English explanation of what the marker is and what
  /// this particular result means.
  final String note;

  /// What the report suggests doing about this result.
  final List<String> actions;

  /// For differential white cell counts — "38.5% of white cells".
  final String share;

  /// Flagged by the reporting clinician as needing attention.
  final bool priority;

  /// A result that sits inside its printed range but which the
  /// laboratory's own interpretation bands still put in the
  /// keep-an-eye-on zone. eGFR is the case here: 78 is above the
  /// 60 floor, yet below the 90 the lab treats as unremarkable.
  final bool forceWatch;

  /// Above range but welcome, so the app never shows it as a fault.
  /// HDL is the classic case.
  final bool highIsGood;

  const BloodMarker({
    required this.key,
    required this.name,
    required this.value,
    required this.refLow,
    required this.refHigh,
    required this.group,
    this.alias = '',
    this.unit = '',
    this.refText = '',
    this.note = '',
    this.actions = const [],
    this.share = '',
    this.priority = false,
    this.forceWatch = false,
    this.highIsGood = false,
  });

  /// Status is derived from the range, never stored — so a report
  /// can never disagree with its own numbers. The one exception is
  /// [forceWatch], which lets a laboratory interpretation band tighten
  /// a result the printed range alone would call normal.
  MarkerStatus get status {
    if (value < refLow) return MarkerStatus.low;
    if (value > refHigh) return MarkerStatus.high;
    if (forceWatch) return MarkerStatus.borderline;
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

  /// Above range and a good thing — shown in green, never in red.
  bool get isFavourable =>
      status == MarkerStatus.high && highIsGood;

  /// Outside the printed reference range in either direction,
  /// whether that is welcome or not. This is the count the report
  /// quotes in its own summary line.
  bool get isOutsideRange => value < refLow || value > refHigh;

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
        'key': key, 'name': name, 'alias': alias,
        'value': value, 'unit': unit,
        'ref_low': refLow, 'ref_high': refHigh, 'ref_text': refText,
        'group': group, 'note': note, 'actions': actions,
        'share': share, 'priority': priority,
        'force_watch': forceWatch, 'high_is_good': highIsGood,
      };

  factory BloodMarker.fromJson(Map<String, dynamic> j) => BloodMarker(
        key: j['key'] as String,
        name: j['name'] as String,
        alias: j['alias'] as String? ?? '',
        value: (j['value'] as num).toDouble(),
        unit: j['unit'] as String? ?? '',
        refLow: (j['ref_low'] as num?)?.toDouble() ?? 0,
        refHigh: (j['ref_high'] as num?)?.toDouble() ?? 0,
        refText: j['ref_text'] as String? ?? '',
        group: j['group'] as String? ?? 'Other',
        note: j['note'] as String? ?? '',
        actions: ((j['actions'] as List?) ?? []).cast<String>().toList(),
        share: j['share'] as String? ?? '',
        priority: j['priority'] as bool? ?? false,
        forceWatch: j['force_watch'] as bool? ?? false,
        highIsGood: j['high_is_good'] as bool? ?? false,
      );
}

// ── ONE OF THE THREADS THE REPORT OPENS WITH ──────────────
/// The "read this first" section: a handful of themes that tie
/// several markers together, so the patient meets the story before
/// the table of numbers.
class ReportThread {
  final String tag;
  final String lede;
  final String body;
  const ReportThread({
    required this.tag,
    required this.lede,
    required this.body,
  });

  Map<String, dynamic> toJson() =>
      {'tag': tag, 'lede': lede, 'body': body};

  factory ReportThread.fromJson(Map<String, dynamic> j) => ReportThread(
        tag: j['tag'] as String? ?? '',
        lede: j['lede'] as String? ?? '',
        body: j['body'] as String? ?? '',
      );
}

// ── ONE NUMBERED NEXT STEP ────────────────────────────────
class ReportStep {
  final String title;
  final String detail;

  /// Step six on this panel is a safety-netting instruction rather
  /// than a routine action, and is shown as a warning.
  final bool urgent;

  const ReportStep({
    required this.title,
    required this.detail,
    this.urgent = false,
  });

  Map<String, dynamic> toJson() =>
      {'title': title, 'detail': detail, 'urgent': urgent};

  factory ReportStep.fromJson(Map<String, dynamic> j) => ReportStep(
        title: j['title'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
        urgent: j['urgent'] as bool? ?? false,
      );
}

// ── ONE REPORT ────────────────────────────────────────────
class BloodReport {
  final String id;
  final String testName;
  final DateTime testDate;

  /// Laboratory provenance, printed on the report and shown in the
  /// app so the patient can match one to the other.
  final String labName;
  final String labRef;
  final String reportedOn;
  final String sampleTakenAt;
  final int ageAtTest;

  /// The opening line of the report — "Curtis, here is what your
  /// blood is telling you." minus the name, which the app already has.
  final String headline;
  final String summary;

  final String clinicalContext;
  final List<ReportThread> threads;
  final List<BloodMarker> markers;
  final List<String> recommendations;
  final List<ReportStep> steps;

  const BloodReport({
    required this.id,
    required this.testName,
    required this.testDate,
    required this.markers,
    this.labName = '',
    this.labRef = '',
    this.reportedOn = '',
    this.sampleTakenAt = '',
    this.ageAtTest = 0,
    this.headline = '',
    this.summary = '',
    this.clinicalContext = '',
    this.threads = const [],
    this.recommendations = const [],
    this.steps = const [],
  });

  int get totalCount => markers.length;
  int get concernCount => markers.where((m) => m.isConcern).length;

  /// Of the out-of-range markers, how many the reporting clinician
  /// flagged as needing attention first.
  int get priorityCount =>
      markers.where((m) => m.isConcern && m.priority).length;

  /// Above range but welcome — HDL is the usual case. Counted
  /// separately so a good finding is never shown as a red alert.
  int get favourableCount => markers.where((m) => m.isFavourable).length;

  int get borderlineCount =>
      markers.where((m) => m.status == MarkerStatus.borderline).length;
  int get inRangeCount => totalCount - concernCount - borderlineCount;

  /// Everything outside the printed range, welcome or not. This is
  /// the number the report's own summary sentence quotes.
  int get outsideRangeCount =>
      markers.where((m) => m.isOutsideRange).length;

  List<BloodMarker> get concerns =>
      markers.where((m) => m.isConcern).toList()
        ..sort((a, b) => (b.priority ? 1 : 0).compareTo(a.priority ? 1 : 0));

  /// Everything the report draws attention to, in reading order:
  /// discuss first, then keep an eye on, then the good news.
  List<BloodMarker> get flagged => markers
      .where((m) =>
          m.isConcern ||
          m.isFavourable ||
          m.status == MarkerStatus.borderline)
      .toList()
    ..sort((a, b) => _rank(a).compareTo(_rank(b)));

  static int _rank(BloodMarker m) {
    if (m.isConcern && m.priority) return 0;
    if (m.isConcern) return 1;
    if (m.status == MarkerStatus.borderline) return 2;
    return 3;
  }

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
        'lab_name': labName,
        'lab_ref': labRef,
        'reported_on': reportedOn,
        'sample_taken_at': sampleTakenAt,
        'age_at_test': ageAtTest,
        'headline': headline,
        'summary': summary,
        'clinical_context': clinicalContext,
        'threads': threads.map((t) => t.toJson()).toList(),
        'markers': markers.map((m) => m.toJson()).toList(),
        'recommendations': recommendations,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  /// The exact shape the super admin dashboard should POST:
  /// {
  ///   "id": "rpt_2026_03_11",
  ///   "test_name": "Well Man Blood Profile",
  ///   "test_date": "2026-03-11",
  ///   "lab_name": "The Doctors Laboratory",
  ///   "lab_ref": "26T185954",
  ///   "summary": "…",
  ///   "threads":  [ { "tag":"Muscle", "lede":"…", "body":"…" }, … ],
  ///   "markers": [ { "key":"vitamin_d", "name":"Vitamin D",
  ///                  "alias":"…", "value":42, "unit":"nmol/L",
  ///                  "ref_low":50, "ref_high":200,
  ///                  "ref_text":"50 to 200",
  ///                  "group":"Vitamins",
  ///                  "note":"…", "actions":["…"],
  ///                  "priority":true,
  ///                  "high_is_good":false }, … ],
  ///   "steps": [ { "title":"…", "detail":"…", "urgent":false }, … ]
  /// }
  factory BloodReport.fromJson(Map<String, dynamic> j) => BloodReport(
        id: j['id'] as String? ?? 'report',
        testName: j['test_name'] as String? ?? 'Blood profile',
        testDate:
            DateTime.tryParse(j['test_date'] as String? ?? '') ?? DateTime.now(),
        labName: j['lab_name'] as String? ?? '',
        labRef: j['lab_ref'] as String? ?? '',
        reportedOn: j['reported_on'] as String? ?? '',
        sampleTakenAt: j['sample_taken_at'] as String? ?? '',
        ageAtTest: (j['age_at_test'] as num?)?.toInt() ?? 0,
        headline: j['headline'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        clinicalContext: j['clinical_context'] as String? ?? '',
        threads: ((j['threads'] as List?) ?? [])
            .map((e) => ReportThread.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        markers: ((j['markers'] as List?) ?? [])
            .map((e) => BloodMarker.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        recommendations:
            ((j['recommendations'] as List?) ?? []).cast<String>().toList(),
        steps: ((j['steps'] as List?) ?? [])
            .map((e) => ReportStep.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
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

  /// True while the app is showing the seeded panel rather than a
  /// report uploaded for this patient.
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
    // seeded panel so the feature can be reviewed end to end.
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

  // ─────────────────────────────────────────────────────────
  //  SEED — the Well Man panel of 11 March 2026, all 48 markers,
  //  carried across from the printed report.
  // ─────────────────────────────────────────────────────────
  static final BloodReport sampleReport = BloodReport(
    id: 'wellman_2026_03_11',
    testName: 'Well Man Blood Profile',
    testDate: DateTime(2026, 3, 11),
    labName: 'The Doctors Laboratory',
    labRef: '26T185954',
    sampleTakenAt: '11 Mar 2026, 07:25',
    reportedOn: '12 Mar 2026',
    ageAtTest: 37,
    headline: 'Here is what your blood is telling you.',
    summary:
        'Forty eight measurements from a single sample taken on '
        '11 March 2026. Every one of them is explained below in plain '
        'English, with what you can do next.',
    clinicalContext:
        'Three threads run through this panel. Everything else sits '
        'comfortably in range.',
    threads: const [
      ReportThread(
        tag: 'Muscle',
        lede:
            'Your creatine kinase, AST and creatinine all point the same '
            'way, and it is very likely muscle rather than illness.',
        body:
            'Creatine kinase leaks out of muscle fibres after hard '
            'training and yours is around four and a half times the usual '
            'ceiling. AST and creatinine both rise alongside it for the '
            'same reason. The liver specific enzyme ALT is normal, which '
            'is the reassuring detail. The clean way to settle this is to '
            'repeat these three after five to seven days without heavy '
            'training. Tell your doctor if you had a hard session in the '
            'days before the draw, because it changes how the whole set '
            'is read.',
      ),
      ReportThread(
        tag: 'Vitamin D',
        lede:
            'At 42 nmol/L you sit in the insufficient band, just below '
            'the 50 mark.',
        body:
            'This is the single easiest number on the page to move, and '
            'it is common in the UK for most of the year. Your lab has '
            'printed its own interpretation bands, which you can see on '
            'that card below.',
      ),
      ReportThread(
        tag: 'Strong',
        lede: 'A lot here is genuinely good.',
        body:
            'Your inflammation marker is close to zero, triglycerides are '
            'low, HDL is high, iron stores are healthy, thyroid and '
            'testosterone are mid range, and blood sugar sits inside the '
            'normal band. Your LDL and total cholesterol are modestly '
            'above target and are worth a plan, though your non HDL '
            'cholesterol, which is the number many clinicians now prefer, '
            'is inside target.',
      ),
    ],
    steps: const [
      ReportStep(
        title: 'Book a review of this panel with a doctor.',
        detail:
            'Bring the original signed laboratory report. The muscle '
            'enzyme picture and the kidney estimate are best interpreted '
            'by someone who can ask you about your training, your '
            'medicines and your supplements.',
      ),
      ReportStep(
        title:
            'Repeat creatine kinase, AST and creatinine after a rest week.',
        detail:
            'Five to seven days with no heavy lifting or long runs, well '
            'hydrated, ideally fasted and at a similar time of day.',
      ),
      ReportStep(
        title: 'Address vitamin D.',
        detail:
            'Ask your doctor about a suitable dose and retest in about '
            'twelve weeks. Daylight on skin and oily fish help, though in '
            'the UK diet alone rarely closes the gap in winter.',
      ),
      ReportStep(
        title: 'Review your B12 supplement.',
        detail:
            'Your active B12 is above range, which almost always reflects '
            'a supplement or an injection rather than anything '
            'concerning. Worth confirming the dose is still the one you '
            'need.',
      ),
      ReportStep(
        title: 'Give LDL cholesterol a twelve week plan.',
        detail:
            'Soluble fibre, plant sterols, oily fish, less saturated fat, '
            'and a retest to see the shape of the response. Your low '
            'triglycerides and high HDL are a strong starting position.',
      ),
      ReportStep(
        urgent: true,
        title: 'Seek urgent medical advice',
        detail:
            'if you develop severe muscle pain with weakness, dark cola '
            'coloured urine, or a marked drop in how much you pass. Those '
            'symptoms alongside a raised creatine kinase need same day '
            'assessment.',
      ),
    ],
    recommendations: const [
      'Book a review of this panel with a doctor and bring the signed '
          'laboratory report.',
      'Repeat creatine kinase, AST and creatinine after five to seven '
          'days without heavy training.',
      'Address vitamin D with your doctor and retest in about twelve '
          'weeks.',
      'Confirm your B12 supplement dose is still the one you need.',
      'Give LDL cholesterol a twelve week plan and retest.',
    ],
    markers: [
    // ── Oxygen carrying and red cells ──
    BloodMarker(
      key: 'haemoglobin',
      name: 'Haemoglobin',
      alias: 'The oxygen carrying protein',
      value: 164.0,
      unit: 'g/L',
      refLow: 130.0, refHigh: 170.0,
      refText: '130 to 170',
      group: 'Oxygen carrying and red cells',
      note:
          'Haemoglobin is the iron rich protein inside red blood cells that '
          'binds oxygen at the lungs and releases it in your tissues. It is '
          'the single best measure of your blood\'s carrying capacity, and '
          'low levels are what people mean by anaemia. Yours sits in the '
          'upper part of the healthy male range, which fits a well '
          'nourished, iron replete, physically active person.',
      actions: [
        'Keep iron rich foods in regular rotation, such as red meat, '
        'pulses, dark leafy greens and fortified cereals.',
        'No action needed on this result.',
      ],
    ),
    BloodMarker(
      key: 'haematocrit',
      name: 'Haematocrit',
      alias: 'Proportion of blood made of red cells',
      value: 0.475,
      unit: 'ratio',
      refLow: 0.37, refHigh: 0.5,
      refText: '0.37 to 0.50',
      group: 'Oxygen carrying and red cells',
      note:
          'Haematocrit is the share of your blood volume taken up by red '
          'cells, so it reflects how concentrated your blood is. It moves '
          'with hydration as well as with red cell production, which is why '
          'a dehydrated sample can read higher. Yours is in the upper half '
          'of the range and consistent with your haemoglobin.',
      actions: [
        'Drink water steadily through the day, and especially around '
        'training, flights and hot weather.',
        'Arrive well hydrated for future blood draws so results are '
        'comparable.',
      ],
    ),
    BloodMarker(
      key: 'red_cell_count',
      name: 'Red cell count',
      alias: 'How many red cells you have',
      value: 5.48,
      unit: 'x10^12/L',
      refLow: 4.4, refHigh: 5.8,
      refText: '4.40 to 5.80',
      group: 'Oxygen carrying and red cells',
      note:
          'This is a straight count of red cells per litre. Read together '
          'with haemoglobin and haematocrit, it confirms your red cell '
          'production is working well. All three are in step with each '
          'other, which is the pattern you want to see.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'mcv',
      name: 'MCV',
      alias: 'Average red cell size',
      value: 86.7,
      unit: 'fL',
      refLow: 80.0, refHigh: 99.0,
      refText: '80 to 99',
      group: 'Oxygen carrying and red cells',
      note:
          'MCV describes the average size of your red cells. Small cells '
          'often point towards iron deficiency, while large cells can '
          'suggest a shortage of vitamin B12 or folate, an underactive '
          'thyroid, or regular alcohol. Yours sits comfortably in the '
          'middle, which argues against all of those.',
      actions: [
        'No action needed. This is a useful early warning marker to watch '
        'across repeat panels.',
      ],
    ),
    BloodMarker(
      key: 'mch',
      name: 'MCH',
      alias: 'Average haemoglobin per cell',
      value: 29.9,
      unit: 'pg',
      refLow: 27.0, refHigh: 33.5,
      refText: '27.0 to 33.5',
      group: 'Oxygen carrying and red cells',
      note:
          'MCH is how much haemoglobin each red cell carries on average. It '
          'tends to fall alongside MCV when iron is short. Yours is mid '
          'range and confirms your cells are well loaded with oxygen '
          'carrying protein.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'mchc',
      name: 'MCHC',
      alias: 'Haemoglobin concentration in cells',
      value: 345.0,
      unit: 'g/L',
      refLow: 300.0, refHigh: 350.0,
      refText: '300 to 350',
      group: 'Oxygen carrying and red cells',
      note:
          'MCHC measures how densely packed the haemoglobin is inside each '
          'cell, rather than the absolute amount. Yours sits near the top '
          'of the range. On its own that carries little significance, '
          'especially when every other red cell index is normal, and it can '
          'simply reflect the sample.',
      actions: [
        'No action needed. Worth glancing at again on your next panel for '
        'the trend.',
      ],
    ),
    BloodMarker(
      key: 'rdw',
      name: 'RDW',
      alias: 'Variation in red cell size',
      value: 11.9,
      unit: '%',
      refLow: 11.5, refHigh: 15.0,
      refText: '11.5 to 15.0',
      group: 'Oxygen carrying and red cells',
      note:
          'RDW measures how much your red cells vary in size from one '
          'another. A rise often shows up before MCV shifts, so it acts as '
          'an early signal of a developing nutritional deficiency or mixed '
          'picture. Yours is at the low end, meaning your cells are a very '
          'uniform population.',
      actions: [
        'No action needed. This is a reassuring result.',
      ],
    ),
    // ── Clotting ──
    BloodMarker(
      key: 'platelet_count',
      name: 'Platelet count',
      alias: 'Cells that stop bleeding',
      value: 271.0,
      unit: 'x10^9/L',
      refLow: 150.0, refHigh: 400.0,
      refText: '150 to 400',
      group: 'Clotting',
      note:
          'Platelets clump at the site of an injury and form the first plug '
          'that stops bleeding. Low counts can mean easy bruising and slow '
          'clotting, while high counts can follow inflammation, infection '
          'or iron deficiency. Yours is comfortably mid range.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'mpv',
      name: 'MPV',
      alias: 'Average platelet size',
      value: 9.8,
      unit: 'fL',
      refLow: 7.0, refHigh: 13.0,
      refText: '7 to 13',
      group: 'Clotting',
      note:
          'MPV reflects the average size of your platelets, which stands in '
          'for how quickly your bone marrow is producing them. Younger, '
          'freshly released platelets tend to be larger. Yours is mid range '
          'and consistent with steady, unhurried production.',
      actions: [
        'No action needed.',
      ],
    ),
    // ── Immune system ──
    BloodMarker(
      key: 'white_cell_count',
      name: 'White cell count',
      alias: 'Total immune cells',
      value: 4.95,
      unit: 'x10^9/L',
      refLow: 3.0, refHigh: 10.0,
      refText: '3.0 to 10.0',
      group: 'Immune system',
      note:
          'This totals every type of white blood cell in circulation. It '
          'climbs during infection, inflammation and physical stress, and '
          'falls with certain viral illnesses and some medicines. Yours '
          'sits comfortably in range, which is the important context for '
          'the neutrophil result below.',
      actions: [
        'No action needed on the total count.',
      ],
    ),
    BloodMarker(
      key: 'neutrophils',
      name: 'Neutrophils',
      alias: 'First responders to bacteria',
      value: 1.91,
      unit: 'x10^9/L',
      refLow: 2.0, refHigh: 7.5,
      refText: '2.0 to 7.5',
      group: 'Immune system',
      share: '38.5% of white cells',
      note:
          'Neutrophils are the most numerous white cells and the first to '
          'arrive at a bacterial infection. Yours is 1.91 against a lower '
          'limit of 2.0, so it sits marginally below the printed range '
          'while your total white cell count stays normal. A reading this '
          'close to the line is common and frequently harmless. It can '
          'follow a recent viral infection, a period of heavy training, or '
          'it can simply be your normal level, since a meaningful '
          'proportion of healthy people, particularly those of African, '
          'Middle Eastern or West Indian ancestry, naturally run lower '
          'neutrophil counts with no effect on immunity at all. Certain '
          'medicines and supplements can also nudge it down.',
      actions: [
        'Mention any recent viral illness, medicines or supplements to '
        'your doctor, since these are the usual explanations.',
        'Ask about a simple repeat full blood count in four to six weeks '
        'to see whether it is a one off dip or your steady baseline.',
        'No change to daily life is warranted for a reading this close to '
        'the range, and your normal total white cell count is reassuring.',
      ],
    ),
    BloodMarker(
      key: 'lymphocytes',
      name: 'Lymphocytes',
      alias: 'Viral defence and immune memory',
      value: 2.28,
      unit: 'x10^9/L',
      refLow: 1.2, refHigh: 3.65,
      refText: '1.2 to 3.65',
      group: 'Immune system',
      share: '46.1% of white cells',
      note:
          'Lymphocytes include the T cells and B cells that handle viruses '
          'and hold your immune memory, which is what vaccination trains. '
          'Yours is mid range and healthy. It makes up a slightly larger '
          'share of the total than usual, which is simply the arithmetic '
          'consequence of the modest neutrophil dip.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'monocytes',
      name: 'Monocytes',
      alias: 'Clean up crew',
      value: 0.42,
      unit: 'x10^9/L',
      refLow: 0.2, refHigh: 1.0,
      refText: '0.2 to 1.0',
      group: 'Immune system',
      share: '8.5% of white cells',
      note:
          'Monocytes mature into macrophages, the cells that engulf debris, '
          'damaged tissue and microbes, and they play a large part in '
          'tissue repair after exercise. Yours is well within range.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'eosinophils',
      name: 'Eosinophils',
      alias: 'Allergy and parasite response',
      value: 0.26,
      unit: 'x10^9/L',
      refLow: 0.0, refHigh: 0.4,
      refText: '0.0 to 0.4',
      group: 'Immune system',
      share: '5.3% of white cells',
      note:
          'Eosinophils rise with allergy, asthma, eczema, drug reactions '
          'and parasitic infection. Yours is inside the range, sitting in '
          'its upper portion, which is a common finding in people with hay '
          'fever or other mild allergic tendencies.',
      actions: [
        'If you have seasonal allergies or asthma, this is a useful '
        'number to track across panels.',
        'No action needed now.',
      ],
    ),
    BloodMarker(
      key: 'basophils',
      name: 'Basophils',
      alias: 'Histamine release',
      value: 0.08,
      unit: 'x10^9/L',
      refLow: 0.0, refHigh: 0.1,
      refText: '0.0 to 0.1',
      group: 'Immune system',
      share: '1.6% of white cells',
      note:
          'Basophils are the rarest white cells and release histamine '
          'during allergic reactions. The normal range is narrow because '
          'the numbers are so small to begin with. Yours is in range.',
      actions: [
        'No action needed.',
      ],
    ),
    // ── Cholesterol and heart risk ──
    BloodMarker(
      key: 'ldl_cholesterol',
      name: 'LDL cholesterol',
      alias: 'The particle that drives plaque',
      value: 3.5,
      unit: 'mmol/L',
      refLow: 0.0, refHigh: 3.0,
      refText: 'Up to 3.0',
      group: 'Cholesterol and heart risk',
      priority: true,
      note:
          'LDL particles carry cholesterol from your liver out to your '
          'tissues, and when they lodge in artery walls they are the main '
          'driver of plaque over decades. Yours is 3.5 against a target '
          'ceiling of 3.0, so modestly above. This is a long horizon number '
          'rather than an urgent one, and it responds well to diet, weight '
          'and activity, which means you have real room to move it.',
      actions: [
        'Build in soluble fibre daily, such as oats, barley, beans, '
        'lentils, apples and psyllium, which binds cholesterol in the '
        'gut.',
        'Swap saturated fat for unsaturated where you can, so olive oil, '
        'nuts, avocado and oily fish in place of butter, fatty processed '
        'meat and pastry.',
        'Consider plant sterol or stanol fortified products, which '
        'typically lower LDL by around ten per cent when taken daily.',
        'Two portions of oily fish a week, and regular aerobic exercise, '
        'both help the overall picture.',
        'Retest in about twelve weeks to see how your LDL responds, and '
        'ask your doctor to work out your full cardiovascular risk score '
        'using your blood pressure, weight, family history and smoking '
        'status.',
      ],
    ),
    BloodMarker(
      key: 'total_cholesterol',
      name: 'Total cholesterol',
      alias: 'Everything added together',
      value: 5.6,
      unit: 'mmol/L',
      refLow: 0.0, refHigh: 5.0,
      refText: 'Optimum under 5.0',
      group: 'Cholesterol and heart risk',
      note:
          'This is every cholesterol carrying particle combined, both the '
          'helpful and the harmful. Because it includes your high HDL, a '
          'raised total can overstate risk in someone like you. Yours is '
          '5.6 against an optimum of under 5.0, and roughly a third of it '
          'is protective HDL, so read this alongside the LDL and non HDL '
          'figures rather than on its own.',
      actions: [
        'Treat the LDL and non HDL numbers as the ones to act on.',
        'The same dietary changes listed under LDL will bring this figure '
        'down too.',
      ],
    ),
    BloodMarker(
      key: 'non_hdl_cholesterol',
      name: 'Non HDL cholesterol',
      alias: 'All the harmful particles combined',
      value: 3.8,
      unit: 'mmol/L',
      refLow: 0.0, refHigh: 3.9,
      refText: 'Under 3.9',
      group: 'Cholesterol and heart risk',
      note:
          'Non HDL is your total cholesterol with the protective HDL '
          'subtracted, so it captures every particle type that can '
          'contribute to plaque, not just LDL. Many clinicians now prefer '
          'it as the single best snapshot of lipid risk, and it does not '
          'require fasting. Yours is 3.8 against a target of under 3.9, so '
          'it sits just inside target.',
      actions: [
        'This is the number to watch on repeat panels, since it moves '
        'with everything you do for LDL.',
        'Aim to open up a clearer margin below 3.9 over the next twelve '
        'weeks.',
      ],
    ),
    BloodMarker(
      key: 'hdl_cholesterol',
      name: 'HDL cholesterol',
      alias: 'The particle that clears cholesterol away',
      value: 1.8,
      unit: 'mmol/L',
      refLow: 0.9, refHigh: 1.5,
      refText: '0.9 to 1.5',
      group: 'Cholesterol and heart risk',
      highIsGood: true,
      note:
          'HDL particles collect excess cholesterol from tissues and artery '
          'walls and return it to the liver for disposal. Your report flags '
          '1.8 because it sits above the printed range, though for HDL a '
          'higher figure has traditionally been regarded as favourable '
          'rather than a problem, and a level like yours usually reflects '
          'regular exercise, low alcohol intake or genetics. Very high '
          'levels well beyond this are a separate discussion, but yours is '
          'not in that territory.',
      actions: [
        'Keep doing what is producing it, in particular regular aerobic '
        'exercise.',
        'No action needed. Mention it to your doctor for completeness, '
        'since it is printed as out of range.',
      ],
    ),
    BloodMarker(
      key: 'hdl_share_of_total',
      name: 'HDL share of total',
      alias: 'Protective fraction',
      value: 32.0,
      unit: '%',
      refLow: 20.0, refHigh: 60.0,
      refText: '20 and over',
      group: 'Cholesterol and heart risk',
      note:
          'This expresses how much of your total cholesterol is the '
          'protective kind. A higher share is better, and above twenty per '
          'cent is the threshold used here. At thirty two per cent yours is '
          'a strong result and it tempers how the raised total cholesterol '
          'should be read.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'triglycerides',
      name: 'Triglycerides',
      alias: 'Circulating fat',
      value: 0.6,
      unit: 'mmol/L',
      refLow: 0.0, refHigh: 2.3,
      refText: 'Under 2.3',
      group: 'Cholesterol and heart risk',
      note:
          'Triglycerides are the main form in which fat travels and is '
          'stored. They respond quickly to refined carbohydrate, alcohol, '
          'excess calories and insulin resistance, so they act as a fast '
          'feedback marker for diet. At 0.6 yours is excellent and well '
          'below the ceiling, which suggests your carbohydrate handling and '
          'alcohol intake are both in good shape.',
      actions: [
        'No action needed. This is one of the strongest results in your '
        'panel.',
      ],
    ),
    // ── Blood sugar ──
    BloodMarker(
      key: 'hba1c',
      name: 'HbA1c',
      alias: 'Three month average blood sugar',
      value: 39.0,
      unit: 'mmol/mol',
      refLow: 20.0, refHigh: 41.0,
      refText: '20 to 41',
      group: 'Blood sugar',
      note:
          'Because red cells live around three months, the amount of sugar '
          'stuck to them reveals your average glucose over that period, '
          'which no single reading can. In the UK, 42 to 47 is the '
          'prediabetes band and 48 and above supports a diagnosis of '
          'diabetes. At 39, equivalent to 5.7 per cent, you are inside the '
          'normal band with a small margin to the prediabetes threshold, so '
          'this is a number worth protecting rather than fixing.',
      actions: [
        'Keep resistance training and walking after meals, both of which '
        'help muscle take up glucose.',
        'Favour whole grains, pulses, vegetables and protein at each meal '
        'over refined carbohydrate and sugary drinks.',
        'Retest annually so you can see the direction of travel rather '
        'than a single point.',
      ],
    ),
    // ── Liver and muscle enzymes ──
    BloodMarker(
      key: 'creatine_kinase',
      name: 'Creatine kinase',
      alias: 'Released by working muscle',
      value: 937.0,
      unit: 'IU/L',
      refLow: 0.0, refHigh: 204.0,
      refText: '38 to 204',
      group: 'Liver and muscle enzymes',
      priority: true,
      note:
          'Creatine kinase, or CK, sits inside muscle fibres and leaks into '
          'blood when those fibres are damaged or heavily worked. Yours is '
          '937 against a ceiling of 204. In an active person this is very '
          'commonly explained by exercise, particularly resistance '
          'training, a long or hilly run, a new programme, or any session '
          'heavy in eccentric loading such as lowering weights or downhill '
          'running. Levels peak roughly one to three days after a hard '
          'session and can take a week to settle. Less commonly, raised CK '
          'relates to certain medicines including statins, thyroid '
          'problems, or a muscle condition, which is why the repeat test '
          'matters. Your normal ALT alongside this is what points the '
          'finger at muscle rather than liver.',
      actions: [
        'Repeat CK after five to seven days with no heavy or unfamiliar '
        'training, well hydrated.',
        'Tell your doctor what training you did in the week before this '
        'sample, and list every medicine and supplement you take.',
        'Drink water generously in the days after very hard sessions.',
        'Seek urgent medical advice if you have severe muscle pain with '
        'weakness, or dark cola coloured urine, as those signs need same '
        'day assessment.',
      ],
    ),
    BloodMarker(
      key: 'ast',
      name: 'AST',
      alias: 'Enzyme from liver, muscle and heart',
      value: 49.0,
      unit: 'IU/L',
      refLow: 0.0, refHigh: 37.0,
      refText: '0 to 37',
      group: 'Liver and muscle enzymes',
      note:
          'AST is found in liver cells but also abundantly in skeletal '
          'muscle and heart muscle, so it is not liver specific. Yours is '
          'mildly raised at 49. When AST is up, ALT is normal and CK is '
          'markedly high, muscle is by far the most likely source, and that '
          'is exactly the pattern here.',
      actions: [
        'Repeat alongside CK after a rest week, and expect it to fall as '
        'CK falls.',
        'If it stays raised once CK has normalised, ask your doctor about '
        'a liver focused review.',
      ],
    ),
    BloodMarker(
      key: 'alt',
      name: 'ALT',
      alias: 'The liver specific enzyme',
      value: 39.0,
      unit: 'IU/L',
      refLow: 10.0, refHigh: 50.0,
      refText: '10 to 50',
      group: 'Liver and muscle enzymes',
      note:
          'ALT is concentrated in liver cells far more than anywhere else, '
          'which makes it the most useful single marker of liver cell '
          'stress from fatty liver, alcohol, medicines or viral hepatitis. '
          'Yours is normal, and this is the single most reassuring number '
          'in your liver panel because it is what separates a muscle story '
          'from a liver one.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'alkaline_phosphatase',
      name: 'Alkaline phosphatase',
      alias: 'Bile ducts and bone',
      value: 67.0,
      unit: 'IU/L',
      refLow: 40.0, refHigh: 129.0,
      refText: '40 to 129',
      group: 'Liver and muscle enzymes',
      note:
          'ALP comes mainly from the bile ducts and from bone, so it rises '
          'with bile flow obstruction and with high bone turnover. Yours is '
          'comfortably mid range, which argues against a bile duct problem.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'gamma_gt',
      name: 'Gamma GT',
      alias: 'Sensitive to alcohol and bile flow',
      value: 27.0,
      unit: 'IU/L',
      refLow: 10.0, refHigh: 71.0,
      refText: '10 to 71',
      group: 'Liver and muscle enzymes',
      note:
          'Gamma GT is the enzyme most sensitive to regular alcohol intake '
          'and to bile duct irritation, and it is often the first liver '
          'marker to move. Yours is well within range and in the lower '
          'half, which is a positive sign alongside your normal ALT.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'bilirubin',
      name: 'Bilirubin',
      alias: 'Pigment from recycled red cells',
      value: 8.0,
      unit: 'umol/L',
      refLow: 0.0, refHigh: 20.0,
      refText: '0 to 20',
      group: 'Liver and muscle enzymes',
      note:
          'Bilirubin is the yellow pigment produced when old red cells are '
          'broken down and cleared by the liver. It rises with liver or '
          'bile duct problems, faster red cell breakdown, or the harmless '
          'inherited variation known as Gilbert\'s syndrome. Yours is '
          'normal.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'total_protein',
      name: 'Total protein',
      alias: 'All blood proteins',
      value: 75.0,
      unit: 'g/L',
      refLow: 63.0, refHigh: 83.0,
      refText: '63 to 83',
      group: 'Liver and muscle enzymes',
      note:
          'This adds albumin and the globulins together to give a broad '
          'view of your liver\'s production, your nutrition and your immune '
          'activity. Yours is mid range.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'albumin',
      name: 'Albumin',
      alias: 'The liver\'s main protein',
      value: 45.0,
      unit: 'g/L',
      refLow: 34.0, refHigh: 50.0,
      refText: '34 to 50',
      group: 'Liver and muscle enzymes',
      note:
          'Albumin is made by the liver, holds fluid inside blood vessels '
          'and ferries hormones, calcium and medicines around the body. It '
          'falls with poor nutrition, liver disease, inflammation or '
          'protein loss through the kidneys. Yours is in the upper part of '
          'the range, which reflects good liver synthesis and good '
          'nutrition.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'globulin',
      name: 'Globulin',
      alias: 'Antibodies and transport proteins',
      value: 30.0,
      unit: 'g/L',
      refLow: 19.0, refHigh: 35.0,
      refText: '19 to 35',
      group: 'Liver and muscle enzymes',
      note:
          'Globulins include your antibodies and a range of carrier '
          'proteins, so this figure moves with immune activity and chronic '
          'inflammation. Yours is normal, which fits with your very low '
          'inflammation marker.',
      actions: [
        'No action needed.',
      ],
    ),
    // ── Kidneys and hydration ──
    BloodMarker(
      key: 'creatinine',
      name: 'Creatinine',
      alias: 'Muscle waste filtered by the kidneys',
      value: 105.0,
      unit: 'umol/L',
      refLow: 59.0, refHigh: 104.0,
      refText: '59 to 104',
      group: 'Kidneys and hydration',
      note:
          'Creatinine is the waste product of normal muscle metabolism, and '
          'your kidneys clear it steadily, which is why it is used to judge '
          'filtration. The catch is that the more muscle you carry and the '
          'harder you have trained recently, the more creatinine you '
          'produce, so a muscular or recently exercised person reads higher '
          'without any kidney problem. Yours is 105 against a ceiling of '
          '104, so it is over the line by a single unit, and it sits '
          'alongside a markedly raised CK from muscle. Dehydration and a '
          'high protein or creatine supplemented diet nudge it up too.',
      actions: [
        'Repeat when rested and well hydrated, ideally in the same '
        'sitting as the CK recheck.',
        'Mention creatine supplements and high protein intake to your '
        'doctor, as both raise this legitimately.',
        'If your doctor wants a muscle independent view of kidney '
        'function, ask about cystatin C, which is not affected by muscle '
        'mass.',
      ],
    ),
    BloodMarker(
      key: 'egfr',
      name: 'eGFR',
      alias: 'Estimated filtration rate',
      value: 78.0,
      unit: 'mL/min/1.73m2',
      refLow: 60.0, refHigh: 120.0,
      refText: '60 and above',
      group: 'Kidneys and hydration',
      forceWatch: true,
      note:
          'eGFR estimates how much blood your kidneys filter each minute, '
          'calculated from your creatinine, age and sex. Because it is '
          'derived from creatinine, anything that raises creatinine lowers '
          'the estimate, so muscular and recently trained people are '
          'routinely underestimated. A figure of 78 sits in the mildly '
          'reduced band, though on its own, in a healthy person with no '
          'protein in the urine, it is often of no clinical significance. '
          'Kidney disease is defined by a sustained reduction over at least '
          'three months, not by a single reading.',
      actions: [
        'Recheck with the repeat creatinine after a rest week.',
        'Ask your doctor about a urine albumin to creatinine ratio, which '
        'is the other half of the standard kidney assessment and is not '
        'affected by muscle.',
        'Stay well hydrated and use anti inflammatory painkillers '
        'sparingly.',
      ],
    ),
    BloodMarker(
      key: 'urea',
      name: 'Urea',
      alias: 'Protein waste product',
      value: 5.8,
      unit: 'mmol/L',
      refLow: 1.7, refHigh: 8.3,
      refText: '1.7 to 8.3',
      group: 'Kidneys and hydration',
      note:
          'Urea is made in the liver when protein is broken down and is '
          'then cleared by the kidneys. It rises with dehydration, a high '
          'protein intake or reduced kidney clearance. Yours is comfortably '
          'mid range, which is a helpful counterweight to the borderline '
          'creatinine and supports the view that filtration is working '
          'well.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'uric_acid',
      name: 'Uric acid',
      alias: 'Purine waste, linked to gout',
      value: 315.0,
      unit: 'umol/L',
      refLow: 266.0, refHigh: 474.0,
      refText: '266 to 474',
      group: 'Kidneys and hydration',
      note:
          'Uric acid comes from breaking down purines found in food and in '
          'your own cells, and when it crystallises in a joint it causes '
          'gout. High levels also track with metabolic and kidney risk. '
          'Yours is in the lower half of the range, which is a good place '
          'to be.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'magnesium',
      name: 'Magnesium',
      alias: 'Mineral for muscle and nerve',
      value: 0.8,
      unit: 'mmol/L',
      refLow: 0.6, refHigh: 1.0,
      refText: '0.60 to 1.00',
      group: 'Kidneys and hydration',
      note:
          'Magnesium is required for hundreds of enzyme reactions, '
          'including muscle contraction and relaxation, nerve signalling '
          'and energy production. Blood levels are tightly controlled and '
          'only loosely reflect body stores, so a normal result is '
          'reassuring rather than conclusive. Yours is mid range.',
      actions: [
        'Keep nuts, seeds, whole grains, pulses and dark leafy greens in '
        'the diet as your main sources.',
        'No action needed.',
      ],
    ),
    // ── Iron status ──
    BloodMarker(
      key: 'ferritin',
      name: 'Ferritin',
      alias: 'Your iron store',
      value: 100.0,
      unit: 'ug/L',
      refLow: 30.0, refHigh: 400.0,
      refText: '30 to 400',
      group: 'Iron status',
      note:
          'Ferritin is the protein that stores iron and it is the best '
          'single indicator of how much iron you have banked. It falls '
          'first when iron runs short, well before haemoglobin drops. One '
          'caveat is that ferritin also rises with inflammation, which can '
          'mask a deficiency, though your inflammation marker is close to '
          'zero so your figure can be taken at face value. At 100 you have '
          'a healthy reserve.',
      actions: [
        'No action needed. This is a genuinely good result.',
      ],
    ),
    BloodMarker(
      key: 'serum_iron',
      name: 'Serum iron',
      alias: 'Iron circulating right now',
      value: 13.0,
      unit: 'umol/L',
      refLow: 10.6, refHigh: 28.3,
      refText: '10.6 to 28.3',
      group: 'Iron status',
      note:
          'This measures iron in transit in your bloodstream at the moment '
          'of the draw. It swings considerably through the day, peaking in '
          'the morning, and it dips after meals, so a single value is far '
          'less informative than ferritin. Yours is in range in the lower '
          'portion, which is unremarkable given your healthy stores.',
      actions: [
        'No action needed. Read this alongside ferritin rather than '
        'alone.',
      ],
    ),
    BloodMarker(
      key: 'total_iron_binding_capacity',
      name: 'Total iron binding capacity',
      alias: 'Room available to carry iron',
      value: 63.0,
      unit: 'umol/L',
      refLow: 41.0, refHigh: 77.0,
      refText: '41 to 77',
      group: 'Iron status',
      note:
          'TIBC reflects how much transferrin, the iron taxi protein, you '
          'have available. The body makes more of it when iron is scarce, '
          'so a high TIBC alongside low ferritin signals deficiency. Yours '
          'is in range.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'transferrin_saturation',
      name: 'Transferrin saturation',
      alias: 'How full the taxis are',
      value: 21.0,
      unit: '%',
      refLow: 20.0, refHigh: 55.0,
      refText: '20 to 55',
      group: 'Iron status',
      note:
          'This is serum iron expressed as a percentage of your binding '
          'capacity, so it shows how full your iron transport system is. '
          'Below twenty per cent suggests iron supply is tight, while high '
          'figures raise the question of iron overload. Yours sits just '
          'inside the lower boundary. With ferritin at 100 and normal '
          'haemoglobin, this is a mildly low value in an otherwise healthy '
          'iron picture and is likely to reflect the morning timing and '
          'daily variation of the sample.',
      actions: [
        'Pair iron rich foods with vitamin C, such as citrus or peppers, '
        'to improve absorption.',
        'Keep tea and coffee away from iron rich meals by an hour or so, '
        'since they reduce uptake.',
        'No supplement is indicated on these numbers. Iron supplements '
        'without a clear deficiency are best avoided.',
      ],
    ),
    // ── Vitamins ──
    BloodMarker(
      key: 'vitamin_d',
      name: 'Vitamin D',
      alias: '25 OH vitamin D',
      value: 42.0,
      unit: 'nmol/L',
      refLow: 50.0, refHigh: 200.0,
      refText: '50 to 200',
      group: 'Vitamins',
      priority: true,
      note:
          'Vitamin D is made in skin exposed to summer sunlight and is '
          'required for calcium absorption, bone strength, muscle function '
          'and immune regulation. Your laboratory prints the bands it uses: '
          'below 25 is deficient, 25 to 49 is insufficient, 50 to 200 is '
          'normal, and above 200 suggests reducing the dose. At 42 you fall '
          'in the insufficient band, close to the lower edge of normal. '
          'This is extremely common in the UK, where the sun is too weak '
          'for skin production from about October to March, and it is '
          'entirely correctable.',
      actions: [
        'Ask your doctor about a suitable supplement. Public Health '
        'England advises considering ten micrograms, or 400 international '
        'units, daily for adults through autumn and winter, and '
        'correcting a low level often calls for a higher dose for a '
        'defined period.',
        'Include oily fish such as salmon, mackerel and sardines, plus '
        'eggs and fortified foods, though diet alone rarely closes the '
        'gap in a UK winter.',
        'Get daylight on skin in the summer months, in short spells and '
        'without burning.',
        'Retest in about twelve weeks to confirm you have moved into the '
        'normal band and to fine tune the dose.',
      ],
    ),
    BloodMarker(
      // Keyed as vitamin_b12 so the Biomarkers nutrient card can pair
      // dietary and supplemental B12 intake with this result.
      key: 'vitamin_b12',
      name: 'Active B12',
      alias: 'The usable fraction of vitamin B12',
      value: 211.4,
      unit: 'pmol/L',
      refLow: 25.1, refHigh: 165.0,
      refText: '25.1 to 165.0',
      group: 'Vitamins',
      note:
          'Active B12, also called holotranscobalamin, measures only the '
          'portion of vitamin B12 your cells can actually take up, which '
          'makes it more informative than a total B12. B12 is essential for '
          'red cell production, nerve function and DNA synthesis. Yours is '
          'above the range at 211.4, and in practice a high active B12 is '
          'nearly always the footprint of a supplement, a fortified diet or '
          'an injection. There is no known harm from high B12 in a healthy '
          'person and the body simply passes on what it cannot use. The '
          'relevance is that it confirms you are far from deficient, and '
          'where it is unexpected it is worth reviewing.',
      actions: [
        'Confirm your current B12 or multivitamin dose with your doctor '
        'and ask whether it can be reduced or spaced out.',
        'If you take no B12 supplement and receive no injections, flag '
        'this specifically, as an unexplained high level deserves a look.',
        'No symptoms or restrictions arise from this result on its own.',
      ],
    ),
    BloodMarker(
      key: 'folate',
      name: 'Folate',
      alias: 'Vitamin B9',
      value: 14.3,
      unit: 'ug/L',
      refLow: 2.9, refHigh: 20.0,
      refText: 'Above 2.9',
      group: 'Vitamins',
      note:
          'Folate works closely with B12 to build red cells and DNA, and a '
          'shortage causes a specific type of anaemia with enlarged red '
          'cells. Your laboratory notes that where diet has not changed, a '
          'normal serum folate makes deficiency unlikely. At 14.3 you are '
          'comfortably above the floor.',
      actions: [
        'Keep leafy greens, pulses, citrus and fortified cereals in '
        'regular rotation.',
        'No action needed.',
      ],
    ),
    // ── Inflammation ──
    BloodMarker(
      key: 'high_sensitivity_crp',
      name: 'High sensitivity CRP',
      alias: 'Low grade inflammation',
      value: 0.3,
      unit: 'mg/L',
      refLow: 0.0, refHigh: 5.0,
      refText: '0.0 to 5.0',
      group: 'Inflammation',
      note:
          'C reactive protein is made by the liver in response to '
          'inflammation anywhere in the body, and the high sensitivity '
          'version detects the very low levels linked to long term '
          'cardiovascular risk. Levels under 1.0 are generally regarded as '
          'the low risk band. At 0.3 yours is close to the floor of what '
          'the test can measure, which suggests no active infection and '
          'very little background inflammation. It also means your ferritin '
          'can be read at face value, since inflammation would otherwise '
          'inflate it.',
      actions: [
        'No action needed. This is one of the strongest results in your '
        'panel and provides useful context for the rest.',
      ],
    ),
    // ── Hormones ──
    BloodMarker(
      key: 'tsh',
      name: 'TSH',
      alias: 'Thyroid stimulating hormone',
      value: 3.01,
      unit: 'mIU/L',
      refLow: 0.27, refHigh: 4.2,
      refText: '0.27 to 4.2',
      group: 'Hormones',
      note:
          'TSH is the signal your pituitary sends to the thyroid, so it '
          'rises when the thyroid is underperforming and falls when it is '
          'overactive. It is the most sensitive first line thyroid test, '
          'since it moves before the thyroid hormones themselves do. Yours '
          'is in range, in the upper middle portion, and your actual '
          'thyroid hormones below are both normal.',
      actions: [
        'No action needed. Worth tracking on repeat panels for the trend '
        'rather than the single value.',
      ],
    ),
    BloodMarker(
      key: 'free_t4',
      name: 'Free T4',
      alias: 'The thyroid\'s main output',
      value: 15.2,
      unit: 'pmol/L',
      refLow: 12.0, refHigh: 22.0,
      refText: '12.0 to 22.0',
      group: 'Hormones',
      note:
          'T4 is the main hormone your thyroid releases and it acts as the '
          'reservoir that gets converted into the active form. The free '
          'measurement counts only the unbound portion available to your '
          'tissues. Yours is in range.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'free_t3',
      name: 'Free T3',
      alias: 'The active thyroid hormone',
      value: 5.5,
      unit: 'pmol/L',
      refLow: 3.1, refHigh: 6.8,
      refText: '3.1 to 6.8',
      group: 'Hormones',
      note:
          'T3 is the biologically active thyroid hormone that actually sets '
          'the metabolic rate of your cells, converted from T4 mostly in '
          'the liver. Yours is in the upper half of the range, and together '
          'with a normal TSH and T4 it indicates your thyroid axis is '
          'working well from signal through to conversion.',
      actions: [
        'No action needed.',
      ],
    ),
    BloodMarker(
      key: 'testosterone',
      name: 'Testosterone',
      alias: 'Total testosterone',
      value: 22.6,
      unit: 'nmol/L',
      refLow: 7.6, refHigh: 31.4,
      refText: '7.6 to 31.4',
      group: 'Hormones',
      note:
          'Testosterone supports muscle mass, bone density, red cell '
          'production, libido, mood and energy. Levels peak in the early '
          'morning and fall through the day, so a 07:25 sample like yours '
          'is the ideal timing and gives the most meaningful reading. This '
          'measures total testosterone, both bound and free. At 22.6 you '
          'are in the upper middle of the adult male range, which is a '
          'healthy result.',
      actions: [
        'Protect it with consistent sleep, resistance training, a healthy '
        'body composition and moderate alcohol.',
        'No action needed.',
      ],
    ),
    ],
  );
}
