import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import 'services/question_management_service.dart';


class QuestionEditorPage extends StatefulWidget {
  final String department;
  final String course;
  final String subject;
  final Map<String, dynamic> metadataBase;
  final Map<String, dynamic>? question;

  const QuestionEditorPage({
    super.key,
    required this.department,
    required this.course,
    required this.subject,
    required this.metadataBase,
    this.question,
  });

  bool get isEditing => question != null;

  @override
  State<QuestionEditorPage> createState() =>
      _QuestionEditorPageState();
}


class _QuestionEditorPageState
    extends State<QuestionEditorPage> {
  final QuestionManagementService _service =
      QuestionManagementService();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _argumentController =
      TextEditingController();

  final TextEditingController _questionController =
      TextEditingController();

  final TextEditingController _estimatedTimeController =
      TextEditingController(
    text: '15',
  );

  final TextEditingController _formalExplanationController =
      TextEditingController();

  final TextEditingController _informalExplanationController =
      TextEditingController();

  final Map<String, TextEditingController>
      _optionControllers = {
    'a': TextEditingController(),
    'b': TextEditingController(),
    'c': TextEditingController(),
    'd': TextEditingController(),
  };

  final Map<String, TextEditingController>
      _answerExplanationControllers = {
    'a': TextEditingController(),
    'b': TextEditingController(),
    'c': TextEditingController(),
    'd': TextEditingController(),
  };

  String _correctOption =
      'a';

  List<Map<String, dynamic>>
      _existingAttachments = [];

  final List<_PendingAttachment>
      _pendingAttachments = [];

  bool _saving =
      false;

  String? _error;


  @override
  void initState() {
    super.initState();
    _loadQuestion();
  }


  void _loadQuestion() {
    final Map<String, dynamic>? question =
        widget.question;

    if (question == null) {
      return;
    }

    final dynamic metadataRaw =
        question['metadata'];

    final Map<String, dynamic> metadata =
        metadataRaw is Map
            ? Map<String, dynamic>.from(
                metadataRaw,
              )
            : {};

    _argumentController.text =
        metadata['argoment']
            ?.toString() ??
        '';

    _questionController.text =
        question['text']
            ?.toString() ??
        '';

    _estimatedTimeController.text =
        question['estimed_time']
            ?.toString() ??
        '15';

    _formalExplanationController.text =
        question['formal_explanation']
            ?.toString() ??
        '';

    _informalExplanationController.text =
        question['informal_explanation']
            ?.toString() ??
        '';

    final dynamic optionsRaw =
        question['option'];

    if (optionsRaw is List) {
      for (final dynamic raw in optionsRaw) {
        if (raw is! Map) {
          continue;
        }

        final String id =
            raw['id']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

        if (
          !_optionControllers
              .containsKey(
            id,
          )
        ) {
          continue;
        }

        _optionControllers[
          id
        ]!.text =
            raw['text']
                ?.toString() ??
            '';
      }
    }

    final String correct =
        question['id_correct']
            ?.toString()
            .trim()
            .toLowerCase() ??
        'a';

    if (
      _optionControllers
          .containsKey(
        correct,
      )
    ) {
      _correctOption =
          correct;
    }

    final dynamic explanationsRaw =
        question[
            'question_response_explanation'];

    if (
      explanationsRaw is Map
    ) {
      for (
        final MapEntry<dynamic, dynamic>
            entry
        in explanationsRaw.entries
      ) {
        final String id =
            entry.key
                .toString()
                .trim()
                .toLowerCase();

        if (
          !_answerExplanationControllers
              .containsKey(
            id,
          )
        ) {
          continue;
        }

        _answerExplanationControllers[
          id
        ]!.text =
            entry.value
                ?.toString() ??
            '';
      }
    } else if (
      explanationsRaw
          is String &&
      explanationsRaw
          .trim()
          .isNotEmpty
    ) {
      _answerExplanationControllers[
        _correctOption
      ]!.text =
          explanationsRaw.trim();
    }

    final dynamic attachmentsRaw =
        question['attachments'];

    if (attachmentsRaw is List) {
      _existingAttachments =
          attachmentsRaw
              .whereType<Map>()
              .map(
                (
                  Map raw,
                ) =>
                    Map<String, dynamic>.from(
                  raw,
                ),
              )
              .toList();
    }
  }


  @override
  void dispose() {
    _argumentController.dispose();
    _questionController.dispose();
    _estimatedTimeController.dispose();
    _formalExplanationController.dispose();
    _informalExplanationController.dispose();

    for (
      final TextEditingController controller
      in _optionControllers.values
    ) {
      controller.dispose();
    }

    for (
      final TextEditingController controller
      in _answerExplanationControllers.values
    ) {
      controller.dispose();
    }

    super.dispose();
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
          widget.isEditing
              ? 'Modifica domanda'
              : 'Nuova domanda',
          style:
              const TextStyle(
            fontSize:
                18,
            fontWeight:
                FontWeight.w600,
          ),
        ),
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
                  820,
            ),
            child:
                Form(
              key:
                  _formKey,
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
                        24,
                  ),
                  _sectionTitle(
                    'Contesto',
                    'Definisci argomento e tempo medio previsto.',
                  ),
                  const SizedBox(
                    height:
                        12,
                  ),
                  _SectionCard(
                    child:
                        Column(
                      children: [
                        _buildTextField(
                          controller:
                              _argumentController,
                          label:
                              'Argomento',
                          hint:
                              'Es. Puntatori',
                          icon:
                              Icons.topic_outlined,
                          required:
                              true,
                        ),
                        const SizedBox(
                          height:
                              16,
                        ),
                        _buildTextField(
                          controller:
                              _estimatedTimeController,
                          label:
                              'Tempo stimato',
                          hint:
                              '15',
                          icon:
                              Icons.timer_outlined,
                          required:
                              true,
                          keyboardType:
                              TextInputType.number,
                          suffixText:
                              'secondi',
                          validator:
                              _validateEstimatedTime,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height:
                        24,
                  ),
                  _sectionTitle(
                    'Domanda',
                    'Scrivi il testo che verrà mostrato allo studente.',
                  ),
                  const SizedBox(
                    height:
                        12,
                  ),
                  _SectionCard(
                    child:
                        _buildTextField(
                      controller:
                          _questionController,
                      label:
                          'Testo della domanda',
                      hint:
                          'Inserisci la domanda...',
                      icon:
                          Icons.quiz_outlined,
                      required:
                          true,
                      minLines:
                          3,
                      maxLines:
                          7,
                    ),
                  ),
                  const SizedBox(
                    height:
                        24,
                  ),
                  _sectionTitle(
                    'Risposte',
                    'Inserisci quattro opzioni e indica quella corretta.',
                  ),
                  const SizedBox(
                    height:
                        12,
                  ),
                  _buildAnswersCard(),
                  const SizedBox(
                    height:
                        24,
                  ),
                  _sectionTitle(
                    'Spiegazioni',
                    'Aggiungi il feedback mostrato dopo la risposta.',
                  ),
                  const SizedBox(
                    height:
                        12,
                  ),
                  _buildExplanationsCard(),
                  const SizedBox(
                    height:
                        24,
                  ),
                  _sectionTitle(
                    'Allegati',
                    'Aggiungi immagini o documenti utili alla domanda.',
                  ),
                  const SizedBox(
                    height:
                        12,
                  ),
                  _buildAttachmentsCard(),
                  if (
                    _error != null
                  ) ...[
                    const SizedBox(
                      height:
                          18,
                    ),
                    _ErrorCard(
                      message:
                          _error!,
                    ),
                  ],
                  const SizedBox(
                    height:
                        28,
                  ),
                  SizedBox(
                    height:
                        54,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          _saving
                              ? null
                              : _save,
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.brandNightBlue,
                        foregroundColor:
                            AppColors.pureWhite,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                      icon:
                          _saving
                              ? const SizedBox(
                                  width:
                                      20,
                                  height:
                                      20,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : const Icon(
                                  Icons.save_outlined,
                                ),
                      label:
                          Text(
                        _saving
                            ? 'Salvataggio...'
                            : widget.isEditing
                                ? 'Salva modifiche'
                                : 'Crea domanda',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height:
                        20,
                  ),
                ],
              ),
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
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withValues(
            alpha:
                0.14,
          ),
        ),
      ),
      child:
          Row(
        children: [
          Container(
            width:
                52,
            height:
                52,
            decoration:
                BoxDecoration(
              color:
                  AppColors.brandNightBlue,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child:
                const Icon(
              Icons.edit_note_rounded,
              color:
                  AppColors.skyBlue,
              size:
                  28,
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
                  widget.subject,
                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,
                    fontSize:
                        17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height:
                      4,
                ),
                Text(
                  '${widget.department} • ${widget.course}',
                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withValues(
                      alpha:
                          0.5,
                    ),
                    fontSize:
                        12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAnswersCard() {
    return _SectionCard(
      child:
          Column(
        children: [
          for (
            final String id
            in const [
              'a',
              'b',
              'c',
              'd',
            ]
          ) ...[
            _AnswerEditor(
              id:
                  id,
              controller:
                  _optionControllers[
                    id
                  ]!,
              selected:
                  _correctOption ==
                      id,
              onSelected:
                  () {
                setState(() {
                  _correctOption =
                      id;
                });
              },
            ),
            if (
              id != 'd'
            )
              const SizedBox(
                height:
                    12,
              ),
          ],
        ],
      ),
    );
  }


  Widget _buildExplanationsCard() {
    return _SectionCard(
      child:
          Column(
        children: [
          _buildTextField(
            controller:
                _formalExplanationController,
            label:
                'Spiegazione formale',
            hint:
                'Spiega in modo rigoroso perché la risposta è corretta...',
            icon:
                Icons.school_outlined,
            minLines:
                3,
            maxLines:
                7,
          ),
          const SizedBox(
            height:
                18,
          ),
          _buildTextField(
            controller:
                _informalExplanationController,
            label:
                'Spiegazione semplice',
            hint:
                'Scrivi una spiegazione più intuitiva...',
            icon:
                Icons.lightbulb_outline_rounded,
            minLines:
                3,
            maxLines:
                6,
          ),
          const SizedBox(
            height:
                22,
          ),
          Align(
            alignment:
                Alignment.centerLeft,
            child:
                Text(
              'Spiegazione per risposta',
              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withValues(
                  alpha:
                      0.82,
                ),
                fontSize:
                    13,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(
            height:
                12,
          ),
          for (
            final String id
            in const [
              'a',
              'b',
              'c',
              'd',
            ]
          ) ...[
            _buildTextField(
              controller:
                  _answerExplanationControllers[
                    id
                  ]!,
              label:
                  'Risposta ${id.toUpperCase()}',
              hint:
                  'Perché questa risposta è corretta o errata...',
              icon:
                  id ==
                          _correctOption
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
              minLines:
                  2,
              maxLines:
                  5,
            ),
            if (
              id != 'd'
            )
              const SizedBox(
                height:
                    12,
              ),
          ],
        ],
      ),
    );
  }


  Widget _buildAttachmentsCard() {
    return _SectionCard(
      child:
          Column(
        children: [
          InkWell(
            onTap:
                _saving
                    ? null
                    : _pickAttachments,
            borderRadius:
                BorderRadius.circular(
              13,
            ),
            child:
                Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                14,
              ),
              decoration:
                  BoxDecoration(
                color:
                    AppColors.brandNightBlue
                        .withValues(
                  alpha:
                      0.5,
                ),
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                border:
                    Border.all(
                  color:
                      AppColors.skyBlue
                          .withValues(
                    alpha:
                        0.14,
                  ),
                ),
              ),
              child:
                  const Row(
                children: [
                  Icon(
                    Icons.attach_file_rounded,
                    color:
                        AppColors.skyBlue,
                  ),
                  SizedBox(
                    width:
                        12,
                  ),
                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aggiungi allegato',
                          style:
                              TextStyle(
                            color:
                                AppColors.pureWhite,
                            fontSize:
                                14,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        SizedBox(
                          height:
                              3,
                        ),
                        Text(
                          'PNG, JPG, WebP, PDF, TXT, DOCX o PPTX · max 50 MB',
                          style:
                              TextStyle(
                            color:
                                Colors.white54,
                            fontSize:
                                11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.add_rounded,
                    color:
                        AppColors.skyBlue,
                  ),
                ],
              ),
            ),
          ),
          if (
            _existingAttachments
                .isNotEmpty ||
            _pendingAttachments
                .isNotEmpty
          ) ...[
            const SizedBox(
              height:
                  14,
            ),
            for (
              final Map<String, dynamic>
                  attachment
              in _existingAttachments
            )
              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom:
                      8,
                ),
                child:
                    _AttachmentTile(
                  name:
                      attachment[
                              'original_name']
                          ?.toString() ??
                      'Allegato',
                  mimeType:
                      attachment[
                              'mime_type']
                          ?.toString() ??
                      '',
                  uploaded:
                      true,
                  onRemove:
                      _saving
                          ? null
                          : () {
                              setState(() {
                                _existingAttachments
                                    .remove(
                                  attachment,
                                );
                              });
                            },
                ),
              ),
            for (
              final _PendingAttachment
                  attachment
              in _pendingAttachments
            )
              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom:
                      8,
                ),
                child:
                    _AttachmentTile(
                  name:
                      attachment.name,
                  mimeType:
                      attachment.extension
                          .toUpperCase(),
                  uploaded:
                      false,
                  onRemove:
                      _saving
                          ? null
                          : () {
                              setState(() {
                                _pendingAttachments
                                    .remove(
                                  attachment,
                                );
                              });
                            },
                ),
              ),
          ],
        ],
      ),
    );
  }


  Widget _sectionTitle(
    String title,
    String description,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
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
              4,
        ),
        Text(
          description,
          style:
              TextStyle(
            color:
                AppColors.pureWhite
                    .withValues(
              alpha:
                  0.5,
            ),
            fontSize:
                12,
          ),
        ),
      ],
    );
  }


  Widget _buildTextField({
    required TextEditingController
        controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? suffixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:
          controller,
      minLines:
          minLines,
      maxLines:
          maxLines,
      keyboardType:
          keyboardType,
      style:
          const TextStyle(
        color:
            AppColors.pureWhite,
        fontSize:
            13,
      ),
      validator:
          validator ??
          (
            String? value,
          ) {
            if (
              required &&
              (
                value == null ||
                value
                    .trim()
                    .isEmpty
              )
            ) {
              return 'Campo obbligatorio.';
            }

            return null;
          },
      decoration:
          InputDecoration(
        labelText:
            required
                ? '$label *'
                : label,
        hintText:
            hint,
        suffixText:
            suffixText,
        prefixIcon:
            Icon(
          icon,
          color:
              AppColors.skyBlue,
        ),
        labelStyle:
            TextStyle(
          color:
              AppColors.pureWhite
                  .withValues(
            alpha:
                0.72,
          ),
        ),
        hintStyle:
            TextStyle(
          color:
              AppColors.pureWhite
                  .withValues(
            alpha:
                0.35,
          ),
        ),
        suffixStyle:
            TextStyle(
          color:
              AppColors.pureWhite
                  .withValues(
            alpha:
                0.45,
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
            12,
          ),
          borderSide:
              BorderSide.none,
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          borderSide:
              BorderSide(
            color:
                AppColors.skyBlue
                    .withValues(
              alpha:
                  0.08,
            ),
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          borderSide:
              BorderSide(
            color:
                AppColors.skyBlue
                    .withValues(
              alpha:
                  0.6,
            ),
          ),
        ),
        errorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          borderSide:
              BorderSide(
            color:
                Colors.redAccent
                    .withValues(
              alpha:
                  0.75,
            ),
          ),
        ),
      ),
    );
  }


  String? _validateEstimatedTime(
    String? value,
  ) {
    final int? seconds =
        int.tryParse(
      value?.trim() ??
          '',
    );

    if (
      seconds == null ||
      seconds <= 0
    ) {
      return 'Inserisci un tempo valido.';
    }

    if (
      seconds > 3600
    ) {
      return 'Il tempo stimato non può superare 3600 secondi.';
    }

    return null;
  }


  Future<void> _pickAttachments() async {
    final FilePickerResult? result =
        await FilePicker.pickFiles(
      allowMultiple:
          true,
      type:
          FileType.custom,
      allowedExtensions:
          const [
        'png',
        'jpg',
        'jpeg',
        'webp',
        'pdf',
        'txt',
        'docx',
        'pptx',
      ],
    );

    if (
      result == null
    ) {
      return;
    }

    final List<_PendingAttachment>
        selected = [];

    for (
      final PlatformFile file
      in result.files
    ) {
      final String? path =
          file.path;

      if (
        path == null ||
        path.trim().isEmpty
      ) {
        continue;
      }

      if (
        file.size >
        50 * 1024 * 1024
      ) {
        if (!mounted) {
          return;
        }

        setState(() {
          _error =
              '${file.name} supera il limite di 50 MB.';
        });

        continue;
      }

      final bool alreadySelected =
          _pendingAttachments.any(
        (
          _PendingAttachment item,
        ) =>
            item.path ==
            path,
      );

      if (
        alreadySelected
      ) {
        continue;
      }

      selected.add(
        _PendingAttachment(
          path:
              path,
          name:
              file.name,
          size:
              file.size,
          extension:
              file.extension ??
              '',
        ),
      );
    }

    if (
      selected.isEmpty
    ) {
      return;
    }

    setState(() {
      _pendingAttachments
          .addAll(
        selected,
      );
      _error =
          null;
    });
  }


  Map<String, dynamic> _buildPayload() {
    final Map<String, dynamic> metadata =
        Map<String, dynamic>.from(
      widget.metadataBase,
    );

    if (
      widget.question?[
          'metadata'] is Map
    ) {
      metadata.addAll(
        Map<String, dynamic>.from(
          widget.question![
              'metadata'] as Map,
        ),
      );
    }

    metadata[
      'argoment'
    ] =
        _argumentController.text
            .trim();

    final List<Map<String, String>>
        options =
        const [
      'a',
      'b',
      'c',
      'd',
    ]
            .map(
              (
                String id,
              ) =>
                  {
                'id':
                    id,
                'text':
                    _optionControllers[
                      id
                    ]!
                        .text
                        .trim(),
              },
            )
            .toList();

    final Map<String, String>
        answerExplanations = {
      for (
        final String id
        in const [
          'a',
          'b',
          'c',
          'd',
        ]
      )
        id:
            _answerExplanationControllers[
              id
            ]!
                .text
                .trim(),
    };

    return {
      'estimed_time':
          int.parse(
        _estimatedTimeController
            .text
            .trim(),
      ),
      'metadata':
          metadata,
      'text':
          _questionController
              .text
              .trim(),
      'option':
          options,
      'id_correct':
          _correctOption,
      'formal_explanation':
          _formalExplanationController
              .text
              .trim(),
      'informal_explanation':
          _informalExplanationController
              .text
              .trim(),
      'question_response_explanation':
          answerExplanations,
    };
  }


  bool _validateAnswers() {
    for (
      final MapEntry<String,
              TextEditingController>
          entry
      in _optionControllers.entries
    ) {
      if (
        entry.value.text
            .trim()
            .isEmpty
      ) {
        setState(() {
          _error =
              'Inserisci il testo della risposta ${entry.key.toUpperCase()}.';
        });

        return false;
      }
    }

    return true;
  }


  Future<void> _save() async {
    FocusScope.of(
      context,
    ).unfocus();

    setState(() {
      _error =
          null;
    });

    if (
      !(
        _formKey.currentState
                ?.validate() ??
            false
      )
    ) {
      return;
    }

    if (
      !_validateAnswers()
    ) {
      return;
    }

    setState(() {
      _saving =
          true;
    });

    try {
      final Map<String, dynamic>
          payload =
          _buildPayload();

      final List<String>
          pendingPaths =
          _pendingAttachments
              .map(
                (
                  _PendingAttachment
                      attachment,
                ) =>
                    attachment.path,
              )
              .toList();

      late final Map<String, dynamic>
          saved;

      if (
        widget.isEditing
      ) {
        final String questionId =
            widget.question![
                    'id_question']
                ?.toString()
                .trim() ??
            '';

        if (
          questionId.isEmpty
        ) {
          throw Exception(
            'Identificativo domanda non valido.',
          );
        }

        saved =
            await _service
                .saveExistingQuestionWithAttachments(
          department:
              widget.department,
          course:
              widget.course,
          subject:
              widget.subject,
          questionId:
              questionId,
          data:
              payload,
          existingAttachments:
              _existingAttachments,
          newAttachmentFilePaths:
              pendingPaths,
        );
      } else {
        saved =
            await _service
                .saveNewQuestionWithAttachments(
          department:
              widget.department,
          course:
              widget.course,
          subject:
              widget.subject,
          data:
              payload,
          attachmentFilePaths:
              pendingPaths,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        saved,
      );
    } catch (
      error
    ) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _friendlyError(
          error,
        );
      });
    } finally {
      if (
        mounted
      ) {
        setState(() {
          _saving =
              false;
        });
      }
    }
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

    if (
      message.trim().isEmpty
    ) {
      return 'Non è stato possibile salvare la domanda.';
    }

    return message.trim();
  }
}


class _SectionCard
    extends StatelessWidget {
  final Widget child;

  const _SectionCard({
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
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
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withValues(
            alpha:
                0.1,
          ),
        ),
      ),
      child:
          child,
    );
  }
}


class _AnswerEditor
    extends StatelessWidget {
  final String id;
  final TextEditingController controller;
  final bool selected;
  final VoidCallback onSelected;

  const _AnswerEditor({
    required this.id,
    required this.controller,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.brandNightBlue
                .withValues(
          alpha:
              selected
                  ? 0.72
                  : 0.38,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        border:
            Border.all(
          color:
              selected
                  ? AppColors.skyBlue
                      .withValues(
                    alpha:
                        0.55,
                  )
                  : AppColors.skyBlue
                      .withValues(
                    alpha:
                        0.08,
                  ),
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap:
                onSelected,
            borderRadius:
                BorderRadius.circular(
              30,
            ),
            child:
                Padding(
              padding:
                  const EdgeInsets.all(
                4,
              ),
              child:
                  Radio<String>(
                value:
                    id,
                groupValue:
                    selected
                        ? id
                        : '',
                onChanged:
                    (_) =>
                        onSelected(),
                activeColor:
                    AppColors.skyBlue,
              ),
            ),
          ),
          const SizedBox(
            width:
                6,
          ),
          Expanded(
            child:
                TextFormField(
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
                fontSize:
                    13,
              ),
              validator:
                  (
                String? value,
              ) {
                if (
                  value == null ||
                  value
                      .trim()
                      .isEmpty
                ) {
                  return 'Risposta obbligatoria.';
                }

                return null;
              },
              decoration:
                  InputDecoration(
                labelText:
                    'Risposta ${id.toUpperCase()}',
                hintText:
                    'Inserisci il testo...',
                labelStyle:
                    TextStyle(
                  color:
                      AppColors.pureWhite
                          .withValues(
                    alpha:
                        0.7,
                  ),
                ),
                hintStyle:
                    TextStyle(
                  color:
                      AppColors.pureWhite
                          .withValues(
                    alpha:
                        0.3,
                  ),
                ),
                filled:
                    true,
                fillColor:
                    AppColors.darkElegance
                        .withValues(
                  alpha:
                      0.42,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _AttachmentTile
    extends StatelessWidget {
  final String name;
  final String mimeType;
  final bool uploaded;
  final VoidCallback? onRemove;

  const _AttachmentTile({
    required this.name,
    required this.mimeType,
    required this.uploaded,
    required this.onRemove,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool image =
        mimeType
            .toLowerCase()
            .startsWith(
          'image/',
        ) ||
        [
          'PNG',
          'JPG',
          'JPEG',
          'WEBP',
        ].contains(
          mimeType
              .toUpperCase(),
        );

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            12,
        vertical:
            10,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.brandNightBlue
                .withValues(
          alpha:
              0.34,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child:
          Row(
        children: [
          Icon(
            image
                ? Icons.image_outlined
                : Icons.description_outlined,
            color:
                AppColors.skyBlue,
          ),
          const SizedBox(
            width:
                11,
          ),
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,
                    fontSize:
                        13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height:
                      2,
                ),
                Text(
                  uploaded
                      ? 'Già collegato alla domanda'
                      : 'Verrà caricato al salvataggio',
                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withValues(
                      alpha:
                          0.44,
                    ),
                    fontSize:
                        10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip:
                'Rimuovi',
            onPressed:
                onRemove,
            icon:
                const Icon(
              Icons.close_rounded,
              color:
                  Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}


class _PendingAttachment {
  final String path;
  final String name;
  final int size;
  final String extension;

  const _PendingAttachment({
    required this.path,
    required this.name,
    required this.size,
    required this.extension,
  });
}


class _ErrorCard
    extends StatelessWidget {
  final String message;

  const _ErrorCard({
    required this.message,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.redAccent
                .withValues(
          alpha:
              0.1,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        border:
            Border.all(
          color:
              Colors.redAccent
                  .withValues(
            alpha:
                0.28,
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
          ),
          const SizedBox(
            width:
                10,
          ),
          Expanded(
            child:
                Text(
              message,
              style:
                  const TextStyle(
                color:
                    AppColors.pureWhite,
                fontSize:
                    12,
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