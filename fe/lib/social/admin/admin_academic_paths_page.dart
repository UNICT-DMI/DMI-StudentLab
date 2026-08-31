import 'package:flutter/material.dart';

import '../../services/api_service.dart';

import '../../theme/nightTheme.dart';

import '../social_models.dart';



class AdminAcademicPathsPage

    extends StatefulWidget {

  const AdminAcademicPathsPage({

super.key,

  });

  @override

  State<AdminAcademicPathsPage> createState() =>

      _AdminAcademicPathsPageState();

}



class _AdminAcademicPathsPageState

    extends State<AdminAcademicPathsPage> {

  final ApiService _apiService =

      ApiService();

  List<SocialAcademicPath> _paths =

      [];

  final Set<int> _processingIds =

      {};

  bool _loading =

      true;

  bool _refreshing =

      false;

  String? _error;



  @override

  void initState() {

super.initState();

    _loadPaths();

  }



  Future<void> _loadPaths({

    bool refresh = false,

  }) async {

    if (refresh) {

      if (_refreshing) {

        return;

      }

      setState(() {

        _refreshing =

            true;

      });

    } else {

      setState(() {

        _loading =

            true;

        _error =

            null;

      });

    }

    try {

      final List<SocialAcademicPath>

          paths =

          await _apiService

              .getPendingAcademicPaths();

      if (!mounted) {

        return;

      }

      setState(() {

        _paths =

            paths;

        _error =

            null;

      });

    } catch (e) {

      if (!mounted) {

        return;

      }

      setState(() {

        _error =

            _cleanError(

          e,

        );

      });

    } finally {

      if (!mounted) {

        return;

      }

      setState(() {

        _loading =

            false;

        _refreshing =

            false;

      });

    }

  }



  bool _isProcessing(

    SocialAcademicPath path,

  ) {

    return _processingIds.contains(

      path.id,

    );

  }



  Future<void> _approvePath(

    SocialAcademicPath path,

  ) async {

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

              AppColors.eleganceDeepNavy,

          title:

              const Text(

            'Verifica percorso',

            style:

                TextStyle(

              color:

                  AppColors.pureWhite,

            ),

          ),

          content:

              Text(

            'Vuoi verificare il percorso accademico "${_pathTitle(path)}"?',

            style:

                const TextStyle(

              color:

                  Colors.white70,

              height:

                  1.45,

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

                'Verifica',

                style:

                    TextStyle(

                  color:

                      Colors.greenAccent,

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

    await _setVerification(

      path:

          path,

      verified:

          true,

      successMessage:

          'Percorso accademico verificato.',

    );

  }



  Future<void> _rejectPath(

    SocialAcademicPath path,

  ) async {

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

              AppColors.eleganceDeepNavy,

          title:

              const Text(

            'Rifiuta verifica',

            style:

                TextStyle(

              color:

                  AppColors.pureWhite,

            ),

          ),

          content:

              Text(

            'Vuoi rifiutare la verifica del percorso accademico "${_pathTitle(path)}"?',

            style:

                const TextStyle(

              color:

                  Colors.white70,

              height:

                  1.45,

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

                'Rifiuta',

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

    await _setVerification(

      path:

          path,

      verified:

          false,

      successMessage:

          'Verifica del percorso rifiutata.',

    );

  }



  Future<void> _setVerification({

    required SocialAcademicPath path,

    required bool verified,

    required String successMessage,

  }) async {

    if (

      _processingIds.contains(

        path.id,

      )

    ) {

      return;

    }

    setState(() {

      _processingIds.add(

        path.id,

      );

    });

    try {

      await _apiService

          .updateAcademicPathVerification(

        academicPathId:

            path.id,

        verified:

            verified,

      );

      if (!mounted) {

        return;

      }

      setState(() {

        _paths.removeWhere(

          (

            SocialAcademicPath item,

          ) =>

              item.id ==

              path.id,

        );

      });

      _showMessage(

        successMessage,

      );

    } catch (e) {

      if (!mounted) {

        return;

      }

      _showMessage(

        _cleanError(

          e,

        ),

      );

    } finally {

      if (mounted) {

        setState(() {

          _processingIds.remove(

            path.id,

          );

        });

      }

    }

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

            const Text(

          'Verifica percorsi',

          style:

              TextStyle(

            fontSize:

                18,

            fontWeight:

                FontWeight.w500,

          ),

        ),

        actions: [

          IconButton(

            tooltip:

                'Aggiorna',

            onPressed:

                _refreshing

                    ? null

                    : () {

                        _loadPaths(

                          refresh:

                              true,

                        );

                      },

            icon:

                _refreshing

                    ? const SizedBox(

                        width:

                            19,

                        height:

                            19,

                        child:

                            CircularProgressIndicator(

                          strokeWidth:

                              2,

                          color:

                              AppColors.pureWhite,

                        ),

                      )

                    : const Icon(

                        Icons.refresh_rounded,

                      ),

          ),

        ],

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

                  900,

            ),

            child:

                _buildBody(),

          ),

        ),

      ),

    );

  }



  Widget _buildBody() {

    if (_loading) {

      return const Center(

        child:

            CircularProgressIndicator(),

      );

    }

    if (_error != null) {

      return _AcademicPathError(

        message:

            _error!,

        onRetry:

            _loadPaths,

      );

    }

    if (_paths.isEmpty) {

      return const _EmptyAcademicPaths();

    }

    return RefreshIndicator(

      onRefresh:

          () =>

              _loadPaths(

        refresh:

            true,

      ),

      child:

          ListView.separated(

        physics:

            const AlwaysScrollableScrollPhysics(),

        padding:

            const EdgeInsets.all(

          16,

        ),

        itemCount:

            _paths.length,

        separatorBuilder:

            (

          BuildContext context,

          int index,

        ) =>

                const SizedBox(

          height:

              14,

        ),

        itemBuilder:

            (

          BuildContext context,

          int index,

        ) {

          final SocialAcademicPath path =

              _paths[index];

          return _AcademicPathVerificationCard(

            path:

                path,

            processing:

                _isProcessing(

              path,

            ),

            onApprove:

                () {

              _approvePath(

                path,

              );

            },

            onReject:

                () {

              _rejectPath(

                path,

              );

            },

          );

        },

      ),

    );

  }



  String _pathTitle(

    SocialAcademicPath path,

  ) {

    final String course =

        path.course.trim();

    final String degreeType =

        path.degreeType.trim();

    if (

      course.isNotEmpty &&

      degreeType.isNotEmpty

    ) {

      return '$course $degreeType';

    }

    if (course.isNotEmpty) {

      return course;

    }

    if (degreeType.isNotEmpty) {

      return degreeType;

    }

    return 'Percorso accademico';

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



  String _cleanError(

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

        'Exception: '.length,

      );

    }

    return message;

  }

}



class _AcademicPathVerificationCard

    extends StatelessWidget {

  final SocialAcademicPath path;

  final bool processing;

  final VoidCallback onApprove;

  final VoidCallback onReject;



  const _AcademicPathVerificationCard({

    required this.path,

    required this.processing,

    required this.onApprove,

    required this.onReject,

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

            AppColors.eleganceMidnight,

        borderRadius:

            BorderRadius.circular(

          18,

        ),

        border:

            Border.all(

          color:

              AppColors.skyBlue

                  .withOpacity(

            0.16,

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

                  Icons

                      .account_balance_outlined,

                  color:

                      AppColors.skyBlue,

                  size:

                      27,

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

                    Text(

                      _title(),

                      maxLines:

                          2,

                      overflow:

                          TextOverflow.ellipsis,

                      style:

                          const TextStyle(

                        color:

                            AppColors.pureWhite,

                        fontSize:

                            15,

                        fontWeight:

                            FontWeight.bold,

                        height:

                            1.25,

                      ),

                    ),

                    const SizedBox(

                      height:

                          5,

                    ),

                    Text(

                      'Utente #${path.userId}',

                      style:

                          const TextStyle(

                        color:

                            Colors.white38,

                        fontSize:

                            9,

                      ),

                    ),

                    const SizedBox(

                      height:

                          7,

                    ),

                    const _AcademicPendingBadge(),

                  ],

                ),

              ),

            ],

          ),

          const SizedBox(

            height:

                16,

          ),

          Divider(

            height:

                1,

            color:

                AppColors.pureWhite

                    .withOpacity(

              0.07,

            ),

          ),

          const SizedBox(

            height:

                14,

          ),

          _AcademicInfoRow(

            icon:

                Icons

                    .account_balance_outlined,

            label:

                'Ateneo',

            value:

                path.university.isEmpty

                    ? 'Non specificato'

                    : path.university,

          ),

          const SizedBox(

            height:

                10,

          ),

          _AcademicInfoRow(

            icon:

                Icons.business_outlined,

            label:

                'Dipartimento',

            value:

                path.department.isEmpty

                    ? 'Non specificato'

                    : path.department,

          ),

          const SizedBox(

            height:

                10,

          ),

          _AcademicInfoRow(

            icon:

                Icons.school_outlined,

            label:

                'Corso',

            value:

                path.course.isEmpty

                    ? 'Non specificato'

                    : path.course,

          ),

          if (

            path.degreeType

                .trim()

                .isNotEmpty

          ) ...[

            const SizedBox(

              height:

                  10,

            ),

            _AcademicInfoRow(

              icon:

                  Icons

                      .workspace_premium_outlined,

              label:

                  'Titolo',

              value:

                  path.degreeType,

            ),

          ],

          const SizedBox(

            height:

                15,

          ),

          Wrap(

            spacing:

                7,

            runSpacing:

                7,

            children: [

              _AcademicStatusBadge(

                status:

                    path.status,

              ),

              if (path.isCurrent)

                const _AcademicSmallBadge(

                  icon:

                      Icons

                          .play_circle_outline_rounded,

                  label:

                      'Corrente',

                ),

              if (path.isPrimary)

                const _AcademicSmallBadge(

                  icon:

                      Icons.star_outline_rounded,

                  label:

                      'Principale',

                ),

              if (

                path.startYear !=

                    null

              )

                _AcademicSmallBadge(

                  icon:

                      Icons

                          .calendar_month_outlined,

                  label:

                      'Dal ${path.startYear}',

                ),

              if (

                path.graduationYear !=

                    null

              )

                _AcademicSmallBadge(

                  icon:

                      Icons

                          .workspace_premium_outlined,

                  label:

                      'Laurea ${path.graduationYear}',

                ),

            ],

          ),

          if (

            path.status ==

                AcademicPathStatus.graduated

          ) ...[

            const SizedBox(

              height:

                  14,

            ),

            Container(

              width:

                  double.infinity,

              padding:

                  const EdgeInsets.all(

                12,

              ),

              decoration:

                  BoxDecoration(

                color:

                    Colors.greenAccent

                        .withOpacity(

                  0.04,

                ),

                borderRadius:

                    BorderRadius.circular(

                  11,

                ),

                border:

                    Border.all(

                  color:

                      Colors.greenAccent

                          .withOpacity(

                    0.12,

                  ),

                ),

              ),

              child:

                  Row(

                crossAxisAlignment:

                    CrossAxisAlignment.start,

                children: [

                  const Icon(

                    Icons

                        .workspace_premium_outlined,

                    color:

                        Colors.greenAccent,

                    size:

                        19,

                  ),

                  const SizedBox(

                    width:

                        9,

                  ),

                  Expanded(

                    child:

                        Text(

                      path.graduationYear ==

                              null

                          ? "L\\'utente dichiara di aver completato questo percorso."

                          : "L\\'utente dichiara di essersi laureato nel ${path.graduationYear}.",

                      style:

                          const TextStyle(

                        color:

                            Colors.white60,

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

          ],

          const SizedBox(

            height:

                18,

          ),

          if (processing)

            const LinearProgressIndicator()

          else

            Row(

              children: [

                Expanded(

                  child:

                      ElevatedButton.icon(

                    onPressed:

                        onApprove,

                    style:

                        ElevatedButton.styleFrom(

                      backgroundColor:

                          Colors.greenAccent,

                      foregroundColor:

                          AppColors

                              .eleganceSoftNight,

                      elevation:

                          0,

                      padding:

                          const EdgeInsets.symmetric(

                        vertical:

                            12,

                      ),

                      shape:

                          RoundedRectangleBorder(

                        borderRadius:

                            BorderRadius.circular(

                          12,

                        ),

                      ),

                    ),

                    icon:

                        const Icon(

                      Icons.verified_outlined,

                    ),

                    label:

                        const Text(

                      'Verifica',

                    ),

                  ),

                ),

                const SizedBox(

                  width:

                      10,

                ),

                Expanded(

                  child:

                      OutlinedButton.icon(

                    onPressed:

                        onReject,

                    style:

                        OutlinedButton.styleFrom(

                      foregroundColor:

                          Colors.redAccent,

                      side:

                          BorderSide(

                        color:

                            Colors.redAccent

                                .withOpacity(

                          0.40,

                        ),

                      ),

                      padding:

                          const EdgeInsets.symmetric(

                        vertical:

                            12,

                      ),

                      shape:

                          RoundedRectangleBorder(

                        borderRadius:

                            BorderRadius.circular(

                          12,

                        ),

                      ),

                    ),

                    icon:

                        const Icon(

                      Icons.close_rounded,

                    ),

                    label:

                        const Text(

                      'Rifiuta',

                    ),

                  ),

                ),

              ],

            ),

        ],

      ),

    );

  }



  String _title() {

    final String course =

        path.course.trim();

    final String degreeType =

        path.degreeType.trim();

    if (

      course.isNotEmpty &&

      degreeType.isNotEmpty

    ) {

      return '$course $degreeType';

    }

    if (course.isNotEmpty) {

      return course;

    }

    if (degreeType.isNotEmpty) {

      return degreeType;

    }

    return 'Percorso accademico';

  }

}



class _AcademicPendingBadge

    extends StatelessWidget {

  const _AcademicPendingBadge();



  @override

  Widget build(

    BuildContext context,

  ) {

    return Container(

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

            Colors.amber

                .withOpacity(

          0.09,

        ),

        borderRadius:

            BorderRadius.circular(

          8,

        ),

        border:

            Border.all(

          color:

              Colors.amber

                  .withOpacity(

            0.20,

          ),

        ),

      ),

      child:

          const Row(

        mainAxisSize:

            MainAxisSize.min,

        children: [

          Icon(

            Icons.schedule_rounded,

            color:

                Colors.amber,

            size:

                12,

          ),

          SizedBox(

            width:

                4,

          ),

          Text(

            'Verifica in attesa',

            style:

                TextStyle(

              color:

                  Colors.amber,

              fontSize:

                  8,

              fontWeight:

                  FontWeight.bold,

            ),

          ),

        ],

      ),

    );

  }

}



class _AcademicInfoRow

    extends StatelessWidget {

  final IconData icon;

  final String label;

  final String value;



  const _AcademicInfoRow({

    required this.icon,

    required this.label,

    required this.value,

  });



  @override

  Widget build(

    BuildContext context,

  ) {

    return Row(

      crossAxisAlignment:

          CrossAxisAlignment.start,

      children: [

        Icon(

          icon,

          color:

              AppColors.materialSky,

          size:

              17,

        ),

        const SizedBox(

          width:

              9,

        ),

        SizedBox(

          width:

              92,

          child:

              Text(

            label,

            style:

                const TextStyle(

              color:

                  Colors.white38,

              fontSize:

                  9,

            ),

          ),

        ),

        Expanded(

          child:

              Text(

            value,

            textAlign:

                TextAlign.right,

            style:

                const TextStyle(

              color:

                  Colors.white70,

              fontSize:

                  10,

              fontWeight:

                  FontWeight.w500,

            ),

          ),

        ),

      ],

    );

  }

}



class _AcademicSmallBadge

    extends StatelessWidget {

  final IconData icon;

  final String label;



  const _AcademicSmallBadge({

    required this.icon,

    required this.label,

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

            5,

      ),

      decoration:

          BoxDecoration(

        color:

            AppColors.skyBlue

                .withOpacity(

          0.08,

        ),

        borderRadius:

            BorderRadius.circular(

          8,

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

                AppColors.materialSky,

            size:

                11,

          ),

          const SizedBox(

            width:

                4,

          ),

          Text(

            label,

            style:

                const TextStyle(

              color:

                  AppColors.materialSky,

              fontSize:

                  8,

              fontWeight:

                  FontWeight.w600,

            ),

          ),

        ],

      ),

    );

  }

}



class _AcademicStatusBadge

    extends StatelessWidget {

  final AcademicPathStatus status;



  const _AcademicStatusBadge({

    required this.status,

  });



  @override

  Widget build(

    BuildContext context,

  ) {

    final String label;

    final IconData icon;

    switch (status) {

      case AcademicPathStatus.enrolled:

        label =

            'Iscritto';

        icon =

            Icons.school_outlined;

        break;

      case AcademicPathStatus.graduated:

        label =

            'Laureato';

        icon =

            Icons

                .workspace_premium_outlined;

        break;

      case AcademicPathStatus.suspended:

        label =

            'Sospeso';

        icon =

            Icons

                .pause_circle_outline_rounded;

        break;

      case AcademicPathStatus.withdrawn:

        label =

            'Interrotto';

        icon =

            Icons

                .remove_circle_outline;

        break;

      case AcademicPathStatus.transferred:

        label =

            'Trasferito';

        icon =

            Icons.swap_horiz_rounded;

        break;

    }

    return _AcademicSmallBadge(

      icon:

          icon,

      label:

          label,

    );

  }

}



class _EmptyAcademicPaths

    extends StatelessWidget {

  const _EmptyAcademicPaths();



  @override

  Widget build(

    BuildContext context,

  ) {

    return ListView(

      physics:

          const AlwaysScrollableScrollPhysics(),

      padding:

          const EdgeInsets.all(

        20,

      ),

      children: [

        const SizedBox(

          height:

              100,

        ),

        Container(

          width:

              double.infinity,

          padding:

              const EdgeInsets.all(

            28,

          ),

          decoration:

              BoxDecoration(

            color:

                AppColors.eleganceMidnight,

            borderRadius:

                BorderRadius.circular(

              18,

            ),

            border:

                Border.all(

              color:

                  AppColors.skyBlue

                      .withOpacity(

                0.10,

              ),

            ),

          ),

          child:

              const Column(

            children: [

              Icon(

                Icons

                    .account_balance_outlined,

                color:

                    Colors.white38,

                size:

                    46,

              ),

              SizedBox(

                height:

                    13,

              ),

              Text(

                'Nessun percorso accademico in attesa di verifica.',

                textAlign:

                    TextAlign.center,

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

      ],

    );

  }

}



class _AcademicPathError

    extends StatelessWidget {

  final String message;

  final Future<void> Function({

    bool refresh,

  }) onRetry;



  const _AcademicPathError({

    required this.message,

    required this.onRetry,

  });



  @override

  Widget build(

    BuildContext context,

  ) {

    return Center(

      child:

          Padding(

        padding:

            const EdgeInsets.all(

          20,

        ),

        child:

            Container(

          width:

              double.infinity,

          padding:

              const EdgeInsets.all(

            24,

          ),

          decoration:

              BoxDecoration(

            color:

                AppColors.eleganceMidnight,

            borderRadius:

                BorderRadius.circular(

              18,

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

                Icons.error_outline_rounded,

                color:

                    Colors.redAccent,

                size:

                    40,

              ),

              const SizedBox(

                height:

                    12,

              ),

              const Text(

                'Impossibile caricare i percorsi',

                textAlign:

                    TextAlign.center,

                style:

                    TextStyle(

                  color:

                      AppColors.pureWhite,

                  fontSize:

                      15,

                  fontWeight:

                      FontWeight.bold,

                ),

              ),

              const SizedBox(

                height:

                    8,

              ),

              Text(

                message,

                textAlign:

                    TextAlign.center,

                style:

                    const TextStyle(

                  color:

                      Colors.white60,

                  fontSize:

                      11,

                ),

              ),

              const SizedBox(

                height:

                    16,

              ),

              OutlinedButton.icon(

                onPressed:

                    () {

                  onRetry();

                },

                icon:

                    const Icon(

                  Icons.refresh_rounded,

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

    );

  }

}