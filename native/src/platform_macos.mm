#include "platform_macos.h"
#import <Foundation/Foundation.h>
#import <ServiceManagement/ServiceManagement.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>

using namespace godot;

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
