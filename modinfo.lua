---@diagnostic disable: lowercase-global

name = "Emojified"
description = "Emojify your game with your well known emojis!"
author = "Filip"
version = "1"

dst_compatible = true
all_clients_require_mod = true

-- Lowest possible priority so we override all the other emoji mods.
priority = -1.7976931348623e+308 -- std::numeric_limits<lua_Number>::max()

api_version = 10

configuration_options = {
    {
        name="CUSTOM_EMOJI_PACKS",
        default = {
            ["discord_emojis"] = true,
            ["discord_emojis_animated"] = true,
        },
    },

    {
        name="EMOJI_MENU",
        default = true,
    },
}
