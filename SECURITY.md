# Security Policy

## Reporting a vulnerability

**Do not open a public issue for security vulnerabilities.**

Report privately through GitHub Security Advisories:
https://github.com/camillobucciarelli/postino/security/advisories/new

Include: affected version and platform, reproduction steps, and the impact you
believe the issue has. A proof of concept helps but is not required.

## Response

This project is maintained by a single developer in their spare time. Best
effort targets, not guarantees: acknowledgement within 7 days, initial
assessment within 14 days, fix or documented mitigation for confirmed
high-severity issues within 90 days. Please allow a fix to ship before public
disclosure. There is no bug bounty program.

## Supported versions

Only the latest released version receives security fixes.

## Security model

Postino talks directly to the mail providers the user connects (Google,
Microsoft, iCloud, IMAP/SMTP servers); the developer runs no mail server.
Mail is stored on the device in a SQLCipher database, and credentials in the
system keychain or keystore. Optional synced settings are encrypted on the
device before they reach the user's Google Drive. See the privacy policy at
https://postino.camillobucciarelli.dev/privacy.html. Postino does not protect
against a compromised operating system or an attacker with access to the
user's unlocked account.
