import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../http/controllers/magic_starter_billing_controller.dart';
import '../../components/page_scaffold/page_scaffold.dart';

/// **The plan and billing screen.**
///
/// One page over the six independent reads
/// [MagicStarterBillingController] publishes: the tier the team holds, the
/// catalogue it can move to, what it has spent this cycle, its billing history,
/// the card on file, and where the subscription is managed.
///
/// ## It resolves its controller, it does not construct one
///
/// [MagicStatefulViewState] resolves the controller through `Magic.find`, and
/// the registry builder below is zero-argument, so nothing on the render path
/// can supply a collaborator. The consumer therefore registers the controller
/// itself before this route is reached:
///
/// ```dart
/// Magic.put(
///   MagicStarterBillingController(
///     usageCopy: withUsageCopy,
///     formatNumber: formatCount,
///     storeFundedTeamReader: readStoreFundedTeam,
///     isOwnerReader: readTeamOwnership,
///   ),
/// );
/// ```
///
/// That is also why every consumer-supplied thing this screen renders through
/// (the usage copy, the number format) is a REQUIRED parameter on the
/// controller rather than on this widget: a view parameter would need a default
/// at the registration site, and both of the defaults available there are the
/// wrong answer shipped silently.
///
/// ## Page chrome comes from [MSPageScaffold]
///
/// Never hand-rolled. The scaffold routes the page through the host's one
/// `MSPageContainer` geometry, so this screen lines up with every other page in
/// the app rather than centring at its own width.
class MagicStarterBillingView
    extends MagicStatefulView<MagicStarterBillingController> {
  /// Creates the billing view.
  const MagicStarterBillingView({super.key});

  @override
  State<MagicStarterBillingView> createState() =>
      _MagicStarterBillingViewState();
}

class _MagicStarterBillingViewState
    extends
        MagicStatefulViewState<
          MagicStarterBillingController,
          MagicStarterBillingView
        > {
  @override
  Widget build(BuildContext context) {
    return MSPageScaffold(
      title: trans('magic_starter.billing.title'),
      subtitle: trans('magic_starter.billing.description'),
      children: const <Widget>[],
    );
  }
}
