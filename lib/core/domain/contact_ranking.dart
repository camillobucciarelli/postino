import 'dart:math' as math;

import 'contact.dart';
import 'mailbox.dart';

/// One message as the Contatti see it: its sender, its To, Cc and Ccn (`Name <address>` each), its date and
/// whether the user sent it.
typedef ContactSighting = ({String sender, String? senderName, List<String> recipients, DateTime date, bool sent});

/// Each message counts 0.5^(age / 30 days). The score is [_sentWeight] times the decayed sum of the messages the
/// user sent to the address, plus the logarithm of 1 + the decayed sum of the others: someone written to yesterday
/// (≈ 9.8) beats a newsletter received every day forever (ln(1 + 43.8) ≈ 3.8), and among the received the
/// frequency still counts.
const _halfLife = Duration(days: 30);
const _sentWeight = 10.0;

/// Addresses no one can reply to: they are never suggested.
final _automatic = RegExp('no[-_.]?reply|do[-_.]?not[-_.]?reply|mailer-daemon', caseSensitive: false);

/// The best [limit] Contatti in [rows] matching [prefix] (see `ContactsRepository.suggest`), leaving out the
/// Accounts' [own] addresses (lowercase) and the automatic ones; an address in any case is one Contatto with the
/// most recent name it had. Every row of an address counts, whatever the prefix: [rows] should hold them all
/// ([foundByName] says which ones a prefix filter on the rows can miss).
List<Contact> rankContacts(
  Iterable<ContactSighting> rows, {
  required String prefix,
  required Set<String> own,
  required DateTime now,
  int limit = 6,
}) {
  final p = prefix.trim().toLowerCase();
  if (p.isEmpty) return const [];
  final ranked = [
    for (final e in _tally(rows, own, now).entries)
      if (_matches(p, e.key, e.value.name)) e,
  ]..sort((a, b) => b.value.score.compareTo(a.value.score));
  return [for (final e in ranked.take(limit)) (name: e.value.name, address: e.key)];
}

/// The Contatti of [rows] matching [prefix] by a word of their name, not by their address: the rows that mention
/// them without that name (a message sent to the bare address, an older name) do not contain the prefix. Best first.
List<String> foundByName(
  Iterable<ContactSighting> rows, {
  required String prefix,
  required Set<String> own,
  required DateTime now,
}) {
  final p = prefix.trim().toLowerCase();
  final named = [
    for (final e in _tally(rows, own, now).entries)
      if (!e.key.contains(p) && _matches(p, e.key, e.value.name)) e,
  ]..sort((a, b) => b.value.score.compareTo(a.value.score));
  return [for (final e in named) e.key];
}

Map<String, _Tally> _tally(Iterable<ContactSighting> rows, Set<String> own, DateTime now) {
  final found = <String, _Tally>{};
  void count(Mailbox m, ContactSighting r, {required bool sent}) {
    final address = m.address.toLowerCase();
    final at = address.indexOf('@');
    if (at <= 0 || own.contains(address) || _automatic.hasMatch(address.substring(0, at))) return;
    // A date in the future (an IMAP `Date` is the sender's word) counts as now, not as 2^(age / 30 days).
    final age = math.max(0, now.difference(r.date).inMinutes);
    final weight = math.pow(0.5, age / _halfLife.inMinutes).toDouble();
    final t = found[address] ??= _Tally();
    if (sent) {
      t.sent += weight;
    } else {
      t.received += weight;
    }
    final name = m.name;
    if (name != null && (t.nameDate == null || r.date.isAfter(t.nameDate!))) {
      t
        ..name = name
        ..nameDate = r.date;
    }
  }

  for (final r in rows) {
    count((name: r.senderName, address: r.sender), r, sent: false);
    for (final line in r.recipients) {
      count(parseMailbox(line), r, sent: r.sent);
    }
  }
  return found;
}

bool _matches(String p, String address, String? name) {
  if (address.startsWith(p)) return true;
  if (name == null) return false;
  final n = name.toLowerCase();
  return n.startsWith(p) || n.split(RegExp(r'[\s,.()"]+')).any((w) => w.startsWith(p));
}

class _Tally() {
  double sent = 0;
  double received = 0;
  String? name;
  DateTime? nameDate;

  double get score => _sentWeight * sent + math.log(1 + received);
}
