import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../health/breathing/breathing_screen.dart';
import 'womens_biocare_screen.dart';
import 'senior_biocare_screen.dart';
import 'activity_screen.dart';

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

                // ── ACTIVITY ─────────────────────────────
                BMHSectionTitle('Activity'),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const ActivityScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [
                          BMHColors.sOxygen.withOpacity(0.12),
                          BMHColors.sOxygen.withOpacity(0.02)]),
                      borderRadius: BorderRadius.circular(BMHRadius.xl),
                      border: Border.all(
                        color: BMHColors.sOxygen.withOpacity(0.3))),
                    child: Row(children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: BMHColors.sOxygen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: BMHColors.sOxygen.withOpacity(0.25))),
                        child: const Center(child: Icon(
                          Icons.directions_bike_outlined,
                          color: BMHColors.sOxygen, size: 28))),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text('Activity', style: BMHText.heading2),
                        const SizedBox(height: 4),
                        Text('Steps · Distance · Calories · Goals',
                          style: BMHText.monoSm.copyWith(
                            color: BMHColors.sOxygen, fontSize: 9)),
                      ])),
                      Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(
                          color: BMHColors.sOxygen,
                          shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded,
                          color: BMHColors.bg0, size: 18)),
                    ])),
                ),
                const SizedBox(height: 30),

                // ── SENIOR BIOCARE ───────────────────────
                BMHSectionTitle('Senior Biocare'),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const SeniorBiocareScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFe8a33d).withOpacity(0.12),
                          const Color(0xFFe8a33d).withOpacity(0.02)]),
                      borderRadius: BorderRadius.circular(BMHRadius.xl),
                      border: Border.all(
                        color: const Color(0xFFe8a33d).withOpacity(0.3))),
                    child: Row(children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFe8a33d).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFe8a33d).withOpacity(0.25))),
                        child: const Center(child: Icon(
                          Icons.elderly_rounded,
                          color: Color(0xFFe8a33d), size: 28))),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text('Senior Biocare™', style: BMHText.heading2),
                        const SizedBox(height: 4),
                        Text('Mobility · Balance · Gentle Strength',
                          style: BMHText.monoSm.copyWith(
                            color: const Color(0xFFe8a33d), fontSize: 9)),
                      ])),
                      Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFe8a33d),
                          shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded,
                          color: BMHColors.bg0, size: 18)),
                    ])),
                ),

                const SizedBox(height: 120),
              ]),
            )),
          ])),
      ]),
    );
  }
}
