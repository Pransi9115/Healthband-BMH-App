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
    (Icons.monitor_heart_rounded, Icons.monitor_heart_outlined, 'Health'),
    (Icons.self_improvement_rounded, Icons.self_improvement_outlined, 'Wellness'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
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
                  padding: active
                      ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
                      : const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? _teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? item.$1 : item.$2,
                        color: active ? Colors.white : Colors.white.withOpacity(0.3),
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
    );
  }
}
