import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

import '../social_models.dart';


class SocialSubjectEditor extends StatefulWidget {
  final String department;

  final String course;

  final bool showGrade;

  final SocialSubject? initialSubject;


  const SocialSubjectEditor({
    super.key,
    required this.department,
    required this.course,
    this.showGrade = true,
    this.initialSubject,
  });


  @override
  State<SocialSubjectEditor> createState() =>
      _SocialSubjectEditorState();
}


class _SocialSubjectEditorState
    extends State<SocialSubjectEditor> {

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();


  late final TextEditingController
      _nameController;

  late final TextEditingController
      _gradeController;

  late final TextEditingController
      _noteController;


  bool _canHelp =
      false;

  bool _canGivePrivateLessons =
      false;


  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
      text:
          widget.initialSubject?.name ??
              '',
    );

    _gradeController =
        TextEditingController(
      text:
          widget.initialSubject?.grade
                  ?.toString() ??
              '',
    );

    _noteController =
        TextEditingController(
      text:
          widget.initialSubject?.note ??
              '',
    );

    _canHelp =
        widget.initialSubject?.canHelp ??
            false;

    _canGivePrivateLessons =
        widget.initialSubject
                ?.canGivePrivateLessons ??
            false;
  }


  @override
  void dispose() {
    _nameController.dispose();

    _gradeController.dispose();

    _noteController.dispose();

    super.dispose();
  }


  void _save() {
    if (
      !_formKey.currentState!
          .validate()
    ) {
      return;
    }

    final String name =
        _nameController.text
            .trim();

    final String gradeText =
        _gradeController.text
            .trim();

    final String note =
        _noteController.text
            .trim();

    int? grade;

    if (
      widget.showGrade &&
      gradeText.isNotEmpty
    ) {
      grade =
          int.tryParse(
        gradeText,
      );
    }

    final SocialSubject? initial =
        widget.initialSubject;

    final SocialSubject subject =
        SocialSubject(
      id:
          initial?.id ??
              0,

      name:
          name,

      department:
          initial?.department.isNotEmpty ==
                  true
              ? initial!.department
              : widget.department,

      course:
          initial?.course.isNotEmpty ==
                  true
              ? initial!.course
              : widget.course,

      grade:
          grade,

      gradeVerificationStatus:
          initial
                  ?.gradeVerificationStatus ??
              GradeVerificationStatus.none,

      note:
          note,

      canHelp:
          _canHelp,
    );

    Navigator.pop(
      context,
      subject,
    );
  }


  String? _validateName(
    String? value,
  ) {
    if (
      value == null ||
      value.trim().isEmpty
    ) {
      return 'Inserisci il nome della materia';
    }

    return null;
  }


  String? _validateGrade(
    String? value,
  ) {
    if (!widget.showGrade) {
      return null;
    }

    if (
      value == null ||
      value.trim().isEmpty
    ) {
      return null;
    }

    final int? grade =
        int.tryParse(
      value.trim(),
    );

    if (grade == null) {
      return 'Inserisci un numero valido';
    }

    if (
      grade < 18 ||
      grade > 30
    ) {
      return 'Il voto deve essere tra 18 e 30';
    }

    return null;
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    final bool isEditing =
        widget.initialSubject !=
            null;

    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,

      appBar:
          AppBar(
        backgroundColor:
            AppColors.brandNightBlue,

        foregroundColor:
            AppColors.pureWhite,

        title:
            Text(
          isEditing
              ? 'Modifica materia'
              : 'Aggiungi materia',
        ),
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
                  650,
            ),

            child:
                Form(
              key:
                  _formKey,

              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets.all(
                  20,
                ),

                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,

                  children: [
                    const Text(
                      'Materia',

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

                    TextFormField(
                      controller:
                          _nameController,

                      validator:
                          _validateName,

                      textInputAction:
                          TextInputAction.next,

                      style:
                          const TextStyle(
                        color:
                            AppColors.pureWhite,
                      ),

                      decoration:
                          _decoration(
                        hint:
                            'Es. Programmazione 1',

                        icon:
                            Icons
                                .menu_book_outlined,
                      ),
                    ),

                    const SizedBox(
                      height:
                          8,
                    ),

                    Text(
                      '${widget.department} • ${widget.course}',

                      style:
                          TextStyle(
                        color:
                            AppColors.pureWhite
                                .withOpacity(
                          0.40,
                        ),

                        fontSize:
                            10,
                      ),
                    ),

                    if (widget.showGrade) ...[
                      const SizedBox(
                        height:
                            20,
                      ),

                      const Text(
                        'Voto',

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
                            4,
                      ),

                      Text(
                        'Facoltativo',

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withOpacity(
                            0.40,
                          ),

                          fontSize:
                              12,
                        ),
                      ),

                      const SizedBox(
                        height:
                            8,
                      ),

                      TextFormField(
                        controller:
                            _gradeController,

                        keyboardType:
                            TextInputType.number,

                        validator:
                            _validateGrade,

                        style:
                            const TextStyle(
                          color:
                              AppColors.pureWhite,
                        ),

                        decoration:
                            InputDecoration(
                          hintText:
                              'Es. 28',

                          hintStyle:
                              TextStyle(
                            color:
                                AppColors.pureWhite
                                    .withOpacity(
                              0.35,
                            ),
                          ),

                          prefixIcon:
                              const Icon(
                            Icons.grade_outlined,

                            color:
                                AppColors.skyBlue,
                          ),

                          suffixText:
                              '/ 30',

                          suffixStyle:
                              TextStyle(
                            color:
                                AppColors.pureWhite
                                    .withOpacity(
                              0.45,
                            ),
                          ),

                          filled:
                              true,

                          fillColor:
                              AppColors.brandNightBlue,

                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),

                            borderSide:
                                BorderSide.none,
                          ),

                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),

                            borderSide:
                                BorderSide(
                              color:
                                  AppColors.skyBlue
                                      .withOpacity(
                                0.08,
                              ),
                            ),
                          ),

                          focusedBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),

                            borderSide:
                                BorderSide(
                              color:
                                  AppColors.skyBlue
                                      .withOpacity(
                                0.45,
                              ),
                            ),
                          ),

                          errorBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),

                            borderSide:
                                const BorderSide(
                              color:
                                  Colors.redAccent,
                            ),
                          ),

                          focusedErrorBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),

                            borderSide:
                                const BorderSide(
                              color:
                                  Colors.redAccent,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                            8,
                      ),

                      Text(
                        'Se modifichi il voto, la nuova valutazione potrà richiedere una nuova verifica.',

                        style:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withOpacity(
                            0.34,
                          ),

                          fontSize:
                              9,

                          height:
                              1.35,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height:
                          20,
                    ),

                    _buildSwitchCard(
                      title:
                          'Disponibile ad aiutare',

                      subtitle:
                          'Gli altri utenti potranno chiederti supporto su questa materia.',

                      icon:
                          Icons
                              .volunteer_activism_outlined,

                      value:
                          _canHelp,

                      onChanged:
                          (
                        bool value,
                      ) {
                        setState(() {
                          _canHelp =
                              value;
                        });
                      },
                    ),

                    const SizedBox(
                      height:
                          12,
                    ),

                    _buildSwitchCard(
                      title:
                          'Lezioni private',

                      subtitle:
                          'Gli altri utenti potranno richiederti lezioni private su questa materia.',

                      icon:
                          Icons
                              .cast_for_education_outlined,

                      value:
                          _canGivePrivateLessons,

                      onChanged:
                          (
                        bool value,
                      ) {
                        setState(() {
                          _canGivePrivateLessons =
                              value;
                        });
                      },
                    ),

                    const SizedBox(
                      height:
                          20,
                    ),

                    const Text(
                      'Nota sulla materia',

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
                          4,
                    ),

                    Text(
                      'Facoltativa',

                      style:
                          TextStyle(
                        color:
                            AppColors.pureWhite
                                .withOpacity(
                          0.40,
                        ),

                        fontSize:
                            12,
                      ),
                    ),

                    const SizedBox(
                      height:
                          8,
                    ),

                    TextFormField(
                      controller:
                          _noteController,

                      minLines:
                          3,

                      maxLines:
                          5,

                      style:
                          const TextStyle(
                        color:
                            AppColors.pureWhite,
                      ),

                      decoration:
                          InputDecoration(
                        hintText:
                            'Scrivi una breve nota su questa materia...',

                        hintStyle:
                            TextStyle(
                          color:
                              AppColors.pureWhite
                                  .withOpacity(
                            0.35,
                          ),
                        ),

                        prefixIcon:
                            const Padding(
                          padding:
                              EdgeInsets.only(
                            bottom:
                                70,
                          ),

                          child:
                              Icon(
                            Icons.notes_outlined,

                            color:
                                AppColors.skyBlue,
                          ),
                        ),

                        filled:
                            true,

                        fillColor:
                            AppColors.brandNightBlue,

                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),

                          borderSide:
                              BorderSide.none,
                        ),

                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),

                          borderSide:
                              BorderSide(
                            color:
                                AppColors.skyBlue
                                    .withOpacity(
                              0.08,
                            ),
                          ),
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),

                          borderSide:
                              BorderSide(
                            color:
                                AppColors.skyBlue
                                    .withOpacity(
                              0.45,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          30,
                    ),

                    SizedBox(
                      height:
                          54,

                      child:
                          ElevatedButton.icon(
                        onPressed:
                            _save,

                        icon:
                            const Icon(
                          Icons.check_rounded,
                        ),

                        label:
                            Text(
                          isEditing
                              ? 'Salva modifiche'
                              : 'Aggiungi materia',

                          style:
                              const TextStyle(
                            fontSize:
                                15,

                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.socialBlue,

                          foregroundColor:
                              AppColors.pureWhite,

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),
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


  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
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
          SwitchListTile(
        value:
            value,

        onChanged:
            onChanged,

        activeColor:
            AppColors.skyBlue,

        secondary:
            Icon(
          icon,

          color:
              AppColors.skyBlue,
        ),

        title:
            Text(
          title,

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

        subtitle:
            Text(
          subtitle,

          style:
              TextStyle(
            color:
                AppColors.pureWhite
                    .withOpacity(
              0.45,
            ),

            fontSize:
                11,

            height:
                1.35,
          ),
        ),
      ),
    );
  }


  InputDecoration _decoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText:
          hint,

      hintStyle:
          TextStyle(
        color:
            AppColors.pureWhite
                .withOpacity(
          0.35,
        ),
      ),

      prefixIcon:
          Icon(
        icon,

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
          14,
        ),

        borderSide:
            BorderSide.none,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),

        borderSide:
            BorderSide(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.08,
          ),
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),

        borderSide:
            BorderSide(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.45,
          ),
        ),
      ),

      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),

        borderSide:
            const BorderSide(
          color:
              Colors.redAccent,
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),

        borderSide:
            const BorderSide(
          color:
              Colors.redAccent,
        ),
      ),
    );
  }
}