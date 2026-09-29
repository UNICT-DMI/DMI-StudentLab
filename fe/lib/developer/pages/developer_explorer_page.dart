import 'package:flutter/material.dart';

import 'package:fe/theme/nightTheme.dart';
import '../data/developer_api_repository.dart';
import '../models/developer_models.dart';
import '../theme/developer_ui_style.dart';
import '../widgets/developer_tree_view.dart';
import 'developer_file_detail_page.dart';

class DeveloperExplorerPage
    extends StatefulWidget {
  const DeveloperExplorerPage({
    super.key,
  });

  @override
  State<DeveloperExplorerPage> createState() =>
      _DeveloperExplorerPageState();
}

class _DeveloperExplorerPageState
    extends State<DeveloperExplorerPage> {
  final DeveloperApiRepository _repository =
      const DeveloperApiRepository();

  DeveloperTreeNode? _tree;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final DeveloperTreeNode tree =
          await _repository.getTree();

      if (!mounted) {
        return;
      }

      setState(() {
        _tree = tree;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Non è stato possibile caricare il repository. Riprova tra poco.';
      });
    }
  }

  Future<void> _openNode(
    DeveloperTreeNode node,
  ) async {
    if (node.type !=
        DeveloperNodeType.file) {
      return;
    }

    try {
      final DeveloperFileDoc file =
          await _repository.getFile(
        node.path,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              DeveloperFileDetailPage(
            file: file,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('File non disponibile'),
          content: const Text(
            'Non è stato possibile aprire il file. Riprova tra poco.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Chiudi'),
            ),
          ],
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
            Text('Repository Explorer'),
        actions: [
          IconButton(
            onPressed:
                _loading ? null : _load,
            tooltip: 'Aggiorna',
            icon:
                const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  DeveloperUiStyle.maxContentWidth,
            ),
            child: _loading
                ? Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          AppColors.skyBlue,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(
                            24,
                          ),
                          child: Text(
                            _error!,
                            style: DeveloperUiStyle.bodyMuted,
                          ),
                        ),
                      )
                    : ListView(
                        padding:
                            const EdgeInsets.all(
                          20,
                        ),
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.all(
                              16,
                            ),
                            decoration:
                                DeveloperUiStyle
                                    .panelDecoration(),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
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
                                  child:
                                      Icon(
                                    Icons
                                        .account_tree_outlined,
                                    color: AppColors
                                        .skyBlue,
                                    size: 22,
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
                                        'Albero repository',
                                        style:
                                            DeveloperUiStyle
                                                .bodyStrong,
                                      ),
                                      const SizedBox(
                                        height: 4,
                                      ),
                                      Text(
                                        'Apri una cartella o un file per '
                                        'visualizzare architettura, funzioni e sicurezza.',
                                        style:
                                            DeveloperUiStyle
                                                .bodyMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          Container(
                            padding:
                                const EdgeInsets.all(
                              12,
                            ),
                            decoration:
                                DeveloperUiStyle
                                    .panelDecoration(),
                            child:
                                DeveloperTreeView(
                              root: _tree!,
                              onNodeTap:
                                  _openNode,
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
