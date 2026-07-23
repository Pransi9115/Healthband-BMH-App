// ─────────────────────────────────────────────────────────
//  BIORESPONSE — BIOMARKERS
//  Three views:
//    Linked  · intake read against the blood result
//    Intake  · everything going in (food + supplements)
//    Blood   · the panel BMH ran
//
//  Counts shown are computed from the markers themselves, so the
//  headline always matches what the patient can count on screen.
//  Markers the clinician flagged are surfaced as priority, but
//  nothing outside range is hidden from the total.
//
//  The per day / per week range applies to intake. A blood result
//  is one lab measurement on one date, so it does not move with
//  the range — the screen says so rather than implying otherwise.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/biomarker_link_service.dart';
import '../../core/bioresponse/blood_report_service.dart';
import '../../core/bioresponse/nutritional_score_service.dart';
import '../../core/bioresponse/supplement_service.dart';
import '../../core/diet/diet_service.dart';
import 'blood_report_screen.dart';
import 'supplements_screen.dart';

enum _View { linked, intake, blood }

Color markerColor(MarkerStatus s, bool highIsGood) => switch (s) {
      MarkerStatus.low => BMHColors.warn,
      MarkerStatus.high => highIsGood ? BMHColors.success : BMHColors.danger,
      MarkerStatus.borderline => BMHColors.sMetabolic,
      MarkerStatus.inRange => BMHColors.success,
    };

String fmtNum(double v) => v >= 1000
    ? v.round().toString()
    : v == v.roundToDouble()
        ? v.round().toString()
        : v.abs() < 1
            ? v.toStringAsFixed(2)
            : v.toStringAsFixed(1);

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
  final _diet = DietService.instance;
  final _score = NutritionalScoreService.instance;

  late ScoreRange _range;
  _View _view = _View.linked;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    _blood.addListener(_refresh);
    _supps.addListener(_refresh);
    _boot();
  }

  Future<void> _boot() async {
    await _blood.init();
    await _supps.init();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = _blood.report;

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
            BMHIconButton(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SupplementsScreen())),
              icon: const Icon(Icons.medication_outlined,
                color: BMHColors.cyan, size: 16)),
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
              _tab('Linked', _View.linked),
              _tab('Intake', _View.intake),
              _tab('Blood', _View.blood),
            ]))),

        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BMHSpacing.s5, 14, BMHSpacing.s5, 40),
          children: switch (_view) {
            _View.linked => _linkedView(report),
            _View.intake => _intakeView(),
            _View.blood => _bloodView(report),
          })),
      ])),
    );
  }

  Widget _tab(String label, _View v) => Expanded(child: GestureDetector(
    onTap: () => setState(() => _view = v),
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: _view == v ? BMHColors.cyan : Colors.transparent,
        borderRadius: BorderRadius.circular(BMHRadius.full)),
      child: Text(label,
        textAlign: TextAlign.center,
        style: BMHText.labelMd.copyWith(
          color: _view == v ? BMHColors.bg0 : BMHColors.inkDim,
          fontWeight: _view == v ? FontWeight.w700 : FontWeight.w500)))));

  Widget _rangeControl({required String note}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
                  color: r == _range ? BMHColors.sGut : Colors.transparent,
                  borderRadius: BorderRadius.circular(BMHRadius.full)),
                child: Text(r.label,
                  textAlign: TextAlign.center,
                  style: BMHText.labelMd.copyWith(
                    color: r == _range ? BMHColors.bg0 : BMHColors.inkDim,
                    fontWeight: r == _range
                      ? FontWeight.w700 : FontWeight.w500))))),
        ])),
      const SizedBox(height: 9),
      Text(note,
        style: BMHText.bodySm.copyWith(
          fontSize: 10.5, color: BMHColors.inkMute, height: 1.45)),
      const SizedBox(height: 16),
    ]);

  // ═══════════════ LINKED ═══════════════════════════════
  List<Widget> _linkedView(BloodReport? report) {
    final results = _links.allResults(_range);
    final attention = results.where((r) => r.needsAttention).length;
    final c = attention > 0 ? BMHColors.warn : BMHColors.success;

    return [
      _rangeControl(
        note: 'The range applies to your intake. Blood results come from '
              'your test on ${report == null ? "—" : fmtDate(report.testDate)} '
              'and do not change with the range.'),

      if (_blood.isSample) _sampleBanner(),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [c.withOpacity(0.13), BMHColors.bg2]),
          borderRadius: BorderRadius.circular(BMHRadius.xl),
          border: Border.all(color: c.withOpacity(0.3))),
        child: Row(children: [
          Icon(attention > 0
              ? Icons.compare_arrows_rounded
              : Icons.check_circle_outline_rounded,
            color: c, size: 26),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attention > 0
                  ? '$attention of ${results.length} need a closer look'
                  : 'Intake and blood line up',
                style: BMHText.labelLg.copyWith(color: BMHColors.ink)),
              const SizedBox(height: 3),
              Text('What you take in, read against what your blood shows.',
                style: BMHText.bodySm.copyWith(
                  fontSize: 11, color: BMHColors.inkDim)),
            ])),
        ])),

      const SizedBox(height: 22),
      BMHSectionTitle('Intake vs blood'),
      const SizedBox(height: 12),

      for (final r in results) ...[
        _LinkCard(result: r),
        const SizedBox(height: 11),
      ],

      const SizedBox(height: 6),
      _footNote(
        'Intake and blood use different units and are never added '
        'together. The app compares whether each side is low, on target '
        'or high, then reads the pair.'),
    ];
  }

  // ═══════════════ INTAKE ═══════════════════════════════
  List<Widget> _intakeView() {
    final rows = _links.fullIntake(_range);
    final days = rows.isEmpty ? 0 : rows.first.days;
    final suppCount = _supps.active.length;

    return [
      _rangeControl(
        note: days == 0
          ? 'Nothing logged in this range yet.'
          : _range == ScoreRange.day
            ? 'From the meals and supplements you logged today.'
            : 'Daily average across $days of the last 7 days with '
              'anything logged.'),

      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const SupplementsScreen())),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: BMHColors.surface,
            borderRadius: BorderRadius.circular(BMHRadius.lg),
            border: Border.all(color: BMHColors.cyan.withOpacity(0.25))),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: BMHColors.cyan.withOpacity(0.10),
                borderRadius: BorderRadius.circular(BMHRadius.md),
                border: Border.all(color: BMHColors.cyan.withOpacity(0.22))),
              child: const Icon(Icons.medication_outlined,
                color: BMHColors.cyan, size: 20)),
            const SizedBox(width: 13),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Supplements',
                  style: BMHText.labelLg.copyWith(color: BMHColors.ink)),
                const SizedBox(height: 3),
                Text(
                  suppCount == 0
                    ? 'None added — tap to add what you take'
                    : '$suppCount added · '
                      '${_supps.takenCount(DateTime.now())} taken today',
                  style: BMHText.bodySm.copyWith(
                    fontSize: 11, color: BMHColors.inkDim)),
              ])),
            const Icon(Icons.chevron_right_rounded,
              color: BMHColors.inkDim, size: 20),
          ]))),

      const SizedBox(height: 22),
      BMHSectionTitle('Nutrients in'),
      const SizedBox(height: 6),
      Text('Food and supplements combined, against the daily target.',
        style: BMHText.bodySm.copyWith(
          fontSize: 10.5, color: BMHColors.inkMute)),
      const SizedBox(height: 14),

      if (days == 0)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
          decoration: BoxDecoration(
            color: BMHColors.surface,
            borderRadius: BorderRadius.circular(BMHRadius.lg),
            border: Border.all(color: BMHColors.line)),
          child: Column(children: [
            const Icon(Icons.restaurant_menu_outlined,
              color: BMHColors.inkMute, size: 30),
            const SizedBox(height: 11),
            Text('Nothing logged yet',
              style: BMHText.labelLg.copyWith(color: BMHColors.ink2)),
            const SizedBox(height: 6),
            Text('Log meals in BioMedical Diet and add your supplements '
                 'to see everything going in.',
              textAlign: TextAlign.center,
              style: BMHText.bodySm.copyWith(
                fontSize: 11, color: BMHColors.inkMute, height: 1.5)),
          ]))
      else
        for (final r in rows) ...[
          _IntakeRow(
            name: r.micro.name,
            unit: r.micro.unit,
            food: r.food,
            supps: r.supps,
            target: r.micro.rda),
          const SizedBox(height: 10),
        ],
    ];
  }

  // ═══════════════ BLOOD ════════════════════════════════
  List<Widget> _bloodView(BloodReport? report) {
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
            Text('Tested ${fmtDate(report.testDate)}',
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
                Row(children: [
                  const Icon(Icons.priority_high_rounded,
                    color: BMHColors.danger, size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    '${report.priorityCount} of the ${report.concernCount} '
                    'were flagged by your clinician as needing attention '
                    'first',
                    style: BMHText.bodySm.copyWith(
                      fontSize: 10.5, color: BMHColors.ink2, height: 1.4))),
                ]),
              if (report.favourableCount > 0) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.check_circle_outline_rounded,
                    color: BMHColors.success, size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    '${report.favourableCount} marker above its range is a '
                    'good result and is not counted as a concern',
                    style: BMHText.bodySm.copyWith(
                      fontSize: 10.5, color: BMHColors.ink2, height: 1.4))),
                ]),
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
        'This panel is prepared from a blood sample without access to '
        'your full medical records. It must not be used to diagnose or '
        'treat any condition — always speak to a medical professional '
        'before acting on it.'),
    ];
  }

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
//  LINK CARD — the intake ↔ blood pairing
// ─────────────────────────────────────────────────────────
class _LinkCard extends StatelessWidget {
  final LinkResult result;
  const _LinkCard({required this.result});

  Color get _c => switch (result.verdict) {
        LinkVerdict.matched => BMHColors.success,
        LinkVerdict.dietGap => BMHColors.warn,
        LinkVerdict.absorption => BMHColors.sNervous,
        LinkVerdict.overSupplement => BMHColors.danger,
        LinkVerdict.watch => BMHColors.sMetabolic,
        LinkVerdict.unknown => BMHColors.inkMute,
      };

  IconData get _icon => switch (result.verdict) {
        LinkVerdict.matched => Icons.check_circle_outline_rounded,
        LinkVerdict.dietGap => Icons.trending_down_rounded,
        LinkVerdict.absorption => Icons.help_outline_rounded,
        LinkVerdict.overSupplement => Icons.trending_up_rounded,
        LinkVerdict.watch => Icons.visibility_outlined,
        LinkVerdict.unknown => Icons.remove_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final blood = result.blood;
    final pct = result.intakePercent.clamp(0, 999).toDouble();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: _c.withOpacity(0.26))),
      child: Column(children: [
        Row(children: [
          Icon(_icon, color: _c, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(result.link.name,
            style: BMHText.labelLg.copyWith(color: BMHColors.ink))),
          Flexible(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _c.withOpacity(0.14),
              borderRadius: BorderRadius.circular(BMHRadius.full)),
            child: Text(result.verdict.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BMHText.monoSm.copyWith(
                fontSize: 8.5, color: _c, fontWeight: FontWeight.w700)))),
        ]),

        const SizedBox(height: 14),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GOING IN',
                style: BMHText.monoSm.copyWith(
                  fontSize: 8, letterSpacing: 1.2, color: BMHColors.inkDim)),
              const SizedBox(height: 5),
              Text(
                result.hasIntake
                  ? '${fmtNum(result.intakeTotal)} ${result.intakeUnit}'
                  : '—',
                style: BMHText.monoMd.copyWith(
                  fontSize: 14, color: BMHColors.ink,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                result.hasIntake ? '${pct.round()}% of target' : 'not logged',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkDim)),
              if (result.intakeFromSupplements > 0) ...[
                const SizedBox(height: 3),
                Text(
                  'food ${fmtNum(result.intakeFromFood)} · '
                  'supp ${fmtNum(result.intakeFromSupplements)}',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 8, color: BMHColors.inkMute)),
              ],
            ])),

          Container(
            width: 1, height: 46,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: BMHColors.line),

          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IN BLOOD',
                style: BMHText.monoSm.copyWith(
                  fontSize: 8, letterSpacing: 1.2, color: BMHColors.inkDim)),
              const SizedBox(height: 5),
              Text(
                blood == null ? '—' : '${fmtNum(blood.value)} ${blood.unit}',
                style: BMHText.monoMd.copyWith(
                  fontSize: 14,
                  color: blood == null
                    ? BMHColors.inkMute
                    : markerColor(blood.status, blood.highIsGood),
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                blood == null
                  ? 'not in panel'
                  : '${blood.status.label.toLowerCase()} · ref '
                    '${fmtNum(blood.refLow)}–${fmtNum(blood.refHigh)}',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkDim)),
            ])),
        ]),

        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: BMHColors.bg2,
            borderRadius: BorderRadius.circular(BMHRadius.sm)),
          child: Text(result.message,
            style: BMHText.bodySm.copyWith(
              fontSize: 10.5, color: BMHColors.ink2, height: 1.5))),
      ]));
  }
}

// ─────────────────────────────────────────────────────────
class _IntakeRow extends StatelessWidget {
  final String name;
  final String unit;
  final double food;
  final double supps;
  final double target;

  const _IntakeRow({
    required this.name,
    required this.unit,
    required this.food,
    required this.supps,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final total = food + supps;
    final pct = target <= 0 ? 0.0 : (total / target * 100);
    final c = pct >= 150 ? BMHColors.sMetabolic
        : pct >= 90 ? BMHColors.success
        : pct >= 60 ? BMHColors.sGut
        : pct >= 30 ? BMHColors.warn
        : BMHColors.danger;
    final foodFlex = total <= 0 ? 100 : (food / total * 100).round();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: BMHColors.line)),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(name,
            style: BMHText.labelMd.copyWith(color: BMHColors.ink))),
          Text('${fmtNum(total)} / ${fmtNum(target)} $unit',
            style: BMHText.monoSm.copyWith(
              fontSize: 10, color: BMHColors.inkDim)),
        ]),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(BMHRadius.full),
          child: SizedBox(height: 6, child: Stack(children: [
            Container(color: BMHColors.bg4),
            FractionallySizedBox(
              widthFactor: (pct / 100).clamp(0.0, 1.0),
              child: Row(children: [
                Expanded(
                  flex: foodFlex.clamp(0, 100),
                  child: Container(color: c)),
                Expanded(
                  flex: (100 - foodFlex).clamp(0, 100),
                  child: Container(color: c.withOpacity(0.45))),
              ])),
          ]))),
        const SizedBox(height: 7),
        Row(children: [
          Text('${pct.round()}%',
            style: BMHText.monoSm.copyWith(
              fontSize: 9.5, color: c, fontWeight: FontWeight.w700)),
          const SizedBox(width: 9),
          Expanded(child: Text(
            supps > 0
              ? 'food ${fmtNum(food)} · supplements ${fmtNum(supps)}'
              : 'from food only',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BMHText.monoSm.copyWith(
              fontSize: 8.5, color: BMHColors.inkMute))),
        ]),
      ]));
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
//  RANGE BAR — green in-range zone with a needle at the result
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
