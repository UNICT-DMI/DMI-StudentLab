import 'package:flutter/material.dart';

import 'package:fe/theme/nightTheme.dart';
import '../data/developer_api_repository.dart';
import '../models/developer_models.dart';
import '../theme/developer_ui_style.dart';
import 'developer_explorer_page.dart';
import 'developer_graph_page.dart';
import 'developer_search_page.dart';

class DeveloperDashboardPage extends StatefulWidget {
  final String? authorizedRole;

  const DeveloperDashboardPage({
    super.key,
    this.authorizedRole,
  });

  @override
  State<DeveloperDashboardPage> createState() =>
      _DeveloperDashboardPageState();
}

class _DeveloperDashboardPageState
    extends State<DeveloperDashboardPage> {
  final DeveloperApiRepository _repository =
      const DeveloperApiRepository();

  DeveloperRepositoryStatus? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final DeveloperRepositoryStatus status =
          await _repository.getStatus();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DeveloperRepositoryStatus? status =
        _status;

    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        title: const Text('Developer & System'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna indice',
            onPressed: _loading ? null : _load,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: DeveloperUiStyle.maxContentWidth,
            ),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _buildHeader(status),
                  const SizedBox(height: 20),
                  if (_loading)
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 45),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.skyBlue,
                        ),
                      ),
                    )
                  else if (_error != null)
                    _DeveloperErrorCard(
                      message: _error!,
                      onRetry: _load,
                    )
                  else if (status != null) ...[
                    _buildMetrics(status),
                    const SizedBox(height: 26),
                    const _SectionTitle(
                      title: 'Architettura',
                      subtitle:
                          'Esplora la struttura reale del progetto StudentLab.',
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationGrid(),
                    const SizedBox(height: 26),
                    const _SectionTitle(
                      title: 'Repository',
                      subtitle:
                          'Stato della sorgente attualmente indicizzata.',
                    ),
                    const SizedBox(height: 12),
                    _buildRepositoryCard(status),
                  ],
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    DeveloperRepositoryStatus? status,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration:
          DeveloperUiStyle.elevatedPanelDecoration(
        borderColor: AppColors.materialSky,
        radius: 20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.brandNightBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.developer_mode_rounded,
              color: AppColors.skyBlue,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'StudentLab Architecture',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Repository, funzioni, dipendenze, '
                  'flussi e sicurezza in un unico ambiente tecnico.',
                  style: DeveloperUiStyle.bodyMuted,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (widget.authorizedRole != null)
                      _HeaderBadge(
                        icon: Icons.verified_user_outlined,
                        label: widget.authorizedRole!,
                        color: Colors.greenAccent,
                      ),
                    if (status?.branch != null)
                      _HeaderBadge(
                        icon: Icons.account_tree_outlined,
                        label: status!.branch!,
                        color: AppColors.materialSky,
                      ),
                    if (status != null)
                      _HeaderBadge(
                        icon: status.gitAvailable
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        label: status.gitAvailable
                            ? 'Git connected'
                            : 'Git unavailable',
                        color: status.gitAvailable
                            ? Colors.greenAccent
                            : Colors.amber,
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

  Widget _buildMetrics(
    DeveloperRepositoryStatus status,
  ) {
    final List<_MetricData> metrics = [
      _MetricData(
        icon: Icons.description_outlined,
        value: '${status.filesIndexed}',
        label: 'File',
        color: AppColors.skyBlue,
      ),
      _MetricData(
        icon: Icons.functions,
        value: '${status.functionsIndexed}',
        label: 'Funzioni',
        color: AppColors.materialSky,
      ),
      _MetricData(
        icon: Icons.verified_outlined,
        value: '${status.documentedFiles}',
        label: 'Documentati',
        color: Colors.greenAccent,
      ),
      _MetricData(
        icon: Icons.warning_amber_rounded,
        value: '${status.outdatedFiles}',
        label: 'Outdated',
        color: Colors.amber,
      ),
      _MetricData(
        icon: Icons.change_circle_outlined,
        value: '${status.changedFiles}',
        label: 'Changed',
        color: AppColors.socialSky,
      ),
      _MetricData(
        icon: Icons.lock_outline_rounded,
        value: '${status.securityCriticalFiles}',
        label: 'Security',
        color: Colors.redAccent,
      ),
    ];

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final int columns =
            constraints.maxWidth >= 900
                ? 6
                : constraints.maxWidth >= 620
                    ? 3
                    : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 112,
          ),
          itemBuilder: (
            BuildContext context,
            int index,
          ) {
            final _MetricData metric =
                metrics[index];

            return _MetricCard(
              data: metric,
            );
          },
        );
      },
    );
  }

  Widget _buildNavigationGrid() {
    final List<_NavData> entries = [
      _NavData(
        icon: Icons.folder_copy_outlined,
        title: 'Repository',
        description:
            'Naviga cartelle, file e stato della documentazione.',
        color: AppColors.skyBlue,
        page: const DeveloperExplorerPage(),
      ),
      _NavData(
        icon: Icons.manage_search,
        title: 'Ricerca',
        description:
            'Trova file, funzioni e comportamenti dell’ecosistema.',
        color: AppColors.materialSky,
        page: const DeveloperSearchPage(),
      ),
      _NavData(
        icon: Icons.hub_outlined,
        title: 'Architecture Graph',
        description:
            'Visualizza relazioni tra file, funzioni e dipendenze.',
        color: AppColors.lavenderBlue,
        page: const DeveloperGraphPage(),
      ),
    ];

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final int columns =
            constraints.maxWidth >= 850
                ? 3
                : constraints.maxWidth >= 520
                    ? 2
                    : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 180,
          ),
          itemBuilder: (
            BuildContext context,
            int index,
          ) {
            final _NavData entry =
                entries[index];

            return _DeveloperModuleCard(
              data: entry,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => entry.page,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRepositoryCard(
    DeveloperRepositoryStatus status,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          DeveloperUiStyle.panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandNightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.source_outlined,
              color: AppColors.skyBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  status.repositoryName,
                  style:
                      DeveloperUiStyle.bodyStrong,
                ),
                const SizedBox(height: 4),
                Text(
                  status.repositoryRoot,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DeveloperUiStyle.bodyMuted,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.greenAccent
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'READ-ONLY',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricData({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;

  const _MetricCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          DeveloperUiStyle.panelDecoration(
        borderColor: data.color,
        radius: 14,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            data.icon,
            color: data.color,
            size: 19,
          ),
          const Spacer(),
          Text(
            data.value,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            data.label,
            style: TextStyle(
              color: AppColors.pureWhite
                  .withValues(alpha: 0.42),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Widget page;

  const _NavData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.page,
  });
}

class _DeveloperModuleCard
    extends StatelessWidget {
  final _NavData data;
  final VoidCallback onTap;

  const _DeveloperModuleCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration:
              DeveloperUiStyle.panelDecoration(
            borderColor: data.color,
            radius: 17,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                          AppColors.brandNightBlue,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Icon(
                      data.icon,
                      color: data.color,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white30,
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                data.title,
                style: const TextStyle(
                  color: AppColors.pureWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Text(
                  data.description,
                  style:
                      DeveloperUiStyle.bodyMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeaderBadge({
    required this.icon,
    required this.label,
    required this.color,
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
              color.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: DeveloperUiStyle.sectionTitle,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: DeveloperUiStyle.bodyMuted,
        ),
      ],
    );
  }
}

class _DeveloperErrorCard
    extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _DeveloperErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          DeveloperUiStyle.panelDecoration(
        borderColor: Colors.redAccent,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: DeveloperUiStyle.bodyMuted,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              onRetry();
            },
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text('Riprova'),
          ),
        ],
      ),
    );
  }
}
