// The components of the Etichette (#107): one golden each (light and dark × text 100% and 200%) and the guidelines.
import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:postino/design_system/design_system.dart';

import '../support/golden_grid.dart';

void _noop() {}
const _sky = (color: PostinoAccountColor.sky, initial: 'L');
final _strings = PostinoLabelPickerStrings(
  search: 'Cerca o crea un’Etichetta',
  nestHelp: 'Usa «/» per annidarla, es. Progetti/Postino.',
  create: (name) => 'Crea «$name»',
  selected: (n) => 'Etichette, $n ${n == 1 ? 'selezionata' : 'selezionate'}',
  empty: 'Nessuna Etichetta',
);
const _labels = <PostinoLabelOption>[
  (id: 'l1', name: 'Fatture'),
  (id: 'l2', name: 'Progetti'),
  (id: 'l3', name: 'Progetti/Postino'),
];

Widget _picker() => PostinoLabelPicker(
  labels: _labels,
  selected: const {'l1'},
  onToggle: (_) {},
  onCreate: (_) {},
  validateName: (_) => null,
  strings: _strings,
);

/// Runs [open] with the context of [child] on the first frame: a route over a cell of the grid.
class const _Opens({required final void Function(BuildContext anchor) open, required final Widget child})
    extends StatefulWidget {
  @override
  State<_Opens> createState() => _OpensState();
}

class _OpensState() extends State<_Opens> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A pane of [height] with its own Navigator, [narrow] under `breakpoint-medium`, where [open] shows a route
/// anchored to an icon button at the top right.
Widget _pane(void Function(BuildContext anchor) open, {bool narrow = false, double height = 460}) => SizedBox(
  height: height,
  child: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: Size(narrow ? 328 : 720, height)),
      child: Navigator(
        onGenerateRoute: (_) => PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => Align(
            alignment: Alignment.topRight,
            child: _Opens(
              open: open,
              child: PostinoIconButton(icon: PostinoIcons.tag, label: 'Etichette', onPressed: () {}),
            ),
          ),
        ),
      ),
    ),
  ),
);

void _popover(BuildContext anchor) =>
    unawaited(showPostinoPopover<void>(anchor, label: 'Etichette', barrierLabel: 'Chiudi', builder: (_) => _picker()));

void _dialog(BuildContext anchor) => unawaited(
  showPostinoDialog<bool>(
    anchor,
    title: 'Scaricare 310 MB su rete cellulare?',
    cancelValue: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PostinoSpacing.s4,
      children: [
        const Text('Il modello delle Etichette automatiche è grande: con il Wi-Fi non consumi dati.'),
        PostinoDialogActions(
          children: [
            PostinoButton(label: 'Aspetta il Wi-Fi', variant: PostinoButtonVariant.ghost, onPressed: () {}),
            PostinoButton(label: 'Scarica ora', autofocus: true, onPressed: () {}),
          ],
        ),
      ],
    ),
  ),
);

final _routes = <String, Widget Function()>{
  'popover': () => _pane(_popover),
  'popover_sheet': () => _pane(_popover, narrow: true),
  'dialog': () => _pane(_dialog),
  'dialog_sheet': () => _pane(_dialog, narrow: true),
};

final _components = <String, Widget Function()>{
  'icon_etichette': () => Wrap(
    spacing: 8,
    children: [
      for (final i in [PostinoIcons.plus, PostinoIcons.search, PostinoIcons.settings, PostinoIcons.chevronRight])
        PostinoIcon(i, size: PostinoSize.iconLg),
    ],
  ),
  'checkbox_tile': () => Column(
    children: [
      PostinoCheckboxTile(label: 'Fatture', value: true, onChanged: (_) {}),
      PostinoCheckboxTile(label: 'Progetti/Postino', value: false, onChanged: (_) {}),
    ],
  ),
  'switch': () => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          PostinoSwitch(value: true, label: 'Automatica', onChanged: (_) {}),
          PostinoSwitch(value: false, label: 'Automatica', onChanged: (_) {}),
        ],
      ),
      PostinoSwitchRow(title: 'Fatture', description: 'Automatica', value: true, onChanged: (_) {}),
    ],
  ),
  'settings_item': () => const PostinoSettingsSection(
    title: 'Account',
    children: [PostinoSettingsItem(title: 'Etichette automatiche', subtitle: '2 attive', onTap: _noop)],
  ),
  'text_field': () => Column(
    spacing: 16,
    children: [
      PostinoTextField(
        label: 'Cerca o crea un’Etichetta',
        icon: PostinoIcons.search,
        controller: TextEditingController(text: 'Viaggi'),
        helper: 'Usa «/» per annidarla, es. Progetti/Postino.',
      ),
      const PostinoTextField(
        label: 'Descrizione (facoltativa)',
        multiline: true,
        helper: 'Descrivi che email ci vanno, es. fatture e ricevute dei fornitori',
      ),
      PostinoTextField(
        label: 'Nome',
        controller: TextEditingController(text: 'Progetti/'),
        error: 'Ogni livello ha bisogno di un nome: «Progetti/Postino», non «Progetti/».',
      ),
    ],
  ),
  'progress': () => const Column(
    spacing: 16,
    children: [
      PostinoProgressBar(label: 'Download del modello', value: 0.54),
      PostinoSpinner(label: 'Preparazione del modello'),
    ],
  ),
  'label_picker': () => Builder(
    builder: (context) => Material(color: context.pc.surfaceRaised, child: _picker()),
  ),
  'label_chip_removable': () => Wrap(
    spacing: 8,
    children: [
      for (final l in ['Fatture', 'Progetti/Postino'])
        PostinoLabelChip(name: l, onRemove: () {}, removeLabel: 'Togli Etichetta $l'),
    ],
  ),
  'banner_progress': () => const Column(
    children: [
      PostinoBanner(
        tone: PostinoBannerTone.info,
        leading: PostinoSpinner(label: 'Preparazione'),
        title: 'Preparazione delle Etichette automatiche',
      ),
      PostinoBanner(
        tone: PostinoBannerTone.info,
        icon: PostinoIcons.download,
        title: 'Download del modello',
        message: '167 MB di 310 MB · 54%',
        progress: PostinoProgressBar(label: 'Download del modello', value: 0.54),
      ),
    ],
  ),
  'message_tile_labels': () => const PostinoMessageTile(
    sender: 'Ada Okafor',
    subject: 'Fattura di ottobre',
    preview: 'In allegato la fattura del mese.',
    time: '09:42',
    unread: false,
    starred: false,
    labels: ['Fatture', 'Progetti/Postino'],
    semanticLabel: 'Ada Okafor, Etichette Fatture e Progetti/Postino',
  ),
  'thread_view_removable': () => SizedBox(
    height: 220,
    child: PostinoThreadView(
      subject: 'Fattura di ottobre',
      account: _sky,
      accountName: 'lavoro@example.com',
      labels: const ['Fatture', 'Progetti'],
      onRemoveLabel: (_) {},
      removeLabelName: (l) => 'Togli Etichetta $l',
      messages: const [],
    ),
  ),
  'settings_page': () => SizedBox(
    height: 560,
    child: PostinoSettingsPage(
      title: 'Etichette automatiche',
      subtitle: 'Impostazioni · Lavoro',
      account: _sky,
      onBack: () {},
      intro: 'Postino dà un’Etichetta alle email nuove con un modello che gira sul dispositivo.',
      sections: [
        PostinoSettingsSection(
          title: 'Etichette',
          children: [
            PostinoSwitchRow(title: 'Fatture', description: 'Automatica', value: true, onChanged: (_) {}),
            PostinoSwitchRow(title: 'Progetti', description: 'Automatica', value: false, onChanged: (_) {}),
          ],
        ),
      ],
    ),
  ),
};

void main() {
  testComponentGoldens(_components);
  testComponentGoldens(_routes, settle: true);
}
