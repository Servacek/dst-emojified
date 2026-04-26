
function AddClassFunctionPreCall(name, precb, class)
    local origin = class[name]
    class[name] = function(...)
        if precb(...) == false then return end
        return origin(...)
    end

    return origin
end

local function pack(...)
    return select('#', ...), {...}
end

function AddClassFunctionPostCall(name, postcb, class)
    class = type(class) == "string" and require(class) or class

    if type(class) ~= "table" then
        return error("Invalid class")
    end

    local origin = class[name]
    class[name] = function(...)
        local n, results = pack(origin(...))
        postcb(...)
        return unpack(results, 1, n)
    end

    return origin
end
