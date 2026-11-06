import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'connect_error.dart';
import 'password_account_form.dart';

/// The choice of Provider for a new Account, the same in the onboarding and in «Aggiungi Account»: «Collega Gmail»
/// (Google consent, its failure in a `danger` Banner above), «Collega iCloud» and «Altro IMAP» (the password form).
/// [onConnected] runs once the Account exists.
class const AccountChoices({super.key, final VoidCallback? onConnected}) extends StatefulWidget {
  @override
  State<AccountChoices> createState() => _AccountChoicesState();
}

class _AccountChoicesState() extends State<AccountChoices> {
  String? _error;

  Future<void> _gmail() async {
    final r = await GetIt.I<AccountsRepository>().connectGmail();
    if (!mounted) return;
    setState(() => _error = connectError(context, r));
    if (r case Ok()) widget.onConnected?.call();
  }

  Future<void> _password({required bool icloud}) async {
    setState(() => _error = null);
    if (await showPasswordAccountForm(context, icloud: icloud) && mounted) widget.onConnected?.call();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: PostinoSpacing.s2,
    children: [
      if (_error case final e?)
        PostinoBanner(tone: PostinoBannerTone.danger, title: context.t.connect.title, message: e),
      PostinoButton(label: context.t.onboarding.connectGmail, onPressed: _gmail, size: PostinoButtonSize.lg),
      PostinoButton(
        label: context.t.onboarding.connectIcloud,
        onPressed: () => _password(icloud: true),
        size: PostinoButtonSize.lg,
      ),
      PostinoButton(
        label: context.t.onboarding.connectImap,
        onPressed: () => _password(icloud: false),
        size: PostinoButtonSize.lg,
      ),
    ],
  );
}

/// «Aggiungi Account» of the Impostazioni: the [AccountChoices] in a dialog, closed once the Account exists.
Future<void> showAddAccountDialog(BuildContext context) => showPostinoDialog<void>(
  context,
  title: context.t.accounts.add,
  child: Builder(builder: (context) => AccountChoices(onConnected: () => Navigator.of(context).pop())),
);
