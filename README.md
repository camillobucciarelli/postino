# Postino

Postino è un client email multi-account scritto in Flutter.

## Codegen

```sh
dart run routefly
dart run slang
dart run build_runner build
```

`routefly` rigenera le rotte da `lib/app`; `slang` rigenera le traduzioni (config in `slang.yaml`); `build_runner` rigenera la dependency injection (injectable). Il codice generato è committato.

## Verifica

```sh
flutter analyze && flutter test
```

## Documentazione

- Decisioni architetturali: [`docs/adr`](docs/adr)
- Linguaggio di dominio: [`GLOSSARY.md`](GLOSSARY.md)
