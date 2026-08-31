import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../../services/api_service.dart';

import '../social_models.dart';

import '../groups/models/study_group.dart';


// =============================================================================
// GROUP ADMIN LAYER
// =============================================================================

class GroupAdminLayer extends StatefulWidget {
  final StudyGroup group;

  const GroupAdminLayer({
    super.key,
    required this.group,
  });

  @override
  State<GroupAdminLayer> createState() =>
      _GroupAdminLayerState();
}


// =============================================================================
// STATE
// =============================================================================

class _GroupAdminLayerState
    extends State<GroupAdminLayer> {

  final ApiService _apiService =
      ApiService();


  // ===========================================================================
  // PARTECIPANTI
  // ===========================================================================

  List<_GroupParticipant>
      _participants =
      [];


  // ===========================================================================
  // RICHIESTE
  // ===========================================================================

  List<_JoinRequest>
      _requests =
      [];


  // ===========================================================================
  // UTENTI DISPONIBILI
  // ===========================================================================

  List<SocialUser>
      _usersToInvite =
      [];


  // ===========================================================================
  // STATO
  // ===========================================================================

  bool _loading =
      true;

  String? _error;


  int? _busyUserId;

  int? _busyRequestId;


  bool _deletingGroup =
      false;


  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _loadAdminData();
  }


  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<void> _loadAdminData() async {
    setState(() {
      _loading =
          true;

      _error =
          null;
    });


    try {
      final int groupId =
          widget.group.id;


      // =======================================================================
      // GRUPPO + MEMBRI
      // =======================================================================

      final Map<String, dynamic>
          groupData =
          await _apiService.getGroup(
        groupId,
      );


      final List<_GroupParticipant>
          participants =
          await _loadParticipants(
        groupData,
      );


      // =======================================================================
      // RICHIESTE
      // =======================================================================

      final List<_JoinRequest>
          requests =
          await _loadRequests(
        groupId,
      );


      // =======================================================================
      // UTENTI
      // =======================================================================

      final List<SocialUser>
          allUsers =
          await _apiService
              .getSocialUsers();


      final Set<int>
          currentParticipantIds =
          participants
              .map(
                (
                  participant,
                ) =>
                    participant.user.id,
              )
              .toSet();


      final List<SocialUser>
          usersToInvite =
          allUsers
              .where(
                (
                  user,
                ) =>
                    !currentParticipantIds
                        .contains(
                      user.id,
                    ),
              )
              .toList();


      if (!mounted) {
        return;
      }


      setState(() {
        _participants =
            participants;

        _requests =
            requests;

        _usersToInvite =
            usersToInvite;

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
  // PARTECIPANTI DAL DETTAGLIO GRUPPO
  // ===========================================================================

  Future<List<_GroupParticipant>>
      _loadParticipants(
    Map<String, dynamic> groupData,
  ) async {

    final dynamic rawMembers =
        groupData['members'];


    if (rawMembers is! List) {
      return [];
    }


    final List<_GroupParticipant>
        participants =
        [];


    for (final dynamic rawMember
        in rawMembers) {

      if (rawMember is! Map) {
        continue;
      }


      final Map<String, dynamic>
          member =
          Map<String, dynamic>.from(
        rawMember,
      );


      final int? userId =
          _toInt(
        member['user_id'],
      );


      if (userId == null) {
        continue;
      }


      try {
        final SocialUser user =
            await _apiService
                .getSocialUser(
          userId,
        );


        participants.add(
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
      } catch (_) {
        // Se un profilo non è disponibile,
        // non blocchiamo tutta la pagina.
      }
    }


    return participants;
  }


  // ===========================================================================
  // RICHIESTE
  // ===========================================================================

  Future<List<_JoinRequest>>
      _loadRequests(
    int groupId,
  ) async {

    try {
      final List<Map<String, dynamic>>
          rawRequests =
          await _apiService
              .getGroupRequests(
        groupId,
      );


      final List<_JoinRequest>
          result =
          [];


      for (final rawRequest
          in rawRequests) {

        final int? requestId =
            _toInt(
          rawRequest['id'],
        );


        final int? userId =
            _toInt(
          rawRequest['user_id'],
        );


        if (requestId == null ||
            userId == null) {
          continue;
        }


        try {
          final SocialUser user =
              await _apiService
                  .getSocialUser(
            userId,
          );


          result.add(
            _JoinRequest(
              id:
                  requestId,

              userId:
                  userId,

              user:
                  user,

              status:
                  rawRequest['status']
                          ?.toString() ??
                      'pending',

              createdAt:
                  DateTime.tryParse(
                rawRequest['created_at']
                        ?.toString() ??
                    '',
              ),
            ),
          );
        } catch (_) {
          // Ignoriamo la singola richiesta
          // se il profilo non è leggibile.
        }
      }


      return result;
    } catch (_) {
      /*
       * Se non ci sono richieste o l'endpoint
       * non restituisce dati utilizzabili,
       * la sezione rimane semplicemente vuota.
       */
      return [];
    }
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
          'Amministrazione gruppo',

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
                _loading
                    ? null
                    : _loadAdminData,

            icon:
                const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body:
          SafeArea(
        child:
            _buildBody(),
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
      return Center(
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            20,
          ),

          child:
              _AdminErrorCard(
            message:
                _error!,

            onRetry:
                _loadAdminData,
          ),
        ),
      );
    }


    return Center(
      child:
          LayoutBuilder(
        builder:
            (
          context,
          constraints,
        ) {

          final double width =
              constraints.maxWidth >
                      700
                  ? 700
                  : constraints
                      .maxWidth;


          return SizedBox(
            width:
                width,

            child:
                RefreshIndicator(
              onRefresh:
                  _loadAdminData,

              child:
                  ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),

                padding:
                    const EdgeInsets.all(
                  20,
                ),

                children: [
                  _buildGroupHeader(),

                  const SizedBox(
                    height:
                        20,
                  ),

                  _buildParticipantsSection(),

                  const SizedBox(
                    height:
                        20,
                  ),

                  _buildRequestsSection(),

                  const SizedBox(
                    height:
                        20,
                  ),

                  _buildInviteSection(),

                  const SizedBox(
                    height:
                        20,
                  ),

                  _buildMaterialsSection(),

                  const SizedBox(
                    height:
                        20,
                  ),

                  _buildSettingsSection(),

                  const SizedBox(
                    height:
                        30,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildGroupHeader() {
    return Container(
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
      ),

      child:
          Row(
        children: [
          Container(
            width:
                58,

            height:
                58,

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
              Icons.groups_rounded,

              color:
                  AppColors.skyBlue,

              size:
                  31,
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
                        19,

                    fontWeight:
                        FontWeight.bold,
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

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  '${widget.group.department} • ${widget.group.course}',

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
              ],
            ),
          ),

          Container(
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
                  AppColors.skyBlue
                      .withOpacity(
                0.10,
              ),

              borderRadius:
                  BorderRadius.circular(
                8,
              ),
            ),

            child:
                const Text(
              'OWNER',

              style:
                  TextStyle(
                color:
                    AppColors.materialSky,

                fontSize:
                    9,

                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


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


    return 'Materia non specificata';
  }


  // ===========================================================================
  // PARTECIPANTI
  // ===========================================================================

  Widget _buildParticipantsSection() {
    return _AdminSection(
      title:
          'Partecipanti',

      subtitle:
          '${_participants.length} persone nel gruppo',

      icon:
          Icons.people_outline_rounded,

      child:
          _participants.isEmpty
              ? _buildEmptySmall(
                  icon:
                      Icons.people_outline_rounded,

                  text:
                      'Nessun partecipante.',
                )
              : Column(
                  children: [
                    for (int i = 0;
                        i <
                            _participants.length;
                        i++) ...[
                      _ParticipantTile(
                        participant:
                            _participants[i],

                        busy:
                            _busyUserId ==
                                _participants[i]
                                    .user
                                    .id,

                        onRemove:
                            () {
                          _removeParticipant(
                            _participants[i],
                          );
                        },
                      ),

                      if (i <
                          _participants.length -
                              1)
                        Divider(
                          height:
                              1,

                          color:
                              Colors.white
                                  .withOpacity(
                            0.07,
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }


  // ===========================================================================
  // RICHIESTE
  // ===========================================================================

  Widget _buildRequestsSection() {
    final List<_JoinRequest>
        pendingRequests =
        _requests
            .where(
              (
                request,
              ) =>
                  request.status
                      .toLowerCase() ==
                  'pending',
            )
            .toList();


    return _AdminSection(
      title:
          'Richieste di partecipazione',

      subtitle:
          '${pendingRequests.length} richieste in attesa',

      icon:
          Icons.person_add_alt_1_rounded,

      trailing:
          pendingRequests.isNotEmpty
              ? _Badge(
                  text:
                      '${pendingRequests.length}',
                )
              : null,

      child:
          pendingRequests.isEmpty
              ? _buildEmptySmall(
                  icon:
                      Icons.check_circle_outline,

                  text:
                      'Non ci sono richieste in attesa.',
                )
              : Column(
                  children: [
                    for (int i = 0;
                        i <
                            pendingRequests.length;
                        i++) ...[
                      _RequestTile(
                        request:
                            pendingRequests[i],

                        busy:
                            _busyRequestId ==
                                pendingRequests[i]
                                    .id,

                        onAccept:
                            () {
                          _acceptRequest(
                            pendingRequests[i],
                          );
                        },

                        onReject:
                            () {
                          _rejectRequest(
                            pendingRequests[i],
                          );
                        },
                      ),

                      if (i <
                          pendingRequests.length -
                              1)
                        Divider(
                          height:
                              1,

                          color:
                              Colors.white
                                  .withOpacity(
                            0.07,
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }


  // ===========================================================================
  // INVITA
  // ===========================================================================

  Widget _buildInviteSection() {
    return _AdminSection(
      title:
          'Invita partecipanti',

      subtitle:
          'Cerca studenti o insegnanti da aggiungere.',

      icon:
          Icons.person_add_rounded,

      child:
          InkWell(
        onTap:
            () {
          _showInviteSearch(
            context,
          );
        },

        borderRadius:
            BorderRadius.circular(
          13,
        ),

        child:
            Container(
          width:
              double.infinity,

          padding:
              const EdgeInsets.symmetric(
            horizontal:
                14,

            vertical:
                13,
          ),

          decoration:
              BoxDecoration(
            color:
                AppColors.brandNightBlue,

            borderRadius:
                BorderRadius.circular(
              13,
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
              Row(
            children: [
              const Icon(
                Icons.search_rounded,

                color:
                    AppColors.skyBlue,

                size:
                    21,
              ),

              const SizedBox(
                width:
                    10,
              ),

              Expanded(
                child:
                    Text(
                  'Cerca studenti o insegnanti',

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
              ),

              const Icon(
                Icons.chevron_right_rounded,

                color:
                    Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ===========================================================================
  // MATERIALI
  // ===========================================================================

  Widget _buildMaterialsSection() {
    return _AdminSection(
      title:
          'Materiali',

      subtitle:
          'Gestisci i file condivisi nel gruppo.',

      icon:
          Icons.folder_outlined,

      child:
          Column(
        children: [
          _AdminActionTile(
            icon:
                Icons.upload_file_rounded,

            title:
                'Aggiungi materiale',

            description:
                'Apri il dettaglio gruppo per caricare un nuovo file.',

            onTap:
                () {
              Navigator.of(
                context,
              ).pop();
            },
          ),

          const SizedBox(
            height:
                8,
          ),

          _AdminActionTile(
            icon:
                Icons.folder_open_rounded,

            title:
                'Gestisci materiali',

            description:
                'Visualizza i materiali disponibili nel gruppo.',

            onTap:
                () {
              /*
               * Puoi collegare qui GroupMaterialsPage,
               * se vuoi mantenere una pagina separata.
               */
              _showMessage(
                'Apri la pagina materiali del gruppo.',
              );
            },
          ),
        ],
      ),
    );
  }


  // ===========================================================================
  // SETTINGS
  // ===========================================================================

  Widget _buildSettingsSection() {
    return _AdminSection(
      title:
          'Impostazioni',

      subtitle:
          'Modifica le impostazioni del gruppo.',

      icon:
          Icons.settings_outlined,

      child:
          Column(
        children: [
          _AdminActionTile(
            icon:
                Icons.edit_outlined,

            title:
                'Modifica gruppo',

            description:
                'Nome, descrizione e informazioni del gruppo.',

            onTap:
                () {
              _showMessage(
                'Collegheremo qui PATCH /update_group/${widget.group.id}.',
              );
            },
          ),

          const SizedBox(
            height:
                8,
          ),

          _AdminActionTile(
            icon:
                Icons.lock_outline_rounded,

            title:
                'Privacy del gruppo',

            description:
                widget.group.isPrivate
                    ? 'Gruppo privato'
                    : 'Gruppo pubblico',

            onTap:
                _showPrivacyDialog,
          ),

          const SizedBox(
            height:
                8,
          ),

          _AdminActionTile(
            icon:
                Icons.delete_outline_rounded,

            title:
                'Elimina gruppo',

            description:
                'Elimina definitivamente il gruppo.',

            danger:
                true,

            onTap:
                _deletingGroup
                    ? () {}
                    : _confirmDeleteGroup,
          ),
        ],
      ),
    );
  }


  // ===========================================================================
  // RICERCA INVITI
  // ===========================================================================

  void _showInviteSearch(
    BuildContext context,
  ) {
    final TextEditingController
        controller =
        TextEditingController();


    showModalBottomSheet(
      context:
          context,

      isScrollControlled:
          true,

      backgroundColor:
          AppColors.eleganceDeepNavy,

      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top:
              Radius.circular(
            20,
          ),
        ),
      ),

      builder:
          (
        sheetContext,
      ) {
        return StatefulBuilder(
          builder:
              (
            context,
            setModalState,
          ) {

            final String query =
                controller.text
                    .trim()
                    .toLowerCase();


            final List<SocialUser>
                users =
                _usersToInvite
                    .where(
                      (
                        user,
                      ) {

                        if (query.isEmpty) {
                          return true;
                        }


                        final String searchable =
                            [
                          user.name,
                          user.email,
                          user.course,
                          user.department,
                        ].join(
                          ' ',
                        ).toLowerCase();


                        return searchable
                            .contains(
                          query,
                        );
                      },
                    )
                    .toList();


            return SafeArea(
              child:
                  Padding(
                padding:
                    EdgeInsets.only(
                  left:
                      20,

                  right:
                      20,

                  top:
                      20,

                  bottom:
                      MediaQuery.of(
                            context,
                          ).viewInsets.bottom +
                          20,
                ),

                child:
                    SizedBox(
                  height:
                      MediaQuery.of(
                            context,
                          ).size.height *
                          0.68,

                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Invita partecipanti',

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite,

                          fontSize:
                              19,

                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height:
                            14,
                      ),

                      TextField(
                        controller:
                            controller,

                        autofocus:
                            true,

                        onChanged:
                            (
                          _,
                        ) {
                          setModalState(
                            () {},
                          );
                        },

                        style:
                            const TextStyle(
                          color:
                              AppColors.pureWhite,
                        ),

                        decoration:
                            InputDecoration(
                          hintText:
                              'Cerca utente...',

                          hintStyle:
                              const TextStyle(
                            color:
                                Colors.white38,
                          ),

                          prefixIcon:
                              const Icon(
                            Icons.search_rounded,

                            color:
                                AppColors.skyBlue,
                          ),

                          filled:
                              true,

                          fillColor:
                              AppColors.brandNightBlue,

                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              13,
                            ),

                            borderSide:
                                BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                            14,
                      ),

                      Expanded(
                        child:
                            users.isEmpty
                                ? const Center(
                                    child:
                                        Text(
                                      'Nessun utente disponibile.',

                                      style:
                                          TextStyle(
                                        color:
                                            Colors.white54,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount:
                                        users.length,

                                    itemBuilder:
                                        (
                                      context,
                                      index,
                                    ) {

                                      final SocialUser user =
                                          users[index];


                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(
                                          bottom:
                                              8,
                                        ),

                                        child:
                                            _InviteTile(
                                          user:
                                              user,

                                          onInvite:
                                              () async {

                                            Navigator.pop(
                                              sheetContext,
                                            );


                                            await _inviteUser(
                                              user,
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(
      controller.dispose,
    );
  }


  // ===========================================================================
  // INVITA / AGGIUNGI UTENTE
  // ===========================================================================

  Future<void> _inviteUser(
    SocialUser user,
  ) async {

    setState(() {
      _busyUserId =
          user.id;
    });


    try {
      await _apiService.addGroupMember(
        groupId:
            widget.group.id,

        userId:
            user.id,

        role:
            'member',
      );


      await _loadAdminData();


      if (!mounted) {
        return;
      }


      _showMessage(
        '${user.name} è stato aggiunto al gruppo.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }


      _showMessage(
        'Errore aggiunta partecipante: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyUserId =
              null;
        });
      }
    }
  }


  // ===========================================================================
  // REMOVE PARTICIPANT
  // ===========================================================================

  Future<void> _removeParticipant(
    _GroupParticipant participant,
  ) async {

    if (participant.role ==
        'owner') {

      _showMessage(
        'L\'owner non può essere rimosso dal gruppo.',
      );

      return;
    }


    setState(() {
      _busyUserId =
          participant.user.id;
    });


    try {
      await _apiService
          .removeGroupMember(
        groupId:
            widget.group.id,

        userId:
            participant.user.id,
      );


      await _loadAdminData();


      if (!mounted) {
        return;
      }


      _showMessage(
        '${participant.user.name} è stato rimosso dal gruppo.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }


      _showMessage(
        'Errore rimozione partecipante: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyUserId =
              null;
        });
      }
    }
  }


  // ===========================================================================
  // ACCEPT REQUEST
  // ===========================================================================

  Future<void> _acceptRequest(
    _JoinRequest request,
  ) async {

    setState(() {
      _busyRequestId =
          request.id;
    });


    try {
      await _apiService
          .acceptGroupRequest(
        request.id,
      );


      await _loadAdminData();


      if (!mounted) {
        return;
      }


      _showMessage(
        '${request.user.name} è stato aggiunto al gruppo.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }


      _showMessage(
        'Errore accettazione richiesta: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestId =
              null;
        });
      }
    }
  }


  // ===========================================================================
  // REJECT REQUEST
  // ===========================================================================

  Future<void> _rejectRequest(
    _JoinRequest request,
  ) async {

    setState(() {
      _busyRequestId =
          request.id;
    });


    try {
      await _apiService
          .rejectGroupRequest(
        request.id,
      );


      await _loadAdminData();


      if (!mounted) {
        return;
      }


      _showMessage(
        'Richiesta di ${request.user.name} rifiutata.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }


      _showMessage(
        'Errore rifiuto richiesta: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestId =
              null;
        });
      }
    }
  }


  // ===========================================================================
  // PRIVACY
  // ===========================================================================

  void _showPrivacyDialog() {
    showDialog(
      context:
          context,

      builder:
          (
        dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              AppColors.eleganceDeepNavy,

          title:
              const Text(
            'Privacy del gruppo',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),

          content:
              Text(
            widget.group.isPrivate
                ? 'Questo gruppo è privato.'
                : 'Questo gruppo è pubblico.',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite
                      .withOpacity(
                0.65,
              ),
            ),
          ),

          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
                  const Text(
                'Chiudi',
              ),
            ),
          ],
        );
      },
    );
  }


  // ===========================================================================
  // DELETE GROUP
  // ===========================================================================

  Future<void> _confirmDeleteGroup() async {
    final bool? confirmed =
        await showDialog<bool>(
      context:
          context,

      builder:
          (
        dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              AppColors.eleganceDeepNavy,

          title:
              const Text(
            'Eliminare il gruppo?',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),

          content:
              Text(
            'Questa operazione eliminerà definitivamente il gruppo e i suoi contenuti.',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite
                      .withOpacity(
                0.65,
              ),
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
                'Elimina',

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


    if (confirmed !=
        true) {
      return;
    }


    setState(() {
      _deletingGroup =
          true;
    });


    try {
      await _apiService.deleteGroup(
        widget.group.id,
      );


      if (!mounted) {
        return;
      }


      Navigator.of(
        context,
      ).pop(
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }


      _showMessage(
        'Errore eliminazione gruppo: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingGroup =
              false;
        });
      }
    }
  }


  // ===========================================================================
  // EMPTY
  // ===========================================================================

  Widget _buildEmptySmall({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding:
          const EdgeInsets.all(
        20,
      ),

      child:
          Column(
        children: [
          Icon(
            icon,

            color:
                Colors.white38,

            size:
                32,
          ),

          const SizedBox(
            height:
                8,
          ),

          Text(
            text,

            textAlign:
                TextAlign.center,

            style:
                const TextStyle(
              color:
                  Colors.white54,

              fontSize:
                  12,
            ),
          ),
        ],
      ),
    );
  }


  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(
    String message,
  ) {
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
// ADMIN SECTION
// =============================================================================

class _AdminSection
    extends StatelessWidget {

  final String title;

  final String subtitle;

  final IconData icon;

  final Widget child;

  final Widget? trailing;


  const _AdminSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.charcoalGrey,

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
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width:
                    42,

                height:
                    42,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.brandNightBlue,

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    Icon(
                  icon,

                  color:
                      AppColors.skyBlue,

                  size:
                      22,
                ),
              ),

              const SizedBox(
                width:
                    12,
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
                            15,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                          3,
                    ),

                    Text(
                      subtitle,

                      maxLines:
                          2,

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
                  ],
                ),
              ),

              if (trailing !=
                  null)
                trailing!,
            ],
          ),

          const SizedBox(
            height:
                14,
          ),

          child,
        ],
      ),
    );
  }
}


// =============================================================================
// PARTICIPANT TILE
// =============================================================================

class _ParticipantTile
    extends StatelessWidget {

  final _GroupParticipant participant;

  final bool busy;

  final VoidCallback onRemove;


  const _ParticipantTile({
    required this.participant,
    required this.busy,
    required this.onRemove,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final SocialUser user =
        participant.user;


    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            10,
      ),

      child:
          Row(
        children: [
          Container(
            width:
                40,

            height:
                40,

            decoration:
                const BoxDecoration(
              color:
                  AppColors.brandNightBlue,

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons.person_outline_rounded,

              color:
                  AppColors.skyBlue,

              size:
                  21,
            ),
          ),

          const SizedBox(
            width:
                11,
          ),

          Expanded(
            child:
                Column(
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
                              13,

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
                  ],
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  '${user.course} • ${user.department}',

                  maxLines:
                      1,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.45,
                    ),

                    fontSize:
                        10,
                  ),
                ),
              ],
            ),
          ),

          if (participant.role !=
              'owner')
            busy
                ? const Padding(
                    padding:
                        EdgeInsets.all(
                      12,
                    ),

                    child:
                        SizedBox(
                      width:
                          18,

                      height:
                          18,

                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2,
                      ),
                    ),
                  )
                : IconButton(
                    tooltip:
                        'Rimuovi',

                    onPressed:
                        onRemove,

                    icon:
                        const Icon(
                      Icons.remove_circle_outline,

                      color:
                          Colors.white38,

                      size:
                          20,
                    ),
                  ),
        ],
      ),
    );
  }
}


// =============================================================================
// REQUEST TILE
// =============================================================================

class _RequestTile
    extends StatelessWidget {

  final _JoinRequest request;

  final bool busy;

  final VoidCallback onAccept;

  final VoidCallback onReject;


  const _RequestTile({
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            11,
      ),

      child:
          Row(
        children: [
          Container(
            width:
                40,

            height:
                40,

            decoration:
                const BoxDecoration(
              color:
                  AppColors.brandNightBlue,

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons.person_add_alt_1_rounded,

              color:
                  AppColors.skyBlue,

              size:
                  20,
            ),
          ),

          const SizedBox(
            width:
                11,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  request.user.name,

                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,

                    fontSize:
                        13,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  '${request.user.course} • ${request.user.department}',

                  maxLines:
                      1,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.45,
                    ),

                    fontSize:
                        10,
                  ),
                ),
              ],
            ),
          ),

          if (busy)
            const Padding(
              padding:
                  EdgeInsets.all(
                10,
              ),

              child:
                  SizedBox(
                width:
                    18,

                height:
                    18,

                child:
                    CircularProgressIndicator(
                  strokeWidth:
                      2,
                ),
              ),
            )
          else ...[
            IconButton(
              tooltip:
                  'Rifiuta',

              onPressed:
                  onReject,

              icon:
                  const Icon(
                Icons.close_rounded,

                color:
                    Colors.redAccent,

                size:
                    20,
              ),
            ),

            IconButton(
              tooltip:
                  'Accetta',

              onPressed:
                  onAccept,

              icon:
                  const Icon(
                Icons.check_circle_outline_rounded,

                color:
                    AppColors.skyBlue,

                size:
                    21,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


// =============================================================================
// INVITE TILE
// =============================================================================

class _InviteTile
    extends StatelessWidget {

  final SocialUser user;

  final VoidCallback onInvite;


  const _InviteTile({
    required this.user,
    required this.onInvite,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final String role =
        user.type ==
                SocialUserType.teacher
            ? 'Insegnante'
            : 'Studente';


    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.brandNightBlue,

        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),

      child:
          Row(
        children: [
          Container(
            width:
                38,

            height:
                38,

            decoration:
                const BoxDecoration(
              color:
                  AppColors.eleganceMidnight,

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons.person_outline_rounded,

              color:
                  AppColors.skyBlue,

              size:
                  20,
            ),
          ),

          const SizedBox(
            width:
                10,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  user.name,

                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,

                    fontSize:
                        13,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  '$role • ${user.course}',

                  maxLines:
                      1,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Colors.white54,

                    fontSize:
                        10,
                  ),
                ),
              ],
            ),
          ),

          TextButton(
            onPressed:
                onInvite,

            child:
                const Text(
              'Aggiungi',
            ),
          ),
        ],
      ),
    );
  }
}


// =============================================================================
// ADMIN ACTION TILE
// =============================================================================

class _AdminActionTile
    extends StatelessWidget {

  final IconData icon;

  final String title;

  final String description;

  final VoidCallback onTap;

  final bool danger;


  const _AdminActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.danger = false,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final Color iconColor =
        danger
            ? Colors.redAccent
            : AppColors.skyBlue;


    return InkWell(
      onTap:
          onTap,

      borderRadius:
          BorderRadius.circular(
        13,
      ),

      child:
          Container(
        padding:
            const EdgeInsets.all(
          12,
        ),

        decoration:
            BoxDecoration(
          color:
              AppColors.brandNightBlue,

          borderRadius:
              BorderRadius.circular(
            13,
          ),
        ),

        child:
            Row(
          children: [
            Container(
              width:
                  40,

              height:
                  40,

              decoration:
                  BoxDecoration(
                color:
                    iconColor
                        .withOpacity(
                  0.10,
                ),

                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
              ),

              child:
                  Icon(
                icon,

                color:
                    iconColor,

                size:
                    21,
              ),
            ),

            const SizedBox(
              width:
                  11,
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
                        TextStyle(
                      color:
                          danger
                              ? Colors.redAccent
                              : AppColors.pureWhite,

                      fontSize:
                          13,

                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height:
                        3,
                  ),

                  Text(
                    description,

                    maxLines:
                        2,

                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        TextStyle(
                      color:
                          AppColors.pureWhite
                              .withOpacity(
                        0.45,
                      ),

                      fontSize:
                          10,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,

              color:
                  Colors.white38,

              size:
                  21,
            ),
          ],
        ),
      ),
    );
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
    final String text =
        switch (
          role.toLowerCase()
        ) {
          'owner' =>
            'OWNER',

          'admin' =>
            'ADMIN',

          _ =>
            'MEMBER',
        };


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
        text,

        style:
            const TextStyle(
          color:
              AppColors.materialSky,

          fontSize:
              8,

          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }
}


// =============================================================================
// BADGE
// =============================================================================

class _Badge
    extends StatelessWidget {

  final String text;


  const _Badge({
    required this.text,
  });


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
            4,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.skyBlue
                .withOpacity(
          0.12,
        ),

        borderRadius:
            BorderRadius.circular(
          8,
        ),
      ),

      child:
          Text(
        text,

        style:
            const TextStyle(
          color:
              AppColors.skyBlue,

          fontSize:
              11,

          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }
}


// =============================================================================
// ERROR CARD
// =============================================================================

class _AdminErrorCard
    extends StatelessWidget {

  final String message;

  final Future<void> Function()
      onRetry;


  const _AdminErrorCard({
    required this.message,
    required this.onRetry,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        maxWidth:
            500,
      ),

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
            'Errore caricamento amministrazione',

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,

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
                  Colors.white54,

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
    );
  }
}


// =============================================================================
// MODELLI LOCALI
// =============================================================================

class _GroupParticipant {
  final int membershipId;

  final SocialUser user;

  final String role;

  final DateTime? joinedAt;


  const _GroupParticipant({
    required this.membershipId,
    required this.user,
    required this.role,
    required this.joinedAt,
  });
}


class _JoinRequest {
  final int id;

  final int userId;

  final SocialUser user;

  final String status;

  final DateTime? createdAt;


  const _JoinRequest({
    required this.id,
    required this.userId,
    required this.user,
    required this.status,
    required this.createdAt,
  });
}