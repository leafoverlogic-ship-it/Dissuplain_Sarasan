import 'browser_download_stub.dart'
    if (dart.library.html) 'browser_download_web.dart';

Future<bool> downloadTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) {
  return saveTextFile(fileName: fileName, content: content, mimeType: mimeType);
}
