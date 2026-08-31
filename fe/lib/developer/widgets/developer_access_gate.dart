import 'package:flutter/material.dart';

import '../services/developer_access_policy.dart';

class DeveloperAccessGate extends StatelessWidget {
  final String? userRole;
  final Widget child;
  final Widget? denied;

  const DeveloperAccessGate({
    super.key,
    required this.userRole,
    required this.child,
    this.denied,
  });

  @override
  Widget build(BuildContext context) {
    if (DeveloperAccessPolicy.canAccess(userRole)) {
      return child;
    }

    return denied ??
        const Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Area Developer & System',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Questa sezione è disponibile solo '
                      'ai ruoli devsyst e creator.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}
