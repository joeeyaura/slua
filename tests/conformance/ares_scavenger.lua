-- TODO: Make this an actual test and not just something I run...

local _VALUE_LIKE = {
    ["nil"]= true,
    ["boolean"]= true,
    ["number"]=true,
    ["string"]=true,
    ["vector"]=true,
    ["uuid"]=true,
    ["lljson_constant"]=true,
}

local function get_reference_type(obj)
    local t = typeof(obj)
    if not _VALUE_LIKE[t] then
        return t
    end
    return nil
end

local function visit_objects(root, visited)
    -- Skip if already visited or if it's a value-like object
    if visited[root] then
        return
    end
    local t = get_reference_type(root)
    if not t then
        return
    end

    -- Mark as visited
    visited[root] = true

    if t == "table" then
        -- Visit all values in the table using generalized iteration
        for key, value in root do
            visit_objects(value, visited)
        end

        -- Visit the metatable if it exists
        local mt = getmetatable(root)
        if mt then
            visit_objects(mt, visited)
        end
    end
end

local function main()
    -- Make sure these are included even though they wouldn't normally be scavenged
    local all_heap = {
        [vector(0, 0, 0)]=true,
        [quaternion(0,0,0,0)]=true,
        [uuid("")]=true,
    }
    visit_objects(_G, all_heap)

    local to_scan = {
        -- Some things that won't be reachable from _G
        getmetatable(quaternion(0,0,0,0)),
        getmetatable(vector(0,0,0)),
        getmetatable(getmetatable(uuid)),
        getmetatable(""),
        getmetatable(false),
        getmetatable(1),
        getmetatable(nil),
        getmetatable(LLEvents),
        getmetatable(LLTimers),
        getfenv(),
    }
    for i, v in to_scan do
        if not v then
            continue
        end
        visit_objects(v, all_heap)
    end
    print(ares.persist(all_heap))
end

main()
