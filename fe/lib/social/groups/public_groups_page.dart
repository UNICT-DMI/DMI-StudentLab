import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import 'models/study_group.dart';
import 'study_group_detail_page.dart';
class PublicGroupsPage extends StatefulWidget {
  const PublicGroupsPage( {
    super.key,
  }
  );
  @override State<PublicGroupsPage> createState() => _PublicGroupsPageState();
}
class _PublicGroupsPageState extends State<PublicGroupsPage> {
  final ApiService _apiService = ApiService();
  final AuthSession _session = AuthSession.instance;
  final TextEditingController _searchController = TextEditingController();
  List<StudyGroup> _groups = [];
  String _searchQuery = '';
  String? _selectedSubject;
  String? _selectedDepartment;
  String? _selectedCourse;
  _GroupSort _sort = _GroupSort.name;
  bool _loading = true;
  String? _error;
  bool get isGuest {
    return _session.isGuest;
  }
  @override void initState() {
    super.initState();
    _session.addListener(_onSessionChanged,);
    _loadGroups();
  }
  @override void dispose() {
    _session.removeListener(_onSessionChanged,);
    _searchController.dispose();
    super.dispose();
  }
  void _onSessionChanged() {
    if (!mounted) {
      return;
    }
    _loadGroups();
  }
  Future<void> _loadGroups() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      }
      );
    }
    try {
      final List<Map<String, dynamic>> data = await _apiService.getGroups();
      final int? currentUserId = _session.currentUserId;
      final List<StudyGroup> groups = [];
      for (final Map<String, dynamic> rawGroup in data) {
        final Map<String, dynamic> merged = Map<String, dynamic>.from(rawGroup,);
        final int? groupId = _toInt(rawGroup['id'],);
        if (groupId != null) {
          try {
            final Map<String, dynamic> detail = await _apiService.getGroup(groupId,);
            merged.addAll(detail,);
          }  catch (_) {
          }
          try {
            final List<Map<String, dynamic>> materials = await _apiService.getGroupMaterials(groupId,);
            merged['material_count'] = materials.length;
          }  catch (_) {
          }
        }
        final StudyGroup group = StudyGroup.fromJson(merged, currentUserId: currentUserId,);
        if (!group.isPrivate) {
          groups.add(group,);
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = groups;
        _loading = false;
      }
      );
    }  catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _cleanError(e,);
        _loading = false;
      }
      );
    }
  }
  List<StudyGroup> get _filteredGroups {
    Iterable<StudyGroup> result = _groups.where((group) => !group.isPrivate,);
    final String query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((group) {
        final String searchable = [group.name, group.description, group.subject, group.department, group.course,].join(' ',
        ).toLowerCase();
        return searchable.contains(query,);
      }
      ,);
    }
    if (_selectedSubject != null) {
      result = result.where((group) => group.subject == _selectedSubject,);
    }
    if (_selectedDepartment != null) {
      result = result.where((group) => group.department == _selectedDepartment,);
    }
    if (_selectedCourse != null) {
      result = result.where((group) => group.course == _selectedCourse,);
    }
    final List<StudyGroup> groups = result.toList();
    switch (_sort) {
      case _GroupSort.name: groups.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase(),),);
      case _GroupSort.members: groups.sort((a, b) => b.memberCount.compareTo(a.memberCount,),);
      case _GroupSort.materials: groups.sort((a, b) => b.materialCount.compareTo(a.materialCount,),);
    }
    return groups;
  }
  List<String> get _subjects {
    final List<String> values = _groups.map((group) => group.subject,).where((value) => value.trim().isNotEmpty,).toSet().toList();
    values.sort();
    return values;
  }
  List<String> get _departments {
    final List<String> values = _groups.map((group) => group.department,).where((value) => value.trim().isNotEmpty,
    ).toSet().toList();
    values.sort();
    return values;
  }
  List<String> get _courses {
    final List<String> values = _groups.where((group) => _selectedDepartment == null || group.department == _selectedDepartment,
    ).map((group) => group.course,).where((value) => value.trim().isNotEmpty,).toSet().toList();
    values.sort();
    return values;
  }
  bool get _hasFilters {
    return _selectedSubject != null || _selectedDepartment != null || _selectedCourse != null || _sort != _GroupSort.name;
  }
  String get _sortLabel {
    switch (_sort) {
      case _GroupSort.name: return 'Ordina';
      case _GroupSort.members: return 'Più membri';
      case _GroupSort.materials: return 'Più materiale';
    }
  }
  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedSubject = null;
      _selectedDepartment = null;
      _selectedCourse = null;
      _sort = _GroupSort.name;
    }
    );
  }
  Future<void> _openGroup(StudyGroup group,) async {
    await Navigator.of(context,).push(MaterialPageRoute(builder: (_) => StudyGroupDetailPage(group: group,),),);
    if (mounted) {
      _loadGroups();
    }
  }
  @override Widget build(BuildContext context,) {
    return Scaffold(backgroundColor: AppColors.darkElegance, appBar: AppBar(backgroundColor: AppColors.brandNightBlue,
    foregroundColor: AppColors.pureWhite, elevation: 0, title: const Text('Gruppi pubblici', style: TextStyle(fontSize: 19,
    fontWeight: FontWeight.w600,),), actions: [IconButton(tooltip: 'Aggiorna', onPressed: _loading ? null : _loadGroups,
    icon: const Icon(Icons.refresh_rounded,),),],), body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth:
    1050,), child: RefreshIndicator(onRefresh: _loadGroups, child: ListView(physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(20,), children: [const Text('Trova il tuo gruppo', style: TextStyle(color: AppColors.pureWhite,
    fontSize: 25, fontWeight: FontWeight.bold,),), const SizedBox(height: 6,), Text('Esplora i gruppi pubblici di StudentLab. '
    'Cerca per nome, materia, dipartimento o corso ' 'e scopri materiali, appunti e community ' 'dedicate allo studio.',
    style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.52,), fontSize: 12, height: 1.45,),), if (isGuest)...[const
    SizedBox(height: 20,), _buildGuestInfo(),], const SizedBox(height: 18,), _buildSearchBar(), const SizedBox(height: 12,
    ), _buildFilters(), const SizedBox(height: 16,), _buildResultsHeader(), const SizedBox(height: 14,), _buildContent(),
    const SizedBox(height: 24,),],),),),),),);
  }
  Widget _buildGuestInfo() {
    return Container(padding: const EdgeInsets.all(14,), decoration: BoxDecoration(color: AppColors.skyBlue.withValues(alpha:
    0.06,), borderRadius: BorderRadius.circular(14,), border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.13,
    ),),), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.visibility_outlined,
    color: AppColors.materialSky, size: 20,), const SizedBox(width: 10,), Expanded(child: Text('Stai esplorando come Guest. '
    'Puoi cercare e aprire i gruppi pubblici, ' 'vedere i partecipanti e scaricare il materiale ' 'disponibile per consultarlo offline. '
    'Per entrare nei gruppi, utilizzare la chat ' 'o condividere materiale devi accedere a StudentLab.', style: TextStyle(color:
    AppColors.pureWhite.withValues(alpha: 0.55,), fontSize: 11, height: 1.45,),),),],),);
  }
  Widget _buildSearchBar() {
    return TextField(controller: _searchController, onChanged: (String value,) {
      setState(() {
        _searchQuery = value;
      }
      );
    }
    , style: const TextStyle(color: AppColors.pureWhite,), decoration: InputDecoration(hintText: 'Cerca nome, materia, corso...',
    hintStyle: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.35,),), prefixIcon: const Icon(Icons.search_rounded,
    color: AppColors.skyBlue,), suffixIcon: _searchQuery.isEmpty ? null : IconButton(tooltip: 'Cancella ricerca', onPressed:
    () {
      _searchController.clear();
      setState(() {
        _searchQuery = '';
      }
      );
    }
    , icon: const Icon(Icons.close_rounded, color: Colors.white54,),), filled: true, fillColor: AppColors.eleganceMidnight,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15,), borderSide: BorderSide.none,), enabledBorder: OutlineInputBorder(borderRadius:
    BorderRadius.circular(15,), borderSide: BorderSide(color: AppColors.skyBlue.withValues(alpha: 0.10,),),), focusedBorder:
    OutlineInputBorder(borderRadius: BorderRadius.circular(15,), borderSide: BorderSide(color: AppColors.skyBlue.withValues(alpha:
    0.50,),),),),);
  }
  Widget _buildFilters() {
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_FilterButton(icon: Icons.menu_book_outlined,
    label: _selectedSubject ?? 'Materia', active: _selectedSubject != null, onTap: () {
      _showStringFilter(title: 'Seleziona materia', values: _subjects, selected: _selectedSubject, onSelected: (value,
      ) {
        setState(() {
          _selectedSubject = value;
        }
        );
      }
      ,);
    }
    ,), const SizedBox(width: 8,), _FilterButton(icon: Icons.account_balance_outlined, label: _selectedDepartment ?? 'Dipartimento',
    active: _selectedDepartment != null, onTap: () {
      _showStringFilter(title: 'Seleziona dipartimento', values: _departments, selected: _selectedDepartment, onSelected: (value,
      ) {
        setState(() {
          _selectedDepartment = value;
          _selectedCourse = null;
        }
        );
      }
      ,);
    }
    ,), const SizedBox(width: 8,), _FilterButton(icon: Icons.school_outlined, label: _selectedCourse ?? 'Corso', active: _selectedCourse
    != null, onTap: () {
      _showStringFilter(title: 'Seleziona corso', values: _courses, selected: _selectedCourse, onSelected: (value,) {
        setState(() {
          _selectedCourse = value;
        }
        );
      }
      ,);
    }
    ,), const SizedBox(width: 8,), _FilterButton(icon: Icons.sort_rounded, label: _sortLabel, active: _sort != _GroupSort.name,
    onTap: _showSortFilter,), if (_hasFilters || _searchQuery.isNotEmpty)...[const SizedBox(width: 8,), TextButton.icon(onPressed:
    _resetFilters, icon: const Icon(Icons.filter_alt_off_outlined, size: 17,), label: const Text('Reset',),),],],),
    );
  }
  Widget _buildResultsHeader() {
    if (_loading || _error != null) {
      return const SizedBox.shrink();
    }
    final int count = _filteredGroups.length;
    return Row(children: [Expanded(child: Text(count == 1 ? '1 gruppo trovato' : '$count gruppi trovati', style: TextStyle(color:
    AppColors.pureWhite.withValues(alpha: 0.55,), fontSize: 11, fontWeight: FontWeight.w500,),),), Text('${_groups.length} pubblici',
    style: TextStyle(color: AppColors.materialSky.withValues(alpha: 0.75,), fontSize: 10,),),],);
  }
  Widget _buildContent() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 60,), child: Center(child: CircularProgressIndicator(),
      ),);
    }
    if (_error != null) {
      return _PublicGroupsError(message: _error!, onRetry: _loadGroups,);
    }
    final List<StudyGroup> groups = _filteredGroups;
    if (groups.isEmpty) {
      return _EmptyPublicGroups(filtered: _hasFilters || _searchQuery.isNotEmpty, onReset: _resetFilters,);
    }
    return LayoutBuilder(builder: (context, constraints,) {
      int columns = 2;
      if (constraints.maxWidth < 500) {
        columns = 1;
      }  else if (constraints.maxWidth >= 900) {
        columns = 3;
      }
      return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: groups.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing:
      12, mainAxisExtent: 205,), itemBuilder: (context, index,) {
        final StudyGroup group = groups[index];
        return _PublicGroupCard(group: group, onTap: () {
          _openGroup(group,);
        }
        ,);
      }
      ,);
    }
    ,);
  }
  Future<void> _showStringFilter( {
    required String title, required List<String> values, required String? selected, required ValueChanged<String?> onSelected,
  }
  ) async {
    final String? value = await showModalBottomSheet<String?>(context: context, backgroundColor: AppColors.eleganceDeepNavy,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20,),),), builder: (sheetContext,
    ) {
      return SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 10,), children: [Padding(padding:
      const EdgeInsets.fromLTRB(18, 8, 18, 10,), child: Text(title, style: const TextStyle(color: AppColors.pureWhite,
      fontSize: 18, fontWeight: FontWeight.bold,),),), ListTile(leading: const Icon(Icons.clear_all_rounded, color: AppColors.skyBlue,
      ), title: const Text('Tutti', style: TextStyle(color: AppColors.pureWhite,),), trailing: selected == null ? const Icon(Icons.check_rounded,
      color: AppColors.skyBlue,) : null, onTap: () {
        Navigator.pop(sheetContext, '',);
      }
      ,),...values.map((String item,) {
        return ListTile(title: Text(item, style: const TextStyle(color: AppColors.pureWhite,),), trailing: selected == item ? const
        Icon(Icons.check_rounded, color: AppColors.skyBlue,) : null, onTap: () {
          Navigator.pop(sheetContext, item,);
        }
        ,);
      }
      ,),],),);
    }
    ,);
    if (!mounted || value == null) {
      return;
    }
    if (value.isEmpty) {
      onSelected(null,);
      return;
    }
    onSelected(value,);
  }
  Future<void> _showSortFilter() async {
    final _GroupSort? selected = await showModalBottomSheet< _GroupSort>(context: context, backgroundColor: AppColors.eleganceDeepNavy,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20,),),), builder: (sheetContext,
    ) {
      return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [const SizedBox(height: 8,), _SortOption(title: 'Nome A-Z',
      icon: Icons.sort_by_alpha_rounded, selected: _sort == _GroupSort.name, onTap: () {
        Navigator.pop(sheetContext, _GroupSort.name,);
      }
      ,), _SortOption(title: 'Più membri', icon: Icons.groups_rounded, selected: _sort == _GroupSort.members, onTap: () {
        Navigator.pop(sheetContext, _GroupSort.members,);
      }
      ,), _SortOption(title: 'Più materiale', icon: Icons.folder_copy_outlined, selected: _sort == _GroupSort.materials,
      onTap: () {
        Navigator.pop(sheetContext, _GroupSort.materials,);
      }
      ,), const SizedBox(height: 8,),],),);
    }
    ,);
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _sort = selected;
    }
    );
  }
  String _cleanError(Object error,) {
    String message = error.toString();
    if (message.startsWith('Exception: ',)) {
      message = message.substring('Exception: '.length,);
    }
    return message;
  }
  static int? _toInt(dynamic value,) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '',);
  }
}
enum _GroupSort {
  name, members, materials,
}
class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterButton( {
    required this.icon, required this.label, required this.active, required this.onTap,
  }
  );
  @override Widget build(BuildContext context,) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10,), child: Container(padding: const EdgeInsets.symmetric(horizontal:
    11, vertical: 9,), decoration: BoxDecoration(color: active ? AppColors.skyBlue.withValues(alpha: 0.14,) : AppColors.eleganceMidnight,
    borderRadius: BorderRadius.circular(10,), border: Border.all(color: active ? AppColors.skyBlue.withValues(alpha: 0.32,
    ) : AppColors.skyBlue.withValues(alpha: 0.10,),),), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon,
    size: 16, color: active ? AppColors.skyBlue : Colors.white54,), const SizedBox(width: 6,), Text(label, style: TextStyle(color:
    active ? AppColors.pureWhite : AppColors.pureWhite.withValues(alpha: 0.60,), fontSize: 10, fontWeight: active ? FontWeight.w600
    : FontWeight.normal,),), const SizedBox(width: 3,), const Icon(Icons.arrow_drop_down_rounded, size: 17, color: Colors.white38,
    ),],),),);
  }
}
class _PublicGroupCard extends StatelessWidget {
  final StudyGroup group;
  final VoidCallback onTap;
  const _PublicGroupCard( {
    required this.group, required this.onTap,
  }
  );
  @override Widget build(BuildContext context,) {
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18,
    ), child: Container(padding: const EdgeInsets.all(15,), decoration: BoxDecoration(color: AppColors.eleganceMidnight,
    borderRadius: BorderRadius.circular(18,), border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.12,),
    ),), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 40,
    height: 40, decoration: BoxDecoration(color: AppColors.brandNightBlue, borderRadius: BorderRadius.circular(11,
    ),), child: const Icon(Icons.groups_2_outlined, color: AppColors.skyBlue, size: 21,),), const SizedBox(width: 10,
    ), Expanded(child: Text(group.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.pureWhite,
    fontSize: 14, fontWeight: FontWeight.bold,),),), if (group.isOwner) const Icon(Icons.admin_panel_settings_outlined,
    color: AppColors.materialSky, size: 17,),],), const SizedBox(height: 11,), Text(group.description.isEmpty ? 'Nessuna descrizione.'
    : group.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.pureWhite.withValues(alpha:
    0.48,), fontSize: 10, height: 1.35,),), const Spacer(), _GroupInfoRow(icon: Icons.menu_book_outlined, text: group.subject.isEmpty
    ? 'Materia non specificata' : group.subject,), const SizedBox(height: 6,), _GroupInfoRow(icon: Icons.school_outlined,
    text: '${group.department} • ${group.course}',), const SizedBox(height: 10,), Row(children: [_GroupCounter(icon: Icons.people_outline_rounded,
    value: '${group.memberCount}',), const SizedBox(width: 12,), _GroupCounter(icon: Icons.folder_outlined, value: '${group.materialCount}',
    ), const Spacer(), const Icon(Icons.arrow_forward_rounded, color: AppColors.skyBlue, size: 17,),],),],),),),);
  }
}
class _GroupInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GroupInfoRow( {
    required this.icon, required this.text,
  }
  );
  @override Widget build(BuildContext context,) {
    return Row(children: [Icon(icon, size: 14, color: AppColors.materialSky,), const SizedBox(width: 6,), Expanded(child: Text(text,
    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.pureWhite.withValues(alpha: 0.55,
    ), fontSize: 10,),),),],);
  }
}
class _GroupCounter extends StatelessWidget {
  final IconData icon;
  final String value;
  const _GroupCounter( {
    required this.icon, required this.value,
  }
  );
  @override Widget build(BuildContext context,) {
    return Row(children: [Icon(icon, color: Colors.white38, size: 14,), const SizedBox(width: 4,), Text(value, style: const TextStyle(color:
    Colors.white54, fontSize: 9,),),],);
  }
}
class _SortOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SortOption( {
    required this.title, required this.icon, required this.selected, required this.onTap,
  }
  );
  @override Widget build(BuildContext context,) {
    return ListTile(onTap: onTap, leading: Icon(icon, color: AppColors.skyBlue,), title: Text(title, style: const TextStyle(color:
    AppColors.pureWhite,),), trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.skyBlue,) : null,
    );
  }
}
class _PublicGroupsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _PublicGroupsError( {
    required this.message, required this.onRetry,
  }
  );
  @override Widget build(BuildContext context,) {
    return Container(padding: const EdgeInsets.all(18,), decoration: BoxDecoration(color: AppColors.eleganceMidnight,
    borderRadius: BorderRadius.circular(16,),), child: Column(children: [const Icon(Icons.cloud_off_rounded, color: Colors.redAccent,
    size: 34,), const SizedBox(height: 10,), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60,
    fontSize: 11,),), const SizedBox(height: 12,), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded,
    ), label: const Text('Riprova',),),],),);
  }
}
class _EmptyPublicGroups extends StatelessWidget {
  final bool filtered;
  final VoidCallback onReset;
  const _EmptyPublicGroups( {
    required this.filtered, required this.onReset,
  }
  );
  @override Widget build(BuildContext context,) {
    return Container(padding: const EdgeInsets.all(24,), decoration: BoxDecoration(color: AppColors.eleganceMidnight,
    borderRadius: BorderRadius.circular(18,),), child: Column(children: [const Icon(Icons.groups_outlined, color: AppColors.skyBlue,
    size: 38,), const SizedBox(height: 12,), Text(filtered ? 'Nessun gruppo corrisponde alla ricerca.' : 'Non ci sono ancora gruppi pubblici.',
    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.pureWhite, fontSize: 13, fontWeight: FontWeight.w600,
    ),), if (filtered)...[const SizedBox(height: 12,), TextButton.icon(onPressed: onReset, icon: const Icon(Icons.filter_alt_off_outlined,
    ), label: const Text('Rimuovi filtri',),),],],),);
  }
}