import 'package\:flutter/material.dart';

import '../../theme/nightTheme.dart';

import '../../social/teacher/teacher_material_form_page.dart';

import 'question_bank_page.dart';

import 'services/teacher_quiz_assignments_page.dart';

import 'teacher_quiz_results_page.dart';



class TeacherSubjectToolsPage extends StatelessWidget {

  final int subjectId;

  final String subjectCode;

  final String subjectName;

  final String department;

  final String departmentCode;

  final String course;

  final String courseCode;

  final String university;

  final String universityCode;

  final VoidCallback? onOpenAssignments;

  final VoidCallback? onOpenStatistics;

  final VoidCallback? onOpenMaterials;

  const TeacherSubjectToolsPage({

super.key,

    required this.subjectId,

    required this.subjectCode,

    required this.subjectName,

    required this.department,

    required this.departmentCode,

    required this.course,

    required this.courseCode,

this.university = '',

this.universityCode = '',

this.onOpenAssignments,

this.onOpenStatistics,

this.onOpenMaterials,

  });

  Map<String, dynamic> get _metadataBase => {

        if (university.trim().isNotEmpty) 'university': university.trim(),

        if (universityCode.trim().isNotEmpty)

          'university_code': universityCode.trim(),

        'department': department.trim(),

        'department_code': departmentCode.trim(),

        'course': course.trim(),

        'course_code': courseCode.trim(),

        'subject': subjectName.trim(),

        'subject_code': subjectCode.trim(),

        'teacher': <String>[],

        'year_of_validity': 'attuale',

      };

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(

        backgroundColor: AppColors.brandNightBlue,

        foregroundColor: AppColors.pureWhite,

        elevation: 0,

        title: Text(

          subjectName,

          maxLines: 1,

          overflow: TextOverflow.ellipsis,

          style: const TextStyle(

            fontSize: 18,

            fontWeight: FontWeight.w600,

          ),

        ),

      ),

      body: SafeArea(

        child: Center(

          child: ConstrainedBox(

            constraints: const BoxConstraints(

              maxWidth: 820,

            ),

            child: ListView(

              padding: const EdgeInsets.all(20),

              children: [

                _SubjectHeader(

                  subjectCode: subjectCode,

                  subjectName: subjectName,

                  department: department,

                  course: course,

                ),

                const SizedBox(height: 26),

                const Text(

                  'Strumenti docente',

                  style: TextStyle(

                    color: AppColors.pureWhite,

                    fontSize: 20,

                    fontWeight: FontWeight.bold,

                  ),

                ),

                const SizedBox(height: 6),

                Text(

                  'Gestisci banca domande, quiz, materiali e risultati della materia.',

                  style: TextStyle(

                    color: AppColors.pureWhite.withValues(alpha: 0.5),

                    fontSize: 12,

                  ),

                ),

                const SizedBox(height: 16),

                LayoutBuilder(

                  builder: (

                    BuildContext context,

                    BoxConstraints constraints,

                  ) {

                    final bool twoColumns = constraints.maxWidth >= 650;

                    final double width = twoColumns

                        ? (constraints.maxWidth - 14) / 2

                        : constraints.maxWidth;

                    return Wrap(

                      spacing: 14,

                      runSpacing: 14,

                      children: [

                        SizedBox(

                          width: width,

                          child: _ToolCard(

                            icon: Icons.quiz_outlined,

                            title: 'Banca domande',

                            description:

                                'Crea, modifica, importa e organizza le domande della materia.',

                            actionLabel: 'Apri banca domande',

                            onTap: () => _openQuestions(context),

                          ),

                        ),

                        SizedBox(

                          width: width,

                          child: _ToolCard(

                            icon: Icons.assignment_outlined,

                            title: 'Quiz',

                            description:

                                'Crea quiz e assegnali a studenti o gruppi.',

                            actionLabel: 'Gestisci quiz',

                            onTap: () => _openAssignments(

                              context,

                            ),

                          ),

                        ),

                        SizedBox(

                          width: width,

                          child: _ToolCard(

                            icon: Icons.folder_copy_outlined,

                            title: 'Materiali didattici',

                            description:

                                'Pubblica e gestisci i materiali didattici della materia.',

                            actionLabel: 'Gestisci materiali',

                            onTap: () => _openMaterials(context),

                          ),

                        ),

                        SizedBox(

                          width: width,

                          child: _ToolCard(

                            icon: Icons.analytics_outlined,

                            title: 'Risultati e statistiche',

                            description:

                                'Consulta risultati, andamento e difficoltà emerse nei quiz.',

                            actionLabel: 'Apri risultati e statistiche',

                            onTap: () => _openStatistics(

                              context,

                            ),

                          ),

                        ),

                      ],

                    );

                  },

                ),

                const SizedBox(height: 26),

                _InfoBanner(

                  icon: Icons.verified_user_outlined,

                  text:

                      'Questi strumenti sono disponibili solo per le materie verificate e attualmente associate al tuo profilo docente.',

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

  Future<void> _openQuestions(BuildContext context) {

    return Navigator.of(context).push(

      MaterialPageRoute<void>(

        builder: (_) => QuestionBankPage(

          department: departmentCode,

          course: courseCode,

          subject: subjectName,

          metadataBase: _metadataBase,

        ),

      ),

    );

  }

  Future<void> _openAssignments(

    BuildContext context,

  ) async {

    if (onOpenAssignments != null) {

      onOpenAssignments!();

      return;

    }

    await Navigator.of(context).push(

      MaterialPageRoute<void>(

        builder: (_) => TeacherQuizAssignmentsPage(

          subjectId: subjectId,

          department: departmentCode,

          course: courseCode,

          subject: subjectName,

        ),

      ),

    );

  }



  Future<void> _openStatistics(

    BuildContext context,

  ) async {

    if (onOpenStatistics != null) {

      onOpenStatistics!();

      return;

    }

    await Navigator.of(context).push(

      MaterialPageRoute<void>(

        builder: (_) => TeacherQuizResultsPage(

          subjectId: subjectId,

          department: departmentCode,

          course: courseCode,

          subject: subjectName,

        ),

      ),

    );

  }



  Future<void> _openMaterials(BuildContext context) async {

    if (onOpenMaterials != null) {

      onOpenMaterials!();

      return;

    }

    await Navigator.of(context).push(

      MaterialPageRoute<void>(

        builder: (_) => const TeacherMaterialFormPage(),

      ),

    );

  }

}



class _SubjectHeader extends StatelessWidget {

  final String subjectCode;

  final String subjectName;

  final String department;

  final String course;

  const _SubjectHeader({

    required this.subjectCode,

    required this.subjectName,

    required this.department,

    required this.course,

  });

  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: AppColors.eleganceDeepNavy,

        borderRadius: BorderRadius.circular(19),

        border: Border.all(

          color: AppColors.skyBlue.withValues(alpha: 0.12),

        ),

      ),

      child: Row(

        children: [

          Container(

            width: 58,

            height: 58,

            decoration: BoxDecoration(

              color: AppColors.brandNightBlue,

              borderRadius: BorderRadius.circular(16),

            ),

            child: const Icon(

              Icons.school_outlined,

              color: AppColors.skyBlue,

              size: 30,

            ),

          ),

          const SizedBox(width: 15),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                if (subjectCode.trim().isNotEmpty)

                  Text(

                    subjectCode.trim(),

                    style: const TextStyle(

                      color: AppColors.skyBlue,

                      fontSize: 11,

                      fontWeight: FontWeight.w700,

                    ),

                  ),

                if (subjectCode.trim().isNotEmpty)

                  const SizedBox(height: 4),

                Text(

                  subjectName,

                  style: const TextStyle(

                    color: AppColors.pureWhite,

                    fontSize: 18,

                    fontWeight: FontWeight.bold,

                  ),

                ),

                const SizedBox(height: 6),

                Text(

                  '$department • $course',

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(

                    color: AppColors.pureWhite.withValues(alpha: 0.5),

                    fontSize: 11,

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



class _ToolCard extends StatelessWidget {

  final IconData icon;

  final String title;

  final String description;

  final String actionLabel;

  final VoidCallback onTap;

  const _ToolCard({

    required this.icon,

    required this.title,

    required this.description,

    required this.actionLabel,

    required this.onTap,

  });

  @override

  Widget build(BuildContext context) {

    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(18),

        child: Container(

          constraints: const BoxConstraints(

            minHeight: 190,

          ),

          padding: const EdgeInsets.all(18),

          decoration: BoxDecoration(

            color: AppColors.eleganceDeepNavy,

            borderRadius: BorderRadius.circular(18),

            border: Border.all(

              color: AppColors.skyBlue.withValues(alpha: 0.1),

            ),

          ),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Container(

                width: 47,

                height: 47,

                decoration: BoxDecoration(

                  color: AppColors.brandNightBlue,

                  borderRadius: BorderRadius.circular(13),

                ),

                child: Icon(

                  icon,

                  color: AppColors.skyBlue,

                  size: 24,

                ),

              ),

              const SizedBox(height: 15),

              Text(

                title,

                style: const TextStyle(

                  color: AppColors.pureWhite,

                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const SizedBox(height: 7),

              Expanded(

                child: Text(

                  description,

                  style: TextStyle(

                    color: AppColors.pureWhite.withValues(alpha: 0.5),

                    fontSize: 11,

                    height: 1.35,

                  ),

                ),

              ),

              const SizedBox(height: 14),

              Row(

                children: [

                  Text(

                    actionLabel,

                    style: const TextStyle(

                      color: AppColors.skyBlue,

                      fontSize: 11,

                      fontWeight: FontWeight.w600,

                    ),

                  ),

                  const SizedBox(width: 5),

                  const Icon(

                    Icons.arrow_forward_rounded,

                    color: AppColors.skyBlue,

                    size: 17,

                  ),

                ],

              ),

            ],

          ),

        ),

      ),

    );

  }

}



class _InfoBanner extends StatelessWidget {

  final IconData icon;

  final String text;

  const _InfoBanner({

    required this.icon,

    required this.text,

  });

  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(

        color: AppColors.brandNightBlue.withValues(alpha: 0.35),

        borderRadius: BorderRadius.circular(14),

      ),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Icon(

            icon,

            color: AppColors.skyBlue,

            size: 21,

          ),

          const SizedBox(width: 11),

          Expanded(

            child: Text(

              text,

              style: TextStyle(

                color: AppColors.pureWhite.withValues(alpha: 0.62),

                fontSize: 11,

                height: 1.4,

              ),

            ),

          ),

        ],

      ),

    );

  }

}