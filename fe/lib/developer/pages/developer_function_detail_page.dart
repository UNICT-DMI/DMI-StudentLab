import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/nightTheme.dart';

import '../data/developer_api_repository.dart';
import '../models/developer_models.dart';
import '../theme/developer_ui_style.dart';

class DeveloperFunctionDetailPage
    extends StatefulWidget {
  final DeveloperFileDoc file;
  final DeveloperFunctionDoc function;

  const DeveloperFunctionDetailPage({
    super.key,
    required this.file,
    required this.function,
  });

  @override
  State<DeveloperFunctionDetailPage> createState() =>
      _DeveloperFunctionDetailPageState();
}

class _DeveloperFunctionDetailPageState
    extends State<DeveloperFunctionDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<_FunctionTabData> _tabs = [
    _FunctionTabData(
      label: 'Overview',
      icon: Icons.dashboard_outlined,
    ),
    _FunctionTabData(
      label: 'Source',
      icon: Icons.code_rounded,
    ),
    _FunctionTabData(
      label: 'Calls',
      icon: Icons.call_made_rounded,
    ),
    _FunctionTabData(
      label: 'Called By',
      icon: Icons.call_received_rounded,
    ),
    _FunctionTabData(
      label: 'Security',
      icon: Icons.shield_outlined,
    ),
    _FunctionTabData(
      label: 'Flow',
      icon: Icons.account_tree_outlined,
    ),
    _FunctionTabData(
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DeveloperFunctionDoc function =
        widget.function;

    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        title: Text(
          '${function.name}()',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth:
                  DeveloperUiStyle.maxContentWidth,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    12,
                  ),
                  child: _buildHeader(),
                ),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _OverviewTab(
                        file: widget.file,
                        function: function,
                      ),
                      _SourceTab(
                        file: widget.file,
                        function: function,
                      ),
                      _CallsTab(
                        function: function,
                      ),
                      _CalledByTab(
                        function: function,
                      ),
                      _SecurityTab(
                        file: widget.file,
                        function: function,
                      ),
                      _FlowTab(
                        function: function,
                      ),
                      _ImpactTab(
                        file: widget.file,
                        function: function,
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

  Widget _buildHeader() {
    final DeveloperFunctionDoc function =
        widget.function;

    final Color riskColor =
        DeveloperUiStyle.riskColor(
      function.risk.name,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration:
          DeveloperUiStyle.elevatedPanelDecoration(
        borderColor: riskColor,
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
              color: AppColors.brandNightBlue,
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.functions,
              color: riskColor,
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
                  '${function.name}()',
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.file.path,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      DeveloperUiStyle.bodyMuted,
                ),
                const SizedBox(height: 8),
                Text(
                  function.signature,
                  maxLines: 4,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.pureWhite
                        .withValues(alpha: 0.72),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _InfoBadge(
                      icon: Icons
                          .warning_amber_rounded,
                      label:
                          function.risk.name
                              .toUpperCase(),
                      color: riskColor,
                    ),
                    if (function.isAsync)
                      const _InfoBadge(
                        icon:
                            Icons.sync_rounded,
                        label: 'ASYNC',
                        color:
                            AppColors.materialSky,
                      ),
                    if (function.lineStart != null)
                      _InfoBadge(
                        icon:
                            Icons.numbers_rounded,
                        label:
                            'L${function.lineStart}'
                            '${function.lineEnd != null ? '–${function.lineEnd}' : ''}',
                      ),
                    if (function.security
                        .isNotEmpty)
                      const _InfoBadge(
                        icon: Icons
                            .lock_outline_rounded,
                        label: 'SECURITY',
                        color:
                            Colors.redAccent,
                      ),
                  ],
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
      margin: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      decoration:
          DeveloperUiStyle.panelDecoration(
        radius: 14,
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorSize:
            TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
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
        labelColor: AppColors.pureWhite,
        unselectedLabelColor:
            AppColors.pureWhite
                .withValues(alpha: 0.42),
        labelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        tabs: _tabs
            .map(
              (_FunctionTabData tab) =>
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
}

class _OverviewTab extends StatelessWidget {
  final DeveloperFileDoc file;
  final DeveloperFunctionDoc function;

  const _OverviewTab({
    required this.file,
    required this.function,
  });

  @override
  Widget build(BuildContext context) {
    return _TabScroll(
      children: [
        _DetailSection(
          icon: Icons.info_outline_rounded,
          title: 'Responsabilità',
          accent: AppColors.skyBlue,
          child: Text(
            function.description.isEmpty
                ? 'Descrizione semantica non ancora '
                    'disponibile per questa funzione.'
                : function.description,
            style: DeveloperUiStyle.bodyMuted,
          ),
        ),
        _DetailSection(
          icon: Icons.input_rounded,
          title: 'Input',
          accent: AppColors.materialSky,
          child: function.inputs.isEmpty
              ? const _EmptyInline(
                  message:
                      'Nessun input indicizzato.',
                )
              : Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: function.inputs
                      .map(
                        (String value) =>
                            _InfoBadge(
                          icon:
                              Icons.login_rounded,
                          label: value,
                        ),
                      )
                      .toList(),
                ),
        ),
        _DetailSection(
          icon: Icons.output_rounded,
          title: 'Output',
          accent: AppColors.socialSky,
          child: function.outputs.isEmpty
              ? const _EmptyInline(
                  message:
                      'Nessun output indicizzato.',
                )
              : Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: function.outputs
                      .map(
                        (String value) =>
                            _InfoBadge(
                          icon:
                              Icons.logout_rounded,
                          label: value,
                          color:
                              AppColors.socialSky,
                        ),
                      )
                      .toList(),
                ),
        ),
        _DetailSection(
          icon: Icons.analytics_outlined,
          title: 'Metadata',
          accent: AppColors.lavenderBlue,
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _InfoBadge(
                icon: Icons
                    .description_outlined,
                label: file.name,
              ),
              _InfoBadge(
                icon: Icons.layers_outlined,
                label: file.layer,
              ),
              _InfoBadge(
                icon: Icons.folder_outlined,
                label: file.module,
              ),
              if (function.lineStart != null)
                _InfoBadge(
                  icon: Icons.numbers_rounded,
                  label:
                      'Line ${function.lineStart}'
                      '${function.lineEnd != null ? '–${function.lineEnd}' : ''}',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceTab extends StatefulWidget {
  final DeveloperFileDoc file;
  final DeveloperFunctionDoc function;

  const _SourceTab({
    required this.file,
    required this.function,
  });

  @override
  State<_SourceTab> createState() =>
      _SourceTabState();
}

class _SourceTabState
    extends State<_SourceTab> {
  final DeveloperApiRepository _repository =
      const DeveloperApiRepository();

  late Future<DeveloperSourceCode>
      _futureSource;

  @override
  void initState() {
    super.initState();
    _futureSource = _load();
  }

  Future<DeveloperSourceCode> _load() {
    return _repository.getSource(
      path: widget.file.path,
      functionName:
          widget.function.name,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _futureSource = _load();
    });

    await _futureSource;
  }

  Future<void> _copy(
    DeveloperSourceCode source,
  ) async {
    await Clipboard.setData(
      ClipboardData(
        text: source.source,
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Codice sorgente copiato.',
        ),
      ),
    );
  }

  String _numberedSource(
    DeveloperSourceCode source,
  ) {
    final List<String> lines =
        source.source.split('\n');

    final int width =
        source.lineEnd
            .toString()
            .length;

    return List<String>.generate(
      lines.length,
      (int index) {
        final int lineNumber =
            source.lineStart +
                index;

        return '${lineNumber.toString().padLeft(width)} │ '
            '${lines[index]}';
      },
    ).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        DeveloperSourceCode>(
      future: _futureSource,
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DeveloperSourceCode>
            snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _SourceError(
            message:
                snapshot.error.toString(),
            onRetry: _reload,
          );
        }

        final DeveloperSourceCode?
            source = snapshot.data;

        if (source == null) {
          return const _EmptyTab(
            icon: Icons.code_off_rounded,
            title:
                'Sorgente non disponibile',
            message:
                'Il backend non ha restituito '
                'il codice della funzione.',
          );
        }

        return _TabScroll(
          children: [
            _DetailSection(
              icon: Icons.code_rounded,
              title: 'Source',
              accent:
                  AppColors.materialSky,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _InfoBadge(
                        icon: Icons
                            .description_outlined,
                        label:
                            source.path,
                      ),
                      _InfoBadge(
                        icon: Icons
                            .numbers_rounded,
                        label:
                            'L${source.lineStart}'
                            '–${source.lineEnd}',
                      ),
                      _InfoBadge(
                        icon:
                            Icons.code_rounded,
                        label:
                            source.language,
                        color:
                            AppColors.materialSky,
                      ),
                      _InfoBadge(
                        icon: Icons
                            .commit_rounded,
                        label:
                            source.commitSha !=
                                    null
                                ? source
                                    .commitSha!
                                    .substring(
                                      0,
                                      source
                                                  .commitSha!
                                                  .length >
                                              8
                                          ? 8
                                          : source
                                              .commitSha!
                                              .length,
                                    )
                                : 'NO SHA',
                        color:
                            AppColors.lavenderBlue,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          source.symbol ??
                              widget
                                  .function
                                  .name,
                          style:
                              DeveloperUiStyle
                                  .bodyStrong,
                        ),
                      ),
                      IconButton(
                        tooltip:
                            'Copia sorgente',
                        onPressed: () {
                          _copy(
                            source,
                          );
                        },
                        icon: const Icon(
                          Icons
                              .content_copy_rounded,
                          size: 18,
                        ),
                      ),
                      IconButton(
                        tooltip:
                            'Ricarica sorgente',
                        onPressed: () {
                          _reload();
                        },
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Container(
                    width:
                        double.infinity,
                    constraints:
                        const BoxConstraints(
                      minHeight: 160,
                    ),
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),
                    decoration:
                        BoxDecoration(
                      color: AppColors
                          .eleganceDeepNavy,
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                      border:
                          Border.all(
                        color: AppColors
                            .skyBlue
                            .withValues(
                          alpha: 0.10,
                        ),
                      ),
                    ),
                    child:
                        SingleChildScrollView(
                      scrollDirection:
                          Axis.horizontal,
                      child:
                          SelectableText(
                        _numberedSource(
                          source,
                        ),
                        style:
                            TextStyle(
                          color: AppColors
                              .pureWhite
                              .withValues(
                            alpha: 0.88,
                          ),
                          fontSize: 11,
                          height: 1.55,
                          fontFamily:
                              'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _DetailSection(
              icon:
                  Icons.fingerprint_rounded,
              title:
                  'Source identity',
              accent:
                  AppColors.lavenderBlue,
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _InfoBadge(
                    icon: Icons
                        .account_tree_outlined,
                    label:
                        source.repository,
                  ),
                  if (source.branch != null)
                    _InfoBadge(
                      icon: Icons
                          .fork_right_rounded,
                      label:
                          source.branch!,
                    ),
                  _InfoBadge(
                    icon: Icons
                        .tag_rounded,
                    label:
                        source.contentHash
                            .substring(
                              0,
                              source
                                          .contentHash
                                          .length >
                                      12
                                  ? 12
                                  : source
                                      .contentHash
                                      .length,
                            ),
                    color:
                        AppColors.lavenderBlue,
                  ),
                  _InfoBadge(
                    icon: Icons
                        .format_list_numbered_rounded,
                    label:
                        '${source.lineCount} lines',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SourceError extends StatelessWidget {
  final String message;
  final Future<void> Function()
      onRetry;

  const _SourceError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Container(
          constraints:
              const BoxConstraints(
            maxWidth: 520,
          ),
          padding:
              const EdgeInsets.all(20),
          decoration:
              DeveloperUiStyle.panelDecoration(
            borderColor:
                Colors.redAccent,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.code_off_rounded,
                color:
                    Colors.redAccent,
                size: 38,
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                'Source non disponibile',
                style:
                    DeveloperUiStyle
                        .bodyStrong,
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                message,
                textAlign:
                    TextAlign.center,
                style:
                    DeveloperUiStyle
                        .bodyMuted,
              ),
              const SizedBox(
                height: 14,
              ),
              FilledButton.icon(
                onPressed: () {
                  onRetry();
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label:
                    const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallsTab extends StatelessWidget {
  final DeveloperFunctionDoc function;

  const _CallsTab({
    required this.function,
  });

  @override
  Widget build(BuildContext context) {
    if (function.calls.isEmpty) {
      return const _EmptyTab(
        icon: Icons.call_made_rounded,
        title:
            'Nessuna chiamata indicizzata',
        message:
            'L’indicizzatore non ha rilevato funzioni '
            'chiamate direttamente da questo metodo.',
      );
    }

    return _TabScroll(
      children: [
        _DetailSection(
          icon: Icons.call_made_rounded,
          title:
              'Calls (${function.calls.length})',
          accent: AppColors.materialSky,
          child: Column(
            children: function.calls
                .map(
                  (String call) =>
                      _RelationRow(
                    icon:
                        Icons.call_made_rounded,
                    title: call,
                    subtitle:
                        'Chiamata da ${function.name}()',
                    color:
                        AppColors.materialSky,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _CalledByTab extends StatelessWidget {
  final DeveloperFunctionDoc function;

  const _CalledByTab({
    required this.function,
  });

  @override
  Widget build(BuildContext context) {
    if (function.calledBy.isEmpty) {
      return const _EmptyTab(
        icon:
            Icons.call_received_rounded,
        title:
            'Nessun chiamante indicizzato',
        message:
            'Non risultano ancora funzioni collegate '
            'che chiamano direttamente questo metodo.',
      );
    }

    return _TabScroll(
      children: [
        _DetailSection(
          icon:
              Icons.call_received_rounded,
          title:
              'Called By (${function.calledBy.length})',
          accent:
              AppColors.lavenderBlue,
          child: Column(
            children: function.calledBy
                .map(
                  (String caller) =>
                      _RelationRow(
                    icon: Icons
                        .call_received_rounded,
                    title: caller,
                    subtitle:
                        'Dipendenza in ingresso',
                    color:
                        AppColors.lavenderBlue,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ApiTab extends StatefulWidget {
  final DeveloperFileDoc file;
  final DeveloperFunctionDoc function;

  const _ApiTab({
    required this.file,
    required this.function,
  });

  @override
  State<_ApiTab> createState() =>
      _ApiTabState();
}

class _ApiTabState extends State<_ApiTab> {
  final DeveloperApiRepository _repository =
      const DeveloperApiRepository();

  late Future<DeveloperApiContract>
      _futureContract;

  @override
  void initState() {
    super.initState();
    _futureContract = _load();
  }

  Future<DeveloperApiContract> _load() {
    return _repository.getApiContract(
      path: widget.file.path,
      functionName:
          widget.function.name,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _futureContract = _load();
    });

    await _futureContract;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        DeveloperApiContract>(
      future: _futureContract,
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DeveloperApiContract>
            snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _EmptyTab(
            icon: Icons.api_outlined,
            title:
                'API contract unavailable',
            message:
                snapshot.error.toString(),
          );
        }

        final DeveloperApiContract?
            contract = snapshot.data;

        if (contract == null) {
          return const _EmptyTab(
            icon: Icons.api_outlined,
            title:
                'No API contract',
            message:
                'No contract was resolved for '
                'this function.',
          );
        }

        return _TabScroll(
          children: [
            _DetailSection(
              icon: Icons.api_outlined,
              title: 'API contract',
              accent:
                  AppColors.materialSky,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    contract.summary,
                    style:
                        DeveloperUiStyle
                            .bodyMuted,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _InfoBadge(
                        icon: Icons
                            .verified_outlined,
                        label: contract
                            .confidence
                            .toUpperCase(),
                        color:
                            AppColors.skyBlue,
                      ),
                      _InfoBadge(
                        icon: contract
                                .authRequired
                            ? Icons
                                .lock_outline_rounded
                            : Icons
                                .lock_open_outlined,
                        label: contract
                                .authRequired
                            ? 'AUTH REQUIRED'
                            : 'NO AUTH OBSERVED',
                        color: contract
                                .authRequired
                            ? Colors.redAccent
                            : Colors.greenAccent,
                      ),
                      if (contract
                          .securityCritical)
                        const _InfoBadge(
                          icon: Icons
                              .shield_outlined,
                          label:
                              'SECURITY CRITICAL',
                          color:
                              Colors.redAccent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (contract
                .backendEndpoints.isNotEmpty)
              _DetailSection(
                icon:
                    Icons.route_outlined,
                title:
                    'Backend endpoints',
                accent:
                    AppColors.materialSky,
                child: Column(
                  children: contract
                      .backendEndpoints
                      .map(
                        (
                          DeveloperApiEndpointContract
                              endpoint,
                        ) =>
                            _ApiEndpointCard(
                          endpoint:
                              endpoint,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (contract
                .requestSchemas.isNotEmpty)
              _DetailSection(
                icon: Icons
                    .input_outlined,
                title: 'Request schemas',
                accent:
                    AppColors.skyBlue,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: contract
                      .requestSchemas
                      .map(
                        (String value) =>
                            _InfoBadge(
                          icon: Icons
                              .data_object_rounded,
                          label: value,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (contract
                .responseSchemas.isNotEmpty)
              _DetailSection(
                icon: Icons
                    .output_outlined,
                title: 'Response schemas',
                accent:
                    AppColors.lavenderBlue,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: contract
                      .responseSchemas
                      .map(
                        (String value) =>
                            _InfoBadge(
                          icon: Icons
                              .data_object_rounded,
                          label: value,
                          color: AppColors
                              .lavenderBlue,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (contract
                .authDependencies.isNotEmpty)
              _DetailSection(
                icon:
                    Icons.lock_outline_rounded,
                title:
                    'Auth dependencies',
                accent:
                    Colors.redAccent,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: contract
                      .authDependencies
                      .map(
                        (String value) =>
                            _InfoBadge(
                          icon: Icons
                              .shield_outlined,
                          label: value,
                          color:
                              Colors.redAccent,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (contract
                .frontendHttpHints.isNotEmpty)
              _DetailSection(
                icon:
                    Icons.http_outlined,
                title:
                    'Frontend HTTP hints',
                accent:
                    AppColors.skyBlue,
                child: Column(
                  children: contract
                      .frontendHttpHints
                      .map(
                        (
                          DeveloperFrontendHttpHint
                              hint,
                        ) =>
                            _RelationRow(
                          icon:
                              Icons.http_outlined,
                          title:
                              '${hint.method} ${hint.path ?? ''}'
                                  .trim(),
                          subtitle:
                              '${hint.call} · ${hint.confidence}',
                          color:
                              AppColors.skyBlue,
                        ),
                      )
                      .toList(),
                ),
              ),
            Center(
              child: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                ),
                label: const Text(
                  'Refresh contract',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ApiEndpointCard
    extends StatelessWidget {
  final DeveloperApiEndpointContract
      endpoint;

  const _ApiEndpointCard({
    required this.endpoint,
  });

  @override
  Widget build(BuildContext context) {
    final String route = [
      endpoint.method,
      endpoint.path,
    ]
        .where(
          (String? value) =>
              value != null &&
              value.trim().isNotEmpty,
        )
        .join(' ');

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.materialSky
              .withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  route.isEmpty
                      ? endpoint.function
                      : route,
                  style:
                      DeveloperUiStyle
                          .bodyStrong,
                ),
              ),
              _InfoBadge(
                icon: Icons
                    .verified_outlined,
                label: endpoint
                    .confidence
                    .toUpperCase(),
                color:
                    AppColors.materialSky,
              ),
            ],
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            '${endpoint.file} → '
            '${endpoint.function}()',
            style:
                DeveloperUiStyle.bodyMuted,
          ),
          if (endpoint.requestSchema !=
              null) ...[
            const SizedBox(height: 6),
            Text(
              'Request: '
              '${endpoint.requestSchema}',
              style:
                  DeveloperUiStyle
                      .bodyMuted,
            ),
          ],
          if (endpoint.responseSchema !=
              null) ...[
            const SizedBox(height: 4),
            Text(
              'Response: '
              '${endpoint.responseSchema}',
              style:
                  DeveloperUiStyle
                      .bodyMuted,
            ),
          ],
          if (endpoint
              .authDependencies.isNotEmpty) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: endpoint
                  .authDependencies
                  .map(
                    (String value) =>
                        _InfoBadge(
                      icon: Icons
                          .lock_outline_rounded,
                      label: value,
                      color:
                          Colors.redAccent,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SecurityTab extends StatelessWidget {
  final DeveloperFileDoc file;
  final DeveloperFunctionDoc function;

  const _SecurityTab({
    required this.file,
    required this.function,
  });

  @override
  Widget build(BuildContext context) {
    final bool sensitive =
        function.security.isNotEmpty ||
            function.risk ==
                DeveloperRiskLevel.critical ||
            file.securityCritical;

    return _TabScroll(
      children: [
        _DetailSection(
          icon: Icons.shield_outlined,
          title: 'Classificazione',
          accent: sensitive
              ? Colors.redAccent
              : Colors.greenAccent,
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                sensitive
                    ? Icons
                        .lock_outline_rounded
                    : Icons
                        .verified_user_outlined,
                color: sensitive
                    ? Colors.redAccent
                    : Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  sensitive
                      ? 'Questa funzione è coinvolta in '
                          'logica potenzialmente sensibile.'
                      : 'Nessun indicatore di sicurezza '
                          'specifico rilevato.',
                  style:
                      DeveloperUiStyle.bodyMuted,
                ),
              ),
            ],
          ),
        ),
        if (function.security.isNotEmpty)
          _DetailSection(
            icon: Icons
                .security_update_warning_outlined,
            title: 'Security indicators',
            accent: Colors.redAccent,
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: function.security
                  .map(
                    (String value) =>
                        _InfoBadge(
                      icon: Icons
                          .lock_outline_rounded,
                      label: value,
                      color:
                          Colors.redAccent,
                    ),
                  )
                  .toList(),
            ),
          ),
        if (file.securityNotes.isNotEmpty)
          _DetailSection(
            icon: Icons.notes_rounded,
            title:
                'File security notes',
            accent:
                Colors.orangeAccent,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: file.securityNotes
                  .map(
                    (String note) =>
                        _BulletText(
                      text: note,
                      color: Colors
                          .orangeAccent,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _FlowTab extends StatelessWidget {
  final DeveloperFunctionDoc function;

  const _FlowTab({
    required this.function,
  });

  @override
  Widget build(BuildContext context) {
    if (function.flows.isEmpty) {
      return const _EmptyTab(
        icon: Icons.account_tree_outlined,
        title:
            'Nessun flow associato',
        message:
            'Questa funzione non è ancora collegata '
            'a un flow applicativo esplicito.',
      );
    }

    return _TabScroll(
      children: [
        _DetailSection(
          icon:
              Icons.account_tree_outlined,
          title:
              'Part of Flow (${function.flows.length})',
          accent: AppColors.socialSky,
          child: Column(
            children: function.flows
                .map(
                  (String flow) =>
                      _RelationRow(
                    icon:
                        Icons.route_outlined,
                    title: flow,
                    subtitle:
                        'Flow applicativo associato',
                    color:
                        AppColors.socialSky,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _RuntimeTab extends StatefulWidget {
  final DeveloperFileDoc file;
  final DeveloperFunctionDoc function;

  const _RuntimeTab({
    required this.file,
    required this.function,
  });

  @override
  State<_RuntimeTab> createState() =>
      _RuntimeTabState();
}

class _RuntimeTabState
    extends State<_RuntimeTab> {
  final DeveloperApiRepository _repository =
      const DeveloperApiRepository();

  late Future<DeveloperRuntimeRisk>
      _futureRuntime;

  @override
  void initState() {
    super.initState();
    _futureRuntime = _load();
  }

  Future<DeveloperRuntimeRisk> _load() {
    return _repository.getRuntimeRisk(
      path: widget.file.path,
      functionName:
          widget.function.name,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _futureRuntime = _load();
    });

    await _futureRuntime;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        DeveloperRuntimeRisk>(
      future: _futureRuntime,
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DeveloperRuntimeRisk>
            snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _EmptyTab(
            icon:
                Icons.bug_report_outlined,
            title:
                'Runtime analysis unavailable',
            message:
                snapshot.error.toString(),
          );
        }

        final DeveloperRuntimeRisk?
            runtime = snapshot.data;

        if (runtime == null) {
          return const _EmptyTab(
            icon:
                Icons.bug_report_outlined,
            title:
                'No runtime analysis',
            message:
                'No runtime risk information '
                'was resolved.',
          );
        }

        final Color riskColor =
            DeveloperUiStyle.riskColor(
          runtime.risk.name,
        );

        return _TabScroll(
          children: [
            _DetailSection(
              icon:
                  Icons.bug_report_outlined,
              title: 'Runtime risk',
              accent: riskColor,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    runtime.summary,
                    style:
                        DeveloperUiStyle
                            .bodyMuted,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _InfoBadge(
                        icon: Icons
                            .warning_amber_rounded,
                        label: runtime.risk.name
                            .toUpperCase(),
                        color: riskColor,
                      ),
                      if (runtime
                          .securityCritical)
                        const _InfoBadge(
                          icon: Icons
                              .shield_outlined,
                          label:
                              'SECURITY CRITICAL',
                          color:
                              Colors.redAccent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (runtime.findings.isNotEmpty)
              _DetailSection(
                icon: Icons
                    .warning_amber_rounded,
                title: 'Findings',
                accent: riskColor,
                child: Column(
                  children: runtime.findings
                      .map(
                        (
                          DeveloperRuntimeFinding
                              finding,
                        ) =>
                            _RuntimeFindingCard(
                          finding:
                              finding,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (runtime
                .sideEffects.isNotEmpty)
              _DetailSection(
                icon:
                    Icons.bolt_outlined,
                title: 'Side effects',
                accent:
                    AppColors.materialSky,
                child: Column(
                  children: runtime
                      .sideEffects
                      .map(
                        (
                          DeveloperSideEffect
                              effect,
                        ) =>
                            _RelationRow(
                          icon: Icons
                              .bolt_outlined,
                          title:
                              effect.label,
                          subtitle:
                              '${effect.category} · '
                              '${effect.confidence}'
                              '${effect.evidence != null ? ' · ${effect.evidence}' : ''}',
                          color: AppColors
                              .materialSky,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (runtime
                .errorPaths.isNotEmpty)
              _DetailSection(
                icon:
                    Icons.alt_route_outlined,
                title: 'Error paths',
                accent:
                    Colors.orangeAccent,
                child: Column(
                  children: runtime
                      .errorPaths
                      .map(
                        (
                          DeveloperErrorPath
                              path,
                        ) =>
                            _RelationRow(
                          icon: Icons
                              .alt_route_outlined,
                          title:
                              path.code == null
                                  ? path.label
                                  : '${path.code} · ${path.label}',
                          subtitle:
                              '${path.kind} · ${path.confidence}',
                          color: Colors
                              .orangeAccent,
                        ),
                      )
                      .toList(),
                ),
              ),
            Center(
              child: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                ),
                label: const Text(
                  'Refresh runtime analysis',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RuntimeFindingCard
    extends StatelessWidget {
  final DeveloperRuntimeFinding finding;

  const _RuntimeFindingCard({
    required this.finding,
  });

  @override
  Widget build(BuildContext context) {
    final Color color =
        DeveloperUiStyle.riskColor(
      finding.severity,
    );

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              color.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  finding.title,
                  style:
                      DeveloperUiStyle
                          .bodyStrong,
                ),
              ),
              _InfoBadge(
                icon: Icons
                    .warning_amber_rounded,
                label: finding.severity
                    .toUpperCase(),
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            finding.message,
            style:
                DeveloperUiStyle.bodyMuted,
          ),
          if (finding.evidence != null) ...[
            const SizedBox(height: 7),
            Text(
              'Evidence: ${finding.evidence}',
              style: TextStyle(
                color:
                    AppColors.skyBlue,
                fontSize: 10,
              ),
            ),
          ],
          if (finding.recommendation !=
              null) ...[
            const SizedBox(height: 7),
            Text(
              'Recommendation: '
              '${finding.recommendation}',
              style:
                  DeveloperUiStyle.bodyMuted,
            ),
          ],
          const SizedBox(height: 7),
          _InfoBadge(
            icon:
                Icons.verified_outlined,
            label: finding.confidence
                .toUpperCase(),
            color:
                AppColors.lavenderBlue,
          ),
        ],
      ),
    );
  }
}

class _ImpactTab extends StatefulWidget {
  final DeveloperFileDoc file;
  final DeveloperFunctionDoc function;

  const _ImpactTab({
    required this.file,
    required this.function,
  });

  @override
  State<_ImpactTab> createState() =>
      _ImpactTabState();
}

class _ImpactTabState
    extends State<_ImpactTab> {
  final DeveloperApiRepository _repository =
      const DeveloperApiRepository();

  late Future<DeveloperImpactAnalysis>
      _futureImpact;

  @override
  void initState() {
    super.initState();
    _futureImpact = _load();
  }

  Future<DeveloperImpactAnalysis>
      _load() {
    return _repository.getImpact(
      path: widget.file.path,
      functionName:
          widget.function.name,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _futureImpact = _load();
    });

    await _futureImpact;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        DeveloperImpactAnalysis>(
      future: _futureImpact,
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DeveloperImpactAnalysis>
            snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _ImpactError(
            message:
                snapshot.error.toString(),
            onRetry: _reload,
          );
        }

        final DeveloperImpactAnalysis?
            impact = snapshot.data;

        if (impact == null) {
          return const _EmptyTab(
            icon:
                Icons.warning_amber_rounded,
            title:
                'Impact non disponibile',
            message:
                'Il backend non ha restituito '
                'un’analisi di impatto.',
          );
        }

        final Color riskColor =
            DeveloperUiStyle.riskColor(
          impact.risk.name,
        );

        return _TabScroll(
          children: [
            _DetailSection(
              icon:
                  Icons.auto_awesome_outlined,
              title:
                  'What should change together?',
              accent: riskColor,
              child: Text(
                impact.semanticAnswer,
                style:
                    DeveloperUiStyle.bodyMuted,
              ),
            ),
            _DetailSection(
              icon:
                  Icons.speed_outlined,
              title: 'Impact summary',
              accent: riskColor,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    impact.summary,
                    style:
                        DeveloperUiStyle.bodyMuted,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      final int columns =
                          constraints.maxWidth >=
                                  650
                              ? 4
                              : 2;

                      final List<
                              _ImpactMetricData>
                          metrics = [
                        _ImpactMetricData(
                          label:
                              'Callers',
                          value:
                              '${impact.directCallers.length}',
                          icon: Icons
                              .call_received_rounded,
                        ),
                        _ImpactMetricData(
                          label:
                              'Flows',
                          value:
                              '${impact.flows.length}',
                          icon:
                              Icons.route_outlined,
                        ),
                        _ImpactMetricData(
                          label:
                              'Endpoints',
                          value:
                              '${impact.endpoints.length}',
                          icon:
                              Icons.api_outlined,
                        ),
                        _ImpactMetricData(
                          label:
                              'Tests',
                          value:
                              '${impact.tests.length}',
                          icon: Icons
                              .science_outlined,
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
                          mainAxisSpacing:
                              8,
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
                ],
              ),
            ),
            if (impact.recommendations
                .isNotEmpty)
              _DetailSection(
                icon:
                    Icons.rule_folder_outlined,
                title: 'Modify together',
                accent:
                    AppColors.skyBlue,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: impact
                      .recommendations
                      .map(
                        (String item) =>
                            _ImpactRecommendation(
                          text: item,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (impact.endpoints.isNotEmpty)
              _DetailSection(
                icon: Icons.api_outlined,
                title:
                    'Affected endpoints',
                accent:
                    AppColors.materialSky,
                child: Column(
                  children: impact.endpoints
                      .map(
                        (
                          DeveloperImpactEndpoint
                              endpoint,
                        ) =>
                            _RelationRow(
                          icon:
                              Icons.api_outlined,
                          title:
                              '${endpoint.function}()',
                          subtitle:
                              '${endpoint.file} · ${endpoint.confidence}',
                          color: AppColors
                              .materialSky,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (impact.models.isNotEmpty)
              _DetailSection(
                icon:
                    Icons.storage_outlined,
                title: 'DB models',
                accent:
                    AppColors.lavenderBlue,
                child: Column(
                  children: impact.models
                      .map(
                        (
                          DeveloperImpactModelRef
                              model,
                        ) =>
                            _RelationRow(
                          icon: Icons
                              .storage_outlined,
                          title: model.name,
                          subtitle:
                              '${model.file} · ${model.confidence}',
                          color: AppColors
                              .lavenderBlue,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (impact.tests.isNotEmpty)
              _DetailSection(
                icon:
                    Icons.science_outlined,
                title: 'Related tests',
                accent:
                    Colors.greenAccent,
                child: Column(
                  children: impact.tests
                      .map(
                        (
                          DeveloperImpactTestRef
                              test,
                        ) =>
                            _RelationRow(
                          icon: Icons
                              .science_outlined,
                          title: test.file,
                          subtitle:
                              '${test.confidence} · ${test.reason}',
                          color: Colors
                              .greenAccent,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (impact.flows.isNotEmpty)
              _DetailSection(
                icon:
                    Icons.route_outlined,
                title: 'Affected flows',
                accent:
                    AppColors.socialSky,
                child: Column(
                  children: impact.flows
                      .map(
                        (
                          DeveloperImpactFlow
                              flow,
                        ) =>
                            _RelationRow(
                          icon: Icons
                              .account_tree_outlined,
                          title: flow.name,
                          subtitle:
                              '${flow.risk.name.toUpperCase()} · '
                              'step ${flow.matchedSteps.join(', ')}',
                          color:
                              DeveloperUiStyle
                                  .riskColor(
                            flow.risk.name,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (impact
                .directCallers.isNotEmpty)
              _DetailSection(
                icon: Icons
                    .call_received_rounded,
                title: 'Direct callers',
                accent:
                    AppColors.lavenderBlue,
                child: Column(
                  children: impact
                      .directCallers
                      .map(
                        (
                          DeveloperImpactFunctionRef
                              item,
                        ) =>
                            _RelationRow(
                          icon: Icons
                              .call_received_rounded,
                          title:
                              '${item.function}()',
                          subtitle:
                              item.file,
                          color:
                              DeveloperUiStyle
                                  .riskColor(
                            item.risk.name,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (impact
                .directCallees.isNotEmpty)
              _DetailSection(
                icon:
                    Icons.call_made_rounded,
                title:
                    'Outgoing dependencies',
                accent:
                    AppColors.materialSky,
                child: Column(
                  children: impact
                      .directCallees
                      .map(
                        (
                          DeveloperImpactFunctionRef
                              item,
                        ) =>
                            _RelationRow(
                          icon: Icons
                              .call_made_rounded,
                          title:
                              '${item.function}()',
                          subtitle:
                              item.file,
                          color:
                              DeveloperUiStyle
                                  .riskColor(
                            item.risk.name,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (impact
                .transitiveCallers
                .isNotEmpty)
              _DetailSection(
                icon: Icons.hub_outlined,
                title:
                    'Transitive callers',
                accent:
                    AppColors.skyBlue,
                child: Column(
                  children: impact
                      .transitiveCallers
                      .map(
                        (
                          DeveloperImpactFunctionRef
                              item,
                        ) =>
                            _RelationRow(
                          icon:
                              Icons.hub_outlined,
                          title:
                              '${item.function}()',
                          subtitle:
                              '${item.file}'
                              '${item.depth != null ? ' · depth ${item.depth}' : ''}',
                          color:
                              DeveloperUiStyle
                                  .riskColor(
                            item.risk.name,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (impact
                .relatedFiles.isNotEmpty)
              _DetailSection(
                icon: Icons
                    .description_outlined,
                title: 'Related files',
                accent:
                    AppColors.materialSky,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: impact
                      .relatedFiles
                      .map(
                        (String path) =>
                            _InfoBadge(
                          icon: Icons
                              .description_outlined,
                          label: path,
                        ),
                      )
                      .toList(),
                ),
              ),
            if (impact
                .securityFlags.isNotEmpty)
              _DetailSection(
                icon:
                    Icons.shield_outlined,
                title:
                    'Security exposure',
                accent:
                    Colors.redAccent,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: impact
                      .securityFlags
                      .map(
                        (String flag) =>
                            _InfoBadge(
                          icon: Icons
                              .lock_outline_rounded,
                          label: flag,
                          color:
                              Colors.redAccent,
                        ),
                      )
                      .toList(),
                ),
              ),
            Center(
              child: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                ),
                label: const Text(
                  'Recalculate impact',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ImpactRecommendation
    extends StatelessWidget {
  final String text;

  const _ImpactRecommendation({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Padding(
            padding:
                EdgeInsets.only(
              top: 3,
            ),
            child: Icon(
              Icons
                  .check_circle_outline_rounded,
              color:
                  AppColors.skyBlue,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
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

class _ImpactError extends StatelessWidget {
  final String message;
  final Future<void> Function()
      onRetry;

  const _ImpactError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Container(
          constraints:
              const BoxConstraints(
            maxWidth: 520,
          ),
          padding:
              const EdgeInsets.all(20),
          decoration:
              DeveloperUiStyle.panelDecoration(
            borderColor:
                Colors.redAccent,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .error_outline_rounded,
                color:
                    Colors.redAccent,
                size: 38,
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                'Impact analysis unavailable',
                style:
                    DeveloperUiStyle
                        .bodyStrong,
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                message,
                textAlign:
                    TextAlign.center,
                style:
                    DeveloperUiStyle
                        .bodyMuted,
              ),
              const SizedBox(
                height: 14,
              ),
              FilledButton.icon(
                onPressed: () {
                  onRetry();
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label:
                    const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.all(20),
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
          const EdgeInsets.only(bottom: 12),
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
                decoration: BoxDecoration(
                  color:
                      AppColors.brandNightBlue,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style:
                      DeveloperUiStyle.bodyStrong,
                ),
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

class _InfoBadge extends StatelessWidget {
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

class _RelationRow
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _RelationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.all(11),
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
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  AppColors.brandNightBlue,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      DeveloperUiStyle.bodyStrong,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style:
                      DeveloperUiStyle.bodyMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;
  final Color color;

  const _BulletText({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 5,
              color: color,
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
              color: AppColors.pureWhite,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            data.label,
            style: TextStyle(
              color: AppColors.pureWhite
                  .withValues(alpha: 0.38),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInline
    extends StatelessWidget {
  final String message;

  const _EmptyInline({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style:
          DeveloperUiStyle.bodyMuted,
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
                color: Colors.white24,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign:
                    TextAlign.center,
                style:
                    DeveloperUiStyle.bodyStrong,
              ),
              const SizedBox(height: 6),
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

class _FunctionTabData {
  final String label;
  final IconData icon;

  const _FunctionTabData({
    required this.label,
    required this.icon,
  });
}
