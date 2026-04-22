
local CONSTANTS = {
    UTF_EMOJI_PATTERN = "[\243\238\239][\128-\191][\128-\191][\128-\191]?",
    EMOJI_DELIM       = ":",

    EMOJI_CHAR_SIZE   = 2, -- How many characters wide is one emoji.

    STRINGS = {
        FAVORITES = "Favorites",
        FREQUENTLY_USED = "Frequently Used",
        VANILLA = "Standard",
        DISCORD = "Discord",

        UI = {
            EMOJI_MENU = {
                NO_EMOJIS_FOUND = "No emojis match your search", -- from discord

                FAVORITE_BUTTON_HOVER = "Favourite",
                UNFAVORITE_BUTTON_HOVER = "Unfavourite",

                OPEN_BUTTON_HOVER = "View Emojis\n(%s)",
                CLEAR_BUTTON_HOVER = "Clear\n(%s)",

                SEARCH = "Search",
                NEW = "New!",
            },
        }
    }
}

CONSTANTS.EMOJI_PATTERN = CONSTANTS.EMOJI_DELIM.."([%S]+)"..CONSTANTS.EMOJI_DELIM

return CONSTANTS
