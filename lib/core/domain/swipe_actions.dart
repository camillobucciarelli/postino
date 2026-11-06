/// An Azione an Impostazione di Postino can bind to a swipe of a row (#147): the Azioni v1 the UI offers.
enum SwipeAction() {
  /// Archivia.
  archive,

  /// Segna come letto, or non letto on a Conversazione already read.
  markRead,

  /// Stella, or togli la stella on a Conversazione that has it.
  star,

  /// Elimina.
  delete,

  /// Applica Etichetta: opens the picker.
  applyLabel,
}

/// Which way the row is dragged: the Azione a swipe in that direction runs.
enum SwipeDirection() {
  /// Il dito va a sinistra.
  left,

  /// Il dito va a destra.
  right,
}

/// The Azione of each direction.
typedef SwipeActions = ({SwipeAction left, SwipeAction right});

/// What swiping does until the user chooses: left Archivia, right Segna come letto.
const swipeActionsDefault = (left: SwipeAction.archive, right: SwipeAction.markRead);
