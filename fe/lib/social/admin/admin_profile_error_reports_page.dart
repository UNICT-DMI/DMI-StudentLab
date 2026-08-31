import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';

const Map<String, String> _categoryLabels = {
  'personal_data': 'Dati personali',
  'biography': 'Biografia',
  'academic_path': 'Percorso accademico',
  'academic_titles': 'Titoli accademici',
  'degree_verification': 'Verifica laurea/titolo',
  'subject': 'Materia',
  'grade_verification': 'Verifica voto',
  'teacher_assignment': 'Insegnamento docente',
  'teacher_verification': 'Verifica docente',
  'availability': 'Disponibilità',
  'news': 'Avvisi',
  'groups': 'Gruppi',
  'materials': 'Materiali',
  'quiz': 'Quiz',
  'tutor': 'Tutor',
  'messages': 'Messaggi',
  'notifications': 'Notifiche',
  'account_security': 'Account e sicurezza',
  'performance': 'Prestazioni e caricamento',
  'other': 'Altro',
};

const List<String> _categoryOrder = [
  'personal_data',
  'biography',
  'academic_path',
  'academic_titles',
  'degree_verification',
  'subject',
  'grade_verification',
  'teacher_assignment',
  'teacher_verification',
  'availability',
  'news',
  'groups',
  'materials',
  'quiz',
  'tutor',
  'messages',
  'notifications',
  'account_security',
  'performance',
  'other',
];

class AdminProfileErrorReportsPage extends StatefulWidget {
  const AdminProfileErrorReportsPage({super.key});

  @override
  State<AdminProfileErrorReportsPage> createState() =>
      _AdminProfileErrorReportsPageState();
}

class _AdminProfileErrorReportsPageState
    extends State<AdminProfileErrorReportsPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<_ErrorReport> _items = [];
  bool _loading = true;
  String? _selectedStatus;
  String? _selectedCategory;
  String _search = '';
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    try {
      final values = await _apiService.getAdminProfileErrorReports(
        status: _selectedStatus,
        category: _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _items = values.map(_ErrorReport.fromJson).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  List<_ErrorReport> get _visibleItems {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where(
          (item) =>
              item.description.toLowerCase().contains(q) ||
              item.categoryLabel.toLowerCase().contains(q) ||
              item.statusLabel.toLowerCase().contains(q) ||
              item.id.toString().contains(q) ||
              item.userId.toString().contains(q),
        )
        .toList();
  }

  int _count(String status) =>
      _items.where((item) => item.status == status).length;

  Future<void> _open(_ErrorReport item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AdminProfileErrorReportDetailPage(item: item),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        title: const Text('Segnalazioni errori'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(),
                      const SizedBox(height: 16),
                      _buildCounters(),
                      const SizedBox(height: 16),
                      _buildFilters(),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 70),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.skyBlue,
                            ),
                          ),
                        )
                      else if (_loadFailed)
                        _GraphicRetry(onRetry: _load)
                      else
                        _buildReports(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCounters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 470
            ? 2
            : 1;
        const gap = 10.0;
        final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _Counter(
              width: w,
              icon: Icons.schedule_rounded,
              value: _count('pending'),
              label: 'In attesa',
              color: Colors.amber,
            ),
            _Counter(
              width: w,
              icon: Icons.manage_search_rounded,
              value: _count('reviewing'),
              label: 'In analisi',
              color: AppColors.skyBlue,
            ),
            _Counter(
              width: w,
              icon: Icons.check_circle_outline_rounded,
              value: _count('resolved'),
              label: 'Risolti',
              color: Colors.greenAccent,
            ),
            _Counter(
              width: w,
              icon: Icons.block_rounded,
              value: _count('rejected'),
              label: 'Rifiutati',
              color: Colors.redAccent,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters() {
    Widget status = DropdownButtonFormField<String?>(
      value: _selectedStatus,
      isExpanded: true,
      dropdownColor: AppColors.eleganceDeepNavy,
      decoration: _decoration('Stato', Icons.tune_rounded),
      items: const [
        DropdownMenuItem(
          value: null,
          child: Text('Tutti', style: TextStyle(color: AppColors.pureWhite)),
        ),
        DropdownMenuItem(
          value: 'pending',
          child: Text(
            'In attesa',
            style: TextStyle(color: AppColors.pureWhite),
          ),
        ),
        DropdownMenuItem(
          value: 'reviewing',
          child: Text(
            'In analisi',
            style: TextStyle(color: AppColors.pureWhite),
          ),
        ),
        DropdownMenuItem(
          value: 'resolved',
          child: Text('Risolti', style: TextStyle(color: AppColors.pureWhite)),
        ),
        DropdownMenuItem(
          value: 'rejected',
          child: Text(
            'Rifiutati',
            style: TextStyle(color: AppColors.pureWhite),
          ),
        ),
      ],
      onChanged: _loading
          ? null
          : (value) {
              setState(() => _selectedStatus = value);
              _load();
            },
    );
    Widget category = DropdownButtonFormField<String?>(
      value: _selectedCategory,
      isExpanded: true,
      dropdownColor: AppColors.eleganceDeepNavy,
      decoration: _decoration('Categoria', Icons.category_outlined),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('Tutte', style: TextStyle(color: AppColors.pureWhite)),
        ),
        ..._categoryOrder.map(
          (value) => DropdownMenuItem(
            value: value,
            child: Text(
              _categoryLabel(value),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.pureWhite),
            ),
          ),
        ),
      ],
      onChanged: _loading
          ? null
          : (value) {
              setState(() => _selectedCategory = value);
              _load();
            },
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.pureWhite.withValues(alpha: .06)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.pureWhite),
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'Cerca per categoria, descrizione o ID',
              hintStyle: TextStyle(
                color: AppColors.pureWhite.withValues(alpha: .35),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.skyBlue,
              ),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppColors.darkElegance,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) => c.maxWidth < 650
                ? Column(
                    children: [status, const SizedBox(height: 10), category],
                  )
                : Row(
                    children: [
                      Expanded(child: status),
                      const SizedBox(width: 10),
                      Expanded(child: category),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: AppColors.pureWhite.withValues(alpha: .55)),
    prefixIcon: Icon(icon, color: AppColors.skyBlue, size: 19),
    filled: true,
    fillColor: AppColors.darkElegance,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide.none,
    ),
  );

  Widget _buildReports() {
    final items = _visibleItems;
    if (items.isEmpty) return const _EmptyState();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        const gap = 12.0;
        final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: w,
                  child: _ReportCard(item: item, onTap: () => _open(item)),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AdminProfileErrorReportDetailPage extends StatefulWidget {
  final _ErrorReport item;
  const _AdminProfileErrorReportDetailPage({required this.item});
  @override
  State<_AdminProfileErrorReportDetailPage> createState() =>
      _AdminProfileErrorReportDetailPageState();
}

class _AdminProfileErrorReportDetailPageState
    extends State<_AdminProfileErrorReportDetailPage> {
  final ApiService _apiService = ApiService();
  late _ErrorReport _item;
  late final TextEditingController _noteController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _noteController = TextEditingController(text: _item.resolutionNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _setStatus(String status) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final value = await _apiService.moderateProfileErrorReport(
        reportId: _item.id,
        status: status,
        resolutionNote: _noteController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _item = _ErrorReport.fromJson(value);
        _noteController.text = _item.resolutionNote;
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        title: const Text('Dettaglio segnalazione'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Summary(item: _item),
                const SizedBox(height: 14),
                _Section(
                  icon: Icons.notes_rounded,
                  title: 'Descrizione',
                  child: SelectableText(
                    _item.description,
                    style: TextStyle(
                      color: AppColors.pureWhite.withValues(alpha: .72),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Section(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Nota amministratore',
                  child: TextField(
                    controller: _noteController,
                    enabled: !_saving,
                    maxLines: 6,
                    maxLength: 5000,
                    style: const TextStyle(color: AppColors.pureWhite),
                    decoration: InputDecoration(
                      hintText: 'Es. corretto nella prossima versione',
                      hintStyle: TextStyle(
                        color: AppColors.pureWhite.withValues(alpha: .3),
                      ),
                      filled: true,
                      fillColor: AppColors.darkElegance,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (_saving)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.skyBlue),
                  )
                else
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (_item.status != 'pending')
                        OutlinedButton.icon(
                          onPressed: () => _setStatus('pending'),
                          icon: const Icon(Icons.schedule_rounded),
                          label: const Text('In attesa'),
                        ),
                      if (_item.status != 'reviewing')
                        OutlinedButton.icon(
                          onPressed: () => _setStatus('reviewing'),
                          icon: const Icon(Icons.manage_search_rounded),
                          label: const Text('In analisi'),
                        ),
                      if (_item.status != 'rejected')
                        OutlinedButton.icon(
                          onPressed: () => _setStatus('rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          icon: const Icon(Icons.block_rounded),
                          label: const Text('Rifiuta'),
                        ),
                      if (_item.status != 'resolved')
                        ElevatedButton.icon(
                          onPressed: () => _setStatus('resolved'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: AppColors.darkElegance,
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Risolto'),
                        ),
                    ],
                  ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorReport {
  final int id;
  final int userId;
  final String category;
  final String description;
  final String status;
  final int? reviewedBy;
  final DateTime? reviewedAt;
  final String resolutionNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const _ErrorReport({
    required this.id,
    required this.userId,
    required this.category,
    required this.description,
    required this.status,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.resolutionNote,
    required this.createdAt,
    required this.updatedAt,
  });
  factory _ErrorReport.fromJson(Map<String, dynamic> j) => _ErrorReport(
    id: _int(j['id']),
    userId: _int(j['user_id']),
    category: j['category']?.toString() ?? 'other',
    description: j['description']?.toString() ?? '',
    status: j['status']?.toString() ?? 'pending',
    reviewedBy: _nullableInt(j['reviewed_by']),
    reviewedAt: _date(j['reviewed_at']),
    resolutionNote: j['resolution_note']?.toString() ?? '',
    createdAt: _date(j['created_at']),
    updatedAt: _date(j['updated_at']),
  );
  String get categoryLabel => _categoryLabel(category);
  String get statusLabel => _statusLabel(status);
  Color get statusColor => _statusColor(status);
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.eleganceMidnight,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: AppColors.skyBlue.withValues(alpha: .12)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.bug_report_outlined, color: AppColors.skyBlue, size: 31),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Errori segnalati',
                style: TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Consulta le segnalazioni inviate dagli utenti e gestiscine lo stato.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Counter extends StatelessWidget {
  final double width;
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  const _Counter({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.eleganceMidnight,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .13)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ReportCard extends StatelessWidget {
  final _ErrorReport item;
  final VoidCallback onTap;
  const _ReportCard({required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.eleganceMidnight,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: item.statusColor.withValues(alpha: .14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _categoryIcon(item.category),
                  color: AppColors.skyBlue,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.categoryLabel,
                    style: const TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _Status(item: item),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 7,
              children: [
                _Chip(
                  icon: Icons.person_outline_rounded,
                  text: 'Utente #${item.userId}',
                ),
                _Chip(icon: Icons.tag_rounded, text: '#${item.id}'),
                _Chip(
                  icon: Icons.schedule_outlined,
                  text: _formatDate(item.createdAt),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Summary extends StatelessWidget {
  final _ErrorReport item;
  const _Summary({required this.item});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.eleganceMidnight,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: item.statusColor.withValues(alpha: .18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _categoryIcon(item.category),
              color: AppColors.skyBlue,
              size: 25,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.categoryLabel,
                    style: const TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Segnalazione #${item.id} · Utente #${item.userId}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
            _Status(item: item),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              icon: Icons.schedule_outlined,
              text: _formatDate(item.createdAt),
            ),
            _Chip(
              icon: Icons.update_rounded,
              text: _formatDate(item.updatedAt),
            ),
            if (item.reviewedBy != null)
              _Chip(
                icon: Icons.admin_panel_settings_outlined,
                text: 'Admin #${item.reviewedBy}',
              ),
          ],
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.eleganceMidnight,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.pureWhite.withValues(alpha: .06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.skyBlue, size: 19),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.pureWhite,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _Status extends StatelessWidget {
  final _ErrorReport item;
  const _Status({required this.item});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: item.statusColor.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: item.statusColor.withValues(alpha: .2)),
    ),
    child: Text(
      item.statusLabel.toUpperCase(),
      style: TextStyle(
        color: item.statusColor,
        fontSize: 8,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.brandNightBlue,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 12),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 54),
    decoration: BoxDecoration(
      color: AppColors.eleganceMidnight,
      borderRadius: BorderRadius.circular(17),
    ),
    child: const Column(
      children: [
        Icon(Icons.task_alt_rounded, color: Colors.greenAccent, size: 38),
        SizedBox(height: 12),
        Text(
          'Nessuna segnalazione',
          style: TextStyle(
            color: AppColors.pureWhite,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _GraphicRetry extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _GraphicRetry({required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 44),
    decoration: BoxDecoration(
      color: AppColors.eleganceMidnight,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.sync_problem_rounded,
          color: Colors.orangeAccent,
          size: 38,
        ),
        const SizedBox(height: 15),
        IconButton.filledTonal(
          tooltip: 'Riprova',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
  );
}

String _categoryLabel(String value) =>
    _categoryLabels[value] ?? _categoryLabels['other']!;
String _statusLabel(String value) {
  switch (value) {
    case 'pending':
      return 'In attesa';
    case 'reviewing':
      return 'In analisi';
    case 'resolved':
      return 'Risolto';
    case 'rejected':
      return 'Rifiutato';
    default:
      return value;
  }
}

Color _statusColor(String value) {
  switch (value) {
    case 'pending':
      return Colors.amber;
    case 'reviewing':
      return AppColors.skyBlue;
    case 'resolved':
      return Colors.greenAccent;
    case 'rejected':
      return Colors.redAccent;
    default:
      return Colors.white54;
  }
}

IconData _categoryIcon(String v) {
  switch (v) {
    case 'personal_data':
      return Icons.badge_outlined;
    case 'biography':
      return Icons.notes_outlined;
    case 'academic_path':
      return Icons.account_balance_outlined;
    case 'academic_titles':
      return Icons.workspace_premium_outlined;
    case 'degree_verification':
      return Icons.verified_outlined;
    case 'subject':
      return Icons.menu_book_outlined;
    case 'grade_verification':
      return Icons.fact_check_outlined;
    case 'teacher_assignment':
      return Icons.cast_for_education_outlined;
    case 'teacher_verification':
      return Icons.school_outlined;
    case 'availability':
      return Icons.event_available_outlined;
    case 'news':
      return Icons.campaign_outlined;
    case 'groups':
      return Icons.groups_2_outlined;
    case 'materials':
      return Icons.folder_copy_outlined;
    case 'quiz':
      return Icons.quiz_outlined;
    case 'tutor':
      return Icons.support_outlined;
    case 'messages':
      return Icons.chat_bubble_outline_rounded;
    case 'notifications':
      return Icons.notifications_none_rounded;
    case 'account_security':
      return Icons.security_outlined;
    case 'performance':
      return Icons.speed_rounded;
    default:
      return Icons.more_horiz_rounded;
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return '—';
  final v = value.toLocal();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(v.day)}/${p(v.month)}/${v.year} ${p(v.hour)}:${p(v.minute)}';
}

int _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
int? _nullableInt(dynamic v) => v == null
    ? null
    : v is int
    ? v
    : int.tryParse(v.toString());
DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString());
