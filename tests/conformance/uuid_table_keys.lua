local foo = uuid('00000000-0000-0000-0000-000000000001')
local bar = uuid('00000000-0000-0000-0000-000000000002')
local foo2 = uuid('00000000-0000-0000-0000-000000000001')

-- This should be turned into a compressed key
local real_str = "12345678-9abc-def0-1234-56789abcdef0"
local real_key = uuid(real_str)

local tab = {}

function add_to_tab(val)
    tab[val] = (tab[val] or 0) + 1
end

add_to_tab(foo)
add_to_tab(foo)
assert(tab[foo] == 2)
add_to_tab(foo2)
assert(tab[foo] == 3)
add_to_tab(bar)
add_to_tab(bar)
assert(tab[foo] == 3)
assert(tab[bar] == 2)
add_to_tab(real_key)
add_to_tab(real_key)
assert(tab[real_key] == 2)
assert(tab[foo] == 3)
assert(tab[bar] == 2)

return 'OK'
