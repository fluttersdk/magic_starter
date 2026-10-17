import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../http/controllers/magic_starter_releases_controller.dart';
import '../../../models/magic_starter_release.dart';
import '../../components/badge/index.dart';
import '../../components/button/index.dart';
import '../../components/card/index.dart';
import '../../components/empty_state/index.dart';
import '../../components/error_state/index.dart';
import '../../components/page_scaffold/index.dart';
import '../../components/skeleton/index.dart';
import '../../widgets/magic_starter_app_version.dart';

/// The "What's new" page: the app's release notes, newest first.
///
/// Loads the feed through [MagicStarterReleasesController.fetchReleases] on
/// open and renders one [MSCard] per release: the version, its date when the
/// backend has one, and each change as a toned [MSBadge] plus the copy in the
/// reader's language ([MagicStarterReleaseItem.textFor]). The running build is
/// captioned at the top by [MagicStarterAppVersion].
///
/// ## Failure mode
///
/// A failed read shows an [MSErrorState] with a retry that reads again; a feed
/// with no releases shows an [MSEmptyState]. Neither throws.
class MagicStarterChangelogView
    extends MagicStatefulView<MagicStarterReleasesController> {
  const MagicStarterChangelogView({super.key});

  @override
  State<MagicStarterChangelogView> createState() =>
      _MagicStarterChangelogViewState();
}

class _MagicStarterChangelogViewState
    extends
        MagicStatefulViewState<
          MagicStarterReleasesController,
          MagicStarterChangelogView
        > {
  static const _iconEmpty = Icons.new_releases_outlined;
  static const _iconError = Icons.error_outline;

  /// How many placeholder cards the loading state shows.
  static const int _skeletonCards = 3;

  @override
  void onInit() {
    controller.fetchReleases();
  }

  /// The badge tone for a kind of change.
  BadgeTone _toneFor(MagicStarterReleaseItemType type) {
    return switch (type) {
      MagicStarterReleaseItemType.newFeature => BadgeTone.primary,
      MagicStarterReleaseItemType.improved => BadgeTone.accent,
      MagicStarterReleaseItemType.fixed => BadgeTone.success,
    };
  }

  Widget _buildLoading() {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        for (var i = 0; i < _skeletonCards; i++) const MSSkeleton(height: 96),
      ],
    );
  }

  Widget _buildEmpty() {
    return MSEmptyState(
      icon: _iconEmpty,
      title: trans('magic_starter.releases.empty_title'),
      description: trans('magic_starter.releases.empty_description'),
    );
  }

  Widget _buildError(String message) {
    return MSErrorState(
      icon: _iconError,
      title: message,
      action: MSButton(
        intent: ButtonIntent.secondary,
        onPressed: controller.fetchReleases,
        child: WText(
          trans('magic_starter.releases.retry'),
          className: 'text-center',
        ),
      ),
    );
  }

  Widget _buildReleases(MagicStarterReleaseFeed feed) {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        for (final MagicStarterRelease release in feed.releases)
          _buildRelease(release),
      ],
    );
  }

  Widget _buildRelease(MagicStarterRelease release) {
    final DateTime? publishedAt = release.publishedAt;
    final String languageCode = Lang.current.languageCode;

    return MSCard(
      child: WDiv(
        className: 'flex flex-col gap-3',
        children: [
          WDiv(
            className: 'flex flex-row items-baseline gap-3',
            children: [
              WText(
                release.version,
                className: 'text-base font-semibold text-fg',
              ),
              if (publishedAt != null)
                WText(
                  Carbon.fromDateTime(
                    publishedAt.toLocal(),
                  ).toFormattedDateString(),
                  className: 'text-xs text-fg-muted',
                ),
            ],
          ),
          for (final MagicStarterReleaseItem item in release.items)
            WDiv(
              className: 'flex flex-row items-start gap-3',
              children: [
                MSBadge(
                  trans('magic_starter.releases.types.${item.type.key}'),
                  tone: _toneFor(item.type),
                ),
                WText(
                  item.textFor(languageCode),
                  className: 'flex-1 text-sm text-fg',
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MSPageScaffold(
      title: trans('magic_starter.titles.changelog'),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        const MagicStarterAppVersion(),
        controller.renderState(
          _buildReleases,
          onLoading: _buildLoading(),
          onEmpty: _buildEmpty(),
          onError: _buildError,
        ),
      ],
    );
  }
}
