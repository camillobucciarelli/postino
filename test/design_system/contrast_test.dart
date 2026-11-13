// WCAG 2.2 AA on the real tokens, light and dark: text 4.5:1, icons, borders and UI parts 3:1.
// The colors are composited as the screen shows them: translucent tokens over their background,
// the theme's focus, hover and pressed overlays over the rows they light up.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postino/design_system/tokens/postino_theme.dart';
import 'package:postino/design_system/tokens/postino_tokens.dart';

typedef _Token = Color Function(PostinoColors c);

const _text = 4.5;
const _ui = 3.0;

double _ratio(Color fg, Color bg) {
  final f = Color.alphaBlend(fg, bg).computeLuminance();
  final b = bg.computeLuminance();
  return (f > b ? f + 0.05 : b + 0.05) / (f > b ? b + 0.05 : f + 0.05);
}

/// (where it is used, foreground, backgrounds, minimum ratio)
final _pairs = <(String, _Token, List<_Token>, double)>[
  (
    'MessageTile unread sender and subject',
    (c) => c.listItemFgUnread,
    [(c) => c.listItemBg, (c) => c.listItemBgSelected],
    _text,
  ),
  (
    'MessageTile read sender, subject, preview',
    (c) => c.listItemFgRead,
    [(c) => c.listItemBg, (c) => c.listItemBgSelected],
    _text,
  ),
  (
    'MessageTile time and thread count',
    (c) => c.listItemMeta,
    [(c) => c.listItemBg, (c) => c.listItemBgSelected],
    _text,
  ),
  ('MessageTile unread time', (c) => c.brand, [(c) => c.listItemBg, (c) => c.listItemBgSelected], _text),
  ('MessageTile unread dot', (c) => c.unread, [(c) => c.listItemBg, (c) => c.listItemBgSelected], _ui),
  ('unread dot of the icon sidebar', (c) => c.unread, [(c) => c.drawerBg, (c) => c.drawerItemBgActive], _ui),
  ('Da ricollegare badge of the icon sidebar', (c) => c.warning, [(c) => c.drawerBg], _ui),
  (
    'star in the list, Importante in the Conversazione',
    (c) => c.star,
    [(c) => c.listItemBg, (c) => c.listItemBgSelected, (c) => c.surface],
    _ui,
  ),
  (
    'ink text',
    (c) => c.ink,
    [(c) => c.surface, (c) => c.surfaceRaised, (c) => c.surfaceGround, (c) => c.surfaceSelected],
    _text,
  ),
  ('ink-muted text', (c) => c.inkMuted, [(c) => c.surface, (c) => c.surfaceGround], _text),
  (
    'PostinoSuggestions address, on the panel and on the highlighted row',
    (c) => c.inkMuted,
    [(c) => c.surfaceRaised, (c) => c.surfaceSelected],
    _text,
  ),
  (
    'ink-muted icons (IconButton, chevron, quote toggle)',
    (c) => c.inkMuted,
    [(c) => c.surface, (c) => c.surfacePressed],
    _ui,
  ),
  (
    'ink-subtle text (subtitle, time, details, hint)',
    (c) => c.inkSubtle,
    [(c) => c.surface, (c) => c.surfaceGround, (c) => c.inputBg],
    _text,
  ),
  ('drawer section title', (c) => c.inkSubtle, [(c) => c.drawerBg], _text),
  ('drawer item', (c) => c.drawerItemFg, [(c) => c.drawerBg, (c) => c.drawerItemBgActive], _text),
  ('drawer item icon', (c) => c.drawerItemIcon, [(c) => c.drawerBg], _ui),
  ('drawer active item icon', (c) => c.drawerItemIconActive, [(c) => c.drawerItemBgActive], _ui),
  ('SyncStatus icon', (c) => c.warning, [(c) => c.drawerBg, (c) => c.surface], _ui),
  (
    'Banner text',
    (c) => c.ink,
    [(c) => c.dangerSubtle, (c) => c.warningSubtle, (c) => c.brandSubtle, (c) => c.surfacePressed],
    _text,
  ),
  ('Banner danger icon', (c) => c.danger, [(c) => c.dangerSubtle], _ui),
  ('Banner warning icon', (c) => c.warning, [(c) => c.warningSubtle], _ui),
  ('Banner info icon', (c) => c.brand, [(c) => c.brandSubtle], _ui),
  ('Banner offline icon', (c) => c.inkMuted, [(c) => c.surfacePressed], _ui),
  ('EmptyState icon', (c) => c.brand, [(c) => c.surfaceSelected], _ui),
  ('primary button', (c) => c.onBrand, [(c) => c.brand], _text),
  ('ghost button', (c) => c.brand, [(c) => c.surface, (c) => c.surfaceRaised], _text),
  ('FAB', (c) => c.fabFg, [(c) => c.fabBg], _text),
  (
    'AccountMark initial',
    (c) => c.onAccount,
    [for (final a in PostinoAccountColor.values) (c) => c.account(a).color],
    _text,
  ),
  for (final a in PostinoAccountColor.values)
    (
      'AccountMark and account bar (${a.name})',
      (c) => c.account(a).color,
      [(c) => c.listItemBg, (c) => c.drawerBg, (c) => c.surface],
      _ui,
    ),
  ('Avatar, LabelChip (stone)', (c) => c.labelStoneFg, [(c) => c.labelStoneBg], _text),
  ('Avatar, LabelChip (sand)', (c) => c.labelSandFg, [(c) => c.labelSandBg], _text),
  ('Avatar, LabelChip (sage)', (c) => c.labelSageFg, [(c) => c.labelSageBg], _text),
  ('Avatar, LabelChip (sea)', (c) => c.labelSeaFg, [(c) => c.labelSeaBg], _text),
  ('Avatar, LabelChip (lilac)', (c) => c.labelLilacFg, [(c) => c.labelLilacBg], _text),
  ('Avatar, LabelChip (blush)', (c) => c.labelBlushFg, [(c) => c.labelBlushBg], _text),
  (
    'strong borders (outlined button, checkbox, switch, drag handle, list resize handle)',
    (c) => c.borderStrong,
    [(c) => c.surface, (c) => c.surfaceRaised, (c) => c.surfaceGround, (c) => c.listItemBg],
    _ui,
  ),
  ('input border', (c) => c.inputBorder, [(c) => c.inputBg, (c) => c.surface], _ui),
  ('input border with focus', (c) => c.inputBorderFocus, [(c) => c.inputBg], _ui),
  ('input border in error', (c) => c.inputBorderError, [(c) => c.inputBg], _ui),
  ('tooltip', (c) => c.inkInverse, [(c) => c.surfaceInverse], _text),
  ('SnackBar text', (c) => c.snackbarFg, [(c) => c.snackbarBg], _text),
  ('SnackBar action', (c) => c.snackbarAction, [(c) => c.snackbarBg], _text),
  ('Material Chip', (c) => c.chipFg, [(c) => c.chipBg, (c) => c.chipBgSelected], _text),
  ('TabBar indicator', (c) => c.tabIndicator, [(c) => c.surface], _ui),
  ('Switch track on', (c) => c.switchTrackOn, [(c) => c.surface], _ui),
  (
    'focus ring on what it surrounds or sits on',
    (c) => c.focusRing,
    [
      (c) => c.surface,
      (c) => c.surfaceRaised,
      (c) => c.surfaceGround,
      (c) => c.surfacePressed,
      (c) => c.listItemBg,
      (c) => c.listItemBgSelected,
      (c) => c.drawerBg,
      (c) => c.drawerItemBgActive,
      (c) => c.dangerSubtle,
      (c) => c.warningSubtle,
      (c) => c.brandSubtle,
      (c) => c.inputBg,
    ],
    _ui,
  ),
];

/// The texts of a row lit by the InkWell overlays, over each background of that row.
final _rows = <(String, List<_Token>, List<(String, _Token, double)>)>[
  (
    'MessageTile',
    [(c) => c.listItemBg, (c) => c.listItemBgSelected],
    [
      ('list-item-fg-read', (c) => c.listItemFgRead, _text),
      ('list-item-meta', (c) => c.listItemMeta, _text),
      ('brand', (c) => c.brand, _text),
      ('list-item-fg-unread', (c) => c.listItemFgUnread, _text),
      ('star', (c) => c.star, _ui),
    ],
  ),
  (
    'ThreadMessage header',
    [(c) => c.surface],
    [('ink', (c) => c.ink, _text), ('ink-muted', (c) => c.inkMuted, _text), ('ink-subtle', (c) => c.inkSubtle, _text)],
  ),
];

void main() {
  for (final (theme, data) in [('light', PostinoTheme.light()), ('dark', PostinoTheme.dark())]) {
    final c = data.extension<PostinoColors>()!;
    group(theme, () {
      for (final (where, fg, bgs, min) in _pairs) {
        test(where, () {
          for (final bg in bgs) {
            expect(_ratio(fg(c), bg(c)), greaterThanOrEqualTo(min), reason: '${fg(c)} on ${bg(c)}');
          }
        });
      }

      // Every state a row can show at once: focus fill under, then hover or pressed.
      final overlays = <(String, List<Color>)>[
        ('rest', []),
        ('hover', [data.hoverColor]),
        ('pressed', [data.splashColor]),
        ('focus', [data.focusColor]),
        ('focus + hover', [data.focusColor, data.hoverColor]),
        ('focus + pressed', [data.focusColor, data.splashColor]),
      ];
      for (final (row, bgs, texts) in _rows) {
        test('$row texts stay readable under focus, hover and pressed', () {
          for (final bg in bgs) {
            for (final (state, layers) in overlays) {
              final lit = layers.fold(bg(c), (b, o) => Color.alphaBlend(o, b));
              for (final (name, fg, min) in texts) {
                expect(_ratio(fg(c), lit), greaterThanOrEqualTo(min), reason: '$name on ${bg(c)} + $state');
              }
            }
          }
        });
      }

      test('the inset focus ring stands out from the rows it lights up', () {
        for (final bg in [c.listItemBg, c.listItemBgSelected, c.surface, c.drawerBg, c.drawerItemBgActive]) {
          for (final (state, layers) in overlays.where((o) => o.$1.startsWith('focus'))) {
            final lit = layers.fold(bg, (b, o) => Color.alphaBlend(o, b));
            expect(_ratio(c.focusRing, lit), greaterThanOrEqualTo(_ui), reason: 'focus-ring on $bg + $state');
          }
        }
      });
    });
  }
}
