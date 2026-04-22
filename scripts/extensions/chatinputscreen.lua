
--- @class ChatInputScreen
local ChatInputScreen = require("screens/chatinputscreen")

require("frontend")

local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")

------------------------------------

local m_EMOJIS = modrequire("emojis")
local m_CONSTANTS = modrequire("constants")

--- @type EmojiMenu
local m_EmojiMenu = modrequire("widgets/emojimenu")

local m_ClientEmojiManager = modrequire("clientemojimanager")

local EmojiButton = modrequire("widgets/emojibutton")

---------------------------
-- [[ Constants ]]
---------------------------

local EMOJI_MENU_BUTTON_SIZE = 30
local EMOJI_MENU_BUTTON_SCALE = {x = 1, y = 1, z = 1}
local EMOJI_MENU_BUTTON_FOCUS_SCALE = {x = 1.3, y = 1.3, z = 1.3}
local EMOJI_MENU_BUTTON_OFFSET_X = 0
local EMOJI_MENU_BUTTON_OFFSET_Y = 60
local EMOJI_MENU_BUTTON_ALIGN_RIGHT = true

local CONTROL_MODIFIER = "Ctrl"

---------------------------
-- [[ Local Variables ]]
---------------------------

local _OnRawKey, _OnControl

---------------------------
-- [[ Handler Extensions ]]
---------------------------

local function ExtendedOnRawKey(self, key, down, ...)
    local active_screen = self:GetActiveScreen()
    if active_screen and ChatInputScreen.is_instance(active_screen) and active_screen.emoji_menu then
        if TheInput:IsKeyDown(KEY_CTRL) then
            if not down and key == KEY_Y and active_screen.emoji_menu_button then
                active_screen.emoji_menu_button.onclick()
            else
                return active_screen.emoji_menu:OnRawKey(key, down, ...)
            end

            return true
        end
    end

    return _OnRawKey(self, key, down, ...)
end

local function ExtendedOnControl(self, control, down, ...)
    local active_screen = self:GetActiveScreen()
    if active_screen and ChatInputScreen.is_instance(active_screen) then
        active_screen.emoji_menu:OnControl(control, down, ...)
    end

    return _OnControl(self, control, down, ...)
end

---------------------------
-- [[ Local Functions ]]
---------------------------

local function GetSayControl()
    local control = CONTROL_TOGGLE_SAY
    local controllerid = TheInput:GetControllerID()
    local controltocheck = TheInput:ControllerAttached() and LOADING_SCREEN_CONTROLLER_ID_LOOKUP[control] or control
    return TheInput:GetLocalizedControl(controllerid, controltocheck)
end

local followhandler = TheInput:AddMoveHandler(function(x, y) end)
local function AddEmojiMenuButton(menu)
    -- Let's handle the scaling ourselves.
    -- Make the background bigger so it can be clicked on easier.
    local bg_margin = 20
    local btn = EmojiButton(EMOJI_MENU_BUTTON_SIZE, true, bg_margin)
    btn.bg:SetTexture(m_EmojiMenu.ATLAS, "emoji_background.tex")
    btn.bg:SetTint(1, 1, 1, 1)
    btn:SetText(m_EMOJIS.GAME.WAVE)
    btn._hasnew_img = btn:AddChild(Image("images/ui.xml", "new_label_motd2.tex"))
    btn._hasnew_img:SetScale(.3)
    local w, h = btn.bg:GetSize()
    btn._hasnew_img:SetPosition(w / 4, h / 3)
    btn._hasnew_img:Hide()
    btn.glow = btn:AddChild(Image("images/global_redux.xml", "shop_glow.tex"))
    btn.glow:RotateTo( 0, 0.8, 0.3, nil, true )
    btn.glow:Hide()
    btn.glow:SetScale(.75)
    btn.glow:MoveToBack()
    if m_ClientEmojiManager:HasAnyNewEmojis() then
        btn._hasnew_img:Show()
        btn.glow:Show()
    end

    local tx, ty = btn.text:GetPositionXYZ()
    btn.text:SetPosition(tx, ty + 8)
    btn._hovertext = menu.parent:AddChild(Text(UIFONT, 30))
    btn._hovertext:SetString(m_CONSTANTS.STRINGS.UI.EMOJI_MENU.OPEN_BUTTON_HOVER:format(
        CONTROL_MODIFIER.." + "..GetSayControl()
    ))
    btn._hovertext:SetScaleMode(SCALEMODE_PROPORTIONAL)
    btn._hovertext:Hide()

    btn._hovertext._UpdatePosition = function(self, x, y)
        if not x or y then
            local pos = TheInput:GetScreenPosition()
            x, y = pos.x, pos.y
        end

        self:SetPosition(
            x + EMOJI_MENU_BUTTON_OFFSET_X, y + EMOJI_MENU_BUTTON_OFFSET_Y, 0
        )
    end
    btn._hovertext:_UpdatePosition()

    followhandler.fn = function(x, y)
        if btn._hovertext.inst.widget ~= nil then
            btn._hovertext:_UpdatePosition(x, y)
        end
    end

    btn.ScaleUp = function() btn:SetScale(EMOJI_MENU_BUTTON_FOCUS_SCALE) end
    btn.ScaleDown = function() btn:SetScale(EMOJI_MENU_BUTTON_SCALE) end
    btn.ScaleDown()

    btn:SetOnGainFocus(function()
        btn:ScaleUp()

        if not menu:IsOpen() then
            btn._hovertext:Show()
        end
    end)
    btn:SetOnLoseFocus(function()
        if not menu:IsOpen() and not menu.closing then
            btn:ScaleDown()
        end

        btn._hovertext:Hide()
    end)
    btn:SetOnClick(function()
        menu:Toggle()

        local pos_x, pos_y = btn:GetPositionXYZ()
        local _, h = (menu.menu.mid_center or menu.menu.bg or menu.menu):GetSize()
        menu:SetPosition(pos_x - 10, pos_y + h / 2 + EMOJI_MENU_BUTTON_SIZE * 4)
    end)

    if FrontEnd.OnRawKey ~= ExtendedOnRawKey then
        _OnRawKey = FrontEnd.OnRawKey or function() return false end
        FrontEnd.OnRawKey = ExtendedOnRawKey
    end

    if FrontEnd.OnControl ~= ExtendedOnControl then
        _OnControl = FrontEnd.OnControl
        FrontEnd.OnControl = ExtendedOnControl
    end

    return btn
end

local function AddEmojiMenu(self)
    local _bg = self.chat_edit:AddChild(ImageButton("images/global.xml", "square.tex"))
    _bg.image:SetVRegPoint(ANCHOR_MIDDLE)
    _bg.image:SetHRegPoint(ANCHOR_MIDDLE)
    _bg.image:SetVAnchor(ANCHOR_MIDDLE)
    _bg.image:SetHAnchor(ANCHOR_MIDDLE)
    _bg.image:SetScaleMode(SCALEMODE_FILLSCREEN)
    _bg.image:SetTint(0,0,0,0)
    _bg:SetHelpTextMessage("")
    _bg:MoveToFront()
    _bg:Select() -- So no hover sound
    _bg.AllowOnControlWhenSelected = true
    _bg:Hide()

    self.emoji_menu = self.screen_root:AddChild(m_EmojiMenu(m_EmojiMenu.STYLES.HUD))
    self.emoji_menu:LoadEmojiCategories(m_ClientEmojiManager.CATEGORIES_ORDERED)
    self.emoji_menu:MoveToFront()

    _bg:SetOnClick(function()
        if self.emoji_menu:IsOpen() then
            self.emoji_menu:Close()
        end
    end)

    _bg.focus_forward = function()
        if self.emoji_menu:IsOpen() then
            return self.emoji_menu
        end
    end

    self.emoji_menu_button = self.chat_edit:AddChild(AddEmojiMenuButton(self.emoji_menu))
    local x = 0
    if EMOJI_MENU_BUTTON_ALIGN_RIGHT then
        local padding_x = 100
        local edit_x, edit_y = self.chat_edit:GetPositionXYZ()
        local w, h = self.chat_edit:GetRegionSize()
        self.chat_edit:SetPosition(edit_x - padding_x / 2, edit_y)
        w = w - padding_x
        self.chat_edit:SetRegionSize(w, h)
        x = (w / 2) + 50
    else
        x = -465
        if self.chat_type then
            x = x - self.chat_type:GetString():len() * self.chat_type:GetSize() / 3.5
        end
    end
    self.emoji_menu_button:SetPosition(x, 0)
    self.emoji_menu_button:MoveToFront()

    local insert_index = 1
    self.emoji_menu.onopen = function()
        self.chat_edit:SetEditing(false)
        self.chat_edit:ClearFocus()

        if self.emoji_menu_button.hovertext_root then
            self.emoji_menu_button.hovertext_root:Hide()
        end

        insert_index = self.chat_edit.inst.TextEditWidget:GetEditCursorPos() or 1
        _bg:Show()

        if not self.emoji_menu_button.focus then
            self.emoji_menu_button:OnGainFocus()
        end
    end

    self.emoji_menu.onrefresh = function()
        if not m_ClientEmojiManager:HasAnyNewEmojis() then
            self.emoji_menu_button._hasnew_img:Hide()
            self.emoji_menu_button.glow:Hide()
        end
    end

    self.emoji_menu.onclosing = function()
        self.chat_edit:SetEditing(true)
        self.chat_edit.inst.TextEditWidget:SetEditCursorPos(insert_index)

        _bg:Hide()
        _bg:SetFocus()
    end

    self.emoji_menu.onclose = function()
        if not m_ClientEmojiManager:HasAnyNewEmojis() then
            self.emoji_menu_button._hasnew_img:Hide()
            self.emoji_menu_button.glow:Hide()
        end

        -- The button is in it's focused state until the menu is closed.
        if not self.emoji_menu_button.focus then
            self.emoji_menu_button:OnLoseFocus()
        end
    end

    self.emoji_menu.onemojichosen = function(emoji_id)
        local emoji_data = m_EMOJIS.DATA[emoji_id]
        local str = self.chat_edit:GetString()
        local add_str = emoji_data.utf8_str.." "
        local new_str = str:sub(1, insert_index)..add_str..str:sub(insert_index + 1)

        -- Only append if the
        if new_str:utf8len() < (self.chat_edit.limit or MAX_CHAT_INPUT_LENGTH) then
            self.chat_edit:SetString(new_str)
            insert_index = insert_index + add_str:len()
        end
    end

    AddClassFunctionPreCall("ValidateChar", function()
        return not TheInput:IsKeyDown(KEY_CTRL)
    end, self.chat_edit)
end

---------------------------
-- [[ Overrides ]]
---------------------------

AddClassPostConstruct("screens/chatinputscreen", function(self, whisper)
    if m_ClientEmojiManager:HasAnyAvailableEmojis() then
        -- if PEARL.CONFIG.DEBUG_MODE then
        --     PEARL.loadfile("extensions/ui/templates", nil, true)

        --     -- Hot reload for faster testing
        --     m_EmojiMenu = PEARL.loadfile("widgets/emojimenu", nil, true)

        --     -- -- For debugging the animated emoji aligment
        --     -- -- Swap testing emojis and their names, so animations are opposite colour.
        --     -- PEARL.EMOJIS.UTF_TO_NAME[PEARL.EMOJIS.DISCORD["whitesquare"]] = "blacksquare"
        --     -- PEARL.EMOJIS.UTF_TO_NAME[PEARL.EMOJIS.DISCORD["blacksquare"]] = "whitesquare"

        --     -- local debug_text = self.chat_edit:AddChild(Text(UIFONT, 60))
        --     -- debug_text:SetString(PEARL.EMOJIS.DISCORD.whitesquare.." "..PEARL.EMOJIS.DISCORD.whitesquare..""..PEARL.EMOJIS.DISCORD.whitesquare)

        --     -- local infront = false
        --     -- PEARL.AddClassFunctionPreCall("OnRawKey", function(self, key, down)
        --     --     if not down then
        --     --         return
        --     --     end

        --     --     if key == KEY_DOWN then
        --     --         debug_text:SetSize(debug_text:GetSize() - 1)
        --     --         return false
        --     --     elseif key == KEY_UP then
        --     --         debug_text:SetSize(debug_text:GetSize() + 1)
        --     --         return false
        --     --     end

        --     --     local anim = next(debug_text.children)
        --     --     if not anim then
        --     --         return
        --     --     end

        --     --     if key == KEY_F2 then
        --     --         if not infront then
        --     --             anim:MoveToFront()
        --     --         else
        --     --             anim:MoveToBack()
        --     --         end

        --     --         infront = not infront
        --     --         return false
        --     --     end

        --     --     local x, y = anim:GetPositionXYZ()
        --     --     if key == KEY_LEFT then
        --     --         anim:SetPosition(x + 1, y)
        --     --         print("NEW POSITION", anim:GetPositionXYZ())
        --     --     elseif key == KEY_RIGHT then
        --     --         anim:SetPosition(x - 1, y)
        --     --         print("NEW POSITION", anim:GetPositionXYZ())
        --     --     end
        --     -- end, TheFrontEnd)
        -- end

        AddEmojiMenu(self)
    end
end)
