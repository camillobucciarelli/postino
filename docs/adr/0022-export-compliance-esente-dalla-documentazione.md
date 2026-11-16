---
status: Accettato
date: 2026-11-16
---

# Export compliance Apple: `ITSAppUsesNonExemptEncryption` = NO, esente dal fornire documentazione

Questa ADR sostituisce la decisione dell'[ADR 0020](0020-crittografia-ed-export-compliance-apple.md) (`true`). Restano validi l'inventario della crittografia e la tabella di Apple che quella ADR riporta. La chiave vale `false` in `ios/Runner/Info.plist`, `macos/Runner/Info.plist` e `macos/Runner/Store-Info.plist`, e non c'è nessuna chiave `ITSEncryptionExportComplianceCode` (#342).

## Perché

- **L'errore 90592.** Con `true` e senza codice, App Store Connect ha rifiutato gli upload della v1.6.0, sia iOS sia Mac App Store: «Invalid Export Compliance Code. The export compliance key value [] … doesn't match the key value of the app's export compliance documentation». L'ADR 0020 contava sul fatto che, con `true` e senza codice, App Store Connect avrebbe fatto le domande a ogni build. Questo presupposto era sbagliato: con `true` Apple vuole il codice di un documento approvato, e Postino non ne ha (in App Store Connect c'è solo il pulsante «Carica»).
- **La tabella di Apple** (https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption). Per un algoritmo standard che il sistema operativo Apple non fornisce, l'unico documento richiesto è la dichiarazione di crittografia francese, e solo se l'app è distribuita in Francia. Dal 16/11/2026 la Francia è esclusa (#333), quindi a Postino non serve nessun documento.
- **Cosa deve dire il plist.** Le pagine *Overview of export compliance* e *Determine and upload app encryption documentation* chiedono che il plist dichiari l'app esente dal fornire documentazione quando non ne serve. Il riferimento della chiave (https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption) definisce NO come «non usa crittografia **o** usa solo forme esenti dalla documentazione».

## Cosa significa `false`

Per Postino `false` vuol dire «esente dal fornire documentazione». Non vuol dire «nessuna crittografia». SQLCipher, pointycastle e il TLS di Dart restano tutti come descritti nell'ADR 0020: è cambiata solo la documentazione che Apple chiede, non quello che l'app usa.

## Conseguenze

- **Condizione: Francia esclusa.** Se si distribuisce in Francia, la dichiarazione francese torna obbligatoria e `false` diventa falso.
- **Per riaprire la Francia**, in quest'ordine:
  1. caricare la dichiarazione di crittografia francese (ANSSI) in App Store Connect (App Information → App Encryption Documentation) e aspettare che venga approvata;
  2. impostare `true` e il codice assegnato da Apple come `ITSEncryptionExportComplianceCode` nei tre plist, e aggiornare `store_bundle_check.sh`;
  3. solo dopo, aggiungere la Francia ai Paesi di distribuzione.
- `tool/release/store_bundle_check.sh` vuole `false` nel bundle Mac App Store e fallisce se compare `ITSEncryptionExportComplianceCode`. Per iOS non c'è un controllo del bundle: il valore viene dal plist sorgente, e nessuno script lo riscrive.
- Prima del merge il titolare conferma in App Store Connect l'esito del questionario «Documentazione relativa alla crittografia dell'app»: deve risultare «nessun documento richiesto» (`docs/store/checklist-titolare.md`).
- Gli obblighi verso il governo USA (BIS, per esempio il rapporto annuale di autoclassificazione) li valuta il titolare. Questa ADR non è una consulenza legale.
