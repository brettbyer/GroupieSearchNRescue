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
	print(map("mapWidth"))
	local boxes = map.layer["boxes"].object

	for x=1, #map.layer["boxes"].object do
		local tempBox = boxes[x]
		temperX = tempBox.x
		temperY = tempBox.y
		print(temperX .. " " .. temperY)
		tempBox.gridX = math.ceil(temperX/map("tileWidth"))
		tempBox.gridY = math.ceil(temperY/map("tileWidth"))
		tempBox.found = false
	end

	print(#map.layer["boxes"].object)
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
	local boxFound = false;
	function player.toNextNode()
		if player.path[player.nodeIndex] then
			if player.nodeTrans then transition.cancel(player.nodeTrans) end

			local objectNear, boxX, boxY, objX, objY=isObjectNear(player.path[player.nodeIndex][1],player.path[player.nodeIndex][2])
			print(objectNear)
			print(" " .. boxX .. " " .. boxY)

			if objectNear and not boxFound then
				boxFound = true;
				currX =math.ceil(player.x/map("tileWidth"))
				currY =math.ceil(player.y/map("tileHeight"))
				print( currX .. " " .. currY )
				player.movementAllowed=true

				for i=1, #player.pathDisplay do
					display.remove(player.pathDisplay[i])
					player.pathDisplay[i]=nil
				end
				local path=pathfinder:getPath(currX, currY, boxX, boxY)
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
				end

				--player.x = 
				player.nodeIndex=2 
				--local tempEvent = {x = (boxX-0.5)*map("tileWidth"), y = (boxY-0.5)*map("tileHeight")}
				--player:dispatchEvent(tempEvent)
			end
			print(player.nodeIndex)
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
			boxFound = false
			--print(player.movementAllowed)
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

	------------------------------------------------------------------------------
	-- Check 8 adjacent locations for boxes
	------------------------------------------------------------------------------
	function isObjectNear(tileX, tileY)
		local disX, distY, tempBox
		for index=1, #boxes do
			tempBox = boxes[index]
			
			distX = math.abs(tileX - tempBox.gridX)
			distY = math.abs(tileY - tempBox.gridY)

			if (math.sqrt(math.pow(distX,2)+math.pow(distY,2)) <= math.sqrt(2)) then
				if not tempBox.found then
					tempBox.found = true;
					return true, tempBox.gridX, tempBox.gridY, tempBox.x, tempBox.y
				end
			end
		end

		return false, -1, -1, -1, -1
	end


	function removeBox( tileX, tileY )
		local tempBox
		for index=1, #boxes do
			tempBox = boxes[index]
			if (tileX == tempBox.gridX) and (tileY == tempBox.gridY) then
				table.remove( boxes, index )
			end
		end
	end
	------------------------------------------------------------------------------
	-- Move Player
	------------------------------------------------------------------------------
	local function movePlayer(event)
		if "began"==event.phase and player.movementAllowed then
			for i=1, #player.pathDisplay do
				display.remove(player.pathDisplay[i])
				player.pathDisplay[i]=nil
			end

			player.updateGridPos() -- Reset player grid position

			local pointBlocked, tileX, tileY=checkForTile(event.x, event.y)

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
	
	local function movePlayerToBox(boxX, boxY)
		if player.movementAllowed then
			for i=1, #player.pathDisplay do
				display.remove(player.pathDisplay[i])
				player.pathDisplay[i]=nil
			end

			player.updateGridPos() -- Reset player grid position

			local pointBlocked, tileX, tileY=checkForTile(event.x, event.y)

			if not pointBlocked then
				local path=pathfinder:getPath(player.gridX, player.gridY, boxX, boxY)
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

	Runtime:addEventListener("touch", movePlayer)
	Runtime:addEventListener("tempEvent", movePlayer)
	box1 = map.layer["boxes"].object["box1"]
	print(box1.weight)
	print(box1.y)

end