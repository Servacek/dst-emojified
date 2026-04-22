
local ImageButton = require("widgets/imagebutton")
local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Image = require("widgets/image")

--- @type TEMPLATES
local TEMPLATES = require("widgets/redux/templates")

-----------------------------------------

local m_CONSTANTS = modrequire("constants")

local m_EMOJIS = modrequire("emojis")

local m_ClientEmojiManager = modrequire("clientemojimanager")

local EmojiButton = modrequire("widgets/emojibutton")

---------------------------
-- [[ Constants ]]
---------------------------

local MENU_WIDTH = 200
local MENU_HEIGHT = 300

local ITEM_SIZE = 35
local SCROLLER_ITEM_SPACING = 0
local SCROLLER_ITEM_MARGIN = 10
local SCROLLIST_WIDGET_WIDTH = ITEM_SIZE + SCROLLER_ITEM_SPACING + SCROLLER_ITEM_MARGIN -- 50
local SCROLLIST_WIDGET_HEIGHT = SCROLLIST_WIDGET_WIDTH -- We want it to be a square

local SCROLLIST_MARGIN_X = 10
local SCROLLIST_PAD = 0
-- scissor_width = opts.widget_width * opts.num_columns + scissor_pad
local SCROLLIST_WIDTH = math.floor(
    (MENU_WIDTH - SCROLLIST_MARGIN_X) / SCROLLIST_WIDGET_WIDTH
) * SCROLLIST_WIDGET_WIDTH + SCROLLIST_WIDGET_WIDTH --(MENU_WIDTH * 1.8) - SCROLLIST_WIDGET_WIDTH -- SCROLLIST_MARGIN_X

local SEARCHBOX_PADDING_X = 0 -- 10
local SEARCHBOX_PADDING_Y = -25
local SEARCHBOX_MARGIN_X = 22
local SEARCHBOX_MARGIN_Y = -25
local SEARCHBOX_WIDTH = SCROLLIST_WIDTH + SEARCHBOX_MARGIN_X
local SEARCHBOX_HEIGHT = 35
local SEARCHBOX_FONT_SIZE = nil --35 -- Let it fallback to the default value
local SEARCHBOX_VALID_CHARS = [[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_]]

local SCROLLIST_PADDING_Y = -(SEARCHBOX_HEIGHT + SEARCHBOX_MARGIN_Y) + 10
local SCROLLIST_PEAK_PERCENT = .62 -- Number of percent the last row is visible Can be used for adjusting the size of the scrolling grid
local SCROLLIST_MARGIN_Y = 0
-- opts.widget_height * opts.peek_percent
local SCROLLIST_PEAK_HEIGHT = SCROLLIST_WIDGET_HEIGHT * SCROLLIST_PEAK_PERCENT
-- scissor_height = opts.widget_height * opts.num_visible_rows + peek_height
local SCROLLIST_HEIGHT = math.floor(
    (MENU_HEIGHT - SCROLLIST_MARGIN_Y + SCROLLIST_PADDING_Y) / SCROLLIST_WIDGET_HEIGHT
) * SCROLLIST_WIDGET_HEIGHT - SCROLLIST_WIDGET_HEIGHT
local SCROLLIST_PADDING_X = -10

-- These have to be unsigned integers.
local SCROLLER_VISIBLE_ROWS = math.floor(SCROLLIST_HEIGHT / SCROLLIST_WIDGET_HEIGHT)
local SCROLLER_VISIBLE_COLS = math.floor((SCROLLIST_WIDTH - SCROLLIST_PAD) / SCROLLIST_WIDGET_WIDTH)

local SCROLLBAR_OFFSET = 15

local TIMEBUDGET = FRAMES * 0.1
local CHECK_FREQUENCY = 50

--local MAX_ALIAS_LEN = 32

local EMPTY_TILE = {} -- So we do not create a dummy table each time as a fillament
local EMPTY_HEADER_TILE = {header = true}

local DELIM = m_CONSTANTS.EMOJI_DELIM
local EMOJI_ALIAS_FORMAT = DELIM.."%s"..DELIM

local EMOJI_CHARACTER_FALLBACK = "?"

local CLEAR_BUTTON_CONTROLS = "Ctrl + X"

local DIRECTIONS = {MOVE_LEFT = -1, MOVE_RIGHT = 1, MOVE_UP = -1, MOVE_DOWN = 1}

local ATLAS = MODROOT.."images/emoji_menu.xml"

local STYLES = {
    REDUX_BROWN = "redux_brown",
    HUD = "hud"
}

---------------------------
-- [[ Local Variables ]]
---------------------------

local emoji_data_cache = {}

local _i = CHECK_FREQUENCY
local _last_check = 0

---------------------------
-- [[ Local Functions ]]
---------------------------

-- Inspired by Geometric Placement (rezecib)
local function check_and_yield()
    _i = _i - 1
    if _i == 0 then
        if os.clock() - _last_check > TIMEBUDGET then
            Yield()
            _last_check = os.clock()
        end
        _i = CHECK_FREQUENCY
    end
end

local function is_emoji(widget, emoji)
    return widget and widget.data and (
        (emoji and widget.data.emoji_utf8 == emoji) or (emoji == nil and widget.data.emoji_utf8 ~= nil)
    )
end

local function OnUpdateEmojiWidget(emoji_widget)
    if m_ClientEmojiManager:IsEmojiFavorite(emoji_widget.data and emoji_widget.data.emoji_id) then
        emoji_widget.button.fav_button:SetTextures(ATLAS, "star_checked.tex", "star_checked.tex", nil, "star_uncheck.tex")
        emoji_widget.button.fav_button:SetHoverText(m_CONSTANTS.STRINGS.UI.EMOJI_MENU.UNFAVORITE_BUTTON_HOVER)
    else
        emoji_widget.button.fav_button:SetTextures(ATLAS, "star_uncheck.tex", "star_uncheck.tex", nil, "star_checked.tex")
        emoji_widget.button.fav_button:SetHoverText(m_CONSTANTS.STRINGS.UI.EMOJI_MENU.FAVORITE_BUTTON_HOVER)
    end
end

---------------------------
-- [[ Class Declaration ]]
---------------------------

--- @class EmojiMenu
--- @field selected_widget_data table?
--- @param style EmojiMenu.STYLE
local EmojiMenu = Class(Widget, function(self, style)
    Widget._ctor(self, "EmojiMenu")

    self.selected_widget_data = nil

    self.style = style or STYLES.REDUX_BROWN

    self.loaded = false

    self.onopen = nil
    self.onclose = nil
    self.onclosing = nil
    self.onrefresh = nil

    self.onemojichosen = nil

    self.inst:ListenForEvent("emojis_used", function()
        if self.categories ~= nil then
            -- Do not do the reload immediately since we can use emojis even without the menu open.
            emoji_data_cache[self.categories] = nil
        end
    end, TheGlobalInstance)

    self.widget_data = {} -- All scrollable menu widgets
    self.search_data = {} -- Array of emojis implicitly sorted by priority (every emoji there should be unique)
    self.emoji_data_map = {} -- Map of emoji_ids and their widget data.
    self.new_emojis = {} -- This is being reseted upon reopening the emoji menu.

    self.last_search_data = nil
    self.last_search_text = nil
end)

---------------------------
-- [[ Static Variables ]]
---------------------------

EmojiMenu.ATLAS = ATLAS

--- @enum EmojiMenu.STYLE
EmojiMenu.STYLES = STYLES

---------------------------
-- [[ Private Methods ]]
---------------------------

function EmojiMenu:_GetWidgetDataForEmoji(emoji_id, category)
    local emoji_data = m_EMOJIS.DATA[emoji_id]
    local emoji_name = emoji_data.name
    local search_token = emoji_name
    local fullname = EMOJI_ALIAS_FORMAT:format(emoji_name)
    if table.empty(emoji_data.aliases) == false then
        for _, alias in ipairs(emoji_data.aliases) do
            fullname = fullname.." "..EMOJI_ALIAS_FORMAT:format(alias)
            search_token = search_token.." "..alias
        end
    end

    return {
        emoji_utf8 = emoji_data.utf8_str or (emoji_data.animated and "" or EMOJI_CHARACTER_FALLBACK),
        display_name = fullname,
        search_token = search_token, -- In case we add case sensitive search priorities
        search_token_normalized = search_token:lower(),
        category = category.name,
        category_index = category.index,
        searchable = category.searchable ~= false,
        name = emoji_name,
        case_sensitive = not string.match(fullname, "%u"), -- check if not lowercase.
        unlocked = m_EMOJIS.IsEmojiOwnedBy(emoji_id),
        emoji_id = emoji_id,
        timecreated = emoji_data.timecreated,
    }
end

--- @param category table
function EmojiMenu:_LoadEmojiCategory(category)
    -- PEARL.debug("EmojiMenu:_LoadEmojiCategory")
    print("LOADING EMOJI CATEGORY")
    table.dump(category)

    local remainder = #self.widget_data % SCROLLER_VISIBLE_COLS
    if remainder ~= 0 then -- Fill the remaining space in the last row with empty tiles.
        for _ = 1, SCROLLER_VISIBLE_COLS - remainder do
            self.widget_data[#self.widget_data + 1] = EMPTY_TILE
        end
    end

    self.widget_data[#self.widget_data + 1] = {
        category = category.name or category.id, header = true
    }

    for _ = 1, SCROLLER_VISIBLE_COLS - 1 do
        self.widget_data[#self.widget_data + 1] = EMPTY_HEADER_TILE
    end

    -- We cannot skip any emojis from category.emojis since the indexes need to be "synced"
    local locked
    local rows, cols = 1, 0
    for _, emoji_id in ipairs(category.emojis) do
        cols = cols + 1
        if cols > SCROLLER_VISIBLE_COLS then
            rows, cols = rows + 1, 1
        end

        if category.maxrows and rows > category.maxrows then
            break
        end

        if m_ClientEmojiManager:IsEmojiAvailable(emoji_id) then
            local widget_data = self:_GetWidgetDataForEmoji(emoji_id, category)
            if widget_data.unlocked ~= true then
                locked = locked or {}
                locked[#locked + 1] = widget_data
            else
                self.widget_data[#self.widget_data + 1] = widget_data
            end

            -- Search data contains each emoji widget just once.
            if widget_data.searchable and self.emoji_data_map[emoji_id] == nil then
                self.search_data[#self.search_data + 1] = widget_data
                self.emoji_data_map[emoji_id] = widget_data
            end
        end

        check_and_yield()
    end

    if locked then
        table.join(self.widget_data, locked) -- Keep locked emojis at the bottom
    end
end

function EmojiMenu:_CreateSearchBox(width, height)
    local searchbox = Widget("emoji_menu_searchbox")

    searchbox.textbox_root = searchbox:AddChild(TEMPLATES.StandardSingleLineTextEntry(nil, width, height, nil, SEARCHBOX_FONT_SIZE))
    searchbox.textbox = searchbox.textbox_root.textbox
    searchbox.textbox:SetForceEdit(true)
    searchbox.textbox:SetTextLengthLimit(25)
    searchbox.textbox:EnableRegionSizeLimit(true)
    searchbox.textbox:SetCharacterFilter(SEARCHBOX_VALID_CHARS)
    searchbox.textbox:EnableWordWrap(false)
    searchbox.textbox:SetAllowNewline(false)
    searchbox.textbox:EnableScrollEditWindow(true)
    searchbox.textbox:SetHelpTextEdit("")
    searchbox.textbox:SetTextPrompt("", UICOLOURS.GREY)
    searchbox.textbox:SetPassControlToScreen(CONTROL_CANCEL, true)
    searchbox.textbox:SetPassControlToScreen(CONTROL_SCROLLBACK, true)
    searchbox.textbox:SetPassControlToScreen(CONTROL_SCROLLFWD, true)
    searchbox.textbox:SetPassControlToScreen(CONTROL_SCROLLFWD, true)
    searchbox.textbox._TryUpdateTextPrompt = function(_self)
        if _self.prompt then
            local visible = _self.prompt:IsVisible()
            if searchbox:HasAnyInput() then
                _self.prompt:Hide()
            else
                _self.prompt:Show()
            end

            if visible ~= _self.prompt:IsVisible() then
                self:OnSearchPromptUpdated(_self.prompt)
            end
        end
    end

    searchbox.textbox.OnTextInputted = function()
        searchbox.textbox:_TryUpdateTextPrompt()

        local search_text = searchbox.textbox:GetLineEditString()
        if search_text ~= nil and search_text ~= self.last_search_text then
            self:RefreshSearching(search_text)
        end
    end

    searchbox.textbox.OnTextEntered = function()
        -- Only allow ENTER key for entering emojis
        if self.selected_widget_data and TheInput:IsKeyDown(KEY_ENTER) then
            self:_EnterEmoji(self.selected_widget_data.emoji_id)
        else
            -- No matches, so keep the editing state
            searchbox.textbox:SetEditing(true)
        end
    end

    -- Just do nothing - Also an option but then cause the input to not be fetched
    -- So... let's just keep it the Discord way and lose focus.
    --searchbox.textbox.OnStopForceProcessTextInput = function() end

    searchbox.HasAnyInput = function()
        return searchbox.textbox:GetString():len() > 0
    end

    searchbox.Clear = function()
        searchbox.button_clear:Hide()

        searchbox.textbox:SetString("")
        searchbox.textbox:OnTextInputted()

        searchbox.textbox.prompt:SetString(m_CONSTANTS.STRINGS.UI.EMOJI_MENU.SEARCH)
    end

    local atlas = resolvefilepath(CRAFTING_ATLAS)
    searchbox.button_clear = searchbox.textbox:AddChild(ImageButton(atlas, "pinslot_unpin_button.tex"))
    searchbox.button_clear:SetScale(0.2)
    searchbox.button_clear:SetHoverText(m_CONSTANTS.STRINGS.UI.EMOJI_MENU.CLEAR_BUTTON_HOVER:format(
        CLEAR_BUTTON_CONTROLS
    ), {offset_y = 50})
    searchbox.button_clear:SetPosition(SEARCHBOX_WIDTH / 2 - 20, 0)
    searchbox.button_clear:Hide()

    searchbox.button_clear:SetOnClick(searchbox.Clear)

    searchbox.focus_forward = searchbox.textbox

    return searchbox
end

function EmojiMenu:_EnterEmoji(emoji_id)
    -- PEARL.debug("EmojiMenu:_ChooseEmoji", emoji_id)

    if self.onemojichosen then
        self.onemojichosen(emoji_id)
    end

    -- When shift is down, keep the window open so emojis can be spammed.
    if not TheInput:IsKeyDown(KEY_SHIFT) then
        self:Close()
    end
end

function EmojiMenu:_CreateEmojiScrollList(peak_percent)
    local function ScrollWidgetsCtor(context, index)
        local w = Widget("emoji_menu_widget_"..tostring(index))

        -- Glow removed because it was causing problems with focus.
        w.button = w:AddChild(EmojiButton(ITEM_SIZE, false, SCROLLER_ITEM_MARGIN))
        --w.button.AllowOnControlWhenSelected = true -- So we handle clicks even when selected

        w.focus_forward = w.button

        w.button.fav_button = w.button:AddChild(ImageButton(ATLAS, "star_uncheck.tex", "star_uncheck.tex", nil, "star_checked.tex"))
        w.button.fav_button:SetFocusScale(.6, .6)
        w.button.fav_button:SetNormalScale(.5, .5)
        w.button.fav_button:SetPosition(20, 20)
        w.button.fav_button:Hide()
        w.button.fav_button:SetOnClick(function()
            if not w.data.emoji_id then
                return
            end

            m_ClientEmojiManager:OnEmojiFavoriteToggled(w.data.emoji_id)
            OnUpdateEmojiWidget(w)

            m_ClientEmojiManager:SavePersistentData()
            self:ReloadData(true)
        end)

        ----------------
        w.category_label = w:AddChild(Text(TITLEFONT, 28))
        -- Push right to centre across all columns.
        w.category_label:SetPosition(SCROLLIST_WIDGET_WIDTH * (SCROLLER_VISIBLE_COLS-1)/2, 0)
        w.category_label:SetHAlign(ANCHOR_MIDDLE)
        w.category_label:SetRegionSize(SCROLLIST_WIDGET_WIDTH * SCROLLER_VISIBLE_COLS, SCROLLIST_WIDGET_HEIGHT)

        local width, height = w.category_label:GetRegionSize()
        local line_height = 4
        w.category_label.underline = w.category_label:AddChild(Image("images/ui.xml", "line_horizontal_white.tex"))
        w.category_label.underline:SetPosition(0, -line_height / 2 - height / 2 + 5)
        w.category_label.underline:SetTint(unpack(BROWN))
        w.category_label.underline:ScaleToSize(width, line_height)
        w.category_label.underline:MoveToBack()
        ----------------

        w.button:SetOnGainFocus(function()
            if not w:IsSelected() then
                self:SelectEmojiWidget(w, true)
            end

            if w.button:IsEnabled() and w:IsSelected() then
                w.button.fav_button:Show()
            end
        end)

        w.button:SetOnLoseFocus(function()
            w.button.fav_button:Hide()
        end)

        w.button:SetOnClick(function()
            self:_EnterEmoji(w.data.emoji_id)
        end)

        w.IsSelected = function()
            return self.selected_widget_data ~= nil and self.selected_widget_data == w.data
               and self.selected_widget_data.widget == w
        end

        w.Unselect = function()
            if self.selected_widget_data.widget == w then
                --self.selected_widget_data = nil -- Always keep something selected?
            end

            w.button.bg:SetTint(0, 0, 0, 0)
        end

        w.Select = function()
            if self.selected_widget_data ~= nil and self.selected_widget_data.widget ~= w then
                self.selected_widget_data.widget:Unselect()
            end

            self.selected_widget_data = w.data

            w.button.bg:SetTint(.4, .4, .4, .5)
        end

		----------------
        OnUpdateEmojiWidget(w)
        ----------------

		return w
    end

    local function ApplyDataToWidget(context, widget, data, index)
        local old_data = widget.data
        widget.data = data
        if table.empty(data) ~= false then
            return widget:Hide()
        end

        --print("ASSIGNING DATA TO WIDGET", widget, data)
        widget.data.widget = widget
        widget:MoveToFront()
        widget.category_label:Hide()
        if data.header then
            widget.button:Hide()

            if type(data.category) == "string" then
                widget.category_label:SetString(data.category)
                widget.category_label:Show()
                widget:MoveToBack()
            end
        elseif type(data.emoji_utf8) == "string" then
            widget.button:SetText(data.emoji_utf8)
            widget.button:Show()

            OnUpdateEmojiWidget(widget)

            if data.unlocked == false then
                widget.button:Lock()
                widget.button.fav_button:Hide()
            else
                widget.button:Unlock()

                if self.new_emojis[data.emoji_id] == true then
                    widget.button.new_tag_image:Show()
                else
                    widget.button.new_tag_image:Hide()
                end
            end

            --print("OLD DATA", (old_data and old_data.emoji_id), "NEW DATA", (data.emoji_id), "SELECTED", (self.selected_widget_data and self.selected_widget_data.emoji_id))
            --print(self.scroll_list.focused_widget_index, self.scroll_list.widgets_to_update[self.scroll_list.focused_widget_index])
            if widget.focus or (self.selected_widget_data and data == self.selected_widget_data) then
                self:SelectEmojiWidget(widget)
            elseif (self.selected_widget_data and data ~= self.selected_widget_data) then
                --print("UNSELECT", widget)
                self:UnselectEmojiWidget(widget)
            end

            if self.scroll_list and self.scroll_list:IsVisible() and widget:IsFullyInView() then
                m_ClientEmojiManager:OnEmojiDisplayed(data.emoji_id)
            end
        end

        if not widget:IsVisible() then
            widget:Show()
        end
    end

	local scroll_list = TEMPLATES.ScrollingGrid(self.widget_data, {
        scroll_context          = nil,  -- Used for custom arguments for ScrollWidgetsCtor
        --- @NOTE: This doesn't need to be true. If you need the scrolling widget to be bigger/smaller
        --- Just change the spacing.
        widget_width            = SCROLLIST_WIDGET_WIDTH, -- width of one of the widgets in the grid
        widget_height           = SCROLLIST_WIDGET_HEIGHT, -- height of one of the widgets in the grid
        peek_height             = SCROLLIST_PEAK_HEIGHT, -- how much of row to see at the bottom.
        peek_percent            = peak_percent or SCROLLIST_PEAK_PERCENT,
        item_ctor_fn            = ScrollWidgetsCtor,
        scissor_pad             = SCROLLIST_PAD,
        scrollbar_height_offset = -50, -- Height of the scrollbar itself
        num_visible_rows        = SCROLLER_VISIBLE_ROWS,
        num_columns             = SCROLLER_VISIBLE_COLS,
        scroll_per_click        = 1,
        scrollbar_offset        = SCROLLBAR_OFFSET, -- Offset of the scrollbar from the grid
        apply_fn                = ApplyDataToWidget,
        --allow_bottom_empty_row  = false,
    })

    if self.style == EmojiMenu.STYLES.HUD then
        local atlas = resolvefilepath(CRAFTING_ATLAS)
        scroll_list.up_button:SetTextures(atlas, "scrollbar_arrow_up.tex", "scrollbar_arrow_up_hl.tex")
        scroll_list.up_button:SetScale(0.4)

        scroll_list.down_button:SetTextures(atlas, "scrollbar_arrow_down.tex", "scrollbar_arrow_down_hl.tex")
        scroll_list.down_button:SetScale(0.4)

        scroll_list.scroll_bar_line:SetTexture(atlas, "scrollbar_bar.tex")
        scroll_list.scroll_bar_line:ScaleToSize(11, scroll_list.scrollbar_height - 15)

        scroll_list.position_marker:SetTextures(atlas, "scrollbar_handle.tex")
        scroll_list.position_marker.image:SetTexture(atlas, "scrollbar_handle.tex")
        scroll_list.position_marker:SetScale(.3)
    end

    scroll_list.no_emojis_msg = scroll_list:AddChild(Text(UIFONT, 26, m_CONSTANTS.STRINGS.UI.EMOJI_MENU.NO_EMOJIS_FOUND, UICOLOURS.GOLD_UNIMPORTANT))
	scroll_list.no_emojis_msg:SetPosition(SCROLLBAR_OFFSET, 0)
	scroll_list.no_emojis_msg:Hide()

	scroll_list.custom_focus_check = function() return self.focus end

    --- Called after all the data are assigned to widgets using "ApplyDataToWidget"
    --- So save the persistent data here in case we have displayed some brand new emojis.
    AddClassFunctionPostCall("RefreshView", function()
        if m_ClientEmojiManager:HasAnyUnsavedChanges() then
            m_ClientEmojiManager:SavePersistentData()
        end

        if self.onrefresh then
            self.onrefresh()
        end
    end, scroll_list)
    -- scroll_list.OnEmojiWidgetSelected = scroll_list.OnWidgetFocus
    -- scroll_list.OnWidgetFocus = function() end
    -- --- @TODO: Add support for arrow keys and controlers.
    -- scroll_list.OnFocusMove = function(_self, dir, down)
    --     local index = 1
    --     for i = 1, _self.items_per_view do
    --         if _self.widgets_to_update[i] == self.selected_widget then
    --             index = i
    --         end
    --     end

    --     if dir == MOVE_RIGHT or dir == MOVE_LEFT and self.searchbox.textbox:IsEditing() and self.searchbox:HasAnyInput() then
    --         return -- Leave those for the textbox.
    --     end

    --     --- 3x3
    --     --- ... [1, 1] = 1 * 3 + 1
    --     --- ... [2, 2] =
    --     --- ...
    --     local i = index - 1
    --     local row = (math.floor(i / SCROLLER_VISIBLE_COLS))
    --     local col = i - (row * SCROLLER_VISIBLE_COLS) + 1

    --     print(row, col)

    --     if dir == MOVE_LEFT then
    --         local new_index = index - 1
    --         print(new_index % SCROLLER_VISIBLE_COLS, index % SCROLLER_VISIBLE_COLS)
    --         if new_index % SCROLLER_VISIBLE_COLS ~= index % SCROLLER_VISIBLE_COLS then
    --             print("CIRCULAR")
    --             new_index = (index % SCROLLER_VISIBLE_COLS) * SCROLLER_VISIBLE_COLS + SCROLLER_VISIBLE_COLS
    --         end
    --         self:SelectEmojiWidget(_self.widgets_to_update[new_index])
    --     else

    --     end
    -- end

	return scroll_list
end

-- Clears the state of the emoji menu, useful when reloading.
function EmojiMenu:_Clear()
    self.widget_data = {} -- Create a new table since the old one is cached.

    table.iclear(self.search_data)
    table.clear(self.emoji_data_map)

    self.last_search_data = nil
    self.last_search_text = ""

    --- @type table?
    self.selected_widget_data = nil
    self.loaded = false
end

function EmojiMenu:_GetSearchedEmojis(search_prompt, narrow)
    local search_prompt_normalized = search_prompt:lower()
    local search_results = {}

    local search_data = narrow and self.last_search_data or self.search_data
    for i = 1, #search_data do
        local data = search_data[i]

        data._search_i = data.search_token_normalized:find(search_prompt_normalized, 1, true)
        if data._search_i then
            search_results[#search_results + 1] = data
        end
    end

    table.sort(search_results, function(a, b) --- a<b (a should be before b)
        if a.unlocked ~= b.unlocked then
            return a.unlocked ~= false and b.unlocked == false -- Keep locked emojis at the bottom
        elseif a.category_index ~= b.category_index then
            return a.category_index < b.category_index -- Sort by category first
        -- elseif a._case_sensitive_match ~= b._case_sensitive_match then
        --     return a._case_sensitive_match -- Sort by case sensitivity?
        elseif a._search_i ~= b._search_i then
            return a._search_i < b._search_i -- Better matches are closer to the start
        else
            return a.name < b.name -- Sort alphabetically at least.
        end
    end)

    return search_results
end

function EmojiMenu:_BuildExplorerFrame(width, height, style)
    if style == EmojiMenu.STYLES.HUD then
        local atlas = resolvefilepath(CRAFTING_ATLAS)
        local hud_atlas = resolvefilepath(HUD_ATLAS)
        local bg_width, bg_height = width + 180, height + 125
        local menu = Widget("emoji_menu")
        menu.bg = menu:AddChild(Image(hud_atlas, "craftingsubmenu_fullvertical.tex"))
        menu.bg:ScaleToSize(bg_width, -bg_height)

        local searchbox_padding_y = SEARCHBOX_PADDING_Y - 50
        menu.split_header = menu:AddChild(Image(atlas, "horizontal_bar.tex"))
        menu.split_header:SetPosition(1, bg_height/2 - SEARCHBOX_HEIGHT + searchbox_padding_y / 2 - 10)
        menu.split_header:ScaleToSize(bg_width - 114, 15)

        menu.scroll_list = menu:AddChild(self:_CreateEmojiScrollList())
        menu.scroll_list:SetPosition(SCROLLIST_PADDING_X, SCROLLIST_PADDING_Y)

        local _, bg_h = menu.bg:GetSize()
        menu.searchbox = menu:AddChild(self:_CreateSearchBox(SEARCHBOX_WIDTH, SEARCHBOX_HEIGHT))
        menu.searchbox:SetPosition(SEARCHBOX_PADDING_X, bg_h / 2 + searchbox_padding_y)
        menu.searchbox:MoveToFront()

        return menu
    end

    -- Fallback to the more generic redux style
    local menu = TEMPLATES.RectangleWindow(MENU_WIDTH, MENU_HEIGHT)
    menu:SetBackgroundTint(unpack(UICOLOURS.BROWN_DARK)) -- No transparency

    menu.scroll_list = menu:AddChild(self:_CreateEmojiScrollList(1))
    menu.scroll_list:SetPosition(SCROLLIST_PADDING_X, SCROLLIST_PADDING_Y - 20)

    local _, y = menu.top:GetPositionXYZ()
    menu.searchbox = menu:InsertWidget(self:_CreateSearchBox(SEARCHBOX_WIDTH, SEARCHBOX_HEIGHT))
    menu.searchbox:SetPosition(SEARCHBOX_PADDING_X, y + SEARCHBOX_PADDING_Y)
    menu.searchbox:MoveToFront()

    return menu
end

function EmojiMenu:_BuildExplorer()
    self.menu = self:AddChild(self:_BuildExplorerFrame(MENU_WIDTH, MENU_HEIGHT, self.style))
    self.scroll_list = self.menu.scroll_list
    self.searchbox = self.menu.searchbox

    self.default_focus = self.searchbox

    return self.menu
end

--- @return Widget? emoji
function EmojiMenu:GetFirstEmojiWidget()
    if self.scroll_list and self.scroll_list.widgets_to_update then
        for i = 1, #self.scroll_list.widgets_to_update do
            local widget = self.scroll_list.widgets_to_update[i]
            if is_emoji(widget) and widget:IsVisible() then
                return widget
            end
        end
    end
end

function EmojiMenu:UnselectEmojiWidget(widget)
    -- PEARL.debug("EmojiMenu:UnselectEmojiWidget", widget and widget.data and widget.data.display_name)
    return widget:Unselect()
end

--- @param widget Widget?
function EmojiMenu:SelectEmojiWidget(widget, focus)
    -- PEARL.debug("EmojiMenu:SelectEmojiWidget", widget and widget.data and widget.data.display_name, CalledFrom())
    local data = widget and widget.data
    if not widget or not data then
        self.selected_widget_data = nil
        return
    end

    if not self.searchbox:HasAnyInput() and data ~= self.selected_widget_data then
        self.searchbox.textbox.prompt:SetString(data.display_name or data.name)
    end

    widget:Select()
end

--- @param search_text string?
function EmojiMenu:RefreshSearching(search_text)
    -- PEARL.debug("EmojiMenu:RefreshSearching", CalledFrom())
    self.scroll_list.no_emojis_msg:Hide()
    self.scroll_list:ResetScroll()

    local search_result_data
    if not search_text or search_text == "" then
        search_result_data = self.widget_data
        self.last_search_data = nil
    else
        local narrower_search = search_text:len() > (self.last_search_text and self.last_search_text:len() or 0)
        search_result_data = self:_GetSearchedEmojis(search_text, narrower_search)
        self.last_search_data = search_result_data -- Only save data from the search function here!
    end

    self.scroll_list:SetItemsData(search_result_data)

    self.last_search_text = search_text

    if table.empty(self.scroll_list.items) ~= false then
        self.scroll_list.no_emojis_msg:Show()
    end

    -- Accept even nil - representing no results
    self:SelectEmojiWidget(self:GetFirstEmojiWidget())
end

---------------------------
-- [[ Public Methods ]]
---------------------------

function EmojiMenu:IsSearching()
    return self.scroll_list and self.scroll_list.items == self.last_search_data and self.searchbox:HasAnyInput()
end

function EmojiMenu:IsEmojiWidgetSelected(widget)
    return widget:IsSelected()
end

--- @param categories table<number, table> Array of emoji categories. Order is kept.
function EmojiMenu:LoadEmojiCategories(categories, silent)
    self.categories = categories

    -- PEARL.debug("EmojiMenu:LoadEmojisCategories")
    if emoji_data_cache[self.categories] ~= nil then
        self.widget_data = emoji_data_cache[self.categories]
        self:OnEmojiDataLoaded(silent)
        return
    end

    self:_Clear()
    emoji_data_cache[self.categories] = self.widget_data -- Cache the table right away to prevent dupes

    self.loaded = false
    StartStaticThread(function()
        _last_check = os.clock()

        for _, category in ipairs(categories) do
            if m_ClientEmojiManager:HasCategoryAnyAvailableEmojis(category) then
                self:_LoadEmojiCategory(category)

                check_and_yield()
            end
        end

        self:OnEmojiDataLoaded(silent)
    end, self.inst.GUID)
end

function EmojiMenu:ReloadData(silent)
    -- PEARL.debug("EmojiMenu:ReloadData")

    emoji_data_cache[self.categories] = nil
    self:LoadEmojiCategories(self.categories, silent)
end

function EmojiMenu:Open()
    -- PEARL.debug("EmojiMenu:Open")

    -- After each session this is being cleared.
    table.clear(self.new_emojis)

    for emoji_id, _ in pairs(self.emoji_data_map) do
        -- Save the "new" state here in case it changes during the session.
        print(emoji_id, m_ClientEmojiManager:IsEmojiNew(emoji_id))
        if m_ClientEmojiManager:IsEmojiNew(emoji_id) then
            self.new_emojis[emoji_id] = true
        end
    end

    if emoji_data_cache[self.categories] == nil then
        self:ReloadData()
    end

    self.menu = self.menu or self:_BuildExplorer()
    self.menu:Show()
    self.menu:MoveToFront()

    if type(self.onopen) == "function" then
        self.onopen()
    end

    if self.loaded then
        self:RefreshSearching()
    end

    self.searchbox:Clear()
    self.searchbox.textbox:SetFocus(true)
    self.searchbox.textbox:SetEditing(true)
end

function EmojiMenu:Close()
    -- PEARL.debug("EmojiMenu:Close")

    self.menu:Hide()

    self.closing = true
    self.inst:DoStaticTaskInTime(0, function()
        self.closing = false

        if type(self.onclose) == "function" then
            self.onclose()
        end
    end)

    self.searchbox.textbox:SetEditing(false)
    self.searchbox.textbox:SetString("")

    if type(self.onclosing) == "function" then
        self.onclosing()
    end
end

function EmojiMenu:Toggle()
    if self:IsOpen() then
        self:Close()
    else
        self:Open()
    end
end

--- @TODO: Maybe this could be improved?
function EmojiMenu:IsOpen()
    return self.menu and self.menu:IsVisible()
end

---------------------------
-- [[ Event Handlers ]]
---------------------------

function EmojiMenu:OnEmojiDataLoaded(silent)
    -- PEARL.debug("EmojiMenu:OnEmojiDataLoaded", silent)

    self.loaded = true
    if self.scroll_list and self:IsOpen() then
        if silent then
            if self.scroll_list.items ~= self.last_search_data then
                self.scroll_list:SetItemsData(self.widget_data)
            end
        else
            self:RefreshSearching()
            self.searchbox:Clear()
        end
    end
end

function EmojiMenu:OnSearchPromptUpdated(prompt)
    if prompt:IsVisible() then
        self.searchbox.button_clear:Hide()
    else
        self.searchbox.button_clear:Show()
    end
end

function EmojiMenu:OnControl(control, down, ...)
    -- PEARL.debug("EmojiMenu:OnControl", control, down)
    if EmojiMenu._base.OnControl(self, control, down, ...) then return true end

    if not self:IsOpen() then
        return
    end

    if not down and control == CONTROL_CANCEL then -- Pressing ESC
        self:Close()

        return true
    end

    --- @TODO:
    -- if down then
    --     if control == CONTROL_FOCUS_DOWN then
    --         self.scroll_list:OnFocusMove(MOVE_DOWN, true)
    --     elseif control == CONTROL_FOCUS_UP then
    --         self.scroll_list:OnFocusMove(MOVE_UP, true)
    --     elseif control == CONTROL_FOCUS_LEFT then
    --         self.scroll_list:OnFocusMove(MOVE_LEFT, true)
    --     elseif control == CONTROL_FOCUS_RIGHT then
    --         self.scroll_list:OnFocusMove(MOVE_RIGHT, true)
    --     end
    -- end

    -- if self.scroll_list then
    --     return self.scroll_list:OnControl(control, down, ...)
    -- end
end

function EmojiMenu:OnRawKey(key, down, ...)
    -- PEARL.debug("EmojiMenu:OnRawKey", key, down)

    if EmojiMenu._base.OnRawKey(self, key, down, ...) then return true end

    if not self:IsOpen() then
        return
    end

    -- This is here for cases where the searchbox is not focused.
    if down and key == KEY_ENTER and self.selected_widget_data then
        self:_EnterEmoji(self.selected_widget_data.emoji_id)

        return true
    end

    if not down and key == KEY_X and self.searchbox then
        self.searchbox:Clear()

        return true
    end
end

---------------------------
-- [[ Return ]]
---------------------------

return EmojiMenu
