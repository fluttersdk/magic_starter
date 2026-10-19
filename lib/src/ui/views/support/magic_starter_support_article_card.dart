import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../../../models/magic_starter_support_conversation.dart';

/// One knowledge-base article as a tappable card: its question and, when the
/// backend sent one, an excerpt.
///
/// Used for the suggestions under the create form and for the cards under an AI
/// answer. A tap opens the article's public page; an article without a `url` is
/// plain text, since the host has no page to open.
class MagicStarterSupportArticleCard extends StatelessWidget {
  const MagicStarterSupportArticleCard(this.article, {super.key});

  final MagicStarterSupportArticle article;

  static const _iconOpen = Icons.open_in_new;

  @override
  Widget build(BuildContext context) {
    final String? url = article.url;
    final String? excerpt = article.excerpt;

    final Widget card = WDiv(
      key: ValueKey<String>('support-article-${article.slug}'),
      className:
          'w-full flex flex-row items-start gap-2.5 px-3.5 py-3 rounded-xl '
          'border border-color-border bg-surface-container-high',
      children: [
        Flexible(
          child: WDiv(
            className: 'flex flex-col gap-1',
            children: [
              WText(article.question, className: 'text-sm font-medium text-fg'),
              if (excerpt != null && excerpt.isNotEmpty)
                WText(excerpt, className: 'text-xs text-fg-muted line-clamp-2'),
            ],
          ),
        ),
        if (url != null) WIcon(_iconOpen, className: 'text-sm text-fg-muted'),
      ],
    );

    if (url == null) return card;

    return WAnchor(onTap: () => Launch.url(url), child: card);
  }
}
