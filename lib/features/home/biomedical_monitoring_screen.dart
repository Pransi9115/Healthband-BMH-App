import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';

/// ─────────────────────────────────────────────────────────
///  BIOMEDICAL MONITORING — Blood · GUT · DNA
///  Informational pages for upcoming lab-based monitoring.
/// ─────────────────────────────────────────────────────────
class BiomedicalMonitoringScreen extends StatelessWidget {
  final String type; // 'Blood' | 'GUT' | 'DNA'
  const BiomedicalMonitoringScreen({super.key, required this.type});

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
}
