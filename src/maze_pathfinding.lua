--[[
GroupieSearchNRescue

Demonstrates:
	- Generating a pathfinding map
	- Using pathfinding in tandem with Ceramic

Note:
	The Jumper pathfinding module was sourced from github.com/yonaba/jumper.

--]]

return function()
	------------------------------------------------------------------------------
	-- Load Miscellaneous
	------------------------------------------------------------------------------
	require("physics")
	physics.start()
	physics.setScale(140)
	physics.setDrawMode("hybrid")

	local ceramic=require("Ceramic")
	local map=ceramic.buildMap("maps/test.json", true) -- Notice the true; this tells Ceramic to load map using basic mode
	
	local jumper_grid=require("jumper.grid")
	local other_grid=require("jumper.grid")
	local jumper_pathfinder=require("jumper.pathfinder")

	local mapGrid={}

	local str=""

	------------------------------------------------------------------------------
	-- Generate Map Grid
	------------------------------------------------------------------------------
	for y=1, map("mapHeight") do
		mapGrid[y]={}
		str=str.."\n"
		for x=1, map("mapWidth") do
			if map.layer["obstacles"].tile(x, y) then
				mapGrid[y][x]=10
				str=str.."##"
			else
				mapGrid[y][x]=0
				str=str.."  "
			end
		end
	end

	local boxGrid = {}

	for y=1, map("mapHeight") do
		boxGrid[y]={}
		str=str.."\n"
		for x=1, map("mapWidth") do
			if map.layer["boxes2"].tile(x, y) then
				boxGrid[y][x]=10
				str=str.."##"
			else
				boxGrid[y][x]=0
				str=str.."  "
			end
		end
	end

	local boxGrid1 = other_grid(boxGrid)

	print("\nRepresentation of generated pathfinding map: "..str)

	local grid=jumper_grid(mapGrid)
	-- create a pathfinder using A* with grid based on Tiled json
	local pathfinder=jumper_pathfinder(grid, "ASTAR", 0)

	------------------------------------------------------------------------------
	-- Create Player
	------------------------------------------------------------------------------
	local playerXY=map.layer["obstacles"].playerSpawn

	local player=display.newImageRect("assets/player.png", 32, 32)
	player.x=(playerXY[1]-0.5)*map("tileWidth")
	player.y=(playerXY[2]-0.5)*map("tileHeight")

	player.gridX=math.ceil((player.x)/map("tileWidth")) -- Position in tiles
	player.gridY=math.ceil((player.y)/map("tileHeight"))
	
	player.movementAllowed=true -- Allow touches to trigger movement or not
	player.path={} -- Path calculated by Jumper
	player.pathDisplay={} -- Display objects to mark travelled path
	player.nodeIndex=2 -- Current node

	function player.updateGridPos()
		player.gridX, player.gridY=math.ceil((player.x)/map("tileWidth")), math.ceil((player.y)/map("tileHeight"))
	end

	------------------------------------------------------------------------------
	-- Move Player to Next Node
	------------------------------------------------------------------------------
	function player.toNextNode()
		if player.path[player.nodeIndex] then
			if player.nodeTrans then transition.cancel(player.nodeTrans) end

			player.nodeTrans=transition.to(player, {
				x=(player.path[player.nodeIndex][1]-0.5)*map("tileWidth"),
				y=(player.path[player.nodeIndex][2]-0.5)*map("tileHeight"),
				time=25,
				onComplete=function()
					transition.to(player.pathDisplay[player.nodeIndex-1], {xScale=0.5, yScale=0.5, time=100})
					player.pathDisplay[player.nodeIndex-1]:setFillColor(255, 255, 0)
					player.toNextNode()
				end
			})

			player.nodeIndex=player.nodeIndex+1
		else
			player.nodeIndex=2
			player.movementAllowed=true
			print(player.movementAllowed)
		end
	end

	map.layer["obstacles"]:insert(player)

	------------------------------------------------------------------------------
	-- Check for Existence of Tile at Location
	------------------------------------------------------------------------------
	local function checkForTile(x, y)
		x=math.ceil(x/map("tileWidth"))
		y=math.ceil(y/map("tileHeight"))
		
		return map.layer["obstacles"].tile(x, y)~=nil, x, y
	end

	local function checkForBox( x, y )
		x=math.ceil(x/map("tileWidth"))
		y=math.ceil(y/map("tileHeight"))

		return map.layer["boxes2"].tile(x,y)~=nil, x, y
	end

	local function checkSurrounding(x,y)
		if x <= map("mapWidth") then
		end	
	end
	------------------------------------------------------------------------------
	-- Move Player
	------------------------------------------------------------------------------
	local function movePlayer(event, boxX, boxY )
		if "began"==event.phase and player.movementAllowed then
			for i=1, #player.pathDisplay do
				display.remove(player.pathDisplay[i])
				player.pathDisplay[i]=nil
			end

			player.updateGridPos() -- Reset player grid position

			local pointBlocked, tileX, tileY=checkForTile(event.x or boxX, event.y or boxY)

			if not pointBlocked then
				local path=pathfinder:getPath(player.gridX, player.gridY, tileX, tileY)
				if path then -- With this map, there will always be a path, but I just put this check in for safety with other maps.
					local length=path:getLength()
					player.path={}
					for node, count in path:nodes() do
						table.insert(player.path, {node:getX(), node:getY()})

						local obj=display.newCircle(0, 0, 10)
						obj.x, obj.y=(node:getX()-0.5)*map("tileWidth"), (node:getY()-0.5)*map("tileHeight")
						table.insert(player.pathDisplay, obj)

						if count==1 then
							obj:setFillColor(255, 255, 0)
						else
							obj:setFillColor(255, 0, 0)
						end
					end

					player.movementAllowed=false
					player.toNextNode() -- Initiate movement
				end
			end
		end
	end
	
	local function doThis( event )
    	print( "Test 2" )
	end

	local function doThisToo( event )
		print( "Test 3" )
	end

	print( "Test 1 " )
	timer.performWithDelay( 1000, doThis, 1 )

	Runtime:addEventListener("touch", movePlayer)
	box1 = map.layer["boxes"].object["box1"]
	print(box1.weight)
	print(box1.y)

end