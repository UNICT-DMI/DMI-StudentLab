import '../models/developer_models.dart';

class DeveloperRepositoryConnection {
  final DeveloperSourceType type;
  final String label;
  final bool readOnly;
  final bool consentGranted;
  final DateTime? lastSyncAt;
  const DeveloperRepositoryConnection({required this.type, required this.label, required this.readOnly, required this.consentGranted, this.lastSyncAt});
}

abstract class DeveloperRepositorySource {
  DeveloperRepositoryConnection get connection;
  Future<void> refresh();
}

class MockDeveloperRepositorySource implements DeveloperRepositorySource {
  @override
  final DeveloperRepositoryConnection connection;
  const MockDeveloperRepositorySource({this.connection = const DeveloperRepositoryConnection(type: DeveloperSourceType.local, label: 'Repository locale', readOnly: true, consentGranted: false)});
  @override
  Future<void> refresh() async {}
}
