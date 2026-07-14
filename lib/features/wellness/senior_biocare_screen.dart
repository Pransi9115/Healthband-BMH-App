import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';

/// ─────────────────────────────────────────────────────────
///  SENIOR BIOCARE™ — gentle, senior-appropriate programs:
///  mobility, balance (fall prevention), light strength and
///  flexibility. All exercises are low-impact and include a
///  safety note. Icon-based (no image assets required).
/// ─────────────────────────────────────────────────────────

const _amber       = Color(0xFFe8a33d);
const _amberBg     = Color(0x1Fe8a33d);
const _amberBorder = Color(0x40e8a33d);

class SeniorExercise {
  final String name, duration, frequency, safety;
  final IconData icon;
  final List<String> steps;
  const SeniorExercise({
    required this.name, required this.icon, required this.duration,
    required this.frequency, required this.steps, required this.safety});
}

class SeniorCategory {
  final String title, subtitle, why;
  final IconData icon;
  final List<SeniorExercise> exercises;
  const SeniorCategory({
    required this.title, required this.subtitle, required this.icon,
    required this.why, required this.exercises});
}

const _categories = <SeniorCategory>[
  SeniorCategory(
    title: 'Balance & Fall Prevention',
    subtitle: 'The foundation of independent living',
    icon: Icons.accessibility_new_rounded,
    why: 'Balance training reduces fall risk — the single biggest '
         'threat to senior independence. Practice near a wall or '
         'sturdy chair.',
    exercises: [
      SeniorExercise(
        name: 'Single-Leg Stand',
        icon: Icons.accessibility_rounded,
        duration: '10–30 sec each side',
        frequency: 'Daily · 3 rounds',
        safety: 'Always keep a chair or counter within reach.',
        steps: [
          'Stand tall behind a sturdy chair, hands hovering over it',
          'Shift weight onto one foot and lift the other slightly',
          'Hold steady, eyes forward, breathing normally',
          'Lower gently and switch sides',
        ]),
      SeniorExercise(
        name: 'Heel-to-Toe Walk',
        icon: Icons.linear_scale_rounded,
        duration: '10 steps forward',
        frequency: 'Daily · 2–3 walks',
        safety: 'Walk alongside a wall you can touch for support.',
        steps: [
          'Place the heel of one foot directly in front of the other',
          'Walk in a straight line, arms out slightly for balance',
          'Look ahead, not down at your feet',
          'Turn slowly and repeat back the other way',
        ]),
      SeniorExercise(
        name: 'Sit-to-Stand',
        icon: Icons.chair_alt_rounded,
        duration: '8–12 repetitions',
        frequency: '3–4× per week',
        safety: 'Use a firm chair with armrests if needed.',
        steps: [
          'Sit at the front edge of a sturdy chair, feet hip-width',
          'Lean slightly forward and push through your heels to stand',
          'Stand fully tall, then lower back down slowly with control',
          'Use hands on thighs or armrests only if necessary',
        ]),
    ]),
  SeniorCategory(
    title: 'Gentle Strength',
    subtitle: 'Preserve muscle and bone density',
    icon: Icons.fitness_center_rounded,
    why: 'After 60, muscle is lost faster each year — light '
         'resistance work protects strength, bone density and '
         'metabolism.',
    exercises: [
      SeniorExercise(
        name: 'Wall Push-Up',
        icon: Icons.back_hand_rounded,
        duration: '8–12 repetitions',
        frequency: '2–3× per week',
        safety: 'Keep feet firmly planted; stop if wrists hurt.',
        steps: [
          'Stand arm\'s length from a wall, palms flat at shoulder height',
          'Bend elbows and lean chest slowly toward the wall',
          'Keep body in a straight line from head to heels',
          'Push back to the start position with control',
        ]),
      SeniorExercise(
        name: 'Seated Leg Extension',
        icon: Icons.airline_seat_recline_normal_rounded,
        duration: '10 reps each leg',
        frequency: '2–3× per week',
        safety: 'Move slowly; never lock the knee forcefully.',
        steps: [
          'Sit tall in a chair, feet flat on the floor',
          'Straighten one knee until the leg is level, toes up',
          'Hold for 2 seconds, feeling the thigh working',
          'Lower slowly and switch legs',
        ]),
      SeniorExercise(
        name: 'Heel Raises',
        icon: Icons.trending_up_rounded,
        duration: '10–15 repetitions',
        frequency: 'Daily',
        safety: 'Hold a counter or chair back for support.',
        steps: [
          'Stand tall holding a counter, feet hip-width apart',
          'Rise slowly up onto the balls of your feet',
          'Pause briefly at the top',
          'Lower heels down slowly with control',
        ]),
    ]),
  SeniorCategory(
    title: 'Mobility & Flexibility',
    subtitle: 'Keep joints moving freely',
    icon: Icons.self_improvement_rounded,
    why: 'Daily gentle movement keeps shoulders, hips and spine '
         'mobile — easing stiffness and making everyday tasks '
         'easier.',
    exercises: [
      SeniorExercise(
        name: 'Shoulder Rolls',
        icon: Icons.rotate_right_rounded,
        duration: '10 rolls each way',
        frequency: 'Daily · anytime',
        safety: 'Keep movements small and pain-free.',
        steps: [
          'Sit or stand tall, arms relaxed at your sides',
          'Roll shoulders slowly up, back and down in a circle',
          'Repeat 10 times, then reverse direction',
          'Breathe deeply throughout',
        ]),
      SeniorExercise(
        name: 'Seated Spinal Twist',
        icon: Icons.sync_alt_rounded,
        duration: 'Hold 15 sec each side',
        frequency: 'Daily',
        safety: 'Twist gently — never force the range.',
        steps: [
          'Sit tall sideways-on in a chair, feet flat',
          'Place hands on the chair back and rotate gently toward it',
          'Keep hips facing forward, lengthen the spine',
          'Hold, breathe, then repeat on the other side',
        ]),
      SeniorExercise(
        name: 'Ankle Circles',
        icon: Icons.radio_button_unchecked_rounded,
        duration: '10 circles each way',
        frequency: 'Daily · morning',
        safety: 'Great to do before getting out of bed.',
        steps: [
          'Sit with one leg extended slightly forward',
          'Slowly draw circles with your toes, 10 clockwise',
          'Reverse for 10 counter-clockwise circles',
          'Switch to the other ankle',
        ]),
    ]),
  SeniorCategory(
    title: 'Light Cardio',
    subtitle: 'Heart health without strain',
    icon: Icons.directions_walk_rounded,
    why: 'Regular light cardio supports heart health, mood and '
         'sleep. Your health band tracks every step of it.',
    exercises: [
      SeniorExercise(
        name: 'Brisk Walking',
        icon: Icons.directions_walk_rounded,
        duration: '10–30 minutes',
        frequency: '5× per week',
        safety: 'Wear supportive shoes; start with 10 minutes.',
        steps: [
          'Walk at a pace where you can talk but feel warm',
          'Swing arms naturally, stand tall',
          'Your band counts steps automatically — aim to build up '
              'gradually week by week',
          'Cool down with 2 minutes of slow walking',
        ]),
      SeniorExercise(
        name: 'Seated Marching',
        icon: Icons.event_seat_rounded,
        duration: '1–2 minutes',
        frequency: 'Daily · 2–3 rounds',
        safety: 'Perfect for rainy days or limited mobility.',
        steps: [
          'Sit tall at the front of a sturdy chair',
          'Lift one knee, then the other, in a marching rhythm',
          'Pump arms gently as you march',
          'Keep a steady, comfortable pace',
        ]),
    ]),
];

class SeniorBiocareScreen extends StatefulWidget {
  const SeniorBiocareScreen({super.key});
  @override
  State<SeniorBiocareScreen> createState() => _SeniorBiocareScreenState();
}

class _SeniorBiocareScreenState extends State<SeniorBiocareScreen> {
  int? _openCategory = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 2),
      body: Stack(children: [
        Positioned(top: -180, right: -120,
          child: Container(width: 480, height: 480,
            decoration: const BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Color(0x14e8a33d), Colors.transparent])))),
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
                  BMHEyebrow('Wellness · senior care'),
                  Text('Senior Biocare™',
                    style: BMHText.heading1.copyWith(fontSize: 24)),
                ])),
            ])),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _amberBg,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: _amberBorder)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const Icon(Icons.favorite_rounded,
                      color: _amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Gentle, low-impact programs designed for adults '
                      '60+. Move at your own pace, and check with your '
                      'doctor before starting a new exercise routine.',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 9, color: BMHColors.ink,
                        height: 1.5))),
                  ])),
                const SizedBox(height: 20),

                ...List.generate(_categories.length, (ci) {
                  final cat = _categories[ci];
                  final isOpen = _openCategory == ci;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => setState(() =>
                          _openCategory = isOpen ? null : ci),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: BMHColors.surface,
                          borderRadius:
                            BorderRadius.circular(BMHRadius.lg),
                          border: Border.all(
                            color: isOpen ? _amberBorder : BMHColors.line)),
                        child: Column(children: [
                          Row(children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: _amberBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _amberBorder)),
                              child: Icon(cat.icon,
                                color: _amber, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment:
                                CrossAxisAlignment.start,
                              children: [
                              Text(cat.title, style: BMHText.heading2
                                .copyWith(fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(cat.subtitle,
                                style: BMHText.monoSm.copyWith(
                                  fontSize: 9, color: Colors.white)),
                            ])),
                            Icon(Icons.keyboard_arrow_down_rounded,
                              color: isOpen ? _amber : BMHColors.inkMute,
                              size: 20),
                          ]),
                          if (isOpen) ...[
                            const SizedBox(height: 12),
                            ...cat.exercises.map((ex) => _ExerciseRow(
                              exercise: ex,
                              onTap: () => _showSheet(ex))),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _amberBg,
                                borderRadius:
                                  BorderRadius.circular(BMHRadius.md),
                                border: Border.all(color: _amberBorder)),
                              child: Row(
                                crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                children: [
                                const Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: _amber, size: 14),
                                const SizedBox(width: 6),
                                Expanded(child: Text(cat.why,
                                  style: BMHText.monoSm.copyWith(
                                    fontSize: 9,
                                    color: BMHColors.ink,
                                    fontStyle: FontStyle.italic))),
                              ])),
                          ],
                        ]))),
                  );
                }),
                const SizedBox(height: 120),
              ]))),
        ])),
      ]),
    );
  }

  void _showSheet(SeniorExercise ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeniorExerciseSheet(exercise: ex));
  }
}

class _ExerciseRow extends StatelessWidget {
  final SeniorExercise exercise;
  final VoidCallback onTap;
  const _ExerciseRow({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BMHColors.bg3,
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(color: BMHColors.line)),
        child: Row(children: [
          Icon(exercise.icon, color: _amber, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(exercise.name, style: BMHText.labelMd),
            Text(exercise.duration,
              style: BMHText.monoSm.copyWith(
                fontSize: 8, color: Colors.white)),
          ])),
          Text(exercise.frequency.split(' · ').first,
            style: BMHText.monoSm.copyWith(
              fontSize: 9, color: _amber)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
            color: BMHColors.inkMute, size: 16),
        ]))));
}

class _SeniorExerciseSheet extends StatelessWidget {
  final SeniorExercise exercise;
  const _SeniorExerciseSheet({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131c2e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: BMHColors.line,
                borderRadius: BorderRadius.circular(2)))),
            Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _amberBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _amberBorder)),
                child: Center(child: Icon(exercise.icon,
                  color: _amber, size: 26))),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(exercise.name,
                  style: BMHText.heading1.copyWith(fontSize: 20)),
                const SizedBox(height: 2),
                Text(exercise.duration,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9, color: _amber)),
              ])),
            ]),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(child: _info('Duration', exercise.duration)),
              const SizedBox(width: 8),
              Expanded(child: _info('Frequency', exercise.frequency)),
            ]),
            const SizedBox(height: 16),

            Text('How to do it',
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.inkMute,
                letterSpacing: 1.2)),
            const SizedBox(height: 10),
            ...List.generate(exercise.steps.length, (i) =>
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: BMHColors.bg3,
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(color: BMHColors.line)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Container(
                    width: 22, height: 22,
                    margin: const EdgeInsets.only(right: 10, top: 1),
                    decoration: BoxDecoration(
                      color: _amberBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: _amberBorder)),
                    child: Center(child: Text('${i + 1}',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 9, color: _amber,
                        fontWeight: FontWeight.w700)))),
                  Expanded(child: Text(exercise.steps[i],
                    style: BMHText.bodySm.copyWith(
                      color: Colors.white, height: 1.5))),
                ]))),
            const SizedBox(height: 8),

            // Safety note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1F34D399),
                borderRadius: BorderRadius.circular(BMHRadius.md),
                border: Border.all(color: const Color(0x4034D399))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Icon(Icons.health_and_safety_rounded,
                  color: Color(0xFF34D399), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(exercise.safety,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9, color: BMHColors.ink, height: 1.4))),
              ])),
          ]))),
    );
  }

  Widget _info(String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _amberBg,
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: _amberBorder)),
    child: Column(children: [
      Text(label, style: BMHText.monoSm.copyWith(
        fontSize: 8, color: BMHColors.inkMute)),
      const SizedBox(height: 4),
      Text(value, textAlign: TextAlign.center,
        style: BMHText.monoSm.copyWith(
          fontSize: 11, color: _amber,
          fontWeight: FontWeight.w600)),
    ]));
}
