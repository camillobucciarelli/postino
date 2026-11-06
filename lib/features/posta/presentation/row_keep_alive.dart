import 'package:flutter/widgets.dart';

/// Keeps the cursor row built when it scrolls out of sight, so Tab still finds it.
class const RowKeepAlive({super.key, required final bool keep, required final Widget child}) extends StatefulWidget {
  @override
  State<RowKeepAlive> createState() => _RowKeepAliveState();
}

class _RowKeepAliveState() extends State<RowKeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keep;

  @override
  void didUpdateWidget(RowKeepAlive old) {
    super.didUpdateWidget(old);
    if (old.keep != widget.keep) updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
