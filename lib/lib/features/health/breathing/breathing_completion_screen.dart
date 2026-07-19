import 'package:flutter/material.dart';
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import '../../../shared/widgets/bmh_global_nav.dart';
import 'breathing_program.dart';

// ─────────────────────────────────────────────────────────
//  BREATHING COMPLETION SCREEN - RESULTS (NO CHANGES)
//  Session results & mood check-in
// ─────────────────────────────────────────────────────────

class BreathingCompletionScreen extends StatefulWidget {
  final BreathingSession session;
  final int cyclesCompleted;

  const BreathingCompletionScreen({
    super.key,
    required this.session,
    required this.cyclesCompleted,
  });

  @override
  State<BreathingCompletionScreen> createState() =>
      _BreathingCompletionScreenState();
}

class _BreathingCompletionScreenState extends State<BreathingCompletionScreen> {
  MoodLevel? _moodAfter;

  void _saveMoodAndClose() {
    if (_moodAfter != null) {
      widget.session.moodAfter = _moodAfter;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = BreathingProgram.getById(widget.session.programId);
    final moodImprovement = _calculateMoodImprovement();

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      appBar: AppBar(
        backgroundColor: BMHColors.bg0,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text('✓ Results',
          style: BMHText.heading2.copyWith(fontSize: 18)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Success Badge
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: BMHColors.sGut.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(color: BMHColors.sGut.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                      color: BMHColors.sGut, size: 18),
                    const SizedBox(width: 8),
                    Text('Session completed!',
                      style: BMHText.bodySm.copyWith(color: BMHColors.sGut)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Celebration
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: BMHColors.line),
                ),
                child: Column(
                  children: [
                    Text(program.icon, style: const TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Text('Excellent!',
                      style: BMHText.heading1.copyWith(fontSize: 24)),
                    const SizedBox(height: 6),
                    Text('You completed your session',
                      style: BMHText.bodySm.copyWith(color: BMHColors.ink2),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Session Summary
              Text('Summary', style: BMHText.heading2.copyWith(fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: BMHColors.line),
                ),
                child: Column(
                  children: [
                    _summaryRow('Program', program.name),
                    Divider(color: BMHColors.line, height: 12),
                    _summaryRow('Duration', '${widget.session.durationMinutes} min'),
                    Divider(color: BMHColors.line, height: 12),
                    _summaryRow('Cycles', '${widget.cyclesCompleted}'),
                    Divider(color: BMHColors.line, height: 12),
                    _summaryRow('Mood Before', widget.session.moodBefore.label),
                    if (_moodAfter != null)
                      Column(
                        children: [
                          Divider(color: BMHColors.line, height: 12),
                          _summaryRow('Mood After', _moodAfter!.label),
                          if (moodImprovement.isNotEmpty) ...[
                            Divider(color: BMHColors.line, height: 12),
                            _summaryRow('Status', moodImprovement,
                              color: BMHColors.sGut),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Mood Check-in
              if (_moodAfter == null) ...[
                Text('How do you feel now?',
                  style: BMHText.heading2.copyWith(fontSize: 16)),
                const SizedBox(height: 12),
                ...MoodLevel.values.map((mood) {
                  final isSelected = _moodAfter == mood;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _moodAfter = mood);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? BMHColors.bg3 : BMHColors.surface,
                          borderRadius: BorderRadius.circular(BMHRadius.lg),
                          border: Border.all(
                            color: isSelected ? BMHColors.cyan : BMHColors.line,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(mood.label, style: BMHText.bodyMd),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                color: BMHColors.cyan, size: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => setState(() => _moodAfter = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: BMHColors.surface,
                        borderRadius: BorderRadius.circular(BMHRadius.md),
                        border: Border.all(color: BMHColors.line),
                      ),
                      child: Text('Change Mood',
                        textAlign: TextAlign.center,
                        style: BMHText.bodyMd.copyWith(color: BMHColors.ink2, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Action Buttons
              if (_moodAfter != null)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: BMHColors.surface,
                            borderRadius: BorderRadius.circular(BMHRadius.md),
                            border: Border.all(color: BMHColors.line),
                          ),
                          child: Text('Dashboard',
                            textAlign: TextAlign.center,
                            style: BMHText.bodyMd.copyWith(
                              color: BMHColors.ink2, 
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _saveMoodAndClose,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: BMHColors.cyan,
                            borderRadius: BorderRadius.circular(BMHRadius.md),
                          ),
                          child: Text('Save & Close',
                            textAlign: TextAlign.center,
                            style: BMHText.bodyMd.copyWith(
                              color: BMHColors.bg0,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _saveMoodAndClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: BMHColors.cyan,
                        borderRadius: BorderRadius.circular(BMHRadius.md),
                      ),
                      child: Text('Continue',
                        textAlign: TextAlign.center,
                        style: BMHText.bodyMd.copyWith(
                          color: BMHColors.bg0,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 2),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
        Text(value,
          style: BMHText.bodySm.copyWith(
            color: color ?? BMHColors.cyan,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _calculateMoodImprovement() {
    if (widget.session.moodBefore.index > _moodAfter!.index) {
      return '✓ Improved';
    } else if (widget.session.moodBefore.index == _moodAfter!.index) {
      return '→ Stable';
    }
    return '';
  }
}
