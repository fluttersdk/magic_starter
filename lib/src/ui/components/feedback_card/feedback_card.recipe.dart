import 'package:magic/magic.dart';

/// The `score` axis key: whether a score chip is the chosen one.
const String kFeedbackScoreAxis = 'score';

/// Builds the [WindSlotRecipe] for the MSFeedbackCard component.
///
/// The chosen score borrows the selected-chip treatment of the support topic
/// and rating chips (a primary border on `bg-primary-container`), so a screen
/// that shows both reads them as one control family.
///
/// ### Slot structure
/// ```
/// root     - the column inside the card
/// question - the 0-10 question
/// scale    - the wrapping row of eleven score chips
/// score    - one square chip (`score` axis: idle / selected)
/// label    - the number inside a chip
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
        'flex flex-row items-center justify-center w-10 h-10 rounded-xl border',
    'label': 'text-sm font-medium text-fg',
    'ends': 'flex flex-row justify-between gap-3',
    'end': 'text-xs text-fg-muted',
    'actions': 'flex flex-row wrap items-center gap-3',
    'thanks': 'text-sm text-fg',
    'link': 'text-sm font-medium text-primary',
  },
  variants: {
    kFeedbackScoreAxis: {
      'idle': {'score': 'border-color-border bg-surface-container-high'},
      'selected': {
        'score':
            'border-primary-600 dark:border-primary-500 bg-primary-container',
      },
    },
  },
  defaultVariants: {kFeedbackScoreAxis: 'idle'},
);
