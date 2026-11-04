import '../atoms/postino_account_mark.dart';

/// One row of the details of a message (“Da”, “A”, “Data”, “Ricevuto su”); [account] puts its mark before [value].
class PostinoMessageDetail {
  const PostinoMessageDetail(this.label, this.value, {this.account});

  final String label;
  final String value;
  final PostinoAccountRef? account;
}
