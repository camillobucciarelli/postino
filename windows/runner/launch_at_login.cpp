#include "launch_at_login.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

namespace {

constexpr wchar_t kRunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kValueName[] = L"Postino";
// Where Task Manager's Startup tab records an entry the user turned off: an
// odd first byte means off.
constexpr wchar_t kApprovedKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run";

// The running executable, quoted: the Run value is a command line.
std::wstring Command() {
  std::wstring path(MAX_PATH, L'\0');
  DWORD length = 0;
  while ((length = GetModuleFileNameW(nullptr, path.data(),
                                      static_cast<DWORD>(path.size()))) ==
         path.size()) {
    path.resize(path.size() * 2);
  }
  path.resize(length);
  return L"\"" + path + L"\"";
}

// On only when the Run value starts this very executable (an install moved
// elsewhere reads as off) and Task Manager has not turned it off.
bool IsEnabled() {
  wchar_t value[4 * MAX_PATH];
  DWORD size = sizeof(value);
  if (RegGetValueW(HKEY_CURRENT_USER, kRunKey, kValueName, RRF_RT_REG_SZ,
                   nullptr, value, &size) != ERROR_SUCCESS ||
      _wcsicmp(value, Command().c_str()) != 0) {
    return false;
  }
  BYTE approved[12];
  DWORD approved_size = sizeof(approved);
  return RegGetValueW(HKEY_CURRENT_USER, kApprovedKey, kValueName,
                      RRF_RT_REG_BINARY, nullptr, approved,
                      &approved_size) != ERROR_SUCCESS ||
         approved_size == 0 || (approved[0] & 1) == 0;
}

LSTATUS SetEnabled(bool enabled) {
  HKEY key;
  LSTATUS status = RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0,
                                   KEY_SET_VALUE, nullptr, &key, nullptr);
  if (status != ERROR_SUCCESS) return status;
  if (enabled) {
    const std::wstring command = Command();
    status = RegSetValueExW(
        key, kValueName, 0, REG_SZ,
        reinterpret_cast<const BYTE*>(command.c_str()),
        static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
    // Turning it on here also undoes an earlier "off" from Task Manager.
    if (status == ERROR_SUCCESS) {
      const LSTATUS approved =
          RegDeleteKeyValueW(HKEY_CURRENT_USER, kApprovedKey, kValueName);
      if (approved != ERROR_FILE_NOT_FOUND && approved != ERROR_PATH_NOT_FOUND) {
        status = approved;
      }
    }
  } else {
    status = RegDeleteValueW(key, kValueName);
    if (status == ERROR_FILE_NOT_FOUND) status = ERROR_SUCCESS;
  }
  RegCloseKey(key);
  return status;
}

}  // namespace

void RegisterLaunchAtLogin(flutter::BinaryMessenger* messenger) {
  // Lives as long as the process: the engine keeps calling its handler.
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      channel;
  channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "it.postino/launch_at_login",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "isEnabled") {
          result->Success(flutter::EncodableValue(IsEnabled()));
        } else if (call.method_name() == "setEnabled") {
          const auto* enabled = std::get_if<bool>(call.arguments());
          if (enabled == nullptr) {
            result->Error("bad_args", "setEnabled takes a bool");
            return;
          }
          const LSTATUS status = SetEnabled(*enabled);
          if (status == ERROR_SUCCESS) {
            result->Success();
          } else {
            result->Error("registry", "Run key not written",
                          flutter::EncodableValue(static_cast<int>(status)));
          }
        } else {
          result->NotImplemented();
        }
      });
}
