import 'package:sqflite_common/sqlite_api.dart';

import '../database/app_database.dart';
import '../database/database_tables.dart';

import '../models/material_local.dart';


class MaterialRepository {
  final AppDatabase _database =
      AppDatabase.instance;


  Future<int> insert(
    MaterialLocal material,
  ) async {
    final Database db =
        await _database.database;

    return db.insert(
      DatabaseTables.materials,
      material.toMap(),
      conflictAlgorithm:
          ConflictAlgorithm.abort,
    );
  }


  Future<int> save(
    MaterialLocal material,
  ) async {
    final Database db =
        await _database.database;

    if (material.id != null) {
      await db.update(
        DatabaseTables.materials,
        material.toMap(),
        where:
            'id = ?',
        whereArgs: <Object?>[
          material.id,
        ],
      );

      return material.id!;
    }

    if (
      material.remoteKey != null &&
      material.remoteKey!.trim().isNotEmpty
    ) {
      final MaterialLocal? existing =
          await getByRemoteKey(
        userId:
            material.userId,
        remoteKey:
            material.remoteKey!,
      );

      if (existing != null) {
        await db.update(
          DatabaseTables.materials,
          material.toMap(),
          where:
              'id = ?',
          whereArgs: <Object?>[
            existing.id,
          ],
        );

        return existing.id!;
      }
    }

    return db.insert(
      DatabaseTables.materials,
      material.toMap(),
    );
  }


  Future<void> saveAll(
    List<MaterialLocal> materials,
  ) async {
    if (materials.isEmpty) {
      return;
    }

    final Database db =
        await _database.database;

    await db.transaction(
      (
        Transaction transaction,
      ) async {
        for (
          final MaterialLocal material
          in materials
        ) {
          if (material.id != null) {
            await transaction.update(
              DatabaseTables.materials,
              material.toMap(),
              where:
                  'id = ?',
              whereArgs: <Object?>[
                material.id,
              ],
            );

            continue;
          }

          if (
            material.remoteKey != null &&
            material.remoteKey!.trim().isNotEmpty
          ) {
            final List<Map<String, Object?>>
                existing =
                await transaction.query(
              DatabaseTables.materials,
              columns: <String>[
                'id',
              ],
              where:
                  'user_id = ? AND remote_key = ?',
              whereArgs: <Object?>[
                material.userId,
                material.remoteKey,
              ],
              limit:
                  1,
            );

            if (existing.isNotEmpty) {
              final int? id =
                  _asInt(
                existing.first['id'],
              );

              if (id != null) {
                await transaction.update(
                  DatabaseTables.materials,
                  material.toMap(),
                  where:
                      'id = ?',
                  whereArgs: <Object?>[
                    id,
                  ],
                );

                continue;
              }
            }
          }

          await transaction.insert(
            DatabaseTables.materials,
            material.toMap(),
          );
        }
      },
    );
  }


  Future<MaterialLocal?> getById(
    int id,
  ) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.materials,
      where:
          'id = ?',
      whereArgs: <Object?>[
        id,
      ],
      limit:
          1,
    );

    if (result.isEmpty) {
      return null;
    }

    return MaterialLocal.fromMap(
      result.first,
    );
  }


  Future<MaterialLocal?> getByRemoteKey({
    required int userId,
    required String remoteKey,
  }) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.materials,
      where:
          'user_id = ? AND remote_key = ?',
      whereArgs: <Object?>[
        userId,
        remoteKey.trim(),
      ],
      limit:
          1,
    );

    if (result.isEmpty) {
      return null;
    }

    return MaterialLocal.fromMap(
      result.first,
    );
  }


  Future<MaterialLocal?> getByRemoteId({
    required int userId,
    required MaterialSourceLocal source,
    required int remoteId,
  }) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.materials,
      where:
          'user_id = ? AND source = ? AND remote_id = ?',
      whereArgs: <Object?>[
        userId,
        source.name,
        remoteId,
      ],
      limit:
          1,
    );

    if (result.isEmpty) {
      return null;
    }

    return MaterialLocal.fromMap(
      result.first,
    );
  }


  Future<List<MaterialLocal>> getByUser(
    int userId,
  ) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.materials,
      where:
          'user_id = ?',
      whereArgs: <Object?>[
        userId,
      ],
      orderBy:
          'updated_at DESC, id DESC',
    );

    return result
        .map(
          MaterialLocal.fromMap,
        )
        .toList();
  }


  Future<List<MaterialLocal>> getAvailableByUser(
    int userId,
  ) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.materials,
      where:
          'user_id = ? AND (source = ? OR is_available_remote = 1)',
      whereArgs: <Object?>[
        userId,
        MaterialSourceLocal.local.name,
      ],
      orderBy:
          'updated_at DESC, id DESC',
    );

    return result
        .map(
          MaterialLocal.fromMap,
        )
        .toList();
  }


  Future<List<MaterialLocal>> getDownloadedByUser(
    int userId,
  ) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.rawQuery(
      '''
      SELECT m.*
      FROM ${DatabaseTables.materials} AS m
      INNER JOIN ${DatabaseTables.materialFiles} AS f
        ON f.id = m.file_id
      WHERE m.user_id = ?
        AND f.exists_locally = 1
      ORDER BY m.updated_at DESC, m.id DESC
      ''',
      <Object?>[
        userId,
      ],
    );

    return result
        .map(
          MaterialLocal.fromMap,
        )
        .toList();
  }


  Future<List<MaterialLocal>> getBySource({
    required int userId,
    required MaterialSourceLocal source,
    bool onlyAvailable = false,
  }) async {
    final Database db =
        await _database.database;

    String where =
        'user_id = ? AND source = ?';

    final List<Object?> args =
        <Object?>[
      userId,
      source.name,
    ];

    if (
      onlyAvailable &&
      source != MaterialSourceLocal.local
    ) {
      where +=
          ' AND is_available_remote = 1';
    }

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.materials,
      where:
          where,
      whereArgs:
          args,
      orderBy:
          'updated_at DESC, id DESC',
    );

    return result
        .map(
          MaterialLocal.fromMap,
        )
        .toList();
  }


  Future<List<MaterialLocal>> getByGroup({
    required int userId,
    required int groupId,
    bool onlyAvailable = true,
  }) async {
    final Database db =
        await _database.database;

    String where =
        'user_id = ? AND group_id = ?';

    final List<Object?> args =
        <Object?>[
      userId,
      groupId,
    ];

    if (onlyAvailable) {
      where +=
          ' AND (source = ? OR is_available_remote = 1)';

      args.add(
        MaterialSourceLocal.local.name,
      );
    }

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.materials,
      where:
          where,
      whereArgs:
          args,
      orderBy:
          'updated_at DESC, id DESC',
    );

    return result
        .map(
          MaterialLocal.fromMap,
        )
        .toList();
  }


  Future<List<MaterialLocal>> getBySubject({
    required int userId,
    required int subjectId,
    bool onlyAvailable = true,
  }) async {
    final Database db =
        await _database.database;

    String where =
        'user_id = ? AND subject_id = ?';

    final List<Object?> args =
        <Object?>[
      userId,
      subjectId,
    ];

    if (onlyAvailable) {
      where +=
          ' AND (source = ? OR is_available_remote = 1)';

      args.add(
        MaterialSourceLocal.local.name,
      );
    }

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.materials,
      where:
          where,
      whereArgs:
          args,
      orderBy:
          'updated_at DESC, id DESC',
    );

    return result
        .map(
          MaterialLocal.fromMap,
        )
        .toList();
  }


  Future<List<MaterialLocal>> getBySubjectName({
    required int userId,
    required String subjectName,
    bool onlyAvailable = true,
  }) async {
    final Database db =
        await _database.database;

    String where =
        'user_id = ? AND subject_name = ?';

    final List<Object?> args =
        <Object?>[
      userId,
      subjectName.trim(),
    ];

    if (onlyAvailable) {
      where +=
          ' AND (source = ? OR is_available_remote = 1)';

      args.add(
        MaterialSourceLocal.local.name,
      );
    }

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.materials,
      where:
          where,
      whereArgs:
          args,
      orderBy:
          'updated_at DESC, id DESC',
    );

    return result
        .map(
          MaterialLocal.fromMap,
        )
        .toList();
  }


  Future<List<String>> getUniversities(
    int userId,
  ) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.rawQuery(
      '''
      SELECT DISTINCT TRIM(university) AS value
      FROM ${DatabaseTables.materials}
      WHERE user_id = ?
        AND university IS NOT NULL
        AND TRIM(university) <> ''
        AND (source = 'local' OR is_available_remote = 1)
      ORDER BY value COLLATE NOCASE ASC
      ''',
      <Object?>[
        userId,
      ],
    );

    return _extractStrings(
      result,
    );
  }


  Future<List<String>> getDepartments({
    required int userId,
    required String university,
  }) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.rawQuery(
      '''
      SELECT DISTINCT TRIM(department) AS value
      FROM ${DatabaseTables.materials}
      WHERE user_id = ?
        AND university = ?
        AND department IS NOT NULL
        AND TRIM(department) <> ''
        AND (source = 'local' OR is_available_remote = 1)
      ORDER BY value COLLATE NOCASE ASC
      ''',
      <Object?>[
        userId,
        university.trim(),
      ],
    );

    return _extractStrings(
      result,
    );
  }


  Future<List<String>> getCourses({
    required int userId,
    required String university,
    required String department,
  }) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.rawQuery(
      '''
      SELECT DISTINCT TRIM(course) AS value
      FROM ${DatabaseTables.materials}
      WHERE user_id = ?
        AND university = ?
        AND department = ?
        AND course IS NOT NULL
        AND TRIM(course) <> ''
        AND (source = 'local' OR is_available_remote = 1)
      ORDER BY value COLLATE NOCASE ASC
      ''',
      <Object?>[
        userId,
        university.trim(),
        department.trim(),
      ],
    );

    return _extractStrings(
      result,
    );
  }


  Future<List<MaterialLocal>> getSubjects({
    required int userId,
    required String university,
    required String department,
    required String course,
  }) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.materials,
      where:
          'user_id = ? AND university = ? AND department = ? AND course = ? AND (source = ? OR is_available_remote = 1)',
      whereArgs: <Object?>[
        userId,
        university.trim(),
        department.trim(),
        course.trim(),
        MaterialSourceLocal.local.name,
      ],
      orderBy:
          'subject_name COLLATE NOCASE ASC, updated_at DESC',
    );

    final Map<String, MaterialLocal>
        subjects =
        <String, MaterialLocal>{};

    for (
      final Map<String, Object?> row
      in result
    ) {
      final MaterialLocal material =
          MaterialLocal.fromMap(
        row,
      );

      final String key;

      if (material.subjectId != null) {
        key =
            'id:${material.subjectId}';
      } else {
        final String name =
            material.subjectName
                    ?.trim()
                    .toLowerCase() ??
                '';

        if (name.isEmpty) {
          continue;
        }

        key =
            'name:$name';
      }

      subjects.putIfAbsent(
        key,
        () =>
            material,
      );
    }

    return subjects.values.toList();
  }


  Future<List<MaterialLocal>> getMaterialsByHierarchy({
    required int userId,
    required String university,
    required String department,
    required String course,
    int? subjectId,
    String? subjectName,
    bool onlyAvailable = true,
  }) async {
    final Database db =
        await _database.database;

    String where =
        'user_id = ? AND university = ? AND department = ? AND course = ?';

    final List<Object?> whereArgs =
        <Object?>[
      userId,
      university.trim(),
      department.trim(),
      course.trim(),
    ];

    if (subjectId != null) {
      where +=
          ' AND subject_id = ?';

      whereArgs.add(
        subjectId,
      );
    } else if (
      subjectName != null &&
      subjectName.trim().isNotEmpty
    ) {
      where +=
          ' AND subject_name = ?';

      whereArgs.add(
        subjectName.trim(),
      );
    }

    if (onlyAvailable) {
      where +=
          ' AND (source = ? OR is_available_remote = 1)';

      whereArgs.add(
        MaterialSourceLocal.local.name,
      );
    }

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.materials,
      where:
          where,
      whereArgs:
          whereArgs,
      orderBy:
          'updated_at DESC, id DESC',
    );

    return result
        .map(
          MaterialLocal.fromMap,
        )
        .toList();
  }


  Future<List<MaterialLocal>> getDownloadedSubjects(
    int userId,
  ) async {
    final List<MaterialLocal> materials =
        await getDownloadedByUser(
      userId,
    );

    final Map<String, MaterialLocal>
        uniqueSubjects =
        <String, MaterialLocal>{};

    for (
      final MaterialLocal material
      in materials
    ) {
      final String key;

      if (material.subjectId != null) {
        key =
            '${material.university}|${material.department}|${material.course}|${material.subjectId}';
      } else {
        final String name =
            material.subjectName
                    ?.trim()
                    .toLowerCase() ??
                '';

        if (name.isEmpty) {
          continue;
        }

        key =
            '${material.university}|${material.department}|${material.course}|$name';
      }

      uniqueSubjects.putIfAbsent(
        key,
        () =>
            material,
      );
    }

    return uniqueSubjects.values.toList();
  }


  Future<void> attachFile({
    required int materialId,
    required int fileId,
  }) async {
    final Database db =
        await _database.database;

    await db.update(
      DatabaseTables.materials,
      <String, Object?>{
        'file_id':
            fileId,
        'updated_at':
            DateTime.now().toUtc().toIso8601String(),
      },
      where:
          'id = ?',
      whereArgs: <Object?>[
        materialId,
      ],
    );
  }


  Future<void> detachFile(
    int materialId,
  ) async {
    final Database db =
        await _database.database;

    await db.update(
      DatabaseTables.materials,
      <String, Object?>{
        'file_id':
            null,
        'updated_at':
            DateTime.now().toUtc().toIso8601String(),
      },
      where:
          'id = ?',
      whereArgs: <Object?>[
        materialId,
      ],
    );
  }


  Future<void> markRemoteUnavailable({
    required int userId,
    required String remoteKey,
    String remoteStatus = 'removed',
  }) async {
    final Database db =
        await _database.database;

    await db.update(
      DatabaseTables.materials,
      <String, Object?>{
        'is_available_remote':
            0,
        'remote_status':
            remoteStatus,
        'updated_at':
            DateTime.now().toUtc().toIso8601String(),
      },
      where:
          'user_id = ? AND remote_key = ? AND source <> ?',
      whereArgs: <Object?>[
        userId,
        remoteKey.trim(),
        MaterialSourceLocal.local.name,
      ],
    );
  }


  Future<int> markMissingRemoteKeysUnavailable({
    required int userId,
    required Set<String> visibleKeys,
  }) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>> rows =
        await db.query(
      DatabaseTables.materials,
      columns: <String>[
        'id',
        'remote_key',
      ],
      where:
          'user_id = ? AND source <> ? AND is_available_remote = 1',
      whereArgs: <Object?>[
        userId,
        MaterialSourceLocal.local.name,
      ],
    );

    final List<int> ids =
        <int>[];

    for (
      final Map<String, Object?> row
      in rows
    ) {
      final int? id =
          _asInt(
        row['id'],
      );

      final String? remoteKey =
          row['remote_key']?.toString();

      if (
        id != null &&
        remoteKey != null &&
        !visibleKeys.contains(
          remoteKey,
        )
      ) {
        ids.add(
          id,
        );
      }
    }

    if (ids.isEmpty) {
      return 0;
    }

    final Batch batch =
        db.batch();

    final String now =
        DateTime.now()
            .toUtc()
            .toIso8601String();

    for (final int id in ids) {
      batch.update(
        DatabaseTables.materials,
        <String, Object?>{
          'is_available_remote':
              0,
          'updated_at':
              now,
        },
        where:
            'id = ?',
        whereArgs: <Object?>[
          id,
        ],
      );
    }

    await batch.commit(
      noResult:
          true,
    );

    return ids.length;
  }


  Future<int> countByUser(
    int userId, {
    bool onlyAvailable = true,
  }) async {
    final Database db =
        await _database.database;

    String where =
        'user_id = ?';

    final List<Object?> args =
        <Object?>[
      userId,
    ];

    if (onlyAvailable) {
      where +=
          ' AND (source = ? OR is_available_remote = 1)';

      args.add(
        MaterialSourceLocal.local.name,
      );
    }

    final List<Map<String, Object?>> result =
        await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM ${DatabaseTables.materials}
      WHERE $where
      ''',
      args,
    );

    return _extractCount(
      result,
    );
  }


  Future<int> countBySubject({
    required int userId,
    int? subjectId,
    String? subjectName,
    String? university,
    String? department,
    String? course,
    bool onlyAvailable = true,
  }) async {
    final Database db =
        await _database.database;

    String where =
        'user_id = ?';

    final List<Object?> args =
        <Object?>[
      userId,
    ];

    if (
      university != null &&
      university.trim().isNotEmpty
    ) {
      where +=
          ' AND university = ?';

      args.add(
        university.trim(),
      );
    }

    if (
      department != null &&
      department.trim().isNotEmpty
    ) {
      where +=
          ' AND department = ?';

      args.add(
        department.trim(),
      );
    }

    if (
      course != null &&
      course.trim().isNotEmpty
    ) {
      where +=
          ' AND course = ?';

      args.add(
        course.trim(),
      );
    }

    if (subjectId != null) {
      where +=
          ' AND subject_id = ?';

      args.add(
        subjectId,
      );
    } else if (
      subjectName != null &&
      subjectName.trim().isNotEmpty
    ) {
      where +=
          ' AND subject_name = ?';

      args.add(
        subjectName.trim(),
      );
    } else {
      return 0;
    }

    if (onlyAvailable) {
      where +=
          ' AND (source = ? OR is_available_remote = 1)';

      args.add(
        MaterialSourceLocal.local.name,
      );
    }

    final List<Map<String, Object?>> result =
        await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM ${DatabaseTables.materials}
      WHERE $where
      ''',
      args,
    );

    return _extractCount(
      result,
    );
  }


  Future<int> deleteById(
    int id,
  ) async {
    final Database db =
        await _database.database;

    return db.delete(
      DatabaseTables.materials,
      where:
          'id = ?',
      whereArgs: <Object?>[
        id,
      ],
    );
  }


  Future<int> deleteRemote({
    required int userId,
    required String remoteKey,
  }) async {
    final Database db =
        await _database.database;

    return db.delete(
      DatabaseTables.materials,
      where:
          'user_id = ? AND remote_key = ? AND source <> ?',
      whereArgs: <Object?>[
        userId,
        remoteKey.trim(),
        MaterialSourceLocal.local.name,
      ],
    );
  }


  Future<int> deleteLocal(
    int id,
  ) async {
    final Database db =
        await _database.database;

    return db.delete(
      DatabaseTables.materials,
      where:
          'id = ? AND source = ?',
      whereArgs: <Object?>[
        id,
        MaterialSourceLocal.local.name,
      ],
    );
  }


  Future<int> deleteByUser(
    int userId,
  ) async {
    final Database db =
        await _database.database;

    return db.delete(
      DatabaseTables.materials,
      where:
          'user_id = ?',
      whereArgs: <Object?>[
        userId,
      ],
    );
  }


  static List<String> _extractStrings(
    List<Map<String, Object?>> result,
  ) {
    return result
        .map(
          (
            Map<String, Object?> row,
          ) =>
              row['value']?.toString().trim() ??
              '',
        )
        .where(
          (
            String value,
          ) =>
              value.isNotEmpty,
        )
        .toList();
  }


  static int _extractCount(
    List<Map<String, Object?>> result,
  ) {
    if (result.isEmpty) {
      return 0;
    }

    return _asInt(
          result.first['count'],
        ) ??
        0;
  }


  static int? _asInt(
    Object? value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ??
          '',
    );
  }
}