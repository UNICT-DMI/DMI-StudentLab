import 'package:flutter/material.dart';

import 'package:fe/material/StudentMaterialPage.dart';

import 'package:fe/quiz/subjectSelection.dart';

import 'package:fe/quiz/review/student_quiz_review_page.dart';

import 'package:fe/social/social_page.dart';

import 'package:fe/theme/nightTheme.dart';

import 'package:fe/widgets/studentlab_coming_soon_badge.dart';

enum HomeFeatureType {

  exercise,

  examSimulation,

  review,

  definitions,

  materials,

  institution,

  marketplace,

  jobs,

}

class FeatureCard {

  final HomeFeatureType type;

  final String title;

  final String description;

  final IconData icon;

  final Color accent;

  final bool isComingSoon;

  const FeatureCard({

    required this.type,

    required this.title,

    required this.description,

    required this.icon,

    required this.accent,

this.isComingSoon = false,

  });

}

class HomeLayer extends StatelessWidget {

  HomeLayer({super.key});

  final List<FeatureCard> _featureCards =

      const <FeatureCard>[

    FeatureCard(

      type: HomeFeatureType.exercise,

      title: 'Esercitazione',

      description:

          'Allenati senza pressione, scegliendo materia e argomenti su cui vuoi concentrarti.',

      icon: Icons.quiz_outlined,

      accent: AppColors.skyBlue,

    ),

    FeatureCard(

      type: HomeFeatureType.examSimulation,

      title: 'Simulazione Esame',

      description:

          'Mettiti alla prova con simulazioni strutturate come un vero appello.',

      icon:

          Icons.assignment_turned_in_outlined,

      accent: AppColors.teacherIndigo,

      isComingSoon: true,

    ),

    FeatureCard(

      type: HomeFeatureType.review,

      title: 'Ripasso',

      description:

          'Rivedi errori, concetti deboli e argomenti che meritano più attenzione.',

      icon: Icons.restart_alt_rounded,

      accent: AppColors.adminMagenta,

    ),

    FeatureCard(

      type: HomeFeatureType.definitions,

      title: 'Definizioni',

      description:

          'Consulta termini e concetti chiave delle materie del tuo percorso.',

      icon: Icons.menu_book_outlined,

      accent: AppColors.materialSky,

      isComingSoon: true,

    ),

    FeatureCard(

      type: HomeFeatureType.materials,

      title: 'Materiali',

      description:

          'Accedi a dispense, slide, documenti e file disponibili anche offline.',

      icon: Icons.folder_copy_outlined,

      accent: AppColors.studentBlue,

    ),

    FeatureCard(

      type: HomeFeatureType.institution,

      title: 'Istituzione',

      description:

          'News di ateneo e dipartimento, gruppi di studio e delle tue materie, studenti, docenti universitari e insegnanti privati.',

      icon:

          Icons.account_balance_outlined,

      accent: AppColors.socialBlue,

    ),

  ];

  @override

  Widget build(BuildContext context) {

    return SafeArea(

      top: false,

      child: LayoutBuilder(

        builder:

            (

          BuildContext context,

          BoxConstraints constraints,

        ) {

          final double width =

              constraints.maxWidth;

          final int crossAxisCount;

          final double maxWidth;

          final double cardHeight;

          final double gap;

          final double horizontalPadding;

          if (width < 560) {

            crossAxisCount = 1;

            maxWidth = 660;

            cardHeight = 178;

            gap = 12;

            horizontalPadding = 16;

          } else if (width < 900) {

            crossAxisCount = 2;

            maxWidth = 860;

            cardHeight = 204;

            gap = 14;

            horizontalPadding = 20;

          } else if (width < 1320) {

            crossAxisCount = 3;

            maxWidth = 1160;

            cardHeight = 210;

            gap = 14;

            horizontalPadding = 24;

          } else {

            crossAxisCount = 4;

            maxWidth = 1420;

            cardHeight = 214;

            gap = 16;

            horizontalPadding = 28;

          }

          return Center(

            child: ConstrainedBox(

              constraints:

                  BoxConstraints(

                maxWidth:

                    maxWidth,

              ),

              child:

                  CustomScrollView(

                slivers: [

                  SliverPadding(

                    padding:

                        EdgeInsets.fromLTRB(

                      horizontalPadding,

                      8,

                      horizontalPadding,

                      28,

                    ),

                    sliver:

                        SliverGrid(

                      delegate:

                          SliverChildBuilderDelegate(

                        (

                          BuildContext context,

                          int index,

                        ) {

                          final FeatureCard card =

                              _featureCards[index];

                          return _FeatureCardView(

                            card:

                                card,

                            animationSeed:

                                index,

                            onTap:

                                () =>

                                    _openFeature(

                              context,

                              card,

                            ),

                          );

                        },

                        childCount:

                            _featureCards.length,

                      ),

                      gridDelegate:

                          SliverGridDelegateWithFixedCrossAxisCount(

                        crossAxisCount:

                            crossAxisCount,

                        crossAxisSpacing:

                            gap,

                        mainAxisSpacing:

                            gap,

                        mainAxisExtent:

                            cardHeight,

                      ),

                    ),

                  ),

                ],

              ),

            ),

          );

        },

      ),

    );

  }





  Future<void> _openFeature(

    BuildContext context,

    FeatureCard card,

  ) async {

    switch (card.type) {

      case HomeFeatureType.exercise:

        await Navigator.of(context)

            .push(

          MaterialPageRoute<void>(

            builder: (_) =>

                const SubjectSelection(),

          ),

        );

        return;

      case HomeFeatureType.materials:

        await Navigator.of(context)

            .push(

          MaterialPageRoute<void>(

            builder: (_) =>

                const StudentMaterialPage(),

          ),

        );

        return;

      case HomeFeatureType.institution:

        await Navigator.of(context)

            .push(

          MaterialPageRoute<void>(

            builder: (_) =>

                const SocialPage(),

          ),

        );

        return;

      case HomeFeatureType.review:

        await Navigator.of(context).push(

          MaterialPageRoute<void>(

            builder: (_) => const StudentQuizReviewPage(),

          ),

        );

        return;

      case HomeFeatureType.examSimulation:

      case HomeFeatureType.definitions:

      case HomeFeatureType.marketplace:

      case HomeFeatureType.jobs:

        return;

    }

  }

}



class _HomeIconBox

    extends StatelessWidget {

  final IconData icon;

  final Color accent;

  final double size;

  final double iconSize;

  final double borderRadius;

  const _HomeIconBox({

    required this.icon,

    required this.accent,

    required this.size,

    required this.iconSize,

    required this.borderRadius,

  });

  @override

  Widget build(

    BuildContext context,

  ) {

    return Container(

      width:

          size,

      height:

          size,

      decoration:

          BoxDecoration(

        color:

            AppColors.brandNightBlue,

        borderRadius:

            BorderRadius.circular(

          borderRadius,

        ),

        border:

            Border.all(

          color:

              accent.withValues(

            alpha:

                0.14,

          ),

        ),

      ),

      alignment:

          Alignment.center,

      child:

          Icon(

        icon,

        color:

            accent,

        size:

            iconSize,

      ),

    );

  }

}

class _FeatureCardView

    extends StatefulWidget {

  final FeatureCard card;

  final int animationSeed;

  final VoidCallback onTap;

  const _FeatureCardView({

    required this.card,

    required this.animationSeed,

    required this.onTap,

  });

  @override

  State<_FeatureCardView> createState() =>

      _FeatureCardViewState();

}

class _FeatureCardViewState

    extends State<_FeatureCardView>

    with TickerProviderStateMixin {

  bool _hovered =

      false;

  bool _pressed =

      false;

  late final AnimationController

      _badgeController;

  @override

  void initState() {
super.initState();

    _badgeController =

        AnimationController(

      vsync:

this,

      duration:

          Duration(

        milliseconds:

            760 +

                (

                  widget.animationSeed %

                      4

                ) *

                    90,

      ),

    );

    if (widget.card.isComingSoon) {

      Future<void>.delayed(

        Duration(

          milliseconds:

              widget.animationSeed *

                  115,

        ),

        () {

          if (mounted) {

            _badgeController.repeat(

              reverse:

                  true,

            );

          }

        },

      );

    }

  }

  @override

  void dispose() {

    _badgeController.dispose();

super.dispose();

  }

  @override

  Widget build(

    BuildContext context,

  ) {

    final FeatureCard card =

        widget.card;

    final double scale =

        _pressed

            ? 1.015

            : _hovered

                ? 1.006

                : 1;

    return MouseRegion(

      onEnter:

          (_) {

        setState(() {

          _hovered =

              true;

        });

      },

      onExit:

          (_) {

        setState(() {

          _hovered =

              false;

          _pressed =

              false;

        });

      },

      child:

          AnimatedScale(

        scale:

            scale,

        duration:

            const Duration(

          milliseconds:

              150,

        ),

        curve:

            Curves.easeOutCubic,

        child:

            Material(

          color:

              Colors.transparent,

          child:

              InkWell(

            onTap:

                widget.onTap,

            onTapDown:

                (_) {

              setState(() {

                _pressed =

                    true;

              });

            },

            onTapUp:

                (_) {

              setState(() {

                _pressed =

                    false;

              });

            },

            onTapCancel:

                () {

              setState(() {

                _pressed =

                    false;

              });

            },

            splashColor:

                Colors.transparent,

            highlightColor:

                Colors.transparent,

            hoverColor:

                Colors.transparent,

            focusColor:

                Colors.transparent,

            overlayColor:

                const WidgetStatePropertyAll<Color>(

              Colors.transparent,

            ),

            borderRadius:

                BorderRadius.circular(

              18,

            ),

            child:

                Container(

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

                      card.accent

                          .withValues(

                    alpha:

                        card.isComingSoon

                            ? 0.11

                            : 0.20,

                  ),

                ),

              ),

              child:

                  Padding(

                padding:

                    const EdgeInsets.all(

                  18,

                ),

                child:

                    Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,

                  children: [

                    Row(

                      children: [

                        _HomeIconBox(

                          icon:

                              card.icon,

                          accent:

                              card.accent,

                          size:

                              44,

                          iconSize:

                              22,

                          borderRadius:

                              13,

                        ),

                        const Spacer(),

                        if (card.isComingSoon)

                          AnimatedBuilder(

                            animation:

                                _badgeController,

                            child:

                                const StudentLabComingSoonBadge(),

                            builder:

                                (

                              BuildContext context,

                              Widget? child,

                            ) {

                              final double t =

                                  Curves.easeInOut

                                      .transform(

                                _badgeController.value,

                              );

                              final double dx =

                                  -1.6 +

                                      (

                                        3.2 *

                                            t

                                      );

                              final double angle =

                                  -0.025 +

                                      (

                                        0.050 *

                                            t

                                      );

                              return Transform.translate(

                                offset:

                                    Offset(

                                  dx,

                                  0,

                                ),

                                child:

                                    Transform.rotate(

                                  angle:

                                      angle,

                                  child:

                                      child,

                                ),

                              );

                            },

                          )

                        else

                          Icon(

                            Icons

                                .arrow_outward_rounded,

                            color:

                                card.accent

                                    .withValues(

                              alpha:

                                  0.65,

                            ),

                            size:

                                19,

                          ),

                      ],

                    ),

                    const Spacer(),

                    Text(

                      card.title,

                      maxLines:

                          1,

                      overflow:

                          TextOverflow.ellipsis,

                      style:

                          const TextStyle(

                        color:

                            AppColors.pureWhite,

                        fontSize:

                            17,

                        fontWeight:

                            FontWeight.w700,

                        letterSpacing:

                            -0.2,

                      ),

                    ),

                    const SizedBox(

                      height:

                          7,

                    ),

                    Text(

                      card.description,

                      maxLines:

                          3,

                      overflow:

                          TextOverflow.ellipsis,

                      style:

                          TextStyle(

                        color:

                            AppColors.pureWhite

                                .withValues(

                          alpha:

                              card.isComingSoon

                                  ? 0.34

                                  : 0.52,

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

            ),

          ),

        ),

      ),

    );

  }

}