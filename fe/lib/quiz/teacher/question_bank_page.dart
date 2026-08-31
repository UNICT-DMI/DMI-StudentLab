import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import 'question_editor_page.dart';
import 'services/question_management_service.dart';


class QuestionBankPage extends StatefulWidget {
  final String department;
  final String course;
  final String subject;
  final Map<String, dynamic> metadataBase;

  const QuestionBankPage({
    super.key,
    required this.department,
    required this.course,
    required this.subject,
    required this.metadataBase,
  });

  @override
  State<QuestionBankPage> createState() =>
      _QuestionBankPageState();
}


class _QuestionBankPageState
    extends State<QuestionBankPage> {
  final QuestionManagementService _service =
      QuestionManagementService();

  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  bool _actionRunning = false;
  String? _error;
  String? _argumentFilter;
  bool _showHidden = true;


  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<Map<String, dynamic>> questions =
          await _service.getQuestions(
        department:
            widget.department,
        course:
            widget.course,
        subject:
            widget.subject,
        includeHidden:
            true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _questions = questions;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _friendlyError(
          error,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }


  List<String> get _arguments {
    final Set<String> values = {};

    for (final Map<String, dynamic> question in _questions) {
      final dynamic metadataRaw =
          question['metadata'];

      if (metadataRaw is! Map) {
        continue;
      }

      final String value =
          metadataRaw['argoment']
              ?.toString()
              .trim() ??
          '';

      if (value.isNotEmpty) {
        values.add(
          value,
        );
      }
    }

    final List<String> result =
        values.toList()
          ..sort(
            (
              String a,
              String b,
            ) =>
                a.toLowerCase().compareTo(
                      b.toLowerCase(),
                    ),
          );

    return result;
  }


  List<Map<String, dynamic>> get _filteredQuestions {
    final String search =
        _searchController.text
            .trim()
            .toLowerCase();

    return _questions.where(
      (
        Map<String, dynamic> question,
      ) {
        final bool hidden =
            question['is_hidden'] ==
            true;

        if (
          hidden &&
          !_showHidden
        ) {
          return false;
        }

        final dynamic metadataRaw =
            question['metadata'];

        final Map<String, dynamic> metadata =
            metadataRaw is Map
                ? Map<String, dynamic>.from(
                    metadataRaw,
                  )
                : {};

        final String argument =
            metadata['argoment']
                ?.toString()
                .trim() ??
            '';

        if (
          _argumentFilter != null &&
          _argumentFilter!
              .isNotEmpty &&
          argument !=
              _argumentFilter
        ) {
          return false;
        }

        if (search.isEmpty) {
          return true;
        }

        final String text =
            question['text']
                ?.toString()
                .toLowerCase() ??
            '';

        final String questionId =
            question['id_question']
                ?.toString()
                .toLowerCase() ??
            '';

        return text.contains(
              search,
            ) ||
            argument
                .toLowerCase()
                .contains(
                  search,
                ) ||
            questionId.contains(
              search,
            );
      },
    ).toList();
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
            Text(
          widget.subject,
          maxLines:
              1,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontSize:
                18,
            fontWeight:
                FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip:
                'Aggiorna',
            onPressed:
                _loading
                    ? null
                    : _loadQuestions,
            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _actionRunning
                ? null
                : _createQuestion,
        backgroundColor:
            AppColors.brandNightBlue,
        foregroundColor:
            AppColors.pureWhite,
        icon:
            const Icon(
          Icons.add_rounded,
        ),
        label:
            const Text(
          'Nuova domanda',
        ),
      ),
      body:
          SafeArea(
        child:
            Column(
          children: [
            _buildToolbar(),
            Expanded(
              child:
                  _buildBody(),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildToolbar() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        border:
            Border(
          bottom:
              BorderSide(
            color:
                AppColors.skyBlue
                    .withValues(
              alpha:
                  0.08,
            ),
          ),
        ),
      ),
      child:
          Column(
        children: [
          Row(
            children: [
              Expanded(
                child:
                    TextField(
                  controller:
                      _searchController,
                  onChanged:
                      (_) {
                    setState(() {});
                  },
                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,
                    fontSize:
                        13,
                  ),
                  decoration:
                      InputDecoration(
                    hintText:
                        'Cerca domanda, ID o argomento...',
                    hintStyle:
                        TextStyle(
                      color:
                          AppColors.pureWhite
                              .withValues(
                        alpha:
                            0.38,
                      ),
                    ),
                    prefixIcon:
                        const Icon(
                      Icons.search_rounded,
                      color:
                          AppColors.skyBlue,
                    ),
                    suffixIcon:
                        _searchController.text
                                .isEmpty
                            ? null
                            : IconButton(
                                tooltip:
                                    'Pulisci',
                                onPressed:
                                    () {
                                  _searchController
                                      .clear();
                                  setState(() {});
                                },
                                icon:
                                    const Icon(
                                  Icons.close_rounded,
                                  color:
                                      Colors.white54,
                                ),
                              ),
                    filled:
                        true,
                    fillColor:
                        AppColors.brandNightBlue
                            .withValues(
                      alpha:
                          0.42,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width:
                    10,
              ),
              OutlinedButton.icon(
                onPressed:
                    _actionRunning
                        ? null
                        : _importJson,
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      AppColors.skyBlue,
                  side:
                      BorderSide(
                    color:
                        AppColors.skyBlue
                            .withValues(
                      alpha:
                          0.35,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        14,
                    vertical:
                        15,
                  ),
                ),
                icon:
                    const Icon(
                  Icons.upload_file_outlined,
                  size:
                      19,
                ),
                label:
                    const Text(
                  'Importa',
                ),
              ),
            ],
          ),
          const SizedBox(
            height:
                10,
          ),
          SingleChildScrollView(
            scrollDirection:
                Axis.horizontal,
            child:
                Row(
              children: [
                _FilterChip(
                  label:
                      _argumentFilter ??
                      'Tutti gli argomenti',
                  icon:
                      Icons.topic_outlined,
                  onTap:
                      _chooseArgument,
                ),
                const SizedBox(
                  width:
                      8,
                ),
                FilterChip(
                  selected:
                      _showHidden,
                  onSelected:
                      (
                        bool value,
                      ) {
                    setState(() {
                      _showHidden =
                          value;
                    });
                  },
                  label:
                      const Text(
                    'Mostra nascoste',
                  ),
                  avatar:
                      const Icon(
                    Icons.visibility_off_outlined,
                    size:
                        18,
                  ),
                  selectedColor:
                      AppColors.brandNightBlue,
                  checkmarkColor:
                      AppColors.skyBlue,
                  labelStyle:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,
                    fontSize:
                        12,
                  ),
                  backgroundColor:
                      AppColors.eleganceDeepNavy,
                  side:
                      BorderSide(
                    color:
                        AppColors.skyBlue
                            .withValues(
                      alpha:
                          0.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      return _StateMessage(
        icon:
            Icons.error_outline_rounded,
        title:
            'Impossibile caricare le domande',
        message:
            _error!,
        actionLabel:
            'Riprova',
        onAction:
            _loadQuestions,
      );
    }

    final List<Map<String, dynamic>> questions =
        _filteredQuestions;

    if (questions.isEmpty) {
      return _StateMessage(
        icon:
            Icons.quiz_outlined,
        title:
            _questions.isEmpty
                ? 'Nessuna domanda'
                : 'Nessun risultato',
        message:
            _questions.isEmpty
                ? 'Crea la prima domanda oppure importa un file JSON.'
                : 'Modifica i filtri o la ricerca per vedere altre domande.',
        actionLabel:
            _questions.isEmpty
                ? 'Nuova domanda'
                : null,
        onAction:
            _questions.isEmpty
                ? _createQuestion
                : null,
      );
    }

    return RefreshIndicator(
      onRefresh:
          _loadQuestions,
      child:
          ListView.builder(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          14,
          16,
          100,
        ),
        itemCount:
            questions.length,
        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          return Padding(
            padding:
                const EdgeInsets.only(
              bottom:
                  12,
            ),
            child:
                _QuestionCard(
              question:
                  questions[
                    index
                  ],
              onOpen:
                  () =>
                      _editQuestion(
                questions[
                  index
                ],
              ),
              onAction:
                  (
                    _QuestionAction action,
                  ) =>
                      _handleAction(
                questions[
                  index
                ],
                action,
              ),
            ),
          );
        },
      ),
    );
  }


  Future<void> _chooseArgument() async {
    final List<String> arguments =
        _arguments;

    final String? result =
        await showModalBottomSheet<String?>(
      context:
          context,
      backgroundColor:
          AppColors.eleganceDeepNavy,
      showDragHandle:
          true,
      builder:
          (
        BuildContext context,
      ) {
        return SafeArea(
          child:
              ListView(
            shrinkWrap:
                true,
            children: [
              ListTile(
                leading:
                    const Icon(
                  Icons.clear_all_rounded,
                  color:
                      AppColors.skyBlue,
                ),
                title:
                    const Text(
                  'Tutti gli argomenti',
                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite,
                  ),
                ),
                onTap:
                    () =>
                        Navigator.pop(
                  context,
                  '',
                ),
              ),
              for (
                final String argument
                in arguments
              )
                ListTile(
                  leading:
                      const Icon(
                    Icons.topic_outlined,
                    color:
                        AppColors.skyBlue,
                  ),
                  title:
                      Text(
                    argument,
                    style:
                        const TextStyle(
                      color:
                          AppColors.pureWhite,
                    ),
                  ),
                  onTap:
                      () =>
                          Navigator.pop(
                    context,
                    argument,
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (
      result == null
    ) {
      return;
    }

    setState(() {
      _argumentFilter =
          result.isEmpty
              ? null
              : result;
    });
  }


  Future<void> _createQuestion() async {
    final Map<String, dynamic>? result =
        await Navigator.push<
            Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (
          BuildContext context,
        ) =>
                QuestionEditorPage(
          department:
              widget.department,
          course:
              widget.course,
          subject:
              widget.subject,
          metadataBase:
              widget.metadataBase,
        ),
      ),
    );

    if (
      result != null
    ) {
      await _loadQuestions();
    }
  }


  Future<void> _editQuestion(
    Map<String, dynamic> question,
  ) async {
    final Map<String, dynamic>? result =
        await Navigator.push<
            Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (
          BuildContext context,
        ) =>
                QuestionEditorPage(
          department:
              widget.department,
          course:
              widget.course,
          subject:
              widget.subject,
          metadataBase:
              widget.metadataBase,
          question:
              question,
        ),
      ),
    );

    if (
      result != null
    ) {
      await _loadQuestions();
    }
  }


  Future<void> _importJson() async {
    final FilePickerResult? result =
        await FilePicker.pickFiles(
      allowMultiple:
          false,
      type:
          FileType.custom,
      allowedExtensions:
          const [
        'json',
      ],
    );

    if (
      result == null ||
      result.files.isEmpty
    ) {
      return;
    }

    final String? path =
        result.files.first.path;

    if (
      path == null ||
      path.trim().isEmpty
    ) {
      _showMessage(
        'Il file selezionato non è accessibile.',
      );
      return;
    }

    setState(() {
      _actionRunning =
          true;
    });

    try {
      final Map<String, dynamic> imported =
          await _service.importQuestions(
        department:
            widget.department,
        course:
            widget.course,
        subject:
            widget.subject,
        filePath:
            path,
        skipDuplicates:
            true,
      );

      if (!mounted) {
        return;
      }

      final dynamic importedCount =
          imported['imported_count'] ??
          imported['created'] ??
          imported['count'];

      _showMessage(
        importedCount == null
            ? 'Import completato.'
            : 'Import completato: $importedCount domande aggiunte.',
      );

      await _loadQuestions();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _friendlyError(
          error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionRunning =
              false;
        });
      }
    }
  }


  Future<void> _handleAction(
    Map<String, dynamic> question,
    _QuestionAction action,
  ) async {
    if (_actionRunning) {
      return;
    }

    final String questionId =
        question['id_question']
            ?.toString()
            .trim() ??
        '';

    if (
      questionId.isEmpty
    ) {
      _showMessage(
        'Identificativo domanda non valido.',
      );
      return;
    }

    if (
      action ==
      _QuestionAction.edit
    ) {
      await _editQuestion(
        question,
      );
      return;
    }

    if (
      action ==
      _QuestionAction.delete
    ) {
      final bool confirmed =
          await _confirmDelete();

      if (!confirmed) {
        return;
      }
    }

    setState(() {
      _actionRunning =
          true;
    });

    try {
      switch (action) {
        case _QuestionAction.hide:
          await _service.hideQuestion(
            department:
                widget.department,
            course:
                widget.course,
            subject:
                widget.subject,
            questionId:
                questionId,
          );
          break;

        case _QuestionAction.restore:
          await _service.restoreQuestion(
            department:
                widget.department,
            course:
                widget.course,
            subject:
                widget.subject,
            questionId:
                questionId,
          );
          break;

        case _QuestionAction.activate:
          await _service.activateQuestion(
            department:
                widget.department,
            course:
                widget.course,
            subject:
                widget.subject,
            questionId:
                questionId,
          );
          break;

        case _QuestionAction.deactivate:
          await _service.deactivateQuestion(
            department:
                widget.department,
            course:
                widget.course,
            subject:
                widget.subject,
            questionId:
                questionId,
          );
          break;

        case _QuestionAction.delete:
          await _service.deleteQuestion(
            department:
                widget.department,
            course:
                widget.course,
            subject:
                widget.subject,
            questionId:
                questionId,
          );
          break;

        case _QuestionAction.edit:
          break;
      }

      await _loadQuestions();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _friendlyError(
          error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionRunning =
              false;
        });
      }
    }
  }


  Future<bool> _confirmDelete() async {
    final bool? result =
        await showDialog<bool>(
      context:
          context,
      builder:
          (
        BuildContext context,
      ) {
        return AlertDialog(
          backgroundColor:
              AppColors.eleganceDeepNavy,
          title:
              const Text(
            'Eliminare la domanda?',
            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),
          content:
              const Text(
            'La domanda verrà rimossa dal catalogo. Questa azione non modifica gli snapshot dei quiz già completati.',
            style:
                TextStyle(
              color:
                  Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  () =>
                      Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text(
                'Annulla',
              ),
            ),
            FilledButton(
              onPressed:
                  () =>
                      Navigator.pop(
                context,
                true,
              ),
              child:
                  const Text(
                'Elimina',
              ),
            ),
          ],
        );
      },
    );

    return result ??
        false;
  }


  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    )
        .showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),
      ),
    );
  }


  String _friendlyError(
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
        11,
      );
    }

    return message
            .trim()
            .isEmpty
        ? 'Operazione non riuscita.'
        : message.trim();
  }
}


enum _QuestionAction {
  edit,
  hide,
  restore,
  activate,
  deactivate,
  delete,
}


class _QuestionCard
    extends StatelessWidget {
  final Map<String, dynamic> question;
  final VoidCallback onOpen;
  final ValueChanged<_QuestionAction> onAction;

  const _QuestionCard({
    required this.question,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final String questionId =
        question['id_question']
            ?.toString() ??
        '?';

    final String text =
        question['text']
            ?.toString()
            .trim() ??
        '';

    final bool hidden =
        question['is_hidden'] ==
        true;

    final bool active =
        question['is_active'] !=
        false;

    final dynamic metadataRaw =
        question['metadata'];

    final Map<String, dynamic> metadata =
        metadataRaw is Map
            ? Map<String, dynamic>.from(
                metadataRaw,
              )
            : {};

    final String argument =
        metadata['argoment']
            ?.toString()
            .trim() ??
        'Senza argomento';

    final dynamic attachmentsRaw =
        question['attachments'];

    final int attachmentCount =
        attachmentsRaw is List
            ? attachmentsRaw.length
            : 0;

    return Material(
      color:
          Colors.transparent,
      child:
          InkWell(
        onTap:
            onOpen,
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
                AppColors.eleganceDeepNavy,
            borderRadius:
                BorderRadius.circular(
              17,
            ),
            border:
                Border.all(
              color:
                  hidden
                      ? Colors.amber
                          .withValues(
                        alpha:
                            0.24,
                      )
                      : AppColors.skyBlue
                          .withValues(
                        alpha:
                            0.1,
                      ),
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
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal:
                          9,
                      vertical:
                          5,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.brandNightBlue,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child:
                        Text(
                      '#$questionId',
                      style:
                          const TextStyle(
                        color:
                            AppColors.skyBlue,
                        fontSize:
                            11,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _StatusBadge(
                    hidden:
                        hidden,
                    active:
                        active,
                  ),
                  PopupMenuButton<_QuestionAction>(
                    tooltip:
                        'Azioni',
                    color:
                        AppColors.eleganceDeepNavy,
                    icon:
                        const Icon(
                      Icons.more_vert_rounded,
                      color:
                          Colors.white70,
                    ),
                    onSelected:
                        onAction,
                    itemBuilder:
                        (
                      BuildContext context,
                    ) {
                      return [
                        const PopupMenuItem(
                          value:
                              _QuestionAction.edit,
                          child:
                              _MenuItem(
                            icon:
                                Icons.edit_outlined,
                            label:
                                'Modifica',
                          ),
                        ),
                        PopupMenuItem(
                          value:
                              hidden
                                  ? _QuestionAction.restore
                                  : _QuestionAction.hide,
                          child:
                              _MenuItem(
                            icon:
                                hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                            label:
                                hidden
                                    ? 'Ripristina'
                                    : 'Nascondi',
                          ),
                        ),
                        PopupMenuItem(
                          value:
                              active
                                  ? _QuestionAction.deactivate
                                  : _QuestionAction.activate,
                          child:
                              _MenuItem(
                            icon:
                                active
                                    ? Icons.pause_circle_outline_rounded
                                    : Icons.play_circle_outline_rounded,
                            label:
                                active
                                    ? 'Disattiva'
                                    : 'Attiva',
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value:
                              _QuestionAction.delete,
                          child:
                              _MenuItem(
                            icon:
                                Icons.delete_outline_rounded,
                            label:
                                'Elimina',
                            destructive:
                                true,
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(
                height:
                    12,
              ),
              Text(
                text.isEmpty
                    ? 'Domanda senza testo'
                    : text,
                maxLines:
                    3,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color:
                      AppColors.pureWhite,
                  fontSize:
                      15,
                  height:
                      1.35,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(
                height:
                    12,
              ),
              Wrap(
                spacing:
                    8,
                runSpacing:
                    8,
                children: [
                  _InfoChip(
                    icon:
                        Icons.topic_outlined,
                    text:
                        argument,
                  ),
                  if (
                    attachmentCount >
                    0
                  )
                    _InfoChip(
                      icon:
                          Icons.attach_file_rounded,
                      text:
                          '$attachmentCount allegat${attachmentCount == 1 ? 'o' : 'i'}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _StatusBadge
    extends StatelessWidget {
  final bool hidden;
  final bool active;

  const _StatusBadge({
    required this.hidden,
    required this.active,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final String label =
        hidden
            ? 'Nascosta'
            : active
                ? 'Attiva'
                : 'Disattivata';

    final IconData icon =
        hidden
            ? Icons.visibility_off_outlined
            : active
                ? Icons.check_circle_outline_rounded
                : Icons.pause_circle_outline_rounded;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            9,
        vertical:
            5,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.brandNightBlue
                .withValues(
          alpha:
              0.58,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
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
                14,
            color:
                hidden
                    ? Colors.amberAccent
                    : active
                        ? Colors.greenAccent
                        : Colors.white54,
          ),
          const SizedBox(
            width:
                5,
          ),
          Text(
            label,
            style:
                const TextStyle(
              color:
                  AppColors.pureWhite,
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


class _InfoChip
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            9,
        vertical:
            6,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.brandNightBlue
                .withValues(
          alpha:
              0.35,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
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
                14,
            color:
                AppColors.skyBlue,
          ),
          const SizedBox(
            width:
                5,
          ),
          ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  220,
            ),
            child:
                Text(
              text,
              maxLines:
                  1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
                fontSize:
                    10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _FilterChip
    extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ActionChip(
      onPressed:
          onTap,
      avatar:
          Icon(
        icon,
        size:
            18,
        color:
            AppColors.skyBlue,
      ),
      label:
          Text(
        label,
      ),
      backgroundColor:
          AppColors.eleganceDeepNavy,
      side:
          BorderSide(
        color:
            AppColors.skyBlue
                .withValues(
          alpha:
              0.15,
        ),
      ),
      labelStyle:
          const TextStyle(
        color:
            AppColors.pureWhite,
        fontSize:
            12,
      ),
    );
  }
}


class _MenuItem
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size:
              19,
          color:
              destructive
                  ? Colors.redAccent
                  : AppColors.skyBlue,
        ),
        const SizedBox(
          width:
              10,
        ),
        Text(
          label,
          style:
              TextStyle(
            color:
                destructive
                    ? Colors.redAccent
                    : AppColors.pureWhite,
          ),
        ),
      ],
    );
  }
}


class _StateMessage
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          28,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size:
                  52,
              color:
                  AppColors.skyBlue,
            ),
            const SizedBox(
              height:
                  14,
            ),
            Text(
              title,
              textAlign:
                  TextAlign.center,
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
            const SizedBox(
              height:
                  7,
            ),
            Text(
              message,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.white54,
                fontSize:
                    12,
                height:
                    1.35,
              ),
            ),
            if (
              actionLabel != null &&
              onAction != null
            ) ...[
              const SizedBox(
                height:
                    18,
              ),
              FilledButton(
                onPressed:
                    onAction,
                child:
                    Text(
                  actionLabel!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}