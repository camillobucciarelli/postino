import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/platform_services.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/link_check.dart';

/// Opens a tapped link outside Postino (ADR 0007). Web and mail only: a `file:` link in a message must never open
/// (or hand out) a local file. If a visible text of the link ([texts]: every link with that URL) shows another
/// registrable domain than the real one, a Dialog names the real domain first; nothing opens until the user agrees.
/// `mailto:` and subdomains of the same site open at once.
Future<void> openGuardedLink(BuildContext context, String url, Iterable<String> texts) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !['http', 'https', 'mailto'].contains(uri.scheme)) return;
  final warning = texts.map((t) => deceptiveLink(uri, t)).nonNulls.firstOrNull;
  if (warning != null) {
    final t = context.t.conversazione;
    final proceed = await showPostinoConfirmDialog(
      context,
      title: t.linkWarningTitle,
      message: t.linkWarningBody(domain: warning.domain),
      note: warning.punycode ? t.linkWarningPunycode : null,
      confirmLabel: t.linkOpen,
      cancelLabel: t.linkCancel,
    );
    if (!proceed) return;
  }
  await GetIt.I<LinkOpener>().open(uri);
}
