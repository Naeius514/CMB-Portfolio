-- TODO: Use Rodux to change and setup the active weapon

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Promise = require(ReplicatedStorage.Packages.Promise)
local Camera = workspace.CurrentCamera
local ViewModel = ReplicatedStorage:WaitForChild("ViewModelR6")
local Weapon = ReplicatedStorage:WaitForChild("Glock")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
local Mouse = LocalPlayer:GetMouse()

local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude
Params.FilterDescendantsInstances = { Character, Weapon, ViewModel }

local RANGE = 100
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local ads = false

-- Constants
local IdleBobbleFrequency = 40
local MovementBobbleFrequency = 9

local TransitionProgress = 0
local TransitionSpeed = 0.03
local StrafeTransitionSpeed = 0.1
local RecoilTransitionSpeed = 0.3

local MovementSpeed = Humanoid.WalkSpeed / 4
local BobbleSpeed = 1.2
local WaveSize = 3.8

local CurrentStrafeOffset = CFrame.new()
local StrafeOffset = CFrame.new()

local RecoilOffset = CFrame.new()
local CurrentRecoilOffset = CFrame.new()

local OscillationOffset = CFrame.new()

local ADSCount = 0
local ADSOffset

-- Methods
local function abs(x)
	-- This is a modified version of math.abs() for smoother ossilication from (around) 0 to 1.
	-- Formed based on the understanding that: math.abs(x) == math.sqrt(x*x)
	return sqrt((x * x) + 0.005)
end

local function UpdateArms()
	-- Right Arm
	local RightInitialCFrame = ViewModel.Torso.CFrame * ViewModel.Torso["Right Shoulder"].C0
	local RightTargetCFrame = Weapon.Right.CFrame * CFrame.Angles(math.pi / 2, 0, 0)
	local RightOffset = CFrame.new(0, 1.4, 0.45)
	ViewModel.Torso["Right Shoulder"].C1 = (RightTargetCFrame * RightOffset):Inverse() * RightInitialCFrame

	-- Left Arm
	local LeftInitialCFrame = ViewModel.Torso.CFrame * ViewModel.Torso["Left Shoulder"].C0
	local LeftTargetCFrame = Weapon.Right.CFrame * CFrame.Angles(math.pi / 2, 0, (math.pi * 2) / 9)
	local LeftOffset = CFrame.new(0, 1, 0.62) * CFrame.Angles((math.pi * 2) / 45, 0, 0)
	ViewModel.Torso["Left Shoulder"].C1 = (LeftTargetCFrame * LeftOffset):Inverse() * LeftInitialCFrame
end

local function CalculateIdleBobble(angle)
	return CFrame.new(cos(angle) / IdleBobbleFrequency, sin(angle) / IdleBobbleFrequency, 0)
end

local function CalculateMovementBobble(currentTime)
	return CFrame.new(
		cos(currentTime * MovementSpeed) / MovementBobbleFrequency,
		if not ads then abs(sin(currentTime * MovementSpeed) / MovementBobbleFrequency) else 0,
		0
	)
end

local function UpdateViewModelPosition()
	-- Initialise
	local CurrentTime = tick()
	local InitialCFrame = Camera.CFrame * CFrame.new(0, 0.5, -1.75)
	local MoveDirection = Humanoid.MoveDirection

	-- Arm Movement
	TransitionProgress = if MoveDirection.Magnitude > 0
		then math.min(TransitionProgress + TransitionSpeed, 1)
		else math.max(TransitionProgress - TransitionSpeed, 0)
	if TransitionProgress == 0 then
		OscillationOffset = CalculateIdleBobble(CurrentTime)
	elseif TransitionProgress == 1 then
		OscillationOffset = CalculateMovementBobble(CurrentTime)
	elseif TransitionProgress < 1 and TransitionProgress > 0 then
		OscillationOffset =
			CalculateIdleBobble(CurrentTime):Lerp(CalculateMovementBobble(CurrentTime), TransitionProgress)
	end

	-- Apply
	StrafeOffset = StrafeOffset:Lerp(CurrentStrafeOffset, StrafeTransitionSpeed)
	RecoilOffset = RecoilOffset:Lerp(CurrentRecoilOffset, RecoilTransitionSpeed)
	ViewModel.Head.CFrame = InitialCFrame * OscillationOffset * StrafeOffset * RecoilOffset
end

local function Strafing(_, InputState, InputObject)
	if InputState == Enum.UserInputState.Begin then
		if InputObject.KeyCode == Enum.KeyCode.A then
			CurrentStrafeOffset = CFrame.Angles(0, 0, math.pi / 18)
		elseif InputObject.KeyCode == Enum.KeyCode.D then
			CurrentStrafeOffset = CFrame.Angles(0, 0, -math.pi / 18)
		end
	else
		CurrentStrafeOffset = CFrame.new()
	end
end

local function AimDownSights(_, InputState)
	local aiming = if InputState == Enum.UserInputState.Begin then true else false
	local joint = ViewModel.Head.Joint
	local start = joint.C1
	local goal = if aiming then joint.C0 * ADSOffset else CFrame.new()
	IdleBobbleFrequency = if aiming then 100 else 40
	MovementBobbleFrequency = if aiming then 100 else 9
	ads = if aiming then true else false
	MovementSpeed = if aiming then Humanoid.WalkSpeed / 16 else Humanoid.WalkSpeed / 4

	ADSCount = ADSCount + 1
	local current = ADSCount
	for t = 0, 1.01, 0.1 do
		if current ~= ADSCount then
			break
		end
		RunService.RenderStepped:Wait()
		joint.C1 = start:Lerp(goal, t)
		UpdateArms()
	end
end
local function Discharge(Action, InputState, InputObject)
	if InputState == Enum.UserInputState.Begin then
		ReplicatedStorage.RemoteEvents.Discharge:FireServer(
			Weapon.Barrel.Position,
			Weapon.Aim.CFrame.LookVector * RANGE
		)
		-- Recoil
		RecoilOffset = CFrame.new(0, 0, 0.5) * CFrame.Angles((2 * math.pi) / 45, 0, 0)
		Promise.delay(RecoilTransitionSpeed):andThen(function()
			RecoilOffset = CFrame.new()
		end)
	end
end

-- Setup
do
	-- Initialise ViewModel
	ViewModel.Parent = Camera
	Weapon.Parent = ViewModel
	ADSOffset = Weapon.Handle.CFrame:Inverse() * Weapon.Aim.CFrame * CFrame.new(0, 0.5, -1.1)
	-- Joint
	local Joint = Instance.new("Motor6D")
	Joint.Name = "Joint"
	Joint.C0 = CFrame.new(1, -1.5, 0)
	Joint.Part0 = ViewModel.Head
	Joint.Part1 = Weapon.Handle
	Joint.Parent = ViewModel.Head
	-- Init
	UpdateArms()
end

-- Connections
RunService.RenderStepped:Connect(UpdateViewModelPosition)
ContextActionService:BindActionAtPriority("Strafing", Strafing, false, 1999, Enum.KeyCode.A, Enum.KeyCode.D)
ContextActionService:BindAction("Discharge", Discharge, false, Enum.UserInputType.MouseButton1)
ContextActionService:BindAction("AimDownSights", AimDownSights, false, Enum.UserInputType.MouseButton2)
