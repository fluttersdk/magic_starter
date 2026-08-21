import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'textarea.recipe.dart';

/// A reusable multiline text input component for Magic Starter forms.
///
/// Wraps [WInput] in [InputType.multiline] mode with a [WindRecipe] that
/// applies semantic tokens. Use [state] to signal validation errors.
///
/// ### Why this is stateful
///
/// A multiline field has no Return key that closes the keyboard: Return inserts
/// a newline, which is the whole point of the field. On a phone that leaves a
/// user who tabbed in from the field above with an open keyboard, a hidden form
/// below it and nothing to press. So the textarea carries a [WKeyboardActions]
/// toolbar with a Done button, which needs a [FocusNode] it can watch, and it
/// owns one whenever the caller does not pass [focusNode].
///
/// The toolbar is iOS only, and that is the scope of the problem rather than a
/// convenience: Android's soft keyboard carries a system dismiss (the back
/// gesture), and on web or desktop Escape and a click elsewhere already work.
/// iOS is the one surface where a focused multiline field leaves a user with no
/// way out. Keeping it off Android also keeps it out of every consumer's widget
/// tests, which run as Android by default: an active toolbar schedules a frame
/// per frame, and `pumpAndSettle` on a page holding a focused textarea then
/// never settles.
///
/// That hazard is still live for a test that opts INTO iOS. A consumer setting
/// `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` and focusing a
/// textarea has to pump explicitly rather than settle, and the override has to be
/// reset inside the test body. Nothing in the component's surface hints at it, so
/// it is written down here.
///
/// ### Basic usage
///
/// ```dart
/// MSTextarea(
///   placeholder: 'Enter a description',
///   minLines: 3,
///   maxLines: 8,
///   onChanged: (v) => controller.description = v,
/// )
/// ```
@immutable
class MSTextarea extends StatefulWidget {
  /// The controlled value of the textarea.
  final String? value;

  /// Called when the user changes the textarea value.
  final ValueChanged<String>? onChanged;

  /// Visual state of the textarea.
  final TextareaState state;

  /// Placeholder text shown when the textarea is empty.
  final String? placeholder;

  /// Whether the textarea is enabled.
  final bool enabled;

  /// Whether the textarea is read-only.
  final bool readOnly;

  /// Maximum number of lines before scrolling.
  final int? maxLines;

  /// Minimum number of visible lines.
  final int minLines;

  /// External focus node.
  final FocusNode? focusNode;

  /// External text editing controller.
  final TextEditingController? controller;

  /// Whether the textarea fills the width of its parent.
  ///
  /// Wraps the rendered [WInput] in a `SizedBox(width: double.infinity)` at
  /// the widget layer, matching Flutter's cross-axis-stretch workaround
  /// (flutter/flutter#19399) rather than baking width into the recipe.
  /// Orthogonal to layout state; defaults to `false` (content-width).
  final bool fullWidth;

  /// Optional caller className appended after the recipe output.
  ///
  /// Wind's parse-time per-family last-wins lets these tokens override the
  /// matching recipe classes while every non-overridden base class survives.
  final String? className;

  /// Accessible label for the textarea.
  final String? semanticLabel;

  /// Creates a [MSTextarea].
  const MSTextarea({
    super.key,
    this.value,
    this.onChanged,
    this.state = TextareaState.normal,
    this.placeholder,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines,
    this.minLines = 3,
    this.focusNode,
    this.controller,
    this.fullWidth = false,
    this.className,
    this.semanticLabel,
  });

  @override
  State<MSTextarea> createState() => _MSTextareaState();
}

class _MSTextareaState extends State<MSTextarea> {
  /// Owned only when the caller passed none, and disposed on the same terms:
  /// a node handed in from outside belongs to whoever created it.
  FocusNode? _ownedNode;

  /// The node the field and the keyboard toolbar share.
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedNode ??= FocusNode(debugLabel: 'MSTextarea'));

  @override
  void dispose() {
    _ownedNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget textarea = WInput(
      value: widget.value,
      onChanged: widget.onChanged,
      type: InputType.multiline,
      className: textareaRecipe(
        variants: {kTextareaStateAxis: widget.state.name},
        className: widget.className,
      ),
      placeholder: widget.placeholder,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      focusNode: _focusNode,
      controller: widget.controller,
      semanticLabel: widget.semanticLabel,
    );

    if (widget.fullWidth) {
      textarea = SizedBox(width: double.infinity, child: textarea);
    }

    // A read-only or disabled field takes no keyboard, so it takes no toolbar
    // either. That is expressed by handing WKeyboardActions an EMPTY node list
    // rather than by returning early, and the difference is data loss.
    //
    // `enabled` is commonly dynamic (`enabled: !controller.isLoading` while a
    // form submits). An early return makes the element at this slot change type
    // when it flips, so the WInput below is unmounted and rebuilt, and
    // `_WInputState.initState` re-seeds its controller from `widget.value ?? ''`.
    // Uncontrolled usage, which is the common case and what these tests
    // construct, therefore loses whatever the user had typed. Reproduced both
    // ways: type "hello world", rebuild with `enabled: false`, and the text is
    // gone on the early-return shape and present on this one.
    //
    // `nextFocus: false`: one node has nowhere to navigate, and a pair of dead
    // arrows beside the Done button is worse than no arrows.
    final bool takesKeyboard = widget.enabled && !widget.readOnly;

    return WKeyboardActions(
      focusNodes: takesKeyboard ? [_focusNode] : const <FocusNode>[],
      platform: 'ios',
      nextFocus: false,
      child: textarea,
    );
  }
}
