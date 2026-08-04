// ─────────────────────────────────────────────────────────
//  MEDICATION AND SUPPLEMENTS — MEDICATION
//
//  Every dose is its own tick. A medication taken twice a day shows
//  two slots, because "did you take your metformin today" has two
//  different answers at 9 in the morning and 9 at night, and folding
//  them into one checkbox loses the one that matters.
//
//  Nothing here is ever added to intake totals. Medications add
//  context — a nutrient that stays low while intake looks fine — and
//  every message points back to the care team.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/medication_service.dart';
import '../../core/meds/medication_reminder_service.dart';
import 'add_medication_screen.dart';

const _accent = BMHColors.sDna;

class MedicationsScreen extends StatefulWidget {
  final DateTime? day;

  /// True when shown as a tab inside MedicationSupplementsScreen.
  final bool embedded;

  const MedicationsScreen({super.key, this.day, this.embedded = false});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final _svc = MedicationService.instance;
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    _day = widget.day ?? DateTime.now();
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

  bool get _isToday {
    final n = DateTime.now();
    return _day.year == n.year && _day.month == n.month && _day.day == n.day;
  }

  String get _dayLabel {
    if (_isToday) return 'Today · ${_fmtDate(_day)}';
    final y = DateTime.now().subtract(const Duration(days: 1));
    if (_day.year == y.year && _day.month == y.month && _day.day == y.day) {
      return 'Yesterday · ${_fmtDate(_day)}';
    }
    return _fmtDate(_day);
  }

  static String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  void _shiftDay(int delta) {
    final next = _day.add(Duration(days: delta));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _day = next);
  }

  Future<void> _open({Medication? existing}) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddMedicationScreen(existing: existing)));
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete(Medication m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMHColors.bg3,
        title: Text('Remove ${m.name}?', style: BMHText.heading3),
        content: Text(
          'Its schedule, reminders and dose history are removed too.',
          style: BMHText.bodySm.copyWith(color: BMHColors.inkDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
              style: BMHText.labelMd.copyWith(color: BMHColors.inkDim))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
              style: BMHText.labelMd.copyWith(color: BMHColors.danger))),
        ]));
    if (ok == true) {
      await MedicationReminderService.instance.cancelFor(m.id);
      await _svc.remove(m.id);
    }
  }

  // ── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final items = _svc.scheduledOn(_day);
    final taken = _svc.dosesTaken(_day);
    final total = _svc.dosesTotal(_day);
    final next = _svc.nextDose(_day);
    final missed = _svc.dosesMissed(_day);

    final body = Column(children: [
      if (!widget.embedded)
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
                const BMHEyebrow('MEDICATION AND SUPPLEMENTS'),
                Text('Medication', style: BMHText.heading1),
              ])),
            BMHIconButton(
              onTap: () => _open(),
              icon: const Icon(Icons.add_rounded,
                color: _accent, size: 18)),
          ])),

      // ── DAY STRIP ─────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.s5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: BMHColors.bg2,
            borderRadius: BorderRadius.circular(BMHRadius.full),
            border: Border.all(color: BMHColors.line)),
          child: Row(children: [
            GestureDetector(
              onTap: () => _shiftDay(-1),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.chevron_left_rounded,
                  color: BMHColors.inkDim, size: 18))),
            Expanded(child: Text(_dayLabel,
              textAlign: TextAlign.center,
              style: BMHText.labelLg.copyWith(color: BMHColors.ink))),
            GestureDetector(
              onTap: _isToday ? null : () => _shiftDay(1),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.chevron_right_rounded,
                  color: _isToday
                    ? BMHColors.inkFaint : BMHColors.inkDim, size: 18))),
          ]))),

      const SizedBox(height: 14),

      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(
          BMHSpacing.s5, 0, BMHSpacing.s5, 40),
        children: [
          if (items.isEmpty)
            _empty()
          else ...[
            // ── ADHERENCE SUMMARY ─────────────────────
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.09),
                borderRadius: BorderRadius.circular(BMHRadius.lg),
                border: Border.all(color: _accent.withOpacity(0.3))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_isToday ? "TODAY" : _fmtDate(_day).toUpperCase()} · '
                    '$taken OF $total DOSES TAKEN',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 10, letterSpacing: 1.1, color: _accent)),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(BMHRadius.full),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : taken / total,
                      minHeight: 4,
                      backgroundColor: BMHColors.bg4,
                      valueColor: AlwaysStoppedAnimation(
                        taken == total ? BMHColors.sGut : _accent))),
                  const SizedBox(height: 9),
                  Text(
                    next != null
                      ? 'Next: ${next.med.name} at ${next.timeLabel}'
                      : missed > 0
                        ? '$missed dose${missed == 1 ? "" : "s"} missed'
                        : 'All doses done',
                    style: BMHText.bodySm.copyWith(
                      fontSize: 11,
                      color: missed > 0 && next == null
                        ? BMHColors.danger : BMHColors.inkDim)),
                ])),

            const SizedBox(height: 18),
            Text('TO BE TAKEN',
              style: BMHText.monoSm.copyWith(
                fontSize: 10, letterSpacing: 1.5, color: BMHColors.inkDim)),
            const SizedBox(height: 11),

            for (final m in items) ...[
              _MedCard(
                med: m,
                day: _day,
                svc: _svc,
                onEdit: () => _open(existing: m),
                onDelete: () => _confirmDelete(m)),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 6),
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
                    'Medications never count toward intake. Never stop or '
                    'change a prescription based on what this app shows — '
                    'bring it to your care team instead.',
                    style: BMHText.bodySm.copyWith(
                      fontSize: 10.5, color: BMHColors.inkMute,
                      height: 1.45))),
                ])),
          ],
        ])),
    ]);

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: SafeArea(child: body),
    );
  }

  Widget _empty() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    decoration: BoxDecoration(
      color: BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.lg),
      border: Border.all(color: BMHColors.line)),
    child: Column(children: [
      const Icon(Icons.local_pharmacy_outlined,
        color: BMHColors.inkMute, size: 32),
      const SizedBox(height: 12),
      Text('No medication added',
        style: BMHText.labelLg.copyWith(color: BMHColors.ink2)),
      const SizedBox(height: 6),
      Text('Add what you take and when. You get a reminder at each dose '
           'time, and your blood results gain the context to explain '
           'themselves.',
        textAlign: TextAlign.center,
        style: BMHText.bodySm.copyWith(
          fontSize: 11, color: BMHColors.inkMute, height: 1.5)),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => _open(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(BMHRadius.full)),
          child: Text('Add medication',
            style: BMHText.labelMd.copyWith(
              color: BMHColors.bg0, fontWeight: FontWeight.w600)))),
    ]));
}

// ─────────────────────────────────────────────────────────
//  ONE MEDICATION, WITH A SLOT PER DOSE
// ─────────────────────────────────────────────────────────
class _MedCard extends StatelessWidget {
  final Medication med;
  final DateTime day;
  final MedicationService svc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedCard({
    required this.med,
    required this.day,
    required this.svc,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final times = med.resolvedTimes;
    final anyMissed = List.generate(times.length, (i) => i)
        .any((i) => svc.doseStatus(day, med, i) == DoseStatus.missed);
    final allTaken = List.generate(times.length, (i) => i)
        .every((i) => svc.isDoseTaken(day, med.id, i));

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(
          color: allTaken
            ? BMHColors.sGut.withOpacity(0.3)
            : anyMissed
              ? BMHColors.danger.withOpacity(0.3)
              : BMHColors.line)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(med.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BMHText.labelLg.copyWith(color: BMHColors.ink))),
                if (med.strengthLine.isNotEmpty) ...[
                  const SizedBox(width: 7),
                  Text(med.strengthLine,
                    style: BMHText.monoSm.copyWith(
                      fontSize: 8.5, color: BMHColors.inkMute)),
                ],
              ]),
              const SizedBox(height: 3),
              Text(med.scheduleLine,
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkDim, height: 1.35)),
            ])),
          Icon(
            med.remind
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
            size: 15,
            color: med.remind ? BMHColors.sGut : BMHColors.inkMute),
          GestureDetector(
            onTap: onEdit,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Icon(Icons.edit_outlined,
                color: BMHColors.inkDim, size: 15))),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.delete_outline_rounded,
                color: BMHColors.danger, size: 15))),
        ]),

        const SizedBox(height: 11),

        // ── DOSE SLOTS ──────────────────────────────────
        Row(children: [
          for (var i = 0; i < times.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(child: _DoseChip(
              time: Medication.formatMinutes(times[i]),
              status: svc.doseStatus(day, med, i),
              onTap: () => svc.toggleDose(day, med.id, i))),
          ],
        ]),

        if (med.affects.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in med.affects)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(BMHRadius.full)),
                child: Text('may affect $a',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 8, color: _accent))),
          ]),
        ],

        if (med.note.isNotEmpty) ...[
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: Text(med.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.inkDim, height: 1.35))),
          ]),
        ],
      ]));
  }
}

// ─────────────────────────────────────────────────────────
class _DoseChip extends StatelessWidget {
  final String time;
  final DoseStatus status;
  final VoidCallback onTap;

  const _DoseChip({
    required this.time,
    required this.status,
    required this.onTap,
  });

  Color get _c => switch (status) {
        DoseStatus.taken    => BMHColors.sGut,
        DoseStatus.due      => _accent,
        DoseStatus.missed   => BMHColors.danger,
        DoseStatus.upcoming => BMHColors.inkMute,
      };

  String get _text => switch (status) {
        DoseStatus.taken    => 'Taken',
        DoseStatus.due      => 'Due',
        DoseStatus.missed   => 'Missed',
        DoseStatus.upcoming => 'Later',
      };

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: status == DoseStatus.taken
          ? _c.withOpacity(0.12) : BMHColors.bg3,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(
          color: status == DoseStatus.upcoming
            ? BMHColors.line : _c.withOpacity(0.4))),
      child: Column(children: [
        Text(time,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BMHText.monoSm.copyWith(fontSize: 9.5, color: _c)),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (status == DoseStatus.taken) ...[
            Icon(Icons.check_rounded, size: 12, color: _c),
            const SizedBox(width: 3),
          ],
          Flexible(child: Text(_text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BMHText.labelMd.copyWith(
              fontSize: 10.5,
              color: status == DoseStatus.upcoming
                ? BMHColors.inkDim : _c))),
        ]),
      ])));
}
