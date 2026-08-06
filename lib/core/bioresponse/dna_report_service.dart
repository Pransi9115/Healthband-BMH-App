// ─────────────────────────────────────────────────────────
//  DNA — FITNESS GENOMICS
//
//  The report the laboratory issues, in the app's own shape.
//
//  HOW A GENETIC RESULT DIFFERS FROM A BLOOD RESULT
//  A blood marker is a measurement of you today; repeat the test and
//  it moves. A genotype does not move. That changes what the reading
//  means: it is a predisposition, not a verdict, and almost every
//  trait here can be trained against. The screen says so, because a
//  patient told their muscle-building response is "poor" needs to
//  know that is a starting line rather than a ceiling.
//
//  SCORING
//  The laboratory scores each trait 0 to 10, where HIGHER IS WORSE —
//  10 is the least favourable genotype. That is the opposite of every
//  other score in this app, so it is inverted for display and the
//  band (Good / Typical / Poor) is what drives the colour.
// ─────────────────────────────────────────────────────────

enum GeneBand { good, typical, poor }

extension GeneBandX on GeneBand {
  String get label => switch (this) {
        GeneBand.good => 'Good',
        GeneBand.typical => 'Typical',
        GeneBand.poor => 'Poor',
      };

  /// Filled squares out of five, as the printed report draws them.
  int get pips => switch (this) {
        GeneBand.good => 2,
        GeneBand.typical => 3,
        GeneBand.poor => 4,
      };

  static GeneBand parse(String s) => switch (s.toLowerCase()) {
        'good' => GeneBand.good,
        'poor' => GeneBand.poor,
        _ => GeneBand.typical,
      };
}

class GeneTrait {
  final String id;
  final String category;
  final String name;
  final GeneBand band;
  final double score;        // 0–10, higher is less favourable
  final String summary;
  final String whatIs;
  final String interpretation;
  final String geneName;
  final String genotype;
  final String geneNote;
  final List<String> dos;
  final List<String> donts;

  const GeneTrait({
    required this.id,
    required this.category,
    required this.name,
    required this.band,
    required this.score,
    required this.summary,
    required this.whatIs,
    required this.interpretation,
    required this.geneName,
    required this.genotype,
    required this.geneNote,
    this.dos = const [],
    this.donts = const [],
  });

  /// 0..1 along the bar. The laboratory scale runs the wrong way for a
  /// traffic light, so it is flipped here — full bar means favourable.
  double get barPosition => ((10 - score) / 10).clamp(0.0, 1.0);
}

class DnaReport {
  final String patientName;
  final String dateOfBirth;
  final String panel;
  final DateTime reportedAt;
  final List<GeneTrait> traits;

  const DnaReport({
    required this.patientName,
    required this.dateOfBirth,
    required this.panel,
    required this.reportedAt,
    required this.traits,
  });

  List<String> get categories {
    final out = <String>[];
    for (final t in traits) {
      if (!out.contains(t.category)) out.add(t.category);
    }
    return out;
  }

  List<GeneTrait> inCategory(String c) =>
      traits.where((t) => t.category == c).toList();

  int get goodCount =>
      traits.where((t) => t.band == GeneBand.good).length;
  int get typicalCount =>
      traits.where((t) => t.band == GeneBand.typical).length;
  int get poorCount =>
      traits.where((t) => t.band == GeneBand.poor).length;

  /// The traits worth acting on first.
  List<GeneTrait> get flagged {
    final list = traits.where((t) => t.band == GeneBand.poor).toList();
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }
}

// ─────────────────────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────────────────────
class DnaReportService {
  DnaReportService._();
  static final DnaReportService instance = DnaReportService._();

  DnaReport? _report;
  DnaReport? get report => _report ?? _sample;
  bool get isSample => _report == null;

  /// THE SEAM. A real result from the laboratory replaces the sample.
  void ingest(DnaReport r) => _report = r;

  static final _sample = DnaReport(
    patientName: 'Avani Mehta',
    dateOfBirth: '17 December 2000',
    panel: 'Fitness Genomics',
    reportedAt: DateTime(2026, 8, 6),
    traits: const [
      // ── ENDURANCE ─────────────────────────────────────
      GeneTrait(
        id: 'lactate_threshold',
        category: 'Endurance',
        name: 'Lactate threshold',
        band: GeneBand.poor,
        score: 6.7,
        summary: 'Your lactate threshold is poor.',
        whatIs:
          'Lactate is produced during hard effort, and the aerobic '
          'system burns it back off as fuel. Past a certain intensity '
          'it is produced faster than it can be cleared, it accumulates, '
          'and fatigue sets in. That crossover point is the lactate '
          'threshold. A higher one means you can hold a harder pace '
          'before it starts to hurt.',
        interpretation:
          'People with this genotype tend to clear and reuse lactate '
          'less efficiently, so holding a high intensity for long tends '
          'to be harder than it is for others training the same amount.',
        geneName: 'PPARD',
        genotype: 'AA',
        geneNote:
          'Encodes peroxisome proliferator-activated receptor delta, '
          'which affects fatty acid oxidation and energy production. In '
          'muscle its expression rises with exercise, increasing fat '
          'burning capacity and type I fibres.',
        dos: [
          'Fartlek sessions and sprint training, which raise the '
            'threshold directly.',
          'High-intensity work above threshold, around 85 to 95 percent '
            'of maximal heart rate.',
          'At least two threshold sessions a week, adding a third if it '
            'is not shifting.',
        ],
        donts: [
          'Relying on steady conventional runs — they do little for the '
            'threshold itself.',
        ]),

      GeneTrait(
        id: 'aerobic_trainability',
        category: 'Endurance',
        name: 'Aerobic capacity trainability',
        band: GeneBand.typical,
        score: 4.7,
        summary: 'Your aerobic capacity trainability is typical.',
        whatIs:
          'Aerobic capacity, or VO2 max, is the most oxygen your body '
          'can take in and use during exercise. Training improves it, '
          'but how quickly and how far varies enormously between people '
          'for genetic reasons.',
        interpretation:
          'You respond to aerobic training about as much as the average '
          'person does. Gains will come, but they will come from the '
          'work rather than from a head start.',
        geneName: 'CAMTA1',
        genotype: 'AA',
        geneNote:
          'Encodes calmodulin-binding transcription activator 1, a '
          'transcriptional activator. Variants of this gene have been '
          'associated with smaller gains in VO2 max.',
        dos: [
          'High-intensity interval work above 85 percent of maximum '
            'heart rate — the most effective lever on aerobic capacity.',
          'At least one HIIT session a week.',
          'Foods rich in iron and the B vitamins.',
        ],
        donts: [
          'Nicotine and tobacco in any form.',
          'Building only with slow long-distance sessions.',
        ]),

      GeneTrait(
        id: 'endurance',
        category: 'Endurance',
        name: 'Endurance',
        band: GeneBand.typical,
        score: 4.5,
        summary: 'Your endurance profile is typical.',
        whatIs:
          'Endurance is the ability to sustain activity for a long '
          'time without undue breathlessness or fatigue. It rests on '
          'aerobic capacity, fat oxidation, lactate threshold, exercise '
          'economy and the share of slow twitch fibres you carry.',
        interpretation:
          'An average genetic profile for endurance. Reaching a very '
          'high level in endurance events would take a strict regimen, '
          'but a strict regimen does offset it.',
        geneName: 'ACE',
        genotype: 'AA',
        geneNote:
          'ACE is a dipeptidyl carboxypeptidase that converts '
          'angiotensin I into the vasoconstrictor angiotensin II and '
          'inactivates bradykinin. Its variants are among the most '
          'studied in exercise genetics.',
        dos: [
          'Train every trainable component: aerobic capacity, lactate '
            'threshold, resistance to fatigue, exercise economy.',
          'Raise mileage and intensity gradually to avoid injury.',
          'Consider caffeine and beta-alanine, which have evidence '
            'behind them for endurance.',
          'Carbohydrate loading before long distance efforts.',
          'Rest properly after hard or high-volume sessions.',
        ],
        donts: [
          'Training only long and slow.',
          'Poor technique, and poor nutrition — both blunt recovery.',
        ]),

      // ── POWER ─────────────────────────────────────────
      GeneTrait(
        id: 'power',
        category: 'Power',
        name: 'Power',
        band: GeneBand.typical,
        score: 5.1,
        summary: 'Your power profile is typical.',
        whatIs:
          'Power is how much force your muscles can produce quickly — '
          'the quality behind jumping, sprinting, lifting heavy and '
          'short-distance swimming.',
        interpretation:
          'An average genetic profile for power and strength. Elite '
          'level in these events would be hard-won, but training '
          'meaningfully offsets the difference.',
        geneName: 'ACE',
        genotype: 'AA',
        geneNote:
          'The same ACE variant that shapes the endurance profile also '
          'influences power output, which is why one genotype appears '
          'against several traits in this report.',
        dos: [
          'Plyometric training to raise muscular power output.',
          'Muscle-building blocks, since more muscle means more power.',
          'Lower volume with heavier loads — power comes from '
            'neuromuscular output, not from accumulated fatigue.',
          'Creatine is worth considering.',
        ],
        donts: [
          'Sudden jumps in intensity — the usual route to injury.',
          'Poor form under heavy load.',
          'Training power in a calorie deficit.',
          'Starting without a proper warm-up.',
        ]),

      // ── INJURY RISK ───────────────────────────────────
      GeneTrait(
        id: 'muscle_injury',
        category: 'Injury risk',
        name: 'Muscle injury',
        band: GeneBand.typical,
        score: 5.4,
        summary: 'You have a typical risk for muscle injury.',
        whatIs:
          'Exercise damages muscle, and a small amount of that damage '
          'is exactly how muscle adapts and grows. Too much becomes a '
          'strain — fibres tearing under mechanical stress, with pain '
          'and loss of function.',
        interpretation:
          'Your genetics neither raise your risk of muscle injury nor '
          'protect you from it.',
        geneName: 'CCL2',
        genotype: 'GC',
        geneNote:
          'Encodes chemokine ligand 2, which signals within muscle '
          'during inflammation. Reduced levels are associated with a '
          'blunted response to acute skeletal muscle injury.',
        dos: [
          'Rest, ice, compression and elevation after an injury.',
          'Keep movement pain-free during activity.',
          'Resistance training, to make the muscle more robust.',
          'Warm up properly, and work on flexibility.',
        ],
        donts: [
          'Over-exerting a muscle that is already fatigued.',
          'Lifting well beyond what you are used to.',
          'Large jumps in load between sessions.',
        ]),

      GeneTrait(
        id: 'achilles',
        category: 'Injury risk',
        name: 'Achilles tendinopathy',
        band: GeneBand.good,
        score: 3.2,
        summary: 'You have a low risk for Achilles tendinopathy.',
        whatIs:
          'The Achilles is the thickest tendon in the body, joining the '
          'calf to the heel. Tendinopathy there is a common overuse '
          'injury in runners and jumpers, bringing ache, swelling and '
          'stiffness that is worse the day after activity.',
        interpretation:
          'A low genetic risk. Tendons with this profile tend to '
          'withstand greater physical trauma than average.',
        geneName: 'COL5A1',
        genotype: 'AA',
        geneNote:
          'COL5A1 influences production of the alpha-1 chain of type V '
          'collagen, which regulates fibril development in tendons and '
          'ligaments. Collagen composition affects how severe a soft '
          'tissue injury becomes.',
        dos: [
          'Running shoes with proper heel cushioning and firm arch '
            'support.',
          'Gentle calf and Achilles stretching before a run.',
          'Calf strengthening through resistance training.',
          'Adequate rest between sessions, and gradual progression into '
            'any new programme.',
        ],
        donts: [
          'Worn-out shoes.',
          'Skipping the warm-up, or the cool-down stretches.',
          'Training on an already sore Achilles.',
        ]),

      GeneTrait(
        id: 'rotator_cuff',
        category: 'Injury risk',
        name: 'Rotator cuff injury',
        band: GeneBand.poor,
        score: 7.2,
        summary: 'You have an elevated risk for rotator cuff injury.',
        whatIs:
          'The rotator cuff is four tendons stabilising the shoulder '
          'and holding the head of the upper arm bone in its socket. '
          'Injury ranges from a minor strain to a complete tear, '
          'usually from trauma or repetitive overhead movement.',
        interpretation:
          'Your rotator cuff tendons are not genetically predisposed to '
          'withstand great physical trauma. This is the trait in this '
          'panel most worth training around.',
        geneName: 'DEFB1',
        genotype: 'CG',
        geneNote:
          'Encodes defensin beta 1, involved in resisting microbial '
          'binding to epithelial surfaces. A variant of this gene has '
          'been associated with rotator cuff disease.',
        dos: [
          'Refine technique on overhead movements — tennis serve, '
            'military press.',
          'Warm up and stretch arms and shoulders before anything '
            'shoulder-heavy.',
          'Strengthen the shoulder through resistance training.',
          'Train the small rotator cuff muscles specifically, for '
            'example dumbbell external rotations — they are usually the '
            'neglected part.',
          'Rest properly between sessions.',
        ],
        donts: [
          'Going heavy on behind-the-neck press or behind-the-neck lat '
            'pulldown.',
          'Finishing a session without cooling down.',
        ]),

      GeneTrait(
        id: 'acl',
        category: 'Injury risk',
        name: 'Anterior cruciate ligament injury',
        band: GeneBand.poor,
        score: 6.3,
        summary:
          'You have an elevated risk for anterior cruciate ligament '
          'injury.',
        whatIs:
          'The ACL is one of four main ligaments joining thigh to shin '
          'at the knee. It stops the shin sliding forward, limits '
          'rotation and hyperextension, and resists sideways force. '
          'Tears usually happen on sudden stops, jumps or direction '
          'changes, and repair means surgery and six to nine months out.',
        interpretation:
          'Your genotype suggests an ACL less able to withstand large '
          'physical trauma. Landing mechanics matter more for you than '
          'for most people.',
        geneName: 'COL12A1',
        genotype: 'AA',
        geneNote:
          'Encodes chains of type XII collagen, a major component of '
          'ACL collagen. Variants have been associated with ACL tears '
          'across several populations.',
        dos: [
          'A full warm-up before play.',
          'Stretch thighs, calves and hips afterwards, with attention '
            'to anything tight.',
          'Squats and lunges, so the knee has support on impact.',
        ],
        donts: [
          'Letting the knees collapse inward on landing.',
          'Stopping dead out of a jump — bleed the momentum off by '
            'letting the knees bend softly.',
        ]),

      GeneTrait(
        id: 'tennis_elbow',
        category: 'Injury risk',
        name: 'Tennis elbow',
        band: GeneBand.poor,
        score: 7.0,
        summary: 'You have an elevated risk for tennis elbow.',
        whatIs:
          'Lateral elbow tendinopathy: the outer elbow becomes painful '
          'and tender when the tendons there are overloaded by '
          'repetitive wrist and arm motion. Gripping through a racket '
          'swing is the classic cause, but any repetitive motion does '
          'it.',
        interpretation:
          'The tendons on the outside of your elbow are not '
          'predisposed to withstand large physical trauma.',
        geneName: 'COL5A1',
        genotype: 'TC',
        geneNote:
          'A different COL5A1 genotype from the one behind your '
          'Achilles result, affecting type V collagen and therefore '
          'the fibril structure of tendons and ligaments.',
        dos: [
          'Perfect the technique of the movement itself — racket swing '
            'form, for instance.',
          'Warm up and gently stretch the arm beforehand.',
          'Strengthen the forearm through resistance training.',
          'Rest between sessions and cool down afterwards.',
        ],
        donts: [
          'Beginning or ending a session without warm-up and cool-down.',
          'Using a racket or tool heavier than you need.',
          'Pushing through elbow soreness.',
        ]),

      GeneTrait(
        id: 'concussion',
        category: 'Injury risk',
        name: 'Concussion',
        band: GeneBand.typical,
        score: 5.6,
        summary: 'You have a typical risk for concussion.',
        whatIs:
          'A concussion is temporary loss of consciousness or confusion '
          'from a blow to the head or violent shaking. Some symptoms '
          'start at once, others days later. Neurons stay vulnerable '
          'after symptoms resolve, and a second impact during that '
          'window can do permanent damage.',
        interpretation:
          'An average propensity for concussion and an average rate of '
          'recovery from one.',
        geneName: 'COMT',
        genotype: 'AG',
        geneNote:
          'Catechol-O-methyltransferase breaks down the catecholamine '
          'neurotransmitters — dopamine, epinephrine and '
          'norepinephrine — and is also important in the metabolism of '
          'catechol drugs.',
        dos: [
          'Wear head protection wherever it applies.',
          'Learn the symptoms — an unreported concussion is the '
            'dangerous one, because the next impact lands on vulnerable '
            'tissue.',
          'Strengthen the neck and shoulders.',
        ],
        donts: [
          'Returning to activity as soon as symptoms clear. Get medical '
            'clearance first.',
        ]),

      // ── EXERCISE RESPONSE ─────────────────────────────
      GeneTrait(
        id: 'muscle_recovery',
        category: 'Exercise response',
        name: 'Muscle damage and recovery',
        band: GeneBand.poor,
        score: 6.3,
        summary: 'Your muscle damage and recovery profile is poor.',
        whatIs:
          'Training damages muscle, inflammation repairs it, and that '
          'inflammation is what soreness is. How much damage a session '
          'causes and how fast you clear it decides how hard and how '
          'often you can train.',
        interpretation:
          'This genotype tends towards significant muscle damage during '
          'exercise and slow recovery afterwards. High volume with '
          'short rests will leave you sore for longer than it would '
          'leave most people.',
        geneName: 'ACE',
        genotype: 'AA',
        geneNote:
          'The ACE genotype appears again here. The same variant that '
          'shapes endurance and power also influences the inflammatory '
          'response to training.',
        dos: [
          'Three to four sessions a week rather than more, and take the '
            'rest day when you are sore.',
          'Low to moderate volume, with proper rest between sets.',
          'Deep tissue massage for soreness.',
        ],
        donts: [
          'High-intensity training at high frequency. If you do it, '
            'keep volume and frequency low.',
          'High-volume sessions.',
          'Poor form, and poor nutrition — both slow recovery further.',
        ]),

      GeneTrait(
        id: 'fat_loss',
        category: 'Exercise response',
        name: 'Fat loss response to exercise',
        band: GeneBand.poor,
        score: 7.5,
        summary: 'Your fat loss response to exercise is poor.',
        whatIs:
          'Stored fat is broken into free fatty acids, carried to '
          'muscle and oxidised for energy. How efficiently that chain '
          'runs during exercise varies genetically, and it decides how '
          'much fat a given amount of training actually shifts.',
        interpretation:
          'This genotype uses fat inefficiently as a fuel during '
          'exercise, so training alone tends to move body fat less than '
          'it does for others. Diet does the heavier lifting for you.',
        geneName: 'ADRB3',
        genotype: 'AA',
        geneNote:
          'Encodes the beta-3 adrenergic receptor, found mainly in fat '
          'tissue. It regulates fat breakdown and heat production; '
          'reduced function slows the mobilisation of fat from cells.',
        dos: [
          'Put the emphasis on the diet rather than the session.',
          'Protein and fibre, which hold hunger off.',
          'Weight training four times a week — more muscle raises the '
            'metabolic floor.',
        ],
        donts: [
          'Relying on long cardio sessions for fat loss; they are not '
            'efficient for you.',
          'High-calorie, fried and sugary foods.',
        ]),

      GeneTrait(
        id: 'muscle_building',
        category: 'Exercise response',
        name: 'Resistance training and muscle building',
        band: GeneBand.poor,
        score: 7.8,
        summary:
          'Your response to resistance training and muscle building is '
          'poor.',
        whatIs:
          'Muscle is the body\'s main site of fat burning and glucose '
          'uptake, and more of it improves insulin sensitivity, '
          'strength, immunity and injury resistance. It is built by '
          'resistance training plus enough protein and energy — but how '
          'readily is partly genetic.',
        interpretation:
          'This genotype builds muscle slowly despite consistent '
          'resistance training. Progress comes, but it takes deliberate '
          'attention to both diet and programming rather than volume '
          'alone.',
        geneName: 'ACE',
        genotype: 'AA',
        geneNote:
          'The third trait in this panel driven by the same ACE '
          'variant. One genotype is doing a lot of work across your '
          'results, which is why several of them point the same way.',
        dos: [
          'Weight training at least three days a week, hitting every '
            'muscle group weekly.',
          'Cardio alongside, to manage fat during a building phase.',
          'Hit the daily protein target — meal timing matters far less '
            'than the total.',
          'Eat in a slight surplus.',
        ],
        donts: [
          'Excessive cardio while trying to build.',
          'Dropping protein on rest days.',
          'Neglecting complex carbohydrates and healthy fats.',
        ]),

      // ── FLEXIBILITY ───────────────────────────────────
      GeneTrait(
        id: 'flexibility',
        category: 'Flexibility',
        name: 'Flexibility',
        band: GeneBand.typical,
        score: 5.0,
        summary: 'Your genetic profile indicates typical flexibility.',
        whatIs:
          'Flexibility is the range of motion available at a joint. It '
          'depends on sex, age, training, temperature and the '
          'elasticity of the surrounding ligaments, tendons and '
          'muscles — elasticity that collagen controls, which is where '
          'the genetic link comes in.',
        interpretation:
          'No predisposition either way. Your musculoskeletal system is '
          'neither more nor less flexible than average before training.',
        geneName: 'COL5A1',
        genotype: 'TC',
        geneNote:
          'The same COL5A1 genotype behind your tennis elbow result. '
          'Type V collagen regulates fibril development in tendons and '
          'ligaments, and therefore how elastic they are.',
        dos: [
          'Stretching sessions, warmed up first with ten to fifteen '
            'minutes of light jogging.',
          'Dynamic stretches before static ones.',
          'Yoga or pilates.',
        ],
        donts: [
          'Overstretching — it causes dislocations, muscle pulls and '
            'tendon injuries.',
          'Poor form while stretching.',
        ]),
    ]);
}
