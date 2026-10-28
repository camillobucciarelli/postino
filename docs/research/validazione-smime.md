# Validazione delle catene S/MIME e revoca

Ricerca per il ticket #7 (mappa #1). Contesto: nessun backend (ADR 0001), S/MIME con l'API CMS di OpenSSL libcrypto via Dart FFI, fiducia al primo uso per i certificati degli altri (ADR 0012). Fonti consultate il 2026-10-28.

Legenda: **[F]** fatto osservato nella fonte citata, **[I]** inferenza, **[R]** raccomandazione.

## Domanda

Come si validano catena e revoca (OCSP, CRL) dei certificati S/MIME sul dispositivo, senza backend, con OpenSSL via FFI su iOS, Android, macOS, Windows e Linux? Quali store di certificati radice usare per piattaforma? Conviene usare le API native? Che impatto ha OCSP sulla privacy?

## Risposta breve

- **[R]** Un solo motore su tutte le piattaforme: OpenSSL (`CMS_verify` con un `X509_STORE` costruito da noi). Le radici di default sono la lista Mozilla con il trust bit *Email*, inclusa nell'app, più le ancore importate dall'utente.
- **[R]** Per la revoca: prima le CRL (scaricate e messe in cache sul dispositivo), poi le CRL o risposte OCSP incluse nel messaggio firmato. OCSP online è spento di default e attivabile dall'utente. Se lo stato non si può verificare (soft-fail), la UI mostra uno stato esplicito "revoca non verificata", mai "valido".
- **[R]** Le API native (Security.framework, CryptoAPI) restano un'aggiunta da valutare dopo, per riconoscere le CA aziendali distribuite via MDM o GPO. Non sono il motore principale: Android e Linux non hanno un equivalente affidabile con le radici separate per scopo.

## 1. Cosa fa (e non fa) OpenSSL

- **[F]** `X509_V_FLAG_CRL_CHECK` attiva il controllo CRL sul certificato foglia, e "an error occurs if a suitable CRL cannot be found". `X509_V_FLAG_CRL_CHECK_ALL` lo estende a tutta la catena. Fonte: [X509_VERIFY_PARAM_set_flags(3)](https://github.com/openssl/openssl/blob/master/doc/man3/X509_VERIFY_PARAM_set_flags.pod).
- **[F]** OpenSSL non scarica le CRL da solo durante la verifica: le CRL vanno messe nello store o nel contesto. Esiste `X509_CRL_load_http()` (da OpenSSL 3.0, limite di 32 MB, timeout configurabile) per scaricarle dall'URL `cRLDistributionPoints`. Fonte: [X509_load_http(3)](https://github.com/openssl/openssl/blob/master/doc/man3/X509_load_http.pod).
- **[F]** OpenSSL 3.6 ha aggiunto `X509_STORE_CTX_set_ocsp_resp()` e i flag `X509_V_FLAG_OCSP_RESP_CHECK(_ALL)`, che verificano risposte OCSP *già ottenute* (pensati per lo stapling TLS). Non interrogano il responder. Fonte: [X509_STORE_CTX_new(3)](https://github.com/openssl/openssl/blob/master/doc/man3/X509_STORE_CTX_new.pod), [X509_VERIFY_PARAM_set_flags(3)](https://github.com/openssl/openssl/blob/master/doc/man3/X509_VERIFY_PARAM_set_flags.pod).
- **[F]** `CMS_verify` passa al contesto di verifica le CRL contenute nel `SignedData` (`ossl_cms_get1_crls_ex` → `X509_STORE_CTX_set0_crls`). Fonte: [crypto/cms/cms_smime.c](https://github.com/openssl/openssl/blob/master/crypto/cms/cms_smime.c).
- **[F]** Il formato CMS prevede il campo `crls` (`RevocationInfoChoices`) nel `SignedData`, che può contenere anche risposte OCSP. Fonti: [RFC 5652 §5.1](https://www.rfc-editor.org/rfc/rfc5652#section-5.1), [RFC 5940](https://www.rfc-editor.org/rfc/rfc5940).
- **[I]** È l'unico equivalente dello "stapling" per la posta: dipende dal mittente e in pratica è raro. Lo usiamo se c'è, senza contarci.
- **[I]** Con OpenSSL, quindi, la logica di rete (download delle CRL, eventuale richiesta OCSP con `OSSL_HTTP`/`OCSP_sendreq`, cache, timeout) è codice nostro, in Dart sopra FFI. È lavoro, ma è lo stesso su cinque piattaforme.

## 2. Cosa garantiscono le CA S/MIME pubbliche

Fonte: [CA/B Forum S/MIME Baseline Requirements v1.0.16, 2026-09-28](https://github.com/cabforum/smime/blob/main/SBR.md).

- **[F]** `cRLDistributionPoints` "SHALL be present" nei certificati degli abbonati (§7.1.2.3), con URI HTTP (generazioni Strict e Multipurpose).
- **[F]** `authorityInformationAccess` è "SHOULD be present", e l'URL OCSP al suo interno è un "MAY". OCSP è previsto "when provided" (§4.9.9).
- **[F]** Le CRL degli abbonati vengono riemesse almeno ogni 7 giorni, con `nextUpdate` entro 10 giorni (§4.9.7).
- **[I]** La CRL è l'unico meccanismo garantito per i certificati conformi alle BR. OCSP può mancare. Per i certificati non pubblici (CA aziendali, legacy) non c'è garanzia su nessuno dei due.

## 3. Store delle radici per piattaforma

| Piattaforma | Store di sistema | Separazione per scopo (email) | API nativa di validazione | Revoca nativa | Nota per Postino |
|---|---|---|---|---|---|
| **iOS / iPadOS** | Store Apple condiviso ([elenco](https://support.apple.com/en-us/126047), [pagina](https://support.apple.com/en-us/103272)) | Sì: la policy Apple definisce le Trust Purpose "Secure Email" e "Legacy S/MIME" legate all'EKU `emailProtection` ([Apple Root Program Policy v2.0, 2026-08-01](https://github.com/apple/apple-root-program/blob/main/policy.md)) | `SecTrust` con `kSecPolicyAppleSMIME` (iOS 7+, macOS 10.7+: "Basic X509 plus email address verification and KeyUsage enforcement") ([doc](https://developer.apple.com/documentation/security/ksecpolicyapplesmime)) | `SecPolicyCreateRevocation` con OCSP, CRL, PreferCRL, RequirePositiveResponse, NetworkAccessDisabled ([doc](https://developer.apple.com/documentation/security/secpolicycreaterevocation(_:))) | Lo store non è leggibile come file: per OpenSSL serve la lista inclusa nell'app |
| **macOS** | Come sopra, più il portachiavi di sistema e dell'utente (CA aziendali via MDM) | Come sopra | Come sopra | Come sopra | `SecPolicyCreateSMIME` è un'API privata ([SecPolicyPriv.h](https://opensource.apple.com/source/Security/Security-55471/sec/Security/SecPolicyPriv.h.auto.html)): da evitare |
| **Android** | `/system/etc/security/cacerts` (AOSP), più le CA dell'utente; KeyStore `AndroidCAStore` | **No**: i file sono solo certificati nominati per hash, senza metadati di scopo ([README.cacerts](https://android.googlesource.com/platform/system/ca-certificates/+/refs/heads/main/README.cacerts)) | `CertPathValidator("PKIX")` | `PKIXRevocationChecker` (API 24+), opzioni `PREFER_CRLS`, `NO_FALLBACK`, `ONLY_END_ENTITY`, `SOFT_FAIL`; scarica OCSP e CRL da rete ([doc](https://developer.android.com/reference/java/security/cert/PKIXRevocationChecker)) | Lo store è pensato per TLS: usarlo per la posta accetterebbe radici non approvate per S/MIME [I] |
| **Windows** | Store `ROOT` di CryptoAPI, aggiornato da Windows Update; CA aziendali via GPO | Sì (proprietà EKU per certificato nel Microsoft Trusted Root Program) [I: non verificato in questa ricerca] | `CertGetCertificateChain` + `CertVerifyCertificateChainPolicy` | Flag `CERT_CHAIN_REVOCATION_CHECK_END_CERT/CHAIN`, `..._CACHE_ONLY` (nessuna rete), `..._ACCUMULATIVE_TIMEOUT`; cache di sistema per CRL e OCSP ([doc](https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-certgetcertificatechain)) | Lo store è leggibile via `CertOpenSystemStore`/`CertEnumCertificatesInStore`, ma le proprietà di scopo vanno lette a parte [I] |
| **Linux** | Non uniforme. Debian e Ubuntu: `/etc/ssl/certs/ca-certificates.crt`. Fedora: `/etc/pki/ca-trust/extracted/` | Debian: **no**, il bundle include solo le radici con `CKA_TRUST_SERVER_AUTH` ([certdata2pem.py](https://salsa.debian.org/debian/ca-certificates/-/blob/master/mozilla/certdata2pem.py)). Fedora: **sì**, `email-ca-bundle.pem` ([update-ca-trust(8)](https://src.fedoraproject.org/rpms/ca-certificates/blob/rawhide/f/update-ca-trust.8.txt)) | Nessuna di sistema: OpenSSL o NSS | Nessuna | Su Debian e Ubuntu lo store di sistema è sbagliato per la posta |

Lista Mozilla con trust bit Email, pubblicata da CCADB: [PEM TXT](https://ccadb.my.salesforce-sites.com/mozilla/IncludedRootsPEMTxt?TrustBitsInclude=Email), [CSV](https://ccadb.my.salesforce-sites.com/mozilla/IncludedRootsPEMCSV?TrustBitsInclude=Email) (indice: [wiki Mozilla](https://wiki.mozilla.org/CA/Included_Certificates)). **[F]**

**[I]** La lista Mozilla Email è l'unica fonte che sia separata per scopo, multipiattaforma e caricabile in un `X509_STORE` così com'è. Il costo è aggiornarla a ogni release dell'app. Thunderbird usa lo stesso modello (NSS con i trust bit Mozilla).

## 4. API native: conviene preferirle?

Pro **[I]**:
- Su Apple e Windows riconoscono le CA aziendali installate via MDM o GPO e le revoche distribuite dal sistema (come la Disallowed CTL di Windows, citata nella doc di `CertGetCertificateChain`).
- Su Windows c'è una cache di sistema per CRL e OCSP.

Contro **[I]**:
- Tre implementazioni diverse (Swift/ObjC, Kotlin/Java, C Win32) sopra un parser CMS che resta comunque OpenSSL. Ogni piattaforma ha semantiche diverse su soft-fail, cache e tempo di validazione.
- Su Android il validatore nativo usa uno store TLS senza scopo. Su Linux non esiste.
- Gli esiti cambiano da piattaforma a piattaforma per lo stesso messaggio, cosa difficile da spiegare a chi usa Postino su più dispositivi.

**[R]** OpenSSL come motore unico. Valutare dopo un "secondo parere" nativo solo su Apple e Windows, per riconoscere le radici aziendali (vedi punti aperti).

## 5. Privacy di OCSP (e delle CRL)

- **[F]** Con OCSP, la CA che gestisce il responder vede l'IP del client e quale certificato viene controllato. Let's Encrypt ha abbandonato OCSP per le CRL anche per questo motivo ([Let's Encrypt, 2024-07-23](https://letsencrypt.org/2024/07/23/replacing-ocsp-with-crls/)).
- **[I]** Nella posta è peggio che nel web. Una richiesta OCSP fatta all'apertura di un messaggio dice alla CA che quel messaggio di quel mittente è stato letto, quando e da quale IP. Se il mittente gestisce la propria CA (caso comune nelle aziende), è di fatto una **conferma di lettura**, come un pixel di tracciamento. Lo stesso vale per un URL CRL dedicato scaricato all'apertura.
- **[I]** Una CRL scaricata in background, slegata dall'apertura e messa in cache fino a `nextUpdate`, rivela molto meno: solo che il client tratta certificati di quella CA.
- **[R]** Quindi:
  1. Mai rete al momento dell'apertura del messaggio.
  2. La verifica avviene alla sincronizzazione/ricezione e il risultato si salva nel DB locale (ADR 0003) con la data.
  3. CRL in cache condivisa per emittente.
  4. OCSP solo come opzione esplicita, spenta di default.
  5. Il download delle CRL si disattiva insieme al caricamento delle immagini remote, se l'utente sceglie la modalità più restrittiva.

## 6. Tempo di validazione

- **[I]** L'attributo `signingTime` è firmato ma dichiarato dal mittente, quindi non è una prova temporale. Validare "adesso" fa diventare invalidi i vecchi messaggi quando il certificato scade.
- **[R]** Validare al momento della ricezione e salvare l'esito con la data. Mostrare "valida alla ricezione il …" per i messaggi vecchi, invece di rivalidarli.
- **[F]** Windows offre un modello simile con `CERT_CHAIN_TIMESTAMP_TIME`. Fonte: [CertGetCertificateChain](https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-certgetcertificatechain).

## 7. Raccomandazione completa [R]

1. `X509_STORE` costruito dall'app: lista Mozilla Email (CCADB) inclusa e aggiornata a ogni release, più le ancore aggiunte dall'utente, più i certificati foglia accettati con TOFU (ADR 0012) come stato separato. TOFU non è una catena valida e la UI lo distingue.
2. Purpose S/MIME (`X509_PURPOSE_SMIME_SIGN` / EKU `emailProtection`) e corrispondenza dell'indirizzo `From` con `rfc822Name` del certificato: questo controllo lo facciamo noi, OpenSSL non lo fa.
3. Revoca nell'ordine: CRL/OCSP incluse nel `SignedData`, poi CRL in cache, poi download CRL in background (`X509_CRL_load_http` con timeout breve). OCSP solo su opt-in.
4. `X509_V_FLAG_CRL_CHECK_ALL` solo quando le CRL di tutta la catena sono disponibili. Altrimenti si verifica senza il flag e si mostra lo stato "revoca non verificata" (soft-fail esplicito, mai "valido" pieno).
5. Esiti possibili:
   - valida;
   - valida, revoca non verificata;
   - fidata al primo uso;
   - catena sconosciuta;
   - revocata;
   - firma rotta.

## Punti aperti (possono cambiare la raccomandazione)

1. **CA aziendali e PA italiane.** Molti certificati della PA e delle aziende italiane vengono da CA qualificate eIDAS o interne, non presenti nella lista Mozilla Email. Va deciso se usare anche la [EU Trusted List](https://eidas.ec.europa.eu/efda/tl-browser/) o le radici di sistema su Apple e Windows. Se il target principale è la PA, il "secondo parere" nativo diventa prioritario.
2. **Windows: separazione per scopo nello store.** Non verificata su fonte primaria in questa ricerca. Va controllato come leggere le proprietà EKU (`CERT_ENHKEY_USAGE_PROP_ID`) se si vuole usare lo store di sistema.
3. **Comportamento reale di `PKIXRevocationChecker` su Android.** Supporto CRL con URL HTTP, timeout, cache. Non testato. Rilevante solo se si sceglie la via nativa.
4. **Dimensione e frequenza delle CRL.** Alcune CA S/MIME pubblicano CRL grandi. Va misurato su un campione di CA (limite 32 MB di `X509_CRL_load_http`, uso di rete su mobile).
5. **Aggiornamento della lista Mozilla** tra una release e l'altra: inclusa solo nella build, o scaricata e firmata? Senza backend, l'opzione più semplice è nella build.
6. **Linux con libcrypto di sistema (ADR 0012):** le versioni delle distro possono essere precedenti a 3.6. Le API usate devono restare nel sottoinsieme 3.0.
