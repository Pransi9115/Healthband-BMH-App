import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';

// ─────────────────────────────────────────────────────────
//  CONSTANTS
// ─────────────────────────────────────────────────────────
const _pink        = Color(0xFFd4537e);
const _pinkBg      = Color(0x1Ad4537e);
const _pinkBorder  = Color(0x4Dd4537e);
const _green       = Color(0xFF4dbb8f);
const _greenBg     = Color(0x1A4dbb8f);
const _greenBorder = Color(0x4D4dbb8f);

// ─────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────
class BMHExercise {
  final String name;
  final String muscleGroup;
  final int sets;
  final String reps;
  final String rest;
  final List<String> steps;
  final String hormonalTip;
  final String emoji;
  final String imagePath;
  final List<String> hormonalBenefits;

  const BMHExercise({
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    this.rest = '60s',
    required this.steps,
    required this.hormonalTip,
    required this.emoji,
    required this.imagePath,
    required this.hormonalBenefits,
  });
}

class BMHExerciseCategory {
  final String name;
  final String subtitle;
  final String emoji;
  final String why;
  final List<BMHExercise> exercises;

  const BMHExerciseCategory({
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.why,
    required this.exercises,
  });
}

// ─────────────────────────────────────────────────────────
//  EMOJI → LINE ICON
//  Calm Dark replaces emoji glyphs with modern line icons.
//  The emoji field on each exercise/category is left exactly
//  as-is (still real data) — this just maps it to an IconData
//  for rendering, in one place, instead of changing every
//  entry in the dataset below.
// ─────────────────────────────────────────────────────────
IconData _bmhIconForEmoji(String emoji) {
  switch (emoji) {
    case '🦵': return Icons.directions_walk_rounded;       // legs
    case '🏋️': return Icons.fitness_center_rounded;        // weighted lift
    case '🍑': return Icons.arrow_upward_rounded;           // hip drive
    case '📦': return Icons.inventory_2_outlined;           // step box
    case '🦿': return Icons.accessibility_new_rounded;      // leg press
    case '🧱': return Icons.crop_square_rounded;            // wall sit
    case '🪑': return Icons.event_seat_outlined;            // chair
    case '🦶': return Icons.vertical_align_top_rounded;     // calf raise
    case '💪': return Icons.fitness_center_rounded;         // strength
    case '🔽': return Icons.arrow_downward_rounded;         // pulldown
    case '🦾': return Icons.front_hand_rounded;             // arm extension
    case '⬆️': return Icons.arrow_upward_rounded;           // push up
    case '🧘': return Icons.self_improvement_rounded;       // core/calm
    case '🎯': return Icons.adjust_rounded;                 // stability target
    case '🐛': return Icons.bug_report_outlined;            // dead bug
    case '🌉': return Icons.arrow_upward_rounded;           // bridge
    case '🏔️': return Icons.landscape_outlined;             // plank/peak
    case '🧳': return Icons.shopping_bag_outlined;          // carry
    case '🦴': return Icons.shield_outlined;                // bone density
    case '⚡': return Icons.bolt_rounded;                   // impact drill
    default: return Icons.fitness_center_rounded;
  }
}

// ─────────────────────────────────────────────────────────
//  EXERCISE DATA
// ─────────────────────────────────────────────────────────
const _kCategories = [
  BMHExerciseCategory(
    name: 'Lower Body',
    subtitle: 'High Hormonal Impact',
    emoji: '🦵',
    why: 'Lower body resistance training has the strongest metabolic and bone-density response.',
    exercises: [
      BMHExercise(
        name: 'Goblet Squat',
        muscleGroup: 'Quads · Glutes · Core',
        sets: 3, reps: '10–12', rest: '60s',
        emoji: '🏋️',
        imagePath: 'assets/images/exercises/hip_thrust_goblet_detail.png',
        steps: [
          'Hold a dumbbell vertically at chest height with both hands',
          'Stand with feet shoulder-width apart, toes slightly out',
          'Squat down keeping chest tall and knees tracking over toes',
          'Press through heels to return to standing',
        ],
        hormonalBenefits: ['Bone Density Support', 'Metabolic Activation', 'Hormonal Balance'],
        hormonalTip: 'Best in follicular phase for maximum strength gains and hormonal response.',
      ),
      BMHExercise(
        name: 'Hip Thrust',
        muscleGroup: 'Glutes · Hamstrings',
        sets: 3, reps: '12–15', rest: '60s',
        emoji: '🍑',
        imagePath: 'assets/images/exercises/goblet_squat_hip_thrust.jpg',
        steps: [
          'Sit with upper back against a bench, dumbbell across hips',
          'Plant feet flat on floor, hip-width apart',
          'Drive hips upward squeezing glutes at the top',
          'Lower slowly with control',
        ],
        hormonalBenefits: ['Glute Activation', 'Pelvic Stability', 'Estrogen Support'],
        hormonalTip: 'Glute activation supports estrogen-driven fat distribution and pelvic stability.',
      ),
      BMHExercise(
        name: 'Romanian Deadlift',
        muscleGroup: 'Hamstrings · Glutes · Lower Back',
        sets: 3, reps: '10–12', rest: '60s',
        emoji: '🏋️',
        imagePath: 'assets/images/exercises/split_squat_romanian.jpg',
        steps: [
          'Hold dumbbells in front of thighs, feet hip-width apart',
          'Hinge at hips pushing them back, keeping back flat',
          'Lower weights along legs until you feel a hamstring stretch',
          'Drive hips forward to return to standing',
        ],
        hormonalBenefits: ['Cortisol Regulation', 'Insulin Sensitivity', 'Posterior Chain Strength'],
        hormonalTip: 'Posterior chain training improves cortisol regulation and insulin sensitivity.',
      ),
      BMHExercise(
        name: 'Split Squat',
        muscleGroup: 'Quads · Glutes · Balance',
        sets: 3, reps: '10 each leg', rest: '60s',
        emoji: '🦵',
        imagePath: 'assets/images/exercises/split_squat_romanian.jpg',
        steps: [
          'Stand in a staggered stance, front foot forward',
          'Lower back knee toward the floor',
          'Keep front shin vertical and chest tall',
          'Press through front heel to return up',
        ],
        hormonalBenefits: ['Muscle Symmetry', 'Balance Support', 'Hormonal Correction'],
        hormonalTip: 'Unilateral training corrects hormonal imbalances causing muscle asymmetry.',
      ),
      BMHExercise(
        name: 'Step-Ups',
        muscleGroup: 'Quads · Glutes · Stability',
        sets: 3, reps: '12 each leg', rest: '45s',
        emoji: '📦',
        imagePath: 'assets/images/exercises/step_up_deadlift.png',
        steps: [
          'Stand facing a sturdy box or step',
          'Step up with one foot, pressing through heel to lift body',
          'Bring opposite knee up at the top',
          'Step back down slowly with control',
        ],
        hormonalBenefits: ['Progesterone Balance', 'Joint Health', 'Functional Strength'],
        hormonalTip: 'Functional movement supports progesterone balance and joint health.',
      ),
      BMHExercise(
        name: 'Leg Press',
        muscleGroup: 'Quads · Glutes · Hamstrings',
        sets: 3, reps: '12–15', rest: '90s',
        emoji: '🦿',
        imagePath: 'assets/images/exercises/leg_press_wall_sit.png',
        steps: [
          'Sit in leg press machine, feet shoulder-width on platform',
          'Release safety and lower platform until knees reach 90°',
          'Press platform away until legs are nearly straight',
          'Lower slowly with control',
        ],
        hormonalBenefits: ['Growth Hormone Boost', 'Metabolic Activation', 'Bone Density'],
        hormonalTip: 'High volume leg press elevates growth hormone for up to 24 hours post-workout.',
      ),
      BMHExercise(
        name: 'Wall Sit Hold',
        muscleGroup: 'Quads · Glutes · Endurance',
        sets: 3, reps: '30–60 sec', rest: '45s',
        emoji: '🧱',
        imagePath: 'assets/images/exercises/leg_press_wall_sit.png',
        steps: [
          'Stand with back flat against a wall',
          'Slide down until thighs are parallel to floor',
          'Keep knees at 90° and feet flat',
          'Hold position breathing steadily',
        ],
        hormonalBenefits: ['Cortisol Reduction', 'Endurance', 'Stress Relief'],
        hormonalTip: 'Isometric holds reduce cortisol spikes better than high-intensity intervals.',
      ),
      BMHExercise(
        name: 'Sit-to-Stand',
        muscleGroup: 'Quads · Glutes · Functional',
        sets: 3, reps: '15', rest: '45s',
        emoji: '🪑',
        imagePath: 'assets/images/exercises/sit_to_stand_calf_raise.png',
        steps: [
          'Sit at edge of a chair, feet flat on floor',
          'Lean slightly forward and drive through heels to stand',
          'Squeeze glutes at the top',
          'Lower back to chair slowly',
        ],
        hormonalBenefits: ['Insulin Sensitivity', 'Functional Health', 'Daily Hormone Balance'],
        hormonalTip: 'Functional movement improves insulin sensitivity throughout the day.',
      ),
      BMHExercise(
        name: 'Calf Raise',
        muscleGroup: 'Calves · Ankle Stability',
        sets: 3, reps: '15–20', rest: '45s',
        emoji: '🦶',
        imagePath: 'assets/images/exercises/sit_to_stand_calf_raise.png',
        steps: [
          'Stand with feet hip-width, hold dumbbells at sides',
          'Press through balls of feet to rise onto toes',
          'Hold at top for 1 second',
          'Lower slowly back to floor',
        ],
        hormonalBenefits: ['Circulation Support', 'Perimenopause Relief', 'Ankle Stability'],
        hormonalTip: 'Lower leg strength supports circulation and reduces perimenopause leg symptoms.',
      ),
    ],
  ),
  BMHExerciseCategory(
    name: 'Upper Body',
    subtitle: 'Lean Mass & Posture',
    emoji: '💪',
    why: 'Upper body strength reduces muscle loss during perimenopause and menopause.',
    exercises: [
      BMHExercise(
        name: 'Shoulder Press',
        muscleGroup: 'Shoulders · Triceps · Core',
        sets: 3, reps: '10–12', rest: '60s',
        emoji: '🏋️',
        imagePath: 'assets/images/exercises/upper_body_grid.jpg',
        steps: [
          'Hold dumbbells at shoulder height, palms facing forward',
          'Press overhead until arms are fully extended',
          'Lower slowly back to shoulder height with control',
        ],
        hormonalBenefits: ['Lean Mass Preservation', 'Posture Support', 'Shoulder Health'],
        hormonalTip: 'Best performed in follicular phase for maximum strength gains.',
      ),
      BMHExercise(
        name: 'Chest Press',
        muscleGroup: 'Chest · Shoulders · Triceps',
        sets: 3, reps: '10–12', rest: '60s',
        emoji: '💪',
        imagePath: 'assets/images/exercises/upper_body_grid.jpg',
        steps: [
          'Lie on bench, dumbbells at chest level, elbows at 45°',
          'Press dumbbells up until arms are fully extended',
          'Lower slowly back to start position',
        ],
        hormonalBenefits: ['Posture Correction', 'Upper Strength', 'Muscle Tone'],
        hormonalTip: 'Chest pressing supports posture changes that occur during hormonal shifts.',
      ),
      BMHExercise(
        name: 'Bent-Over Row',
        muscleGroup: 'Back · Biceps · Rear Deltoids',
        sets: 3, reps: '10–12', rest: '60s',
        emoji: '🏋️',
        imagePath: 'assets/images/exercises/upper_body_grid.jpg',
        steps: [
          'Hinge at hips to 45°, holding dumbbells hanging down',
          'Pull weights to hips squeezing shoulder blades together',
          'Lower slowly maintaining back position',
        ],
        hormonalBenefits: ['Estrogen Posture Support', 'Back Strength', 'Bone Density'],
        hormonalTip: 'Back strengthening reduces the postural decline seen in low estrogen phases.',
      ),
      BMHExercise(
        name: 'Lat Pulldown',
        muscleGroup: 'Lats · Biceps · Upper Back',
        sets: 3, reps: '10–12', rest: '60s',
        emoji: '🔽',
        imagePath: 'assets/images/exercises/upper_body_grid.jpg',
        steps: [
          'Sit at lat pulldown machine, grip bar wide overhead',
          'Pull bar down to upper chest squeezing lats',
          'Return bar slowly to start position',
        ],
        hormonalBenefits: ['Cortisol Reduction', 'Posture', 'Upper Back Strength'],
        hormonalTip: 'Lat engagement improves posture and reduces cortisol-related upper back tension.',
      ),
      BMHExercise(
        name: 'Bicep Curl',
        muscleGroup: 'Biceps · Forearms',
        sets: 3, reps: '12–15', rest: '45s',
        emoji: '💪',
        imagePath: 'assets/images/exercises/upper_body_grid.jpg',
        steps: [
          'Stand holding dumbbells at sides, palms facing forward',
          'Curl weights toward shoulders keeping elbows fixed',
          'Squeeze at top then lower slowly',
        ],
        hormonalBenefits: ['Functional Independence', 'Lean Tone', 'Muscle Preservation'],
        hormonalTip: 'Arm strength training supports functional independence during menopause.',
      ),
      BMHExercise(
        name: 'Tricep Extension',
        muscleGroup: 'Triceps · Shoulder Stability',
        sets: 3, reps: '12–15', rest: '45s',
        emoji: '🦾',
        imagePath: 'assets/images/exercises/upper_body_grid.jpg',
        steps: [
          'Hold one dumbbell overhead with both hands',
          'Lower it behind head bending at elbows',
          'Press back up to start squeezing triceps',
        ],
        hormonalBenefits: ['Arm Tone', 'Perimenopause Fat Reduction', 'Shoulder Stability'],
        hormonalTip: 'Tricep work reduces arm fat redistribution common in perimenopause.',
      ),
      BMHExercise(
        name: 'Incline Push-Up',
        muscleGroup: 'Chest · Shoulders · Core',
        sets: 3, reps: '10–15', rest: '45s',
        emoji: '⬆️',
        imagePath: 'assets/images/exercises/upper_body_grid.jpg',
        steps: [
          'Place hands on bench or wall, body in straight line',
          'Lower chest toward surface keeping core tight',
          'Push back up to start position',
        ],
        hormonalBenefits: ['Wrist Bone Density', 'Safe Upper Body Load', 'Core Stability'],
        hormonalTip: 'Modified push-ups maintain bone density in wrists and shoulders safely.',
      ),
    ],
  ),
  BMHExerciseCategory(
    name: 'Core & Metabolic',
    subtitle: 'Metabolic Stability',
    emoji: '🧘',
    why: 'Core stability improves insulin sensitivity and spinal health.',
    exercises: [
      BMHExercise(
        name: 'Pall of Press',
        muscleGroup: 'Core · Anti-Rotation',
        sets: 3, reps: '10 each side', rest: '45s',
        emoji: '🎯',
        imagePath: 'assets/images/exercises/core_grid.jpg',
        steps: [
          'Hold cable or band at chest height, anchor to side',
          'Press arms straight out in front of you',
          'Hold 2 seconds resisting rotation',
          'Return to chest slowly',
        ],
        hormonalBenefits: ['Abdominal Fat Reduction', 'Cortisol Balance', 'Core Stability'],
        hormonalTip: 'Anti-rotation core work reduces abdominal fat accumulation driven by cortisol.',
      ),
      BMHExercise(
        name: 'Dead Bug',
        muscleGroup: 'Deep Core · Stability',
        sets: 3, reps: '10 each side', rest: '45s',
        emoji: '🐛',
        imagePath: 'assets/images/exercises/core_grid.jpg',
        steps: [
          'Lie on back, arms up and knees at 90°',
          'Lower opposite arm and leg toward floor',
          'Keep lower back pressed to floor throughout',
          'Return and repeat on other side',
        ],
        hormonalBenefits: ['Spinal Health', 'Deep Core Activation', 'Bone Density Protection'],
        hormonalTip: 'Deep core activation protects the spine during hormonal bone density changes.',
      ),
      BMHExercise(
        name: 'Glute Bridge',
        muscleGroup: 'Glutes · Core · Hamstrings',
        sets: 3, reps: '15', rest: '45s',
        emoji: '🌉',
        imagePath: 'assets/images/exercises/core_grid.jpg',
        steps: [
          'Lie on back, knees bent, feet flat on floor',
          'Drive hips up squeezing glutes at top',
          'Hold 2 seconds at the top',
          'Lower slowly back to floor',
        ],
        hormonalBenefits: ['Pelvic Floor Health', 'Estrogen Support', 'Glute Activation'],
        hormonalTip: 'Glute bridges support pelvic floor function affected by estrogen decline.',
      ),
      BMHExercise(
        name: 'Plank',
        muscleGroup: 'Core · Shoulders · Full Body',
        sets: 3, reps: '30–60 sec', rest: '45s',
        emoji: '🏔️',
        imagePath: 'assets/images/exercises/core_grid.jpg',
        steps: [
          'Place forearms on floor, elbows under shoulders',
          'Lift body into straight line from head to heels',
          'Squeeze core and glutes throughout',
          'Breathe steadily and hold position',
        ],
        hormonalBenefits: ['Cortisol Improvement', 'Belly Fat Reduction', 'Full Body Stability'],
        hormonalTip: 'Plank holds improve cortisol response and reduce menopausal belly fat.',
      ),
      BMHExercise(
        name: 'Farmer\'s Carry',
        muscleGroup: 'Core · Grip · Full Body',
        sets: 3, reps: '30 metres', rest: '60s',
        emoji: '🧳',
        imagePath: 'assets/images/exercises/farmers_carry.png',
        steps: [
          'Hold heavy dumbbells at sides, stand tall',
          'Walk forward with controlled steps',
          'Keep core tight and shoulders back throughout',
          'Turn and walk back to start',
        ],
        hormonalBenefits: ['Growth Hormone Boost', 'Lean Mass', 'Testosterone Support'],
        hormonalTip: 'Loaded carries boost growth hormone and testosterone for lean mass preservation.',
      ),
    ],
  ),
  BMHExerciseCategory(
    name: 'Bone Density',
    subtitle: 'Impact Stimulus',
    emoji: '🦴',
    why: 'Mechanical loading improves osteoblastic activity and bone mineral density.',
    exercises: [
      BMHExercise(
        name: 'Weighted Squat',
        muscleGroup: 'Full Lower Body · Spine',
        sets: 4, reps: '8–10', rest: '90s',
        emoji: '🏋️',
        imagePath: 'assets/images/exercises/bone_density_grid.jpg',
        steps: [
          'Hold barbell across upper back or dumbbells at sides',
          'Stand feet shoulder-width, toes slightly out',
          'Squat to parallel keeping chest tall',
          'Drive through heels to return to standing',
        ],
        hormonalBenefits: ['Bone Density', 'Post-Menopausal Strength', 'Full Body Stimulus'],
        hormonalTip: 'Heavy squats are the best exercise for bone density in post-menopausal women.',
      ),
      BMHExercise(
        name: 'Dumbbell Deadlift',
        muscleGroup: 'Full Posterior Chain · Spine',
        sets: 4, reps: '8–10', rest: '90s',
        emoji: '🏋️',
        imagePath: 'assets/images/exercises/step_up_deadlift.png',
        steps: [
          'Stand with dumbbells in front of shins, feet hip-width',
          'Hinge at hips and bend knees to grip weights',
          'Drive through floor to stand up tall',
          'Lower back with control hinging at hips first',
        ],
        hormonalBenefits: ['Osteogenic Response', 'Posterior Chain', 'Metabolic Boost'],
        hormonalTip: 'Deadlifts trigger the highest osteogenic response of any resistance exercise.',
      ),
      BMHExercise(
        name: 'Step Impact Drill',
        muscleGroup: 'Legs · Bone Stimulus',
        sets: 3, reps: '10 each leg', rest: '60s',
        emoji: '⚡',
        imagePath: 'assets/images/exercises/bone_density_grid.jpg',
        steps: [
          'Stand beside a step',
          'Step up firmly creating impact through heel',
          'Step down with control',
          'Alternate legs at a moderate pace',
        ],
        hormonalBenefits: ['Bone Remodelling', 'Safe Impact Loading', 'Balance'],
        hormonalTip: 'Low-impact stepping stimulates bone remodelling safely.',
      ),
      BMHExercise(
        name: 'Loaded Carry',
        muscleGroup: 'Full Body · Bone Loading',
        sets: 3, reps: '40 metres', rest: '60s',
        emoji: '🧳',
        imagePath: 'assets/images/exercises/bone_density_grid.jpg',
        steps: [
          'Hold heavy weights at sides or in rack position',
          'Walk tall with controlled breathing',
          'Keep core braced and spine neutral',
          'Complete distance without setting weights down',
        ],
        hormonalBenefits: ['Spinal Bone Density', 'Axial Loading', 'Core Strength'],
        hormonalTip: 'Axial loading through carries is critical for spinal bone density preservation.',
      ),
    ],
  ),
];

// ─────────────────────────────────────────────────────────
//  WOMEN'S BIOCARE SCREEN
// ─────────────────────────────────────────────────────────
class WomensBiocareScreen extends StatefulWidget {
  const WomensBiocareScreen({super.key});
  @override
  State<WomensBiocareScreen> createState() => _WomensBiocareScreenState();
}

class _WomensBiocareScreenState extends State<WomensBiocareScreen>
    with TickerProviderStateMixin {

  final Set<int> _expanded = {};
  late AnimationController _entryCtrl;
  late List<Animation<double>> _slideAnims;
  late List<Animation<double>> _fadeAnims;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800));

    _slideAnims = List.generate(_kCategories.length, (i) =>
      Tween<double>(begin: 30, end: 0).animate(CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(i * 0.1, 0.6 + i * 0.1,
          curve: Curves.easeOutCubic))));

    _fadeAnims = List.generate(_kCategories.length, (i) =>
      Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(i * 0.1, 0.6 + i * 0.1,
          curve: Curves.easeOut))));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  void _showExerciseSheet(BMHExercise ex) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ExerciseSheet(exercise: ex),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 2),
      body: Stack(children: [
        Positioned(top: -150, right: -100,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _pink.withOpacity(0.07), Colors.transparent])))),
        SafeArea(bottom: false,
          child: Column(children: [

            // ── Header ──────────────────────────────
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
                  BMHEyebrow('Women\'s Biocare™', showDot: true),
                  Text('Hormonal Strength', style: BMHText.heading1),
                ])),
              ])),

            // ── Stats bar ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BMHSpacing.screenH),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _pinkBg,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: _pinkBorder)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                  _StatChip('25', 'Exercises'),
                  Container(width: 1, height: 24, color: _pinkBorder),
                  _StatChip('4', 'Categories'),
                  Container(width: 1, height: 24, color: _pinkBorder),
                  _StatChip('3–4', 'Sets each'),
                ]))),

            const SizedBox(height: 22),

            // ── Category list ────────────────────────
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: BMHSpacing.screenH),
              child: Column(children: [
                ...List.generate(_kCategories.length, (ci) {
                  final cat = _kCategories[ci];
                  final isOpen = _expanded.contains(ci);
                  return AnimatedBuilder(
                    animation: _entryCtrl,
                    builder: (_, child) => Opacity(
                      opacity: _fadeAnims[ci].value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnims[ci].value),
                        child: child)),
                    child: Column(children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (isOpen) _expanded.remove(ci);
                            else _expanded.add(ci);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: BMHColors.surface,
                            borderRadius:
                              BorderRadius.circular(BMHRadius.lg),
                            border: Border.all(
                              color: isOpen
                                ? _pinkBorder : BMHColors.line)),
                          child: Column(children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Icon(_bmhIconForEmoji(cat.emoji),
                                  color: _pink, size: 22),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                  children: [
                                  Text(cat.name,
                                    style: BMHText.heading2),
                                  Text(cat.subtitle,
                                    style: BMHText.monoSm.copyWith(
                                      fontSize: 9,
                                      color: BMHColors.inkMute)),
                                ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _pinkBg,
                                    borderRadius: BorderRadius.circular(
                                      BMHRadius.full),
                                    border:
                                      Border.all(color: _pinkBorder)),
                                  child: Text(
                                    '${cat.exercises.length}',
                                    style: BMHText.monoSm.copyWith(
                                      fontSize: 9, color: _pink))),
                                const SizedBox(width: 8),
                                AnimatedRotation(
                                  turns: isOpen ? 0.5 : 0,
                                  duration:
                                    const Duration(milliseconds: 250),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: isOpen
                                      ? _pink : BMHColors.inkMute,
                                    size: 20)),
                              ])),
                            if (isOpen) ...[
                              Container(height: 1,
                                color: BMHColors.line,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 14)),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14, 8, 14, 8),
                                child: Column(children: [
                                  ...cat.exercises.map((ex) =>
                                    _ExerciseRow(
                                      exercise: ex,
                                      onTap: () =>
                                        _showExerciseSheet(ex))),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _pinkBg,
                                      borderRadius:
                                        BorderRadius.circular(
                                          BMHRadius.md),
                                      border: Border.all(
                                        color: _pinkBorder)),
                                    child: Row(
                                      crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                      children: [
                                      const Icon(
                                        Icons.lightbulb_outline_rounded,
                                        color: _pink, size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(cat.why,
                                        style: BMHText.monoSm.copyWith(
                                          fontSize: 9,
                                          color: BMHColors.inkDim,
                                          fontStyle:
                                            FontStyle.italic))),
                                    ])),
                                ])),
                            ],
                          ])),
                      ),
                      const SizedBox(height: 8),
                    ]));
                }),
                const SizedBox(height: 100),
              ]),
            )),
          ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  ANIMATED EXERCISE ROW
// ─────────────────────────────────────────────────────────
class _ExerciseRow extends StatefulWidget {
  final BMHExercise exercise;
  final VoidCallback onTap;
  const _ExerciseRow({required this.exercise, required this.onTap});

  @override
  State<_ExerciseRow> createState() => _ExerciseRowState();
}

class _ExerciseRowState extends State<_ExerciseRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350));
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<double>(begin: 10, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) =>
      _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, child) => Opacity(
      opacity: _fade.value,
      child: Transform.translate(
        offset: Offset(0, _slide.value),
        child: child)),
    child: GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BMHColors.bg3,
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(color: BMHColors.line)),
        child: Row(children: [
          Icon(_bmhIconForEmoji(widget.exercise.emoji),
            color: _pink, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(widget.exercise.name, style: BMHText.labelMd),
            Text(widget.exercise.muscleGroup,
              style: BMHText.monoSm.copyWith(
                fontSize: 8, color: BMHColors.inkMute)),
          ])),
          Text('${widget.exercise.sets}×${widget.exercise.reps}',
            style: BMHText.monoSm.copyWith(
              fontSize: 9, color: _pink)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
            color: BMHColors.inkMute, size: 16),
        ]))));
}

// ── Stat chip ─────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String value, label;
  const _StatChip(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: BMHText.monoSm.copyWith(
      fontSize: 16, fontWeight: FontWeight.w600, color: _pink)),
    Text(label, style: BMHText.monoSm.copyWith(
      fontSize: 8, color: BMHColors.inkMute)),
  ]);
}

// ─────────────────────────────────────────────────────────
//  EXERCISE BOTTOM SHEET
// ─────────────────────────────────────────────────────────
class _ExerciseSheet extends StatelessWidget {
  final BMHExercise exercise;
  const _ExerciseSheet({required this.exercise});

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
            crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Drag handle
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: BMHColors.line,
                borderRadius: BorderRadius.circular(2)))),

            // Title row
            Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _pinkBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _pinkBorder)),
                child: Center(child: Icon(_bmhIconForEmoji(exercise.emoji),
                  color: _pink, size: 26))),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(exercise.name,
                  style: BMHText.heading1.copyWith(fontSize: 20)),
                const SizedBox(height: 2),
                Text(exercise.muscleGroup,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9, color: _pink)),
              ])),
            ]),

            const SizedBox(height: 16),

            // ── Exercise Image ────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(BMHRadius.lg),
              child: Container(
                width: double.infinity,
                height: 200,
                color: _pinkBg,
                child: Image.asset(
                  exercise.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _pinkBg,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(_bmhIconForEmoji(exercise.emoji),
                        color: _pink, size: 48),
                      const SizedBox(height: 8),
                      Text(exercise.name,
                        style: BMHText.monoSm.copyWith(
                          color: _pink, fontSize: 12)),
                    ])))),
            ),

            const SizedBox(height: 16),

            // ── Sets · Reps · Rest ────────────────────
            Row(children: [
              Expanded(child: _InfoCard(
                'Sets', '${exercise.sets}',
                _pink, _pinkBg, _pinkBorder, fontSize: 28)),
              const SizedBox(width: 8),
              Expanded(child: _InfoCard(
                'Reps', exercise.reps,
                _pink, _pinkBg, _pinkBorder, fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(child: _InfoCard(
                'Rest', exercise.rest,
                _green, _greenBg, _greenBorder, fontSize: 20)),
            ]),

            const SizedBox(height: 20),

            // ── How to do it ──────────────────────────
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
                      color: _pinkBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: _pinkBorder)),
                    child: Center(child: Text('${i + 1}',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 9, color: _pink,
                        fontWeight: FontWeight.w700)))),
                  Expanded(child: Text(exercise.steps[i],
                    style: BMHText.bodyMd.copyWith(
                      fontSize: 12, color: BMHColors.inkDim,
                      height: 1.5))),
                ])),
            ),

            const SizedBox(height: 16),

            // ── Hormonal Benefits ─────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _greenBg,
                borderRadius: BorderRadius.circular(BMHRadius.lg),
                border: Border.all(color: _greenBorder)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(children: [
                  const Icon(Icons.verified_outlined,
                    color: _green, size: 16),
                  const SizedBox(width: 6),
                  Text('Hormonal Benefits',
                    style: BMHText.labelMd.copyWith(
                      color: _green, fontSize: 11)),
                ]),
                const SizedBox(height: 10),
                ...exercise.hormonalBenefits.map((b) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(
                        width: 18, height: 18,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _greenBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: _greenBorder)),
                        child: const Center(child: Icon(
                          Icons.check_rounded,
                          color: _green, size: 11))),
                      Text(b, style: BMHText.bodyMd.copyWith(
                        fontSize: 12,
                        color: BMHColors.inkDim)),
                    ]))),
              ])),

            const SizedBox(height: 12),

            // ── Hormonal Tip ──────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _pinkBg,
                borderRadius: BorderRadius.circular(BMHRadius.lg),
                border: Border.all(color: _pinkBorder)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Icon(Icons.lightbulb_outline_rounded,
                  color: _pink, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text('Hormonal Tip',
                    style: BMHText.labelMd.copyWith(
                      color: _pink, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(exercise.hormonalTip,
                    style: BMHText.bodyMd.copyWith(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: BMHColors.inkDim,
                      height: 1.5)),
                ])),
              ])),
          ]),
        )));
  }
}

// ── Info card (Sets / Reps / Rest) ────────────────────────
class _InfoCard extends StatelessWidget {
  final String label, value;
  final Color color, bg, border;
  final double fontSize;
  const _InfoCard(this.label, this.value, this.color,
    this.bg, this.border, {this.fontSize = 24});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(BMHRadius.lg),
      border: Border.all(color: border)),
    child: Column(children: [
      Text(label, style: BMHText.monoSm.copyWith(
        fontSize: 9, color: BMHColors.inkMute,
        letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text(value, style: BMHText.displayMd.copyWith(
        color: color, fontSize: fontSize, height: 1.1)),
    ]));
}
