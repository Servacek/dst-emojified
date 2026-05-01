
local GLOBAL = GLOBAL
local setmetatable, rawget = GLOBAL.setmetatable, GLOBAL.rawget

--------------------------------
-- [[ Local Constants ]]
--------------------------------

local ENV = GLOBAL.getfenv()
local MT = {
    -- Called when lua is not able to find the field in our environment table.
    -- This allows implicit access to fields of the GLOBAL table.
    -- This is beign called... a lot.
    __index = function(env, index)
        return rawget(GLOBAL, index)
    end,
}

--------------------------------
-- [[ Setup ]]
--------------------------------

-- Setup the enviroment so we do not have to type GLOBAL
-- everytime we access something from that table.
--- @return table
-- Modify the metatable of the current safe separated mod environment.
setmetatable(ENV, MT)

-- Set to true to enable debug output and cheats during development.
-- ! Can cause issues wíth the mod loading when enabled.
DEBUG = false

local CONFLICTING_MOD_NAMES = {
    ["workshop-3713900704"] = true,
    ["workshop-emojified"]  = true,
}

local function IsConflictingModEnabled()
    local known_mod_index = GLOBAL.KnownModIndex
    if known_mod_index and type(known_mod_index.IsModEnabled) == "function" then
        for name in pairs(CONFLICTING_MOD_NAMES) do
            if name ~= modname and known_mod_index:IsModEnabled(name) then
                return true, name
            end
        end
    end

    return false
end

local has_conflict, conflict_modname = IsConflictingModEnabled()
if has_conflict then
    print("[Emojified] Disabled because conflicting mod is enabled:", conflict_modname)
    return
end

local _modrequire_cache = {}
function modrequire(modulename)
    if _modrequire_cache[modulename] then
        return unpack(_modrequire_cache[modulename])
    end

    local fn = kleiloadlua(MODROOT.."/scripts/"..modulename..".lua")
    if type(fn) == "function" then
        setfenv(fn, ENV)
        _modrequire_cache[modulename] = {fn()}
        return unpack(_modrequire_cache[modulename])
    else
        error("Failed to load file "..modulename.." - "..tostring(fn or "File not found!"))
    end
end

if not GLOBAL.TheNet:IsDedicated() then
    modimport("scripts/clientside")
end
