import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';

class AdminMaterialPublicationsPage
    extends StatefulWidget {
  const AdminMaterialPublicationsPage({
    super.key,
  });

  @override
  State<AdminMaterialPublicationsPage>
      createState() =>
          _AdminMaterialPublicationsPageState();
}

class _AdminMaterialPublicationsPageState
    extends State<AdminMaterialPublicationsPage> {

  final ApiService _apiService =
      ApiService();

  List<Map<String, dynamic>>
      _requests =
      [];

  bool _loading =
      true;

  bool _processing =
      false;

  String? _error;

  String _statusFilter =
      'pending';

  @override
  void initState() {
    super.initState();

    _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading =
          true;

      _error =
          null;
    });

    try {
      final List<Map<String, dynamic>>
          requests;

      if (_statusFilter ==
          'all') {
        requests =
            await _apiService
                .getAdminMaterialPublications();
      } else {
        requests =
            await _apiService
                .getAdminMaterialPublications(
          status:
              _statusFilter,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _requests =
            requests;

        _loading =
            false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;

        _error =
            _friendlyError(
          e,
        );
      });
    }
  }

  Future<void> _changeFilter(
    String value,
  ) async {
    if (
      _statusFilter ==
          value ||
      _loading ||
      _processing
    ) {
      return;
    }

    setState(() {
      _statusFilter =
          value;
    });

    await _loadRequests();
  }

  Future<void> _openRequest(
    Map<String, dynamic> request,
  ) async {
    final int? requestId =
        _toInt(
      request['id'],
    );

    if (requestId == null) {
      _showMessage(
        'Richiesta non valida.',
      );

      return;
    }

    Map<String, dynamic> detail =
        request;

    try {
      detail =
          await _apiService
              .getAdminMaterialPublication(
        requestId,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    final bool? changed =
        await Navigator.of(
      context,
    ).push<bool>(
      MaterialPageRoute(
        builder:
            (_) =>
                _AdminMaterialPublicationDetailPage(
          request:
              detail,

          apiService:
              _apiService,
        ),
      ),
    );

    if (
      changed == true &&
      mounted
    ) {
      await _loadRequests();
    }
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

        title:
            const Text(
          'Materiali da verificare',
        ),

        actions: [
          IconButton(
            tooltip:
                'Aggiorna',

            onPressed:
                _loading ||
                        _processing
                    ? null
                    : _loadRequests,

            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body:
          SafeArea(
        child:
            Column(
          children: [
            _buildFilters(),

            Expanded(
              child:
                  _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.fromLTRB(
        14,
        14,
        14,
        10,
      ),

      color:
          AppColors.eleganceMidnight,

      child:
          SingleChildScrollView(
        scrollDirection:
            Axis.horizontal,

        child:
            Row(
          children: [
            _FilterChip(
              label:
                  'In attesa',

              selected:
                  _statusFilter ==
                      'pending',

              onTap:
                  () {
                _changeFilter(
                  'pending',
                );
              },
            ),

            const SizedBox(
              width:
                  8,
            ),

            _FilterChip(
              label:
                  'Approvati',

              selected:
                  _statusFilter ==
                      'approved',

              onTap:
                  () {
                _changeFilter(
                  'approved',
                );
              },
            ),

            const SizedBox(
              width:
                  8,
            ),

            _FilterChip(
              label:
                  'Rifiutati',

              selected:
                  _statusFilter ==
                      'rejected',

              onTap:
                  () {
                _changeFilter(
                  'rejected',
                );
              },
            ),

            const SizedBox(
              width:
                  8,
            ),

            _FilterChip(
              label:
                  'Tutti',

              selected:
                  _statusFilter ==
                      'all',

              onTap:
                  () {
                _changeFilter(
                  'all',
                );
              },
            ),
          ],
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
      return _buildErrorState();
    }

    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh:
            _loadRequests,

        child:
            ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.all(
            24,
          ),

          children: [
            const SizedBox(
              height:
                  110,
            ),

            Icon(
              Icons.fact_check_outlined,

              size:
                  52,

              color:
                  AppColors.pureWhite
                      .withOpacity(
                0.25,
              ),
            ),

            const SizedBox(
              height:
                  14,
            ),

            const Text(
              'Nessuna richiesta',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite,

                fontSize:
                    17,

                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height:
                  7,
            ),

            Text(
              _emptyMessage(),

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withOpacity(
                  0.45,
                ),

                fontSize:
                    11,

                height:
                    1.4,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          _loadRequests,

      child:
          ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          14,
          14,
          14,
          30,
        ),

        itemCount:
            _requests.length,

        separatorBuilder:
            (
          BuildContext context,
          int index,
        ) {
          return const SizedBox(
            height:
                10,
          );
        },

        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          final Map<String, dynamic>
              request =
              _requests[index];

          return _PublicationRequestCard(
            request:
                request,

            onTap:
                () {
              _openRequest(
                request,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          24,
        ),

        child:
            Container(
          width:
              double.infinity,

          constraints:
              const BoxConstraints(
            maxWidth:
                520,
          ),

          padding:
              const EdgeInsets.all(
            24,
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
                  Colors.redAccent
                      .withOpacity(
                0.18,
              ),
            ),
          ),

          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              const Icon(
                Icons.error_outline_rounded,

                color:
                    Colors.redAccent,

                size:
                    42,
              ),

              const SizedBox(
                height:
                    14,
              ),

              const Text(
                'Impossibile caricare le richieste',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
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
                    8,
              ),

              Text(
                _error!,

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite
                          .withOpacity(
                    0.55,
                  ),

                  fontSize:
                      11,

                  height:
                      1.4,
                ),
              ),

              const SizedBox(
                height:
                    16,
              ),

              OutlinedButton.icon(
                onPressed:
                    _loadRequests,

                icon:
                    const Icon(
                  Icons.refresh_rounded,
                ),

                label:
                    const Text(
                  'Riprova',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _emptyMessage() {
    switch (_statusFilter) {
      case 'pending':
        return 'Non ci sono materiali in attesa di revisione.';

      case 'approved':
        return 'Non ci sono ancora richieste approvate.';

      case 'rejected':
        return 'Non ci sono ancora richieste rifiutate.';

      default:
        return 'Non sono presenti richieste di pubblicazione.';
    }
  }

  String _friendlyError(
    Object error,
  ) {
    final String message =
        error
            .toString()
            .toLowerCase();

    if (
      message.contains(
            '401',
          ) ||
      message.contains(
            'unauthorized',
          )
    ) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (
      message.contains(
            '403',
          ) ||
      message.contains(
            'forbidden',
          )
    ) {
      return 'Non hai i permessi necessari per gestire le richieste dei materiali.';
    }

    if (
      message.contains(
            'network',
          ) ||
      message.contains(
            'socket',
          ) ||
      message.contains(
            'connection',
          ) ||
      message.contains(
            'timeout',
          ) ||
      message.contains(
            'host lookup',
          )
    ) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    if (
      message.contains(
            '500',
          ) ||
      message.contains(
            '502',
          ) ||
      message.contains(
            '503',
          )
    ) {
      return 'StudentLab non è temporaneamente disponibile. Riprova tra qualche momento.';
    }

    return 'Non è stato possibile caricare le richieste dei materiali.';
  }

  int? _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ??
          '',
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
}

class _AdminMaterialPublicationDetailPage
    extends StatefulWidget {

  final Map<String, dynamic>
      request;

  final ApiService apiService;

  const _AdminMaterialPublicationDetailPage({
    required this.request,
    required this.apiService,
  });

  @override
  State<_AdminMaterialPublicationDetailPage>
      createState() =>
          _AdminMaterialPublicationDetailPageState();
}

class _AdminMaterialPublicationDetailPageState
    extends State<_AdminMaterialPublicationDetailPage> {

  late Map<String, dynamic>
      _request;

  bool _processing =
      false;

  bool _openingFile =
      false;

  bool _openingDuplicate =
      false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _request =
        Map<String, dynamic>.from(
      widget.request,
    );
  }

  int? get _requestId =>
      _toInt(
        _request['id'],
      );

  String get _status =>
      (
        _request['status']
            ?.toString()
            .trim()
            .toLowerCase()
      ) ??
      'pending';

  String get _duplicateStatus =>
      (
        _request['duplicate_status']
            ?.toString()
            .trim()
            .toLowerCase()
      ) ??
      'none';

  bool get _isPending =>
      _status ==
      'pending';

  bool get _hasPossibleDuplicate =>
      _toInt(
        _request[
          'possible_duplicate_material_id'
        ],
      ) !=
      null;

  Future<void> _refreshDetail() async {
    final int? id =
        _requestId;

    if (id == null) {
      return;
    }

    try {
      final Map<String, dynamic>
          result =
          await widget.apiService
              .getAdminMaterialPublication(
        id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _request =
            result;

        _error =
            null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _friendlyError(
          e,
        );
      });
    }
  }

  Future<void> _openSubmittedFile() async {
    final int? id =
        _requestId;

    if (
      id == null ||
      _openingFile
    ) {
      return;
    }

    setState(() {
      _openingFile =
          true;

      _error =
          null;
    });

    try {
      final Uint8List bytes =
          await widget.apiService
              .downloadAdminMaterialPublicationFile(
        id,
      );

      final String originalName =
          _safeFileName(
        _value(
          'original_name',
          fallback:
              'materiale',
        ),
      );

      final File file =
          await _writeTemporaryFile(
        bytes:
            bytes,

        fileName:
            originalName,
      );

      final OpenResult result =
          await OpenFilex.open(
        file.path,
      );

      if (
        result.type !=
            ResultType.done &&
        mounted
      ) {
        _showMessage(
          'Non è stato possibile aprire il file con le applicazioni disponibili.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _friendlyError(
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _openingFile =
              false;
        });
      }
    }
  }

  Future<void> _openPossibleDuplicate() async {
    final int? id =
        _requestId;

    if (
      id == null ||
      !_hasPossibleDuplicate ||
      _openingDuplicate
    ) {
      return;
    }

    setState(() {
      _openingDuplicate =
          true;

      _error =
          null;
    });

    try {
      final Map<String, dynamic>
          duplicate =
          await widget.apiService
              .getAdminPossibleDuplicateMaterial(
        id,
      );

      final Uint8List bytes =
          await widget.apiService
              .downloadAdminPossibleDuplicateFile(
        id,
      );

      final String originalName =
          _safeFileName(
        duplicate[
              'original_name'
            ]
                ?.toString() ??
            'possibile_duplicato',
      );

      final File file =
          await _writeTemporaryFile(
        bytes:
            bytes,

        fileName:
            'duplicato_$originalName',
      );

      final OpenResult result =
          await OpenFilex.open(
        file.path,
      );

      if (
        result.type !=
            ResultType.done &&
        mounted
      ) {
        _showMessage(
          'Non è stato possibile aprire il possibile duplicato.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _friendlyError(
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _openingDuplicate =
              false;
        });
      }
    }
  }

  Future<void> _reviewDuplicate(
    String duplicateStatus,
  ) async {
    final int? id =
        _requestId;

    if (
      id == null ||
      _processing ||
      !_isPending
    ) {
      return;
    }

    final String? note =
        await _askOptionalNote(
      title:
          duplicateStatus ==
                  'confirmed'
              ? 'Conferma duplicato'
              : 'Escludi duplicato',

      message:
          duplicateStatus ==
                  'confirmed'
              ? 'Confermi che il materiale proposto è già presente su StudentLab?'
              : 'Confermi che il materiale proposto non è un duplicato?',
    );

    if (note == null) {
      return;
    }

    setState(() {
      _processing =
          true;

      _error =
          null;
    });

    try {
      final Map<String, dynamic>
          result =
          await widget.apiService
              .reviewAdminMaterialDuplicate(
        requestId:
            id,

        data: {
          'duplicate_status':
              duplicateStatus,

          'admin_note':
              note.trim().isEmpty
                  ? null
                  : note.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _request =
            result;
      });

      _showMessage(
        duplicateStatus ==
                'confirmed'
            ? 'Materiale confermato come duplicato.'
            : 'Il materiale non è stato considerato duplicato.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _friendlyError(
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _processing =
              false;
        });
      }
    }
  }

  Future<void> _approve() async {
    final int? id =
        _requestId;

    if (
      id == null ||
      _processing ||
      !_isPending
    ) {
      return;
    }

    if (_duplicateStatus ==
        'confirmed') {
      _showMessage(
        'Il materiale è stato confermato come duplicato e non può essere pubblicato.',
      );

      return;
    }

    if (
      _hasPossibleDuplicate &&
      _duplicateStatus ==
          'suspected'
    ) {
      _showMessage(
        'Prima di approvare, verifica il possibile duplicato.',
      );

      return;
    }

    final String? note =
        await _askOptionalNote(
      title:
          'Approva materiale',

      message:
          'Il materiale verrà pubblicato e diventerà disponibile agli utenti. Vuoi procedere?',
    );

    if (note == null) {
      return;
    }

    setState(() {
      _processing =
          true;

      _error =
          null;
    });

    try {
      await widget.apiService
          .approveAdminMaterialPublication(
        requestId:
            id,

        data: {
          'admin_note':
              note.trim().isEmpty
                  ? null
                  : note.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Materiale approvato e pubblicato.',
      );

      Navigator.of(
        context,
      ).pop(
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _friendlyError(
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _processing =
              false;
        });
      }
    }
  }

  Future<void> _reject() async {
    final int? id =
        _requestId;

    if (
      id == null ||
      _processing ||
      !_isPending
    ) {
      return;
    }

    final _RejectResult? result =
        await _askRejection();

    if (result == null) {
      return;
    }

    setState(() {
      _processing =
          true;

      _error =
          null;
    });

    try {
      await widget.apiService
          .rejectAdminMaterialPublication(
        requestId:
            id,

        data: {
          'rejection_reason':
              result.reason.trim(),

          'admin_note':
              result.note.trim().isEmpty
                  ? null
                  : result.note.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Richiesta rifiutata.',
      );

      Navigator.of(
        context,
      ).pop(
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _friendlyError(
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _processing =
              false;
        });
      }
    }
  }

  Future<String?> _askOptionalNote({
    required String title,
    required String message,
  }) async {
    final TextEditingController
        controller =
        TextEditingController();

    final String? result =
        await showDialog<String>(
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
              SingleChildScrollView(
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  message,

                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.65,
                    ),

                    height:
                        1.4,
                  ),
                ),

                const SizedBox(
                  height:
                      16,
                ),

                TextField(
                  controller:
                      controller,

                  minLines:
                      2,

                  maxLines:
                      5,

                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,
                  ),

                  decoration:
                      const InputDecoration(
                    labelText:
                        'Nota admin (facoltativa)',
                  ),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
                  const Text(
                'Annulla',
              ),
            ),

            ElevatedButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  controller.text,
                );
              },

              child:
                  const Text(
                'Conferma',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  Future<_RejectResult?> _askRejection() async {
    final TextEditingController
        reasonController =
        TextEditingController();

    final TextEditingController
        noteController =
        TextEditingController();

    final _RejectResult? result =
        await showDialog<_RejectResult>(
      context:
          context,

      builder:
          (
        BuildContext dialogContext,
      ) {
        String? localError;

        return StatefulBuilder(
          builder:
              (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            return AlertDialog(
              backgroundColor:
                  AppColors.eleganceDeepNavy,

              title:
                  const Text(
                'Rifiuta materiale',

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite,
                ),
              ),

              content:
                  SingleChildScrollView(
                child:
                    Column(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    TextField(
                      controller:
                          reasonController,

                      minLines:
                          2,

                      maxLines:
                          5,

                      style:
                          const TextStyle(
                        color:
                            AppColors.pureWhite,
                      ),

                      decoration:
                          InputDecoration(
                        labelText:
                            'Motivo del rifiuto',

                        errorText:
                            localError,
                      ),
                    ),

                    const SizedBox(
                      height:
                          14,
                    ),

                    TextField(
                      controller:
                          noteController,

                      minLines:
                          2,

                      maxLines:
                          5,

                      style:
                          const TextStyle(
                        color:
                            AppColors.pureWhite,
                      ),

                      decoration:
                          const InputDecoration(
                        labelText:
                            'Nota admin (facoltativa)',
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed:
                      () {
                    Navigator.pop(
                      dialogContext,
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
                    final String reason =
                        reasonController.text
                            .trim();

                    if (reason.isEmpty) {
                      setDialogState(
                        () {
                          localError =
                              'Inserisci il motivo del rifiuto';
                        },
                      );

                      return;
                    }

                    Navigator.pop(
                      dialogContext,

                      _RejectResult(
                        reason:
                            reason,

                        note:
                            noteController.text
                                .trim(),
                      ),
                    );
                  },

                  child:
                      const Text(
                    'Rifiuta',

                    style:
                        TextStyle(
                      color:
                          Colors.redAccent,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    reasonController.dispose();
    noteController.dispose();

    return result;
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

        title:
            const Text(
          'Verifica materiale',
        ),

        actions: [
          IconButton(
            tooltip:
                'Aggiorna',

            onPressed:
                _processing
                    ? null
                    : _refreshDetail,

            icon:
                const Icon(
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
                  760,
            ),

            child:
                ListView(
              padding:
                  const EdgeInsets.all(
                20,
              ),

              children: [
                _buildHeader(),

                const SizedBox(
                  height:
                      16,
                ),

                _buildAcademicData(),

                const SizedBox(
                  height:
                      16,
                ),

                _buildFileSection(),

                if (_hasPossibleDuplicate ||
                    _duplicateStatus !=
                        'none') ...[
                  const SizedBox(
                    height:
                        16,
                  ),

                  _buildDuplicateSection(),
                ],

                if (_value(
                      'admin_note',
                    ).isNotEmpty ||
                    _value(
                      'rejection_reason',
                    ).isNotEmpty) ...[
                  const SizedBox(
                    height:
                        16,
                  ),

                  _buildModerationInfo(),
                ],

                if (_error !=
                    null) ...[
                  const SizedBox(
                    height:
                        16,
                  ),

                  _buildError(),
                ],

                if (_isPending) ...[
                  const SizedBox(
                    height:
                        22,
                  ),

                  _buildActions(),
                ],

                const SizedBox(
                  height:
                      30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding:
          const EdgeInsets.all(
        17,
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
              _statusColor()
                  .withOpacity(
            0.22,
          ),
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(
                  _value(
                    'title',
                    fallback:
                        'Materiale senza titolo',
                  ),

                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,

                    fontSize:
                        18,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              _StatusBadge(
                status:
                    _status,
              ),
            ],
          ),

          if (_value(
                'description',
              ).isNotEmpty) ...[
            const SizedBox(
              height:
                  12,
            ),

            Text(
              _value(
                'description',
              ),

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withOpacity(
                  0.58,
                ),

                fontSize:
                    11,

                height:
                    1.45,
              ),
            ),
          ],

          const SizedBox(
            height:
                14,
          ),

          Wrap(
            spacing:
                8,

            runSpacing:
                8,

            children: [
              _SmallBadge(
                icon:
                    Icons.person_outline_rounded,

                label:
                    'Utente #${_value('user_id', fallback: '?')}',
              ),

              _SmallBadge(
                icon:
                    Icons.schedule_rounded,

                label:
                    _formatDate(
                  _value(
                    'created_at',
                  ),
                ),
              ),

              if (_duplicateStatus !=
                  'none')
                _SmallBadge(
                  icon:
                      Icons.content_copy_rounded,

                  label:
                      _duplicateLabel(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicData() {
    return _Section(
      title:
          'Collocazione',

      icon:
          Icons.school_outlined,

      child:
          Column(
        children: [
          _InfoRow(
            label:
                'Ateneo',

            value:
                _value(
              'university',
              fallback:
                  '-',
            ),
          ),

          _InfoRow(
            label:
                'Dipartimento',

            value:
                _value(
              'department',
              fallback:
                  '-',
            ),
          ),

          _InfoRow(
            label:
                'Corso',

            value:
                _value(
              'course',
              fallback:
                  '-',
            ),
          ),

          _InfoRow(
            label:
                'Materia ID',

            value:
                _value(
              'subject_id',
              fallback:
                  '-',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSection() {
    return _Section(
      title:
          'File proposto',

      icon:
          Icons.insert_drive_file_outlined,

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,

        children: [
          _InfoRow(
            label:
                'Nome',

            value:
                _value(
              'original_name',
              fallback:
                  '-',
            ),
          ),

          _InfoRow(
            label:
                'Formato',

            value:
                _value(
              'mime_type',
              fallback:
                  '-',
            ),
          ),

          _InfoRow(
            label:
                'Dimensione',

            value:
                _formatSize(
              _toInt(
                _request[
                  'size'
                ],
              ),
            ),
          ),

          const SizedBox(
            height:
                14,
          ),

          OutlinedButton.icon(
            onPressed:
                _openingFile ||
                        _processing
                    ? null
                    : _openSubmittedFile,

            icon:
                _openingFile
                    ? const SizedBox(
                        width:
                            17,

                        height:
                            17,

                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                        ),
                      )
                    : const Icon(
                        Icons.open_in_new_rounded,
                      ),

            label:
                Text(
              _openingFile
                  ? 'Apertura...'
                  : 'Apri file da verificare',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateSection() {
    return _Section(
      title:
          'Controllo duplicato',

      icon:
          Icons.content_copy_outlined,

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,

        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(
                  _duplicateDescription(),

                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.56,
                    ),

                    fontSize:
                        11,

                    height:
                        1.4,
                  ),
                ),
              ),
            ],
          ),

          if (_hasPossibleDuplicate) ...[
            const SizedBox(
              height:
                  14,
            ),

            OutlinedButton.icon(
              onPressed:
                  _openingDuplicate ||
                          _processing
                      ? null
                      : _openPossibleDuplicate,

              icon:
                  _openingDuplicate
                      ? const SizedBox(
                          width:
                              17,

                          height:
                              17,

                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Icon(
                          Icons.compare_arrows_rounded,
                        ),

              label:
                  const Text(
                'Apri materiale simile',
              ),
            ),
          ],

          if (
            _isPending &&
            _duplicateStatus ==
                'suspected'
          ) ...[
            const SizedBox(
              height:
                  12,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _processing
                            ? null
                            : () {
                                _reviewDuplicate(
                                  'not_duplicate',
                                );
                              },

                    icon:
                        const Icon(
                      Icons.check_rounded,
                    ),

                    label:
                        const Text(
                      'Non duplicato',
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                      10,
                ),

                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _processing
                            ? null
                            : () {
                                _reviewDuplicate(
                                  'confirmed',
                                );
                              },

                    icon:
                        const Icon(
                      Icons.content_copy_rounded,

                      color:
                          Colors.orangeAccent,
                    ),

                    label:
                        const Text(
                      'È duplicato',

                      style:
                          TextStyle(
                        color:
                            Colors.orangeAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModerationInfo() {
    return _Section(
      title:
          'Revisione',

      icon:
          Icons.fact_check_outlined,

      child:
          Column(
        children: [
          if (_value(
                'rejection_reason',
              ).isNotEmpty)
            _InfoRow(
              label:
                  'Motivo rifiuto',

              value:
                  _value(
                'rejection_reason',
              ),
            ),

          if (_value(
                'admin_note',
              ).isNotEmpty)
            _InfoRow(
              label:
                  'Nota admin',

              value:
                  _value(
                'admin_note',
              ),
            ),

          if (_value(
                'reviewed_at',
              ).isNotEmpty)
            _InfoRow(
              label:
                  'Revisionato',

              value:
                  _formatDate(
                _value(
                  'reviewed_at',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [
        if (_processing)
          const Padding(
            padding:
                EdgeInsets.only(
              bottom:
                  14,
            ),

            child:
                LinearProgressIndicator(),
          ),

        Row(
          children: [
            Expanded(
              child:
                  ElevatedButton.icon(
                onPressed:
                    _processing
                        ? null
                        : _approve,

                icon:
                    const Icon(
                  Icons.check_circle_outline_rounded,
                ),

                label:
                    const Text(
                  'Approva',
                ),

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.green.shade700,

                  foregroundColor:
                      Colors.white,

                  padding:
                      const EdgeInsets.symmetric(
                    vertical:
                        14,
                  ),
                ),
              ),
            ),

            const SizedBox(
              width:
                  10,
            ),

            Expanded(
              child:
                  OutlinedButton.icon(
                onPressed:
                    _processing
                        ? null
                        : _reject,

                icon:
                    const Icon(
                  Icons.cancel_outlined,

                  color:
                      Colors.redAccent,
                ),

                label:
                    const Text(
                  'Rifiuta',

                  style:
                      TextStyle(
                    color:
                        Colors.redAccent,
                  ),
                ),

                style:
                    OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical:
                        14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding:
          const EdgeInsets.all(
        13,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.redAccent
                .withOpacity(
          0.08,
        ),

        borderRadius:
            BorderRadius.circular(
          12,
        ),

        border:
            Border.all(
          color:
              Colors.redAccent
                  .withOpacity(
            0.20,
          ),
        ),
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.error_outline_rounded,

            color:
                Colors.redAccent,

            size:
                19,
          ),

          const SizedBox(
            width:
                8,
          ),

          Expanded(
            child:
                Text(
              _error!,

              style:
                  const TextStyle(
                color:
                    Colors.white70,

                fontSize:
                    11,

                height:
                    1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<File> _writeTemporaryFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final Directory directory =
        Directory(
      '${Directory.systemTemp.path}'
      '${Platform.pathSeparator}'
      'studentlab_admin_materials',
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive:
            true,
      );
    }

    final File file =
        File(
      '${directory.path}'
      '${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}_$fileName',
    );

    await file.writeAsBytes(
      bytes,
      flush:
          true,
    );

    return file;
  }

  String _safeFileName(
    String value,
  ) {
    final String cleaned =
        value.replaceAll(
      RegExp(
        r'[^a-zA-Z0-9._-]',
      ),
      '_',
    );

    return cleaned.isEmpty
        ? 'materiale'
        : cleaned;
  }

  String _value(
    String key, {
    String fallback = '',
  }) {
    final dynamic value =
        _request[key];

    if (value == null) {
      return fallback;
    }

    final String text =
        value.toString().trim();

    return text.isEmpty
        ? fallback
        : text;
  }

  int? _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ??
          '',
    );
  }

  String _formatSize(
    int? size,
  ) {
    if (
      size == null ||
      size <= 0
    ) {
      return 'Dimensione non disponibile';
    }

    if (size < 1024) {
      return '$size B';
    }

    if (
      size <
      1024 * 1024
    ) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }

    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(
    String raw,
  ) {
    if (raw.trim().isEmpty) {
      return '-';
    }

    final DateTime? parsed =
        DateTime.tryParse(
      raw,
    );

    if (parsed == null) {
      return raw;
    }

    final DateTime local =
        parsed.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _duplicateLabel() {
    switch (_duplicateStatus) {
      case 'suspected':
        return 'Possibile duplicato';

      case 'confirmed':
        return 'Duplicato confermato';

      case 'not_duplicate':
        return 'Non duplicato';

      default:
        return 'Nessun duplicato';
    }
  }

  String _duplicateDescription() {
    switch (_duplicateStatus) {
      case 'suspected':
        return 'StudentLab ha rilevato un materiale simile. Confronta i due file prima di approvare o rifiutare la richiesta.';

      case 'confirmed':
        return 'Il materiale è stato confermato come duplicato. Non può essere approvato per la pubblicazione.';

      case 'not_duplicate':
        return 'Il possibile duplicato è stato controllato e il materiale è stato considerato differente.';

      default:
        return 'Non sono stati rilevati materiali simili.';
    }
  }

  Color _statusColor() {
    switch (_status) {
      case 'approved':
        return Colors.greenAccent;

      case 'rejected':
        return Colors.redAccent;

      default:
        return Colors.amber;
    }
  }

  String _friendlyError(
    Object error,
  ) {
    final String message =
        error
            .toString()
            .toLowerCase();

    if (
      message.contains(
            '401',
          ) ||
      message.contains(
            'unauthorized',
          )
    ) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (
      message.contains(
            '403',
          ) ||
      message.contains(
            'forbidden',
          )
    ) {
      return 'Non hai i permessi necessari per questa operazione amministrativa.';
    }

    if (
      message.contains(
            '404',
          ) ||
      message.contains(
            'not found',
          )
    ) {
      return 'La richiesta o il file non sono più disponibili.';
    }

    if (
      message.contains(
            '409',
          ) ||
      message.contains(
            'conflict',
          ) ||
      message.contains(
            'duplicat',
          )
    ) {
      return 'La richiesta non può essere completata nello stato attuale. Aggiorna i dati e riprova.';
    }

    if (
      message.contains(
            'network',
          ) ||
      message.contains(
            'socket',
          ) ||
      message.contains(
            'connection',
          ) ||
      message.contains(
            'timeout',
          ) ||
      message.contains(
            'host lookup',
          )
    ) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    if (
      message.contains(
            '500',
          ) ||
      message.contains(
            '502',
          ) ||
      message.contains(
            '503',
          )
    ) {
      return 'StudentLab non è temporaneamente disponibile. Riprova tra qualche momento.';
    }

    return 'Non è stato possibile completare l’operazione. Riprova.';
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
}

class _PublicationRequestCard
    extends StatelessWidget {

  final Map<String, dynamic>
      request;

  final VoidCallback onTap;

  const _PublicationRequestCard({
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final String title =
        request['title']
                ?.toString()
                .trim() ??
            '';

    final String status =
        request['status']
                ?.toString()
                .trim()
                .toLowerCase() ??
            'pending';

    final String duplicateStatus =
        request['duplicate_status']
                ?.toString()
                .trim()
                .toLowerCase() ??
            'none';

    final String course =
        request['course']
                ?.toString()
                .trim() ??
            '';

    final String department =
        request['department']
                ?.toString()
                .trim() ??
            '';

    return Material(
      color:
          Colors.transparent,

      child:
          InkWell(
        onTap:
            onTap,

        borderRadius:
            BorderRadius.circular(
          17,
        ),

        child:
            Container(
          padding:
              const EdgeInsets.all(
            16,
          ),

          decoration:
              BoxDecoration(
            color:
                AppColors.eleganceMidnight,

            borderRadius:
                BorderRadius.circular(
              17,
            ),

            border:
                Border.all(
              color:
                  _statusColor(
                    status,
                  ).withOpacity(
                0.18,
              ),
            ),
          ),

          child:
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
                      AppColors.brandNightBlue,

                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),

                child:
                    const Icon(
                  Icons.description_outlined,

                  color:
                      AppColors.skyBlue,

                  size:
                      23,
                ),
              ),

              const SizedBox(
                width:
                    12,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Expanded(
                          child:
                              Text(
                            title.isEmpty
                                ? 'Materiale senza titolo'
                                : title,

                            maxLines:
                                2,

                            overflow:
                                TextOverflow.ellipsis,

                            style:
                                const TextStyle(
                              color:
                                  AppColors.pureWhite,

                              fontSize:
                                  14,

                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width:
                              8,
                        ),

                        _StatusBadge(
                          status:
                              status,
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                          7,
                    ),

                    Text(
                      [
                        department,
                        course,
                      ]
                          .where(
                            (
                              String value,
                            ) =>
                                value.isNotEmpty,
                          )
                          .join(
                            ' • ',
                          ),

                      maxLines:
                          2,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          TextStyle(
                        color:
                            AppColors.pureWhite
                                .withOpacity(
                          0.45,
                        ),

                        fontSize:
                            10,
                      ),
                    ),

                    if (duplicateStatus ==
                        'suspected') ...[
                      const SizedBox(
                        height:
                            8,
                      ),

                      const Row(
                        children: [
                          Icon(
                            Icons.content_copy_outlined,

                            color:
                                Colors.orangeAccent,

                            size:
                                14,
                          ),

                          SizedBox(
                            width:
                                5,
                          ),

                          Text(
                            'Possibile duplicato',

                            style:
                                TextStyle(
                              color:
                                  Colors.orangeAccent,

                              fontSize:
                                  9,

                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(
                width:
                    8,
              ),

              const Icon(
                Icons.chevron_right_rounded,

                color:
                    Colors.white30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case 'approved':
        return Colors.greenAccent;

      case 'rejected':
        return Colors.redAccent;

      default:
        return Colors.amber;
    }
  }
}

class _StatusBadge
    extends StatelessWidget {

  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    String label;

    Color color;

    switch (status) {
      case 'approved':
        label =
            'APPROVATO';

        color =
            Colors.greenAccent;
        break;

      case 'rejected':
        label =
            'RIFIUTATO';

        color =
            Colors.redAccent;
        break;

      default:
        label =
            'IN ATTESA';

        color =
            Colors.amber;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            7,

        vertical:
            4,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          0.08,
        ),

        borderRadius:
            BorderRadius.circular(
          8,
        ),

        border:
            Border.all(
          color:
              color.withOpacity(
            0.18,
          ),
        ),
      ),

      child:
          Text(
        label,

        style:
            TextStyle(
          color:
              color,

          fontSize:
              8,

          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }
}

class _FilterChip
    extends StatelessWidget {

  final String label;

  final bool selected;

  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap:
          onTap,

      borderRadius:
          BorderRadius.circular(
        20,
      ),

      child:
          Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal:
              13,

          vertical:
              8,
        ),

        decoration:
            BoxDecoration(
          color:
              selected
                  ? AppColors.socialBlue
                  : AppColors.brandNightBlue,

          borderRadius:
              BorderRadius.circular(
            20,
          ),

          border:
              Border.all(
            color:
                selected
                    ? AppColors.skyBlue
                        .withOpacity(
                        0.35,
                      )
                    : AppColors.pureWhite
                        .withOpacity(
                        0.07,
                      ),
          ),
        ),

        child:
            Text(
          label,

          style:
              TextStyle(
            color:
                selected
                    ? AppColors.pureWhite
                    : AppColors.pureWhite
                        .withOpacity(
                        0.60,
                      ),

            fontSize:
                10,

            fontWeight:
                selected
                    ? FontWeight.w600
                    : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _Section
    extends StatelessWidget {

  final String title;

  final IconData icon;

  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        17,
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
              AppColors.skyBlue
                  .withOpacity(
            0.10,
          ),
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Icon(
                icon,

                color:
                    AppColors.skyBlue,

                size:
                    19,
              ),

              const SizedBox(
                width:
                    8,
              ),

              Text(
                title,

                style:
                    const TextStyle(
                  color:
                      AppColors.pureWhite,

                  fontSize:
                      14,

                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                15,
          ),

          child,
        ],
      ),
    );
  }
}

class _InfoRow
    extends StatelessWidget {

  final String label;

  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom:
            9,
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          SizedBox(
            width:
                108,

            child:
                Text(
              label,

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withOpacity(
                  0.38,
                ),

                fontSize:
                    10,
              ),
            ),
          ),

          Expanded(
            child:
                Text(
              value,

              textAlign:
                  TextAlign.right,

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withOpacity(
                  0.72,
                ),

                fontSize:
                    10,

                fontWeight:
                    FontWeight.w500,

                height:
                    1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge
    extends StatelessWidget {

  final IconData icon;

  final String label;

  const _SmallBadge({
    required this.icon,
    required this.label,
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
            6,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.brandNightBlue,

        borderRadius:
            BorderRadius.circular(
          9,
        ),
      ),

      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            icon,

            size:
                12,

            color:
                AppColors.materialSky,
          ),

          const SizedBox(
            width:
                5,
          ),

          Text(
            label,

            style:
                TextStyle(
              color:
                  AppColors.pureWhite
                      .withOpacity(
                0.60,
              ),

              fontSize:
                  9,
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectResult {

  final String reason;

  final String note;

  const _RejectResult({
    required this.reason,
    required this.note,
  });
}