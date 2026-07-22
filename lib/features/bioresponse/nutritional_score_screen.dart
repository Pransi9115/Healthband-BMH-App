// ─────────────────────────────────────────────────────────
//  BIORESPONSE — NUTRITIONAL SCORE
//  All 11 goals scored from the patient's logged meals, with a
//  per day / per week range the patient controls. Tapping a goal
//  opens the nutrient-by-nutrient breakdown behind its score.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/nutritional_score_service.dart';
import '../../core/diet/diet_service.dart';

class NutritionalScoreScreen extends StatefulWidget {
  final ScoreRange initialRange;
  const NutritionalScoreScreen({
    super.key,
    this.initialRange = ScoreRange.day,
  });

  @override
  State<NutritionalScoreScreen> createState() =>
      _NutritionalScoreScreenState();
}

class _NutritionalScoreScreenState extends State<NutritionalScoreScreen> {
  final _svc = NutritionalScoreService.instance;
  final _diet = DietService.instance;
  late ScoreRange _range;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    _ensureWeek();
  }

  /// Weekly scoring reads six earlier days, which may not be in
  /// memory yet — load them before scoring.
  Future<void> _ensureWeek() async {
    for (final d in _svc.daysIn(ScoreRange.week, DateTime.now())) {
      await _diet.ensureDay(d);
    }
    if (mounted) setState(() {});
  }

  static Color colorFor(double s, bool hasData) {
    if (!hasData) return BMHColors.inkMute;
    if (s >= 80) return BMHColors.success;
    if (s >= 60) return BMHColors.sGut;
    if (s >= 40) return BMHColors.warn;
    return BMHColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final scores = _svc.scoreAll(_range);
    final logged = _svc.daysLogged(_range);
    final hasData = logged > 0;

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
                Text('Nutritional score', style: BMHText.heading1),
              ])),
          ])),

        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.s5),
          children: [
            const SizedBox(height: 6),

            // Range control
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
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: r == _range
                          ? BMHColors.cyan : Colors.transparent,
                        borderRadius:
                          BorderRadius.circular(BMHRadius.full)),
                      child: Text(r.label,
                        textAlign: TextAlign.center,
                        style: BMHText.labelMd.copyWith(
                          color: r == _range
                            ? BMHColors.bg0 : BMHColors.inkDim,
                          fontWeight: r == _range
                            ? FontWeight.w700 : FontWeight.w500))))),
              ])),
            const SizedBox(height: 10),

            Text(
              hasData
                ? _range == ScoreRange.day
                  ? 'Scored from the meals you logged today.'
                  : 'Scored from $logged of the last 7 days that have '
                    'logged meals. Days with no food are left out rather '
                    'than counted as zero.'
                : 'No meals logged in this range yet.',
              style: BMHText.bodySm.copyWith(
                fontSize: 11, color: BMHColors.inkMute, height: 1.45)),

            const SizedBox(height: 18),

            if (!hasData)
              _EmptyState(range: _range)
            else ...[
              BMHSectionTitle('Goals · highest first'),
              const SizedBox(height: 12),
              for (final s in scores) ...[
                _GoalCard(
                  result: s,
                  range: _range,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => _GoalDetailScreen(
                      result: s, range: _range))),
                ),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 40),
          ])),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final ScoreRange range;
  const _EmptyState({required this.range});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(children: [
        const Icon(Icons.restaurant_menu_outlined,
          color: BMHColors.inkMute, size: 32),
        const SizedBox(height: 12),
        Text('Nothing to score yet',
          style: BMHText.labelLg.copyWith(color: BMHColors.ink2)),
        const SizedBox(height: 6),
        Text(
          range == ScoreRange.day
            ? 'Log today’s meals in BioMedical Diet and all 11 goals '
              'will be scored from what you actually ate.'
            : 'Log meals across the week and this view will average '
              'the days you recorded.',
          textAlign: TextAlign.center,
          style: BMHText.bodySm.copyWith(
            fontSize: 11, color: BMHColors.inkMute, height: 1.5)),
      ]));
  }
}

// ─────────────────────────────────────────────────────────
class _GoalCard extends StatelessWidget {
  final CategoryScore result;
  final ScoreRange range;
  final VoidCallback onTap;

  const _GoalCard({
    required this.result,
    required this.range,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = _NutritionalScoreScreenState.colorFor(
      result.score, result.hasData);
    final weak = result.weakest;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(color: c.withOpacity(0.22))),
        child: Column(children: [
          Row(children: [
            // Score dial
            SizedBox(
              width: 46, height: 46,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 46, height: 46,
                  child: CircularProgressIndicator(
                    value: (result.score / 100).clamp(0.0, 1.0),
                    strokeWidth: 4,
                    backgroundColor: BMHColors.bg4,
                    valueColor: AlwaysStoppedAnimation(c))),
                Text(result.score.round().toString(),
                  style: BMHText.monoMd.copyWith(
                    fontSize: 13, color: c, fontWeight: FontWeight.w700)),
              ])),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.category.name,
                  style: BMHText.labelLg.copyWith(color: BMHColors.ink)),
                const SizedBox(height: 3),
                Text(result.category.blurb,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BMHText.bodySm.copyWith(
                    fontSize: 10.5, color: BMHColors.inkDim,
                    height: 1.35)),
              ])),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
              color: BMHColors.inkDim, size: 20),
          ]),
          if (weak != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: BMHColors.bg2,
                borderRadius: BorderRadius.circular(BMHRadius.sm)),
              child: Row(children: [
                Icon(Icons.trending_up_rounded,
                  color: c, size: 13),
                const SizedBox(width: 7),
                Expanded(child: Text(
                  'Biggest gain: more ${weak.driver.label.toLowerCase()} '
                  '(${weak.attainment.round()}% of target)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9.5, color: BMHColors.inkDim))),
              ])),
          ],
        ])));
  }
}

// ─────────────────────────────────────────────────────────
//  GOAL DETAIL — why the score is what it is
// ─────────────────────────────────────────────────────────
class _GoalDetailScreen extends StatelessWidget {
  final CategoryScore result;
  final ScoreRange range;

  const _GoalDetailScreen({required this.result, required this.range});

  static String _fmt(double v) =>
      v >= 100 ? v.round().toString()
      : v >= 10 ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final c = _NutritionalScoreScreenState.colorFor(
      result.score, result.hasData);
    final drivers = [...result.drivers]
      ..sort((a, b) => b.driver.weight.compareTo(a.driver.weight));

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
                BMHEyebrow(range.label.toUpperCase()),
                Text(result.category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BMHText.heading2),
              ])),
          ])),

        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.s5),
          children: [
            const SizedBox(height: 6),

            // Headline
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [c.withOpacity(0.14), BMHColors.bg2]),
                borderRadius: BorderRadius.circular(BMHRadius.xl),
                border: Border.all(color: c.withOpacity(0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(result.score.round().toString(),
                        style: BMHText.displayLg.copyWith(
                          color: c, height: 0.95)),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('/ 100',
                          style: BMHText.bodySm.copyWith(
                            color: BMHColors.inkDim))),
                      const Spacer(),
                      BMHPill(result.band,
                        type: result.score >= 60 ? BMHPillType.success
                          : result.score >= 40 ? BMHPillType.warn
                          : BMHPillType.danger),
                    ]),
                  const SizedBox(height: 10),
                  Text(result.category.blurb,
                    style: BMHText.bodySm.copyWith(
                      fontSize: 11.5, color: BMHColors.ink2, height: 1.45)),
                  if (range == ScoreRange.week) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Daily average across '
                      '${result.daysWithData} of ${result.daysInRange} '
                      'days logged',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 9, color: BMHColors.inkMute)),
                  ],
                ])),

            const SizedBox(height: 22),
            BMHSectionTitle('What builds this score'),
            const SizedBox(height: 6),
            Text(
              'Each nutrient counts by weight. The bar shows how much of '
              'your ${range == ScoreRange.week ? "daily average " : ""}'
              'target you reached.',
              style: BMHText.bodySm.copyWith(
                fontSize: 10.5, color: BMHColors.inkMute, height: 1.4)),
            const SizedBox(height: 14),

            for (final d in drivers) ...[
              _DriverRow(result: d),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 30),
          ])),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _DriverRow extends StatelessWidget {
  final DriverResult result;
  const _DriverRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final att = result.attainment;
    final color = att >= 90 ? BMHColors.success
        : att >= 60 ? BMHColors.sGut
        : att >= 35 ? BMHColors.warn
        : BMHColors.danger;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: BMHColors.line)),
      child: Column(children: [
        Row(children: [
          Expanded(child: Row(children: [
            Text(result.driver.label,
              style: BMHText.labelMd.copyWith(color: BMHColors.ink)),
            const SizedBox(width: 6),
            if (result.isLimit)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BMHColors.bg4,
                  borderRadius: BorderRadius.circular(BMHRadius.full)),
                child: Text('KEEP UNDER',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 7.5, letterSpacing: 0.6,
                    color: BMHColors.inkDim))),
          ])),
          Text(
            '${_GoalDetailScreen._fmt(result.consumed)} / '
            '${_GoalDetailScreen._fmt(result.need)} '
            '${result.driver.unit}',
            style: BMHText.monoSm.copyWith(
              fontSize: 10, color: BMHColors.inkDim)),
        ]),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(BMHRadius.full),
          child: LinearProgressIndicator(
            value: (att / 100).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: BMHColors.bg4,
            valueColor: AlwaysStoppedAnimation(color))),
        const SizedBox(height: 7),
        Row(children: [
          Text('${att.round()}%',
            style: BMHText.monoSm.copyWith(
              fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(child: Text(result.note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BMHText.monoSm.copyWith(
              fontSize: 9, color: BMHColors.inkMute))),
          Text('weight ${(result.driver.weight * 100).round()}%',
            style: BMHText.monoSm.copyWith(
              fontSize: 8.5, color: BMHColors.inkFaint)),
        ]),
      ]));
  }
}
