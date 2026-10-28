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

## Verifica

```sh
flutter analyze && flutter test
```

## Documentazione

- Decisioni architetturali: [`docs/adr`](docs/adr)
- Linguaggio di dominio: [`GLOSSARY.md`](GLOSSARY.md)
