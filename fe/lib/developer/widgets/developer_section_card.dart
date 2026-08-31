import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

import '../theme/developer_ui_style.dart';

class DeveloperSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DeveloperSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final Color accent =
        accentColor ?? AppColors.skyBlue;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration:
          DeveloperUiStyle.panelDecoration(
        borderColor: accent,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon case final IconData value)
                Container(
                  width: 36,
                  height: 36,
                  margin:
                      const EdgeInsets.only(
                    right: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        AppColors.brandNightBlue,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: Icon(
                    value,
                    color: accent,
                    size: 18,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          DeveloperUiStyle.bodyStrong,
                    ),
                    ?subtitle?.trim().isNotEmpty == true
                        ? Text(
                            subtitle!,
                            style:
                                DeveloperUiStyle.bodyMuted,
                          )
                        : null,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}