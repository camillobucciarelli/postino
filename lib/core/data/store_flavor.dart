/// Whether [flavor] is a store variant: Mac App Store (#325, ADR 0021) or Google Play (#345, ADR 0023). `--flavor store`
/// gives `store`; an Xcode build passes the scheme's name, `Store`.
bool isStoreFlavor(String? flavor) => flavor?.toLowerCase() == 'store';
