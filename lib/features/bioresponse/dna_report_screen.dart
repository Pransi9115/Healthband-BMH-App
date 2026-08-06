// ─────────────────────────────────────────────────────────
//  DNA REPORT — FITNESS GENOMICS
//
//  Same reading pattern as the blood report: counts at the top, the
//  short list of things worth acting on, then every trait grouped by
//  body system, each expanding into what it is, what your result
//  means, the gene behind it, and what to do.
//
//  ONE DIFFERENCE FROM BLOOD, DELIBERATELY
//  A genotype does not change, so a "poor" result read the wrong way
//  becomes a life sentence rather than a training note. Every poor
//  trait in this panel has do's attached precisely because it is
//  trainable, and the screen leads with that rather than burying it.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/dna_report_service.dart';

const _accent = BMHColors.sDna;

Color bandColor(GeneBand b) => switch (b) {
      GeneBand.good => BMHColors.rangeIn,
      GeneBand.typical => BMHColors.rangeEdge,
      GeneBand.poor => BMHColors.rangeOut,
    };

class DnaReportScreen extends StatelessWidget {
  final DnaReport report;
  const DnaReportScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: Stack(children: [
        Positioned(top: -180, right: -120,
          child: Container(width: 480, height: 480,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _accent.withOpacity(0.08), Colors.transparent])))),

        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH, vertical: 8),
            child: Row(children: [
              BMHIconButton(
                onTap: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                  color: BMHColors.ink, size: 16)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BMHEyebrow('DNA PANEL'),
                  Text(report.panel,
                    style: BMHText.heading1.copyWith(fontSize: 24)),
                ])),
            ])),

          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BMHSpacing.screenH, 6, BMHSpacing.screenH, 60),
            children: [
              _masthead(),
              const SizedBox(height: 16),
              _counts(),

              const SizedBox(height: 18),
              _readFirst(),

              if (report.flagged.isNotEmpty) ...[
                const SizedBox(height: 24),
                BMHSectionTitle('Worth training around'),
                const SizedBox(height: 6),
                Text(
                  'The traits where your genotype is least favourable. '
                  'Each one is trainable — that is the point of knowing.',
                  style: BMHText.bodySm.copyWith(
                    fontSize: 11, color: BMHColors.inkMute, height: 1.45)),
                const SizedBox(height: 12),
                for (final t in report.flagged)
                  _FlagRow(trait: t),
              ],

              for (final cat in report.categories) ...[
                const SizedBox(height: 26),
                Row(children: [
                  Container(
                    width: 3, height: 26,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 11),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat,
                        style: BMHText.heading2.copyWith(
                          fontSize: 19, color: BMHColors.ink)),
                      const SizedBox(height: 2),
                      Text(_countLabel(report.inCategory(cat).length),
                        style: BMHText.monoSm.copyWith(
                          fontSize: 9, color: BMHColors.inkMute)),
                    ])),
                ]),
                const SizedBox(height: 12),
                for (final t in report.inCategory(cat)) ...[
                  _TraitCard(trait: t),
                  const SizedBox(height: 10),
                ],
              ],

              const SizedBox(height: 20),
              _disclaimer(),
            ])),
        ])),
      ]));
  }

  static String _countLabel(int n) =>
      n == 1 ? '1 trait in this group' : '$n traits in this group';

  Widget _masthead() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.lg),
      border: Border.all(color: BMHColors.line)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _kv('NAME', report.patientName)),
          Expanded(child: _kv('DATE OF BIRTH', report.dateOfBirth)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _kv('PANEL', report.panel)),
          Expanded(child: _kv('TRAITS',
            '${report.traits.length}')),
        ]),
      ]));

  Widget _kv(String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k,
        style: BMHText.monoSm.copyWith(
          fontSize: 8, letterSpacing: 1.1, color: BMHColors.inkMute)),
      const SizedBox(height: 4),
      Text(v,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: BMHText.labelMd.copyWith(
          fontSize: 13, color: BMHColors.ink)),
    ]);

  Widget _counts() => Row(children: [
    Expanded(child: _countCard(
      '${report.goodCount}', 'FAVOURABLE', BMHColors.rangeIn)),
    const SizedBox(width: 9),
    Expanded(child: _countCard(
      '${report.typicalCount}', 'TYPICAL', BMHColors.rangeEdge)),
    const SizedBox(width: 9),
    Expanded(child: _countCard(
      '${report.poorCount}', 'LESS FAVOURABLE', BMHColors.rangeOut)),
  ]);

  Widget _countCard(String n, String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border(
        top: BorderSide(color: c, width: 2.5),
        left: BorderSide(color: BMHColors.line),
        right: BorderSide(color: BMHColors.line),
        bottom: BorderSide(color: BMHColors.line))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(n,
          style: BMHText.displayMd.copyWith(
            fontSize: 26, color: c, height: 1)),
        const SizedBox(height: 5),
        Text(label,
          maxLines: 2,
          style: BMHText.monoSm.copyWith(
            fontSize: 8, letterSpacing: 0.8, color: BMHColors.inkDim)),
      ]));

  Widget _readFirst() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _accent.withOpacity(0.07),
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: _accent.withOpacity(0.28))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.lightbulb_outline_rounded,
        color: _accent, size: 15),
      const SizedBox(width: 11),
      Expanded(child: Text(
        'Your genes set a starting point, not a limit. A less '
        'favourable result means a trait needs more deliberate work '
        'than it would for someone else — not that the work will not '
        'pay. Nothing here is a diagnosis, and none of it should change '
        'your training or diet without your care team.',
        style: BMHText.bodySm.copyWith(
          fontSize: 11.5, color: BMHColors.ink2, height: 1.5))),
    ]));

  Widget _disclaimer() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: BMHColors.bg2,
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.line)),
    child: Text(
      'These results are for information and wellbeing purposes and do '
      'not constitute a medical diagnosis. Genetic associations are '
      'population averages, and a single gene explains only a small '
      'part of any trait. Discuss anything shown here with a qualified '
      'professional before changing training, medication or diet.',
      style: BMHText.bodySm.copyWith(
        fontSize: 10.5, color: BMHColors.inkMute, height: 1.5)));
}

// ─────────────────────────────────────────────────────────
class _FlagRow extends StatelessWidget {
  final GeneTrait trait;
  const _FlagRow({required this.trait});

  @override
  Widget build(BuildContext context) {
    final c = bandColor(trait.band);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: BMHColors.line)),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trait.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BMHText.labelMd.copyWith(
                fontSize: 13, color: BMHColors.ink)),
            const SizedBox(height: 3),
            Text(trait.category,
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.inkMute)),
          ])),
        const SizedBox(width: 10),
        _Pips(band: trait.band),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.withOpacity(0.14),
            borderRadius: BorderRadius.circular(BMHRadius.full),
            border: Border.all(color: c.withOpacity(0.45))),
          child: Text(trait.band.label.toUpperCase(),
            style: BMHText.monoSm.copyWith(
              fontSize: 8.5, letterSpacing: 0.8, color: c,
              fontWeight: FontWeight.w700))),
      ]));
  }
}

// ─────────────────────────────────────────────────────────
class _Pips extends StatelessWidget {
  final GeneBand band;
  const _Pips({required this.band});

  @override
  Widget build(BuildContext context) {
    final c = bandColor(band);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 5; i++) ...[
        if (i > 0) const SizedBox(width: 3),
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            color: i == band.pips - 1 ? c : BMHColors.bg4,
            borderRadius: BorderRadius.circular(1.5))),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────
class _TraitCard extends StatefulWidget {
  final GeneTrait trait;
  const _TraitCard({required this.trait});

  @override
  State<_TraitCard> createState() => _TraitCardState();
}

class _TraitCardState extends State<_TraitCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trait;
    final c = bandColor(t.band);

    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border(
            left: BorderSide(color: c, width: 3),
            top: BorderSide(color: BMHColors.line),
            right: BorderSide(color: BMHColors.line),
            bottom: BorderSide(color: BMHColors.line))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(t.name,
                  style: BMHText.labelLg.copyWith(
                    fontSize: 15, color: BMHColors.ink))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(BMHRadius.full),
                    border: Border.all(color: c.withOpacity(0.45))),
                  child: Text(t.band.label,
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9, color: c, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 11),
              Row(children: [
                _Pips(band: t.band),
                const SizedBox(width: 12),
                Expanded(child: _bar(t, c)),
                const SizedBox(width: 10),
                Text(t.score.toStringAsFixed(1),
                  style: BMHText.monoSm.copyWith(
                    fontSize: 11, color: c)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text(t.summary,
                  style: BMHText.bodySm.copyWith(
                    fontSize: 11.5, color: BMHColors.ink2, height: 1.45))),
                const SizedBox(width: 8),
                Icon(_open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                  size: 18, color: BMHColors.inkDim),
              ]),
            ])),

          if (_open) ...[
            Divider(height: 1, color: BMHColors.line.withOpacity(0.6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('WHAT IT IS'),
                  const SizedBox(height: 6),
                  _body(t.whatIs),

                  const SizedBox(height: 15),
                  _label('YOUR RESULT'),
                  const SizedBox(height: 6),
                  _body(t.interpretation),

                  const SizedBox(height: 15),
                  _label('THE GENE'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BMHColors.bg2,
                      borderRadius: BorderRadius.circular(BMHRadius.md),
                      border: Border.all(color: BMHColors.line)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _chip(t.geneName, _accent),
                          const SizedBox(width: 8),
                          _chip('Genotype ${t.genotype}',
                            BMHColors.sCardio),
                        ]),
                        const SizedBox(height: 10),
                        _body(t.geneNote),
                      ])),

                  if (t.dos.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    _adviceBlock('WHAT HELPS', t.dos,
                      BMHColors.rangeIn, Icons.check_rounded),
                  ],
                  if (t.donts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _adviceBlock('WHAT DOES NOT', t.donts,
                      BMHColors.rangeOut, Icons.close_rounded),
                  ],
                ])),
          ],
        ])));
  }

  Widget _bar(GeneTrait t, Color c) => LayoutBuilder(
    builder: (ctx, box) {
      final w = box.maxWidth;
      return SizedBox(height: 14, child: Stack(children: [
        Positioned(
          left: 0, right: 0, top: 5,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: BMHColors.bg4,
              borderRadius: BorderRadius.circular(BMHRadius.full)))),
        Positioned(
          left: 0, width: (t.barPosition * w).clamp(0.0, w), top: 5,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(BMHRadius.full)))),
      ]));
    });

  Widget _label(String s) => Text(s,
    style: BMHText.monoSm.copyWith(
      fontSize: 8.5, letterSpacing: 1.2, color: BMHColors.inkDim));

  Widget _body(String s) => Text(s,
    style: BMHText.bodySm.copyWith(
      fontSize: 11.5, color: BMHColors.ink2, height: 1.55));

  Widget _chip(String s, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(BMHRadius.sm),
      border: Border.all(color: c.withOpacity(0.4))),
    child: Text(s,
      style: BMHText.monoSm.copyWith(fontSize: 9.5, color: c)));

  Widget _adviceBlock(
      String title, List<String> lines, Color c, IconData icon) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.07),
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: c.withOpacity(0.25))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: BMHText.monoSm.copyWith(
              fontSize: 8.5, letterSpacing: 1.2, color: c,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 12, color: c)),
              const SizedBox(width: 8),
              Expanded(child: Text(lines[i],
                style: BMHText.bodySm.copyWith(
                  fontSize: 11, color: BMHColors.ink2, height: 1.45))),
            ]),
          ],
        ]));
}
