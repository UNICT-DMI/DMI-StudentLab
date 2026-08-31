import 'package:flutter/material.dart';

import 'developer_entry_page.dart';

/// Preview locale della Developer UI.
/// Non usare questa pagina come bypass dei controlli reali di ruolo in produzione.
class DeveloperPreviewPage extends StatelessWidget {
  const DeveloperPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DeveloperEntryPage();
  }
}
