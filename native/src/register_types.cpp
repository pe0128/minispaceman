#include "desktop_bridge.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#ifdef __APPLE__
#include "platform_macos.h"
#endif

using namespace godot;
static void initialize(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        ClassDB::register_class<DesktopBridge>();
#ifdef __APPLE__
        mac_initialize_lifecycle();
#endif
    }
}
static void terminate(ModuleInitializationLevel level) {
#ifdef __APPLE__
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) mac_terminate_lifecycle();
#endif
}
extern "C" {
GDExtensionBool GDE_EXPORT minispaceman_library_init(GDExtensionInterfaceGetProcAddress get_proc,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize);
    init.register_terminator(terminate);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
}
