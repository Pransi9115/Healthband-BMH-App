// ─────────────────────────────────────────────────────────
//  BIOMEDICAL DIET — MEDICATIONS
//
//  Separate from supplements on purpose. A supplement adds nutrients
//  to the body. A medication generally does not, but it can change
//  how much of a nutrient gets absorbed or lost — which is exactly
//  what explains a blood level that stays low while intake looks
//  fine.
//
//  Nothing here is ever added to intake totals. Medications only
//  add context, and every message points back to the care team.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/medication_service.dart';
import '../../core/diet/diet_models.dart';

const _accent = BMHColors.sDna;

class MedicationsScreen extends StatefulWidget {
  final DateTime? day;
  const MedicationsScreen({super.key, this.day});

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

  Future<void> _sheet({Medication? existing}) async {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final doseC = TextEditingController(text: existing?.dose ?? '');
    final noteC = TextEditingController(text: existing?.note ?? '');
    var affects = List<String>.from(existing?.affects ?? const []);
    var daily = existing?.daily ?? true;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BMHColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(BMHRadius.xl))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 22),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existing == null ? 'Add medication' : 'Edit medication',
              style: BMHText.heading2),
            const SizedBox(height: 4),
            Text('Medications are not counted as intake. They are recorded '
                 'because some affect how nutrients are absorbed.',
              style: BMHText.bodySm.copyWith(
                fontSize: 11, color: BMHColors.inkDim, height: 1.4)),

            if (existing == null) ...[
              const SizedBox(height: 16),
              Text('COMMON ONES',
                style: BMHText.monoSm.copyWith(
                  fontSize: 8.5, letterSpacing: 1.3,
                  color: BMHColors.inkDim)),
              const SizedBox(height: 8),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (final p in MedicationPreset.all)
                  GestureDetector(
                    onTap: () {
                      nameC.text = p.name;
                      doseC.text = p.dose;
                      noteC.text = p.note;
                      affects = List.of(p.affects);
                      setSheet(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(BMHRadius.full),
                        border: Border.all(
                          color: _accent.withOpacity(0.25))),
                      child: Text(p.name,
                        style: BMHText.monoSm.copyWith(
                          fontSize: 9.5, color: _accent)))),
              ]),
            ],

            const SizedBox(height: 18),
            _field(nameC, 'Name *', 'e.g. Omeprazole'),
            const SizedBox(height: 12),
            _field(doseC, 'Dose', 'e.g. 20 mg'),
            const SizedBox(height: 12),
            _field(noteC, 'Note', 'when you take it, why…'),

            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setSheet(() => daily = !daily),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: BMHColors.bg3,
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(
                    color: daily
                      ? BMHColors.sGut.withOpacity(0.35) : BMHColors.line)),
                child: Row(children: [
                  Expanded(child: Text('Taken daily',
                    style: BMHText.labelMd.copyWith(color: BMHColors.ink))),
                  Container(
                    width: 40, height: 23,
                    decoration: BoxDecoration(
                      color: daily ? BMHColors.sGut : BMHColors.bg4,
                      borderRadius: BorderRadius.circular(BMHRadius.full)),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 150),
                      alignment: daily
                        ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 19, height: 19,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)))),
                ]))),

            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Text('MAY AFFECT',
                style: BMHText.monoSm.copyWith(
                  fontSize: 8.5, letterSpacing: 1.3,
                  color: BMHColors.inkDim))),
            ]),
            const SizedBox(height: 4),
            Text('Nutrients this medication is documented to affect. Used '
                 'only to add context to your biomarkers.',
              style: BMHText.bodySm.copyWith(
                fontSize: 10, color: BMHColors.inkMute, height: 1.35)),
            const SizedBox(height: 9),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final m in Micronutrient.all)
                GestureDetector(
                  onTap: () => setSheet(() {
                    affects.contains(m.name)
                      ? affects.remove(m.name)
                      : affects.add(m.name);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: affects.contains(m.name)
                        ? _accent.withOpacity(0.16) : BMHColors.bg3,
                      borderRadius: BorderRadius.circular(BMHRadius.full),
                      border: Border.all(
                        color: affects.contains(m.name)
                          ? _accent.withOpacity(0.45) : BMHColors.line)),
                    child: Text(m.name,
                      style: BMHText.monoSm.copyWith(
                        fontSize: 9,
                        color: affects.contains(m.name)
                          ? _accent : BMHColors.inkDim)))),
            ]),

            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: BMHText.bodySm.copyWith(
                fontSize: 11, color: BMHColors.danger)),
            ],

            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final name = nameC.text.trim();
                if (name.isEmpty) {
                  setSheet(() => error = 'Give the medication a name.');
                  return;
                }
                final m = Medication(
                  id: existing?.id ??
                    'med_${DateTime.now().microsecondsSinceEpoch}',
                  name: name,
                  dose: doseC.text.trim(),
                  note: noteC.text.trim(),
                  daily: daily,
                  active: existing?.active ?? true,
                  affects: affects);
                existing == null
                  ? await _svc.add(m)
                  : await _svc.update(m);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(BMHRadius.full)),
                child: Text(existing == null ? 'Add' : 'Save changes',
                  textAlign: TextAlign.center,
                  style: BMHText.labelLg.copyWith(
                    color: BMHColors.bg0,
                    fontWeight: FontWeight.w600)))),
          ])))));
  }

  Widget _field(TextEditingController c, String label, String hint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(),
        style: BMHText.monoSm.copyWith(
          fontSize: 8.5, letterSpacing: 1.3, color: BMHColors.inkDim)),
      const SizedBox(height: 6),
      TextField(
        controller: c,
        style: BMHText.bodyMd.copyWith(color: BMHColors.ink),
        cursorColor: _accent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: BMHText.bodyMd.copyWith(color: BMHColors.inkMute),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 13, vertical: 11))),
    ]);

  Future<void> _confirmDelete(Medication m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMHColors.bg2,
        title: Text('Remove ${m.name}?', style: BMHText.heading3),
        content: Text('It will no longer appear in your records.',
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
    if (ok == true) await _svc.remove(m.id);
  }

  @override
  Widget build(BuildContext context) {
    final items = _svc.all;

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
                const BMHEyebrow('BIOMEDICAL DIET'),
                Text('Medications', style: BMHText.heading1),
              ])),
            BMHIconButton(
              onTap: () => _sheet(),
              icon: const Icon(Icons.add_rounded,
                color: _accent, size: 18)),
          ])),

        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BMHSpacing.s5, 6, BMHSpacing.s5, 40),
          children: [
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: BMHColors.line)),
                child: Column(children: [
                  const Icon(Icons.local_pharmacy_outlined,
                    color: BMHColors.inkMute, size: 32),
                  const SizedBox(height: 12),
                  Text('No medications added',
                    style: BMHText.labelLg.copyWith(color: BMHColors.ink2)),
                  const SizedBox(height: 6),
                  Text('Some medications change how nutrients are '
                       'absorbed. Recording them helps explain your '
                       'blood results.',
                    textAlign: TextAlign.center,
                    style: BMHText.bodySm.copyWith(
                      fontSize: 11, color: BMHColors.inkMute, height: 1.5)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _sheet(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 11),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius:
                          BorderRadius.circular(BMHRadius.full)),
                      child: Text('Add medication',
                        style: BMHText.labelMd.copyWith(
                          color: BMHColors.bg0,
                          fontWeight: FontWeight.w600)))),
                ]))
            else ...[
              Text(
                '${_svc.takenCount(_day)} of ${items.length} taken '
                '${_isToday ? "today" : "that day"}. Medications never '
                'count toward intake.',
                style: BMHText.bodySm.copyWith(
                  fontSize: 10.5, color: BMHColors.inkMute, height: 1.45)),
              const SizedBox(height: 14),
              for (final m in items) ...[
                _MedRow(
                  med: m,
                  taken: _svc.isTaken(_day, m.id),
                  onToggle: (v) => _svc.setTaken(_day, m.id, v),
                  onEdit: () => _sheet(existing: m),
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
                      'Never stop or change a prescription based on what '
                      'this app shows. Bring it to your care team instead.',
                      style: BMHText.bodySm.copyWith(
                        fontSize: 10.5, color: BMHColors.inkMute,
                        height: 1.45))),
                  ])),
            ],
          ])),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _MedRow extends StatelessWidget {
  final Medication med;
  final bool taken;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedRow({
    required this.med,
    required this.taken,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(
          color: taken
            ? BMHColors.sGut.withOpacity(0.32) : BMHColors.line)),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => onToggle(!taken),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: taken ? BMHColors.sGut : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: taken ? BMHColors.sGut : BMHColors.inkMute,
                  width: 1.5)),
              child: taken
                ? const Icon(Icons.check_rounded,
                    color: BMHColors.bg0, size: 16)
                : null)),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(med.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BMHText.labelLg.copyWith(color: BMHColors.ink))),
                if (med.dose.isNotEmpty) ...[
                  const SizedBox(width: 7),
                  Text(med.dose,
                    style: BMHText.monoSm.copyWith(
                      fontSize: 8.5, color: BMHColors.inkMute)),
                ],
                if (med.daily) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BMHColors.sGut.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(BMHRadius.full)),
                    child: Text('DAILY',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 7, letterSpacing: 0.5,
                        color: BMHColors.sGut,
                        fontWeight: FontWeight.w700))),
                ],
              ]),
              if (med.note.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(med.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9, color: BMHColors.inkDim, height: 1.35)),
              ],
            ])),
          GestureDetector(
            onTap: onEdit,
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.edit_outlined,
                color: BMHColors.inkDim, size: 15))),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.delete_outline_rounded,
                color: BMHColors.danger, size: 15))),
        ]),
        if (med.affects.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            const SizedBox(width: 39),
            Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [
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
            ])),
          ]),
        ],
      ]));
  }
}
