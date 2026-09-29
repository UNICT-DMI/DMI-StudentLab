import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';

/// Admin › Esercizi › Tipi per dipartimento (v24).
/// Ogni dipartimento (i 17 di UniCT e le SDS di Ragusa e Siracusa) appartiene a un'area; ogni area
/// ha i suoi tipi di esercizio consigliati. Lo studente non vede le schede dei tipi fuori area
/// senza esercizi; il docente li trova in fondo alla scelta del tipo. Nessuna migrazione: la
/// configurazione è un file JSON sul server.
class ExerciseAreasPage extends StatefulWidget {
  const ExerciseAreasPage({super.key});

  @override
  State<ExerciseAreasPage> createState() => _ExerciseAreasPageState();
}

class _ExerciseAreasPageState extends State<ExerciseAreasPage> {
  final ExerciseApiService _api = ExerciseApiService();
  Map<String, dynamic> _config = <String, dynamic>{};
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  // prova
  final TextEditingController _testDepartment = TextEditingController();
  final TextEditingController _testCourse = TextEditingController();
  Map<String, dynamic>? _testResult;
  String? _testError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _testDepartment.dispose();
    _testCourse.dispose();
    super.dispose();
  }

  Map<String, Map<String, dynamic>> get _areas =>
      asMap(_config['areas']).map((String k, dynamic v) => MapEntry<String, Map<String, dynamic>>(k, asMap(v)));

  List<Map<String, dynamic>> get _departments => asMapList(_config['departments']);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _config = await _api.areas();
      _dirty = false;
    } catch (error) {
      _error = cleanError(error, 'Aree non disponibili.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _payload() => <String, dynamic>{
        'version': 1,
        'areas': _config['areas'],
        'default_area': _config['default_area'],
        'departments': _config['departments'],
        'courses': _config['courses'],
      };

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      _config = await _api.saveAreas(_payload());
      _dirty = false;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aree salvate.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _reset() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Ripristinare le aree predefinite?'),
        content: const Text('Le modifiche fatte a dipartimenti e tipi verranno perse.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ripristina')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      _config = await _api.resetAreas();
      _dirty = false;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
    }
    if (mounted) setState(() => _saving = false);
  }

  void _setDepartmentArea(int index, String area) {
    final List<Map<String, dynamic>> departments = _departments;
    departments[index] = <String, dynamic>{...departments[index], 'area': area};
    setState(() {
      _config = <String, dynamic>{..._config, 'departments': departments};
      _dirty = true;
    });
  }

  void _toggleType(String area, String type, bool on) {
    final Map<String, Map<String, dynamic>> areas = _areas;
    final List<String> types = asStringList(areas[area]?['types']);
    if (on && !types.contains(type)) types.add(type);
    if (!on) {
      if (types.length <= 1) return;           // un'area ha almeno un tipo
      types.remove(type);
    }
    areas[area] = <String, dynamic>{...?areas[area], 'types': types};
    setState(() {
      _config = <String, dynamic>{..._config, 'areas': areas};
      _dirty = true;
    });
  }

  Future<void> _test() async {
    final String department = _testDepartment.text.trim();
    final String course = _testCourse.text.trim();
    if (department.isEmpty || course.isEmpty) return;
    setState(() {
      _testError = null;
      _testResult = null;
    });
    try {
      final Map<String, dynamic> result = await _api.areaFor(department, course);
      if (mounted) setState(() => _testResult = result);
    } catch (error) {
      if (mounted) setState(() => _testError = cleanError(error));
    }
  }

  Color _areaColor(BuildContext context, String area) {
    final p = context.palette;
    return switch (area) {
      'informatica' => p.skyBlue,
      'matematica_fisica' => const Color(0xFFA9A8FF),
      'ingegneria' => p.adminAmber,
      'scienze' => p.adminGreen,
      'salute' => p.adminCoral,
      'giuridico_economico' => p.adminCyan,
      'umanistica' => p.adminMagenta,
      _ => p.pureWhite.withValues(alpha: 0.7),
    };
  }

  Widget _departmentsTab(BuildContext context) {
    final p = context.palette;
    final List<Map<String, dynamic>> departments = _departments;
    final Map<String, List<int>> groups = <String, List<int>>{};
    for (int i = 0; i < departments.length; i++) {
      groups.putIfAbsent(departments[i]['group']?.toString() ?? 'Altro', () => <int>[]).add(i);
    }
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      Text('Ogni dipartimento appartiene a un’area. Le regole sul nome del corso vengono prima '
          '(es. Informatica al DMI e Ingegneria informatica al DIEEI → area Informatica).',
          style: SlText.muted(p).copyWith(fontSize: 12.5)),
      const SizedBox(height: 12),
      for (final MapEntry<String, List<int>> group in groups.entries) ...<Widget>[
        Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: SlOverline(group.key.toUpperCase())),
        for (final int i in group.value)
          Card(
            color: p.eleganceMidnight,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
                final Widget title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text(departments[i]['name']?.toString() ?? '',
                      style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(departments[i]['code']?.toString() ?? '', style: SlText.mono(p, size: 11)),
                ]);
                final String area = departments[i]['area']?.toString() ?? '';
                final Widget picker = DropdownButton<String>(
                  value: _areas.containsKey(area) ? area : null,
                  isExpanded: box.maxWidth < 520,
                  items: <DropdownMenuItem<String>>[
                    for (final MapEntry<String, Map<String, dynamic>> a in _areas.entries)
                      DropdownMenuItem<String>(
                        value: a.key,
                        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: _areaColor(context, a.key), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(a.value['label']?.toString() ?? a.key, overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                  ],
                  onChanged: (String? v) {
                    if (v != null) _setDepartmentArea(i, v);
                  },
                );
                return box.maxWidth < 520
                    ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[title, picker])
                    : Row(children: <Widget>[Expanded(child: title), const SizedBox(width: 12), SizedBox(width: 280, child: picker)]);
              }),
            ),
          ),
      ],
      const SizedBox(height: 12),
      SlOverline('REGOLE SUI CORSI'),
      const SizedBox(height: 6),
      for (final Map<String, dynamic> rule in asMapList(_config['courses']))
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('“${asStringList(rule['match']).join('”, “')}” → ${_areas[rule['area']]?['label'] ?? rule['area']}',
              style: SlText.muted(p).copyWith(fontSize: 12.5)),
        ),
    ]);
  }

  Widget _typesTab(BuildContext context) {
    final p = context.palette;
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      Text('Tipi consigliati per ogni area. La risposta multipla c’è sempre. Un tipo spento non sparisce: '
          'se il docente ha già esercizi di quel tipo, gli studenti continuano a vederli.',
          style: SlText.muted(p).copyWith(fontSize: 12.5)),
      const SizedBox(height: 12),
      for (final MapEntry<String, Map<String, dynamic>> area in _areas.entries)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.eleganceMidnight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _areaColor(context, area.key).withValues(alpha: 0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Row(children: <Widget>[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: _areaColor(context, area.key), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(area.value['label']?.toString() ?? area.key,
                    style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Text('${_departments.where((Map<String, dynamic> d) => d['area'] == area.key).length} dip.',
                  style: SlText.mono(p, size: 11)),
            ]),
            if ((area.value['examples']?.toString() ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(area.value['examples'].toString(), style: SlText.muted(p).copyWith(fontSize: 12)),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
              for (final String type in kExerciseTypes.where((String type) => type != 'flashcard'))
                Builder(builder: (BuildContext context) {
                  final ExerciseTypeInfo info = exerciseInfo(type);
                  final bool on = asStringList(area.value['types']).contains(type);
                  return FilterChip(
                    avatar: Icon(info.icon, size: 16, color: on ? categoryColor(context, info.category) : null),
                    label: Text(info.label),
                    selected: on,
                    onSelected: (bool v) => _toggleType(area.key, type, v),
                  );
                }),
            ]),
          ]),
        ),
    ]);
  }

  Widget _testTab(BuildContext context) {
    final p = context.palette;
    final Map<String, dynamic>? r = _testResult;
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      Text('Scrivi i codici come nelle materie (es. DMI e L-31): il server usa anche i nomi completi salvati. '
          'Vale la configurazione salvata, non le modifiche ancora da salvare.',
          style: SlText.muted(p).copyWith(fontSize: 12.5)),
      const SizedBox(height: 12),
      TextField(controller: _testDepartment, decoration: const InputDecoration(labelText: 'Codice dipartimento', isDense: true)),
      const SizedBox(height: 8),
      TextField(controller: _testCourse, decoration: const InputDecoration(labelText: 'Codice corso', isDense: true)),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(onPressed: _test, icon: const Icon(Icons.search_rounded), label: const Text('Trova l’area')),
      ),
      if (_testError != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_testError!, style: TextStyle(color: p.adminCoral))),
      if (r != null) ...<Widget>[
        const SizedBox(height: 14),
        Text('${r['label']}', style: TextStyle(color: _areaColor(context, '${r['id']}'), fontSize: 17, fontWeight: FontWeight.w700)),
        Text(
            switch (r['matched']) {
              'course' => 'Trovata dal nome del corso',
              'department' => 'Trovata dal dipartimento ${asMap(r['department'])['code'] ?? ''}',
              _ => 'Nessuna regola: area predefinita',
            },
            style: SlText.muted(p).copyWith(fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
          for (final String t in asStringList(r['types'])) Chip(avatar: Icon(exerciseInfo(t).icon, size: 16), label: Text(exerciseInfo(t).label)),
        ]),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: p.darkElegance,
        appBar: slAdminAppBar(context, title: 'Tipi di esercizio per dipartimento', breadcrumb: 'ADMIN / ESERCIZI', actions: <Widget>[
          IconButton(
            tooltip: 'Ripristina i predefiniti',
            onPressed: _loading || _saving ? null : _reset,
            icon: const Icon(Icons.restore_rounded),
          ),
        ]),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: p.skyBlue))
            : _error != null
                ? Center(child: SlErrorCard(title: 'Attenzione', message: _error!, onRetry: _load))
                : Column(children: <Widget>[
                    TabBar(tabs: const <Tab>[Tab(text: 'Dipartimenti'), Tab(text: 'Tipi per area'), Tab(text: 'Prova')]),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: TabBarView(children: <Widget>[_departmentsTab(context), _typesTab(context), _testTab(context)]),
                        ),
                      ),
                    ),
                  ]),
        bottomNavigationBar: _dirty
            ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  color: p.eleganceMidnight,
                  child: Row(children: <Widget>[
                    Icon(Icons.edit_note_rounded, color: p.adminAmber),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Modifiche da salvare')),
                    TextButton(onPressed: _saving ? null : _load, child: const Text('Scarta')),
                    const SizedBox(width: 6),
                    FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Salvo…' : 'Salva')),
                  ]),
                ),
              )
            : null,
      ),
    );
  }
}
