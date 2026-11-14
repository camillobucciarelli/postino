# Firma stabile in debug su macOS (#76)

Senza un'identità di firma, Xcode firma la build debug in modo ad-hoc: l'identità del codice (cdhash) cambia a ogni build e il Portachiavi di login non riconosce più l'app come proprietaria degli elementi. Chiede la password per ognuno di quelli letti all'avvio: la chiave del DB cifrato e il token OAuth. In release la firma è Developer ID, stabile, e non chiede nulla.

## Setup (una volta, per sviluppatore)

1. Accesso Keychain › Assistente Certificati › Crea un certificato… › nome `Postino Dev`, tipo identità "Auto-firmato", tipo certificato "Firma del codice".
2. Crea `macos/Runner/Configs/Local.xcconfig` (ignorato da git, incluso da `AppInfo.xcconfig`):

   ```
   CODE_SIGN_IDENTITY = Postino Dev
   ```

3. Al primo avvio il Portachiavi chiede la password per ogni elemento: scegli **Consenti sempre**. Da lì in poi le build successive, firmate con lo stesso certificato, non chiedono più nulla.

Senza `Local.xcconfig` la build resta ad-hoc e i prompt restano (comportamento invariato).

## Note

- Gli elementi non cambiano Portachiavi e non c'è migrazione: DB e token esistenti restano leggibili.
- L'errore `-60008` compare se l'app parte a schermo bloccato: non c'entra con i prompt, basta sbloccare e riavviare.
- La riga `CODE_SIGN_STYLE = Manual` nel target Debug serve perché lo stile Automatic pretende un team di sviluppo anche con un'identità locale.
- Debug e Profile restano sul Portachiavi legacy; la release tiene la chiave del database nel Data Protection Keychain, che senza provisioning profile non si legge (#270, ADR 0017). Sullo stesso Mac la build debug condivide il container della release (stesso bundle ID): se la release ha già spostato la chiave, la debug trova `database_key.moved` e fallisce all'avvio invece di cancellare `postino.db`. Per sviluppare lì usa un altro utente macOS.
- `Local.xcconfig` vale anche per le build Release/Profile fatte in locale (stesso `AppInfo.xcconfig`); la CI non ha il file e non cambia. Per un rilascio locale firmato Developer ID rimuovi il file o la riga.
