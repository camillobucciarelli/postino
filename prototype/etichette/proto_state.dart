// PROTOTIPO usa-e-getta (#106): stato finto in memoria, nessuna mutazione reale.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

/// The three ways of assigning an Etichetta being compared.
enum ProtoVariant() {
  a,
  b,
  c;

  String get label => switch (this) {
    a => 'A (Popover con ricerca)',
    b => 'B (Chip inline)',
    c => 'C (Pannello/Dialog)',
  };
}

/// The download of the on-device model for the Etichette automatiche.
enum ModelPhase() {
  assente,
  preparazione,
  confermaCellulare,
  attesaWifi,
  download,
  errore,
  pronto;

  String get label => switch (this) {
    assente => 'assente',
    preparazione => 'in preparazione',
    confermaCellulare => 'in attesa di conferma',
    attesaWifi => 'in attesa del Wi-Fi',
    download => 'in download',
    errore => 'errore',
    pronto => 'pronto',
  };
}

enum ProtoPage() {
  posta,
  impostazioni,
}

/// An Etichetta utente, with its Etichettatura automatica setting.
class ProtoLabel(final String name) {
  bool auto = false;
  String description = '';
}

/// A fake Conversazione; [labels] is mutated in place.
class FakeThread({
  required final String id,
  required final String sender,
  required final String subject,
  required final String preview,
  required final String time,
  required final String body,
  required final Set<String> labels,
  final bool unread = false,
  final bool starred = false,
}) {}

const account = (color: PostinoAccountColor.blue, initial: 'C');
const accountName = 'camillo@gmail.com';
const modelMb = 310;

/// The whole prototype: one instance, [proto].
class ProtoState() extends ChangeNotifier {
  ProtoVariant variant = ProtoVariant.a;
  bool cellular = false;
  bool simulateError = false;
  bool chipsInList = true;
  bool dark = false;
  bool large = false;
  ProtoPage page = ProtoPage.posta;
  String? openId;
  String? filter;

  ModelPhase phase = ModelPhase.assente;
  double progress = 0;
  Timer? _timer;

  /// Shows «Etichette automatiche pronte» (set by the app).
  VoidCallback? onReady;

  /// Opens the label picker of the open Conversazione (`l`); set by the Conversazione.
  VoidCallback? openLabels;

  final labels = [
    for (final n in ['Banca', 'Famiglia', 'Fatture', 'Lavoro', 'Newsletter', 'Progetti/Postino', 'Viaggi'])
      ProtoLabel(n),
  ];

  final threads = <FakeThread>[
    FakeThread(
      id: '1',
      sender: 'Enel Energia',
      subject: 'La tua bolletta di ottobre è disponibile',
      preview: 'Importo 84,20 €, scadenza 15 novembre. Scarica il PDF dall’area clienti.',
      time: '09:42',
      body: 'Gentile cliente, la bolletta di ottobre è disponibile. Importo 84,20 €, scadenza 15 novembre.',
      labels: {'Fatture'},
      unread: true,
    ),
    FakeThread(
      id: '2',
      sender: 'Trenitalia',
      subject: 'Biglietto Roma–Milano, 12 novembre',
      preview: 'Frecciarossa 9541, carrozza 7, posto 12A. Codice PNR QX7L2M.',
      time: '08:15',
      body: 'Grazie per aver scelto Trenitalia. Frecciarossa 9541 delle 07:10, carrozza 7, posto 12A.',
      labels: {'Viaggi'},
      unread: true,
      starred: true,
    ),
    FakeThread(
      id: '3',
      sender: 'Giulia Rossi',
      subject: 'Revisione del design delle Etichette',
      preview: 'Ho guardato le tre varianti: la A mi convince, ma il dialog è più chiaro su mobile…',
      time: 'Ieri',
      body: 'Ciao Camillo, ho guardato le tre varianti. La A mi convince su desktop, la C è più chiara su mobile.',
      labels: {'Lavoro', 'Progetti/Postino'},
    ),
    FakeThread(
      id: '4',
      sender: 'Mamma',
      subject: 'Pranzo di domenica',
      preview: 'Porti tu il dolce? Ci sono anche gli zii, siamo in dieci.',
      time: 'Ieri',
      body: 'Porti tu il dolce? Ci sono anche gli zii, siamo in dieci. Un bacio.',
      labels: {'Famiglia'},
    ),
    FakeThread(
      id: '5',
      sender: 'Banca Sella',
      subject: 'Estratto conto di ottobre',
      preview: 'Il tuo estratto conto è disponibile nell’app. Saldo al 31/10.',
      time: 'lun',
      body: 'Il tuo estratto conto di ottobre è disponibile nell’app e nell’home banking.',
      labels: {'Banca'},
    ),
    FakeThread(
      id: '6',
      sender: 'Flutter Weekly',
      subject: 'Primary constructors are here',
      preview: 'This week: Dart 3.13, primary constructors, and a new take on Semantics.',
      time: 'dom',
      body: 'This week: Dart 3.13 ships primary constructors. Plus: Semantics roles and a new testing API.',
      labels: {'Newsletter'},
    ),
    FakeThread(
      id: '7',
      sender: 'Booking.com',
      subject: 'Conferma prenotazione: Hotel Navigli',
      preview: 'Check-in 12 novembre, check-out 14 novembre. Pagamento in struttura.',
      time: '2 nov',
      body: 'La tua prenotazione all’Hotel Navigli è confermata. Check-in 12 novembre dalle 14:00.',
      labels: {},
    ),
    FakeThread(
      id: '8',
      sender: 'Marco Bianchi',
      subject: 'Calcetto giovedì?',
      preview: 'Manca uno per giovedì alle 21, ci sei?',
      time: '1 nov',
      body: 'Manca uno per giovedì alle 21 al solito campo, ci sei?',
      labels: {},
    ),
  ];

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  FakeThread? get open => threads.where((t) => t.id == openId).firstOrNull;

  // --- Etichette ----------------------------------------------------------

  /// «Progetti / Postino » → «Progetti/Postino».
  static String normalize(String raw) => raw.split('/').map((p) => p.trim()).join('/');

  /// Why [raw] cannot be a new Etichetta (case-insensitive against [labels] and [pending]), or null.
  String? nameError(String raw, {Iterable<String> pending = const []}) {
    final name = normalize(raw);
    if (name.isEmpty) return 'Scrivi un nome per l’Etichetta.';
    if (name.split('/').any((p) => p.isEmpty)) {
      return 'Ogni livello ha bisogno di un nome: «Progetti/Postino», non «Progetti/».';
    }
    final same = [...labels.map((l) => l.name), ...pending].where((n) => n.toLowerCase() == name.toLowerCase());
    if (same.isNotEmpty) return 'Esiste già un’Etichetta «${same.first}».';
    return null;
  }

  ProtoLabel? find(String name) => labels.where((l) => l.name.toLowerCase() == name.trim().toLowerCase()).firstOrNull;

  /// Creates the Etichetta (call [nameError] first) and returns its name.
  String create(String raw) {
    final l = ProtoLabel(normalize(raw));
    update(() {
      labels
        ..add(l)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
    return l.name;
  }

  void deleteLabels(Iterable<String> names) => update(() {
    labels.removeWhere((l) => names.contains(l.name));
    for (final t in threads) {
      t.labels.removeAll(names);
    }
  });

  // --- Modello -------------------------------------------------------------

  int get percent => (progress * 100).round();

  /// For screen readers: only every 25%, not every tick.
  int get steppedPercent => (progress * 100) ~/ 25 * 25;

  String get progressText => '${(modelMb * progress).round()} MB di $modelMb MB · $percent%';

  Future<void> prepare() async {
    update(() => phase = ModelPhase.preparazione);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }

  void askCellular() => update(() => phase = ModelPhase.confermaCellulare);

  void waitWifi() => update(() => phase = ModelPhase.attesaWifi);

  /// Starts or resumes: ~15 s from 0 to 100%.
  void startDownload() {
    _timer?.cancel();
    update(() => phase = ModelPhase.download);
    _timer = Timer.periodic(const Duration(milliseconds: 150), (t) {
      update(() => progress = math.min(1, progress + 0.01));
      if (simulateError && progress >= 0.6) {
        t.cancel();
        // ponytail: one-shot failure, so Riprova goes on; switch it on again to fail again.
        update(() {
          simulateError = false;
          phase = ModelPhase.errore;
        });
      } else if (progress >= 1) {
        t.cancel();
        update(() => phase = ModelPhase.pronto);
        onReady?.call();
      }
    });
  }

  void setCellular({required bool value}) {
    update(() => cellular = value);
    if (!value && (phase == ModelPhase.attesaWifi || phase == ModelPhase.confermaCellulare)) startDownload();
  }

  /// Back to the start: model absent, every Etichetta manual again.
  void resetModel() {
    _timer?.cancel();
    update(() {
      phase = ModelPhase.assente;
      progress = 0;
      for (final l in labels) {
        l.auto = false;
      }
    });
  }
}

final proto = ProtoState();

/// Rebuilds its dependents when [proto] changes.
class const Proto({super.key, required super.notifier, required super.child}) extends InheritedNotifier<ProtoState> {
  static ProtoState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Proto>()!.notifier!;
}

/// A context under the app's ScaffoldMessenger, for snackbars shown after a popover or dialog closed.
late BuildContext appContext;
