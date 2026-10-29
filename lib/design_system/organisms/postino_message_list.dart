import 'package:flutter/material.dart';

import '../atoms/postino_skeleton.dart';
import '../molecules/postino_empty_state.dart';

/// The list of messages: Skeleton on the first load, EmptyState when empty, pull-to-refresh always.
class PostinoMessageList extends StatelessWidget {
  const PostinoMessageList({
    super.key,
    required this.loading,
    required this.itemCount,
    required this.itemBuilder,
    required this.onRefresh,
    required this.loadingLabel,
    required this.emptyTitle,
    this.emptyBody,
  });

  final bool loading;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Future<void> Function() onRefresh;
  final String loadingLabel;
  final String emptyTitle;
  final String? emptyBody;

  @override
  Widget build(BuildContext context) {
    // Pullable even when shorter than the screen.
    const physics = AlwaysScrollableScrollPhysics();
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: loading || itemCount == 0
          ? ListView(
              physics: physics,
              children: [
                if (loading)
                  PostinoSkeleton(label: loadingLabel)
                else
                  PostinoEmptyState(title: emptyTitle, body: emptyBody),
              ],
            )
          : ListView.builder(
              physics: physics,
              itemCount: itemCount,
              itemBuilder: itemBuilder,
            ),
    );
  }
}
