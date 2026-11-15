import 'package:flutter/widgets.dart';

import '../../../core/domain/app_version.dart';
import '../../../design_system/design_system.dart';
import '../../../i18n/strings.g.dart';

/// The version of Postino installed (#297), as quiet meta text under «Cerca aggiornamenti»: a value, so it is
/// selectable and copiable; read by the screen reader as one sentence, not a control.
class const AppVersionLabel({super.key, final AppVersion version = const AppVersion.installed()})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.t.impostazioni;
    final text = version.isDevelopment
        ? t.versionDevelopment
        : t.versionLabel(version: version.version, build: version.build);
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PostinoSpacing.s4, vertical: PostinoSpacing.s3),
        child: PostinoSelectable(
          child: Text(text, style: PostinoText.caption.copyWith(color: context.pc.inkMuted)),
        ),
      ),
    );
  }
}
