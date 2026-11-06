import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// GreenMail standalone: la versione e il suo SHA-256 sono fissati qui. Il jar si scarica solo da Maven Central
/// (repo ufficiale del progetto, vedi https://greenmail-mail-test.github.io/greenmail/) e non si committa.
const greenmailVersion = '2.1.15';
const greenmailSha256 = '91d58798698cac357f015365240383b936ced2f2a1a9f7db37d9e3e1a31391b1';
const _jarUrl =
    'https://repo1.maven.org/maven2/com/icegreen/greenmail-standalone/$greenmailVersion/greenmail-standalone-$greenmailVersion.jar';

/// Se impostata a `1` (la CI) un server di test mancante fa fallire i test invece di saltarli.
const requireServerEnv = 'POSTINO_REQUIRE_IMAP_SERVER';

String get _java {
  final home = Platform.environment['JAVA_HOME'];
  return home == null || home.isEmpty ? 'java' : '$home/bin/java';
}

/// Perché i test `imap` vanno saltati, o `null` se vanno eseguiti. Senza Java si salta con un messaggio chiaro,
/// ma in CI ([requireServerEnv]) l'assenza non si salta: il test fallirà all'avvio del server.
String? get imapSkipReason {
  if (Platform.environment[requireServerEnv] == '1') return null;
  try {
    if (Process.runSync(_java, ['-version']).exitCode == 0) return null;
  } on ProcessException {
    // Java non c'è.
  }
  return 'Java non trovato: serve per il server di test GreenMail (JDK 17 o più recente, o JAVA_HOME). '
      'In CI ($requireServerEnv=1) il test fallisce invece di essere saltato.';
}

/// Un server IMAP+SMTP locale (GreenMail) su porte libere, con TLS autofirmato.
class GreenmailServer._(
  final Process _process,

  /// IMAP e SMTP sono su TLS implicito (GreenMail non offre STARTTLS); il certificato è autofirmato.
  final int imapsPort,
  final int smtpsPort,
  final int _apiPort,
) {
  final _http = _realClient();

  static const host = '127.0.0.1';

  /// Scarica il jar se manca (verificando il checksum) e avvia il server; fallisce con un errore chiaro.
  static Future<GreenmailServer> start() async {
    final jar = await _jar();
    final ports = [for (var i = 0; i < 3; i++) await _freePort()];
    final process = await Process.start(_java, [
      '-Dgreenmail.imaps.hostname=$host',
      '-Dgreenmail.imaps.port=${ports[0]}',
      '-Dgreenmail.smtps.hostname=$host',
      '-Dgreenmail.smtps.port=${ports[1]}',
      '-Dgreenmail.api.hostname=$host',
      '-Dgreenmail.api.port=${ports[2]}',
      '-jar',
      jar.path,
    ]);
    final output = StringBuffer();
    process.stdout.transform(utf8.decoder).listen(output.write);
    process.stderr.transform(utf8.decoder).listen(output.write);
    final server = GreenmailServer._(process, ports[0], ports[1], ports[2]);
    final exited = process.exitCode.then((c) => 'GreenMail terminato con codice $c:\n$output');
    for (var i = 0; i < 100; i++) {
      final early = await Future.any<String?>([exited, Future.delayed(const Duration(milliseconds: 100))]);
      if (early != null) throw StateError(early);
      try {
        final ready = await server._http.get(Uri.parse('${server._api}/service/readiness'));
        if (ready.statusCode == 200) return server;
      } on Exception {
        // Non ancora in ascolto.
      }
    }
    process.kill();
    throw StateError('GreenMail non è partito entro 10 s:\n$output');
  }

  String get _api => 'http://$host:$_apiPort/api';

  /// L'indirizzo dell'utente [login].
  static String addressOf(String login) => '$login@localhost';

  Future<void> createUser(String login, String password) async {
    final r = await _http.post(
      Uri.parse('$_api/user'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'email': addressOf(login), 'login': login, 'password': password}),
    );
    if (r.statusCode != 200) throw StateError('createUser $login: ${r.statusCode} ${r.body}');
  }

  /// Elimina l'utente con la sua posta; ricrearlo dà una casella nuova (nuovo UIDVALIDITY).
  Future<void> deleteUser(String login) async {
    final r = await _http.delete(Uri.parse('$_api/user/${addressOf(login)}'));
    if (r.statusCode != 200) throw StateError('deleteUser $login: ${r.statusCode} ${r.body}');
  }

  Future<void> stop() async {
    _http.close();
    _process.kill();
    await _process.exitCode;
  }
}

/// `flutter test` sostituisce l'HttpClient con uno che risponde 400: qui servono rete e localhost veri.
http.Client _realClient() => HttpOverrides.runWithHttpOverrides(http.Client.new, _RealHttp());

class _RealHttp() extends HttpOverrides;

Future<int> _freePort() async {
  final s = await ServerSocket.bind(GreenmailServer.host, 0);
  final port = s.port;
  await s.close();
  return port;
}

Future<File> _jar() async {
  final file = File('.dart_tool/greenmail/greenmail-standalone-$greenmailVersion.jar');
  if (file.existsSync() && sha256.convert(file.readAsBytesSync()).toString() == greenmailSha256) return file;
  final client = _realClient();
  final http.Response response;
  try {
    response = await client.get(Uri.parse(_jarUrl));
  } finally {
    client.close();
  }
  if (response.statusCode != 200) throw StateError('Download di GreenMail fallito: ${response.statusCode} $_jarUrl');
  final digest = sha256.convert(response.bodyBytes).toString();
  if (digest != greenmailSha256) {
    throw StateError('Checksum di GreenMail errato: atteso $greenmailSha256, scaricato $digest');
  }
  file.parent.createSync(recursive: true);
  // Scrittura atomica: più file di test possono scaricare insieme.
  final tmp = File('${file.path}.$pid.tmp')..writeAsBytesSync(response.bodyBytes);
  return tmp.renameSync(file.path);
}
