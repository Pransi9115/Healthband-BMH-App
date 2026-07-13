import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/auth/auth_service.dart';
import '../../core/ble/ble_service.dart';
import '../home/main_shell.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: BMHColors.bg0,
    ));
    _logoCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    );
    _textCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _animate();
  }

  Future<void> _animate() async {
    // Validate the stored session while the logo animates —
    // no extra wait is added to the splash.
    final sessionCheck = AuthService.instance.hasValidSession();

    await Future.delayed(const Duration(milliseconds: 300));
    await _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    await _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 900));

    final loggedIn = await sessionCheck;
    if (!mounted) return;

    if (loggedIn) {
      // Returning user → straight to Home, no Login screen.
      // Also silently reconnect the previously paired band.
      BleService.instance.tryAutoReconnect();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            loggedIn ? const MainShell() : const WelcomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: Stack(
        children: [
          // Ambient cyan glow — top left
          Positioned(
            top: -200, left: -200,
            child: Container(
              width: 600, height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  BMHColors.cyan.withOpacity(0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // Centre content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── LOGO ────────────────────────────────
                // Uses the official Bio Health Care lockup from
                // assets. Falls back to the original scan-line
                // mark if the asset is not bundled yet.
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Image.asset(
                      'assets/images/bio_health_care_logo.png',
                      width: 300,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          color: BMHColors.bg1,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: BMHColors.lineBright),
                          boxShadow: BMHShadows.cyan,
                        ),
                        child: const Center(
                          child: BMHScanLineFigure(
                            width: 42, height: 64, opacity: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── TAGLINE ─────────────────────────────
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        // Tagline
                        Text(
                          'THE FUTURE DOESN\'T HAVE TO BE UNPREDICTABLE',
                          style: BMHText.monoSm.copyWith(
                            fontSize: 8,
                            letterSpacing: 0.32 * 8,
                            color: BMHColors.inkDim,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Version bottom
          Positioned(
            bottom: 44, left: 0, right: 0,
            child: FadeTransition(
              opacity: _textFade,
              child: Text(
                'v1.0.0',
                textAlign: TextAlign.center,
                style: BMHText.monoSm.copyWith(fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
