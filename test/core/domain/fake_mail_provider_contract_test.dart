import 'mail_provider_contract.dart';
import 'mail_provider_search_contract.dart';

void main() {
  mailProviderContract('FakeMailProvider', FakeHarness.new);
  mailProviderActionContract('FakeMailProvider', FakeHarness.new);
  mailProviderSearchContract('FakeMailProvider', FakeHarness.new);
}
