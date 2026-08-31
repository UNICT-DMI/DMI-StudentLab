import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'local_database_backend_base.dart';

class NativeLocalDatabaseBackend implements LocalDatabaseBackend {
  DatabaseFactory? _factory;

  @override
  Future<void> initialize() async {
    if (_factory != null) return;

    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      sqfliteFfiInit();
      _factory = databaseFactoryFfi;
      return;
    }

    _factory = mobile.databaseFactory;
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
    final DatabaseFactory factory = _factory!;
    final String root = await factory.getDatabasesPath();
    return factory.openDatabase(
      p.join(root, name),
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
    NativeLocalDatabaseBackend();
