#pragma once

struct lua_State;

// Setup function to initialize the LLTimers metatable
void luaSL_setup_llltimers_metatable(lua_State *L, int expose_internal_funcs);

// Timer event wrapper for LLEvents integration
int timer_event_wrapper(lua_State *L);
