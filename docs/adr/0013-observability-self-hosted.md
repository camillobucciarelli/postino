---
status: Accettato
date: 2026-10-28
---

# Observability self-hosted nella v2

Nella v2 Postino può mandare, solo con consenso, segnali a uno stack open source ospitato dall'autore. Supera in parte la [ADR 0001](0001-nessun-backend.md): l'unico backend ammesso è questo endpoint di observability. La posta continua a non passare da nessun server.

## Decisione

- **Segnali**: errori e stack trace; metriche tecniche (durata della sincronizzazione, errori del Provider, tempo di avvio, versione, piattaforma); metriche d'uso (schermate e Azioni usate, senza contenuti). Niente tracce: l'SDK OpenTelemetry per Dart è immaturo. Si aggiungono se servono a capire una lentezza.
- **Stack**: OpenTelemetry Collector (OTLP/HTTP, unico endpoint esposto), Loki, Prometheus e Grafana, in Docker Compose su una VPS dell'autore.
- **Consenso**: opt-in nelle Impostazioni del dispositivo, spento di default. Solo dati tecnici: mai oggetti, corpi, indirizzi o token. L'identificativo d'installazione è casuale e non ha nessun legame con l'Account.
- **Segnalazione di un problema**: con l'opt-in attivo Postino non propone più l'email al riavvio dopo un crash, perché l'errore arriva già allo stack. L'azione «Segnala un problema» resta. Senza opt-in tutto come nella v1.

## Alternative considerate

- **GlitchTip / Sentry self-hosted**: solo errori. Scartata.
- **SigNoz**: più pesante da ospitare. Scartata.
- **Versione ridotta, solo errori**, con Loki senza Collector e Prometheus. Scartata: l'autore vuole metriche tecniche e d'uso.

## Conseguenze

- Una VPS da mantenere e aggiornare.
- Serve un'informativa sui dati raccolti.
- Rivede per la v2 la scelta «nessuna metrica» di [Crash reporting e telemetria](https://github.com/camillobucciarelli/postino/issues/16).
