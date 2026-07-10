// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> saveTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) async {
  final blob = html.Blob([content], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}
