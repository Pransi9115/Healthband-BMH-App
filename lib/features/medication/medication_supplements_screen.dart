// ─────────────────────────────────────────────────────────
//  MEDICATION AND SUPPLEMENTS — module hub
//
//  Two tabs over the same idea: things the patient takes on a
//  schedule. They stay separate because they are clinically
//  different — a supplement adds nutrients and counts toward intake,
//  a medication does not and never will.
//
//  Both services live where they always did, so BioResponse →
//  Biomarkers, the Nutritional Score and the diet log all keep
//  reading exactly what they read before. Only the place a patient
//  manages them has moved out of the diet module.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../shared/widgets/bmh_global_nav.dart';
import '../../core/bioresponse/medication_service.dart';
import '../../core/bioresponse/supplement_service.dart';
import 'medications_screen.dart';
import 'supplements_screen.dart';

class MedicationSupplementsScreen extends StatefulWidget {
  /// 0 = Medication, 1 = Supplements.
  final int initialTab;
  const MedicationSupplementsScreen({super.key, this.initialTab = 0});

  @override
  State<MedicationSupplementsScreen> createState() =>
      _MedicationSupplementsScreenState();
}

class _MedicationSupplementsScreenState
    extends State<MedicationSupplementsScreen> {
  final _meds = MedicationService.instance;
  final _supps = SupplementService.instance;
  late int _tab = widget.initialTab;

  static const _medAccent = BMHColors.sDna;
  static const _suppAccent = BMHColors.sMetabolic;

  @override
  void initState() {
    super.initState();
    _meds.addListener(_refresh);
    _supps.addListener(_refresh);
    _meds.init();
    _supps.init();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _meds.removeListener(_refresh);
    _supps.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final accent = _tab == 0 ? _medAccent : _suppAccent;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      bottomNavigationBar: const BMHGlobalNav(activeIndex: 0),
      body: Stack(children: [
        Positioned(top: -160, right: -110,
          child: Container(width: 420, height: 420,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                accent.withOpacity(0.08), Colors.transparent])))),

        SafeArea(bottom: false, child: Column(children: [
          // ── HEADER ────────────────────────────────
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
                  const BMHEyebrow('MODULE'),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Medication & Supplements',
                      maxLines: 1,
                      style: BMHText.heading1)),
                ])),
            ])),

          // ── TAB SWITCH ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BMHSpacing.s5, 6, BMHSpacing.s5, 14),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: BMHColors.bg2,
                borderRadius: BorderRadius.circular(BMHRadius.full),
                border: Border.all(color: BMHColors.line)),
              child: Row(children: [
                _tabButton(
                  label: 'Medication',
                  index: 0,
                  accent: _medAccent,
                  badge: _meds.dosesTotal(today) == 0
                    ? null
                    : '${_meds.dosesTaken(today)}/'
                      '${_meds.dosesTotal(today)}'),
                _tabButton(
                  label: 'Supplements',
                  index: 1,
                  accent: _suppAccent,
                  badge: _supps.all.isEmpty
                    ? null
                    : '${_supps.takenCount(today)}/${_supps.all.length}'),
              ]))),

          // ── TAB BODY ──────────────────────────────
          // IndexedStack rather than TabBarView so each tab keeps its
          // own selected day and scroll position when you switch back.
          Expanded(child: IndexedStack(
            index: _tab,
            sizing: StackFit.expand,
            children: const [
              MedicationsScreen(embedded: true),
              SupplementsScreen(embedded: true),
            ])),
        ])),
      ]),
    );
  }

  Widget _tabButton({
    required String label,
    required int index,
    required Color accent,
    String? badge,
  }) {
    final selected = _tab == index;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(BMHRadius.full)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
              style: BMHText.labelMd.copyWith(
                color: selected ? BMHColors.bg0 : BMHColors.inkDim,
                fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500)),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                    ? BMHColors.bg0.withOpacity(0.18)
                    : BMHColors.bg4,
                  borderRadius: BorderRadius.circular(BMHRadius.full)),
                child: Text(badge,
                  style: BMHText.monoSm.copyWith(
                    fontSize: 8,
                    color: selected ? BMHColors.bg0 : BMHColors.inkMute))),
            ],
          ]))));
  }
}
