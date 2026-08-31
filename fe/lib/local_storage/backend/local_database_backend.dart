import 'local_database_backend_base.dart';
import 'local_database_backend_native.dart'
    if (dart.library.js_interop) 'local_database_backend_web.dart';

export 'local_database_backend_base.dart';

LocalDatabaseBackend createLocalDatabaseBackend() =>
    createPlatformLocalDatabaseBackend();
