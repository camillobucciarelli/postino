import 'package:flutter/material.dart';

import '../atoms/postino_skeleton.dart';
import '../molecules/postino_empty_state.dart';

/// The list of messages: Skeleton on the first load, EmptyState when empty, pull-to-refresh always.
class const PostinoMessageList({
  super.key,
  required this.loading,
  required this.itemCount,
  required this.itemBuilder,
  required this.onRefresh,
  required this.loadingLabel,
  required this.emptyTitle,
  this.emptyBody,
  this.controller,
}) extends StatelessWidget {
  /// Lista dei messaggi con caricamento, stato vuoto e aggiornamento con trascinamento.
  this;

  /// Se vero mostra lo scheletro di caricamento al posto delle righe.
  final bool loading;

  /// Numero di righe della lista.
  final int itemCount;

  /// Costruisce la riga all'indice dato.
  final IndexedWidgetBuilder itemBuilder;

  /// Eseguito quando l'utente trascina la lista per aggiornarla.
  final Future<void> Function() onRefresh;

  /// Testo letto dagli screen reader durante il caricamento.
  final String loadingLabel;

  /// Titolo dello stato vuoto, mostrato quando non ci sono righe.
  final String emptyTitle;

  /// Testo facoltativo sotto il titolo dello stato vuoto.
  final String? emptyBody;

  /// Lets the caller scroll the rows (keeping the selected one visible).
  final ScrollController? controller;

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
