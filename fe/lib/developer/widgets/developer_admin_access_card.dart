import 'package:flutter/material.dart';

import '../data/developer_api_repository.dart';
import '../pages/developer_entry_page.dart';

class DeveloperAdminAccessCard
    extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    VoidCallback openDeveloperArea,
  ) builder;

  const DeveloperAdminAccessCard({
    super.key,
    required this.builder,
  });

  @override
  State<DeveloperAdminAccessCard> createState() =>
      _DeveloperAdminAccessCardState();
}

class _DeveloperAdminAccessCardState
    extends State<DeveloperAdminAccessCard> {
  final DeveloperApiRepository _repository =
      const DeveloperApiRepository();

  bool? _authorized;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bool authorized =
          await _repository.canAccess();

      if (!mounted) {
        return;
      }

      setState(() {
        _authorized = authorized;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authorized = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authorized != true) {
      return const SizedBox.shrink();
    }

    return widget.builder(
      context,
      () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const DeveloperEntryPage(),
          ),
        );
      },
    );
  }
}
