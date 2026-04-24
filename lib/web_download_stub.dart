// Stub for non-web platforms — never called because of kIsWeb guard.
Future<void> downloadFileOnWeb(
  String filename,
  List<int> bytes,
  String mimeType,
) async {
  throw UnsupportedError('downloadFileOnWeb is only available on web.');
}
