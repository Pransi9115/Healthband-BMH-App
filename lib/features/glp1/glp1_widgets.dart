// ─────────────────────────────────────────────────────────
//  GLP-1 CHECK-IN — ANSWER WIDGETS
//
//  Built from the ruleset, not hard-coded: each widget renders
//  whatever the JSON says the question is. Nothing here decides what
//  is asked or what an answer means.
//
//  Accessibility notes from section 14 of the spec are load bearing
//  here — large targets, one question in focus, and never colour on
//  its own to signal risk. Each risk state carries an icon and a word
//  alongside the colour.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/theme/bmh_tokens.dart';
import '../../core/glp1/glp1_models.dart';

// ── RISK PRESENTATION ─────────────────────────────────────
Color riskColor(RiskLevel r) => switch (r) {
      RiskLevel.green => BMHColors.success,
      RiskLevel.yellow => BMHColors.warn,
      RiskLevel.orange => const Color(0xFFFF8A3D),
      RiskLevel.red => BMHColors.danger,
      RiskLevel.undetermined => BMHColors.inkDim,
    };

IconData riskIcon(RiskLevel r) => switch (r) {
      RiskLevel.green => Icons.check_circle_outline_rounded,
      RiskLevel.yellow => Icons.visibility_outlined,
      RiskLevel.orange => Icons.priority_high_rounded,
      RiskLevel.red => Icons.warning_amber_rounded,
      RiskLevel.undetermined => Icons.help_outline_rounded,
    };

// ── SINGLE CHOICE ─────────────────────────────────────────
class Glp1OptionList extends StatelessWidget {
  final Question question;
  final num? value;
  final ValueChanged<num> onChanged;

  /// Value held by the previous assessment, shown as context when
  /// the patient is editing a pre-populated answer.
  final num? yesterday;

  const Glp1OptionList({
    super.key,
    required this.question,
    required this.value,
    required this.onChanged,
    this.yesterday,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final o in question.options)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _OptionTile(
            label: o.label,
            selected: value == o.value,
            uncertain: o.uncertain,
            isYesterday: yesterday != null && yesterday == o.value,
            onTap: () => onChanged(o.value))),
    ]);
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool uncertain;
  final bool isYesterday;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.uncertain,
    required this.isYesterday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = uncertain ? BMHColors.warn : BMHColors.cyan;
    return Semantics(
      button: true,
      selected: selected,
      label: isYesterday ? '$label, your answer yesterday' : label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          // Comfortably above the 48dp minimum touch target.
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.14) : BMHColors.bg2,
            borderRadius: BorderRadius.circular(BMHRadius.md),
            border: Border.all(
              color: selected ? accent : BMHColors.line,
              width: selected ? 1.6 : 1)),
          child: Row(children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? accent : BMHColors.inkMute),
            const SizedBox(width: 13),
            Expanded(child: Text(label,
              style: BMHText.bodyMd.copyWith(
                fontSize: 15,
                color: selected ? BMHColors.ink : BMHColors.ink2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400))),
            if (isYesterday)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BMHColors.bg4,
                  borderRadius: BorderRadius.circular(BMHRadius.full)),
                child: Text('yesterday',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9, color: BMHColors.inkDim))),
          ]))));
  }
}

// ── 0–10 SCALE ────────────────────────────────────────────
class Glp1Scale extends StatelessWidget {
  final Question question;
  final num? value;
  final ValueChanged<num> onChanged;
  final num? yesterday;

  const Glp1Scale({
    super.key,
    required this.question,
    required this.value,
    required this.onChanged,
    this.yesterday,
  });

  @override
  Widget build(BuildContext context) {
    final lo = (question.min ?? 0).toInt();
    final hi = (question.max ?? 10).toInt();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Text(
        value == null ? '—' : value.toString(),
        style: BMHText.displaySm.copyWith(
          fontSize: 44,
          color: value == null ? BMHColors.inkMute : BMHColors.cyan))),
      if (yesterday != null)
        Center(child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('yesterday: $yesterday',
            style: BMHText.monoSm.copyWith(
              fontSize: 11, color: BMHColors.inkDim)))),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = lo; i <= hi; i++)
          Semantics(
            button: true,
            selected: value == i,
            label: '$i out of $hi',
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 52, height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == i
                      ? BMHColors.cyan.withOpacity(0.18)
                      : BMHColors.bg2,
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(
                    color: value == i ? BMHColors.cyan : BMHColors.line,
                    width: value == i ? 1.6 : 1)),
                child: Text('$i',
                  style: BMHText.monoMd.copyWith(
                    fontSize: 16,
                    color: value == i ? BMHColors.cyan : BMHColors.ink2,
                    fontWeight: value == i
                        ? FontWeight.w700 : FontWeight.w500))))),
      ]),
    ]);
  }
}

// ── FREE NUMBER ───────────────────────────────────────────
class Glp1Number extends StatelessWidget {
  final Question question;
  final num? value;
  final ValueChanged<num?> onChanged;

  const Glp1Number({
    super.key,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: BMHText.monoMd.copyWith(fontSize: 18, color: BMHColors.ink),
      onChanged: (s) => onChanged(num.tryParse(s.trim())),
      decoration: InputDecoration(
        hintText: question.unit ?? 'Enter a number',
        hintStyle: BMHText.bodyMd.copyWith(color: BMHColors.inkMute),
        suffixText: question.unit,
        suffixStyle: BMHText.monoSm.copyWith(color: BMHColors.inkDim),
        filled: true,
        fillColor: BMHColors.bg2,
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BMHRadius.md),
          borderSide: const BorderSide(color: BMHColors.line)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BMHRadius.md),
          borderSide: const BorderSide(color: BMHColors.cyan))));
  }
}

// ── FREE TEXT ─────────────────────────────────────────────
class Glp1Text extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  const Glp1Text({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value ?? '',
      maxLines: 5,
      style: BMHText.bodyMd.copyWith(fontSize: 15, color: BMHColors.ink),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Type anything you would like your care team to know.',
        hintStyle: BMHText.bodySm.copyWith(color: BMHColors.inkMute),
        filled: true,
        fillColor: BMHColors.bg2,
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BMHRadius.md),
          borderSide: const BorderSide(color: BMHColors.line)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BMHRadius.md),
          borderSide: const BorderSide(color: BMHColors.cyan))));
  }
}

// ── PRIMARY BUTTON ────────────────────────────────────────
class Glp1Button extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;

  const Glp1Button({
    super.key,
    required this.label,
    this.onTap,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    final c = color ?? BMHColors.cyan;
    return Semantics(
      button: true,
      enabled: on,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c : BMHColors.bg4,
            borderRadius: BorderRadius.circular(BMHRadius.md)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18,
                  color: on ? BMHColors.bg0 : BMHColors.inkMute),
                const SizedBox(width: 8),
              ],
              Text(label,
                style: BMHText.labelLg.copyWith(
                  fontSize: 15,
                  color: on ? BMHColors.bg0 : BMHColors.inkMute,
                  fontWeight: FontWeight.w700)),
            ]))));
  }
}

// ── PROGRESS ──────────────────────────────────────────────
class Glp1Progress extends StatelessWidget {
  final int step;
  final int total;
  const Glp1Progress({super.key, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final v = total == 0 ? 0.0 : (step / total).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(BMHRadius.full),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 4,
          backgroundColor: BMHColors.bg4,
          valueColor: const AlwaysStoppedAnimation(BMHColors.cyan))),
      const SizedBox(height: 6),
      Text('Step $step of $total',
        style: BMHText.monoSm.copyWith(
          fontSize: 10, color: BMHColors.inkMute)),
    ]);
  }
}
