---@diagnostic disable: lowercase-global

name = "Animated Emojis"
description = "Emojify your game with your well known emojis... even those animated!"
author = "Fi8iP"
version = "1.20"

dst_compatible = true
-- client_only_mod = true
-- ! For server-side version of the mod uncomment this:
all_clients_require_mod = true

-- Lowest possible priority so we override all the other emoji mods.
priority = -1.7976931348623e+308 -- std::numeric_limits<lua_Number>::max()

api_version = 10

icon_atlas = "images/mod_icon.xml"
icon = "mod_icon.tex"

configuration_options = {
	{
		name = "DISCORD_EMOJIS",
		label = "Discord Emojis (Static)",
		hover = "Enable or disable static Discord emoji pack.",
		options = {
			{
				description = "Disabled",
				data = false
			},
			{
				description = "Enabled",
				data = true
			}
		},
		default = true
	},

	{
		name = "DISCORD_EMOJIS_ANIMATED",
		label = "Discord Emojis (Animated)",
		hover = "Enable or disable animated Discord emoji pack.",
		options = {
			{
				description = "Disabled",
				data = false
			},
			{
				description = "Enabled",
				data = true
			}
		},
		default = true
	},

	{
		name = "EMOJI_MENU",
		label = "Emoji Menu",
		hover = "Enable or disable the emoji picker menu in the chat. Disabling keeps emoji autocomplete working.",
		options = {
			{
				description = "Disabled",
				data = false
			},
			{
				description = "Enabled",
				data = true
			}
		},
		default = true
	},
}
