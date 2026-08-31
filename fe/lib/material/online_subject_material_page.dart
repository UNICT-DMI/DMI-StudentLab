import 'package:flutter/material.dart';

import '../local_storage/local_storage.dart';
import '../theme/nightTheme.dart';
import 'models/study_material.dart';
import 'widgets/material_card.dart';

class OnlineSubjectMaterialPage extends StatefulWidget {
  final int? subjectId;
  final String subjectName;
  final String course;
  final String department;
  final int groupId;
  final List<StudyMaterial> materials;

  const OnlineSubjectMaterialPage({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.course,
    required this.department,
    required this.groupId,
    required this.materials,
  });

  @override
  State<OnlineSubjectMaterialPage> createState() =>
      _OnlineSubjectMaterialPageState();
}

class _OnlineSubjectMaterialPageState
    extends State<OnlineSubjectMaterialPage> {
  final MaterialDownloadService _downloadService =
      MaterialDownloadService();

  final Set<int> _downloadedIds = <int>{};
  final Set<int> _downloadingIds = <int>{};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedState();
  }

  Future<void> _loadDownloadedState() async {
    final Set<int> downloaded = <int>{};

    for (final StudyMaterial material in widget.materials) {
      final int? materialId = int.tryParse(material.id);

      if (materialId == null) {
        continue;
      }

      final bool isDownloaded =
          await _downloadService.isMaterialDownloaded(
        source: MaterialSourceLocal.group,
        materialId: materialId,
      );

      if (isDownloaded) {
        downloaded.add(materialId);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _downloadedIds
        ..clear()
        ..addAll(downloaded);
      _loading = false;
    });
  }

  Future<void> _downloadMaterial(
    StudyMaterial material,
  ) async {
    final int? materialId = int.tryParse(material.id);

    if (materialId == null) {
      _showMessage(
        'ID materiale non valido.',
      );
      return;
    }

    if (_downloadingIds.contains(materialId)) {
      return;
    }

    setState(() {
      _downloadingIds.add(materialId);
    });

    try {
      final MaterialLocal localMaterial =
          await _downloadService.getOrDownloadMaterial(
        source: MaterialSourceLocal.group,
        materialId: materialId,
        groupId: widget.groupId,
        subjectId: widget.subjectId,
        subjectName: widget.subjectName,
        course: widget.course,
        department: widget.department,
        originalName: material.name,
        mimeType: _mimeTypeFromMaterial(material),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _downloadedIds.add(materialId);
      });

      _showMessage(
        '${localMaterial.originalName} disponibile offline.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(materialId);
        });
      }
    }
  }

  Future<void> _openMaterial(
    StudyMaterial material,
  ) async {
    final int? materialId = int.tryParse(material.id);
    if (materialId == null) {
      _showMessage('ID materiale non valido.');
      return;
    }

    try {
      MaterialLocal? local = await _downloadService.getLocalMaterialV6(
        source: MaterialSourceLocal.group,
        materialId: materialId,
      );

      local ??= await _downloadService.getOrDownloadMaterial(
        source: MaterialSourceLocal.group,
        materialId: materialId,
        groupId: widget.groupId,
        subjectId: widget.subjectId,
        subjectName: widget.subjectName,
        course: widget.course,
        department: widget.department,
        originalName: material.name,
        mimeType: _mimeTypeFromMaterial(material),
      );

      await _downloadService.openLocalMaterial(local);
      if (!mounted) return;
      setState(() {
        _downloadedIds.add(materialId);
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    }
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: Text(
          widget.subjectName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed:
                _loading ? null : _loadDownloadedState,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (
              BuildContext context,
              BoxConstraints constraints,
            ) {
              final double width =
                  constraints.maxWidth > 750
                      ? 750
                      : constraints.maxWidth;

              return SizedBox(
                width: width,
                child: _buildBody(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (widget.materials.isEmpty) {
      return const _EmptyMaterials();
    }

    return RefreshIndicator(
      onRefresh: _loadDownloadedState,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.subjectName,
            style: const TextStyle(
              color: AppColors.pureWhite,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            '${widget.department} • ${widget.course}',
            style: TextStyle(
              color: AppColors.pureWhite.withValues(
                        alpha: 0.48,
                      ),
              fontSize: 12,
            ),
          ),
          const SizedBox(
            height: 24,
          ),
          const Text(
            'Materiali disponibili',
            style: TextStyle(
              color: AppColors.pureWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          ...widget.materials.map(
            (
              StudyMaterial material,
            ) {
              final int? materialId =
                  int.tryParse(material.id);

              final bool downloaded =
                  materialId != null &&
                      _downloadedIds.contains(
                        materialId,
                      );

              final bool downloading =
                  materialId != null &&
                      _downloadingIds.contains(
                        materialId,
                      );

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: Column(
                  children: [
                    MaterialCard(
                      material: material,
                      onTap: () {
                        _openMaterial(
                          material,
                        );
                      },
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.end,
                      children: [
                        if (downloaded)
                          const Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color:
                                    Colors.greenAccent,
                                size: 16,
                              ),
                              SizedBox(
                                width: 5,
                              ),
                              Text(
                                'Disponibile offline',
                                style: TextStyle(
                                  color:
                                      Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        else
                          TextButton.icon(
                            onPressed:
                                downloading
                                    ? null
                                    : () {
                                        _downloadMaterial(
                                          material,
                                        );
                                      },
                            icon:
                                downloading
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons
                                            .download_rounded,
                                        size: 17,
                                      ),
                            label: Text(
                              downloading
                                  ? 'Download...'
                                  : 'Scarica offline',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String? _mimeTypeFromMaterial(
    StudyMaterial material,
  ) {
    switch (material.type.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'image':
        return 'image/*';
      case 'document':
        return 'application/octet-stream';
      default:
        return 'application/octet-stream';
    }
  }

  String _cleanError(
    Object error,
  ) {
    String message = error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      message = message.substring(
        'Exception: '.length,
      );
    }

    return message;
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
        content: Text(
          message,
        ),
      ),
    );
  }
}

class _EmptyMaterials extends StatelessWidget {
  const _EmptyMaterials();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          30,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(
            30,
          ),
          decoration: BoxDecoration(
            color: AppColors.materialNavy,
            borderRadius: BorderRadius.circular(
              16,
            ),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_rounded,
                color: Colors.white38,
                size: 45,
              ),
              SizedBox(
                height: 12,
              ),
              Text(
                'Nessun materiale disponibile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}