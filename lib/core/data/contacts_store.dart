import 'package:injectable/injectable.dart';

import '../domain/contact.dart';
import '../domain/contact_ranking.dart';
import '../domain/contacts_repository.dart';
import '../domain/platform_services.dart';
import 'postino_database.dart';

/// The Contatti from the messages in the local database (#216): no network, no state of their own to keep aligned.
@LazySingleton(as: ContactsRepository)
class ContactsStore(final PostinoDatabase _db, final Clock _clock) implements ContactsRepository {
  @override
  Future<List<Contact>> suggest(String prefix, {int limit = 6}) async {
    final p = prefix.trim();
    if (p.isEmpty) return const [];
    final dao = _db.contactsDao;
    return rankContacts(
      await dao.sightings(p),
      prefix: p,
      own: await dao.ownAddresses(),
      now: _clock.now(),
      limit: limit,
    );
  }
}
