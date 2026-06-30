import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
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
  final VoidCallback onTap;

  const _DeviceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isConnected,
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
              BMHPill('Connected', type: BMHPillType.success)
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
  static _MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainShellState>();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  void switchTab(int index) => setState(() => _currentIndex = index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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

  static const _teal = Color(0xFF00c8c8);
  static const _navBg = Color(0xFF050b16);

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.monitor_heart_rounded, Icons.monitor_heart_outlined, 'Health'),
    (Icons.self_improvement_rounded, Icons.self_improvement_outlined, 'Wellness'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080f1e),
      body: IndexedStack(index: _currentIndex, children: _screens),
      extendBody: true,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _navBg,
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.06),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (i) {
                final active = i == _currentIndex;
                final item = _items[i];
                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: active
                        ? const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8)
                        : const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? _teal : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          active ? item.$1 : item.$2,
                          color: active
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          size: 22,
                        ),
                        if (active) ...[
                          const SizedBox(width: 6),
                          Text(
                            item.$3,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
