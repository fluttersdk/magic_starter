import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../../configuration/magic_starter_config.dart';
import '../../../../facades/magic_starter.dart';
import '../../../../http/controllers/magic_starter_profile_controller.dart';
import '../../../../support/confirms_identity.dart';
import '../../../components/page_scaffold/page_scaffold.dart';
import '../../../components/settings_section/settings_section.dart';

/// Connected accounts settings sub-page.
///
/// Drilled into from the Settings hub, which shows its row only while the
/// `social_login` feature is on and the app has set a social login bridge
/// (`MagicStarter.useSocialAuth`). The route itself is registered on the
/// feature alone, so a page opened with no bridge renders empty. Lists the
/// bridge's providers: a linked one
/// (from the user's `social_accounts`, `revoked_at` null) shows the address it
/// was linked with and Disconnect; an unlinked one shows Connect.
///
/// Disconnect is disabled for a password-less account with exactly one active
/// link, as a courtesy: the server holds that line (`last_login_method`)
/// whatever the page shows. Connect confirms identity first, with a proof
/// minted for that attempt, then asks the bridge to begin. On the web the
/// provider popup opens only from a user tap, so the view then asks for one
/// ("Continue with ...") instead of opening it after the awaits behind it; on
/// iOS and Android it opens at once. Every retry starts over.
class MagicStarterConnectedAccountsView
    extends MagicStatefulView<MagicStarterProfileController> {
  /// Creates the page.
  ///
  /// [openerNeedsTap] is whether the provider opens only from a fresh tap; it
  /// follows the platform and is a parameter only so a test can exercise the
  /// web path.
  const MagicStarterConnectedAccountsView({
    super.key,
    @visibleForTesting this.openerNeedsTap = kIsWeb,
  });

  /// Whether the opener the bridge answered must run inside a user tap.
  final bool openerNeedsTap;

  @override
  State<MagicStarterConnectedAccountsView> createState() =>
      _MagicStarterConnectedAccountsViewState();
}

class _MagicStarterConnectedAccountsViewState
    extends
        MagicStatefulViewState<
          MagicStarterProfileController,
          MagicStarterConnectedAccountsView
        > {
  /// The provider whose action is in flight, so its button spins and the
  /// others hold still.
  String? _busyProvider;

  /// The sentence for the last refusal, cleared when the next action starts.
  String? _error;

  /// A begun connect waiting for the tap that opens it (web only).
  ({String provider, Future<Map<String, dynamic>> Function() opener})?
  _pendingConnect;

  // -- Lifecycle -------------------------------------------------------------

  @override
  void onInit() {
    controller.resetQuietly();
  }

  // -- Actions ---------------------------------------------------------------

  Future<void> _disconnect(String provider) async {
    setState(() {
      _busyProvider = provider;
      _error = null;
      _pendingConnect = null;
    });

    final disconnected = await controller.withoutNotifying(
      () => controller.doDisconnectSocialAccount(provider),
    );

    if (!mounted) return;
    setState(() {
      _busyProvider = null;
      _error = disconnected ? null : controller.rxStatus.message;
    });
  }

  Future<void> _connect(String provider) async {
    setState(() {
      _error = null;
      _pendingConnect = null;
    });

    // 1. A linked provider is a new way into the account: confirm first, with
    //    a proof that lives for this attempt only.
    final proof = await confirmIdentity(
      context,
      title: trans('social.confirm_identity'),
    );
    if (proof == null || !mounted) return;

    // 2. The network half of the flow (the bridge's link ticket).
    setState(() => _busyProvider = provider);
    final opener = await controller.withoutNotifying(
      () => controller.beginSocialConnect(provider, proof: proof),
    );
    if (!mounted) return;

    if (opener == null) {
      setState(() {
        _busyProvider = null;
        _error = controller.rxStatus.message;
      });
      return;
    }

    // 3. A web popup opened after the awaits above is blocked, so the user
    //    taps once more; elsewhere the provider opens at once.
    if (widget.openerNeedsTap) {
      setState(() {
        _busyProvider = null;
        _pendingConnect = (provider: provider, opener: opener);
      });
      return;
    }

    await _openProvider(provider, opener);
  }

  /// Runs [opener]. Called straight from a tap on the web, so nothing is
  /// awaited before the bridge sees it.
  Future<void> _openProvider(
    String provider,
    Future<Map<String, dynamic>> Function() opener,
  ) async {
    setState(() {
      _busyProvider = provider;
      _pendingConnect = null;
    });

    final connected = await controller.withoutNotifying(
      () => controller.doConnectSocialAccount(opener),
    );

    if (!mounted) return;
    setState(() {
      _busyProvider = null;
      _error = connected ? null : controller.rxStatus.message;
    });
  }

  // -- Data ------------------------------------------------------------------

  /// The active links by provider. A link the provider revoked no longer
  /// counts as a way to sign in.
  Map<String, Map<String, dynamic>> _activeLinks() {
    final accounts =
        Auth.user()?.get<List<dynamic>>('social_accounts') ?? const [];

    return {
      for (final account in accounts.cast<Map<String, dynamic>>())
        if (account['revoked_at'] == null)
          account['provider'] as String: account,
    };
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bridge = MagicStarter.socialAuth;
    final links = _activeLinks();
    final hasPassword = Auth.user()?.get<bool>('has_password') ?? true;
    final onlyLoginMethod = !hasPassword && links.length <= 1;
    final pending = _pendingConnect;

    return MSPageScaffold(
      title: trans('social.connected_accounts'),
      backLabel: trans('profile.settings'),
      backFallback: MagicStarterConfig.settingsHubRoute(),
      children: [
        if (_error != null)
          WText(_error!, className: 'text-sm text-destructive px-1'),
        MSSettingsSection(
          footer: onlyLoginMethod && links.isNotEmpty
              ? trans('social.last_login_method')
              : trans('social.connected_accounts_description'),
          children: [
            if (bridge != null)
              for (final provider in bridge.providers())
                _buildProviderRow(
                  bridge.icon(provider),
                  bridge.label(provider),
                  provider,
                  links[provider],
                  canDisconnect: !onlyLoginMethod,
                ),
          ],
        ),
        if (pending != null && bridge != null)
          MSSettingsSection(
            children: [
              WDiv(
                className: 'px-5 py-4',
                children: [
                  WButton(
                    onTap: () =>
                        _openProvider(pending.provider, pending.opener),
                    className:
                        'px-4 py-2 rounded-lg bg-primary '
                        'hover:bg-primary/80 text-white text-sm font-medium '
                        'w-full flex justify-center',
                    child: WText(
                      trans('social.continue_with', {
                        'provider': bridge.label(pending.provider),
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  /// One provider: its mark, name, the address it was linked with (when it is),
  /// and the action that fits.
  Widget _buildProviderRow(
    Widget icon,
    String label,
    String provider,
    Map<String, dynamic>? link, {
    required bool canDisconnect,
  }) {
    final isBusy = _busyProvider == provider;
    final isIdle = _busyProvider == null;

    return WDiv(
      className: 'flex flex-row items-center gap-3 px-5 py-3.5',
      children: [
        icon,
        WDiv(
          className: 'flex flex-col gap-0.5 flex-1 min-w-0',
          children: [
            WText(label, className: 'text-base font-medium text-fg'),
            if (link != null)
              WText(
                link['email_at_link'] as String? ?? '',
                className: 'text-sm text-fg-muted',
              ),
          ],
        ),
        if (link != null)
          WButton(
            onTap: isIdle && canDisconnect ? () => _disconnect(provider) : null,
            isLoading: isBusy,
            className:
                'text-destructive text-sm px-3 py-1 rounded border '
                'border-color-border hover:bg-surface-container '
                '${canDisconnect ? '' : 'opacity-50'}',
            child: WText(
              trans('social.disconnect'),
              className: 'text-destructive',
            ),
          )
        else
          WButton(
            onTap: isIdle ? () => _connect(provider) : null,
            isLoading: isBusy,
            className:
                'px-3 py-1 rounded border border-color-border '
                'hover:bg-surface-container text-fg text-sm',
            child: WText(trans('social.connect')),
          ),
      ],
    );
  }
}
