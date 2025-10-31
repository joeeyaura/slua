-- Test suite for LLTimers API

assert(typeof(LLTimers) == "LLTimers")

-- Helper to increment clock with epsilon to avoid floating point precision issues
local function incrementclock(delta)
    setclock(getclock() + delta + 0.001)
end

local function assert_errors(func, expected_str)
    local success, ret = pcall(func)
    assert(not success)
    local is_match = typeof(ret) == "string" and ret:find(expected_str) ~= nil
    if not is_match then
        print(ret, "!=", expected_str)
    end
    assert(is_match)
end

-- Test basic on() functionality
local on_count = 0
local on_handler = LLTimers:on(0.1, function()
    on_count += 1
end)

assert(typeof(on_handler) == "function")

-- Simulate timer tick
setclock(0.05) -- Not time yet
-- `ll.GetTime()` should be using the clock provider.
assert(math.abs(ll.GetTime() - 0.05) < 0.01)
LLTimers:_tick()
assert(on_count == 0)

-- This should be using our fake clock
assert(math.abs(os.clock() - 0.05) < 0.000001)

incrementclock(0.05) -- Advance to past 0.1, should fire now
LLTimers:_tick()
assert(on_count == 1)

incrementclock(0.1) -- Advance by interval, should fire again
LLTimers:_tick()
assert(on_count == 2)

-- Clean up on() timer before testing once()
LLTimers:off(on_handler)

-- Test once() functionality
local once_count = 0
local once_handler = LLTimers:once(0.1, function()
    once_count += 1
end)

incrementclock(0.1) -- Should fire the once handler
LLTimers:_tick()
assert(once_count == 1)

incrementclock(0.1) -- Should NOT fire again
LLTimers:_tick()
assert(once_count == 1)

-- Test off() functionality
-- Create a new timer to test removal
local new_on_handler = LLTimers:on(0.1, function()
    on_count += 1
end)

local result = LLTimers:off(new_on_handler)
assert(result == true)

incrementclock(0.1) -- Should not increment on_count anymore
LLTimers:_tick()
assert(on_count == 2) -- Still 2 from before

-- Test off() with non-existent handler
local fake_handler = function() end
result = LLTimers:off(fake_handler)
assert(result == false)

-- Test multiple timers
local timer1_count = 0
local timer2_count = 0

setclock(0.5)
local timer1 = LLTimers:on(0.1, function()
    timer1_count += 1
end)

local timer2 = LLTimers:on(0.05, function()
    timer2_count += 1
end)

setclock(0.551) -- timer2 fires (at 0.55), reschedules to 0.601
LLTimers:_tick()
assert(timer1_count == 0)
assert(timer2_count == 1)

setclock(0.60001) -- timer1 fires (at 0.6), timer2 doesn't yet (still at 0.601)
LLTimers:_tick()
assert(timer1_count == 1)
assert(timer2_count == 1)

setclock(0.651) -- timer2 fires (at 0.601), timer1 doesn't (at 0.70001)
LLTimers:_tick()
assert(timer1_count == 1)
assert(timer2_count == 2)

-- Clean up
LLTimers:off(timer1)
LLTimers:off(timer2)

-- Test cancelling a once timer before it fires
local cancelled_count = 0
setclock(0.7)
local cancel_handler = LLTimers:once(0.5, function()
    cancelled_count += 1
end)

result = LLTimers:off(cancel_handler)
assert(result == true)

incrementclock(0.5) -- Should not fire
LLTimers:_tick()
assert(cancelled_count == 0)

-- Test negative interval
local success, err = pcall(function()
    LLTimers:on(-1, function() end)
end)
assert(success == false)

-- Test zero interval
success, err = pcall(function()
    LLTimers:on(0, function() end)
end)
assert(success == false)

-- Test invalid handler type
success, err = pcall(function()
    LLTimers:on(1, "not a function")
end)
assert(success == false)

-- Test tostring
local str = tostring(LLTimers)
assert(type(str) == "string")
assert(string.find(str, "LLTimers"))

-- Test that timers can be removed during tick
local removal_test_count = 0
local remover = nil
setclock(1.2)
remover = LLTimers:on(0.1, function()
    removal_test_count += 1
    if removal_test_count >= 2 then
        LLTimers:off(remover)
    end
end)

incrementclock(0.1)
LLTimers:_tick()
assert(removal_test_count == 1)

incrementclock(0.1)
LLTimers:_tick()
assert(removal_test_count == 2)

incrementclock(0.1)
LLTimers:_tick()
assert(removal_test_count == 2) -- Should not increment

-- Test that timers can handle internal `lua_break()`s due to the scheduler
local breaker_call_order = {}
setclock(2.0)

local breaker_timer1 = LLTimers:on(0.01, function()
    table.insert(breaker_call_order, 1)
    breaker()
end)

-- This should work with :once() too :)
local breaker_timer2 = LLTimers:once(0.01, function()
    breaker()
    table.insert(breaker_call_order, 2)
end)

local breaker_timer3 = LLTimers:on(0.01, function()
    table.insert(breaker_call_order, 3)
    breaker()
    table.insert(breaker_call_order, 4)
end)

setclock(2.1) -- All timers should fire
LLEvents:_handleEvent('timer')

assert(lljson.encode(breaker_call_order) == "[1,2,3,4]")

-- Clean up
LLTimers:off(breaker_timer1)
LLTimers:off(breaker_timer3)

-- Test that timers can handle coroutine yields
breaker_call_order = {}
local yield_order = {}
setclock(3.0)

local yield_timer1 = LLTimers:on(0.01, function()
    table.insert(breaker_call_order, 1)
    coroutine.yield(1)
end)

-- This should work with :once() too :)
local yield_timer2 = LLTimers:once(0.01, function()
    coroutine.yield(2)
    table.insert(breaker_call_order, 2)
end)

local yield_timer3 = LLTimers:on(0.01, function()
    table.insert(breaker_call_order, 3)
    coroutine.yield(3)
    table.insert(breaker_call_order, 4)
end)

setclock(3.1) -- All timers should fire

local tick_coro = coroutine.create(function() LLEvents:_handleEvent('timer') end)

while true do
    local co_status, yielded_val = coroutine.resume(tick_coro)
    if not co_status then
        break
    end
    table.insert(yield_order, yielded_val)
end

assert(lljson.encode(breaker_call_order) == "[1,2,3,4]")
assert(lljson.encode(yield_order) == "[1,2,3]")

-- Clean up
LLTimers:off(yield_timer1)
LLTimers:off(yield_timer2)
LLTimers:off(yield_timer3)

-- Test reentrancy detection
setclock(0.0)
local reentrant_handler = LLTimers:on(0.1, function()
    -- This should error because we're already inside _tick()
    LLTimers:_tick()
end)

setclock(1.0)
assert_errors(
    function() LLTimers:_tick() end,
    "Recursive call to LLTimers:_tick%(%) detected"
)

-- Clean up
LLTimers:off(reentrant_handler)

-- Test automatic registration with LLEvents when first timer is added
setclock(4.0)
assert(#LLEvents:listeners("timer") == 0)

local auto_reg_timer1 = LLTimers:on(1.0, function() end)
assert(#LLEvents:listeners("timer") == 1)

-- Adding second timer should not add another listener
local auto_reg_timer2 = LLTimers:on(2.0, function() end)
assert(#LLEvents:listeners("timer") == 1)

-- Removing first timer should keep listener (still have timer2)
LLTimers:off(auto_reg_timer1)
assert(#LLEvents:listeners("timer") == 1)

-- Removing last timer should auto-deregister
LLTimers:off(auto_reg_timer2)
assert(#LLEvents:listeners("timer") == 0)

-- Test that timer wrapper in listeners() cannot be called directly
local guard_timer = LLTimers:on(1.0, function() end)
local timer_listeners = LLEvents:listeners("timer")
assert(#timer_listeners == 1)

local guard_func = timer_listeners[1]
assert_errors(function()
    guard_func()
end, "Cannot call internal timer wrapper directly")

-- Verify guard function exists
assert(guard_func ~= nil)

-- Clean up
LLTimers:off(guard_timer)

-- Test that LLEvents:_handleEvent('timer') drives LLTimers:_tick()
setclock(5.0)
local integration_count = 0
local integration_timer = LLTimers:on(0.5, function()
    integration_count += 1
end)

-- Manually trigger timer event via LLEvents (no arguments)
setclock(5.6)
LLEvents:_handleEvent('timer')
assert(integration_count == 1)

-- Trigger again
incrementclock(0.5)
LLEvents:_handleEvent('timer')
assert(integration_count == 2)

-- Clean up
LLTimers:off(integration_timer)

-- Test callable tables (tables with __call metamethod) as timer handlers
setclock(6.0)
local callable_count = 0
local callable_table = nil
callable_table = setmetatable({}, {
    __call = function(self)
        assert(self == callable_table)
        callable_count += 1
    end
})

-- Register callable table as timer handler
local callable_timer = LLTimers:on(0.3, callable_table)
assert(callable_timer ~= nil)

-- Advance time and trigger timer
setclock(6.4)
LLEvents:_handleEvent('timer')
assert(callable_count == 1)

-- Trigger again
incrementclock(0.3)
LLEvents:_handleEvent('timer')
assert(callable_count == 2)

-- Test unregistering by passing the same table reference
local off_result = LLTimers:off(callable_table)
assert(off_result == true)

-- Verify timer no longer fires
incrementclock(0.3)
LLEvents:_handleEvent('timer')
assert(callable_count == 2)

-- make sure serialization still works
setclock(0)
-- error() is the poor man's long-return.
local function throw_error() error("called!") end
LLTimers:on(0.5, throw_error)

-- In reality you wouldn't give users primitives to clone these, but just for testing!
local timers_clone = ares.unpersist(ares.persist(LLTimers))
setclock(0.6)

assert_errors(function() timers_clone:_tick() end, "called!")
assert_errors(function() LLTimers:_tick() end, "called!")

incrementclock(0.6)

LLTimers:off(throw_error)
-- Only one of them now has the problematic handler
LLTimers:_tick()
assert_errors(function() timers_clone:_tick() end, "called!")

-- Test that setTimerEventCb is called with correct intervals
-- Single timer should schedule with correct interval
setclock(10.0)
local interval_timer1 = LLTimers:every(0.5, function() end)
assert(math.abs(get_last_interval() - 0.5) < 0.001)

-- Adding an earlier timer should reschedule to shorter interval
local interval_timer2 = LLTimers:on(0.3, function() end)
assert(math.abs(get_last_interval() - 0.3) < 0.001)

-- Adding a later timer should not change the interval
local interval_timer3 = LLTimers:on(1.0, function() end)
-- Should still be 0.3 (the earliest timer)
assert(math.abs(get_last_interval() - 0.3) < 0.001)

-- Scenario 4: Removing the earliest timer should reschedule to next timer
LLTimers:off(interval_timer2)
-- Now earliest should be 0.5
assert(math.abs(get_last_interval() - 0.5) < 0.001)

-- Scenario 5: Removing all timers should call with 0.0
LLTimers:off(interval_timer1)
LLTimers:off(interval_timer3)
assert(math.abs(get_last_interval() - 0.0) < 0.001)

-- Oh also we should make sure that `:once()` behaves correctly.
LLTimers:once(0.5, interval_timer1)
assert(math.abs(get_last_interval() - 0.5) < 0.001)

return "OK"
