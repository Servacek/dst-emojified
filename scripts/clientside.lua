
-- debugging:
GLOBAL.BRANCH = "dev"
GLOBAL.CHEATS_ENABLED = true

----------------------------------

local TheNet = GLOBAL.TheNet

local BuiltinEmojiUtils = require("util/emoji")

--------------------------------
-- [[ Constants ]]
--------------------------------

local FONT_ASSET_PATH = MODROOT.."fonts/%s.zip"
local ANIM_ASSET_PATH = MODROOT.."anim/%s.zip"

local CUSTOM_EMOJI_FONTS = {}
local FONT_FALLBACK_TABLES = {
    DEFAULT_FALLBACK_TABLE,
    DEFAULT_FALLBACK_TABLE_OUTLINE
}

--------------------------------
-- [[ Extensions ]]
--------------------------------

print("Loading extensions...")

modrequire("extensions/api")
modrequire("extensions/table")
modrequire("extensions/text")
modrequire("extensions/chatsidebar")
modrequire("extensions/chatinputscreen")

local ClientEmojiManager = modrequire("clientemojimanager")
local m_EMOJIS = modrequire("emojis")
local m_CONSTANTS   = modrequire("constants")

--------------------------------
-- [[ Assets ]]
--------------------------------

Assets = {
    Asset("IMAGE", "images/emoji_menu.tex"),
    Asset("ATLAS", "images/emoji_menu.xml"),
}

for pack_name, enabled in pairs(GetModConfigData("CUSTOM_EMOJI_PACKS") or {}) do
    if enabled == true then
        local filepath = FONT_ASSET_PATH:format(pack_name)
        local font_table = {filename = filepath, alias = pack_name, disable_color = true}

        table.insert(CUSTOM_EMOJI_FONTS, font_table)
        table.insert(GLOBAL.FONTS, font_table)

        table.insert(Assets, Asset("FONT", filepath))

        if m_EMOJIS.IsEmojiPackAnimated(pack_name) then
            for emoji_name, _ in pairs(m_EMOJIS.PACK_CHAR_MAP[pack_name]) do
                table.insert(Assets, Asset("ANIM", ANIM_ASSET_PATH:format(emoji_name)))
            end
        end
    end
end


AddSimPostInit(function()
    for _, font_table in ipairs(CUSTOM_EMOJI_FONTS) do
        if font_table and font_table.alias then
            for _, fallback_table in ipairs(FONT_FALLBACK_TABLES) do
                if fallback_table then
                    --- Insert only right before the fonts are loaded so the fallbacks cannot be used unloaded.
                    table.insert(fallback_table, 1, font_table.alias)
                end
            end
        end
    end

    GLOBAL.LoadFonts()
end)


local _GetWordPredictionDictionary = BuiltinEmojiUtils.GetWordPredictionDictionary
BuiltinEmojiUtils.GetWordPredictionDictionary = _GetWordPredictionDictionary ~= nil and (function(...)
    local data = _GetWordPredictionDictionary(...) or {}
    for _, char_map in pairs(m_EMOJIS.PACK_CHAR_MAP) do
        table.join(data.words, table.keys(char_map))
    end

    if (data.GetDisplayString ~= nil) then
        local _GetDisplayString = data.GetDisplayString
        data.GetDisplayString = function(word, ...)
            local custom_emote = m_EMOJIS.ALL[word]
            if custom_emote then
                return custom_emote.." "..data.delim..word..data.postfix
            else
                return _GetDisplayString(word, ...)
            end
        end
    end

    return data
end) or nil


local mt = GLOBAL.getmetatable(TheNet)
local _Say = mt and mt.__index and mt.__index.Say
if _Say ~= nil then
    mt.__index.Say = function(self, message, ...)
        if type(message) == "string" then
            message = message:gsub(m_CONSTANTS.EMOJI_PATTERN, function(emoji_id)
                if m_EMOJIS.IsEmojiAvailable(emoji_id) then
                    return m_EMOJIS.ALL[emoji_id]
                end
            end)

            local emoji_count = 0
            local needs_saving = false
            for match in message:gmatch(m_CONSTANTS.UTF_EMOJI_PATTERN) do
                local emoji_name = m_EMOJIS.UTF_TO_NAME[match]
                if emoji_name then
                    ClientEmojiManager:OnEmojiUsed(emoji_name)
                    needs_saving = true
                end

                emoji_count = emoji_count + 1
            end

            if (emoji_count * m_CONSTANTS.EMOJI_CHAR_SIZE + message:utf8len()) > MAX_CHAT_INPUT_LENGTH then
                return -- Do not allow sending such an invalid message
            end

            if needs_saving then
                ClientEmojiManager:SavePersistentData()

                TheGlobalInstance:PushEvent("emojis_used")
            end
        end

        return _Say(self, message, ...)
    end
end
