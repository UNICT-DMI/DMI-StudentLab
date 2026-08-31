import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../theme/nightTheme.dart';
import '../../services/api_service.dart';
import '../../services/auth_session.dart';

import '../social_models.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({
    super.key,
  });

  @override
  State<CreateGroupPage> createState() =>
      _CreateGroupPageState();
}

class _CreateGroupPageState
    extends State<CreateGroupPage> {
  final ApiService _apiService =
      ApiService();

  final TextEditingController
      _nameController =
      TextEditingController();

  final TextEditingController
      _descriptionController =
      TextEditingController();

  final TextEditingController
      _universityController =
      TextEditingController();

  final TextEditingController
      _participantSearchController =
      TextEditingController();

  SocialUser? _currentUser;

  String _department =
      '';

  String _course =
      '';

  List<SocialSubject> _subjects =
      [];

  int? _selectedSubjectId;

  bool _useSubjectAsGroupName =
      false;

  List<SocialUser> _socialUsers =
      [];

  final List<_InvitedUser>
      _invitedUsers =
      [];

  final List<_SelectedMaterial>
      _materials =
      [];

  bool _isPrivate =
      false;

  bool _loading =
      true;

  bool _creating =
      false;

  String? _loadError;

  @override
  void initState() {
    super.initState();

    _loadInitialData();

    _nameController.addListener(
      _refreshSummary,
    );

    _descriptionController.addListener(
      _refreshSummary,
    );

    _universityController.addListener(
      _refreshSummary,
    );
  }

  @override
  void dispose() {
    _nameController.removeListener(
      _refreshSummary,
    );

    _descriptionController.removeListener(
      _refreshSummary,
    );

    _universityController.removeListener(
      _refreshSummary,
    );

    _nameController.dispose();

    _descriptionController.dispose();

    _universityController.dispose();

    _participantSearchController
        .dispose();

    super.dispose();
  }

  void _refreshSummary() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading =
          true;

      _loadError =
          null;
    });

    try {
      final int? currentUserId =
          AuthSession
              .instance
              .currentUserId;

      if (currentUserId == null) {
        throw Exception(
          'Utente non autenticato.',
        );
      }

      final SocialUser currentUser =
          await _apiService
              .getCurrentUser();

      final List<SocialSubject>
          subjects =
          await _apiService
              .getSocialSubjects(
        currentUser.department,
        currentUser.course,
      );

      final List<SocialUser>
          users =
          await _apiService
              .getSocialUsers();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser =
            currentUser;

        _department =
            currentUser.department;

        _course =
            currentUser.course;

        _subjects =
            subjects;

        _socialUsers =
            users
                .where(
                  (
                    SocialUser user,
                  ) =>
                      user.id !=
                      currentUserId,
                )
                .toList();

        if (
          _universityController
              .text
              .trim()
              .isEmpty &&
          currentUser.university
              .trim()
              .isNotEmpty
        ) {
          _universityController.text =
              currentUser.university
                  .trim();
        }

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

        _loadError =
            _cleanError(
          e,
          fallback:
              'Non è stato possibile caricare i dati necessari. Riprova.',
        );
      });
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
          'Crea gruppo',

          style:
              TextStyle(
            fontSize:
                20,

            fontWeight:
                FontWeight.w500,
          ),
        ),
      ),

      body:
          SafeArea(
        child:
            _buildBody(),
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

    if (_loadError != null) {
      return Center(
        child:
            ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth:
                600,
          ),

          child:
              Padding(
            padding:
                const EdgeInsets.all(
              20,
            ),

            child:
                _CreateGroupErrorCard(
              message:
                  _loadError!,

              onRetry:
                  _loadInitialData,
            ),
          ),
        ),
      );
    }

    return Center(
      child:
          LayoutBuilder(
        builder:
            (
          BuildContext context,
          BoxConstraints constraints,
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
                SingleChildScrollView(
              padding:
                  const EdgeInsets.all(
                20,
              ),

              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  _buildIntro(),

                  const SizedBox(
                    height:
                        24,
                  ),

                  _buildSectionTitle(
                    'Informazioni del gruppo',
                    'Definisci le informazioni principali.',
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _buildBasicInformationCard(),

                  const SizedBox(
                    height:
                        24,
                  ),

                  _buildSectionTitle(
                    'Materia',
                    'Collega il gruppo a una materia del tuo corso.',
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _buildSubjectCard(),

                  const SizedBox(
                    height:
                        24,
                  ),

                  _buildSectionTitle(
                    'Accesso al gruppo',
                    'Scegli come potranno partecipare gli altri utenti.',
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _buildPrivacyCard(),

                  const SizedBox(
                    height:
                        24,
                  ),

                  _buildSectionTitle(
                    'Partecipanti',
                    'Puoi aggiungere subito studenti o insegnanti al gruppo.',
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _buildParticipantsCard(),

                  const SizedBox(
                    height:
                        24,
                  ),

                  _buildSectionTitle(
                    'Materiale iniziale',
                    'Puoi caricare file insieme alla creazione del gruppo.',
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _buildMaterialsCard(),

                  const SizedBox(
                    height:
                        28,
                  ),

                  _buildSummaryCard(),

                  const SizedBox(
                    height:
                        20,
                  ),

                  _buildCreateButton(),

                  const SizedBox(
                    height:
                        20,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntro() {
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
            AppColors
                .eleganceDeepNavy,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withValues(alpha: 
            0.14,
          ),
        ),
      ),

      child:
          Row(
        children: [
          Container(
            width:
                54,

            height:
                54,

            decoration:
                BoxDecoration(
              color:
                  AppColors
                      .brandNightBlue,

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
                  29,
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
                const Text(
                  'Crea il tuo gruppo di studio',

                  style:
                      TextStyle(
                    color:
                        AppColors
                            .pureWhite,

                    fontSize:
                        18,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                      5,
                ),

                Text(
                  'Organizza il materiale, invita altri utenti e studiate insieme.',

                  style:
                      TextStyle(
                    color:
                        AppColors
                            .pureWhite
                            .withValues(alpha: 
                          0.55,
                        ),

                    fontSize:
                        12,

                    height:
                        1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    String description,
  ) {
    return Column(
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
                18,

            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height:
              4,
        ),

        Text(
          description,

          style:
              TextStyle(
            color:
                AppColors.pureWhite
                    .withValues(alpha: 
              0.50,
            ),

            fontSize:
                12,
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInformationCard() {
    return _SectionCard(
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          _buildFieldLabel(
            'Nome del gruppo',
            required:
                !_useSubjectAsGroupName,
          ),

          const SizedBox(
            height:
                8,
          ),

          _buildTextField(
            controller:
                _nameController,

            hint:
                _useSubjectAsGroupName
                    ? 'Verrà usato il nome della materia'
                    : 'Es. Gruppo Programmazione 1',

            icon:
                Icons.groups_outlined,

            enabled:
                !_useSubjectAsGroupName,
          ),

          const SizedBox(
            height:
                18,
          ),

          _buildFieldLabel(
            'Descrizione',
          ),

          const SizedBox(
            height:
                8,
          ),

          _buildTextField(
            controller:
                _descriptionController,

            hint:
                'Descrivi brevemente lo scopo del gruppo...',

            icon:
                Icons
                    .description_outlined,

            maxLines:
                4,
          ),

          const SizedBox(
            height:
                18,
          ),

          _buildFieldLabel(
            'Ateneo',
            required:
                true,
          ),

          const SizedBox(
            height:
                8,
          ),

          _buildTextField(
            controller:
                _universityController,

            hint:
                'Es. Università degli Studi di Catania',

            icon:
                Icons
                    .account_balance_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard() {
    return _SectionCard(
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width:
                    44,

                height:
                    44,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .brandNightBlue,

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .menu_book_outlined,

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
                      _course.isEmpty
                          ? 'Materia'
                          : _course,

                      style:
                          const TextStyle(
                        color:
                            AppColors
                                .pureWhite,

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
                      _department.isEmpty
                          ? 'Seleziona la materia'
                          : '$_department • $_course',

                      style:
                          TextStyle(
                        color:
                            AppColors
                                .pureWhite
                                .withValues(alpha: 
                              0.45,
                            ),

                        fontSize:
                            10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                14,
          ),

          if (_subjects.isEmpty)
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
                    AppColors
                        .brandNightBlue
                        .withValues(alpha: 
                      0.35,
                    ),

                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
              ),

              child:
                  Text(
                'Non risultano materie disponibili per $_department / $_course.',

                style:
                    TextStyle(
                  color:
                      AppColors
                          .pureWhite
                          .withValues(alpha: 
                        0.55,
                      ),

                  fontSize:
                      11,
                ),
              ),
            )
          else
            DropdownButtonFormField<int>(
              initialValue:
                  _selectedSubjectId,

              dropdownColor:
                  AppColors
                      .eleganceDeepNavy,

              isExpanded:
                  true,

              style:
                  const TextStyle(
                color:
                    AppColors
                        .pureWhite,

                fontSize:
                    13,
              ),

              decoration:
                  InputDecoration(
                prefixIcon:
                    const Icon(
                  Icons
                      .menu_book_outlined,

                  color:
                      AppColors.skyBlue,
                ),

                hintText:
                    'Seleziona una materia',

                hintStyle:
                    TextStyle(
                  color:
                      AppColors
                          .pureWhite
                          .withValues(alpha: 
                        0.40,
                      ),
                ),

                filled:
                    true,

                fillColor:
                    AppColors
                        .brandNightBlue
                        .withValues(alpha: 
                      0.55,
                    ),

                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),

                  borderSide:
                      BorderSide.none,
                ),
              ),

              items:
                  _subjects.map(
                (
                  SocialSubject subject,
                ) {
                  return DropdownMenuItem<int>(
                    value:
                        subject.id,

                    child:
                        Text(
                      subject.name,

                      overflow:
                          TextOverflow
                              .ellipsis,
                    ),
                  );
                },
              ).toList(),

              onChanged:
                  (
                int? value,
              ) {
                setState(() {
                  _selectedSubjectId =
                      value;

                  if (value == null) {
                    _useSubjectAsGroupName =
                        false;
                  }
                });
              },
            ),

          if (_selectedSubjectId != null) ...[
            const SizedBox(
              height:
                  10,
            ),

            SizedBox(
              width:
                  double.infinity,

              child:
                  OutlinedButton.icon(
                onPressed:
                    () {
                  setState(() {
                    _selectedSubjectId =
                        null;

                    _useSubjectAsGroupName =
                        false;
                  });
                },

                icon:
                    const Icon(
                  Icons
                      .remove_circle_outline_rounded,

                  size:
                      18,
                ),

                label:
                    const Text(
                  'Nessuna materia',
                ),
              ),
            ),

            const SizedBox(
              height:
                  12,
            ),

            _GroupNameModeOption(
              selected:
                  _useSubjectAsGroupName,

              subjectName:
                  _subjectById(
                        _selectedSubjectId,
                      )
                      ?.name ??
                      '',

              onChanged:
                  (
                bool value,
              ) {
                setState(() {
                  _useSubjectAsGroupName =
                      value;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  SocialSubject? _subjectById(
    int? subjectId,
  ) {
    if (subjectId == null) {
      return null;
    }

    for (
      final SocialSubject subject
      in _subjects
    ) {
      if (
        subject.id ==
        subjectId
      ) {
        return subject;
      }
    }

    return null;
  }

  Widget _buildPrivacyCard() {
    return _SectionCard(
      child:
          Column(
        children: [
          _PrivacyOption(
            icon:
                Icons.public_rounded,

            title:
                'Gruppo pubblico',

            description:
                'Gli utenti possono entrare direttamente nel gruppo.',

            selected:
                !_isPrivate,

            onTap:
                () {
              setState(() {
                _isPrivate =
                    false;
              });
            },
          ),

          const SizedBox(
            height:
                10,
          ),

          _PrivacyOption(
            icon:
                Icons
                    .lock_outline_rounded,

            title:
                'Gruppo privato',

            description:
                'Gli utenti devono essere invitati o approvati da un amministratore.',

            selected:
                _isPrivate,

            onTap:
                () {
              setState(() {
                _isPrivate =
                    true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsCard() {
    return _SectionCard(
      child:
          Column(
        children: [
          Row(
            children: [
              Container(
                width:
                    44,

                height:
                    44,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .brandNightBlue,

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .person_add_alt_1_rounded,

                  color:
                      AppColors.skyBlue,

                  size:
                      23,
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
                    const Text(
                      'Aggiungi partecipanti',

                      style:
                          TextStyle(
                        color:
                            AppColors
                                .pureWhite,

                        fontSize:
                            14,

                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      _invitedUsers.isEmpty
                          ? 'Nessun partecipante selezionato.'
                          : '${_invitedUsers.length} partecipanti selezionati.',

                      style:
                          TextStyle(
                        color:
                            AppColors
                                .pureWhite
                                .withValues(alpha: 
                              0.50,
                            ),

                        fontSize:
                            11,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip:
                    'Aggiungi partecipanti',

                onPressed:
                    _addParticipant,

                icon:
                    const Icon(
                  Icons.add_rounded,

                  color:
                      AppColors.skyBlue,
                ),
              ),
            ],
          ),

          if (_invitedUsers.isNotEmpty) ...[
            const SizedBox(
              height:
                  14,
            ),

            ..._invitedUsers.map(
              (
                _InvitedUser user,
              ) {
                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom:
                        8,
                  ),

                  child:
                      _InvitedUserTile(
                    user:
                        user,

                    onRemove:
                        () {
                      setState(() {
                        _invitedUsers
                            .remove(
                          user,
                        );
                      });
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaterialsCard() {
    return _SectionCard(
      child:
          Column(
        children: [
          InkWell(
            onTap:
                _creating
                    ? null
                    : _addMaterial,

            borderRadius:
                BorderRadius.circular(
              12,
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
                    AppColors
                        .brandNightBlue
                        .withValues(alpha: 
                      0.50,
                    ),

                borderRadius:
                    BorderRadius.circular(
                  12,
                ),

                border:
                    Border.all(
                  color:
                      AppColors
                          .skyBlue
                          .withValues(alpha: 
                        0.12,
                      ),
                ),
              ),

              child:
                  const Row(
                children: [
                  _MaterialUploadIcon(),

                  SizedBox(
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
                          'Aggiungi materiale',

                          style:
                              TextStyle(
                            color:
                                AppColors
                                    .pureWhite,

                            fontSize:
                                14,

                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),

                        SizedBox(
                          height:
                              4,
                        ),

                        Text(
                          'PDF, DOCX, PPTX, TXT e ZIP.',

                          style:
                              TextStyle(
                            color:
                                Colors.white54,

                            fontSize:
                                11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.add_rounded,

                    color:
                        AppColors.skyBlue,
                  ),
                ],
              ),
            ),
          ),

          if (_materials.isNotEmpty) ...[
            const SizedBox(
              height:
                  14,
            ),

            ..._materials.map(
              (
                _SelectedMaterial material,
              ) {
                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom:
                        8,
                  ),

                  child:
                      _SelectedMaterialTile(
                    material:
                        material,

                    onRemove:
                        () {
                      setState(() {
                        _materials.remove(
                          material,
                        );
                      });
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final SocialSubject?
        selectedSubject =
        _subjectById(
      _selectedSubjectId,
    );

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
            AppColors
                .eleganceDeepNavy,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withValues(alpha: 
            0.12,
          ),
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Text(
            'Riepilogo',

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
                14,
          ),

          _SummaryRow(
            icon:
                Icons.groups_outlined,

            label:
                'Nome',

            value:
                _resolvedGroupName(
                  selectedSubject,
                ),
          ),

          const SizedBox(
            height:
                10,
          ),

          _SummaryRow(
            icon:
                Icons.menu_book_outlined,

            label:
                'Materia',

            value:
                selectedSubject
                        ?.name ??
                    'Non selezionata',
          ),

          const SizedBox(
            height:
                10,
          ),

          _SummaryRow(
            icon:
                Icons
                    .account_balance_outlined,

            label:
                'Ateneo',

            value:
                _universityController
                        .text
                        .trim()
                        .isEmpty
                    ? 'Non specificato'
                    : _universityController
                        .text
                        .trim(),
          ),

          const SizedBox(
            height:
                10,
          ),

          _SummaryRow(
            icon:
                Icons.school_outlined,

            label:
                'Corso',

            value:
                '$_department • $_course',
          ),

          const SizedBox(
            height:
                10,
          ),

          _SummaryRow(
            icon:
                _isPrivate
                    ? Icons
                        .lock_outline
                    : Icons
                        .public_rounded,

            label:
                'Accesso',

            value:
                _isPrivate
                    ? 'Privato'
                    : 'Pubblico',
          ),

          const SizedBox(
            height:
                10,
          ),

          _SummaryRow(
            icon:
                Icons
                    .people_outline_rounded,

            label:
                'Partecipanti aggiunti',

            value:
                '${_invitedUsers.length}',
          ),

          const SizedBox(
            height:
                10,
          ),

          _SummaryRow(
            icon:
                Icons.folder_outlined,

            label:
                'Materiali',

            value:
                '${_materials.length}',
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width:
          double.infinity,

      height:
          52,

      child:
          ElevatedButton.icon(
        onPressed:
            _creating
                ? null
                : _createGroup,

        icon:
            _creating
                ? const SizedBox(
                    width:
                        18,

                    height:
                        18,

                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          2,

                      color:
                          AppColors
                              .brandNightBlue,
                    ),
                  )
                : const Icon(
                    Icons
                        .groups_rounded,
                  ),

        label:
            Text(
          _creating
              ? 'Creazione...'
              : 'Crea gruppo',
        ),

        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              AppColors.skyBlue,

          foregroundColor:
              AppColors.brandNightBlue,

          disabledBackgroundColor:
              AppColors.skyBlue
                  .withValues(alpha: 
            0.50,
          ),

          disabledForegroundColor:
              AppColors
                  .brandNightBlue
                  .withValues(alpha: 
                0.70,
              ),

          elevation:
              0,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),

          textStyle:
              const TextStyle(
            fontSize:
                14,

            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(
    String label, {
    bool required = false,
  }) {
    return Row(
      children: [
        Text(
          label,

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

        if (required)
          const Text(
            ' *',

            style:
                TextStyle(
              color:
                  AppColors.skyBlue,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController
        controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextField(
      controller:
          controller,

      enabled:
          enabled,

      maxLines:
          maxLines,

      style:
          const TextStyle(
        color:
            AppColors.pureWhite,

        fontSize:
            13,
      ),

      decoration:
          InputDecoration(
        prefixIcon:
            Icon(
          icon,

          color:
              AppColors.skyBlue,

          size:
              20,
        ),

        hintText:
            hint,

        hintStyle:
            TextStyle(
          color:
              AppColors
                  .pureWhite
                  .withValues(alpha: 
                0.35,
              ),

          fontSize:
              12,
        ),

        filled:
            true,

        fillColor:
            AppColors
                .brandNightBlue
                .withValues(alpha: 
              0.55,
            ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),

          borderSide:
              BorderSide.none,
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),

          borderSide:
              const BorderSide(
            color:
                AppColors.skyBlue,

            width:
                1,
          ),
        ),

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal:
              14,

          vertical:
              14,
        ),
      ),
    );
  }

  void _addParticipant() {
    _participantSearchController
        .clear();

    showModalBottomSheet<void>(
      context:
          context,

      isScrollControlled:
          true,

      backgroundColor:
          AppColors
              .eleganceDeepNavy,

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
        BuildContext sheetContext,
      ) {
        return StatefulBuilder(
          builder:
              (
            BuildContext context,
            StateSetter setSheetState,
          ) {
            final String query =
                _participantSearchController
                    .text
                    .trim()
                    .toLowerCase();

            final List<SocialUser>
                users =
                _socialUsers
                    .where(
                      (
                        SocialUser user,
                      ) {
                        final bool
                            alreadySelected =
                            _invitedUsers.any(
                          (
                            _InvitedUser
                                invited,
                          ) =>
                              invited.id ==
                              user.id,
                        );

                        if (alreadySelected) {
                          return false;
                        }

                        if (query.isEmpty) {
                          return true;
                        }

                        final String
                            subjectNames =
                            user.subjects
                                .map(
                                  (
                                    SocialSubject
                                        subject,
                                  ) =>
                                      subject.name,
                                )
                                .join(
                                  ' ',
                                );

                        final String
                            searchable =
                            [
                          user.name,
                          user.email,
                          user.course,
                          user.department,
                          subjectNames,
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
                          0.70,

                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child:
                                Text(
                              'Aggiungi partecipanti',

                              style:
                                  TextStyle(
                                color:
                                    AppColors
                                        .pureWhite,

                                fontSize:
                                    18,

                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),

                          IconButton(
                            onPressed:
                                () {
                              Navigator.pop(
                                sheetContext,
                              );
                            },

                            icon:
                                const Icon(
                              Icons
                                  .close_rounded,

                              color:
                                  Colors.white54,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height:
                            6,
                      ),

                      Text(
                        'Seleziona uno studente o insegnante da aggiungere al gruppo.',

                        style:
                            TextStyle(
                          color:
                              AppColors
                                  .pureWhite
                                  .withValues(alpha: 
                                0.50,
                              ),

                          fontSize:
                              12,
                        ),
                      ),

                      const SizedBox(
                        height:
                            16,
                      ),

                      TextField(
                        controller:
                            _participantSearchController,

                        style:
                            const TextStyle(
                          color:
                              AppColors
                                  .pureWhite,
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
                            Icons
                                .search_rounded,

                            color:
                                AppColors
                                    .skyBlue,
                          ),

                          filled:
                              true,

                          fillColor:
                              AppColors
                                  .eleganceMidnight,

                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),

                            borderSide:
                                BorderSide.none,
                          ),
                        ),

                        onChanged:
                            (
                          String _,
                        ) {
                          setSheetState(
                            () {},
                          );
                        },
                      ),

                      const SizedBox(
                        height:
                            14,
                      ),

                      Expanded(
                        child:
                            users.isEmpty
                                ? Center(
                                    child:
                                        Text(
                                      'Nessun utente disponibile.',

                                      style:
                                          TextStyle(
                                        color:
                                            AppColors
                                                .pureWhite
                                                .withValues(alpha: 
                                              0.45,
                                            ),
                                      ),
                                    ),
                                  )
                                : ListView
                                    .separated(
                                    itemCount:
                                        users.length,

                                    separatorBuilder:
                                        (
                                      BuildContext _,
                                      int __,
                                    ) =>
                                            const SizedBox(
                                      height:
                                          8,
                                    ),

                                    itemBuilder:
                                        (
                                      BuildContext
                                          context,
                                      int index,
                                    ) {
                                      final SocialUser
                                          user =
                                          users[
                                              index];

                                      return _SocialUserOption(
                                        user:
                                            user,

                                        onTap:
                                            () {
                                          _selectParticipant(
                                            _InvitedUser(
                                              id:
                                                  user.id,

                                              name:
                                                  user.name,

                                              subtitle:
                                                  '${_roleName(user)} • ${user.course}',
                                            ),
                                          );

                                          Navigator.pop(
                                            sheetContext,
                                          );
                                        },
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
    );
  }

  String _roleName(
    SocialUser user,
  ) {
    switch (user.type) {
      case SocialUserType.teacher:
        return 'Insegnante';

      case SocialUserType.student:
        return 'Studente';
    }
  }

  void _selectParticipant(
    _InvitedUser user,
  ) {
    final bool exists =
        _invitedUsers.any(
      (
        _InvitedUser item,
      ) =>
          item.id ==
          user.id,
    );

    if (exists) {
      _showMessage(
        'Questo utente è già stato selezionato.',
      );

      return;
    }

    setState(() {
      _invitedUsers.add(
        user,
      );
    });
  }

  Future<void> _addMaterial() async {
    try {
      final FilePickerResult? result =
          await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: <String>[
          'pdf',
          'docx',
          'pptx',
          'txt',
          'zip',
        ],
      );

      if (result == null) {
        return;
      }

      final PlatformFile file =
          result.files.single;

      final String? path =
          file.path;

      if (
        path == null ||
        path.trim().isEmpty
      ) {
        _showMessage(
          'Impossibile ottenere il percorso del file.',
        );

        return;
      }

      final bool alreadyExists =
          _materials.any(
        (
          _SelectedMaterial material,
        ) =>
            material.path ==
            path,
      );

      if (alreadyExists) {
        _showMessage(
          'Questo file è già stato selezionato.',
        );

        return;
      }

      if (
        file.size >
        ApiService.maxMaterialFileSize
      ) {
        _showMessage(
          'Il file supera la dimensione massima consentita di 250 MB.',
        );

        return;
      }

      setState(() {
        _materials.add(
          _SelectedMaterial(
            name:
                file.name,

            path:
                path,

            type:
                _extensionToType(
              file.extension,
            ),

            size:
                _formatFileSize(
              file.size,
            ),
          ),
        );
      });

      _showMessage(
        'File aggiunto.',
      );
    } catch (e) {
      _showMessage(
        'Errore selezione file: $e',
      );
    }
  }

  String _extensionToType(
    String? extension,
  ) {
    final String value =
        extension
                ?.trim()
                .toUpperCase() ??
            'FILE';

    if (value.isEmpty) {
      return 'FILE';
    }

    return value;
  }

  String _formatFileSize(
    int size,
  ) {
    if (size < 1024) {
      return '$size B';
    }

    if (
      size <
      1024 * 1024
    ) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }

    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _createGroup() async {
    if (_creating) {
      return;
    }

    final SocialSubject?
        selectedSubject =
        _subjectById(
      _selectedSubjectId,
    );

    final String customName =
        _nameController.text
            .trim();

    final String name =
        _useSubjectAsGroupName &&
                selectedSubject != null
            ? selectedSubject.name
                .trim()
            : customName;

    final String description =
        _descriptionController.text
            .trim();

    final String university =
        _universityController.text
            .trim();

    if (
      !AuthSession
          .instance
          .isAuthenticated
    ) {
      _showMessage(
        'Utente non autenticato.',
      );

      return;
    }

    if (name.isEmpty) {
      _showMessage(
        'Inserisci il nome del gruppo oppure usa il nome della materia.',
      );

      return;
    }

    if (university.isEmpty) {
      _showMessage(
        'Inserisci l\'ateneo.',
      );

      return;
    }

    if (
      _department.isEmpty ||
      _course.isEmpty
    ) {
      _showMessage(
        'Dipartimento o corso non disponibili.',
      );

      return;
    }

    setState(() {
      _creating =
          true;
    });

    try {
      final Map<String, dynamic>
          createdGroup =
          await _apiService
              .createGroup(
        name:
            name,

        description:
            description,

        subjectId:
            _selectedSubjectId,

        university:
            university,

        department:
            _department,

        course:
            _course,

        isPrivate:
            _isPrivate,
      );

      final int? groupId =
          _toInt(
        createdGroup['id'],
      );

      if (groupId == null) {
        throw Exception(
          'Il backend non ha restituito l\'ID del gruppo.',
        );
      }

      for (
        final _InvitedUser user
        in _invitedUsers
      ) {
        await _apiService
            .addGroupMember(
          groupId:
              groupId,

          userId:
              user.id,

          role:
              'member',
        );
      }

      for (
        final _SelectedMaterial
            material
        in _materials
      ) {
        await _apiService
            .addGroupMaterial(
          groupId:
              groupId,

          filePath:
              material.path,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        'Gruppo "$name" creato correttamente.',
      );

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
        _cleanError(
          e,
          fallback:
              'Non è stato possibile creare il gruppo. Riprova.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _creating =
              false;
        });
      }
    }
  }

  String _resolvedGroupName(
    SocialSubject? selectedSubject,
  ) {
    if (
      _useSubjectAsGroupName &&
      selectedSubject != null &&
      selectedSubject.name
          .trim()
          .isNotEmpty
    ) {
      return selectedSubject.name
          .trim();
    }

    final String customName =
        _nameController.text
            .trim();

    return customName.isEmpty
        ? 'Non specificato'
        : customName;
  }

  String _cleanError(
    Object error, {
    required String fallback,
  }) {
    final String message =
        error
            .toString()
            .toLowerCase();

    if (
      message.contains('401') ||
      message.contains(
        'unauthorized',
      ) ||
      message.contains(
        'token non valido',
      )
    ) {
      return 'La sessione non è più valida. Accedi nuovamente.';
    }

    if (
      message.contains('403') ||
      message.contains(
        'forbidden',
      )
    ) {
      return 'Non hai i permessi necessari per completare questa operazione.';
    }

    if (
      message.contains('404') ||
      message.contains(
        'not found',
      )
    ) {
      return 'Una delle informazioni selezionate non è più disponibile. Aggiorna e riprova.';
    }

    if (
      message.contains('409') ||
      message.contains(
        'conflict',
      )
    ) {
      return 'Non è stato possibile completare l’operazione perché alcuni dati sono già presenti o sono cambiati.';
    }

    if (
      message.contains(
        'socket',
      ) ||
      message.contains(
        'network',
      ) ||
      message.contains(
        'connection',
      ) ||
      message.contains(
        'host lookup',
      )
    ) {
      return 'Non è stato possibile connettersi a StudentLab. Controlla la connessione e riprova.';
    }

    if (
      message.contains(
        'timeout',
      ) ||
      message.contains(
        'timed out',
      )
    ) {
      return 'La richiesta sta impiegando troppo tempo. Riprova tra qualche momento.';
    }

    return fallback;
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

class _SectionCard
    extends StatelessWidget {
  final Widget child;

  const _SectionCard({
    required this.child,
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
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors
                .eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withValues(alpha: 
            0.12,
          ),
        ),
      ),

      child:
          child,
    );
  }
}

class _PrivacyOption
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String description;

  final bool selected;

  final VoidCallback onTap;

  const _PrivacyOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap:
          onTap,

      borderRadius:
          BorderRadius.circular(
        13,
      ),

      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds:
              180,
        ),

        padding:
            const EdgeInsets.all(
          12,
        ),

        decoration:
            BoxDecoration(
          color:
              selected
                  ? AppColors
                      .brandNightBlue
                      .withValues(alpha: 
                        0.70,
                      )
                  : Colors.transparent,

          borderRadius:
              BorderRadius.circular(
            13,
          ),

          border:
              Border.all(
            color:
                selected
                    ? AppColors
                        .skyBlue
                        .withValues(alpha: 
                          0.30,
                        )
                    : Colors.white
                        .withValues(alpha: 
                          0.06,
                        ),
          ),
        ),

        child:
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
                    selected
                        ? AppColors
                            .skyBlue
                            .withValues(alpha: 
                              0.12,
                            )
                        : AppColors
                            .brandNightBlue,

                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
              ),

              child:
                  Icon(
                icon,

                color:
                    AppColors
                        .skyBlue,

                size:
                    21,
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
                          AppColors
                              .pureWhite,

                      fontSize:
                          13,

                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height:
                        4,
                  ),

                  Text(
                    description,

                    maxLines:
                        2,

                    overflow:
                        TextOverflow
                            .ellipsis,

                    style:
                        TextStyle(
                      color:
                          AppColors
                              .pureWhite
                              .withValues(alpha: 
                            0.48,
                          ),

                      fontSize:
                          11,

                      height:
                          1.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width:
                  8,
            ),

            Icon(
              selected
                  ? Icons
                      .radio_button_checked_rounded
                  : Icons
                      .radio_button_unchecked_rounded,

              color:
                  selected
                      ? AppColors
                          .skyBlue
                      : Colors.white30,

              size:
                  21,
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialUserOption
    extends StatelessWidget {
  final SocialUser user;

  final VoidCallback onTap;

  const _SocialUserOption({
    required this.user,
    required this.onTap,
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

    return ListTile(
      onTap:
          onTap,

      tileColor:
          AppColors
              .eleganceMidnight,

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),

      leading:
          const CircleAvatar(
        backgroundColor:
            AppColors
                .brandNightBlue,

        child:
            Icon(
          Icons
              .person_outline_rounded,

          color:
              AppColors.skyBlue,
        ),
      ),

      title:
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

      subtitle:
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

      trailing:
          const Icon(
        Icons.add_rounded,

        color:
            AppColors.skyBlue,
      ),
    );
  }
}

class _InvitedUserTile
    extends StatelessWidget {
  final _InvitedUser user;

  final VoidCallback onRemove;

  const _InvitedUserTile({
    required this.user,
    required this.onRemove,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            10,

        vertical:
            8,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors
                .brandNightBlue
                .withValues(alpha: 
              0.45,
            ),

        borderRadius:
            BorderRadius.circular(
          11,
        ),
      ),

      child:
          Row(
        children: [
          CircleAvatar(
            radius:
                18,

            backgroundColor:
                AppColors
                    .skyBlue
                    .withValues(alpha: 
                  0.12,
                ),

            child:
                const Icon(
              Icons
                  .person_outline_rounded,

              color:
                  AppColors.skyBlue,

              size:
                  19,
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
                        AppColors
                            .pureWhite,

                    fontSize:
                        12,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height:
                      2,
                ),

                Text(
                  user.subtitle,

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

          IconButton(
            tooltip:
                'Rimuovi',

            onPressed:
                onRemove,

            icon:
                const Icon(
              Icons.close_rounded,

              color:
                  Colors.white38,

              size:
                  18,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialUploadIcon
    extends StatelessWidget {
  const _MaterialUploadIcon();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          44,

      height:
          44,

      decoration:
          BoxDecoration(
        color:
            AppColors
                .skyBlue
                .withValues(alpha: 
              0.10,
            ),

        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),

      child:
          const Icon(
        Icons.upload_file_rounded,

        color:
            AppColors.skyBlue,

        size:
            23,
      ),
    );
  }
}

class _SelectedMaterialTile
    extends StatelessWidget {
  final _SelectedMaterial material;

  final VoidCallback onRemove;

  const _SelectedMaterialTile({
    required this.material,
    required this.onRemove,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        10,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors
                .brandNightBlue
                .withValues(alpha: 
              0.45,
            ),

        borderRadius:
            BorderRadius.circular(
          11,
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
                BoxDecoration(
              color:
                  AppColors
                      .brandNightBlue,

              borderRadius:
                  BorderRadius.circular(
                9,
              ),
            ),

            child:
                Icon(
              material.type ==
                      'PDF'
                  ? Icons
                      .picture_as_pdf_rounded
                  : material.type ==
                          'ZIP'
                      ? Icons
                          .folder_zip_outlined
                      : Icons
                          .description_rounded,

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
                  material.name,

                  maxLines:
                      1,

                  overflow:
                      TextOverflow
                          .ellipsis,

                  style:
                      const TextStyle(
                    color:
                        AppColors
                            .pureWhite,

                    fontSize:
                        12,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  '${material.type} • ${material.size}',

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

          IconButton(
            tooltip:
                'Rimuovi',

            onPressed:
                onRemove,

            icon:
                const Icon(
              Icons.close_rounded,

              color:
                  Colors.white38,

              size:
                  18,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow
    extends StatelessWidget {
  final IconData icon;

  final String label;

  final String value;

  const _SummaryRow({
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
              AppColors
                  .materialSky,

          size:
              17,
        ),

        const SizedBox(
          width:
              8,
        ),

        SizedBox(
          width:
              75,

          child:
              Text(
            label,

            style:
                TextStyle(
              color:
                  AppColors
                      .pureWhite
                      .withValues(alpha: 
                    0.45,
                  ),

              fontSize:
                  11,
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
                  AppColors
                      .pureWhite,

              fontSize:
                  11,

              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateGroupErrorCard
    extends StatelessWidget {
  final String message;

  final Future<void> Function()
      onRetry;

  const _CreateGroupErrorCard({
    required this.message,
    required this.onRetry,
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
        24,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors
                .eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              Colors.redAccent
                  .withValues(alpha: 
            0.20,
          ),
        ),
      ),

      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          const Icon(
            Icons
                .error_outline_rounded,

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
            'Impossibile caricare i dati',

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
    );
  }
}

class _InvitedUser {
  final int id;

  final String name;

  final String subtitle;

  const _InvitedUser({
    required this.id,
    required this.name,
    required this.subtitle,
  });
}

class _SelectedMaterial {
  final String name;

  final String path;

  final String type;

  final String size;

  const _SelectedMaterial({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
  });
}

class _GroupNameModeOption extends StatelessWidget {
  final bool selected;
  final String subjectName;
  final ValueChanged<bool> onChanged;

  const _GroupNameModeOption({
    required this.selected,
    required this.subjectName,
    required this.onChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap:
          () {
        onChanged(
          !selected,
        );
      },
      borderRadius:
          BorderRadius.circular(
        13,
      ),
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds:
              180,
        ),
        padding:
            const EdgeInsets.all(
          12,
        ),
        decoration:
            BoxDecoration(
          color:
              selected
                  ? AppColors.skyBlue
                      .withValues(
                      alpha:
                          0.10,
                    )
                  : AppColors
                      .brandNightBlue
                      .withValues(
                      alpha:
                          0.35,
                    ),
          borderRadius:
              BorderRadius.circular(
            13,
          ),
          border:
              Border.all(
            color:
                selected
                    ? AppColors.skyBlue
                        .withValues(
                        alpha:
                            0.30,
                      )
                    : AppColors.pureWhite
                        .withValues(
                        alpha:
                            0.06,
                      ),
          ),
        ),
        child:
            Row(
          children: [
            Icon(
              selected
                  ? Icons
                      .radio_button_checked_rounded
                  : Icons
                      .radio_button_unchecked_rounded,
              color:
                  selected
                      ? AppColors.skyBlue
                      : Colors.white38,
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
                  const Text(
                    'Usa la materia come nome del gruppo',
                    style:
                        TextStyle(
                      color:
                          AppColors
                              .pureWhite,
                      fontSize:
                          12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height:
                        4,
                  ),
                  Text(
                    subjectName.isEmpty
                        ? 'Seleziona una materia per usare questa opzione.'
                        : 'Il gruppo verrà mostrato come “$subjectName”.',
                    style:
                        TextStyle(
                      color:
                          AppColors
                              .pureWhite
                              .withValues(
                            alpha:
                                0.48,
                          ),
                      fontSize:
                          10,
                      height:
                          1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}