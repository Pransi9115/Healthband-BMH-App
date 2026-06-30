import 'package:flutter/material.dart';
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import '../../../shared/widgets/bmh_global_nav.dart';
import 'breathing_program.dart';
import 'breathing_session_screen.dart';

// ─────────────────────────────────────────────────────────
//  BREATHING SCREEN - HOME & PROGRAM SELECTION
//  Browse programs, select mood, then start session
// ─────────────────────────────────────────────────────────

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  BreathingProgram? _selectedProgram;
  MoodLevel? _moodBefore;
  int? _selectedDuration;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _startSession() {
    if (_selectedProgram != null && _moodBefore != null && _selectedDuration != null) {
      final session = BreathingSession(
        programId: _selectedProgram!.id,
        durationMinutes: _selectedDuration!,
        moodBefore: _moodBefore!,
        startTime: DateTime.now(),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BreathingSessionScreen(session: session),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      appBar: AppBar(
        backgroundColor: BMHColors.bg0,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BMHColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: BMHColors.line),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 14, color: BMHColors.ink),
          ),
        ),
        title: Text('⚕️ Breathing Exercises',
          style: BMHText.heading2.copyWith(fontSize: 16)),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildProgramsPage(),
          _buildMoodPage(),
          _buildDurationPage(),
        ],
      ),
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 2),
    );
  }

  // ─────────────────────────────────────────────────────────
  // PAGE 1: PROGRAM SELECTION - COMPACT VERSION
  // ─────────────────────────────────────────────────────────
  Widget _buildProgramsPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a Program',
              style: BMHText.heading2.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text('Select a guided breathing program',
              style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
            const SizedBox(height: 16),
            ...BreathingProgram.allPrograms.map((program) {
              final isSelected = _selectedProgram?.id == program.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedProgram = program);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? BMHColors.bg3 : BMHColors.surface,
                      borderRadius: BorderRadius.circular(BMHRadius.lg),
                      border: Border.all(
                        color: isSelected ? BMHColors.cyan : BMHColors.line,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(
                            color: BMHColors.bg2,
                            borderRadius: BorderRadius.circular(BMHRadius.md),
                          ),
                          child: Center(
                            child: Text(program.icon, style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(program.name, 
                                style: BMHText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(program.description,
                                style: BMHText.bodySm.copyWith(color: BMHColors.ink2),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: BMHColors.cyan,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 14, color: BMHColors.bg0),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _buildButton(
                label: 'Next: How do you feel?',
                enabled: _selectedProgram != null,
                onTap: _nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // PAGE 2: MOOD CHECK-IN (BEFORE)
  // ─────────────────────────────────────────────────────────
  Widget _buildMoodPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How do you feel?',
              style: BMHText.heading2.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text('Select your current mood',
              style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
            const SizedBox(height: 16),
            if (_selectedProgram != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: BMHColors.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: BMHColors.bg2,
                        borderRadius: BorderRadius.circular(BMHRadius.md),
                      ),
                      child: Center(
                        child: Text(_selectedProgram!.icon,
                          style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedProgram!.name, 
                            style: BMHText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                          Text(_selectedProgram!.description,
                            style: BMHText.bodySm.copyWith(color: BMHColors.ink2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ...MoodLevel.values.map((mood) {
              final isSelected = _moodBefore == mood;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _moodBefore = mood);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: BMHColors.cyan,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 14, color: BMHColors.bg0),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildButton(
                    label: 'Back',
                    secondary: true,
                    onTap: _previousPage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildButton(
                    label: 'Next: Duration',
                    enabled: _moodBefore != null,
                    onTap: _nextPage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // PAGE 3: DURATION SELECTION & START
  // ─────────────────────────────────────────────────────────
  Widget _buildDurationPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Duration',
              style: BMHText.heading2.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text('You can pause or stop anytime',
              style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
            const SizedBox(height: 16),
            if (_selectedProgram != null && _moodBefore != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: BMHColors.line),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Program', style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
                        Text(_selectedProgram!.name,
                          style: BMHText.bodySm.copyWith(color: BMHColors.cyan)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mood', style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
                        Text(_moodBefore!.label,
                          style: BMHText.bodySm.copyWith(color: BMHColors.cyan)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Duration', style: BMHText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: (_selectedProgram?.durationOptions ?? []).map((duration) {
                final isSelected = _selectedDuration == duration;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDuration = duration);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? BMHColors.cyan : BMHColors.surface,
                      borderRadius: BorderRadius.circular(BMHRadius.md),
                      border: Border.all(
                        color: isSelected ? BMHColors.cyan : BMHColors.line,
                      ),
                    ),
                    child: Text('$duration min',
                      style: BMHText.bodyMd.copyWith(
                        color: isSelected ? BMHColors.bg0 : BMHColors.ink,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_selectedDuration != null && _selectedProgram != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: BMHColors.line),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Duration', style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
                        Text('$_selectedDuration minutes',
                          style: BMHText.bodySm.copyWith(color: BMHColors.cyan)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cycles', style: BMHText.bodySm.copyWith(color: BMHColors.ink2)),
                        Text('~${_selectedProgram!.getCyclesForDuration(_selectedDuration!)} cycles',
                          style: BMHText.bodySm.copyWith(color: BMHColors.cyan)),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildButton(
                    label: 'Back',
                    secondary: true,
                    onTap: _previousPage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildButton(
                    label: 'Start →',
                    enabled: _selectedDuration != null,
                    onTap: _startSession,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    bool secondary = false,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: secondary
            ? BMHColors.surface
            : (enabled ? BMHColors.cyan : BMHColors.inkDim.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(
            color: secondary ? BMHColors.line : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(label,
            style: BMHText.bodyMd.copyWith(
              color: secondary ? BMHColors.ink : BMHColors.bg0,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
