import 'package:equatable/equatable.dart';

/// The one notification «N nuovi messaggi» of an Account (#210), in place of its single ones when a sync brings more
/// than [summaryThreshold] new messages; tapping it opens the Account's inbox.
class const NewMailSummary({
  /// The Account.
  required final String accountId,

  /// Its address: the title of the group.
  required final String accountAddress,

  /// How many new messages the sync brought.
  required final int count,
}) extends Equatable {
  /// Crea il riepilogo.
  this;

  @override
  List<Object?> get props => [accountId, accountAddress, count];
}

/// Past this many new messages of an Account in one sync, a [NewMailSummary] replaces the single notifications.
const summaryThreshold = 10;
