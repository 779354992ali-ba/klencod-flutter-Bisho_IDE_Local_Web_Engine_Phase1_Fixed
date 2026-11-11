
import 'dart:typed_data';

import 'package:saf/saf.dart';

class SafFileService {
  final Saf _saf = Saf();

  // اختيار مجلد المشروع
  Future<SafDocumentFile?> pickProjectFolder() async {
    return _saf.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
  }

  // اختيار ملف
  Future<SafDocumentFile?> pickFile() async {
    return _saf.pickFile(
      persistablePermission: true,
    );
  }

  // استرجاع جميع صلاحيات SAF المحفوظة
  Future<List<SafPersistedPermission>>
      getPersistedPermissions() async {
    return _saf.persistedPermissions();
  }

  // عرض محتويات مجلد
  Future<List<SafDocumentFile>> listDirectory(
    String directoryUri,
  ) async {
    return _saf.list(directoryUri);
  }

  // قراءة ملف
  Future<Uint8List> readFile(String fileUri) async {
    return _saf.readFileBytes(fileUri);
  }

  // حفظ ملف
  Future<SafDocumentFile> saveFile({
    required String parentUri,
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    bool overwrite = true,
  }) async {
    return _saf.writeFileBytes(
      parentUri,
      fileName,
      mimeType,
      bytes,
      overwrite: overwrite,
    );
  }

  // إنشاء مجلد
  Future<SafDocumentFile> createFolder({
    required String parentUri,
    required String folderName,
  }) async {
    return _saf.mkdirp(
      parentUri,
      [folderName],
    );
  }

  // حذف ملف أو مجلد
  Future<void> deleteItem(String uri) async {
    await _saf.delete(uri);
  }

  // إعادة تسمية
  Future<SafDocumentFile> renameItem({
    required String uri,
    required String newName,
  }) async {
    return _saf.rename(uri, newName);
  }

  // البحث عن عنصر داخل مجلد
  Future<SafDocumentFile?> findChild({
    required String parentUri,
    required String name,
  }) async {
    return _saf.child(
      parentUri,
      [name],
    );
  }

  // الحصول على معلومات ملف أو مجلد
  Future<SafDocumentFile?> getItem(String uri) async {
    return _saf.stat(uri);
  }
}