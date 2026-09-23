/// Names the device behind one session row, or `''` when nothing is known.
///
/// Platform first, then whichever client this is: a browser name for a web
/// session, the application's own name for a native one. The two are mutually
/// exclusive by construction (`SessionAgent` leaves `browser` empty for a
/// native agent and `app` empty for a browser), so the result reads
/// "Mac - Chrome" or "iOS - Uptizm" and never both.
///
/// Empty rather than a word when every part is, because the caller is the only
/// side that can translate and the package ships no catalogue. The caller's
/// fallback is `profile.unknown_device`, and that key exists because the
/// fallback used to be the SECTION HEADING: a row in a Turkish app read
/// "Tarayıcı Oturumları" as the name of a device, directly beneath a heading
/// saying the same words.
///
/// It lives in `support/` rather than beside either caller because BOTH screens
/// that draw sessions need it and both are publishable. A published copy keeps
/// its imports verbatim, so a helper reachable only through a private `src/`
/// path would leave the host choosing between an `implementation_imports`
/// violation and reimplementing the rule, which is the drift this exists to
/// end. Exported from the package barrel for the same reason.
String sessionDeviceTitle({
  required String platform,
  required String browser,
  required String app,
}) {
  final String client = browser.trim().isNotEmpty ? browser : app;

  // A part made only of whitespace is as unknown as an empty one; kept, it
  // rendered as "Mac -  " with a dangling separator.
  return <String>[platform, client]
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .join(' - ');
}
