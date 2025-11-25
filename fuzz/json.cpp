// This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
// ServerLua: JSON decoder fuzzer for lljson module
#include "lua.h"
#include "lualib.h"
#include "Luau/Common.h"

static lua_State* L = nullptr;
static lua_SLRuntimeState lsl_state;

static void initLuaState()
{
    if (L)
        return;

    L = luaL_newstate();
    luaL_openlibs(L);

    // Tag as SL VM (required for UUID/quaternion support)
    lsl_state.slIdentifier = LUA_SL_IDENTIFIER;
    lua_setthreaddata(L, &lsl_state);

    // Register SL types (UUID metatables, quaternion metatables, weak tables)
    luaopen_sl(L, true);

    // Register JSON functions (decode, sldecode, encode, slencode)
    luaopen_cjson(L);
    lua_getfield(L, 1, "sldecode");
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* Data, size_t Size)
{
    initLuaState();
    int base = lua_gettop(L);

    lua_pushvalue(L, -1);

    // Test json_decode_sl (SL tagged types)
    lua_pushlstring(L, (const char*)Data, Size);
    if (lua_pcall(L, 1, 1, 0) == 0)
    {
        // Success - verify exactly 1 value returned
        if (lua_gettop(L) != base + 1)
            LUAU_ASSERT(!"sldecode returned wrong number of values");
    }
    lua_settop(L, base);

    return 0;
}
