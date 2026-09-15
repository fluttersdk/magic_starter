import 'package:magic/magic.dart';

/// Builds the avatar [WindRecipe].
///
/// The base carries only what is true of every avatar: clip the photo to the
/// box, and centre the fallback inside it. `overflow-hidden` is what makes the
/// rounding apply to the image rather than only to the background behind it.
///
/// Size, shape and the fallback's own colours are NOT here. An avatar is 32
/// logical pixels in a header, 80 on a profile screen, a circle for a person
/// and a rounded square for a team, and the fallback is a white initial on the
/// brand in one place and a muted glyph on a container surface in another.
/// Every one of those is the caller's decision, so they arrive as `className`
/// and as the fallback widget rather than as variants nobody could enumerate.
///
/// Emission order: base then the caller's className.
const WindRecipe avatarRecipe = WindRecipe(
  base: 'overflow-hidden flex items-center justify-center shrink-0',
);
