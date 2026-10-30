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
    // The Scaffold only caps the bar: unconstrained in height it is as tall as its content
    // (56, more with enlarged text), and the body starts under it.
    // ponytail: the cap holds a 3-line title and a subtitle at 200%; raise it if titles get longer.
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(PostinoSize.appBarHeight * 4),
      child: UnconstrainedBox(
        constrainedAxis: Axis.horizontal,
        alignment: Alignment.topCenter,
        child: appBar,
      ),
    ),
    drawer: drawer,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Side margins: space-4 on the phone, space-6 from the tablet up.
          padding: EdgeInsets.symmetric(
            horizontal:
                MediaQuery.sizeOf(context).width < PostinoSize.breakpointMedium
                ? PostinoSpacing.s4
                : PostinoSpacing.s6,
          ),
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
