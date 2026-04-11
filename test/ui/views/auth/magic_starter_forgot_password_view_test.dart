import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver — intercepts all Http facade calls
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;

  String? lastMethod;
  String? lastUrl;
  dynamic lastData;

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(data: data ?? {}, statusCode: statusCode);
  }

  MagicResponse _respond(String method, String url, {dynamic data}) {
    lastMethod = method;
    lastUrl = url;
    lastData = data;
    return nextResponse ?? MagicResponse(data: {}, statusCode: 500);
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async =>
      _respond('GET', url);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async =>
      _respond('DELETE', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      _respond('INDEX', resource);

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async =>
      _respond('UPLOAD', url, data: data);
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

  group('MagicStarterForgotPasswordView', () {
    late MockNetworkDriver mockDriver;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('network', () => MockNetworkDriver());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.put(MagicStarterAuthController());

      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    });

    // -----------------------------------------------------------------------
    // Empty state rendering
    // -----------------------------------------------------------------------

    testWidgets('renders email field, submit button, and back-to-login link', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      // Email input field.
      expect(
        find.widgetWithText(WFormInput, trans('attributes.email')),
        findsOneWidget,
      );

      // Submit button.
      expect(
        find.widgetWithText(WButton, trans('auth.send_reset_link')),
        findsOneWidget,
      );

      // Back to login link.
      expect(find.text(trans('auth.back_to_login')), findsOneWidget);
    });

    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      expect(find.text(trans('auth.forgot_password_title')), findsOneWidget);
      expect(find.text(trans('auth.forgot_password_subtitle')), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Form validation
    // -----------------------------------------------------------------------

    testWidgets('does not call controller when email is empty', (tester) async {
      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      // Tap submit without entering email.
      await tester.tap(
        find.widgetWithText(WButton, trans('auth.send_reset_link')),
      );
      await tester.pumpAndSettle();

      // Controller was never called — no HTTP request made.
      expect(mockDriver.lastMethod, isNull);
      expect(mockDriver.lastUrl, isNull);
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

      // Enter a valid email.
      await tester.enterText(
        find.widgetWithText(WFormInput, trans('attributes.email')),
        'alice@example.com',
      );

      // Submit the form.
      await tester.tap(
        find.widgetWithText(WButton, trans('auth.send_reset_link')),
      );
      await tester.pumpAndSettle();

      // Success confirmation message is visible.
      expect(find.text(trans('auth.reset_link_sent')), findsOneWidget);

      // Check icon is rendered.
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // Back to login link is still available.
      expect(find.text(trans('auth.back_to_login')), findsOneWidget);

      // The email form field is gone (replaced by success state).
      expect(
        find.widgetWithText(WFormInput, trans('attributes.email')),
        findsNothing,
      );
    });

    // -----------------------------------------------------------------------
    // Error state
    // -----------------------------------------------------------------------

    testWidgets('shows error banner after failed submission', (tester) async {
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

      // Enter a valid email.
      await tester.enterText(
        find.widgetWithText(WFormInput, trans('attributes.email')),
        'nobody@example.com',
      );

      // Submit the form.
      await tester.tap(
        find.widgetWithText(WButton, trans('auth.send_reset_link')),
      );
      await tester.pumpAndSettle();

      // Form is still visible (not replaced by success).
      expect(
        find.widgetWithText(WFormInput, trans('attributes.email')),
        findsOneWidget,
      );

      // Success state is NOT shown.
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    // -----------------------------------------------------------------------
    // Loading state
    // -----------------------------------------------------------------------

    testWidgets('submit button receives isLoading from controller', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const MagicStarterForgotPasswordView()));
      await tester.pumpAndSettle();

      // In empty state, the button should not be loading.
      final button = tester.widget<WButton>(
        find.widgetWithText(WButton, trans('auth.send_reset_link')),
      );
      expect(button.isLoading, isFalse);
    });
  });
}
