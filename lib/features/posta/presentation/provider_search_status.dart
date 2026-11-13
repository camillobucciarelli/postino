// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'provider_search.dart';

/// Where the search on the Providers stands (#207), above the results: «Cerco anche su…» while an Account
/// is asked, «Risultati solo locali» for one not reachable, «Mostrati i primi 1.000 risultati» for one whose
/// Provider stopped at its cap (all live regions, their text selectable), and «Mostra altri» for the next page.
/// Nothing before Invio.
class const ProviderSearchStatus({super.key, required final ProviderSearch search}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SignalBuilder(
    builder: (context) {
      final t = context.t.cerca.provider;
      PostinoAccountRef mark(Account a) => (color: PostinoAccountColor.values[a.color], initial: a.initial);
      final children = [
        for (final a in search.searching.value)
          PostinoBanner(
            key: ValueKey('cerca-su-${a.id}'),
            tone: PostinoBannerTone.info,
            // The title already says it.
            leading: ExcludeSemantics(
              child: PostinoSpinner(label: t.searching(name: a.name)),
            ),
            account: mark(a),
            title: t.searching(name: a.name),
          ),
        for (final (a, failure) in search.unreachable.value)
          PostinoBanner(
            key: ValueKey('non-raggiungibile-${a.id}'),
            tone: PostinoBannerTone.offline,
            account: mark(a),
            title: t.unreachable(name: a.name),
            // Invio helps only when it was the network.
            message: switch (failure) {
              AuthFailure() => t.reconnect,
              RateLimitFailure() => t.later,
              _ => t.retry,
            },
          ),
        for (final (a, n) in search.capped.value)
          PostinoBanner(
            key: ValueKey('tetto-${a.id}'),
            tone: PostinoBannerTone.info,
            account: mark(a),
            title: t.capped(
              n: NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(n),
              name: a.name,
            ),
          ),
        if (search.hasMore.value)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PostinoButton(
              label: t.more,
              onPressed: search.more,
              variant: PostinoButtonVariant.ghost,
              size: PostinoButtonSize.sm,
            ),
          ),
      ];
      if (children.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
    },
  );
}
