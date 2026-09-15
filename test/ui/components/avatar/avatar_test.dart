import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Minimal authenticated user for the fake auth manager, mirroring the
/// `_FakeUser` helper in `test/middleware/redirect_if_authenticated_test.dart`.
class _FakeUser extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => ['id', 'name', 'email', 'profile_photo_url'];
}

_FakeUser _fakeUser({String? photoUrl}) {
  final user = _FakeUser();
  user.fill({
    'id': 1,
    'name': 'Anilcan Cakir',
    'email': 'a@example.test',
    if (photoUrl != null) 'profile_photo_url': photoUrl,
  });
  user.exists = true;

  return user;
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Config.set('wind.colors.primary', 'indigo');
  });

  Widget wrap(Widget widget) {
    final themeData = WindThemeData(colors: {'primary': Colors.indigo});
    return WindTheme(
      data: themeData,
      child: MaterialApp(
        theme: themeData.toThemeData(),
        home: Scaffold(body: Center(child: widget)),
      ),
    );
  }

  group('MSAvatar', () {
    testWidgets('renders the photo when there is one', (tester) async {
      await tester.pumpWidget(
        wrap(
          const MSAvatar(
            photoUrl: 'https://example.test/avatar.png',
            className: 'w-8 h-8 rounded-full',
            fallback: WText('AC'),
          ),
        ),
      );

      expect(find.byType(WImage), findsOneWidget);
      expect(find.text('AC'), findsNothing);
    });

    testWidgets('falls back when there is no photo', (tester) async {
      await tester.pumpWidget(
        wrap(
          const MSAvatar(
            className: 'w-8 h-8 rounded-full',
            fallback: WText('AC'),
          ),
        ),
      );

      expect(find.text('AC'), findsOneWidget);
      expect(find.byType(WImage), findsNothing);
    });

    testWidgets('treats an empty url as no photo', (tester) async {
      // An API that clears a photo commonly answers `''` rather than null, and
      // a bare null check would then render an image widget pointed at nothing.
      await tester.pumpWidget(
        wrap(
          const MSAvatar(
            photoUrl: '',
            className: 'w-8 h-8 rounded-full',
            fallback: WText('AC'),
          ),
        ),
      );

      expect(find.text('AC'), findsOneWidget);
      expect(find.byType(WImage), findsNothing);
    });

    testWidgets('clips, so the shape applies to the photo', (tester) async {
      // Without `overflow-hidden` from the recipe base the rounding reaches
      // only the background behind the image, and a square photo sits inside a
      // circular frame.
      await tester.pumpWidget(
        wrap(
          const MSAvatar(
            photoUrl: 'https://example.test/avatar.png',
            className: 'w-8 h-8 rounded-full',
            fallback: WText('AC'),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsWidgets);
    });
  });

  group('MSUserProfileDropdown', () {
    testWidgets('shows the signed-in account photo in its trigger', (
      tester,
    ) async {
      // The one control on screen at all times drew the initial whatever the
      // account carried, so a person who had uploaded a photo saw it on the
      // profile screen and nowhere else.
      Auth.fake(user: _fakeUser(photoUrl: 'https://example.test/me.png'));

      await tester.pumpWidget(wrap(const MSUserProfileDropdown()));

      expect(find.byType(MSAvatar), findsOneWidget);
      expect(
        tester.widget<MSAvatar>(find.byType(MSAvatar)).photoUrl,
        'https://example.test/me.png',
      );
    });

    testWidgets('falls back to the initial with no photo', (tester) async {
      Auth.fake(user: _fakeUser());

      await tester.pumpWidget(wrap(const MSUserProfileDropdown()));

      expect(find.text('A'), findsOneWidget);
    });
  });
}
