---@diagnostic disable: lowercase-global

name = "Animated Emojis"
description = "Emojify your game with your well known emojis... even those animated!"
author = "Fi8iP"
version = "1.1"

dst_compatible = true
client_only_mod = true
-- ! For server-side version of the mod uncomment this:
-- all_clients_require_mod = true

-- Lowest possible priority so we override all the other emoji mods.
priority = -1.7976931348623e+308 -- std::numeric_limits<lua_Number>::max()

api_version = 10

icon_atlas = "images/mod_icon.xml"
icon = "mod_icon.tex"

configuration_options = {
    -- TODO: Add configuration options.
    -- {
    --     name="CUSTOM_EMOJI_PACKS",
    --     default = {
    --         ["discord_emojis"] = true,
    --         ["discord_emojis_animated"] = true,
    --     },
    -- },

    -- {
    --     name="EMOJI_MENU",
    --     default = true,
    -- },
}
