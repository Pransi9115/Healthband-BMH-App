// ─────────────────────────────────────────────────────────
//  BIOMEDICAL DIET — main screen
//  Calorie summary · macro bars · micronutrient strip · meals
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../../core/diet/diet_models.dart';
import '../../core/diet/diet_service.dart';
import 'meal_detail_screen.dart';
import 'micronutrients_screen.dart';
import 'log_meal_screen.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});
  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  final _diet = DietService.instance;
  DateTime _day = DateTime.now();

  static const _accent = BMHColors.sMetabolic; // amber, matches home card

  @override
  void initState() {
    super.initState();
    _diet.addListener(_onDiet);
    _diet.init().then((_) => _diet.ensureDay(_day));
  }

  void _onDiet() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _diet.removeListener(_onDiet);
    super.dispose();
  }

  bool get _isToday {
    final n = DateTime.now();
    return _day.year == n.year && _day.month == n.month && _day.day == n.day;
  }

  void _shiftDay(int delta) {
    final next = _day.add(Duration(days: delta));
    if (next.isAfter(DateTime.now().add(const Duration(days: 1)))) return;
    setState(() => _day = next);
    _diet.ensureDay(next);
  }

  /// Tap the date label → full calendar, jump to any day.
  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: BMHColors.bg3,
            onSurface: BMHColors.ink)),
        child: child!));
    if (d != null) {
      setState(() => _day = DateTime(d.year, d.month, d.day));
      _diet.ensureDay(_day);
    }
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

  Future<void> _openLog({MealType? preset, Meal? existing}) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => LogMealScreen(
        day: _day,
        presetType: preset,
        existingMeal: existing,
      )));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final meals   = _diet.mealsFor(_day);
    final targets = _diet.targets;
    final kcal    = _diet.kcalFor(_day);

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 0),
      body: Stack(children: [
        Positioned(top: -160, right: -110,
          child: Container(width: 420, height: 420,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _accent.withOpacity(0.08), Colors.transparent])))),
        SafeArea(bottom: false, child: Column(children: [
          // ── HEADER ────────────────────────────────
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
                  const BMHEyebrow('Module'),
                  Text('BioMedical Diet', style: BMHText.heading1),
                ])),
              BMHIconButton(
                onTap: () => _openLog(),
                icon: const Icon(Icons.add_rounded,
                  color: BMHColors.ink, size: 18)),
            ])),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── DATE STRIP ──────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.full),
                    border: Border.all(color: BMHColors.line)),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => _shiftDay(-1),
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(Icons.chevron_left_rounded,
                        color: BMHColors.inkDim, size: 20)),
                    Expanded(child: GestureDetector(
                      onTap: _pickDay,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                            color: BMHColors.inkDim, size: 13),
                          const SizedBox(width: 7),
                          Text(_dayLabel,
                            style: BMHText.labelLg.copyWith(
                              color: BMHColors.ink)),
                        ]))),
                    GestureDetector(
                      onTap: _isToday ? null : () => _shiftDay(1),
                      behavior: HitTestBehavior.opaque,
                      child: Icon(Icons.chevron_right_rounded,
                        color: _isToday
                          ? BMHColors.inkFaint : BMHColors.inkDim, size: 20)),
                  ])),

                const SizedBox(height: 16),

                // ── CALORIE + MACRO CARD ────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight, end: Alignment.bottomLeft,
                      colors: [_accent.withOpacity(0.12), BMHColors.bg3]),
                    borderRadius: BorderRadius.circular(BMHRadius.xl),
                    border: Border.all(color: _accent.withOpacity(0.35))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(kcal.round().toString(),
                            style: BMHText.displayXl.copyWith(
                              fontSize: 46, height: 1,
                              fontFamily: 'Fraunces', color: _accent)),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, left: 8),
                            child: Text(
                              '/ ${targets.kcal.round()} kcal',
                              style: BMHText.monoMd.copyWith(
                                color: BMHColors.inkMute))),
                          const Spacer(),
                          BMHPill(
                            kcal <= targets.kcal ? 'On track' : 'Over',
                            type: kcal <= targets.kcal
                              ? BMHPillType.success : BMHPillType.warn),
                        ]),
                      const SizedBox(height: 18),
                      _MacroBar(
                        label: 'Protein',
                        value: _diet.proteinFor(_day),
                        target: targets.proteinG,
                        color: BMHColors.sCardio),
                      const SizedBox(height: 12),
                      _MacroBar(
                        label: 'Carbs',
                        value: _diet.carbsFor(_day),
                        target: targets.carbsG,
                        color: BMHColors.sOxygen),
                      const SizedBox(height: 12),
                      _MacroBar(
                        label: 'Fat',
                        value: _diet.fatFor(_day),
                        target: targets.fatG,
                        color: _accent),
                      const SizedBox(height: 12),
                      _MacroBar(
                        label: 'Sugars',
                        value: _diet.sugarsFor(_day),
                        target: targets.sugarsG,
                        color: BMHColors.sDna),
                    ])),

                const SizedBox(height: 16),

                // ── MICRONUTRIENT STRIP ─────────────
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => MicronutrientsScreen(day: _day))),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BMHColors.surface,
                      borderRadius: BorderRadius.circular(BMHRadius.lg),
                      border: Border.all(color: BMHColors.line)),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: Text(
                          'MICRONUTRIENTS · '
                          '${_diet.microScore(_day).round()}% OPTIMAL',
                          style: BMHText.monoSm.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: BMHColors.inkDim))),
                        Text('View all',
                          style: BMHText.monoSm.copyWith(
                            fontSize: 10, color: _accent)),
                        const Icon(Icons.chevron_right_rounded,
                          color: BMHColors.inkDim, size: 16),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        for (final n in const [
                          'Vitamin C','Vitamin D','Iron','Magnesium','Vitamin B12'
                        ])
                          Expanded(child: _MicroDot(
                            short: _shortName(n),
                            percent: _diet.microPercent(_day, n))),
                      ]),
                    ]))),

                const SizedBox(height: 22),

                Text(_isToday
                    ? "TODAY'S MEALS"
                    : 'MEALS · ${_fmtDate(_day).toUpperCase()}',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 10, letterSpacing: 1.6,
                    color: BMHColors.inkDim)),
                const SizedBox(height: 12),

                if (meals.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: BMHColors.surface,
                      borderRadius: BorderRadius.circular(BMHRadius.lg),
                      border: Border.all(color: BMHColors.line)),
                    child: Column(children: [
                      const Icon(Icons.restaurant_outlined,
                        color: BMHColors.inkMute, size: 30),
                      const SizedBox(height: 10),
                      Text('No meals logged yet',
                        style: BMHText.bodySm.copyWith(
                          color: BMHColors.inkDim)),
                    ]))
                else
                  ...meals.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MealRow(
                      meal: m,
                      accent: _accent,
                      onTap: () async {
                        if (m.planned) {
                          await _openLog(preset: m.type, existing: m);
                        } else {
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => MealDetailScreen(
                              day: _day, mealId: m.id)));
                          if (mounted) setState(() {});
                        }
                      }))),

                // ── MEAL TOTALS ─────────────────────
                if (meals.any((m) => !m.planned)) ...[
                  const SizedBox(height: 18),
                  Text('MEAL TOTALS',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 10, letterSpacing: 1.6,
                      color: BMHColors.inkDim)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: BMHColors.surface,
                      borderRadius: BorderRadius.circular(BMHRadius.lg),
                      border: Border.all(color: BMHColors.line)),
                    child: Column(children: [
                      for (final t in MealType.values)
                        if (_diet.kcalForType(_day, t) > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8),
                            child: Row(children: [
                              Expanded(child: Text(t.label,
                                style: BMHText.labelMd.copyWith(
                                  color: BMHColors.ink2))),
                              Text(
                                '${_diet.kcalForType(_day, t).round()} kcal',
                                style: BMHText.monoSm.copyWith(
                                  fontSize: 11,
                                  color: BMHColors.inkDim)),
                            ])),
                      const Divider(
                        color: BMHColors.line, height: 14),
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 4, bottom: 10),
                        child: Row(children: [
                          Expanded(child: Text('Day total',
                            style: BMHText.labelLg.copyWith(
                              color: BMHColors.ink,
                              fontWeight: FontWeight.w600))),
                          Text('${kcal.round()} kcal',
                            style: BMHText.monoMd.copyWith(
                              color: _accent,
                              fontWeight: FontWeight.w600)),
                        ])),
                    ])),
                ],

                const SizedBox(height: 18),

                // ── LOG A MEAL ──────────────────────
                GestureDetector(
                  onTap: () => _openLog(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(BMHRadius.full),
                      boxShadow: [BoxShadow(
                        color: _accent.withOpacity(0.35),
                        blurRadius: 22, offset: const Offset(0, 6))]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_rounded,
                          color: BMHColors.bg0, size: 20),
                        const SizedBox(width: 8),
                        Text('Log a meal',
                          style: BMHText.labelLg.copyWith(
                            color: BMHColors.bg0,
                            fontWeight: FontWeight.w600)),
                      ]))),

                const SizedBox(height: 120),
              ]))),
        ])),
      ]),
    );
  }

  static String _shortName(String n) => switch (n) {
        'Vitamin C'   => 'Vit C',
        'Vitamin D'   => 'Vit D',
        'Vitamin B12' => 'B12',
        'Magnesium'   => 'Mag',
        _             => n,
      };
}

// ─────────────────────────────────────────────────────────
class _MacroBar extends StatelessWidget {
  final String label;
  final double value, target;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final over = value > target;
    return Column(children: [
      Row(children: [
        Expanded(child: Text(label,
          style: BMHText.labelMd.copyWith(color: BMHColors.ink2))),
        Text('${value.round()} / ${target.round()}g',
          style: BMHText.monoSm.copyWith(
            fontSize: 11,
            color: over ? BMHColors.warn : BMHColors.inkDim)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(BMHRadius.full),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 6,
          backgroundColor: BMHColors.bg4,
          valueColor: AlwaysStoppedAnimation(
            over ? BMHColors.warn : color))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
class _MicroDot extends StatelessWidget {
  final String short;
  final double percent;

  const _MicroDot({required this.short, required this.percent});

  Color get _c {
    if (percent >= 70) return BMHColors.sGut;
    if (percent >= 50) return BMHColors.warn;
    return BMHColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final p = (percent / 100).clamp(0.0, 1.0);
    return Column(children: [
      SizedBox(width: 38, height: 38, child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: 38, height: 38, child: CircularProgressIndicator(
            value: p,
            strokeWidth: 3.5,
            backgroundColor: BMHColors.bg4,
            valueColor: AlwaysStoppedAnimation(_c))),
          Text('${percent.round()}',
            style: BMHText.monoSm.copyWith(fontSize: 9, color: _c)),
        ])),
      const SizedBox(height: 6),
      Text(short,
        style: BMHText.monoSm.copyWith(
          fontSize: 9, color: BMHColors.inkDim)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
class _MealRow extends StatelessWidget {
  final Meal meal;
  final Color accent;
  final VoidCallback onTap;

  const _MealRow({
    required this.meal,
    required this.accent,
    required this.onTap,
  });

  IconData get _icon => switch (meal.type) {
        MealType.breakfast => Icons.wb_twilight_rounded,
        MealType.lunch     => Icons.wb_sunny_outlined,
        MealType.dinner    => Icons.nightlight_round,
        MealType.snack     => Icons.cookie_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final planned = meal.planned;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(
            color: planned ? accent.withOpacity(0.35) : BMHColors.line,
            style: BorderStyle.solid)),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(planned ? 0.10 : 0.16),
              borderRadius: BorderRadius.circular(BMHRadius.md)),
            child: Icon(_icon,
              color: planned ? accent.withOpacity(0.7) : accent, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(planned
                    ? '${meal.type.upper} · TAP TO LOG'
                    : meal.type.upper,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9, letterSpacing: 1.2,
                    color: planned ? accent : BMHColors.inkDim)),
                const Spacer(),
                Text(planned ? '~ ${meal.timeLabel}' : meal.timeLabel,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9, color: BMHColors.inkMute)),
              ]),
              const SizedBox(height: 4),
              Text(meal.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BMHText.heading3.copyWith(fontSize: 14)),
              if (!planned) ...[
                const SizedBox(height: 5),
                Row(children: [
                  Text('${meal.kcal.round()} kcal',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 10, color: accent)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(meal.macroChips,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BMHText.monoSm.copyWith(
                      fontSize: 10, color: BMHColors.inkMute))),
                ]),
              ],
            ])),
          Icon(Icons.chevron_right_rounded,
            color: planned ? accent : BMHColors.inkMute, size: 18),
        ])));
  }
}

extension on Meal {
  String get macroChips =>
      'Protein ${proteinG.round()}g · Carbs ${carbsG.round()}g · '
      'Fat ${fatG.round()}g';
}
