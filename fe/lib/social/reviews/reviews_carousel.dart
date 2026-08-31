import 'dart:async';

import 'package:flutter/material.dart';

import '../social_models.dart';
import 'review_card.dart';


class ReviewsCarousel extends StatefulWidget {
  final List<SocialReview> reviews;

  final double height;

  final Duration autoPlayInterval;

  final Duration animationDuration;

  final bool autoPlay;

  final EdgeInsetsGeometry padding;

  final ValueChanged<SocialReview>? onReviewTap;


  const ReviewsCarousel({
    super.key,
    required this.reviews,
    this.height = 330,
    this.autoPlayInterval =
        const Duration(
      seconds: 1,
    ),
    this.animationDuration =
        const Duration(
      milliseconds: 850,
    ),
    this.autoPlay = true,
    this.padding =
        const EdgeInsets.symmetric(
      horizontal: 16,
    ),
    this.onReviewTap,
  });


  @override
  State<ReviewsCarousel>
      createState() =>
          _ReviewsCarouselState();
}


class _ReviewsCarouselState
    extends State<ReviewsCarousel> {
  PageController? _controller;

  Timer? _autoPlayTimer;

  Timer? _restartTimer;

  int _currentPage = 0;

  bool _userInteracting = false;


  int get _reviewsCount {
    return widget.reviews.length;
  }


  bool get _canAutoPlay {
    return widget.autoPlay &&
        _reviewsCount > 1;
  }


  int get _initialPage {
    if (_reviewsCount <= 1) {
      return 0;
    }

    const int base =
        10000;

    return base -
        (
          base %
          _reviewsCount
        );
  }


  @override
  void initState() {
    super.initState();

    _createController();

    _startAutoPlay();
  }


  @override
  void didUpdateWidget(
    covariant ReviewsCarousel oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    final bool reviewsChanged =
        oldWidget.reviews.length !=
            widget.reviews.length ||
        !_sameReviewIds(
          oldWidget.reviews,
          widget.reviews,
        );

    final bool settingsChanged =
        oldWidget.autoPlay !=
            widget.autoPlay ||
        oldWidget.autoPlayInterval !=
            widget.autoPlayInterval;

    if (reviewsChanged) {
      _autoPlayTimer?.cancel();
      _restartTimer?.cancel();

      _controller?.dispose();

      _createController();

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          if (!mounted) {
            return;
          }

          _startAutoPlay();
        },
      );

      return;
    }

    if (settingsChanged) {
      _startAutoPlay();
    }
  }


  bool _sameReviewIds(
    List<SocialReview> first,
    List<SocialReview> second,
  ) {
    if (
      first.length !=
          second.length
    ) {
      return false;
    }

    for (
      int index = 0;
      index < first.length;
      index++
    ) {
      if (
        first[index].id !=
            second[index].id
      ) {
        return false;
      }
    }

    return true;
  }


  void _createController() {
    _currentPage =
        _initialPage;

    _controller =
        PageController(
      initialPage:
          _currentPage,
      viewportFraction:
          0.92,
    );
  }


  void _startAutoPlay() {
    _autoPlayTimer?.cancel();

    if (!_canAutoPlay) {
      return;
    }

    _autoPlayTimer =
        Timer.periodic(
      widget.autoPlayInterval,
      (_) {
        _goToNextPage();
      },
    );
  }


  Future<void>
      _goToNextPage() async {
    if (
      !_canAutoPlay ||
      _userInteracting
    ) {
      return;
    }

    final PageController? controller =
        _controller;

    if (
      controller == null ||
      !controller.hasClients
    ) {
      return;
    }

    final int nextPage =
        _currentPage + 1;

    try {
      await controller.animateToPage(
        nextPage,
        duration:
            widget.animationDuration,
        curve:
            Curves.easeInOutCubic,
      );
    } catch (_) {}
  }


  void _pauseAutoPlay() {
    _userInteracting =
        true;

    _autoPlayTimer?.cancel();

    _restartTimer?.cancel();
  }


  void _resumeAutoPlayLater() {
    _restartTimer?.cancel();

    _restartTimer =
        Timer(
      const Duration(
        seconds: 4,
      ),
      () {
        if (!mounted) {
          return;
        }

        _userInteracting =
            false;

        _startAutoPlay();
      },
    );
  }


  void _onPageChanged(
    int page,
  ) {
    if (!mounted) {
      return;
    }

    setState(
      () {
        _currentPage =
            page;
      },
    );
  }


  int get _currentIndex {
    if (_reviewsCount == 0) {
      return 0;
    }

    return _currentPage %
        _reviewsCount;
  }


  @override
  void dispose() {
    _autoPlayTimer?.cancel();

    _restartTimer?.cancel();

    _controller?.dispose();

    super.dispose();
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    if (widget.reviews.isEmpty) {
      return const _EmptyReviews();
    }

    if (widget.reviews.length == 1) {
      return Padding(
        padding:
            widget.padding,
        child:
            ReviewCard(
          review:
              widget.reviews.first,
          onTap:
              widget.onReviewTap ==
                      null
                  ? null
                  : () {
                      widget.onReviewTap!(
                        widget
                            .reviews
                            .first,
                      );
                    },
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height:
              widget.height,
          child:
              NotificationListener<
                  ScrollNotification>(
            onNotification:
                (
                  ScrollNotification
                      notification,
                ) {
              if (
                notification
                is ScrollStartNotification
              ) {
                _pauseAutoPlay();
              }

              if (
                notification
                is ScrollEndNotification
              ) {
                _resumeAutoPlayLater();
              }

              return false;
            },
            child:
                PageView.builder(
              controller:
                  _controller,
              onPageChanged:
                  _onPageChanged,
              itemBuilder:
                  (
                    BuildContext context,
                    int page,
                  ) {
                final int index =
                    page %
                        widget
                            .reviews
                            .length;

                final SocialReview review =
                    widget
                        .reviews[
                    index
                  ];

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        6,
                    vertical:
                        8,
                  ),
                  child:
                      ReviewCard(
                    review:
                        review,
                    onTap:
                        widget.onReviewTap ==
                                null
                            ? null
                            : () {
                                widget
                                    .onReviewTap!(
                                  review,
                                );
                              },
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(
          height:
              10,
        ),

        _CarouselIndicator(
          count:
              widget.reviews.length,
          currentIndex:
              _currentIndex,
        ),
      ],
    );
  }
}


class _CarouselIndicator
    extends StatelessWidget {
  final int count;

  final int currentIndex;


  const _CarouselIndicator({
    required this.count,
    required this.currentIndex,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    if (count <= 1) {
      return const SizedBox.shrink();
    }

    final ColorScheme colors =
        Theme.of(
      context,
    ).colorScheme;

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children:
          List.generate(
        count,
        (
          int index,
        ) {
          final bool selected =
              index ==
                  currentIndex;

          return AnimatedContainer(
            duration:
                const Duration(
              milliseconds:
                  220,
            ),
            curve:
                Curves.easeOut,
            margin:
                const EdgeInsets.symmetric(
              horizontal:
                  3,
            ),
            width:
                selected
                    ? 20
                    : 7,
            height:
                7,
            decoration:
                BoxDecoration(
              color:
                  selected
                      ? colors.primary
                      : colors
                          .outlineVariant,
              borderRadius:
                  BorderRadius.circular(
                999,
              ),
            ),
          );
        },
      ),
    );
  }
}


class _EmptyReviews
    extends StatelessWidget {
  const _EmptyReviews();


  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(
      context,
    );

    final ColorScheme colors =
        theme.colorScheme;

    return Container(
      width:
          double.infinity,
      margin:
          const EdgeInsets.symmetric(
        horizontal:
            16,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            24,
        vertical:
            32,
      ),
      decoration:
          BoxDecoration(
        color:
            colors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              colors.outlineVariant
                  .withValues(
            alpha:
                0.5,
          ),
        ),
      ),
      child:
          Column(
        children: [
          Container(
            width:
                56,
            height:
                56,
            decoration:
                BoxDecoration(
              color:
                  colors
                      .primaryContainer,
              shape:
                  BoxShape.circle,
            ),
            child:
                Icon(
              Icons.rate_review_outlined,
              color:
                  colors
                      .onPrimaryContainer,
              size:
                  27,
            ),
          ),

          const SizedBox(
            height:
                14,
          ),

          Text(
            'Nessuna recensione',
            textAlign:
                TextAlign.center,
            style:
                theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height:
                6,
          ),

          Text(
            'Le recensioni approvate compariranno qui.',
            textAlign:
                TextAlign.center,
            style:
                theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
              color:
                  colors
                      .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}