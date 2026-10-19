#include "desktop_bridge.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <dwmapi.h>
#elif defined(__APPLE__)
#include <CoreGraphics/CoreGraphics.h>
#include <CoreFoundation/CoreFoundation.h>
#include <unistd.h>
#include "platform_macos.h"
#endif

using namespace godot;

void DesktopBridge::_bind_methods() {
    ClassDB::bind_method(D_METHOD("snapshot_windows"), &DesktopBridge::snapshot_windows);
    ClassDB::bind_method(D_METHOD("screen_capture_allowed"), &DesktopBridge::screen_capture_allowed);
    ClassDB::bind_method(D_METHOD("request_screen_capture"), &DesktopBridge::request_screen_capture);
    ClassDB::bind_method(D_METHOD("autostart_status", "executable"), &DesktopBridge::autostart_status);
    ClassDB::bind_method(D_METHOD("set_autostart", "enabled", "executable"), &DesktopBridge::set_autostart);
    ClassDB::bind_method(D_METHOD("open_login_settings"), &DesktopBridge::open_login_settings);
    ClassDB::bind_method(D_METHOD("claim_instance"), &DesktopBridge::claim_instance);
    ClassDB::bind_method(D_METHOD("set_window_taskbar_visible", "handle", "visible"), &DesktopBridge::set_window_taskbar_visible);
    ClassDB::bind_method(D_METHOD("set_app_dock_visible", "visible"), &DesktopBridge::set_app_dock_visible);
}

#ifdef _WIN32
static BOOL CALLBACK collect_monitor(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
    MONITORINFOEXW info{};
    info.cbSize = sizeof(info);
    if (GetMonitorInfoW(monitor, &info)) {
        const RECT r = info.rcMonitor;
        Dictionary record;
        record["bounds"] = Rect2(r.left, r.top, r.right-r.left, r.bottom-r.top);
        record["name"] = String(info.szDevice);
        reinterpret_cast<Array *>(data)->append(record);
    }
    return TRUE;
}
static BOOL CALLBACK collect_window(HWND window, LPARAM data) {
    DWORD process = 0;
    GetWindowThreadProcessId(window, &process);
    if (process == GetCurrentProcessId() || !IsWindowVisible(window) || IsIconic(window)) return TRUE;
    DWORD cloaked = 0;
    if (SUCCEEDED(DwmGetWindowAttribute(window, DWMWA_CLOAKED, &cloaked, sizeof(cloaked))) && cloaked) return TRUE;
    const LONG_PTR style = GetWindowLongPtrW(window, GWL_EXSTYLE);
    if (style & (WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE)) return TRUE;
    wchar_t klass[256]{};
    GetClassNameW(window, klass, 256);
    if (wcscmp(klass, L"Progman") == 0 || wcscmp(klass, L"WorkerW") == 0 ||
        wcscmp(klass, L"Shell_TrayWnd") == 0 || wcscmp(klass, L"Shell_SecondaryTrayWnd") == 0) return TRUE;
    RECT r{};
    if (FAILED(DwmGetWindowAttribute(window, DWMWA_EXTENDED_FRAME_BOUNDS, &r, sizeof(r))) && !GetWindowRect(window, &r)) return TRUE;
    if (r.right-r.left < 48 || r.bottom-r.top < 32) return TRUE;
    Dictionary record;
    record["bounds"] = Rect2(r.left, r.top, r.right-r.left, r.bottom-r.top);
    record["id"] = int64_t(reinterpret_cast<intptr_t>(window));
    reinterpret_cast<Array *>(data)->append(record);
    return TRUE;
}
#endif

Dictionary DesktopBridge::snapshot_windows() const {
    Array windows;
    Array displays;
#ifdef _WIN32
    EnumDisplayMonitors(nullptr, nullptr, collect_monitor, reinterpret_cast<LPARAM>(&displays));
    // EnumWindows traverses top-level windows from front to back.
    EnumWindows(collect_window, reinterpret_cast<LPARAM>(&windows));
#elif defined(__APPLE__)
    CGDirectDisplayID ids[32];
    uint32_t count = 0;
    if (CGGetActiveDisplayList(32, ids, &count) == kCGErrorSuccess) {
        for (uint32_t i=0; i<count; ++i) {
            CGRect r = CGDisplayBounds(ids[i]);
            Dictionary display;
            display["bounds"] = Rect2(r.origin.x, r.origin.y, r.size.width, r.size.height);
            display["name"] = String::num_uint64(ids[i]);
            displays.append(display);
        }
    }
    CFArrayRef list = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    if (list) {
        for (CFIndex i=0; i<CFArrayGetCount(list); ++i) {
            auto item = static_cast<CFDictionaryRef>(CFArrayGetValueAtIndex(list, i));
            int pid=0, layer=0, number=0;
            double alpha=1.0;
            auto read_number = [&](CFStringRef key, CFNumberType type, void *value) {
                auto n = static_cast<CFNumberRef>(CFDictionaryGetValue(item, key));
                if (n) CFNumberGetValue(n, type, value);
            };
            read_number(kCGWindowOwnerPID, kCFNumberIntType, &pid);
            read_number(kCGWindowLayer, kCFNumberIntType, &layer);
            read_number(kCGWindowNumber, kCFNumberIntType, &number);
            read_number(kCGWindowAlpha, kCFNumberDoubleType, &alpha);
            if (pid == getpid() || layer != 0 || alpha <= 0.01) continue;
            CGRect r{};
            auto bounds = static_cast<CFDictionaryRef>(CFDictionaryGetValue(item, kCGWindowBounds));
            if (!bounds || !CGRectMakeWithDictionaryRepresentation(bounds, &r) || r.size.width<48 || r.size.height<32) continue;
            Dictionary record;
            record["bounds"] = Rect2(r.origin.x, r.origin.y, r.size.width, r.size.height);
            record["id"] = int64_t(number);
            windows.append(record);
        }
        CFRelease(list);
    }
#endif
    Dictionary result;
    result["windows"] = windows;
    result["displays"] = displays;
    return result;
}

bool DesktopBridge::screen_capture_allowed() const {
#ifdef __APPLE__
    return CGPreflightScreenCaptureAccess();
#else
    return true;
#endif
}
bool DesktopBridge::request_screen_capture() const {
#ifdef __APPLE__
    return CGRequestScreenCaptureAccess();
#else
    return true;
#endif
}

#ifdef _WIN32
static constexpr const wchar_t *RUN_KEY = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
static constexpr const wchar_t *RUN_NAME = L"minispaceman";
#endif

Dictionary DesktopBridge::autostart_status(const String &executable) const {
#ifdef __APPLE__
    return mac_login_status();
#else
    Dictionary result;
    HKEY key = nullptr;
    const LSTATUS opened = RegOpenKeyExW(HKEY_CURRENT_USER, RUN_KEY, 0, KEY_QUERY_VALUE, &key);
    if (opened == ERROR_FILE_NOT_FOUND) { result["state"] = "notRegistered"; return result; }
    if (opened != ERROR_SUCCESS) { result["state"] = "unavailable"; result["message"] = "无法读取系统登录项。"; return result; }
    wchar_t command[32768]{};
    DWORD bytes = sizeof(command), type = 0;
    const LSTATUS read = RegQueryValueExW(key, RUN_NAME, nullptr, &type, reinterpret_cast<BYTE *>(command), &bytes);
    RegCloseKey(key);
    const String expected = "\"" + executable.replace("/", "\\") + "\"";
    if (read == ERROR_FILE_NOT_FOUND) result["state"] = "notRegistered";
    else if (read != ERROR_SUCCESS || type != REG_SZ) {
        result["state"] = "unavailable"; result["message"] = "系统登录项无法读取。";
    } else result["state"] = String(command) == expected ? "enabled" : "notFound";
    return result;
#endif
}

Dictionary DesktopBridge::set_autostart(bool enabled, const String &executable) const {
#ifdef __APPLE__
    return mac_set_login(enabled);
#else
    Dictionary result;
    HKEY key = nullptr;
    LSTATUS status = RegCreateKeyExW(HKEY_CURRENT_USER, RUN_KEY, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr);
    if (status == ERROR_SUCCESS) {
        if (enabled) {
            const String command = "\"" + executable.replace("/", "\\") + "\"";
            const auto utf16 = command.utf16();
            status = RegSetValueExW(key, RUN_NAME, 0, REG_SZ, reinterpret_cast<const BYTE *>(utf16.get_data()), (utf16.length() + 1) * sizeof(wchar_t));
        } else {
            status = RegDeleteValueW(key, RUN_NAME);
            if (status == ERROR_FILE_NOT_FOUND) status = ERROR_SUCCESS;
        }
        RegCloseKey(key);
    }
    result["ok"] = status == ERROR_SUCCESS;
    if (status != ERROR_SUCCESS) result["message"] = "无法更改系统登录项，错误码：" + String::num_int64(status);
    return result;
#endif
}

void DesktopBridge::open_login_settings() const {
#ifdef __APPLE__
    mac_open_login_settings();
#endif
}

bool DesktopBridge::claim_instance() const {
#ifdef __APPLE__
    return mac_claim_instance();
#else
    static HANDLE instance = nullptr;
    if (instance) return true;
    wchar_t username[256]{};
    DWORD length = 256;
    if (!GetUserNameW(username, &length)) return false;
    const String name = String("Local\\minispaceman.Instance.") + String(username);
    const auto utf16 = name.utf16();
    HANDLE candidate = CreateMutexW(nullptr, FALSE, reinterpret_cast<const wchar_t *>(utf16.get_data()));
    const DWORD error = GetLastError();
    if (!candidate) return false;
    if (error == ERROR_ALREADY_EXISTS) { CloseHandle(candidate); return false; }
    instance = candidate;
    return true;
#endif
}

bool DesktopBridge::set_window_taskbar_visible(int64_t handle, bool visible) const {
#ifdef _WIN32
    HWND window = reinterpret_cast<HWND>(static_cast<intptr_t>(handle));
    DWORD owner = 0;
    GetWindowThreadProcessId(window, &owner);
    if (!IsWindow(window) || owner != GetCurrentProcessId()) return false;
    const LONG_PTR previous = GetWindowLongPtrW(window, GWL_EXSTYLE);
    const LONG_PTR next = visible ? (previous | WS_EX_APPWINDOW) & ~WS_EX_TOOLWINDOW
                                  : (previous | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW;
    if (previous == next) return true;
    // The shell caches taskbar membership: change the styles while hidden.
    const bool was_visible = IsWindowVisible(window);
    const bool restore_focus = GetForegroundWindow() == window && !(previous & WS_EX_NOACTIVATE);
    if (was_visible) ShowWindow(window, SW_HIDE);
    SetLastError(0);
    const LONG_PTR result = SetWindowLongPtrW(window, GWL_EXSTYLE, next);
    const bool ok = result != 0 || GetLastError() == 0;
    SetWindowPos(window, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    if (was_visible) {
        ShowWindow(window, restore_focus ? SW_SHOW : SW_SHOWNOACTIVATE);
        if (restore_focus) SetForegroundWindow(window);
    }
    return ok;
#else
    return true;
#endif
}

bool DesktopBridge::set_app_dock_visible(bool visible) const {
#ifdef __APPLE__
    return mac_set_dock_visible(visible);
#else
    return true;
#endif
}
