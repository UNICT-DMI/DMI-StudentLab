import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../social_models.dart';
import 'profile_search_card.dart';

class StudentHelpCard extends StatelessWidget {
  final SocialUser student;

  const StudentHelpCard({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    return StudentLabProfileSearchCard(
      user: student,
      typeLabel: 'Studente',
      accent: AppColors.studentBlue,
    );
  }
}
