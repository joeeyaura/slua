// This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
#include "luau/Compiler.h"
#include "Luau/Compiler.h"
#include "luacode.h"
#include "Luau/BytecodeBuilder.h"
#include "Luau/Parser.h"
#include <string.h>

#undef LUAU_COMPILE_API
#if defined(_WIN32)
#define LUAU_COMPILE_API __declspec(dllexport)
#else
#define LUAU_COMPILE_API
#endif

static Luau::CompileOptions copts()
{
    Luau::CompileOptions result = {};
    result.optimizationLevel = 1;
    result.debugLevel = 1;
    result.typeInfoLevel = 0;

    return result;
}

extern "C" LUAU_COMPILE_API LuauCompileResult Compile(const char* source)
{
    LuauCompileResult result = {nullptr, 0, nullptr};
    Luau::Allocator allocator;
    Luau::AstNameTable names(allocator);
    Luau::ParseResult parseResult = Luau::Parser::parse(source, strlen(source), names, allocator);

    if (!parseResult.errors.empty())
    {
        std::string errorStr;
        for (const auto& error : parseResult.errors)
        {
            char buffer[256];
            snprintf(buffer, sizeof(buffer), "(%d,%d): %s\n", error.getLocation().begin.line + 1, error.getLocation().begin.column + 1, error.what());
            errorStr += buffer;
        }
        result.errors = new char[errorStr.size() + 1];
        memcpy(result.errors, errorStr.c_str(), errorStr.size() + 1);
        return result;
    }

    try
    {
        Luau::BytecodeBuilder bcb;
        Luau::compileOrThrow(bcb, parseResult, names, copts());

        std::string bytecode = bcb.getBytecode();
        result.data = new char[bytecode.size()];
        memcpy(result.data, bytecode.data(), bytecode.size());
        result.size = bytecode.size();
    }
    catch (Luau::CompileError& e)
    {
        std::string errorStr = e.what();
        result.errors = new char[errorStr.size() + 1];
        memcpy(result.errors, errorStr.c_str(), errorStr.size() + 1);
    }

    return result;
}

