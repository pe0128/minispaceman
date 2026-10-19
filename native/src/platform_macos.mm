#include "platform_macos.h"
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string.hpp>
#import <Foundation/Foundation.h>
#import <ServiceManagement/ServiceManagement.h>
#import <AppKit/AppKit.h>
#import <CoreServices/CoreServices.h>
#import <objc/runtime.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <string>

using namespace godot;

namespace {
bool login_launch = false;
bool reopen_requested = false;
id launch_observer = nil;
IMP previous_reopen = nullptr;
Class delegate_class = Nil;
std::string reopen_encoding;

void capture_launch_event() {
    NSAppleEventDescriptor *event = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];
    if (event.eventID == kAEOpenApplication &&
        [[event paramDescriptorForKeyword:keyAEPropData] enumCodeValue] == keyAELaunchedAsLogInItem) login_launch = true;
}

BOOL handle_reopen(id delegate, SEL selector, NSApplication *application, BOOL visible) {
    reopen_requested = true;
    if (previous_reopen) return reinterpret_cast<BOOL (*)(id, SEL, NSApplication *, BOOL)>(previous_reopen)(delegate, selector, application, visible);
    return YES;
}
}

void mac_initialize_lifecycle() {
    // Godot starts the extension inside applicationDidFinishLaunching. Cache
    // the Apple event before a later event replaces currentAppleEvent.
    capture_launch_event();
    launch_observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification *) { capture_launch_event(); }];
    if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"io.github.pe0128.minispaceman"]) return;
    delegate_class = object_getClass([NSApp delegate]);
    if (!delegate_class) return;
    SEL selector = @selector(applicationShouldHandleReopen:hasVisibleWindows:);
    Method existing = class_getInstanceMethod(delegate_class, selector);
    if (existing) previous_reopen = method_getImplementation(existing);
    reopen_encoding = std::string(@encode(BOOL)) + "@:@" + @encode(BOOL);
    if (existing) reopen_encoding = method_getTypeEncoding(existing);
    class_replaceMethod(delegate_class, selector, reinterpret_cast<IMP>(handle_reopen), reopen_encoding.c_str());
}

void mac_terminate_lifecycle() {
    if (launch_observer) [[NSNotificationCenter defaultCenter] removeObserver:launch_observer];
    launch_observer = nil;
    if (delegate_class && previous_reopen) class_replaceMethod(delegate_class, @selector(applicationShouldHandleReopen:hasVisibleWindows:), previous_reopen, reopen_encoding.c_str());
}

bool mac_launched_at_login() { return login_launch; }
bool mac_consume_reopen() {
    const bool result = reopen_requested;
    reopen_requested = false;
    return result;
}

Dictionary mac_login_status() {
    @autoreleasepool {
        Dictionary result;
        switch ([SMAppService mainAppService].status) {
            case SMAppServiceStatusEnabled: result["state"] = "enabled"; break;
            case SMAppServiceStatusRequiresApproval: result["state"] = "requiresApproval"; break;
            case SMAppServiceStatusNotFound: result["state"] = "notFound"; break;
            default: result["state"] = "notRegistered"; break;
        }
        return result;
    }
}

Dictionary mac_set_login(bool enabled) {
    @autoreleasepool {
        NSError *error = nil;
        BOOL ok = enabled ? [[SMAppService mainAppService] registerAndReturnError:&error]
                          : [[SMAppService mainAppService] unregisterAndReturnError:&error];
        Dictionary result = mac_login_status();
        // Registration can succeed while the OS still requires user approval.
        result["ok"] = ok || (enabled && String(result["state"]) == "requiresApproval");
        if (error) result["message"] = String::utf8([[error localizedDescription] UTF8String]);
        return result;
    }
}

void mac_open_login_settings() {
    [SMAppService openSystemSettingsLoginItems];
}

bool mac_claim_instance() {
    static int descriptor = -1;
    if (descriptor >= 0) return true;
    @autoreleasepool {
        NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/minispaceman"];
        if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nullptr]) return false;
        NSString *path = [directory stringByAppendingPathComponent:@"instance.lock"];
        int candidate = open([path fileSystemRepresentation], O_CREAT | O_RDWR | O_CLOEXEC, 0600);
        if (candidate < 0) return false;
        if (flock(candidate, LOCK_EX | LOCK_NB) != 0) { close(candidate); return false; }
        descriptor = candidate;
        return true;
    }
}

bool mac_set_dock_visible(bool visible) {
    @autoreleasepool {
        NSApplicationActivationPolicy policy = visible ? NSApplicationActivationPolicyRegular
                                                       : NSApplicationActivationPolicyAccessory;
        if ([NSApp activationPolicy] == policy) return true;
        return [NSApp setActivationPolicy:policy];
    }
}
