import '../../domain/message.dart';

/// A folder of the Account: its Graph [id], its [path] from the top (`Lavoro/Progetti`), and the Etichetta id its
/// messages carry: the system one (`INBOX`, `SENT`...) for a well-known folder, else the Graph id.
class const GraphFolder(final String id, final String path, final String labelId) {
  /// An Etichetta of the user (Archivio too: it has no system id), named by its full path as on IMAP.
  Label? get label => labelId == id ? Label(id: id, name: path, kind: LabelKind.cartella) : null;
}
