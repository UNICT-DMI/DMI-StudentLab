import 'package:flutter/material.dart';

import 'package:fe/theme/nightTheme.dart';

import 'package:fe/social/social_models.dart';

import 'package:fe/social/widgets/student_social_form.dart';
import 'package:fe/social/widgets/teacher_social_form.dart';


// =============================================================================
// SOCIAL PROFILE TYPE
// =============================================================================

class SocialProfileType extends StatelessWidget {
  const SocialProfileType({
    super.key,
  });


  // ===========================================================================
  // REGISTRA STUDENTE
  // ===========================================================================

  Future<void> _openStudentRegistration(
    BuildContext context,
  ) async {
    final SocialUser? user =
        await Navigator.push<SocialUser>(
      context,

      MaterialPageRoute(
        builder:
            (_) =>
                const StudentSocialForm(),
      ),
    );


    if (user == null) {
      return;
    }


    if (!context.mounted) {
      return;
    }


    // =========================================================================
    // L'utente è già:
    //
    // - registrato nel backend;
    // - autenticato;
    // - associato al JWT;
    // - presente in AuthSession;
    // - preparato nel LocalStorage;
    // - associato alle materie selezionate.
    //
    // Lo restituiamo alla pagina che ha aperto SocialProfileType.
    // =========================================================================

    Navigator.pop(
      context,
      user,
    );
  }


  // ===========================================================================
  // REGISTRA INSEGNANTE
  // ===========================================================================

  Future<void> _openTeacherRegistration(
    BuildContext context,
  ) async {
    final SocialUser? user =
        await Navigator.push<SocialUser>(
      context,

      MaterialPageRoute(
        builder:
            (_) =>
                const TeacherSocialForm(),
      ),
    );


    if (user == null) {
      return;
    }


    if (!context.mounted) {
      return;
    }


    Navigator.pop(
      context,
      user,
    );
  }


  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,


      // =========================================================================
      // APP BAR
      // =========================================================================

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
          'Registrazione StudentLab',
        ),
      ),


      // =========================================================================
      // BODY
      // =========================================================================

      body:
          SafeArea(
        child:
            LayoutBuilder(
          builder:
              (
            context,
            constraints,
          ) {
            return SingleChildScrollView(
              child:
                  Center(
                child:
                    ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth:
                        650,
                  ),

                  child:
                      Padding(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),

                    child:
                        Column(
                      mainAxisSize:
                          MainAxisSize.min,

                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,

                      children: [
                        const SizedBox(
                          height:
                              20,
                        ),


                        // =====================================================
                        // ICON
                        // =====================================================

                        const Icon(
                          Icons.groups_rounded,

                          size:
                              70,

                          color:
                              AppColors.socialSky,
                        ),

                        const SizedBox(
                          height:
                              20,
                        ),


                        // =====================================================
                        // TITLE
                        // =====================================================

                        const Text(
                          'Entra nella community',

                          textAlign:
                              TextAlign.center,

                          style:
                              TextStyle(
                            color:
                                AppColors.pureWhite,

                            fontSize:
                                26,

                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height:
                              12,
                        ),


                        // =====================================================
                        // DESCRIPTION
                        // =====================================================

                        Text(
                          'Crea il tuo account StudentLab scegliendo '
                          'il tipo di profilo che meglio ti rappresenta.',

                          textAlign:
                              TextAlign.center,

                          style:
                              TextStyle(
                            color:
                                AppColors.pureWhite
                                    .withOpacity(
                              0.65,
                            ),

                            fontSize:
                                15,

                            height:
                                1.5,
                          ),
                        ),

                        const SizedBox(
                          height:
                              8,
                        ),

                        Text(
                          'Dopo la registrazione resterai autenticato '
                          'e potrai utilizzare le funzionalità riservate '
                          'agli utenti registrati.',

                          textAlign:
                              TextAlign.center,

                          style:
                              TextStyle(
                            color:
                                AppColors.pureWhite
                                    .withOpacity(
                              0.42,
                            ),

                            fontSize:
                                12,

                            height:
                                1.4,
                          ),
                        ),

                        const SizedBox(
                          height:
                              35,
                        ),


                        // =====================================================
                        // STUDENTE
                        // =====================================================

                        _buildOptionCard(
                          icon:
                              Icons.school_rounded,

                          title:
                              'Sono uno studente',

                          description:
                              'Crea un profilo studente, aggiungi le tue '
                              'materie e indica dove puoi aiutare gli altri.',

                          color:
                              AppColors.studentBlue,

                          onTap:
                              () {
                            _openStudentRegistration(
                              context,
                            );
                          },
                        ),

                        const SizedBox(
                          height:
                              16,
                        ),


                        // =====================================================
                        // INSEGNANTE
                        // =====================================================

                        _buildOptionCard(
                          icon:
                              Icons.cast_for_education_rounded,

                          title:
                              'Sono un insegnante',

                          description:
                              'Crea un profilo insegnante, indica le materie '
                              'che insegni e la tua disponibilità.',

                          color:
                              AppColors.teacherIndigo,

                          onTap:
                              () {
                            _openTeacherRegistration(
                              context,
                            );
                          },
                        ),

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
          },
        ),
      ),
    );
  }


  // ===========================================================================
  // OPTION CARD
  // ===========================================================================

  Widget _buildOptionCard({
    required IconData icon,

    required String title,

    required String description,

    required Color color,

    required VoidCallback onTap,
  }) {
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
                color.withOpacity(
              0.35,
            ),
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black
                      .withOpacity(
                0.15,
              ),

              blurRadius:
                  10,

              offset:
                  const Offset(
                0,
                5,
              ),
            ),
          ],
        ),

        child:
            Row(
          children: [
            Container(
              width:
                  55,

              height:
                  55,

              decoration:
                  BoxDecoration(
                color:
                    color.withOpacity(
                  0.15,
                ),

                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
              ),

              child:
                  Icon(
                icon,

                color:
                    color,

                size:
                    28,
              ),
            ),

            const SizedBox(
              width:
                  16,
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
                    description,

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite
                              .withOpacity(
                        0.60,
                      ),

                      fontSize:
                          13,

                      height:
                          1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width:
                  10,
            ),

            Icon(
              Icons.arrow_forward_ios_rounded,

              color:
                  color,

              size:
                  17,
            ),
          ],
        ),
      ),
    );
  }
}