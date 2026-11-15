import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/screen_guard.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// How long «Abbina un altro dispositivo» stays open (ADR 0019).
const pairingCodeShownFor = Duration(minutes: 2);

/// The times left the screen reader announces, in seconds: not every tick.
const _spokenAt = {120, 60, 30, 10};

/// The body of «Abbina un altro dispositivo» (ADR 0019) for [code], null when this device has no key yet: the QR and
/// the code, the countdown, «Chiudi». The secret shows only once the platform said the screen is not being captured.
class const PairingCodePanel({
  super.key,

  /// The codice di abbinamento; null before this device has a key.
  required final String? code,
}) extends StatefulWidget {
  @override
  State<PairingCodePanel> createState() => _PairingCodePanelState();
}

class _PairingCodePanelState() extends State<PairingCodePanel> with WidgetsBindingObserver {
  final _guard = GetIt.I<ScreenGuard>();
  StreamSubscription<bool>? _captures;
  Timer? _tick;
  var _left = pairingCodeShownFor.inSeconds;

  /// Null until the platform answered: the secret stays hidden meanwhile, so a recording already running never
  /// catches it (iOS).
  bool? _captured;
  var _closed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.code == null) return;
    _captures = _guard.watchCaptured().listen((on) => setState(() => _captured = on));
    unawaited(
      _guard.protect(on: true).then((on) {
        if (mounted) setState(() => _captured = on);
      }),
    );
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (--_left <= 0) return _close();
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    unawaited(_captures?.cancel());
    if (widget.code != null) unawaited(_guard.protect(on: false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On a phone before the app switcher takes its snapshot; on a desktop only once the window is hidden, not when
    // it merely loses the focus.
    final mobile = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        (mobile && state == AppLifecycleState.inactive)) {
      _close();
    }
  }

  void _close() {
    if (_closed || !mounted) return;
    // Gone from the very next frame, not at the end of the closing transition: the app switcher's snapshot may come
    // first.
    setState(() => _closed = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.impostazioni;
    final c = context.pc;
    final code = _closed ? null : widget.code;
    final close = PostinoDialogActions(
      children: [PostinoButton(label: t.syncPairClose, autofocus: true, onPressed: _close)],
    );
    if (code == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PostinoSpacing.s4,
        children: [
          PostinoSelectable(
            child: Text(t.syncPairNoKey, style: PostinoText.body.copyWith(color: c.ink)),
          ),
          close,
        ],
      );
    }
    final groups = ['P1', for (var i = 2; i < code.length; i += 4) code.substring(i, (i + 4).clamp(0, code.length))];
    final time = '${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PostinoSpacing.s4,
      children: [
        PostinoSelectable(
          child: Text(t.syncPairShowBody, style: PostinoText.body.copyWith(color: c.ink)),
        ),
        if (_captured case null)
          const SizedBox.shrink()
        else if (_captured case true)
          PostinoBanner(tone: PostinoBannerTone.warning, title: t.syncPairCaptured, spaced: false)
        else ...[
          Center(
            child: PostinoQrCode(data: code, semanticLabel: t.syncPairQrLabel),
          ),
          // Read group by group, each one character by character: «P 1, A B C D, …».
          Semantics(
            label: '${t.syncPairCodeLabel}: ${[for (final g in groups) g.split('').join(' ')].join(', ')}',
            child: ExcludeSemantics(
              child: PostinoSelectable(
                child: Text(
                  groups.join(' '),
                  key: const ValueKey('pairing-code'),
                  textAlign: TextAlign.center,
                  style: PostinoText.code.copyWith(color: c.ink),
                ),
              ),
            ),
          ),
        ],
        // The countdown shows every second, and is announced only at a few marks.
        Semantics(
          liveRegion: true,
          label: _spokenAt.contains(_left) || _left == pairingCodeShownFor.inSeconds
              ? t.syncPairClosesInSeconds(seconds: _left)
              : null,
          child: ExcludeSemantics(
            child: Text(
              t.syncPairClosesIn(time: time),
              textAlign: TextAlign.center,
              style: PostinoText.caption.copyWith(color: c.inkMuted),
            ),
          ),
        ),
        close,
      ],
    );
  }
}
