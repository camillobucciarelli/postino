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
      // ponytail: no Azione brings a message back to the inbox in v1; add one when the UI offers it.
      _ => throw StateError('no Azione puts a message in the inbox'),
    },
    _ when attribute.startsWith('label:') =>
      want == true ? ApplyLabel(attribute.substring(6)) : RemoveLabel(attribute.substring(6)),
    _ => throw StateError('unknown attribute $attribute'),
  };
}
