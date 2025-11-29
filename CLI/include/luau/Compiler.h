// This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details

#pragma once

#if defined(_WIN32)
    #define LUAU_CLI_API __declspec(dllexport)
#else
    #define LUAU_CLI_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// luau_compile_cli is the entry point for the Luau compiler command-line interface.
// It takes the same arguments as the original main() function.
LUAU_CLI_API int luau_compile_cli(int argc, char** argv);

// luau_ast_cli is the entry point for the Luau AST tool command-line interface.
// It takes the same arguments as the original main() function.
LUAU_CLI_API int luau_ast_cli(int argc, char** argv);

#ifdef __cplusplus
}
#endif
