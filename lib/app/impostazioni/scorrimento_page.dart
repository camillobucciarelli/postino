import 'package:flutter/widgets.dart';

import '../../features/impostazioni/presentation/swipe_actions_view.dart';
import 'impostazioni_page.dart';

/// `/impostazioni/scorrimento`: Impostazioni › Azioni per scorrimento.
class SwipePage extends StatelessWidget {
  // ignore: use_primary_constructors, routefly legge il nome del widget dal testo della classe
  const SwipePage({super.key});

  @override
  Widget build(BuildContext context) => SwipeActionsView(onBack: () => goBackOrToPosta(context));
}
