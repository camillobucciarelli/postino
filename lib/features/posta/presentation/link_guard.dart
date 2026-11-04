import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/platform_services.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';
import '../domain/link_check.dart';
import '../domain/link_table.dart';

/// Opens a tapped link outside Postino (ADR 0007). Web and mail only: a `file:` link in a message must never open
/// (or hand out) a local file. If a visible text of the link ([texts]: the labels of the link: one, from `LinkTable`) shows another
/// registrable domain than the real one, or no text can be found for the URL, a Dialog names the real domain first; nothing opens until the user agrees.
/// `mailto:` and subdomains of the same site open at once.
Future<void> openGuardedLink(BuildContext context, String url, Iterable<String> texts) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !['http', 'https', 'mailto'].contains(uri.scheme)) return;
  final warning = linkWarning(uri, texts);
  if (warning != null) {
    final t = context.t.conversazione;
    final proceed = await showPostinoConfirmDialog(
      context,
      title: t.linkWarningTitle,
      message: warning.unverified
          ? t.linkUnverifiedBody(domain: warning.domain)
          : t.linkWarningBody(domain: warning.domain),
      note: warning.punycode ? t.linkWarningPunycode : null,
      confirmLabel: t.linkOpen,
      cancelLabel: t.linkCancel,
    );
    if (!proceed) return;
  }
  await GetIt.I<LinkOpener>().open(uri);
}

/// A tap on [url], a token of [table] ([tokenizeLinks]): the link it stands for goes through [openGuardedLink] with
/// its own label. Any other URL is no link of the body, so its destination cannot be vouched for: the Dialog asks.
Future<void> openTokenLink(BuildContext context, LinkTable table, String url) async {
  final entry = table.lookup(url);
  // Not a token: only a web address is worth asking about; nothing else (mail included) opens unasked.
  if (entry == null && !RegExp('^https?:', caseSensitive: false).hasMatch(url)) return;
  await openGuardedLink(context, entry?.href ?? url, entry == null ? const [] : [entry.label]);
}
