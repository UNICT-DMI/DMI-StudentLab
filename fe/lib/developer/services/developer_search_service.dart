import '../models/developer_models.dart';

class DeveloperSearchService {
  final List<DeveloperFileDoc> files;
  final List<DeveloperFlowDoc> flows;

  const DeveloperSearchService({
    required this.files,
    required this.flows,
  });

  List<DeveloperSearchResult> search(
    String rawQuery,
  ) {
    final String query =
        _normalize(rawQuery);

    if (query.isEmpty) {
      return const [];
    }

    final Set<String> tokens = query
        .split(' ')
        .where(
          (String e) => e.length > 1,
        )
        .toSet();

    final List<DeveloperSearchResult> results =
        <DeveloperSearchResult>[];

    for (final DeveloperFileDoc file in files) {
      final String fileText = _normalize(
        '${file.path} ${file.layer} ${file.module} '
        '${file.description} ${file.importance} '
        '${file.flows.join(' ')} '
        '${file.securityNotes.join(' ')}',
      );

      final double fileScore =
          _score(
        fileText,
        query,
        tokens,
      );

      if (fileScore > 0) {
        results.add(
          DeveloperSearchResult(
            kind: 'file',
            title: file.name.isEmpty
                ? file.path.split('/').last
                : file.name,
            subtitle:
                '${file.layer} · ${file.module}',
            path: file.path,
            score: fileScore,
            reasons: _reasons(
              fileText,
              query,
              tokens,
            ),
          ),
        );
      }

      for (final DeveloperFunctionDoc fn
          in file.functions) {
        final String fnText = _normalize(
          '${fn.name} ${fn.signature} '
          '${fn.description} ${fn.calls.join(' ')} '
          '${fn.calledBy.join(' ')} '
          '${fn.flows.join(' ')} '
          '${fn.security.join(' ')} '
          '${file.path}',
        );

        final double score =
            _score(
              fnText,
              query,
              tokens,
            ) +
            _intentBoost(
              query,
              fnText,
            );

        if (score > 0) {
          results.add(
            DeveloperSearchResult(
              kind: 'function',
              title: '${fn.name}()',
              subtitle:
                  '${file.path} · ${fn.description}',
              path: file.path,
              functionName: fn.name,
              score: score,
              reasons: _reasons(
                fnText,
                query,
                tokens,
              ),
            ),
          );
        }
      }
    }

    for (final DeveloperFlowDoc flow in flows) {
      if (flow.steps.isEmpty) {
        continue;
      }

      final String text = _normalize(
        '${flow.name} ${flow.description} '
        '${flow.steps.map(
          (DeveloperFlowStep e) =>
              '${e.title} ${e.file} ${e.function ?? ''}',
        ).join(' ')}',
      );

      final double score =
          _score(
            text,
            query,
            tokens,
          ) +
          (
            query.contains('flusso')
                ? 1.5
                : 0
          );

      if (score > 0) {
        final DeveloperFlowStep first =
            flow.steps.first;

        results.add(
          DeveloperSearchResult(
            kind: 'flow',
            title: 'Flow: ${flow.name}',
            subtitle: flow.description,
            path: first.file,
            functionName: first.function,
            score: score,
            reasons: const [
              'flusso applicativo correlato',
            ],
          ),
        );
      }
    }

    results.sort(
      (
        DeveloperSearchResult a,
        DeveloperSearchResult b,
      ) =>
          b.score.compareTo(a.score),
    );

    return results.take(30).toList();
  }

  double _score(
    String text,
    String fullQuery,
    Set<String> tokens,
  ) {
    double score = 0;

    if (text.contains(fullQuery)) {
      score += 6;
    }

    for (final String token in tokens) {
      if (text.contains(token)) {
        score += token.length > 6
            ? 1.4
            : 0.8;
      }
    }

    return score;
  }

  double _intentBoost(
    String query,
    String text,
  ) {
    double boost = 0;

    if ((query.contains('docente') ||
            query.contains('teacher')) &&
        text.contains('teacher')) {
      boost += 2;
    }

    if ((query.contains('verificat') ||
            query.contains('verifica')) &&
        text.contains('verif')) {
      boost += 2;
    }

    if (query.contains('login') &&
        text.contains('login')) {
      boost += 3;
    }

    if ((query.contains('sicurezza') ||
            query.contains('security')) &&
        text.contains('security')) {
      boost += 1.5;
    }

    if ((query.contains('password') ||
            query.contains('bcrypt')) &&
        text.contains('password')) {
      boost += 2;
    }

    return boost;
  }

  List<String> _reasons(
    String text,
    String query,
    Set<String> tokens,
  ) {
    final List<String> reasons =
        <String>[];

    if (text.contains(query)) {
      reasons.add(
        'corrispondenza diretta',
      );
    }

    final List<String> hits = tokens
        .where(
          (
            String token,
          ) =>
              text.contains(token),
        )
        .take(3)
        .toList();

    if (hits.isNotEmpty) {
      reasons.add(
        'termini: ${hits.join(', ')}',
      );
    }

    return reasons;
  }

  String _normalize(
    String value,
  ) {
    return value
        .toLowerCase()
        .replaceAll(
          RegExp(
            r'[^a-z0-9_/.àèéìòù ]',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }
}
