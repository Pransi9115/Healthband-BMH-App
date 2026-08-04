// ─────────────────────────────────────────────────────────
//  MEDICINE CATALOG
//
//  A bundled, offline list of commonly prescribed medicines with
//  the brand names actually printed on the strip in India, so a
//  patient can search for "Glycomet" and land on Metformin.
//
//  Every entry carries:
//    · the generic name and its drug class
//    · brand aliases, searched alongside the generic
//    · the strengths and forms it is normally supplied in
//    · the nutrients it is documented to affect
//
//  The nutrient names below MUST match Micronutrient.all in
//  core/diet/diet_models.dart, because BiomarkerLinkService reads
//  Medication.affects against that same vocabulary.
//
//  IMPORTANT: `affects` is factual pharmacology used to add context
//  to a blood result. It is never advice, and never a reason to stop
//  a prescription. Nothing here replaces the care team.
//
//  Not exhaustive by design. Anything missing is entered freehand
//  through "Not listed — type your own", which keeps the catalog a
//  convenience rather than a gate.
// ─────────────────────────────────────────────────────────

class MedicineEntry {
  final String generic;
  final String klass;
  final List<String> brands;
  final List<String> strengths;
  final List<String> forms;
  final List<String> affects;
  final String note;

  const MedicineEntry(
    this.generic,
    this.klass,
    this.brands,
    this.strengths,
    this.forms, {
    this.affects = const [],
    this.note = '',
  });

  String get defaultStrength => strengths.isEmpty ? '' : strengths.first;
  String get defaultForm => forms.isEmpty ? 'Tablet' : forms.first;

  /// "Metformin" or "Metformin (Glycomet)" when matched by brand.
  String displayFor(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return generic;
    for (final b in brands) {
      if (b.toLowerCase().startsWith(q)) return '$generic ($b)';
    }
    return generic;
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (generic.toLowerCase().contains(q)) return true;
    if (klass.toLowerCase().contains(q)) return true;
    for (final b in brands) {
      if (b.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  /// Brands shown under the generic in the picker row.
  String get brandLine => brands.isEmpty ? klass : brands.take(3).join(' · ');
}

// ─────────────────────────────────────────────────────────
//  DOSE UNITS AND FORMS
// ─────────────────────────────────────────────────────────
class MedicineOptions {
  MedicineOptions._();

  static const units = <String>[
    'mg', 'mcg', 'g', 'ml', 'IU', 'units', '%', 'drops', 'puffs', 'mEq',
  ];

  static const forms = <String>[
    'Tablet', 'Capsule', 'Chewable tablet', 'Sublingual tablet',
    'Dispersible tablet', 'Syrup', 'Suspension', 'Oral drops',
    'Sachet or powder', 'Injection', 'Insulin pen', 'IV infusion',
    'Inhaler', 'Rotacap', 'Nebuliser solution', 'Nasal spray',
    'Patch', 'Cream or ointment', 'Gel', 'Eye drops', 'Ear drops',
    'Suppository', 'Pessary', 'Lozenge',
  ];

  /// Quantity taken at each dose, offered per form.
  static List<String> quantitiesFor(String form) {
    switch (form) {
      case 'Syrup':
      case 'Suspension':
        return ['2.5 ml', '5 ml', '10 ml', '15 ml', '20 ml'];
      case 'Oral drops':
      case 'Eye drops':
      case 'Ear drops':
        return ['1 drop', '2 drops', '3 drops', '4 drops'];
      case 'Injection':
      case 'Insulin pen':
      case 'IV infusion':
        return ['1 injection', '2 units', '4 units', '6 units',
                '8 units', '10 units', '12 units', '16 units', '20 units'];
      case 'Inhaler':
      case 'Nasal spray':
      case 'Nebuliser solution':
        return ['1 puff', '2 puffs', '3 puffs', '4 puffs'];
      case 'Sachet or powder':
        return ['1 sachet', '2 sachets', 'Half sachet'];
      case 'Cream or ointment':
      case 'Gel':
        return ['Thin layer', 'Fingertip unit', '2 fingertip units'];
      case 'Patch':
        return ['1 patch'];
      case 'Suppository':
      case 'Pessary':
        return ['1', '2'];
      case 'Capsule':
        return ['1 capsule', '2 capsules', '3 capsules'];
      default:
        return ['Half tablet', '1 tablet', '1.5 tablets',
                '2 tablets', '3 tablets'];
    }
  }
}

// ─────────────────────────────────────────────────────────
//  THE CATALOG
// ─────────────────────────────────────────────────────────
class MedicineCatalog {
  MedicineCatalog._();

  static List<MedicineEntry> search(String query, {int limit = 40}) {
    final out = <MedicineEntry>[];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return all.take(limit).toList();
    }
    // Exact and prefix matches first, so "pan" surfaces Pantoprazole
    // before it surfaces anything that merely contains "pan".
    for (final m in all) {
      if (m.generic.toLowerCase().startsWith(q)) out.add(m);
    }
    for (final m in all) {
      if (out.contains(m)) continue;
      for (final b in m.brands) {
        if (b.toLowerCase().startsWith(q)) { out.add(m); break; }
      }
    }
    for (final m in all) {
      if (out.contains(m)) continue;
      if (m.matches(q)) out.add(m);
    }
    return out.take(limit).toList();
  }

  static MedicineEntry? byGeneric(String generic) {
    for (final m in all) {
      if (m.generic.toLowerCase() == generic.toLowerCase()) return m;
    }
    return null;
  }

  static const all = <MedicineEntry>[
    // ── DIABETES ──────────────────────────────────────────
    MedicineEntry('Metformin', 'Antidiabetic · biguanide',
      ['Glycomet', 'Gluconorm', 'Obimet', 'Carbophage', 'Glyciphage'],
      ['250 mg', '500 mg', '850 mg', '1000 mg'],
      ['Tablet'],
      affects: ['Vitamin B12', 'Folate'],
      note: 'Long-term metformin is associated with lower vitamin B12 '
          'levels. Periodic B12 checks are usual.'),
    MedicineEntry('Glimepiride', 'Antidiabetic · sulfonylurea',
      ['Amaryl', 'Glimestar', 'Zoryl', 'Glimisave'],
      ['0.5 mg', '1 mg', '2 mg', '3 mg', '4 mg'], ['Tablet']),
    MedicineEntry('Gliclazide', 'Antidiabetic · sulfonylurea',
      ['Diamicron', 'Reclide', 'Glizid', 'Dianorm'],
      ['30 mg', '40 mg', '60 mg', '80 mg'], ['Tablet']),
    MedicineEntry('Glipizide', 'Antidiabetic · sulfonylurea',
      ['Glynase', 'Glytop'], ['2.5 mg', '5 mg', '10 mg'], ['Tablet']),
    MedicineEntry('Sitagliptin', 'Antidiabetic · DPP-4 inhibitor',
      ['Januvia', 'Istavel', 'Sitazit', 'Zituvia'],
      ['25 mg', '50 mg', '100 mg'], ['Tablet']),
    MedicineEntry('Vildagliptin', 'Antidiabetic · DPP-4 inhibitor',
      ['Galvus', 'Zomelis', 'Jalra', 'Vysov'],
      ['50 mg'], ['Tablet']),
    MedicineEntry('Teneligliptin', 'Antidiabetic · DPP-4 inhibitor',
      ['Tenepure', 'Zita', 'Tenglyn', 'Teneza'],
      ['20 mg'], ['Tablet']),
    MedicineEntry('Dapagliflozin', 'Antidiabetic · SGLT2 inhibitor',
      ['Forxiga', 'Oxra', 'Dapanorm', 'Udapa'],
      ['5 mg', '10 mg'], ['Tablet'],
      affects: ['Magnesium'],
      note: 'Increases urine output, which can shift fluid and '
          'electrolyte balance.'),
    MedicineEntry('Empagliflozin', 'Antidiabetic · SGLT2 inhibitor',
      ['Jardiance', 'Gibtulio', 'Empaglyn'],
      ['10 mg', '25 mg'], ['Tablet'], affects: ['Magnesium']),
    MedicineEntry('Pioglitazone', 'Antidiabetic · thiazolidinedione',
      ['Pioz', 'Piozone', 'Pioglit'], ['7.5 mg', '15 mg', '30 mg'],
      ['Tablet']),
    MedicineEntry('Acarbose', 'Antidiabetic · alpha-glucosidase inhibitor',
      ['Glucobay', 'Asucrose'], ['25 mg', '50 mg', '100 mg'], ['Tablet']),
    MedicineEntry('Voglibose', 'Antidiabetic · alpha-glucosidase inhibitor',
      ['Volix', 'Vogs', 'Voglinorm'], ['0.2 mg', '0.3 mg'], ['Tablet']),
    MedicineEntry('Insulin glargine', 'Insulin · long acting',
      ['Lantus', 'Basalog', 'Glaritus', 'Toujeo'],
      ['100 IU', '300 IU'], ['Insulin pen', 'Injection'],
      affects: ['Potassium', 'Magnesium'],
      note: 'Insulin moves potassium into cells, which can lower blood '
          'potassium.'),
    MedicineEntry('Insulin human', 'Insulin · short acting',
      ['Huminsulin', 'Actrapid', 'Insugen', 'Wosulin'],
      ['40 IU', '100 IU'], ['Insulin pen', 'Injection'],
      affects: ['Potassium', 'Magnesium']),
    MedicineEntry('Insulin aspart', 'Insulin · rapid acting',
      ['NovoRapid', 'Novomix', 'Ryzodeg'], ['100 IU'],
      ['Insulin pen', 'Injection'], affects: ['Potassium']),
    MedicineEntry('Semaglutide', 'GLP-1 receptor agonist',
      ['Ozempic', 'Rybelsus', 'Wegovy'],
      ['0.25 mg', '0.5 mg', '1 mg', '3 mg', '7 mg', '14 mg'],
      ['Injection', 'Tablet'],
      note: 'Appetite falls sharply on GLP-1 medication. The risk shifts '
          'from eating too much to eating too little, so protein and '
          'micronutrient intake need watching.'),
    MedicineEntry('Liraglutide', 'GLP-1 receptor agonist',
      ['Victoza', 'Saxenda'], ['0.6 mg', '1.2 mg', '1.8 mg', '3 mg'],
      ['Injection'],
      note: 'Appetite reduction can pull total intake below target.'),
    MedicineEntry('Tirzepatide', 'GIP and GLP-1 receptor agonist',
      ['Mounjaro', 'Zepbound'], ['2.5 mg', '5 mg', '7.5 mg', '10 mg'],
      ['Injection'],
      note: 'Appetite reduction can pull total intake below target.'),

    // ── ACID, STOMACH AND GUT ─────────────────────────────
    MedicineEntry('Omeprazole', 'Proton pump inhibitor',
      ['Omez', 'Ocid', 'Omecip'], ['10 mg', '20 mg', '40 mg'],
      ['Capsule', 'Tablet'],
      affects: ['Vitamin B12', 'Magnesium', 'Calcium', 'Iron'],
      note: 'Reduced stomach acid lowers absorption of B12, magnesium, '
          'calcium and iron from food.'),
    MedicineEntry('Pantoprazole', 'Proton pump inhibitor',
      ['Pan', 'Pantocid', 'Pantop', 'Pan-D', 'Pantodac'],
      ['20 mg', '40 mg'], ['Tablet', 'Injection'],
      affects: ['Vitamin B12', 'Magnesium', 'Calcium', 'Iron'],
      note: 'Reduced stomach acid lowers absorption of B12, magnesium, '
          'calcium and iron from food.'),
    MedicineEntry('Rabeprazole', 'Proton pump inhibitor',
      ['Razo', 'Rabium', 'Veloz', 'Rabekind'], ['10 mg', '20 mg'],
      ['Tablet'],
      affects: ['Vitamin B12', 'Magnesium', 'Calcium', 'Iron']),
    MedicineEntry('Esomeprazole', 'Proton pump inhibitor',
      ['Nexpro', 'Sompraz', 'Esoz'], ['20 mg', '40 mg'], ['Tablet'],
      affects: ['Vitamin B12', 'Magnesium', 'Calcium', 'Iron']),
    MedicineEntry('Lansoprazole', 'Proton pump inhibitor',
      ['Lanzol', 'Junior Lanzol'], ['15 mg', '30 mg'],
      ['Capsule', 'Tablet'],
      affects: ['Vitamin B12', 'Magnesium', 'Calcium', 'Iron']),
    MedicineEntry('Famotidine', 'H2 blocker',
      ['Topcid', 'Famocid'], ['20 mg', '40 mg'], ['Tablet'],
      affects: ['Vitamin B12', 'Iron']),
    MedicineEntry('Ranitidine', 'H2 blocker',
      ['Zinetac', 'Rantac', 'Aciloc'], ['150 mg', '300 mg'], ['Tablet'],
      affects: ['Vitamin B12', 'Iron']),
    MedicineEntry('Domperidone', 'Prokinetic',
      ['Domstal', 'Vomistop', 'Dom-DT'], ['10 mg'],
      ['Tablet', 'Suspension']),
    MedicineEntry('Metoclopramide', 'Prokinetic',
      ['Perinorm', 'Reglan'], ['5 mg', '10 mg'],
      ['Tablet', 'Injection']),
    MedicineEntry('Ondansetron', 'Anti-emetic',
      ['Emeset', 'Vomikind', 'Ondem'], ['4 mg', '8 mg'],
      ['Tablet', 'Syrup', 'Injection']),
    MedicineEntry('Sucralfate', 'Mucosal protectant',
      ['Sucrafil', 'Sucral'], ['1 g'], ['Suspension', 'Tablet'],
      affects: ['Phosphorus', 'Iron'],
      note: 'Binds phosphate in the gut and can reduce absorption of '
          'other medicines taken at the same time.'),
    MedicineEntry('Antacid gel', 'Antacid',
      ['Digene', 'Gelusil', 'Mucaine'], ['5 ml', '10 ml'],
      ['Suspension', 'Chewable tablet'],
      affects: ['Iron', 'Phosphorus', 'Calcium'],
      note: 'Aluminium and magnesium antacids bind phosphate and reduce '
          'iron absorption. Space them apart from meals and tablets.'),
    MedicineEntry('Lactulose', 'Osmotic laxative',
      ['Duphalac', 'Looz', 'Livoluk'], ['10 g', '15 ml', '30 ml'],
      ['Syrup'], affects: ['Potassium'],
      note: 'Ongoing loose stools can lower potassium and magnesium.'),
    MedicineEntry('Ispaghula husk', 'Bulk-forming laxative',
      ['Isabgol', 'Naturolax', 'Fybogel'], ['1 sachet', '5 g'],
      ['Sachet or powder'],
      affects: ['Iron', 'Calcium', 'Zinc'],
      note: 'Soluble fibre can bind minerals if taken at the same time '
          'as a supplement.'),
    MedicineEntry('Mesalamine', 'Aminosalicylate',
      ['Mesacol', 'Mezavant', 'Octasa'], ['400 mg', '800 mg', '1.2 g'],
      ['Tablet', 'Suppository'], affects: ['Folate']),
    MedicineEntry('Ursodeoxycholic acid', 'Bile acid',
      ['Udiliv', 'Ursocol'], ['150 mg', '300 mg'], ['Tablet']),
    MedicineEntry('Dicyclomine', 'Antispasmodic',
      ['Cyclopam', 'Colimex'], ['10 mg', '20 mg'],
      ['Tablet', 'Syrup', 'Injection']),
    MedicineEntry('Hyoscine butylbromide', 'Antispasmodic',
      ['Buscopan'], ['10 mg'], ['Tablet', 'Injection']),
    MedicineEntry('Rifaximin', 'Gut antibiotic',
      ['Rifagut', 'Ciblor'], ['200 mg', '400 mg', '550 mg'], ['Tablet']),

    // ── HEART, BLOOD PRESSURE AND LIPIDS ──────────────────
    MedicineEntry('Atorvastatin', 'Statin',
      ['Atorva', 'Storvas', 'Lipvas', 'Tonact'],
      ['5 mg', '10 mg', '20 mg', '40 mg', '80 mg'], ['Tablet'],
      note: 'Statins modestly lower coenzyme Q10. Muscle aches are worth '
          'reporting to the care team.'),
    MedicineEntry('Rosuvastatin', 'Statin',
      ['Rosuvas', 'Crestor', 'Rozat', 'Rosulip'],
      ['5 mg', '10 mg', '20 mg', '40 mg'], ['Tablet'],
      note: 'Statins modestly lower coenzyme Q10.'),
    MedicineEntry('Simvastatin', 'Statin',
      ['Simvotin', 'Simcard'], ['10 mg', '20 mg', '40 mg'], ['Tablet']),
    MedicineEntry('Fenofibrate', 'Fibrate',
      ['Lipicard', 'Fenolip', 'Tricor'], ['67 mg', '145 mg', '160 mg',
      '200 mg'], ['Tablet', 'Capsule']),
    MedicineEntry('Ezetimibe', 'Cholesterol absorption inhibitor',
      ['Ezetib', 'Zetia'], ['10 mg'], ['Tablet'],
      affects: ['Vitamin D', 'Vitamin A']),
    MedicineEntry('Aspirin', 'Antiplatelet',
      ['Ecosprin', 'Disprin', 'Loprin'], ['75 mg', '81 mg', '150 mg',
      '325 mg'], ['Tablet'],
      affects: ['Iron', 'Folate', 'Vitamin C'],
      note: 'Long-term use can cause slow blood loss from the gut, which '
          'shows up as low iron.'),
    MedicineEntry('Clopidogrel', 'Antiplatelet',
      ['Clopilet', 'Deplatt', 'Plavix', 'Clavix'], ['75 mg', '150 mg'],
      ['Tablet'], affects: ['Iron']),
    MedicineEntry('Warfarin', 'Anticoagulant',
      ['Warf', 'Sofarin', 'Uniwarfin'], ['1 mg', '2 mg', '3 mg', '5 mg'],
      ['Tablet'],
      note: 'Vitamin K intake must stay steady, not zero. Sudden changes '
          'in green vegetables or supplements shift the INR — discuss any '
          'change with the care team first.'),
    MedicineEntry('Rivaroxaban', 'Anticoagulant',
      ['Xarelto', 'Rivaflo'], ['2.5 mg', '10 mg', '15 mg', '20 mg'],
      ['Tablet']),
    MedicineEntry('Apixaban', 'Anticoagulant',
      ['Eliquis', 'Apixabid'], ['2.5 mg', '5 mg'], ['Tablet']),
    MedicineEntry('Dabigatran', 'Anticoagulant',
      ['Pradaxa', 'Dabigat'], ['75 mg', '110 mg', '150 mg'], ['Capsule']),
    MedicineEntry('Enoxaparin', 'Low molecular weight heparin',
      ['Clexane', 'Lomoh'], ['40 mg', '60 mg', '80 mg'], ['Injection'],
      affects: ['Potassium'],
      note: 'Prolonged heparin use can raise potassium and affect bone '
          'density.'),
    MedicineEntry('Amlodipine', 'Calcium channel blocker',
      ['Amlong', 'Amlopres', 'Stamlo', 'Amlokind'],
      ['2.5 mg', '5 mg', '10 mg'], ['Tablet']),
    MedicineEntry('Cilnidipine', 'Calcium channel blocker',
      ['Cilacar', 'Cilanorm', 'Nexovas'], ['5 mg', '10 mg', '20 mg'],
      ['Tablet']),
    MedicineEntry('Telmisartan', 'Angiotensin receptor blocker',
      ['Telma', 'Telsartan', 'Telvas', 'Telpres'],
      ['20 mg', '40 mg', '80 mg'], ['Tablet'],
      affects: ['Potassium'],
      note: 'Can raise blood potassium, so potassium supplements and salt '
          'substitutes need care.'),
    MedicineEntry('Losartan', 'Angiotensin receptor blocker',
      ['Losar', 'Repace', 'Covance'], ['25 mg', '50 mg', '100 mg'],
      ['Tablet'], affects: ['Potassium']),
    MedicineEntry('Olmesartan', 'Angiotensin receptor blocker',
      ['Olmezest', 'Olmat', 'Olsar'], ['10 mg', '20 mg', '40 mg'],
      ['Tablet'], affects: ['Potassium']),
    MedicineEntry('Ramipril', 'ACE inhibitor',
      ['Cardace', 'Ramistar', 'Ramipres'],
      ['1.25 mg', '2.5 mg', '5 mg', '10 mg'], ['Tablet', 'Capsule'],
      affects: ['Potassium', 'Zinc'],
      note: 'ACE inhibitors can raise potassium and lower zinc over time.'),
    MedicineEntry('Enalapril', 'ACE inhibitor',
      ['Envas', 'Enam'], ['2.5 mg', '5 mg', '10 mg'], ['Tablet'],
      affects: ['Potassium', 'Zinc']),
    MedicineEntry('Lisinopril', 'ACE inhibitor',
      ['Listril', 'Lipril'], ['2.5 mg', '5 mg', '10 mg'], ['Tablet'],
      affects: ['Potassium', 'Zinc']),
    MedicineEntry('Metoprolol', 'Beta blocker',
      ['Metolar', 'Betaloc', 'Met XL', 'Revelol'],
      ['25 mg', '50 mg', '100 mg'], ['Tablet']),
    MedicineEntry('Atenolol', 'Beta blocker',
      ['Aten', 'Tenormin', 'Betacard'], ['25 mg', '50 mg', '100 mg'],
      ['Tablet']),
    MedicineEntry('Bisoprolol', 'Beta blocker',
      ['Concor', 'Corbis', 'Bisolong'], ['2.5 mg', '5 mg', '10 mg'],
      ['Tablet']),
    MedicineEntry('Nebivolol', 'Beta blocker',
      ['Nebicard', 'Nodon', 'Nebilong'], ['2.5 mg', '5 mg', '10 mg'],
      ['Tablet']),
    MedicineEntry('Carvedilol', 'Beta blocker',
      ['Carloc', 'Carca'], ['3.125 mg', '6.25 mg', '12.5 mg', '25 mg'],
      ['Tablet']),
    MedicineEntry('Propranolol', 'Beta blocker',
      ['Ciplar', 'Inderal'], ['10 mg', '20 mg', '40 mg'], ['Tablet']),
    MedicineEntry('Ivabradine', 'Heart rate lowering agent',
      ['Ivabrad', 'Inaspro'], ['5 mg', '7.5 mg'], ['Tablet']),
    MedicineEntry('Digoxin', 'Cardiac glycoside',
      ['Lanoxin', 'Digox'], ['0.0625 mg', '0.125 mg', '0.25 mg'],
      ['Tablet'],
      affects: ['Magnesium', 'Potassium'],
      note: 'Low potassium or magnesium increases digoxin toxicity risk. '
          'These are usually monitored together.'),
    MedicineEntry('Isosorbide mononitrate', 'Nitrate',
      ['Monotrate', 'Ismo', 'Monit'], ['10 mg', '20 mg', '40 mg'],
      ['Tablet']),
    MedicineEntry('Sacubitril and valsartan', 'ARNI',
      ['Vymada', 'Entresto'], ['50 mg', '100 mg', '200 mg'], ['Tablet'],
      affects: ['Potassium']),

    // ── DIURETICS ─────────────────────────────────────────
    MedicineEntry('Furosemide', 'Loop diuretic',
      ['Lasix', 'Frusenex', 'Frusemide'], ['20 mg', '40 mg', '80 mg'],
      ['Tablet', 'Injection'],
      affects: ['Potassium', 'Magnesium', 'Calcium', 'Sodium', 'Zinc'],
      note: 'Loop diuretics increase urinary loss of potassium, '
          'magnesium, calcium and zinc.'),
    MedicineEntry('Torsemide', 'Loop diuretic',
      ['Dytor', 'Tide'], ['5 mg', '10 mg', '20 mg', '100 mg'], ['Tablet'],
      affects: ['Potassium', 'Magnesium', 'Sodium']),
    MedicineEntry('Hydrochlorothiazide', 'Thiazide diuretic',
      ['Aquazide', 'Hydrazide'], ['12.5 mg', '25 mg'], ['Tablet'],
      affects: ['Potassium', 'Magnesium', 'Sodium', 'Zinc'],
      note: 'Thiazides lower potassium, magnesium and sodium while '
          'retaining calcium.'),
    MedicineEntry('Chlorthalidone', 'Thiazide-like diuretic',
      ['Ctd', 'Chlortha', 'Hygroton'], ['6.25 mg', '12.5 mg', '25 mg'],
      ['Tablet'], affects: ['Potassium', 'Magnesium', 'Sodium']),
    MedicineEntry('Indapamide', 'Thiazide-like diuretic',
      ['Natrilix', 'Lorvas'], ['1.5 mg', '2.5 mg'], ['Tablet'],
      affects: ['Potassium', 'Magnesium', 'Sodium']),
    MedicineEntry('Spironolactone', 'Potassium-sparing diuretic',
      ['Aldactone', 'Spiromide'], ['12.5 mg', '25 mg', '50 mg', '100 mg'],
      ['Tablet'], affects: ['Potassium'],
      note: 'Retains potassium, so blood potassium can rise. Potassium '
          'supplements and salt substitutes need care.'),
    MedicineEntry('Acetazolamide', 'Carbonic anhydrase inhibitor',
      ['Diamox', 'Iopar'], ['250 mg'], ['Tablet'],
      affects: ['Potassium', 'Sodium']),

    // ── THYROID AND HORMONES ──────────────────────────────
    MedicineEntry('Levothyroxine', 'Thyroid hormone',
      ['Thyronorm', 'Eltroxin', 'Thyrox', 'Thyrup'],
      ['12.5 mcg', '25 mcg', '50 mcg', '62.5 mcg', '75 mcg', '88 mcg',
       '100 mcg', '112 mcg', '125 mcg', '137 mcg', '150 mcg'],
      ['Tablet'],
      affects: ['Calcium', 'Iron'],
      note: 'Calcium and iron taken at the same time reduce absorption. '
          'Spacing them at least four hours apart is usual.'),
    MedicineEntry('Carbimazole', 'Antithyroid',
      ['Neomercazole', 'Thyrozole'], ['5 mg', '10 mg', '20 mg'],
      ['Tablet']),
    MedicineEntry('Methimazole', 'Antithyroid',
      ['Tapazole'], ['5 mg', '10 mg'], ['Tablet']),
    MedicineEntry('Propylthiouracil', 'Antithyroid',
      ['PTU'], ['50 mg', '100 mg'], ['Tablet']),
    MedicineEntry('Combined oral contraceptive', 'Hormonal contraceptive',
      ['Yasmin', 'Femilon', 'Mala-D', 'Krimson', 'Novelon'],
      ['1 tablet'], ['Tablet'],
      affects: ['Folate', 'Vitamin B12', 'Magnesium', 'Zinc', 'Vitamin C'],
      note: 'Oestrogen-containing contraceptives are associated with '
          'lower folate, B12, magnesium and zinc.'),
    MedicineEntry('Progesterone', 'Hormone',
      ['Susten', 'Duphaston', 'Naturogest'],
      ['100 mg', '200 mg', '300 mg', '400 mg'],
      ['Capsule', 'Tablet', 'Injection', 'Pessary']),
    MedicineEntry('Estradiol', 'Hormone replacement',
      ['Progynova', 'Estrabet'], ['1 mg', '2 mg'], ['Tablet', 'Patch'],
      affects: ['Folate', 'Vitamin B12']),
    MedicineEntry('Testosterone', 'Hormone replacement',
      ['Sustanon', 'Cernos', 'Androgel'],
      ['40 mg', '100 mg', '250 mg'], ['Capsule', 'Injection', 'Gel']),

    // ── PAIN, FEVER AND INFLAMMATION ──────────────────────
    MedicineEntry('Paracetamol', 'Analgesic and antipyretic',
      ['Crocin', 'Dolo 650', 'Calpol', 'Paracip', 'Pacimol'],
      ['125 mg', '250 mg', '500 mg', '650 mg', '1000 mg'],
      ['Tablet', 'Syrup', 'Suspension', 'Injection']),
    MedicineEntry('Ibuprofen', 'NSAID',
      ['Brufen', 'Combiflam', 'Ibugesic'],
      ['200 mg', '400 mg', '600 mg'], ['Tablet', 'Suspension'],
      affects: ['Iron'],
      note: 'NSAIDs can irritate the stomach lining and cause slow blood '
          'loss, which shows up as low iron.'),
    MedicineEntry('Diclofenac', 'NSAID',
      ['Voveran', 'Dynapar', 'Diclonac'], ['50 mg', '75 mg', '100 mg'],
      ['Tablet', 'Injection', 'Gel'], affects: ['Iron']),
    MedicineEntry('Aceclofenac', 'NSAID',
      ['Zerodol', 'Hifenac', 'Acemiz'], ['100 mg', '200 mg'], ['Tablet'],
      affects: ['Iron']),
    MedicineEntry('Naproxen', 'NSAID',
      ['Naprosyn', 'Naxdom'], ['250 mg', '500 mg'], ['Tablet'],
      affects: ['Iron']),
    MedicineEntry('Etoricoxib', 'NSAID · COX-2 selective',
      ['Etova', 'Nucoxia', 'Etoshine'],
      ['60 mg', '90 mg', '120 mg'], ['Tablet']),
    MedicineEntry('Mefenamic acid', 'NSAID',
      ['Meftal', 'Ponstan'], ['250 mg', '500 mg'],
      ['Tablet', 'Suspension'], affects: ['Iron']),
    MedicineEntry('Ketorolac', 'NSAID',
      ['Ketorol', 'Zorotrol'], ['10 mg', '30 mg'],
      ['Tablet', 'Injection'], affects: ['Iron']),
    MedicineEntry('Indomethacin', 'NSAID',
      ['Indocap'], ['25 mg', '75 mg'], ['Capsule'], affects: ['Iron']),
    MedicineEntry('Tramadol', 'Opioid analgesic',
      ['Ultracet', 'Tramazac', 'Contramal'], ['37.5 mg', '50 mg',
      '100 mg'], ['Tablet', 'Capsule', 'Injection']),
    MedicineEntry('Serratiopeptidase', 'Anti-inflammatory enzyme',
      ['Serratio', 'Enzoflam'], ['5 mg', '10 mg'], ['Tablet']),

    // ── STEROIDS ──────────────────────────────────────────
    MedicineEntry('Prednisolone', 'Corticosteroid',
      ['Wysolone', 'Omnacortil', 'Predmet'],
      ['5 mg', '10 mg', '20 mg', '40 mg'], ['Tablet'],
      affects: ['Calcium', 'Vitamin D', 'Potassium', 'Zinc'],
      note: 'Long-term steroids affect calcium balance and bone health, '
          'and can lower potassium.'),
    MedicineEntry('Methylprednisolone', 'Corticosteroid',
      ['Medrol', 'Solu-Medrol'], ['4 mg', '8 mg', '16 mg', '32 mg'],
      ['Tablet', 'Injection'],
      affects: ['Calcium', 'Vitamin D', 'Potassium']),
    MedicineEntry('Deflazacort', 'Corticosteroid',
      ['Defcort', 'Decdan DFZ'], ['6 mg', '12 mg', '24 mg', '30 mg'],
      ['Tablet'], affects: ['Calcium', 'Vitamin D', 'Potassium']),
    MedicineEntry('Dexamethasone', 'Corticosteroid',
      ['Decdan', 'Dexona'], ['0.5 mg', '4 mg', '8 mg'],
      ['Tablet', 'Injection'],
      affects: ['Calcium', 'Vitamin D', 'Potassium']),
    MedicineEntry('Hydrocortisone', 'Corticosteroid',
      ['Efcorlin', 'Hycort'], ['5 mg', '10 mg', '100 mg'],
      ['Tablet', 'Injection', 'Cream or ointment'],
      affects: ['Calcium', 'Potassium']),
    MedicineEntry('Budesonide', 'Inhaled corticosteroid',
      ['Budecort', 'Pulmicort'], ['100 mcg', '200 mcg', '400 mcg'],
      ['Inhaler', 'Rotacap', 'Nebuliser solution']),

    // ── ANTIBIOTICS AND ANTIMICROBIALS ────────────────────
    MedicineEntry('Amoxicillin', 'Penicillin antibiotic',
      ['Mox', 'Novamox', 'Amoxil'], ['250 mg', '500 mg'],
      ['Capsule', 'Suspension']),
    MedicineEntry('Amoxicillin and clavulanate', 'Penicillin antibiotic',
      ['Augmentin', 'Clavam', 'Moxikind-CV', 'Advent'],
      ['375 mg', '625 mg', '1000 mg'], ['Tablet', 'Suspension']),
    MedicineEntry('Azithromycin', 'Macrolide antibiotic',
      ['Azithral', 'Azee', 'Zithromax'], ['250 mg', '500 mg'],
      ['Tablet', 'Suspension']),
    MedicineEntry('Clarithromycin', 'Macrolide antibiotic',
      ['Claribid', 'Crixan'], ['250 mg', '500 mg'], ['Tablet']),
    MedicineEntry('Cefixime', 'Cephalosporin antibiotic',
      ['Taxim-O', 'Zifi', 'Mahacef'], ['100 mg', '200 mg'],
      ['Tablet', 'Suspension']),
    MedicineEntry('Cefuroxime', 'Cephalosporin antibiotic',
      ['Ceftum', 'Altacef'], ['250 mg', '500 mg'], ['Tablet']),
    MedicineEntry('Ceftriaxone', 'Cephalosporin antibiotic',
      ['Monocef', 'Rocephin'], ['250 mg', '500 mg', '1 g', '2 g'],
      ['Injection'], affects: ['Calcium'],
      note: 'Should not be mixed with calcium-containing IV fluids.'),
    MedicineEntry('Ciprofloxacin', 'Fluoroquinolone antibiotic',
      ['Ciplox', 'Cifran', 'Ciprobid'], ['250 mg', '500 mg', '750 mg'],
      ['Tablet', 'Eye drops'],
      affects: ['Calcium', 'Iron', 'Magnesium', 'Zinc'],
      note: 'Binds to calcium, iron, magnesium and zinc, so supplements '
          'and dairy should be spaced two hours apart.'),
    MedicineEntry('Levofloxacin', 'Fluoroquinolone antibiotic',
      ['Levoflox', 'Loxof', 'Glevo'], ['250 mg', '500 mg', '750 mg'],
      ['Tablet'],
      affects: ['Calcium', 'Iron', 'Magnesium', 'Zinc']),
    MedicineEntry('Ofloxacin', 'Fluoroquinolone antibiotic',
      ['Oflox', 'Zanocin', 'O2'], ['200 mg', '400 mg'],
      ['Tablet', 'Eye drops'],
      affects: ['Calcium', 'Iron', 'Magnesium', 'Zinc']),
    MedicineEntry('Norfloxacin', 'Fluoroquinolone antibiotic',
      ['Norflox', 'Norbactin'], ['200 mg', '400 mg'], ['Tablet'],
      affects: ['Calcium', 'Iron', 'Magnesium', 'Zinc']),
    MedicineEntry('Doxycycline', 'Tetracycline antibiotic',
      ['Doxt', 'Doxy-1', 'Minicycline'], ['100 mg'],
      ['Tablet', 'Capsule'],
      affects: ['Calcium', 'Iron', 'Magnesium', 'Zinc'],
      note: 'Binds to calcium, iron, magnesium and zinc. Space dairy and '
          'supplements at least two hours apart.'),
    MedicineEntry('Metronidazole', 'Antiprotozoal antibiotic',
      ['Flagyl', 'Metrogyl', 'Metron'], ['200 mg', '400 mg', '500 mg'],
      ['Tablet', 'Suspension', 'IV infusion']),
    MedicineEntry('Cotrimoxazole', 'Sulfonamide antibiotic',
      ['Septran', 'Bactrim', 'Trimosul'],
      ['400 mg', '800 mg', '960 mg'], ['Tablet', 'Suspension'],
      affects: ['Folate'],
      note: 'Trimethoprim blocks folate metabolism. Folic acid is often '
          'prescribed alongside for long courses.'),
    MedicineEntry('Nitrofurantoin', 'Urinary antibiotic',
      ['Niftran', 'Nitrofur'], ['50 mg', '100 mg'], ['Capsule', 'Tablet'],
      affects: ['Folate']),
    MedicineEntry('Linezolid', 'Oxazolidinone antibiotic',
      ['Linospan', 'Lizolid'], ['600 mg'], ['Tablet', 'IV infusion'],
      note: 'Interacts with tyramine-rich foods such as aged cheese and '
          'fermented products.'),
    MedicineEntry('Rifampicin', 'Antitubercular',
      ['R-Cin', 'Rifadin', 'Rimactane'], ['150 mg', '300 mg', '450 mg',
      '600 mg'], ['Capsule', 'Tablet'],
      affects: ['Vitamin D', 'Calcium'],
      note: 'Speeds up vitamin D breakdown in the liver.'),
    MedicineEntry('Isoniazid', 'Antitubercular',
      ['Isokin', 'Solonex'], ['100 mg', '300 mg'], ['Tablet'],
      affects: ['Folate', 'Calcium', 'Vitamin D'],
      note: 'Depletes vitamin B6, which is why pyridoxine is routinely '
          'prescribed alongside it.'),
    MedicineEntry('Ethambutol', 'Antitubercular',
      ['Combutol', 'Myambutol'], ['400 mg', '800 mg'], ['Tablet'],
      affects: ['Zinc', 'Magnesium']),
    MedicineEntry('Pyrazinamide', 'Antitubercular',
      ['Pyzina', 'P-Zide'], ['500 mg', '750 mg', '1000 mg'], ['Tablet']),
    MedicineEntry('Fluconazole', 'Antifungal',
      ['Forcan', 'Zocon', 'Flucos'], ['50 mg', '150 mg', '200 mg',
      '400 mg'], ['Tablet', 'Capsule']),
    MedicineEntry('Itraconazole', 'Antifungal',
      ['Itraspor', 'Canditral', 'Sporanox'], ['100 mg', '200 mg'],
      ['Capsule'],
      note: 'Needs stomach acid to be absorbed, so acid-reducing '
          'medicines lower its effect.'),
    MedicineEntry('Terbinafine', 'Antifungal',
      ['Lamisil', 'Terbicip'], ['250 mg'],
      ['Tablet', 'Cream or ointment']),
    MedicineEntry('Acyclovir', 'Antiviral',
      ['Zovirax', 'Acivir'], ['200 mg', '400 mg', '800 mg'],
      ['Tablet', 'Cream or ointment']),
    MedicineEntry('Valacyclovir', 'Antiviral',
      ['Valcivir', 'Valtrex'], ['500 mg', '1000 mg'], ['Tablet']),
    MedicineEntry('Hydroxychloroquine', 'Antimalarial and DMARD',
      ['HCQS', 'Zyq'], ['200 mg', '300 mg', '400 mg'], ['Tablet']),
    MedicineEntry('Ivermectin', 'Antiparasitic',
      ['Ivermectol', 'Iverheal'], ['3 mg', '6 mg', '12 mg'], ['Tablet']),
    MedicineEntry('Albendazole', 'Antiparasitic',
      ['Zentel', 'Bandy'], ['400 mg'], ['Tablet', 'Suspension']),

    // ── MIND, SLEEP AND NEUROLOGY ─────────────────────────
    MedicineEntry('Sertraline', 'SSRI antidepressant',
      ['Serta', 'Daxid', 'Zoloft'], ['25 mg', '50 mg', '100 mg'],
      ['Tablet']),
    MedicineEntry('Escitalopram', 'SSRI antidepressant',
      ['Nexito', 'Cipralex', 'Escitalent'],
      ['5 mg', '10 mg', '20 mg'], ['Tablet']),
    MedicineEntry('Fluoxetine', 'SSRI antidepressant',
      ['Fludac', 'Prodep'], ['10 mg', '20 mg', '40 mg'],
      ['Capsule', 'Tablet']),
    MedicineEntry('Paroxetine', 'SSRI antidepressant',
      ['Paxidep', 'Pari'], ['12.5 mg', '25 mg'], ['Tablet']),
    MedicineEntry('Venlafaxine', 'SNRI antidepressant',
      ['Venlor', 'Veniz'], ['37.5 mg', '75 mg', '150 mg'],
      ['Tablet', 'Capsule']),
    MedicineEntry('Duloxetine', 'SNRI antidepressant',
      ['Duzela', 'Dulane'], ['20 mg', '30 mg', '60 mg'], ['Capsule']),
    MedicineEntry('Amitriptyline', 'Tricyclic antidepressant',
      ['Tryptomer', 'Amitone'], ['10 mg', '25 mg', '75 mg'], ['Tablet']),
    MedicineEntry('Mirtazapine', 'Antidepressant',
      ['Mirtaz', 'Mirnite'], ['7.5 mg', '15 mg', '30 mg'], ['Tablet']),
    MedicineEntry('Alprazolam', 'Benzodiazepine',
      ['Alprax', 'Restyl', 'Trika'], ['0.25 mg', '0.5 mg', '1 mg'],
      ['Tablet']),
    MedicineEntry('Clonazepam', 'Benzodiazepine',
      ['Rivotril', 'Lonazep', 'Clonotril'],
      ['0.25 mg', '0.5 mg', '1 mg', '2 mg'], ['Tablet']),
    MedicineEntry('Etizolam', 'Thienodiazepine',
      ['Etilaam', 'Etizola'], ['0.25 mg', '0.5 mg', '1 mg'], ['Tablet']),
    MedicineEntry('Zolpidem', 'Sedative hypnotic',
      ['Zolfresh', 'Nitrest'], ['5 mg', '10 mg'], ['Tablet']),
    MedicineEntry('Quetiapine', 'Antipsychotic',
      ['Qutipin', 'Seroquel'], ['25 mg', '50 mg', '100 mg', '200 mg'],
      ['Tablet']),
    MedicineEntry('Olanzapine', 'Antipsychotic',
      ['Oleanz', 'Oliza'], ['2.5 mg', '5 mg', '10 mg', '20 mg'],
      ['Tablet']),
    MedicineEntry('Risperidone', 'Antipsychotic',
      ['Risdone', 'Sizodon'], ['0.5 mg', '1 mg', '2 mg', '4 mg'],
      ['Tablet']),
    MedicineEntry('Lithium carbonate', 'Mood stabiliser',
      ['Licab', 'Intalith'], ['300 mg', '400 mg'], ['Tablet'],
      affects: ['Sodium', 'Iodine'],
      note: 'Sodium intake and hydration must stay steady, because low '
          'sodium raises lithium levels. Thyroid is monitored too.'),
    MedicineEntry('Sodium valproate', 'Anticonvulsant',
      ['Valparin', 'Encorate', 'Epilex'],
      ['200 mg', '300 mg', '500 mg'], ['Tablet', 'Syrup'],
      affects: ['Folate', 'Zinc', 'Vitamin D', 'Calcium'],
      note: 'Anticonvulsants are associated with lower folate and '
          'vitamin D. Folic acid matters especially before pregnancy.'),
    MedicineEntry('Levetiracetam', 'Anticonvulsant',
      ['Levipil', 'Levera', 'Keppra'],
      ['250 mg', '500 mg', '750 mg', '1000 mg'], ['Tablet', 'Syrup'],
      affects: ['Vitamin D']),
    MedicineEntry('Phenytoin', 'Anticonvulsant',
      ['Eptoin', 'Dilantin'], ['50 mg', '100 mg', '300 mg'],
      ['Tablet', 'Capsule', 'Suspension'],
      affects: ['Folate', 'Vitamin D', 'Calcium'],
      note: 'Speeds up vitamin D breakdown and lowers folate. Both are '
          'commonly monitored on long-term therapy.'),
    MedicineEntry('Carbamazepine', 'Anticonvulsant',
      ['Tegretol', 'Mazetol', 'Zeptol'], ['100 mg', '200 mg', '400 mg'],
      ['Tablet'],
      affects: ['Folate', 'Vitamin D', 'Calcium', 'Sodium'],
      note: 'Can lower blood sodium as well as vitamin D and folate.'),
    MedicineEntry('Phenobarbitone', 'Anticonvulsant',
      ['Gardenal', 'Phenobarb'], ['30 mg', '60 mg'], ['Tablet'],
      affects: ['Folate', 'Vitamin D', 'Calcium']),
    MedicineEntry('Gabapentin', 'Neuropathic pain agent',
      ['Gabapin', 'Gabantin'], ['100 mg', '300 mg', '400 mg', '600 mg'],
      ['Capsule', 'Tablet']),
    MedicineEntry('Pregabalin', 'Neuropathic pain agent',
      ['Pregeb', 'Nuroday', 'Maxgalin'],
      ['25 mg', '50 mg', '75 mg', '150 mg'], ['Capsule']),
    MedicineEntry('Donepezil', 'Cholinesterase inhibitor',
      ['Donep', 'Aricep'], ['5 mg', '10 mg'], ['Tablet']),
    MedicineEntry('Levodopa and carbidopa', 'Antiparkinsonian',
      ['Syndopa', 'Tidomet', 'Sinemet'],
      ['110 mg', '125 mg', '250 mg'], ['Tablet'],
      affects: ['Folate', 'Vitamin B12'],
      note: 'Protein-rich meals compete with levodopa absorption, and '
          'long-term use is linked to lower B12 and folate.'),
    MedicineEntry('Pramipexole', 'Antiparkinsonian',
      ['Pramipex', 'Parkitidin'], ['0.125 mg', '0.25 mg', '0.5 mg',
      '1 mg'], ['Tablet']),
    MedicineEntry('Sumatriptan', 'Antimigraine',
      ['Suminat', 'Imitrex'], ['25 mg', '50 mg', '100 mg'],
      ['Tablet', 'Nasal spray']),
    MedicineEntry('Flunarizine', 'Migraine prophylaxis',
      ['Sibelium', 'Flunarin'], ['5 mg', '10 mg'], ['Tablet']),
    MedicineEntry('Betahistine', 'Vertigo agent',
      ['Vertin', 'Betavert'], ['8 mg', '16 mg', '24 mg'], ['Tablet']),

    // ── LUNGS AND ALLERGY ─────────────────────────────────
    MedicineEntry('Salbutamol', 'Short-acting bronchodilator',
      ['Asthalin', 'Ventorlin', 'Levolin'],
      ['100 mcg', '2 mg', '4 mg'],
      ['Inhaler', 'Nebuliser solution', 'Tablet', 'Syrup'],
      affects: ['Potassium'],
      note: 'High or frequent doses can lower blood potassium.'),
    MedicineEntry('Formoterol and budesonide', 'Combination inhaler',
      ['Foracort', 'Symbicort'], ['6 mcg', '100 mcg', '200 mcg',
      '400 mcg'], ['Inhaler', 'Rotacap']),
    MedicineEntry('Salmeterol and fluticasone', 'Combination inhaler',
      ['Seroflo', 'Advair'], ['50 mcg', '125 mcg', '250 mcg'],
      ['Inhaler', 'Rotacap']),
    MedicineEntry('Tiotropium', 'Long-acting bronchodilator',
      ['Tiova', 'Spiriva'], ['9 mcg', '18 mcg'], ['Inhaler', 'Rotacap']),
    MedicineEntry('Montelukast', 'Leukotriene antagonist',
      ['Montair', 'Montek', 'Telekast'], ['4 mg', '5 mg', '10 mg'],
      ['Tablet', 'Chewable tablet']),
    MedicineEntry('Cetirizine', 'Antihistamine',
      ['Cetzine', 'Alerid', 'Okacet'], ['5 mg', '10 mg'],
      ['Tablet', 'Syrup']),
    MedicineEntry('Levocetirizine', 'Antihistamine',
      ['Levocet', 'Xyzal', 'Vozet'], ['2.5 mg', '5 mg'],
      ['Tablet', 'Syrup']),
    MedicineEntry('Fexofenadine', 'Antihistamine',
      ['Allegra', 'Fexova'], ['30 mg', '120 mg', '180 mg'], ['Tablet'],
      note: 'Fruit juices reduce absorption. Take with water.'),
    MedicineEntry('Chlorpheniramine', 'Antihistamine',
      ['Cadistin', 'Piriton'], ['2 mg', '4 mg'], ['Tablet', 'Syrup']),
    MedicineEntry('Theophylline', 'Bronchodilator',
      ['Deriphyllin', 'Theobid'], ['100 mg', '150 mg', '300 mg'],
      ['Tablet', 'Injection'], affects: ['Potassium']),

    // ── BONE, JOINTS AND GOUT ─────────────────────────────
    MedicineEntry('Alendronate', 'Bisphosphonate',
      ['Osteofos', 'Fosamax', 'Alendra'], ['10 mg', '35 mg', '70 mg'],
      ['Tablet'],
      affects: ['Calcium'],
      note: 'Must be taken on an empty stomach with plain water, sitting '
          'upright. Calcium and food block absorption completely.'),
    MedicineEntry('Risedronate', 'Bisphosphonate',
      ['Rise', 'Actonel'], ['5 mg', '35 mg', '150 mg'], ['Tablet'],
      affects: ['Calcium']),
    MedicineEntry('Zoledronic acid', 'Bisphosphonate',
      ['Zoldria', 'Aclasta'], ['4 mg', '5 mg'], ['IV infusion'],
      affects: ['Calcium', 'Vitamin D'],
      note: 'Calcium and vitamin D are usually corrected before the '
          'infusion.'),
    MedicineEntry('Calcitriol', 'Active vitamin D',
      ['Rocaltrol', 'Calcitas'], ['0.25 mcg', '0.5 mcg'], ['Capsule'],
      affects: ['Calcium', 'Phosphorus', 'Vitamin D'],
      note: 'Raises calcium absorption. Blood calcium is monitored.'),
    MedicineEntry('Cholecalciferol', 'Vitamin D3',
      ['Uprise D3', 'Calcirol', 'D-Rise', 'Tayo 60K'],
      ['1000 IU', '2000 IU', '60000 IU'],
      ['Sachet or powder', 'Capsule', 'Tablet'],
      affects: ['Vitamin D', 'Calcium']),
    MedicineEntry('Calcium carbonate', 'Calcium supplement',
      ['Shelcal', 'Calcimax', 'Ostocalcium'],
      ['250 mg', '500 mg', '1000 mg'], ['Tablet', 'Suspension'],
      affects: ['Calcium', 'Iron'],
      note: 'Blocks iron absorption when taken together. Space them '
          'apart.'),
    MedicineEntry('Allopurinol', 'Gout · xanthine oxidase inhibitor',
      ['Zyloric', 'Ziloric'], ['100 mg', '300 mg'], ['Tablet']),
    MedicineEntry('Febuxostat', 'Gout · xanthine oxidase inhibitor',
      ['Febutaz', 'Zurig', 'Feburic'], ['40 mg', '80 mg'], ['Tablet']),
    MedicineEntry('Colchicine', 'Gout',
      ['Goutnil', 'Colchicine'], ['0.5 mg'], ['Tablet'],
      affects: ['Vitamin B12'],
      note: 'Long-term use is associated with reduced B12 absorption.'),
    MedicineEntry('Methotrexate', 'DMARD',
      ['Folitrax', 'Methotrex', 'Imutrex'],
      ['2.5 mg', '7.5 mg', '10 mg', '15 mg', '25 mg'],
      ['Tablet', 'Injection'],
      affects: ['Folate'],
      note: 'Works against folate, which is why folic acid is prescribed '
          'alongside on a different day of the week.'),
    MedicineEntry('Sulfasalazine', 'DMARD',
      ['Saaz', 'Sazo'], ['500 mg', '1000 mg'], ['Tablet'],
      affects: ['Folate'],
      note: 'Reduces folate absorption in the gut.'),
    MedicineEntry('Leflunomide', 'DMARD',
      ['Lefno', 'Cleft'], ['10 mg', '20 mg'], ['Tablet']),

    // ── TRANSPLANT AND IMMUNE ─────────────────────────────
    MedicineEntry('Azathioprine', 'Immunosuppressant',
      ['Imuran', 'Azoran'], ['25 mg', '50 mg'], ['Tablet'],
      affects: ['Folate']),
    MedicineEntry('Mycophenolate mofetil', 'Immunosuppressant',
      ['Cellcept', 'Mycept'], ['250 mg', '500 mg'],
      ['Tablet', 'Capsule'], affects: ['Iron'],
      note: 'Iron and antacids taken together reduce absorption.'),
    MedicineEntry('Tacrolimus', 'Immunosuppressant',
      ['Pangraf', 'Prograf'], ['0.5 mg', '1 mg', '5 mg'], ['Capsule'],
      affects: ['Magnesium', 'Potassium'],
      note: 'Commonly lowers magnesium and can raise potassium. '
          'Grapefruit raises drug levels.'),
    MedicineEntry('Cyclosporine', 'Immunosuppressant',
      ['Panimun', 'Sandimmun'], ['25 mg', '50 mg', '100 mg'], ['Capsule'],
      affects: ['Magnesium', 'Potassium'],
      note: 'Lowers magnesium and can raise potassium. Grapefruit raises '
          'drug levels.'),

    // ── KIDNEY, URINARY AND PROSTATE ──────────────────────
    MedicineEntry('Tamsulosin', 'Alpha blocker',
      ['Urimax', 'Veltam', 'Contiflo'], ['0.2 mg', '0.4 mg'],
      ['Tablet', 'Capsule']),
    MedicineEntry('Finasteride', '5-alpha reductase inhibitor',
      ['Finast', 'Fincar', 'Finpecia'], ['1 mg', '5 mg'], ['Tablet']),
    MedicineEntry('Dutasteride', '5-alpha reductase inhibitor',
      ['Dutas', 'Duprost'], ['0.5 mg'], ['Capsule']),
    MedicineEntry('Sildenafil', 'PDE5 inhibitor',
      ['Manforce', 'Penegra', 'Viagra'], ['25 mg', '50 mg', '100 mg'],
      ['Tablet']),
    MedicineEntry('Tadalafil', 'PDE5 inhibitor',
      ['Tadacip', 'Megalis', 'Cialis'], ['2.5 mg', '5 mg', '10 mg',
      '20 mg'], ['Tablet']),
    MedicineEntry('Sevelamer', 'Phosphate binder',
      ['Renvela', 'Sevcar'], ['400 mg', '800 mg'], ['Tablet'],
      affects: ['Phosphorus', 'Vitamin D', 'Calcium'],
      note: 'Binds phosphate in the gut and can reduce fat-soluble '
          'vitamin absorption. Taken with meals.'),
    MedicineEntry('Potassium chloride', 'Potassium supplement',
      ['Potklor', 'K-Cl'], ['600 mg', '1 g', '15 ml'],
      ['Tablet', 'Syrup'], affects: ['Potassium']),
    MedicineEntry('Sodium bicarbonate', 'Alkalising agent',
      ['Sodamint', 'Nodosis'], ['500 mg'], ['Tablet'],
      affects: ['Sodium', 'Potassium', 'Calcium']),

    // ── WEIGHT AND METABOLIC ──────────────────────────────
    MedicineEntry('Orlistat', 'Lipase inhibitor',
      ['Obelit', 'Orlica', 'Xenical'], ['60 mg', '120 mg'], ['Capsule'],
      affects: ['Vitamin A', 'Vitamin D', 'Omega-3'],
      note: 'Blocks fat absorption, and with it the fat-soluble '
          'vitamins. A multivitamin at bedtime is usual.'),
    MedicineEntry('Cholestyramine', 'Bile acid sequestrant',
      ['Cholestyramine', 'Questran'], ['4 g'], ['Sachet or powder'],
      affects: ['Vitamin A', 'Vitamin D', 'Folate', 'Iron'],
      note: 'Binds fat-soluble vitamins and folate in the gut. Space '
          'other medicines and supplements several hours apart.'),
    MedicineEntry('Levocarnitine', 'Metabolic supplement',
      ['Carnitor', 'L-Carnitine'], ['330 mg', '500 mg', '1 g'],
      ['Tablet', 'Syrup']),

    // ── EYE, SKIN AND OTHERS ──────────────────────────────
    MedicineEntry('Isotretinoin', 'Retinoid',
      ['Sotret', 'Accufine', 'Isotroin'], ['10 mg', '20 mg', '30 mg'],
      ['Capsule'],
      affects: ['Vitamin A'],
      note: 'A vitamin A derivative. Extra vitamin A supplements must be '
          'avoided while taking it.'),
    MedicineEntry('Timolol eye drops', 'Glaucoma · beta blocker',
      ['Glucomol', 'Timolet'], ['0.25 %', '0.5 %'], ['Eye drops']),
    MedicineEntry('Latanoprost', 'Glaucoma · prostaglandin analogue',
      ['Latoprost', 'Xalatan'], ['0.005 %'], ['Eye drops']),
    MedicineEntry('Clobetasol', 'Topical steroid',
      ['Tenovate', 'Clobetamos'], ['0.05 %'],
      ['Cream or ointment', 'Gel']),
    MedicineEntry('Silymarin', 'Hepatoprotective',
      ['Silybon', 'Livokin'], ['70 mg', '140 mg'], ['Tablet']),
    MedicineEntry('Ferrous ascorbate', 'Iron supplement',
      ['Orofer XT', 'Autrin', 'Livogen'], ['100 mg', '200 mg'],
      ['Tablet', 'Syrup'],
      affects: ['Iron'],
      note: 'Absorbed best on an empty stomach with vitamin C. Tea, '
          'coffee, calcium and antacids block it.'),
    MedicineEntry('Methylcobalamin', 'Vitamin B12 supplement',
      ['Nurokind', 'Neurobion', 'Mecobal'],
      ['500 mcg', '1500 mcg'], ['Tablet', 'Injection'],
      affects: ['Vitamin B12']),
    MedicineEntry('Folic acid', 'Folate supplement',
      ['Folvite', 'Foligraf'], ['1 mg', '5 mg'], ['Tablet'],
      affects: ['Folate']),
    MedicineEntry('Potassium iodide', 'Iodine supplement',
      ['Iodex oral'], ['65 mg', '130 mg'], ['Tablet'],
      affects: ['Iodine']),
    MedicineEntry('Zinc sulphate', 'Zinc supplement',
      ['Zincovit', 'Z and D'], ['20 mg', '50 mg'],
      ['Tablet', 'Syrup'],
      affects: ['Zinc', 'Iron'],
      note: 'High-dose zinc taken long term can lower copper and compete '
          'with iron absorption.'),
  ];
}
