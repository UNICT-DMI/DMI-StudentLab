import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../services/public_news_api_service.dart';
import '../../theme/nightTheme.dart';
import '../social_models.dart';
import 'models/public_news.dart';
import 'models/dmi_external_notice.dart';
import 'public_news_editor_page.dart';

class InstitutionalNewsPage extends StatefulWidget {
  final bool embedded;

  const InstitutionalNewsPage({
    super.key,
    this.embedded = false,
  });

  @override
  State<InstitutionalNewsPage> createState() => _InstitutionalNewsPageState();
}

class _InstitutionalNewsPageState extends State<InstitutionalNewsPage> {
  final PublicNewsApiService _newsApi = PublicNewsApiService();
  final ApiService _apiService = ApiService();
  final AuthSession _session = AuthSession.instance;
  final TextEditingController _searchController = TextEditingController();

  List<PublicNews> _items = [];
  List<DmiExternalNotice> _officialNotices = [];
  List<String> _availableTeachers = [];
  bool _hasOfficialSource = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _total = 0;
  int _offset = 0;
  static const int _limit = 50;

  String? _selectedUniversity;
  String? _selectedDepartment;
  String? _selectedCourse;
  String? _selectedTeacher;
  String? _selectedSubjectName;
  int? _selectedSubjectId;

  SocialUser? get _currentUser => _session.currentUser;
  bool get _isGuest => _session.isGuest || !_session.isAuthenticated;

  bool get _canPublish {
    final SocialUser? user = _currentUser;
    if (user == null || !user.isActive) return false;
    final String role = user.role.trim().toLowerCase();
    return role == 'admin' ||
        role == 'creator' ||
        (user.isTeacher && user.isVerifiedTeacher);
  }

  bool get _isAdminPublisher {
    final String role = _currentUser?.role.trim().toLowerCase() ?? '';
    return role == 'admin' || role == 'creator';
  }

  bool get _hasFilters =>
      _selectedUniversity != null ||
      _selectedDepartment != null ||
      _selectedCourse != null ||
      _selectedTeacher != null ||
      _selectedSubjectName != null;

  String _universityKey(String value) {
    final String text = value.trim().toLowerCase();
    return text == 'unict' || text.contains('università di catania') ||
            text.contains('università degli studi di catania')
        ? 'unict' : text;
  }

  String _departmentKey(String value) {
    final String text = value.trim().toLowerCase();
    if (text == 'dmi' || text.contains('matematica e informatica')) return 'dmi';
    if (text == 'dsbga' || text.contains('scienze biologiche, geologiche')) return 'dsbga';
    return text;
  }

  String _courseKey(String value) {
    final String text = value.trim().toLowerCase();
    if (RegExp(r'\blm[ -]?40\b').hasMatch(text) || text.contains('matematica magistrale')) return 'lm-40';
    if (RegExp(r'\blm[ -]?18\b').hasMatch(text) || text.contains('informatica magistrale')) return 'lm-18';
    if (RegExp(r'\bl[ -]?35\b').hasMatch(text) || text == 'matematica') return 'l-35';
    if (RegExp(r'\bl[ -]?13\b').hasMatch(text) || text == 'scienze biologiche') return 'l-13';
    if (RegExp(r'\bl[ -]?31\b').hasMatch(text) || text == 'informatica' ||
        text == 'scienze e tecnologie informatiche') return 'l-31';
    return text;
  }

  String _courseLabel(String value) {
    const Map<String, String> names = {
      'l-31': 'Informatica L-31', 'lm-18': 'Informatica magistrale (LM-18)',
      'l-35': 'Matematica L-35', 'lm-40': 'Matematica magistrale (LM-40)',
      'l-13': 'Scienze Biologiche L-13',
    };
    return names[_courseKey(value)] ?? value.trim();
  }

  String _teacherKey(String value) => value.trim().toLowerCase()
      .replaceFirst(RegExp(r'^(?:(?:prof(?:\.ssa|essoressa|essore|ssa)?|dott(?:\.ssa|oressa|ore|ssa)?)\.?\s+)+'), '')
      .replaceAll(RegExp(r'[^a-zà-ÿ0-9]+'), ' ')
      .trim();

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _applyMyPath();
    _load();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(_applyMyPath);
    _load();
  }

  void _applyMyPath() {
    final SocialUser? user = _currentUser;
    if (user == null) {
      _selectedUniversity = null;
      _selectedDepartment = null;
      _selectedCourse = null;
      _selectedTeacher = null;
      _selectedSubjectName = null;
      _selectedSubjectId = null;
      return;
    }

    _selectedUniversity =
        user.university.trim().isEmpty ? null : user.university.trim();
    _selectedDepartment =
        user.department.trim().isEmpty ? null : user.department.trim();
    _selectedCourse =
        user.course.trim().isEmpty ? null : _courseLabel(user.course);
    _selectedTeacher = null;
    _selectedSubjectName = null;
    _selectedSubjectId = null;
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
    });

    try {
      final Future<List<DmiExternalNotice>> officialFuture = _newsApi.getDmiNotices(
        university: _selectedUniversity, department: _selectedDepartment,
        course: _selectedCourse)
          .catchError((Object _) => <DmiExternalNotice>[]);
      final PublicNewsFeedResult result = await _newsApi.getFeed(
        search: _searchController.text,
        university: _selectedUniversity ?? '',
        department: _selectedDepartment ?? '',
        course: _selectedCourse ?? '',
        teacher: _selectedTeacher,
        subjectId: _selectedSubjectId,
        limit: _limit,
        offset: 0,
      );
      final List<DmiExternalNotice> official = await officialFuture;

      if (!mounted) return;

      List<PublicNews> items = result.items;
      items = items.where(_matchesAcademicScope).toList();
      final String? manualSubject =
          _selectedSubjectId == null ? _selectedSubjectName : null;

      if (manualSubject != null && manualSubject.trim().isNotEmpty) {
        final String wanted = manualSubject.trim().toLowerCase();
        items = items
            .where((PublicNews news) => news.subjectName.trim().toLowerCase() == wanted)
            .toList();
      }

      setState(() {
        _items = items;
        _availableTeachers = _selectedCourse == null
            ? []
            : _selectedTeacher != null
            ? _availableTeachers
            : ({for (final notice in official)
                if ((notice.teacher ?? '').trim().isNotEmpty)
                  _teacherKey(notice.teacher!): notice.teacher!.trim(),
                for (final news in result.items)
                  if (news.author.isVerifiedTeacher && _matchesCourseOnly(news))
                    _teacherKey(news.author.fullName): news.author.fullName,
              }.values.toList()..sort());
        _officialNotices = official.where(_matchesOfficialNotice).toList();
        _hasOfficialSource = official.isNotEmpty;
        _total = manualSubject == null ? result.total : items.length;
        _offset = result.items.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  bool _matchesOfficialNotice(DmiExternalNotice notice) {
    if (_selectedTeacher != null && _teacherKey(notice.teacher ?? '') != _teacherKey(_selectedTeacher!)) {
      return false;
    }
    final source = Uri.tryParse(notice.sourceUrl ?? notice.originalUrl);
    if (source == null) return false;
    final path = source.path.toLowerCase().replaceFirst('/it/corsi/', '/corsi/');
    final courseMatch = RegExp(r'^/corsi/(l-31|l-35|lm-18|lm-40|l-13)/(?:avvisi|avvisi-docente)(?:/|$)')
        .firstMatch(path);
    final courseCode = courseMatch?.group(1) ??
        (source.host.toLowerCase() == 'www.unict.it' && notice.course != null
            ? _courseKey(notice.course!) : null);
    final sourceDepartment = courseCode == 'l-13' ? 'dsbga' : 'dmi';
    final host = source.host.toLowerCase();
    if (_selectedCourse != null) {
      if (courseCode == null || _courseKey(_selectedCourse!) != courseCode ||
          (host != 'www.unict.it' &&
              host != (courseCode == 'l-13' ? 'www.dsbga.unict.it' : 'web.dmi.unict.it'))) {
        return false;
      }
      if (_selectedDepartment != null && _departmentKey(_selectedDepartment!) != sourceDepartment) return false;
    } else if (_selectedDepartment != null) {
      return false; // Nessun feed ufficiale autonomo per il dipartimento.
    } else if (notice.course != null || host != 'www.unict.it' ||
        !(path == '/it/news' || path == '/it/news/' ||
          RegExp(r'^/it/(?:[^/]+/)?news/[^/]+').hasMatch(path))) {
      return false;
    }
    final String search = _searchController.text.trim().toLowerCase();
    return search.isEmpty || '${notice.title} ${notice.content} ${notice.teacher ?? ''}'.toLowerCase().contains(search);
  }

  bool _matchesAcademicScope(PublicNews news) {
    if (_selectedTeacher != null && (!news.author.isVerifiedTeacher ||
        _teacherKey(news.author.fullName) != _teacherKey(_selectedTeacher!))) {
      return false;
    }
    if (_selectedCourse != null) {
      return (news.targetType == 'course' || news.targetType == 'subject') &&
          _matchesCourseOnly(news);
    }
    if (_selectedDepartment != null) {
      return news.targetType == 'department' &&
          _departmentKey(news.departmentCode.isNotEmpty ? news.departmentCode : news.department) ==
              _departmentKey(_selectedDepartment!);
    }
    return news.targetType == 'all' || news.targetType == 'university';
  }

  bool _matchesCourseOnly(PublicNews news) => _selectedCourse != null &&
      _courseKey(news.courseCode.isNotEmpty ? news.courseCode : news.course) ==
          _courseKey(_selectedCourse!);

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _items.length >= _total) return;

    setState(() {
      _loadingMore = true;
    });

    try {
      final PublicNewsFeedResult result = await _newsApi.getFeed(
        search: _searchController.text,
        university: _selectedUniversity ?? '',
        department: _selectedDepartment ?? '',
        course: _selectedCourse ?? '',
        teacher: _selectedTeacher,
        subjectId: _selectedSubjectId,
        limit: _limit,
        offset: _offset,
      );

      if (!mounted) return;

      final Map<int, PublicNews> merged = {
        for (final PublicNews item in _items) item.id: item,
      };
      for (final PublicNews item in result.items) {
        merged[item.id] = item;
      }

      final List<PublicNews> values = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _items = values.where(_matchesAcademicScope).toList();
        _total = result.total;
        _offset = result.offset + result.items.length;
      });
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  List<String> get _universities {
    final Map<String, String> values = {'unict': 'Università di Catania'};
    final String current = _currentUser?.university.trim() ?? '';
    if (current.isNotEmpty) values.putIfAbsent(_universityKey(current), () => current);
    for (final PublicNews news in _items) {
      if (news.university.trim().isNotEmpty) {
        values.putIfAbsent(_universityKey(news.university), () => news.university.trim());
      }
    }
    return values.values.toList()..sort();
  }

  List<String> get _departments {
    final Map<String, String> values = {
      'dmi': 'Dipartimento di Matematica e Informatica',
      'dsbga': 'Dipartimento di Scienze Biologiche, Geologiche e Ambientali',
    };
    final String current = _currentUser?.department.trim() ?? '';
    if (current.isNotEmpty) values.putIfAbsent(_departmentKey(current), () => current);
    for (final PublicNews news in _items) {
      if (_selectedUniversity != null &&
          _universityKey(news.university) != _universityKey(_selectedUniversity!)) {
        continue;
      }
      if (news.department.trim().isNotEmpty) {
        values.putIfAbsent(_departmentKey(news.department), () => news.department.trim());
      }
    }
    return values.values.toList()..sort();
  }

  List<String> get _courses {
    final Map<String, String> values = {};
    if (_selectedDepartment == null || _departmentKey(_selectedDepartment!) == 'dmi') {
      values.addAll(const {'l-31': 'Informatica L-31',
        'lm-18': 'Informatica magistrale (LM-18)',
        'l-35': 'Matematica L-35', 'lm-40': 'Matematica magistrale (LM-40)'});
    }
    if (_selectedDepartment == null || _departmentKey(_selectedDepartment!) == 'dsbga') {
      values['l-13'] = 'Scienze Biologiche L-13';
    }
    final String current = _currentUser?.course.trim() ?? '';
    if (current.isNotEmpty && (_selectedDepartment == null ||
        _departmentKey(_currentUser?.department ?? '') == _departmentKey(_selectedDepartment!))) {
      values.putIfAbsent(_courseKey(current), () => _courseLabel(current));
    }
    for (final PublicNews news in _items) {
      if (_selectedDepartment != null &&
          _departmentKey(news.department) != _departmentKey(_selectedDepartment!)) {
        continue;
      }
      if (news.course.trim().isNotEmpty) {
        values.putIfAbsent(_courseKey(news.course), () => _courseLabel(news.course));
      }
    }
    return values.values.toList()..sort();
  }

  List<_SubjectFilterValue> get _subjects {
    final Map<String, _SubjectFilterValue> values = {};
    for (final PublicNews news in _items) {
      final String name = news.subjectName.trim();
      if (name.isEmpty) continue;
      values[name.toLowerCase()] = _SubjectFilterValue(
        id: news.subjectId,
        name: name,
      );
    }
    final List<_SubjectFilterValue> result = values.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<void> _selectStringFilter({
    required String title,
    required List<String> values,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) async {
    final TextEditingController manualController =
        TextEditingController(text: selected ?? '');
    String query = '';

    final String? result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final String normalized = query.trim().toLowerCase();
            final List<String> visible = values
                .where((String value) =>
                    normalized.isEmpty || value.toLowerCase().contains(normalized))
                .toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.68,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        style: TextStyle(color: AppColors.pureWhite),
                        decoration: const InputDecoration(
                          hintText: 'Cerca tra i suggerimenti...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (String value) {
                          setSheetState(() {
                            query = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: Icon(
                          Icons.filter_alt_off_outlined,
                          color: AppColors.white54,
                        ),
                        title: Text(
                          'Qualsiasi',
                          style: TextStyle(color: AppColors.pureWhite),
                        ),
                        onTap: () => Navigator.pop(sheetContext, ''),
                      ),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final String value in visible)
                              ListTile(
                                leading: Icon(
                                  Icons.auto_awesome_outlined,
                                  color: AppColors.materialSky,
                                ),
                                title: Text(
                                  value,
                                  style: TextStyle(color: AppColors.pureWhite),
                                ),
                                trailing: selected == value
                                    ? Icon(
                                        Icons.check_rounded,
                                        color: AppColors.greenAccent,
                                      )
                                    : null,
                                onTap: () => Navigator.pop(sheetContext, value),
                              ),
                            Divider(color: AppColors.white10),
                            Padding(
                              padding: EdgeInsets.only(top: 8, bottom: 8),
                              child: Text(
                                'Oppure inserisci manualmente',
                                style: TextStyle(
                                  color: AppColors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            TextField(
                              controller: manualController,
                              style: TextStyle(color: AppColors.pureWhite),
                              decoration: const InputDecoration(
                                labelText: 'Valore manuale',
                                prefixIcon: Icon(Icons.edit_outlined),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(
                                  sheetContext,
                                  manualController.text.trim(),
                                );
                              },
                              child: const Text('Usa valore manuale'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    manualController.dispose();
    if (result == null || !mounted) return;
    onSelected(result.trim().isEmpty ? null : result.trim());
    await _load();
  }

  Future<void> _selectSubjectFilter() async {
    final TextEditingController manualController =
        TextEditingController(text: _selectedSubjectName ?? '');

    final _SubjectFilterValue? result =
        await showModalBottomSheet<_SubjectFilterValue>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceDeepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleziona materia',
                    style: TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.filter_alt_off_outlined),
                    title: Text(
                      'Qualsiasi materia',
                      style: TextStyle(color: AppColors.pureWhite),
                    ),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      const _SubjectFilterValue(id: null, name: ''),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final _SubjectFilterValue subject in _subjects)
                          ListTile(
                            leading: Icon(
                              Icons.menu_book_outlined,
                              color: AppColors.materialSky,
                            ),
                            title: Text(
                              subject.name,
                              style: TextStyle(color: AppColors.pureWhite),
                            ),
                            onTap: () => Navigator.pop(sheetContext, subject),
                          ),
                        Divider(color: AppColors.white10),
                        TextField(
                          controller: manualController,
                          style: TextStyle(color: AppColors.pureWhite),
                          decoration: const InputDecoration(
                            labelText: 'Materia manuale',
                            prefixIcon: Icon(Icons.edit_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            final String value = manualController.text.trim();
                            if (value.isEmpty) return;
                            Navigator.pop(
                              sheetContext,
                              _SubjectFilterValue(id: null, name: value),
                            );
                          },
                          child: const Text('Usa valore manuale'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    manualController.dispose();
    if (result == null || !mounted) return;

    setState(() {
      _selectedSubjectId = result.id;
      _selectedSubjectName = result.name.isEmpty ? null : result.name;
    });
    await _load();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _selectedUniversity = null;
      _selectedDepartment = null;
      _selectedCourse = null;
      _selectedTeacher = null;
      _selectedSubjectName = null;
      _selectedSubjectId = null;
    });
    _load();
  }

  Future<void> _restoreMyPath() async {
    setState(_applyMyPath);
    await _load();
  }

  Future<void> _openPublisher() async {
    if (!_canPublish) return;

    bool? created;
    if (_isAdminPublisher) {
      created = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const PublicNewsEditorPage.admin(),
        ),
      );
    } else {
      List<Map<String, dynamic>> subjects = [];
      try {
        subjects = await _apiService.getTeacherSubjects();
      } catch (_) {}

      if (!mounted) return;
      created = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PublicNewsEditorPage.teacher(subjects: subjects),
        ),
      );
    }

    if (created == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: AppColors.brandNightBlue,
              foregroundColor: AppColors.pureWhite,
              title: const Text('Avvisi'),
            ),
      floatingActionButton: _canPublish
          ? FloatingActionButton.extended(
              onPressed: _openPublisher,
              backgroundColor:
                  _isAdminPublisher ? AppColors.socialBlue : AppColors.teacherIndigo,
              foregroundColor: AppColors.pureWhite,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Pubblica'),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Avvisi StudentLab',
                    style: TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Comunicazioni pubbliche accademiche e istituzionali. Gli avvisi dei gruppi restano nei rispettivi gruppi.',
                    style: TextStyle(
                      color: AppColors.pureWhite.withValues(alpha: 0.52),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildFilters(),
                  const SizedBox(height: 12),
                  _buildResultsHeader(),
                  const SizedBox(height: 14),
                  _buildContent(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onSubmitted: (_) => _load(),
      style: TextStyle(color: AppColors.pureWhite),
      decoration: InputDecoration(
        hintText: 'Cerca autore, titolo, materia, corso...',
        hintStyle: TextStyle(
          color: AppColors.pureWhite.withValues(alpha: 0.35),
        ),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.skyBlue),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Cancella ricerca',
                onPressed: () {
                  _searchController.clear();
                  _load();
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: AppColors.eleganceMidnight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterButton(
            icon: Icons.account_balance_outlined,
            label: _selectedUniversity ?? 'Ateneo',
            active: _selectedUniversity != null,
            onTap: () => _selectStringFilter(
              title: 'Seleziona ateneo',
              values: _universities,
              selected: _selectedUniversity,
              onSelected: (value) {
                setState(() {
                  _selectedUniversity = value;
                  _selectedDepartment = null;
                  _selectedCourse = null;
                  _selectedTeacher = null;
                  _selectedSubjectName = null;
                  _selectedSubjectId = null;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          _FilterButton(
            icon: Icons.domain_outlined,
            label: _selectedDepartment ?? 'Dipartimento',
            active: _selectedDepartment != null,
            onTap: () => _selectStringFilter(
              title: 'Seleziona dipartimento',
              values: _departments,
              selected: _selectedDepartment,
              onSelected: (value) {
                setState(() {
                  _selectedDepartment = value;
                  _selectedCourse = null;
                  _selectedTeacher = null;
                  _selectedSubjectName = null;
                  _selectedSubjectId = null;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          _FilterButton(
            icon: Icons.school_outlined,
            label: _selectedCourse ?? 'Corso',
            active: _selectedCourse != null,
            onTap: () => _selectStringFilter(
              title: 'Seleziona corso',
              values: _courses,
              selected: _selectedCourse,
              onSelected: (value) {
                setState(() {
                  _selectedCourse = value;
                  _selectedTeacher = null;
                  _selectedSubjectName = null;
                  _selectedSubjectId = null;
                });
              },
            ),
          ),
          if (_selectedCourse != null && _availableTeachers.isNotEmpty) ...[
            const SizedBox(width: 8),
            _FilterButton(
              icon: Icons.person_search_outlined,
              label: _selectedTeacher ?? 'Docente',
              active: _selectedTeacher != null,
              onTap: () => _selectStringFilter(
                title: 'Seleziona docente',
                values: _availableTeachers,
                selected: _selectedTeacher,
                onSelected: (value) => setState(() => _selectedTeacher = value),
              ),
            ),
          ],
          if (_currentUser != null) ...[
            const SizedBox(width: 8),
            _FilterButton(
              icon: Icons.my_location_outlined,
              label: 'Il mio percorso',
              active: false,
              onTap: _restoreMyPath,
            ),
          ],
          if (_hasFilters || _searchController.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            _FilterButton(
              icon: Icons.restart_alt_rounded,
              label: 'Reset',
              active: false,
              onTap: _resetFilters,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Row(
      children: [
        Text(
          '${_total + _officialNotices.length} ${_total + _officialNotices.length == 1 ? 'avviso' : 'avvisi'}',
          style: TextStyle(
            color: AppColors.pureWhite,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          _isGuest ? 'Lettura pubblica' : 'Feed pubblico',
          style: TextStyle(color: AppColors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _StateCard(
        icon: Icons.error_outline_rounded,
        title: 'Impossibile caricare gli avvisi',
        message: _error!,
        actionLabel: 'Riprova',
        onAction: _load,
      );
    }

    if (_items.isEmpty && _officialNotices.isEmpty) {
      return const _StateCard(
        icon: Icons.newspaper_outlined,
        title: 'Nessun avviso',
        message: 'Non ci sono comunicazioni compatibili con i filtri selezionati.',
      );
    }

    return Column(
      children: [
        for (final DmiExternalNotice notice in _officialNotices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DmiNoticeCard(notice: notice, onOpen: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => _DmiNoticeDetailPage(notice: notice),
              ));
            }),
          ),
        for (final PublicNews news in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PublicNewsCard(
              news: news,
              isGuest: _isGuest,
              onOpen: () => _openDetail(news),
              onDelete: news.canDelete ? () => _delete(news) : null,
              onModerate: news.canModerate ? () => _moderate(news) : null,
              onReport: news.canReport ? () => _report(news) : null,
              onBlock: news.canBlockAuthor ? () => _block(news) : null,
            ),
          ),
        if (_items.length < _total)
          OutlinedButton(
            onPressed: _loadingMore ? null : _loadMore,
            child: Text(_loadingMore ? 'Caricamento...' : 'Carica altri avvisi'),
          ),
      ],
    );
  }

  Future<void> _openDetail(PublicNews news) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicNewsDetailPage(news: news, isGuest: _isGuest),
      ),
    );
  }

  Future<void> _delete(PublicNews news) async {
    final bool confirmed = await _confirm(
      title: 'Elimina avviso',
      message: 'Vuoi eliminare questo avviso?',
      action: 'Elimina',
    );
    if (!confirmed) return;

    try {
      await _newsApi.delete(news.id);
      await _load();
      _showMessage('Avviso eliminato.');
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _moderate(PublicNews news) async {
    final TextEditingController controller = TextEditingController();
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.eleganceDeepNavy,
        title: Text(
          'Rimuovi avviso',
          style: TextStyle(color: AppColors.pureWhite),
        ),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          style: TextStyle(color: AppColors.pureWhite),
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              final String value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(
              'Rimuovi',
              style: TextStyle(color: AppColors.redAccent),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;

    try {
      await _newsApi.moderate(newsId: news.id, reason: reason);
      await _load();
      _showMessage('Avviso rimosso.');
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _report(PublicNews news) async {
    final _ReportDraft? draft = await showModalBottomSheet<_ReportDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.eleganceDeepNavy,
      builder: (_) => const _PublicNewsReportSheet(),
    );
    if (draft == null) return;

    try {
      await _newsApi.report(
        newsId: news.id,
        reason: draft.reason,
        description: draft.description,
      );
      _showMessage('Segnalazione inviata.');
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _block(PublicNews news) async {
    final bool confirmed = await _confirm(
      title: 'Blocca utente',
      message:
          'Non vedrai più gli avvisi pubblicati da ${news.author.fullName}. Vuoi continuare?',
      action: 'Blocca',
    );
    if (!confirmed) return;

    try {
      await _newsApi.blockAuthor(news.authorUserId);
      await _load();
      _showMessage('Utente bloccato.');
    } catch (error) {
      _showMessage(_friendlyError(error));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppColors.eleganceDeepNavy,
        title: Text(title, style: TextStyle(color: AppColors.pureWhite)),
        content: Text(message, style: TextStyle(color: AppColors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action, style: TextStyle(color: AppColors.redAccent)),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _friendlyError(Object error) {
    final String value = error.toString().toLowerCase();
    if (value.contains('401')) return 'La sessione non è più valida. Accedi nuovamente.';
    if (value.contains('403')) return 'Non hai i permessi necessari per questa operazione.';
    if (value.contains('404')) return 'L’avviso non è più disponibile.';
    if (value.contains('409')) return 'Questa operazione è già stata registrata.';
    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection') ||
        value.contains('timeout')) {
      return 'Non è stato possibile connettersi a StudentLab. Controlla la connessione e riprova.';
    }
    return 'Non è stato possibile completare l’operazione. Riprova.';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _dmiDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class _DmiNoticeCard extends StatelessWidget {
  final DmiExternalNotice notice;
  final VoidCallback onOpen;

  const _DmiNoticeCard({required this.notice, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity, child: Card(
      color: AppColors.eleganceMidnight,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notice.title, style: TextStyle(color: AppColors.pureWhite, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(notice.sourceLabel, style: TextStyle(color: AppColors.materialSky)),
              if (notice.teacher != null && notice.teacher!.trim().isNotEmpty)
                Text(notice.teacher!, style: TextStyle(color: AppColors.white70)),
              Text(_dmiDate(notice.publishedOn), style: TextStyle(color: AppColors.white54)),
              const SizedBox(height: 10),
              Text(notice.content, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.white70)),
            ],
          ),
        ),
      ),
    ));
  }
}

class _DmiNoticeDetailPage extends StatelessWidget {
  final DmiExternalNotice notice;

  const _DmiNoticeDetailPage({required this.notice});

  List<Widget> _formattedContent() {
    // La fonte fornisce talvolta testo senza ritorni a capo. Separiamo i
    // canali e le coppie matricola/esito conservando integralmente i valori.
    final String content = notice.content.replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    final RegExp channel = RegExp(r'\bCanale\s+[A-Z]{1,3}(?:\s*[-/]\s*[A-Z]{1,3})?\b', caseSensitive: false);
    final matches = channel.allMatches(content).toList();
    final parts = <Widget>[];
    void addBody(String value) {
      final String formatted = value.trim().replaceAllMapped(
        RegExp(r'(\b\d{7,10}\s*[:–-]\s*[^\s,;]+)(?=\s+\d{7,10}\b)'),
        (match) => '${match.group(1)}\n',
      );
      if (formatted.isEmpty) return;
      parts.add(Padding(padding: const EdgeInsets.only(bottom: 14),
        child: SelectableText(formatted, style: TextStyle(color: AppColors.pureWhite, height: 1.65))));
    }
    if (matches.isEmpty) {
      addBody(content);
    } else {
      addBody(content.substring(0, matches.first.start));
      for (int i = 0; i < matches.length; i++) {
        parts.add(Padding(padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text(matches[i].group(0)!, style: TextStyle(color: AppColors.materialSky,
            fontSize: 14, fontWeight: FontWeight.w700))));
        addBody(content.substring(matches[i].end,
          i + 1 < matches.length ? matches[i + 1].start : content.length));
      }
    }
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(backgroundColor: AppColors.brandNightBlue, foregroundColor: AppColors.pureWhite,
        title: const Text('Avviso')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(notice.title, style: TextStyle(color: AppColors.pureWhite, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(notice.sourceLabel, style: TextStyle(color: AppColors.materialSky)),
          if (notice.teacher != null && notice.teacher!.trim().isNotEmpty)
            Text(notice.teacher!, style: TextStyle(color: AppColors.white70)),
          Text(_dmiDate(notice.publishedOn), style: TextStyle(color: AppColors.white54)),
          const SizedBox(height: 22),
          ..._formattedContent(),
          const SizedBox(height: 28),
          Divider(color: AppColors.white38),
          Text('Fonte: ${notice.sourceLabel}', style: TextStyle(color: AppColors.white70)),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: () async {
              final Uri? url = Uri.tryParse(notice.originalUrl);
              if (url == null || url.scheme != 'https' ||
                  !const ['web.dmi.unict.it', 'www.dsbga.unict.it', 'www.unict.it'].contains(url.host)) return;
              if (!await launchUrl(url, mode: LaunchMode.externalApplication) && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossibile aprire l’avviso originale.')));
              }
            },
            icon: const Icon(Icons.open_in_new), label: const Text('Apri avviso originale'),
          )),
        ]),
      ))),
    );
  }
}

class PublicNewsDetailPage extends StatelessWidget {
  final PublicNews news;
  final bool isGuest;

  const PublicNewsDetailPage({
    super.key,
    required this.news,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Avviso'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _PublicNewsCard(
                  news: news,
                  isGuest: isGuest,
                  expanded: true,
                ),
],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicNewsCard extends StatelessWidget {
  final PublicNews news;
  final bool isGuest;
  final bool expanded;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;
  final VoidCallback? onModerate;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  const _PublicNewsCard({
    required this.news,
    required this.isGuest,
    this.expanded = false,
    this.onOpen,
    this.onDelete,
    this.onModerate,
    this.onReport,
    this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.skyBlue.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.brandNightBlue,
                child: Text(
                  _initials(news.author.fullName),
                  style: TextStyle(
                    color: AppColors.skyBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      news.author.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.pureWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      news.author.roleLabel,
                      style: TextStyle(
                        color: AppColors.materialSky,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(news.createdAt),
                      style: TextStyle(color: AppColors.white38, fontSize: 9),
                    ),
                  ],
                ),
              ),
              if (!isGuest &&
                  (onDelete != null ||
                      onModerate != null ||
                      onReport != null ||
                      onBlock != null))
                PopupMenuButton<String>(
                  tooltip: 'Azioni',
                  color: AppColors.eleganceDeepNavy,
                  onSelected: (String value) {
                    if (value == 'delete') onDelete?.call();
                    if (value == 'moderate') onModerate?.call();
                    if (value == 'report') onReport?.call();
                    if (value == 'block') onBlock?.call();
                  },
                  itemBuilder: (_) => [
                    if (onReport != null)
                      const PopupMenuItem(value: 'report', child: Text('Segnala')),
                    if (onBlock != null)
                      const PopupMenuItem(value: 'block', child: Text('Blocca autore')),
                    if (onModerate != null)
                      const PopupMenuItem(
                        value: 'moderate',
                        child: Text('Rimuovi come moderatore'),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Elimina',
                          style: TextStyle(color: AppColors.redAccent),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            news.academicContext,
            maxLines: expanded ? null : 2,
            overflow: expanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.materialSky,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            news.title,
            maxLines: expanded ? null : 2,
            overflow: expanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.pureWhite,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            news.content,
            maxLines: expanded ? null : 6,
            overflow: expanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.pureWhite.withValues(alpha: 0.78),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (!expanded && news.needsDedicatedPage && onOpen != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Apri avviso'),
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((value) => value.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatDate(DateTime value) {
    final DateTime date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} · '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? AppColors.materialSky : AppColors.white60,
        backgroundColor:
            active ? AppColors.skyBlue.withValues(alpha: 0.10) : null,
        side: BorderSide(
          color: active
              ? AppColors.skyBlue.withValues(alpha: 0.30)
              : AppColors.skyBlue.withValues(alpha: 0.10),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.white30, size: 40),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.pureWhite,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.white54, fontSize: 10),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubjectFilterValue {
  final int? id;
  final String name;

  const _SubjectFilterValue({
    required this.id,
    required this.name,
  });
}

class _PublicNewsReportSheet extends StatefulWidget {
  const _PublicNewsReportSheet();

  @override
  State<_PublicNewsReportSheet> createState() => _PublicNewsReportSheetState();
}

class _PublicNewsReportSheetState extends State<_PublicNewsReportSheet> {
  final TextEditingController _controller = TextEditingController();
  String _reason = 'spam';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Segnala avviso',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                dropdownColor: AppColors.eleganceDeepNavy,
                items: const [
                  DropdownMenuItem(value: 'spam', child: Text('Spam')),
                  DropdownMenuItem(
                    value: 'harassment',
                    child: Text('Molestie o comportamento offensivo'),
                  ),
                  DropdownMenuItem(
                    value: 'hate',
                    child: Text('Contenuto discriminatorio'),
                  ),
                  DropdownMenuItem(
                    value: 'privacy',
                    child: Text('Violazione della privacy'),
                  ),
                  DropdownMenuItem(
                    value: 'illegal_content',
                    child: Text('Contenuto illecito'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Altro')),
                ],
                onChanged: (String? value) {
                  if (value != null) setState(() => _reason = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                style: TextStyle(color: AppColors.pureWhite),
                decoration: const InputDecoration(labelText: 'Dettagli facoltativi'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    _ReportDraft(
                      reason: _reason,
                      description: _controller.text.trim(),
                    ),
                  );
                },
                child: const Text('Invia segnalazione'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportDraft {
  final String reason;
  final String description;

  const _ReportDraft({
    required this.reason,
    required this.description,
  });
}
