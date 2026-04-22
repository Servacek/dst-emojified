
function AddClassFunctionPreCall(name, precb, class)
    local origin = class[name]
    class[name] = function(...)
        precb(...)
        return origin(...)
    end

    return origin
end

function AddClassFunctionPostCall(name, postcb, class)
    class = type(class) == "string" and require(class) or class

    if type(class) ~= "table" then
        return error("Invalid class")
    end

    local origin = class[name]
    class[name] = function(...)
        local results = {origin(...)}
        postcb(...)
        return unpack(results)
    end

    return origin
end
