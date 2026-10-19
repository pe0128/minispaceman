#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {
class DesktopBridge : public RefCounted {
    GDCLASS(DesktopBridge, RefCounted)
protected:
    static void _bind_methods();
public:
    Dictionary snapshot_windows() const;
    bool screen_capture_allowed() const;
    bool request_screen_capture() const;
};
}
