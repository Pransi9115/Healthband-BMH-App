// ─────────────────────────────────────────────────────────
//  BIOMEDICAL DIET — SUPPLEMENTS
//
//  Lives in the diet module because a supplement is something the
//  patient takes, like a meal — and is logged the same way. What is
//  taken here flows straight into BioResponse → Biomarkers.
//
//  "Take daily" is the important control: routine supplements count
//  automatically so nobody has to tick the same tablet every morning
//  for years. Ticking a daily one off records that it was missed.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/supplement_service.dart';
import '../../core/diet/diet_models.dart';

const _accent = BMHColors.sMetabolic;

class SupplementsScreen extends StatefulWidget {
  final DateTime? day;
  const SupplementsScreen({super.key, this.day});

  @override
  State<SupplementsScreen> createState() => _SupplementsScreenState();
}

class _SupplementsScreenState extends State<SupplementsScreen> {
  final _svc = SupplementService.instance;
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
    if (_isToday) return 'Today';
    final y = DateTime.now().subtract(const Duration(days: 1));
    if (_day.year == y.year && _day.month == y.month && _day.day == y.day) {
      return 'Yesterday';
    }
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
               'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${_day.day} ${m[_day.month - 1]}';
  }

  void _shiftDay(int d) {
    final next = _day.add(Duration(days: d));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _day = next);
  }

  // ── ADD / EDIT ──────────────────────────────────────────
  Future<void> _sheet({Supplement? existing}) async {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final brandC = TextEditingController(text: existing?.brand ?? '');
    final doseC = TextEditingController(text: existing?.dose ?? '');
    final nutrients = Map<String, double>.from(existing?.nutrients ?? {});
    var daily = existing?.daily ?? true;      // routine is the common case
    String? withMeal = existing?.withMeal;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BMHColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(BMHRadius.xl))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        void applyPreset(SupplementPreset p) {
          nameC.text = p.name;
          doseC.text = p.dose;
          nutrients
            ..clear()
            ..addAll(p.nutrients);
          setSheet(() {});
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 22),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Add supplement' : 'Edit supplement',
                style: BMHText.heading2),
              const SizedBox(height: 4),
              Text('Nutrient amounts feed your intake totals, so keep them '
                   'as close to the label as you can.',
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
                  for (final p in SupplementPreset.all)
                    GestureDetector(
                      onTap: () => applyPreset(p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.08),
                          borderRadius:
                            BorderRadius.circular(BMHRadius.full),
                          border: Border.all(
                            color: _accent.withOpacity(0.25))),
                        child: Text(p.name,
                          style: BMHText.monoSm.copyWith(
                            fontSize: 9.5, color: _accent)))),
                ]),
              ],

              const SizedBox(height: 18),
              _field(nameC, 'Name *', 'e.g. Vitamin D3'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(brandC, 'Brand', 'optional')),
                const SizedBox(width: 10),
                Expanded(child: _field(doseC, 'Dose', '1 capsule')),
              ]),

              // Take daily
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
                        ? BMHColors.sGut.withOpacity(0.35)
                        : BMHColors.line)),
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Take daily',
                          style: BMHText.labelMd.copyWith(
                            color: BMHColors.ink)),
                        const SizedBox(height: 3),
                        Text(
                          daily
                            ? 'Counts automatically each day. Untick a day '
                              'you miss it.'
                            : 'You will tick it on the days you take it.',
                          style: BMHText.bodySm.copyWith(
                            fontSize: 10, color: BMHColors.inkDim,
                            height: 1.35)),
                      ])),
                    const SizedBox(width: 10),
                    Container(
                      width: 40, height: 23,
                      decoration: BoxDecoration(
                        color: daily
                          ? BMHColors.sGut : BMHColors.bg4,
                        borderRadius:
                          BorderRadius.circular(BMHRadius.full)),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 150),
                        alignment: daily
                          ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 19, height: 19,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle)))),
                  ]))),

              // Taken with a meal
              const SizedBox(height: 14),
              Text('TAKEN WITH',
                style: BMHText.monoSm.copyWith(
                  fontSize: 8.5, letterSpacing: 1.3,
                  color: BMHColors.inkDim)),
              const SizedBox(height: 8),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (final m in const [
                  null, 'Breakfast', 'Lunch', 'Dinner', 'Snack'])
                  GestureDetector(
                    onTap: () => setSheet(() => withMeal = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: withMeal == m
                          ? _accent.withOpacity(0.16)
                          : BMHColors.bg3,
                        borderRadius:
                          BorderRadius.circular(BMHRadius.full),
                        border: Border.all(
                          color: withMeal == m
                            ? _accent.withOpacity(0.45)
                            : BMHColors.line)),
                      child: Text(m ?? 'No meal',
                        style: BMHText.monoSm.copyWith(
                          fontSize: 9.5,
                          color: withMeal == m
                            ? _accent : BMHColors.inkDim)))),
              ]),

              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: Text('NUTRIENTS PER DOSE',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 8.5, letterSpacing: 1.3,
                    color: BMHColors.inkDim))),
                GestureDetector(
                  onTap: () async {
                    final picked = await _pickNutrient(ctx, nutrients.keys);
                    if (picked != null) {
                      nutrients[picked] = 0;
                      setSheet(() {});
                    }
                  },
                  child: Text('+ Add nutrient',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9.5, color: BMHColors.cyan))),
              ]),
              const SizedBox(height: 8),

              if (nutrients.isEmpty)
                Text('None yet — pick a common supplement above or add a '
                     'nutrient.',
                  style: BMHText.bodySm.copyWith(
                    fontSize: 10.5, color: BMHColors.inkMute))
              else
                for (final key in nutrients.keys.toList()) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(child: Text(key,
                        style: BMHText.labelMd.copyWith(
                          fontSize: 12, color: BMHColors.ink))),
                      SizedBox(width: 86, child: TextField(
                        controller: TextEditingController(
                          text: nutrients[key] == 0
                            ? ''
                            : Supplement.fmt(nutrients[key]!)),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                        textAlign: TextAlign.right,
                        style: BMHText.monoSm.copyWith(
                          fontSize: 12, color: BMHColors.ink),
                        cursorColor: _accent,
                        onChanged: (v) =>
                          nutrients[key] = double.tryParse(v) ?? 0,
                        decoration: const InputDecoration(
                          isDense: true, hintText: '0',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9)))),
                      const SizedBox(width: 8),
                      SizedBox(width: 34, child: Text(
                        Micronutrient.byName(key)?.unit ?? '',
                        style: BMHText.monoSm.copyWith(
                          fontSize: 9.5, color: BMHColors.inkDim))),
                      GestureDetector(
                        onTap: () {
                          nutrients.remove(key);
                          setSheet(() {});
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded,
                            size: 14, color: BMHColors.inkMute))),
                    ])),
                ],

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
                    setSheet(() => error = 'Give the supplement a name.');
                    return;
                  }
                  nutrients.removeWhere((_, v) => v <= 0);
                  final s = Supplement(
                    id: existing?.id ??
                      'supp_${DateTime.now().microsecondsSinceEpoch}',
                    name: name,
                    brand: brandC.text.trim(),
                    dose: doseC.text.trim(),
                    nutrients: nutrients,
                    active: existing?.active ?? true,
                    daily: daily,
                    withMeal: withMeal);
                  existing == null
                    ? await _svc.add(s)
                    : await _svc.update(s);
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
            ])));
      }));
  }

  Future<String?> _pickNutrient(
      BuildContext ctx, Iterable<String> already) async {
    final options = Micronutrient.all
        .where((m) => !already.contains(m.name))
        .toList();
    if (options.isEmpty) return null;
    return showModalBottomSheet<String>(
      context: ctx,
      backgroundColor: BMHColors.bg3,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(BMHRadius.xl))),
      builder: (c) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Text('Add nutrient', style: BMHText.heading3),
          const SizedBox(height: 10),
          Flexible(child: ListView(
            shrinkWrap: true,
            children: [
              for (final m in options)
                ListTile(
                  dense: true,
                  title: Text(m.name,
                    style: BMHText.labelMd.copyWith(color: BMHColors.ink)),
                  trailing: Text(m.unit,
                    style: BMHText.monoSm.copyWith(
                      fontSize: 10, color: BMHColors.inkDim)),
                  onTap: () => Navigator.pop(c, m.name)),
            ])),
          const SizedBox(height: 10),
        ])));
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

  Future<void> _confirmDelete(Supplement s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMHColors.bg2,
        title: Text('Remove ${s.name}?', style: BMHText.heading3),
        content: Text('It will no longer count toward your intake.',
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
    if (ok == true) await _svc.remove(s.id);
  }

  // ── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final items = _svc.all;
    final taken = _svc.takenCount(_day);

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
                Text('Supplements', style: BMHText.heading1),
              ])),
            BMHIconButton(
              onTap: () => _sheet(),
              icon: const Icon(Icons.add_rounded,
                color: _accent, size: 18)),
          ])),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.s5),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: BMHColors.bg2,
              borderRadius: BorderRadius.circular(BMHRadius.full),
              border: Border.all(color: BMHColors.line)),
            child: Row(children: [
              GestureDetector(
                onTap: () => _shiftDay(-1),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.chevron_left_rounded,
                    color: BMHColors.inkDim, size: 18))),
              Expanded(child: Text(_dayLabel,
                textAlign: TextAlign.center,
                style: BMHText.labelLg.copyWith(color: BMHColors.ink))),
              GestureDetector(
                onTap: () => _shiftDay(1),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.chevron_right_rounded,
                    color: _isToday
                      ? BMHColors.inkFaint : BMHColors.inkDim,
                    size: 18))),
            ]))),

        const SizedBox(height: 14),

        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BMHSpacing.s5, 0, BMHSpacing.s5, 40),
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
                  const Icon(Icons.medication_outlined,
                    color: BMHColors.inkMute, size: 32),
                  const SizedBox(height: 12),
                  Text('No supplements added',
                    style: BMHText.labelLg.copyWith(color: BMHColors.ink2)),
                  const SizedBox(height: 6),
                  Text('Add what you take so your intake totals include '
                       'tablets and capsules, not just food.',
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
                      child: Text('Add supplement',
                        style: BMHText.labelMd.copyWith(
                          color: BMHColors.bg0,
                          fontWeight: FontWeight.w600)))),
                ]))
            else ...[
              Text(
                '$taken of ${items.length} taken '
                '${_isToday ? "today" : "on $_dayLabel"}. Daily ones count '
                'on their own — untick a day you missed.',
                style: BMHText.bodySm.copyWith(
                  fontSize: 10.5, color: BMHColors.inkMute, height: 1.45)),
              const SizedBox(height: 14),
              for (final s in items) ...[
                _SuppRow(
                  supp: s,
                  taken: _svc.isTaken(_day, s.id),
                  onToggle: (v) => _svc.setTaken(_day, s.id, v),
                  onEdit: () => _sheet(existing: s),
                  onDelete: () => _confirmDelete(s)),
                const SizedBox(height: 10),
              ],
            ],
          ])),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _SuppRow extends StatelessWidget {
  final Supplement supp;
  final bool taken;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SuppRow({
    required this.supp,
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
      child: Row(children: [
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
              Flexible(child: Text(supp.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BMHText.labelLg.copyWith(color: BMHColors.ink))),
              if (supp.dose.isNotEmpty) ...[
                const SizedBox(width: 7),
                Text(supp.dose,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 8.5, color: BMHColors.inkMute)),
              ],
              if (supp.daily) ...[
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
            const SizedBox(height: 3),
            Text(
              supp.summary +
                (supp.withMeal != null
                  ? ' · with ${supp.withMeal!.toLowerCase()}' : ''),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.inkDim, height: 1.35)),
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
      ]));
  }
}
