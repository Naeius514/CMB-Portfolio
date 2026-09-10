local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local INITIAL_SPEED = 100
local GRAVITY = Vector3.new(0, workspace.Gravity, 0)
local LOOK_AHEAD_AMOUNT = 0.2
local SPIN_RATE = math.pi * (INITIAL_SPEED / 10)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.ExcludeInstances = {Character}

--[=[
    Models the trajectory of the projectile.
    @param x0 Vector3 The initial starting position.
    @param direction Vector3 The throw direction.
    @param t number Time elapsed since throw.
]=]
local function getProjectileMotion(x0: Vector3, direction: Vector3, t: number): Vector3
	local v0 = direction * INITIAL_SPEED
	return x0 + v0 * t - 0.5 * GRAVITY * t^2
end

--[=[
    Solves for the time the projectile will land using the quadratic formula.
    @param direction Vector3 The throw direction.
    @param x0 Vector3 The initial starting position.
]=]
local function getEndTime(direction: Vector3, x0: Vector3): number
	local v0y = direction.Y * INITIAL_SPEED
	local ay = -workspace.Gravity
	local y0 = x0.Y

	local a = 0.5 * ay
	local b = v0y
	local c = y0

	return (-b - math.sqrt(b^2 - 4*a*c)) / (2*a)
end

--[=[
    Traverses the projectile's trajectory using a Raycast.
    Erects a SECANT LINE on the parabola between the current and future position.
    f(t + LOOK_AHEAD) - f(t) — the Difference Quotient without the "Quotient."
]=]
local function raycastOnTrajectory(sword: Part, x0: Vector3, direction: Vector3, elapsed: number): RaycastResult
	local currentPosition = getProjectileMotion(x0, direction, elapsed)
	local futurePosition = getProjectileMotion(x0, direction, elapsed + LOOK_AHEAD_AMOUNT)
	local lookAheadDisplacement = futurePosition - currentPosition

	return workspace:Raycast(
		sword.Position,
		lookAheadDisplacement.Unit * 3,
		params
	)
end

--[=[
    Throws the sword at an arbitrary spin rate.
    Once an obstruction is discovered via raycast, the sword lands tip-first.
]=]
local function throwSword(sword: Part, x0: Vector3, direction: Vector3)
	
	print(sword.CFrame.RightVector)
	print(direction)
	local SPIN_AXIS = Character.HumanoidRootPart.CFrame.RightVector
	
	
	
	local elapsed = 0  -- local, resets every throw
	local endTime = getEndTime(direction, x0)
	local currentRotation = sword.CFrame.Rotation --CFrame.Angles(0, 0, math.pi/2)

	while elapsed <= endTime do
		local deltaTime = RunService.Heartbeat:Wait()
		elapsed += deltaTime

		currentRotation = CFrame.fromAxisAngle(SPIN_AXIS, SPIN_RATE * deltaTime) * currentRotation

		local currentPosition = getProjectileMotion(x0, direction, elapsed)
		sword.CFrame = CFrame.new(currentPosition) * currentRotation

		local result = raycastOnTrajectory(sword, x0, direction, elapsed)

		if result then
			-- Align cylinder so its length axis (X/RightVector) points into the surface
			sword.CFrame = CFrame.fromMatrix(
				result.Position + result.Normal * 2,
				-result.Normal,  -- RightVector points into surface
				result.Normal:Cross(sword.CFrame.LookVector).Unit  -- UpVector
			)
			break
		end
	end
	warn("DONE.")
end

ContextActionService:BindAction("Throw", function(actionName, userInputState, inputObject)
	if userInputState == Enum.UserInputState.Begin then
		
		local throwDirection = Character.HumanoidRootPart.CFrame.LookVector + Vector3.new(0, 1, 0)
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(2,4,1)
		part.Anchored = true
		part.Name = "Sword"
		part.Parent = workspace

		-- Now set position and orientation
		local spawnPosition = Character.HumanoidRootPart.Position + Vector3.new(0, 10, 0)
		part.CFrame = CFrame.lookAt(spawnPosition, spawnPosition + throwDirection )
		
		
		warn(part.CFrame.LookVector)
		
		throwSword(part, part.Position, throwDirection)
	end
end, false, Enum.UserInputType.MouseButton1)