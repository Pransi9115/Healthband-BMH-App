import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/bmh_tokens.dart';

// ─────────────────────────────────────────────
//  SCAN-LINE BODY FIGURE (brand motif)
// ─────────────────────────────────────────────

class BMHScanLineFigure extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;
  const BMHScanLineFigure({
    super.key, this.width = 80, this.height = 120, this.opacity = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width, height: height,
      child: CustomPaint(painter: _ScanLinePainter(opacity: opacity)),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double opacity;
  _ScanLinePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BMHColors.cyan.withOpacity(opacity)
      ..strokeWidth = 1;

    // Elliptical mask via clip
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.75, height: size.height * 0.85,
      )));

    // Horizontal scan lines every 5px
    for (double y = 0; y < size.height; y += 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
//  PULSING DOT (live indicator)
// ─────────────────────────────────────────────

class BMHPulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const BMHPulsingDot({super.key, this.color = BMHColors.cyan, this.size = 7});

  @override
  State<BMHPulsingDot> createState() => _BMHPulsingDotState();
}

class _BMHPulsingDotState extends State<BMHPulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_anim.value),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color: widget.color.withOpacity(0.6 * _anim.value),
            blurRadius: 8,
          )],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EYEBROW LABEL (mono uppercase with dot)
// ─────────────────────────────────────────────

class BMHEyebrow extends StatelessWidget {
  final String text;
  final bool showDot;
  const BMHEyebrow(this.text, {super.key, this.showDot = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot) ...[
          const BMHPulsingDot(), const SizedBox(width: 8),
        ],
        Text(text.toUpperCase(), style: BMHText.eyebrow),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION TITLE (mono + divider + optional link)
// ─────────────────────────────────────────────

class BMHSectionTitle extends StatelessWidget {
  final String title;
  final String? linkLabel;
  final VoidCallback? onLink;
  const BMHSectionTitle(this.title, {super.key, this.linkLabel, this.onLink});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title.toUpperCase(), style: BMHText.monoMd),
            if (linkLabel != null)
              GestureDetector(
                onTap: onLink,
                child: Text(linkLabel!, style: BMHText.labelMd.copyWith(
                  color: BMHColors.cyan,
                  letterSpacing: 0,
                  fontSize: 11,
                )),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  ICON BUTTON (circular, blurred surface)
// ─────────────────────────────────────────────

class BMHIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final bool hasDot;
  const BMHIconButton({super.key, required this.icon, this.onTap, this.hasDot = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: BMHColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: BMHColors.line),
            ),
            child: Center(child: icon),
          ),
          if (hasDot)
            Positioned(
              top: 7, right: 7,
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: BMHColors.cyan,
                  shape: BoxShape.circle,
                  border: Border.all(color: BMHColors.bg1, width: 1.5),
                  boxShadow: [BoxShadow(color: BMHColors.cyanGlow, blurRadius: 8)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STATUS PILL
// ─────────────────────────────────────────────

enum BMHPillType { info, success, warn, danger, neutral }

class BMHPill extends StatelessWidget {
  final String label;
  final BMHPillType type;
  const BMHPill(this.label, {super.key, this.type = BMHPillType.info});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (type) {
      BMHPillType.success => (BMHColors.sGut.withOpacity(0.15), BMHColors.sGut),
      BMHPillType.warn    => (BMHColors.warn.withOpacity(0.15), BMHColors.warn),
      BMHPillType.danger  => (BMHColors.danger.withOpacity(0.15), BMHColors.danger),
      BMHPillType.neutral => (BMHColors.bg4, BMHColors.inkDim),
      BMHPillType.info    => (BMHColors.cyanSoft, BMHColors.cyan),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BMHRadius.full),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(label, style: BMHText.monoSm.copyWith(color: fg, letterSpacing: 0.2)),
    );
  }
}

// ─────────────────────────────────────────────
//  METRIC CARD (Home dashboard 2×2 grid)
// ─────────────────────────────────────────────

class BMHMetricCard extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final String trend;
  final bool trendUp;
  final Color signalColor;
  final Widget icon;
  final VoidCallback? onTap;

  const BMHMetricCard({
    super.key,
    required this.value,
    required this.unit,
    required this.label,
    required this.trend,
    required this.signalColor,
    required this.icon,
    this.trendUp = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(BMHSpacing.s4),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.lg - 2),
          border: Border.all(color: BMHColors.line),
        ),
        child: Stack(
          children: [
            // Signal top bar
            Positioned(
              top: -BMHSpacing.s4, left: -BMHSpacing.s4,
              child: Container(
                width: 80, height: 2,
                decoration: BoxDecoration(
                  color: signalColor.withOpacity(0.9),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(BMHRadius.lg - 2),
                  ),
                ),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon badge
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: BMHColors.signalBg(signalColor),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: BMHColors.signalBorder(signalColor)),
                      ),
                      child: Center(child: icon),
                    ),
                    // Trend
                    Text(
                      trend,
                      style: BMHText.monoMd.copyWith(
                        color: trendUp ? signalColor : BMHColors.inkMute,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Value
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: BMHText.displayMd.copyWith(fontSize: 30, height: 1),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: BMHText.bodyMd.copyWith(color: BMHColors.inkMute),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Label
                Text(label.toUpperCase(), style: BMHText.monoSm),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CHECK-IN CARD (hero card on Home)
// ─────────────────────────────────────────────

class BMHCheckInCard extends StatelessWidget {
  final String title;
  final bool completed;
  final VoidCallback? onTap;
  const BMHCheckInCard({
    super.key,
    this.title = 'How are you feeling today?',
    this.completed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: completed
              ? [BMHColors.sGut.withOpacity(0.10),
                 BMHColors.sGut.withOpacity(0.02)]
              : [BMHColors.cyan.withOpacity(0.12),
                 BMHColors.cyan.withOpacity(0.02)],
          ),
          borderRadius: BorderRadius.circular(BMHRadius.lg),
          border: Border.all(
            color: completed
              ? BMHColors.sGut.withOpacity(0.4)
              : BMHColors.lineBright),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BMHEyebrow(
                    completed ? 'Completed today ✓' : 'Daily check-in',
                    showDot: !completed),
                  const SizedBox(height: 8),
                  completed
                    ? Text.rich(TextSpan(
                        style: BMHText.heading2.copyWith(
                          fontFamily: 'Fraunces', fontSize: 19),
                        children: [
                          const TextSpan(text: 'Check-in '),
                          TextSpan(text: 'done',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: BMHColors.sGut)),
                          const TextSpan(text: ' for today!'),
                        ]))
                    : Text.rich(TextSpan(
                        style: BMHText.heading2.copyWith(
                          fontFamily: 'Fraunces', fontSize: 19),
                        children: [
                          const TextSpan(text: 'How are you '),
                          TextSpan(text: 'feeling',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: BMHColors.cyan)),
                          const TextSpan(text: ' today?'),
                        ])),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Stack(
              alignment: Alignment.centerRight,
              children: [
                const BMHScanLineFigure(width: 60, height: 90, opacity: 0.3),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: completed ? BMHColors.sGut : BMHColors.cyan,
                    shape: BoxShape.circle,
                    boxShadow: BMHShadows.cyan,
                  ),
                  child: Icon(
                    completed ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    color: BMHColors.bg0, size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MODULE CARD (expandable, Home modules list)
// ─────────────────────────────────────────────

class BMHModuleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final Color signalColor;
  final Widget? expandedContent;
  final VoidCallback? onTap;
  final bool initiallyOpen;

  const BMHModuleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.signalColor,
    this.expandedContent,
    this.onTap,
    this.initiallyOpen = false,
  });

  @override
  State<BMHModuleCard> createState() => _BMHModuleCardState();
}

class _BMHModuleCardState extends State<BMHModuleCard>
    with SingleTickerProviderStateMixin {
  late bool _open;
  late final AnimationController _ctrl;
  late final Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyOpen;
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280),
    );
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (_open) _ctrl.value = 1.0;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.signalColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: _open ? color.withOpacity(0.4) : BMHColors.line),
      ),
      child: Column(
        children: [
          // Left accent bar when open
          ClipRRect(
            borderRadius: BorderRadius.circular(BMHRadius.lg),
            child: Stack(
              children: [
                if (_open)
                  Positioned(
                    left: 0, top: 0, bottom: 0,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: color,
                        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12)],
                      ),
                    ),
                  ),
                // Header
                GestureDetector(
                  onTap: _toggle,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(BMHSpacing.s4 + 2),
                    child: Row(
                      children: [
                        // Icon
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: _open ? color : BMHColors.signalBg(color),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _open ? color : BMHColors.signalBorder(color)),
                            boxShadow: _open ? BMHShadows.glow(color) : [],
                          ),
                          child: Center(
                            child: IconTheme(
                              data: IconThemeData(
                                color: _open ? BMHColors.bg0 : color,
                                size: 20,
                              ),
                              child: widget.icon,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.title, style: BMHText.heading2),
                              const SizedBox(height: 4),
                              Text(widget.subtitle.toUpperCase(), style: BMHText.monoSm),
                            ],
                          ),
                        ),
                        // Chevron
                        AnimatedRotation(
                          turns: _open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 280),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _open ? color : BMHColors.inkMute,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expanded body
          SizeTransition(
            sizeFactor: _expand,
            child: widget.expandedContent != null
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: widget.expandedContent,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HEALTH ROW (vitals list item)
// ─────────────────────────────────────────────

class BMHHealthRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color signalColor;
  final Widget icon;
  final VoidCallback? onTap;
  final bool showMeasure;

  const BMHHealthRow({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.signalColor,
    required this.icon,
    this.onTap,
    this.showMeasure = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(color: BMHColors.line),
        ),
        child: Row(
          children: [
            // Signal icon badge
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: BMHColors.signalBg(signalColor),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BMHColors.signalBorder(signalColor)),
              ),
              child: Center(
                child: IconTheme(
                  data: IconThemeData(color: signalColor, size: 18),
                  child: icon,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Label
            Expanded(
              child: Text(label, style: BMHText.bodyMd),
            ),
            // Value
            RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: value,
                  style: BMHText.displaySm.copyWith(
                    fontFamily: 'JetBrains Mono', fontSize: 18,
                    color: BMHColors.ink, height: 1,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: BMHText.monoSm.copyWith(color: BMHColors.inkMute),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            // Measure pill or chevron
            if (showMeasure)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: BMHColors.cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(BMHRadius.full),
                  border: Border.all(color: BMHColors.cyanSoft),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: BMHColors.cyan, size: 12),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: BMHColors.inkMute, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  LOADING SKELETON (shimmer)
// ─────────────────────────────────────────────

class BMHSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const BMHSkeleton({
    super.key, this.width = double.infinity, this.height = 16, this.radius = 8,
  });

  @override
  State<BMHSkeleton> createState() => _BMHSkeletonState();
}

class _BMHSkeletonState extends State<BMHSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: [BMHColors.bg3, BMHColors.bg4, BMHColors.bg3],
            stops: [0, _anim.value, 1],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────

class BMHEmptyState extends StatelessWidget {
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;
  const BMHEmptyState({
    super.key,
    required this.title, required this.body,
    this.ctaLabel, this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BMHSpacing.s10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BMHScanLineFigure(width: 60, height: 80, opacity: 0.2),
            const SizedBox(height: 24),
            Text(title, style: BMHText.heading2, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(body, style: BMHText.italic, textAlign: TextAlign.center),
            if (ctaLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onCta, child: Text(ctaLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
