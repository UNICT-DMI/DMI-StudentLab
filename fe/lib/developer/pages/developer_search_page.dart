import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

import '../data/developer_api_repository.dart';
import '../models/developer_models.dart';
import '../theme/developer_ui_style.dart';
import 'developer_file_detail_page.dart';

class DeveloperSearchPage
    extends StatefulWidget {
  const DeveloperSearchPage({
    super.key,
  });

  @override
  State<DeveloperSearchPage> createState() =>
      _DeveloperSearchPageState();
}

class _DeveloperSearchPageState
    extends State<DeveloperSearchPage> {
  final DeveloperApiRepository _repository =
      const DeveloperApiRepository();

  final TextEditingController _controller =
      TextEditingController();

  Timer? _debounce;

  List<DeveloperSearchResult> _results =
      const [];

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(value),
    );
  }

  Future<void> _search(
    String value,
  ) async {
    final String query =
        value.trim();

    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _results = const [];
          _loading = false;
          _error = null;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<DeveloperSearchResult>
          results =
          await _repository.search(
        query,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _open(
    DeveloperSearchResult result,
  ) async {
    try {
      final DeveloperFileDoc file =
          await _repository.getFile(
        result.path,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              DeveloperFileDetailPage(
            file: file,
            initialFunctionName:
                result.functionName,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(error.toString()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor:
            AppColors.brandNightBlue,
        foregroundColor:
            AppColors.pureWhite,
        elevation: 0,
        title:
            Text('Developer Search'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  DeveloperUiStyle.maxContentWidth,
            ),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.all(
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cerca nell’architettura',
                        style: TextStyle(
                          color:
                              AppColors.pureWhite,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        'Puoi cercare file, funzioni o descrivere '
                        'un comportamento: “login”, “docente verificato”, '
                        '“bcrypt”, “material upload”.',
                        style: DeveloperUiStyle.bodyMuted,
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      TextField(
                        controller:
                            _controller,
                        onChanged:
                            _onChanged,
                        style:
                            const TextStyle(
                          color:
                              AppColors.pureWhite,
                        ),
                        decoration:
                            InputDecoration(
                          hintText:
                              'Cerca comportamento, file o funzione...',
                          hintStyle:
                              const TextStyle(
                            color:
                                Colors.white38,
                          ),
                          prefixIcon:
                              const Icon(
                            Icons.manage_search,
                            color:
                                AppColors.skyBlue,
                          ),
                          filled: true,
                          fillColor: AppColors
                              .eleganceMidnight,
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            borderSide:
                                BorderSide(
                              color: AppColors
                                  .skyBlue
                                  .withValues(
                                alpha: 0.10,
                              ),
                            ),
                          ),
                          focusedBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            borderSide:
                                BorderSide(
                              color: AppColors
                                  .skyBlue
                                  .withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const LinearProgressIndicator(
                    color:
                        AppColors.skyBlue,
                    backgroundColor:
                        AppColors.eleganceMidnight,
                  ),
                if (_error != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color:
                            Colors.redAccent,
                        fontSize: 11,
                      ),
                    ),
                  ),
                Expanded(
                  child: _results.isEmpty &&
                          !_loading
                      ? Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(
                              24,
                            ),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons
                                      .travel_explore_outlined,
                                  color:
                                      Colors.white24,
                                  size: 44,
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Text(
                                  'La ricerca attraversa path, '
                                  'funzioni, calls, calledBy e sicurezza.',
                                  textAlign:
                                      TextAlign.center,
                                  style:
                                      DeveloperUiStyle
                                          .bodyMuted,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets
                                  .fromLTRB(
                            20,
                            8,
                            20,
                            24,
                          ),
                          itemCount:
                              _results.length,
                          separatorBuilder:
                              (_, _) =>
                                  const SizedBox(
                            height: 9,
                          ),
                          itemBuilder:
                              (
                            BuildContext context,
                            int index,
                          ) {
                            final DeveloperSearchResult
                                result =
                                _results[index];

                            final bool isFunction =
                                result.kind ==
                                    'function';

                            return InkWell(
                              onTap: () =>
                                  _open(result),
                              borderRadius:
                                  BorderRadius.circular(
                                15,
                              ),
                              child: Container(
                                padding:
                                    const EdgeInsets
                                        .all(
                                  14,
                                ),
                                decoration:
                                    DeveloperUiStyle
                                        .panelDecoration(
                                  borderColor:
                                      isFunction
                                          ? AppColors
                                              .materialSky
                                          : AppColors
                                              .skyBlue,
                                  radius: 15,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration:
                                          BoxDecoration(
                                        color: AppColors
                                            .brandNightBlue,
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          12,
                                        ),
                                      ),
                                      child: Icon(
                                        isFunction
                                            ? Icons
                                                .functions
                                            : Icons
                                                .description_outlined,
                                        color:
                                            isFunction
                                                ? AppColors
                                                    .materialSky
                                                : AppColors
                                                    .skyBlue,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 12,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            result.title,
                                            style:
                                                const TextStyle(
                                              color: AppColors
                                                  .pureWhite,
                                              fontSize:
                                                  12,
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 3,
                                          ),
                                          Text(
                                            result
                                                .subtitle,
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                            style:
                                                DeveloperUiStyle
                                                    .bodyMuted,
                                          ),
                                          if (result.reasons
                                              .isNotEmpty) ...[
                                            const SizedBox(
                                              height: 6,
                                            ),
                                            Wrap(
                                              spacing: 5,
                                              runSpacing:
                                                  5,
                                              children: result
                                                  .reasons
                                                  .take(3)
                                                  .map(
                                                    (
                                                      String
                                                          reason,
                                                    ) =>
                                                        _ReasonBadge(
                                                      label:
                                                          reason,
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 8,
                                    ),
                                    Text(
                                      result.score
                                          .toStringAsFixed(
                                        1,
                                      ),
                                      style:
                                          const TextStyle(
                                        color: AppColors
                                            .materialSky,
                                        fontSize: 10,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonBadge
    extends StatelessWidget {
  final String label;

  const _ReasonBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.skyBlue
            .withValues(alpha: 0.08),
        borderRadius:
            BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.materialSky,
          fontSize: 7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}