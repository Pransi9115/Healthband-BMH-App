// ─────────────────────────────────────────────────────────
//  BIORESPONSE — GUT HEALTH
//
//  Beneficial and unwanted bacteria read from the member's
//  uploaded gut microbiome report. Levels are reported exactly as
//  the lab stated them — nothing is inferred, and no advice is
//  attached to a bacterium on this screen.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';

// ── TONE ──────────────────────────────────────────────────
enum GutTone { aligned, review, attention }

extension _GutToneX on GutTone {
  Color get color => switch (this) {
        GutTone.aligned => BMHColors.success,
        GutTone.review => BMHColors.warn,
        GutTone.attention => BMHColors.danger,
      };
}

class GutOrganism {
  final String name;
  final String level;
  final GutTone tone;
  const GutOrganism(this.name, this.level, this.tone);
}

class GutReport {
  final String uploaded;
  final String diversity;
  final GutTone diversityTone;
  final List<GutOrganism> good;
  final List<GutOrganism> watch;

  const GutReport({
    required this.uploaded,
    required this.diversity,
    required this.diversityTone,
    required this.good,
    required this.watch,
  });
}

/// The report currently on file. Replace with the parsed upload once
/// the microbiome ingestion endpoint is wired in.
const kGutReport = GutReport(
  uploaded: '12 Jun 2026',
  diversity: 'Good diversity',
  diversityTone: GutTone.aligned,
  good: [
    GutOrganism('Bifidobacterium', 'Adequate', GutTone.aligned),
    GutOrganism('Lactobacillus', 'Adequate', GutTone.aligned),
    GutOrganism('Faecalibacterium prausnitzii', 'Low', GutTone.review),
    GutOrganism('Akkermansia muciniphila', 'Adequate', GutTone.aligned),
  ],
  watch: [
    GutOrganism('Proteobacteria', 'Normal', GutTone.aligned),
    GutOrganism(
      'Escherichia coli (pathogenic)', 'Not detected', GutTone.aligned),
    GutOrganism('Clostridioides difficile', 'Not detected', GutTone.aligned),
    GutOrganism('Methanogens', 'Slightly elevated', GutTone.review),
  ],
);

class GutHealthScreen extends StatelessWidget {
  final GutReport report;
  const GutHealthScreen({super.key, this.report = kGutReport});

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
                Text('Gut health', style: BMHText.heading1),
              ])),
          ])),

        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.s5),
          children: [
            const SizedBox(height: 6),
            Text('Your BioResponse gut health', style: BMHText.heading2),
            const SizedBox(height: 6),
            Text(
              'Beneficial and unwanted bacteria from your uploaded gut '
              'microbiome report.',
              style: BMHText.bodySm.copyWith(
                fontSize: 11.5, color: BMHColors.inkDim, height: 1.5)),
            const SizedBox(height: 16),

            // ── REPORT STRIP ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BMHColors.surface,
                borderRadius: BorderRadius.circular(BMHRadius.lg),
                border: Border.all(color: BMHColors.line)),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('GUT MICROBIOME REPORT',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9.5, letterSpacing: 0.6,
                      color: BMHColors.inkMute)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: BMHColors.bg4,
                      borderRadius: BorderRadius.circular(BMHRadius.sm)),
                    child: RichText(text: TextSpan(children: [
                      TextSpan(text: 'Diversity ',
                        style: BMHText.monoSm.copyWith(
                          fontSize: 10, color: BMHColors.inkDim)),
                      TextSpan(text: report.diversity,
                        style: BMHText.monoSm.copyWith(
                          fontSize: 10, color: BMHColors.ink,
                          fontWeight: FontWeight.w700)),
                    ]))),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: BMHColors.bg4,
                      borderRadius: BorderRadius.circular(BMHRadius.sm)),
                    child: Text('uploaded ${report.uploaded}',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 10, color: BMHColors.inkDim))),
                ])),

            const SizedBox(height: 22),
            _SubHead('GOOD BACTERIA'),
            const SizedBox(height: 12),
            _Grid(items: report.good),

            const SizedBox(height: 22),
            _SubHead('BACTERIA TO WATCH'),
            const SizedBox(height: 12),
            _Grid(items: report.watch),

            const SizedBox(height: 20),
            Text(
              'Levels are reported as the laboratory stated them. '
              'Changes to diet, supplements or medication should be '
              'agreed with your care team.',
              style: BMHText.bodySm.copyWith(
                fontSize: 10.5, color: BMHColors.inkMute, height: 1.55)),
            const SizedBox(height: 40),
          ])),
      ])),
    );
  }
}

class _SubHead extends StatelessWidget {
  final String text;
  const _SubHead(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: BMHText.monoSm.copyWith(
        fontSize: 10, letterSpacing: 0.9,
        color: BMHColors.cyan, fontWeight: FontWeight.w700));
}

class _Grid extends StatelessWidget {
  final List<GutOrganism> items;
  const _Grid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final o in items) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BMHColors.surface,
            borderRadius: BorderRadius.circular(BMHRadius.md),
            border: Border.all(color: BMHColors.line)),
          child: Row(children: [
            Expanded(child: Text(o.name,
              style: BMHText.labelMd.copyWith(
                fontSize: 12.5, color: BMHColors.ink))),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: o.tone.color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(BMHRadius.full)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: o.tone.color)),
                const SizedBox(width: 6),
                Text(o.level,
                  style: BMHText.bodySm.copyWith(
                    fontSize: 11, color: o.tone.color,
                    fontWeight: FontWeight.w600)),
              ])),
          ])),
        const SizedBox(height: 10),
      ],
    ]);
  }
}
