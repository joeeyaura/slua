change_memcat(0)
local foo = table.create(1000, 1)
change_memcat(10)
-- The allocs inside table.clone() should fail, and it should not break freeing the GCO
assert(not pcall(table.clone, foo))
return "OK"
