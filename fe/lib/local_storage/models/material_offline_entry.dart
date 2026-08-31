import 'material_file_local.dart';
import 'material_local.dart';

class MaterialOfflineEntry {
  final MaterialLocal material;
  final MaterialFileLocal file;

  const MaterialOfflineEntry({
    required this.material,
    required this.file,
  });

  int? get materialId => material.id;
  int? get remoteId => material.remoteId;
  int? get fileId => file.id;

  String get originalName => material.originalName;
  String get localPath => file.localPath;
  String? get mimeType => file.mimeType;
  int? get size => file.size;
  String? get fileHash => file.fileHash;
  bool get existsLocally => file.existsLocally;
}