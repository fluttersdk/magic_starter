import 'package:magic/magic.dart';

/// The `score` axis key: whether a score chip is the chosen one.
const String kFeedbackScoreAxis = 'score';

/// What a focused score looks like.
///
/// It trails each variant's own border classes, not the base: wind resolves a
/// family last-wins across the active classes, so a `border-*` colour that came
/// after `focus:border-2` would undo the thicker border.
const String _scoreFocus =
    'focus:border-2 focus:border-primary-400 '
    'focus:ring-2 focus:ring-offset-2 focus:ring-primary-500';

/// Builds the [WindSlotRecipe] for the MSFeedbackCard component.
///
/// A score is a 44 x 44 tap target. When the keyboard reaches it the border
/// thickens to the primary colour and a ring follows; the border is what shows
/// on a wind release that does not yet paint `focus:ring-*` on a `WDiv`. The chosen one is filled with the primary colour, so it reads as
/// chosen at a glance rather than as a faint ring.
///
/// ### Slot structure
/// ```
/// root     - the column inside the card
/// question - the 0-10 question
/// scale    - the wrapping row of eleven score chips
/// score    - one square chip (`score` axis: idle / selected)
/// label    - the number inside a chip (`score` axis: idle / selected)
/// ends     - the "Not likely" / "Very likely" row under the scale
/// end      - one of those two captions
/// actions  - the send and "Not now" row
/// thanks   - the line that replaces the form once answered
/// link     - the conversation a low score opened
/// ```
const WindSlotRecipe feedbackCardRecipe = WindSlotRecipe(
  slots: {
    'root': 'flex flex-col gap-4',
    'question': 'text-sm font-semibold text-fg',
    'scale': 'flex flex-row wrap gap-2',
    'score':
        'flex flex-row items-center justify-center w-11 h-11 rounded-xl border',
    'label': 'text-sm font-medium',
    'ends': 'flex flex-row justify-between gap-3',
    'end': 'text-xs text-fg-muted',
    'actions': 'flex flex-row wrap items-center gap-3',
    'thanks': 'text-sm text-fg',
    'link': 'text-sm font-medium text-primary',
  },
  variants: {
    kFeedbackScoreAxis: {
      'idle': {
        'score': 'border-color-border bg-surface-container-high $_scoreFocus',
        'label': 'text-fg',
      },
      'selected': {
        'score':
            'border-primary-600 dark:border-primary-500 bg-primary '
            '$_scoreFocus',
        'label': 'text-on-primary',
      },
    },
  },
  defaultVariants: {kFeedbackScoreAxis: 'idle'},
);
