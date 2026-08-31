import 'package:sqflite_common/sqlite_api.dart';

abstract class LocalDatabaseBackend {
  Future<void> initialize();

  Future<Database> open({
    required String name,
    required int version,
    required OnDatabaseCreateFn onCreate,
    required OnDatabaseVersionChangeFn onUpgrade,
    required OnDatabaseConfigureFn onConfigure,
  });
}
