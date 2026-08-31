import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';


class SocialLoginIntro extends StatelessWidget {
  final Future<void> Function() onLogin;


  const SocialLoginIntro({
    super.key,
    required this.onLogin,
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
        20,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.14,
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
                width:
                    48,

                height:
                    48,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.brandNightBlue,

                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),

                  border:
                      Border.all(
                    color:
                        AppColors.skyBlue
                            .withOpacity(
                      0.12,
                    ),
                  ),
                ),

                child:
                    const Icon(
                  Icons.login_rounded,

                  color:
                      AppColors.skyBlue,

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
                    const Text(
                      'Hai già un account?',

                      style:
                          TextStyle(
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
                          6,
                    ),

                    Text(
                      'Accedi al tuo account StudentLab per ritrovare il tuo percorso, '
                      'i percorsi accademici, le materie, i gruppi e le conversazioni.',

                      style:
                          TextStyle(
                        color:
                            AppColors.pureWhite
                                .withOpacity(
                          0.52,
                        ),

                        fontSize:
                            11,

                        height:
                            1.45,
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

          Container(
            width:
                double.infinity,

            padding:
                const EdgeInsets.all(
              13,
            ),

            decoration:
                BoxDecoration(
              color:
                  AppColors.brandNightBlue
                      .withOpacity(
                0.65,
              ),

              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),

            child:
                Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Icon(
                  Icons
                      .verified_user_outlined,

                  color:
                      AppColors.materialSky,

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
                    'Con l\'accesso puoi partecipare alla community, '
                    'contattare studenti e docenti, gestire i tuoi percorsi '
                    'e utilizzare le funzionalità associate al tuo account.',

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite
                              .withOpacity(
                        0.48,
                      ),

                      fontSize:
                          10,

                      height:
                          1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height:
                16,
          ),

          SizedBox(
            width:
                double.infinity,

            height:
                50,

            child:
                OutlinedButton.icon(
              onPressed:
                  () async {
                await onLogin();
              },

              icon:
                  const Icon(
                Icons.login_rounded,
              ),

              label:
                  const Text(
                'Accedi a StudentLab',

                style:
                    TextStyle(
                  fontSize:
                      14,

                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    AppColors.skyBlue,

                side:
                    BorderSide(
                  color:
                      AppColors.skyBlue
                          .withOpacity(
                    0.40,
                  ),

                  width:
                      1.2,
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}