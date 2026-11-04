/// How the user set up one Etichetta for the Etichettatura automatica (ADR 0015): whether it is an Etichetta
/// automatica and its optional description, used by the zero-shot start. A record, so equality comes free.
typedef AutoLabel = ({bool automatic, String? description});
