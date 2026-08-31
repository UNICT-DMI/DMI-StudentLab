import 'package:file_picker/file_picker.dart';

import '../local_storage/services/local_file_service.dart';

class PickedFileBridge {
  final LocalFileService _files;

  PickedFileBridge({LocalFileService? files})
      : _files = files ?? LocalFileService();

  Future<String> materialize(
    PlatformFile file, {
    String? mimeType,
  }) async {
    final String? nativePath = file.path;
    if (nativePath != null && nativePath.trim().isNotEmpty) {
      return nativePath;
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError(
        'Il browser non ha reso disponibile il contenuto del file selezionato.',
      );
    }

    return _files.saveTransientFile(
      fileName: file.name,
      bytes: bytes,
      mimeType: mimeType,
    );
  }
}
