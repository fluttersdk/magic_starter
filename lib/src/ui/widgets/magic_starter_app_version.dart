import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/app_build.dart';

/// A one-line caption naming the build the app is running, such as
/// `Version 1.2.0 (34)`.
///
/// Reads the package info through [MagicStarterAppBuild.info] and formats it
/// with [MagicStarterAppBuild.label], so the caption matches what the support
/// conversation reports. The starter shows it on the settings hub and the
/// changelog page; a host app that wants it elsewhere places the widget itself.
///
/// The read starts once, when the caption mounts; a rebuild reuses it.
///
/// ## Failure mode
///
/// Renders nothing while the read is pending and when the platform cannot
/// answer, so a caption never shows a placeholder or an error.
class MagicStarterAppVersion extends StatefulWidget {
  /// The Wind className of the caption, replacing the default (a small, muted,
  /// centred line).
  final String? className;

  /// Creates a [MagicStarterAppVersion].
  const MagicStarterAppVersion({super.key, this.className});

  @override
  State<MagicStarterAppVersion> createState() => _MagicStarterAppVersionState();
}

class _MagicStarterAppVersionState extends State<MagicStarterAppVersion> {
  /// The default caption style; `text-fg-muted` carries its dark pair.
  static const String _defaultClassName = 'text-xs text-fg-muted text-center';

  late final Future<PackageInfo?> _info;

  @override
  void initState() {
    super.initState();

    _info = MagicStarterAppBuild.info();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo?>(
      future: _info,
      builder: (context, snapshot) {
        final PackageInfo? info = snapshot.data;
        if (info == null) {
          return const SizedBox.shrink();
        }

        return WText(
          trans('magic_starter.releases.version_caption', {
            'version': MagicStarterAppBuild.label(info),
          }),
          className: widget.className ?? _defaultClassName,
        );
      },
    );
  }
}
