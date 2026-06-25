import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'accordion.dart';

/// Static variant-matrix preview for [Accordion].
///
/// Renders a three-item accordion so the catalog can exercise the expand/
/// collapse interaction and light/dark themes. One preview class per file is
/// the canonical Wave 4 contract.
class AccordionPreview extends StatelessWidget {
  /// Creates the accordion variant-matrix preview.
  const AccordionPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-6 p-6',
      children: [
        WText(
          'Accordion — default',
          className: 'text-sm font-medium text-fg-muted',
        ),
        const Accordion(
          items: [
            AccordionItem(
              title: 'What is Magic Starter?',
              body: WText(
                'A Flutter starter kit built on the Magic framework, '
                'providing 13 opt-in features out of the box.',
              ),
            ),
            AccordionItem(
              title: 'What features are included?',
              body: WText(
                'Auth, registration, 2FA, profile, profile photos, teams, '
                'sessions, notifications, email verification, social login, '
                'phone OTP, and guest auth.',
              ),
            ),
            AccordionItem(
              title: 'How do I customise views?',
              body: WText(
                'Use the view registry: MagicStarter.view.register() or '
                'MagicStarter.view.slot() to override any view or insert '
                'content into named slots.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
