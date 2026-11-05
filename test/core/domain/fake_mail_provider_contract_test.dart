import 'mail_provider_contract.dart';

void main() {
  mailProviderContract('FakeMailProvider', FakeHarness.new);
  mailProviderActionContract('FakeMailProvider', FakeHarness.new);
}
