import 'package:flutter/material.dart';

import 'package:fe/theme/nightTheme.dart';

import '../social_models.dart';

import 'social_profile_type.dart';


class SocialIntro extends StatelessWidget {
  final ValueChanged<SocialUser> onProfileCreated;


  const SocialIntro({
    super.key,
    required this.onProfileCreated,
  });


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [
        const SizedBox(
          height: 20,
        ),

        Center(
          child: Container(
            width: 90,
            height: 90,

            decoration: BoxDecoration(
              color:
                  AppColors.brandNightBlue,

              borderRadius:
                  BorderRadius.circular(28),

              border: Border.all(
                color:
                    AppColors.skyBlue
                        .withOpacity(0.20),
              ),

              boxShadow: [
                BoxShadow(
                  color:
                      AppColors.brandNightBlue
                          .withOpacity(0.40),

                  blurRadius:
                      20,

                  offset:
                      const Offset(0, 8),
                ),
              ],
            ),

            child: const Icon(
              Icons.people_alt_rounded,
              color:
                  AppColors.skyBlue,
              size:
                  45,
            ),
          ),
        ),

        const SizedBox(
          height: 28,
        ),

        const Text(
          'Connettiti con la tua comunità',

          textAlign:
              TextAlign.center,

          style: TextStyle(
            color:
                AppColors.pureWhite,

            fontSize:
                25,

            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        Text(
          'StudentLab Social nasce per mettere '
          'in contatto studenti e insegnanti.',

          textAlign:
              TextAlign.center,

          style: TextStyle(
            color:
                AppColors.pureWhite
                    .withOpacity(0.70),

            fontSize:
                15,

            height:
                1.5,
          ),
        ),

        const SizedBox(
          height: 30,
        ),

        const _SocialInfoCard(
          icon:
              Icons.school_rounded,

          title:
              'Studenti',

          description:
              'Confrontati con altri studenti, '
              'chiedi aiuto, condividi le tue '
              'conoscenze e studia insieme agli altri.',
        ),

        const SizedBox(
          height: 14,
        ),

        const _SocialInfoCard(
          icon:
              Icons.cast_for_education_rounded,

          title:
              'Insegnanti',

          description:
              'Scopri insegnanti disponibili per '
              'lezioni private, ripetizioni e '
              'supporto nella preparazione degli esami.',
        ),

        const SizedBox(
          height: 35,
        ),

        SizedBox(
          height:
              54,

          child: ElevatedButton.icon(
            onPressed:
                () async {

              final SocialUser? user =
                  await Navigator.push<SocialUser>(
                context,

                MaterialPageRoute(
                  builder:
                      (_) =>
                          const SocialProfileType(),
                ),
              );


              if (user != null) {
                onProfileCreated(
                  user,
                );
              }
            },

            icon:
                const Icon(
              Icons.arrow_forward_rounded,
            ),

            label:
                const Text(
              'Inizia',

              style:
                  TextStyle(
                fontSize:
                    16,

                fontWeight:
                    FontWeight.w600,
              ),
            ),

            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  AppColors.eleganceMidnight,

              foregroundColor:
                  AppColors.pureWhite,

              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    24,

                vertical:
                    16,
              ),

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),

              elevation:
                  6,
            ),
          ),
        ),

        const SizedBox(
          height: 15,
        ),

        Text(
          'Il tuo account StudentLab verrà utilizzato '
          'per collegare il tuo profilo Social.',

          textAlign:
              TextAlign.center,

          style: TextStyle(
            color:
                AppColors.pureWhite
                    .withOpacity(0.40),

            fontSize:
                11,
          ),
        ),
      ],
    );
  }
}


class _SocialInfoCard
    extends StatelessWidget {

  final IconData icon;

  final String title;

  final String description;


  const _SocialInfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            AppColors.brandNightBlue,

        borderRadius:
            BorderRadius.circular(18),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withOpacity(0.12),
        ),
      ),

      child:
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
                  AppColors.electricBlue
                      .withOpacity(0.20),

              borderRadius:
                  BorderRadius.circular(14),
            ),

            child:
                Icon(
              icon,

              color:
                  AppColors.skyBlue,

              size:
                  25,
            ),
          ),

          const SizedBox(
            width:
                15,
          ),

          Expanded(
            child:
                Column(
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
                        16,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                      6,
                ),

                Text(
                  description,

                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(0.60),

                    fontSize:
                        13,

                    height:
                        1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}