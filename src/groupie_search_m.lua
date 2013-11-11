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
	--print(map("mapWidth"))
	local boxes = map.layer["boxes"].object

	for x=1, #map.layer["boxes"].object do
		local tempBox = boxes[x]
		temperX = tempBox.x
		temperY = tempBox.y
		--print(temperX .. " " .. temperY)
		tempBox.gridX = math.ceil(temperX/map("tileWidth"))
		tempBox.gridY = math.ceil(temperY/map("tileWidth"))
		tempBox.found = false
	end

	--print(#map.layer["boxes"].object)
	print("\nRepresentation of generated pathfinding map: "..str)

	local grid=jumper_grid(mapGrid)
	-- create a pathfinder using A* with grid based on Tiled json
	local pathfinder=jumper_pathfinder(grid, "ASTAR", 0)

	local players = {}
	------------------------------------------------------------------------------
	-- Create Player
	------------------------------------------------------------------------------
	function createPlayer()
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

		player.helping = false
		player.searching = true
		player.goingHome = false
		player.rescueing = false
		player.hasNextLoc = false
		player.nextLoc = {}
		player.index = 0
		player.waiting = false

		map.layer["obstacles"]:insert(player)

		return player
	end

	-- add player to player list
	players[1] = createPlayer()
	players[2] = createPlayer()
	players[3] = createPlayer()


	------------------------------------------------------------------------------
	-- Converts a player's pixel location to tile location on the grid
	------------------------------------------------------------------------------
	function updateGridPos(player)
		player.gridX, player.gridY=math.ceil((player.x)/map("tileWidth")), math.ceil((player.y)/map("tileHeight"))
	end

	------------------------------------------------------------------------------
	-- Create a new path for specified player
	------------------------------------------------------------------------------
	function setPath( player, x, y )
		-- convert current pixel position to tile position
		currX =math.ceil(player.x/map("tileWidth"))
		currY =math.ceil(player.y/map("tileHeight"))
		-- remove old path graphics
		for i=1, #player.pathDisplay do
			display.remove(player.pathDisplay[i])
			player.pathDisplay[i]=nil
		end
		-- populate new path and build graphics
		local path=pathfinder:getPath(currX, currY, x, y)
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
		player.nodeIndex=2 
	end

	------------------------------------------------------------------------------
	-- Move Player to Next Node
	------------------------------------------------------------------------------
	
	function toNextNode(player)
		local objectNear, boxX, boxY
		if player.path[player.nodeIndex] then
			if player.nodeTrans then transition.cancel(player.nodeTrans) end
			if not player.goingHome and player.searching then
				objectNear, boxX, boxY, player.index=isObjectNear(player.path[player.nodeIndex][1],player.path[player.nodeIndex][2])
				--print(player.goingHome)
				--print("this index " .. player.index)
			end

			updateGridPos(player)
			if objectNear and not player.goingHome then
				player.movementAllowed=true
				player.goingHome = true
				player.searching = false
				setPath(player, boxX, boxY)
				boxes[player.index].weight = (boxes[player.index].weight - 1)
				--print(boxes[player.index].weight)
			end



			--print(player.goingHome)

			player.nodeTrans=transition.to(player, {
				x=(player.path[player.nodeIndex][1]-0.5)*map("tileWidth"),
				y=(player.path[player.nodeIndex][2]-0.5)*map("tileHeight"),
				time=25,
				onComplete=function()
					transition.to(player.pathDisplay[player.nodeIndex-1], {xScale=0.5, yScale=0.5, time=25})
					player.pathDisplay[player.nodeIndex-1]:setFillColor(255, 255, 0)
					toNextNode(player)
				end
			})
			
			player.nodeIndex=player.nodeIndex+1

		else
			player.nodeIndex=2
			player.movementAllowed=true
			updateGridPos(player)


			local home = map.layer["obstacles"].home
			if (math.ceil(player.x/map("tileWidth")) == home[1]) and (math.ceil(player.y/map("tileHeight"))== home[2]) then
				player.goingHome = false
				player.searching = true
				newFoundBox = nil
				player.index = 0
			end
			
			if player.goingHome then 
				--print("first index: " .. player.index)
				goHome(player)
			end
			
		end
	end

	------------------------------------------------------------------------------
	-- Move Player and Optional Box to Home Position
	------------------------------------------------------------------------------
	function toHomeNode(player)
		--print("BoxIndex: " .. player.index)
		local newFoundBox = boxes[player.index]
		if player.path[player.nodeIndex] then
			if player.nodeTrans then transition.cancel(player.nodeTrans) end
			updateGridPos(player)
			-- force box to follow player
			if (newFoundBox ~= nil) and (newFoundBox.found)  then
				--print("made it here")
				newFoundBox.nodeTrans=transition.to(newFoundBox, {
					x=(player.path[player.nodeIndex][1]-0.5)*map("tileWidth"),
					y=(player.path[player.nodeIndex][2]-0.5)*map("tileHeight"),
					time=25,
					onComplete=function()
						transition.to(player.pathDisplay[player.nodeIndex-1], {xScale=0.5, yScale=0.5, time=25})
						player.pathDisplay[player.nodeIndex-1]:setFillColor(255, 255, 0)
						--player.toNextNode()
					end
				})	
			end

			--print(player.goingHome)

			player.nodeTrans=transition.to(player, {
				x=(player.path[player.nodeIndex][1]-0.5)*map("tileWidth"),
				y=(player.path[player.nodeIndex][2]-0.5)*map("tileHeight"),
				time=25,
				onComplete=function()
					transition.to(player.pathDisplay[player.nodeIndex-1], {xScale=0.5, yScale=0.5, time=25})
					player.pathDisplay[player.nodeIndex-1]:setFillColor(255, 255, 0)
					toHomeNode(player, boxIndex)
				end
			})
			
			player.nodeIndex=player.nodeIndex+1

		else
			player.nodeIndex=2
			player.movementAllowed=true
		

			local home = map.layer["obstacles"].home
			if (math.ceil(player.x/map("tileWidth")) == home[1]) and (math.ceil(player.y/map("tileHeight"))== home[2]) then
				player.goingHome = false
				player.searching = true
				newFoundBox = nil
				player.index = 0
			end
			
		end
	end

	

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
		local disX, distY, index
		for index=1, #boxes do
			tempBox = boxes[index]
			
			distX = math.abs(tileX - tempBox.gridX)
			distY = math.abs(tileY - tempBox.gridY)

			if (math.sqrt(math.pow(distX,2)+math.pow(distY,2)) <= math.sqrt(2)) then
				if not tempBox.found then
					tempBox.found = true
					--print("super first index " .. index)
					return true, tempBox.gridX, tempBox.gridY, index
				end
			end
		end

		return false, -1, -1, 0
	end

	------------------------------------------------------------------------------
	-- Move Player
	------------------------------------------------------------------------------
	local function movePlayer(event)
		
		for temp=1, #players do
			player = players[temp]
			if "began"==event.phase and player.movementAllowed and player.searching then
				for i=1, #player.pathDisplay do
					display.remove(player.pathDisplay[i])
					player.pathDisplay[i]=nil
				end
	
				updateGridPos(player) -- Reset player grid position
	
				local pointBlocked, tileX, tileY=checkForTile((math.random(30)-0.5)*map("tileWidth"), (math.random(22)-0.5)*map("tileHeight"))
	
				if not pointBlocked then
	
					setPath(player, tileX, tileY)
					player.movementAllowed=false
					toNextNode(player) -- Initiate movement
				end
			end
		end
	end


	function goHome(player)
		updateGridPos(player)
		print(boxes[player.index].weight)
		if player.movementAllowed and (boxes[player.index].weight == 0) then
			print("can move")

			updateGridPos(player) -- Reset player grid position
			local home = map.layer["obstacles"].home

			setPath(player, home[1], home[2])
			player.movementAllowed= false
			toHomeNode(player)

			for i=1,#players do
				if (players[i].gridX == player.gridX) and (players[i].gridY == player.gridY) then
					if (players[i].helping) then
						setPath(players[i], home[1], home[2])
						players[i].movementAllowed = false
						toNextNode(players[i])
						--players[i].searching = true
					end
				end
			end

		elseif (boxes[player.index].weight > 0) and not player.waiting then
			callHelp(player)
			player.waiting = true
			local function doit()
				goHome(player)
			end
			timer.performWithDelay( 1000, doit, 1 )
			

		elseif player.waiting then
			print("I'm here")
			for i=1, #players do
				if not players[i].waiting and not players[i].helping then
					print("Player: " .. player.gridX .. " " .. players[i].gridX)
					if (players[i].gridX == player.gridX) and (players[i].gridY == player.gridY) then
						boxes[player.index].weight = boxes[player.index].weight - 1
						print("New weight" .. boxes[player.index].weight)
						if (boxes[player.index].weight == 0) then
							players[i].helping = true
							players[i].rescueing = false
							player.movementAllowed = true
							print("Player1: " .. player.gridX .. " " .. players[i].gridX)
							goHome(player)
							break
						end
					--else
						--goHome(player)
					end

				end
			end
		end

	end

	function callHelp(player)
		for i=1, #players do
			if(players[i].searching == true) then
				players[i].searching = false
				players[i].rescueing = true
				setPath(players[i], player.gridX, player.gridY)
				toNextNode(players[i])
				--boxes[player.index].weight = boxes[player.index].weight -1
				--goHome(player)
				break
				-- while not (players[i].gridX == player.gridX) and not (players[i].gridY == player.gridY) do
				-- 	updateGridPos(players[i])
				-- end
				-- 
				
			end
		end
	end

	Runtime:addEventListener("touch", movePlayer)

	--box1 = map.layer["boxes"].object["box1"]
	--print(box1.weight)
	--print(box1.y)

end