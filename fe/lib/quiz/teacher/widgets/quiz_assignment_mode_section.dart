import 'package:flutter/material.dart';
import 'package:fe/theme/nightTheme.dart';

class QuizAssignmentModeSection extends StatelessWidget {
  final String executionMode;
  final String externalActivityPolicy;
  final ValueChanged<String> onExecutionModeChanged;
  final ValueChanged<String> onExternalActivityPolicyChanged;

  const QuizAssignmentModeSection({
    super.key,
    required this.executionMode,
    required this.externalActivityPolicy,
    required this.onExecutionModeChanged,
    required this.onExternalActivityPolicyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool controlled = executionMode == 'simulation';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modalità di svolgimento',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Scegli come deve essere svolto il quiz assegnato.',
          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: 'practice',
              icon: Icon(Icons.school_outlined),
              label: Text('Esercitazione'),
            ),
            ButtonSegment<String>(
              value: 'simulation',
              icon: Icon(Icons.shield_outlined),
              label: Text('Quiz controllato'),
            ),
          ],
          selected: {executionMode},
          onSelectionChanged: (value) => onExecutionModeChanged(value.first),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: controlled
              ? _ControlledQuizOptions(
                  externalActivityPolicy: externalActivityPolicy,
                  onChanged: onExternalActivityPolicyChanged,
                )
              : const _PracticeInfo(),
        ),
      ],
    );
  }
}

class _PracticeInfo extends StatelessWidget {
  const _PracticeInfo();
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('practice'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Nell’esercitazione lo studente può interrompere il quiz e riprenderlo successivamente. L’uscita dall’app non comporta la consegna automatica.',
        style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.45),
      ),
    );
  }
}

class _ControlledQuizOptions extends StatelessWidget {
  final String externalActivityPolicy;
  final ValueChanged<String> onChanged;
  const _ControlledQuizOptions({
    required this.externalActivityPolicy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('controlled'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ambiente del quiz controllato',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Il tentativo ha sempre il tempo massimo definito dal docente. Se lo studente consegna o il tempo termina, il quiz viene chiuso definitivamente.',
            style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 12),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'disabled',
            groupValue: externalActivityPolicy,
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            title: const Text(
              'Dispositivo personale',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'Il tempo limite resta obbligatorio. StudentLab non presume di poter controllare le altre app o tutto il traffico Internet del dispositivo personale.',
              style: TextStyle(fontSize: 11, height: 1.35),
            ),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'structured_devices',
            groupValue: externalActivityPolicy,
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            title: const Text(
              'Dispositivo strutturato dell’istituzione',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'Il quiz è pensato per un dispositivo predisposto dall’istituzione. Se StudentLab rileva un’uscita dall’app, una perdita del focus/ambiente controllato o un’altra attività esterna non prevista, registra l’evento e consegna immediatamente il tentativo, associando la causa al quiz inviato.',
              style: TextStyle(fontSize: 11, height: 1.35),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'StudentLab non blocca preventivamente l’attività esterna: registra gli eventi che riesce a rilevare durante la prova. Per identificare anche attività o traffico esterno non visibili direttamente all’app, il dispositivo o la rete dell’istituzione devono esporre tali eventi tramite il proprio ambiente gestito. Quando una violazione prevista viene rilevata, il quiz viene consegnato immediatamente e la causa viene registrata.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      height: 1.4,
                    ),
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
