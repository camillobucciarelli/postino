import 'package:flutter/material.dart';

import '../tokens/postino_tokens.dart';

/// One pane on the phone: [appBar], the [drawer] behind it, [banners] on top of the [body].
class PostinoSinglePaneLayout extends StatelessWidget {
  const PostinoSinglePaneLayout({
    super.key,
    required this.appBar,
    required this.body,
    this.drawer,
    this.banners = const [],
  });

  final Widget appBar;
  final Widget body;
  final Widget? drawer;
  final List<Widget> banners;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(PostinoSize.appBarHeight),
      child: appBar,
    ),
    drawer: drawer,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: banners,
          ),
        ),
        Expanded(child: body),
      ],
    ),
  );
}
