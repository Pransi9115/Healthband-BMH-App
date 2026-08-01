// ─────────────────────────────────────────────────────────
//  GLP-1 MONITORING — DOMAIN MODELS
//
//  Every clinical decision in this module comes from a versioned
//  ruleset file, never from Dart. These types are the vocabulary
//  the ruleset is written in; they carry no thresholds, no
//  question wording and no risk logic of their own.
//
//  The audit fields on Response exist because a carried forward
//  answer and an answer the patient gave today are not the same
//  clinical evidence, and a reviewing clinician has to be able to
//  tell them apart months later.
// ─────────────────────────────────────────────────────────

// ── RISK ──────────────────────────────────────────────────
enum RiskLevel { green, yellow, orange, red, undetermined }

extension RiskLevelX on RiskLevel {
  String get key => switch (this) {
        RiskLevel.green => 'green',
        RiskLevel.yellow => 'yellow',
        RiskLevel.orange => 'orange',
        RiskLevel.red => 'red',
        RiskLevel.undetermined => 'undetermined',
      };

  String get label => switch (this) {
        RiskLevel.green => 'Stable',
        RiskLevel.yellow => 'Monitor',
        RiskLevel.orange => 'Clinical review',
        RiskLevel.red => 'Urgent assessment',
        RiskLevel.undetermined => 'Unable to determine',
      };

  /// Ordering used when combining today's result with an unresolved
  /// one carried over. Undetermined deliberately outranks yellow:
  /// not knowing is worse than knowing it is mild.
  int get severity => switch (this) {
        RiskLevel.green => 0,
        RiskLevel.yellow => 1,
        RiskLevel.undetermined => 2,
        RiskLevel.orange => 3,
        RiskLevel.red => 4,
      };

  bool get needsClinician =>
      this == RiskLevel.orange ||
      this == RiskLevel.red ||
      this == RiskLevel.undetermined;

  static RiskLevel parse(String s) => switch (s) {
        'yellow' => RiskLevel.yellow,
        'orange' => RiskLevel.orange,
        'red' => RiskLevel.red,
        'undetermined' => RiskLevel.undetermined,
        _ => RiskLevel.green,
      };
}

/// Picks whichever of two levels is more serious.
RiskLevel maxRisk(RiskLevel a, RiskLevel b) =>
    a.severity >= b.severity ? a : b;

// ── HOW THE PATIENT ENTERED TODAY'S CHECK-IN ─────────────
enum CheckInMode { baseline, same, edit, significant }

extension CheckInModeX on CheckInMode {
  String get key => switch (this) {
        CheckInMode.baseline => 'baseline',
        CheckInMode.same => 'same',
        CheckInMode.edit => 'edit',
        CheckInMode.significant => 'significant',
      };

  static CheckInMode parse(String s) => switch (s) {
        'baseline' => CheckInMode.baseline,
        'edit' => CheckInMode.edit,
        'significant' => CheckInMode.significant,
        _ => CheckInMode.same,
      };
}

// ── QUESTION ──────────────────────────────────────────────
enum QuestionType { single, scale, number, text, date }

QuestionType _parseType(String s) => switch (s) {
      'scale' => QuestionType.scale,
      'number' => QuestionType.number,
      'text' => QuestionType.text,
      'date' => QuestionType.date,
      _ => QuestionType.single,
    };

class AnswerOption {
  final String label;
  final num value;

  /// True for answers like "I am not sure". These never count as a
  /// negative: an uncertain answer to a safety question routes to
  /// Unable to Determine rather than quietly passing as No.
  final bool uncertain;

  /// Only set on the change-mode question, naming the flow to enter.
  final String? mode;

  const AnswerOption({
    required this.label,
    required this.value,
    this.uncertain = false,
    this.mode,
  });

  factory AnswerOption.fromJson(Map<String, dynamic> j) => AnswerOption(
        label: j['label'] as String,
        value: j['value'] as num,
        uncertain: j['uncertain'] as bool? ?? false,
        mode: j['mode'] as String?,
      );
}

class Question {
  final String id;
  final String section;
  final String text;
  final QuestionType type;
  final List<AnswerOption> options;
  final num? min;
  final num? max;
  final String? unit;

  /// Condition controlling whether this question is shown at all.
  final Map<String, dynamic>? showIf;

  /// Must be actively answered before the check-in can be submitted.
  final bool mandatory;

  /// Safety questions. Copying one of these forward from yesterday
  /// would mean claiming the patient denied a red flag today when
  /// they were never asked, so it is forbidden outright.
  final bool neverCarryForward;

  const Question({
    required this.id,
    required this.section,
    required this.text,
    required this.type,
    this.options = const [],
    this.min,
    this.max,
    this.unit,
    this.showIf,
    this.mandatory = false,
    this.neverCarryForward = false,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        section: j['section'] as String,
        text: j['text'] as String,
        type: _parseType(j['type'] as String),
        options: ((j['options'] as List?) ?? [])
            .map((o) => AnswerOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        min: j['min'] as num?,
        max: j['max'] as num?,
        unit: j['unit'] as String?,
        showIf: j['show_if'] as Map<String, dynamic>?,
        mandatory: j['mandatory'] as bool? ?? false,
        neverCarryForward: j['never_carry_forward'] as bool? ?? false,
      );

  bool get isBaseline => section.startsWith('baseline');
  bool get isSafety => section == 'safety';
  bool get isOpener => section == 'opener';

  /// The label the patient saw for a stored value, for the
  /// "yesterday said X" line and the change summary.
  String labelFor(num? v) {
    if (v == null) return 'Not answered';
    for (final o in options) {
      if (o.value == v) return o.label;
    }
    if (type == QuestionType.scale) return '$v out of ${max ?? 10}';
    return v.toString();
  }

  bool isUncertain(num? v) {
    if (v == null) return false;
    for (final o in options) {
      if (o.value == v) return o.uncertain;
    }
    return false;
  }
}

// ── RULE ──────────────────────────────────────────────────
class ClinicalRule {
  final String id;
  final String version;
  final String name;
  final RiskLevel risk;
  final Map<String, dynamic> when;
  final Map<String, dynamic>? unless;
  final String patientMessage;
  final String clinicianMessage;
  final String action;
  final int priority;
  final List<String> tags;
  final String? approvedBy;
  final String? approvalDate;

  const ClinicalRule({
    required this.id,
    required this.version,
    required this.name,
    required this.risk,
    required this.when,
    required this.patientMessage,
    required this.clinicianMessage,
    required this.action,
    required this.priority,
    this.unless,
    this.tags = const [],
    this.approvedBy,
    this.approvalDate,
  });

  factory ClinicalRule.fromJson(Map<String, dynamic> j) => ClinicalRule(
        id: j['id'] as String,
        version: j['version'] as String? ?? '1.0.0',
        name: j['name'] as String,
        risk: RiskLevelX.parse(j['risk'] as String),
        when: j['when'] as Map<String, dynamic>,
        unless: j['unless'] as Map<String, dynamic>?,
        patientMessage: j['patient_message'] as String? ?? '',
        clinicianMessage: j['clinician_message'] as String? ?? '',
        action: j['action'] as String? ?? 'monitor',
        priority: j['priority'] as int? ?? 3,
        tags: ((j['tags'] as List?) ?? []).cast<String>(),
        approvedBy: j['approved_by'] as String?,
        approvalDate: j['approval_date'] as String?,
      );

  bool get isApproved => approvedBy != null && approvalDate != null;
}

class RiskModifier {
  final String id;
  final String label;
  final String question;
  final String op;
  final num value;
  final int weight;

  const RiskModifier({
    required this.id,
    required this.label,
    required this.question,
    required this.op,
    required this.value,
    required this.weight,
  });

  factory RiskModifier.fromJson(Map<String, dynamic> j) => RiskModifier(
        id: j['id'] as String,
        label: j['label'] as String,
        question: j['q'] as String,
        op: j['op'] as String,
        value: j['value'] as num,
        weight: j['weight'] as int,
      );
}

// ── RESPONSE ──────────────────────────────────────────────
class Response {
  final String questionId;
  final num? value;
  final String? textValue;

  /// What this question held in the assessment it was copied from.
  final num? previousValue;

  /// True when the value came from a previous assessment rather than
  /// from the patient answering today.
  final bool carriedForward;

  /// True when the patient edited a pre-populated value.
  final bool manuallyChanged;

  final DateTime answeredAt;

  const Response({
    required this.questionId,
    this.value,
    this.textValue,
    this.previousValue,
    this.carriedForward = false,
    this.manuallyChanged = false,
    required this.answeredAt,
  });

  bool get isAnswered => value != null || (textValue?.isNotEmpty ?? false);

  Response copyWith({
    num? value,
    String? textValue,
    num? previousValue,
    bool? carriedForward,
    bool? manuallyChanged,
    DateTime? answeredAt,
  }) =>
      Response(
        questionId: questionId,
        value: value ?? this.value,
        textValue: textValue ?? this.textValue,
        previousValue: previousValue ?? this.previousValue,
        carriedForward: carriedForward ?? this.carriedForward,
        manuallyChanged: manuallyChanged ?? this.manuallyChanged,
        answeredAt: answeredAt ?? this.answeredAt,
      );

  Map<String, dynamic> toJson() => {
        'q': questionId,
        if (value != null) 'v': value,
        if (textValue != null) 'txt': textValue,
        if (previousValue != null) 'prev': previousValue,
        'cf': carriedForward,
        'mc': manuallyChanged,
        't': answeredAt.millisecondsSinceEpoch,
      };

  factory Response.fromJson(Map<String, dynamic> j) => Response(
        questionId: j['q'] as String,
        value: j['v'] as num?,
        textValue: j['txt'] as String?,
        previousValue: j['prev'] as num?,
        carriedForward: j['cf'] as bool? ?? false,
        manuallyChanged: j['mc'] as bool? ?? false,
        answeredAt: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
      );
}

// ── A FIRED RULE ──────────────────────────────────────────
class TriggeredRule {
  final String ruleId;
  final String ruleVersion;
  final String name;
  final RiskLevel risk;
  final String patientMessage;
  final String clinicianMessage;
  final String action;
  final List<String> tags;

  const TriggeredRule({
    required this.ruleId,
    required this.ruleVersion,
    required this.name,
    required this.risk,
    required this.patientMessage,
    required this.clinicianMessage,
    required this.action,
    required this.tags,
  });

  Map<String, dynamic> toJson() => {
        'id': ruleId, 'ver': ruleVersion, 'name': name,
        'risk': risk.key, 'pm': patientMessage, 'cm': clinicianMessage,
        'action': action, 'tags': tags,
      };

  factory TriggeredRule.fromJson(Map<String, dynamic> j) => TriggeredRule(
        ruleId: j['id'] as String,
        ruleVersion: j['ver'] as String? ?? '1.0.0',
        name: j['name'] as String,
        risk: RiskLevelX.parse(j['risk'] as String),
        patientMessage: j['pm'] as String? ?? '',
        clinicianMessage: j['cm'] as String? ?? '',
        action: j['action'] as String? ?? 'monitor',
        tags: ((j['tags'] as List?) ?? []).cast<String>(),
      );
}

// ── RISK RESULT ───────────────────────────────────────────
class RiskResult {
  final RiskLevel level;

  /// The level today's answers produced on their own, before any
  /// unresolved risk from earlier days was folded in.
  final RiskLevel calculatedLevel;

  /// Set when an unresolved Orange or Red from a previous day raised
  /// today's level. Recorded so a clinician can see why.
  final RiskLevel? carriedRisk;

  final List<TriggeredRule> triggered;
  final List<String> modifiers;
  final int modifierScore;
  final String rulesetVersion;
  final List<String> missingMandatory;

  const RiskResult({
    required this.level,
    required this.calculatedLevel,
    this.carriedRisk,
    required this.triggered,
    required this.modifiers,
    required this.modifierScore,
    required this.rulesetVersion,
    this.missingMandatory = const [],
  });

  bool get isComplete => missingMandatory.isEmpty;

  /// Highest-priority patient message among the rules that fired.
  String get patientMessage {
    if (triggered.isEmpty) {
      return 'Your check-in has been recorded. Report any new or '
          'worsening symptoms.';
    }
    final top = [...triggered]
      ..sort((a, b) => b.risk.severity.compareTo(a.risk.severity));
    return top.first.patientMessage;
  }

  List<TriggeredRule> get topRules {
    final t = [...triggered]
      ..sort((a, b) => b.risk.severity.compareTo(a.risk.severity));
    return t;
  }

  bool hasTag(String tag) => triggered.any((t) => t.tags.contains(tag));

  Map<String, dynamic> toJson() => {
        'level': level.key,
        'calc': calculatedLevel.key,
        if (carriedRisk != null) 'carried': carriedRisk!.key,
        'rules': triggered.map((t) => t.toJson()).toList(),
        'mods': modifiers,
        'modScore': modifierScore,
        'rsv': rulesetVersion,
        'missing': missingMandatory,
      };

  factory RiskResult.fromJson(Map<String, dynamic> j) => RiskResult(
        level: RiskLevelX.parse(j['level'] as String),
        calculatedLevel: RiskLevelX.parse(
            j['calc'] as String? ?? j['level'] as String),
        carriedRisk: j['carried'] == null
            ? null
            : RiskLevelX.parse(j['carried'] as String),
        triggered: ((j['rules'] as List?) ?? [])
            .map((r) => TriggeredRule.fromJson(r as Map<String, dynamic>))
            .toList(),
        modifiers: ((j['mods'] as List?) ?? []).cast<String>(),
        modifierScore: j['modScore'] as int? ?? 0,
        rulesetVersion: j['rsv'] as String? ?? '0',
        missingMandatory: ((j['missing'] as List?) ?? []).cast<String>(),
      );
}

// ── ASSESSMENT ────────────────────────────────────────────
class Assessment {
  final String id;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final CheckInMode mode;

  /// The assessment this one copied its answers from, if any.
  final String? sourceAssessmentId;

  final Map<String, Response> responses;
  final RiskResult? risk;
  final String rulesetVersion;
  final bool isWeeklyReview;

  /// Cleared by a clinician, or by the patient actively reporting
  /// improvement. Until then an Orange or Red keeps carrying.
  final bool resolved;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  const Assessment({
    required this.id,
    required this.startedAt,
    this.submittedAt,
    required this.mode,
    this.sourceAssessmentId,
    required this.responses,
    this.risk,
    required this.rulesetVersion,
    this.isWeeklyReview = false,
    this.resolved = false,
    this.resolvedAt,
    this.resolvedBy,
  });

  bool get isSubmitted => submittedAt != null;

  DateTime get day => DateTime(startedAt.year, startedAt.month, startedAt.day);

  num? valueOf(String qid) => responses[qid]?.value;

  /// Fields the patient actually edited today, for the change summary.
  List<Response> get changed =>
      responses.values.where((r) => r.manuallyChanged).toList();

  Assessment copyWith({
    DateTime? submittedAt,
    Map<String, Response>? responses,
    RiskResult? risk,
    bool? resolved,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) =>
      Assessment(
        id: id,
        startedAt: startedAt,
        submittedAt: submittedAt ?? this.submittedAt,
        mode: mode,
        sourceAssessmentId: sourceAssessmentId,
        responses: responses ?? this.responses,
        risk: risk ?? this.risk,
        rulesetVersion: rulesetVersion,
        isWeeklyReview: isWeeklyReview,
        resolved: resolved ?? this.resolved,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        resolvedBy: resolvedBy ?? this.resolvedBy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': startedAt.millisecondsSinceEpoch,
        if (submittedAt != null)
          'sub': submittedAt!.millisecondsSinceEpoch,
        'mode': mode.key,
        if (sourceAssessmentId != null) 'src': sourceAssessmentId,
        'resp': responses.values.map((r) => r.toJson()).toList(),
        if (risk != null) 'risk': risk!.toJson(),
        'rsv': rulesetVersion,
        'weekly': isWeeklyReview,
        'resolved': resolved,
        if (resolvedAt != null) 'resAt': resolvedAt!.millisecondsSinceEpoch,
        if (resolvedBy != null) 'resBy': resolvedBy,
      };

  factory Assessment.fromJson(Map<String, dynamic> j) {
    final list = ((j['resp'] as List?) ?? [])
        .map((r) => Response.fromJson(r as Map<String, dynamic>));
    return Assessment(
      id: j['id'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(j['start'] as int),
      submittedAt: j['sub'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(j['sub'] as int),
      mode: CheckInModeX.parse(j['mode'] as String? ?? 'same'),
      sourceAssessmentId: j['src'] as String?,
      responses: {for (final r in list) r.questionId: r},
      risk: j['risk'] == null
          ? null
          : RiskResult.fromJson(j['risk'] as Map<String, dynamic>),
      rulesetVersion: j['rsv'] as String? ?? '0',
      isWeeklyReview: j['weekly'] as bool? ?? false,
      resolved: j['resolved'] as bool? ?? false,
      resolvedAt: j['resAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(j['resAt'] as int),
      resolvedBy: j['resBy'] as String?,
    );
  }
}

// ── A SINGLE FIELD CHANGE, FOR THE SUMMARY SCREEN ─────────
class FieldChange {
  final Question question;
  final num? from;
  final num? to;

  const FieldChange({
    required this.question,
    required this.from,
    required this.to,
  });

  /// "Nausea increased from 3 to 7"
  String get sentence {
    final a = question.labelFor(from);
    final b = question.labelFor(to);
    if (from != null && to != null && question.type == QuestionType.scale) {
      final dir = to! > from! ? 'increased' : 'decreased';
      return '${question.text.replaceAll('?', '')} $dir from $from to $to';
    }
    return '${question.text.replaceAll('?', '')}: $a → $b';
  }

  bool get isWorse => (to ?? 0) > (from ?? 0);
}
