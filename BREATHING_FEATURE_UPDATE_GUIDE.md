# 🌬️ BREATHING FEATURE - COMPLETE UPDATE GUIDE

## 📋 WHAT'S UPDATED

The breathing feature has been completely rebuilt from the ground up while maintaining your app's design system (BMH colors, typography, theme).

### ✅ NEW FEATURES ADDED

1. **6 Breathing Programs**
   - Calm Breathing (4-2-6)
   - Box Breathing (4-4-4-4)
   - Sleep Breathing (4-7-8)
   - Anxiety Reset (3-2-6)
   - Focus Breathing (5-2-5)
   - Recovery Breathing (6-3-6)

2. **Program Selection Screen**
   - Browse all 6 programs with descriptions
   - View breathing pattern for each
   - Select your program

3. **Pre-Session Mood Tracking**
   - Check in with current mood (Stressed, Anxious, Neutral, Calm)
   - Helps track progress

4. **Duration Selection**
   - Choose 2, 5, or 10 minutes (varies per program)
   - See estimated cycle count
   - Shows session summary before starting

5. **Active Breathing Session**
   - Animated breathing circle (expands/contracts)
   - Clock-style progress ring
   - Countdown timer per phase
   - Session elapsed/remaining time
   - Cycle counter
   - Pause/Resume/Stop controls

6. **Completion & Results Screen**
   - Success celebration
   - Session summary (program, duration, cycles)
   - Post-session mood check-in
   - Mood improvement tracking

## 📁 FILES TO UPDATE

### Location: `lib/features/health/breathing/`

**REPLACE these files:**
```
breathing_screen.dart (COMPLETELY REPLACED)
```

**ADD these NEW files:**
```
breathing_program.dart (NEW - Models & constants)
breathing_session_screen.dart (NEW - Active session)
breathing_completion_screen.dart (NEW - Results)
```

## 🔧 HOW TO UPDATE

### Step 1: Copy Files
Copy the 4 files from `/mnt/user-data/outputs/` to your project:

```
breathing_program.dart 
  → lib/features/health/breathing/breathing_program.dart

breathing_screen.dart (NEW VERSION)
  → lib/features/health/breathing/breathing_screen.dart

breathing_session_screen.dart
  → lib/features/health/breathing/breathing_session_screen.dart

breathing_completion_screen.dart
  → lib/features/health/breathing/breathing_completion_screen.dart
```

### Step 2: No Changes Needed Elsewhere
- ✅ `main.dart` - NO CHANGES
- ✅ `wellness_screen.dart` - NO CHANGES (already uses BreathingScreen)
- ✅ `pubspec.yaml` - NO CHANGES (no new dependencies)
- ✅ Theme/Colors - NO CHANGES (uses existing BMH tokens)
- ✅ Fonts - NO CHANGES (uses existing Fraunces)

### Step 3: Run Your App
```bash
cd ~/Desktop/bmh_app
flutter pub get
flutter run
```

## 🎨 DESIGN SYSTEM COMPLIANCE

✅ **Colors Used:**
- `BMHColors.bg0, bg1, bg2, bg3` - Backgrounds
- `BMHColors.cyan` - Primary accent
- `BMHColors.sOxygen` - Breathing animation
- `BMHColors.sCardio` - Pause/Stop
- `BMHColors.sGut` - Success
- `BMHColors.ink, ink2, inkMute` - Text colors
- `BMHColors.surface, line` - Surfaces & borders

✅ **Typography:**
- `BMHText.displaySm` - Large countdown (48px)
- `BMHText.heading1, heading2` - Section titles
- `BMHText.bodyLg, bodyMd, bodySm` - Body text
- `BMHText.monoSm` - Technical info

✅ **Border Radius:**
- `BMHRadius.lg` - Cards (12px)
- `BMHRadius.md` - Buttons (8px)

✅ **Theme:**
- Dark navy theme (BMHColors.bg0)
- Cyan accent color
- All existing styling maintained
- Seamless integration with app

## 📊 FEATURE BREAKDOWN

### Screen 1: Program Selection
- List all 6 programs
- Show icon, name, description, breathing pattern
- Select one (visual feedback with cyan highlight)
- Button: "Next: How do you feel?"

### Screen 2: Pre-Mood Check-in
- Show selected program details
- 4 mood options: Stressed, Anxious, Neutral, Calm
- Back/Next navigation

### Screen 3: Duration Selection
- Show selected program & mood
- Duration options (2/5/10 min)
- Display cycles estimate
- Start Breathing button

### Screen 4: Active Session
- Animated breathing circle (scale 0.6 to 1.0)
- Progress ring (clock-style, updates in real-time)
- Countdown timer (4...3...2...1)
- Current phase (Inhale/Hold/Exhale/Rest)
- Session timer (elapsed + remaining)
- Cycle counter
- Controls: Start, Pause, Resume, Stop

### Screen 5: Completion
- Success celebration with program emoji
- Session summary (program, duration, cycles)
- Pre/Post mood comparison
- Mood improvement indicator
- Post-session mood selection
- Action buttons: Dashboard / Save & Close

## ⚙️ TECHNICAL DETAILS

### State Management
- Uses `StatefulWidget` with `AnimationController`
- Page navigation with `PageController`
- Timers for clock updates
- Real-time progress calculation

### Animation
- Breathing circle scales from 0.6 to 1.0
- Progress ring draws arc based on percentage
- Smooth 300ms page transitions
- Animation based on breathing pattern duration

### Time Tracking
- `BreathingSession` class tracks elapsed/remaining
- Auto-calculates cycles based on pattern
- Session ends automatically at duration limit

## 🔴 POSSIBLE FUTURE ENHANCEMENTS

(Not included, but can be added later)
- Save sessions to local database
- View breathing history
- Sound guidance & haptic feedback
- Custom breathing programs
- Integration with health data tracking

## ✅ TESTING CHECKLIST

After copying files, test:

1. ✓ Click "Breathing" in wellness/health screen
2. ✓ See all 6 programs listed
3. ✓ Select a program and click Next
4. ✓ Select a mood (Calm, Stressed, etc.)
5. ✓ Select duration (2/5/10 min)
6. ✓ Review summary and click "Start Breathing"
7. ✓ See animated circle expanding/contracting
8. ✓ See countdown timer (4...3...2...1)
9. ✓ See progress ring filling
10. ✓ See elapsed/remaining time updating
11. ✓ Click Pause - animation stops
12. ✓ Click Resume - animation continues
13. ✓ Click Stop - goes to completion screen
14. ✓ Session auto-completes at time limit
15. ✓ Select mood after session
16. ✓ See summary with program/duration/cycles
17. ✓ Click Save & Close - returns to dashboard

## 📞 SUPPORT

All imports use relative paths based on your current project structure:
```
import '../../../shared/theme/bmh_tokens.dart';
import '../../../shared/widgets/bmh_widgets.dart';
import '../../../shared/widgets/bmh_global_nav.dart';
```

These match your existing app structure - no changes needed.

---

**Status:** ✅ Ready to integrate
**Last Updated:** June 24, 2026
**Version:** 1.0
