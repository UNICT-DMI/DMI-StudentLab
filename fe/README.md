# fe

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


social/message/message_page.dart — per fare Contatta → conversazione con utente selezionato.
social/message/contact_user_page.dart — probabilmente va allineato allo stesso sistema.

social/layers/group_chat_layer.dart — controllare se usa ancora ID/utente hardcoded e come gestisce la chat.

social/layers/group_partecipants_layer.dart — verificare se usa ancora parametri vecchi e collegare apertura profilo utente.

social/layers/group_management_layer.dart e group_admin_layer.dart — verificare AuthSession e operazioni owner/admin.

social/groups/create_group_page.dart — verificare che createdBy venga da AuthSession.currentUserId, non da un ID fisso.

social/groups/groups_material_page.dart — dovrebbe essere collegato al nuovo local storage/download.

material/StudentMaterialPage.dart, online_subject_material_page.dart e relative card — collegare definitivamente download/cache SQLite.

layers/home.dart — verificare login/logout/sessione reale e rimuovere eventuale static const bool isAuthenticated.
layers/homeLayer.dart — verificare che le funzionalità Guest/Auth reagiscano alla sessione reale.
social/widgets/social_intro.dart, student_social_form.dart, teacher_social_form.dart — controllare che registrazione e SocialProfileDraft siano allineati con AuthService.register().
social/widgets/student_help_card.dart e teacher_help_card.dart — verificare che eventuali pulsanti interni non siano ancora placeholder.
social/booking/teacher_booking_page.dart — da considerare quando colleghiamo la prenotazione reale.
