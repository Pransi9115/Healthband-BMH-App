// ─────────────────────────────────────────────────────────
//  BIORESPONSE — BIOMARKERS
//
//  Two tabs:
//    Nutrients    · one card per nutrient — intake on top, blood
//                   underneath, so both sides read in a single glance
//    Blood report · the panel BMH ran, with true counts
//
//  Every tracked nutrient appears in the first tab. The blood half
//  only shows for nutrients the panel actually measured; the rest
//  say so plainly rather than showing an empty bar.
//
//  The per day / per week range applies to intake only. A blood
//  result is one lab measurement on one date, and the screen says
//  so rather than implying it moves.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/biomarker_link_service.dart';
import '../../core/bioresponse/blood_report_service.dart';
import '../../core/bioresponse/medication_service.dart';
import '../../core/bioresponse/nutritional_score_service.dart';
import '../../core/bioresponse/supplement_service.dart';
import '../../core/diet/diet_service.dart';
import 'blood_report_screen.dart';

const _foodColor = BMHColors.sGut;
const _suppColor = BMHColors.sMetabolic;

Color markerColor(MarkerStatus s, bool highIsGood) => switch (s) {
      MarkerStatus.low => BMHColors.warn,
      MarkerStatus.high => highIsGood ? BMHColors.success : BMHColors.danger,
      MarkerStatus.borderline => BMHColors.sMetabolic,
      MarkerStatus.inRange => BMHColors.success,
    };

String fmtNum(double v) {
  if (v >= 1000) return v.round().toString();
  if (v == v.roundToDouble()) return v.round().toString();
  if (v.abs() < 1) return v.toStringAsFixed(2);
  return v.toStringAsFixed(1);
}

String fmtDate(DateTime d) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun',
             'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

class BiomarkersScreen extends StatefulWidget {
  final ScoreRange initialRange;
  const BiomarkersScreen({super.key, this.initialRange = ScoreRange.day});

  @override
  State<BiomarkersScreen> createState() => _BiomarkersScreenState();
}

class _BiomarkersScreenState extends State<BiomarkersScreen> {
  final _links = BiomarkerLinkService.instance;
  final _blood = BloodReportService.instance;
  final _supps = SupplementService.instance;
  final _meds = MedicationService.instance;
  final _diet = DietService.instance;
  final _score = NutritionalScoreService.instance;

  late ScoreRange _range;
  int _tab = 0;   // 0 = nutrients, 1 = blood report

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    _blood.addListener(_refresh);
    _supps.addListener(_refresh);
    _meds.addListener(_refresh);
    _boot();
  }

  Future<void> _boot() async {
    await _blood.init();
    await _supps.init();
    await _meds.init();
    for (final d in _score.daysIn(ScoreRange.week, DateTime.now())) {
      await _diet.ensureDay(d);
    }
    if (mounted) setState(() {});
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _blood.removeListener(_refresh);
    _supps.removeListener(_refresh);
    _meds.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BMHSpacing.s5, vertical: 8),
          child: Row(children: [
            BMHIconButton(
              onTap: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded,
                color: BMHColors.ink, size: 16)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BMHEyebrow('BIORESPONSE'),
                Text('Biomarkers', style: BMHText.heading1),
              ])),
          ])),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.s5),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: BMHColors.bg2,
              borderRadius: BorderRadius.circular(BMHRadius.full),
              border: Border.all(color: BMHColors.line)),
            child: Row(children: [
              _tabBtn('Nutrients', 0),
              _tabBtn('Blood report', 1),
            ]))),

        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BMHSpacing.s5, 14, BMHSpacing.s5, 40),
          children: _tab == 0 ? _nutrientsTab() : _bloodTab())),
      ])),
    );
  }

  Widget _tabBtn(String label, int i) => Expanded(child: GestureDetector(
    onTap: () => setState(() => _tab = i),
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: _tab == i ? BMHColors.cyan : Colors.transparent,
        borderRadius: BorderRadius.circular(BMHRadius.full)),
      child: Text(label,
        textAlign: TextAlign.center,
        style: BMHText.labelMd.copyWith(
          color: _tab == i ? BMHColors.bg0 : BMHColors.inkDim,
          fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w500)))));

  // ═══════════════ TAB 1 · NUTRIENTS ════════════════════
  List<Widget> _nutrientsTab() {
    final results = _links.allResults(_range);
    final report = _blood.report;
    final logged = results.isEmpty ? 0 : results.first.daysWithData;

    return [
      // Range control — intake only
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: BMHColors.bg2,
          borderRadius: BorderRadius.circular(BMHRadius.full),
          border: Border.all(color: BMHColors.line)),
        child: Row(children: [
          for (final r in ScoreRange.values)
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _range = r),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: r == _range ? _foodColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(BMHRadius.full)),
                child: Text(r.label,
                  textAlign: TextAlign.center,
                  style: BMHText.labelMd.copyWith(
                    color: r == _range ? BMHColors.bg0 : BMHColors.inkDim,
                    fontWeight: r == _range
                      ? FontWeight.w700 : FontWeight.w500))))),
        ])),
      const SizedBox(height: 9),
      Text(
        logged == 0
          ? 'Nothing logged in this range yet. Log meals and supplements '
            'in BioMedical Diet to fill the intake side.'
          : _range == ScoreRange.day
            ? 'Intake is from the meals and supplements you logged today. '
              'Blood is from your test on '
              '${report == null ? "—" : fmtDate(report.testDate)} and does '
              'not change with the range.'
            : 'Intake is a daily average across $logged of the last 7 days '
              'logged. Blood is from your test on '
              '${report == null ? "—" : fmtDate(report.testDate)} and does '
              'not change with the range.',
        style: BMHText.bodySm.copyWith(
          fontSize: 10.5, color: BMHColors.inkMute, height: 1.45)),
      const SizedBox(height: 14),

      if (_blood.isSample) _sampleBanner(),

      for (final r in results) ...[
        _NutrientCard(result: r),
        const SizedBox(height: 11),
      ],
    ];
  }

  // ═══════════════ TAB 2 · BLOOD REPORT ═════════════════
  List<Widget> _bloodTab() {
    final report = _blood.report;
    if (report == null) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: BMHColors.surface,
            borderRadius: BorderRadius.circular(BMHRadius.lg),
            border: Border.all(color: BMHColors.line)),
          child: Column(children: [
            const Icon(Icons.bloodtype_outlined,
              color: BMHColors.inkMute, size: 32),
            const SizedBox(height: 12),
            Text('No blood report yet',
              style: BMHText.labelLg.copyWith(color: BMHColors.ink2)),
            const SizedBox(height: 6),
            Text('Your BMH blood panel appears here once your clinic '
                 'uploads it.',
              textAlign: TextAlign.center,
              style: BMHText.bodySm.copyWith(
                fontSize: 11, color: BMHColors.inkMute, height: 1.5)),
          ])),
      ];
    }

    return [
      if (_blood.isSample) _sampleBanner(),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.xl),
          border: Border.all(color: BMHColors.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.testName,
              style: BMHText.labelLg.copyWith(color: BMHColors.ink)),
            const SizedBox(height: 3),
            Text('Tested ${fmtDate(report.testDate)} · BioHealthcare Hub',
              style: BMHText.monoSm.copyWith(
                fontSize: 9.5, color: BMHColors.inkDim)),
            const SizedBox(height: 16),
            Row(children: [
              _stat('${report.concernCount}', 'Outside\nrange',
                BMHColors.danger),
              _stat('${report.borderlineCount}', 'Border-\nline',
                BMHColors.sMetabolic),
              _stat('${report.inRangeCount}', 'In\nrange',
                BMHColors.success),
              _stat('${report.totalCount}', 'Total\nmarkers',
                BMHColors.cyan),
            ]),
            if (report.priorityCount > 0 || report.favourableCount > 0) ...[
              const SizedBox(height: 14),
              const Divider(color: BMHColors.line, height: 1),
              const SizedBox(height: 12),
              if (report.priorityCount > 0)
                _summaryLine(Icons.priority_high_rounded, BMHColors.danger,
                  '${report.priorityCount} of the ${report.concernCount} '
                  'were flagged by your clinician as needing attention '
                  'first'),
              if (report.favourableCount > 0) ...[
                const SizedBox(height: 8),
                _summaryLine(Icons.check_circle_outline_rounded,
                  BMHColors.success,
                  '${report.favourableCount} marker above its range is a '
                  'good result, not a concern'),
              ],
            ],
          ])),

      const SizedBox(height: 18),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => BloodReportScreen(report: report))),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BMHRadius.full),
            border: Border.all(color: BMHColors.cyan.withOpacity(0.5))),
          child: Text('View all ${report.totalCount} markers',
            textAlign: TextAlign.center,
            style: BMHText.labelLg.copyWith(
              color: BMHColors.cyan, fontWeight: FontWeight.w600)))),

      const SizedBox(height: 24),
      BMHSectionTitle('Outside range'),
      const SizedBox(height: 12),
      if (report.concerns.isEmpty)
        _footNote('Every marker in this panel sits inside its reference '
                  'range.')
      else
        for (final m in report.concerns) ...[
          _MarkerCard(marker: m),
          const SizedBox(height: 11),
        ],

      if (report.recommendations.isNotEmpty) ...[
        const SizedBox(height: 22),
        BMHSectionTitle('Clinical recommendations'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: BMHColors.surface,
            borderRadius: BorderRadius.circular(BMHRadius.lg),
            border: Border.all(color: BMHColors.line)),
          child: Column(children: [
            for (var i = 0; i < report.recommendations.length; i++) ...[
              if (i > 0) const Divider(color: BMHColors.line, height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 20, height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: BMHColors.cyan.withOpacity(0.12),
                    shape: BoxShape.circle),
                  child: Center(child: Text('${i + 1}',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9, color: BMHColors.cyan,
                      fontWeight: FontWeight.w700)))),
                const SizedBox(width: 11),
                Expanded(child: Text(report.recommendations[i],
                  style: BMHText.bodySm.copyWith(
                    fontSize: 11, color: BMHColors.ink2, height: 1.5))),
              ]),
            ],
          ])),
      ],

      const SizedBox(height: 18),
      _footNote(
        'Prepared from a blood sample without access to your full medical '
        'records. Not for diagnosing or treating any condition — always '
        'speak to a medical professional before acting on these results.'),
    ];
  }

  Widget _summaryLine(IconData ic, Color c, String text) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ic, color: c, size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
          style: BMHText.bodySm.copyWith(
            fontSize: 10.5, color: BMHColors.ink2, height: 1.4))),
      ]);

  Widget _stat(String v, String l, Color c) => Expanded(child: Column(
    children: [
      Text(v, style: BMHText.heading2.copyWith(color: c)),
      const SizedBox(height: 3),
      Text(l,
        textAlign: TextAlign.center,
        style: BMHText.monoSm.copyWith(
          fontSize: 8, height: 1.3, color: BMHColors.inkDim)),
    ]));

  Widget _sampleBanner() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: BMHColors.sMetabolic.withOpacity(0.10),
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.sMetabolic.withOpacity(0.35))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.science_outlined,
        color: BMHColors.sMetabolic, size: 15),
      const SizedBox(width: 10),
      Expanded(child: Text(
        'Example panel. Your own results replace this as soon as your '
        'clinic uploads your blood report.',
        style: BMHText.bodySm.copyWith(
          fontSize: 10.5, color: BMHColors.ink2, height: 1.45))),
    ]));

  Widget _footNote(String s) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: BMHColors.bg2,
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.line)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded,
        color: BMHColors.inkDim, size: 14),
      const SizedBox(width: 10),
      Expanded(child: Text(s,
        style: BMHText.bodySm.copyWith(
          fontSize: 10.5, color: BMHColors.inkMute, height: 1.45))),
    ]));
}

// ─────────────────────────────────────────────────────────
//  NUTRIENT CARD — intake bar above, blood bar below
// ─────────────────────────────────────────────────────────
class _NutrientCard extends StatelessWidget {
  final LinkResult result;
  const _NutrientCard({required this.result});

  /// The intake bar runs to 150% of target, so the dotted target
  /// marker sits two-thirds along and anything above it is visible
  /// without the bar becoming meaningless at 40x target.
  static const _barCeiling = 150.0;

  Color get _pillColor {
    final b = result.blood;
    if (b == null) return BMHColors.inkMute;
    return markerColor(b.status, b.highIsGood);
  }

  String get _pillLabel {
    final b = result.blood;
    if (b == null) return 'Intake only';
    if (b.highIsGood && b.status == MarkerStatus.high) return 'Protective';
    return switch (b.status) {
      MarkerStatus.low => 'Low',
      MarkerStatus.high => 'High',
      MarkerStatus.borderline => 'Borderline',
      MarkerStatus.inRange => 'In range',
    };
  }

  Color get _verdictColor => switch (result.verdict) {
        LinkVerdict.matched => BMHColors.success,
        LinkVerdict.dietGap => BMHColors.warn,
        LinkVerdict.absorption => BMHColors.sNervous,
        LinkVerdict.overSupplement => BMHColors.danger,
        LinkVerdict.watch => BMHColors.sMetabolic,
        LinkVerdict.unknown => BMHColors.inkMute,
      };

  IconData get _verdictIcon => switch (result.verdict) {
        LinkVerdict.matched => Icons.check_circle_outline_rounded,
        LinkVerdict.dietGap => Icons.trending_down_rounded,
        LinkVerdict.absorption => Icons.help_outline_rounded,
        LinkVerdict.overSupplement => Icons.trending_up_rounded,
        LinkVerdict.watch => Icons.visibility_outlined,
        LinkVerdict.unknown => Icons.remove_circle_outline_rounded,
      };

  String get _category {
    const vitamins = ['Vitamin A','Vitamin C','Vitamin D','Vitamin B12',
                      'Folate'];
    if (vitamins.contains(result.link.name)) return 'Vitamin';
    if (result.link.name == 'Omega-3') return 'Fatty acid';
    return 'Mineral';
  }

  @override
  Widget build(BuildContext context) {
    final b = result.blood;
    final pct = result.intakePercent;
    final showVerdict = b != null && result.hasIntake;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(
          color: result.needsAttention
            ? _verdictColor.withOpacity(0.30)
            : BMHColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.link.name,
                  style: BMHText.labelLg.copyWith(color: BMHColors.ink)),
                const SizedBox(height: 3),
                Text(_category,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9, color: BMHColors.inkMute)),
              ])),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _pillColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(BMHRadius.full)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    color: _pillColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_pillLabel,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 8.5, color: _pillColor,
                    fontWeight: FontWeight.w700)),
              ])),
          ]),

          // ── INTAKE ──
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('INTAKE',
                style: BMHText.monoSm.copyWith(
                  fontSize: 8.5, letterSpacing: 1.3,
                  color: BMHColors.inkDim, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                result.hasIntake
                  ? '${fmtNum(result.intakeTotal)} ${result.intakeUnit}'
                  : '—',
                style: BMHText.monoMd.copyWith(
                  fontSize: 12, color: BMHColors.ink,
                  fontWeight: FontWeight.w700)),
              const SizedBox(width: 5),
              Text('vs ${fmtNum(result.intakeTarget)}',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9.5, color: BMHColors.inkMute)),
            ]),
          const SizedBox(height: 8),
          _IntakeBar(
            food: result.intakeFromFood,
            supps: result.intakeFromSupplements,
            target: result.intakeTarget,
            ceiling: _barCeiling),
          const SizedBox(height: 8),
          Row(children: [
            _swatch(_foodColor),
            const SizedBox(width: 5),
            Text('food ${fmtNum(result.intakeFromFood)}',
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.inkMute)),
            if (result.intakeFromSupplements > 0) ...[
              const SizedBox(width: 10),
              _swatch(_suppColor),
              const SizedBox(width: 5),
              Text('supplement ${fmtNum(result.intakeFromSupplements)}',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkMute)),
            ] else ...[
              const SizedBox(width: 8),
              Text('· no supplement',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkFaint)),
            ],
            const Spacer(),
            if (result.hasIntake && pct > _barCeiling)
              Text('${pct.round()}% of target',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: _suppColor,
                  fontWeight: FontWeight.w700)),
          ]),

          // ── BLOOD ──
          if (b != null) ...[
            const SizedBox(height: 11),
            const Center(child: Icon(Icons.south_rounded,
              color: BMHColors.inkFaint, size: 13)),
            const SizedBox(height: 9),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('BLOOD',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 8.5, letterSpacing: 1.3,
                    color: BMHColors.inkDim, fontWeight: FontWeight.w600)),
                const Spacer(),
                Flexible(child: Text('${fmtNum(b.value)} ${b.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BMHText.monoMd.copyWith(
                    fontSize: 12,
                    color: markerColor(b.status, b.highIsGood),
                    fontWeight: FontWeight.w700))),
              ]),
            const SizedBox(height: 8),
            _BloodBar(marker: b),
            const SizedBox(height: 7),
            Text(
              '${b.name} · range ${fmtNum(b.refLow)} to '
              '${fmtNum(b.refHigh)} ${b.unit}',
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.inkMute)),
          ] else ...[
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: BMHColors.bg2,
                borderRadius: BorderRadius.circular(BMHRadius.sm)),
              child: Text(
                'Not measured in your latest blood panel — intake only.',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkMute))),
          ],

          // ── VERDICT ──
          if (showVerdict) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: BMHColors.bg2,
                borderRadius: BorderRadius.circular(BMHRadius.sm)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_verdictIcon, color: _verdictColor, size: 14),
                  const SizedBox(width: 9),
                  Expanded(child: Text(result.message,
                    style: BMHText.bodySm.copyWith(
                      fontSize: 10.5, color: BMHColors.ink2,
                      height: 1.5))),
                ])),
          ],

          // ── SOURCE ──
          const SizedBox(height: 10),
          Text(
            'Source: ${[
              if (b != null) 'blood lab',
              'meal diary',
              if (result.intakeFromSupplements > 0) 'supplement records',
              if (result.medications.isNotEmpty) 'medication records',
            ].join(', ')}.',
            style: BMHText.monoSm.copyWith(
              fontSize: 8.5, color: BMHColors.inkFaint, height: 1.4)),
        ]));
  }

  static Widget _swatch(Color c) => Container(
    width: 7, height: 7,
    decoration: BoxDecoration(
      color: c, borderRadius: BorderRadius.circular(2)));
}

// ─────────────────────────────────────────────────────────
//  INTAKE BAR — food segment, supplement segment, target tick
// ─────────────────────────────────────────────────────────
class _IntakeBar extends StatelessWidget {
  final double food;
  final double supps;
  final double target;
  final double ceiling;

  const _IntakeBar({
    required this.food,
    required this.supps,
    required this.target,
    required this.ceiling,
  });

  @override
  Widget build(BuildContext context) {
    final total = food + supps;
    final pct = target <= 0 ? 0.0 : total / target * 100;
    final fillFrac = (pct / ceiling).clamp(0.0, 1.0);
    final tickFrac = (100 / ceiling).clamp(0.0, 1.0);
    final foodFlex = total <= 0 ? 100 : (food / total * 100).round();

    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      return SizedBox(height: 12, child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0, right: 0, top: 2,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: BMHColors.bg4,
                borderRadius: BorderRadius.circular(BMHRadius.full)))),
          Positioned(
            left: 0, top: 2, width: w * fillFrac,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BMHRadius.full),
              child: SizedBox(height: 8, child: Row(children: [
                Expanded(
                  flex: foodFlex.clamp(0, 100),
                  child: Container(color: _foodColor)),
                Expanded(
                  flex: (100 - foodFlex).clamp(0, 100),
                  child: Container(color: _suppColor)),
              ])))),
          // Dotted target marker
          Positioned(
            left: w * tickFrac - 1, top: -1,
            child: Column(children: [
              for (var i = 0; i < 4; i++) ...[
                Container(width: 2, height: 2, color: BMHColors.ink2),
                const SizedBox(height: 1.5),
              ],
            ])),
        ]));
    });
  }
}

// ─────────────────────────────────────────────────────────
//  BLOOD BAR — reference zone with a needle at the result
// ─────────────────────────────────────────────────────────
class _BloodBar extends StatelessWidget {
  final BloodMarker marker;
  const _BloodBar({required this.marker});

  @override
  Widget build(BuildContext context) {
    final c = markerColor(marker.status, marker.highIsGood);
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      final zs = marker.zoneStart, ze = marker.zoneEnd;
      final pos = marker.barPosition;
      return SizedBox(height: 14, child: Stack(children: [
        Positioned(
          left: 0, right: 0, top: 3,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: BMHColors.danger.withOpacity(0.16),
              borderRadius: BorderRadius.circular(BMHRadius.full)))),
        Positioned(
          left: zs * w, width: ((ze - zs) * w).clamp(2.0, w), top: 3,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: BMHColors.success.withOpacity(0.42),
              borderRadius: BorderRadius.circular(BMHRadius.full)))),
        Positioned(
          left: (pos * w - 1.5).clamp(0.0, w - 3), top: 0,
          child: Container(
            width: 3, height: 14,
            decoration: BoxDecoration(
              color: c, borderRadius: BorderRadius.circular(2)))),
      ]));
    });
  }
}

// ─────────────────────────────────────────────────────────
class _MarkerCard extends StatelessWidget {
  final BloodMarker marker;
  const _MarkerCard({required this.marker});

  @override
  Widget build(BuildContext context) {
    final c = markerColor(marker.status, marker.highIsGood);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: c.withOpacity(0.28))),
      child: Column(children: [
        Row(children: [
          Expanded(child: Row(children: [
            Flexible(child: Text(marker.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BMHText.labelMd.copyWith(color: BMHColors.ink))),
            if (marker.priority) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BMHColors.danger.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(BMHRadius.full)),
                child: Text('PRIORITY',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 7, letterSpacing: 0.5,
                    color: BMHColors.danger,
                    fontWeight: FontWeight.w700))),
            ],
          ])),
          const SizedBox(width: 8),
          Text('${fmtNum(marker.value)} ${marker.unit}',
            style: BMHText.monoMd.copyWith(
              fontSize: 12, color: c, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.withOpacity(0.14),
              borderRadius: BorderRadius.circular(BMHRadius.full)),
            child: Text(
              marker.highIsGood && marker.status == MarkerStatus.high
                ? 'HIGH — PROTECTIVE'
                : marker.status.label,
              style: BMHText.monoSm.copyWith(
                fontSize: 8, color: c, fontWeight: FontWeight.w700))),
          const Spacer(),
          Text('ref ${fmtNum(marker.refLow)}–${fmtNum(marker.refHigh)} '
               '${marker.unit}',
            style: BMHText.monoSm.copyWith(
              fontSize: 8.5, color: BMHColors.inkMute)),
        ]),
        const SizedBox(height: 11),
        RangeBar(marker: marker, color: c),
        if (marker.note.isNotEmpty) ...[
          const SizedBox(height: 11),
          Text(marker.note,
            style: BMHText.bodySm.copyWith(
              fontSize: 10.5, color: BMHColors.inkDim, height: 1.5)),
        ],
      ]));
  }
}

// ─────────────────────────────────────────────────────────
//  Shared by the full-report screen
// ─────────────────────────────────────────────────────────
class RangeBar extends StatelessWidget {
  final BloodMarker marker;
  final Color color;
  const RangeBar({super.key, required this.marker, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      final zs = marker.zoneStart, ze = marker.zoneEnd;
      final pos = marker.barPosition;
      return SizedBox(height: 26, child: Stack(children: [
        Positioned(
          left: 0, right: 0, top: 10,
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: BMHColors.danger.withOpacity(0.16),
              borderRadius: BorderRadius.circular(BMHRadius.full)))),
        Positioned(
          left: zs * w, width: ((ze - zs) * w).clamp(2.0, w), top: 10,
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: BMHColors.success.withOpacity(0.5),
              borderRadius: BorderRadius.circular(BMHRadius.full)))),
        Positioned(
          left: (pos * w - 5).clamp(0.0, w - 10), top: 2,
          child: Column(children: [
            Container(
              width: 10, height: 7,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2))),
            Container(width: 2, height: 14, color: color),
          ])),
      ]));
    });
  }
}
