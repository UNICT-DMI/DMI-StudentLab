import 'package:sqflite_common/sqlite_api.dart';

import '../database/app_database.dart';

class MaterialPreferenceService {
  final AppDatabase _database;
  MaterialPreferenceService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  Future<Map<String, int>> byUser(int userId) async {
    final db = await _database.database;
    final rows = await db.query('material_duplicate_preferences',
      where: 'user_id = ?', whereArgs: <Object?>[userId]);
    return <String, int>{for (final row in rows)
      if (row['file_hash'] is String && row['material_id'] is int)
        row['file_hash'] as String: row['material_id'] as int};
  }

  Future<void> choose({required int userId, required String hash,
      required int materialId}) async {
    final db = await _database.database;
    await db.insert('material_duplicate_preferences', <String, Object?>{
      'user_id': userId, 'file_hash': hash.toLowerCase(),
      'material_id': materialId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> keepBoth({required int userId, required String hash}) async {
    final db = await _database.database;
    await db.delete('material_duplicate_preferences',
      where: 'user_id = ? AND file_hash = ?',
      whereArgs: <Object?>[userId, hash.toLowerCase()]);
  }

  Future<void> claimGuest(int userId) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      final rows = await transaction.query('material_duplicate_preferences',
        where: 'user_id = 0');
      for (final row in rows) {
        final materialId = row['material_id'];
        if (materialId is! int) continue;
        final owner = await transaction.query('materials', columns: <String>['id'],
          where: 'id = ? AND user_id = ?', whereArgs: <Object?>[materialId, userId],
          limit: 1);
        if (owner.isEmpty) continue;
        await transaction.insert('material_duplicate_preferences', <String, Object?>{
          'user_id': userId, 'file_hash': row['file_hash'],
          'material_id': materialId, 'updated_at': row['updated_at'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await transaction.delete('material_duplicate_preferences',
          where: 'user_id = 0 AND file_hash = ?',
          whereArgs: <Object?>[row['file_hash']]);
      }
    });
  }
}
