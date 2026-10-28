#pragma once
#include <godot_cpp/variant/dictionary.hpp>
godot::Dictionary mac_login_status();
godot::Dictionary mac_set_login(bool enabled);
void mac_open_login_settings();
bool mac_claim_instance();
bool mac_set_dock_visible(bool visible);
void mac_initialize_lifecycle();
void mac_terminate_lifecycle();
bool mac_launched_at_login();
bool mac_consume_reopen();
bool mac_present_menu_window(int64_t handle);
bool mac_present_world_window(int64_t handle);
