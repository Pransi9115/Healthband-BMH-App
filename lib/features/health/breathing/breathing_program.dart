// ─────────────────────────────────────────────────────────
//  BREATHING PROGRAM MODEL
//  All 6 breathing programs with patterns & session tracking
// ─────────────────────────────────────────────────────────

enum MoodLevel {
  stressed(label: 'Stressed'),
  anxious(label: 'Anxious'),
  neutral(label: 'Neutral'),
  calm(label: 'Calm');

  final String label;
  const MoodLevel({required this.label});
}

class BreathingProgram {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int inhaleSeconds;
  final int holdSeconds;
  final int exhaleSeconds;
  final int restSeconds;
  final List<int> durationOptions; // minutes

  const BreathingProgram({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.inhaleSeconds,
    required this.holdSeconds,
    required this.exhaleSeconds,
    required this.restSeconds,
    required this.durationOptions,
  });

  int get cycleDurationSeconds =>
      inhaleSeconds + holdSeconds + exhaleSeconds + restSeconds;

  int getCyclesForDuration(int minutes) {
    int totalSeconds = minutes * 60;
    return (totalSeconds / cycleDurationSeconds).floor();
  }

  static const List<BreathingProgram> allPrograms = [
    BreathingProgram(
      id: 'calm',
      name: 'Calm Breathing',
      description: 'For relaxation and stress reduction',
      icon: '🧘',
      inhaleSeconds: 4,
      holdSeconds: 2,
      exhaleSeconds: 6,
      restSeconds: 0,
      durationOptions: [2, 5, 10],
    ),
    BreathingProgram(
      id: 'box',
      name: 'Box Breathing',
      description: 'For control and mental clarity',
      icon: '📊',
      inhaleSeconds: 4,
      holdSeconds: 4,
      exhaleSeconds: 4,
      restSeconds: 4,
      durationOptions: [3, 5, 10],
    ),
    BreathingProgram(
      id: 'sleep',
      name: 'Sleep Breathing',
      description: 'For winding down before rest',
      icon: '🌙',
      inhaleSeconds: 4,
      holdSeconds: 7,
      exhaleSeconds: 8,
      restSeconds: 0,
      durationOptions: [5, 10, 15],
    ),
    BreathingProgram(
      id: 'anxiety',
      name: 'Anxiety Reset',
      description: 'For nervous system balance',
      icon: '⚡',
      inhaleSeconds: 3,
      holdSeconds: 2,
      exhaleSeconds: 6,
      restSeconds: 0,
      durationOptions: [1, 3, 5],
    ),
    BreathingProgram(
      id: 'focus',
      name: 'Focus Breathing',
      description: 'For improving concentration',
      icon: '🎯',
      inhaleSeconds: 5,
      holdSeconds: 2,
      exhaleSeconds: 5,
      restSeconds: 0,
      durationOptions: [3, 5, 7],
    ),
    BreathingProgram(
      id: 'recovery',
      name: 'Recovery Breathing',
      description: 'For post-exercise recovery',
      icon: '💪',
      inhaleSeconds: 6,
      holdSeconds: 3,
      exhaleSeconds: 6,
      restSeconds: 0,
      durationOptions: [5, 10, 15],
    ),
  ];

  static BreathingProgram getById(String id) {
    return allPrograms.firstWhere((p) => p.id == id);
  }
}

class BreathingSession {
  final String programId;
  final int durationMinutes;
  final MoodLevel moodBefore;
  final DateTime startTime;
  DateTime? endTime;
  MoodLevel? moodAfter;
  int cyclesCompleted;

  BreathingSession({
    required this.programId,
    required this.durationMinutes,
    required this.moodBefore,
    required this.startTime,
    this.cyclesCompleted = 0,
    this.endTime,
    this.moodAfter,
  });

  int get elapsedSeconds => DateTime.now().difference(startTime).inSeconds;
  int get totalSeconds => durationMinutes * 60;
  int get remainingSeconds => (totalSeconds - elapsedSeconds).clamp(0, totalSeconds);
  bool get isComplete => remainingSeconds == 0;
  int get progressPercent => ((elapsedSeconds / totalSeconds) * 100).toInt().clamp(0, 100);

  String get programName => BreathingProgram.getById(programId).name;
}
