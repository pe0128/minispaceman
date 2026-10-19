#pragma once
#include <godot_cpp/variant/dictionary.hpp>
godot::Dictionary mac_login_status();
godot::Dictionary mac_set_login(bool enabled);
void mac_open_login_settings();
bool mac_claim_instance();
bool mac_set_dock_visible(bool visible);
