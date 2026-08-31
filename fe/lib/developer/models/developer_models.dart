import 'package:flutter/material.dart';

enum DeveloperNodeType { folder, file }

enum DeveloperRelationType {
  calls,
  calledBy,
  usesModel,
  usesConfig,
  frontend,
  flow,
  security,
  endpoint,
  imports,
  contains,
  unknown,
}

enum DeveloperSourceType {
  local,
  remote,
  synced,
}

enum DeveloperRiskLevel {
  low,
  medium,
  high,
  critical,
}

class DeveloperBadge {
  final String label;
  final IconData icon;
  final Color color;

  const DeveloperBadge(
    this.label,
    this.icon,
    this.color,
  );
}

class DeveloperAccessResult {
  final bool authorized;
  final String? role;

  const DeveloperAccessResult({
    required this.authorized,
    this.role,
  });
}

class DeveloperRepositoryStatus {
  final String repositoryName;
  final String repositoryRoot;
  final DeveloperSourceType sourceType;
  final bool gitAvailable;
  final String? branch;
  final String? headCommit;
  final int filesIndexed;
  final int functionsIndexed;
  final int documentedFiles;
  final int outdatedFiles;
  final int changedFiles;
  final int securityCriticalFiles;

  const DeveloperRepositoryStatus({
    required this.repositoryName,
    required this.repositoryRoot,
    required this.sourceType,
    required this.gitAvailable,
    required this.branch,
    required this.headCommit,
    required this.filesIndexed,
    required this.functionsIndexed,
    required this.documentedFiles,
    required this.outdatedFiles,
    required this.changedFiles,
    required this.securityCriticalFiles,
  });
}

class DeveloperTreeNode {
  final String id;
  final String name;
  final String path;
  final DeveloperNodeType type;
  final List<DeveloperTreeNode> children;
  final bool documented;
  final bool outdated;
  final bool changed;
  final bool securityCritical;
  final int? functionCount;

  const DeveloperTreeNode({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    this.children = const [],
    this.documented = false,
    this.outdated = false,
    this.changed = false,
    this.securityCritical = false,
    this.functionCount,
  });
}

class DeveloperFunctionDoc {
  final String id;
  final String name;
  final String signature;
  final String description;
  final int? lineStart;
  final int? lineEnd;
  final bool isAsync;
  final List<String> calls;
  final List<String> calledBy;
  final List<String> flows;
  final List<String> security;
  final List<String> inputs;
  final List<String> outputs;
  final DeveloperRiskLevel risk;

  const DeveloperFunctionDoc({
    required this.id,
    required this.name,
    required this.signature,
    required this.description,
    this.lineStart,
    this.lineEnd,
    this.isAsync = false,
    this.calls = const [],
    this.calledBy = const [],
    this.flows = const [],
    this.security = const [],
    this.inputs = const [],
    this.outputs = const [],
    this.risk = DeveloperRiskLevel.medium,
  });
}

class DeveloperRelation {
  final DeveloperRelationType type;
  final String label;
  final String targetPath;
  final String? targetFunction;

  const DeveloperRelation({
    required this.type,
    required this.label,
    required this.targetPath,
    this.targetFunction,
  });
}


class DeveloperEndpointArtifact {
  final String method;
  final String path;
  final String functionName;
  final int? lineStart;
  final String? routerName;
  final List<String> dependencies;
  final String? responseModel;
  final bool securityCritical;
  final String confidence;

  const DeveloperEndpointArtifact({
    required this.method,
    required this.path,
    required this.functionName,
    this.lineStart,
    this.routerName,
    this.dependencies = const [],
    this.responseModel,
    this.securityCritical = false,
    this.confidence = 'observed',
  });
}

class DeveloperModelArtifact {
  final String name;
  final String? tableName;
  final List<String> bases;
  final List<String> columns;
  final List<String> relationships;
  final int? lineStart;
  final String confidence;

  const DeveloperModelArtifact({
    required this.name,
    this.tableName,
    this.bases = const [],
    this.columns = const [],
    this.relationships = const [],
    this.lineStart,
    this.confidence = 'observed',
  });
}

class DeveloperTestArtifact {
  final String name;
  final int? lineStart;
  final String framework;
  final List<String> calls;
  final List<String> targetCandidates;
  final String confidence;

  const DeveloperTestArtifact({
    required this.name,
    this.lineStart,
    required this.framework,
    this.calls = const [],
    this.targetCandidates = const [],
    this.confidence = 'observed',
  });
}

class DeveloperFileDoc {
  final String id;
  final String path;
  final String name;
  final String extension;
  final String language;
  final String layer;
  final String module;
  final String description;
  final String importance;
  final DeveloperRiskLevel risk;
  final DeveloperSourceType sourceType;
  final bool documented;
  final bool outdated;
  final bool changed;
  final bool securityCritical;
  final int sizeBytes;
  final double? modifiedAt;
  final String contentHash;
  final List<DeveloperBadge> badges;
  final List<DeveloperFunctionDoc> functions;
  final List<String> imports;
  final List<DeveloperRelation> relations;
  final List<String> flows;
  final List<String> securityNotes;
  final List<DeveloperEndpointArtifact> endpoints;
  final List<DeveloperModelArtifact> models;
  final List<DeveloperTestArtifact> tests;

  const DeveloperFileDoc({
    required this.id,
    required this.path,
    required this.name,
    required this.extension,
    required this.language,
    required this.layer,
    required this.module,
    required this.description,
    required this.importance,
    required this.risk,
    required this.sourceType,
    required this.documented,
    required this.outdated,
    required this.changed,
    required this.securityCritical,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.contentHash,
    this.badges = const [],
    this.functions = const [],
    this.imports = const [],
    this.relations = const [],
    this.flows = const [],
    this.securityNotes = const [],
    this.endpoints = const [],
    this.models = const [],
    this.tests = const [],
  });
}

class DeveloperSearchResult {
  final String kind;
  final String title;
  final String subtitle;
  final String path;
  final String? functionName;
  final double score;
  final List<String> reasons;

  const DeveloperSearchResult({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.path,
    this.functionName,
    required this.score,
    this.reasons = const [],
  });
}

class DeveloperFlowDoc {
  final String id;
  final String name;
  final String description;
  final DeveloperRiskLevel risk;
  final List<DeveloperFlowStep> steps;

  const DeveloperFlowDoc({
    required this.id,
    required this.name,
    required this.description,
    required this.risk,
    required this.steps,
  });
}

class DeveloperFlowStep {
  final int order;
  final String title;
  final String file;
  final String? function;
  final String layer;
  final String relation;
  final String context;
  final bool securityCritical;

  const DeveloperFlowStep({
    required this.order,
    required this.title,
    required this.file,
    this.function,
    required this.layer,
    this.relation = 'NEXT',
    this.context = '',
    this.securityCritical = false,
  });
}

class DeveloperGraphNode {
  final String id;
  final String label;
  final String path;
  final String? functionName;
  final String kind;
  final String? layer;
  final bool securityCritical;

  const DeveloperGraphNode({
    required this.id,
    required this.label,
    required this.path,
    required this.functionName,
    required this.kind,
    required this.layer,
    required this.securityCritical,
  });
}

class DeveloperGraphEdge {
  final String id;
  final String source;
  final String target;
  final String type;
  final String label;

  const DeveloperGraphEdge({
    required this.id,
    required this.source,
    required this.target,
    required this.type,
    required this.label,
  });
}

class DeveloperGraphData {
  final List<DeveloperGraphNode> nodes;
  final List<DeveloperGraphEdge> edges;

  const DeveloperGraphData({
    required this.nodes,
    required this.edges,
  });
}

class DeveloperImpactFunctionRef {
  final String file;
  final String function;
  final String layer;
  final bool securityCritical;
  final DeveloperRiskLevel risk;
  final int? depth;

  const DeveloperImpactFunctionRef({
    required this.file,
    required this.function,
    required this.layer,
    required this.securityCritical,
    required this.risk,
    this.depth,
  });
}

class DeveloperImpactFlow {
  final String id;
  final String name;
  final DeveloperRiskLevel risk;
  final List<int> matchedSteps;

  const DeveloperImpactFlow({
    required this.id,
    required this.name,
    required this.risk,
    required this.matchedSteps,
  });
}

class DeveloperImpactEndpoint {
  final String file;
  final String function;
  final String? method;
  final String? path;
  final String confidence;

  const DeveloperImpactEndpoint({
    required this.file,
    required this.function,
    required this.method,
    required this.path,
    required this.confidence,
  });
}

class DeveloperImpactModelRef {
  final String file;
  final String name;
  final String layer;
  final String confidence;

  const DeveloperImpactModelRef({
    required this.file,
    required this.name,
    required this.layer,
    required this.confidence,
  });
}

class DeveloperImpactTestRef {
  final String file;
  final String confidence;
  final String reason;

  const DeveloperImpactTestRef({
    required this.file,
    required this.confidence,
    required this.reason,
  });
}

class DeveloperImpactAnalysis {
  final String path;
  final String? function;
  final DeveloperRiskLevel risk;
  final String summary;
  final String semanticAnswer;
  final List<DeveloperImpactFunctionRef>
      directCallers;
  final List<DeveloperImpactFunctionRef>
      directCallees;
  final List<DeveloperImpactFunctionRef>
      transitiveCallers;
  final List<String> relatedFiles;
  final List<DeveloperImpactFlow> flows;
  final List<DeveloperImpactEndpoint>
      endpoints;
  final List<DeveloperImpactModelRef>
      models;
  final List<DeveloperImpactTestRef>
      tests;
  final List<String> recommendations;
  final List<String> securityFlags;
  final bool securityCritical;

  const DeveloperImpactAnalysis({
    required this.path,
    required this.function,
    required this.risk,
    required this.summary,
    required this.semanticAnswer,
    required this.directCallers,
    required this.directCallees,
    required this.transitiveCallers,
    required this.relatedFiles,
    required this.flows,
    required this.endpoints,
    required this.models,
    required this.tests,
    required this.recommendations,
    required this.securityFlags,
    required this.securityCritical,
  });
}

class DeveloperSourceCode {
  final String path;
  final String language;
  final String? symbol;
  final String sourceKind;
  final int lineStart;
  final int lineEnd;
  final int lineCount;
  final String source;
  final String? commitSha;
  final String contentHash;
  final String repository;
  final String? branch;

  const DeveloperSourceCode({
    required this.path,
    required this.language,
    required this.symbol,
    required this.sourceKind,
    required this.lineStart,
    required this.lineEnd,
    required this.lineCount,
    required this.source,
    required this.commitSha,
    required this.contentHash,
    required this.repository,
    required this.branch,
  });
}

class DeveloperApiEndpointContract {
  final String file;
  final String function;
  final String? method;
  final String? path;
  final List<String> authDependencies;
  final String? requestSchema;
  final String? responseSchema;
  final String confidence;
  final bool securityCritical;

  const DeveloperApiEndpointContract({
    required this.file,
    required this.function,
    required this.method,
    required this.path,
    required this.authDependencies,
    required this.requestSchema,
    required this.responseSchema,
    required this.confidence,
    required this.securityCritical,
  });
}

class DeveloperFrontendHttpHint {
  final String method;
  final String? path;
  final String call;
  final String confidence;

  const DeveloperFrontendHttpHint({
    required this.method,
    required this.path,
    required this.call,
    required this.confidence,
  });
}

class DeveloperApiContract {
  final String path;
  final String function;
  final String layer;
  final String summary;
  final String confidence;
  final bool authRequired;
  final List<String> authDependencies;
  final List<String> requestSchemas;
  final List<String> responseSchemas;
  final bool securityCritical;
  final List<DeveloperApiEndpointContract>
      backendEndpoints;
  final List<DeveloperFrontendHttpHint>
      frontendHttpHints;

  const DeveloperApiContract({
    required this.path,
    required this.function,
    required this.layer,
    required this.summary,
    required this.confidence,
    required this.authRequired,
    required this.authDependencies,
    required this.requestSchemas,
    required this.responseSchemas,
    required this.securityCritical,
    required this.backendEndpoints,
    required this.frontendHttpHints,
  });
}

class DeveloperRuntimeFinding {
  final String id;
  final String title;
  final String category;
  final String severity;
  final String confidence;
  final String message;
  final String? evidence;
  final String? recommendation;

  const DeveloperRuntimeFinding({
    required this.id,
    required this.title,
    required this.category,
    required this.severity,
    required this.confidence,
    required this.message,
    this.evidence,
    this.recommendation,
  });
}

class DeveloperSideEffect {
  final String category;
  final String label;
  final String confidence;
  final String? evidence;

  const DeveloperSideEffect({
    required this.category,
    required this.label,
    required this.confidence,
    this.evidence,
  });
}

class DeveloperErrorPath {
  final String kind;
  final String? code;
  final String label;
  final String confidence;

  const DeveloperErrorPath({
    required this.kind,
    required this.code,
    required this.label,
    required this.confidence,
  });
}

class DeveloperRuntimeRisk {
  final String path;
  final String function;
  final String language;
  final DeveloperRiskLevel risk;
  final String summary;
  final bool securityCritical;
  final List<DeveloperRuntimeFinding> findings;
  final List<DeveloperSideEffect> sideEffects;
  final List<DeveloperErrorPath> errorPaths;

  const DeveloperRuntimeRisk({
    required this.path,
    required this.function,
    required this.language,
    required this.risk,
    required this.summary,
    required this.securityCritical,
    required this.findings,
    required this.sideEffects,
    required this.errorPaths,
  });
}

