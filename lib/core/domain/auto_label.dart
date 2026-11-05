/// How the user set up one Etichetta for the Etichettatura automatica (ADR 0015): whether it is an Etichetta
/// automatica, its optional description, used by the zero-shot start, and when it was switched on
/// (activatedAt, ms since the epoch; null when off): only the mail that arrives after it is classified.
/// A record, so equality comes free.
typedef AutoLabel = ({bool automatic, String? description, int? activatedAt});

/// An Etichetta the user never set up: not automatica, no description.
const AutoLabel autoLabelDefault = (automatic: false, description: null, activatedAt: null);
