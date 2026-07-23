// ─────────────────────────────────────────────────────────
//  BIORESPONSE — FULL BLOOD REPORT
//  Every marker in the panel, grouped by body system, each with
//  its reference bar and the reporting clinician's note.
//  Counts come from the marker data, so what the header says and
//  what the patient can count always agree.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/blood_report_service.dart';
import 'biomarkers_screen.dart';

class BloodReportScreen extends StatefulWidget {
  final BloodReport report;
  const BloodReportScreen({super.key, required this.report});

  @override
  State<BloodReportScreen> createState() => _BloodReportScreenState();
}

class _BloodReportScreenState extends State<BloodReportScreen> {
  bool _onlyFlagged = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;

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
                const BMHEyebrow('BLOOD PANEL'),
                Text(r.testName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BMHText.heading2),
              ])),
          ])),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.s5),
          child: Row(children: [
            Expanded(child: Text('Tested ${fmtDate(r.testDate)}',
              style: BMHText.monoSm.copyWith(
                fontSize: 9.5, color: BMHColors.inkDim))),
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
                      ? BMHColors.danger : BMHColors.inkDim),
                  const SizedBox(width: 6),
                  Text('Outside range only',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9,
                      color: _onlyFlagged
                        ? BMHColors.danger : BMHColors.inkDim)),
                ]))),
          ])),

        const SizedBox(height: 12),

        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BMHSpacing.s5, 0, BMHSpacing.s5, 40),
          children: [
            if (r.clinicalContext.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BMHColors.bg2,
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(color: BMHColors.line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CLINICAL CONTEXT',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 8, letterSpacing: 1.4,
                        color: BMHColors.inkDim)),
                    const SizedBox(height: 7),
                    Text(r.clinicalContext,
                      style: BMHText.bodySm.copyWith(
                        fontSize: 10.5, color: BMHColors.ink2,
                        height: 1.5)),
                  ])),
              const SizedBox(height: 18),
            ],

            // Legend
            Row(children: [
              _key(BMHColors.success, 'In range'),
              const SizedBox(width: 14),
              _key(BMHColors.sMetabolic, 'Borderline'),
              const SizedBox(width: 14),
              _key(BMHColors.danger, 'Outside range'),
            ]),
            const SizedBox(height: 18),

            for (final g in r.groups) ...[
              ...(() {
                final markers = r.inGroup(g)
                    .where((m) => !_onlyFlagged || m.isConcern)
                    .toList();
                if (markers.isEmpty) return <Widget>[];
                return <Widget>[
                  Row(children: [
                    Expanded(child: BMHSectionTitle(g)),
                    Text('${markers.length}',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 9, color: BMHColors.inkMute)),
                  ]),
                  const SizedBox(height: 10),
                  for (final m in markers) ...[
                    _Row(marker: m),
                    const SizedBox(height: 9),
                  ],
                  const SizedBox(height: 12),
                ];
              })(),
            ],

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: BMHColors.bg2,
                borderRadius: BorderRadius.circular(BMHRadius.md),
                border: Border.all(color: BMHColors.line)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                    color: BMHColors.inkDim, size: 14),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Prepared from a blood sample without access to your '
                    'full medical records. Not for diagnosing or treating '
                    'any condition — always consult a medical professional '
                    'before acting on these results.',
                    style: BMHText.bodySm.copyWith(
                      fontSize: 10, color: BMHColors.inkMute,
                      height: 1.45))),
                ])),
          ])),
      ])),
    );
  }

  Widget _key(Color c, String label) => Row(children: [
    Container(
      width: 9, height: 9,
      decoration: BoxDecoration(
        color: c.withOpacity(0.6),
        borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 5),
    Text(label,
      style: BMHText.monoSm.copyWith(
        fontSize: 8.5, color: BMHColors.inkDim)),
  ]);
}

// ─────────────────────────────────────────────────────────
class _Row extends StatefulWidget {
  final BloodMarker marker;
  const _Row({required this.marker});

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.marker;
    final c = markerColor(m.status, m.highIsGood);
    final hasNote = m.note.isNotEmpty;

    return GestureDetector(
      onTap: hasNote ? () => setState(() => _open = !_open) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(
            color: m.isConcern ? c.withOpacity(0.28) : BMHColors.line)),
        child: Column(children: [
          Row(children: [
            Expanded(child: Row(children: [
              Flexible(child: Text(m.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BMHText.labelMd.copyWith(
                  fontSize: 12, color: BMHColors.ink))),
              if (m.priority) ...[
                const SizedBox(width: 6),
                Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                    color: BMHColors.danger, shape: BoxShape.circle)),
              ],
            ])),
            const SizedBox(width: 8),
            Text('${fmtNum(m.value)} ${m.unit}',
              style: BMHText.monoSm.copyWith(
                fontSize: 10.5, color: c, fontWeight: FontWeight.w700)),
            if (hasNote) ...[
              const SizedBox(width: 4),
              Icon(_open
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                size: 15, color: BMHColors.inkMute),
            ],
          ]),
          const SizedBox(height: 9),
          RangeBar(marker: m, color: c),
          Row(children: [
            Text(fmtNum(m.refLow),
              style: BMHText.monoSm.copyWith(
                fontSize: 8, color: BMHColors.inkFaint)),
            const Spacer(),
            Text(
              m.highIsGood && m.status == MarkerStatus.high
                ? 'HIGH — PROTECTIVE'
                : m.status.label,
              style: BMHText.monoSm.copyWith(
                fontSize: 8, color: c, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(fmtNum(m.refHigh),
              style: BMHText.monoSm.copyWith(
                fontSize: 8, color: BMHColors.inkFaint)),
          ]),
          if (_open && hasNote) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: BMHColors.bg2,
                borderRadius: BorderRadius.circular(BMHRadius.sm)),
              child: Text(m.note,
                style: BMHText.bodySm.copyWith(
                  fontSize: 10.5, color: BMHColors.ink2, height: 1.5))),
          ],
        ])));
  }
}
