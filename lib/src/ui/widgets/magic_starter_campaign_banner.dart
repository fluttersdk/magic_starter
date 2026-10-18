import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../configuration/magic_starter_config.dart';
import '../../http/controllers/magic_starter_billing_controller.dart';
import '../../models/magic_starter_campaign.dart';
import '../components/update_banner/update_banner.dart';

/// Tells a floor-tier team owner on the web rail, on every page, that a
/// time-boxed offer is running, and sends them to the plan grid.
///
/// ## Where the offer comes from
///
/// [MagicStarterBillingController.loadCampaign] (`GET /billing/campaign`). The
/// banner resolves that controller the way the billing view does, through the
/// container, and never starts the screen's six billing reads. It asks once
/// when it mounts; the controller keeps the answer for the session, and
/// [MagicStarterBillingController.resetForSession] (a team switch, a sign-in)
/// clears it, which the banner answers by asking again for the new team.
///
/// ## When it shows
///
/// Only with a campaign in hand, while
/// [MagicStarterBillingController.canPurchaseViaWeb] holds and the campaign's
/// id is not the one dismissed. With the billing feature off, or no billing
/// controller registered, it renders nothing and starts nothing. A host
/// mapping `layout.app` to its own layout places it itself.
///
/// ## Dismissal
///
/// "Dismiss" stores the campaign id under [dismissedCampaignKey] in the
/// [Vault], so that campaign stays hidden across launches and the next one
/// (a new id) shows again. The banner holds no static state.
///
/// ## Failure mode
///
/// A read that fails is logged by the controller and leaves the banner empty.
class MagicStarterCampaignBanner extends StatefulWidget {
  /// Creates a [MagicStarterCampaignBanner].
  const MagicStarterCampaignBanner({super.key});

  /// The [Vault] key the dismissed campaign's id is stored under.
  static const String dismissedCampaignKey =
      'magic_starter.campaign.dismissed_id';

  /// Stands in for the router when "See plans" is tapped, in a test.
  @visibleForTesting
  static void Function(String path)? debugNavigateTo;

  @override
  State<MagicStarterCampaignBanner> createState() =>
      _MagicStarterCampaignBannerState();
}

class _MagicStarterCampaignBannerState
    extends State<MagicStarterCampaignBanner> {
  static const IconData _icon = Icons.local_offer_outlined;

  MagicStarterBillingController? _controller;
  String? _dismissedId;
  bool _dismissalRead = false;

  @override
  void initState() {
    super.initState();

    // 1. Nothing to show without the feature and a controller to ask.
    if (!MagicStarterConfig.hasBillingFeatures() ||
        !Magic.isRegistered<MagicStarterBillingController>()) {
      return;
    }

    // 2. Find the controller without running its `onInit`, which would fire
    //    the six billing reads this banner has no use for.
    final MagicStarterBillingController controller =
        Magic.find<MagicStarterBillingController>();
    _controller = controller..addListener(_loadCampaign);

    // 3. Ask for the offer, and for what the viewer already dismissed.
    _loadCampaign();
    unawaited(_readDismissal());
  }

  @override
  void dispose() {
    _controller?.removeListener(_loadCampaign);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MagicStarterBillingController? controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final MagicStarterCampaign? campaign = controller.campaign;
        if (campaign == null ||
            !_dismissalRead ||
            campaign.id == _dismissedId ||
            !controller.canPurchaseViaWeb) {
          return const SizedBox.shrink();
        }

        return MSUpdateBanner(
          icon: _icon,
          message: _message(campaign),
          actionLabel: trans('magic_starter.billing.campaign_see_plans'),
          onAction: _seePlans,
          dismissLabel: trans('magic_starter.billing.campaign_dismiss'),
          onDismiss: () => unawaited(_dismiss(campaign.id)),
        );
      },
    );
  }

  /// The headline over the body, each in the app locale then the default one.
  String _message(MagicStarterCampaign campaign) {
    final String language = Lang.current.languageCode;

    return <String>[
      campaign.headlineFor(language),
      campaign.bodyFor(language),
    ].where((String line) => line.isNotEmpty).join('\n');
  }

  /// Idempotent on the controller, so every notification may call it: it is
  /// what repeats the read after a reset cleared the answer.
  void _loadCampaign() {
    unawaited(_controller?.loadCampaign());
  }

  Future<void> _readDismissal() async {
    String? id;

    try {
      id = await Vault.get(MagicStarterCampaignBanner.dismissedCampaignKey);
    } catch (error) {
      Log.warning('[MagicStarterCampaignBanner] dismissal not read: $error');
    }
    if (!mounted) return;

    setState(() {
      _dismissedId = id;
      _dismissalRead = true;
    });
  }

  void _seePlans() {
    (MagicStarterCampaignBanner.debugNavigateTo ?? _navigate)(
      MagicStarterConfig.billingRoute(),
    );
  }

  static void _navigate(String path) {
    MagicRoute.to(path);
  }

  /// Hides the campaign, then remembers its [id]. Hidden first, so a remount
  /// during the write does not offer it again; a failed write still keeps it
  /// hidden until the banner is next mounted.
  Future<void> _dismiss(String id) async {
    setState(() => _dismissedId = id);

    try {
      await Vault.put(MagicStarterCampaignBanner.dismissedCampaignKey, id);
    } catch (error) {
      Log.warning('[MagicStarterCampaignBanner] dismissal not stored: $error');
    }
  }
}
