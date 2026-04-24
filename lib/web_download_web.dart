// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers a browser file download on Flutter Web.
Future<void> downloadFileOnWeb(
  String filename,
  List<int> bytes,
  String mimeType,
) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
