import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../features/posta/presentation/search_screen.dart';
import 'impostazioni/impostazioni_page.dart' show goBackOrToPosta;
import 'posta/posta_routes.dart' show openDraft;

/// `/cerca`: the search of the Posta (#205), pushed over the view it was opened from; back pops to it.
/// Its argument is the (Account, Etichetta) to search in; null Account: all of them.
class SearchPage extends StatefulWidget {
  // ignore: use_primary_constructors, routefly legge il nome del widget dal testo della classe
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState() extends State<SearchPage> {
  // Read once: the last route's argument, and a later rebuild may find another route on top.
  final (String?, String?) _scope = Routefly.query.arguments as (String?, String?)? ?? (null, null);

  @override
  Widget build(BuildContext context) => SearchScreen(
    accountId: _scope.$1,
    labelId: _scope.$2,
    onBack: () => goBackOrToPosta(context),
    onOpenDraft: openDraft,
  );
}
