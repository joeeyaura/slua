#pragma once

struct lua_State;
void luaSL_setup_llevents_metatable(lua_State *L, int expose_internal_funcs);
void luaSL_setup_detectedevent_metatable(lua_State *L);
