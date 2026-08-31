import 'package:flutter/material.dart';

import 'package:fe/theme/nightTheme.dart';

import '../models/study_material.dart';

class MaterialCard extends StatelessWidget {
  final StudyMaterial material;
  final VoidCallback onTap;
  final String? provenanceLabel;
  final Widget? provenanceIcon;
  final bool provenanceVerified;

  const MaterialCard({
    super.key,
    required this.material,
    required this.onTap,
    this.provenanceLabel,
    this.provenanceIcon,
    this.provenanceVerified = false,
  });

  IconData get icon {
    switch (material.type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  bool get hasProvenance {
    return provenanceLabel?.trim().isNotEmpty == true;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.darkElegance,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: AppColors.brandNightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.skyBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${material.type} • ${material.size}',
                    style: TextStyle(
                      color: AppColors.pureWhite.withValues(
                        alpha: 0.55,
                      ),
                      fontSize: 12,
                    ),
                  ),
                  if (hasProvenance) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (provenanceIcon != null) ...[
                          SizedBox(
                            width: 17,
                            height: 17,
                            child: Center(
                              child: provenanceIcon!,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            provenanceLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.materialSky,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (provenanceVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppColors.materialSky,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white38,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}