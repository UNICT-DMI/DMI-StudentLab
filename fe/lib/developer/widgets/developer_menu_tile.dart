import 'package:flutter/material.dart';

import '../pages/developer_entry_page.dart';
import '../services/developer_access_policy.dart';

class DeveloperMenuTile extends StatelessWidget {
  final String? userRole;
  final bool showSubtitle;

  const DeveloperMenuTile({
    super.key,
    required this.userRole,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!DeveloperAccessPolicy.canAccess(userRole)) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: const Icon(Icons.developer_mode_outlined),
      title: const Text('Developer & System'),
      subtitle: showSubtitle
          ? const Text('Architettura, funzioni, flussi e sicurezza')
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DeveloperEntryPage(),
          ),
        );
      },
    );
  }
}
