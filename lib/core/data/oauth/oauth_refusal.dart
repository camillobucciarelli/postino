import '../../domain/result.dart';

/// The organization's refusal named by an OAuth [error] and its [description] (the `AADSTS…` codes of Microsoft
/// Entra ID), from the callback or the token endpoint; null for any other error.
Failure? organizationRefusal(String? error, String? description) {
  final d = description ?? '';
  if (error == 'consent_required' || d.contains('AADSTS65001') || d.contains('AADSTS90094')) {
    return const AdminConsentFailure();
  }
  if (d.contains('AADSTS53003') || d.contains('AADSTS50105')) return const OrganizationPolicyFailure();
  return null;
}
