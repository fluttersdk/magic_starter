import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'avatar.dart';

/// Static variant-matrix preview for [MSAvatar].
///
/// The axes that matter are photo-or-fallback and the shape the caller asks
/// for, so the matrix crosses those rather than a variant enum this component
/// deliberately does not have. The photo row uses a remote placeholder, so an
/// offline catalog run exercises the error path instead: that is the same
/// fallback a 404 or an expired signed link produces in the app, and seeing it
/// here is worth more than a blank cell.
class AvatarPreview extends StatelessWidget {
  /// Creates the avatar variant-matrix preview.
  const AvatarPreview({super.key});

  static const String _photo = 'https://i.pravatar.cc/160';
  static const IconData _iconPerson = Icons.person_outline;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        _row('with a photo', <Widget>[
          const MSAvatar(
            photoUrl: _photo,
            className: 'w-8 h-8 rounded-full bg-surface-container-high',
            fallback: WText('AC', className: 'text-xs font-bold text-fg'),
          ),
          const MSAvatar(
            photoUrl: _photo,
            className: 'w-12 h-12 rounded-full bg-surface-container-high',
            fallback: WText('AC', className: 'text-sm font-bold text-fg'),
          ),
          const MSAvatar(
            photoUrl: _photo,
            className: 'w-20 h-20 rounded-full bg-surface-container-high',
            fallback: WText('AC', className: 'text-xl font-bold text-fg'),
          ),
        ]),
        _row('initials fallback', <Widget>[
          const MSAvatar(
            className: 'w-8 h-8 rounded-full bg-primary',
            fallback: WText(
              'A',
              className: 'text-xs font-bold text-on-primary',
            ),
          ),
          const MSAvatar(
            className: 'w-12 h-12 rounded-full bg-primary',
            fallback: WText(
              'AC',
              className: 'text-sm font-bold text-on-primary',
            ),
          ),
        ]),
        _row('glyph fallback', <Widget>[
          MSAvatar(
            className: 'w-20 h-20 rounded-full bg-surface-container-high',
            fallback: WIcon(
              _iconPerson,
              className: 'text-fg-muted text-3xl',
            ),
          ),
        ]),
        _row('a team, squared off', <Widget>[
          const MSAvatar(
            className: 'w-9 h-9 rounded-lg bg-accent',
            fallback: WText(
              'U',
              className: 'text-sm font-bold text-on-primary',
            ),
          ),
          const MSAvatar(
            photoUrl: _photo,
            className: 'w-9 h-9 rounded-lg bg-accent',
            fallback: WText(
              'U',
              className: 'text-sm font-bold text-on-primary',
            ),
          ),
        ]),
      ],
    );
  }

  Widget _row(String label, List<Widget> children) {
    return WDiv(
      className: 'flex flex-col gap-2',
      children: [
        WText(label, className: 'text-xs font-medium text-fg-muted'),
        WDiv(
          className: 'flex flex-row items-center gap-4',
          children: children,
        ),
      ],
    );
  }
}
