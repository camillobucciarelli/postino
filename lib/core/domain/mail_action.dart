import 'package:equatable/equatable.dart';

/// Where a Messaggio lives: the attribute Archivia and Elimina change.
enum Placement() {
  /// Nella posta in arrivo.
  inbox,

  /// Archiviato: fuori dalla posta in arrivo, non nel Cestino.
  archive,

  /// Nel Cestino.
  trash,
}

/// An Azione v1 on a Messaggio (ADR 0008): the attribute it changes and the value the user wants for it.
/// The offline queue keeps one voce per message and [attribute]: Azioni on the same one merge.
sealed class const MailAction() extends Equatable {
  /// Costruttore delle varianti.
  this;

  /// The attribute it changes: [readAttribute], [starredAttribute], [placementAttribute] or [labelAttribute].
  String get attribute;

  /// The value it wants: a [bool], or a [Placement] for [placementAttribute].
  Object get wanted;

  @override
  List<Object?> get props => [attribute, wanted];
}

/// The attribute of [MarkRead] and [MarkUnread].
const readAttribute = 'read';

/// The attribute of [Star] and [Unstar].
const starredAttribute = 'starred';

/// The attribute of [Archive] and [Delete].
const placementAttribute = 'placement';

/// The attribute of [ApplyLabel] and [RemoveLabel] for the Etichetta [labelId].
String labelAttribute(String labelId) => '$_labelPrefix$labelId';

/// The Etichetta of a [labelAttribute]; null for the other attributes.
String? labelIdOf(String attribute) =>
    attribute.startsWith(_labelPrefix) ? attribute.substring(_labelPrefix.length) : null;

const _labelPrefix = 'label:';

/// Segna come letto.
final class const MarkRead() extends MailAction {
  /// Crea l'Azione.
  this;

  @override
  String get attribute => readAttribute;

  @override
  bool get wanted => true;
}

/// Segna come non letto.
final class const MarkUnread() extends MailAction {
  /// Crea l'Azione.
  this;

  @override
  String get attribute => readAttribute;

  @override
  bool get wanted => false;
}

/// Stella.
final class const Star() extends MailAction {
  /// Crea l'Azione.
  this;

  @override
  String get attribute => starredAttribute;

  @override
  bool get wanted => true;
}

/// Togli Stella.
final class const Unstar() extends MailAction {
  /// Crea l'Azione.
  this;

  @override
  String get attribute => starredAttribute;

  @override
  bool get wanted => false;
}

/// Archivia.
final class const Archive() extends MailAction {
  /// Crea l'Azione.
  this;

  @override
  String get attribute => placementAttribute;

  @override
  Placement get wanted => Placement.archive;
}

/// Elimina: moves the message to the Cestino; it never meets a Conflitto (ADR 0008).
final class const Delete() extends MailAction {
  /// Crea l'Azione.
  this;

  @override
  String get attribute => placementAttribute;

  @override
  Placement get wanted => Placement.trash;
}

/// Applica Etichetta.
final class const ApplyLabel(
  /// Id dell'Etichetta lato Provider.
  final String labelId,
) extends MailAction {
  /// Crea l'Azione.
  this;

  @override
  String get attribute => labelAttribute(labelId);

  @override
  bool get wanted => true;
}

/// Togli Etichetta.
final class const RemoveLabel(
  /// Id dell'Etichetta lato Provider.
  final String labelId,
) extends MailAction {
  /// Crea l'Azione.
  this;

  @override
  String get attribute => labelAttribute(labelId);

  @override
  bool get wanted => false;
}
