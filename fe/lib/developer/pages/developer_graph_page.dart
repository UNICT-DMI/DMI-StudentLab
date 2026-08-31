import 'package:flutter/material.dart';

import 'package:fe/theme/nightTheme.dart';
import '../data/developer_api_repository.dart';
import '../models/developer_models.dart';
import '../theme/developer_ui_style.dart';

class DeveloperGraphPage
    extends StatefulWidget {
  const DeveloperGraphPage({
    super.key,
  });

  @override
  State<DeveloperGraphPage> createState() =>
      _DeveloperGraphPageState();
}

class _DeveloperGraphPageState
    extends State<DeveloperGraphPage> {
  final DeveloperApiRepository _repository =
      const DeveloperApiRepository();

  DeveloperGraphData? _graph;
  bool _loading = true;
  String? _error;
  bool _functionsVisible = true;

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
      final DeveloperGraphData graph =
          await _repository.getGraph();

      if (!mounted) {
        return;
      }

      setState(() {
        _graph = graph;
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
    final DeveloperGraphData? graph =
        _graph;

    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor:
            AppColors.brandNightBlue,
        foregroundColor:
            AppColors.pureWhite,
        elevation: 0,
        title:
            Text('Architecture Graph'),
        actions: [
          IconButton(
            onPressed:
                _loading ? null : _load,
            tooltip: 'Aggiorna grafo',
            icon:
                const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  DeveloperUiStyle.maxContentWidth,
            ),
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          AppColors.skyBlue,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: DeveloperUiStyle.bodyMuted,
                        ),
                      )
                    : ListView(
                        padding:
                            const EdgeInsets.all(
                          20,
                        ),
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.all(
                              16,
                            ),
                            decoration:
                                DeveloperUiStyle
                                    .panelDecoration(
                              borderColor:
                                  AppColors
                                      .lavenderBlue,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration:
                                      BoxDecoration(
                                    color: AppColors
                                        .brandNightBlue,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      12,
                                    ),
                                  ),
                                  child:
                                      const Icon(
                                    Icons.hub_outlined,
                                    color: AppColors
                                        .lavenderBlue,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                       Text(
                                        'Grafo semantico',
                                        style:
                                            DeveloperUiStyle
                                                .bodyStrong,
                                      ),
                                      const SizedBox(
                                        height: 4,
                                      ),
                                      Text(
                                        '${graph!.nodes.length} nodi · '
                                        '${graph.edges.length} relazioni',
                                        style:
                                            DeveloperUiStyle
                                                .bodyMuted,
                                      ),
                                    ],
                                  ),
                                ),
                                FilterChip(
                                  selectedColor:
                                      AppColors
                                          .skyBlue
                                          .withValues(
                                    alpha: 0.14,
                                  ),
                                  backgroundColor:
                                      AppColors
                                          .eleganceDeepNavy,
                                  side: BorderSide(
                                    color: AppColors
                                        .skyBlue
                                        .withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                  label: const Text(
                                    'Funzioni',
                                  ),
                                  selected:
                                      _functionsVisible,
                                  onSelected:
                                      (
                                    bool value,
                                  ) {
                                    setState(() {
                                      _functionsVisible =
                                          value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          ..._buildFileCards(
                            graph,
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFileCards(
    DeveloperGraphData graph,
  ) {
    final List<DeveloperGraphNode> files =
        graph.nodes
            .where(
              (
                DeveloperGraphNode node,
              ) =>
                  node.kind == 'file',
            )
            .toList();

    final Map<String, DeveloperGraphNode>
        nodesById = {
      for (final DeveloperGraphNode node
          in graph.nodes)
        node.id: node,
    };

    return files.map<Widget>(
      (DeveloperGraphNode file) {
        final List<DeveloperGraphEdge>
            outgoing = graph.edges
                .where(
                  (
                    DeveloperGraphEdge edge,
                  ) =>
                      edge.source ==
                      file.id,
                )
                .toList();

        final List<Widget> children =
            <Widget>[];

        for (final DeveloperGraphEdge edge
            in outgoing) {
          final DeveloperGraphNode? target =
              nodesById[edge.target];

          if (target == null) {
            continue;
          }

          if (!_functionsVisible &&
              target.kind ==
                  'function') {
            continue;
          }

          children.add(
            ListTile(
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors
                      .brandNightBlue,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Icon(
                  target.kind ==
                          'function'
                      ? Icons.functions
                      : Icons
                          .description_outlined,
                  color: target
                          .securityCritical
                      ? Colors.redAccent
                      : AppColors
                          .materialSky,
                  size: 17,
                ),
              ),
              title: Text(
                '${edge.label} → ${target.label}',
                style: const TextStyle(
                  color:
                      AppColors.pureWhite,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              subtitle: Text(
                target.path,
                style:
                    DeveloperUiStyle.bodyMuted,
              ),
              trailing:
                  target.securityCritical
                      ? const Icon(
                          Icons
                              .lock_outline_rounded,
                          color:
                              Colors.redAccent,
                          size: 16,
                        )
                      : null,
            ),
          );
        }

        return Container(
          margin:
              const EdgeInsets.only(
            bottom: 10,
          ),
          decoration:
              DeveloperUiStyle.panelDecoration(
            borderColor:
                file.securityCritical
                    ? Colors.redAccent
                    : DeveloperUiStyle
                        .layerColor(
                        file.layer ??
                            '',
                      ),
          ),
          child: Theme(
            data: Theme.of(context)
                .copyWith(
              dividerColor:
                  Colors.transparent,
            ),
            child: ExpansionTile(
              collapsedIconColor:
                  Colors.white38,
              iconColor:
                  AppColors.skyBlue,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      AppColors.brandNightBlue,
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  file.securityCritical
                      ? Icons
                          .shield_outlined
                      : Icons
                          .description_outlined,
                  color:
                      file.securityCritical
                          ? Colors.redAccent
                          : AppColors
                              .skyBlue,
                  size: 19,
                ),
              ),
              title: Text(
                file.path,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  color:
                      AppColors.pureWhite,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              subtitle: Text(
                file.layer ??
                    'Repository',
                style:
                    DeveloperUiStyle.bodyMuted,
              ),
              children: children.isEmpty
                  ? const [
                      ListTile(
                        title: Text(
                          'Nessuna relazione '
                          'diretta visibile.',
                          style: TextStyle(
                            color:
                                Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ]
                  : children,
            ),
          ),
        );
      },
    ).toList();
  }
}
