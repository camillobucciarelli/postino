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
    drawer: drawer,
    // The bar sits in the body, not in `Scaffold.appBar`: it takes the height of its content
    // (56, more with enlarged text) and the rest starts under it, with no fixed cap.
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        appBar,
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
