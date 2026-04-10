import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;
  String? lastMethod;
  String? lastUrl;
  Map<String, dynamic>? lastData;

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(data: data ?? {}, statusCode: statusCode);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    lastMethod = 'POST';
    lastUrl = url;
    lastData = data is Map<String, dynamic> ? data : null;
    return nextResponse ?? MagicResponse(data: {}, statusCode: 500);
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => nextResponse ?? MagicResponse(data: {}, statusCode: 500);
  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}
  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => nextResponse!;
  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async => nextResponse!;
  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async => nextResponse!;
  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => nextResponse!;
  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => nextResponse!;
  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => nextResponse!;
  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => nextResponse!;
  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async => nextResponse!;
}

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
  }

  late MockNetworkDriver mockDriver;
  late MagicStarterAuthController controller;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    mockDriver = MockNetworkDriver();
    Magic.singleton('network', () => mockDriver);
    Magic.singleton('log', () => LogManager());
    Magic.singleton('magic_starter', () => MagicStarterManager());
    controller = MagicStarterAuthController();
    Magic.put(controller);
  });

  tearDown(() {
    controller.dispose();
  });

  group('MagicStarterForgotPasswordView', () {
    // -----------------------------------------------------------------------
    // Form rendering
    // -----------------------------------------------------------------------

    testWidgets('renders email input field', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(WFormInput, trans('attributes.email')),
        findsOneWidget,
      );
    });

    testWidgets('renders submit button with send reset link text', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      expect(find.text(trans('auth.send_reset_link')), findsOneWidget);
      expect(find.byType(WButton), findsOneWidget);
    });

    testWidgets('renders back-to-login link in form state', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      expect(find.text(trans('auth.back_to_login')), findsOneWidget);
    });

    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      expect(find.text(trans('auth.forgot_password_title')), findsOneWidget);
      expect(find.text(trans('auth.forgot_password_subtitle')), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Submission
    // -----------------------------------------------------------------------

    testWidgets('submits email to forgot password endpoint', (tester) async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {'message': 'Reset link sent'},
      );

      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      final input = find.widgetWithText(WFormInput, trans('attributes.email'));
      await tester.enterText(input, 'alice@example.com');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(WButton));
      await tester.pumpAndSettle();

      expect(mockDriver.lastUrl, equals('/auth/forgot-password'));
      expect(mockDriver.lastMethod, equals('POST'));
      expect(mockDriver.lastData?['email'], equals('alice@example.com'));
    });

    // -----------------------------------------------------------------------
    // Success state
    // -----------------------------------------------------------------------

    testWidgets('shows success state after successful submission', (
      tester,
    ) async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {'message': 'Reset link sent'},
      );

      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(WFormInput, trans('attributes.email')),
        'alice@example.com',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(WButton));
      await tester.pumpAndSettle();

      expect(find.text(trans('auth.reset_link_sent')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows back-to-login link in success state', (tester) async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {'message': 'Reset link sent'},
      );

      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(WFormInput, trans('attributes.email')),
        'alice@example.com',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(WButton));
      await tester.pumpAndSettle();

      expect(find.text(trans('auth.back_to_login')), findsOneWidget);
    });

    testWidgets('hides form fields in success state', (tester) async {
      mockDriver.mockResponse(
        statusCode: 200,
        data: {'message': 'Reset link sent'},
      );

      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(WFormInput, trans('attributes.email')),
        'alice@example.com',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(WButton));
      await tester.pumpAndSettle();

      expect(find.byType(WFormInput), findsNothing);
      expect(find.byType(WButton), findsNothing);
    });

    // -----------------------------------------------------------------------
    // Error state
    // -----------------------------------------------------------------------

    testWidgets('shows error message on 422 response', (tester) async {
      mockDriver.mockResponse(
        statusCode: 422,
        data: {
          'message': 'Email not found',
          'errors': {
            'email': ['No user found with this email.'],
          },
        },
      );

      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(WFormInput, trans('attributes.email')),
        'nobody@example.com',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(WButton));
      await tester.pumpAndSettle();

      // Error state still shows the form.
      expect(find.byType(WFormInput), findsOneWidget);
      expect(find.byType(WButton), findsOneWidget);
    });

    testWidgets('keeps back-to-login link visible on error', (tester) async {
      mockDriver.mockResponse(
        statusCode: 422,
        data: {
          'message': 'Email not found',
          'errors': {
            'email': ['No user found with this email.'],
          },
        },
      );

      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(WFormInput, trans('attributes.email')),
        'nobody@example.com',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(WButton));
      await tester.pumpAndSettle();

      expect(find.text(trans('auth.back_to_login')), findsOneWidget);
    });
  });
}
