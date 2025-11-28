// This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
#include "luau/Compiler.h"
#include "Luau/Ast.h"
#include "Luau/AstJsonEncoder.h"
#include "Luau/Parser.h"
#include "Luau/ParseOptions.h"

#undef LUAU_AST_API
#if defined(_WIN32)
#define LUAU_AST_API __declspec(dllexport)
#else
#define LUAU_AST_API
#endif

extern "C" LUAU_AST_API LuauCompileResult Ast(const char* source)
{
    LuauCompileResult result = {nullptr, 0, nullptr};
    Luau::Allocator allocator;
    Luau::AstNameTable names(allocator);

    Luau::ParseOptions options;
    options.captureComments = true;
    options.allowDeclarationSyntax = true;

    Luau::ParseResult parseResult = Luau::Parser::parse(source, strlen(source), names, allocator, std::move(options));

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
    }
    else
    {
        std::string json = Luau::toJson(parseResult.root, parseResult.commentLocations);
        result.data = new char[json.size() + 1];
        memcpy(result.data, json.c_str(), json.size() + 1);
        result.size = json.size();
    }

    return result;
}
