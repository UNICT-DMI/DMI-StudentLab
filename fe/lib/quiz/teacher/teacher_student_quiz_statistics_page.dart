import 'package:flutter/material.dart';

import '../../../theme/nightTheme.dart';
import 'services/teacher_quiz_statistics_service.dart';


class TeacherStudentQuizStatisticsPage
    extends StatefulWidget {
  final int studentId;
  final String studentLabel;
  final String department;
  final String course;
  final String subject;

  const TeacherStudentQuizStatisticsPage({
    super.key,
    required this.studentId,
    required this.studentLabel,
    required this.department,
    required this.course,
    required this.subject,
  });

  @override
  State<TeacherStudentQuizStatisticsPage>
      createState() =>
          _TeacherStudentQuizStatisticsPageState();
}


class _TeacherStudentQuizStatisticsPageState
    extends State<TeacherStudentQuizStatisticsPage> {
  final TeacherQuizStatisticsService _service =
      TeacherQuizStatisticsService();

  List<Map<String, dynamic>>
      _arguments = [];

  List<Map<String, dynamic>>
      _weakArguments = [];

  List<Map<String, dynamic>>
      _review = [];

  bool _loading =
      true;

  String? _error;


  @override
  void initState() {
    super.initState();
    _load();
  }


  Future<void> _load() async {
    setState(() {
      _loading =
          true;

      _error =
          null;
    });

    try {
      final List<Map<String, dynamic>> arguments =
          await _service
              .getStudentArguments(
        studentId:
            widget.studentId,
        department:
            widget.department,
        course:
            widget.course,
        subject:
            widget.subject,
      );

      final List<Map<String, dynamic>> weak =
          await _service
              .getStudentWeakArguments(
        studentId:
            widget.studentId,
        department:
            widget.department,
        course:
            widget.course,
        subject:
            widget.subject,
      );

      final List<Map<String, dynamic>> review =
          await _service
              .getStudentReview(
        studentId:
            widget.studentId,
        department:
            widget.department,
        course:
            widget.course,
        subject:
            widget.subject,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _arguments =
            arguments;

        _weakArguments =
            weak;

        _review =
            review;

        _loading =
            false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading =
            false;

        _error =
            _cleanError(
          error,
        );
      });
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
        title:
            Text(
          widget.studentLabel,
          maxLines:
              1,
          overflow:
              TextOverflow.ellipsis,
        ),
      ),
      body:
          _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : _error != null
                  ? Center(
                      child:
                          Padding(
                        padding:
                            const EdgeInsets.all(
                          24,
                        ),
                        child:
                            Text(
                          _error!,
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh:
                          _load,
                      child:
                          ListView(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        children: [
                          _header(),
                          const SizedBox(
                            height:
                                18,
                          ),
                          _sectionTitle(
                            'Argomenti',
                          ),
                          const SizedBox(
                            height:
                                10,
                          ),
                          if (
                            _arguments.isEmpty
                          )
                            _empty(
                              'Nessuna statistica disponibile.',
                            )
                          else
                            for (
                              final Map<String, dynamic> item
                              in _arguments
                            )
                              _ArgumentCard(
                                data:
                                    item,
                              ),
                          const SizedBox(
                            height:
                                22,
                          ),
                          _sectionTitle(
                            'Argomenti da rafforzare',
                          ),
                          const SizedBox(
                            height:
                                10,
                          ),
                          if (
                            _weakArguments.isEmpty
                          )
                            _empty(
                              'Nessun argomento sotto la soglia di attenzione.',
                            )
                          else
                            for (
                              final Map<String, dynamic> item
                              in _weakArguments
                            )
                              _ArgumentCard(
                                data:
                                    item,
                                weak:
                                    true,
                              ),
                          const SizedBox(
                            height:
                                22,
                          ),
                          _sectionTitle(
                            'Domande da rivedere',
                          ),
                          const SizedBox(
                            height:
                                10,
                          ),
                          if (
                            _review.isEmpty
                          )
                            _empty(
                              'Nessuna domanda da rivedere.',
                            )
                          else
                            for (
                              final Map<String, dynamic> item
                              in _review
                            )
                              _ReviewCard(
                                data:
                                    item,
                              ),
                        ],
                      ),
                    ),
    );
  }


  Widget _header() {
    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child:
          Row(
        children: [
          const CircleAvatar(
            backgroundColor:
                AppColors.brandNightBlue,
            child:
                Icon(
              Icons.person_outline_rounded,
              color:
                  AppColors.skyBlue,
            ),
          ),
          const SizedBox(
            width:
                12,
          ),
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentLabel,
                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,
                    fontSize:
                        16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height:
                      3,
                ),
                Text(
                  widget.subject,
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                    fontSize:
                        11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _sectionTitle(
    String title,
  ) {
    return Text(
      title,
      style:
          const TextStyle(
        color:
            AppColors.pureWhite,
        fontSize:
            17,
        fontWeight:
            FontWeight.bold,
      ),
    );
  }


  Widget _empty(
    String text,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
      child:
          Text(
        text,
        style:
            const TextStyle(
          color:
              Colors.white54,
          fontSize:
              11,
        ),
      ),
    );
  }


  String _cleanError(
    Object error,
  ) {
    String value =
        error.toString();

    if (
      value.startsWith(
        'Exception: ',
      )
    ) {
      value =
          value.substring(
        11,
      );
    }

    return value.trim();
  }
}


class _ArgumentCard
    extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool weak;

  const _ArgumentCard({
    required this.data,
    this.weak = false,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final String argument =
        data[
                'argument']
            ?.toString() ??
        data[
                'argoment']
            ?.toString() ??
        'Argomento';

    final double accuracy =
        _toDouble(
              data[
                'accuracy_percentage'
              ],
            ) ??
            0;

    final int correct =
        _toInt(
              data[
                'correct_count'
              ],
            ) ??
            0;

    final int wrong =
        _toInt(
              data[
                'wrong_count'
              ],
            ) ??
            0;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            10,
      ),
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            weak
                ? Border.all(
                    color:
                        Colors.orangeAccent
                            .withValues(
                      alpha:
                          0.25,
                    ),
                  )
                : null,
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(
                  argument,
                  style:
                      const TextStyle(
                    color:
                        AppColors.pureWhite,
                    fontSize:
                        13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${accuracy.toStringAsFixed(1)}%',
                style:
                    TextStyle(
                  color:
                      weak
                          ? Colors.orangeAccent
                          : AppColors.skyBlue,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(
            height:
                10,
          ),
          LinearProgressIndicator(
            value:
                (accuracy / 100)
                    .clamp(
              0,
              1,
            ),
          ),
          const SizedBox(
            height:
                8,
          ),
          Text(
            '$correct corrette · $wrong errate',
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
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ??
          '',
    );
  }
}


class _ReviewCard
    extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ReviewCard({
    required this.data,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final String questionId =
        data[
                'question_id']
            ?.toString() ??
        '?';

    final double accuracy =
        _toDouble(
              data[
                'accuracy_percentage'
              ],
            ) ??
            0;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            10,
      ),
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceDeepNavy,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child:
          Row(
        children: [
          const Icon(
            Icons.replay_circle_filled_outlined,
            color:
                AppColors.skyBlue,
          ),
          const SizedBox(
            width:
                10,
          ),
          Expanded(
            child:
                Text(
              'Domanda #$questionId',
              style:
                  const TextStyle(
                color:
                    AppColors.pureWhite,
                fontSize:
                    12,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${accuracy.toStringAsFixed(1)}%',
            style:
                const TextStyle(
              color:
                  Colors.white54,
              fontSize:
                  11,
            ),
          ),
        ],
      ),
    );
  }


  static double? _toDouble(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ??
          '',
    );
  }
}