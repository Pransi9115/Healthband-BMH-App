import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../../core/bioresponse/blood_report_service.dart';
import '../bioresponse/biomarkers_screen.dart';
import '../bioresponse/blood_report_screen.dart';
import '../bioresponse/blood_report_format.dart';

/// ─────────────────────────────────────────────────────────
///  BIOMEDICAL MONITORING — Blood · GUT · DNA
///
///  Blood shows the patient's actual panel in the same report
///  format BioResponse → Biomarkers uses — one source of truth,
///  one presentation, wherever it is opened from. GUT and DNA stay
///  informational until their data sources are wired in.
///
///  Text is BMHColors.ink (white) throughout; only trailing
///  provenance lines drop to ink2, so nothing reads as dim grey on
///  the dark theme.
/// ─────────────────────────────────────────────────────────
class BiomedicalMonitoringScreen extends StatefulWidget {
  final String type; // 'Blood' | 'GUT' | 'DNA'
  const BiomedicalMonitoringScreen({super.key, required this.type});

  @override
  State<BiomedicalMonitoringScreen> createState() =>
      _BiomedicalMonitoringScreenState();
}

class _BiomedicalMonitoringScreenState
    extends State<BiomedicalMonitoringScreen> {
  final _blood = BloodReportService.instance;

  String get type => widget.type;

  @override
  void initState() {
    super.initState();
    if (type == 'Blood') {
      _blood.addListener(_refresh);
      _blood.init();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (type == 'Blood') _blood.removeListener(_refresh);
    super.dispose();
  }

  ({String title, String tagline, IconData icon, Color color,
    String intro, List<(IconData, String)> features}) get _cfg {
    switch (type) {
      case 'Blood':
        return (
          title: 'Blood Analysis',
          tagline: 'Your inner chemistry, decoded',
          icon: Icons.bloodtype_outlined,
          color: BMHColors.sCardio,
          intro: 'Periodic blood panels reveal what wearables cannot — '
              'from cholesterol and blood sugar control to vitamin '
              'levels and inflammation markers.',
          features: [
            (Icons.water_drop_outlined, 'Lipid Profile'),
            (Icons.cake_outlined, 'Metabolic Panel'),
            (Icons.shield_outlined, 'Inflammation & Vitamins'),
          ]);
      case 'GUT':
        return (
          title: 'GUT Microbiome',
          tagline: 'The second brain in your belly',
          icon: Icons.spa_outlined,
          color: BMHColors.sGut,
          intro: 'Your gut microbiome influences digestion, immunity, '
              'mood and even sleep. Microbiome testing maps the '
              'bacteria in your gut and turns it into practical food '
              'and lifestyle guidance.',
          features: [
            (Icons.pie_chart_outline_rounded, 'Diversity Score'),
            (Icons.restaurant_outlined, 'Food Response'),
            (Icons.mood_outlined, 'Gut–Brain Axis'),
          ]);
      default: // DNA
        return (
          title: 'DNA Insights',
          tagline: 'Written in your genes',
          icon: Icons.biotech_outlined,
          color: BMHColors.sDna,
          intro: 'A one-time DNA analysis reveals lifelong traits — '
              'how your body responds to nutrition, exercise and '
              'sleep. Paired with your live band data, it enables '
              'truly personalized health guidance.',
          features: [
            (Icons.fitness_center_outlined, 'Fitness Genetics'),
            (Icons.restaurant_menu_outlined, 'Nutrigenomics'),
            (Icons.nightlight_outlined, 'Sleep & Rhythm'),
          ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _cfg;
    final hasReport = type == 'Blood' && _blood.report != null;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 0),
      body: Stack(children: [
        Positioned(top: -180, right: -120,
          child: Container(width: 480, height: 480,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                c.color.withOpacity(0.08), Colors.transparent])))),
        SafeArea(bottom: false, child: Column(children: [
          // ── HEADER with back button ─────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH, vertical: 8),
            child: Row(children: [
              BMHIconButton(onTap: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                  color: BMHColors.ink, size: 16)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BMHEyebrow('Biomedical monitoring'),
                  Text(c.title,
                    style: BMHText.heading1.copyWith(fontSize: 24)),
                ])),
            ])),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: BMHSpacing.screenH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // ── HERO — slimmer, tighter, white body copy ──
                _Hero(cfg: c),
                const SizedBox(height: 18),

                if (hasReport)
                  // The actual panel, in the shared report format.
                  ..._bloodReport(context)
                else
                  // Explainer for GUT / DNA (and Blood before upload).
                  ..._explainer(c),

                const SizedBox(height: 120),
              ]))),
        ])),
      ]),
    );
  }

  // ── BLOOD — the full report, same format as Biomarkers ──
  List<Widget> _bloodReport(BuildContext context) {
    final r = _blood.report!;
    final flagged = r.flagged;

    return [
      ReportMasthead(report: r),
      const SizedBox(height: 16),
      ReportCounts(report: r),

      const SizedBox(height: 18),
      BloodReportOutlineButton(
        label: 'VIEW FULL REPORT',
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => BloodReportScreen(report: r)))),

      const SizedBox(height: 12),
      _dietCrossLink(context),

      if (r.threads.isNotEmpty) ...[
        const SizedBox(height: 24),
        BMHSectionTitle('Read this first'),
        const SizedBox(height: 12),
        ReportThreads(report: r),
      ],

      // ── TRENDING PATTERN — a dot per marker in each body system,
      //    placed by where it sits in its own reference range and
      //    joined into a line. Drawn straight from the report.
      const SizedBox(height: 24),
      BMHSectionTitle('Pattern across the panel'),
      const SizedBox(height: 6),
      Text(
        'Each dot is one marker, placed by where it sits inside its '
        'reference range. The band down the middle is where a result '
        'should land.',
        style: BMHText.bodySm.copyWith(
          fontSize: 11, color: BMHColors.ink, height: 1.5)),
      const SizedBox(height: 14),
      for (final g in r.groups) ...[
        _TrendGroup(group: g, markers: r.inGroup(g)),
        const SizedBox(height: 10),
      ],

      const SizedBox(height: 12),
      BMHSectionTitle('What the report flagged'),
      const SizedBox(height: 10),
      Text(
        flagged.isEmpty
          ? 'Every marker in this panel sits inside its reference range.'
          : '${r.outsideRangeCount} of ${r.totalCount} markers fell '
            'outside the laboratory reference range. Tap any one to read '
            'what it means and what you can do.',
        style: BMHText.bodySm.copyWith(
          fontSize: 11, color: BMHColors.ink, height: 1.5)),
      const SizedBox(height: 12),
      const ReportLegend(),
      const SizedBox(height: 14),
      for (final m in flagged) ...[
        ReportMarkerRow(marker: m),
        const SizedBox(height: 9),
      ],

      if (r.steps.isNotEmpty) ...[
        const SizedBox(height: 22),
        BMHSectionTitle('What to do next'),
        const SizedBox(height: 6),
        Text('In the order that makes the most difference.',
          style: BMHText.bodySm.copyWith(
            fontSize: 11, color: BMHColors.ink)),
        const SizedBox(height: 12),
        ReportSteps(report: r),
      ],

      const SizedBox(height: 18),
      ReportDisclaimer(report: r),
    ];
  }

  Widget _dietCrossLink(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => const BiomarkersScreen())),
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.cyan.withOpacity(0.24))),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: BMHColors.cyan.withOpacity(0.10),
            borderRadius: BorderRadius.circular(BMHRadius.md)),
          child: const Icon(Icons.insights_outlined,
            color: BMHColors.cyan, size: 17)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('See it against your diet',
              style: BMHText.labelMd.copyWith(color: BMHColors.ink)),
            const SizedBox(height: 2),
            Text('Opens BioResponse → Biomarkers',
              style: BMHText.bodySm.copyWith(
                fontSize: 10, color: BMHColors.ink2)),
          ])),
        const Icon(Icons.chevron_right_rounded,
          color: BMHColors.ink2, size: 20),
      ])));

  // ── GUT / DNA — lean explainer, white text, no coming-soon note ──
  List<Widget> _explainer(
      ({String title, String tagline, IconData icon, Color color,
        String intro, List<(IconData, String)> features}) c) {
    return [
      BMHSectionTitle('What you\'ll get'),
      const SizedBox(height: 12),
      for (final f in c.features)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BMHColors.surface,
            borderRadius: BorderRadius.circular(BMHRadius.lg),
            border: Border.all(color: BMHColors.line)),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: c.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.color.withOpacity(0.22))),
              child: Icon(f.$1, color: c.color, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(f.$2,
              style: BMHText.labelMd.copyWith(color: BMHColors.ink))),
          ])),
    ];
  }
}

// ─────────────────────────────────────────────────────────
//  HERO — compact, so the card stays neat and the report sits
//  higher up the page.
// ─────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  final ({String title, String tagline, IconData icon, Color color,
    String intro, List<(IconData, String)> features}) cfg;
  const _Hero({required this.cfg});

  @override
  Widget build(BuildContext context) {
    final c = cfg;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.color.withOpacity(0.14),
            c.color.withOpacity(0.02)]),
        borderRadius: BorderRadius.circular(BMHRadius.xl),
        border: Border.all(color: c.color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: c.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.color.withOpacity(0.25))),
              child: Icon(c.icon, color: c.color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(c.tagline,
              style: BMHText.heading3.copyWith(
                fontStyle: FontStyle.italic, color: c.color))),
          ]),
          const SizedBox(height: 10),
          Text(c.intro,
            style: BMHText.bodySm.copyWith(
              fontSize: 11.5, color: BMHColors.ink, height: 1.55)),
        ]));
  }
}

// ─────────────────────────────────────────────────────────
//  TREND GROUP — one body system's markers as a dotted pattern
// ─────────────────────────────────────────────────────────
class _TrendGroup extends StatelessWidget {
  final String group;
  final List<BloodMarker> markers;
  const _TrendGroup({required this.group, required this.markers});

  @override
  Widget build(BuildContext context) {
    final flaggedCount = markers
        .where((m) => m.isConcern || m.status == MarkerStatus.borderline)
        .length;
    final tone = flaggedCount > 0 ? BMHColors.sMetabolic : BMHColors.sGut;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(group,
              style: BMHText.labelMd.copyWith(
                fontSize: 12, color: BMHColors.ink))),
            Text(
              flaggedCount == 0
                ? 'all in range'
                : '$flaggedCount to watch',
              style: BMHText.monoSm.copyWith(
                fontSize: 8.5, color: tone, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          TrendDots(markers: markers, color: tone),
        ]));
  }
}
