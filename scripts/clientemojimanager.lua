
-------------------------------------
-- [[ Constants ]]
-------------------------------------

local PERSISTENT_DATA_FILEPATH  = "workshop_emojified_emoji_data"

local MAX_FU_EMOJIS             = 32

--- An emoji is considered new when it was created within a month
--- and was not already displayed.
local NEW_MAX_TIME              = 30 * 24 * 60 * 60

local m_EMOJIS                  = modrequire("emojis")
local m_CONSTANTS               = modrequire("constants")

-------------------------------------
-- [[ Class Declaration ]]
-------------------------------------

--- @class ClientEmojiManager
local ClientEmojiManager = {
    _persistdata = {
        frequently_used = {},
        favourites      = {},
        displayed       = {},
    },

    _encode_save_data = true,
    _unsaved_changes = false,
}

-------------------------------------
-- [[ Static ]]
-------------------------------------

ClientEmojiManager.CATEGORIES_ORDERED = {
    {
        --- Here we want to make sure to keep the order in which the emojis were added to this category.
        id = "FAVORITES",
        name = m_CONSTANTS.STRINGS.FAVORITES,
        emojis = ClientEmojiManager._persistdata.favourites,
        --- Validation not needed because invalid emojis will just not be shown.
        loadfn = function(self, data)
            local emojis_copy = deepcopy(self.emojis)
            table.clear(self.emojis)
            self.emojis = table.toset(emojis_copy, self.emojis)
        end,
    },

    {
        id = "FREQUENTLY_USED",
        name = m_CONSTANTS.STRINGS.FREQUENTLY_USED,
        emojis = {}, -- Has to be loaded
        searchable = false, -- Do not allow the emojis in this category to be searchable since they are dupes.
        maxrows = 2,
        validatefn = function(self, data)
            table.limit(data.frequently_used, MAX_FU_EMOJIS)

            for k, v in pairs(data.frequently_used) do
                if m_EMOJIS.DATA[k] == nil then
                    data.frequently_used[k] = nil -- Remove invalid emojis or non-existent emojis.
                end

                -- No more, since the emoji utf8 characters do not match!
                -- if type(v) == "table" then -- For compatibility with older saves
                --     data.frequently_used[k] = v.count
                -- end
            end
        end,
        sortfn = function(id_a, id_b)
            local frequently_used = ClientEmojiManager._persistdata.frequently_used
            return frequently_used[id_a] > frequently_used[id_b]
        end,
        loadfn = function(self, data)
            local frequently_used_ids = table.keys(data.frequently_used)
            table.sort(frequently_used_ids, self.sortfn)
            table.iclear(self.emojis)
            table.join(self.emojis, frequently_used_ids)
        end,
    },

    {
        id = "DISCORD",
        name = m_CONSTANTS.STRINGS.DISCORD,
        emojis = {},
        optional = true,
        loadfn = function(self) -- Make sure this is loaded only after all the modules.
            for _, pack_name in pairs(m_EMOJIS.PACKS.DISCORD) do
                -- Load these emojis only if their pack is enabled.
                if DEBUG then print("PACK: ", pack_name, "AVAILABLE: ", m_EMOJIS.IsEmojiPackAvailable(pack_name)) end
                if m_EMOJIS.IsEmojiPackAvailable(pack_name) then
                    table.join(self.emojis, table.keys(m_EMOJIS.PACK_CHAR_MAP[pack_name]))
                end
            end
        end,
    },

    {
        id = "VANILLA",
        name = m_CONSTANTS.STRINGS.VANILLA,
        emojis = table.values(m_EMOJIS.INPUTNAME_TO_ID),
    },
}

if DEBUG then table.dump(ClientEmojiManager.CATEGORIES_ORDERED) end

--- A category is represented as a table containing some data associated to the specific emoji category.
--- It also contains a list of emoji ids that are specific to this category.
--- Mapped by ID not by order.
--- @enum ClientEmojiManager.CATEGORY
ClientEmojiManager.CATEGORY = {}
for i, category in ipairs(ClientEmojiManager.CATEGORIES_ORDERED) do
    if category.available ~= false then
        --- Make sure every category has the index field (useful for sorting).
        category.index = i
        -- Custom emojis should be right after the frequently used ones
        -- (similiar to how discord implements this)
        ClientEmojiManager.CATEGORY[category.id] = category
    end
end

-------------------------------------
-- [[ Getters ]]
-------------------------------------

function ClientEmojiManager:IsEmojiNew(emoji_id)
    local emoji_data = m_EMOJIS.DATA[emoji_id]
    return self:IsEmojiAvailable(emoji_id) and not self:WasEmojiAlreadyDisplayed(emoji_id)
        -- Do not show the "new" label for vanilla emojis synce they cannot be actually "new".
        and not m_EMOJIS.IsEmojiVanilla(emoji_id)
        and (
            (emoji_data and emoji_data.timecreated and (os.time() - (tonumber(emoji_data.timecreated) or 0)) < NEW_MAX_TIME)
            -- If nothing was displayed at all that means we are very new to
            -- all of this (probably the users first time seeing this mod).
            -- so show all custom emojis as new.
            or not self:WereAnyEmojisAlreadyDisplayed()
        )
end

--- @param category ClientEmojiManager.CATEGORY
function ClientEmojiManager:HasCategoryAnyAvailableEmojis(category)
    for _, emoji_id in pairs(category.emojis) do
        if self:IsEmojiAvailable(emoji_id) then
            return true
        end
    end

    return false
end

function ClientEmojiManager:HasAnyAvailableEmojis()
    for _, category in pairs(ClientEmojiManager.CATEGORIES_ORDERED) do
        if self:HasCategoryAnyAvailableEmojis(category) then
            return true
        end
    end

    return false
end

function ClientEmojiManager:HasAnyNewEmojis()
    for emoji_id in pairs(m_EMOJIS.DATA) do
        if self:IsEmojiNew(emoji_id) then
            return true
        end
    end

    return false
end

function ClientEmojiManager:HasAnyUnsavedChanges()
    return self._unsaved_changes == true
end

function ClientEmojiManager:WasEmojiAlreadyDisplayed(emoji_id)
    return self._persistdata.displayed[emoji_id] == true
end

function ClientEmojiManager:WereAnyEmojisAlreadyDisplayed()
    return table.empty(self._persistdata.displayed) == false
end

function ClientEmojiManager:IsEmojiFavorite(emoji_id)
    return table.getkey(self._persistdata.favourites, emoji_id) ~= nil
end

function ClientEmojiManager:IsEmojiAvailable(emoji_id)
    return m_EMOJIS.IsEmojiAvailable(emoji_id)
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

function ClientEmojiManager:SavePersistentData()
    TheSim:SetPersistentString(PERSISTENT_DATA_FILEPATH, ZipAndEncodeString(self._persistdata), self._encode_save_data, function(success)
        if success then
            self._unsaved_changes = false
        end
    end)
end

function ClientEmojiManager:LoadPersistentData()
    local success, datastr
    -- Synchronous even if it doesnt look like that.
    TheSim:GetPersistentString(PERSISTENT_DATA_FILEPATH, function(successfull, str)
        success = successfull
        datastr = str
    end)
    if not success or not datastr then
        return
    end

    local data = DecodeAndUnzipString(datastr)
    if type(data) == "table" then
         -- Load up in the existing table in case it is being referenced somewhere already.
        table.update(self._persistdata, data)
    end
end

function ClientEmojiManager:LoadCustomEmojiCategories()
    -- Load up all the categories that require loading (that means they have the loadfn function).
    for _, category in pairs(ClientEmojiManager.CATEGORY) do
        -- Make sure we validate persistdata table before giving it to the emoji loader function.
        if category.validatefn then
            category:validatefn(self._persistdata)
        end

        if category.loadfn then
            category:loadfn(self._persistdata)
        end
    end
end

-------------------------------------
-- [[ Event Handlers ]]
-------------------------------------

function ClientEmojiManager:OnEmojiUsed(emoji_id)
    local category = ClientEmojiManager.CATEGORY.FREQUENTLY_USED
    self._persistdata.frequently_used[emoji_id] = (self._persistdata.frequently_used[emoji_id] or 0) + 1
    table.reinsort(category.emojis, emoji_id, category.sortfn)

    self:OnEmojiDisplayed(emoji_id)
end

function ClientEmojiManager:OnEmojiFavoriteToggled(emoji_id)
    if self:IsEmojiFavorite(emoji_id) then
        table.removearrayvalue(self._persistdata.favourites, emoji_id)
    else
        table.insert(self._persistdata.favourites, emoji_id)
    end

    self._unsaved_changes = true
end

function ClientEmojiManager:OnEmojiDisplayed(emoji_id)
    if self._persistdata.displayed[emoji_id] == nil then
        self._persistdata.displayed[emoji_id] = true
        self._unsaved_changes = true
    end
end

-------------------------------------
-- [[ Setup ]]
-------------------------------------

-- This will populate self._persistdata, which is used later when loading emojis.
ClientEmojiManager:LoadPersistentData()
-- Custom emoji categories can be loaded even when persistdata failed!
ClientEmojiManager:LoadCustomEmojiCategories()

-------------------------------------
-- [[ Return ]]
-------------------------------------

return ClientEmojiManager
