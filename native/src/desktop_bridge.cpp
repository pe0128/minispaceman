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
#endif

using namespace godot;

void DesktopBridge::_bind_methods() {
    ClassDB::bind_method(D_METHOD("snapshot_windows"), &DesktopBridge::snapshot_windows);
    ClassDB::bind_method(D_METHOD("screen_capture_allowed"), &DesktopBridge::screen_capture_allowed);
    ClassDB::bind_method(D_METHOD("request_screen_capture"), &DesktopBridge::request_screen_capture);
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
