import 'package:flutter/material.dart';

import '../groups/models/study_group.dart';

import 'group_admin_layer.dart';


// Questa pagina esiste solo come livello di compatibilità.
//
// La gestione reale del gruppo è centralizzata in GroupAdminLayer.
//
// Quando tutti i riferimenti a GroupManagementPage saranno stati rimossi,
// questo file potrà essere eliminato completamente.

// fe/lib/social/groups/study_group_detail_page.dart:1106:                GroupManagementPage(
// fe/lib/social/layers/group_management_layer.dart:16:// Quando tutti i riferimenti a GroupManagementPage saranno stati rimossi,
// fe/lib/social/layers/group_management_layer.dart:21:class GroupManagementPage extends StatelessWidget {
// fe/lib/social/layers/group_management_layer.dart:24:  const GroupManagementPage({
// fe/lib/social/groups/study_group_detail_page.dart:1110:          participants:
//

class GroupManagementPage extends StatelessWidget {
  final StudyGroup group;

  const GroupManagementPage({
    super.key,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    return GroupAdminLayer(
      group: group,
    );
  }
}