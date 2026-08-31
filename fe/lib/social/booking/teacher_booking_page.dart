import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import '../social_models.dart';

class TeacherBookingPage extends StatefulWidget {
  final SocialUser teacher;

  const TeacherBookingPage({
    super.key,
    required this.teacher,
  });

  @override
  State<TeacherBookingPage> createState() =>
      _TeacherBookingPageState();
}

class _TeacherBookingPageState
    extends State<TeacherBookingPage> {

  final _formKey = GlobalKey<FormState>();

  final _messageController = TextEditingController();

  SocialSubject? _selectedSubject;

  DateTime? _selectedDate;

  TimeOfDay? _selectedTime;

  int _duration = 60;

  @override
  void initState() {
    super.initState();

    if (widget.teacher.subjects.length == 1) {
      _selectedSubject =
          widget.teacher.subjects.first;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final result = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(
        const Duration(days: 90),
      ),
      initialDate: now,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedDate = result;
    });
  }

  Future<void> _selectTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedTime = result;
    });
  }

  void _sendRequest() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSubject == null) {
      _showError(
        'Seleziona una materia.',
      );
      return;
    }

    if (_selectedDate == null) {
      _showError(
        'Seleziona una data.',
      );
      return;
    }

    if (_selectedTime == null) {
      _showError(
        'Seleziona un orario.',
      );
      return;
    }

    // Per ora NON mandiamo nulla al server.
    //
    // In futuro:
    //
    // Flutter
    //    ↓
    // BookingService
    //    ↓
    // API FastAPI
    //    ↓
    // PostgreSQL

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Richiesta di lezione salvata localmente.',
        ),
      ),
    );

    Navigator.pop(context);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,

      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text(
          'Richiedi una lezione',
        ),
      ),

      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  constraints.maxWidth > 700
                      ? 650.0
                      : constraints.maxWidth;

              return SizedBox(
                width: width,

                child: Form(
                  key: _formKey,

                  child: ListView(
                    padding: const EdgeInsets.all(20),

                    children: [

                      Container(
                        padding:
                            const EdgeInsets.all(16),

                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.eleganceDeepNavy,

                          borderRadius:
                              BorderRadius.circular(18),

                          border: Border.all(
                            color: AppColors
                                .teacherIndigo
                                .withOpacity(0.25),
                          ),
                        ),

                        child: Row(
                          children: [

                            CircleAvatar(
                              radius: 27,

                              backgroundColor:
                                  AppColors
                                      .teacherIndigo,

                              child: Text(
                                widget.teacher.name
                                        .isNotEmpty
                                    ? widget.teacher
                                        .name[0]
                                        .toUpperCase()
                                    : '?',

                                style:
                                    const TextStyle(
                                  color: AppColors
                                      .pureWhite,
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [

                                  Text(
                                    widget.teacher.name,

                                    style:
                                        const TextStyle(
                                      color: AppColors
                                          .pureWhite,
                                      fontSize: 17,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(
                                      height: 3),

                                  Text(
                                    'Lezione privata',

                                    style: TextStyle(
                                      color: AppColors
                                          .pureWhite
                                          .withOpacity(
                                              0.55),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Materia',

                        style: TextStyle(
                          color:
                              AppColors.pureWhite,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      DropdownButtonFormField<
                          SocialSubject>(
                        value: _selectedSubject,

                        dropdownColor:
                            AppColors
                                .brandNightBlue,

                        style: const TextStyle(
                          color:
                              AppColors.pureWhite,
                        ),

                        decoration:
                            _decoration(
                          label: 'Materia',
                          icon: Icons
                              .menu_book_outlined,
                        ),

                        items: widget.teacher
                            .subjects
                            .map(
                          (subject) {
                            return DropdownMenuItem<
                                SocialSubject>(
                              value: subject,

                              child: Text(
                                subject.name,
                              ),
                            );
                          },
                        ).toList(),

                        onChanged: (value) {
                          setState(() {
                            _selectedSubject =
                                value;
                          });
                        },

                        validator: (value) {
                          if (value == null) {
                            return 'Seleziona una materia';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 22),

                      const Text(
                        'Data',

                        style: TextStyle(
                          color:
                              AppColors.pureWhite,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      _SelectionTile(
                        icon: Icons
                            .calendar_month_outlined,

                        title: _selectedDate == null
                            ? 'Seleziona una data'
                            : '${_selectedDate!.day}/'
                              '${_selectedDate!.month}/'
                              '${_selectedDate!.year}',

                        onTap:
                            _selectDate,
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Orario',

                        style: TextStyle(
                          color:
                              AppColors.pureWhite,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      _SelectionTile(
                        icon:
                            Icons.access_time,

                        title: _selectedTime ==
                                null
                            ? 'Seleziona un orario'
                            : _selectedTime!
                                .format(context),

                        onTap:
                            _selectTime,
                      ),

                      const SizedBox(height: 22),

                      const Text(
                        'Durata',

                        style: TextStyle(
                          color:
                              AppColors.pureWhite,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      DropdownButtonFormField<int>(
                        value: _duration,

                        dropdownColor:
                            AppColors
                                .brandNightBlue,

                        style: const TextStyle(
                          color:
                              AppColors.pureWhite,
                        ),

                        decoration:
                            _decoration(
                          label: 'Durata',
                          icon:
                              Icons.timer_outlined,
                        ),

                        items: const [
                          DropdownMenuItem(
                            value: 30,
                            child:
                                Text('30 minuti'),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child:
                                Text('60 minuti'),
                          ),
                          DropdownMenuItem(
                            value: 90,
                            child:
                                Text('90 minuti'),
                          ),
                          DropdownMenuItem(
                            value: 120,
                            child:
                                Text('120 minuti'),
                          ),
                        ],

                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _duration = value;
                          });
                        },
                      ),

                      const SizedBox(height: 22),

                      TextFormField(
                        controller:
                            _messageController,

                        maxLines: 5,

                        style:
                            const TextStyle(
                          color:
                              AppColors.pureWhite,
                        ),

                        decoration:
                            _decoration(
                          label:
                              'Messaggio',
                          hint:
                              'Spiega al docente di cosa hai bisogno...',
                          icon:
                              Icons
                                  .message_outlined,
                        ),

                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Inserisci un messaggio';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        height: 54,

                        child:
                            ElevatedButton.icon(
                          onPressed:
                              _sendRequest,

                          icon: const Icon(
                            Icons.send_rounded,
                          ),

                          label: const Text(
                            'Invia richiesta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors
                                    .teacherIndigo,

                            foregroundColor:
                                AppColors
                                    .pureWhite,

                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      16),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,

      labelStyle: TextStyle(
        color:
            AppColors.pureWhite.withOpacity(0.60),
      ),

      hintStyle: TextStyle(
        color:
            AppColors.pureWhite.withOpacity(0.30),
      ),

      prefixIcon: Icon(
        icon,
        color: AppColors.skyBlue,
      ),

      filled: true,

      fillColor:
          AppColors.darkElegance,

      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),

        borderSide:
            BorderSide.none,
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SelectionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      borderRadius:
          BorderRadius.circular(14),

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: AppColors.darkElegance,

          borderRadius:
              BorderRadius.circular(14),

          border: Border.all(
            color:
                AppColors.skyBlue.withOpacity(
              0.15,
            ),
          ),
        ),

        child: Row(
          children: [

            Icon(
              icon,
              color: AppColors.skyBlue,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,

                style: TextStyle(
                  color: AppColors.pureWhite
                      .withOpacity(0.80),
                  fontSize: 14,
                ),
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.skyBlue,
            ),
          ],
        ),
      ),
    );
  }
}