-- This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
-- ServerLua: Tests for uncatchable termination errors
print("testing kill errors")

-- Simple infinite loop function for testing kill errors
function infiniteloop()
    while true do end
end

-- Test pcall with infinite loop
function testpcall()
    local success, err = pcall(infiniteloop)
    -- If we get here, pcall caught the error (normal behavior)
    assert(success == false)
    return err
end

-- Test nested pcalls with infinite loop
function testnested()
    pcall(function()
        pcall(function()
            pcall(function()
                pcall(infiniteloop)
                error("should not reach here")
            end)
            error("should not reach here")
        end)
        error("should not reach here")
    end)
    error("should not reach here")
end

-- Test coroutine.resume() with infinite loop in child
function testcoroutine()
    local co = coroutine.create(infiniteloop)
    local success, err = coroutine.resume(co)
    -- Should never reach here - kill should propagate to parent
    error("should not reach here")
end

-- Test nested coroutines with infinite loop
function testnestedcoroutine()
    local inner = coroutine.create(infiniteloop)
    local outer = coroutine.create(function()
        coroutine.resume(inner)
        error("should not reach here")
    end)
    coroutine.resume(outer)
    error("should not reach here")
end

-- Test coroutine.wrap() with infinite loop
function testwrap()
    local f = coroutine.wrap(infiniteloop)
    f()
    error("should not reach here")
end

return "OK"
