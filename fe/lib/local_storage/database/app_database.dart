import 'package:sqflite_common/sqlite_api.dart';

import '../backend/local_database_backend.dart';

import 'database_migrations.dart';
import 'database_tables.dart';


class AppDatabase {
  AppDatabase._();


  static final AppDatabase instance =
      AppDatabase._();


  static Database? _database;


  static const int _databaseVersion =
      8;

  final LocalDatabaseBackend _backend =
      createLocalDatabaseBackend();


  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database =
        await _initDatabase();

    return _database!;
  }


  Future<Database> _initDatabase() async {
    await _backend.initialize();

    return _backend.open(
      name: 'studentlab.db',
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: DatabaseMigrations.onUpgrade,
      onConfigure: _onConfigure,
    );
  }


  Future<void> _onConfigure(
    Database db,
  ) async {
    await db.execute(
      'PRAGMA foreign_keys = ON',
    );
  }


  Future<void> _onCreate(
    Database db,
    int version,
  ) async {
    await db.execute(
      '''
      CREATE TABLE ${DatabaseTables.materialFiles} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        local_path TEXT NOT NULL,

        file_hash TEXT,

        size INTEGER,

        mime_type TEXT,

        exists_locally INTEGER NOT NULL DEFAULT 1,

        created_at TEXT NOT NULL,

        updated_at TEXT NOT NULL,

        UNIQUE(local_path)
      )
      ''',
    );

    await db.execute(
      '''
      CREATE TABLE ${DatabaseTables.materials} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER NOT NULL,

        source TEXT NOT NULL,

        remote_key TEXT,

        remote_id INTEGER,

        subject_id INTEGER,

        group_id INTEGER,

        university TEXT,

        department TEXT,

        course TEXT,

        subject_name TEXT,

        original_name TEXT NOT NULL,

        file_id INTEGER,

        remote_version INTEGER,

        remote_status TEXT,

        is_available_remote INTEGER NOT NULL DEFAULT 0,

        is_personal INTEGER NOT NULL DEFAULT 0,

        created_at TEXT NOT NULL,

        updated_at TEXT NOT NULL,

        last_synced_at TEXT,

        FOREIGN KEY(file_id)
          REFERENCES ${DatabaseTables.materialFiles}(id)
          ON DELETE SET NULL,

        CHECK(
          source IN (
            'local',
            'public',
            'teacher',
            'group'
          )
        ),

        CHECK(
          is_available_remote IN (
            0,
            1
          )
        ),

        CHECK(
          is_personal IN (
            0,
            1
          )
        ),

        UNIQUE(
          user_id,
          remote_key
        )
      )
      ''',
    );

    await db.execute(
      '''
      CREATE TABLE ${DatabaseTables.materialDownloads} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER NOT NULL,

        material_id INTEGER NOT NULL,

        status TEXT NOT NULL DEFAULT 'pending',

        temp_path TEXT,

        expected_hash TEXT,

        expected_size INTEGER,

        downloaded_bytes INTEGER NOT NULL DEFAULT 0,

        started_at TEXT,

        completed_at TEXT,

        error_message TEXT,

        FOREIGN KEY(material_id)
          REFERENCES ${DatabaseTables.materials}(id)
          ON DELETE CASCADE,

        CHECK(
          status IN (
            'pending',
            'downloading',
            'verifying',
            'completed',
            'failed'
          )
        )
      )
      ''',
    );

    await db.execute(
      '''
      CREATE TABLE ${DatabaseTables.materialSyncState} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER NOT NULL UNIQUE,

        last_manifest_at TEXT,

        last_successful_sync_at TEXT,

        updated_at TEXT NOT NULL
      )
      ''',
    );

    await db.execute(
      '''
      CREATE TABLE ${DatabaseTables.pendingUploads} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER NOT NULL,

        group_id INTEGER NOT NULL,

        local_path TEXT NOT NULL,

        original_name TEXT NOT NULL,

        mime_type TEXT,

        size INTEGER,

        status TEXT NOT NULL DEFAULT 'pending',

        created_at TEXT NOT NULL,

        uploaded_at TEXT,

        server_material_id INTEGER,

        error_message TEXT,

        retry_count INTEGER NOT NULL DEFAULT 0,

        last_attempt_at TEXT
      )
      ''',
    );

    await db.execute(
      '''
      CREATE TABLE ${DatabaseTables.localFileBlobs} (
        path TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        mime_type TEXT,
        data BLOB NOT NULL,
        size INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_local_file_blobs_updated
      ON ${DatabaseTables.localFileBlobs}(updated_at)
      ''',
    );

    await db.execute(
      '''
      CREATE UNIQUE INDEX
      idx_material_files_hash
      ON ${DatabaseTables.materialFiles}(
        file_hash
      )
      WHERE file_hash IS NOT NULL
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_materials_user
      ON ${DatabaseTables.materials}(
        user_id
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_materials_user_source
      ON ${DatabaseTables.materials}(
        user_id,
        source
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_materials_user_subject
      ON ${DatabaseTables.materials}(
        user_id,
        subject_id
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_materials_user_group
      ON ${DatabaseTables.materials}(
        user_id,
        group_id
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_materials_remote_id
      ON ${DatabaseTables.materials}(
        source,
        remote_id
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_materials_file_id
      ON ${DatabaseTables.materials}(
        file_id
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_materials_available_remote
      ON ${DatabaseTables.materials}(
        user_id,
        is_available_remote
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_material_downloads_user_status
      ON ${DatabaseTables.materialDownloads}(
        user_id,
        status
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_material_downloads_material
      ON ${DatabaseTables.materialDownloads}(
        material_id
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_material_sync_state_user
      ON ${DatabaseTables.materialSyncState}(
        user_id
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_pending_uploads_user_status
      ON ${DatabaseTables.pendingUploads}(
        user_id,
        status
      )
      ''',
    );

    await db.execute(
      '''
      CREATE INDEX
      idx_pending_uploads_group
      ON ${DatabaseTables.pendingUploads}(
        group_id
      )
      ''',
    );

    await DatabaseMigrations.createQuizSchema(
      db,
    );
  }


  Future<void> close() async {
    final Database? db =
        _database;

    if (db == null) {
      return;
    }

    await db.close();

    _database =
        null;
  }
}