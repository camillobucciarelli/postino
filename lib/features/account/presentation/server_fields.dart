import 'package:flutter/widgets.dart';

import '../../../core/domain/mail_servers.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// What the user typed for one server of the manual form; [validate] gives the server or sets the field errors.
class ServerDraft(int defaultPort, var ServerSecurity security) {
  final host = TextEditingController();
  final port = TextEditingController(text: '$defaultPort');
  String? hostError;
  String? portError;

  /// The server, or null after setting [hostError] / [portError] to [invalidHost] / [invalidPort].
  MailServer? validate({required String invalidHost, required String invalidPort}) {
    final host = this.host.text.trim();
    final port = int.tryParse(this.port.text.trim());
    hostError = host.isEmpty || host.contains(' ') ? invalidHost : null;
    portError = port == null || port < 1 || port > 65535 ? invalidPort : null;
    if (hostError != null || portError != null) return null;
    return MailServer(host: host, port: port!, security: security);
  }

  void dispose() {
    host.dispose();
    port.dispose();
  }
}

/// Host, port and security (SSL/TLS or STARTTLS) of one server, under its [title] (a heading).
class const ServerFields({
  super.key,
  required final String title,
  required final ServerDraft draft,
  required final VoidCallback onChanged,
  required final VoidCallback onSubmitted,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.t.passwordForm;
    final c = context.pc;
    void choose(ServerSecurity s) {
      draft.security = s;
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PostinoSpacing.s2,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: PostinoText.label.copyWith(color: c.ink)),
        ),
        PostinoTextField(
          key: ValueKey('$title-host'),
          label: t.host,
          controller: draft.host,
          error: draft.hostError,
          keyboardType: TextInputType.url,
          onSubmitted: (_) => onSubmitted(),
        ),
        PostinoTextField(
          key: ValueKey('$title-port'),
          label: t.port,
          controller: draft.port,
          error: draft.portError,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => onSubmitted(),
        ),
        for (final (s, label) in [(ServerSecurity.ssl, t.ssl), (ServerSecurity.starttls, t.starttls)])
          PostinoChoiceRow(label: label, selected: draft.security == s, onSelected: () => choose(s)),
      ],
    );
  }
}
