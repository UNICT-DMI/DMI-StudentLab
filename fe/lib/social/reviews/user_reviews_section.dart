import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_session.dart';
import '../../theme/nightTheme.dart';

import '../social_models.dart';

import 'review_form_page.dart';
import 'reviews_carousel.dart';


class UserReviewsSection
    extends StatefulWidget {
  final SocialUser user;

  final bool showTitle;

  final EdgeInsetsGeometry padding;


  const UserReviewsSection({
    super.key,
    required this.user,
    this.showTitle = true,
    this.padding = EdgeInsets.zero,
  });


  @override
  State<UserReviewsSection>
      createState() =>
          _UserReviewsSectionState();
}


class _UserReviewsSectionState
    extends State<UserReviewsSection> {
  final ApiService _apiService =
      ApiService();

  final AuthSession _session =
      AuthSession.instance;


  List<SocialReview> _reviews =
      [];

  SocialReview? _myReview;

  double _averageRating =
      0;

  int _reviewCount =
      0;

  bool _loading =
      true;

  bool _openingForm =
      false;

  String? _error;


  SocialUser get user {
    return widget.user;
  }


  int? get currentUserId {
    return _session.currentUserId;
  }


  bool get isAuthenticated {
    return _session.isAuthenticated;
  }


  bool get isOwnProfile {
    final int? id =
        currentUserId;

    if (id == null) {
      return false;
    }

    return id ==
        user.id;
  }


  bool get canWriteReview {
    return isAuthenticated &&
        !isOwnProfile;
  }


  @override
  void initState() {
    super.initState();

    _session.addListener(
      _onSessionChanged,
    );

    _loadReviews();
  }


  @override
  void didUpdateWidget(
    covariant UserReviewsSection oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (
      oldWidget.user.id !=
          widget.user.id
    ) {
      _loadReviews();
    }
  }


  @override
  void dispose() {
    _session.removeListener(
      _onSessionChanged,
    );

    super.dispose();
  }


  void _onSessionChanged() {
    if (!mounted) {
      return;
    }

    _loadReviews();
  }


  Future<void> _loadReviews() async {
    if (mounted) {
      setState(() {
        _loading =
            true;

        _error =
            null;
      });
    }

    try {
      final Map<String, dynamic>
          data =
          await _apiService
              .getUserReviewsData(
        user.id,
      );

      final List<SocialReview>
          reviews =
          _parseReviews(
        data,
      );

      final Map<String, dynamic>?
          summary =
          _parseSummary(
        data,
      );

      final double averageRating =
          _toDouble(
            summary?[
              'average_rating'
            ],
          ) ??
          _calculateAverage(
            reviews,
          );

      final int reviewCount =
          _toInt(
            summary?[
              'review_count'
            ],
          ) ??
          reviews.length;

      SocialReview? myReview;

      if (
        isAuthenticated &&
        !isOwnProfile
      ) {
        myReview =
            await _apiService
                .getMyReviewForUser(
          user.id,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _reviews =
            reviews;

        _averageRating =
            averageRating;

        _reviewCount =
            reviewCount;

        _myReview =
            myReview;

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
            _cleanError(
          e,
        );
      });
    }
  }


  List<SocialReview> _parseReviews(
    Map<String, dynamic> data,
  ) {
    final dynamic reviewsData =
        data['reviews'];

    if (reviewsData is! List) {
      return [];
    }

    return reviewsData
        .whereType<Map>()
        .map(
          (
            Map<dynamic, dynamic> item,
          ) =>
              SocialReview.fromJson(
            Map<String, dynamic>.from(
              item,
            ),
          ),
        )
        .toList();
  }


  Map<String, dynamic>? _parseSummary(
    Map<String, dynamic> data,
  ) {
    final dynamic summary =
        data['summary'];

    if (summary is Map) {
      return Map<String, dynamic>.from(
        summary,
      );
    }

    return null;
  }


  double _calculateAverage(
    List<SocialReview> reviews,
  ) {
    if (reviews.isEmpty) {
      return 0;
    }

    final double total =
        reviews.fold<double>(
      0,
      (
        double sum,
        SocialReview review,
      ) =>
          sum +
          review.rating,
    );

    return total /
        reviews.length;
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          widget.padding,

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          if (widget.showTitle)
            _buildHeader(),

          if (widget.showTitle)
            const SizedBox(
              height:
                  14,
            ),

          if (_loading)
            _buildLoading()
          else if (_error != null)
            _buildError()
          else
            _buildContent(),
        ],
      ),
    );
  }


  Widget _buildHeader() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,

      children: [
        const Expanded(
          child:
              Text(
            'Recensioni',

            style:
                TextStyle(
              color:
                  AppColors.pureWhite,

              fontSize:
                  20,

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        if (!_loading &&
            _error == null)
          _RatingSummaryBadge(
            averageRating:
                _averageRating,

            reviewCount:
                _reviewCount,
          ),
      ],
    );
  }


  Widget _buildLoading() {
    return Container(
      width:
          double.infinity,

      height:
          180,

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
          const Center(
        child:
            CircularProgressIndicator(),
      ),
    );
  }


  Widget _buildError() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        20,
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
        children: [
          const Icon(
            Icons.error_outline_rounded,

            color:
                Colors.redAccent,

            size:
                34,
          ),

          const SizedBox(
            height:
                10,
          ),

          Text(
            _error!,

            textAlign:
                TextAlign.center,

            style:
                const TextStyle(
              color:
                  Colors.white60,

              fontSize:
                  11,

              height:
                  1.4,
            ),
          ),

          const SizedBox(
            height:
                14,
          ),

          OutlinedButton.icon(
            onPressed:
                _loadReviews,

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
    );
  }


  Widget _buildContent() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        if (
          _myReview != null
        ) ...[
          _MyReviewStatusCard(
            review:
                _myReview!,
          ),

          const SizedBox(
            height:
                14,
          ),
        ],

        ReviewsCarousel(
          reviews:
              _reviews,

          onReviewTap:
              null,
        ),

        if (
          canWriteReview
        ) ...[
          const SizedBox(
            height:
                18,
          ),

          _buildReviewAction(),
        ],

        if (
          !isAuthenticated
        ) ...[
          const SizedBox(
            height:
                18,
          ),

          _buildLoginInfo(),
        ],
      ],
    );
  }


  Widget _buildReviewAction() {
    final bool editing =
        _myReview != null;

    return SizedBox(
      width:
          double.infinity,

      height:
          50,

      child:
          ElevatedButton.icon(
        onPressed:
            _openingForm
                ? null
                : _openReviewForm,

        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              AppColors.skyBlue,

          foregroundColor:
              AppColors.brandNightBlue,

          disabledBackgroundColor:
              AppColors.skyBlue
                  .withOpacity(
            0.40,
          ),

          disabledForegroundColor:
              AppColors.brandNightBlue
                  .withOpacity(
            0.60,
          ),

          elevation:
              0,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),

        icon:
            _openingForm
                ? const SizedBox(
                    width:
                        18,

                    height:
                        18,

                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          2,

                      color:
                          AppColors
                              .brandNightBlue,
                    ),
                  )
                : Icon(
                    editing
                        ? Icons
                            .edit_outlined
                        : Icons
                            .rate_review_outlined,
                  ),

        label:
            Text(
          editing
              ? 'Modifica recensione'
              : 'Scrivi una recensione',

          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }


  Widget _buildLoginInfo() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.skyBlue
                .withOpacity(
          0.05,
        ),

        borderRadius:
            BorderRadius.circular(
          14,
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
          Row(
        children: [
          const Icon(
            Icons.login_rounded,

            color:
                AppColors.materialSky,

            size:
                20,
          ),

          const SizedBox(
            width:
                10,
          ),

          Expanded(
            child:
                Text(
              'Accedi a StudentLab per lasciare una recensione.',

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withOpacity(
                  0.52,
                ),

                fontSize:
                    11,

                height:
                    1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _openReviewForm() async {
    if (!canWriteReview) {
      return;
    }

    setState(() {
      _openingForm =
          true;
    });

    try {
      final bool? changed =
          await Navigator.of(
        context,
      ).push<bool>(
        MaterialPageRoute(
          builder:
              (
                BuildContext context,
              ) =>
                  ReviewFormPage(
            reviewedUser:
                user,
          ),
        ),
      );

      if (
        changed == true &&
        mounted
      ) {
        await _loadReviews();
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingForm =
              false;
        });
      }
    }
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


  static int? _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ??
          '',
    );
  }


  static double? _toDouble(
    dynamic value,
  ) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ??
          '',
    );
  }
}


class _RatingSummaryBadge
    extends StatelessWidget {
  final double averageRating;

  final int reviewCount;


  const _RatingSummaryBadge({
    required this.averageRating,
    required this.reviewCount,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            10,

        vertical:
            6,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        borderRadius:
            BorderRadius.circular(
          999,
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
          Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          const Icon(
            Icons.star_rounded,

            color:
                Colors.amber,

            size:
                17,
          ),

          const SizedBox(
            width:
                4,
          ),

          Text(
            averageRating
                .toStringAsFixed(
              1,
            ),

            style:
                const TextStyle(
              color:
                  AppColors.pureWhite,

              fontSize:
                  11,

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            width:
                5,
          ),

          Text(
            '($reviewCount)',

            style:
                const TextStyle(
              color:
                  Colors.white54,

              fontSize:
                  10,
            ),
          ),
        ],
      ),
    );
  }
}


class _MyReviewStatusCard
    extends StatelessWidget {
  final SocialReview review;


  const _MyReviewStatusCard({
    required this.review,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final String title;
    final String description;
    final IconData icon;
    final Color color;

    switch (review.moderationStatus) {
      case ReviewModerationStatus.pending:
        title =
            'La tua recensione è in attesa';

        description =
            'Sarà visibile nel profilo dopo l\'approvazione.';

        icon =
            Icons.hourglass_top_rounded;

        color =
            Colors.orangeAccent;

        break;

      case ReviewModerationStatus.approved:
        title =
            'La tua recensione è pubblicata';

        description =
            'Puoi modificarla in qualsiasi momento.';

        icon =
            Icons.verified_rounded;

        color =
            Colors.greenAccent;

        break;

      case ReviewModerationStatus.rejected:
        title =
            'La tua recensione è stata rifiutata';

        description =
            'Puoi modificarla e inviarla nuovamente.';

        icon =
            Icons.cancel_outlined;

        color =
            Colors.redAccent;

        break;

      case ReviewModerationStatus.hidden:
        title =
            'La tua recensione è nascosta';

        description =
            'Al momento non è visibile pubblicamente.';

        icon =
            Icons.visibility_off_outlined;

        color =
            Colors.orangeAccent;

        break;
    }

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          0.05,
        ),

        borderRadius:
            BorderRadius.circular(
          14,
        ),

        border:
            Border.all(
          color:
              color.withOpacity(
            0.18,
          ),
        ),
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            icon,

            color:
                color,

            size:
                21,
          ),

          const SizedBox(
            width:
                10,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style:
                      TextStyle(
                    color:
                        color,

                    fontSize:
                        12,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                      4,
                ),

                Text(
                  description,

                  style:
                      const TextStyle(
                    color:
                        Colors.white54,

                    fontSize:
                        10,

                    height:
                        1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}