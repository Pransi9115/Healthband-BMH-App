import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../health/breathing/breathing_screen.dart';
import 'womens_biocare_screen.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});
  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: Stack(children: [
        Positioned(top: -150, right: -100,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                BMHColors.sGut.withOpacity(0.07), Colors.transparent])))),
        SafeArea(bottom: false,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.screenH),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                // TOP BAR
                Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BMHEyebrow('Mind & Body', showDot: true),
                    const SizedBox(height: 4),
                    Text('Wellness', style: BMHText.heading1),
                  ])),
                ]),
                const SizedBox(height: 10),
                Text('Your personal wellness centre — breathing, mindfulness and recovery.',
                  style: BMHText.bodySm.copyWith(color: BMHColors.inkDim)),
                const SizedBox(height: 30),

                // ── BREATHING EXERCISES ──────────────────
                BMHSectionTitle('Breathing Exercises'),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BreathingScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [
                          BMHColors.sGut.withOpacity(0.12),
                          BMHColors.sGut.withOpacity(0.02)]),
                      borderRadius: BorderRadius.circular(BMHRadius.xl),
                      border: Border.all(color: BMHColors.sGut.withOpacity(0.3))),
                    child: Row(children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: BMHColors.sGut.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: BMHColors.sGut.withOpacity(0.25))),
                        child: const Center(child: Icon(Icons.air_rounded,
                          color: BMHColors.sGut, size: 28))),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Breathing Exercises',
                          style: BMHText.heading2),
                        const SizedBox(height: 4),
                        Text('6 guided programs',
                          style: BMHText.monoSm.copyWith(
                            color: BMHColors.sGut, fontSize: 9)),

                      ])),
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: BMHColors.sGut, shape: BoxShape.circle,
                          boxShadow: BMHShadows.glow(BMHColors.sGut)),
                        child: const Icon(Icons.arrow_forward_rounded,
                          color: BMHColors.bg0, size: 18)),
                    ])),
                ),
                const SizedBox(height: 30),

                // ── WOMEN'S BIOCARE ──────────────────────
                BMHSectionTitle('Women\'s Biocare'),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const WomensBiocareScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFd4537e).withOpacity(0.12),
                          const Color(0xFFd4537e).withOpacity(0.02)]),
                      borderRadius: BorderRadius.circular(BMHRadius.xl),
                      border: Border.all(
                        color: const Color(0xFFd4537e).withOpacity(0.3))),
                    child: Row(children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFd4537e).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFd4537e).withOpacity(0.25))),
                        child: const Center(child: Icon(Icons.fitness_center_rounded,
                          color: Color(0xFFd4537e), size: 28))),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text('Women\'s Biocare™', style: BMHText.heading2),
                        const SizedBox(height: 4),
                        Text('Hormonal Strength Training',
                          style: BMHText.monoSm.copyWith(
                            color: const Color(0xFFd4537e), fontSize: 9)),
                      ])),
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFd4537e),
                          shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded,
                          color: BMHColors.bg0, size: 18)),
                    ])),
                ),
                const SizedBox(height: 30),
                BMHSectionTitle('Coming Soon'),
                const SizedBox(height: 16),

                _ComingSoonCard(
                  icon: Icons.self_improvement_rounded,
                  title: 'Meditation',
                  subtitle: 'Guided mindfulness sessions',
                  color: BMHColors.sSleep),
                const SizedBox(height: 10),
                _ComingSoonCard(
                  icon: Icons.water_drop_outlined,
                  title: 'Water Tracker',
                  subtitle: 'Daily hydration goals',
                  color: BMHColors.sOxygen),
                const SizedBox(height: 10),
                _ComingSoonCard(
                  icon: Icons.bedtime_outlined,
                  title: 'Sleep Goals',
                  subtitle: 'Bedtime reminders & insights',
                  color: BMHColors.sSleep),
                const SizedBox(height: 10),
                _ComingSoonCard(
                  icon: Icons.spa_outlined,
                  title: 'Stress Relief',
                  subtitle: 'Relaxation techniques',
                  color: BMHColors.sGut),

                const SizedBox(height: 120),
              ]),
            )),
          ])),
      ]),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _ComingSoonCard({
    required this.icon, required this.title,
    required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: BMHColors.surface,
      borderRadius: BorderRadius.circular(BMHRadius.lg),
      border: Border.all(color: BMHColors.line)),
    child: Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
        child: Center(child: Icon(icon, color: color, size: 22))),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: BMHText.heading2),
        Text(subtitle, style: BMHText.monoSm.copyWith(
          fontSize: 9, color: BMHColors.inkMute)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: BMHColors.bg4,
          borderRadius: BorderRadius.circular(BMHRadius.full),
          border: Border.all(color: BMHColors.line)),
        child: Text('Soon', style: BMHText.monoSm.copyWith(
          fontSize: 8, color: BMHColors.inkMute))),
    ]));
}
