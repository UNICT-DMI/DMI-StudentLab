import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';

import '../social_models.dart';


class _AssignmentFilter {
  final String value;

  final String label;

  const _AssignmentFilter({
    required this.value,
    required this.label,
  });
}


const List<_AssignmentFilter> _assignmentFilters = [
  _AssignmentFilter(
    value: 'pending',
    label: 'In attesa',
  ),
  _AssignmentFilter(
    value: 'verified',
    label: 'Verificate',
  ),
  _AssignmentFilter(
    value: 'rejected',
    label: 'Rifiutate',
  ),
  _AssignmentFilter(
    value: 'all',
    label: 'Tutte',
  ),
];


class AdminTeacherAssignmentsPage
    extends StatefulWidget {
  const AdminTeacherAssignmentsPage({
    super.key,
  });

  @override
  State<AdminTeacherAssignmentsPage> createState() =>
      _AdminTeacherAssignmentsPageState();
}


class _AdminTeacherAssignmentsPageState
    extends State<AdminTeacherAssignmentsPage> {
  final ApiService _apiService =
      ApiService();

  List<TeacherAssignment> _assignments =
      [];

  final Set<int> _processingIds =
      {};

  String _status =
      'pending';

  bool _loading =
      true;

  bool _refreshing =
      false;

  String? _error;


  @override
  void initState() {
    super.initState();

    _loadAssignments();
  }


  Future<void> _loadAssignments({
    bool refresh = false,
  }) async {
    if (refresh) {
      if (_refreshing) {
        return;
      }

      setState(() {
        _refreshing =
            true;
      });
    } else {
      setState(() {
        _loading =
            true;

        _error =
            null;
      });
    }

    try {
      final List<TeacherAssignment> assignments =
          await _apiService
              .getAdminTeacherAssignments(
        status:
            _status,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _assignments =
            assignments;

        _error =
            null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _cleanError(
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading =
              false;

          _refreshing =
              false;
        });
      }
    }
  }


  Future<void> _changeFilter(
    String value,
  ) async {
    if (value == _status) {
      return;
    }

    setState(() {
      _status =
          value;
    });

    await _loadAssignments();
  }


  Future<void> _verify(
    TeacherAssignment assignment,
  ) async {
    await _applyStatus(
      assignment:
          assignment,

      status:
          'verified',

      title:
          'Verifica insegnamento',

      message:
          'Vuoi verificare l\'insegnamento "${assignment.subject.name}" '
          'di ${_teacherLabel(assignment)}?',

      confirmLabel:
          'Verifica',

      confirmColor:
          Colors.greenAccent,

      successMessage:
          'Insegnamento verificato.',
    );
  }


  Future<void> _reject(
    TeacherAssignment assignment,
  ) async {
    await _applyStatus(
      assignment:
          assignment,

      status:
          'rejected',

      title:
          'Rifiuta insegnamento',

      message:
          'Vuoi rifiutare l\'insegnamento "${assignment.subject.name}" '
          'di ${_teacherLabel(assignment)}?',

      confirmLabel:
          'Rifiuta',

      confirmColor:
          Colors.redAccent,

      successMessage:
          'Insegnamento rifiutato.',
    );
  }


  Future<void> _reopen(
    TeacherAssignment assignment,
  ) async {
    await _applyStatus(
      assignment:
          assignment,

      status:
          'pending',

      title:
          'Rimetti in attesa',

      message:
          'Vuoi rimettere in attesa l\'insegnamento "${assignment.subject.name}" '
          'di ${_teacherLabel(assignment)}?',

      confirmLabel:
          'Rimetti in attesa',

      confirmColor:
          Colors.amber,

      successMessage:
          'Insegnamento rimesso in attesa.',
    );
  }


  Future<void> _applyStatus({
    required TeacherAssignment assignment,
    required String status,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required String successMessage,
  }) async {
    if (
      _processingIds.contains(
        assignment.id,
      )
    ) {
      return;
    }

    final bool? confirmed =
        await _confirm(
      title:
          title,

      message:
          message,

      confirmLabel:
          confirmLabel,

      confirmColor:
          confirmColor,
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _processingIds.add(
        assignment.id,
      );
    });

    try {
      await _apiService
          .setTeacherAssignmentStatus(
        assignmentId:
            assignment.id,

        status:
            status,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        successMessage,
      );

      await _loadAssignments(
        refresh:
            true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(
          e,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingIds.remove(
            assignment.id,
          );
        });
      }
    }
  }


  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context:
          context,

      builder:
          (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              AppColors.eleganceDeepNavy,

          title:
              Text(
            title,

            style:
                const TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),

          content:
              Text(
            message,

            style:
                const TextStyle(
              color:
                  Colors.white70,

              height:
                  1.45,
            ),
          ),

          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
                  const Text(
                'Annulla',
              ),
            ),

            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
                  Text(
                confirmLabel,

                style:
                    TextStyle(
                  color:
                      confirmColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  String _teacherLabel(
    TeacherAssignment assignment,
  ) {
    final String? name =
        assignment.teacherName;

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return 'Docente #${assignment.userId}';
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,

      appBar:
          AppBar(
        backgroundColor:
            AppColors.brandNightBlue,

        foregroundColor:
            AppColors.pureWhite,

        elevation:
            0,

        title:
            const Text(
          'Verifica insegnamenti',

          style:
              TextStyle(
            fontSize:
                18,

            fontWeight:
                FontWeight.w500,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
                'Aggiorna',

            onPressed:
                _refreshing
                    ? null
                    : () {
                        _loadAssignments(
                          refresh:
                              true,
                        );
                      },

            icon:
                _refreshing
                    ? const SizedBox(
                        width:
                            19,

                        height:
                            19,

                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,

                          color:
                              AppColors.pureWhite,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                      ),
          ),
        ],
      ),

      body:
          SafeArea(
        child:
            Center(
          child:
              ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  900,
            ),

            child:
                Column(
              children: [
                _buildFilterBar(),

                Expanded(
                  child:
                      _buildBody(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildFilterBar() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        4,
      ),

      child:
          SingleChildScrollView(
        scrollDirection:
            Axis.horizontal,

        child:
            Row(
          children:
              _assignmentFilters.map(
            (
              _AssignmentFilter filter,
            ) {
              final bool selected =
                  filter.value == _status;

              return Padding(
                padding:
                    const EdgeInsets.only(
                  right:
                      8,
                ),

                child:
                    ChoiceChip(
                  label:
                      Text(
                    filter.label,
                  ),

                  selected:
                      selected,

                  onSelected:
                      (_) {
                    _changeFilter(
                      filter.value,
                    );
                  },

                  backgroundColor:
                      AppColors.eleganceMidnight,

                  selectedColor:
                      AppColors.teacherIndigo
                          .withValues(alpha: 0.35),

                  labelStyle:
                      TextStyle(
                    color:
                        selected
                            ? AppColors.pureWhite
                            : AppColors.pureWhite
                                .withValues(alpha: 0.60),

                    fontSize:
                        12,

                    fontWeight:
                        FontWeight.w600,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),

                    side:
                        BorderSide(
                      color:
                          AppColors.teacherIndigo
                              .withValues(alpha: 0.22),
                    ),
                  ),
                ),
              );
            },
          ).toList(),
        ),
      ),
    );
  }


  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _AdminAssignmentError(
        message:
            _error!,

        onRetry:
            _loadAssignments,
      );
    }

    if (_assignments.isEmpty) {
      return const _EmptyAssignments();
    }

    return RefreshIndicator(
      onRefresh:
          () =>
              _loadAssignments(
        refresh:
            true,
      ),

      child:
          ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.all(
          16,
        ),

        itemCount:
            _assignments.length,

        separatorBuilder:
            (
          BuildContext context,
          int index,
        ) =>
                const SizedBox(
          height:
              14,
        ),

        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          final TeacherAssignment assignment =
              _assignments[index];

          return _TeacherAssignmentVerificationCard(
            assignment:
                assignment,

            teacherLabel:
                _teacherLabel(
              assignment,
            ),

            processing:
                _processingIds.contains(
              assignment.id,
            ),

            onVerify:
                () {
              _verify(
                assignment,
              );
            },

            onReject:
                () {
              _reject(
                assignment,
              );
            },

            onReopen:
                () {
              _reopen(
                assignment,
              );
            },
          );
        },
      ),
    );
  }


  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),
      ),
    );
  }


  String _cleanError(
    Object error,
  ) {
    String message =
        error.toString();

    if (
      message.startsWith(
        'Exception: ',
      )
    ) {
      message =
          message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }
}


class _TeacherAssignmentVerificationCard
    extends StatelessWidget {
  final TeacherAssignment assignment;

  final String teacherLabel;

  final bool processing;

  final VoidCallback onVerify;

  final VoidCallback onReject;

  final VoidCallback onReopen;


  const _TeacherAssignmentVerificationCard({
    required this.assignment,
    required this.teacherLabel,
    required this.processing,
    required this.onVerify,
    required this.onReject,
    required this.onReopen,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final SubjectOffering? offering =
        assignment.offering;

    final List<String> details =
        [];

    if (
      offering != null &&
      offering.module.trim().isNotEmpty
    ) {
      details.add(
        offering.module,
      );
    }

    if (
      offering != null &&
      offering.channel.trim().isNotEmpty
    ) {
      details.add(
        'Canale ${offering.channel}',
      );
    }

    if (
      offering != null &&
      offering.academicYear.trim().isNotEmpty
    ) {
      details.add(
        offering.academicYear,
      );
    }

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        18,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              AppColors.teacherIndigo
                  .withValues(alpha: 0.22),
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Container(
                width:
                    46,

                height:
                    46,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.teacherIndigo
                          .withValues(alpha: 0.14),

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    const Icon(
                  Icons.school_outlined,

                  color:
                      AppColors.skyBlue,
                ),
              ),

              const SizedBox(
                width:
                    14,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      assignment.subject.name,

                      style:
                          const TextStyle(
                        color:
                            AppColors.pureWhite,

                        fontSize:
                            16,

                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height:
                          3,
                    ),

                    Text(
                      teacherLabel,

                      style:
                          TextStyle(
                        color:
                            AppColors.pureWhite
                                .withValues(alpha: 0.60),

                        fontSize:
                            12,
                      ),
                    ),

                    if (
                      assignment.teacherEmail != null &&
                      assignment.teacherEmail!.isNotEmpty
                    ) ...[
                      const SizedBox(
                        height:
                            2,
                      ),

                      Text(
                        assignment.teacherEmail!,

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withValues(alpha: 0.40),

                          fontSize:
                              10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(
                width:
                    8,
              ),

              _StatusBadge(
                status:
                    assignment.verificationStatus,
              ),
            ],
          ),

          const SizedBox(
            height:
                14,
          ),

          Wrap(
            spacing:
                7,

            runSpacing:
                7,

            children: [
              if (assignment.subject.code.trim().isNotEmpty)
                _InfoBadge(
                  label:
                      assignment.subject.code,

                  icon:
                      Icons.tag_rounded,
                ),

              if (assignment.isCurrent)
                const _InfoBadge(
                  label:
                      'Insegnamento corrente',

                  icon:
                      Icons.event_available_outlined,
                ),

              ...details.map(
                (
                  String detail,
                ) =>
                    _InfoBadge(
                  label:
                      detail,

                  icon:
                      Icons.class_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                16,
          ),

          _buildActions(),
        ],
      ),
    );
  }


  Widget _buildActions() {
    if (processing) {
      return const Center(
        child:
            Padding(
          padding:
              EdgeInsets.symmetric(
            vertical:
                6,
          ),

          child:
              SizedBox(
            width:
                20,

            height:
                20,

            child:
                CircularProgressIndicator(
              strokeWidth:
                  2,

              color:
                  AppColors.teacherIndigo,
            ),
          ),
        ),
      );
    }

    final List<Widget> actions =
        [];

    if (!assignment.isVerified) {
      actions.add(
        Expanded(
          child:
              ElevatedButton.icon(
            onPressed:
                onVerify,

            icon:
                const Icon(
              Icons.check_rounded,

              size:
                  18,
            ),

            label:
                const Text(
              'Verifica',
            ),

            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  AppColors.teacherIndigo,

              foregroundColor:
                  AppColors.pureWhite,

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!assignment.isPending) {
      actions.add(
        Expanded(
          child:
              OutlinedButton.icon(
            onPressed:
                onReopen,

            icon:
                const Icon(
              Icons.schedule_rounded,

              size:
                  18,
            ),

            label:
                const Text(
              'Rimetti in attesa',
            ),

            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  Colors.amber,

              side:
                  BorderSide(
                color:
                    Colors.amber
                        .withValues(alpha: 0.40),
              ),
            ),
          ),
        ),
      );
    }

    if (!assignment.isRejected) {
      actions.add(
        Expanded(
          child:
              OutlinedButton.icon(
            onPressed:
                onReject,

            icon:
                const Icon(
              Icons.close_rounded,

              size:
                  18,
            ),

            label:
                const Text(
              'Rifiuta',
            ),

            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  Colors.redAccent,

              side:
                  BorderSide(
                color:
                    Colors.redAccent
                        .withValues(alpha: 0.40),
              ),
            ),
          ),
        ),
      );
    }

    final List<Widget> spaced =
        [];

    for (int i = 0; i < actions.length; i++) {
      if (i > 0) {
        spaced.add(
          const SizedBox(
            width:
                12,
          ),
        );
      }

      spaced.add(
        actions[i],
      );
    }

    return Row(
      children:
          spaced,
    );
  }
}


class _StatusBadge
    extends StatelessWidget {
  final TeacherAssignmentVerificationStatus status;


  const _StatusBadge({
    required this.status,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    late final Color color;

    late final IconData icon;

    late final String label;

    switch (status) {
      case TeacherAssignmentVerificationStatus.verified:
        color = Colors.greenAccent;
        icon = Icons.verified_rounded;
        label = 'VERIFICATO';

      case TeacherAssignmentVerificationStatus.rejected:
        color = Colors.redAccent;
        icon = Icons.cancel_rounded;
        label = 'RIFIUTATO';

      case TeacherAssignmentVerificationStatus.pending:
        color = Colors.amber;
        icon = Icons.schedule_rounded;
        label = 'DA VERIFICARE';
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            8,

        vertical:
            5,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withValues(alpha: 0.10),

        borderRadius:
            BorderRadius.circular(
          8,
        ),
      ),

      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            icon,

            color:
                color,

            size:
                12,
          ),

          const SizedBox(
            width:
                4,
          ),

          Text(
            label,

            style:
                TextStyle(
              color:
                  color,

              fontSize:
                  9,

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


class _InfoBadge
    extends StatelessWidget {
  final String label;

  final IconData icon;


  const _InfoBadge({
    required this.label,
    required this.icon,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            8,

        vertical:
            5,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.skyBlue.withValues(alpha: 0.10),

        borderRadius:
            BorderRadius.circular(
          8,
        ),
      ),

      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            icon,

            color:
                AppColors.materialSky,

            size:
                12,
          ),

          const SizedBox(
            width:
                4,
          ),

          Text(
            label,

            style:
                const TextStyle(
              color:
                  AppColors.materialSky,

              fontSize:
                  10,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


class _EmptyAssignments
    extends StatelessWidget {
  const _EmptyAssignments();

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      children: [
        const SizedBox(
          height:
              120,
        ),

        Icon(
          Icons.verified_outlined,

          size:
              54,

          color:
              AppColors.pureWhite
                  .withValues(alpha: 0.30),
        ),

        const SizedBox(
          height:
              16,
        ),

        Center(
          child:
              Text(
            'Nessun insegnamento in questo stato.',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite
                      .withValues(alpha: 0.55),

              fontSize:
                  14,
            ),
          ),
        ),
      ],
    );
  }
}


class _AdminAssignmentError
    extends StatelessWidget {
  final String message;

  final VoidCallback onRetry;


  const _AdminAssignmentError({
    required this.message,
    required this.onRetry,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      padding:
          const EdgeInsets.all(
        24,
      ),

      children: [
        const SizedBox(
          height:
              100,
        ),

        const Icon(
          Icons.error_outline_rounded,

          color:
              Colors.redAccent,

          size:
              46,
        ),

        const SizedBox(
          height:
              14,
        ),

        Text(
          message,

          textAlign:
              TextAlign.center,

          style:
              TextStyle(
            color:
                AppColors.pureWhite
                    .withValues(alpha: 0.70),

            fontSize:
                13,

            height:
                1.4,
          ),
        ),

        const SizedBox(
          height:
              18,
        ),

        Center(
          child:
              OutlinedButton.icon(
            onPressed:
                onRetry,

            icon:
                const Icon(
              Icons.refresh_rounded,
            ),

            label:
                const Text(
              'Riprova',
            ),

            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  AppColors.pureWhite,
            ),
          ),
        ),
      ],
    );
  }
}
