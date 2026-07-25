// ─────────────────────────────────────────────────────────
//  BIORESPONSE — BODY COMPOSITION
//
//  How weight, body fat and lean mass respond to food,
//  supplements and medication — the same view the provider's
//  BioResponse dashboard shows, brought into the app.
//
//  Each metric carries a small trend line with a dot per reading
//  so the direction reads at a glance. Drivers are grouped by what
//  they are — food, medication, supplement — and say whether each
//  is helping, holding things back, or has no clear effect.
//
//  Text is BMHColors.ink (white) throughout so nothing reads dim
//  on the dark theme.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';

// ── DATA ──────────────────────────────────────────────────
enum DriverTone { helping, holding }

class _Metric {
  final String label;
  final String value;
  final List<double> series;
  final String trend;
  const _Metric(this.label, this.value, this.series, this.trend);
}

class _Driver {
  final String name;
  final String type;      // Food | Medication | Supplement
  final DriverTone tone;
  final String label;     // Helping / No clear effect / …
  final String note;
  const _Driver(this.name, this.type, this.tone, this.label, this.note);
}

const _metrics = <_Metric>[
  _Metric('Weight', '79.0 kg',
    [82.0, 81.2, 80.8, 80.1, 79.6, 79.2, 79.0], 'down 3.0 kg'),
  _Metric('Body fat', '22.4%',
    [24.1, 23.8, 23.4, 23.0, 22.8, 22.6, 22.4], 'down from 24.1'),
  _Metric('Lean mass', '61.3 kg',
    [60.7, 60.9, 61.0, 61.1, 61.2, 61.25, 61.3], 'up 0.6 kg'),
  _Metric('Visceral fat', '8',
    [10, 9.6, 9.2, 8.8, 8.5, 8.2, 8.0], 'down from 10'),
];

const _drivers = <_Driver>[
  _Driver('Lower refined carbohydrate', 'Food', DriverTone.helping,
    'Helping', 'Weight down 3 kg with lean mass preserved on the scale.'),
  _Driver('Reduced saturated fat, plant sterols', 'Food',
    DriverTone.holding, 'No clear effect',
    'Acts on blood lipids rather than body composition.'),
  _Driver('Metformin', 'Medication', DriverTone.helping, 'Slight help',
    'Associated with modest weight reduction.'),
  _Driver('Omeprazole (PPI)', 'Medication', DriverTone.holding,
    'No clear effect', 'No association with body composition.'),
  _Driver('Vitamin D 2000 IU', 'Supplement', DriverTone.holding,
    'No clear effect', 'No association with body composition.'),
  _Driver('Vitamin C 500 mg', 'Supplement', DriverTone.holding,
    'No clear effect', 'No association with body composition.'),
];

class BodyCompositionScreen extends StatelessWidget {
  const BodyCompositionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: SafeArea(child: Column(children: [
        // ── HEADER ──────────────────────────────────────
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
                Text('Body composition', style: BMHText.heading1),
              ])),
          ])),

        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BMHSpacing.s5, 6, BMHSpacing.s5, 40),
          children: [
            Text(
              'How your weight, body fat and lean mass respond to your '
              'food, your supplements and your medication.',
              style: BMHText.bodySm.copyWith(
                fontSize: 11.5, color: BMHColors.ink, height: 1.5)),
            const SizedBox(height: 18),

            BMHSectionTitle('Where your body composition stands'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [for (final m in _metrics) _MetricCard(metric: m)]),

            const SizedBox(height: 24),
            BMHSectionTitle('What is moving the numbers'),
            const SizedBox(height: 6),
            Text('Grouped by what it is, with whether it helps.',
              style: BMHText.bodySm.copyWith(
                fontSize: 11, color: BMHColors.ink)),
            const SizedBox(height: 14),
            for (final t in const ['Food', 'Medication', 'Supplement'])
              ..._driverGroup(t),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BMHColors.bg2,
                borderRadius: BorderRadius.circular(BMHRadius.md),
                border: Border.all(color: BMHColors.line)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                    color: BMHColors.sMetabolic, size: 14),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'These readings come from your BioScale and are a '
                    'general wellness guide, not medical advice. Speak to '
                    'your care team before changing a diet, supplement or '
                    'medicine.',
                    style: BMHText.bodySm.copyWith(
                      fontSize: 10.5, color: BMHColors.ink, height: 1.5))),
                ])),
          ])),
      ])),
    );
  }

  List<Widget> _driverGroup(String type) {
    final items = _drivers.where((d) => d.type == type).toList();
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(type.toUpperCase(),
          style: BMHText.monoSm.copyWith(
            fontSize: 8.5, letterSpacing: 1.3, color: BMHColors.ink2))),
      for (final d in items) ...[
        _DriverCard(driver: d),
        const SizedBox(height: 9),
      ],
      const SizedBox(height: 8),
    ];
  }
}

// ── METRIC CARD ───────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final _Metric metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.label,
            style: BMHText.monoSm.copyWith(
              fontSize: 9, letterSpacing: 0.5, color: BMHColors.ink2)),
          const SizedBox(height: 4),
          Text(metric.value,
            style: BMHText.heading3.copyWith(
              fontSize: 20, color: BMHColors.ink)),
          const Spacer(),
          SizedBox(height: 26,
            child: _Spark(series: metric.series)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.trending_flat_rounded,
              size: 12, color: BMHColors.sGut),
            const SizedBox(width: 4),
            Flexible(child: Text(metric.trend,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: BMHText.monoSm.copyWith(
                fontSize: 8.5, color: BMHColors.sGut,
                fontWeight: FontWeight.w700))),
          ]),
        ]));
  }
}

// ── SPARKLINE — line with a dot per reading ───────────────
class _Spark extends StatelessWidget {
  final List<double> series;
  const _Spark({required this.series});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) => CustomPaint(
      size: Size(box.maxWidth, box.maxHeight),
      painter: _SparkPainter(series)));
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> series;
  _SparkPainter(this.series);

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;
    final lo = series.reduce((a, b) => a < b ? a : b);
    final hi = series.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) * 0.2 + 0.0001;
    final min = lo - pad, max = hi + pad;

    double x(int i) => size.width * i / (series.length - 1);
    double y(double v) => size.height - (v - min) / (max - min) * size.height;

    final pts = [
      for (var i = 0; i < series.length; i++) Offset(x(i), y(series[i]))
    ];

    final line = Paint()
      ..color = BMHColors.sBody.withOpacity(0.7)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, line);

    // a dot per reading, the last one accented
    for (var i = 0; i < pts.length; i++) {
      final last = i == pts.length - 1;
      canvas.drawCircle(pts[i], last ? 3.2 : 2.0,
        Paint()..color = BMHColors.bg0);
      canvas.drawCircle(pts[i], last ? 2.4 : 1.4,
        Paint()..color = last ? BMHColors.sMetabolic : BMHColors.sBody);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.series != series;
}

// ── DRIVER CARD ───────────────────────────────────────────
class _DriverCard extends StatelessWidget {
  final _Driver driver;
  const _DriverCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final helping = driver.tone == DriverTone.helping;
    final c = helping ? BMHColors.sGut : BMHColors.inkMute;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(driver.name,
              style: BMHText.labelMd.copyWith(color: BMHColors.ink))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: c.withOpacity(0.14),
                borderRadius: BorderRadius.circular(BMHRadius.full),
                border: Border.all(color: c.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 5, height: 5,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                Text(driver.label,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 8.5, color: c, fontWeight: FontWeight.w700)),
              ])),
          ]),
          const SizedBox(height: 6),
          Text(driver.note,
            style: BMHText.bodySm.copyWith(
              fontSize: 10.5, color: BMHColors.ink, height: 1.45)),
        ]));
  }
}
