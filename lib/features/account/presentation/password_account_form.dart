import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/mail_servers.dart';
import '../../../core/domain/platform_services.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'server_fields.dart';

/// Apple's page on app-specific passwords, the only way into iCloud Mail for another client.
final _appPasswordsPage = Uri.parse('https://support.apple.com/102654');

/// «Collega iCloud» ([icloud]) or «Altro IMAP»: address and password, the manual servers on request (or when
/// autodiscovery finds none), a test connection, then the Account. With [address] it reconnects that Account:
/// the address is locked. True once the Account is connected; Esc closes it.
Future<bool> showPasswordAccountForm(BuildContext context, {required bool icloud, String? address}) async {
  final t = context.t.passwordForm;
  final connected = await showPostinoDialog<bool>(
    context,
    title: address != null
        ? t.reconnectTitle
        : icloud
        ? t.icloudTitle
        : t.imapTitle,
    child: _PasswordAccountForm(icloud: icloud, address: address),
  );
  return connected ?? false;
}

class const _PasswordAccountForm({required final bool icloud, final String? address}) extends StatefulWidget {
  @override
  State<_PasswordAccountForm> createState() => _PasswordAccountFormState();
}

class _PasswordAccountFormState() extends State<_PasswordAccountForm> {
  late final _address = TextEditingController(text: widget.address);
  final _password = TextEditingController();
  final _imap = ServerDraft(993, ServerSecurity.ssl);
  final _smtp = ServerDraft(587, ServerSecurity.starttls);
  var _manual = false;
  var _busy = false;
  String? _addressError;
  String? _passwordError;

  /// A failure that belongs to no field.
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _password.dispose();
    _imap.dispose();
    _smtp.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_busy) return;
    final t = context.t.passwordForm;
    final address = _address.text.trim();
    final at = address.indexOf('@');
    _addressError = at < 1 || at == address.length - 1 || address.contains(' ') ? t.invalidAddress : null;
    _passwordError = _password.text.isEmpty ? t.emptyPassword : null;
    _error = null;
    ServerSettings? servers;
    var valid = _addressError == null && _passwordError == null;
    if (_manual) {
      final imap = _imap.validate(invalidHost: t.invalidHost, invalidPort: t.invalidPort);
      final smtp = _smtp.validate(invalidHost: t.invalidHost, invalidPort: t.invalidPort);
      if (imap != null && smtp != null) {
        servers = ServerSettings(imap: imap, smtp: smtp);
      } else {
        valid = false;
      }
    }
    if (!valid) return setState(() {});
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final result = await GetIt.I<AccountsRepository>().connectWithPassword(address, _password.text, servers: servers);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        case Ok():
          navigator.pop(true);
        case Err(failure: UseGmailFailure()):
          _addressError = t.useGmail;
        case Err(failure: AlreadyConnectedFailure()):
          _addressError = t.alreadyConnected;
        case Err(failure: AuthFailure()):
          _passwordError = t.authRejected;
        case Err(failure: ServerNotFoundFailure()):
          _manual = true;
          _error = t.serverNotFound;
        case Err(failure: OfflineFailure()):
          _error = t.unreachable;
        case Err():
          _error = context.t.connect.failed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.passwordForm;
    final c = context.pc;
    final locked = widget.address != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PostinoSpacing.s4,
      children: [
        if (widget.icloud) ...[
          PostinoSelectable(
            child: Text(t.icloudHelp, style: PostinoText.preview.copyWith(color: c.inkMuted)),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PostinoButton(
              label: t.appleLink,
              variant: PostinoButtonVariant.ghost,
              underline: true,
              onPressed: () => unawaited(GetIt.I<LinkOpener>().open(_appPasswordsPage)),
            ),
          ),
        ],
        PostinoTextField(
          key: const ValueKey('password-form-address'),
          label: t.address,
          controller: _address,
          error: _addressError,
          readOnly: locked,
          autofocus: !locked,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _connect(),
        ),
        PostinoTextField(
          key: const ValueKey('password-form-password'),
          label: widget.icloud ? t.appPassword : t.password,
          controller: _password,
          error: _passwordError,
          obscure: true,
          autofocus: locked,
          onSubmitted: (_) => _connect(),
        ),
        if (!widget.icloud)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              expanded: _manual,
              child: PostinoButton(
                label: t.manual,
                variant: PostinoButtonVariant.ghost,
                onPressed: () => setState(() => _manual = !_manual),
              ),
            ),
          ),
        if (_manual) ...[
          ServerFields(title: t.imapServer, draft: _imap, onChanged: () => setState(() {}), onSubmitted: _connect),
          ServerFields(title: t.smtpServer, draft: _smtp, onChanged: () => setState(() {}), onSubmitted: _connect),
        ],
        if (_error case final e?)
          Semantics(
            liveRegion: true,
            child: PostinoBanner(tone: PostinoBannerTone.danger, title: e, spaced: false),
          ),
        PostinoDialogActions(
          children: [
            if (_busy) PostinoSpinner(label: t.connecting),
            PostinoButton(
              label: t.cancel,
              variant: PostinoButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            PostinoButton(
              key: const ValueKey('password-form-connect'),
              label: t.connect,
              onPressed: _busy ? null : _connect,
            ),
          ],
        ),
      ],
    );
  }
}
