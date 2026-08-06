// ─────────────────────────────────────────────────────────
//  GUT REPORT — EatIQ IgG PROFILE
//
//  Same reading pattern as the blood and DNA reports.
//
//  THE THING THIS SCREEN HAS TO GET RIGHT
//  Food-specific IgG rises with exposure. A high reading against
//  cow's milk usually means the person drinks milk — not that milk is
//  hurting them. Allergy bodies are explicit that these panels should
//  not drive elimination diets on their own.
//
//  In an app that also plans meals, the failure mode is obvious and
//  serious: a patient sees red dots against thirteen food groups,
//  removes all of them, and ends up with a diet narrower and poorer
//  than the one they started with. So this screen never says "avoid",
//  never says "intolerant", leads with what the numbers actually mean,
//  and points at a supervised trial rather than a ban list.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/gut_report_service.dart';

const _accent = BMHColors.sGut;

Color igGColor(IgGLevel l) => switch (l) {
      IgGLevel.low => BMHColors.rangeIn,
      IgGLevel.intermediate => BMHColors.rangeEdge,
      IgGLevel.high => BMHColors.rangeOut,
    };

IconData igGIcon(String key) => switch (key) {
      'milk' => Icons.egg_outlined,
      'meat' => Icons.kebab_dining_outlined,
      'fish' => Icons.set_meal_outlined,
      'cereal' => Icons.grass_outlined,
      'nuts' => Icons.spa_outlined,
      'legume' => Icons.eco_outlined,
      'fruit' => Icons.apple_outlined,
      'vegetable' => Icons.local_florist_outlined,
      'spice' => Icons.local_fire_department_outlined,
      'mushroom' => Icons.forest_outlined,
      'novel' => Icons.science_outlined,
      'coffee' => Icons.coffee_outlined,
      _ => Icons.category_outlined,
    };

class GutReportScreen extends StatelessWidget {
  final GutReport report;
  const GutReportScreen({super.key, required this.report});

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
                  const BMHEyebrow('GUT PANEL'),
                  Text('IgG food profile',
                    style: BMHText.heading1.copyWith(fontSize: 24)),
                ])),
            ])),

          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BMHSpacing.screenH, 6, BMHSpacing.screenH, 60),
            children: [
              _masthead(),

              const SizedBox(height: 18),
              _readFirst(),

              const SizedBox(height: 18),
              BMHSectionTitle('Across the panel'),
              const SizedBox(height: 6),
              Text(
                'One row per food group, coloured by the highest single '
                'reading inside it.',
                style: BMHText.bodySm.copyWith(
                  fontSize: 11, color: BMHColors.inkMute, height: 1.45)),
              const SizedBox(height: 12),
              for (final c in report.categories)
                _CategoryRow(category: c),

              const SizedBox(height: 14),
              _legend(),

              if (report.elevated.isNotEmpty) ...[
                const SizedBox(height: 24),
                BMHSectionTitle('Highest readings'),
                const SizedBox(height: 6),
                Text(
                  'The foods with most IgG measured against them. Worth '
                  'raising with your care team — not worth cutting out '
                  'on your own.',
                  style: BMHText.bodySm.copyWith(
                    fontSize: 11, color: BMHColors.inkMute, height: 1.45)),
                const SizedBox(height: 12),
                for (final i in report.elevated.take(12))
                  _ItemRow(item: i, showBar: true),
              ],

              for (final c in report.categories)
                if (c.items.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _accent.withOpacity(0.3))),
                      child: Icon(igGIcon(c.icon),
                        color: _accent, size: 17)),
                    const SizedBox(width: 11),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                          style: BMHText.heading2.copyWith(
                            fontSize: 18, color: BMHColors.ink)),
                        const SizedBox(height: 2),
                        Text('${c.items.length} tested · '
                             '${c.elevated.length} above the low band',
                          style: BMHText.monoSm.copyWith(
                            fontSize: 9, color: BMHColors.inkMute)),
                      ])),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: BMHColors.surface,
                      borderRadius: BorderRadius.circular(BMHRadius.lg),
                      border: Border.all(color: BMHColors.line)),
                    child: Column(children: [
                      for (var i = 0; i < c.items.length; i++) ...[
                        _ItemRow(item: c.items[i], inset: true),
                        if (i < c.items.length - 1)
                          Divider(height: 1,
                            color: BMHColors.line.withOpacity(0.4)),
                      ],
                    ])),
                ],

              if (report.hasPendingDetail) ...[
                const SizedBox(height: 22),
                _pending(),
              ],

              const SizedBox(height: 20),
              _disclaimer(),
            ])),
        ])),
      ]));
  }

  Widget _masthead() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.lg),
      border: Border.all(color: BMHColors.line)),
    child: Column(children: [
      Row(children: [
        Expanded(child: _kv('NAME', report.patientName)),
        Expanded(child: _kv('DATE OF BIRTH', report.dateOfBirth)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _kv('ANALYSED',
          '${report.analysedOn.day} '
          '${_month(report.analysedOn.month)} '
          '${report.analysedOn.year}')),
        Expanded(child: _kv('ANTIGENS TESTED',
          '${report.testedAntigens}')),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _kv('SAMPLE', report.sampleCode)),
        Expanded(child: _kv('METHOD', report.method)),
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

  Widget _readFirst() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _accent.withOpacity(0.07),
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: _accent.withOpacity(0.28))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded,
            color: _accent, size: 15),
          const SizedBox(width: 9),
          Text('How to read this',
            style: BMHText.labelLg.copyWith(
              fontSize: 14, color: BMHColors.ink)),
        ]),
        const SizedBox(height: 10),
        Text(
          'IgG antibodies against a food generally rise with how often '
          'you eat it, so a high reading is a record of exposure rather '
          'than proof of harm. This is not an allergy test, and a high '
          'number on its own is not a reason to stop eating something.',
          style: BMHText.bodySm.copyWith(
            fontSize: 11.5, color: BMHColors.ink2, height: 1.5)),
        const SizedBox(height: 9),
        Text(
          'Where these results earn their keep is as a shortlist. If you '
          'have symptoms, your care team can use the highest readings to '
          'decide what to trial removing, and for how long, with a '
          'proper reintroduction afterwards. Cutting out foods on the '
          'strength of this page alone tends to narrow a diet without '
          'settling anything.',
          style: BMHText.bodySm.copyWith(
            fontSize: 11.5, color: BMHColors.ink2, height: 1.5)),
      ]));

  Widget _legend() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: BMHColors.bg2,
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.line)),
    child: Column(children: [
      for (final l in IgGLevel.values) ...[
        if (l != IgGLevel.values.first) const SizedBox(height: 8),
        Row(children: [
          Row(children: [
            for (var i = 0; i < l.dots; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Container(width: 7, height: 7,
                decoration: BoxDecoration(
                  color: igGColor(l), shape: BoxShape.circle)),
            ],
          ]),
          const SizedBox(width: 11),
          Expanded(child: Text('${l.label} IgG level',
            style: BMHText.bodySm.copyWith(
              fontSize: 11, color: BMHColors.ink2))),
          Text(l.rangeLabel,
            style: BMHText.monoSm.copyWith(
              fontSize: 9, color: BMHColors.inkMute)),
        ]),
      ],
    ]));

  Widget _pending() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: BMHColors.warn.withOpacity(0.08),
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.warn.withOpacity(0.3))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.pending_outlined, color: BMHColors.warn, size: 15),
      const SizedBox(width: 10),
      Expanded(child: Text(
        'Item-level results are shown for '
        '${report.reportedCount} of ${report.testedAntigens} antigens. '
        'The remaining food groups are summarised above; their '
        'individual readings were not included in the file supplied.',
        style: BMHText.bodySm.copyWith(
          fontSize: 11, color: BMHColors.ink2, height: 1.45))),
    ]));

  Widget _disclaimer() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: BMHColors.bg2,
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.line)),
    child: Text(
      'These results are for information and wellbeing purposes and do '
      'not constitute a medical diagnosis. Food-specific IgG testing is '
      'not a test for allergy or intolerance, and results should not be '
      'used on their own to remove foods from a diet. Please discuss '
      'anything shown here with a qualified healthcare professional '
      'before changing what you eat.',
      style: BMHText.bodySm.copyWith(
        fontSize: 10.5, color: BMHColors.inkMute, height: 1.5)));

  static String _month(int m) => const [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'][m - 1];
}

// ─────────────────────────────────────────────────────────
class _CategoryRow extends StatelessWidget {
  final IgGCategory category;
  const _CategoryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final c = igGColor(category.highest);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: BMHColors.line)),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: c.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: c.withOpacity(0.28))),
          child: Icon(igGIcon(category.icon), color: c, size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BMHText.bodySm.copyWith(
                fontSize: 12.5, color: BMHColors.ink)),
            const SizedBox(height: 2),
            Text(category.detailPending
                ? 'Summary only'
                : '${category.items.length} foods tested',
              style: BMHText.monoSm.copyWith(
                fontSize: 8.5, color: BMHColors.inkMute)),
          ])),
        Row(children: [
          for (var i = 0; i < category.highest.dots; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Container(width: 8, height: 8,
              decoration: BoxDecoration(
                color: c, shape: BoxShape.circle)),
          ],
        ]),
      ]));
  }
}

// ─────────────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final IgGItem item;
  final bool showBar;
  final bool inset;

  const _ItemRow({
    required this.item,
    this.showBar = false,
    this.inset = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = igGColor(item.level);

    final row = Row(children: [
      Container(width: 7, height: 7,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 11),
      Expanded(child: Text(item.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: BMHText.bodySm.copyWith(
          fontSize: 12,
          color: item.level == IgGLevel.low
            ? BMHColors.ink2 : BMHColors.ink))),
      const SizedBox(width: 10),
      Text(item.valueLabel,
        style: BMHText.monoSm.copyWith(
          fontSize: 10.5,
          color: item.level == IgGLevel.low ? BMHColors.inkDim : c)),
      const SizedBox(width: 4),
      Text('µg/ml',
        style: BMHText.monoSm.copyWith(
          fontSize: 8.5, color: BMHColors.inkMute)),
    ]);

    if (inset) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: row);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: c.withOpacity(0.25))),
      child: Column(children: [
        row,
        if (showBar) ...[
          const SizedBox(height: 9),
          LayoutBuilder(builder: (ctx, box) {
            final w = box.maxWidth;
            return SizedBox(height: 4, child: Stack(children: [
              Positioned(
                left: 0, right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: BMHColors.bg4,
                    borderRadius:
                      BorderRadius.circular(BMHRadius.full)))),
              Positioned(
                left: 0,
                width: (item.barPosition * w).clamp(0.0, w),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius:
                      BorderRadius.circular(BMHRadius.full)))),
            ]));
          }),
        ],
      ]));
  }
}
