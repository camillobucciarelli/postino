import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../features/posta/domain/inbox_sections.dart';
import '../features/posta/presentation/inbox_section_screen.dart';
import 'impostazioni/impostazioni_page.dart' show goBackOrToPosta;
import 'posta/posta_routes.dart' show openDraft, openSearch;

/// `/sezione`: «Mostra tutti» of a section of the posta in arrivo (#366), pushed over the view it was opened from;
/// back pops to it. Its argument is the (section, Account); null Account: the Posta unificata.
class SectionPage extends StatefulWidget {
  // ignore: use_primary_constructors, routefly legge il nome del widget dal testo della classe
  const SectionPage({super.key});

  @override
  State<SectionPage> createState() => _SectionPageState();
}

class _SectionPageState() extends State<SectionPage> {
  // Read once: the last route's argument, and a later rebuild may find another route on top.
  // Routefly keeps the arguments in statics: another route's (a rebuilt stack) is not this page's.
  final (InboxSection, String?) _scope = switch (Routefly.query.arguments) {
    (final InboxSection section, final String? accountId) => (section, accountId),
    _ => (InboxSection.starred, null),
  };

  @override
  Widget build(BuildContext context) => InboxSectionScreen(
    section: _scope.$1,
    accountId: _scope.$2,
    onBack: () => goBackOrToPosta(context),
    onOpenDraft: openDraft,
    onSearch: () => openSearch(accountId: _scope.$2),
  );
}
