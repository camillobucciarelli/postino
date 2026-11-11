# Postino

Postino è un client email multi-account scritto in Flutter.

## Codegen

```sh
dart run routefly
dart run slang
dart run build_runner build
```

`routefly` rigenera le rotte da `lib/app`; `slang` rigenera le traduzioni (config in `slang.yaml`); `build_runner` rigenera la dependency injection (injectable). Il codice generato è committato.

## Client OAuth di Google

Il client ID non sta nel repository: si passa all'avvio, altrimenti l'onboarding mostra l'errore.

```sh
flutter run --dart-define=GOOGLE_CLIENT_ID=<id>.apps.googleusercontent.com
```

Su iOS, Android e macOS serve un client di tipo iOS (callback sullo schema `com.googleusercontent.apps.<id>`); su Windows e Linux un client "App desktop", con in più `--dart-define=GOOGLE_CLIENT_SECRET=<secret>` (callback su `http://localhost:53682`).

## Client OAuth di Microsoft

Per gli account personali Outlook.com, Hotmail, Live e MSN (endpoint `consumers`, niente account di lavoro o scuola). Anche questo client ID non sta nel repository:

```sh
flutter run --dart-define=MICROSOFT_CLIENT_ID=<application id>
```

L'app va registrata su Microsoft Entra ID come «Personal Microsoft accounts only», client pubblico (nessun secret), con i redirect URI di «Mobile and desktop applications» `msal<application id>://auth` (iOS, Android e macOS) e `http://localhost` (Windows e Linux, loopback sulla porta `53682`), e i permessi delegati di Microsoft Graph `Mail.ReadWrite`, `Mail.Send`, `User.Read`, `offline_access`, `openid` ed `email`. In CI il valore sta nel secret `MICROSOFT_CLIENT_ID`, che `release.yml` richiede insieme a `GOOGLE_CLIENT_ID`. Senza, «Collega Outlook» mostra l'errore.

## Verifica

```sh
flutter analyze && flutter test
```

## Documentazione

- Decisioni architetturali: [`docs/adr`](docs/adr)
- Linguaggio di dominio: [`GLOSSARY.md`](GLOSSARY.md)
