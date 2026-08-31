import 'package:flutter/material.dart';
import '../models/developer_models.dart';

class DeveloperBadgeChip extends StatelessWidget {
  final DeveloperBadge badge;
  const DeveloperBadgeChip({super.key, required this.badge});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: badge.color.withValues(alpha: .13), borderRadius: BorderRadius.circular(999), border: Border.all(color: badge.color.withValues(alpha: .45))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(badge.icon, size: 14, color: badge.color), const SizedBox(width: 6), Text(badge.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badge.color))]),
  );
}
