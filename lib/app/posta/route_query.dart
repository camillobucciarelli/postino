import 'package:routefly/routefly.dart';

/// The typed params of a dynamic route (`[accountId]`, `[messageId]`...): always present as strings.
extension RouteParams on RouteflyQuery {
  String param(String key) => this[key] as String;
}
