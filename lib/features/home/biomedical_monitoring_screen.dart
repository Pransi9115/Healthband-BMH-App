import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../../core/bioresponse/blood_report_service.dart';
import '../bioresponse/biomarkers_screen.dart';
import '../bioresponse/blood_report_screen.dart';

/// ─────────────────────────────────────────────────────────
///  BIOMEDICAL MONITORING — Blood · GUT · DNA
///  Blood shows the patient's actual panel once their clinic has
///  uploaded one; GUT and DNA remain informational for now.
///  The report shown here is the same object BioResponse reads —
///  one source of truth, displayed in both places.
/// ─────────────────────────────────────────────────────────
class BiomedicalMonitoringScreen extends StatefulWidget {
  final String type; // 'Blood' | 'GUT' | 'DNA'
  const BiomedicalMonitoringScreen({super.key, required this.type});

  @override
  State<BiomedicalMonitoringScreen> createState() =>
      _BiomedicalMonitoringScreenState();
}

class _BiomedicalMonitoringScreenState
    extends State<BiomedicalMonitoringScreen> {
  final _blood = BloodReportService.instance;

  String get type => widget.type;

  @override
  void initState() {
    super.initState();
    if (type == 'Blood') {
      _blood.addListener(_refresh);
      _blood.init();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (type == 'Blood') _blood.removeListener(_refresh);
    super.dispose();
  }

  ({String title, String tagline, IconData icon, Color color,
    String intro, List<(IconData, String, String)> features}) get _cfg {
    switch (type) {
      case 'Blood':
        return (
          title: 'Blood Analysis',
          tagline: 'Your inner chemistry, decoded',
          icon: Icons.bloodtype_outlined,
          color: BMHColors.sCardio,
          intro: 'Periodic blood panels reveal what wearables cannot — '
              'from cholesterol and blood sugar control to vitamin '
              'levels and inflammation markers. Combined with your '
              'band\'s continuous data, they complete your health '
              'picture.',
          features: [
            (Icons.water_drop_outlined, 'Lipid Profile',
              'Cholesterol, HDL, LDL and triglycerides — key markers '
              'of cardiovascular health.'),
            (Icons.cake_outlined, 'Metabolic Panel',
              'HbA1c and fasting glucose to track long-term blood '
              'sugar control.'),
            (Icons.shield_outlined, 'Inflammation & Vitamins',
              'CRP, Vitamin D, B12 and iron — the hidden drivers of '
              'energy and immunity.'),
          ]);
      case 'GUT':
        return (
          title: 'GUT Microbiome',
          tagline: 'The second brain in your belly',
          icon: Icons.spa_outlined,
          color: BMHColors.sGut,
          intro: 'Your gut microbiome influences digestion, immunity, '
              'mood and even sleep. Microbiome testing maps the '
              'bacteria in your gut and turns it into practical food '
              'and lifestyle guidance.',
          features: [
            (Icons.pie_chart_outline_rounded, 'Diversity Score',
              'How rich and balanced your gut bacteria are — a core '
              'marker of gut health.'),
            (Icons.restaurant_outlined, 'Food Response',
              'Personalized guidance on fibres, probiotics and foods '
              'your gut thrives on.'),
            (Icons.mood_outlined, 'Gut–Brain Axis',
              'How your microbiome links to stress, mood and sleep '
              'quality tracked by your band.'),
          ]);
      default: // DNA
        return (
          title: 'DNA Insights',
          tagline: 'Written in your genes',
          icon: Icons.biotech_outlined,
          color: BMHColors.sDna,
          intro: 'A one-time DNA analysis reveals lifelong traits — '
              'how your body responds to nutrition, exercise and '
              'sleep. Paired with your live band data, it enables '
              'truly personalized health guidance.',
          features: [
            (Icons.fitness_center_outlined, 'Fitness Genetics',
              'Endurance vs power profile, recovery speed and injury '
              'susceptibility.'),
            (Icons.restaurant_menu_outlined, 'Nutrigenomics',
              'Caffeine, lactose and carb sensitivity — eat for your '
              'genotype.'),
            (Icons.nightlight_outlined, 'Sleep & Rhythm',
              'Chronotype and sleep-depth tendencies, matched against '
              'your real sleep data.'),
          ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _cfg;
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 0),
      body: Stack(children: [
        Positioned(top: -180, right: -120,
          child: Container(width: 480, height: 480,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                c.color.withOpacity(0.08), Colors.transparent])))),
        SafeArea(bottom: false, child: Column(children: [
          // ── HEADER with back button ─────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH, vertical: 8),
            child: Row(children: [
              BMHIconButton(onTap: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                  color: BMHColors.ink, size: 16)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BMHEyebrow('Biomedical monitoring'),
                  Text(c.title,
                    style: BMHText.heading1.copyWith(fontSize: 24)),
                ])),
            ])),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Hero
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        c.color.withOpacity(0.14),
                        c.color.withOpacity(0.02)]),
                    borderRadius: BorderRadius.circular(BMHRadius.xl),
                    border: Border.all(
                      color: c.color.withOpacity(0.3))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: c.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: c.color.withOpacity(0.25))),
                      child: Icon(c.icon, color: c.color, size: 26)),
                    const SizedBox(height: 14),
                    Text(c.tagline,
                      style: BMHText.heading2.copyWith(
                        fontStyle: FontStyle.italic, color: c.color)),
                    const SizedBox(height: 8),
                    Text(c.intro,
                      style: BMHText.bodySm.copyWith(
                        color: BMHColors.ink2, height: 1.6)),
                  ])),
                const SizedBox(height: 20),

                // ── THE PATIENT'S ACTUAL PANEL ──────
                // Only on the Blood page, and only once a report
                // exists. Everything below stays as the explainer.
                if (type == 'Blood' && _blood.report != null) ...[
                  _reportCard(context),
                  const SizedBox(height: 20),
                ],

                BMHSectionTitle('What you\'ll get'),
                const SizedBox(height: 12),
                ...c.features.map((f) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: BMHColors.line)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: c.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: c.color.withOpacity(0.22))),
                      child: Icon(f.$1, color: c.color, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(f.$2, style: BMHText.labelMd),
                      const SizedBox(height: 3),
                      Text(f.$3,
                        style: BMHText.monoSm.copyWith(
                          fontSize: 9, color: Colors.white,
                          height: 1.5)),
                    ])),
                  ]))),
                const SizedBox(height: 8),

                // Coming soon banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(
                      color: c.color.withOpacity(0.25))),
                  child: Row(children: [
                    Icon(Icons.schedule_rounded,
                      color: c.color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Lab kit integration is coming soon. Your band '
                      'data keeps building your baseline in the '
                      'meantime.',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 9, color: BMHColors.ink,
                        height: 1.4))),
                  ])),
                const SizedBox(height: 120),
              ]))),
        ])),
      ]),
    );
  }

  // ── LATEST PANEL ────────────────────────────────────────
  Widget _reportCard(BuildContext context) {
    final r = _blood.report!;
    return Column(children: [
      if (_blood.isSample)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: BMHColors.sMetabolic.withOpacity(0.10),
            borderRadius: BorderRadius.circular(BMHRadius.md),
            border: Border.all(
              color: BMHColors.sMetabolic.withOpacity(0.35))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.science_outlined,
                color: BMHColors.sMetabolic, size: 15),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Example panel. Your own results replace this as soon '
                'as your clinic uploads your blood report.',
                style: BMHText.bodySm.copyWith(
                  fontSize: 10.5, color: BMHColors.ink2, height: 1.45))),
            ])),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.xl),
          border: Border.all(color: BMHColors.sCardio.withOpacity(0.28))),
        child: Column(children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: BMHColors.sCardio.withOpacity(0.12),
                borderRadius: BorderRadius.circular(BMHRadius.md),
                border: Border.all(
                  color: BMHColors.sCardio.withOpacity(0.22))),
              child: const Icon(Icons.bloodtype_outlined,
                color: BMHColors.sCardio, size: 19)),
            const SizedBox(width: 13),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your latest panel',
                  style: BMHText.labelLg.copyWith(color: BMHColors.ink)),
                const SizedBox(height: 3),
                Text('${r.testName} · ${fmtDate(r.testDate)}',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9, color: BMHColors.inkDim)),
              ])),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _stat('${r.concernCount}', 'Outside\nrange', BMHColors.danger),
            _stat('${r.borderlineCount}', 'Border-\nline',
              BMHColors.sMetabolic),
            _stat('${r.inRangeCount}', 'In\nrange', BMHColors.success),
            _stat('${r.totalCount}', 'Total\nmarkers', BMHColors.cyan),
          ]),
        ])),

      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => BloodReportScreen(report: r))),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BMHRadius.full),
            border: Border.all(color: BMHColors.cyan.withOpacity(0.45))),
          child: Text('View full report',
            textAlign: TextAlign.center,
            style: BMHText.labelLg.copyWith(
              color: BMHColors.cyan, fontWeight: FontWeight.w600)))),

      const SizedBox(height: 12),
      // Cross-link: the same report, read against what the patient eats.
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const BiomarkersScreen())),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BMHColors.surface,
            borderRadius: BorderRadius.circular(BMHRadius.lg),
            border: Border.all(color: BMHColors.cyan.withOpacity(0.24))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: BMHColors.cyan.withOpacity(0.10),
                borderRadius: BorderRadius.circular(BMHRadius.md)),
              child: const Icon(Icons.insights_outlined,
                color: BMHColors.cyan, size: 17)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('See it against your diet',
                  style: BMHText.labelMd.copyWith(color: BMHColors.ink)),
                const SizedBox(height: 2),
                Text('Opens BioResponse → Biomarkers',
                  style: BMHText.bodySm.copyWith(
                    fontSize: 10, color: BMHColors.inkDim)),
              ])),
            const Icon(Icons.chevron_right_rounded,
              color: BMHColors.inkDim, size: 20),
          ]))),
    ]);
  }

  Widget _stat(String v, String l, Color c) => Expanded(child: Column(
    children: [
      Text(v, style: BMHText.heading2.copyWith(color: c)),
      const SizedBox(height: 3),
      Text(l,
        textAlign: TextAlign.center,
        style: BMHText.monoSm.copyWith(
          fontSize: 8, height: 1.3, color: BMHColors.inkDim)),
    ]));
}
