--------------------------------------------------------------------------------
--[[
	GroupieSearchNRescue startup
--]]
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Miscellaneous Loading
--------------------------------------------------------------------------------
display.setStatusBar(display.HiddenStatusBar)
display.setDefault("minTextureFilter", "nearest")
display.setDefault("magTextureFilter", "nearest")

local cleanUp
local widget=require("widget")
local pathfinding=require("src.groupie_search")

pathfinding()
