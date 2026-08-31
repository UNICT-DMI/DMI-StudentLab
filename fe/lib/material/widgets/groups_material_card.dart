import 'package:flutter/material.dart';
import 'package:fe/theme/nightTheme.dart';

import '../models/study_material.dart';

class GroupMaterialCard extends StatelessWidget {
  final StudyMaterial material;

  final VoidCallback onOpen;
  final VoidCallback onDownload;

  final bool isDownloaded;

  const GroupMaterialCard({
    super.key,
    required this.material,
    required this.onOpen,
    required this.onDownload,
    this.isDownloaded = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        final bool compact = width < 180;
        final bool medium =
            width >= 180 && width < 260;

        final double padding = compact
            ? 12
            : medium
                ? 15
                : 18;

        final double iconSize = compact
            ? 42
            : medium
                ? 46
                : 50;

        final double icon = compact
            ? 22
            : medium
                ? 25
                : 28;

        return InkWell(
          onTap: onOpen,

          borderRadius:
              BorderRadius.circular(18),

          child: Container(
            width: double.infinity,

            padding:
                EdgeInsets.all(padding),

            decoration: BoxDecoration(
              color:
                  AppColors.eleganceMidnight,

              borderRadius:
                  BorderRadius.circular(18),

              border: Border.all(
                color:
                    isDownloaded
                        ? AppColors.materialSky
                            .withOpacity(0.35)
                        : AppColors.skyBlue
                            .withOpacity(0.18),
              ),

              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(
                    0.15,
                  ),

                  blurRadius: 8,

                  offset:
                      const Offset(0, 4),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                // =============================================================
                // HEADER
                // =============================================================

                Row(
                  children: [

                    Container(
                      width: iconSize,
                      height: iconSize,

                      decoration: BoxDecoration(
                        color:
                            AppColors.brandNightBlue,

                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),

                      child: Icon(
                        _fileIcon(
                          material.type,
                        ),

                        color:
                            AppColors.skyBlue,

                        size: icon,
                      ),
                    ),

                    const Spacer(),

                    // =========================================================
                    // DOWNLOAD
                    // =========================================================

                    Material(
                      color:
                          Colors.transparent,

                      child: InkWell(
                        onTap:
                            isDownloaded
                                ? null
                                : onDownload,

                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),

                        child: Container(
                          width:
                              compact ? 34 : 38,

                          height:
                              compact ? 34 : 38,

                          decoration:
                              BoxDecoration(
                            color:
                                isDownloaded
                                    ? AppColors
                                        .materialSky
                                        .withOpacity(
                                        0.12,
                                      )
                                    : AppColors
                                        .brandNightBlue,

                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),

                          child: Icon(
                            isDownloaded
                                ? Icons
                                    .check_rounded
                                : Icons
                                    .download_rounded,

                            color:
                                isDownloaded
                                    ? AppColors
                                        .materialSky
                                    : AppColors
                                        .skyBlue,

                            size:
                                compact
                                    ? 18
                                    : 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height:
                      compact ? 12 : 16,
                ),

                // =============================================================
                // NOME FILE
                // =============================================================

                Text(
                  material.name,

                  maxLines: 2,

                  overflow:
                      TextOverflow.ellipsis,

                  style: TextStyle(
                    color:
                        AppColors.pureWhite,

                    fontSize:
                        compact
                            ? 14
                            : medium
                                ? 16
                                : 17,

                    fontWeight:
                        FontWeight.bold,

                    height: 1.2,
                  ),
                ),

                SizedBox(
                  height:
                      compact ? 4 : 6,
                ),

                // =============================================================
                // TIPO + DIMENSIONE
                // =============================================================

                Text(
                  '${material.type} • ${material.size}',

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,

                  style: TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.60,
                    ),

                    fontSize:
                        compact ? 10 : 12,
                  ),
                ),

                SizedBox(
                  height:
                      compact ? 10 : 14,
                ),

                // =============================================================
                // STATO
                // =============================================================

                Row(
                  children: [

                    Icon(
                      isDownloaded
                          ? Icons
                              .offline_pin_outlined
                          : Icons.folder_outlined,

                      size:
                          compact ? 14 : 16,

                      color:
                          AppColors.materialSky,
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Expanded(
                      child: Text(
                        isDownloaded
                            ? 'Disponibile offline'
                            : 'Materiale condiviso',

                        maxLines: 1,

                        overflow:
                            TextOverflow.ellipsis,

                        style: TextStyle(
                          color:
                              AppColors
                                  .materialSky
                                  .withOpacity(
                            0.9,
                          ),

                          fontSize:
                              compact
                                  ? 10
                                  : 12,

                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _fileIcon(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf_rounded;

      case 'DOCUMENT':
      case 'DOC':
      case 'DOCX':
        return Icons.description_rounded;

      case 'IMAGE':
      case 'PNG':
      case 'JPG':
      case 'JPEG':
        return Icons.image_rounded;

      case 'VIDEO':
      case 'MP4':
        return Icons.video_file_rounded;

      case 'AUDIO':
      case 'MP3':
        return Icons.audio_file_rounded;

      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}