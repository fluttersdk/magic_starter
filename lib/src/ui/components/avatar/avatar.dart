import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'avatar.recipe.dart';

/// **The Shared Avatar**
///
/// One answer to "show this person's photo, and something sensible when there
/// is not one". Every surface in a starter app that draws a user or a team had
/// its own answer before this, and three of them had no photo branch at all:
/// the header dropdown rendered an initial whatever the account carried, and a
/// host app's own shell did the same in its sidebar and top bar. The photo
/// showed on the profile screen and nowhere else, so uploading one looked like
/// it had not worked.
///
/// The component owns exactly two things: clipping the photo to the box, and
/// choosing between the photo and the [fallback]. It owns no size, no shape and
/// no colour, because those genuinely differ per surface (32 logical pixels in
/// a header against 80 on a profile screen, a circle for a person against a
/// rounded square for a team) and a variant axis over them would be a list
/// nobody could finish.
///
/// [fallback] is a widget rather than a string for the same reason. The
/// initials rule is not shared: this package takes one letter, a host app takes
/// the first letter of each of the first two words. Handing the rendered
/// fallback in keeps both correct instead of making one of them wrong.
///
/// A photo that fails to load falls back too, so a broken or expired URL shows
/// the initial rather than a grey box.
///
/// ### Example
/// ```dart
/// MSAvatar(
///   photoUrl: user.profilePhotoUrl,
///   className: 'w-8 h-8 rounded-full bg-primary',
///   fallback: WText(initials, className: 'text-sm font-bold text-on-primary'),
/// )
/// ```
@immutable
class MSAvatar extends StatelessWidget {
  /// The photo to render. Null or empty falls back.
  final String? photoUrl;

  /// What to render when there is no photo, or when one fails to load.
  final Widget fallback;

  /// The box: size, shape, and the fallback's background.
  ///
  /// Appended after the recipe base, so a rounding token here is what decides
  /// the photo's shape as well.
  final String? className;

  /// Creates an [MSAvatar].
  const MSAvatar({
    super.key,
    this.photoUrl,
    required this.fallback,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    final String? url = photoUrl;
    final bool hasPhoto = url != null && url.isNotEmpty;

    return WDiv(
      className: avatarRecipe(className: className),
      child: hasPhoto
          ? WImage(
              src: url,
              className: 'w-full h-full object-cover',
              // A URL that 404s or expires is ordinary rather than
              // exceptional: a photo deleted on another device, a signed link
              // past its window. Showing the fallback is the same answer as
              // having no photo, which is what the account now effectively has.
              errorBuilder: (context, error, stackTrace) => fallback,
            )
          : fallback,
    );
  }
}
