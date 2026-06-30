import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../home/home_screen.dart';
import '../health/health_screen.dart';
import '../body/ble/ble_intro_screen.dart';
import '../wellness/wellness_screen.dart';
import '../profile/profile_screen.dart';
import '../body/ble/device_management_screen.dart';
import '../body/body_track_screen.dart';
import '../../core/ble/ble_service.dart';

// ─────────────────────────────────────────────────────────
//  KEEP ALIVE WRAPPER
// ─────────────────────────────────────────────────────────
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ─────────────────────────────────────────────────────────
//  BODY SCREEN
// ─────────────────────────────────────────────────────────
class _BodyScreen extends StatefulWidget {
  const _BodyScreen();
  @override
  State<_BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<_BodyScreen>
    with AutomaticKeepAliveClientMixin {
  final _ble = BleService.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onBle);
  }

  void _onBle() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ble.removeListener(_onBle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF080f1e),
      body: Stack(
        children: [
          Positioned(
            top: -180,
            left: -120,
            child: Container(
              width: 480,
              height: 480,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BMHColors.sBody.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: BMHSpacing.screenH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BMHEyebrow('Body track',
                              showDot: _ble.isBandConnected),
                          const SizedBox(height: 4),
                          Text('Body', style: BMHText.heading1),
                        ],
                      ),
                      BMHIconButton(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DeviceManagementScreen(),
                          ),
                        ),
                        icon: Icon(
                          Icons.bluetooth_rounded,
                          color: _ble.isBandConnected
                              ? BMHColors.sGut
                              : BMHColors.cyan,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Body Track card — subtitle removed
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BodyTrackScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            BMHColors.sGut.withOpacity(0.10),
                            BMHColors.sGut.withOpacity(0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(BMHRadius.lg),
                        border: Border.all(
                          color: BMHColors.sGut.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BMHEyebrow('Body composition'),
                                const SizedBox(height: 8),
                                Text.rich(
                                  TextSpan(
                                    style: BMHText.heading2
                                        .copyWith(fontFamily: 'Fraunces'),
                                    children: const [
                                      TextSpan(text: 'View '),
                                      TextSpan(
                                        text: 'Body Track',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: BMHColors.sGut,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // REMOVED: Weight · Fat · Muscle · BMI · Water
                              ],
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: BMHColors.sGut,
                              shape: BoxShape.circle,
                              boxShadow: BMHShadows.glow(BMHColors.sGut),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: BMHColors.bg0,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  BMHSectionTitle('Connect your devices'),
                  const SizedBox(height: 14),

                  // Health Band — chips removed
                  _DeviceCard(
                    title: 'Health Band',
                    subtitle: 'Continuous monitoring',
                    icon: Icons.watch_outlined,
                    color: BMHColors.sCardio,
                    isConnected: _ble.isBandConnected,
                    battery: _ble.isBandConnected ? _ble.battery : 0,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ble.isBandConnected
                            ? const DeviceManagementScreen()
                            : const BleIntroScreen(isScale: false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // BioScale — chips removed
                  _DeviceCard(
                    title: 'BioScale',
                    subtitle: 'Body composition',
                    icon: Icons.monitor_weight_outlined,
                    color: BMHColors.sGut,
                    isConnected: _ble.isScaleConnected,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BleIntroScreen(isScale: true),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: BMHColors.cyanSoft,
                      borderRadius: BorderRadius.circular(BMHRadius.md),
                      border: Border.all(color: BMHColors.lineBright),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: BMHColors.cyan, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Devices reconnect automatically when in range.',
                            style: BMHText.bodySm
                                .copyWith(color: BMHColors.inkDim),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  DEVICE CARD — no feature chips
// ─────────────────────────────────────────────────────────
class _DeviceCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final bool isConnected;
  final int battery;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isConnected,
    this.battery = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isConnected ? color.withOpacity(0.06) : BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(
            color: isConnected ? color.withOpacity(0.3) : BMHColors.line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: color.withOpacity(0.28)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BMHText.heading2),
                  const SizedBox(height: 3),
                  Text(
                    subtitle.toUpperCase(),
                    style: BMHText.monoSm.copyWith(
                      color: BMHColors.inkMute,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            if (isConnected)
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (battery > 0) ...[
                  Icon(
                    battery > 70
                        ? Icons.battery_full_rounded
                        : battery > 30
                            ? Icons.battery_4_bar_rounded
                            : Icons.battery_1_bar_rounded,
                    color: battery > 20 ? BMHColors.sGut : BMHColors.danger,
                    size: 14,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$battery%',
                    style: BMHText.monoSm.copyWith(
                      fontSize: 10,
                      color: battery > 20 ? BMHColors.inkDim : BMHColors.danger,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                BMHPill('Connected', type: BMHPillType.success),
              ])
            else
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  MAIN SHELL — Style C bottom nav (teal + white)
// ─────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();

  /// Switch to a tab from anywhere: MainShell.of(context)?.switchTab(1)
  /// Only works when [context] is a descendant of MainShell's own widget
  /// tree (i.e. one of the 4 tab screens themselves).
  static _MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainShellState>();

  /// Jump to a tab from ANY screen, including ones pushed on top of
  /// MainShell via Navigator.push (detail/sub-screens). Pops back down
  /// to the MainShell route, then switches tab on it. Used by
  /// [BMHGlobalNav] so the 4 main tabs are reachable everywhere.
  static void goToTab(BuildContext context, int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _MainShellState._instance?.switchTab(index);
  }
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  // Stable reference to the live MainShell state — MainShell is the root
  // screen of the app and stays mounted (just hidden) under any pushed
  // routes, so this is safe to use from goToTab() above.
  static _MainShellState? _instance;

  void switchTab(int index) => setState(() => _currentIndex = index);

  @override
  void initState() {
    super.initState();
    _instance = this;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Auto-reconnect BLE when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final ble = BleService.instance;
      if (!ble.isBandConnected && ble.lastBandDevice != null) {
        ble.autoReconnect();
      }
    }
  }

  late final List<Widget> _screens = [
    const _KeepAlive(child: HomeScreen()),
    const _KeepAlive(child: HealthScreen()),
    const _KeepAlive(child: WellnessScreen()),
    const _KeepAlive(child: ProfileScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080f1e),
      body: IndexedStack(index: _currentIndex, children: _screens),
      extendBody: true,
      bottomNavigationBar: BMHGlobalNav(activeIndex: _currentIndex),
    );
  }
}
