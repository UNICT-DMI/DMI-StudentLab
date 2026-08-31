import '../models/developer_models.dart';

class DeveloperApiMapper {
  const DeveloperApiMapper._();

  static DeveloperRiskLevel risk(
    dynamic value,
  ) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'low':
        return DeveloperRiskLevel.low;
      case 'high':
        return DeveloperRiskLevel.high;
      case 'critical':
        return DeveloperRiskLevel.critical;
      default:
        return DeveloperRiskLevel.medium;
    }
  }

  static DeveloperSourceType sourceType(
    dynamic value,
  ) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'remote':
        return DeveloperSourceType.remote;
      case 'synced':
        return DeveloperSourceType.synced;
      default:
        return DeveloperSourceType.local;
    }
  }

  static DeveloperRelationType relationType(
    dynamic value,
  ) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'calls':
        return DeveloperRelationType.calls;
      case 'called_by':
      case 'calledby':
        return DeveloperRelationType.calledBy;
      case 'imports':
        return DeveloperRelationType.imports;
      case 'contains':
        return DeveloperRelationType.contains;
      case 'flow':
        return DeveloperRelationType.flow;
      case 'security':
        return DeveloperRelationType.security;
      case 'endpoint':
        return DeveloperRelationType.endpoint;
      default:
        return DeveloperRelationType.unknown;
    }
  }

  static List<String> stringList(
    dynamic value,
  ) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(
          (dynamic item) => item.toString(),
        )
        .toList();
  }

  static DeveloperTreeNode treeNode(
    Map<String, dynamic> json,
  ) {
    final List<DeveloperTreeNode> children =
        (json['children'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (Map child) => treeNode(
                Map<String, dynamic>.from(child),
              ),
            )
            .toList();

    return DeveloperTreeNode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      type: json['type']?.toString() == 'folder'
          ? DeveloperNodeType.folder
          : DeveloperNodeType.file,
      children: children,
      documented: json['documented'] == true,
      outdated: json['outdated'] == true,
      changed: json['changed'] == true,
      securityCritical:
          json['security_critical'] == true,
      functionCount:
          (json['function_count'] as num?)?.toInt(),
    );
  }

  static DeveloperFunctionDoc function(
    Map<String, dynamic> json,
  ) {
    return DeveloperFunctionDoc(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      signature:
          json['signature']?.toString() ?? '',
      description:
          json['description']?.toString() ?? '',
      lineStart:
          (json['line_start'] as num?)?.toInt(),
      lineEnd:
          (json['line_end'] as num?)?.toInt(),
      isAsync: json['is_async'] == true,
      calls: stringList(json['calls']),
      calledBy: stringList(json['called_by']),
      flows: stringList(json['flows']),
      security: stringList(json['security']),
      inputs: stringList(json['inputs']),
      outputs: stringList(json['outputs']),
      risk: risk(json['risk']),
    );
  }

  static DeveloperRelation relation(
    Map<String, dynamic> json,
  ) {
    return DeveloperRelation(
      type: relationType(json['type']),
      label: json['label']?.toString() ?? '',
      targetPath:
          json['target_path']?.toString() ?? '',
      targetFunction:
          json['target_function']?.toString(),
    );
  }

  static DeveloperEndpointArtifact endpoint(
    Map<String, dynamic> json,
  ) {
    return DeveloperEndpointArtifact(
      method:
          json['method']?.toString() ?? '',
      path:
          json['path']?.toString() ?? '',
      functionName:
          json['function_name']?.toString() ?? '',
      lineStart:
          (json['line_start'] as num?)?.toInt(),
      routerName:
          json['router_name']?.toString(),
      dependencies:
          stringList(json['dependencies']),
      responseModel:
          json['response_model']?.toString(),
      securityCritical:
          json['security_critical'] == true,
      confidence:
          json['confidence']?.toString() ??
              'observed',
    );
  }

  static DeveloperModelArtifact modelArtifact(
    Map<String, dynamic> json,
  ) {
    return DeveloperModelArtifact(
      name:
          json['name']?.toString() ?? '',
      tableName:
          json['table_name']?.toString(),
      bases:
          stringList(json['bases']),
      columns:
          stringList(json['columns']),
      relationships:
          stringList(json['relationships']),
      lineStart:
          (json['line_start'] as num?)?.toInt(),
      confidence:
          json['confidence']?.toString() ??
              'observed',
    );
  }

  static DeveloperTestArtifact testArtifact(
    Map<String, dynamic> json,
  ) {
    return DeveloperTestArtifact(
      name:
          json['name']?.toString() ?? '',
      lineStart:
          (json['line_start'] as num?)?.toInt(),
      framework:
          json['framework']?.toString() ??
              'unknown',
      calls:
          stringList(json['calls']),
      targetCandidates:
          stringList(json['target_candidates']),
      confidence:
          json['confidence']?.toString() ??
              'observed',
    );
  }

  static DeveloperFileDoc file(
    Map<String, dynamic> json,
  ) {
    return DeveloperFileDoc(
      id: json['id']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      extension:
          json['extension']?.toString() ?? '',
      language:
          json['language']?.toString() ?? '',
      layer: json['layer']?.toString() ?? '',
      module: json['module']?.toString() ?? '',
      description:
          json['description']?.toString() ?? '',
      importance:
          json['importance']?.toString() ?? '',
      risk: risk(json['risk']),
      sourceType:
          sourceType(json['source_type']),
      documented: json['documented'] == true,
      outdated: json['outdated'] == true,
      changed: json['changed'] == true,
      securityCritical:
          json['security_critical'] == true,
      sizeBytes:
          (json['size_bytes'] as num?)?.toInt() ?? 0,
      modifiedAt:
          (json['modified_at'] as num?)?.toDouble(),
      contentHash:
          json['content_hash']?.toString() ?? '',
      functions:
          (json['functions'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => function(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      imports: stringList(json['imports']),
      relations:
          (json['relations'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => relation(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      flows: stringList(json['flows']),
      securityNotes:
          stringList(json['security_notes']),
      endpoints:
          (json['endpoints'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => endpoint(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      models:
          (json['models'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => modelArtifact(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      tests:
          (json['tests'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => testArtifact(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
    );
  }

  static DeveloperRepositoryStatus status(
    Map<String, dynamic> json,
  ) {
    return DeveloperRepositoryStatus(
      repositoryName:
          json['repository_name']?.toString() ?? '',
      repositoryRoot:
          json['repository_root']?.toString() ?? '',
      sourceType:
          sourceType(json['source_type']),
      gitAvailable:
          json['git_available'] == true,
      branch: json['branch']?.toString(),
      headCommit:
          json['head_commit']?.toString(),
      filesIndexed:
          (json['files_indexed'] as num?)?.toInt() ??
              0,
      functionsIndexed:
          (json['functions_indexed'] as num?)
                  ?.toInt() ??
              0,
      documentedFiles:
          (json['documented_files'] as num?)
                  ?.toInt() ??
              0,
      outdatedFiles:
          (json['outdated_files'] as num?)?.toInt() ??
              0,
      changedFiles:
          (json['changed_files'] as num?)?.toInt() ??
              0,
      securityCriticalFiles:
          (json['security_critical_files'] as num?)
                  ?.toInt() ??
              0,
    );
  }

  static DeveloperSearchResult searchResult(
    Map<String, dynamic> json,
  ) {
    return DeveloperSearchResult(
      kind: json['kind']?.toString() ?? 'file',
      title: json['title']?.toString() ?? '',
      subtitle:
          json['subtitle']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      functionName:
          json['function_name']?.toString(),
      score:
          (json['score'] as num?)?.toDouble() ?? 0,
      reasons: stringList(json['reasons']),
    );
  }

  static DeveloperFlowStep flowStep(
    Map<String, dynamic> json,
  ) {
    return DeveloperFlowStep(
      order:
          (json['order'] as num?)?.toInt() ?? 0,
      title:
          json['title']?.toString() ?? '',
      file:
          json['file']?.toString() ?? '',
      function:
          json['function']?.toString(),
      layer:
          json['layer']?.toString() ?? '',
      relation:
          json['relation']?.toString() ?? 'NEXT',
      context:
          json['context']?.toString() ?? '',
      securityCritical:
          json['security_critical'] == true,
    );
  }

  static DeveloperFlowDoc flow(
    Map<String, dynamic> json,
  ) {
    return DeveloperFlowDoc(
      id: json['id']?.toString() ?? '',
      name:
          json['name']?.toString() ?? '',
      description:
          json['description']?.toString() ?? '',
      risk: risk(json['risk']),
      steps:
          (json['steps'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => flowStep(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
    );
  }

  static DeveloperImpactFunctionRef
      impactFunctionRef(
    Map<String, dynamic> json,
  ) {
    return DeveloperImpactFunctionRef(
      file:
          json['file']?.toString() ?? '',
      function:
          json['function']?.toString() ?? '',
      layer:
          json['layer']?.toString() ?? '',
      securityCritical:
          json['security_critical'] == true,
      risk: risk(json['risk']),
      depth:
          (json['depth'] as num?)?.toInt(),
    );
  }

  static DeveloperImpactFlow impactFlow(
    Map<String, dynamic> json,
  ) {
    return DeveloperImpactFlow(
      id: json['id']?.toString() ?? '',
      name:
          json['name']?.toString() ?? '',
      risk: risk(json['risk']),
      matchedSteps:
          (json['matched_steps'] as List? ??
                  const [])
              .whereType<num>()
              .map(
                (num value) =>
                    value.toInt(),
              )
              .toList(),
    );
  }

  static DeveloperImpactEndpoint
      impactEndpoint(
    Map<String, dynamic> json,
  ) {
    return DeveloperImpactEndpoint(
      file:
          json['file']?.toString() ?? '',
      function:
          json['function']?.toString() ?? '',
      method:
          json['method']?.toString(),
      path:
          json['path']?.toString(),
      confidence:
          json['confidence']?.toString() ??
              'inferred',
    );
  }

  static DeveloperImpactModelRef
      impactModel(
    Map<String, dynamic> json,
  ) {
    return DeveloperImpactModelRef(
      file:
          json['file']?.toString() ?? '',
      name:
          json['name']?.toString() ?? '',
      layer:
          json['layer']?.toString() ?? '',
      confidence:
          json['confidence']?.toString() ??
              'observed',
    );
  }

  static DeveloperImpactTestRef
      impactTest(
    Map<String, dynamic> json,
  ) {
    return DeveloperImpactTestRef(
      file:
          json['file']?.toString() ?? '',
      confidence:
          json['confidence']?.toString() ??
              'inferred',
      reason:
          json['reason']?.toString() ?? '',
    );
  }

  static DeveloperImpactAnalysis impact(
    Map<String, dynamic> json,
  ) {
    List<DeveloperImpactFunctionRef>
        functionRefs(String key) {
      return (json[key] as List? ?? const [])
          .whereType<Map>()
          .map(
            (Map item) =>
                impactFunctionRef(
              Map<String, dynamic>.from(
                item,
              ),
            ),
          )
          .toList();
    }

    return DeveloperImpactAnalysis(
      path:
          json['path']?.toString() ?? '',
      function:
          json['function']?.toString(),
      risk: risk(json['risk']),
      summary:
          json['summary']?.toString() ?? '',
      semanticAnswer:
          json['semantic_answer']
                  ?.toString() ??
              '',
      directCallers:
          functionRefs('direct_callers'),
      directCallees:
          functionRefs('direct_callees'),
      transitiveCallers:
          functionRefs(
        'transitive_callers',
      ),
      relatedFiles:
          (json['related_files'] as List? ??
                  const [])
              .map(
                (dynamic value) =>
                    value.toString(),
              )
              .toList(),
      flows:
          (json['flows'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => impactFlow(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList(),
      endpoints:
          (json['endpoints'] as List? ??
                  const [])
              .whereType<Map>()
              .map(
                (Map item) =>
                    impactEndpoint(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList(),
      models:
          (json['models'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => impactModel(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList(),
      tests:
          (json['tests'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => impactTest(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList(),
      recommendations:
          (json['recommendations'] as List? ??
                  const [])
              .map(
                (dynamic value) =>
                    value.toString(),
              )
              .toList(),
      securityFlags:
          (json['security_flags'] as List? ??
                  const [])
              .map(
                (dynamic value) =>
                    value.toString(),
              )
              .toList(),
      securityCritical:
          json['security_critical'] == true,
    );
  }

  static DeveloperSourceCode source(
    Map<String, dynamic> json,
  ) {
    return DeveloperSourceCode(
      path:
          json['path']?.toString() ?? '',
      language:
          json['language']?.toString() ?? '',
      symbol:
          json['symbol']?.toString(),
      sourceKind:
          json['source_kind']?.toString() ??
              'file',
      lineStart:
          (json['line_start'] as num?)
                  ?.toInt() ??
              1,
      lineEnd:
          (json['line_end'] as num?)
                  ?.toInt() ??
              1,
      lineCount:
          (json['line_count'] as num?)
                  ?.toInt() ??
              0,
      source:
          json['source']?.toString() ?? '',
      commitSha:
          json['commit_sha']?.toString(),
      contentHash:
          json['content_hash']?.toString() ??
              '',
      repository:
          json['repository']?.toString() ??
              '',
      branch:
          json['branch']?.toString(),
    );
  }

  static DeveloperApiEndpointContract
      apiEndpointContract(
    Map<String, dynamic> json,
  ) {
    return DeveloperApiEndpointContract(
      file:
          json['file']?.toString() ?? '',
      function:
          json['function']?.toString() ?? '',
      method:
          json['method']?.toString(),
      path:
          json['path']?.toString(),
      authDependencies:
          (json['auth_dependencies'] as List? ??
                  const [])
              .map(
                (dynamic value) =>
                    value.toString(),
              )
              .toList(),
      requestSchema:
          json['request_schema']?.toString(),
      responseSchema:
          json['response_schema']?.toString(),
      confidence:
          json['confidence']?.toString() ??
              'unknown',
      securityCritical:
          json['security_critical'] == true,
    );
  }

  static DeveloperFrontendHttpHint
      frontendHttpHint(
    Map<String, dynamic> json,
  ) {
    return DeveloperFrontendHttpHint(
      method:
          json['method']?.toString() ?? '',
      path:
          json['path']?.toString(),
      call:
          json['call']?.toString() ?? '',
      confidence:
          json['confidence']?.toString() ??
              'inferred',
    );
  }

  static DeveloperApiContract apiContract(
    Map<String, dynamic> json,
  ) {
    return DeveloperApiContract(
      path:
          json['path']?.toString() ?? '',
      function:
          json['function']?.toString() ?? '',
      layer:
          json['layer']?.toString() ?? '',
      summary:
          json['summary']?.toString() ?? '',
      confidence:
          json['confidence']?.toString() ??
              'unknown',
      authRequired:
          json['auth_required'] == true,
      authDependencies:
          (json['auth_dependencies'] as List? ??
                  const [])
              .map(
                (dynamic value) =>
                    value.toString(),
              )
              .toList(),
      requestSchemas:
          (json['request_schemas'] as List? ??
                  const [])
              .map(
                (dynamic value) =>
                    value.toString(),
              )
              .toList(),
      responseSchemas:
          (json['response_schemas'] as List? ??
                  const [])
              .map(
                (dynamic value) =>
                    value.toString(),
              )
              .toList(),
      securityCritical:
          json['security_critical'] == true,
      backendEndpoints:
          (json['backend_endpoints'] as List? ??
                  const [])
              .whereType<Map>()
              .map(
                (Map item) =>
                    apiEndpointContract(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList(),
      frontendHttpHints:
          (json['frontend_http_hints'] as List? ??
                  const [])
              .whereType<Map>()
              .map(
                (Map item) =>
                    frontendHttpHint(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList(),
    );
  }

  static DeveloperRuntimeFinding
      runtimeFinding(
    Map<String, dynamic> json,
  ) {
    return DeveloperRuntimeFinding(
      id: json['id']?.toString() ?? '',
      title:
          json['title']?.toString() ?? '',
      category:
          json['category']?.toString() ?? '',
      severity:
          json['severity']?.toString() ?? 'low',
      confidence:
          json['confidence']?.toString() ??
              'inferred',
      message:
          json['message']?.toString() ?? '',
      evidence:
          json['evidence']?.toString(),
      recommendation:
          json['recommendation']?.toString(),
    );
  }

  static DeveloperSideEffect sideEffect(
    Map<String, dynamic> json,
  ) {
    return DeveloperSideEffect(
      category:
          json['category']?.toString() ?? '',
      label:
          json['label']?.toString() ?? '',
      confidence:
          json['confidence']?.toString() ??
              'inferred',
      evidence:
          json['evidence']?.toString(),
    );
  }

  static DeveloperErrorPath errorPath(
    Map<String, dynamic> json,
  ) {
    return DeveloperErrorPath(
      kind:
          json['kind']?.toString() ?? '',
      code:
          json['code']?.toString(),
      label:
          json['label']?.toString() ?? '',
      confidence:
          json['confidence']?.toString() ??
              'inferred',
    );
  }

  static DeveloperRuntimeRisk runtimeRisk(
    Map<String, dynamic> json,
  ) {
    return DeveloperRuntimeRisk(
      path:
          json['path']?.toString() ?? '',
      function:
          json['function']?.toString() ?? '',
      language:
          json['language']?.toString() ?? '',
      risk: risk(json['risk']),
      summary:
          json['summary']?.toString() ?? '',
      securityCritical:
          json['security_critical'] == true,
      findings:
          (json['findings'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => runtimeFinding(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList(),
      sideEffects:
          (json['side_effects'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => sideEffect(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList(),
      errorPaths:
          (json['error_paths'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (Map item) => errorPath(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList(),
    );
  }

  static DeveloperGraphData graph(
    Map<String, dynamic> json,
  ) {
    final List<DeveloperGraphNode> nodes =
        (json['nodes'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (Map item) {
                final Map<String, dynamic> node =
                    Map<String, dynamic>.from(item);

                return DeveloperGraphNode(
                  id: node['id']?.toString() ?? '',
                  label:
                      node['label']?.toString() ?? '',
                  path:
                      node['path']?.toString() ?? '',
                  functionName:
                      node['function_name']?.toString(),
                  kind:
                      node['kind']?.toString() ?? '',
                  layer:
                      node['layer']?.toString(),
                  securityCritical:
                      node['security_critical'] == true,
                );
              },
            )
            .toList();

    final List<DeveloperGraphEdge> edges =
        (json['edges'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (Map item) {
                final Map<String, dynamic> edge =
                    Map<String, dynamic>.from(item);

                return DeveloperGraphEdge(
                  id: edge['id']?.toString() ?? '',
                  source:
                      edge['source']?.toString() ?? '',
                  target:
                      edge['target']?.toString() ?? '',
                  type:
                      edge['type']?.toString() ?? '',
                  label:
                      edge['label']?.toString() ?? '',
                );
              },
            )
            .toList();

    return DeveloperGraphData(
      nodes: nodes,
      edges: edges,
    );
  }
}
