// ─────────────────────────────────────────────────────────
//  GLP-1 CHECK-IN — RESULT
//
//  Shows what the rules engine decided and what the patient should
//  do about it.
//
//  THE IMPORTANT PART
//  There is no backend yet, so nothing in this app has told anyone
//  that this patient is unwell. This screen therefore never says a
//  care team has been notified, never says help is on the way, and
//  never tells the patient they are safe. On a red result it says
//  plainly that they must seek help themselves and not wait for a
//  reply here. That wording comes straight from section 20 of the
//  build spec, which requires exactly this when an assessment cannot
//  reach the care team.
//
//  It also never names a condition. The rules engine recognises
//  symptom patterns; a diagnosis is a clinician's job.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/theme/bmh_tokens.dart';
import '../../core/glp1/glp1_models.dart';
import 'glp1_widgets.dart';

class Glp1ResultScreen extends StatelessWidget {
  final RiskResult result;
  final Assessment assessment;

  /// Set once a clinical configuration service exists and an
  /// assessment has actually been transmitted. Until then the screen
  /// must not imply anyone has been told.
  final bool deliveredToCareTeam;

  const Glp1ResultScreen({
    super.key,
    required this.result,
    required this.assessment,
    this.deliveredToCareTeam = false,
  });

  bool get _isUrgent => result.level == RiskLevel.red;

  @override
  Widget build(BuildContext context) {
    final c = riskColor(result.level);

    return PopScope(
      // On an urgent result the patient must acknowledge before the
      // screen can be dismissed.
      canPop: !_isUrgent,
      child: Scaffold(
        backgroundColor: _isUrgent
            ? const Color(0xFF2A0A0A)
            : BMHColors.bg0,
        body: SafeArea(child: Column(children: [
          Expanded(child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.s5, vertical: 20),
            children: [
              // ── STATUS ────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.withOpacity(_isUrgent ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(BMHRadius.xl),
                  border: Border.all(color: c, width: _isUrgent ? 2 : 1)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(riskIcon(result.level), color: c, size: 28),
                      const SizedBox(width: 12),
                      // Never colour alone: the state is written out.
                      Expanded(child: Text(result.level.label,
                        style: BMHText.heading2.copyWith(color: c))),
                    ]),
                    const SizedBox(height: 14),
                    Text(result.patientMessage,
                      style: BMHText.bodyMd.copyWith(
                        fontSize: 15,
                        color: BMHColors.ink,
                        height: 1.55)),
                  ])),

              // ── URGENT ACTIONS ────────────────────────
              if (_isUrgent) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BMHColors.bg0.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(
                      color: BMHColors.danger.withOpacity(0.5))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This app cannot call for help',
                        style: BMHText.labelLg.copyWith(
                          fontSize: 14,
                          color: BMHColors.danger,
                          fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        'Your answers have been saved on this phone only. '
                        'No one has been contacted for you. Please call '
                        'the emergency number for your country, or your '
                        'prescribing clinic, now.',
                        style: BMHText.bodySm.copyWith(
                          fontSize: 13,
                          color: BMHColors.ink2,
                          height: 1.55)),
                    ])),
                const SizedBox(height: 12),
                Glp1Button(
                  label: 'Call emergency services',
                  icon: Icons.phone_in_talk_rounded,
                  color: BMHColors.danger,
                  onTap: () => _showCallSheet(context)),
              ],

              // ── WHY ───────────────────────────────────
              if (result.triggered.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text('WHAT WE NOTICED',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 10, letterSpacing: 0.9,
                    color: BMHColors.inkMute)),
                const SizedBox(height: 10),
                for (final t in result.topRules.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.only(top: 7, right: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: riskColor(t.risk))),
                        Expanded(child: Text(t.clinicianMessage,
                          style: BMHText.bodySm.copyWith(
                            fontSize: 13,
                            color: BMHColors.ink2,
                            height: 1.5))),
                      ])),
              ],

              // ── CARRIED RISK ──────────────────────────
              if (result.carriedRisk != null) ...[
                const SizedBox(height: 16),
                _Note(
                  icon: Icons.history_rounded,
                  text: 'An earlier symptom has not been marked as '
                      'resolved, so your status stays at '
                      '${result.carriedRisk!.label.toLowerCase()} until '
                      'your care team reviews it.'),
              ],

              // ── INCOMPLETE ────────────────────────────
              if (!result.isComplete) ...[
                const SizedBox(height: 16),
                _Note(
                  icon: Icons.help_outline_rounded,
                  text: 'Some required answers are missing, so your '
                      'check-in could not be fully assessed.'),
              ],

              // ── DELIVERY STATUS ───────────────────────
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: BMHColors.bg2,
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(color: BMHColors.line)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      deliveredToCareTeam
                          ? Icons.cloud_done_outlined
                          : Icons.phone_iphone_rounded,
                      size: 15, color: BMHColors.inkDim),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      deliveredToCareTeam
                          ? 'Sent to your care team.'
                          : 'Saved on this phone. This check-in has not '
                            'been sent to your care team.',
                      style: BMHText.bodySm.copyWith(
                        fontSize: 12,
                        color: BMHColors.inkDim,
                        height: 1.45))),
                  ])),

              const SizedBox(height: 14),
              Text(
                'This check-in records the symptoms you reported. It is '
                'not a diagnosis and does not replace advice from your '
                'clinician.',
                style: BMHText.bodySm.copyWith(
                  fontSize: 11, color: BMHColors.inkMute, height: 1.5)),
              const SizedBox(height: 8),
              Text('Ruleset ${result.rulesetVersion}',
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkFaint)),
              const SizedBox(height: 30),
            ])),

          // ── CLOSE ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BMHSpacing.s5, 0, BMHSpacing.s5, 16),
            child: Glp1Button(
              label: _isUrgent
                  ? 'I understand, I will seek help now'
                  : 'Done',
              color: _isUrgent ? BMHColors.bg4 : BMHColors.cyan,
              onTap: () => Navigator.of(context)
                  .popUntil((r) => r.isFirst))),
        ])),
      ));
  }

  /// Emergency numbers vary by country and must come from clinical
  /// configuration before release. Until that exists, the patient is
  /// asked to dial rather than being given a number that might be
  /// wrong for where they are.
  void _showCallSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BMHColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BMHRadius.xl))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call for help', style: BMHText.heading2),
            const SizedBox(height: 10),
            Text(
              'Dial your local emergency number now, or call your '
              'prescribing clinic if you have been told to contact them '
              'first.',
              style: BMHText.bodyMd.copyWith(
                fontSize: 14, color: BMHColors.ink2, height: 1.55)),
            const SizedBox(height: 18),
            Text(
              'Emergency numbers differ by country. Use the number for '
              'the country you are in right now.',
              style: BMHText.bodySm.copyWith(
                fontSize: 12, color: BMHColors.inkDim, height: 1.5)),
            const SizedBox(height: 20),
            Glp1Button(
              label: 'Copy my symptoms to share',
              icon: Icons.copy_rounded,
              color: BMHColors.bg4,
              onTap: () {
                Clipboard.setData(ClipboardData(text: _shareText()));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Symptom summary copied'),
                  backgroundColor: BMHColors.bg4));
              }),
            const SizedBox(height: 10),
          ])));
  }

  /// A short factual summary the patient can read out or paste when
  /// they call. Reported symptoms only, no interpretation.
  String _shareText() {
    final b = StringBuffer();
    b.writeln('GLP-1 symptom check-in');
    b.writeln(DateTime.now().toIso8601String());
    b.writeln('Status: ${result.level.label}');
    for (final t in result.topRules) {
      b.writeln('- ${t.clinicianMessage}');
    }
    if (result.modifiers.isNotEmpty) {
      b.writeln('On record: ${result.modifiers.join(", ")}');
    }
    b.writeln('These are patient-reported symptoms, not a diagnosis.');
    return b.toString();
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: BMHColors.bg2,
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(color: BMHColors.line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: BMHColors.warn),
          const SizedBox(width: 10),
          Expanded(child: Text(text,
            style: BMHText.bodySm.copyWith(
              fontSize: 12.5, color: BMHColors.ink2, height: 1.5))),
        ]));
}
