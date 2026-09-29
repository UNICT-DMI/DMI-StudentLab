import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/teacher/services/teacher_quiz_assignments_page.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_catalog_page.dart';
import 'package:fe/quiz/exercises/teacher/exercise_areas_page.dart';
import 'package:fe/quiz/exercises/teacher/exercise_bank_page.dart';

/// Esercizi per materia. Admin: tutte le materie (anche quelle senza docente
/// in piattaforma). Docente: solo le materie verificate (lo decide il server).
class ExerciseSubjectsPage extends StatefulWidget {
  final bool adminMode;

  const ExerciseSubjectsPage({super.key, this.adminMode = false});

  @override
  State<ExerciseSubjectsPage> createState() => _ExerciseSubjectsPageState();
}

class _ExerciseSubjectsPageState extends State<ExerciseSubjectsPage> {
  final ExerciseApiService _api = ExerciseApiService();
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _subjects = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _subjects = await _api.manageableSubjects(query: _search.text);
    } catch (error) {
      _error = cleanError(error, 'Materie non disponibili.');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _open(Map<String, dynamic> s) {
    final p = context.palette;
    final String department = s['department_code']?.toString() ?? '';
    final String course = s['course_code']?.toString() ?? '';
    final String name = s['name']?.toString() ?? '';
    final int id = int.tryParse('${s['id']}') ?? 0;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.eleganceDeepNavy,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          ListTile(
            title: Text(name, style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w700)),
            subtitle: Text('${s['course'] ?? course} · ${s['department'] ?? department}'),
          ),
          ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: const Text('Banca esercizi'),
            subtitle: const Text('Crea, importa, nascondi gli esercizi'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ExerciseBankPage(department: department, course: course, subject: name, subjectLabel: name),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Assegna quiz ed esercizi'),
            subtitle: const Text('A studenti o gruppi, con scadenza'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => TeacherQuizAssignmentsPage(subjectId: id, department: department, course: course, subject: name),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Prova come studente'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ExerciseCatalogPage(department: department, course: course, subject: name, subjectLabel: name),
              ));
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Widget list = ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      if (widget.adminMode)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.adminAmber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.adminAmber.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Come admin puoi assegnare in qualsiasi materia: gli studenti vedranno “StudentLab” come mittente. '
            'In futuro le assegnazioni potranno partire dalle prenotazioni agli appelli.',
            style: SlText.body(p).copyWith(fontSize: 13),
          ),
        ),
      TextField(
        controller: _search,
        onSubmitted: (_) => _load(),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'Cerca una materia',
          suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward_rounded)),
        ),
      ),
      const SizedBox(height: 12),
      if (_loading)
        Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: p.skyBlue)))
      else if (_error != null)
        SlErrorCard(title: 'Attenzione', message: _error!, onRetry: _load)
      else if (_subjects.isEmpty)
        const SlEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Nessuna materia',
          message: 'Serve il profilo docente verificato e un’assegnazione verificata alla materia.',
        )
      else
        for (final Map<String, dynamic> s in _subjects)
          Card(
            color: p.eleganceMidnight,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const SlIconTile(icon: Icons.extension_outlined, size: 38),
              title: Text('${s['name']}', style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600)),
              subtitle: Text('${s['course'] ?? s['course_code']} · ${s['department_code']}', style: SlText.muted(p)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(s),
            ),
          ),
    ]);
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: widget.adminMode
          ? slAdminAppBar(context, title: 'Esercizi e assegnazioni', actions: <Widget>[
              IconButton(
                tooltip: 'Tipi di esercizio per dipartimento',
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const ExerciseAreasPage())),
                icon: const Icon(Icons.account_tree_outlined),
              ),
              IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
            ])
          : AppBar(backgroundColor: p.eleganceMidnight, foregroundColor: p.pureWhite, title: const Text('Esercizi')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: list)),
    );
  }
}
