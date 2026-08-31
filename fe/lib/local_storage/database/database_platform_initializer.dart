import 'database_platform_initializer_stub.dart'
    if (dart.library.io) 'database_platform_initializer_io.dart'
    if (dart.library.js_interop) 'database_platform_initializer_web.dart'
    as platform;

Future<void> initializeDatabasePlatform() {
  return platform.initializeDatabasePlatform();
}
