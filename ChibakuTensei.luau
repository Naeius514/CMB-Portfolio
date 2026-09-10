local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()


--[=[
	
	The default positional center of the sphere is (0, 0, 0)
	Since it is constructed at the origin of the world.
	Call this function and apply a positional offset after

]=]
local function pointOnSphere(sphereRadius: number, latitudeAngle: number, longitudeAngle: number): Vector3
	
	
	local x = sphereRadius * math.cos(latitudeAngle) * math.cos(longitudeAngle)
	local y = sphereRadius * math.sin(latitudeAngle)
	local z = sphereRadius * math.cos(latitudeAngle) * math.sin(longitudeAngle)
	
	return Vector3.new(x, y, z)
	
end


--[=[

	Longitude and Latitude is essentially a grid. 

	The caller must specify the number of rows and the number of columns.
	Therefore, they decide the shape of the grid.
]=]
local function getPositionsOnGrid(sphereRadius: number, rows: number, columns: number, fillWithParts: boolean): {{Vector3}}
	
	
	
	-- We have, for example, 20 targets THAT NEED TO BE PLACED SOMEWHERE They're simply organized into a grid.
	-- They're not angles or anything we can plot on the sphere yet--just the number of targets---in grid format.

	
	-- TODO: Plot the targets onto the sphere.
	--[[
		Imagine one latitude circle
		We need to divide it up by the number of targets.
		
		This will give us a clean angle for each target.
		
		We must do the same with the longitude bands "circles"
	]]
	--local numberOfTargets = rows * columns;
	
	local longitudeAngleAllocationForEachTarget = (math.pi * 2) / columns
	local latitudeAngleAllocationForEachTarget = math.pi / rows -- Latitude circles only go from -pi/2 to pi/2; a semicircle. So it's full size is only pi.  If you went the full length, you'll cover the same points twice.  
	
	local gridPositions = {}
	for longitude_target = 1, columns do
		
		local longitude_angle = longitudeAngleAllocationForEachTarget * longitude_target
		
		
		local column = {}
		for latitude_target = 1, rows do
			
			local latitude_angle = -math.pi/2 + latitudeAngleAllocationForEachTarget * latitude_target
			
			local positionOnSphere = pointOnSphere(sphereRadius, latitude_angle, longitude_angle)
			
			table.insert(column, positionOnSphere)	
			
			if fillWithParts then
				local part = Instance.new("Part")
				part.Size = Vector3.new(1, 1, 1)
				part.Anchored = true
				part.Position = Vector3.new(0, 10, 0) + positionOnSphere
				part.Parent = workspace
			end

	
		end
		table.insert(gridPositions, column)
	end
	
	warn(gridPositions)
	return gridPositions, {
		Latitude_Angle_Step = latitudeAngleAllocationForEachTarget, 
		Longitude_Angle_Step = longitudeAngleAllocationForEachTarget
	}
	
	
end


local range = 360
local function scatterParts(count: number, sphereRadius, angle_steps)
	
	local parts = {}
	
	for i = 1, count do
		

			
			
		local part = Instance.new("Part")
		
		
		-- Calculate the **ARC LENGTH** = Radius * Angle
		local width = angle_steps.Longitude_Angle_Step * sphereRadius
		local height = angle_steps.Latitude_Angle_Step * sphereRadius
		
		
		
		part.Size = Vector3.new(
			width, --math.random(2, 6),
			height,--math.random(1, 3),
			math.random(2, 6)
		)
		part.Anchored = true
		part.Position = Vector3.new(
			math.random(-range, range),
			math.random(-range/2, part.Size.Y / 2),--part.Size.Y / 2
			math.random(-range, range)
		)
		part.CanCollide = false
		part.Parent = workspace
		table.insert(parts, part)
	end
	
	return parts
end


local TweenService = game:GetService("TweenService")

local function chibaku(positionalOffset: Vector3, sphereRadius: number, rows: number, columns: number, duration: number)
	
	task.wait(10)
	local partPositions, angle_steps = getPositionsOnGrid(sphereRadius, rows, columns, false)
	
	local numberOfParts = rows * columns;
	
	local Parts: {Part} = scatterParts(numberOfParts, sphereRadius, angle_steps)
	
	
	local index = 1
	
	
	
	local MovementVelocity = (Character.HumanoidRootPart.Position - positionalOffset) / (duration / 1.5)
	
	local AlignPosition = Instance.new("AlignPosition")
	AlignPosition.Position = positionalOffset
	AlignPosition.Parent = Character.HumanoidRootPart
	AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	AlignPosition.Attachment0 = Character.HumanoidRootPart.RootAttachment
	AlignPosition.MaxVelocity = MovementVelocity.Magnitude
	
	local Humanoid: Humanoid = Character.Humanoid
	
	Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	
	for i, cols in pairs(partPositions) do
		
		for _, positionOnSphere in pairs(cols) do
			
			
			local position = positionalOffset + positionOnSphere
			-- Retrieve the direction vector
			local direction = (positionOnSphere - Vector3.zero).Unit -- The sphere's center is at the origin of the world.
		
			
			
			-- Animate the parts into position
			local part = Parts[index]
			
			local finalCFrame = CFrame.lookAt(position, position + direction)
			local tween = TweenService:Create(part, TweenInfo.new(duration), {
				CFrame = finalCFrame
			})
			tween:Play()

			
			index += 1
		end
		
	end
	

	
	
	
	
end

chibaku(Vector3.new(0, 270, 0), 40, 20, 20, 20)