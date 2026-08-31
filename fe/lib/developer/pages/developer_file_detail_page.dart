import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

import '../models/developer_models.dart';
import '../theme/developer_ui_style.dart';
import '../widgets/developer_relation_tile.dart';
import '../widgets/developer_status_badges.dart';
import 'developer_function_detail_page.dart';

class DeveloperFileDetailPage
    extends StatefulWidget {
  final DeveloperFileDoc file;
  final String? initialFunctionName;

  const DeveloperFileDetailPage({
    super.key,
    required this.file,
    this.initialFunctionName,
  });

  @override
  State<DeveloperFileDetailPage> createState() =>
      _DeveloperFileDetailPageState();
}

class _DeveloperFileDetailPageState
    extends State<DeveloperFileDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<_FileTabData> _tabs = [
    _FileTabData(
      label: 'Overview',
      icon: Icons.dashboard_outlined,
    ),
    _FileTabData(
      label: 'Functions',
      icon: Icons.functions,
    ),
    _FileTabData(
      label: 'Security',
      icon: Icons.shield_outlined,
    ),
    _FileTabData(
      label: 'Dependencies',
      icon: Icons.account_tree_outlined,
    ),
    _FileTabData(
      label: 'Impact',
      icon: Icons.warning_amber_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
    );

    final String? functionName =
        widget.initialFunctionName;

    if (functionName != null) {
      _tabController.index = 1;

      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        for (final DeveloperFunctionDoc function
            in widget.file.functions) {
          if (function.name ==
                  functionName &&
              mounted) {
            _openFunction(function);
            break;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DeveloperFileDoc file =
        widget.file;

    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor:
            AppColors.brandNightBlue,
        foregroundColor:
            AppColors.pureWhite,
        elevation: 0,
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  DeveloperUiStyle.maxContentWidth,
            ),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    12,
                  ),
                  child: _buildHeader(file),
                ),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller:
                        _tabController,
                    children: [
                      _OverviewTab(
                        file: file,
                      ),
                      _FunctionsTab(
                        file: file,
                        onOpenFunction:
                            _openFunction,
                      ),
                      _SecurityTab(
                        file: file,
                      ),
                      _DependenciesTab(
                        file: file,
                      ),
                      _ImpactTab(
                        file: file,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    DeveloperFileDoc file,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration:
          DeveloperUiStyle.elevatedPanelDecoration(
        borderColor:
            file.securityCritical
                ? Colors.redAccent
                : DeveloperUiStyle.layerColor(
                    file.layer,
                  ),
        radius: 18,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
                  AppColors.brandNightBlue,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: Icon(
              _fileIcon(file),
              color:
                  file.securityCritical
                      ? Colors.redAccent
                      : DeveloperUiStyle
                          .layerColor(
                          file.layer,
                        ),
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  file.path,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:
                        AppColors.pureWhite,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${file.layer} · '
                  '${file.module} · '
                  '${file.language}',
                  style:
                      DeveloperUiStyle.bodyMuted,
                ),
                const SizedBox(height: 10),
                DeveloperStatusBadges(
                  documented:
                      file.documented,
                  outdated:
                      file.outdated,
                  changed:
                      file.changed,
                  securityCritical:
                      file.securityCritical,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      decoration:
          DeveloperUiStyle.panelDecoration(
        radius: 14,
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment:
            TabAlignment.start,
        indicatorSize:
            TabBarIndicatorSize.tab,
        dividerColor:
            Colors.transparent,
        indicator: BoxDecoration(
          color: AppColors.skyBlue
              .withValues(alpha: 0.14),
          borderRadius:
              BorderRadius.circular(11),
          border: Border.all(
            color: AppColors.skyBlue
                .withValues(alpha: 0.20),
          ),
        ),
        labelColor:
            AppColors.pureWhite,
        unselectedLabelColor:
            AppColors.pureWhite
                .withValues(alpha: 0.42),
        labelStyle:
            const TextStyle(
          fontSize: 10,
          fontWeight:
              FontWeight.w600,
        ),
        tabs: _tabs
            .map(
              (_FileTabData tab) =>
                  Tab(
                icon: Icon(
                  tab.icon,
                  size: 16,
                ),
                text: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }

  void _openFunction(
    DeveloperFunctionDoc function,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DeveloperFunctionDetailPage(
          file: widget.file,
          function: function,
        ),
      ),
    );
  }

  IconData _fileIcon(
    DeveloperFileDoc file,
  ) {
    if (file.extension == '.dart') {
      return Icons.flutter_dash_outlined;
    }

    if (file.extension == '.py') {
      return Icons.code_rounded;
    }

    if (file.extension == '.json') {
      return Icons.data_object_rounded;
    }

    return Icons.description_outlined;
  }
}

class _OverviewTab extends StatelessWidget {
  final DeveloperFileDoc file;

  const _OverviewTab({
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return _TabScroll(
      children: [
        _DetailSection(
          icon:
              Icons.info_outline_rounded,
          title: 'Responsabilità',
          accent:
              AppColors.skyBlue,
          child: Text(
            file.description.isEmpty
                ? 'Descrizione automatica '
                    'non ancora disponibile.'
                : file.description,
            style:
                DeveloperUiStyle.bodyMuted,
          ),
        ),
        _DetailSection(
          icon:
              Icons.star_outline_rounded,
          title: 'Importanza',
          accent:
              AppColors.materialSky,
          child: Text(
            file.importance.isEmpty
                ? 'Importanza non ancora '
                    'classificata.'
                : file.importance,
            style:
                DeveloperUiStyle.bodyMuted,
          ),
        ),
        _DetailSection(
          icon:
              Icons.analytics_outlined,
          title: 'Metadata',
          accent:
              AppColors.lavenderBlue,
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _InfoBadge(
                icon:
                    Icons.layers_outlined,
                label: file.layer,
              ),
              _InfoBadge(
                icon:
                    Icons.folder_outlined,
                label: file.module,
              ),
              _InfoBadge(
                icon:
                    Icons.code_rounded,
                label: file.language,
              ),
              _InfoBadge(
                icon:
                    Icons.functions,
                label:
                    '${file.functions.length} funzioni',
              ),
              _InfoBadge(
                icon:
                    Icons.sd_storage_outlined,
                label:
                    '${file.sizeBytes} bytes',
              ),
              _InfoBadge(
                icon:
                    Icons.warning_amber_rounded,
                label:
                    'Risk ${file.risk.name.toUpperCase()}',
                color:
                    DeveloperUiStyle.riskColor(
                  file.risk.name,
                ),
              ),
            ],
          ),
        ),
        if (file.flows.isNotEmpty)
          _DetailSection(
            icon:
                Icons.route_outlined,
            title: 'Flows',
            accent:
                AppColors.socialSky,
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: file.flows
                  .map(
                    (String flow) =>
                        _InfoBadge(
                      icon:
                          Icons
                              .account_tree_outlined,
                      label: flow,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _FunctionsTab
    extends StatelessWidget {
  final DeveloperFileDoc file;
  final ValueChanged<
          DeveloperFunctionDoc>
      onOpenFunction;

  const _FunctionsTab({
    required this.file,
    required this.onOpenFunction,
  });

  @override
  Widget build(BuildContext context) {
    if (file.functions.isEmpty) {
      return const _EmptyTab(
        icon: Icons.functions,
        title:
            'Nessuna funzione indicizzata',
        message:
            'Il file non contiene funzioni riconosciute '
            'oppure l’indicizzatore non le ha ancora analizzate.',
      );
    }

    return ListView.separated(
      padding:
          const EdgeInsets.all(20),
      itemCount:
          file.functions.length,
      separatorBuilder:
          (_, _) =>
              const SizedBox(
        height: 9,
      ),
      itemBuilder: (
        BuildContext context,
        int index,
      ) {
        final DeveloperFunctionDoc function =
            file.functions[index];

        final Color riskColor =
            DeveloperUiStyle.riskColor(
          function.risk.name,
        );

        return InkWell(
          onTap: () =>
              onOpenFunction(function),
          borderRadius:
              BorderRadius.circular(15),
          child: Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                DeveloperUiStyle.panelDecoration(
              borderColor: riskColor,
              radius: 15,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(
                    color: AppColors
                        .brandNightBlue,
                    borderRadius:
                        BorderRadius.circular(
                      11,
                    ),
                  ),
                  child: Icon(
                    Icons.functions,
                    color: riskColor,
                    size: 20,
                  ),
                ),
                const SizedBox(
                  width: 11,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        '${function.name}()',
                        style:
                            const TextStyle(
                          color: AppColors
                              .pureWhite,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        function.signature,
                        maxLines: 3,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            DeveloperUiStyle
                                .bodyMuted,
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _InfoBadge(
                            icon:
                                Icons
                                    .warning_amber_rounded,
                            label:
                                function.risk.name
                                    .toUpperCase(),
                            color:
                                riskColor,
                          ),
                          if (function
                              .isAsync)
                            const _InfoBadge(
                              icon:
                                  Icons
                                      .sync_rounded,
                              label:
                                  'ASYNC',
                              color:
                                  AppColors
                                      .materialSky,
                            ),
                          if (function
                                  .lineStart !=
                              null)
                            _InfoBadge(
                              icon:
                                  Icons
                                      .numbers_rounded,
                              label:
                                  'L${function.lineStart}'
                                  '${function.lineEnd != null ? '–${function.lineEnd}' : ''}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                      Colors.white30,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SecurityTab
    extends StatelessWidget {
  final DeveloperFileDoc file;

  const _SecurityTab({
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    final List<DeveloperFunctionDoc>
        securityFunctions = file.functions
            .where(
              (
                DeveloperFunctionDoc
                    function,
              ) =>
                  function.security
                      .isNotEmpty,
            )
            .toList();

    return _TabScroll(
      children: [
        _DetailSection(
          icon:
              Icons.shield_outlined,
          title: 'Classificazione',
          accent:
              file.securityCritical
                  ? Colors.redAccent
                  : Colors.greenAccent,
          child: Row(
            children: [
              Icon(
                file.securityCritical
                    ? Icons
                        .lock_outline_rounded
                    : Icons
                        .verified_user_outlined,
                color:
                    file.securityCritical
                        ? Colors.redAccent
                        : Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  file.securityCritical
                      ? 'Questo file è classificato '
                          'SECURITY CRITICAL.'
                      : 'Nessun indicatore security-critical '
                          'rilevato per questo file.',
                  style:
                      DeveloperUiStyle.bodyMuted,
                ),
              ),
            ],
          ),
        ),
        if (file.securityNotes.isNotEmpty)
          _DetailSection(
            icon:
                Icons.notes_rounded,
            title: 'Security notes',
            accent:
                Colors.redAccent,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: file.securityNotes
                  .map(
                    (String note) =>
                        Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 7,
                      ),
                      child:
                          _BulletText(
                        text: note,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (securityFunctions.isNotEmpty)
          _DetailSection(
            icon:
                Icons.functions,
            title:
                'Funzioni sensibili',
            accent:
                Colors.orangeAccent,
            child: Column(
              children:
                  securityFunctions
                      .map(
                        (
                          DeveloperFunctionDoc
                              function,
                        ) =>
                            ListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          leading:
                              const Icon(
                            Icons
                                .lock_outline_rounded,
                            color: Colors
                                .orangeAccent,
                          ),
                          title: Text(
                            '${function.name}()',
                            style:
                                DeveloperUiStyle
                                    .bodyStrong,
                          ),
                          subtitle: Text(
                            function.security
                                .join(' · '),
                            style:
                                DeveloperUiStyle
                                    .bodyMuted,
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        if (!file.securityCritical &&
            file.securityNotes.isEmpty &&
            securityFunctions.isEmpty)
          const _EmptySecurityInfo(),
      ],
    );
  }
}

class _DependenciesTab
    extends StatelessWidget {
  final DeveloperFileDoc file;

  const _DependenciesTab({
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return _TabScroll(
      children: [
        if (file.imports.isNotEmpty)
          _DetailSection(
            icon:
                Icons.input_rounded,
            title: 'Imports',
            accent:
                AppColors.lavenderBlue,
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: file.imports
                  .map(
                    (String value) =>
                        _InfoBadge(
                      icon:
                          Icons.link_rounded,
                      label: value,
                    ),
                  )
                  .toList(),
            ),
          ),
        if (file.relations.isNotEmpty)
          _DetailSection(
            icon: Icons
                .account_tree_outlined,
            title: 'Relations',
            accent:
                AppColors.materialSky,
            child: Column(
              children: file.relations
                  .map(
                    (
                      DeveloperRelation
                          relation,
                    ) =>
                        Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 8,
                      ),
                      child:
                          DeveloperRelationTile(
                        relation:
                            relation,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (file.imports.isEmpty &&
            file.relations.isEmpty)
          const _EmptyTab(
            icon:
                Icons.account_tree_outlined,
            title:
                'Nessuna dipendenza indicizzata',
            message:
                'Imports e relazioni verranno mostrate '
                'quando l’indicizzatore le rileverà.',
          ),
      ],
    );
  }
}

class _ImpactTab extends StatelessWidget {
  final DeveloperFileDoc file;

  const _ImpactTab({
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    final int callers = file.functions.fold<int>(
      0,
      (
        int total,
        DeveloperFunctionDoc function,
      ) =>
          total +
          function.calledBy.length,
    );

    final int calls = file.functions.fold<int>(
      0,
      (
        int total,
        DeveloperFunctionDoc function,
      ) =>
          total + function.calls.length,
    );

    final int securityFunctions =
        file.functions
            .where(
              (
                DeveloperFunctionDoc
                    function,
              ) =>
                  function.security
                      .isNotEmpty,
            )
            .length;

    final Color riskColor =
        DeveloperUiStyle.riskColor(
      file.risk.name,
    );

    return _TabScroll(
      children: [
        _DetailSection(
          icon:
              Icons.speed_outlined,
          title: 'Impact summary',
          accent: riskColor,
          child: LayoutBuilder(
            builder: (
              BuildContext context,
              BoxConstraints constraints,
            ) {
              final int columns =
                  constraints.maxWidth >= 650
                      ? 4
                      : 2;

              final List<_ImpactMetricData>
                  metrics = [
                _ImpactMetricData(
                  label:
                      'Functions',
                  value:
                      '${file.functions.length}',
                  icon:
                      Icons.functions,
                ),
                _ImpactMetricData(
                  label:
                      'Calls',
                  value: '$calls',
                  icon:
                      Icons.call_made_rounded,
                ),
                _ImpactMetricData(
                  label:
                      'Called by',
                  value:
                      '$callers',
                  icon:
                      Icons
                          .call_received_rounded,
                ),
                _ImpactMetricData(
                  label:
                      'Security fn',
                  value:
                      '$securityFunctions',
                  icon:
                      Icons
                          .shield_outlined,
                ),
              ];

              return GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                itemCount:
                    metrics.length,
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      columns,
                  crossAxisSpacing:
                      8,
                  mainAxisSpacing: 8,
                  mainAxisExtent:
                      86,
                ),
                itemBuilder: (
                  BuildContext context,
                  int index,
                ) {
                  return _ImpactMetric(
                    data:
                        metrics[index],
                    color:
                        riskColor,
                  );
                },
              );
            },
          ),
        ),
        _DetailSection(
          icon:
              Icons.warning_amber_rounded,
          title: 'Risk',
          accent: riskColor,
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration:
                    BoxDecoration(
                  color: riskColor
                      .withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                  border: Border.all(
                    color: riskColor
                        .withValues(
                      alpha: 0.18,
                    ),
                  ),
                ),
                child: Text(
                  file.risk.name
                      .toUpperCase(),
                  style: TextStyle(
                    color:
                        riskColor,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _riskDescription(
                    file,
                  ),
                  style:
                      DeveloperUiStyle.bodyMuted,
                ),
              ),
            ],
          ),
        ),
        if (file.changed ||
            file.outdated)
          _DetailSection(
            icon:
                Icons.change_circle_outlined,
            title:
                'Modification state',
            accent:
                Colors.amber,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (file.changed)
                  const _BulletText(
                    text:
                        'Git segnala il file come modificato o non tracciato.',
                  ),
                if (file.outdated)
                  const _BulletText(
                    text:
                        'La documentazione associata risulta precedente al sorgente.',
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _riskDescription(
    DeveloperFileDoc file,
  ) {
    switch (file.risk) {
      case DeveloperRiskLevel.critical:
        return 'Modifiche a questo file possono avere '
            'impatto diretto su autenticazione, autorizzazioni, '
            'sicurezza o flussi centrali.';
      case DeveloperRiskLevel.high:
        return 'File ad alto impatto: verificare chiamanti, '
            'contratti API e regressioni prima della modifica.';
      case DeveloperRiskLevel.medium:
        return 'Impatto medio: controllare dipendenze e '
            'funzioni collegate prima di modificare il file.';
      case DeveloperRiskLevel.low:
        return 'Impatto limitato secondo l’indice corrente.';
    }
  }
}

class _TabScroll extends StatelessWidget {
  final List<Widget> children;

  const _TabScroll({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.all(20),
      children: children,
    );
  }
}

class _DetailSection
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final Widget child;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration:
          DeveloperUiStyle.panelDecoration(
        borderColor: accent,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.brandNightBlue,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Text(
                title,
                style:
                    DeveloperUiStyle.bodyStrong,
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _InfoBadge
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.label,
    this.color = AppColors.materialSky,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.08),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color:
              color.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 10,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletText
    extends StatelessWidget {
  final String text;

  const _BulletText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Padding(
            padding:
                EdgeInsets.only(
              top: 5,
            ),
            child: Icon(
              Icons.circle,
              size: 5,
              color:
                  AppColors.materialSky,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style:
                  DeveloperUiStyle.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactMetricData {
  final String label;
  final String value;
  final IconData icon;

  const _ImpactMetricData({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _ImpactMetric
    extends StatelessWidget {
  final _ImpactMetricData data;
  final Color color;

  const _ImpactMetric({
    required this.data,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              color.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            data.icon,
            color: color,
            size: 16,
          ),
          const Spacer(),
          Text(
            data.value,
            style: const TextStyle(
              color:
                  AppColors.pureWhite,
              fontSize: 15,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          Text(
            data.label,
            style: TextStyle(
              color: AppColors
                  .pureWhite
                  .withValues(
                alpha: 0.38,
              ),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints:
              const BoxConstraints(
            maxWidth: 520,
          ),
          padding:
              const EdgeInsets.all(24),
          decoration:
              DeveloperUiStyle.panelDecoration(),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                icon,
                color:
                    Colors.white24,
                size: 42,
              ),
              const SizedBox(
                height: 12,
              ),
              Text(
                title,
                textAlign:
                    TextAlign.center,
                style:
                    DeveloperUiStyle.bodyStrong,
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                message,
                textAlign:
                    TextAlign.center,
                style:
                    DeveloperUiStyle.bodyMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySecurityInfo
    extends StatelessWidget {
  const _EmptySecurityInfo();

  @override
  Widget build(BuildContext context) {
    return const _EmptyTab(
      icon:
          Icons.verified_user_outlined,
      title:
          'Nessun rischio specifico rilevato',
      message:
          'L’indice corrente non segnala funzioni '
          'o note security-critical per questo file.',
    );
  }
}

class _FileTabData {
  final String label;
  final IconData icon;

  const _FileTabData({
    required this.label,
    required this.icon,
  });
}