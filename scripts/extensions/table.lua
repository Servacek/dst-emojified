
local TAB_SIZE = 4
local MAX_DUMP_LEVEL = 10

--------------------------

local function default_cmp(a, b)
    return a > b
end

--------------------------

function table:filter(checkfn)
    local result = {}
    for k, v in pairs(self) do
        if checkfn(k, v) then
            result[k] = v
        end
    end

    return result
end

function table.size(t)
    local size = 0
    for _, _ in pairs(t) do
        size = size + 1
    end

    return size
end

--- @param checkfn fun(key: any, value: any): boolean
--- @param count integer?
--- @return boolean success, integer count
function table:findall(checkfn, count)
    count = count or 1
    for k, v in pairs(self) do
        if checkfn(k, v) then
            count = count - 1
            if count <= 0 then
                return true, count
            end
        end
    end

    return false, count
end

--- @param checkfn fun(key: any, value: any): boolean
--- @return any result
function table:find(checkfn)
    for k, v in pairs(self) do
        if checkfn(k, v) then
            return v
        end
    end
end

-- This is a safe alternative to IsTableEmpty
-- Returns a boolean whether the table you have provided is empty or not.
-- Returns nil if the provided table is not actually a table...
--- @param self any
--- @return boolean? empty
function table:empty()
    if type(self) ~= "table" then
        return
    end

    return next(self) == nil
end

function table.join(t1, t2)
    for _, val in ipairs(t2) do
        table.insert(t1, val)
    end
end

function table.limit(t, limit)
    while #t > limit do
        t[#t] = nil
    end
end

--- https://web.archive.org/web/20131225070434/http://snippets.luacode.org/snippets/Deep_Comparison_of_Two_Values_3
-- function table.equal(t1, t2, ignore_mt)
--     local ty1 = type(t1)
--     local ty2 = type(t2)
--     if ty1 ~= ty2 then return false end
--     -- non-table types can be directly compared
--     if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
--     -- as well as tables which have the metamethod __eq
--     local mt = getmetatable(t1)
--     if not ignore_mt and mt and mt.__eq then return t1 == t2 end
--     for k1,v1 in pairs(t1) do
--         local v2 = t2[k1]
--         if v2 == nil or not table.equal(v1,v2) then return false end
--     end
--     for k2,v2 in pairs(t2) do
--         local v1 = t1[k2]
--         if v1 == nil or not table.equal(v1,v2) then return false end
--     end

--     return true
-- end

function table.update(old, new, strict)
    for key, value in pairs(new) do
        if type(value) == "table" and type(old[key]) == "table" then
            -- If both the source and target have subtables, recursively update them
            table.update(old[key], value)
        else
            if (type(old[key]) ~= type(value)) and strict == true then
                return key
            end

            -- Update or add the key-value pair in the target table
            old[key] = value
        end
    end
end

function table.nestedkeys(t)
    local keys = {}
    local queue = {t}
    while table.empty(queue) == false do
        local l = #queue
        local tc = queue[l]
        queue[l] = nil

        for k, v in pairs(tc) do
            if keys[k] == nil then
                keys[k] = true
            end

            if type(v) == "table" then
                queue[#queue + 1] = v
            end
        end
    end

    return table.keys(keys)
end

function table.isarray(t)
    if type(t) ~= "table" then
        return false
    end

    local count = #t
    if count == 0 then
        return false
    end

    if table.size(t) ~= count then
        return false
    end

    for i = 1, count do
        if t[i] == nil then
            return false
        end
    end

    return true
end

-- function table.create(size, narr)
--     -- This is a function from the C environment.
--     return createTable(size, narr)
-- end

-- Note: The proxy table returned by this doesn't support pairs/ipairs/next or the "#" operator.
function table.readonly(t)
    return setmetatable({}, {
        __index = t,
        __len = function() return #t end,
        __newindex = function()
            return error("Attempted to modify a read-only table."..CalledFrom())
        end,
        -- Prohibit changing this metatable
        __metatable = false,
    })
end

function table:iclear()
    for i = #self, 1, -1 do
        self[i] = nil
    end

    return self
end

function table:clear()
    for k, _ in pairs(self) do
        self[k] = nil
    end

    return self
end

--- Optimized version of table:getkey for true arrays.
--- @return integer? index
function table:index(value)
    for i = 1, #self do
        if self[i] == value then
            return i
        end
    end
end

--- Returns the first key for the specified value found in the the specified table.
--- @return key? any
function table:getkey(value)
    for k, v in pairs(self) do
        if v == value then
            return k
        end
    end
end

--- Returns the all keys for the specified value found in the the specified table.
--- @return key? any
function table:getallkeys(value)
    local keys = {}
    for k, v in pairs(self) do
        if v == value then
            keys[#keys + 1] = k
        end
    end

    return keys
end

--- @param t table
--- @param path string
--- @return any
function table.pathget(t, path)
    local value = t
    for key in path:gmatch("[%w_]+") do
        if type(value) == "table" then
            if value[key] ~= nil then -- Check for explicit nil in case of falsy values
                value = value[key]
            else
                value = value[tonumber(key)] -- Support for arrays
            end
        else
            return nil -- Some intermediate value on the path is not a table
        end
    end

    --- If we have ended on the start, then this path is invalid.
    return value ~= t and value or nil
end

function table.pathset(t, path, new)
    local last_key
    local value = t -- We use this so t is the previous value
    for key in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then
            return nil -- If any intermediate value is not a table, return nil
        end

        t = value
        value = rawget(value, key)
        if value == nil then
            key = tonumber(key)
            value = rawget(value, key)
            if value == nil then
                return -- If any key doesn't exist, return nil
            end
        end

        last_key = key
    end

    if last_key ~= nil then
        rawset(t, last_key, new)
    end
end

function table.rcontains(t, value)
    for _, v in pairs(t) do
        if v == value then
            return true
        elseif type(v) == "table" and table.rcontains(v, value) then
            return true
        end
    end

    return false
end

--- @param fn fun(v: any): result: table<any, any>
function table:map(fn)
    local t = {}
    for k, v in pairs(self) do
        t[k] = fn(v)
    end

    return t
end

function table.sum(t)
    local sum = 0
    for _, value in pairs(t) do
        sum = sum + value
    end

    return sum
end

function table.average(t)
    return table.sum(t) / table.size(t)
end

function table.max(t)
    local maxk
    local maxv = 0
    for k, v in pairs(t) do
        if v > maxv then
            maxk = k
            maxv = v
        end
    end

    return maxk, maxv
end

function table.keys(t, unique)
    local values = unique and {} or nil
    local keys = {}
    for k, v in pairs(t) do
        if not values or values[v] == nil then
            keys[#keys + 1] = k

            if values then
                values[v] = true
            end
        end
    end

    return keys
end

--- --->
--- 1 2 3 4
--- @param cmp? fun(a: any, b: any): boolean a < b (similiar to table.sort - descending order)
--- @return integer position The updated position of the item at t[i]. This can be unchanged.
function table.reorder(t, i, cmp)
    cmp = cmp or default_cmp
    local lstep = (t[i-1] ~= nil and cmp(t[i], t[i-1]) and -1) or 0
    local rstep = (lstep == 0 and t[i+1] ~= nil and cmp(t[i+1], t[i]) and 1) or 0
    local step = lstep + rstep
    -- In sorted array left < right, so loop until this is met.
    while t[i + step] ~= nil and cmp(t[i + rstep], t[i + lstep]) do
        t[i + lstep], t[i + rstep] = t[i + rstep], t[i + lstep]
        i = i + step
    end

    return i
end

function table.insort(t, v, cmp)
    local i = #t+1
    t[i] = v
    --table.insert(t, i, v)

    return table.reorder(t, i, cmp)
end

function table.reinsort(t, v, cmp)
    -- This is a special function defined by Kleis.
    table.removearrayvalue(t, v)
    return table.insort(t, v, cmp)
end

function table.values(t, unique)
    local keys = unique and {} or nil
    local values = {}
    for k, v in pairs(t) do
        if not keys or keys[k] == nil then
            values[#values + 1] = v

            if keys then
                keys[k] = true
            end
        end
    end

    return values
end

--- Returns an array of unique values from the given table.
function table.toset(t, set)
    set = set or {}
    local lk = {}
    for i = 1, #t do
        if lk[t[i]] == nil then
            lk[t[i]] = true

            set[#set+1] = t[i]
        end
    end

    return set
end

-- For some reason this cannot be used as a method :/
function table.dump(t, _i, _r, _visited)
    if type(t) ~= "table" then
        return print("Invalid table")
    end

    _visited = _visited or {}  -- Initialize visited tables set

    -- Check if table has been visited
    if _visited[t] then
        print("Circular reference detected")
        return
    end

    -- Add current table to visited set
    _visited[t] = true

    if type(_i) ~= "number" then
        _i = nil
    end

    if not _i then
        print("{")
    end

    _i = _i or 1
    for k, v in pairs(t) do
        _r = (_r or 0) + 1
        local fm = string.rep(" ", _i * TAB_SIZE)..tostring(k).." = "
        if type(v) == "table" then
            print(fm.."{")
            if _i < MAX_DUMP_LEVEL then
                table.dump(v, _i + 1, _r, _visited)
            else
                print("...")
            end
        elseif type(v) == "string" then
            print(fm..string.format("%q", v)..",")
        else
            print(fm..tostring(v)..",")
        end
    end

    print(string.rep(" ", _i * TAB_SIZE - TAB_SIZE).."},")
end
