import 'package:flutter/material.dart';
import '../theme/bmh_tokens.dart';

class BMHTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BMHTabBar({
    super.key, required this.currentIndex, required this.onTap,
  });

  static const _tabs = [
    (label: 'Home',     icon: _HomeIcon()),
    (label: 'Health',   icon: _HealthIcon()),
    (label: 'Wellness', icon: _WellnessIcon()),
    (label: 'Body',     icon: _BodyIcon()),
    (label: 'Profile',  icon: _ProfileIcon()),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Fade from transparent to dark — exact match to design
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0005091B), Color(0xF202060F)],
          stops: [0.0, 0.5],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final active = i == currentIndex;
              final tab = _tabs[i];
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Active indicator bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 2,
                        width: active ? 28 : 0,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: BMHColors.cyan,
                          borderRadius: BorderRadius.circular(1),
                          boxShadow: active ? BMHShadows.cyan : [],
                        ),
                      ),
                      // Icon
                      IconTheme(
                        data: IconThemeData(
                          color: active ? BMHColors.cyan : BMHColors.inkMute,
                          size: 20,
                        ),
                        child: tab.icon,
                      ),
                      const SizedBox(height: 4),
                      // Label
                      Text(
                        tab.label,
                        style: BMHText.monoSm.copyWith(
                          fontSize: 9,
                          letterSpacing: 0.15,
                          color: active ? BMHColors.cyan : BMHColors.inkMute,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// SVG-accurate icons from the HTML design
class _HomeIcon extends StatelessWidget {
  const _HomeIcon();
  @override
  Widget build(BuildContext context) => Icon(Icons.home_outlined, color: IconTheme.of(context).color);
}
class _HealthIcon extends StatelessWidget {
  const _HealthIcon();
  @override
  Widget build(BuildContext context) => Icon(Icons.monitor_heart_outlined, color: IconTheme.of(context).color);
}
class _BodyIcon extends StatelessWidget {
  const _BodyIcon();
  @override
  Widget build(BuildContext context) => Icon(Icons.accessibility_new_outlined, color: IconTheme.of(context).color);
}
class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon();
  @override
  Widget build(BuildContext context) => Icon(Icons.directions_bike_outlined, color: IconTheme.of(context).color);
}
class _WellnessIcon extends StatelessWidget {
  const _WellnessIcon();
  @override
  Widget build(BuildContext context) => Icon(Icons.self_improvement_rounded, color: IconTheme.of(context).color);
}
class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon();
  @override
  Widget build(BuildContext context) => Icon(Icons.person_outline_rounded, color: IconTheme.of(context).color);
}
