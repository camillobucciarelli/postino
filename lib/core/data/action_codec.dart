import '../domain/mail_action.dart';

/// How the offline queue and the Conflitti store an attribute value: `true`/`false`, or a [Placement] name.
String encodeValue(Object value) => switch (value) {
  final Placement p => p.name,
  _ => '$value',
};

/// The value [encodeValue] stored for [attribute].
Object decodeValue(String attribute, String value) =>
    attribute == placementAttribute ? Placement.values.byName(value) : value == 'true';

/// The Azione that gives [attribute] the stored value [wanted].
MailAction actionOf(String attribute, String wanted) {
  final want = decodeValue(attribute, wanted);
  return switch (attribute) {
    readAttribute => want == true ? const MarkRead() : const MarkUnread(),
    starredAttribute => want == true ? const Star() : const Unstar(),
    placementAttribute => switch (want) {
      Placement.trash => const Delete(),
      Placement.archive => const Archive(),
      Placement.inbox => const Restore(),
      _ => throw StateError('no placement $want'),
    },
    _ => switch (labelIdOf(attribute)) {
      final id? => want == true ? ApplyLabel(id) : RemoveLabel(id),
      null => throw StateError('unknown attribute $attribute'),
    },
  };
}
