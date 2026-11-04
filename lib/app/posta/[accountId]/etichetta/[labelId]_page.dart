// ignore_for_file: file_names
import 'package:flutter/widgets.dart';
import 'package:routefly/routefly.dart';

import '../../posta_views.dart';
import '../../route_query.dart';

/// Route of an Etichetta: PostaLayout draws the view from the URI.
class const LabelPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      postaLabelView(Routefly.query.param('accountId'), Routefly.query.param('labelId'));
}
