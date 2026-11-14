---
status: Accettato
date: 2026-11-14
---

# Chiave del database solo su questo dispositivo

Decisione del proprietario (#263): la chiave del database (`database_key`, ADR 0003) sta nel portachiavi con accessibilità `first_unlock_this_device`: lo stesso livello di sblocco di prima (l'isolate in background la legge a dispositivo bloccato dopo il primo sblocco), ma legata al dispositivo e non sincronizzabile su iCloud Keychain. Un backup può ancora contenere `postino.db`, ma non la sua chiave: su un altro dispositivo il file non si apre.

**Migrazione.** Le voci già scritte tengono il vecchio attributo, e su iOS riscriverle con il nuovo vuol dire cancellarle e aggiungerle di nuovo. Al primo avvio dopo l'aggiornamento `readDeviceOnly` (`lib/core/data/device_only_key.dart`) copia la chiave in `database_key.migrating`, la rilegge, riscrive `database_key`, la rilegge, segna `database_key.device_only` e solo allora toglie la copia. Un passo che fallisce lascia leggibile la chiave o la sua copia; l'avvio prosegue con la chiave letta e si riprova al successivo.

**Ripristino su un altro dispositivo.** `postino.db` c'è, la chiave no: Postino genera una chiave nuova, cancella il file (illeggibile per costruzione) e riparte vuoto, poi risincronizza. Una chiave presente ma sbagliata resta un crash registrato (#116): è un altro caso.

## Conseguenze

- Dopo un ripristino su un altro dispositivo la posta si scarica di nuovo dai Provider; i log cifrati con la vecchia chiave non si leggono più.
- Gli altri segreti dello stesso store (token OAuth, password IMAP, chiave della cache degli allegati) restano `first_unlock`: fuori da questa decisione.
- macOS usa il Portachiavi di login legacy (`usesDataProtectionKeychain: false`), che ignora l'attributo: la chiave lì resta nei backup di Time Machine e segue Migrazione Assistita finché non si passa al Data Protection Keychain (#270, serve un provisioning profile).
- Android era già escluso dai backup (`allowBackup="false"`, `data_extraction_rules.xml`).
