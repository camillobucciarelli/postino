// ignore_for_file: file_names
import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../../features/impostazioni/presentation/auto_labels_view.dart';
import '../../posta/route_query.dart';
import '../impostazioni_page.dart';

/// `/impostazioni/<account>/etichette`: Impostazioni › Account › Etichette automatiche.
class AutoLabelsPage extends StatelessWidget {
  // ignore: use_primary_constructors, routefly legge il nome del widget dal testo della classe
  const AutoLabelsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      AutoLabelsView(accountId: Routefly.query.param('accountId'), onBack: () => goBackOrToPosta(context));
}
