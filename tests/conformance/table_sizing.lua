-- Tests for array sizing cap behavior
-- The cap limits "wasted" array slots to at most 255 for large arrays

-- Build array by insertion to trigger rehash (table.create() pre-allocates, skipping resize)
local function make_array(n)
    local t = {}
    for i = 1, n do
        t[i] = true
    end
    return t
end

local function check_sizes(t, expected_arr, expected_hash, desc)
    local arr_size, hash_size = table_sizes(t)
    assert(arr_size == expected_arr, `{desc}: expected {expected_arr} array slots, got {arr_size}`)
    assert(hash_size == expected_hash, `{desc}: expected {expected_hash} hash slots, got {hash_size}`)
end

-- Basic cap behavior - 600 elements should get 768, not 1024
local t = make_array(600)
check_sizes(t, 768, 0, "600 elements")

t = make_array(512)
check_sizes(t, 512, 0, "512 threshold")

t = make_array(513)
check_sizes(t, 768, 0, "513 threshold")

t = make_array(1500)
check_sizes(t, 1536, 0, "1500 elements")

t = make_array(2000)
check_sizes(t, 2048, 0, "2000 elements")

-- Boundary invariant - sparse table with boundary at high index
-- Element at 1000 doesn't meet 50% threshold, goes to hash
t = {}
t[1] = true
t[1000] = true
check_sizes(t, 1, 1, "boundary invariant")

-- Mixed array/hash - string keys don't affect array sizing
t = make_array(600)
t["foo"] = "bar"
t["baz"] = "qux"
check_sizes(t, 768, 2, "mixed keys")

-- Small arrays (below threshold) - normal power-of-2 sizing
t = make_array(50)
check_sizes(t, 64, 0, "50 elements")

-- Incremental growth
t = make_array(520)
check_sizes(t, 768, 0, "520 elements")

-- Offset array - elements not starting from 1
-- 600 elements at indices 401-1000, meets 50% threshold for 1024
t = {}
for i = 401, 1000 do
    t[i] = true
end
check_sizes(t, 1024, 0, "offset array 401-1000")

-- Sparse with gap - should not cap due to high max_idx
t = make_array(1100)
for i = 1500, 1549 do
    t[i] = true
end
check_sizes(t, 2048, 0, "sparse with gap")

-- Sequential growth across cap threshold
t = make_array(400)
check_sizes(t, 512, 0, "pre-growth 400 elements")
for i = 401, 600 do
    t[i] = true
end
check_sizes(t, 768, 0, "post-growth 600 elements")

-- Index 0 goes to hash, not array
t = make_array(600)
t[0] = true
check_sizes(t, 768, 1, "with index 0")

-- Negative indices go to hash
t = make_array(600)
t[-1] = true
t[-100] = true
check_sizes(t, 768, 2, "with negative indices")

-- Non-integer keys go to hash
t = make_array(600)
t[1.5] = true
t[2.7] = true
check_sizes(t, 768, 2, "with float indices")

-- Exactly at power-of-2 boundaries
t = make_array(1024)
check_sizes(t, 1024, 0, "exactly 1024 elements")

t = make_array(2048)
check_sizes(t, 2048, 0, "exactly 2048 elements")

-- table.create pre-allocates without rehash(), allows creating tables with
--  sizes that rehash() would not normally create.
t = table.create(1535, true)
check_sizes(t, 1535, 0, "exactly 1535 elements")
-- But it'll go to a "normal" size if we overfill it.
t[1536] = 1
check_sizes(t, 1536, 0, "resized to next increment after insert")
t[1537] = 2
check_sizes(t, 1792, 0, "second bigger resize")
-- Double check we didn't muck up the data with either of those resizes
assert(t[1536] == 1)
assert(t[1537] == 2)

-- Exact cap boundary - 1536 elements should get exactly 1536 slots
t = make_array(1536)
check_sizes(t, 1536, 0, "exactly 1536 elements")

-- Just over cap boundary - 1537 elements should grow to 1792
t = make_array(1537)
check_sizes(t, 1792, 0, "1537 elements")

-- Very large array - 10000 elements should get 10240, not 16384
t = make_array(10000)
check_sizes(t, 10240, 0, "10000 elements")

-- Hash spillover triggers rehash and array growth
-- Inserting beyond array size into dummynode triggers rehash
t = make_array(1536)
check_sizes(t, 1536, 0, "before spillover")
-- These will go into hash because they're not sequential with array
t.foo = true
t.bar = true
t.baz = true
-- Should be one space free in `node`
check_sizes(t, 1536, 4, "node insert - node grew")
t[1538] = true
check_sizes(t, 1536, 4, "after num insert - placed in node")

-- This will overflow `t->node`, so it should try to resize array now
t[1537] = true
-- Note that node will NOT shrink, but the values will be moved!
check_sizes(t, 1792, 4, "after spillover - array grew")
assert(t[1538] == true, "1538 still present")

-- System tables (memcat < 2) use power-of-2 sizing, no cap
change_memcat(0)
t = make_array(600)
check_sizes(t, 1024, 0, "system table memcat 0")
change_memcat(2)

return "OK"
