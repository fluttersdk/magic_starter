import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/support/app_build.dart';
import 'package:magic_starter/src/ui/widgets/magic_starter_app_version.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The package's own English copy, so the caption renders real prose.
class _ShippedLoader implements TranslationLoader {
  const _ShippedLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    final raw = File(
      '${Directory.current.path}/assets/stubs/install/en.stub',
    ).readAsStringSync();

    return _flatten(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final Map<String, dynamic> result = <String, dynamic>{};

    for (final MapEntry<String, dynamic> entry in json.entries) {
      final String key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';

      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }

    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    MagicStarterAppBuild.resetForTesting();

    Magic.singleton('log', () => LogManager());
    Translator.instance.setLoader(const _ShippedLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  tearDown(() {
    MagicStarterAppBuild.resetForTesting();
    MagicApp.reset();
    Magic.flush();
  });

  void mockPackageInfo({String buildNumber = '34'}) {
    PackageInfo.setMockInitialValues(
      appName: 'Uptizm',
      packageName: 'com.example.app',
      version: '1.2.0',
      buildNumber: buildNumber,
      buildSignature: '',
    );
  }

  Future<void> mount(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WindTheme(
          data: WindThemeData(aliases: MagicStarterTokens.defaultAliases),
          child: Scaffold(body: widget),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('MagicStarterAppVersion', () {
    testWidgets('renders the native caption as Version 1.2.0 (34)', (
      tester,
    ) async {
      mockPackageInfo();
      MagicStarterAppBuild.debugIsWebOverride = false;

      await mount(tester, const MagicStarterAppVersion());

      expect(find.text('Version 1.2.0 (34)'), findsOneWidget);
    });

    testWidgets('renders the web caption with the dot separator', (
      tester,
    ) async {
      mockPackageInfo();
      MagicStarterAppBuild.debugIsWebOverride = true;

      await mount(tester, const MagicStarterAppVersion());

      expect(find.text('Version 1.2.0 · 34'), findsOneWidget);
    });

    testWidgets('renders just the version when the build number is empty', (
      tester,
    ) async {
      mockPackageInfo(buildNumber: '');
      MagicStarterAppBuild.debugIsWebOverride = false;

      await mount(tester, const MagicStarterAppVersion());

      expect(find.text('Version 1.2.0'), findsOneWidget);
    });

    testWidgets('renders nothing while the package info is pending', (
      tester,
    ) async {
      mockPackageInfo();

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(aliases: MagicStarterTokens.defaultAliases),
            child: const Scaffold(body: MagicStarterAppVersion()),
          ),
        ),
      );

      expect(find.byType(WText), findsNothing);

      await tester.pumpAndSettle();

      expect(find.byType(WText), findsOneWidget);
    });

    testWidgets('accepts a className override', (tester) async {
      mockPackageInfo();
      MagicStarterAppBuild.debugIsWebOverride = false;

      await mount(
        tester,
        const MagicStarterAppVersion(className: 'text-xs text-left'),
      );

      final WText text = tester.widget<WText>(find.byType(WText));

      expect(text.className, 'text-xs text-left');
    });
  });
}
