# Postino

Postino è un client email multi-account scritto in Flutter.

## Codegen

```sh
dart run routefly
dart run build_runner build
```

`routefly` rigenera le rotte da `lib/app`; `build_runner` rigenera traduzioni (slang) e dependency injection (injectable). Il codice generato è committato. Su un checkout appena clonato `build_runner` rifiuta di sovrascrivere gli output slang ("Asset already exists"): cancellali prima con `rm lib/i18n/strings*.g.dart`, come fa la CI.

## Verifica

```sh
flutter analyze && flutter test
```

## Documentazione

- Decisioni architetturali: [`docs/adr`](docs/adr)
- Linguaggio di dominio: [`GLOSSARY.md`](GLOSSARY.md)
