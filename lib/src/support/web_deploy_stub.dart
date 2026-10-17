/// Non-web platforms have no deployed bundle, so there is no build to compare:
/// always `null`.
///
/// [url] exists to match the web implementation's signature and is ignored.
Future<String?> fetchDeployedBuildNumber({Uri? url}) async => null;

/// Non-web platforms have no page to reload: does nothing.
void reloadPage() {}
