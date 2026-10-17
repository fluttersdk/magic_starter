/// The deployed web bundle, as the running page can see it.
///
/// Conditional export: the web implementation fetches `version.json` and
/// reloads the page through `package:web`; every other platform gets a stub
/// that does nothing, so no `dart:js_interop` reaches a mobile build.
///
/// Both implementations expose `Future<String?> fetchDeployedBuildNumber({Uri?
/// url})` and `void reloadPage()`.
library;

export 'web_deploy_stub.dart'
    if (dart.library.js_interop) 'web_deploy_web.dart';
