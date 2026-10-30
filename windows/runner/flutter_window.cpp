#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // postino: two panes and the icon sidebar need 900 (breakpoint-list-detail) of client width and 600 of client height;
  // the window cannot be smaller (the minimum is the outer size that leaves a 900x600 logical pixel client area).
  if (message == WM_GETMINMAXINFO) {
    const UINT dpi = GetDpiForWindow(hwnd);
    RECT frame = {0, 0, MulDiv(900, dpi, USER_DEFAULT_SCREEN_DPI),
                  MulDiv(600, dpi, USER_DEFAULT_SCREEN_DPI)};
    AdjustWindowRectExForDpi(&frame, GetWindowLong(hwnd, GWL_STYLE), FALSE,
                             GetWindowLong(hwnd, GWL_EXSTYLE), dpi);
    reinterpret_cast<MINMAXINFO*>(lparam)->ptMinTrackSize.x =
        frame.right - frame.left;
    reinterpret_cast<MINMAXINFO*>(lparam)->ptMinTrackSize.y =
        frame.bottom - frame.top;
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
