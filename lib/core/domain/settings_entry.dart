import 'package:equatable/equatable.dart';

/// Una voce delle Impostazioni di Postino con quanto serve a last-write-wins (ADR 0016).
class const SettingsEntry({
  /// La chiave della voce, per esempio `auto_labels/<accountId>`.
  required final String key,

  /// Il valore come testo JSON; null per un tombstone.
  required final String? value,

  /// Quando la voce è stata scritta, in millisecondi UTC dall'epoca.
  required final int updatedAt,

  /// Il dispositivo che l'ha scritta: decide a parità di [updatedAt].
  required final String deviceId,

  /// True for a tombstone: the voce was removed, and the removal must win over older copies.
  final bool deleted = false,
}) extends Equatable {
  /// Crea la voce.
  this;

  /// Whether this copy wins over [other] for the same key: later [updatedAt], on a tie the greater [deviceId].
  bool winsOver(SettingsEntry other) =>
      updatedAt != other.updatedAt ? updatedAt > other.updatedAt : deviceId.compareTo(other.deviceId) > 0;

  @override
  List<Object?> get props => [key, value, updatedAt, deviceId, deleted];

  /// Never the value: a voce `credentials/` holds a secret until the cycle swaps it for its fingerprint (ADR 0019).
  @override
  String toString() => 'SettingsEntry($key, $updatedAt, $deviceId${deleted ? ', deleted' : ''})';
}
