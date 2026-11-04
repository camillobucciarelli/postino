#ifndef RUNNER_LAUNCH_AT_LOGIN_H_
#define RUNNER_LAUNCH_AT_LOGIN_H_

#include <flutter/binary_messenger.h>

// postino (#38): avvio al login on the "it.postino/launch_at_login" channel, as a value
// under HKCU\Software\Microsoft\Windows\CurrentVersion\Run. Methods: isEnabled -> bool,
// setEnabled(bool).
void RegisterLaunchAtLogin(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_LAUNCH_AT_LOGIN_H_
