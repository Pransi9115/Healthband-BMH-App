// ─────────────────────────────────────────────────────────
//  BIORESPONSE — FULL BLOOD REPORT
//
//  The whole document, in the order the printed report reads:
//
//    1. masthead — who ran it, when, under which lab reference
//    2. the four counts
//    3. read this first — the threads that tie markers together
//    4. every marker, grouped by body system, each expandable to
//       its plain-English meaning and what you can do about it
//    5. what to do next, in priority order
//    6. the notice that this is not medical advice
//
//  Counts come from the marker data, so what the header says and
//  what the patient can count always agree. Section chips at the
//  top jump to a body system, mirroring the report's own nav.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/blood_report_service.dart';
import 'blood_report_format.dart';

class BloodReportScreen extends StatefulWidget {
  final BloodReport report;
  const BloodReportScreen({super.key, required this.report});

  @override
  State<BloodReportScreen> createState() => _BloodReportScreenState();
}

class _BloodReportScreenState extends State<BloodReportScreen> {
  bool _onlyFlagged = false;

  final _scroll = ScrollController();
  final Map<String, GlobalKey> _anchors = {};

  @override
  void initState() {
    super.initState();
    for (final g in widget.report.groups) {
      _anchors[g] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpTo(String group) {
    final ctx = _anchors[group]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.05);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: SafeArea(child: Column(children: [
        // ── HEADER ────────────────────────────────────────
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
                const BMHEyebrow('BLOOD PANEL'),
                Text(r.testName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BMHText.heading2),
              ])),
          ])),

        // ── FILTER ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.s5),
          child: Row(children: [
            Expanded(child: Text('Tested ${fmtDate(r.testDate)}',
              style: BMHText.monoSm.copyWith(
                fontSize: 9.5, color: BMHColors.ink2))),
            GestureDetector(
              onTap: () => setState(() => _onlyFlagged = !_onlyFlagged),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _onlyFlagged
                    ? BMHColors.danger.withOpacity(0.14)
                    : BMHColors.bg2,
                  borderRadius: BorderRadius.circular(BMHRadius.full),
                  border: Border.all(
                    color: _onlyFlagged
                      ? BMHColors.danger.withOpacity(0.4)
                      : BMHColors.line)),
                child: Row(children: [
                  Icon(
                    _onlyFlagged
                      ? Icons.filter_alt_rounded
                      : Icons.filter_alt_outlined,
                    size: 12,
                    color: _onlyFlagged
                      ? BMHColors.danger : BMHColors.ink2),
                  const SizedBox(width: 6),
                  Text(
                    _onlyFlagged
                      ? 'Only the flagged ones'
                      : 'All ${r.totalCount} markers',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9,
                      color: _onlyFlagged
                        ? BMHColors.danger : BMHColors.ink2)),
                ]))),
          ])),

        const SizedBox(height: 12),

        Expanded(child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(
            BMHSpacing.s5, 0, BMHSpacing.s5, 40),
          children: [
            ReportMasthead(report: r),
            const SizedBox(height: 16),
            ReportCounts(report: r),

            if (r.threads.isNotEmpty) ...[
              const SizedBox(height: 24),
              BMHSectionTitle('Read this first'),
              const SizedBox(height: 12),
              ReportThreads(report: r),
            ],

            // ── SECTION JUMP CHIPS ────────────────────────
            const SizedBox(height: 20),
            SizedBox(height: 30, child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final g in r.groups) ...[
                  GestureDetector(
                    onTap: () => _jumpTo(g),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: BMHColors.bg2,
                        borderRadius:
                          BorderRadius.circular(BMHRadius.full),
                        border: Border.all(color: BMHColors.line)),
                      child: Text(g,
                        style: BMHText.monoSm.copyWith(
                          fontSize: 9, color: BMHColors.ink)))),
                ],
              ])),

            const SizedBox(height: 18),
            const ReportLegend(),
            const SizedBox(height: 18),

            // ── EVERY MARKER, BY BODY SYSTEM ──────────────
            for (final g in r.groups) ...[
              ...(() {
                final markers = r.inGroup(g)
                    .where((m) =>
                      !_onlyFlagged ||
                      m.isConcern ||
                      m.isFavourable ||
                      m.status == MarkerStatus.borderline)
                    .toList();
                if (markers.isEmpty) return <Widget>[];
                return <Widget>[
                  Row(key: _anchors[g], children: [
                    Expanded(child: BMHSectionTitle(g)),
                    Text('${markers.length}',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 9, color: BMHColors.ink2)),
                  ]),
                  const SizedBox(height: 10),
                  for (final m in markers) ...[
                    ReportMarkerRow(marker: m),
                    const SizedBox(height: 9),
                  ],
                  const SizedBox(height: 12),
                ];
              })(),
            ],

            // ── WHAT TO DO NEXT ───────────────────────────
            if (r.steps.isNotEmpty) ...[
              const SizedBox(height: 10),
              BMHSectionTitle('What to do next'),
              const SizedBox(height: 6),
              Text('In the order that makes the most difference.',
                style: BMHText.bodySm.copyWith(
                  fontSize: 11, color: BMHColors.ink)),
              const SizedBox(height: 12),
              ReportSteps(report: r),
              const SizedBox(height: 18),
            ],

            ReportDisclaimer(report: r),
          ])),
      ])),
    );
  }
}
