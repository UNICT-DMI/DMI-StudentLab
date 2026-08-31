import 'package:flutter/material.dart';

import 'package:fe/services/api_service.dart';

import 'package:fe/social/notifications/models/notification_model.dart';

import 'package:fe/theme/nightTheme.dart';


class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
super.key,
  });

  @override
  State<NotificationsPage> createState() =>
      _NotificationsPageState();
}


class _NotificationsPageState
    extends State<NotificationsPage> {
  final ApiService _apiService =
      ApiService();

  bool _loading =
      true;

  bool _markingAll =
      false;

  String? _error;

  List<StudentLabNotification>
      _notifications = [];

  int _unreadCount =
      0;

  final Set<int> _processingActions =
      <int>{};


  @override
  void initState() {
super.initState();

    _loadNotifications();
  }


  Future<void> _loadNotifications() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading =
          true;

      _error =
          null;
    });

    try {
      final NotificationListResult result =
          await _apiService
              .getNotifications();

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications =
            result.notifications;

        _unreadCount =
            result.unreadCount;

        _loading =
            false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;

        _error =
            'Impossibile caricare le notifiche. Controlla la connessione e riprova.';
      });
    }
  }


  Future<void> _markAsRead(
    StudentLabNotification notification,
  ) async {
    if (notification.isRead) {
      return;
    }

    try {
      await _apiService
          .markNotificationAsRead(
        notification.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final int index =
            _notifications.indexWhere(
          (
            StudentLabNotification item,
          ) =>
              item.id ==
              notification.id,
        );

        if (index >= 0) {
          _notifications[index] =
              notification.copyWith(
            isRead:
                true,

            readAt:
                DateTime.now(),
          );
        }

        if (_unreadCount > 0) {
          _unreadCount--;
        }
      });
    } catch (_) {}
  }


  Future<void>
      _markAllAsRead() async {
    if (_markingAll ||
        _unreadCount == 0) {
      return;
    }

    setState(() {
      _markingAll =
          true;
    });

    try {
      await _apiService
          .markAllNotificationsAsRead();

      if (!mounted) {
        return;
      }

      final DateTime now =
          DateTime.now();

      setState(() {
        _notifications =
            _notifications
                .map(
          (
            StudentLabNotification
                notification,
          ) {
            if (notification.isRead) {
              return notification;
            }

            return notification.copyWith(
              isRead:
                  true,

              readAt:
                  now,
            );
          },
        ).toList();

        _unreadCount =
            0;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Impossibile segnare tutte le notifiche come lette.',
      );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _markingAll =
            false;
      });
    }
  }


  Future<void>
      _acceptOwnership(
    StudentLabNotification notification,
  ) async {
    final int? transferId =
        notification.actionResourceId;

    if (transferId == null) {
      _showMessage(
        'Richiesta di trasferimento non valida.',
      );

      return;
    }

    await _processOwnershipAction(
      notification:
          notification,

      action:
          'accept',
    );
  }


  Future<void>
      _rejectOwnership(
    StudentLabNotification notification,
  ) async {
    final int? transferId =
        notification.actionResourceId;

    if (transferId == null) {
      _showMessage(
        'Richiesta di trasferimento non valida.',
      );

      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context:
          context,

      builder:
          (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              AppColors
                  .eleganceDeepNavy,

          title:
              const Text(
            'Rifiuta proprietà',

            style:
                TextStyle(
              color:
                  AppColors
                      .pureWhite,
            ),
          ),

          content:
              Text(
            'Vuoi rifiutare questa richiesta? '
            'Il gruppo verrà eliminato secondo le regole previste dal trasferimento di proprietà.',

            style:
                TextStyle(
              color:
                  AppColors
                      .pureWhite
                      .withOpacity(
                0.65,
              ),

              height:
                  1.4,
            ),
          ),

          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
                  const Text(
                'Annulla',
              ),
            ),

            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
                  const Text(
                'Rifiuta',

                style:
                    TextStyle(
                  color:
                      Colors
                          .redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _processOwnershipAction(
      notification:
          notification,

      action:
          'reject',
    );
  }


  Future<void>
      _processOwnershipAction({
    required StudentLabNotification
        notification,

    required String action,
  }) async {
    final int? transferId =
        notification.actionResourceId;

    if (transferId == null) {
      return;
    }

    if (_processingActions.contains(
      notification.id,
    )) {
      return;
    }

    setState(() {
      _processingActions.add(
        notification.id,
      );
    });

    try {
      if (action == 'accept') {
        await _apiService
            .acceptGroupOwnershipTransfer(
          transferId,
        );
      } else {
        await _apiService
            .rejectGroupOwnershipTransfer(
          transferId,
        );
      }

      if (!mounted) {
        return;
      }

      final int index =
          _notifications.indexWhere(
        (
          StudentLabNotification item,
        ) =>
            item.id ==
            notification.id,
      );

      if (index >= 0) {
        setState(() {
          _notifications[index] =
              notification.copyWith(
            actionStatus:
                action == 'accept'
                    ? 'accepted'
                    : 'rejected',

            isRead:
                true,

            readAt:
                DateTime.now(),
          );

          if (!notification.isRead &&
              _unreadCount > 0) {
            _unreadCount--;
          }
        });
      }

      _showMessage(
        action == 'accept'
            ? 'Hai accettato la proprietà del gruppo.'
            : 'Hai rifiutato la proprietà del gruppo.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        action == 'accept'
            ? 'Impossibile accettare la richiesta.'
            : 'Impossibile rifiutare la richiesta.',
      );

      await _loadNotifications();
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingActions.remove(
          notification.id,
        );
      });
    }
  }


  Future<void> _openNotification(
    StudentLabNotification notification,
  ) async {
    await _markAsRead(
      notification,
    );

    if (!mounted) {
      return;
    }

    if (notification.isOwnershipTransfer) {
      return;
    }

    switch (notification.resourceType) {
      case 'group':
        _showMessage(
          'Apertura gruppo disponibile quando colleghiamo il dettaglio del gruppo alla notifica.',
        );

        return;

      case 'material':
        _showMessage(
          'Apertura materiale disponibile quando completiamo il flusso materiali.',
        );

        return;

      case 'user':
        _showMessage(
          'Apertura profilo disponibile quando colleghiamo il profilo alla notifica.',
        );

        return;

      default:
        return;
    }
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,

      appBar:
          AppBar(
        backgroundColor:
            AppColors
                .eleganceMidnight,

        foregroundColor:
            AppColors.pearlWhite,

        title:
            const Text(
          'Notifiche',
        ),

        actions: [
          if (!_loading &&
              _unreadCount > 0)
            TextButton(
              onPressed:
                  _markingAll
                      ? null
                      : _markAllAsRead,

              child:
                  _markingAll
                      ? const SizedBox(
                          width:
                              18,

                          height:
                              18,

                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Text(
                          'Segna tutte lette',
                        ),
            ),

          const SizedBox(
            width:
                8,
          ),
        ],
      ),

      body:
          _buildBody(),
    );
  }


  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),

          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              const Icon(
                Icons
                    .cloud_off_rounded,

                size:
                    46,

                color:
                    Colors.white38,
              ),

              const SizedBox(
                height:
                    14,
              ),

              Text(
                'Impossibile caricare le notifiche.',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      AppColors
                          .pureWhite
                          .withOpacity(
                    0.75,
                  ),

                  fontSize:
                      15,

                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height:
                    14,
              ),

              OutlinedButton.icon(
                onPressed:
                    _loadNotifications,

                icon:
                    const Icon(
                  Icons.refresh_rounded,
                ),

                label:
                    const Text(
                  'Riprova',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),

          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Icon(
                Icons
                    .notifications_none_rounded,

                size:
                    52,

                color:
                    AppColors
                        .pureWhite
                        .withOpacity(
                  0.28,
                ),
              ),

              const SizedBox(
                height:
                    14,
              ),

              const Text(
                'Nessuna notifica',

                style:
                    TextStyle(
                  color:
                      AppColors
                          .pureWhite,

                  fontSize:
                      17,

                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height:
                    6,
              ),

              Text(
                'Qui troverai richieste, verifiche e aggiornamenti importanti di StudentLab.',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      AppColors
                          .pureWhite
                          .withOpacity(
                    0.48,
                  ),

                  height:
                      1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          _loadNotifications,

      child:
          ListView.separated(
        padding:
            const EdgeInsets.fromLTRB(
          14,
          14,
          14,
          30,
        ),

        itemCount:
            _notifications.length,

        separatorBuilder:
            (
          BuildContext context,
          int index,
        ) {
          return const SizedBox(
            height:
                10,
          );
        },

        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          return _buildNotificationCard(
            _notifications[index],
          );
        },
      ),
    );
  }


  Widget _buildNotificationCard(
    StudentLabNotification notification,
  ) {
    final bool processing =
        _processingActions.contains(
      notification.id,
    );

    return Material(
      color:
          notification.isRead
              ? AppColors
                  .eleganceDeepNavy
              : AppColors
                  .brandNightBlue,

      borderRadius:
          BorderRadius.circular(
        16,
      ),

      child:
          InkWell(
        onTap:
            () {
          _openNotification(
            notification,
          );
        },

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        child:
            Padding(
          padding:
              const EdgeInsets.all(
            15,
          ),

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  _buildNotificationIcon(
                    notification,
                  ),

                  const SizedBox(
                    width:
                        12,
                  ),

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [
                        Row(
                          children: [
                            Expanded(
                              child:
                                  Text(
                                notification
                                    .title,

                                style:
                                    TextStyle(
                                  color:
                                      AppColors
                                          .pureWhite,

                                  fontSize:
                                      14,

                                  fontWeight:
                                      notification
                                              .isRead
                                          ? FontWeight
                                              .w500
                                          : FontWeight
                                              .w700,
                                ),
                              ),
                            ),

                            if (!notification
                                .isRead)
                              Container(
                                width:
                                    8,

                                height:
                                    8,

                                decoration:
                                    const BoxDecoration(
                                  color:
                                      AppColors
                                          .skyBlue,

                                  shape:
                                      BoxShape
                                          .circle,
                                ),
                              ),
                          ],
                        ),

                        if (notification
                            .message
                            .isNotEmpty) ...[
                          const SizedBox(
                            height:
                                6,
                          ),

                          Text(
                            notification
                                .message,

                            style:
                                TextStyle(
                              color:
                                  AppColors
                                      .pureWhite
                                      .withOpacity(
                                0.62,
                              ),

                              fontSize:
                                  12,

                              height:
                                  1.4,
                            ),
                          ),
                        ],

                        const SizedBox(
                          height:
                              8,
                        ),

                        Row(
                          children: [
                            Icon(
                              Icons
                                  .schedule_rounded,

                              size:
                                  13,

                              color:
                                  AppColors
                                      .pureWhite
                                      .withOpacity(
                                0.3,
                              ),
                            ),

                            const SizedBox(
                              width:
                                  4,
                            ),

                            Text(
                              _formatDate(
                                notification
                                    .createdAt,
                              ),

                              style:
                                  TextStyle(
                                color:
                                    AppColors
                                        .pureWhite
                                        .withOpacity(
                                  0.34,
                                ),

                                fontSize:
                                    10,
                              ),
                            ),

                            if (notification
                                    .expiresAt !=
                                null) ...[
                              const SizedBox(
                                width:
                                    12,
                              ),

                              Text(
                                _formatExpiration(
                                  notification
                                      .expiresAt!,
                                ),

                                style:
                                    TextStyle(
                                  color:
                                      notification
                                              .hasExpired
                                          ? Colors
                                              .redAccent
                                          : AppColors
                                              .materialSky,

                                  fontSize:
                                      10,

                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (notification
                      .isOwnershipTransfer &&
                  notification
                      .hasAction) ...[
                const SizedBox(
                  height:
                      14,
                ),

                Divider(
                  height:
                      1,

                  color:
                      AppColors
                          .pureWhite
                          .withOpacity(
                    0.08,
                  ),
                ),

                const SizedBox(
                  height:
                      12,
                ),

                if (processing)
                  const Center(
                    child:
                        Padding(
                      padding:
                          EdgeInsets
                              .symmetric(
                        vertical:
                            4,
                      ),

                      child:
                          SizedBox(
                        width:
                            22,

                        height:
                            22,

                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child:
                            ElevatedButton.icon(
                          onPressed:
                              () {
                            _acceptOwnership(
                              notification,
                            );
                          },

                          icon:
                              const Icon(
                            Icons
                                .check_rounded,
                          ),

                          label:
                              const Text(
                            'Accetta',
                          ),
                        ),
                      ),

                      const SizedBox(
                        width:
                            10,
                      ),

                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              () {
                            _rejectOwnership(
                              notification,
                            );
                          },

                          icon:
                              const Icon(
                            Icons
                                .close_rounded,

                            color:
                                Colors
                                    .redAccent,
                          ),

                          label:
                              const Text(
                            'Rifiuta',

                            style:
                                TextStyle(
                              color:
                                  Colors
                                      .redAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],

              if (notification
                      .actionStatus !=
                  'none' &&
                  notification
                      .actionStatus !=
                      'pending') ...[
                const SizedBox(
                  height:
                      12,
                ),

                _buildActionStatus(
                  notification,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildNotificationIcon(
    StudentLabNotification notification,
  ) {
    IconData icon;

    switch (notification.type) {
      case 'group_ownership_transfer':
        icon =
            Icons
                .admin_panel_settings_outlined;
        break;

      case 'group_join_request':
        icon =
            Icons
                .group_add_outlined;
        break;

      case 'group_join_accepted':
        icon =
            Icons
                .group_rounded;
        break;

      case 'group_join_rejected':
        icon =
            Icons
                .group_off_outlined;
        break;

      case 'material_publication_approved':
        icon =
            Icons
                .task_alt_rounded;
        break;

      case 'material_publication_rejected':
        icon =
            Icons
                .cancel_outlined;
        break;

      case 'academic_path_verification_update':
        icon =
            Icons
                .school_outlined;
        break;

      case 'teacher_assignment_update':
        icon =
            Icons
                .cast_for_education_outlined;
        break;

      case 'profile_report_update':
      case 'profile_error_update':
        icon =
            Icons
                .person_outline_rounded;
        break;

      default:
        icon =
            Icons
                .notifications_none_rounded;
    }

    return Container(
      width:
          42,

      height:
          42,

      decoration:
          BoxDecoration(
        color:
            AppColors.skyBlue
                .withOpacity(
          0.12,
        ),

        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),

      child:
          Icon(
        icon,

        color:
            AppColors.skyBlue,

        size:
            21,
      ),
    );
  }


  Widget _buildActionStatus(
    StudentLabNotification notification,
  ) {
    String label;

    IconData icon;

    Color color;

    switch (notification.actionStatus) {
      case 'accepted':
      case 'completed':
        label =
            notification.isOwnershipTransfer
                ? 'Trasferimento accettato'
                : 'Completata';

        icon =
            Icons
                .check_circle_outline_rounded;

        color =
            Colors.greenAccent;
        break;

      case 'rejected':
        label =
            'Rifiutata';

        icon =
            Icons
                .cancel_outlined;

        color =
            Colors.redAccent;
        break;

      case 'expired':
        label =
            'Scaduta';

        icon =
            Icons
                .schedule_outlined;

        color =
            Colors.orangeAccent;
        break;

      case 'cancelled':
        label =
            'Annullata';

        icon =
            Icons
                .block_outlined;

        color =
            Colors.white54;
        break;

      default:
        return const SizedBox.shrink();
    }

    return Row(
      children: [
        Icon(
          icon,

          size:
              16,

          color:
              color,
        ),

        const SizedBox(
          width:
              6,
        ),

        Text(
          label,

          style:
              TextStyle(
            color:
                color,

            fontSize:
                11,

            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }


  String _formatDate(
    DateTime date,
  ) {
    final DateTime local =
        date.toLocal();

    final DateTime now =
        DateTime.now();

    final DateTime today =
        DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime notificationDay =
        DateTime(
      local.year,
      local.month,
      local.day,
    );

    final int difference =
        today
            .difference(
      notificationDay,
    )
            .inDays;

    final String time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    if (difference == 0) {
      return 'Oggi $time';
    }

    if (difference == 1) {
      return 'Ieri $time';
    }

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} $time';
  }


  String _formatExpiration(
    DateTime expiresAt,
  ) {
    final Duration difference =
        expiresAt.difference(
      DateTime.now(),
    );

    if (difference.isNegative) {
      return 'Scaduta';
    }

    if (difference.inDays >= 1) {
      final int days =
          difference.inDays;

      return days == 1
          ? 'Scade tra 1 giorno'
          : 'Scade tra $days giorni';
    }

    if (difference.inHours >= 1) {
      final int hours =
          difference.inHours;

      return hours == 1
          ? 'Scade tra 1 ora'
          : 'Scade tra $hours ore';
    }

    final int minutes =
        difference.inMinutes;

    return minutes <= 1
        ? 'Scade a breve'
        : 'Scade tra $minutes minuti';
  }


  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),
      ),
    );
  }
}