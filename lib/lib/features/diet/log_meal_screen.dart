// ─────────────────────────────────────────────────────────
//  DIET — LOG A MEAL
//  Meal type · time · food search · recent foods · save
//  Writes through DietService, so entries persist.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/diet/diet_models.dart';
import '../../core/diet/diet_service.dart';

class LogMealScreen extends StatefulWidget {
  final DateTime day;
  final MealType? presetType;

  /// When supplied the screen edits that meal instead of creating one.
  final Meal? existingMeal;

  const LogMealScreen({
    super.key,
    required this.day,
    this.presetType,
    this.existingMeal,
  });

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  final _diet = DietService.instance;
  static const _accent = BMHColors.sMetabolic;

  late MealType _type;
  late TimeOfDay _time;
  final List<FoodItem> _selected = [];
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _saving = false;

  bool get _isEdit => widget.existingMeal != null && !widget.existingMeal!.planned;

  @override
  void initState() {
    super.initState();
    final ex = widget.existingMeal;
    _type = ex?.type ?? widget.presetType ?? _guessType();
    _time = ex != null
        ? TimeOfDay(hour: ex.time.hour, minute: ex.time.minute)
        : TimeOfDay.now();
    if (ex != null) _selected.addAll(ex.foods);
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static MealType _guessType() {
    final h = DateTime.now().hour;
    if (h < 11) return MealType.breakfast;
    if (h < 16) return MealType.lunch;
    if (h < 21) return MealType.dinner;
    return MealType.snack;
  }

  double get _kcal    => _selected.fold(0.0, (s, f) => s + f.kcal);
  double get _protein => _selected.fold(0.0, (s, f) => s + f.proteinG);
  double get _carbs   => _selected.fold(0.0, (s, f) => s + f.carbsG);
  double get _fat     => _selected.fold(0.0, (s, f) => s + f.fatG);

  void _toggle(FoodItem f) {
    setState(() {
      final i = _selected.indexWhere((e) => e.id == f.id);
      if (i >= 0) {
        _selected.removeAt(i);
      } else {
        _selected.add(f);
      }
    });
  }

  bool _isSelected(FoodItem f) => _selected.any((e) => e.id == f.id);

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: BMHColors.bg3,
            onSurface: BMHColors.ink)),
        child: child!));
    if (t != null) setState(() => _time = t);
  }

  String _autoTitle() {
    if (_selected.isEmpty) return _type.label;
    if (_selected.length == 1) return _selected.first.name;
    if (_selected.length == 2) {
      return '${_selected[0].name} & ${_selected[1].name}';
    }
    return '${_selected[0].name}, ${_selected[1].name} '
           '+${_selected.length - 2} more';
  }

  Future<void> _save() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);

    final when = DateTime(
      widget.day.year, widget.day.month, widget.day.day,
      _time.hour, _time.minute);

    final ex = widget.existingMeal;

    if (ex != null) {
      // Editing, or converting a planned meal into an eaten one.
      await _diet.updateMeal(widget.day, ex.copyWith(
        type: _type,
        time: when,
        title: _autoTitle(),
        foods: List.of(_selected),
        planned: false));
    } else {
      await _diet.addMeal(widget.day, Meal(
        id: 'meal_${DateTime.now().microsecondsSinceEpoch}',
        type: _type,
        time: when,
        title: _autoTitle(),
        foods: List.of(_selected)));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Meal saved',
        style: BMHText.monoSm.copyWith(color: BMHColors.bg0)),
      backgroundColor: _accent,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BMHRadius.full))));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final results = _query.trim().isEmpty
        ? _diet.recentFoods
        : FoodLibrary.search(_query);
    final listTitle =
        _query.trim().isEmpty ? 'RECENT FOODS' : 'SEARCH RESULTS';

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: Stack(children: [
        Positioned(top: -150, left: -100,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _accent.withOpacity(0.08), Colors.transparent])))),
        SafeArea(bottom: false, child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH, vertical: 8),
            child: Row(children: [
              BMHIconButton(
                onTap: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                  color: BMHColors.ink, size: 16)),
              const SizedBox(width: 14),
              Expanded(child: Text(
                _isEdit ? 'Edit meal' : 'Log a meal',
                style: BMHText.heading1)),
            ])),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // ── MEAL TYPE ───────────────────────
                Text('MEAL TYPE',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 10, letterSpacing: 1.6,
                    color: BMHColors.inkDim)),
                const SizedBox(height: 10),
                Row(children: [
                  for (final t in MealType.values) ...[
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _type = t),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _type == t
                            ? _accent.withOpacity(0.15) : BMHColors.surface,
                          borderRadius:
                            BorderRadius.circular(BMHRadius.full),
                          border: Border.all(
                            color: _type == t ? _accent : BMHColors.line)),
                        child: Text(t.label,
                          textAlign: TextAlign.center,
                          style: BMHText.monoSm.copyWith(
                            fontSize: 11,
                            color: _type == t
                              ? _accent : BMHColors.inkDim))))),
                    if (t != MealType.values.last) const SizedBox(width: 8),
                  ],
                ]),

                const SizedBox(height: 20),

                // ── TIME ────────────────────────────
                Text('WHEN DID YOU EAT?',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 10, letterSpacing: 1.6,
                    color: BMHColors.inkDim)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: _pickTime,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: BMHColors.surface,
                        borderRadius: BorderRadius.circular(BMHRadius.md),
                        border: Border.all(color: BMHColors.line)),
                      child: Row(children: [
                        const Icon(Icons.schedule_rounded,
                          color: BMHColors.inkDim, size: 16),
                        const SizedBox(width: 8),
                        Text(_time.format(context),
                          style: BMHText.labelLg.copyWith(
                            color: BMHColors.ink)),
                      ])))),
                  const SizedBox(width: 10),
                  Expanded(child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: BMHColors.surface,
                      borderRadius: BorderRadius.circular(BMHRadius.md),
                      border: Border.all(color: BMHColors.line)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                        color: BMHColors.inkDim, size: 14),
                      const SizedBox(width: 8),
                      Text(_dayLabel(),
                        style: BMHText.labelLg.copyWith(
                          color: BMHColors.ink)),
                    ]))),
                ]),

                const SizedBox(height: 20),

                // ── SEARCH ──────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.md),
                    border: Border.all(color: BMHColors.line)),
                  child: Row(children: [
                    const Icon(Icons.search_rounded,
                      color: BMHColors.inkDim, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: _searchCtrl,
                      style: BMHText.bodyMd.copyWith(color: BMHColors.ink),
                      cursorColor: _accent,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                        hintText: 'Search foods to add…',
                        hintStyle: BMHText.bodyMd.copyWith(
                          color: BMHColors.inkMute)))),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: const Icon(Icons.close_rounded,
                          color: BMHColors.inkDim, size: 16)),
                  ])),

                const SizedBox(height: 20),

                Text(listTitle,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 10, letterSpacing: 1.6,
                    color: BMHColors.inkDim)),
                const SizedBox(height: 10),

                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No foods found',
                      style: BMHText.bodySm.copyWith(
                        color: BMHColors.inkMute))))
                else
                  ...results.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FoodRow(
                      food: f,
                      selected: _isSelected(f),
                      accent: _accent,
                      onTap: () => _toggle(f)))),

                const SizedBox(height: 140),
              ]))),
        ])),

        // ── STICKY SUMMARY + SAVE ─────────────────
        Positioned(left: 0, right: 0, bottom: 0, child: Container(
          padding: EdgeInsets.only(
            left: BMHSpacing.screenH, right: BMHSpacing.screenH,
            top: 14,
            bottom: MediaQuery.of(context).padding.bottom + 14),
          decoration: const BoxDecoration(
            color: BMHColors.bg1,
            border: Border(top: BorderSide(color: BMHColors.line))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(
                '${_selected.length} '
                '${_selected.length == 1 ? "item" : "items"} selected',
                style: BMHText.monoSm.copyWith(
                  fontSize: 11, color: BMHColors.inkDim)),
              const Spacer(),
              Text(
                _selected.isEmpty
                  ? '—'
                  : '${_kcal.round()} kcal · '
                    'P${_protein.round()} '
                    'C${_carbs.round()} '
                    'F${_fat.round()}',
                style: BMHText.monoSm.copyWith(
                  fontSize: 11, color: _accent)),
            ]),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _selected.isEmpty ? null : _save,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _selected.isEmpty ? BMHColors.bg4 : _accent,
                  borderRadius: BorderRadius.circular(BMHRadius.full),
                  boxShadow: _selected.isEmpty ? null : [BoxShadow(
                    color: _accent.withOpacity(0.35),
                    blurRadius: 22, offset: const Offset(0, 6))]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded,
                      color: _selected.isEmpty
                        ? BMHColors.inkMute : BMHColors.bg0, size: 20),
                    const SizedBox(width: 8),
                    Text(_saving ? 'Saving…' : 'Save meal',
                      style: BMHText.labelLg.copyWith(
                        color: _selected.isEmpty
                          ? BMHColors.inkMute : BMHColors.bg0,
                        fontWeight: FontWeight.w600)),
                  ]))),
          ]))),
      ]),
    );
  }

  String _dayLabel() {
    final n = DateTime.now();
    final d = widget.day;
    if (d.year == n.year && d.month == n.month && d.day == n.day) {
      return 'Today';
    }
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}

// ─────────────────────────────────────────────────────────
class _FoodRow extends StatelessWidget {
  final FoodItem food;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _FoodRow({
    required this.food,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.10) : BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(
            color: selected ? accent.withOpacity(0.55) : BMHColors.line)),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(food.name,
                style: BMHText.labelLg.copyWith(color: BMHColors.ink)),
              const SizedBox(height: 3),
              Text(
                '${food.portion} · ${food.kcal.round()} kcal · '
                '${food.macroSummary}',
                style: BMHText.monoSm.copyWith(
                  fontSize: 10, color: BMHColors.inkMute)),
            ])),
          const SizedBox(width: 10),
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? accent : BMHColors.inkMute, width: 1.5)),
            child: Icon(
              selected ? Icons.check_rounded : Icons.add_rounded,
              size: 15,
              color: selected ? BMHColors.bg0 : BMHColors.inkMute)),
        ])));
  }
}
