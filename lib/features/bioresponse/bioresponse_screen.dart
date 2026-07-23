// ─────────────────────────────────────────────────────────
//  BIORESPONSE — module hub
//  Four sections. Nutritional Score is live and reads from the
//  BioMedical Diet log. The other three are placeholders until
//  their data sources are wired in.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/nutritional_score_service.dart';
import '../../core/diet/diet_service.dart';
import 'nutritional_score_screen.dart';
import 'biomarkers_screen.dart';

class BioResponseScreen extends StatefulWidget {
  const BioResponseScreen({super.key});
  @override
  State<BioResponseScreen> createState() => _BioResponseScreenState();
}

class _BioResponseScreenState extends State<BioResponseScreen> {
  final _score = NutritionalScoreService.instance;
  ScoreRange _range = ScoreRange.day;

  @override
  Widget build(BuildContext context) {
    final overall = _score.overall(_range);
    final logged = _score.daysLogged(_range);
    final hasData = logged > 0;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: SafeArea(
        child: Column(children: [
          // ── HEADER ──────────────────────────────
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
                  const BMHEyebrow('MODULE'),
                  Text('BioResponse', style: BMHText.heading1),
                ])),
            ])),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),

                // ── RANGE TOGGLE ────────────────────
                _RangeToggle(
                  range: _range,
                  onChanged: (r) => setState(() => _range = r)),
                const SizedBox(height: 16),

                // ── HEADLINE SCORE ──────────────────
                _OverallCard(
                  score: overall,
                  hasData: hasData,
                  range: _range,
                  daysLogged: logged),

                const SizedBox(height: 24),
                BMHSectionTitle('Response areas'),
                const SizedBox(height: 14),

                // ── 1. NUTRITIONAL SCORE (live) ─────
                _AreaCard(
                  title: 'Nutritional score',
                  subtitle: hasData
                    ? '11 goals scored from your logged meals'
                    : 'Log a meal to start scoring',
                  icon: Icons.eco_outlined,
                  color: BMHColors.sGut,
                  trailing: hasData
                    ? Text(overall.round().toString(),
                        style: BMHText.heading2.copyWith(
                          color: BMHColors.sGut))
                    : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NutritionalScoreScreen(
                      initialRange: _range))),
                ),
                const SizedBox(height: 12),

                // ── 2–4. COMING SOON ────────────────
                _AreaCard(
                  title: 'Biomarkers',
                  subtitle: 'Intake vs blood · food, supplements, panel',
                  icon: Icons.bloodtype_outlined,
                  color: BMHColors.sCardio,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BiomarkersScreen(initialRange: _range)))),
                const SizedBox(height: 12),
                _AreaCard(
                  title: 'Body composition',
                  subtitle: 'Lean mass, fat mass and hydration',
                  icon: Icons.accessibility_new_outlined,
                  color: BMHColors.sBody,
                  comingSoon: true),
                const SizedBox(height: 12),
                _AreaCard(
                  title: 'Gut health',
                  subtitle: 'Microbiome diversity and digestion',
                  icon: Icons.biotech_outlined,
                  color: BMHColors.sDna,
                  comingSoon: true),

                const SizedBox(height: 20),
                _DisclaimerNote(),
                const SizedBox(height: 40),
              ])),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  RANGE TOGGLE — patient switches per day / per week
// ─────────────────────────────────────────────────────────
class _RangeToggle extends StatelessWidget {
  final ScoreRange range;
  final ValueChanged<ScoreRange> onChanged;
  const _RangeToggle({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BMHColors.bg2,
        borderRadius: BorderRadius.circular(BMHRadius.full),
        border: Border.all(color: BMHColors.line)),
      child: Row(children: [
        for (final r in ScoreRange.values)
          Expanded(child: GestureDetector(
            onTap: () => onChanged(r),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: r == range ? BMHColors.cyan : Colors.transparent,
                borderRadius: BorderRadius.circular(BMHRadius.full)),
              child: Text(r.label,
                textAlign: TextAlign.center,
                style: BMHText.labelMd.copyWith(
                  color: r == range ? BMHColors.bg0 : BMHColors.inkDim,
                  fontWeight: r == range
                    ? FontWeight.w700 : FontWeight.w500))))),
      ]));
  }
}

// ─────────────────────────────────────────────────────────
class _OverallCard extends StatelessWidget {
  final double score;
  final bool hasData;
  final ScoreRange range;
  final int daysLogged;

  const _OverallCard({
    required this.score,
    required this.hasData,
    required this.range,
    required this.daysLogged,
  });

  Color get _c {
    if (!hasData) return BMHColors.inkMute;
    if (score >= 80) return BMHColors.success;
    if (score >= 60) return BMHColors.sGut;
    if (score >= 40) return BMHColors.warn;
    return BMHColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_c.withOpacity(0.14), BMHColors.bg2]),
        borderRadius: BorderRadius.circular(BMHRadius.xl),
        border: Border.all(color: _c.withOpacity(0.30))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(hasData ? score.round().toString() : '--',
              style: BMHText.displayLg.copyWith(
                color: _c, height: 0.95)),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('/ 100',
                style: BMHText.bodySm.copyWith(color: BMHColors.inkDim))),
            const Spacer(),
            BMHPill(
              hasData
                ? (score >= 80 ? 'Strong'
                  : score >= 60 ? 'Moderate'
                  : score >= 40 ? 'Building' : 'Low')
                : 'No data',
              type: !hasData ? BMHPillType.neutral
                : score >= 60 ? BMHPillType.success
                : score >= 40 ? BMHPillType.warn
                : BMHPillType.danger),
          ]),
          const SizedBox(height: 10),
          Text('BioResponse · nutritional',
            style: BMHText.labelLg.copyWith(color: BMHColors.ink)),
          const SizedBox(height: 4),
          Text(
            hasData
              ? range == ScoreRange.day
                ? 'Average across all 11 goals from today’s meals'
                : 'Average across all 11 goals · $daysLogged of 7 days logged'
              : range == ScoreRange.day
                ? 'No meals logged today yet. Log a meal in BioMedical Diet '
                  'and your score appears here.'
                : 'No meals logged in the last 7 days yet.',
            style: BMHText.bodySm.copyWith(
              fontSize: 11, color: BMHColors.inkDim)),
        ]));
  }
}

// ─────────────────────────────────────────────────────────
class _AreaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool comingSoon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _AreaCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.comingSoon = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dim = comingSoon;
    return GestureDetector(
      onTap: comingSoon ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: dim ? 0.62 : 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BMHColors.surface,
            borderRadius: BorderRadius.circular(BMHRadius.lg),
            border: Border.all(
              color: dim ? BMHColors.line : color.withOpacity(0.28))),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(BMHRadius.md),
                border: Border.all(color: color.withOpacity(0.22))),
              child: Icon(icon, color: color, size: 21)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(title,
                    style: BMHText.labelLg.copyWith(color: BMHColors.ink))),
                  if (comingSoon) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: BMHColors.bg4,
                        borderRadius:
                          BorderRadius.circular(BMHRadius.full),
                        border: Border.all(color: BMHColors.line)),
                      child: Text('COMING SOON',
                        style: BMHText.monoSm.copyWith(
                          fontSize: 8, letterSpacing: 0.8,
                          color: BMHColors.inkDim))),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(subtitle,
                  style: BMHText.bodySm.copyWith(
                    fontSize: 11, color: BMHColors.inkDim)),
              ])),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
            if (!comingSoon) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                color: BMHColors.inkDim, size: 20),
            ],
          ]))));
  }
}

// ─────────────────────────────────────────────────────────
class _DisclaimerNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BMHColors.bg2,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: BMHColors.line)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded,
          color: BMHColors.inkDim, size: 15),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Scores reflect only the food you have logged, and are a general '
          'wellness guide rather than medical advice. Speak to your care '
          'team before changing a diet for a medical condition.',
          style: BMHText.bodySm.copyWith(
            fontSize: 10.5, color: BMHColors.inkMute, height: 1.45))),
      ]));
  }
}
