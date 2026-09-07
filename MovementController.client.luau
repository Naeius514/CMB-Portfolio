--[=[
	MovementController.client.luau

	TO TEST PLEASE USE THE FOLLOWING INSTRUCTIONS:
		1. DOUBLE TAP "W" TO SPRINT
		2. PRESS "Q" TO DASH
		3. DOUBLE PRESS SPACEBAR TO DOUBLE JUMP
		4. DOUBLE PRESS SPACEBAR NEAR A WALL TO CLIMB
]=]

-- Services
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

-- Shared Modules 
local MovementSettings = require(ReplicatedStorage.GlobalSettings.MovementSettings) -- Walk/sprint speed constants
local ClientResources = require(StarterPlayer.StarterPlayerScripts.ClientResources) -- Shared client-side state table (IsSprinting, IsDashing, etc.)
local Promise = require(ReplicatedStorage.Packages.Promise) -- Open-source Promise implementation

-- Shared Variables
local Character = script.Parent -- The script's parent is the Character model itself
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.Camera
local Humanoid: Humanoid = Character.Humanoid
local HumanoidRootPart: BasePart = Character:WaitForChild("HumanoidRootPart")
local AnimationFolder = ReplicatedStorage.Animations.Movement -- Root folder that contains every movement animation used across all of the movement abilities

-- All of the ability functions below are bound to ContextActionService, which expects
-- a function shaped like (actionName: string, inputState: Enum.UserInputState, inputObject: InputObject) -> ()
type functionality = () -> nil

local Sprint: functionality
local Dash: functionality
local DoubleJumpAndWallClimb: functionality



--[=[	SPRINTING	]=]
do
	local SprintAnimation: AnimationTrack = Humanoid.Animator:LoadAnimation(AnimationFolder.sprint)

	local LastSprintPressed = 0
	local SPRINT_PRESS_THRESHOLD = 0.25 -- Seconds allowed between the two presses for it to count as a "double tap"

	local TIME_TO_SPRINT = 0.85 -- Seconds it takes to accelerate up to sprint speed
	local SPRINT_ANIMATION_FADE_IN = 0.4
	local SPRINT_ANIMATION_FADE_OUT = 0.25 -- Unused directly below, but kept for symmetry/reference alongside fade-in

	-- Pre-building the TweenInfo once (instead of inside the function) avoids
	-- reconstructing the same struct on every single sprint press.
	local SPRINT_TWEEN_INFO = TweenInfo.new(TIME_TO_SPRINT)

	Sprint = function(actionName, UserInputState)
		-- Releasing the key exits sprinting immediately and snaps speed back to normal.
		if UserInputState == Enum.UserInputState.End then
			if SprintAnimation.IsPlaying then
				SprintAnimation:Stop()
			end
			Humanoid.WalkSpeed = MovementSettings.DEFAULT_SPEED
			ClientResources.States.IsSprinting = false
			return
		end

		local CurrentTime = os.clock()

		-- If this press landed within the threshold of the last one, treat it as
		-- the "double tap" that triggers sprinting.
		if (CurrentTime - LastSprintPressed) <= SPRINT_PRESS_THRESHOLD then
			print("Sprint")
			ClientResources.States.IsSprinting = true
			SprintAnimation:Play(SPRINT_ANIMATION_FADE_IN, 1)

			-- TweenService smoothly interpolates WalkSpeed up to the sprint speed over
			-- TIME_TO_SPRINT seconds rather than snapping instantly, so acceleration feels natural.
			TweenService:Create(Humanoid, SPRINT_TWEEN_INFO, {
				WalkSpeed = MovementSettings.MAX_SPRINT_SPEED,
			}):Play()
		end

		LastSprintPressed = os.clock()
	end
end


--[=[	DASHING		]=]
do
	local DashVelocity = Instance.new("BodyVelocity") -- Applies the actual displacement force during the dash
	local DashOrientation = Instance.new("AlignOrientation") -- Locks facing direction so the dash doesn't spin the character around
	local SlideVelocity = Instance.new("BodyVelocity") -- Reserved for slide-style movement; not driven by any logic yet

	DashVelocity.MaxForce = Vector3.one * math.huge -- Unlimited force so the velocity we set is applied exactly, unaffected by mass
	DashVelocity.Velocity = Vector3.zero

	DashOrientation.RigidityEnabled = true -- Snaps to the target CFrame instantly instead of easing into it
	DashOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	DashOrientation.Attachment0 = HumanoidRootPart.RootAttachment

	local Animations = {
		ForwardDash = Humanoid.Animator:LoadAnimation(AnimationFolder.forwarddash),
		BackwardDash = Humanoid.Animator:LoadAnimation(AnimationFolder.backwarddash),
		LeftDash = Humanoid.Animator:LoadAnimation(AnimationFolder.leftdash),
		RightDash = Humanoid.Animator:LoadAnimation(AnimationFolder.rightdash),
		AirForwardDash = Humanoid.Animator:LoadAnimation(AnimationFolder.airforwarddash),
		AirBackwardDash = Humanoid.Animator:LoadAnimation(AnimationFolder.airbackwarddash),
	}

	-- Settings
	local DefaultDashDistance = 25 -- Studs the player is displaced from where they started the dash
	local DashDuration = 0.5 -- Seconds it takes to cover that distance
	local DashCooldown = 0.55 -- Seconds to wait after a dash ends before another can begin

	Dash = function(actionName, UserInputState)
		if
			UserInputState == Enum.UserInputState.End --or
			--Humanoid.MoveDirection.Magnitude <= 0 -- If the player is stationary
		then
			return
		end

		local LastMoveDirection = Vector3.zero
		ClientResources.States.IsDashing = true

		local InAir = Humanoid:GetState() == Enum.HumanoidStateType.Jumping
			or Humanoid:GetState() == Enum.HumanoidStateType.Freefall

		DashOrientation.Parent = HumanoidRootPart

		-- Promise.try wraps the loop below so it runs as its own async block --
		-- the rest of Dash() (picking the animation, queuing cleanup) continues
		-- immediately without waiting on this to finish.
		Promise.try(function()
			for _ = 1, 5 do --   The dash direction should be continously updated during the duration of the dash in case the player changes their trajectory or direction, hence the for loop. Maybe we shouldn't hardcode the numbers (start, stop)?
				-- Building a CFrame from the root part's position looking toward the camera.
				DashOrientation.CFrame = CFrame.new(
					HumanoidRootPart.Position,
					HumanoidRootPart.Position + (Camera.CFrame.LookVector * Vector3.new(1, 0, 1)) -- LookVector (Y zeroed via the (1, 0, 1) mask) keeps the dash aligned to the camera without tilting up/down
				)
				local DashDirection = Humanoid.MoveDirection

				if
					Humanoid:GetState() == Enum.HumanoidStateType.Jumping
					or Humanoid:GetState() == Enum.HumanoidStateType.Freefall
				then
					DashDirection -= Vector3.new(0, 0.15, 0) -- Slightly decrease the height if the player is in the air.
				end
				local DashSpeed = DefaultDashDistance / DashDuration -- Converts the target distance/duration into a studs-per-second speed
				DashVelocity.Parent = Character.HumanoidRootPart
				DashVelocity.Velocity = DashDirection
					* (if ClientResources.States.IsSprinting then DashSpeed + (DashSpeed / 2) else DashSpeed) -- Add boost if the player is sprinting
				task.wait(0.1)

				LastMoveDirection = if DashDirection.Magnitude == 0 then LastMoveDirection else DashDirection
			end
			DashOrientation.Parent = nil
			DashOrientation.CFrame = CFrame.new()
		end)

		-- Reading the raw key state (rather than the actionName/UserInputState the
		-- action was bound with) lets us pick a directional animation based on
		-- whatever movement key is currently held, independent of which key
		-- triggered the dash action itself.
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			warn("DOWNNN!!")
			if InAir then
				Animations.AirForwardDash:Play()
			else
				Animations.ForwardDash:Play()
			end
		elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
			if InAir then
				Animations.AirBackwardDash:Play()
			else
				Animations.BackwardDash:Play()
			end
		elseif UserInputService:IsKeyDown(Enum.KeyCode.A) then
			Animations.LeftDash:Play()
		elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
			Animations.RightDash:Play()
		end

		-- first wait out the dash itself and delete the
		-- velocity, then wait out the separate cooldown before allowing another dash.
		Promise.delay(DashDuration)
			:andThen(function()
				DashVelocity.Parent = nil
				DashVelocity.Velocity = Vector3.zero
			end)
			:andThen(function()
				Promise.delay(DashCooldown):andThen(function()
					ClientResources.States.IsDashing = false
				end)
			end)
	end
end


--[=[	DASH & WALL CLIMB	]=]
do
	local JUMP_PRESSED_THRESHOLD: number = 0.5
	local SEARCH_WALL_DISTANCE: number = 3.5
	local MINIMUM_WALL_CLIMB_SIZE: number = 5
	local WALL_CLIMB_COOLDOWN: number = 2
	local WALL_CLIMB_ANCHOR_TIME: number = 0.2

	local JumpCounter: number = 0 -- Important
	local JumpLastPressed: number = 0

	local WallClimbAnimation = Humanoid.Animator:LoadAnimation(AnimationFolder.walljump)
	local AirFrontFlipAnimation = Humanoid.Animator:LoadAnimation(AnimationFolder.airfrontflip)
	local AirBackFlipAnimation = Humanoid.Animator:LoadAnimation(AnimationFolder.airbackflip)

	local LastWallClimbed = nil -- Tracks the most recently climbed wall so the same wall can't be re-triggered immediately
	local VelocityForSuspendedMotion = Instance.new("BodyVelocity") -- Momentarily freezes the character in place at the start of a wall climb
	VelocityForSuspendedMotion.MaxForce = Vector3.one * math.huge
	VelocityForSuspendedMotion.Velocity = Vector3.zero

	local WallClimbRaycastParams = RaycastParams.new()
	WallClimbRaycastParams.FilterDescendantsInstances = { Character } -- Excludes the character's own parts so the raycast can't hit itself

	--[=[
		Traditional functionality of Wall Climbing
		as it worked in Tyrone Shippuden.

		This method is called each time the player enters freefall
		and after the first jump request before a double jump.
	]=]
	local function WallClimb()
		-- Casts forward from the root part to see if there's a wall in range to grab onto.
		local RaycastResult = workspace:Raycast(
			HumanoidRootPart.Position,
			HumanoidRootPart.CFrame.LookVector * SEARCH_WALL_DISTANCE,
			WallClimbRaycastParams
		)
		if not RaycastResult then
			return false -- If a wall could not be found, then exit.
		end

		if RaycastResult.Instance.Size.Y <= MINIMUM_WALL_CLIMB_SIZE then
			return false -- If the size of the detected wall is less than the minimum allowable wall size, then exit.
		end

		if
			not CollectionService:HasTag(RaycastResult.Instance, "NoClimb") -- Ignore walls that have the tag "NoClimb"
			and RaycastResult.Instance.Name ~= "Leaves" -- Leaves attached to trees should not be climbable.
			and LastWallClimbed ~= RaycastResult.Instance -- The detected wall should not be
		then
			LastWallClimbed = RaycastResult.Instance
			WallClimbAnimation:Play()
			WallClimbAnimation:AdjustSpeed(0) -- Freeze the animation on its first frame while the character is anchored below

			-- Suspends the Character in place for WALL_CLIMB_ANCHOR_TIME seconds.
			VelocityForSuspendedMotion.Parent = Character.HumanoidRootPart
			task.wait(WALL_CLIMB_ANCHOR_TIME)
			VelocityForSuspendedMotion.Parent = nil

			-- Calculate the Mass
			local Mass = 0
			do
				for _, BodyPart in pairs(Character:GetChildren()) do
					if BodyPart:IsA("BasePart") and BodyPart.Massless == false then
						Mass += BodyPart:GetMass()
					end
				end
			end

			WallClimbAnimation:AdjustSpeed(1) -- Resume the animation now that the launch is about to happen

			HumanoidRootPart.AssemblyLinearVelocity = HumanoidRootPart.CFrame.UpVector * Humanoid.JumpPower * 0.95 -- apply a fixed upward push scaled using the Humanoid's JumpPower (via the root part's UpVector, so it launches along the wall's surface normal)

				+ Vector3.new(0, (Humanoid.JumpPower / 12.5 * Mass), 0)

			Promise.delay(WALL_CLIMB_COOLDOWN):andThen(function()
				LastWallClimbed = nil
			end)

			return true
		end
	end

	-- Primary Double Jump Logic:
	DoubleJumpAndWallClimb = function(actionName, UserInputState)
		local State = ClientResources.States

		-- Exits if any of the following conditions are true:
		if UserInputState == Enum.UserInputState.End or State.IsCrouching or State.IsDashing or JumpCounter >= 1 then
			return
		end

		-- Executes the Wall Climb logic if the player is freefalling
		if
			Humanoid:GetState() == Enum.HumanoidStateType.Freefall
			and WallClimb() -- If WallClimb() returns false, then the Double Jump will proceed.
			-- if WallClimb() returns true, then the Double Jump will not execute.
		then
			return
		end

		-- If the Spacebar is pressed in time:
		local CurrentTime = os.time()
		if
			CurrentTime - JumpLastPressed <= JUMP_PRESSED_THRESHOLD
			and (
				Humanoid:GetState() == Enum.HumanoidStateType.Jumping
				or Humanoid:GetState() == Enum.HumanoidStateType.Freefall
			)
		then
			Humanoid:ChangeState(Enum.HumanoidStateType.Jumping, true) -- Execute the secondary jump

			-- We have jumped once; increment the jumpcounter
			JumpCounter += 1
			if JumpCounter == 1 then -- If the total number of jumps is only 1 (out of 2), then:
				-- Find a wall to climb (Checking on JUMP request this time)
				if WallClimb() then
					JumpCounter = 0 -- Climbing a wall counts as a successful "Double Jump," so set the JumpCounter back to 0
					return -- And then exit the function since the "Double Jump" was successful.
				end

				-- Else if a climbable wall was not found, execute an actual Double Jump.
				-- The Dot Product of the root part's LookVector and the Humanoid's
				-- MoveDirection tells us whether the player is moving roughly forward
				-- or backward relative to where they're facing (positive = forward,
				-- negative = backward), which decides the flip animation to play.
				local ForwardDot = HumanoidRootPart.CFrame.LookVector:Dot(Humanoid.MoveDirection)
				if ForwardDot >= 0 then
					AirFrontFlipAnimation:Play()
				elseif ForwardDot < 0 then
					AirBackFlipAnimation:Play()
				end

				-- Once we have landed, disconnect everything and cleanup.
				local OnLanded
				OnLanded = Humanoid.StateChanged:Connect(function(_, CurrentState)
					if CurrentState == Enum.HumanoidStateType.Landed then
						--AnimationManager:Play("landed")
						JumpCounter = 0
						OnLanded:Disconnect()
						OnLanded = nil
					end
				end)
			end
		end
		JumpLastPressed = CurrentTime
	end
end

-- Binding each ability to ContextActionService
ContextActionService:BindActionAtPriority("Sprint", Sprint, false, 1999, Enum.PlayerActions.CharacterForward)

--[=[ Intiailize Dashing Functionality  ]=]
ContextActionService:BindActionAtPriority("Dashing", Dash, false, 1999, Enum.KeyCode.Q)

--[=[ Intiailize Double Jump and Wall Climbing Functionality  ]=]
ContextActionService:BindActionAtPriority(
	"DoubleJumpAndWallClimb",
	DoubleJumpAndWallClimb,
	false,
	1999,
	Enum.KeyCode.Space
)
