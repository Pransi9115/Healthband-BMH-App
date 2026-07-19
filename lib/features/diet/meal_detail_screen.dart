// ─────────────────────────────────────────────────────────
//  DIET — MEAL DETAIL
//  Foods in the meal · macros · micronutrients as % daily value
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../../core/diet/diet_models.dart';
import '../../core/diet/diet_service.dart';
import 'micronutrients_screen.dart';
import 'log_meal_screen.dart';

class MealDetailScreen extends StatefulWidget {
  final DateTime day;
  final String mealId;

  const MealDetailScreen({
    super.key,
    required this.day,
    required this.mealId,
  });

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  final _diet = DietService.instance;
  static const _accent = BMHColors.sMetabolic;

  @override
  void initState() {
    super.initState();
    _diet.addListener(_onDiet);
  }

  void _onDiet() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _diet.removeListener(_onDiet);
    super.dispose();
  }

  Meal? get _meal => _diet.mealById(widget.day, widget.mealId);

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMHColors.bg3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          side: const BorderSide(color: BMHColors.line)),
        title: Text('Delete this meal?', style: BMHText.heading2),
        content: Text(
          'This removes it from the day\'s totals. It cannot be undone.',
          style: BMHText.bodySm.copyWith(color: BMHColors.inkDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
              style: BMHText.labelLg.copyWith(color: BMHColors.inkMute))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
              style: BMHText.labelLg.copyWith(color: BMHColors.danger))),
        ]));
    if (ok == true && mounted) {
      await _diet.deleteMeal(widget.day, widget.mealId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = _meal;
    if (meal == null) {
      return Scaffold(
        backgroundColor: BMHColors.bg0,
        bottomNavigationBar: const BMHGlobalNav(activeIndex: 0),
        body: SafeArea(child: Center(child: Text('Meal not found',
          style: BMHText.bodyMd.copyWith(color: BMHColors.inkDim)))));
    }

    final micros = meal.micros;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 0),
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
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BMHEyebrow(meal.type.upper),
                  Text('Eaten ${meal.timeLabel}',
                    style: BMHText.heading1.copyWith(fontSize: 20)),
                ])),
              BMHIconButton(
                onTap: _confirmDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                  color: BMHColors.inkDim, size: 18)),
            ])),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // ── HERO ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight, end: Alignment.bottomLeft,
                      colors: [_accent.withOpacity(0.12), BMHColors.bg3]),
                    borderRadius: BorderRadius.circular(BMHRadius.xl),
                    border: Border.all(color: _accent.withOpacity(0.35))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meal.title, style: BMHText.heading2),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _Chip('${meal.kcal.round()} kcal', _accent),
                        _Chip('Protein ${meal.proteinG.round()}g',
                          BMHColors.sCardio),
                        _Chip('Carbs ${meal.carbsG.round()}g',
                          BMHColors.sOxygen),
                        _Chip('Fat ${meal.fatG.round()}g', _accent),
                        _Chip('Sugars ${meal.sugarsG.round()}g',
                          BMHColors.sDna),
                      ]),
                    ])),

                const SizedBox(height: 22),
                Text('FOODS',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 10, letterSpacing: 1.6,
                    color: BMHColors.inkDim)),
                const SizedBox(height: 10),

                if (meal.foods.isEmpty)
                  Text('No foods recorded',
                    style: BMHText.bodySm.copyWith(color: BMHColors.inkMute))
                else
                  Container(
                    decoration: BoxDecoration(
                      color: BMHColors.surface,
                      borderRadius: BorderRadius.circular(BMHRadius.lg),
                      border: Border.all(color: BMHColors.line)),
                    child: Column(children: [
                      for (int i = 0; i < meal.foods.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: BMHColors.line),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                          child: Row(children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(meal.foods[i].name,
                                  style: BMHText.labelLg.copyWith(
                                    color: BMHColors.ink)),
                                const SizedBox(height: 2),
                                Text(meal.foods[i].portion,
                                  style: BMHText.monoSm.copyWith(
                                    fontSize: 10,
                                    color: BMHColors.inkMute)),
                              ])),
                            Text('${meal.foods[i].kcal.round()} kcal',
                              style: BMHText.monoSm.copyWith(
                                fontSize: 11, color: _accent)),
                          ])),
                      ],
                    ])),

                const SizedBox(height: 22),
                Text('MICRONUTRIENTS · % DAILY VALUE',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 10, letterSpacing: 1.6,
                    color: BMHColors.inkDim)),
                const SizedBox(height: 12),

                if (micros.isEmpty)
                  Text('No micronutrient data for this meal',
                    style: BMHText.bodySm.copyWith(color: BMHColors.inkMute))
                else
                  ...(() {
                    final entries = micros.entries.toList()
                      ..sort((a, b) {
                        final pa = _pct(a.key, a.value);
                        final pb = _pct(b.key, b.value);
                        return pb.compareTo(pa);
                      });
                    return entries.map((e) {
                      final pct = _pct(e.key, e.value);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MicroRow(
                          name: e.key,
                          percent: pct,
                          amount: _amountLabel(e.key, e.value)));
                    }).toList();
                  })(),

                const SizedBox(height: 18),

                // ── INSIGHT ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BMHColors.cyanFaint,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: BMHColors.lineBright)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                        color: BMHColors.cyan, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_insight(meal),
                        style: BMHText.bodySm.copyWith(
                          color: BMHColors.ink2, height: 1.45))),
                    ])),

                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => MicronutrientsScreen(day: widget.day))),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: BMHColors.surface,
                      borderRadius: BorderRadius.circular(BMHRadius.full),
                      border: Border.all(color: BMHColors.line)),
                    child: Text('View full micronutrient dashboard',
                      textAlign: TextAlign.center,
                      style: BMHText.labelLg.copyWith(color: _accent)))),

                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => LogMealScreen(
                        day: widget.day,
                        presetType: meal.type,
                        existingMeal: meal)));
                    if (mounted) setState(() {});
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: BMHColors.surface,
                      borderRadius: BorderRadius.circular(BMHRadius.full),
                      border: Border.all(color: BMHColors.line)),
                    child: Text('Edit this meal',
                      textAlign: TextAlign.center,
                      style: BMHText.labelLg.copyWith(
                        color: BMHColors.ink2)))),

                const SizedBox(height: 120),
              ]))),
        ])),
      ]),
    );
  }

  static double _pct(String name, double amount) {
    final n = Micronutrient.byName(name);
    if (n == null || n.rda <= 0) return 0;
    return amount / n.rda * 100;
  }

  static String _amountLabel(String name, double amount) {
    final n = Micronutrient.byName(name);
    if (n == null) return amount.toStringAsFixed(1);
    final v = amount >= 10
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(1);
    return '$v ${n.unit}';
  }

  static String _insight(Meal meal) {
    final micros = meal.micros;
    final lows = <String>[];
    micros.forEach((k, v) {
      if (_pct(k, v) < 40) lows.add(k);
    });

    if (meal.proteinG >= 30 && lows.isEmpty) {
      return 'Strong protein content and a good micronutrient spread. '
             'This is a well-balanced meal.';
    }
    if (lows.isNotEmpty) {
      final first = lows.first;
      final suggestion = switch (first) {
        'Magnesium'   => 'add pumpkin seeds or spinach',
        'Iron'        => 'add lentils, spinach or lean red meat',
        'Vitamin C'   => 'add citrus, capsicum or broccoli',
        'Vitamin D'   => 'add eggs or oily fish',
        'Calcium'     => 'add yogurt, paneer or almonds',
        'Potassium'   => 'add banana, potato or beans',
        'Omega-3'     => 'add salmon, walnuts or flaxseed',
        _             => 'vary the vegetables alongside it',
      };
      return '$first is running low in this meal — $suggestion to '
             'lift it toward target.';
    }
    if (meal.proteinG < 15) {
      return 'Protein is on the lower side here. Pairing this with a '
             'protein source would balance the meal.';
    }
    return 'A reasonably balanced meal. Keep an eye on the daily '
           'micronutrient dashboard for the full picture.';
  }
}

// ─────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(BMHRadius.full),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Text(text,
      style: BMHText.monoSm.copyWith(fontSize: 10, color: color)));
}

// ─────────────────────────────────────────────────────────
class _MicroRow extends StatelessWidget {
  final String name;
  final double percent;
  final String amount;

  const _MicroRow({
    required this.name,
    required this.percent,
    required this.amount,
  });

  Color get _c {
    if (percent >= 100) return BMHColors.sGut;
    if (percent >= 70)  return BMHColors.sGut;
    if (percent >= 50)  return BMHColors.warn;
    return BMHColors.danger;
  }

  String get _tag {
    if (percent >= 100) return 'high';
    if (percent >= 70)  return 'optimal';
    if (percent >= 50)  return 'fair';
    return 'low';
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: Text(name,
          style: BMHText.labelMd.copyWith(color: BMHColors.ink2))),
        Text('${percent.round()}% · $_tag',
          style: BMHText.monoSm.copyWith(fontSize: 10, color: _c)),
        const SizedBox(width: 8),
        Text(amount,
          style: BMHText.monoSm.copyWith(
            fontSize: 10, color: BMHColors.inkMute)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(BMHRadius.full),
        child: LinearProgressIndicator(
          value: (percent / 100).clamp(0.0, 1.0),
          minHeight: 5,
          backgroundColor: BMHColors.bg4,
          valueColor: AlwaysStoppedAnimation(_c))),
    ]);
  }
}
