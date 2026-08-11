// ─────────────────────────────────────────────────────────
//  BLOOD REPORT — SHARED FORMAT
//
//  One report, one presentation. Biomedical Monitoring → Blood
//  Analysis and BioResponse → Biomarkers → Blood report both build
//  from the pieces in this file, so the patient sees the same
//  report in the same shape wherever they open it from.
//
//  The order mirrors the printed document: who ran it, the counts,
//  the threads that tie markers together, the markers themselves,
//  then what to do next.
//
//  Text colour note: body copy is BMHColors.ink (white) throughout.
//  Only trailing provenance lines drop to ink2, and nothing in the
//  report uses the dim greys that were hard to read on the dark
//  theme.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../core/bioresponse/blood_report_service.dart';

// ── shared helpers ────────────────────────────────────────
//
//  COLOUR SCALE
//  Below range is orange, inside range is green, above range is red.
//  Low and high are deliberately different colours: a low ferritin and
//  a high ferritin are opposite problems needing opposite action, and
//  painting both the same red loses that entirely.
//
//  Anything above its range is red, with no exceptions. A high HDL is
//  clinically a good result, but a patient scanning a list of forty
//  markers should not have to know which ones invert — a value outside
//  its reference range is a value to ask about, and the colour says so
//  consistently. The favourable case is explained in the marker's own
//  detail text instead, where there is room to say why.
//
//  highIsGood is kept in the signature so callers do not all have to
//  change, and so the distinction stays available to the copy.
Color markerColor(MarkerStatus s, bool highIsGood) => switch (s) {
      MarkerStatus.low => BMHColors.rangeLow,
      MarkerStatus.high => BMHColors.rangeHigh,
      MarkerStatus.borderline => BMHColors.rangeEdge,
      MarkerStatus.inRange => BMHColors.rangeIn,
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

/// The label the report itself would print for a result.
///
/// HIGH and LOW are deliberately blunt. "Above range" reads as a
/// description; HIGH reads as something to act on, which is what an
/// out-of-range result is. The favourable nuance for markers where a
/// high value is welcome moves into the detail text.
String reportLabel(BloodMarker m) {
  if (m.status == MarkerStatus.borderline) {
    // Colour says "just outside"; the word says which side.
    return m.value <= (m.refLow + m.refHigh) / 2
      ? 'Borderline low' : 'Borderline high';
  }
  return switch (m.status) {
    MarkerStatus.low => 'LOW',
    MarkerStatus.high => 'HIGH',
    MarkerStatus.borderline => 'Borderline',
    MarkerStatus.inRange => 'In range',
  };
}

/// True when the status deserves the heavier, attention-seeking
/// treatment on screen.
bool isFlagLabel(MarkerStatus s) =>
    s == MarkerStatus.high || s == MarkerStatus.low;

// ─────────────────────────────────────────────────────────
//  MASTHEAD — the report's own opening
// ─────────────────────────────────────────────────────────
class ReportMasthead extends StatelessWidget {
  final BloodReport report;
  const ReportMasthead({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            BMHColors.sCardio.withOpacity(0.12),
            BMHColors.sCardio.withOpacity(0.02)]),
        borderRadius: BorderRadius.circular(BMHRadius.xl),
        border: Border.all(color: BMHColors.sCardio.withOpacity(0.28))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BLOOD RESULTS EXPLAINED',
            style: BMHText.monoSm.copyWith(
              fontSize: 8.5, letterSpacing: 1.5,
              color: BMHColors.sCardio, fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          if (report.headline.isNotEmpty)
            Text(report.headline,
              style: BMHText.heading2.copyWith(
                fontSize: 19, height: 1.25, color: BMHColors.ink)),
          if (report.summary.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(report.summary,
              style: BMHText.bodySm.copyWith(
                fontSize: 11.5, color: BMHColors.ink, height: 1.55)),
          ],
          const SizedBox(height: 14),
          const Divider(color: BMHColors.line, height: 1),
          const SizedBox(height: 12),
          Wrap(spacing: 22, runSpacing: 12, children: [
            if (report.sampleTakenAt.isNotEmpty)
              _meta('Sample taken', report.sampleTakenAt),
            if (report.reportedOn.isNotEmpty)
              _meta('Reported', report.reportedOn),
            if (report.labRef.isNotEmpty)
              _meta('Lab reference', report.labRef),
            if (report.ageAtTest > 0)
              _meta('Age at test', '${report.ageAtTest}'),
            if (report.labName.isNotEmpty)
              _meta('Analysed by', report.labName),
          ]),
        ]));
  }

  Widget _meta(String k, String v) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k.toUpperCase(),
        style: BMHText.monoSm.copyWith(
          fontSize: 7.5, letterSpacing: 1.2, color: BMHColors.ink2)),
      const SizedBox(height: 3),
      Text(v,
        style: BMHText.labelMd.copyWith(
          fontSize: 11.5, color: BMHColors.ink)),
    ]);
}

// ─────────────────────────────────────────────────────────
//  COUNTS — the four numbers, and what they add up to
// ─────────────────────────────────────────────────────────
class ReportCounts extends StatelessWidget {
  final BloodReport report;
  final bool showFootnotes;
  const ReportCounts({
    super.key,
    required this.report,
    this.showFootnotes = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.xl),
        border: Border.all(color: BMHColors.sCardio.withOpacity(0.24))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: BMHColors.sCardio.withOpacity(0.12),
                borderRadius: BorderRadius.circular(BMHRadius.md),
                border: Border.all(
                  color: BMHColors.sCardio.withOpacity(0.22))),
              child: const Icon(Icons.bloodtype_outlined,
                color: BMHColors.sCardio, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.testName,
                  style: BMHText.labelLg.copyWith(color: BMHColors.ink)),
                const SizedBox(height: 3),
                Text('Tested ${fmtDate(r.testDate)}',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9.5, color: BMHColors.ink2)),
              ])),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _stat('${r.concernCount}', 'Outside\nrange',
              BMHColors.rangeHigh),
            _stat('${r.borderlineCount}', 'Keep an\neye on',
              BMHColors.rangeEdge),
            _stat('${r.inRangeCount}', 'In\nrange', BMHColors.rangeIn),
            _stat('${r.totalCount}', 'Total\nmarkers', BMHColors.cyan),
          ]),
          if (showFootnotes &&
              (r.priorityCount > 0 || r.favourableCount > 0)) ...[
            const SizedBox(height: 14),
            const Divider(color: BMHColors.line, height: 1),
            const SizedBox(height: 12),
            if (r.priorityCount > 0)
              _line(Icons.priority_high_rounded, BMHColors.rangeHigh,
                '${r.priorityCount} of the ${r.concernCount} outside range '
                'are the ones to raise with your doctor first'),
            if (r.favourableCount > 0) ...[
              const SizedBox(height: 8),
              _line(Icons.check_circle_outline_rounded, BMHColors.rangeIn,
                '${r.favourableCount} marker above its range is a good '
                'result, not a concern'),
            ],
          ],
        ]));
  }

  Widget _stat(String v, String l, Color c) => Expanded(child: Column(
    children: [
      Text(v, style: BMHText.heading2.copyWith(color: c)),
      const SizedBox(height: 3),
      Text(l,
        textAlign: TextAlign.center,
        style: BMHText.monoSm.copyWith(
          fontSize: 8, height: 1.3, color: BMHColors.ink)),
    ]));

  Widget _line(IconData ic, Color c, String text) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ic, color: c, size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
          style: BMHText.bodySm.copyWith(
            fontSize: 10.5, color: BMHColors.ink, height: 1.45))),
      ]);
}

// ─────────────────────────────────────────────────────────
//  READ THIS FIRST — the threads that tie markers together
// ─────────────────────────────────────────────────────────
class ReportThreads extends StatelessWidget {
  final BloodReport report;
  const ReportThreads({super.key, required this.report});

  static const _tones = [
    BMHColors.sNervous, BMHColors.sMetabolic, BMHColors.success];

  @override
  Widget build(BuildContext context) {
    if (report.threads.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (report.clinicalContext.isNotEmpty) ...[
          Text(report.clinicalContext,
            style: BMHText.bodySm.copyWith(
              fontSize: 11.5, color: BMHColors.ink, height: 1.55)),
          const SizedBox(height: 14),
        ],
        for (var i = 0; i < report.threads.length; i++) ...[
          _ThreadCard(
            thread: report.threads[i],
            tone: _tones[i % _tones.length]),
          const SizedBox(height: 10),
        ],
      ]);
  }
}

class _ThreadCard extends StatefulWidget {
  final ReportThread thread;
  final Color tone;
  const _ThreadCard({required this.thread, required this.tone});

  @override
  State<_ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends State<_ThreadCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    final c = widget.tone;
    return GestureDetector(
      onTap: t.body.isEmpty ? null : () => setState(() => _open = !_open),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(color: c.withOpacity(0.30))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(BMHRadius.full),
                  border: Border.all(color: c.withOpacity(0.35))),
                child: Text(t.tag.toUpperCase(),
                  style: BMHText.monoSm.copyWith(
                    fontSize: 8, letterSpacing: 1.1,
                    color: c, fontWeight: FontWeight.w700))),
              const Spacer(),
              if (t.body.isNotEmpty)
                Icon(_open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                  size: 18, color: BMHColors.ink2),
            ]),
            const SizedBox(height: 9),
            Text(t.lede,
              style: BMHText.bodySm.copyWith(
                fontSize: 11.5, color: BMHColors.ink,
                height: 1.5, fontWeight: FontWeight.w600)),
            if (_open && t.body.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(t.body,
                style: BMHText.bodySm.copyWith(
                  fontSize: 11, color: BMHColors.ink, height: 1.6)),
            ],
          ])));
  }
}

// ─────────────────────────────────────────────────────────
//  MARKER ROW — value, reference bar, and the expandable note
// ─────────────────────────────────────────────────────────
class ReportMarkerRow extends StatefulWidget {
  final BloodMarker marker;

  /// Expanded from the start — used for the handful of markers the
  /// report leads with, so the reader does not have to hunt.
  final bool initiallyOpen;

  const ReportMarkerRow({
    super.key,
    required this.marker,
    this.initiallyOpen = false,
  });

  @override
  State<ReportMarkerRow> createState() => _ReportMarkerRowState();
}

class _ReportMarkerRowState extends State<ReportMarkerRow> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final m = widget.marker;
    final c = markerColor(m.status, m.highIsGood);
    final expandable = m.note.isNotEmpty || m.actions.isNotEmpty;
    final flagged = m.isConcern || m.status == MarkerStatus.borderline;

    return GestureDetector(
      onTap: expandable ? () => setState(() => _open = !_open) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(
            color: flagged || m.isFavourable
              ? c.withOpacity(0.30) : BMHColors.line)),
        child: Column(children: [
          // ── name, alias, value ──
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(m.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BMHText.labelMd.copyWith(
                      fontSize: 12.5, color: BMHColors.ink))),
                  if (m.priority) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 5, height: 5,
                      decoration: const BoxDecoration(
                        color: BMHColors.danger, shape: BoxShape.circle)),
                  ],
                ]),
                if (m.alias.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(m.alias,
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9, color: BMHColors.ink2, height: 1.35)),
                ],
              ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${fmtNum(m.value)} ${m.unit}',
                style: BMHText.monoMd.copyWith(
                  fontSize: 12, color: c, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              // HIGH and LOW get the loud treatment: bigger, bolder,
              // wider tracking. In range stays quiet — a patient should
              // be able to scan a forty-marker list and have their eye
              // caught only by what matters.
              Text(reportLabel(m).toUpperCase(),
                style: BMHText.monoSm.copyWith(
                  fontSize: isFlagLabel(m.status) ? 10 : 7.5,
                  letterSpacing: isFlagLabel(m.status) ? 1.2 : 0.6,
                  color: c,
                  fontWeight: isFlagLabel(m.status)
                    ? FontWeight.w900 : FontWeight.w700)),
            ]),
            if (expandable) ...[
              const SizedBox(width: 4),
              Icon(_open
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                size: 16, color: BMHColors.ink2),
            ],
          ]),

          const SizedBox(height: 10),
          ReferenceBar(marker: m, color: c),
          const SizedBox(height: 5),
          Row(children: [
            Text(
              m.refText.isNotEmpty
                ? 'Range ${m.refText}${m.unit.isEmpty ? "" : " ${m.unit}"}'
                : 'Range ${fmtNum(m.refLow)} to ${fmtNum(m.refHigh)} '
                  '${m.unit}',
              style: BMHText.monoSm.copyWith(
                fontSize: 8.5, color: BMHColors.ink2)),
            const Spacer(),
            if (m.share.isNotEmpty)
              Text(m.share,
                style: BMHText.monoSm.copyWith(
                  fontSize: 8.5, color: BMHColors.ink2)),
          ]),

          // ── the plain-English part ──
          if (_open && expandable) ...[
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BMHColors.bg2,
                borderRadius: BorderRadius.circular(BMHRadius.sm),
                border: Border.all(color: BMHColors.line)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.note.isNotEmpty)
                    Text(m.note,
                      style: BMHText.bodySm.copyWith(
                        fontSize: 11, color: BMHColors.ink, height: 1.6)),
                  if (m.actions.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    Text('WHAT YOU CAN DO',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 7.5, letterSpacing: 1.3,
                        color: BMHColors.cyan,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    for (final a in m.actions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4, height: 4,
                              margin: const EdgeInsets.only(top: 6, right: 8),
                              decoration: const BoxDecoration(
                                color: BMHColors.cyan,
                                shape: BoxShape.circle)),
                            Expanded(child: Text(a,
                              style: BMHText.bodySm.copyWith(
                                fontSize: 10.5, color: BMHColors.ink,
                                height: 1.5))),
                          ])),
                  ],
                ])),
          ],
        ])));
  }
}

// ─────────────────────────────────────────────────────────
//  REFERENCE BAR — green where the result should sit,
//  a needle at the actual value
// ─────────────────────────────────────────────────────────
class ReferenceBar extends StatelessWidget {
  final BloodMarker marker;
  final Color color;
  const ReferenceBar({
    super.key,
    required this.marker,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      final zs = marker.zoneStart, ze = marker.zoneEnd;
      final pos = marker.barPosition;

      // Five zones: red, amber, green, amber, red. The amber
      // shoulders sit just inside each edge and match the borderline
      // status, so the strip and the label always agree.
      final span = ze - zs;
      final edge = span * 0.12;
      final aLo = (zs + edge).clamp(0.0, 1.0);
      final aHi = (ze - edge).clamp(0.0, 1.0);

      Widget zone(double from, double to, Color c,
          {bool roundLeft = false, bool roundRight = false}) {
        final left = (from * w).clamp(0.0, w);
        final width = ((to - from) * w).clamp(0.0, w);
        if (width <= 0) return const SizedBox.shrink();
        return Positioned(
          left: left, width: width, top: 7,
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(roundLeft ? BMHRadius.full : 0),
                right: Radius.circular(roundRight ? BMHRadius.full : 0)))));
      }

      return SizedBox(height: 20, child: Stack(children: [
        zone(0, zs, BMHColors.rangeOut, roundLeft: true),
        zone(zs, aLo, BMHColors.rangeEdge),
        zone(aLo, aHi, BMHColors.rangeIn),
        zone(aHi, ze, BMHColors.rangeEdge),
        zone(ze, 1, BMHColors.rangeOut, roundRight: true),

        // The needle is white, as in the printed report. A coloured
        // needle on a coloured strip fights with the zone underneath
        // it; white reads cleanly against all three.
        Positioned(
          left: (pos * w - 2.5).clamp(0.0, w - 5), top: 4,
          child: Container(
            width: 5, height: 13,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2.5),
              border: Border.all(
                color: BMHColors.bg0.withOpacity(0.55), width: 1)))),
      ]));
    });
  }
}

// ─────────────────────────────────────────────────────────
//  OUTLINE BUTTON
//
//  The call to action that opens the full report. Drawn as a
//  double-outlined capsule with a cyan glow and a leading chevron
//  so it reads as a door into the document rather than as another
//  card. Label is passed in already capitalised.
// ─────────────────────────────────────────────────────────
class BloodReportOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  const BloodReportOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.description_outlined,
    this.color = BMHColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // outer ring
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BMHRadius.full),
          border: Border.all(color: color.withOpacity(0.20)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.14),
              blurRadius: 16, spreadRadius: -4),
          ]),
        child: Container(
          // inner ring
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft, end: Alignment.centerRight,
              colors: [
                color.withOpacity(0.10),
                color.withOpacity(0.02)]),
            borderRadius: BorderRadius.circular(BMHRadius.full),
            border: Border.all(color: color.withOpacity(0.55), width: 1.2)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 10),
              Flexible(child: Text(label,
                textAlign: TextAlign.center,
                style: BMHText.labelLg.copyWith(
                  fontSize: 12.5,
                  color: color,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: color, size: 15),
            ]))));
  }
}

// ─────────────────────────────────────────────────────────
//  WHAT TO DO NEXT — the numbered steps
// ─────────────────────────────────────────────────────────
class ReportSteps extends StatelessWidget {
  final BloodReport report;
  const ReportSteps({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.steps.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (var i = 0; i < report.steps.length; i++) ...[
        _step(report.steps[i], i + 1),
        const SizedBox(height: 9),
      ],
    ]);
  }

  Widget _step(ReportStep s, int n) {
    final c = s.urgent ? BMHColors.danger : BMHColors.cyan;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: s.urgent
          ? BMHColors.danger.withOpacity(0.07) : BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(
          color: s.urgent
            ? BMHColors.danger.withOpacity(0.38) : BMHColors.line)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: c.withOpacity(0.13),
            borderRadius: BorderRadius.circular(BMHRadius.sm),
            border: Border.all(color: c.withOpacity(0.30))),
          child: Center(child: s.urgent
            ? Icon(Icons.priority_high_rounded, size: 13, color: c)
            : Text(n.toString().padLeft(2, '0'),
                style: BMHText.monoSm.copyWith(
                  fontSize: 8.5, color: c, fontWeight: FontWeight.w700)))),
        const SizedBox(width: 11),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title,
              style: BMHText.labelMd.copyWith(
                fontSize: 12, color: s.urgent ? c : BMHColors.ink,
                height: 1.4)),
            const SizedBox(height: 4),
            Text(s.detail,
              style: BMHText.bodySm.copyWith(
                fontSize: 10.5, color: BMHColors.ink, height: 1.5)),
          ])),
      ]));
  }
}

// ─────────────────────────────────────────────────────────
//  LEGEND + DISCLAIMER
// ─────────────────────────────────────────────────────────
class ReportLegend extends StatelessWidget {
  const ReportLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14, runSpacing: 6, children: [
      _key(BMHColors.rangeIn, 'Inside the range'),
      _key(BMHColors.rangeEdge, 'Just outside, borderline'),
      _key(BMHColors.rangeOut, 'Further outside the range'),
    ]);

  Widget _key(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9, height: 9,
        decoration: BoxDecoration(
          color: c.withOpacity(0.75),
          borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 5),
      Text(label,
        style: BMHText.monoSm.copyWith(
          fontSize: 8.5, color: BMHColors.ink)),
    ]);
}

class ReportDisclaimer extends StatelessWidget {
  final BloodReport report;
  const ReportDisclaimer({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BMHColors.bg2,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: BMHColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded,
              color: BMHColors.sMetabolic, size: 14),
            const SizedBox(width: 8),
            Text('THIS REPORT IS NOT MEDICAL ADVICE',
              style: BMHText.monoSm.copyWith(
                fontSize: 8, letterSpacing: 1.1,
                color: BMHColors.sMetabolic, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 9),
          Text(
            'It is written to help you understand your laboratory results '
            'in plain English. Every result should be reviewed with a '
            'registered practitioner who knows your history, your '
            'medicines and your supplements. A blood sample captures one '
            'moment, and further tests are usually needed before any '
            'conclusion. Reference ranges vary between laboratories and '
            'are built so that some entirely healthy people fall outside '
            'them, so a result outside a range is often normal for the '
            'person concerned. Please do not start, stop or change any '
            'medicine, supplement or exercise programme on the strength '
            'of anything here.',
            style: BMHText.bodySm.copyWith(
              fontSize: 10.5, color: BMHColors.ink, height: 1.55)),
          if (report.labName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'The signed report from ${report.labName}'
              '${report.labRef.isEmpty ? "" : " (${report.labRef})"} is '
              'the clinical record. Where the two differ, the signed '
              'report prevails.',
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.ink2, height: 1.5)),
          ],
        ]));
  }
}

// ─────────────────────────────────────────────────────────
//  TREND DOTS
//
//  A compact read of one group of markers: a dot per marker,
//  placed by where it sits inside its own reference range and
//  joined into a line, so a panel can be taken in at a glance
//  without reading eight numbers. Everything is drawn from the
//  report — nothing here is decorative.
// ─────────────────────────────────────────────────────────
class TrendDots extends StatelessWidget {
  final List<BloodMarker> markers;
  final Color color;
  final double height;

  const TrendDots({
    super.key,
    required this.markers,
    required this.color,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (ctx, box) => CustomPaint(
        size: Size(box.maxWidth, height),
        painter: _TrendPainter(markers: markers, color: color))));
  }
}

class _TrendPainter extends CustomPainter {
  final List<BloodMarker> markers;
  final Color color;
  _TrendPainter({required this.markers, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const padX = 6.0;
    final usableW = size.width - padX * 2;
    final midY = size.height / 2;
    final band = size.height * 0.30;

    // the in-range corridor
    final corridor = Paint()..color = BMHColors.rangeIn.withOpacity(0.13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, midY - band, size.width, band * 2),
        const Radius.circular(6)),
      corridor);

    final centre = Paint()
      ..color = BMHColors.rangeIn.withOpacity(0.40)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), centre);

    // one point per marker, positioned by where it sits in its range
    final pts = <Offset>[];
    for (var i = 0; i < markers.length; i++) {
      final m = markers[i];
      final x = markers.length == 1
        ? size.width / 2
        : padX + usableW * (i / (markers.length - 1));
      // barPosition: 0.35..0.65 spans the reference range itself
      final rel = ((m.barPosition - 0.5) / 0.15).clamp(-1.6, 1.6);
      pts.add(Offset(x, midY - rel * band));
    }

    final line = Paint()
      ..color = color.withOpacity(0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, line);

    for (var i = 0; i < pts.length; i++) {
      final m = markers[i];
      final c = markerColor(m.status, m.highIsGood);
      canvas.drawCircle(pts[i], 4.2,
        Paint()..color = BMHColors.bg0);
      canvas.drawCircle(pts[i], 3.2, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.markers != markers || old.color != color;
}
