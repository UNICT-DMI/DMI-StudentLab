import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'local_database_backend_base.dart';

class WebLocalDatabaseBackend implements LocalDatabaseBackend {
  DatabaseFactory? _factory;

  @override
  Future<void> initialize() async {
    _factory ??= databaseFactoryFfiWeb;
  }

  @override
  Future<Database> open({
    required String name,
    required int version,
    required OnDatabaseCreateFn onCreate,
    required OnDatabaseVersionChangeFn onUpgrade,
    required OnDatabaseConfigureFn onConfigure,
  }) async {
    await initialize();
    return _factory!.openDatabase(
      name,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onConfigure: onConfigure,
      ),
    );
  }
}

LocalDatabaseBackend createPlatformLocalDatabaseBackend() =>
    WebLocalDatabaseBackend();
