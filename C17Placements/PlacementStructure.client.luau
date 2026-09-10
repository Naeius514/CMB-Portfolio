--[=[

    PlacementStructure.client.luau 

    Implements client-sided functionality that allows the 
    local player to load previously saved structures.

]=]

--[[TODO:
Should have a fixed position check option though.
Either it is or it isn't.
As in original position.
Where it was saved.

]]
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SavedStructures = {}

local ServerHandlerRemote: RemoteFunction = ReplicatedStorage:WaitForChild("FUNCTION_PlacementStructure") -- Used by the client to invoke the server for server-related requests
local ServerDispatcher: RemoteEvent = ReplicatedStorage:WaitForChild("EVENT_PlacementStructure") -- Used by the server to dispatch saved placements to the client once the Player first joins.

local myPlacements = {}
local Component = require(script.Parent.Component)
local LocalPlayer = Players.LocalPlayer

local Mouse = LocalPlayer:GetMouse()

local GlobalRotation = 0 -- A global rotation value that is applied to all placed models
local MouseMoveConnection: RBXScriptSignal | nil = nil -- Connection to the MouseMove event
local ConfirmPlacementConnection: RBXScriptSignal | nil = nil -- Connection on the ConfirmPlacement button

local Promise = require(ReplicatedStorage:WaitForChild("Promise"))

--[=[

	This is the callback for the client to determine where to place the object.
	This function is executed on the server's request via a RemoteFunction
	and returns the CFrame that represents the client's choice of where to place the object.
	
	
	Allows the player to place their model.
	
	A substitute of the passed in model is created and placed at the player's mouse position.
	Once the player confirms the position of the substiute, a request to the server is made to
	finalize the changes on the actual model.
	
	@params Object Model The model to place.
]=]
local function PlaceObject(type, Object: Model)
	
	if type ~= "WhereDoIPlaceModel" then
		return
	end
	-- A substitute of the model that allows the player to manipulate the model
	local PlacementSubstitute = Object:Clone()
	PlacementSubstitute.Parent = workspace
	PlacementSubstitute.Name = "PLACEMENT_SUBSTITUTE"
	
	local PlacementCF = CFrame.identity
	
	
	local Descendants: { BasePart } = PlacementSubstitute:GetDescendants()
	for Index: number = 1, #Descendants do
		local GrandChild: BasePart = Descendants[Index]

		if (GrandChild:IsA("ProximityPrompt")
			or GrandChild:IsA("Texture"))
		then
			GrandChild:Destroy()
			continue
		end

		if not (GrandChild:IsA("BasePart")) then
			continue
		end

		GrandChild.CanCollide = false
		GrandChild.CanQuery = false
		GrandChild.CanTouch = false

		if GrandChild:GetAttribute("KeepInPlace") then
			continue
		end

		if GrandChild:IsA("MeshPart") then
			GrandChild.TextureID = ""
		end

		GrandChild.Transparency = 0.5
		GrandChild.Material = Enum.Material.SmoothPlastic
		GrandChild.Color = Color3.fromRGB(91, 154, 76)
	end
	
	
	MouseMoveConnection = Mouse.Move:Connect(function()
		PlacementCF = CFrame.new(Mouse.Hit.Position)
			* CFrame.new(0, Object:GetExtentsSize().Y / 2, 0)
			--* Object.Offset.Value
			* CFrame.Angles(0, math.rad(GlobalRotation), 0)
		PlacementSubstitute:PivotTo(PlacementCF)
	end)
	
	ConfirmPlacementConnection = Mouse.Button1Down:Connect(function()
		-- Cleanup the connections and destroy the substitute
		-- This function will disconnect Mouse.Move, which is blocking the function from returning.
		MouseMoveConnection:Disconnect()
		ConfirmPlacementConnection:Disconnect()
		MouseMoveConnection = nil
		ConfirmPlacementConnection = nil
		PlacementSubstitute:Destroy()
	end)		
	
	repeat task.wait() until MouseMoveConnection == nil
	
	return PlacementCF
end


--[=[
    Sends a request to the server to write/read from the DataStores
    or to load a placement from the Stores.

    This function is passed to the UI Component as a callback and it is
        called from there.
]=]
local function SendRequestToServer(RequestType: "Load" | "Save" | "Delete", ...): nil
	local result: Model | boolean = ServerHandlerRemote:InvokeServer(RequestType, ...)
	warn(result)
	if RequestType == "Load" then
		if typeof(result) == "boolean" then
			warn(result)
			return
		end
	else
		if result == false then
			print("Server denied request.")
		end
	end
end

--[=[
	Central method properly initializing the UI Component
]=]
local function startComponent()
	-- If a tree is already active, destroy it to deep refresh the Component.
	if Component.tree then
		Component:doCleaning()
	end
	Component:init(myPlacements, SendRequestToServer)
end

--[=[
    Retrieves the player's saved structures from the Server.
]=]
local function ServerSendsSavedStructures(Placements)
	warn("Recieved!", Placements)
	if Placements then
		warn("Recieved!")
		warn(Placements)
		myPlacements = Placements
		startComponent()
	end
end

--[=[
    Handles the functionality when the PlacementTool tool is equipped
    Initializes the UI Component so that the player can send requests to the Server
]=]
local function OnPlacementToolEquipped(Tool: Tool)
	if not Tool:HasTag("PlacementTool") then
		return
	end
	print(myPlacements)
	startComponent()
end

--[=[
    Executes the doCleaning method of the UI Component
    when the tool is unequipped.
]=]
local function OnPlacementToolUnequipped(Tool: Tool)
	if not Tool:HasTag("PlacementTool") then
		return
	end
	Component:doCleaning()
end

--[=[ Connections ]=]

task.wait(3)
warn("HELLO!")
startComponent()

ContextActionService.LocalToolEquipped:Connect(OnPlacementToolEquipped)
ContextActionService.LocalToolUnequipped:Connect(OnPlacementToolUnequipped)
ServerDispatcher.OnClientEvent:Connect(ServerSendsSavedStructures)
ServerHandlerRemote.OnClientInvoke = PlaceObject -- This is the callback for the client to determine where to place the object.

