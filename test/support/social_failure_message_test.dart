import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/support/social_failure_message.dart';

class _MapLoader implements TranslationLoader {
  const _MapLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async => {
    'social.flow_expired': 'Your sign-in took too long. Try again.',
    'errors.unexpected': 'Something went wrong.',
  };
}

void main() {
  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    Translator.instance.setLoader(const _MapLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  group('socialFailureMessage', () {
    test('a code the catalogue knows shows its sentence', () {
      expect(
        socialFailureMessage(
          const MagicStarterSocialException(
            code: 'flow_expired',
            message: 'ignored',
          ),
        ),
        'Your sign-in took too long. Try again.',
      );
    });

    test('a code the catalogue lacks shows the bridge message', () {
      expect(
        socialFailureMessage(
          const MagicStarterSocialException(
            code: 'brand_new_code',
            message: 'The bridge says so.',
          ),
        ),
        'The bridge says so.',
      );
    });

    test('an uncoded failure shows the bridge message', () {
      expect(
        socialFailureMessage(
          const MagicStarterSocialException(message: 'No network.'),
        ),
        'No network.',
      );
    });

    test('with neither a sentence nor a message it is the generic failure', () {
      expect(
        socialFailureMessage(const MagicStarterSocialException(code: 'x')),
        'Something went wrong.',
      );
    });
  });
}
