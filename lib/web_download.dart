/// Exports the correct implementation based on the platform.
/// On web  → web_download_web.dart  (uses dart:html)
/// On other → web_download_stub.dart (throws if called)
export 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';
