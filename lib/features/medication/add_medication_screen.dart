// ─────────────────────────────────────────────────────────
//  ADD OR EDIT A MEDICATION
//
//  Picking from the catalog fills strength, form, the nutrients the
//  medicine is documented to affect, and the clinical note in one
//  tap — because asking a patient to know that metformin touches B12
//  is asking the wrong person.
//
//  Every auto-filled value stays editable, and "Not listed" drops
//  back to plain typing, so the catalog helps without gatekeeping.
// ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../shared/theme/bmh_tokens.dart';
import '../../shared/widgets/bmh_widgets.dart';
import '../../core/bioresponse/medication_service.dart';
import '../../core/meds/medicine_catalog.dart';
import '../../core/meds/medication_reminder_service.dart';
import '../../core/diet/diet_models.dart';

const _accent = BMHColors.sDna;

class AddMedicationScreen extends StatefulWidget {
  final Medication? existing;
  const AddMedicationScreen({super.key, this.existing});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _svc = MedicationService.instance;

  final _searchC = TextEditingController();
  final _nameC = TextEditingController();
  final _noteC = TextEditingController();
  final _searchFocus = FocusNode();
  final _strengthC = TextEditingController();

  bool _picking = false;      // catalog list open
  bool _freeText = false;     // "not listed" — type the name

  String _brand = '';
  String _klass = '';
  String _strength = '';
  String _unit = 'mg';
  String _form = 'Tablet';
  String _quantity = '1 tablet';

  int _timesPerDay = 1;
  List<int> _times = [480];
  FoodTiming _food = FoodTiming.anytime;
  bool _withWater = false;
  bool _daily = true;
  bool _remind = true;

  DateTime _start = DateTime.now();
  DateTime? _end;

  List<String> _affects = [];
  bool _affectsAuto = false;
  String _catalogNote = '';

  bool get _isEdit => widget.existing != null;

  /// Strength options offered in the dropdown for the chosen medicine.
  List<String> _strengthOptions = const [];
  List<String> _formOptions = MedicineOptions.forms;

  /// The catalog entry behind the chosen medicine, kept so that
  /// changing Form can re-derive the strengths and units that
  /// actually belong to that form.
  MedicineEntry? _entry;

  /// Units valid for the current form.
  List<String> get _unitOptions => MedicineOptions.unitsFor(_form);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameC.text = e.name;
      _searchC.text = e.name;
      _entry = MedicineCatalog.byGeneric(e.name);
      _brand = e.brand;
      _klass = e.klass;
      _strength = e.strength;
      _strengthC.text = e.strength;
      _unit = e.unit.isEmpty ? 'mg' : e.unit;
      _form = e.form;
      _quantity = e.quantity.isEmpty
          ? MedicineOptions.quantitiesFor(e.form).first : e.quantity;
      _timesPerDay = e.timesPerDay;
      _times = e.resolvedTimes;
      _food = e.foodTiming;
      _withWater = e.withWater;
      _daily = e.daily;
      _remind = e.remind;
      _start = e.startDate ?? DateTime.now();
      _end = e.endDate;
      _affects = List.of(e.affects);
      _noteC.text = e.note;
      _freeText = true;

      final entry = MedicineCatalog.byGeneric(e.name);
      if (entry != null) {
        _strengthOptions = entry.strengths;
        _formOptions = _mergeForms(entry.forms);
        _catalogNote = entry.note;
      }
    } else {
      _picking = true;
      _quantity = MedicineOptions.quantitiesFor(_form).first;
    }
  }

  @override
  void dispose() {
    _searchC.dispose();
    _nameC.dispose();
    _noteC.dispose();
    _strengthC.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Forms the medicine actually comes in, first, then the rest — so
  /// the common choice is at the top without hiding the others.
  static List<String> _mergeForms(List<String> preferred) => [
        ...preferred,
        ...MedicineOptions.forms.where((f) => !preferred.contains(f)),
      ];

  void _choose(MedicineEntry e) {
    setState(() {
      _picking = false;
      _freeText = true;
      _entry = e;
      _nameC.text = e.generic;
      _klass = e.klass;
      _brand = _matchedBrand(e, _searchC.text);
      _formOptions = _mergeForms(e.forms);
      _catalogNote = e.note;
      _applyForm(e.defaultForm);

      _affects = List.of(e.affects);
      _affectsAuto = e.affects.isNotEmpty;
      _searchC.text = e.generic;
    });
    _searchFocus.unfocus();
  }

  /// Changing the form re-derives everything that depends on it, so
  /// the four fields can never disagree — a suspension gets mg/5ml
  /// strengths and millilitre doses, a tablet gets milligrams.
  void _applyForm(String form) {
    _form = form;
    _quantity = MedicineOptions.quantitiesFor(form).first;

    final list = _entry?.strengthsFor(form) ?? const <String>[];
    _strengthOptions = list;

    if (list.isNotEmpty) {
      final parts = list.first.split(' ');
      _strength = parts.first;
      _strengthC.text = _strength;
      _unit = parts.length > 1 ? parts.sublist(1).join(' ') : _unit;
    }

    // Keep the unit inside what this form allows.
    final units = MedicineOptions.unitsFor(form);
    if (!units.contains(_unit)) _unit = units.first;
  }

  /// When someone searched "Glycomet", remember that brand.
  static String _matchedBrand(MedicineEntry e, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return '';
    for (final b in e.brands) {
      if (b.toLowerCase().startsWith(q)) return b;
    }
    return '';
  }

  void _typeMyOwn() {
    setState(() {
      _picking = false;
      _freeText = true;
      _nameC.text = _searchC.text.trim();
      _brand = '';
      _klass = '';
      _strengthOptions = const [];
      _formOptions = MedicineOptions.forms;
      _catalogNote = '';
      _affects = [];
      _affectsAuto = false;
      _entry = null;
      _searchC.text = _nameC.text;
    });
    _searchFocus.unfocus();
  }

  void _setTimesPerDay(int n) {
    if (n < 1 || n > 6) return;
    setState(() {
      _timesPerDay = n;
      final next = List<int>.from(_times);
      if (next.length > n) {
        _times = next.take(n).toList();
      } else {
        final defaults = Medication.defaultTimesFor(n);
        while (next.length < n) {
          next.add(defaults[next.length]);
        }
        _times = next;
      }
      _times.sort();
    });
  }

  Future<void> _pickTime(int index) async {
    final current = _times[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: BMHColors.bg3,
            onSurface: BMHColors.ink)),
        child: child!));
    if (picked != null) {
      setState(() {
        _times[index] = picked.hour * 60 + picked.minute;
        _times.sort();
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : (_end ?? now),
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now.add(const Duration(days: 1825)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: BMHColors.bg3,
            onSurface: BMHColors.ink)),
        child: child!));
    if (d != null) {
      setState(() => isStart ? _start = d : _end = d);
    }
  }

  Future<void> _save() async {
    final name = _nameC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: BMHColors.bg3,
        content: Text('Give the medication a name first')));
      return;
    }

    final med = Medication(
      id: widget.existing?.id ??
          'med_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      brand: _brand,
      klass: _klass,
      strength: _strength,
      unit: _unit,
      form: _form,
      quantity: _quantity,
      note: _noteC.text.trim(),
      daily: _daily,
      active: widget.existing?.active ?? true,
      timesPerDay: _timesPerDay,
      doseTimes: _times,
      foodTiming: _food,
      withWater: _withWater,
      startDate: _start,
      endDate: _end,
      remind: _remind,
      affects: _affects);

    _isEdit ? await _svc.update(med) : await _svc.add(med);
    await MedicationReminderService.instance.sync(med);
    if (mounted) Navigator.pop(context, true);
  }

  // ── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BMHColors.bg0,
      body: SafeArea(child: Column(children: [
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
                const BMHEyebrow('MEDICATION AND SUPPLEMENTS'),
                Text(_isEdit ? 'Edit medication' : 'Add medication',
                  style: BMHText.heading1),
              ])),
          ])),

        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BMHSpacing.s5, 4, BMHSpacing.s5, 40),
          children: [
            Text('Not counted as intake. Recorded for your schedule, '
                 'adherence and the nutrient context it adds to your '
                 'blood results.',
              style: BMHText.bodySm.copyWith(
                fontSize: 11, color: BMHColors.inkDim, height: 1.45)),
            const SizedBox(height: 18),

            // ── MEDICINE ──────────────────────────────────
            _label('Medicine'),
            _medicineField(),
            _suggestions(),

            ...[
              const SizedBox(height: 16),

              // ── STRENGTH · UNIT · FORM ──────────────────
              Row(children: [
                SizedBox(width: 84, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Strength'),
                    _strengthField(),
                  ])),
                const SizedBox(width: 9),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Unit'),
                    _dropdown(
                      value: _unitOptions.contains(_unit)
                        ? _unit : _unitOptions.first,
                      items: _unitOptions,
                      title: 'Unit',
                      onChanged: (v) => setState(() => _unit = v)),
                  ])),
                const SizedBox(width: 9),
                Expanded(flex: 2, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Form'),
                    _dropdown(
                      value: _formOptions.contains(_form)
                        ? _form : _formOptions.first,
                      items: _formOptions,
                      title: 'Form',
                      onChanged: (v) => setState(() => _applyForm(v))),
                  ])),
              ]),

              const SizedBox(height: 14),
              _label('Quantity per dose'),
              _dropdown(
                value: MedicineOptions.quantitiesFor(_form).contains(_quantity)
                  ? _quantity
                  : MedicineOptions.quantitiesFor(_form).first,
                items: MedicineOptions.quantitiesFor(_form),
                title: 'Quantity per dose',
                onChanged: (v) => setState(() => _quantity = v)),

              const SizedBox(height: 20),
              const Divider(color: BMHColors.line, height: 1),
              const SizedBox(height: 18),

              // ── SCHEDULE ────────────────────────────────
              _sectionLabel('SCHEDULE', _accent),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text('Times a day',
                  style: BMHText.labelMd.copyWith(color: BMHColors.ink2))),
                _stepper(),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                for (var i = 0; i < _times.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: () => _pickTime(i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: BMHColors.bg3,
                        borderRadius: BorderRadius.circular(BMHRadius.md),
                        border: Border.all(
                          color: _accent.withOpacity(0.32))),
                      child: Column(children: [
                        Text('DOSE ${i + 1}',
                          style: BMHText.monoSm.copyWith(
                            fontSize: 8, letterSpacing: 0.8,
                            color: BMHColors.inkMute)),
                        const SizedBox(height: 3),
                        Text(Medication.formatMinutes(_times[i]),
                          style: BMHText.labelMd.copyWith(
                            fontSize: 12, color: BMHColors.ink)),
                      ]))))
                ],
              ]),

              const SizedBox(height: 16),
              _label('Food timing'),
              Row(children: [
                for (final t in FoodTiming.values) ...[
                  if (t != FoodTiming.values.first) const SizedBox(width: 7),
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _food = t),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _food == t
                          ? BMHColors.sMetabolic : BMHColors.bg3,
                        borderRadius: BorderRadius.circular(BMHRadius.md)),
                      child: Text(t.shortLabel,
                        textAlign: TextAlign.center,
                        style: BMHText.labelMd.copyWith(
                          fontSize: 11,
                          color: _food == t
                            ? BMHColors.bg0 : BMHColors.inkDim)))))
                ],
              ]),

              const SizedBox(height: 14),
              _toggleRow(
                label: 'Take with water',
                value: _withWater,
                onChanged: (v) => setState(() => _withWater = v)),
              const SizedBox(height: 10),
              _toggleRow(
                label: 'Every day',
                sub: _daily
                  ? 'Appears on your schedule daily'
                  : 'Only when you need it',
                value: _daily,
                onChanged: (v) => setState(() => _daily = v)),

              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Starts'),
                    GestureDetector(
                      onTap: () => _pickDate(isStart: true),
                      behavior: HitTestBehavior.opaque,
                      child: _boxed(_fmtDate(_start))),
                  ])),
                const SizedBox(width: 9),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Ends'),
                    GestureDetector(
                      onTap: () async {
                        if (_end != null) {
                          setState(() => _end = null);
                        } else {
                          await _pickDate(isStart: false);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: _boxed(
                        _end == null ? 'Ongoing' : _fmtDate(_end!),
                        dim: _end == null)),
                  ])),
              ]),

              const SizedBox(height: 18),

              // ── REMINDERS ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: BMHColors.bg3,
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(
                    color: _remind
                      ? BMHColors.sGut.withOpacity(0.35) : BMHColors.line)),
                child: Column(children: [
                  Row(children: [
                    Icon(Icons.notifications_active_outlined,
                      color: _remind ? BMHColors.sGut : BMHColors.inkMute,
                      size: 17),
                    const SizedBox(width: 11),
                    Expanded(child: Text('Remind me',
                      style: BMHText.labelLg.copyWith(color: BMHColors.ink))),
                    _switch(_remind, (v) => setState(() => _remind = v)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const SizedBox(width: 28),
                    Expanded(child: Text(
                      _remind
                        ? 'A notification at each dose time. Tapping it '
                          'marks that dose taken.'
                        : 'No notifications. You can still tick doses by '
                          'hand.',
                      style: BMHText.bodySm.copyWith(
                        fontSize: 10.5, color: BMHColors.inkMute,
                        height: 1.45))),
                  ]),
                ])),

              const SizedBox(height: 20),
              const Divider(color: BMHColors.line, height: 1),
              const SizedBox(height: 18),

              // ── MAY AFFECT ──────────────────────────────
              Row(children: [
                Expanded(child: _sectionLabel('MAY AFFECT', BMHColors.inkDim)),
                if (_affectsAuto)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BMHColors.sGut.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(BMHRadius.full)),
                    child: Text('AUTO-FILLED',
                      style: BMHText.monoSm.copyWith(
                        fontSize: 7.5, letterSpacing: 0.7,
                        color: BMHColors.sGut))),
              ]),
              const SizedBox(height: 6),
              Text(_affectsAuto
                  ? 'From the catalog entry for ${_nameC.text.trim()}. Tap '
                    'to remove, or add another.'
                  : 'Nutrients this medication is documented to affect. '
                    'Used only to add context to your biomarkers.',
                style: BMHText.bodySm.copyWith(
                  fontSize: 10.5, color: BMHColors.inkMute, height: 1.4)),
              const SizedBox(height: 10),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (final m in Micronutrient.all)
                  GestureDetector(
                    onTap: () => setState(() {
                      _affects.contains(m.name)
                        ? _affects.remove(m.name)
                        : _affects.add(m.name);
                      _affectsAuto = false;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: _affects.contains(m.name)
                          ? _accent.withOpacity(0.16) : BMHColors.bg3,
                        borderRadius: BorderRadius.circular(BMHRadius.full),
                        border: Border.all(
                          color: _affects.contains(m.name)
                            ? _accent.withOpacity(0.45) : BMHColors.line)),
                      child: Text(m.name,
                        style: BMHText.monoSm.copyWith(
                          fontSize: 9,
                          color: _affects.contains(m.name)
                            ? _accent : BMHColors.inkDim)))),
              ]),

              if (_catalogNote.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BMHColors.bg2,
                    borderRadius: BorderRadius.circular(BMHRadius.md),
                    border: Border.all(color: BMHColors.line)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                        color: BMHColors.inkDim, size: 14),
                      const SizedBox(width: 9),
                      Expanded(child: Text(_catalogNote,
                        style: BMHText.bodySm.copyWith(
                          fontSize: 10.5, color: BMHColors.inkMute,
                          height: 1.45))),
                    ])),
              ],

              const SizedBox(height: 16),
              _label('Your note'),
              _textField(_noteC, 'anything you want to remember'),

              const SizedBox(height: 22),
              GestureDetector(
                onTap: _save,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(BMHRadius.full)),
                  child: Text(
                    _isEdit ? 'Save changes' : 'Save medication',
                    textAlign: TextAlign.center,
                    style: BMHText.labelLg.copyWith(
                      color: BMHColors.bg0,
                      fontWeight: FontWeight.w600)))),

              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BMHColors.bg2,
                  borderRadius: BorderRadius.circular(BMHRadius.md),
                  border: Border.all(color: BMHColors.line)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined,
                      color: BMHColors.inkDim, size: 14),
                    const SizedBox(width: 9),
                    Expanded(child: Text(
                      'Never start, stop or change a prescription based on '
                      'what this app shows. Bring it to your care team '
                      'instead.',
                      style: BMHText.bodySm.copyWith(
                        fontSize: 10.5, color: BMHColors.inkMute,
                        height: 1.45))),
                  ])),
            ],
          ])),
      ])),
    );
  }

  // ── MEDICINE FIELD + INLINE SUGGESTIONS ─────────────────
  // The field stays in place. Typing filters the catalog and the
  // matches drop in directly beneath it, so the rest of the form
  // never disappears behind a separate picker screen.

  bool get _showSuggest =>
      _picking && _searchC.text.trim().isNotEmpty;

  List<MedicineEntry> get _results =>
      MedicineCatalog.search(_searchC.text, limit: 8);

  Widget _medicineField() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: BMHColors.bg3,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(BMHRadius.md),
        topRight: const Radius.circular(BMHRadius.md),
        bottomLeft: Radius.circular(_showSuggest ? 0 : BMHRadius.md),
        bottomRight: Radius.circular(_showSuggest ? 0 : BMHRadius.md)),
      border: Border.all(
        color: _picking ? _accent.withOpacity(0.45) : BMHColors.line)),
    child: Row(children: [
      Icon(_picking ? Icons.search_rounded : Icons.medication_outlined,
        color: _picking ? _accent : BMHColors.inkDim, size: 16),
      const SizedBox(width: 9),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchC,
            focusNode: _searchFocus,
            autofocus: !_isEdit,
            textCapitalization: TextCapitalization.words,
            onTap: () => setState(() => _picking = true),
            onChanged: (v) => setState(() {
              _picking = true;
              _nameC.text = v.trim();
              if (v.trim().isEmpty) {
                _brand = '';
                _klass = '';
                _catalogNote = '';
                _strengthOptions = const [];
                _formOptions = MedicineOptions.forms;
                _affects = [];
                _affectsAuto = false;
              }
            }),
            style: BMHText.bodyMd.copyWith(color: BMHColors.ink),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              hintText: 'Search brand or generic name',
              hintStyle: BMHText.bodySm.copyWith(
                fontSize: 12, color: BMHColors.inkMute))),
          if (!_picking && (_klass.isNotEmpty || _brand.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(
                [if (_brand.isNotEmpty) _brand, if (_klass.isNotEmpty) _klass]
                    .join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BMHText.monoSm.copyWith(
                  fontSize: 9, color: BMHColors.inkMute))),
        ])),
      if (_searchC.text.isNotEmpty)
        GestureDetector(
          onTap: () => setState(() {
            _searchC.clear();
            _nameC.clear();
            _brand = '';
            _klass = '';
            _catalogNote = '';
            _strengthOptions = const [];
            _formOptions = MedicineOptions.forms;
            _affects = [];
            _affectsAuto = false;
            _picking = true;
          }),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded,
              color: BMHColors.inkDim, size: 15))),
    ]));

  Widget _suggestions() {
    if (!_showSuggest) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Search "Glycomet" or "Metformin" — both find the same entry.',
          style: BMHText.bodySm.copyWith(
            fontSize: 10, color: BMHColors.inkMute)));
    }
    final results = _results;
    return Container(
      decoration: BoxDecoration(
        color: BMHColors.bg2,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(BMHRadius.md)),
        border: Border.all(color: _accent.withOpacity(0.45))),
      child: Column(children: [
        for (final e in results)
          GestureDetector(
            onTap: () => _choose(e),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 13, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(
                  color: BMHColors.lineSoft))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.generic,
                    style: BMHText.labelMd.copyWith(
                      fontSize: 13, color: BMHColors.ink)),
                  const SizedBox(height: 2),
                  Text(e.brandLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9, color: BMHColors.inkMute)),
                ]))),
        GestureDetector(
          onTap: _typeMyOwn,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 13, vertical: 13),
            child: Row(children: [
              const Icon(Icons.add_rounded, color: _accent, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text(
                results.isEmpty
                  ? 'Use "${_searchC.text.trim()}"'
                  : 'Not listed — use what I typed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BMHText.labelMd.copyWith(
                  fontSize: 12, color: _accent))),
            ]))),
      ]));
  }

  // ── SMALL PIECES ────────────────────────────────────────
  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(s,
      style: BMHText.bodySm.copyWith(
        fontSize: 11, color: BMHColors.inkDim)));

  Widget _sectionLabel(String s, Color c) => Text(s,
    style: BMHText.monoSm.copyWith(
      fontSize: 9, letterSpacing: 1.3, color: c));

  Widget _boxed(String text, {bool dim = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: BMHColors.bg3,
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.line)),
    child: Text(text,
      style: BMHText.bodySm.copyWith(
        fontSize: 12,
        color: dim ? BMHColors.inkDim : BMHColors.ink)));

  /// Strength is a dropdown when the catalog knows the strengths this
  /// medicine comes in, and a plain field when it does not.
  Widget _strengthField() {
    if (_strengthOptions.isEmpty) {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: BMHColors.bg3,
          borderRadius: BorderRadius.circular(BMHRadius.md),
          border: Border.all(color: BMHColors.line)),
        child: Center(child: TextField(
          controller: _strengthC,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => _strength = v,
          style: BMHText.bodySm.copyWith(
            fontSize: 12.5, color: BMHColors.ink),
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: '500',
            hintStyle: BMHText.bodySm.copyWith(
              fontSize: 12.5, color: BMHColors.inkMute)))));
    }

    final options = _strengthOptions
        .map((s) => s.split(' ').first)
        .toSet()
        .toList();
    return _dropdown(
      value: options.contains(_strength) ? _strength : options.first,
      items: options,
      title: 'Strength',
      onChanged: (v) => setState(() {
        _strength = v;
        // Adopt the unit that ships with that strength, e.g. "60000 IU".
        for (final s in _strengthOptions) {
          final parts = s.split(' ');
          if (parts.first == v && parts.length > 1) {
            _unit = parts.sublist(1).join(' ');
            break;
          }
        }
      }));
  }

  /// One tap opens a titled sheet from the bottom. Same control for
  /// Strength, Unit, Form and Quantity, so the four fields behave
  /// identically and none of them cover the form while open.
  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    String? title,
  }) =>
      GestureDetector(
        onTap: () => _openSheet(
          title: title ?? 'Select',
          items: items,
          current: value,
          onPick: onChanged),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: BMHColors.bg3,
            borderRadius: BorderRadius.circular(BMHRadius.md),
            border: Border.all(color: BMHColors.line)),
          child: Row(children: [
            Expanded(child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BMHText.bodySm.copyWith(
                fontSize: 12.5, color: BMHColors.ink))),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
              color: BMHColors.inkDim, size: 18),
          ])));

  Future<void> _openSheet({
    required String title,
    required List<String> items,
    required String current,
    required ValueChanged<String> onPick,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.55),
        decoration: const BoxDecoration(
          color: BMHColors.bg2,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BMHRadius.lg)),
          border: Border(
            top: BorderSide(color: BMHColors.line),
            left: BorderSide(color: BMHColors.line),
            right: BorderSide(color: BMHColors.line))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: BMHColors.line,
              borderRadius: BorderRadius.circular(BMHRadius.full))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              Expanded(child: Text(title, style: BMHText.labelLg)),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                    color: BMHColors.inkDim, size: 18))),
            ])),
          const SizedBox(height: 8),
          Flexible(child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            children: [
              for (final i in items)
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: i == current
                        ? _accent.withOpacity(0.14)
                        : BMHColors.bg3,
                      borderRadius: BorderRadius.circular(BMHRadius.md),
                      border: Border.all(
                        color: i == current
                          ? _accent.withOpacity(0.55)
                          : BMHColors.line)),
                    child: Row(children: [
                      Expanded(child: Text(i,
                        style: BMHText.bodyMd.copyWith(
                          fontSize: 14,
                          color: i == current
                            ? BMHColors.ink : BMHColors.ink2))),
                      if (i == current)
                        const Icon(Icons.check_rounded,
                          color: _accent, size: 17),
                    ]))),
            ])),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 6),
        ])));
    if (picked != null) onPick(picked);
  }

  Widget _textField(TextEditingController c, String hint) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    decoration: BoxDecoration(
      color: BMHColors.bg3,
      borderRadius: BorderRadius.circular(BMHRadius.md),
      border: Border.all(color: BMHColors.line)),
    child: TextField(
      controller: c,
      minLines: 3,
      maxLines: 5,
      textCapitalization: TextCapitalization.sentences,
      style: BMHText.bodySm.copyWith(
        fontSize: 13, color: BMHColors.ink, height: 1.45),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        hintText: hint,
        hintStyle: BMHText.bodySm.copyWith(
          fontSize: 12.5, color: BMHColors.inkMute))));

  Widget _stepper() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: BMHColors.bg3,
      borderRadius: BorderRadius.circular(BMHRadius.full)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => _setTimesPerDay(_timesPerDay - 1),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.remove_rounded,
            size: 16,
            color: _timesPerDay > 1
              ? BMHColors.inkDim : BMHColors.inkFaint))),
      SizedBox(width: 26, child: Text('$_timesPerDay',
        textAlign: TextAlign.center,
        style: BMHText.labelMd.copyWith(color: BMHColors.ink))),
      GestureDetector(
        onTap: () => _setTimesPerDay(_timesPerDay + 1),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.add_rounded,
            size: 16,
            color: _timesPerDay < 6 ? _accent : BMHColors.inkFaint))),
    ]));

  Widget _toggleRow({
    required String label,
    String? sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: BMHColors.bg3,
            borderRadius: BorderRadius.circular(BMHRadius.md),
            border: Border.all(
              color: value
                ? BMHColors.sGut.withOpacity(0.35) : BMHColors.line)),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: BMHText.labelMd.copyWith(color: BMHColors.ink)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub,
                    style: BMHText.monoSm.copyWith(
                      fontSize: 9, color: BMHColors.inkMute)),
                ],
              ])),
            _switch(value, onChanged),
          ])));

  Widget _switch(bool value, ValueChanged<bool> onChanged) =>
      GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: 40, height: 23,
          decoration: BoxDecoration(
            color: value ? BMHColors.sGut : BMHColors.bg4,
            borderRadius: BorderRadius.circular(BMHRadius.full)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 150),
            alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 19, height: 19,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle)))));

  static String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
