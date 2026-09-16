import 'package:magic/magic.dart';

/// Builds the avatar [WindRecipe].
///
/// The base carries only what is true of every avatar: clip the photo to the
/// box. `overflow-hidden` is what makes the rounding apply to the image rather
/// than only to the background behind it.
///
/// NO FLEX HERE, and that is load-bearing rather than tidy. The base used to
/// carry `flex items-center justify-center` to centre the fallback, and it
/// starved the photo: inside a wind flex, a child asking for `w-full` gets the
/// SCREEN width rather than its parent's, and `h-full` collapses on the cross
/// axis. Measured on a 36px avatar, the image laid out 905.8 x 28.0 instead of
/// 36 x 36, so the clip showed one horizontal band of the photo with the
/// background above and below it: reported off a TestFlight build as an avatar
/// that was "not round, cut on the left and right". The centring moved into the
/// fallback branch, which is the only branch that needed it.
///
/// Size, shape and the fallback's own colours are NOT here. An avatar is 32
/// logical pixels in a header, 80 on a profile screen, a circle for a person
/// and a rounded square for a team, and the fallback is a white initial on the
/// brand in one place and a muted glyph on a container surface in another.
/// Every one of those is the caller's decision, so they arrive as `className`
/// and as the fallback widget rather than as variants nobody could enumerate.
///
/// Emission order: base then the caller's className.
const WindRecipe avatarRecipe = WindRecipe(base: 'overflow-hidden shrink-0');
