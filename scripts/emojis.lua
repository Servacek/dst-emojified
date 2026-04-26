local m_CONSTANTS = modrequire("constants")

local EMOJIS = {
    -- Game utf-8 formatted emotes accessed by name (from code)
    --- @class EMOJIS.GAME
    GAME = {
        ABIGAIL = "󰀜",
        ALCHEMY = "󰀝",
        BACKPACK = "󰀞",
        BATTLE = "󰀘",
        BEEFALO = "󰀁",
        BEEHIVE = "󰀟",
        BERRY = "󰀠",
        CARROT = "󰀡",
        CHEST = "󰀂",
        CHESTER = "󰀃",
        CROCKPOT = "󰀄",
        EYEBALL = "󰀅",
        EGG = "󰀢",
        EYEPLANT = "󰀣",
        FARM = "󰀇",
        FIREPIT = "󰀤",
        FIRE = "󰀈",
        FLEX = "󰀙",
        GHOST = "󰀉",
        GOLD = "󰀚",
        GRAVE = "󰀊",
        HAMBAT = "󰀋",
        HAMMER = "󰀌",
        HEART = "󰀍",
        HORN = "󰀥",
        HUNGER = "󰀎",
        LIGHTBULB = "󰀏",
        ARCANE = "󰀀",
        MEAT = "󰀦",
        PIG = "󰀐",
        POOP = "󰀑",
        REDGEM = "󰀒",
        REFINE = "󰀧",
        SALT = "󰀨",
        SANITY = "󰀓",
        SCIENCEMACHINE = "󰀔",
        FAKETEETH = "󰀆",
        SHADOW = "󰀩",
        SHOVEL = "󰀪",
        SKULL = "󰀕",
        WEB = "󰀗",
        THUMBSUP = "󰀫",
        TOPHAT = "󰀖",
        TORCH = "󰀛",
        TRAP = "󰀬",
        TROPHY = "󰀭",
        WAVE = "󰀮",
        WORMHOLE = "󰀯",
        PORTAL = "󰀰",
        RESURRECTION = "󰀱",

        LMB = STRINGS.LMB,
        RMB = STRINGS.RMB
    },

    ANIMATED = {
        DISCORD = {},
    },

    DISCORD = {},
}

EMOJIS.VANILLA = {}
EMOJIS.INPUTNAME_TO_ID = {}
EMOJIS.DATA = {}

require("emoji_items")
EMOJIS.VANILLA_ITEMS = EMOJI_ITEMS -- This should be the untouched version from emoji_items.lua
for emoji_id, item in pairs(EMOJIS.VANILLA_ITEMS) do
    EMOJIS.VANILLA[emoji_id] = item.data.utf8_str
    EMOJIS.INPUTNAME_TO_ID[item.input_name] = emoji_id
    EMOJIS.DATA[emoji_id] = {
        id = emoji_id,
        name = item.input_name,
        utf8_str = item.data.utf8_str,
        animated = false,
        available = true,
        vanilla = true,
    }
end

print("Loading emoji data...")
local loaded_emoji_data_fn = kleiloadlua(MODROOT.."/scripts/generated/emoji_data.lua")
if type(loaded_emoji_data_fn) == "function" then
    local success, custom_data = pcall(loaded_emoji_data_fn)
    if success then
        for id, entry in pairs(custom_data) do
            EMOJIS.DATA[id] = entry
            if entry.animated then
                EMOJIS.ANIMATED.DISCORD[id] = entry.utf8_str
            else
                EMOJIS.DISCORD[id] = entry.utf8_str
            end
        end
    else
        print("[Error] Failed to load emoji data:", custom_data)
    end
else
    print("[Error] Failed to load emoji data:", loaded_emoji_data_fn)
end

EMOJIS.ALL = MergeMaps(EMOJIS.VANILLA, EMOJIS.DISCORD, EMOJIS.ANIMATED.DISCORD)

EMOJIS.UTF_TO_NAME = {}
for name, utf in pairs(EMOJIS.ALL) do
    EMOJIS.UTF_TO_NAME[utf] = name
end

--- @enum EMOJIS.PACK_TYPE
EMOJIS.PACK_TYPE = {
    CLASSIC = "CLASSIC",
    ANIMATED = "ANIMATED"
}

EMOJIS.PACKS = {
    DISCORD = {
        [EMOJIS.PACK_TYPE.ANIMATED] = "discord_emojis_animated",
        [EMOJIS.PACK_TYPE.CLASSIC]  = "discord_emojis",
    },
}

EMOJIS.PACK_CHAR_MAP = {
    [EMOJIS.PACKS.DISCORD[EMOJIS.PACK_TYPE.ANIMATED]] = EMOJIS.ANIMATED.DISCORD,
    [EMOJIS.PACKS.DISCORD[EMOJIS.PACK_TYPE.CLASSIC]] = EMOJIS.DISCORD,
}

local DISCORD_CLASSIC_PACK = EMOJIS.PACKS.DISCORD[EMOJIS.PACK_TYPE.CLASSIC]
local DISCORD_ANIMATED_PACK = EMOJIS.PACKS.DISCORD[EMOJIS.PACK_TYPE.ANIMATED]

local DEFAULT_CUSTOM_EMOJI_PACKS = {
    [DISCORD_CLASSIC_PACK] = true,
    [DISCORD_ANIMATED_PACK] = true,
}

local PACK_OPTION_KEYS = {
    [DISCORD_CLASSIC_PACK] = "DISCORD_EMOJIS",
    [DISCORD_ANIMATED_PACK] = "DISCORD_EMOJIS_ANIMATED",
}

local function ApplyPackOptionConfig(packs)
    for pack_name, option_name in pairs(PACK_OPTION_KEYS) do
        local enabled = GetModConfigData(option_name)
        local default_enabled = DEFAULT_CUSTOM_EMOJI_PACKS[pack_name]
        -- Apply only explicit non-default values so older CUSTOM_EMOJI_PACKS configs
        -- keep working without being silently overridden by new defaults.
        if type(enabled) == "boolean" and enabled ~= default_enabled then
            packs[pack_name] = enabled
        end
    end
end

local function GetCustomEmojiPackConfig()
    local configured = GetModConfigData("CUSTOM_EMOJI_PACKS")
    local packs = shallowcopy(DEFAULT_CUSTOM_EMOJI_PACKS)

    if type(configured) == "table" then
        for pack_name, enabled in pairs(configured) do
            packs[pack_name] = enabled == true
        end
    end

    ApplyPackOptionConfig(packs)

    return packs
end

--- @param emoji_id string
--- @param userid string? Defaults to TheNet:GetUserID()
--- @return boolean
function EMOJIS.IsEmojiOwnedBy(emoji_id, userid)
    if not EMOJIS.IsEmojiVanilla(emoji_id) then
        return true -- For custom emojis we do not have any ownership logic yet.
    end

    if emoji_id ~= nil then
        userid = userid or TheNet:GetUserID()
        if TheWorld ~= nil and userid ~= nil and TheWorld.ismastersim then
            return TheInventory:CheckClientOwnership(userid, emoji_id)
        elseif userid == TheNet:GetUserID() then
            return TheInventory:CheckOwnership(emoji_id)
        end
    end

    return false
end

function EMOJIS.IsEmojiAnimated(emoji_id)
    local data = EMOJIS.DATA[emoji_id]
    return data ~= nil and data.animated == true
end

function EMOJIS.GetPackForEmoji(emoji_id)
    for pack_name, char_map in pairs(EMOJIS.PACK_CHAR_MAP) do
        if EMOJIS.IsEmojiPackAvailable(pack_name) and char_map[emoji_id] ~= nil then
            return pack_name
        end
    end
end

function EMOJIS.IsEmojiVanilla(emoji_id)
    return EMOJIS.VANILLA[emoji_id] ~= nil
end

function EMOJIS.IsEmojiPackAvailable(pack_name)
    return GetCustomEmojiPackConfig()[pack_name] == true
end


function EMOJIS.CountEmojisInString(s)
    local count = 0
    for _ in s:gmatch(m_CONSTANTS.UTF_EMOJI_PATTERN) do
        count = count + 1
    end
    return count
end


function EMOJIS.IsEmojiAvailable(emoji_id)
    local emoji_data = EMOJIS.DATA[emoji_id]
    if not emoji_data or emoji_data.available == false then
        return false
    end

    local utf8_str = emoji_data.utf8_str
    if not utf8_str or not EMOJIS.UTF_TO_NAME[utf8_str] then
        return false
    end

    return EMOJIS.GetPackForEmoji(emoji_id) ~= nil or EMOJIS.IsEmojiVanilla(emoji_id)
end

function EMOJIS.IsEmojiPackAnimated(pack_name)
    for _, category in pairs(EMOJIS.PACKS) do
        if category[EMOJIS.PACK_TYPE.ANIMATED] == pack_name then
            return true
        end
    end

    return false
end

function EMOJIS.IsAnyAnimatedEmojiPackEnabled()
    for _, category in pairs(EMOJIS.PACKS) do
        for pack_type, pack_name in pairs(category) do
            if pack_type == EMOJIS.PACK_TYPE.ANIMATED and EMOJIS.IsEmojiPackAvailable(pack_name) then
                return true
            end
        end
    end

    return false
end

return EMOJIS
