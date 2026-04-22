--- @class Text
local Text = require("widgets/text")
local UIAnim = require("widgets/uianim")

local m_EMOJIS      = modrequire("emojis")
local m_CONSTANTS   = modrequire("constants")

-------------------------------
-- [[ Constants ]]
-------------------------------

local ANIMATED_EMOJI_WIDTH = 52 -- All emojis are 52x52 in size
local ANIMATED_EMOJI_HEIGHT = ANIMATED_EMOJI_WIDTH

-- An hard limit to ensure nobody will lag the game.
local MAX_EMOJIS_IN_MESSAGE = 8

local TEXT_WIDGET_MARGIN_H = 0---3
local TEXT_WIDGET_MARGIN_V = 0---3

local TEXT_WIDGET_OFFSET_X = 1---3
local TEXT_WIDGET_OFFSET_Y = 0---3

-------------------------------
-- [[ Locals ]]
-------------------------------

--- Using static instance, so we do not have to recreate it on simple calculations.
local _text_widget
local _emoji_anim_states = setmetatable({},{__mode = "kv"})
local _parents = setmetatable({},{
    __mode = "kv", -- Do not let the tables stored inside to hide from the Garbage Collector!
})

--- @type function, function
local _TextEditWidget_SetString = TextEditWidget.SetString
local _TextWidget_SetString, _TextWidget_ResetRegionSize = TextWidget.SetString, TextWidget.ResetRegionSize
assert(_TextEditWidget_SetString and _TextWidget_SetString and _TextWidget_ResetRegionSize)

-------------------------------
-- [[ Public Functions ]]
-------------------------------

local function GetStringSize(self, s, font, size)
    --PEARL.debug("GetStringSize")--, self, s, font, size, "FONT", self and self.font, self and self.size)
    --- For empty strings this goes crazy! "1.7014117331926e+038"
    if s == "" then
        return 0, 0
    end

    if not _text_widget then
        _text_widget = Text(font or self.font, size or self.size).inst.TextWidget
    end

    --- All these can have an effect on the region size
    _text_widget:SetFont(font or self.font)
    _text_widget:SetSize(size or self.size)
    _TextWidget_SetString(_text_widget, s)

    local w, h = _text_widget:GetRegionSize()
    _TextWidget_ResetRegionSize(_text_widget)

    return w and w + TEXT_WIDGET_MARGIN_H or 0, h and h + TEXT_WIDGET_MARGIN_V or 0
end

local function AdjustWidget(lua_widget, widget)
    local s = lua_widget:GetString() -- The whole string content of this widget
    local prefix = s:sub(1, widget._first_index - 1)
    local prefix_width = GetStringSize(lua_widget, prefix)
    if prefix_width > 0 then
        prefix_width = prefix_width + 4
    end
    if lua_widget.inst.TextEditWidget then
        prefix_width = prefix_width + 2
    end
    local _, region_h = GetStringSize(lua_widget, s) -- Use the actual region size needed.
    local region_w = lua_widget:GetRegionSize() or 0
    local char_w, char_h = GetStringSize(lua_widget, widget._proxy_str)

    local widget_w, widget_h
    if widget.GetRegionSize then
        widget_w, widget_h = widget:GetRegionSize()
    end

    if widget_w ~= nil and widget_h ~= nil then
        widget:SetScale(char_w / widget_w, char_h / widget_h, 1)
    end

    local scale = widget:GetScale()
    widget:SetPosition(
        prefix_width - region_w / 2 - (TEXT_WIDGET_OFFSET_X * scale.x),
        -region_h / 2 - (TEXT_WIDGET_OFFSET_Y * scale.y)
    )
end

local function AdjustAllInsertedWidgets(lua_widget)
    if lua_widget.inserted_widgets then
        for _, widget in pairs(lua_widget.inserted_widgets) do
            AdjustWidget(lua_widget, widget)
        end
    end
end

local function OnLuaWidgetInstRemoved(inst)
    print("OnLuaWidgetRemoved", inst, inst._proxy_str)
    local lua_widget = inst.widget
    if not lua_widget then
        return
    end

    print("OnLuaWidgetRemoved", lua_widget)
    for _, widget in pairs(lua_widget.inserted_widgets) do
        if widget._proxy_str ~= nil then
            print("REMOVING", widget._proxy_str)
            _emoji_anim_states[widget._proxy_str] = nil
        end
    end
end

--- @param widget Widget
local function RemoveWidget(lua_widget, widget)
    -- PEARL.debug("Text:RemoveWidget", widget)

    lua_widget:RemoveChild(widget)

    if lua_widget.inserted_widgets then
        lua_widget.inserted_widgets[widget._first_index] = nil
    end

    widget._first_index, widget._last_index, widget._proxy_str = nil, nil, nil

    return widget
end

--- @param widget Widget
--- @param first integer?
--- @param last integer?
local function InsertWidgetAtPosition(lua_widget, widget, first, last)
    -- PEARL.debug("Text:InsertWidgetAtPosition", widget, first, last)

    first = first or 1
    last = last or first

    if widget._first_index and widget._last_index then
        RemoveWidget(lua_widget, widget) -- If the widget was already inserted, remove it.
    end
    lua_widget:AddChild(widget)

    local proxy_str = lua_widget:GetString():sub(first, last)
    widget._first_index, widget._last_index, widget._proxy_str = first, last, proxy_str

    lua_widget.inserted_widgets = lua_widget.inserted_widgets or {}
    if lua_widget.inserted_widgets[first] then -- If an widget is already on this position, remove it!
        RemoveWidget(lua_widget, lua_widget.inserted_widgets[first]):Kill()
    end
    lua_widget.inserted_widgets[first] = widget

    lua_widget.inst:ListenForEvent("onremove", OnLuaWidgetInstRemoved)

    AdjustWidget(lua_widget, widget)
end

-------------------------------
-- [[ Local Functions ]]
-------------------------------

local function GetParent(c_widget)
    return _parents[c_widget]
end

local function IsEmojiInsertedAt(lua_widget, emoji_utf8_str, first)
    return lua_widget.inserted_widgets and lua_widget.inserted_widgets[first]
       and lua_widget.inserted_widgets[first]._proxy_str == emoji_utf8_str
end

local function InsertAnimatedEmoji(lua_widget, first, last, emoji_utf8_str)
    -- PEARL.debug("InsertAnimatedEmoji", lua_widget, first, last)

    local emoji_name = m_EMOJIS.UTF_TO_NAME[emoji_utf8_str]
    local emoji_anim = UIAnim()
    local emoji_anim_state = emoji_anim:GetAnimState()
    emoji_anim_state:SetBuild(emoji_name)
    emoji_anim_state:SetBank(emoji_name)
    emoji_anim_state:PlayAnimation("default", true)
    emoji_anim.GetRegionSize = function()
        return ANIMATED_EMOJI_WIDTH, ANIMATED_EMOJI_HEIGHT
    end

    local frame = (_emoji_anim_states[emoji_utf8_str]
        and _emoji_anim_states[emoji_utf8_str]:GetCurrentAnimationFrame()
    )
    if frame ~= nil then
        emoji_anim_state:SetFrame(frame)
    end

    _emoji_anim_states[emoji_utf8_str] = emoji_anim_state
    InsertWidgetAtPosition(lua_widget, emoji_anim, first, last)
    emoji_anim:MoveToBack()
end

---------------------------
-- [[ Event Handlers ]]
---------------------------

local function OnCWidgetUpdated(c_widget)
    local parent = c_widget:GetParent()
    if parent then
        AdjustAllInsertedWidgets(parent)
    end
end

local function OnTextUpdated(lua_widget)
    local first = 1    --- @type integer?
    local last = first --- @type integer?
    local s = lua_widget:GetString() -- The updated string
    while first ~= nil do
        first, last = s:find(m_CONSTANTS.UTF_EMOJI_PATTERN, first)
        if first == nil or last == nil then
            break
        end

        local total_emoji_count = m_EMOJIS.CountEmojisInString(s)
        local emoji_utf8_str = s:sub(first, last)
        if total_emoji_count < MAX_EMOJIS_IN_MESSAGE and m_EMOJIS.IsEmojiAnimated(m_EMOJIS.UTF_TO_NAME[emoji_utf8_str]) and not IsEmojiInsertedAt(lua_widget, emoji_utf8_str, first) then
            InsertAnimatedEmoji(lua_widget, first, last, emoji_utf8_str)
        end

        if last >= first then
            first = last + 1
        else
            first = first + 1  -- Safety increment
        end
    end

    if lua_widget.inserted_widgets then
        for _, widget in pairs(lua_widget.inserted_widgets) do
            if s:sub(widget._first_index, widget._last_index) ~= widget._proxy_str then
                RemoveWidget(lua_widget, widget)
                widget:Kill()
                widget:Hide()
            end
        end
    end
end

local function OnSetString(c_widget, s)
    local lua_widget = c_widget:GetParent()
    if not lua_widget or s == lua_widget.last_str then
        return
    end

    lua_widget.last_str = s
    if type(s) ~= "string" then
        return
    end

    OnTextUpdated(lua_widget)
end

local function OnSetColour(c_widget, r, g, b, a)
    local parent = c_widget:GetParent()
    if parent and parent.inserted_widgets then
        for _, widget in pairs(parent.inserted_widgets) do
            if widget.inst and widget.inst.AnimState then
                widget.inst.AnimState:SetMultColour(1, 1, 1, a)
            end
        end
    end
end

local function OnKeyDown(c_widget, key)
    if key == KEY_BACKSPACE or key == KEY_DELETE then
        local parent = c_widget:GetParent()
        if parent then
            OnTextUpdated(parent)
        end
    end
end

local function OnTextInput(c_widget, char)
    local parent = c_widget:GetParent()
    if parent then
        OnSetString(c_widget, parent:GetString())
    end
end

local function OnTextPostConstruct(lua_widget)
    --- Make sure the C-side TextWidget has reference to our Lua object.
    if lua_widget.inst.TextWidget then
        _parents[lua_widget.inst.TextWidget] = lua_widget
    end
    if lua_widget.inst.TextEditWidget then
        _parents[lua_widget.inst.TextEditWidget] = lua_widget
    end

    local _SetFont = lua_widget.SetFont
    lua_widget.SetFont = function(self, font, ...)
        local old = self.font
        _SetFont(self, font, ...)
        if old ~= font then
            AdjustAllInsertedWidgets(lua_widget)
        end
    end

    local _SetSize = lua_widget.SetSize
    lua_widget.SetSize = function(self, size, ...)
        local old = self.size
        _SetSize(self, size, ...)
        if old ~= size then
            AdjustAllInsertedWidgets(lua_widget)
        end
    end

    OnTextUpdated(lua_widget)
end

---------------------------
-- [[ Post-Callbacks ]]
---------------------------

if m_EMOJIS.IsAnyAnimatedEmojiPackEnabled() then
    TextWidget.GetParent, TextEditWidget.GetParent = GetParent, GetParent

    AddClassFunctionPostCall("SetString", OnSetString, TextWidget)
    AddClassFunctionPostCall("SetColour", OnSetColour, TextWidget)
    AddClassFunctionPostCall("SetVAnchor", OnCWidgetUpdated, TextWidget)
    AddClassFunctionPostCall("SetHAnchor", OnCWidgetUpdated, TextWidget)
    AddClassFunctionPostCall("SetRegionSize", OnCWidgetUpdated, TextWidget)
    AddClassFunctionPostCall("ResetRegionSize", OnCWidgetUpdated, TextWidget)

    AddClassFunctionPostCall("SetString", OnSetString, TextEditWidget)
    AddClassFunctionPostCall("OnKeyDown", OnKeyDown, TextEditWidget)
    AddClassFunctionPostCall("OnTextInput", OnTextInput, TextEditWidget)

    AddClassPostConstruct("widgets/text", OnTextPostConstruct)
    AddClassPostConstruct("widgets/textedit", OnTextPostConstruct)
end
