import 'package:sqflite/sqflite.dart';

import '../../local_storage/database/app_database.dart';

class SupportDiagnosticCollector {
  final AppDatabase _database;

  SupportDiagnosticCollector({
    AppDatabase? database,
  }) : _database =
           database ?? AppDatabase.instance;

  static const Set<String> _allowedTables = <String>{
    'materials',
    'material_files',
    'material_downloads',
    'material_sync_state',
    'pending_uploads',
  };

  static const Set<String> _sensitiveColumns = <String>{
    'local_path',
    'temp_path',
    'password',
    'password_hash',
    'access_token',
    'refresh_token',
    'token',
  };

  Future<Map<String, dynamic>> collect({
    int maxRowsPerTable = 200,
  }) async {
    final Database db = await _database.database;

    final int? databaseVersion =
        Sqflite.firstIntValue(
      await db.rawQuery(
        'PRAGMA user_version',
      ),
    );

    final List<Map<String, Object?>> tables =
        await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
      ORDER BY name
      ''',
    );

    final Map<String, dynamic> result =
        <String, dynamic>{
      'database_version': databaseVersion ?? 0,
      'collected_at':
          DateTime.now().toUtc().toIso8601String(),
      'tables': <String, dynamic>{},
    };

    final Map<String, dynamic> outputTables =
        result['tables'] as Map<String, dynamic>;

    for (final Map<String, Object?> table in tables) {
      final String name =
          table['name']?.toString().trim() ?? '';

      if (!_allowedTables.contains(name)) {
        continue;
      }

      final List<Map<String, Object?>> columns =
          await db.rawQuery(
        'PRAGMA table_info("$name")',
      );

      final List<String> safeColumns = columns
          .map(
            (Map<String, Object?> row) =>
                row['name']?.toString().trim() ?? '',
          )
          .where(
            (String column) =>
                column.isNotEmpty &&
                !_sensitiveColumns.contains(
                  column.toLowerCase(),
                ),
          )
          .toList();

      final List<Map<String, Object?>> rows =
          safeColumns.isEmpty
              ? <Map<String, Object?>>[]
              : await db.query(
                  name,
                  columns: safeColumns,
                  limit: maxRowsPerTable,
                );

      outputTables[name] = <String, dynamic>{
        'columns': safeColumns,
        'row_count': Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM "$name"',
              ),
            ) ??
            0,
        'rows': rows,
        'truncated': rows.length >= maxRowsPerTable,
      };
    }

    return result;
  }
}
