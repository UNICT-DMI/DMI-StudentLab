import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

import '../data/developer_api_repository.dart';
import '../models/developer_models.dart';
import '../theme/developer_ui_style.dart';

class DeveloperFlowsPage extends StatefulWidget {
  const DeveloperFlowsPage({
    super.key,
  });

  @override
  State<DeveloperFlowsPage> createState() =>
      _DeveloperFlowsPageState();
}

class _DeveloperFlowsPageState
    extends State<DeveloperFlowsPage> {
  final DeveloperApiRepository _repository =
      const DeveloperApiRepository();

  late Future<List<DeveloperFlowDoc>>
      _futureFlows;

  @override
  void initState() {
    super.initState();

    _futureFlows =
        _repository.getFlows();
  }

  Future<void> _reload() async {
    setState(() {
      _futureFlows =
          _repository.getFlows();
    });

    await _futureFlows;
  }

  @override
  Widget build(BuildContext context) {
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
            const Text('Application Flows'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: () {
              _reload();
            },
            icon: const Icon(
              Icons.refresh_rounded,
            ),
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
            child: FutureBuilder<
                List<DeveloperFlowDoc>>(
              future: _futureFlows,
              builder: (
                BuildContext context,
                AsyncSnapshot<
                        List<DeveloperFlowDoc>>
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
                  return _ErrorState(
                    message:
                        snapshot.error.toString(),
                    onRetry: _reload,
                  );
                }

                final List<DeveloperFlowDoc>
                    flows =
                    snapshot.data ??
                        const [];

                if (flows.isEmpty) {
                  return const _EmptyState();
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.all(20),
                    children: [
                      _Header(
                        flows: flows,
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      ...flows.map(
                        (
                          DeveloperFlowDoc flow,
                        ) =>
                            Padding(
                          padding:
                              const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child:
                              _FlowCard(
                            flow: flow,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final List<DeveloperFlowDoc> flows;

  const _Header({
    required this.flows,
  });

  @override
  Widget build(BuildContext context) {
    final int totalSteps =
        flows.fold<int>(
      0,
      (
        int total,
        DeveloperFlowDoc flow,
      ) =>
          total +
          flow.steps.length,
    );

    final int criticalFlows =
        flows.where(
      (DeveloperFlowDoc flow) =>
          flow.risk ==
          DeveloperRiskLevel.critical,
    ).length;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          DeveloperUiStyle.elevatedPanelDecoration(
        borderColor:
            AppColors.skyBlue,
        radius: 18,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.brandNightBlue,
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: const Icon(
                  Icons
                      .account_tree_outlined,
                  color:
                      AppColors.skyBlue,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Application Flows',
                      style: TextStyle(
                        color:
                            AppColors.pureWhite,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Percorsi reali risolti '
                      'sull’indice della repository.',
                      style:
                          DeveloperUiStyle.bodyMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _Badge(
                icon:
                    Icons.route_outlined,
                label:
                    '${flows.length} flows',
                color:
                    AppColors.skyBlue,
              ),
              _Badge(
                icon:
                    Icons.linear_scale_rounded,
                label:
                    '$totalSteps steps',
                color:
                    AppColors.materialSky,
              ),
              if (criticalFlows > 0)
                _Badge(
                  icon:
                      Icons
                          .shield_outlined,
                  label:
                      '$criticalFlows critical',
                  color:
                      Colors.redAccent,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  final DeveloperFlowDoc flow;

  const _FlowCard({
    required this.flow,
  });

  @override
  Widget build(BuildContext context) {
    final Color riskColor =
        DeveloperUiStyle.riskColor(
      flow.risk.name,
    );

    return Container(
      decoration:
          DeveloperUiStyle.panelDecoration(
        borderColor: riskColor,
        radius: 17,
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        iconColor: riskColor,
        collapsedIconColor:
            AppColors.pureWhite
                .withValues(alpha: 0.36),
        shape: const Border(),
        collapsedShape:
            const Border(),
        leading: Container(
          width: 40,
          height: 40,
          decoration:
              BoxDecoration(
            color:
                AppColors.brandNightBlue,
            borderRadius:
                BorderRadius.circular(
              11,
            ),
          ),
          child: Icon(
            Icons.route_outlined,
            color: riskColor,
            size: 20,
          ),
        ),
        title: Text(
          flow.name,
          style: const TextStyle(
            color:
                AppColors.pureWhite,
            fontSize: 13,
            fontWeight:
                FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(
            top: 4,
          ),
          child: Text(
            '${flow.steps.length} step risolti',
            style:
                DeveloperUiStyle.bodyMuted,
          ),
        ),
        trailing: _Badge(
          icon:
              Icons.warning_amber_rounded,
          label:
              flow.risk.name.toUpperCase(),
          color: riskColor,
        ),
        children: [
          Align(
            alignment:
                Alignment.centerLeft,
            child: Text(
              flow.description,
              style:
                  DeveloperUiStyle.bodyMuted,
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          if (flow.steps.isEmpty)
            const _NoResolvedSteps()
          else
            ...List.generate(
              flow.steps.length,
              (int index) {
                final DeveloperFlowStep step =
                    flow.steps[index];

                return _FlowStepTile(
                  step: step,
                  isLast:
                      index ==
                      flow.steps.length - 1,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FlowStepTile
    extends StatelessWidget {
  final DeveloperFlowStep step;
  final bool isLast;

  const _FlowStepTile({
    required this.step,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent =
        step.securityCritical
            ? Colors.redAccent
            : DeveloperUiStyle
                .layerColor(
                step.layer,
              );

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment:
                    Alignment.center,
                decoration:
                    BoxDecoration(
                  color: accent
                      .withValues(
                    alpha: 0.10,
                  ),
                  shape:
                      BoxShape.circle,
                  border:
                      Border.all(
                    color: accent
                        .withValues(
                      alpha: 0.25,
                    ),
                  ),
                ),
                child: Text(
                  '${step.order}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 58,
                  color: accent
                      .withValues(
                    alpha: 0.20,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(
          width: 9,
        ),
        Expanded(
          child: Container(
            margin:
                const EdgeInsets.only(
              bottom: 10,
            ),
            padding:
                const EdgeInsets.all(
              12,
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
                color: accent
                    .withValues(
                  alpha: 0.10,
                ),
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
                        step.title,
                        style:
                            DeveloperUiStyle
                                .bodyStrong,
                      ),
                    ),
                    _Badge(
                      icon:
                          Icons
                              .arrow_forward_rounded,
                      label:
                          step.relation,
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(
                  height: 6,
                ),
                Text(
                  step.file,
                  style: TextStyle(
                    color:
                        AppColors.skyBlue
                            .withValues(
                      alpha: 0.82,
                    ),
                    fontSize: 10,
                    height: 1.25,
                  ),
                ),
                if (step.function != null &&
                    step.function!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    '${step.function}()',
                    style: TextStyle(
                      color: AppColors
                          .pureWhite
                          .withValues(
                        alpha: 0.72,
                      ),
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(
                  height: 7,
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Badge(
                      icon:
                          Icons.layers_outlined,
                      label:
                          step.layer,
                      color: DeveloperUiStyle
                          .layerColor(
                        step.layer,
                      ),
                    ),
                    if (step.securityCritical)
                      const _Badge(
                        icon: Icons
                            .lock_outline_rounded,
                        label:
                            'SECURITY',
                        color:
                            Colors.redAccent,
                      ),
                  ],
                ),
                if (step.context
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    step.context,
                    style:
                        DeveloperUiStyle
                            .bodyMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.08),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color:
              color.withValues(alpha: 0.14),
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
          const SizedBox(
            width: 4,
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResolvedSteps
    extends StatelessWidget {
  const _NoResolvedSteps();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Text(
        'Nessuno step del flow è stato '
        'risolto nell’indice corrente.',
        style:
            DeveloperUiStyle.bodyMuted,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function()
      onRetry;

  const _ErrorState({
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
                'Impossibile caricare i flow',
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Text(
          'Nessun flow disponibile.',
          style:
              DeveloperUiStyle.bodyMuted,
        ),
      ),
    );
  }
}