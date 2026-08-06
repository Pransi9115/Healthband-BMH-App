// ─────────────────────────────────────────────────────────
//  BIO BODY TRACK
//
//  The full body composition report on one screen.
//
//  Every number comes from BodyCompositionService, which serves a
//  demo fixture until the FG2001B-A feed is wired. That is stated at
//  the top of the screen rather than hidden — showing invented
//  numbers as though they were the patient's own is the one thing
//  this screen must never do.
//
//  ORDER
//  Score and weight first, because that is what people came for.
//  Then the composition table, then what to change, then the
//  breakdowns, and raw impedance last — it is the evidence behind
//  everything above, and whoever wants it will scroll.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../../core/body/body_composition.dart';
import '../../core/body/body_composition_service.dart';

const _accent = BMHColors.sBody;

class BodyTrackScreen extends StatefulWidget {
  const BodyTrackScreen({super.key});

  @override
  State<BodyTrackScreen> createState() => _BodyTrackScreenState();
}

class _BodyTrackScreenState extends State<BodyTrackScreen> {
  final _svc = BodyCompositionService.instance;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_refresh);
    _svc.init();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _svc.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _svc.latest;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 0),
      body: Stack(children: [
        Positioned(top: -160, right: -110,
          child: Container(width: 420, height: 420,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _accent.withOpacity(0.08), Colors.transparent])))),

        SafeArea(bottom: false, child: Column(children: [
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
                  const BMHEyebrow('BIOSCALE'),
                  Text('Bio Body Track', style: BMHText.heading1),
                ])),
            ])),

          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BMHSpacing.s5, 4, BMHSpacing.s5, 40),
            children: [
              if (_svc.isDemo) _demoBanner(),
              for (final w in c.warnings) _warningCard(w),

              _hero(c),
              const SizedBox(height: 22),

              _section('Body composition'),
              const SizedBox(height: 10),
              for (final m in c.compositionTable) ...[
                _MetricRow(metric: m),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 14),
              _section('What to change'),
              const SizedBox(height: 10),
              _controls(c),

              const SizedBox(height: 22),
              _section('Where you sit'),
              const SizedBox(height: 10),
              _assessment(c),

              const SizedBox(height: 22),
              _section('Body type'),
              const SizedBox(height: 10),
              _bodyType(c),

              if (c.segmentMuscle.isNotEmpty) ...[
                const SizedBox(height: 22),
                _section('Muscle balance'),
                const SizedBox(height: 6),
                _hint('Each segment against what is expected for your '
                      'height, age and sex. 100% is exactly expected.'),
                const SizedBox(height: 10),
                for (final s in c.segmentMuscle)
                  _SegmentRow(reading: s, isMuscle: true),
              ],

              if (c.segmentFat.isNotEmpty) ...[
                const SizedBox(height: 14),
                _section('Segmental fat'),
                const SizedBox(height: 6),
                _hint('Inferred from whole-body impedance rather than '
                      'measured limb by limb, so read it as a pattern '
                      'rather than a precise figure.'),
                const SizedBox(height: 10),
                for (final s in c.segmentFat)
                  _SegmentRow(reading: s, isMuscle: false),
              ],

              const SizedBox(height: 14),
              _section('Other indicators'),
              const SizedBox(height: 10),
              _indicators(c),

              if (_svc.trend.length > 1) ...[
                const SizedBox(height: 22),
                _section('Trend'),
                const SizedBox(height: 10),
                _trendChart(),
              ],

              if (c.impedance.isNotEmpty) ...[
                const SizedBox(height: 22),
                _section('Bioelectrical impedance'),
                const SizedBox(height: 6),
                _hint('The raw resistance the scale measured. Every '
                      'estimate above is calculated from these numbers '
                      'plus your height, age and sex.'),
                const SizedBox(height: 10),
                _impedance(c),
              ],

              const SizedBox(height: 20),
              _footnote(),
            ])),
        ])),
      ]));
  }

  // ── PIECES ──────────────────────────────────────────────
  Widget _section(String s) => Text(s.toUpperCase(),
    style: BMHText.monoSm.copyWith(
      fontSize: 10, letterSpacing: 1.5, color: BMHColors.inkDim));

  Widget _hint(String s) => Text(s,
    style: BMHText.bodySm.copyWith(
      fontSize: 10.5, color: BMHColors.inkMute, height: 1.45));

  Widget _demoBanner() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: BMHColors.warn.withOpacity(0.09),
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.warn.withOpacity(0.35))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.science_outlined, color: BMHColors.warn, size: 15),
      const SizedBox(width: 10),
      Expanded(child: Text(
        'Sample data. These are not your measurements — the BioScale '
        'feed is not connected yet, so this is here to show the layout.',
        style: BMHText.bodySm.copyWith(
          fontSize: 11, color: BMHColors.ink2, height: 1.45))),
    ]));

  Widget _warningCard(BodyCompositionWarning w) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: BMHColors.rangeOut.withOpacity(0.09),
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.rangeOut.withOpacity(0.35))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline_rounded,
        color: BMHColors.rangeOut, size: 15),
      const SizedBox(width: 10),
      Expanded(child: Text(w.message,
        style: BMHText.bodySm.copyWith(
          fontSize: 11, color: BMHColors.ink2, height: 1.45))),
    ]));

  Widget _hero(BodyComposition c) {
    final score = c.bodyScore;
    final tone = score >= 80
      ? BMHColors.rangeIn
      : score >= 60 ? _accent : BMHColors.rangeEdge;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [tone.withOpacity(0.12), tone.withOpacity(0.02)]),
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: tone.withOpacity(0.35))),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BMHEyebrow('Body score'),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$score',
                  style: BMHText.displayMd.copyWith(
                    fontSize: 44, color: tone, height: 1)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7, left: 4),
                  child: Text('/100',
                    style: BMHText.bodySm.copyWith(
                      fontSize: 12, color: BMHColors.inkDim))),
              ]),
            ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('WEIGHT',
              style: BMHText.monoSm.copyWith(
                fontSize: 9, letterSpacing: 1, color: BMHColors.inkDim)),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(c.weightKg.toStringAsFixed(1),
                style: BMHText.displayMd.copyWith(
                  fontSize: 30, color: BMHColors.ink, height: 1)),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 3),
                child: Text('kg',
                  style: BMHText.bodySm.copyWith(
                    fontSize: 11, color: BMHColors.inkDim))),
            ]),
            const SizedBox(height: 3),
            Text('BMI ${c.bmi.toStringAsFixed(1)} · ${c.bmiBand}',
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.inkDim)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(
            'Measured ${_fmtDateTime(c.measuredAt)} · ${c.source}',
            style: BMHText.monoSm.copyWith(
              fontSize: 9, color: BMHColors.inkMute))),
        ]),
      ]));
  }

  Widget _controls(BodyComposition c) {
    Widget row(String label, double kg) {
      final none = kg.abs() < 0.1;
      final tone = none ? BMHColors.rangeIn : BMHColors.rangeEdge;
      final text = none
        ? 'On target'
        : '${kg > 0 ? "+" : ""}${kg.toStringAsFixed(1)} kg';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Expanded(child: Text(label,
            style: BMHText.bodySm.copyWith(
              fontSize: 12.5, color: BMHColors.ink2))),
          Text(text,
            style: BMHText.labelMd.copyWith(fontSize: 13, color: tone)),
        ]));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Expanded(child: Text('Suggested target weight',
              style: BMHText.bodySm.copyWith(
                fontSize: 12.5, color: BMHColors.ink2))),
            Text('${c.targetWeightKg.toStringAsFixed(1)} kg',
              style: BMHText.labelMd.copyWith(
                fontSize: 13, color: BMHColors.ink)),
          ])),
        Divider(height: 1, color: BMHColors.line.withOpacity(0.6)),
        row('Weight change', c.weightControlKg),
        row('From fat', c.fatControlKg),
        row('From muscle', c.muscleControlKg),
        const SizedBox(height: 4),
        Text(
          'A range to steer by, not an instruction. Which direction fat '
          'and muscle move over months matters far more than hitting '
          'any particular number.',
          style: BMHText.bodySm.copyWith(
            fontSize: 10, color: BMHColors.inkMute, height: 1.45)),
        const SizedBox(height: 8),
      ]));
  }

  Widget _assessment(BodyComposition c) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.lg),
      border: Border.all(color: BMHColors.line)),
    child: Column(children: [
      _BandStrip(
        label: 'BMI',
        value: c.bmi.toStringAsFixed(1),
        bands: const ['Thin', 'Standard', 'High', 'Too high'],
        activeIndex: switch (c.bmiBand) {
          'Thin' => 0, 'Standard' => 1, 'High' => 2, _ => 3 }),
      const SizedBox(height: 14),
      _BandStrip(
        label: 'Body fat',
        value: '${c.bodyFatPct.toStringAsFixed(1)}%',
        bands: const ['Thin', 'Standard', 'High', 'Too high'],
        activeIndex: switch (c.fatBand) {
          'Thin' => 0, 'Standard' => 1, 'High' => 2, _ => 3 }),
      const SizedBox(height: 14),
      _BandStrip(
        label: 'Weight against target',
        value: '${c.weightVsTargetPct.round()}%',
        bands: const ['Low', 'Normal', 'High'],
        activeIndex: switch (c.weightVsTargetBand) {
          'Low' => 0, 'Normal' => 1, _ => 2 }),
    ]));

  Widget _bodyType(BodyComposition c) {
    final t = c.bodyType;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: _accent.withOpacity(0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _accent.withOpacity(0.35))),
          child: const Icon(Icons.accessibility_new_rounded,
            color: _accent, size: 20)),
        const SizedBox(width: 13),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.label,
              style: BMHText.heading2.copyWith(
                fontSize: 18, color: BMHColors.ink)),
            const SizedBox(height: 4),
            Text(t.blurb,
              style: BMHText.bodySm.copyWith(
                fontSize: 11.5, color: BMHColors.inkDim, height: 1.45)),
            const SizedBox(height: 8),
            Text(
              'From BMI ${c.bmi.toStringAsFixed(1)} against '
              '${c.bodyFatPct.toStringAsFixed(1)}% body fat',
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.inkMute)),
          ])),
      ]));
  }

  Widget _indicators(BodyComposition c) {
    final items = <List<String>>[
      ['Visceral fat grade', '${c.visceralGrade}',
       c.visceralGrade <= 9 ? 'Within the healthy band' : 'Above the band'],
      ['Basal metabolic rate', '${c.bmrKcal.round()} kcal',
       'Energy used at complete rest'],
      ['Fat free mass', '${c.fatFreeMassKg.toStringAsFixed(1)} kg',
       'Everything that is not fat'],
      ['Subcutaneous fat', '${c.subcutaneousPct.toStringAsFixed(1)}%',
       'The fat sitting under the skin'],
      ['Skeletal muscle index', c.smi.toStringAsFixed(1),
       'Limb muscle scaled to height'],
      ['Body age', '${c.bodyAge}',
       'Composition compared with age ${c.age}'],
      ['Waist to hip ratio', c.whr.toStringAsFixed(2),
       'How fat is distributed'],
    ];

    return Container(
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 15, vertical: 11),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(items[i][0],
                    style: BMHText.bodySm.copyWith(
                      fontSize: 12.5, color: BMHColors.ink)),
                  const SizedBox(height: 2),
                  Text(items[i][2],
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9, color: BMHColors.inkMute)),
                ])),
              Text(items[i][1],
                style: BMHText.labelMd.copyWith(
                  fontSize: 13, color: _accent)),
            ])),
          if (i < items.length - 1)
            Divider(height: 1, color: BMHColors.line.withOpacity(0.5)),
        ],
      ]));
  }

  Widget _trendChart() {
    final pts = _svc.trend;
    final min = pts.map((p) => p.weightKg).reduce((a, b) => a < b ? a : b);
    final max = pts.map((p) => p.weightKg).reduce((a, b) => a > b ? a : b);
    final change = _svc.weightChange(days: 90);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(children: [
        if (change != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(children: [
              Expanded(child: Text(
                '${change > 0 ? "+" : ""}${change.toStringAsFixed(1)} kg '
                'over the last 90 days',
                style: BMHText.bodySm.copyWith(
                  fontSize: 11.5, color: BMHColors.ink2))),
            ])),
        SizedBox(height: 138, child: LineChart(LineChartData(
          minY: min - 1.5, maxY: max + 1.5,
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: BMHColors.line.withOpacity(0.5), strokeWidth: 1)),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < pts.length; i++)
                  FlSpot(i.toDouble(), pts[i].weightKg),
              ],
              isCurved: true,
              curveSmoothness: 0.28,
              color: _accent,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                  radius: 3, color: _accent,
                  strokeWidth: 2, strokeColor: BMHColors.bg0)),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _accent.withOpacity(0.22),
                    _accent.withOpacity(0.0)]))),
          ]))),
      ]));
  }

  Widget _impedance(BodyComposition c) {
    Widget cell(String s, {bool head = false, bool first = false}) =>
      Expanded(
        flex: first ? 3 : 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Text(s,
            textAlign: first ? TextAlign.left : TextAlign.right,
            style: BMHText.monoSm.copyWith(
              fontSize: head ? 8.5 : 10,
              letterSpacing: head ? 0.8 : 0,
              color: head ? BMHColors.inkDim : BMHColors.ink))));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(children: [
        Row(children: [
          cell('SEGMENT', head: true, first: true),
          cell('20 kHz', head: true),
          cell('100 kHz', head: true),
        ]),
        Divider(height: 1, color: BMHColors.line.withOpacity(0.6)),
        for (var i = 0; i < c.impedance.length; i++) ...[
          Row(children: [
            cell(c.impedance[i].segment.label, first: true),
            cell('${c.impedance[i].ohms20kHz.toStringAsFixed(1)} Ω'),
            cell('${c.impedance[i].ohms100kHz.toStringAsFixed(1)} Ω'),
          ]),
          if (i < c.impedance.length - 1)
            Divider(height: 1, color: BMHColors.line.withOpacity(0.35)),
        ],
        const SizedBox(height: 4),
      ]));
  }

  Widget _footnote() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: BMHColors.bg2,
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.line)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded,
        color: BMHColors.inkDim, size: 14),
      const SizedBox(width: 10),
      Expanded(child: Text(
        'A scale measures two things: your weight, and how easily a '
        'small current passes through you. Everything else here is '
        'estimated from those two, plus your height, age and sex. '
        'Readings move with hydration, food and time of day, so weigh '
        'yourself the same way each time and read the trend rather '
        'than any single morning.',
        style: BMHText.bodySm.copyWith(
          fontSize: 10.5, color: BMHColors.inkMute, height: 1.5))),
    ]));

  static String _fmtDateTime(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'am' : 'pm';
    return '${d.day} ${months[d.month - 1]}, $h:$m $ap';
  }
}

// ─────────────────────────────────────────────────────────
//  ONE COMPOSITION ROW
// ─────────────────────────────────────────────────────────
class _MetricRow extends StatelessWidget {
  final BodyMetric metric;
  const _MetricRow({required this.metric});

  static Color toneFor(BandStatus s) => switch (s) {
        BandStatus.low => BMHColors.rangeOut,
        BandStatus.high => BMHColors.rangeOut,
        BandStatus.standard => BMHColors.rangeIn,
        BandStatus.excellent => BMHColors.sBody,
      };

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(metric.status);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BMHText.labelLg.copyWith(color: BMHColors.ink))),
                if (metric.measured) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BMHColors.bg4,
                      borderRadius:
                        BorderRadius.circular(BMHRadius.full)),
                    child: Text('MEASURED',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 7, letterSpacing: 0.6,
                        color: BMHColors.inkDim))),
                ],
              ]),
              const SizedBox(height: 3),
              Text('Range ${metric.rangeLabel} ${metric.unit}',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkMute)),
            ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(metric.valueLabel,
                style: BMHText.heading2.copyWith(
                  fontSize: 19, color: tone)),
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 3),
                child: Text(metric.unit,
                  style: BMHText.bodySm.copyWith(
                    fontSize: 10, color: BMHColors.inkDim))),
            ]),
            const SizedBox(height: 2),
            Text(metric.status.label.toUpperCase(),
              style: BMHText.monoSm.copyWith(
                fontSize: 8.5, letterSpacing: 0.9, color: tone,
                fontWeight: FontWeight.w700)),
          ]),
        ]),

        const SizedBox(height: 11),
        _RangeBar(metric: metric),

        if (metric.description.isNotEmpty) ...[
          const SizedBox(height: 9),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(metric.description,
              style: BMHText.bodySm.copyWith(
                fontSize: 10.5, color: BMHColors.inkMute, height: 1.4))),
            if (metric.percentOfWeight != null) ...[
              const SizedBox(width: 10),
              Text('${metric.percentOfWeight!.toStringAsFixed(1)}%',
                style: BMHText.monoSm.copyWith(
                  fontSize: 10, color: BMHColors.inkDim)),
            ],
          ]),
        ],
      ]));
  }
}

// ─────────────────────────────────────────────────────────
//  Below range is red. Above range is red too, unless more is
//  better — muscle, protein, water, bone — where it is the body
//  accent instead, because telling someone their muscle is
//  dangerously high would be nonsense.
// ─────────────────────────────────────────────────────────
class _RangeBar extends StatelessWidget {
  final BodyMetric metric;
  const _RangeBar({required this.metric});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (ctx, box) {
      final w = box.maxWidth;
      final zs = metric.zoneStart, ze = metric.zoneEnd;

      Widget zone(double from, double to, Color c,
          {bool l = false, bool r = false}) {
        final left = (from * w).clamp(0.0, w);
        final width = ((to - from) * w).clamp(0.0, w);
        if (width <= 0) return const SizedBox.shrink();
        return Positioned(
          left: left, width: width, top: 6,
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(l ? BMHRadius.full : 0),
                right: Radius.circular(r ? BMHRadius.full : 0)))));
      }

      return SizedBox(height: 18, child: Stack(children: [
        zone(0, zs, BMHColors.rangeOut, l: true),
        zone(zs, ze, BMHColors.rangeIn),
        zone(ze, 1,
          metric.highIsGood ? BMHColors.sBody : BMHColors.rangeOut,
          r: true),
        Positioned(
          left: (metric.barPosition * w - 2.5).clamp(0.0, w - 5), top: 3,
          child: Container(
            width: 5, height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2.5),
              border: Border.all(
                color: BMHColors.bg0.withOpacity(0.55), width: 1)))),
      ]));
    });
}

// ─────────────────────────────────────────────────────────
class _SegmentRow extends StatelessWidget {
  final SegmentReading reading;
  final bool isMuscle;
  const _SegmentRow({required this.reading, required this.isMuscle});

  @override
  Widget build(BuildContext context) {
    final status = isMuscle ? reading.statusMuscle() : reading.statusFat();
    final tone = _MetricRow.toneFor(status);
    final pct = reading.percentOfExpected;

    // 60% to 160% of expected across the bar.
    final pos = ((pct - 60) / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(color: BMHColors.line)),
        child: Row(children: [
          SizedBox(width: 58, child: Text(reading.segment.shortLabel,
            style: BMHText.bodySm.copyWith(
              fontSize: 12, color: BMHColors.ink2))),
          Expanded(child: LayoutBuilder(builder: (ctx, box) {
            final w = box.maxWidth;
            return SizedBox(height: 14, child: Stack(children: [
              Positioned(
                left: 0, right: 0, top: 5,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: BMHColors.bg4,
                    borderRadius:
                      BorderRadius.circular(BMHRadius.full)))),
              Positioned(
                left: 0, width: (pos * w).clamp(0.0, w), top: 5,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius:
                      BorderRadius.circular(BMHRadius.full)))),
            ]));
          })),
          const SizedBox(width: 11),
          SizedBox(width: 50, child: Text(
            '${reading.massKg.toStringAsFixed(1)} kg',
            textAlign: TextAlign.right,
            style: BMHText.monoSm.copyWith(
              fontSize: 10, color: BMHColors.ink))),
          const SizedBox(width: 8),
          SizedBox(width: 38, child: Text('${pct.round()}%',
            textAlign: TextAlign.right,
            style: BMHText.monoSm.copyWith(fontSize: 10, color: tone))),
        ])));
  }
}

// ─────────────────────────────────────────────────────────
class _BandStrip extends StatelessWidget {
  final String label;
  final String value;
  final List<String> bands;
  final int activeIndex;

  const _BandStrip({
    required this.label,
    required this.value,
    required this.bands,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    // Middle band is where you want to be; the far end is red; a step
    // off centre is amber.
    final tone = activeIndex == 1
      ? BMHColors.rangeIn
      : activeIndex >= bands.length - 1
        ? BMHColors.rangeOut
        : BMHColors.rangeEdge;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label,
          style: BMHText.bodySm.copyWith(
            fontSize: 12, color: BMHColors.ink2))),
        Text(value,
          style: BMHText.labelMd.copyWith(fontSize: 13, color: tone)),
      ]),
      const SizedBox(height: 7),
      Row(children: [
        for (var i = 0; i < bands.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: i == activeIndex
                ? tone.withOpacity(0.18) : BMHColors.bg3,
              borderRadius: BorderRadius.circular(BMHRadius.sm),
              border: Border.all(
                color: i == activeIndex
                  ? tone.withOpacity(0.5) : Colors.transparent)),
            child: Text(bands[i],
              textAlign: TextAlign.center,
              style: BMHText.monoSm.copyWith(
                fontSize: 8.5,
                color: i == activeIndex ? tone : BMHColors.inkMute)))),
        ],
      ]),
    ]);
  }
}
