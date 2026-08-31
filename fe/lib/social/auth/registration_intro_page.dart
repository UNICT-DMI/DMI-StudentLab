import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../social_models.dart';
import '../widgets/social_intro.dart';

class RegistrationIntroPage extends StatelessWidget {
  const RegistrationIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        elevation: 0,
        title: const Text('Registrati'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SocialIntro(
                  onProfileCreated: (SocialUser user) {
                    Navigator.of(context).pop<SocialUser>(user);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}