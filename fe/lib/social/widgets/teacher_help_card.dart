import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../social_models.dart';
import 'profile_search_card.dart';

class TeacherHelpCard extends StatelessWidget {
  final SocialUser teacher;

  const TeacherHelpCard({
    super.key,
    required this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    return StudentLabProfileSearchCard(
      user: teacher,
      typeLabel: 'Insegnante',
      accent: AppColors.teacherIndigo,
    );
  }
}
