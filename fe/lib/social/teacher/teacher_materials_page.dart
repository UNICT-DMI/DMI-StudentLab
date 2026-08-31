import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';
import 'teacher_material_form_page.dart';


class TeacherMaterialsPage
    extends StatefulWidget {
  const TeacherMaterialsPage({
    super.key,
  });

  @override
  State<TeacherMaterialsPage> createState() =>
      _TeacherMaterialsPageState();
}


class _TeacherMaterialsPageState
    extends State<TeacherMaterialsPage> {
  final ApiService _apiService =
      ApiService();

  bool _loading =
      true;

  bool _authorized =
      false;

  bool _busy =
      false;

  String? _error;

  List<Map<String, dynamic>>
      _materials =
      [];

  List<Map<String, dynamic>>
      _subjects =
      [];

  int? _selectedSubjectId;

  String _searchQuery =
      '';


  @override
  void initState() {
    super.initState();

    _initialize();
  }


  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _loading =
            true;

        _error =
            null;
      });
    }

    try {
      final bool authorized =
          await _apiService
              .canAccessTeacherArea();

      if (!mounted) {
        return;
      }

      if (!authorized) {
        setState(() {
          _authorized =
              false;

          _loading =
              false;
        });

        return;
      }

      final List<dynamic> result =
          await Future.wait([
        _apiService
            .getTeacherSubjects(),

        _apiService
            .getTeacherMaterials(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _authorized =
            true;

        _subjects =
            List<
                Map<String, dynamic>>.from(
          result[0]
              as List<
                  Map<String, dynamic>>,
        );

        _materials =
            List<
                Map<String, dynamic>>.from(
          result[1]
              as List<
                  Map<String, dynamic>>,
        );

        _loading =
            false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authorized =
            false;

        _loading =
            false;

        _error =
            _friendlyError(e);
      });
    }
  }


  Future<bool>
      _verifyAccess() async {
    try {
      final bool authorized =
          await _apiService
              .canAccessTeacherArea();

      if (!mounted) {
        return false;
      }

      if (!authorized) {
        setState(() {
          _authorized =
              false;
        });

        return false;
      }

      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      _showMessage(
        'Impossibile verificare i permessi docente.',
      );

      return false;
    }
  }


  Future<void> _refresh() async {
    if (_busy) {
      return;
    }

    final bool authorized =
        await _verifyAccess();

    if (!authorized) {
      return;
    }

    setState(() {
      _busy =
          true;

      _error =
          null;
    });

    try {
      final List<dynamic> result =
          await Future.wait([
        _apiService
            .getTeacherSubjects(),

        _apiService
            .getTeacherMaterials(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _subjects =
            List<
                Map<String, dynamic>>.from(
          result[0]
              as List<
                  Map<String, dynamic>>,
        );

        _materials =
            List<
                Map<String, dynamic>>.from(
          result[1]
              as List<
                  Map<String, dynamic>>,
        );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _friendlyError(e);
      });

      _showMessage(
        'Errore durante l\'aggiornamento dei materiali.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy =
              false;
        });
      }
    }
  }


  List<Map<String, dynamic>>
      get _filteredMaterials {
    Iterable<Map<String, dynamic>>
        result =
        _materials;

    if (_selectedSubjectId != null) {
      result =
          result.where(
        (
          Map<String, dynamic>
              material,
        ) {
          return _toInt(
                material[
                    'subject_id'],
              ) ==
              _selectedSubjectId;
        },
      );
    }

    final String query =
        _searchQuery
            .trim()
            .toLowerCase();

    if (query.isNotEmpty) {
      result =
          result.where(
        (
          Map<String, dynamic>
              material,
        ) {
          final String title =
              material['title']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          final String description =
              material['description']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          final String originalName =
              material[
                          'original_name']
                      ?.toString()
                      .toLowerCase() ??
                  '';

          final String subjectName =
              _subjectName(
            _toInt(
              material[
                  'subject_id'],
            ),
          ).toLowerCase();

          return title.contains(
                query,
              ) ||
              description.contains(
                query,
              ) ||
              originalName.contains(
                query,
              ) ||
              subjectName.contains(
                query,
              );
        },
      );
    }

    return result.toList();
  }


  Future<void> _editMaterial(
    Map<String, dynamic> material,
  ) async {
    final bool authorized =
        await _verifyAccess();

    if (!authorized) {
      return;
    }

    final int? materialId =
        _toInt(
      material['id'],
    );

    if (materialId == null) {
      return;
    }

    final TextEditingController
        titleController =
        TextEditingController(
      text:
          material['title']
                  ?.toString() ??
              '',
    );

    final TextEditingController
        descriptionController =
        TextEditingController(
      text:
          material['description']
                  ?.toString() ??
              '',
    );

    String visibility =
        material['visibility']
                ?.toString()
                .trim()
                .toLowerCase() ??
            'students';

    if (
      visibility != 'students' &&
      visibility != 'private'
    ) {
      visibility =
          'students';
    }

    bool isActive =
        _toBool(
              material[
                  'is_active'],
            ) ??
            true;

    final bool? saved =
        await showDialog<bool>(
      context:
          context,

      builder:
          (
        BuildContext dialogContext,
      ) {
        return StatefulBuilder(
          builder:
              (
            BuildContext context,
            void Function(
              void Function(),
            )
                setDialogState,
          ) {
            return AlertDialog(
              backgroundColor:
                  AppColors
                      .eleganceDeepNavy,

              title:
                  const Text(
                'Modifica materiale',

                style:
                    TextStyle(
                  color:
                      AppColors
                          .pureWhite,
                ),
              ),

              content:
                  SizedBox(
                width:
                    480,

                child:
                    SingleChildScrollView(
                  child:
                      Column(
                    mainAxisSize:
                        MainAxisSize.min,

                    children: [
                      TextField(
                        controller:
                            titleController,

                        style:
                            const TextStyle(
                          color:
                              AppColors
                                  .pureWhite,
                        ),

                        decoration:
                            _inputDecoration(
                          label:
                              'Titolo',
                        ),
                      ),

                      const SizedBox(
                        height:
                            14,
                      ),

                      TextField(
                        controller:
                            descriptionController,

                        minLines:
                            3,

                        maxLines:
                            6,

                        style:
                            const TextStyle(
                          color:
                              AppColors
                                  .pureWhite,
                        ),

                        decoration:
                            _inputDecoration(
                          label:
                              'Descrizione',
                        ),
                      ),

                      const SizedBox(
                        height:
                            16,
                      ),

                      DropdownButtonFormField<
                          String>(
                        value:
                            visibility,

                        dropdownColor:
                            AppColors
                                .eleganceDeepNavy,

                        style:
                            const TextStyle(
                          color:
                              AppColors
                                  .pureWhite,
                        ),

                        decoration:
                            _inputDecoration(
                          label:
                              'Visibilità',
                        ),

                        items:
                            const [
                          DropdownMenuItem<
                              String>(
                            value:
                                'students',

                            child:
                                Text(
                              'Studenti',
                            ),
                          ),

                          DropdownMenuItem<
                              String>(
                            value:
                                'private',

                            child:
                                Text(
                              'Privato',
                            ),
                          ),
                        ],

                        onChanged:
                            (
                          String? value,
                        ) {
                          if (
                            value ==
                            null
                          ) {
                            return;
                          }

                          setDialogState(
                            () {
                              visibility =
                                  value;
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      SwitchListTile(
                        contentPadding:
                            EdgeInsets.zero,

                        title:
                            const Text(
                          'Materiale attivo',

                          style:
                              TextStyle(
                            color:
                                AppColors
                                    .pureWhite,
                          ),
                        ),

                        subtitle:
                            const Text(
                          'Se disattivato non sarà disponibile agli studenti.',

                          style:
                              TextStyle(
                            color:
                                Colors
                                    .white54,

                            fontSize:
                                10,
                          ),
                        ),

                        value:
                            isActive,

                        activeColor:
                            AppColors
                                .teacherIndigo,

                        onChanged:
                            (
                          bool value,
                        ) {
                          setDialogState(
                            () {
                              isActive =
                                  value;
                            },
                          );
                        },
                      ),
                    ],
                  ),
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

                FilledButton(
                  onPressed:
                      () {
                    if (
                      titleController
                          .text
                          .trim()
                          .isEmpty
                    ) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },

                  child:
                      const Text(
                    'Salva',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      titleController.dispose();

      descriptionController.dispose();

      return;
    }

    if (!mounted) {
      titleController.dispose();

      descriptionController.dispose();

      return;
    }

    setState(() {
      _busy =
          true;
    });

    try {
      final Map<String, dynamic>
          updated =
          await _apiService
              .updateTeacherMaterial(
        materialId:
            materialId,

        title:
            titleController
                .text
                .trim(),

        description:
            descriptionController
                .text
                .trim(),

        visibility:
            visibility,

        isActive:
            isActive,
      );

      if (!mounted) {
        return;
      }

      final int index =
          _materials.indexWhere(
        (
          Map<String, dynamic>
              item,
        ) =>
            _toInt(
              item['id'],
            ) ==
            materialId,
      );

      if (index >= 0) {
        setState(() {
          _materials[index] =
              updated;
        });
      } else {
        await _refresh();
      }

      _showMessage(
        'Materiale aggiornato.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Errore aggiornamento materiale: $e',
      );
    } finally {
      titleController.dispose();

      descriptionController.dispose();

      if (mounted) {
        setState(() {
          _busy =
              false;
        });
      }
    }
  }


  Future<void> _deleteMaterial(
    Map<String, dynamic> material,
  ) async {
    final bool authorized =
        await _verifyAccess();

    if (!authorized) {
      return;
    }

    final int? materialId =
        _toInt(
      material['id'],
    );

    if (materialId == null) {
      return;
    }

    final String title =
        material['title']
                ?.toString()
                .trim() ??
            '';

    final bool? confirmed =
        await showDialog<bool>(
      context:
          context,

      builder:
          (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              AppColors
                  .eleganceDeepNavy,

          title:
              const Text(
            'Elimina materiale',

            style:
                TextStyle(
              color:
                  AppColors
                      .pureWhite,
            ),
          ),

          content:
              Text(
            title.isEmpty
                ? 'Vuoi eliminare definitivamente questo materiale?'
                : 'Vuoi eliminare definitivamente "$title"?',

            style:
                const TextStyle(
              color:
                  Colors.white70,
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
                  const Text(
                'Elimina',

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

    if (confirmed != true) {
      return;
    }

    setState(() {
      _busy =
          true;
    });

    try {
      await _apiService
          .deleteTeacherMaterial(
        materialId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _materials.removeWhere(
          (
            Map<String, dynamic>
                item,
          ) =>
              _toInt(
                item['id'],
              ) ==
              materialId,
        );
      });

      _showMessage(
        'Materiale eliminato.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Errore eliminazione materiale: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy =
              false;
        });
      }
    }
  }


Future<void> _openUpload() async {
  final bool authorized =
      await _verifyAccess();

  if (!authorized) {
    return;
  }

  if (!mounted) {
    return;
  }
final bool? created =
      await Navigator.of(
    context,
  ).push<bool>(
    MaterialPageRoute(
      builder:
          (_) =>
              TeacherMaterialFormPage(initialSubjects: _subjects),
    ),
  );

  if (
    !mounted ||
    created != true
  ) {
    return;
  }

  await _refresh();

  if (!mounted) {
    return;
  }

  _showMessage(
    'Materiale caricato correttamente.',
  );
}


  String _subjectName(
    int? subjectId,
  ) {
    if (subjectId == null) {
      return 'Materia';
    }

    for (
      final Map<String, dynamic>
          subject
      in _subjects
    ) {
      if (
        _toInt(
          subject['id'],
        ) ==
        subjectId
      ) {
        final String name =
            subject['name']
                    ?.toString()
                    .trim() ??
                '';

        if (name.isNotEmpty) {
          return name;
        }
      }
    }

    return 'Materia #$subjectId';
  }


  String _subjectCode(
    int? subjectId,
  ) {
    if (subjectId == null) {
      return '';
    }

    for (
      final Map<String, dynamic>
          subject
      in _subjects
    ) {
      if (
        _toInt(
          subject['id'],
        ) ==
        subjectId
      ) {
        return subject['code']
                ?.toString()
                .trim() ??
            '';
      }
    }

    return '';
  }


  String _formatFileSize(
    int size,
  ) {
    if (size < 1024) {
      return '$size B';
    }

    if (
      size <
      1024 * 1024
    ) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }

    if (
      size <
      1024 * 1024 * 1024
    ) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }


  String _formatDate(
    dynamic value,
  ) {
    final DateTime? date =
        DateTime.tryParse(
      value?.toString() ??
          '',
    );

    if (date == null) {
      return '';
    }

    final DateTime local =
        date.toLocal();

    final String day =
        local.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String month =
        local.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String year =
        local.year
            .toString();

    return '$day/$month/$year';
  }


  IconData _fileIcon(
    String fileName,
  ) {
    final String lower =
        fileName
            .toLowerCase();

    if (
      lower.endsWith(
        '.pdf',
      )
    ) {
      return Icons
          .picture_as_pdf_outlined;
    }

    if (
      lower.endsWith(
        '.doc',
      ) ||
      lower.endsWith(
        '.docx',
      )
    ) {
      return Icons
          .description_outlined;
    }

    if (
      lower.endsWith(
        '.ppt',
      ) ||
      lower.endsWith(
        '.pptx',
      )
    ) {
      return Icons
          .slideshow_outlined;
    }

    if (
      lower.endsWith(
        '.xls',
      ) ||
      lower.endsWith(
        '.xlsx',
      ) ||
      lower.endsWith(
        '.csv',
      )
    ) {
      return Icons
          .table_chart_outlined;
    }

    if (
      lower.endsWith(
        '.zip',
      )
    ) {
      return Icons
          .folder_zip_outlined;
    }

    if (
      lower.endsWith(
        '.png',
      ) ||
      lower.endsWith(
        '.jpg',
      ) ||
      lower.endsWith(
        '.jpeg',
      ) ||
      lower.endsWith(
        '.webp',
      )
    ) {
      return Icons
          .image_outlined;
    }

    return Icons
        .insert_drive_file_outlined;
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return const Scaffold(
        backgroundColor:
            AppColors.darkElegance,

        body:
            Center(
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              CircularProgressIndicator(
                color:
                    AppColors
                        .teacherIndigo,
              ),

              SizedBox(
                height:
                    16,
              ),

              Text(
                'Caricamento materiali...',

                style:
                    TextStyle(
                  color:
                      Colors.white60,

                  fontSize:
                      12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_authorized) {
      return Scaffold(
        backgroundColor:
            AppColors.darkElegance,

        appBar:
            AppBar(
          backgroundColor:
              AppColors
                  .brandNightBlue,

          foregroundColor:
              AppColors
                  .pureWhite,

          title:
              const Text(
            'Materiali Docente',
          ),
        ),

        body:
            Center(
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              24,
            ),

            child:
                ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth:
                    460,
              ),

              child:
                  Container(
                width:
                    double.infinity,

                padding:
                    const EdgeInsets.all(
                  26,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .eleganceMidnight,

                  borderRadius:
                      BorderRadius.circular(
                    20,
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
                      Icons
                          .gpp_bad_outlined,

                      color:
                          Colors.redAccent,

                      size:
                          46,
                    ),

                    const SizedBox(
                      height:
                          16,
                    ),

                    const Text(
                      'Accesso non autorizzato',

                      textAlign:
                          TextAlign.center,

                      style:
                          TextStyle(
                        color:
                            AppColors
                                .pureWhite,

                        fontSize:
                            19,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                          9,
                    ),

                    const Text(
                      'Solo i docenti verificati e attivi possono gestire i materiali.',

                      textAlign:
                          TextAlign.center,

                      style:
                          TextStyle(
                        color:
                            Colors.white54,

                        fontSize:
                            11,

                        height:
                            1.4,
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(
                        height:
                            10,
                      ),

                      Text(
                        _error!,

                        textAlign:
                            TextAlign.center,

                        style:
                            const TextStyle(
                          color:
                              Colors.white30,

                          fontSize:
                              9,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height:
                          18,
                    ),

                    OutlinedButton.icon(
                      onPressed:
                          _initialize,

                      icon:
                          const Icon(
                        Icons
                            .refresh_rounded,
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
          ),
        ),
      );
    }

    final List<
        Map<String, dynamic>>
        materials =
        _filteredMaterials;

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
          'Materiali Docente',

          style:
              TextStyle(
            fontSize:
                18,

            fontWeight:
                FontWeight.w500,
          ),
        ),

        actions: [
          if (_busy)
            const Padding(
              padding:
                  EdgeInsets.only(
                right:
                    14,
              ),

              child:
                  Center(
                child:
                    SizedBox(
                  width:
                      18,

                  height:
                      18,

                  child:
                      CircularProgressIndicator(
                    strokeWidth:
                        2,

                    color:
                        AppColors
                            .teacherIndigo,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip:
                  'Aggiorna',

              onPressed:
                  _refresh,

              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
              ),
            ),
        ],
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _busy
                ? null
                : _openUpload,

        backgroundColor:
            AppColors
                .teacherIndigo,

        foregroundColor:
            AppColors
                .pureWhite,

        icon:
            const Icon(
          Icons
              .upload_file_outlined,
        ),

        label:
            const Text(
          'Carica',
        ),
      ),

      body:
          RefreshIndicator(
        onRefresh:
            _refresh,

        child:
            CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          slivers: [
            SliverToBoxAdapter(
              child:
                  Center(
                child:
                    ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth:
                        1000,
                  ),

                  child:
                      Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      12,
                    ),

                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        _buildHeader(),

                        const SizedBox(
                          height:
                              20,
                        ),

                        _buildFilters(),

                        if (_error !=
                            null) ...[
                          const SizedBox(
                            height:
                                12,
                          ),

                          _buildError(),
                        ],

                        const SizedBox(
                          height:
                              10,
                        ),

                        Row(
                          children: [
                            Text(
                              '${materials.length} material${materials.length == 1 ? 'e' : 'i'}',

                              style:
                                  const TextStyle(
                                color:
                                    AppColors
                                        .pureWhite,

                                fontSize:
                                    13,

                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),

                            const Spacer(),

                            Text(
                              '${_materials.length} totali',

                              style:
                                  const TextStyle(
                                color:
                                    Colors.white38,

                                fontSize:
                                    10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (materials.isEmpty)
              SliverFillRemaining(
                hasScrollBody:
                    false,

                child:
                    _buildEmpty(),
              )
            else
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  100,
                ),

                sliver:
                    SliverList(
                  delegate:
                      SliverChildBuilderDelegate(
                    (
                      BuildContext context,
                      int index,
                    ) {
                      final Map<
                              String,
                              dynamic>
                          material =
                          materials[
                              index];

                      return Center(
                        child:
                            ConstrainedBox(
                          constraints:
                              const BoxConstraints(
                            maxWidth:
                                1000,
                          ),

                          child:
                              Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom:
                                  12,
                            ),

                            child:
                                _buildMaterialCard(
                              material,
                            ),
                          ),
                        ),
                      );
                    },

                    childCount:
                        materials.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader() {
    final int activeCount =
        _materials
            .where(
              (
                Map<String, dynamic>
                    material,
              ) =>
                  _toBool(
                    material[
                        'is_active'],
                  ) ??
                  true,
            )
            .length;

    final int publicCount =
        _materials
            .where(
              (
                Map<String, dynamic>
                    material,
              ) =>
                  material[
                              'visibility']
                          ?.toString()
                          .toLowerCase() ==
                      'students',
            )
            .length;

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        20,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors
                .eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              AppColors
                  .teacherIndigo
                  .withOpacity(
                0.20,
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
              Container(
                width:
                    52,

                height:
                    52,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .teacherIndigo
                          .withOpacity(
                        0.14,
                      ),

                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .folder_copy_outlined,

                  color:
                      AppColors
                          .teacherIndigo,

                  size:
                      27,
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
                    const Text(
                      'I tuoi materiali',

                      style:
                          TextStyle(
                        color:
                            AppColors
                                .pureWhite,

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
                      'Gestisci i contenuti associati alle tue materie.',

                      style:
                          TextStyle(
                        color:
                            AppColors
                                .pureWhite
                                .withOpacity(
                              0.48,
                            ),

                        fontSize:
                            10,

                        height:
                            1.4,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
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
                      Colors.greenAccent
                          .withOpacity(
                    0.08,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),

                child:
                    const Row(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    Icon(
                      Icons
                          .verified_user_outlined,

                      color:
                          Colors.greenAccent,

                      size:
                          12,
                    ),

                    SizedBox(
                      width:
                          5,
                    ),

                    Text(
                      'Accesso verificato',

                      style:
                          TextStyle(
                        color:
                            Colors.greenAccent,

                        fontSize:
                            8,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                18,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _TeacherMaterialStat(
                  label:
                      'Totali',

                  value:
                      _materials.length
                          .toString(),

                  icon:
                      Icons
                          .folder_outlined,
                ),
              ),

              const SizedBox(
                width:
                    8,
              ),

              Expanded(
                child:
                    _TeacherMaterialStat(
                  label:
                      'Attivi',

                  value:
                      activeCount
                          .toString(),

                  icon:
                      Icons
                          .check_circle_outline,
                ),
              ),

              const SizedBox(
                width:
                    8,
              ),

              Expanded(
                child:
                    _TeacherMaterialStat(
                  label:
                      'Studenti',

                  value:
                      publicCount
                          .toString(),

                  icon:
                      Icons
                          .groups_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildFilters() {
    return Column(
      children: [
        TextField(
          style:
              const TextStyle(
            color:
                AppColors
                    .pureWhite,

            fontSize:
                12,
          ),

          onChanged:
              (
            String value,
          ) {
            setState(() {
              _searchQuery =
                  value;
            });
          },

          decoration:
              InputDecoration(
            hintText:
                'Cerca materiale...',

            hintStyle:
                const TextStyle(
              color:
                  Colors.white38,

              fontSize:
                  11,
            ),

            prefixIcon:
                const Icon(
              Icons
                  .search_rounded,

              color:
                  Colors.white38,

              size:
                  20,
            ),

            filled:
                true,

            fillColor:
                AppColors
                    .eleganceMidnight,

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                13,
              ),

              borderSide:
                  BorderSide(
                color:
                    AppColors
                        .pureWhite
                        .withOpacity(
                      0.07,
                    ),
              ),
            ),

            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                13,
              ),

              borderSide:
                  const BorderSide(
                color:
                    AppColors
                        .teacherIndigo,
              ),
            ),
          ),
        ),

        const SizedBox(
          height:
              10,
        ),

        SizedBox(
          height:
              38,

          child:
              ListView(
            scrollDirection:
                Axis.horizontal,

            children: [
              _FilterChipButton(
                text:
                    'Tutte',

                selected:
                    _selectedSubjectId ==
                        null,

                onTap:
                    () {
                  setState(() {
                    _selectedSubjectId =
                        null;
                  });
                },
              ),

              const SizedBox(
                width:
                    7,
              ),

              ..._subjects.map(
                (
                  Map<String, dynamic>
                      subject,
                ) {
                  final int? subjectId =
                      _toInt(
                    subject['id'],
                  );

                  final String name =
                      subject['name']
                              ?.toString() ??
                          'Materia';

                  return Padding(
                    padding:
                        const EdgeInsets.only(
                      right:
                          7,
                    ),

                    child:
                        _FilterChipButton(
                      text:
                          name,

                      selected:
                          subjectId !=
                                  null &&
                              _selectedSubjectId ==
                                  subjectId,

                      onTap:
                          () {
                        setState(() {
                          _selectedSubjectId =
                              subjectId;
                        });
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildMaterialCard(
    Map<String, dynamic> material,
  ) {
    final int? subjectId =
        _toInt(
      material['subject_id'],
    );

    final String title =
        material['title']
                ?.toString()
                .trim() ??
            '';

    final String description =
        material['description']
                ?.toString()
                .trim() ??
            '';

    final String originalName =
        material['original_name']
                ?.toString()
                .trim() ??
            '';

    final String visibility =
        material['visibility']
                ?.toString()
                .trim()
                .toLowerCase() ??
            'students';

    final bool isActive =
        _toBool(
              material[
                  'is_active'],
            ) ??
            true;

    final int size =
        _toInt(
              material['size'],
            ) ??
            0;

    final String subject =
        _subjectName(
      subjectId,
    );

    final String code =
        _subjectCode(
      subjectId,
    );

    final String createdAt =
        _formatDate(
      material['created_at'],
    );

    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors
                .eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          17,
        ),

        border:
            Border.all(
          color:
              isActive
                  ? AppColors
                      .teacherIndigo
                      .withOpacity(
                        0.14,
                      )
                  : Colors.white
                      .withOpacity(
                        0.05,
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
                50,

            height:
                50,

            decoration:
                BoxDecoration(
              color:
                  AppColors
                      .teacherIndigo
                      .withOpacity(
                    isActive
                        ? 0.13
                        : 0.05,
                  ),

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),

            child:
                Icon(
              _fileIcon(
                originalName,
              ),

              color:
                  isActive
                      ? AppColors
                          .teacherIndigo
                      : Colors.white24,

              size:
                  25,
            ),
          ),

          const SizedBox(
            width:
                13,
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
                            ? originalName
                            : title,

                        maxLines:
                            1,

                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            TextStyle(
                          color:
                              isActive
                                  ? AppColors
                                      .pureWhite
                                  : Colors
                                      .white38,

                          fontSize:
                              14,

                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),

                    PopupMenuButton<
                        String>(
                      color:
                          AppColors
                              .eleganceDeepNavy,

                      icon:
                          const Icon(
                        Icons
                            .more_vert_rounded,

                        color:
                            Colors.white54,
                      ),

                      onSelected:
                          (
                        String value,
                      ) {
                        if (
                          value ==
                          'edit'
                        ) {
                          _editMaterial(
                            material,
                          );
                        }

                        if (
                          value ==
                          'delete'
                        ) {
                          _deleteMaterial(
                            material,
                          );
                        }
                      },

                      itemBuilder:
                          (
                        BuildContext
                            context,
                      ) {
                        return const [
                          PopupMenuItem<
                              String>(
                            value:
                                'edit',

                            child:
                                Row(
                              children: [
                                Icon(
                                  Icons
                                      .edit_outlined,

                                  color:
                                      AppColors
                                          .skyBlue,

                                  size:
                                      18,
                                ),

                                SizedBox(
                                  width:
                                      10,
                                ),

                                Text(
                                  'Modifica',

                                  style:
                                      TextStyle(
                                    color:
                                        AppColors
                                            .pureWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          PopupMenuItem<
                              String>(
                            value:
                                'delete',

                            child:
                                Row(
                              children: [
                                Icon(
                                  Icons
                                      .delete_outline_rounded,

                                  color:
                                      Colors
                                          .redAccent,

                                  size:
                                      18,
                                ),

                                SizedBox(
                                  width:
                                      10,
                                ),

                                Text(
                                  'Elimina',

                                  style:
                                      TextStyle(
                                    color:
                                        Colors
                                            .redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                      4,
                ),

                Row(
                  children: [
                    Flexible(
                      child:
                          Text(
                        code.isEmpty
                            ? subject
                            : '$code · $subject',

                        maxLines:
                            1,

                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            const TextStyle(
                          color:
                              AppColors
                                  .materialSky,

                          fontSize:
                              9,

                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),
                  ],
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(
                    height:
                        8,
                  ),

                  Text(
                    description,

                    maxLines:
                        3,

                    overflow:
                        TextOverflow
                            .ellipsis,

                    style:
                        const TextStyle(
                      color:
                          Colors.white54,

                      fontSize:
                          10,

                      height:
                          1.4,
                    ),
                  ),
                ],

                const SizedBox(
                  height:
                      10,
                ),

                Wrap(
                  spacing:
                      6,

                  runSpacing:
                      6,

                  children: [
                    _MaterialBadge(
                      icon:
                          visibility ==
                                  'private'
                              ? Icons
                                  .lock_outline_rounded
                              : Icons
                                  .groups_outlined,

                      text:
                          visibility ==
                                  'private'
                              ? 'Privato'
                              : 'Studenti',
                    ),

                    _MaterialBadge(
                      icon:
                          isActive
                              ? Icons
                                  .check_circle_outline
                              : Icons
                                  .pause_circle_outline,

                      text:
                          isActive
                              ? 'Attivo'
                              : 'Disattivato',
                    ),

                    if (size > 0)
                      _MaterialBadge(
                        icon:
                            Icons
                                .data_usage_outlined,

                        text:
                            _formatFileSize(
                          size,
                        ),
                      ),

                    if (createdAt.isNotEmpty)
                      _MaterialBadge(
                        icon:
                            Icons
                                .calendar_today_outlined,

                        text:
                            createdAt,
                      ),
                  ],
                ),

                if (
                  originalName.isNotEmpty
                ) ...[
                  const SizedBox(
                    height:
                        8,
                  ),

                  Row(
                    children: [
                      const Icon(
                        Icons
                            .attach_file_rounded,

                        size:
                            12,

                        color:
                            Colors.white30,
                      ),

                      const SizedBox(
                        width:
                            4,
                      ),

                      Expanded(
                        child:
                            Text(
                          originalName,

                          maxLines:
                              1,

                          overflow:
                              TextOverflow
                                  .ellipsis,

                          style:
                              const TextStyle(
                            color:
                                Colors.white30,

                            fontSize:
                                8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildError() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.redAccent
                .withOpacity(
          0.07,
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
            0.14,
          ),
        ),
      ),

      child:
          Row(
        children: [
          const Icon(
            Icons
                .error_outline_rounded,

            color:
                Colors.redAccent,

            size:
                18,
          ),

          const SizedBox(
            width:
                9,
          ),

          Expanded(
            child:
                Text(
              _error!,

              style:
                  const TextStyle(
                color:
                    Colors.white54,

                fontSize:
                    9,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmpty() {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),

        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Container(
              width:
                  72,

              height:
                  72,

              decoration:
                  BoxDecoration(
                color:
                    AppColors
                        .teacherIndigo
                        .withOpacity(
                      0.09,
                    ),

                borderRadius:
                    BorderRadius.circular(
                  21,
                ),
              ),

              child:
                  const Icon(
                Icons
                    .folder_off_outlined,

                color:
                    AppColors
                        .teacherIndigo,

                size:
                    34,
              ),
            ),

            const SizedBox(
              height:
                  16,
            ),

            const Text(
              'Nessun materiale',

              style:
                  TextStyle(
                color:
                    AppColors
                        .pureWhite,

                fontSize:
                    17,

                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
                  7,
            ),

            Text(
              _searchQuery
                          .trim()
                          .isNotEmpty ||
                      _selectedSubjectId !=
                          null
                  ? 'Nessun materiale corrisponde ai filtri selezionati.'
                  : 'Non hai ancora pubblicato materiale didattico.',

              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                color:
                    Colors.white38,

                fontSize:
                    10,

                height:
                    1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }


  static InputDecoration
      _inputDecoration({
    required String label,
  }) {
    return InputDecoration(
      labelText:
          label,

      labelStyle:
          const TextStyle(
        color:
            Colors.white54,
      ),

      filled:
          true,

      fillColor:
          AppColors
              .eleganceMidnight,

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),

        borderSide:
            BorderSide(
          color:
              AppColors.pureWhite
                  .withOpacity(
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
            const BorderSide(
          color:
              AppColors
                  .teacherIndigo,
        ),
      ),
    );
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


  bool? _toBool(
    dynamic value,
  ) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String normalized =
        value
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    if (
      normalized ==
          'true' ||
      normalized ==
          '1'
    ) {
      return true;
    }

    if (
      normalized ==
          'false' ||
      normalized ==
          '0'
    ) {
      return false;
    }

    return null;
  }


  String _friendlyError(Object error) {
    final String value = error.toString().toLowerCase();
    if (value.contains('401') || value.contains('unauthorized')) {
      return 'La sessione non è più valida. Accedi nuovamente.';
    }
    if (value.contains('403') || value.contains('forbidden')) {
      return 'Non hai i permessi necessari per gestire i materiali docente.';
    }
    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection') ||
        value.contains('timeout') ||
        value.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }
    return 'Non è stato possibile caricare i materiali docente.';
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


class _TeacherMaterialStat
    extends StatelessWidget {
  final String label;

  final String value;

  final IconData icon;


  const _TeacherMaterialStat({
    required this.label,
    required this.value,
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
            10,

        vertical:
            9,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors
                .brandNightBlue
                .withOpacity(
              0.50,
            ),

        borderRadius:
            BorderRadius.circular(
          11,
        ),
      ),

      child:
          Row(
        children: [
          Icon(
            icon,

            color:
                AppColors
                    .teacherIndigo,

            size:
                15,
          ),

          const SizedBox(
            width:
                7,
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                value,

                style:
                    const TextStyle(
                  color:
                      AppColors
                          .pureWhite,

                  fontSize:
                      13,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              Text(
                label,

                style:
                    const TextStyle(
                  color:
                      Colors.white38,

                  fontSize:
                      8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _FilterChipButton
    extends StatelessWidget {
  final String text;

  final bool selected;

  final VoidCallback onTap;


  const _FilterChipButton({
    required this.text,
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
        11,
      ),

      child:
          Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal:
              13,

          vertical:
              9,
        ),

        decoration:
            BoxDecoration(
          color:
              selected
                  ? AppColors
                      .teacherIndigo
                      .withOpacity(
                        0.20,
                      )
                  : AppColors
                      .eleganceMidnight,

          borderRadius:
              BorderRadius.circular(
            11,
          ),

          border:
              Border.all(
            color:
                selected
                    ? AppColors
                        .teacherIndigo
                    : AppColors
                        .pureWhite
                        .withOpacity(
                          0.06,
                        ),
          ),
        ),

        child:
            Text(
          text,

          maxLines:
              1,

          overflow:
              TextOverflow
                  .ellipsis,

          style:
              TextStyle(
            color:
                selected
                    ? AppColors
                        .teacherIndigo
                    : Colors.white54,

            fontSize:
                9,

            fontWeight:
                selected
                    ? FontWeight.w600
                    : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}


class _MaterialBadge
    extends StatelessWidget {
  final IconData icon;

  final String text;


  const _MaterialBadge({
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
            7,

        vertical:
            4,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors
                .brandNightBlue
                .withOpacity(
              0.55,
            ),

        borderRadius:
            BorderRadius.circular(
          7,
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
                Colors.white38,

            size:
                10,
          ),

          const SizedBox(
            width:
                4,
          ),

          Text(
            text,

            style:
                const TextStyle(
              color:
                  Colors.white54,

              fontSize:
                  8,
            ),
          ),
        ],
      ),
    );
  }
}