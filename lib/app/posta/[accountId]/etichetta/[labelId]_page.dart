// ignore_for_file: file_names
import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../posta_views.dart';

/// Route of an Etichetta: PostaLayout draws the view from the URI.
class LabelPage extends StatelessWidget {
  const LabelPage({super.key});

  @override
  Widget build(BuildContext context) => postaLabelView(Routefly.query['accountId'], Routefly.query['labelId']);
}
