import 'package:flutter/material.dart';

import '../atoms/postino_skeleton.dart';
import '../molecules/postino_empty_state.dart';

/// The list of messages: Skeleton on the first load, EmptyState when empty, pull-to-refresh always.
class const PostinoMessageList({
  super.key,

  /// Se vero mostra lo scheletro di caricamento al posto delle righe.
  required final bool loading,

  /// Numero di righe della lista.
  required final int itemCount,

  /// Costruisce la riga all'indice dato.
  required final IndexedWidgetBuilder itemBuilder,

  /// Eseguito quando l'utente trascina la lista per aggiornarla.
  required final Future<void> Function() onRefresh,

  /// Testo letto dagli screen reader durante il caricamento.
  required final String loadingLabel,

  /// Titolo dello stato vuoto, mostrato quando non ci sono righe.
  required final String emptyTitle,

  /// Testo facoltativo sotto il titolo dello stato vuoto.
  final String? emptyBody,

  /// Lets the caller scroll the rows (keeping the selected one visible).
  final ScrollController? controller,
}) extends StatelessWidget {
  /// Lista dei messaggi con caricamento, stato vuoto e aggiornamento con trascinamento.
  this;

  @override
  Widget build(BuildContext context) {
    // Pullable even when shorter than the screen.
    const physics = AlwaysScrollableScrollPhysics();
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: loading || itemCount == 0
          ? ListView(
              controller: controller,
              physics: physics,
              children: [
                if (loading)
                  PostinoSkeleton(label: loadingLabel)
                else
                  PostinoEmptyState(title: emptyTitle, body: emptyBody),
              ],
            )
          : ListView.builder(controller: controller, physics: physics, itemCount: itemCount, itemBuilder: itemBuilder),
    );
  }
}
