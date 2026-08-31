import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/nightTheme.dart';

import '../social_models.dart';
import '../reviews/review_card.dart';


class AdminReviewsPage
    extends StatefulWidget {
  const AdminReviewsPage({
    super.key,
  });

  @override
  State<AdminReviewsPage> createState() =>
      _AdminReviewsPageState();
}


class _AdminReviewsPageState
    extends State<AdminReviewsPage> {
  final ApiService _apiService =
      ApiService();

  List<SocialReview> _reviews =
      [];

  ReviewModerationStatus?
      _selectedStatus =
      ReviewModerationStatus.pending;

  bool _loading =
      true;

  bool _refreshing =
      false;

  String? _error;

  final Set<int> _processingIds =
      {};


  @override
  void initState() {
    super.initState();

    _loadReviews();
  }


  Future<void> _loadReviews({
    bool refresh = false,
  }) async {
    if (refresh) {
      if (_refreshing) {
        return;
      }

      setState(() {
        _refreshing =
            true;
      });
    } else {
      setState(() {
        _loading =
            true;

        _error =
            null;
      });
    }

    try {
      final List<SocialReview>
          reviews;

      if (
        _selectedStatus ==
            ReviewModerationStatus.pending
      ) {
        reviews =
            await _apiService
                .getPendingReviews();
      } else {
        reviews =
            await _apiService
                .getAdminReviews(
          moderationStatus:
              _selectedStatus,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _reviews =
            reviews;

        _error =
            null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            _cleanError(
          e,
        );
      });
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;

        _refreshing =
            false;
      });
    }
  }


  Future<void> _changeFilter(
    ReviewModerationStatus? status,
  ) async {
    if (
      _selectedStatus ==
          status
    ) {
      return;
    }

    setState(() {
      _selectedStatus =
          status;
    });

    await _loadReviews();
  }


  bool _isProcessing(
    SocialReview review,
  ) {
    final int? id =
        review.id;

    if (id == null) {
      return false;
    }

    return _processingIds.contains(
      id,
    );
  }


  Future<void> _approve(
    SocialReview review,
  ) async {
    final int? reviewId =
        review.id;

    if (reviewId == null) {
      _showMessage(
        'Recensione senza ID valido.',
      );

      return;
    }

    await _executeAction(
      reviewId:
          reviewId,

      action:
          () =>
              _apiService
                  .approveReview(
        reviewId,
      ),

      successMessage:
          'Recensione approvata.',
    );
  }


  Future<void> _reject(
    SocialReview review,
  ) async {
    final int? reviewId =
        review.id;

    if (reviewId == null) {
      _showMessage(
        'Recensione senza ID valido.',
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
              AppColors.eleganceDeepNavy,

          title:
              const Text(
            'Rifiuta recensione',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),

          content:
              const Text(
            'Vuoi rifiutare questa recensione?',

            style:
                TextStyle(
              color:
                  Colors.white70,
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
                      Colors.redAccent,
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

    await _executeAction(
      reviewId:
          reviewId,

      action:
          () =>
              _apiService
                  .rejectReview(
        reviewId,
      ),

      successMessage:
          'Recensione rifiutata.',
    );
  }


  Future<void> _hide(
    SocialReview review,
  ) async {
    final int? reviewId =
        review.id;

    if (reviewId == null) {
      _showMessage(
        'Recensione senza ID valido.',
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
              AppColors.eleganceDeepNavy,

          title:
              const Text(
            'Nascondi recensione',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,
            ),
          ),

          content:
              const Text(
            'La recensione non sarà più visibile pubblicamente. Vuoi continuare?',

            style:
                TextStyle(
              color:
                  Colors.white70,
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
                'Nascondi',

                style:
                    TextStyle(
                  color:
                      Colors.orangeAccent,
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

    await _executeAction(
      reviewId:
          reviewId,

      action:
          () =>
              _apiService
                  .hideReview(
        reviewId,
      ),

      successMessage:
          'Recensione nascosta.',
    );
  }


  Future<void> _restore(
    SocialReview review,
  ) async {
    final int? reviewId =
        review.id;

    if (reviewId == null) {
      _showMessage(
        'Recensione senza ID valido.',
      );

      return;
    }

    await _executeAction(
      reviewId:
          reviewId,

      action:
          () =>
              _apiService
                  .restoreReview(
        reviewId,
      ),

      successMessage:
          'Recensione ripristinata.',
    );
  }


  Future<void> _executeAction({
    required int reviewId,
    required Future<SocialReview>
        Function() action,
    required String successMessage,
  }) async {
    if (
      _processingIds.contains(
        reviewId,
      )
    ) {
      return;
    }

    setState(() {
      _processingIds.add(
        reviewId,
      );
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      _showMessage(
        successMessage,
      );

      await _loadReviews(
        refresh:
            true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(
          e,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingIds.remove(
            reviewId,
          );
        });
      }
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
            AppColors.brandNightBlue,

        foregroundColor:
            AppColors.pureWhite,

        elevation:
            0,

        title:
            const Text(
          'Moderazione recensioni',

          style:
              TextStyle(
            fontSize:
                18,

            fontWeight:
                FontWeight.w500,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
                'Aggiorna',

            onPressed:
                _refreshing
                    ? null
                    : () {
                        _loadReviews(
                          refresh:
                              true,
                        );
                      },

            icon:
                _refreshing
                    ? const SizedBox(
                        width:
                            19,

                        height:
                            19,

                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,

                          color:
                              AppColors.pureWhite,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                      ),
          ),
        ],
      ),

      body:
          SafeArea(
        child:
            Center(
          child:
              ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  900,
            ),

            child:
                Column(
              children: [
                _buildFilters(),

                Expanded(
                  child:
                      _buildBody(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,

      padding:
          const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        12,
      ),

      child:
          Row(
        children: [
          _FilterChip(
            label:
                'Tutte',

            selected:
                _selectedStatus ==
                    null,

            onTap:
                () {
              _changeFilter(
                null,
              );
            },
          ),

          const SizedBox(
            width:
                8,
          ),

          _FilterChip(
            label:
                'In attesa',

            selected:
                _selectedStatus ==
                    ReviewModerationStatus
                        .pending,

            onTap:
                () {
              _changeFilter(
                ReviewModerationStatus
                    .pending,
              );
            },
          ),

          const SizedBox(
            width:
                8,
          ),

          _FilterChip(
            label:
                'Approvate',

            selected:
                _selectedStatus ==
                    ReviewModerationStatus
                        .approved,

            onTap:
                () {
              _changeFilter(
                ReviewModerationStatus
                    .approved,
              );
            },
          ),

          const SizedBox(
            width:
                8,
          ),

          _FilterChip(
            label:
                'Rifiutate',

            selected:
                _selectedStatus ==
                    ReviewModerationStatus
                        .rejected,

            onTap:
                () {
              _changeFilter(
                ReviewModerationStatus
                    .rejected,
              );
            },
          ),

          const SizedBox(
            width:
                8,
          ),

          _FilterChip(
            label:
                'Nascoste',

            selected:
                _selectedStatus ==
                    ReviewModerationStatus
                        .hidden,

            onTap:
                () {
              _changeFilter(
                ReviewModerationStatus
                    .hidden,
              );
            },
          ),
        ],
      ),
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
      return _AdminReviewsError(
        message:
            _error!,

        onRetry:
            _loadReviews,
      );
    }

    if (_reviews.isEmpty) {
      return _EmptyAdminReviews(
        status:
            _selectedStatus,
      );
    }

    return RefreshIndicator(
      onRefresh:
          () =>
              _loadReviews(
        refresh:
            true,
      ),

      child:
          ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          16,
          6,
          16,
          24,
        ),

        itemCount:
            _reviews.length,

        separatorBuilder:
            (
          BuildContext context,
          int index,
        ) {
          return const SizedBox(
            height:
                16,
          );
        },

        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          final SocialReview review =
              _reviews[index];

          return _AdminReviewItem(
            review:
                review,

            processing:
                _isProcessing(
              review,
            ),

            onApprove:
                () {
              _approve(
                review,
              );
            },

            onReject:
                () {
              _reject(
                review,
              );
            },

            onHide:
                () {
              _hide(
                review,
              );
            },

            onRestore:
                () {
              _restore(
                review,
              );
            },
          );
        },
      ),
    );
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


  String _cleanError(
    Object error,
  ) {
    String message =
        error.toString();

    if (
      message.startsWith(
        'Exception: ',
      )
    ) {
      message =
          message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }
}


class _AdminReviewItem
    extends StatelessWidget {
  final SocialReview review;

  final bool processing;

  final VoidCallback onApprove;

  final VoidCallback onReject;

  final VoidCallback onHide;

  final VoidCallback onRestore;


  const _AdminReviewItem({
    required this.review,
    required this.processing,
    required this.onApprove,
    required this.onReject,
    required this.onHide,
    required this.onRestore,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              AppColors.skyBlue
                  .withOpacity(
            0.12,
          ),
        ),
      ),

      child:
          Column(
        children: [
          ReviewCard(
            review:
                review,

            showModerationStatus:
                true,
          ),

          const SizedBox(
            height:
                12,
          ),

          if (processing)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical:
                    8,
              ),

              child:
                  LinearProgressIndicator(),
            )
          else
            _buildActions(),
        ],
      ),
    );
  }


  Widget _buildActions() {
    switch (review.moderationStatus) {
      case ReviewModerationStatus.pending:
        return Row(
          children: [
            Expanded(
              child:
                  ElevatedButton.icon(
                onPressed:
                    onApprove,

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.greenAccent,

                  foregroundColor:
                      AppColors
                          .eleganceSoftNight,

                  elevation:
                      0,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),

                icon:
                    const Icon(
                  Icons.check_rounded,
                ),

                label:
                    const Text(
                  'Approva',
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
                    onReject,

                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      Colors.redAccent,

                  side:
                      BorderSide(
                    color:
                        Colors.redAccent
                            .withOpacity(
                      0.40,
                    ),
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),

                icon:
                    const Icon(
                  Icons.close_rounded,
                ),

                label:
                    const Text(
                  'Rifiuta',
                ),
              ),
            ),
          ],
        );

      case ReviewModerationStatus.approved:
        return SizedBox(
          width:
              double.infinity,

          child:
              OutlinedButton.icon(
            onPressed:
                onHide,

            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  Colors.orangeAccent,

              side:
                  BorderSide(
                color:
                    Colors.orangeAccent
                        .withOpacity(
                  0.40,
                ),
              ),

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
            ),

            icon:
                const Icon(
              Icons.visibility_off_outlined,
            ),

            label:
                const Text(
              'Nascondi recensione',
            ),
          ),
        );

      case ReviewModerationStatus.rejected:
        return Row(
          children: [
            Expanded(
              child:
                  ElevatedButton.icon(
                onPressed:
                    onApprove,

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.greenAccent,

                  foregroundColor:
                      AppColors
                          .eleganceSoftNight,

                  elevation:
                      0,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),

                icon:
                    const Icon(
                  Icons.check_rounded,
                ),

                label:
                    const Text(
                  'Approva',
                ),
              ),
            ),
          ],
        );

      case ReviewModerationStatus.hidden:
        return SizedBox(
          width:
              double.infinity,

          child:
              ElevatedButton.icon(
            onPressed:
                onRestore,

            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  AppColors.skyBlue,

              foregroundColor:
                  AppColors.brandNightBlue,

              elevation:
                  0,

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
            ),

            icon:
                const Icon(
              Icons.visibility_rounded,
            ),

            label:
                const Text(
              'Ripristina recensione',
            ),
          ),
        );
    }
  }
}


class _FilterChip
    extends StatelessWidget {
  final String label;

  final bool selected;

  final VoidCallback onTap;


  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          Colors.transparent,

      child:
          InkWell(
        onTap:
            onTap,

        borderRadius:
            BorderRadius.circular(
          999,
        ),

        child:
            AnimatedContainer(
          duration:
              const Duration(
            milliseconds:
                170,
          ),

          padding:
              const EdgeInsets.symmetric(
            horizontal:
                14,

            vertical:
                9,
          ),

          decoration:
              BoxDecoration(
            color:
                selected
                    ? AppColors.skyBlue
                    : AppColors
                        .eleganceMidnight,

            borderRadius:
                BorderRadius.circular(
              999,
            ),

            border:
                Border.all(
              color:
                  selected
                      ? AppColors.skyBlue
                      : AppColors.skyBlue
                          .withOpacity(
                          0.13,
                        ),
            ),
          ),

          child:
              Text(
            label,

            style:
                TextStyle(
              color:
                  selected
                      ? AppColors
                          .brandNightBlue
                      : AppColors.pureWhite,

              fontSize:
                  11,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}


class _EmptyAdminReviews
    extends StatelessWidget {
  final ReviewModerationStatus?
      status;


  const _EmptyAdminReviews({
    required this.status,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      padding:
          const EdgeInsets.all(
        20,
      ),

      children: [
        const SizedBox(
          height:
              100,
        ),

        Container(
          padding:
              const EdgeInsets.all(
            28,
          ),

          decoration:
              BoxDecoration(
            color:
                AppColors.eleganceMidnight,

            borderRadius:
                BorderRadius.circular(
              18,
            ),

            border:
                Border.all(
              color:
                  AppColors.skyBlue
                      .withOpacity(
                0.10,
              ),
            ),
          ),

          child:
              Column(
            children: [
              const Icon(
                Icons
                    .rate_review_outlined,

                color:
                    Colors.white38,

                size:
                    44,
              ),

              const SizedBox(
                height:
                    12,
              ),

              Text(
                _message(),

                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      Colors.white60,

                  fontSize:
                      12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  String _message() {
    switch (status) {
      case ReviewModerationStatus.pending:
        return 'Nessuna recensione in attesa di moderazione.';

      case ReviewModerationStatus.approved:
        return 'Nessuna recensione approvata.';

      case ReviewModerationStatus.rejected:
        return 'Nessuna recensione rifiutata.';

      case ReviewModerationStatus.hidden:
        return 'Nessuna recensione nascosta.';

      case null:
        return 'Nessuna recensione disponibile.';
    }
  }
}


class _AdminReviewsError
    extends StatelessWidget {
  final String message;

  final Future<void> Function({
    bool refresh,
  }) onRetry;


  const _AdminReviewsError({
    required this.message,
    required this.onRetry,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          20,
        ),

        child:
            Container(
          width:
              double.infinity,

          padding:
              const EdgeInsets.all(
            24,
          ),

          decoration:
              BoxDecoration(
            color:
                AppColors.eleganceMidnight,

            borderRadius:
                BorderRadius.circular(
              18,
            ),

            border:
                Border.all(
              color:
                  Colors.redAccent
                      .withOpacity(
                0.18,
              ),
            ),
          ),

          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              const Icon(
                Icons.error_outline_rounded,

                color:
                    Colors.redAccent,

                size:
                    40,
              ),

              const SizedBox(
                height:
                    12,
              ),

              const Text(
                'Impossibile caricare le recensioni',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite,

                  fontSize:
                      15,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                    8,
              ),

              Text(
                message,

                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      Colors.white60,

                  fontSize:
                      11,
                ),
              ),

              const SizedBox(
                height:
                    16,
              ),

              OutlinedButton.icon(
                onPressed:
                    () {
                  onRetry();
                },

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
      ),
    );
  }
}