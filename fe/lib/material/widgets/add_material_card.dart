import 'package:flutter/material.dart';
import 'package:fe/theme/nightTheme.dart';

class AddMaterialCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddMaterialCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width =
            constraints.maxWidth;

        final bool compact =
            width < 180;

        final bool medium =
            width >= 180 &&
            width < 260;

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
          onTap: onTap,

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
                    AppColors.skyBlue
                        .withOpacity(0.18),
              ),

              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black
                          .withOpacity(
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

                Row(
                  children: [

                    Container(
                      width: iconSize,
                      height: iconSize,

                      decoration:
                          BoxDecoration(
                        color:
                            AppColors
                                .brandNightBlue,

                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),

                      child: Icon(
                        Icons
                            .add_rounded,

                        color:
                            AppColors
                                .skyBlue,

                        size: icon,
                      ),
                    ),

                    const Spacer(),

                    Icon(
                      Icons
                          .arrow_forward_ios_rounded,

                      color:
                          AppColors
                              .pureWhite
                              .withOpacity(
                        0.45,
                      ),

                      size:
                          compact
                              ? 13
                              : 16,
                    ),
                  ],
                ),

                SizedBox(
                  height:
                      compact
                          ? 12
                          : 16,
                ),

                Text(
                  'Aggiungi materiale',

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
                      compact
                          ? 4
                          : 6,
                ),

                Text(
                  'Condividi un nuovo file con il gruppo',

                  maxLines: 2,

                  overflow:
                      TextOverflow.ellipsis,

                  style: TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.60,
                    ),

                    fontSize:
                        compact
                            ? 10
                            : 12,
                  ),
                ),

                SizedBox(
                  height:
                      compact
                          ? 10
                          : 14,
                ),

                Row(
                  children: [

                    Icon(
                      Icons
                          .upload_file_rounded,

                      size:
                          compact
                              ? 14
                              : 16,

                      color:
                          AppColors
                              .materialSky,
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Text(
                      'Carica file',

                      style:
                          TextStyle(
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
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}