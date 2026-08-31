import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../../services/api_service.dart';

import '../social_models.dart';
import '../groups/models/study_group.dart';


// =============================================================================
// GROUP PARTICIPANTS LAYER
// =============================================================================

class GroupParticipantsLayer extends StatefulWidget {
  final StudyGroup group;

  const GroupParticipantsLayer({
    super.key,
    required this.group,
  });

  @override
  State<GroupParticipantsLayer> createState() =>
      _GroupParticipantsLayerState();
}


// =============================================================================
// STATE
// =============================================================================

class _GroupParticipantsLayerState
    extends State<GroupParticipantsLayer> {

  final ApiService _apiService =
      ApiService();


  List<_GroupParticipant> _participants =
      [];


  bool _loading =
      true;


  String? _error;


  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _loadParticipants();
  }


  // ===========================================================================
  // LOAD PARTICIPANTS
  // ===========================================================================

  Future<void> _loadParticipants() async {
    setState(() {
      _loading =
          true;

      _error =
          null;
    });


    try {
      final Map<String, dynamic> groupData =
          await _apiService.getGroup(
        widget.group.id,
      );


      final dynamic membersData =
          groupData['members'];


      if (membersData is! List) {
        throw Exception(
          'Lista partecipanti non valida.',
        );
      }


      final List<_GroupParticipant> result =
          [];


      for (final dynamic item
          in membersData) {

        if (item is! Map) {
          continue;
        }


        final Map<String, dynamic> member =
            Map<String, dynamic>.from(
          item,
        );


        final int? userId =
            _toInt(
          member['user_id'],
        );


        if (userId == null) {
          continue;
        }


        final SocialUser user =
            await _apiService.getSocialUser(
          userId,
        );


        result.add(
          _GroupParticipant(
            membershipId:
                _toInt(
                      member['id'],
                    ) ??
                    0,

            role:
                member['role']
                        ?.toString() ??
                    'member',

            joinedAt:
                DateTime.tryParse(
              member['joined_at']
                      ?.toString() ??
                  '',
            ),

            user:
                user,
          ),
        );
      }


      if (!mounted) {
        return;
      }


      setState(() {
        _participants =
            result;

        _loading =
            false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }


      setState(() {
        _loading =
            false;

        _error =
            e.toString();
      });
    }
  }


  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor:
            AppColors.brandNightBlue,

        foregroundColor:
            AppColors.pureWhite,

        elevation:
            0,

        title: const Text(
          'Partecipanti',

          style: TextStyle(
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
                _loading
                    ? null
                    : _loadParticipants,

            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder:
                (
              context,
              constraints,
            ) {

              final double width =
                  constraints.maxWidth > 900
                      ? 900
                      : constraints.maxWidth;


              return SizedBox(
                width:
                    width,

                child:
                    _buildBody(),
              );
            },
          ),
        ),
      ),
    );
  }


  // ===========================================================================
  // BODY
  // ===========================================================================

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }


    if (_error != null) {
      return _buildErrorState();
    }


    if (_participants.isEmpty) {
      return RefreshIndicator(
        onRefresh:
            _loadParticipants,

        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          children: [
            SizedBox(
              height:
                  500,

              child:
                  _buildEmptyState(),
            ),
          ],
        ),
      );
    }


    return RefreshIndicator(
      onRefresh:
          _loadParticipants,

      child:
          _buildContent(),
    );
  }


  // ===========================================================================
  // CONTENT
  // ===========================================================================

  Widget _buildContent() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      padding:
          const EdgeInsets.all(
        20,
      ),

      children: [
        _buildGroupCard(),

        const SizedBox(
          height:
              24,
        ),

        Row(
          children: [
            const Expanded(
              child:
                  Text(
                'Partecipanti',

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite,

                  fontSize:
                      20,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    10,

                vertical:
                    5,
              ),

              decoration:
                  BoxDecoration(
                color:
                    AppColors.brandNightBlue,

                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),

              child:
                  Text(
                '${_participants.length}',

                style:
                    const TextStyle(
                  color:
                      AppColors.materialSky,

                  fontSize:
                      12,

                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(
          height:
              6,
        ),

        Text(
          'Studenti e membri del gruppo di studio.',

          style:
              TextStyle(
            color:
                AppColors.pureWhite
                    .withOpacity(
              0.55,
            ),

            fontSize:
                13,
          ),
        ),

        const SizedBox(
          height:
              16,
        ),

        _buildParticipantsGrid(),
      ],
    );
  }


  // ===========================================================================
  // GROUP CARD
  // ===========================================================================

  Widget _buildGroupCard() {
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
            AppColors.eleganceDeepNavy,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.15,
          ),
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.12,
            ),

            blurRadius:
                8,

            offset:
                const Offset(
              0,
              4,
            ),
          ),
        ],
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
                    56,

                height:
                    56,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.brandNightBlue,

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),

                child:
                    const Icon(
                  Icons.menu_book_rounded,

                  color:
                      AppColors.skyBlue,

                  size:
                      30,
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
                    Text(
                      widget.group.name,

                      maxLines:
                          2,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          const TextStyle(
                        color:
                            AppColors.pureWhite,

                        fontSize:
                            20,

                        fontWeight:
                            FontWeight.bold,

                        height:
                            1.2,
                      ),
                    ),

                    const SizedBox(
                      height:
                          5,
                    ),

                    Text(
                      _subjectName,

                      maxLines:
                          1,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          TextStyle(
                        color:
                            AppColors.materialSky
                                .withOpacity(
                          0.9,
                        ),

                        fontSize:
                            13,

                        fontWeight:
                            FontWeight.w600,
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

          Text(
            widget.group.description,

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

          const SizedBox(
            height:
                18,
          ),

          Row(
            children: [
              const Icon(
                Icons.people_outline_rounded,

                color:
                    AppColors.materialSky,

                size:
                    17,
              ),

              const SizedBox(
                width:
                    6,
              ),

              Text(
                '${_participants.length} partecipanti',

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite
                          .withOpacity(
                    0.60,
                  ),

                  fontSize:
                      12,

                  fontWeight:
                      FontWeight.w500,
                ),
              ),

              const Spacer(),

              if (widget.group.isPrivate)
                const Icon(
                  Icons.lock_outline_rounded,

                  color:
                      Colors.white38,

                  size:
                      18,
                ),
            ],
          ),
        ],
      ),
    );
  }


  // ===========================================================================
  // SUBJECT NAME
  // ===========================================================================

  String get _subjectName {
    if (widget.group.subject
        .trim()
        .isNotEmpty) {
      return widget.group.subject;
    }


    if (widget.group.subjectId !=
        null) {
      return 'Materia #${widget.group.subjectId}';
    }


    return widget.group.name;
  }


  // ===========================================================================
  // GRID
  // ===========================================================================

  Widget _buildParticipantsGrid() {
    return LayoutBuilder(
      builder:
          (
        context,
        constraints,
      ) {

        final bool singleColumn =
            constraints.maxWidth <
                560;


        return GridView.builder(
          shrinkWrap:
              true,

          physics:
              const NeverScrollableScrollPhysics(),

          itemCount:
              _participants.length,

          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                singleColumn
                    ? 1
                    : 2,

            crossAxisSpacing:
                14,

            mainAxisSpacing:
                14,

            mainAxisExtent:
                singleColumn
                    ? 128
                    : 145,
          ),

          itemBuilder:
              (
            context,
            index,
          ) {

            final _GroupParticipant participant =
                _participants[index];


            return _ParticipantCard(
              participant:
                  participant,

              onTap:
                  () {
                _openUser(
                  participant.user,
                );
              },
            );
          },
        );
      },
    );
  }


  // ===========================================================================
  // OPEN USER
  // ===========================================================================

  void _openUser(
    SocialUser user,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(
          'Apertura profilo di ${user.name}: da implementare.',
        ),
      ),
    );


    /*
     * In seguito:
     *
     * Navigator.push(
     *   context,
     *   MaterialPageRoute(
     *     builder: (_) => SocialUserProfilePage(
     *       userId: user.id,
     *     ),
     *   ),
     * );
     */
  }


  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh:
          _loadParticipants,

      child:
          ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.all(
          20,
        ),

        children: [
          const SizedBox(
            height:
                70,
          ),

          Container(
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
                  0.20,
                ),
              ),
            ),

            child:
                Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,

                  color:
                      Colors.redAccent,

                  size:
                      42,
                ),

                const SizedBox(
                  height:
                      12,
                ),

                const Text(
                  'Errore caricamento partecipanti',

                  textAlign:
                      TextAlign.center,

                  style:
                      TextStyle(
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
                      8,
                ),

                Text(
                  _error ??
                      'Errore sconosciuto.',

                  textAlign:
                      TextAlign.center,

                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.50,
                    ),

                    fontSize:
                        11,

                    height:
                        1.4,
                  ),
                ),

                const SizedBox(
                  height:
                      16,
                ),

                OutlinedButton.icon(
                  onPressed:
                      _loadParticipants,

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
        ],
      ),
    );
  }


  // ===========================================================================
  // EMPTY
  // ===========================================================================

  Widget _buildEmptyState() {
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
                    AppColors.brandNightBlue,

                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),

              child:
                  const Icon(
                Icons.people_outline_rounded,

                color:
                    AppColors.skyBlue,

                size:
                    38,
              ),
            ),

            const SizedBox(
              height:
                  18,
            ),

            const Text(
              'Nessun partecipante',

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite,

                fontSize:
                    20,

                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            Text(
              'Non ci sono ancora partecipanti da mostrare.',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withOpacity(
                  0.55,
                ),

                fontSize:
                    13,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ===========================================================================
  // UTILITY
  // ===========================================================================

  static int? _toInt(
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
}


// =============================================================================
// PARTICIPANT CARD
// =============================================================================

class _ParticipantCard
    extends StatelessWidget {

  final _GroupParticipant participant;

  final VoidCallback onTap;


  const _ParticipantCard({
    required this.participant,
    required this.onTap,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final SocialUser user =
        participant.user;


    return InkWell(
      onTap:
          onTap,

      borderRadius:
          BorderRadius.circular(
        16,
      ),

      child:
          Container(
        width:
            double.infinity,

        padding:
            const EdgeInsets.all(
          14,
        ),

        decoration:
            BoxDecoration(
          color:
              AppColors.eleganceMidnight,

          borderRadius:
              BorderRadius.circular(
            16,
          ),

          border:
              Border.all(
            color:
                AppColors.skyBlue
                    .withOpacity(
              0.12,
            ),
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black
                      .withOpacity(
                0.10,
              ),

              blurRadius:
                  6,

              offset:
                  const Offset(
                0,
                3,
              ),
            ),
          ],
        ),

        child:
            Row(
          children: [
            Container(
              width:
                  48,

              height:
                  48,

              decoration:
                  const BoxDecoration(
                color:
                    AppColors.brandNightBlue,

                shape:
                    BoxShape.circle,
              ),

              child:
                  Center(
                child:
                    Text(
                  _initials(
                    user.name,
                  ),

                  style:
                      const TextStyle(
                    color:
                        AppColors.skyBlue,

                    fontSize:
                        15,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(
              width:
                  12,
            ),

            Expanded(
              child:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Flexible(
                        child:
                            Text(
                          user.name,

                          maxLines:
                              1,

                          overflow:
                              TextOverflow.ellipsis,

                          style:
                              const TextStyle(
                            color:
                                AppColors.pureWhite,

                            fontSize:
                                14,

                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width:
                            7,
                      ),

                      _RoleBadge(
                        role:
                            participant.role,
                      ),

                      if (user.available) ...[
                        const SizedBox(
                          width:
                              7,
                        ),

                        Container(
                          width:
                              7,

                          height:
                              7,

                          decoration:
                              const BoxDecoration(
                            color:
                                Colors.greenAccent,

                            shape:
                                BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(
                    height:
                        4,
                  ),

                  Text(
                    '${user.department} • ${user.course}',

                    maxLines:
                        1,

                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite
                              .withOpacity(
                        0.50,
                      ),

                      fontSize:
                          11,
                    ),
                  ),

                  if (user.subjects.isNotEmpty) ...[
                    const SizedBox(
                      height:
                          5,
                    ),

                    Text(
                      user.subjects
                          .map(
                            (
                              subject,
                            ) =>
                                subject.name,
                          )
                          .join(
                            ' • ',
                          ),

                      maxLines:
                          1,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          TextStyle(
                        color:
                            AppColors.materialSky
                                .withOpacity(
                          0.85,
                        ),

                        fontSize:
                            10,

                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(
              width:
                  8,
            ),

            const Icon(
              Icons.chevron_right_rounded,

              color:
                  Colors.white38,

              size:
                  22,
            ),
          ],
        ),
      ),
    );
  }


  // ===========================================================================
  // INITIALS
  // ===========================================================================

  String _initials(
    String name,
  ) {
    final String trimmed =
        name.trim();


    if (trimmed.isEmpty) {
      return '?';
    }


    final List<String> parts =
        trimmed.split(
      RegExp(
        r'\s+',
      ),
    );


    if (parts.length ==
        1) {
      return parts.first
          .substring(
            0,
            1,
          )
          .toUpperCase();
    }


    return (
      parts.first.substring(
        0,
        1,
      ) +
      parts.last.substring(
        0,
        1,
      )
    ).toUpperCase();
  }
}


// =============================================================================
// ROLE BADGE
// =============================================================================

class _RoleBadge
    extends StatelessWidget {

  final String role;


  const _RoleBadge({
    required this.role,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final String label;

    switch (role.toLowerCase()) {
      case 'owner':
        label =
            'OWNER';
        break;

      case 'admin':
        label =
            'ADMIN';
        break;

      default:
        label =
            'MEMBER';
    }


    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            6,

        vertical:
            3,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.skyBlue
                .withOpacity(
          0.10,
        ),

        borderRadius:
            BorderRadius.circular(
          6,
        ),
      ),

      child:
          Text(
        label,

        style:
            const TextStyle(
          color:
              AppColors.materialSky,

          fontSize:
              7,

          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }
}


// =============================================================================
// GROUP PARTICIPANT MODEL
// =============================================================================

class _GroupParticipant {
  final int membershipId;

  final String role;

  final DateTime? joinedAt;

  final SocialUser user;


  const _GroupParticipant({
    required this.membershipId,
    required this.role,
    required this.joinedAt,
    required this.user,
  });
}