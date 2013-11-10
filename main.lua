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

require("src.maze_pathfinding")

timer.performWithDelay( 1000, movePlayer, 5 )