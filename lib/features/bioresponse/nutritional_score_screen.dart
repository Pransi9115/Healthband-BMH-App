// ─────────────────────────────────────────────────────────
//  BIORESPONSE — NUTRITIONAL SCORE
//
//  The provider dashboard view, brought into the app unchanged:
//    · a strip of the day being graded
//    · 6 category tabs
//    · the profiles inside the selected tab, as chips
//    · the grade for the selected profile, with every criterion
//      shown against its own target
//    · provider notes
//
//  Grades come from NutritionalScoreService, which is a direct port
//  of the dashboard engine, so a number here and a number there can
//  never disagree.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/nutritional_score_service.dart';
import '../../core/diet/diet_service.dart';

class NutritionalScoreScreen extends StatefulWidget {
  /// Kept so existing callers compile; the dashboard grades one day.
  final ScoreRange initialRange;
  const NutritionalScoreScreen({
    super.key,
    this.initialRange = ScoreRange.day,
  });

  @override
  State<NutritionalScoreScreen> createState() =>
      _NutritionalScoreScreenState();
}

class _NutritionalScoreScreenState extends State<NutritionalScoreScreen> {
  final _svc = NutritionalScoreService.instance;
  final _diet = DietService.instance;

  String _categoryKey = kCategories.first.key;
  late String _profileKey = _svc.profilesIn(_categoryKey).first.key;

  final _notes = TextEditingController();
  String _notesStatus = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final today = DateTime.now();
    await _diet.ensureDay(today);
    final p = await SharedPreferences.getInstance();
    _svc.bodyWeightKg =
        p.getDouble('profile_weight') ?? kReferenceWeightKg;
    _notes.text = p.getString(_notesKey(today)) ?? '';
    if (mounted) setState(() => _ready = true);
  }

  String _notesKey(DateTime d) =>
      'bioresponse_notes_${d.year}-${d.month}-${d.day}';

  Future<void> _saveNote() async {
    final now = DateTime.now();
    final p = await SharedPreferences.getInstance();
    await p.setString(_notesKey(now), _notes.text);
    final stamp = '${now.day.toString().padLeft(2, '0')} '
        '${_month(now.month)} ${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    if (mounted) setState(() => _notesStatus = 'Saved $stamp');
  }

  static String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];

  void _selectCategory(String key) {
    setState(() {
      _categoryKey = key;
      _profileKey = _svc.profilesIn(key).first.key;
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final totals = _svc.totalsFor(today);
    final profile = _svc.profileByKey(_profileKey)!;
    final grade = _svc.gradeFor(profile, totals);

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: SafeArea(child: Column(children: [
        // ── HEADER ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BMHSpacing.s5, vertical: 8),
          child: Row(children: [
            BMHIconButton(
              onTap: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded,
                color: BMHColors.ink, size: 16)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BMHEyebrow('BIOHEALTHCARE / BIOMEDICAL DIET'),
                Text('BioResponse', style: BMHText.heading1),
              ])),
          ])),

        if (!_ready)
          const Expanded(child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2, color: BMHColors.cyan)))
        else
        // The list scrolls under the header, so its top edge is
        // faded out — content dissolves away instead of being cut
        // through the middle of a line.
        Expanded(child: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
            stops: [0.0, 0.035],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: BMHSpacing.s5),
          children: [
            Text('How your body responds to what you eat.',
              style: BMHText.heading3.copyWith(color: BMHColors.cyan)),
            const SizedBox(height: 18),

            Text('Your BioResponse nutritional score',
              style: BMHText.heading2),
            const SizedBox(height: 6),
            Text(
              'Pick a goal or a health condition, and today’s food is '
              'graded on how your body would respond to it. The same day '
              'scores differently for each, since a plate that suits one '
              'goal can work against another.',
              style: BMHText.bodySm.copyWith(
                fontSize: 11.5, color: BMHColors.inkDim, height: 1.5)),
            const SizedBox(height: 16),

            // ── DAY STRIP ─────────────────────────────────
            _DayStrip(totals: totals),
            const SizedBox(height: 16),

            // ── CATEGORY TABS ─────────────────────────────
            // Six categories never fit a phone width, so the row
            // scrolls and keeps the selected tab in view by itself.
            _CategoryTabs(
              selectedKey: _categoryKey,
              onSelect: _selectCategory),
            const SizedBox(height: 10),

            // ── PROFILE CHIPS ─────────────────────────────
            // One scrolling line rather than a wrap: ten profiles
            // would otherwise push the score below the fold.
            _ProfileChips(
              key: ValueKey(_categoryKey),
              profiles: _svc.profilesIn(_categoryKey),
              selectedKey: _profileKey,
              onSelect: (k) => setState(() => _profileKey = k)),
            const SizedBox(height: 18),

            // ── RESULT ────────────────────────────────────
            _ResultCard(profile: profile, grade: grade),
            const SizedBox(height: 18),

            // ── PROVIDER NOTES ────────────────────────────
            _NotesCard(
              controller: _notes,
              status: _notesStatus,
              onSave: _saveNote),
            const SizedBox(height: 16),

            Text(
              'Grades are guidance toward the chosen goal, not a '
              'judgement of the person or medical advice. Safety '
              'ceilings such as potassium and phosphorus for renal care '
              'come from clinician validated limits and cap the grade on '
              'their own. A grade that is not suitable is flagged to the '
              'assigned provider.',
              style: BMHText.bodySm.copyWith(
                fontSize: 10.5, color: BMHColors.inkMute, height: 1.55)),
            const SizedBox(height: 10),
            Text('BioHealthcare Group / BioResponse',
              style: BMHText.monoSm.copyWith(
                fontSize: 9.5, color: BMHColors.inkFaint)),
            const SizedBox(height: 40),
          ]))),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  DAY STRIP — the day being graded
// ─────────────────────────────────────────────────────────
class _DayStrip extends StatelessWidget {
  final DayTotals totals;
  const _DayStrip({required this.totals});

  static String _fmt(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }

  @override
  Widget build(BuildContext context) {
    final who = totals.isReference
        ? 'TODAY, MEMBER 4471, ${_fmt(totals.weightKg)} KG'
        : 'TODAY, ${_fmt(totals.weightKg)} KG';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(who, style: BMHText.monoSm.copyWith(
            fontSize: 9.5, letterSpacing: 0.6, color: BMHColors.inkMute)),
          for (final k in Nutrients.summaryKeys)
            _Stat(
              label: Nutrients.of(k).label,
              value: _fmt(totals[k]),
              unit: Nutrients.of(k).unit),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: totals.isReference
                ? BMHColors.bg4
                : BMHColors.success.withOpacity(0.14),
              borderRadius: BorderRadius.circular(BMHRadius.sm)),
            child: Text(totals.sourceLabel,
              style: BMHText.monoSm.copyWith(
                fontSize: 9.5,
                color: totals.isReference
                  ? BMHColors.inkDim : BMHColors.success))),
        ]));
  }
}

class _Stat extends StatelessWidget {
  final String label, value, unit;
  const _Stat({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: BMHColors.bg4,
        borderRadius: BorderRadius.circular(BMHRadius.sm)),
      child: RichText(text: TextSpan(children: [
        TextSpan(text: '$label ',
          style: BMHText.monoSm.copyWith(
            fontSize: 10, color: BMHColors.inkDim)),
        TextSpan(text: value,
          style: BMHText.monoSm.copyWith(
            fontSize: 10, color: BMHColors.ink,
            fontWeight: FontWeight.w700)),
        TextSpan(text: ' $unit',
          style: BMHText.monoSm.copyWith(
            fontSize: 10, color: BMHColors.inkDim)),
      ])));
  }
}

// ─────────────────────────────────────────────────────────
//  HORIZONTAL STRIP
//
//  Both the category tabs and the profile chips are rows that
//  overflow a phone screen. Each keeps its selection scrolled
//  into view and fades whichever edge still has content beyond
//  it, so a clipped label reads as "there is more this way"
//  rather than as broken text.
// ─────────────────────────────────────────────────────────
class _Strip extends StatefulWidget {
  final int count;
  final int selectedIndex;
  final double height;
  final Widget Function(BuildContext, int) itemBuilder;

  const _Strip({
    super.key,
    required this.count,
    required this.selectedIndex,
    required this.height,
    required this.itemBuilder,
  });

  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  final _ctrl = ScrollController();
  late List<GlobalKey> _keys = _freshKeys();

  bool _atStart = true;
  bool _atEnd = false;

  List<GlobalKey> _freshKeys() =>
      List.generate(widget.count, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onScroll();
      _reveal();
    });
  }

  @override
  void didUpdateWidget(covariant _Strip old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) _keys = _freshKeys();
    if (old.selectedIndex != widget.selectedIndex ||
        old.count != widget.count) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _onScroll() {
    if (!_ctrl.hasClients) return;
    final max = _ctrl.position.maxScrollExtent;
    final at = _ctrl.offset;
    final start = at <= 1;
    final end = max <= 1 || at >= max - 1;
    if (start != _atStart || end != _atEnd) {
      setState(() { _atStart = start; _atEnd = end; });
    }
  }

  /// Slides the selected item to the leading edge, leaving the
  /// next one peeking so the row still reads as scrollable.
  void _reveal() {
    final i = widget.selectedIndex;
    if (i < 0 || i >= _keys.length) return;
    final ctx = _keys[i].currentContext;
    if (ctx == null || !_ctrl.hasClients) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.05,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fade only the edges that still have content past them.
    final stops = <double>[0.0, _atStart ? 0.0 : 0.06,
                           _atEnd ? 1.0 : 0.94, 1.0];
    return SizedBox(
      height: widget.height,
      child: ShaderMask(
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.transparent, Colors.black,
            Colors.black, Colors.transparent,
          ],
          stops: stops,
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          controller: _ctrl,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: widget.count,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (c, i) => KeyedSubtree(
            key: _keys[i],
            child: widget.itemBuilder(c, i)))));
  }
}

// ── CATEGORY TABS ─────────────────────────────────────────
class _CategoryTabs extends StatelessWidget {
  final String selectedKey;
  final ValueChanged<String> onSelect;
  const _CategoryTabs({
    required this.selectedKey, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final i = kCategories.indexWhere((c) => c.key == selectedKey);
    return _Strip(
      count: kCategories.length,
      selectedIndex: i,
      height: 38,
      itemBuilder: (_, n) {
        final c = kCategories[n];
        return _Tab(
          label: c.name,
          selected: c.key == selectedKey,
          onTap: () => onSelect(c.key));
      });
  }
}

// ── PROFILE CHIPS ─────────────────────────────────────────
class _ProfileChips extends StatelessWidget {
  final List<GoalProfile> profiles;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  const _ProfileChips({
    super.key,
    required this.profiles,
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final i = profiles.indexWhere((p) => p.key == selectedKey);
    return _Strip(
      count: profiles.length,
      selectedIndex: i,
      height: 34,
      itemBuilder: (_, n) {
        final p = profiles[n];
        return _Chip(
          label: p.name,
          selected: p.key == selectedKey,
          onTap: () => onSelect(p.key));
      });
  }
}

// ─────────────────────────────────────────────────────────
//  TAB AND CHIP
// ─────────────────────────────────────────────────────────
class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({
    required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? BMHColors.cyan : BMHColors.surface,
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(
            color: selected ? BMHColors.cyan : BMHColors.line)),
        child: Text(label,
          style: BMHText.labelMd.copyWith(
            fontSize: 12.5,
            color: selected ? BMHColors.bg0 : BMHColors.ink2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500))));
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? BMHColors.sGut.withOpacity(0.18) : BMHColors.bg2,
          borderRadius: BorderRadius.circular(BMHRadius.full),
          border: Border.all(
            color: selected ? BMHColors.sGut : BMHColors.line)),
        child: Text(label,
          style: BMHText.bodySm.copyWith(
            fontSize: 12,
            color: selected ? BMHColors.sGut : BMHColors.ink2,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500))));
  }
}

// ─────────────────────────────────────────────────────────
//  RESULT CARD
// ─────────────────────────────────────────────────────────
Color _bandColor(GradeBand b) => switch (b) {
      GradeBand.good => BMHColors.success,
      GradeBand.moderate => BMHColors.warn,
      GradeBand.poor => BMHColors.danger,
    };

Color _barColor(int score) => score >= 75
    ? BMHColors.success
    : score >= 55 ? BMHColors.warn : BMHColors.danger;

class _ResultCard extends StatelessWidget {
  final GoalProfile profile;
  final Grade grade;
  const _ResultCard({required this.profile, required this.grade});

  @override
  Widget build(BuildContext context) {
    final c = _bandColor(grade.band);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.xl),
        border: Border.all(color: BMHColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ring + verdict ────────────────────────────
          Row(children: [
            Container(
              width: 76, height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BMHColors.bg0,
                border: Border.all(color: c, width: 3.5)),
              child: Text(grade.score.toString(),
                style: BMHText.monoLg.copyWith(
                  fontSize: 26, color: c, fontWeight: FontWeight.w700))),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(grade.verdict, style: BMHText.heading3),
                const SizedBox(height: 3),
                Text(grade.scoreLine,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 10.5, color: BMHColors.inkDim)),
              ])),
          ]),
          const SizedBox(height: 14),

          Text(profile.note,
            style: BMHText.bodySm.copyWith(
              fontSize: 11.5, color: BMHColors.inkDim, height: 1.5)),

          // ── safety banner ─────────────────────────────
          if (grade.hasBreach) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BMHColors.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(BMHRadius.md),
                border: Border.all(
                  color: BMHColors.danger.withOpacity(0.4))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                    color: BMHColors.danger, size: 17),
                  const SizedBox(width: 9),
                  Expanded(child: Text(
                    'Safety limit reached: ${grade.breaches.join("; ")}. '
                    'Flagged to the provider.',
                    style: BMHText.bodySm.copyWith(
                      fontSize: 11, color: BMHColors.danger, height: 1.45))),
                ])),
          ],

          const SizedBox(height: 16),
          Divider(color: BMHColors.line, height: 1),
          const SizedBox(height: 14),

          Text('HOW THE DAY SCORED ON EACH TARGET',
            style: BMHText.monoSm.copyWith(
              fontSize: 9.5, letterSpacing: 0.9, color: BMHColors.inkMute)),
          const SizedBox(height: 12),

          for (final r in grade.criteria) ...[
            _CriterionRowView(row: r),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 2),
          // ── what helped / what held it back ───────────
          LayoutBuilder(builder: (_, box) {
            final wide = box.maxWidth > 420;
            final helped = _DriverBox(
              title: 'WHAT HELPED',
              tint: BMHColors.success,
              items: grade.helped,
              empty: 'Nothing scored strongly today');
            final held = _DriverBox(
              title: 'WHAT HELD IT BACK',
              tint: BMHColors.danger,
              items: grade.heldBack,
              empty: 'Nothing fell short');
            return wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: helped),
                      const SizedBox(width: 12),
                      Expanded(child: held),
                    ])
                : Column(children: [
                    helped, const SizedBox(height: 12), held,
                  ]);
          }),
        ]));
  }
}

// ── one criterion: label, value, bar, target ──────────────
class _CriterionRowView extends StatelessWidget {
  final CriterionRow row;
  const _CriterionRowView({required this.row});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(row.label,
            style: BMHText.labelMd.copyWith(
              fontSize: 12.5, color: BMHColors.ink))),
          Text(row.valueText,
            style: BMHText.monoSm.copyWith(
              fontSize: 12, color: BMHColors.ink,
              fontWeight: FontWeight.w700)),
          const SizedBox(width: 3),
          Text(row.unit,
            style: BMHText.monoSm.copyWith(
              fontSize: 9.5, color: BMHColors.inkMute)),
        ]),
        const SizedBox(height: 7),
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(BMHRadius.full),
            child: LinearProgressIndicator(
              value: (row.score / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: BMHColors.bg4,
              valueColor:
                AlwaysStoppedAnimation(_barColor(row.score))))),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(row.target,
              textAlign: TextAlign.right,
              style: BMHText.monoSm.copyWith(
                fontSize: 9.5, color: BMHColors.inkMute))),
        ]),
      ]);
  }
}

// ── what helped / what held it back ───────────────────────
class _DriverBox extends StatelessWidget {
  final String title;
  final Color tint;
  final List<String> items;
  final String empty;

  const _DriverBox({
    required this.title,
    required this.tint,
    required this.items,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) {
    final list = items.isEmpty ? <String>[empty] : items;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BMHColors.bg2,
        borderRadius: BorderRadius.circular(BMHRadius.md),
        border: Border.all(color: BMHColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: BMHText.monoSm.copyWith(
              fontSize: 9.5, letterSpacing: 0.8,
              color: tint, fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          for (final x in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5, height: 5,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: items.isEmpty ? BMHColors.inkMute : tint)),
                  Expanded(child: Text(x,
                    style: BMHText.bodySm.copyWith(
                      fontSize: 11.5,
                      color: items.isEmpty
                        ? BMHColors.inkMute : BMHColors.ink2))),
                ])),
        ]));
  }
}

// ─────────────────────────────────────────────────────────
//  PROVIDER NOTES
// ─────────────────────────────────────────────────────────
class _NotesCard extends StatelessWidget {
  final TextEditingController controller;
  final String status;
  final VoidCallback onSave;

  const _NotesCard({
    required this.controller,
    required this.status,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle, color: BMHColors.warn)),
            const SizedBox(width: 8),
            Text('PROVIDER NOTES',
              style: BMHText.monoSm.copyWith(
                fontSize: 10, letterSpacing: 0.8,
                color: BMHColors.ink2, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 5,
            style: BMHText.bodySm.copyWith(
              fontSize: 12, color: BMHColors.ink, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Notes for this member, visible to the care team. '
                  'For example observations, plan changes, or items to '
                  'follow up at the next review.',
              hintStyle: BMHText.bodySm.copyWith(
                fontSize: 11.5, color: BMHColors.inkMute, height: 1.5),
              filled: true,
              fillColor: BMHColors.bg2,
              contentPadding: const EdgeInsets.all(12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BMHRadius.sm),
                borderSide: const BorderSide(color: BMHColors.line)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BMHRadius.sm),
                borderSide: const BorderSide(color: BMHColors.cyan)),
            )),
          const SizedBox(height: 12),
          Row(children: [
            GestureDetector(
              onTap: onSave,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: BMHColors.cyan,
                  borderRadius: BorderRadius.circular(BMHRadius.sm)),
                child: Text('Save note',
                  style: BMHText.labelMd.copyWith(
                    fontSize: 12.5, color: BMHColors.bg0,
                    fontWeight: FontWeight.w700)))),
            const SizedBox(width: 12),
            Text(status,
              style: BMHText.monoSm.copyWith(
                fontSize: 10, color: BMHColors.inkMute)),
          ]),
        ]));
  }
}
