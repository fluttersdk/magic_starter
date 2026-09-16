import 'package:flutter_test/flutter_test.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('sessionDeviceTitle', () {
    test('names a browser session by platform and browser', () {
      expect(
        sessionDeviceTitle(platform: 'Mac', browser: 'Chrome', app: ''),
        'Mac - Chrome',
      );
    });

    test('names a native session by platform and app', () {
      // The case this exists for. A native agent matched no browser pattern and
      // no platform pattern, so the row fell through to the section heading and
      // a phone's own session read "Browser Sessions" as the name of the
      // device, beside a laptop icon.
      expect(
        sessionDeviceTitle(platform: 'iOS', browser: '', app: 'Uptizm'),
        'iOS - Uptizm',
      );
    });

    test('prefers the browser when a response somehow carries both', () {
      // `SessionAgent` never sends both, so this pins the tie-break rather than
      // describing a shape the backend produces: a row showing "Chrome" is
      // right for a web session whatever else travelled with it.
      expect(
        sessionDeviceTitle(platform: 'Mac', browser: 'Chrome', app: 'Uptizm'),
        'Mac - Chrome',
      );
    });

    test('keeps the half it has when the platform is unreadable', () {
      expect(
        sessionDeviceTitle(platform: '', browser: 'Chrome', app: ''),
        'Chrome',
      );
      expect(
        sessionDeviceTitle(platform: '', browser: '', app: 'Uptizm'),
        'Uptizm',
      );
    });

    test('keeps the platform when the client is unreadable', () {
      expect(sessionDeviceTitle(platform: 'Mac', browser: '', app: ''), 'Mac');
    });

    test('answers empty when nothing is known, so the caller translates', () {
      // Empty rather than a word, because this package ships no catalogue and
      // a literal here would be English frozen into every app that installs it.
      expect(sessionDeviceTitle(platform: '', browser: '', app: ''), '');
    });
  });
}
