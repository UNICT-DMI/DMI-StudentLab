import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';
import 'package:fe/quiz/exercises/widgets/exercise_view.dart';

// ======================================================================= diagramma
/// "Tocca sul diagramma": un diagramma disegnato (nodi e collegamenti) oppure
/// un'immagine caricata dal docente. Con l'immagine si manda il punto toccato:
/// le zone corrette le conosce solo il server.
class DiagrammaView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseScope scope;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const DiagrammaView({super.key, required this.item, required this.scope, required this.onChanged, this.result,
      this.locked = false, this.initial});

  @override
  State<DiagrammaView> createState() => _DiagrammaViewState();
}

class _DiagrammaViewState extends State<DiagrammaView> {
  late final Set<String> _ids = asStringList(widget.initial?['ids']).toSet();
  late final List<Offset> _points = asMapList(widget.initial?['points'])
      .map((Map<String, dynamic> p) => Offset((p['x'] as num?)?.toDouble() ?? 0, (p['y'] as num?)?.toDouble() ?? 0))
      .toList();

  bool get _multiple => widget.item.data['multiple'] == true;
  Map<String, dynamic>? get _scene => widget.item.data['scene'] is Map ? asMap(widget.item.data['scene']) : null;

  void _emit() {
    if (_scene != null) {
      widget.onChanged(<String, dynamic>{'ids': _ids.toList()}, _ids.isNotEmpty);
    } else {
      widget.onChanged(<String, dynamic>{
        'points': _points.map((Offset o) => <String, double>{'x': o.dx, 'y': o.dy}).toList(),
      }, _points.isNotEmpty);
    }
  }

  void _tapNode(String id) {
    if (widget.locked) return;
    setState(() {
      if (_multiple) {
        _ids.contains(id) ? _ids.remove(id) : _ids.add(id);
      } else {
        _ids
          ..clear()
          ..add(id);
      }
    });
    _emit();
  }

  void _tapImage(Offset relative) {
    if (widget.locked) return;
    setState(() {
      if (!_multiple) _points.clear();
      if (_points.length < 10) _points.add(relative);
    });
    _emit();
  }

  IconData _icon(String name, String shape) => switch (name) {
        'computer' => Icons.computer_rounded,
        'switch' => Icons.device_hub_rounded,
        'router' => Icons.router_rounded,
        'cloud' => Icons.cloud_outlined,
        'server' => Icons.dns_rounded,
        'phone' => Icons.smartphone_rounded,
        'database' => Icons.storage_rounded,
        'firewall' => Icons.security_rounded,
        'cpu' => Icons.memory_rounded,
        _ => shape == 'cloud' ? Icons.cloud_outlined : Icons.crop_square_rounded,
      };

  Widget _sceneView(BuildContext context, Map<String, dynamic> scene) {
    final p = context.palette;
    final List<Map<String, dynamic>> nodes = asMapList(scene['nodes']);
    final List<Map<String, dynamic>> edges = asMapList(scene['edges']);
    final double ratio = (scene['ratio'] as num?)?.toDouble() ?? 1.6;
    final Set<String> correct = asStringList(widget.result?.solution?['correct']).toSet();
    return AspectRatio(
      aspectRatio: ratio.clamp(0.6, 3.0),
      child: LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
        Offset at(Map<String, dynamic> n) =>
            Offset(((n['x'] as num?)?.toDouble() ?? 0) * box.maxWidth, ((n['y'] as num?)?.toDouble() ?? 0) * box.maxHeight);
        final Map<String, Map<String, dynamic>> byId = {for (final n in nodes) n['id'].toString(): n};
        const double w = 88, h = 64;
        return Stack(children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _EdgePainter(
                lines: <(Offset, Offset, String)>[
                  for (final Map<String, dynamic> e in edges)
                    if (byId[e['from']] != null && byId[e['to']] != null)
                      (at(byId[e['from']]!), at(byId[e['to']]!), e['label']?.toString() ?? ''),
                ],
                color: p.pureWhite.withValues(alpha: 0.35),
                textColor: p.pureWhite.withValues(alpha: 0.7),
              ),
            ),
          ),
          for (final Map<String, dynamic> n in nodes)
            Builder(builder: (BuildContext context) {
              final String id = n['id'].toString();
              final Offset c = at(n);
              final bool chosen = _ids.contains(id);
              final bool? ok = widget.result == null ? null : (correct.contains(id) ? true : (chosen ? false : null));
              final Color border = ok == true ? p.adminGreen : ok == false ? p.adminCoral : (chosen ? p.skyBlue : p.pureWhite.withValues(alpha: 0.25));
              return Positioned(
                left: (c.dx - w / 2).clamp(0.0, math.max(0.0, box.maxWidth - w)),
                top: (c.dy - h / 2).clamp(0.0, math.max(0.0, box.maxHeight - h)),
                width: w,
                height: h,
                child: Semantics(
                  button: true,
                  selected: chosen,
                  label: n['label']?.toString(),
                  child: Material(
                    color: chosen ? p.skyBlue.withValues(alpha: 0.18) : p.eleganceMidnight,
                    shape: n['shape'] == 'circle'
                        ? StadiumBorder(side: BorderSide(color: border, width: chosen || ok != null ? 2 : 1))
                        : RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(n['shape'] == 'cloud' ? 28 : 12),
                            side: BorderSide(color: border, width: chosen || ok != null ? 2 : 1)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: widget.locked ? null : () => _tapNode(id),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                        Icon(_icon(n['icon']?.toString() ?? '', n['shape']?.toString() ?? ''), size: 22,
                            color: ok == true ? p.adminGreen : (chosen ? p.skyBlue : p.pureWhite.withValues(alpha: 0.85))),
                        const SizedBox(height: 2),
                        Text(n['label']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.pureWhite, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              );
            }),
        ]);
      }),
    );
  }

  Widget _imageView(BuildContext context, String attachmentId) {
    final p = context.palette;
    final Uri uri = ExerciseApiService().exerciseAttachmentUri(
        widget.scope.department, widget.scope.course, widget.scope.subject, widget.item.id, attachmentId);
    final List<Map<String, dynamic>> regions = asMapList(widget.result?.solution?['regions']);
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (TapUpDetails details) {
          final RenderBox? render = context.findRenderObject() as RenderBox?;
          if (render == null || render.size.isEmpty) return;
          final Offset local = render.globalToLocal(details.globalPosition);
          _tapImage(Offset((local.dx / render.size.width).clamp(0.0, 1.0), (local.dy / render.size.height).clamp(0.0, 1.0)));
        },
        child: Stack(children: <Widget>[
          Image.network(uri.toString(), width: box.maxWidth, fit: BoxFit.fitWidth,
              errorBuilder: (BuildContext context, Object e, StackTrace? s) => SizedBox(
                    height: 120,
                    child: Center(child: Text('Immagine non disponibile.', style: SlText.muted(p))),
                  )),
          Positioned.fill(
            child: LayoutBuilder(builder: (BuildContext context, BoxConstraints inner) {
              return Stack(children: <Widget>[
                for (final Map<String, dynamic> r in regions)
                  Positioned(
                    left: ((r['x'] as num?)?.toDouble() ?? 0) * inner.maxWidth,
                    top: ((r['y'] as num?)?.toDouble() ?? 0) * inner.maxHeight,
                    width: ((r['w'] as num?)?.toDouble() ?? 0) * inner.maxWidth,
                    height: ((r['h'] as num?)?.toDouble() ?? 0) * inner.maxHeight,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: p.adminGreen, width: 2),
                          color: p.adminGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                for (final Offset point in _points)
                  Positioned(
                    left: point.dx * inner.maxWidth - 12,
                    top: point.dy * inner.maxHeight - 12,
                    child: IgnorePointer(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: p.pureWhite, width: 2),
                          color: p.skyBlue.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
              ]);
            }),
          ),
        ]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Map<String, dynamic>? scene = _scene;
    final String? imageId = widget.item.data['image_attachment_id']?.toString();
    final Map<String, dynamic> notes = asMap(widget.result?.feedback['notes']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(
          widget.locked
              ? ''
              : scene != null
                  ? (_multiple ? 'Tocca tutti gli elementi giusti.' : 'Tocca l’elemento giusto.')
                  : 'Tocca il punto giusto sull’immagine. Tocca l’immagine allegata sopra per ingrandirla.',
          style: SlText.muted(p).copyWith(fontSize: 12)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: p.darkElegance,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
        ),
        child: scene != null
            ? _sceneView(context, scene)
            : (imageId != null && imageId.isNotEmpty)
                ? _imageView(context, imageId)
                : Text('Diagramma non disponibile.', style: SlText.muted(p)),
      ),
      for (final MapEntry<String, dynamic> note in notes.entries)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('${note.value}', style: SlText.body(p).copyWith(fontSize: 13)),
        ),
    ]);
  }
}

class _EdgePainter extends CustomPainter {
  final List<(Offset, Offset, String)> lines;
  final Color color;
  final Color textColor;
  final List<Color>? colors;

  _EdgePainter({required this.lines, required this.color, required this.textColor, this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < lines.length; i++) {
      final (Offset a, Offset b, String label) = lines[i];
      final Paint paint = Paint()
        ..color = colors != null && i < colors!.length ? colors![i] : color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(a, b, paint);
      if (label.isNotEmpty) {
        final TextPainter text = TextPainter(
          text: TextSpan(text: label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr,
        )..layout();
        final Offset middle = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        final Rect back = Rect.fromCenter(center: middle, width: text.width + 10, height: text.height + 4);
        canvas.drawRRect(RRect.fromRectAndRadius(back, const Radius.circular(6)), Paint()..color = const Color(0xFF0C0F1A));
        text.paint(canvas, middle - Offset(text.width / 2, text.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => true;
}

// ======================================================================= grafo
/// Grafo interattivo: lo studente tocca i nodi nell'ordine della visita
/// (Dijkstra, BFS, DFS). Le distanze provvisorie mostrate sono quelle che
/// scriverebbe a mano; la correzione (pari merito inclusi) è del server.
class GrafoView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const GrafoView({super.key, required this.item, required this.onChanged, this.result, this.locked = false, this.initial});

  @override
  State<GrafoView> createState() => _GrafoViewState();
}

class _GrafoViewState extends State<GrafoView> {
  late final List<String> _order = asStringList(widget.initial?['order']);

  String get _task => widget.item.data['task']?.toString() ?? 'dijkstra';
  List<Map<String, dynamic>> get _nodes => asMapList(widget.item.data['nodes']);
  List<Map<String, dynamic>> get _edges => asMapList(widget.item.data['edges']);
  String get _source => widget.item.data['source']?.toString() ?? (_nodes.isEmpty ? '' : _nodes.first['id'].toString());
  bool get _directed => widget.item.data['directed'] == true;

  Map<String, List<(String, int)>> get _adjacency {
    final Map<String, List<(String, int)>> result = {for (final n in _nodes) n['id'].toString(): <(String, int)>[]};
    for (final Map<String, dynamic> e in _edges) {
      final String a = e['from'].toString(), b = e['to'].toString();
      final int w = int.tryParse('${e['w'] ?? 1}') ?? 1;
      result[a]?.add((b, w));
      if (!_directed) result[b]?.add((a, w));
    }
    return result;
  }

  int get _reachable {
    final Map<String, List<(String, int)>> adj = _adjacency;
    final Set<String> seen = <String>{_source};
    final List<String> todo = <String>[_source];
    while (todo.isNotEmpty) {
      for (final (String other, int _) in adj[todo.removeLast()] ?? const <(String, int)>[]) {
        if (seen.add(other)) todo.add(other);
      }
    }
    return seen.length;
  }

  /// Distanze provvisorie dopo i nodi già chiusi (solo per Dijkstra).
  Map<String, int?> get _distances {
    final Map<String, List<(String, int)>> adj = _adjacency;
    final Map<String, int?> dist = {for (final n in _nodes) n['id'].toString(): null};
    dist[_source] = 0;
    final Set<String> closed = <String>{};
    for (final String node in _order) {
      final int? d = dist[node];
      if (d == null) break;
      closed.add(node);
      for (final (String other, int w) in adj[node] ?? const <(String, int)>[]) {
        if (closed.contains(other)) continue;
        final int? current = dist[other];
        if (current == null || d + w < current) dist[other] = d + w;
      }
    }
    return dist;
  }

  void _emit() => widget.onChanged(<String, dynamic>{'order': List<String>.from(_order)}, _order.length == _reachable);

  void _tap(String id) {
    if (widget.locked || _order.contains(id)) return;
    setState(() => _order.add(id));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Map<String, int?> dist = _task == 'dijkstra' ? _distances : const <String, int?>{};
    final Map<String, String> labels = {for (final n in _nodes) n['id'].toString(): n['label']?.toString() ?? n['id'].toString()};
    final int? validSteps = int.tryParse('${widget.result?.feedback['valid_steps'] ?? ''}');
    final List<String> solution = asStringList(widget.result?.solution?['order']);
    final Map<String, dynamic> solutionDist = asMap(widget.result?.solution?['distances']);
    final String taskLabel = switch (_task) {
      'bfs' => 'Visita in ampiezza (BFS)',
      'dfs' => 'Visita in profondità (DFS)',
      _ => 'Dijkstra',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Row(children: <Widget>[
        SlStatusBadge(label: taskLabel, tone: SlTone.info),
        const SizedBox(width: 6),
        SlStatusBadge(label: 'Partenza: ${labels[_source] ?? _source}'),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: p.darkElegance,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
        ),
        child: AspectRatio(
          aspectRatio: 1.5,
          child: LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
            const double size = 48;
            final double padX = size / 2 + 6, padY = size / 2 + 14;
            Offset at(Map<String, dynamic> n) => Offset(
                  padX + ((n['x'] as num?)?.toDouble() ?? 0) * (box.maxWidth - 2 * padX),
                  padY + ((n['y'] as num?)?.toDouble() ?? 0) * (box.maxHeight - 2 * padY),
                );
            final Map<String, Map<String, dynamic>> byId = {for (final n in _nodes) n['id'].toString(): n};
            return Stack(clipBehavior: Clip.none, children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _EdgePainter(
                    lines: <(Offset, Offset, String)>[
                      for (final Map<String, dynamic> e in _edges)
                        if (byId[e['from'].toString()] != null && byId[e['to'].toString()] != null)
                          (at(byId[e['from'].toString()]!), at(byId[e['to'].toString()]!), _task == 'dijkstra' ? '${e['w']}' : ''),
                    ],
                    color: p.pureWhite.withValues(alpha: 0.30),
                    textColor: p.adminAmber,
                  ),
                ),
              ),
              for (final Map<String, dynamic> n in _nodes)
                Builder(builder: (BuildContext context) {
                  final String id = n['id'].toString();
                  final Offset c = at(n);
                  final int position = _order.indexOf(id);
                  final bool visited = position >= 0;
                  final bool? ok = validSteps == null || !visited ? null : position < validSteps;
                  final Color ring = ok == true
                      ? p.adminGreen
                      : ok == false
                          ? p.adminCoral
                          : (visited ? p.skyBlue : p.pureWhite.withValues(alpha: 0.4));
                  return Positioned(
                    left: c.dx - size / 2,
                    top: c.dy - size / 2,
                    child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                      Semantics(
                        button: true,
                        label: 'Nodo ${labels[id]}${visited ? ', visitato per ${position + 1}°' : ''}',
                        child: InkResponse(
                          onTap: widget.locked ? null : () => _tap(id),
                          radius: size / 2 + 6,
                          child: Container(
                            width: size,
                            height: size,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: visited ? ring.withValues(alpha: 0.22) : p.eleganceMidnight,
                              border: Border.all(color: ring, width: visited ? 2.5 : 1.5),
                            ),
                            child: Text(labels[id] ?? id,
                                style: TextStyle(color: p.pureWhite, fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      if (_task == 'dijkstra')
                        Text(dist[id] == null ? '∞' : '${dist[id]}',
                            style: TextStyle(color: visited ? p.skyBlue : p.pureWhite.withValues(alpha: 0.6), fontSize: 11,
                                fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                    ]),
                  );
                }),
            ]);
          }),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: <Widget>[
        Expanded(
          child: Text(
            _order.isEmpty
                ? 'Tocca i nodi nell’ordine in cui li visiti.'
                : 'Visitati: ${_order.map((String id) => labels[id] ?? id).join(' → ')}',
            style: SlText.body(p).copyWith(fontSize: 13),
          ),
        ),
        if (!widget.locked && _order.isNotEmpty) ...<Widget>[
          IconButton(
            tooltip: 'Annulla l’ultimo',
            onPressed: () {
              setState(() => _order.removeLast());
              _emit();
            },
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Ricomincia',
            onPressed: () {
              setState(_order.clear);
              _emit();
            },
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ]),
      if (widget.result != null && solution.isNotEmpty) ...<Widget>[
        const SizedBox(height: 6),
        Text(
          'Passi giusti: ${validSteps ?? 0} su ${widget.result!.feedback['total'] ?? solution.length}. '
          'Un ordine corretto: ${solution.map((String id) => labels[id] ?? id).join(' → ')}',
          style: TextStyle(color: widget.result!.isCorrect ? p.adminGreen : p.adminAmber, fontSize: 13),
        ),
        if (solutionDist.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Distanze finali: ${solution.map((String id) => '${labels[id]} = ${solutionDist[id] ?? '∞'}').join(', ')}',
              style: SlText.muted(p).copyWith(fontSize: 12),
            ),
          ),
      ],
    ]);
  }
}
