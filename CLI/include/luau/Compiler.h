#pragma once

#include <stddef.h>

#if defined(_WIN32)
#define LUAU_COMPILE_API __declspec(dllimport)
#define LUAU_AST_API __declspec(dllimport)
#else
#define LUAU_COMPILE_API
#define LUAU_AST_API
#endif

typedef struct
{
    char* data;
    size_t size;
    char* errors;
} LuauCompileResult;

extern "C"
{
    LUAU_COMPILE_API LuauCompileResult Compile(const char* source);
    LUAU_AST_API LuauCompileResult Ast(const char* source);
}

extern "C" inline void Free(LuauCompileResult result)
{
    delete[] result.data;
    delete[] result.errors;
}
