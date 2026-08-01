// ─────────────────────────────────────────────────────────
//  GLP-1 DAILY CHECK-IN
//
//  The flow described in sections 1 to 7 of the build spec:
//
//    opener      how are you feeling, versus yesterday, what changed
//    same        yesterday's answers copied forward
//    edit        yesterday's answers pre-filled and editable
//    significant urgent screen first, then the pre-filled questions
//    baseline    the full assessment, first time only
//
//  Whichever route is taken, the safety screen is always answered
//  fresh and can never be skipped. A carried-forward "No" to a red
//  flag would be a record of the patient denying a symptom they were
//  never asked about, so those questions are excluded from carry
//  forward in the ruleset and re-asked here every time.
//
//  Question order, wording, branching and thresholds all come from
//  the ruleset. This file decides what happens next, not what is
//  asked.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/glp1/glp1_models.dart';
import '../../core/glp1/glp1_ruleset.dart';
import '../../core/glp1/glp1_risk_engine.dart';
import '../../core/glp1/glp1_service.dart';
import 'glp1_widgets.dart';
import 'glp1_result_screen.dart';

enum _Stage { loading, opener, urgent, questions, summary, safety }

class Glp1CheckInScreen extends StatefulWidget {
  const Glp1CheckInScreen({super.key});
  @override
  State<Glp1CheckInScreen> createState() => _Glp1CheckInScreenState();
}

class _Glp1CheckInScreenState extends State<Glp1CheckInScreen> {
  final _svc = Glp1Service.instance;

  _Stage _stage = _Stage.loading;
  Assessment? _a;
  Assessment? _previous;

  /// Opener questions answered so far, before the mode is chosen.
  int _openerIndex = 0;

  /// Index into the question list for the current stage.
  int _qIndex = 0;
  List<Question> _queue = [];
  bool _submitting = false;
  String? _error;

  Ruleset get _rs => _svc.ruleset;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await _svc.init();
      _previous = _svc.latest;
      setState(() {
        _a = _svc.startFresh(
            _svc.hasBaseline ? CheckInMode.same : CheckInMode.baseline);
        _stage = _Stage.opener;
      });
    } catch (e) {
      setState(() {
        _error = 'The check-in could not be loaded. Please try again, '
            'and contact your care team if you feel unwell.';
        _stage = _Stage.opener;
      });
    }
  }

  // ── ANSWERING ───────────────────────────────────────────
  void _set(String qid, {num? value, String? text}) {
    setState(() => _a = _svc.answer(_a!, qid, value: value, text: text));
  }

  num? _val(String qid) => _a?.responses[qid]?.value;

  num? _yesterdayFor(String qid) {
    final r = _a?.responses[qid];
    if (r != null && r.carriedForward) return r.previousValue;
    return _previous?.responses[qid]?.value;
  }

  /// Questions to ask, recomputed each time so branching reacts to
  /// what has just been answered.
  List<Question> _visible() {
    final src = AssessmentAnswerSource(_a!);
    final baseline = _a!.mode == CheckInMode.baseline;
    return _rs.questions.where((q) {
      if (q.isOpener) return false;
      if (q.isSafety) return false; // asked in its own stage
      if (q.isBaseline && !baseline) return false;
      return _rs.shouldShow(q, src);
    }).toList();
  }

  // ── OPENER → MODE ───────────────────────────────────────
  void _onOpenerAnswered(Question q, num v) {
    _set(q.id, value: v);

    final openers = _rs.openerQuestions;
    if (q.id != 'change_mode') {
      if (_openerIndex < openers.length - 1) {
        setState(() => _openerIndex++);
      }
      return;
    }

    // Mode chosen — rebuild the assessment on the right footing.
    final opt = q.options.firstWhere((o) => o.value == v,
        orElse: () => q.options.first);
    var mode = CheckInModeX.parse(opt.mode ?? 'same');
    if (!_svc.hasBaseline) mode = CheckInMode.baseline;

    final opener = <String, Response>{
      for (final o in openers)
        if (_a!.responses[o.id] != null) o.id: _a!.responses[o.id]!,
    };

    var next = mode == CheckInMode.baseline
        ? _svc.startFresh(mode)
        : (mode == CheckInMode.same || mode == CheckInMode.edit ||
                mode == CheckInMode.significant
            ? _svc.startCarriedForward(mode)
            : _svc.startFresh(mode));

    next = next.copyWith(
      responses: {...next.responses, ...opener},
    );

    setState(() {
      _a = next;
      _qIndex = 0;
      switch (mode) {
        case CheckInMode.same:
          // Straight to the safety screen: nothing else to ask.
          _stage = _Stage.safety;
        case CheckInMode.significant:
          _stage = _Stage.urgent;
        case CheckInMode.edit:
          _queue = _visible();
          _stage = _Stage.questions;
        case CheckInMode.baseline:
          _queue = _visible();
          _stage = _Stage.questions;
      }
    });
  }

  // ── SAFETY SCREEN ───────────────────────────────────────
  void _onSafetyAnswered(Question q, num v) {
    _set(q.id, value: v);
    final list = _rs.safetyQuestions;
    final i = list.indexWhere((x) => x.id == q.id);
    if (i < list.length - 1) {
      setState(() => _qIndex = i + 1);
    }
  }

  bool get _safetyComplete =>
      _rs.safetyQuestions.every((q) => _val(q.id) != null);

  // ── URGENT SCREEN (significant change) ──────────────────
  void _onUrgentDone() {
    // Emergency screen runs before any routine question, so a red
    // flag short-circuits the rest of the questionnaire.
    final r = _svc.engine.evaluateUrgentOnly(_a!);
    if (r.level == RiskLevel.red) {
      _finish();
      return;
    }
    setState(() {
      _queue = _visible();
      _qIndex = 0;
      _stage = _Stage.questions;
    });
  }

  // ── QUESTION STAGE ──────────────────────────────────────
  void _nextQuestion() {
    // Recompute: an answer may have opened or closed a branch.
    final q = _queue.isEmpty ? null : _queue[_qIndex];
    final fresh = _visible();
    var idx = q == null ? 0 : fresh.indexWhere((x) => x.id == q.id) + 1;
    if (idx < 0) idx = 0;

    if (idx >= fresh.length) {
      setState(() {
        _queue = fresh;
        _stage = _a!.mode == CheckInMode.baseline
            ? _Stage.safety
            : _Stage.summary;
        _qIndex = 0;
      });
      return;
    }
    setState(() {
      _queue = fresh;
      _qIndex = idx;
    });
  }

  void _prevQuestion() {
    if (_qIndex > 0) {
      setState(() => _qIndex--);
    } else {
      setState(() => _stage = _Stage.opener);
    }
  }

  // ── SUBMIT ──────────────────────────────────────────────
  Future<void> _finish() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    // Always the full evaluation: the urgent pass only checks red
    // rules, so submitting on its result alone would lose carried
    // risk and any orange finding.
    final result = await _svc.submit(_a!);

    if (!mounted) return;
    await Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => Glp1ResultScreen(result: result, assessment: _a!)));
  }

  // ── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: SafeArea(child: Column(children: [
        _header(),
        Expanded(child: _body()),
      ])));
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BMHSpacing.s5, 8, BMHSpacing.s5, 4),
      child: Row(children: [
        BMHIconButton(
          onTap: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded,
            color: BMHColors.ink, size: 16)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BMHEyebrow('GLP-1 MONITORING'),
            Text('Daily check-in', style: BMHText.heading2),
          ])),
      ]));
  }

  Widget _body() {
    if (_error != null) return _errorView();
    if (_stage == _Stage.loading || _a == null) {
      return const Center(child: CircularProgressIndicator(
        strokeWidth: 2, color: BMHColors.cyan));
    }
    return switch (_stage) {
      _Stage.opener => _openerView(),
      _Stage.urgent => _urgentView(),
      _Stage.questions => _questionView(),
      _Stage.summary => _summaryView(),
      _Stage.safety => _safetyView(),
      _Stage.loading => const SizedBox.shrink(),
    };
  }

  Widget _errorView() => Padding(
    padding: const EdgeInsets.all(BMHSpacing.s5),
    child: Column(children: [
      const SizedBox(height: 40),
      const Icon(Icons.error_outline_rounded,
        color: BMHColors.warn, size: 40),
      const SizedBox(height: 16),
      Text(_error!, textAlign: TextAlign.center,
        style: BMHText.bodyMd.copyWith(
          color: BMHColors.ink2, height: 1.55)),
      const Spacer(),
      Glp1Button(label: 'Close', onTap: () => Navigator.pop(context)),
    ]));

  // ── OPENER ──────────────────────────────────────────────
  Widget _openerView() {
    final openers = _rs.openerQuestions;
    if (openers.isEmpty) return const SizedBox.shrink();
    final i = _openerIndex.clamp(0, openers.length - 1);
    final q = openers[i];

    // The mode question is only meaningful once there is a previous
    // assessment to carry forward from.
    if (q.id == 'change_mode' && !_svc.hasBaseline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final first = q.options.firstWhere((o) => o.mode == 'baseline',
            orElse: () => q.options.last);
        _onOpenerAnswered(q, first.value);
      });
      return const Center(child: CircularProgressIndicator(
        strokeWidth: 2, color: BMHColors.cyan));
    }

    return _scaffoldQuestion(
      step: i + 1,
      total: openers.length,
      question: q,
      onBack: i == 0 ? null : () => setState(() => _openerIndex--),
      child: Glp1OptionList(
        question: q,
        value: _val(q.id),
        onChanged: (v) => _onOpenerAnswered(q, v)),
    );
  }

  // ── URGENT (significant change) ─────────────────────────
  Widget _urgentView() {
    final list = _rs.safetyQuestions;
    final i = _qIndex.clamp(0, list.length - 1);
    final q = list[i];
    final answered = list.every((x) => _val(x.id) != null);

    return _scaffoldQuestion(
      step: i + 1,
      total: list.length,
      question: q,
      banner: 'Before anything else, a few urgent symptom checks.',
      onBack: i == 0 ? null : () => setState(() => _qIndex--),
      footer: answered
          ? Glp1Button(label: 'Continue', onTap: _onUrgentDone)
          : null,
      child: Glp1OptionList(
        question: q,
        value: _val(q.id),
        onChanged: (v) => _onSafetyAnswered(q, v)),
    );
  }

  // ── SAFETY ──────────────────────────────────────────────
  Widget _safetyView() {
    final list = _rs.safetyQuestions;
    final i = _qIndex.clamp(0, list.length - 1);
    final q = list[i];

    final carried =
        _a!.responses.values.where((r) => r.carriedForward).length;

    return _scaffoldQuestion(
      step: i + 1,
      total: list.length,
      question: q,
      banner: _a!.mode == CheckInMode.same && carried > 0
          ? 'We have carried forward yesterday\u2019s answers. Please '
            'confirm you are not experiencing any new urgent symptoms.'
          : 'These questions are asked fresh every day.',
      onBack: i == 0 ? null : () => setState(() => _qIndex--),
      footer: _safetyComplete
          ? Glp1Button(
              label: _submitting ? 'Saving…' : 'Submit check-in',
              onTap: _submitting ? null : () => _finish())
          : null,
      child: Glp1OptionList(
        question: q,
        value: _val(q.id),
        onChanged: (v) => _onSafetyAnswered(q, v)),
    );
  }

  // ── QUESTIONS ───────────────────────────────────────────
  Widget _questionView() {
    if (_queue.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _nextQuestion());
      return const SizedBox.shrink();
    }
    final i = _qIndex.clamp(0, _queue.length - 1);
    final q = _queue[i];
    final y = _yesterdayFor(q.id);
    final r = _a!.responses[q.id];
    final changed = r?.manuallyChanged ?? false;

    Widget input;
    switch (q.type) {
      case QuestionType.scale:
        input = Glp1Scale(
          question: q, value: _val(q.id), yesterday: y,
          onChanged: (v) => _set(q.id, value: v));
      case QuestionType.number:
        input = Glp1Number(
          question: q, value: _val(q.id),
          onChanged: (v) => _set(q.id, value: v));
      case QuestionType.text:
        input = Glp1Text(
          value: r?.textValue,
          onChanged: (s) => _set(q.id, text: s));
      case QuestionType.date:
        input = Glp1Number(
          question: q, value: _val(q.id),
          onChanged: (v) => _set(q.id, value: v));
      case QuestionType.single:
        input = Glp1OptionList(
          question: q, value: _val(q.id), yesterday: y,
          onChanged: (v) {
            _set(q.id, value: v);
            Future.delayed(const Duration(milliseconds: 180), () {
              if (mounted) _nextQuestion();
            });
          });
    }

    return _scaffoldQuestion(
      step: i + 1,
      total: _queue.length,
      question: q,
      yesterdayLabel: y == null ? null : q.labelFor(y),
      changed: changed,
      onBack: _prevQuestion,
      footer: Glp1Button(
        label: i == _queue.length - 1 ? 'Review changes' : 'Next',
        onTap: _nextQuestion),
      child: input,
    );
  }

  // ── CHANGE SUMMARY ──────────────────────────────────────
  Widget _summaryView() {
    final changes = _svc.engine.changesIn(_a!);

    return Column(children: [
      Expanded(child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: BMHSpacing.s5, vertical: 12),
        children: [
          Text('Changes reported today', style: BMHText.heading2),
          const SizedBox(height: 8),
          Text(
            changes.isEmpty
                ? 'You have not changed any answers. Yesterday\u2019s '
                  'responses will be recorded again for today.'
                : 'Please check these are correct before you submit.',
            style: BMHText.bodySm.copyWith(
              fontSize: 13, color: BMHColors.inkDim, height: 1.5)),
          const SizedBox(height: 18),
          for (final c in changes)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BMHColors.bg2,
                borderRadius: BorderRadius.circular(BMHRadius.md),
                border: Border.all(
                  color: c.isWorse
                      ? BMHColors.warn.withOpacity(0.5)
                      : BMHColors.line)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    c.isWorse
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 16,
                    color: c.isWorse
                        ? BMHColors.warn : BMHColors.success),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.sentence,
                    style: BMHText.bodySm.copyWith(
                      fontSize: 13, color: BMHColors.ink, height: 1.45))),
                ])),
        ])),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          BMHSpacing.s5, 0, BMHSpacing.s5, 16),
        child: Glp1Button(
          // Significant-change mode already answered the safety
          // screen up front; do not make the patient repeat it.
          label: _safetyComplete
              ? 'These changes are correct, submit'
              : 'These changes are correct',
          onTap: _submitting
              ? null
              : () {
                  if (_safetyComplete) {
                    _finish();
                  } else {
                    setState(() {
                      _stage = _Stage.safety;
                      _qIndex = 0;
                    });
                  }
                })),
    ]);
  }

  // ── SHARED QUESTION LAYOUT ──────────────────────────────
  Widget _scaffoldQuestion({
    required int step,
    required int total,
    required Question question,
    required Widget child,
    String? banner,
    String? yesterdayLabel,
    bool changed = false,
    VoidCallback? onBack,
    Widget? footer,
  }) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BMHSpacing.s5, vertical: 10),
        child: Glp1Progress(step: step, total: total)),
      Expanded(child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: BMHSpacing.s5),
        children: [
          if (banner != null) ...[
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: BMHColors.cyanFaint,
                borderRadius: BorderRadius.circular(BMHRadius.md),
                border: Border.all(color: BMHColors.lineBright)),
              child: Text(banner,
                style: BMHText.bodySm.copyWith(
                  fontSize: 12.5, color: BMHColors.ink2, height: 1.5))),
            const SizedBox(height: 18),
          ],
          Text(question.text,
            style: BMHText.heading2.copyWith(fontSize: 21, height: 1.35)),
          if (yesterdayLabel != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Text('Yesterday: $yesterdayLabel',
                style: BMHText.monoSm.copyWith(
                  fontSize: 11, color: BMHColors.inkDim)),
              if (changed) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BMHColors.warn.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(BMHRadius.full)),
                  child: Text('Changed today',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9, color: BMHColors.warn,
                      fontWeight: FontWeight.w700))),
              ],
            ]),
          ],
          const SizedBox(height: 22),
          child,
          const SizedBox(height: 30),
        ])),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          BMHSpacing.s5, 0, BMHSpacing.s5, 16),
        child: Row(children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 54, height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BMHColors.bg2,
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(color: BMHColors.line)),
                child: const Icon(Icons.arrow_back_rounded,
                  size: 18, color: BMHColors.ink2))),
            const SizedBox(width: 10),
          ],
          if (footer != null) Expanded(child: footer),
        ])),
    ]);
  }
}
