import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/contact.dart';
import '../../../core/domain/contacts_repository.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/recipient_token.dart';

/// A, Cc or Ccn with the Contatti (#216): while an address is being written, after the last comma, the best ones
/// are suggested under the field. Up/Down move, Enter writes the highlighted one as `Name <address>, `, Esc closes
/// the list (a second Esc reaches the composer); Tab still moves to the next field (ADR 0014), Cmd/Ctrl+Enter still
/// sends. The focus never leaves the field.
class const RecipientField({
  super.key,
  required final String label,
  required final TextEditingController controller,
  final bool autofocus = false,

  /// Every edit, typed or a Contatto chosen.
  final ValueChanged<String>? onChanged,
}) extends StatefulWidget {
  @override
  State<RecipientField> createState() => _RecipientFieldState();
}

class _RecipientFieldState() extends State<RecipientField> {
  final _contacts = GetIt.I<ContactsRepository>();
  late final _focus = FocusNode(debugLabel: widget.label, onKeyEvent: _key);
  List<Contact> _suggestions = const [];
  int _highlighted = 0;

  /// Bumped by each keystroke and by closing: an answer that arrives late is dropped.
  int _lookup = 0;
  Timer? _debounce;

  /// The address the shown suggestions are for: Enter writes one only while it is still the one being written.
  String _shownFor = '';
  static const _wait = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _close();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    super.dispose();
  }

  /// One query once the typing pauses for [_wait] (#216): the shown suggestions stay meanwhile.
  void _typed(String text) {
    widget.onChanged?.call(text);
    final token = recipientToken(text);
    if (token.isEmpty) return _close();
    _debounce?.cancel();
    final n = ++_lookup;
    _debounce = Timer(_wait, () => unawaited(_suggest(token, n)));
  }

  Future<void> _suggest(String token, int n) async {
    final found = await _contacts.suggest(token);
    if (!mounted || n != _lookup || !_focus.hasFocus) return;
    setState(() {
      _suggestions = found;
      _shownFor = token;
      _highlighted = 0;
    });
  }

  void _close() {
    _debounce?.cancel();
    _lookup++;
    if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
  }

  void _choose(int i) {
    final text = completeRecipient(widget.controller.text, _suggestions[i]);
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _close();
    widget.onChanged?.call(text);
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (_suggestions.isEmpty || e is KeyUpEvent) return KeyEventResult.ignored;
    final n = _suggestions.length;
    final keys = HardwareKeyboard.instance;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _highlighted = (_highlighted + 1) % n);
      case LogicalKeyboardKey.arrowUp:
        setState(() => _highlighted = (_highlighted - 1 + n) % n);
      // Cmd/Ctrl+Enter is Invia: it goes on to the composer.
      // Typed on since the suggestions came: they are for another address.
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
          when e is KeyDownEvent &&
              !keys.isMetaPressed &&
              !keys.isControlPressed &&
              recipientToken(widget.controller.text) == _shownFor:
        _choose(_highlighted);
      // Under PostinoListDetailLayout the Esc reaches PostinoSuggestions' dismiss action first; elsewhere it is this.
      case LogicalKeyboardKey.escape when e is KeyDownEvent:
        _close();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final count = context.t.composizione.suggestions(n: _suggestions.length);
    return PostinoSuggestions(
      suggestions: _suggestions,
      highlighted: _highlighted,
      onSelected: _choose,
      countLabel: count,
      onDismiss: _close,
      child: PostinoComposerField(
        label: widget.label,
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        keyboardType: TextInputType.emailAddress,
        semanticsHint: _suggestions.isEmpty ? null : count,
        onChanged: _typed,
      ),
    );
  }
}
