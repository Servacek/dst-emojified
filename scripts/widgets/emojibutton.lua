
local Button = require("widgets/button")
local Image = require("widgets/image")
local Text = require("widgets/text")

------------------------------------

local m_CONSTANTS = modrequire("constants")

------------------------------------

local SPACING = 7
return function(size, dynamic_bg, bg_margin)
    local btn = Button()

    btn.bg = btn:AddChild(Image("images/global.xml", "square.tex"))
    btn.bg:ScaleToSize(size + (bg_margin or SPACING), size + (bg_margin or SPACING))
    btn.bg:SetTint(0, 0, 0, 0)
    btn.bg:MoveToBack()

    btn.locked_overlay = btn:AddChild(Image("images/global.xml", "square.tex"))
    btn.locked_overlay:ScaleToSize(size, size)
    btn.locked_overlay:SetTint(0, 0, 0, .6)
    btn.locked_overlay:MoveToFront()
    btn.locked_overlay:Hide()

    local crafting_menu_atlas = resolvefilepath(CRAFTING_ATLAS)
    btn.locked_overlay.lock_icon = btn.locked_overlay:AddChild(Image(crafting_menu_atlas, "pinslot_fg_lock.tex"))
    btn.locked_overlay.lock_icon:SetScale(.7)

    btn.new_tag_image = btn:AddChild(Image("images/global_redux.xml", "motd_sale_tag.tex"))
    btn.new_tag_image:SetScale(.2)
    btn.new_tag_image:SetRotation(-90)
    btn.new_tag_image:SetPosition(-7, 7)

    btn.new_tag_image.text = btn.new_tag_image:AddChild(Text(HEADERFONT, 52, m_CONSTANTS.STRINGS.UI.EMOJI_MENU.NEW, UICOLOURS.BLACK))
    btn.new_tag_image.text:SetPosition(20, 20)
    btn.new_tag_image.text:SetRotation(45)
    btn.new_tag_image:Hide()

    btn.text:SetHAlign(ANCHOR_MIDDLE)
    btn.text:SetVAlign(ANCHOR_MIDDLE)

    if dynamic_bg then
        AddClassFunctionPostCall("SetTextSize",
        AddClassFunctionPostCall("SetText", function()
            local w, h = btn.text:GetRegionSize()
            btn.bg:ScaleToSize(w + (bg_margin or SPACING), h + (bg_margin or SPACING))
        end, btn), btn)
    end

    btn:SetTextSize(size)
    btn:SetControl(CONTROL_PRIMARY)

    -- btn.ongainfocus = function()
    --     if scale_on_focus == true then
    --         btn:SetTextSize(size + 7)
    --     end
    -- end

    -- btn.onlosefocus = function()
    --     if scale_on_focus == true then
    --         btn:SetTextSize(size)
    --     end
    -- end

    -------------
    -- Public functions
    btn.SetOnLoseFocus = function(self, fn)
        btn.onlosefocus = btn.onlosefocus or function() end
        AddClassFunctionPostCall("onlosefocus", fn, btn)
    end
    btn.SetOnGainFocus = function(self, fn)
        btn.ongainfocus = btn.ongainfocus or function() end
        AddClassFunctionPostCall("ongainfocus", fn, btn)
    end

    btn.ShowHover = function(self)
        return btn.hovertext_root and (btn.hovertext_root._Show or btn.hovertext_root.Show)(btn.hovertext_root)
    end

    btn.HideHover = function(self)
        return btn.hovertext_root and (btn.hovertext_root._Hide or btn.hovertext_root.Hide)(btn.hovertext_root)
    end

    btn.Lock = function(self)
        btn:Disable()
        btn.locked_overlay:Show()
    end

    btn.Unlock = function(self)
        btn.locked_overlay:Hide()
        btn:Enable()
    end

    btn.AddHoverText = function()
        if btn.hovertext_root then
            return
        end

        btn:SetHoverText(" ", {offset_y = 45})
    end

    AddClassFunctionPostCall("OnHide", function()
        btn:HideHover()
    end, btn)

    -------------------------

    return btn
end
