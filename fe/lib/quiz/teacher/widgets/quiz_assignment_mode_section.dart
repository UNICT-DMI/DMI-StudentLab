import 'package:flutter/material.dart';

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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Scegli come deve essere svolto il quiz assegnato.',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            height: 1.4,
          ),
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
          onSelectionChanged: (value) {
            onExecutionModeChanged(value.first);
          },
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
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Nell’esercitazione lo studente può interrompere il quiz e riprenderlo successivamente. L’uscita dall’app non comporta la consegna automatica.',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 12,
          height: 1.45,
        ),
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
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comportamento del quiz controllato',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Se lo studente esce volontariamente dalla pagina, porta l’app in background o abbandona la sessione, il tentativo viene consegnato definitivamente con le risposte presenti in quel momento.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Controllo attività esterna',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Su smartphone personali StudentLab non può controllare in modo affidabile le richieste HTTP effettuate da altre app o sapere se lo studente apre un browser. Questa verifica va quindi lasciata disattivata sui dispositivi mobili degli studenti.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'disabled',
            groupValue: externalActivityPolicy,
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            title: const Text(
              'Disattivato',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'Da usare su smartphone o dispositivi personali. Restano attivi la consegna su uscita, background e termine del tempo.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
              ),
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
              'Dispositivo strutturato dell’istituto',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'Da usare quando il quiz viene svolto su dispositivi predisposti e gestiti dall’istituto. L’ambiente può applicare controlli aggiuntivi su perdita di focus, cambio finestra e attività di rete secondo la configurazione dell’istituto.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nota: StudentLab registra la scelta del docente e applica i controlli disponibili nell’app. Il monitoraggio completo delle richieste di rete richiede che il dispositivo o la rete dell’istituto siano configurati per supportarlo.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}