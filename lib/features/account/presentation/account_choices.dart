import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/account.dart';
import '../../../core/domain/accounts_repository.dart';
import '../../../core/domain/result.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import 'connect_error.dart';
import 'oauth_connect.dart';
import 'password_account_form.dart';

/// The choice of Provider for a new Account, the same in the onboarding and in «Aggiungi Account»: «Collega Gmail» and «Collega Outlook»
/// (the Provider's consent, its failure in a `danger` Banner above), «Collega iCloud» and «Altro IMAP» (the password form).
/// [onConnected] runs once the Account exists.
class const AccountChoices({super.key, final VoidCallback? onConnected}) extends StatefulWidget {
  @override
  State<AccountChoices> createState() => _AccountChoicesState();
}

class _AccountChoicesState() extends State<AccountChoices> {
  String? _error;

  Future<void> _consent(ProviderKind provider) async {
    final r = await connectWithConsent(GetIt.I<AccountsRepository>(), provider);
    if (r == null || !mounted) return;
    setState(() => _error = connectError(context, r, provider: provider));
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
    children: [
      // It opens and closes, its gap inside (#283).
      PostinoReveal(
        child: _error == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(bottom: PostinoSpacing.s2),
                child: PostinoBanner(tone: PostinoBannerTone.danger, title: context.t.connect.title, message: _error),
              ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: PostinoSpacing.s2,
        children: [
          PostinoButton(
            label: context.t.onboarding.connectGmail,
            onPressed: () => _consent(ProviderKind.gmail),
            size: PostinoButtonSize.lg,
          ),
          PostinoButton(
            label: context.t.onboarding.connectOutlook,
            onPressed: () => _consent(ProviderKind.microsoft),
            size: PostinoButtonSize.lg,
          ),
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
