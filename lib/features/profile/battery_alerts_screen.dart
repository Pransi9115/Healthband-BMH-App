// ─────────────────────────────────────────────────────────
//  BATTERY ALERTS — carer contacts
//  Up to 5 people who get notified (via the BMH server) when
//  the patient's phone battery drops below 20%.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/battery/battery_service.dart';

class BatteryAlertsScreen extends StatefulWidget {
  const BatteryAlertsScreen({super.key});
  @override
  State<BatteryAlertsScreen> createState() => _BatteryAlertsScreenState();
}

class _BatteryAlertsScreenState extends State<BatteryAlertsScreen> {
  final _svc = BatteryService.instance;
  bool _sendingTest = false;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _svc.removeListener(_onChange);
    super.dispose();
  }

  // ── ADD / EDIT SHEET ───────────────────────────────────
  Future<void> _showCarerSheet({CarerContact? existing}) async {
    final nameCtrl  = TextEditingController(text: existing?.name ?? '');
    final relCtrl   = TextEditingController(text: existing?.relation ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BMHColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(BMHRadius.xl))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existing == null ? 'Add notify person' : 'Edit notify person',
              style: BMHText.heading2),
            const SizedBox(height: 4),
            Text('They are alerted when the battery drops below '
                 '${BatteryService.notifyAt}%.',
              style: BMHText.bodySm.copyWith(color: BMHColors.inkDim)),
            const SizedBox(height: 18),
            _field(nameCtrl,  'Name *',            'e.g. Rahul Patel'),
            const SizedBox(height: 12),
            _field(relCtrl,   'Relation',          'e.g. Son, Nurse'),
            const SizedBox(height: 12),
            _field(phoneCtrl, 'Phone (with country code) *', '+91 98…',
              keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            _field(emailCtrl, 'Email (optional)',  'name@example.com',
              keyboard: TextInputType.emailAddress),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: BMHText.bodySm.copyWith(
                color: BMHColors.danger)),
            ],
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final name  = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  setSheet(() =>
                      error = 'Name and phone number are required.');
                  return;
                }
                final c = CarerContact(
                  id: existing?.id ??
                      'carer_${DateTime.now().microsecondsSinceEpoch}',
                  name: name,
                  relation: relCtrl.text.trim(),
                  phone: phone,
                  email: emailCtrl.text.trim(),
                );
                if (existing == null) {
                  await _svc.addCarer(c);
                } else {
                  await _svc.updateCarer(c);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: BMHColors.cyan,
                  borderRadius: BorderRadius.circular(BMHRadius.full)),
                child: Text(
                  existing == null ? 'Add person' : 'Save changes',
                  textAlign: TextAlign.center,
                  style: BMHText.labelLg.copyWith(
                    color: BMHColors.bg0,
                    fontWeight: FontWeight.w600)))),
          ]))));
  }

  Widget _field(TextEditingController c, String label, String hint,
      {TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
          style: BMHText.monoSm.copyWith(
            fontSize: 9, letterSpacing: 1.4, color: BMHColors.inkDim)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: keyboard,
          style: BMHText.bodyMd.copyWith(color: BMHColors.ink),
          cursorColor: BMHColors.cyan,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: BMHText.bodyMd.copyWith(color: BMHColors.inkMute),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12))),
      ]);
  }

  Future<void> _confirmDelete(CarerContact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BMHColors.bg2,
        title: Text('Remove ${c.name}?', style: BMHText.heading3),
        content: Text('They will no longer receive low-battery alerts.',
          style: BMHText.bodySm.copyWith(color: BMHColors.inkDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
              style: BMHText.labelMd.copyWith(color: BMHColors.inkDim))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
              style: BMHText.labelMd.copyWith(color: BMHColors.danger))),
        ]));
    if (ok == true) await _svc.removeCarer(c.id);
  }

  Future<void> _sendTest() async {
    setState(() => _sendingTest = true);
    final ok = await _svc.sendTestAlert();
    if (!mounted) return;
    setState(() => _sendingTest = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? BMHColors.sGut : BMHColors.danger,
      content: Text(
        ok
          ? 'Test alert sent to ${_svc.carers.length} '
            '${_svc.carers.length == 1 ? "person" : "people"}'
          : _svc.carers.isEmpty
              ? 'Add at least one person first'
              : 'Could not reach the alert server — check connection',
        style: BMHText.monoSm.copyWith(color: BMHColors.bg0))));
  }

  // ── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final carers = _svc.carers;

    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BMHSpacing.screenH, vertical: 8),
          child: Row(children: [
            BMHIconButton(
              onTap: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded,
                color: BMHColors.ink, size: 16)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BMHEyebrow('Battery alerts'),
                Text('Notify persons', style: BMHText.heading1),
              ])),
          ])),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: BMHSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // How it works
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BMHColors.surface,
                  borderRadius: BorderRadius.circular(BMHRadius.lg),
                  border: Border.all(color: BMHColors.line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ruleRow(Icons.notifications_active_outlined,
                      BMHColors.warn,
                      'At ${BatteryService.warnAt}%',
                      'An alert appears inside the app'),
                    const SizedBox(height: 10),
                    _ruleRow(Icons.campaign_outlined, BMHColors.danger,
                      'Below ${BatteryService.notifyAt}%',
                      'Phone notification + the people below are '
                      'alerted through BioHealthcare'),
                  ])),

              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: BMHSectionTitle(
                  'People to notify · ${carers.length} of '
                  '${BatteryService.maxCarers}')),
                if (_svc.canAddCarer)
                  GestureDetector(
                    onTap: () => _showCarerSheet(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: BMHColors.cyan.withOpacity(0.10),
                        borderRadius:
                            BorderRadius.circular(BMHRadius.full),
                        border: Border.all(
                          color: BMHColors.cyan.withOpacity(0.3))),
                      child: Row(children: [
                        const Icon(Icons.add_rounded,
                          color: BMHColors.cyan, size: 14),
                        const SizedBox(width: 4),
                        Text('Add',
                          style: BMHText.monoSm.copyWith(
                            fontSize: 10, color: BMHColors.cyan)),
                      ]))),
              ]),
              const SizedBox(height: 12),

              if (carers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    color: BMHColors.surface,
                    borderRadius: BorderRadius.circular(BMHRadius.lg),
                    border: Border.all(color: BMHColors.line)),
                  child: Column(children: [
                    const Icon(Icons.family_restroom_rounded,
                      color: BMHColors.inkMute, size: 30),
                    const SizedBox(height: 10),
                    Text('No one added yet',
                      style: BMHText.bodySm.copyWith(
                        color: BMHColors.inkDim)),
                    const SizedBox(height: 4),
                    Text('Add a family member or carer so they know\n'
                         'when this phone is about to switch off.',
                      textAlign: TextAlign.center,
                      style: BMHText.bodySm.copyWith(
                        fontSize: 11, color: BMHColors.inkMute)),
                  ]))
              else
                ...carers.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CarerRow(
                    carer: c,
                    onEdit: () => _showCarerSheet(existing: c),
                    onDelete: () => _confirmDelete(c)))),

              if (!_svc.canAddCarer)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Maximum of ${BatteryService.maxCarers} people reached. '
                    'Remove one to add another.',
                    style: BMHText.bodySm.copyWith(
                      fontSize: 11, color: BMHColors.inkMute))),

              const SizedBox(height: 22),

              // Test the pipeline
              GestureDetector(
                onTap: _sendingTest ? null : _sendTest,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(BMHRadius.full),
                    border: Border.all(
                      color: BMHColors.cyan.withOpacity(0.5))),
                  child: Text(
                    _sendingTest ? 'Sending…' : 'Send test alert',
                    textAlign: TextAlign.center,
                    style: BMHText.labelLg.copyWith(
                      color: BMHColors.cyan,
                      fontWeight: FontWeight.w600)))),

              if (_svc.lastCarerAlertAt != null) ...[
                const SizedBox(height: 10),
                Center(child: Text(
                  'Last alert sent '
                  '${_fmtTime(_svc.lastCarerAlertAt!)}',
                  style: BMHText.monoSm.copyWith(
                    fontSize: 9, color: BMHColors.inkMute))),
              ],

              const SizedBox(height: 40),
            ]))),
      ])),
    );
  }

  Widget _ruleRow(IconData icon, Color color, String title, String body) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: BMHText.labelMd.copyWith(
              color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(body, style: BMHText.bodySm.copyWith(
              fontSize: 11, color: BMHColors.inkDim)),
          ])),
      ]);

  static String _fmtTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }
}

// ─────────────────────────────────────────────────────────
class _CarerRow extends StatelessWidget {
  final CarerContact carer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CarerRow({
    required this.carer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BMHColors.surface,
        borderRadius: BorderRadius.circular(BMHRadius.lg),
        border: Border.all(color: BMHColors.line)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: BMHColors.cyan.withOpacity(0.10),
            shape: BoxShape.circle,
            border: Border.all(
              color: BMHColors.cyan.withOpacity(0.25))),
          child: Center(child: Text(
            carer.name.isEmpty ? '?' : carer.name[0].toUpperCase(),
            style: BMHText.heading3.copyWith(color: BMHColors.cyan)))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(carer.name, style: BMHText.labelLg.copyWith(
              color: BMHColors.ink)),
            const SizedBox(height: 2),
            Text(
              [
                if (carer.relation.isNotEmpty) carer.relation,
                carer.phone,
                if (carer.email.isNotEmpty) carer.email,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BMHText.monoSm.copyWith(
                fontSize: 9, color: BMHColors.inkMute)),
          ])),
        GestureDetector(
          onTap: onEdit,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.edit_outlined,
              color: BMHColors.inkDim, size: 16))),
        GestureDetector(
          onTap: onDelete,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.delete_outline_rounded,
              color: BMHColors.danger, size: 16))),
      ]));
  }
}
