// ─────────────────────────────────────────────────────────
//  BMH GLOBAL NAV
//  Same visual bottom tab bar as MainShell, droppable into
//  ANY screen (detail / sub-screens included) so the 4 main
//  tabs are always one tap away — no logic/data change,
//  purely a navigation convenience layered on top of the
//  existing MainShell.switchTab mechanism.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../features/home/main_shell.dart';

/// Marker placed above MainShell's IndexedStack. Any BMHGlobalNav that
/// finds this ancestor knows a nav bar is ALREADY on screen and renders
/// nothing, so a screen can safely declare its own nav without ever
/// producing two stacked tab bars.
///
/// This exists because HealthScreen declared its own nav while also
/// being a MainShell tab, which drew the bar twice. A flag fixed that
/// one case; this makes the whole class of bug impossible.
class BMHNavScope extends InheritedWidget {
  const BMHNavScope({super.key, required super.child});

  static bool navAlreadyPresent(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BMHNavScope>() != null;

  @override
  bool updateShouldNotify(BMHNavScope oldWidget) => false;
}

class BMHGlobalNav extends StatelessWidget {
  /// Index (0=Home, 1=Health, 2=Wellness, 3=Profile) to highlight as
  /// "active" on this screen. Pass null if this screen doesn't belong
  /// to one specific tab (the bar still works, just nothing is lit up).
  final int? activeIndex;

  const BMHGlobalNav({super.key, this.activeIndex});

  static const _teal = Color(0xFF00c8c8);
  static const _navBg = Color(0xFF050b16);

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.monitor_heart_rounded, Icons.monitor_heart_outlined, 'Bio Band'),
    (Icons.self_improvement_rounded, Icons.self_improvement_outlined, 'Wellness'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    // A nav bar is already on screen (we're inside a MainShell tab) —
    // draw nothing rather than stacking a second bar.
    if (BMHNavScope.navAlreadyPresent(context)) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: _navBg,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final active = i == activeIndex;
              final item = _items[i];
              return GestureDetector(
                onTap: () => MainShell.goToTab(context, i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? _teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? item.$1 : item.$2,
                        color: active ? Colors.white : Colors.white.withOpacity(0.4),
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active
                              ? Colors.white
                              : Colors.white.withOpacity(0.45),
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
