--[=[
	
	PlacementStructure.luau
	
	Tracks and saves all the components' CFrames within a structure
	so that they may reloaded at a later date (via Datastores).
	
	Written by Naeius
]=]

-- Services
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Variables
local PlacementStructure = {}
local PlacementStore = DataStoreService:GetDataStore("PlacementStore")
PlacementStructure.__index = PlacementStructure

local Promise = require(ReplicatedStorage:WaitForChild("Promise"))

-- Player Data
local PlayerSavedPlacements: PlayerSavedPlacements = {} -- Contains a cache that has all saved/previously created players in the session.
local PlayerPlacements: PlayerPlacements = {} -- Tracks current builds of all players in the session.

-- TYPES

export type EditOperations = "load" | "save" | "delete"
export type PlayerSavedPlacements = { Player: { PlacementStructure } }
export type PlayerPlacements = { Player: PlacementStructure }

export type StructureComponent = {
	PositionalOffset: Vector3,
	Rotation: CFrame,
	StructureType: string, -- Chair, table, etc
}

export type StructureOrigin = {
	AbsoluteWorldPosition: Vector3,
	Rotation: CFrame,
	StructureType: string,
}

export type StructureComponents = {
	Model: { StructureComponent },
}

export type PlacementStructure = {
	Name: string,
	Origin: StructureOrigin,
	StructureComponents: StructureComponents,
}

local ServerHandlerRemote: RemoteFunction; -- Used by the client to invoke the server for server-related requests
local ServerDispatcher: RemoteEvent; -- Used by the server to dispatch saved placements to the client once the Player first joins.
do
	ServerHandlerRemote = ReplicatedStorage:WaitForChild("FUNCTION_PlacementStructure", 10)
	if not ServerHandlerRemote then
		ServerHandlerRemote = Instance.new("RemoteFunction");
		ServerHandlerRemote.Name = "FUNCTION_PlacementStructure";
		ServerHandlerRemote.Parent = ReplicatedStorage;
	end


	ServerDispatcher = ReplicatedStorage:WaitForChild("EVENT_PlacementStructure", 10)
	if not ServerDispatcher then
		ServerDispatcher = Instance.new("RemoteEvent");
		ServerDispatcher.Name = "EVENT_PlacementStructure";
		ServerDispatcher.Parent = ReplicatedStorage;
	end
end


--[=[
	Serializes a CFrame so that it can be properly stored
	into the Data Stores in the required string UTF-8 format.
]=]
local function SerializeCFrame(cframe: CFrame): table
	local components = {cframe:GetComponents()}	
	return components;
end

--[=[
	Deserializes a CFrame and reconstructs it into a CFrame object.
]=]
local function DeserializeCFrame(components: table): CFrame
	return CFrame.new(unpack(components));
end

--[=[
	Loads and caches all saved placements for a player
	when they join the session	
]=]
local function RetrieveAndCachePlacementsFromStore(Player: Player): boolean
	warn("CHECKED PLACEMENTS FOR PLAYER")
	local result, playerPlacementsFromStore = pcall(function()
		return PlacementStore:GetAsync(tostring(Player.UserId)) :: { PlacementStructure } or {}
	end)

	if result then
		warn("PLACEMENTS FOUND FOR PLAYER, SENDING TO CLIENT", playerPlacementsFromStore)

		for _, placement in pairs(playerPlacementsFromStore) do
			setmetatable(placement, PlacementStructure)
		end
		PlayerSavedPlacements[Player] = playerPlacementsFromStore
		print(playerPlacementsFromStore)
		
		task.wait(5)
		print("EXECUTED")
		ServerDispatcher:FireClient(Player, playerPlacementsFromStore) -- Inform the client
	end

	return result and true or false
end


--[=[
	Retrieves a player's structure from the Cache

	@params Player Player the Player to retrieve the placement for
	@params PlacementName string The name of the placement to retrieve
	@return Model | false Returns the reconstructed placement. If a Model did not return, a failure has occured
--]=]
local function LoadPlacementFromCache(Player: Player, PlacementName: string): Model | false

	for _, Placement: PlacementStructure in PlayerSavedPlacements[Player] do
		warn(Placement.Name, PlacementName)
		if Placement.Name == PlacementName then
			

			local Model = Placement:RebuildStructure()
			
			Model:PivotTo(CFrame.identity)
			Model.Parent = workspace
			
			local PlacementCF =  ServerHandlerRemote:InvokeClient(Player, "WhereDoIPlaceModel", Model)
			Model:PivotTo(PlacementCF)

			
			--local PlacementPromise = ServerHandlerRemote:InvokeClient(Player, "WhereDoIPlaceModel", Model)
			--PlacementPromise = setmetatable(PlacementPromise, Promise) -- Repairs the Promise; functions cannot be passed through the network
			
			--PlacementPromise:andThen(function(PlacementCF: CFrame)
			--	Model:PivotTo(PlacementCF)
			--	Model.Parent = workspace
			--end)

			--Where do you want me to put it?
			--Promise.new(function(resolve)
			--	resolve(ServerHandlerRemote:InvokeClient(Player, "WhereDoIPlaceModel", Model))
			--end):andThen(function(PlacementCF)
			--	warn("PLACEMENT LOADED", PlacementCF)
			--	PlacementCF = setmetatable(PlacementCF, Promise)
			--	PlacementCF:andThen(function(x)
			--		print("Yo!!!", x)
			--	end)
			--	--Model:PivotTo(PlacementCF)
			--	--Model.Parent = workspace
			--end)
			return Model;
		end
	end
	return false;
end

--[=[
	Saves the player's current build upon request.
]=]
local function SavePlacementToStore(Player: Player, PlacementName: string): boolean
	
	-- If the player has no actively edited placement, then there is nothing to save.
	if PlayerPlacements[Player] == nil then
		return false;
	-- A placement name is required.
	elseif PlacementName == nil then
		warn("No placement name given.")
		return false;
	end
	
	warn(PlacementName)
	local result = pcall(function()
		return PlacementStore:UpdateAsync(tostring(Player.UserId), function(previousStructures: { PlacementStructure })

			if previousStructures == nil then
				previousStructures = {};
			end
			
			local Placement = PlayerPlacements[Player] -- This represents the placement the player is actively editing.
			Placement.Name = PlacementName;
			warn(Placement)
			table.insert(previousStructures, Placement)
			return previousStructures
		end)
	end)
	
	if result then
		table.insert(PlayerSavedPlacements[Player], PlayerPlacements[Player])
		ServerDispatcher:FireClient(Player, PlayerSavedPlacements[Player])
	end
	-- TODO: Update the list of placements that can be loaded/deleted.
	return result and true or false
end




--[=[
	Deletes a player's placement within the Datastores.
]=]
local function DeletePlacementInStore(Player: Player, PlacementName: string): boolean
	local result = pcall(function()
		return PlacementStore:UpdateAsync(tostring(Player.UserId), function() 
			-- Find the Placement
			for index, Placement: PlacementStructure in PlayerSavedPlacements[Player] do
				if Placement.Name == PlacementName then
					table.remove(PlayerSavedPlacements[Player], index);
				end
			end
			return PlayerSavedPlacements[Player];
		end)
	end)
	
	if result then
		ServerDispatcher:FireClient(Player, PlayerSavedPlacements[Player])
	end
	
	return result and true or false
end

--[=[
	Routes client requests to specific server-sided handlers
	and returns to the client their results.
]=]
local function HandleClientRequests(Player: Player, type: EditOperations, ...)
	print(...)
	warn("RECIEVED FROM CLIENT");
	if type == "Save" then
		return SavePlacementToStore(Player, ...);
	elseif type == "Delete" then
		return DeletePlacementInStore(Player, ...)
	elseif type == "Load" then
		return LoadPlacementFromCache(Player, ...)
	end

end


--[=[
	Instantiate an object that tracks and can 
	save a player's placement.
]=]
function PlacementStructure.new(): PlacementStructure
	local self = setmetatable({}, PlacementStructure)
	self.origin = nil :: StructureOrigin
	self.structureComponents = {} :: StructureComponents

	--task.spawn(function()
	--	task.wait(60)
	--	local Model = self:RebuildStructure()
	--	Model:PivotTo(workspace.Neariest.HumanoidRootPart.CFrame * CFrame.new(5, -0.5, 0))
	--	Model.Parent = workspace
	--	warn("REBUILT IT!!!")
	--end)

	return self
end

--[=[
    Retrieves the Placement for a player
]=]
function PlacementStructure:GetPlayerPlacement(Player: Player): PlacementStructure
	local Placement = PlayerPlacements[Player]
	warn(Placement)
	if not Placement then
		Placement = PlacementStructure.new()
		PlayerPlacements[Player] = Placement
	end
	return Placement
end

--[=[
	Determine the origin of the structure.
	
	@param Part Model The central part to determine the origin position of the structure from.
	@param StructureType string the type of structure that the origin is (e.g a chair, a table, a couch, etc)
		Necessary so that a later date, the origin part will be of the same structure type upon the placement structure's reconstruction.
	@return The structure's origin
]=]
function PlacementStructure:SetOrigin(Model: Model, StructureType: string): StructureOrigin
	local Origin: StructureOrigin = {}
	--Origin.AbsoluteWorldPosition = SerializeCFrame(CFrame.new(Model.WorldPivot.Position))
	--Origin.Rotation = SerializeCFrame(Model.WorldPivot.Rotation)
	Origin.SerializedCFrame = SerializeCFrame(Model.WorldPivot)
	Origin.StructureType = StructureType

	self.origin = Origin

	return Origin
end

--[=[
	Determines the relative positional offset of a StructureComponent from the Structure's origin
	
	Builds a "StructureComponent" for a newly added component of the structure
	
	@param Part Model The part to determine the relative offset from the structure's position.
	@param StructureType string the type of structure that the component is of(e.g a chair, a table, a couch, etc)
		Necessary so that a later date, the component will be of the same structure type upon the placement structure's reconstruction.
	@return The resulting StructureComponent
]=]
function PlacementStructure:BuildStructureComponent(Model: Model, StructureType: string): StructureComponent
	if not self.origin then
		return
	end

	local Component: StructureComponent = {}

	--Component.PositionalOffset = SerializeCFrame(
	--	CFrame.new(DeserializeCFrame(self.origin.AbsoluteWorldPosition).Position - Model.WorldPivot.Position)
	--)
	
	Component.SerializedCFrame = SerializeCFrame(Model.WorldPivot)
	Component.StructureType = StructureType

	self.structureComponents[Model] = Component
	return Component
end

--[=[
	Removes a StructureComponent from the tracker.
	
	@param Model Model the Model to remove.
]=]
function PlacementStructure:RemoveStructureComponent(Model: Model): nil
	if Model and self.structureComponents[Model] then
		self.structureComponents[Model] = nil
	end
end

--[=[
	Reconstructs the original CFrame of a structure's component
	
	@param Position Vector3 The AbsoluteWorldPosition or PositionalOffset of the component
	@param Rotation CFrame The orientation of the component
	@return CFrame The reconstructed CFrame of the structure's component
]=]
local function ReconstructCFrame(Position: Vector3, Rotation: CFrame): CFrame
	return CFrame.new(Position) * Rotation
end
--[=[
	Rebuilds the structure.
	@return A Model that represents the reconstructed Structure from the Datastores.
]=]
function PlacementStructure:RebuildStructure(): Model
	local StructureOrigin: StructureOrigin = self.origin

	local Model = Instance.new("Model")

	local OriginInstance = ReplicatedStorage.PlacementSystem.Models[StructureOrigin.StructureType]:Clone() -- TODO: Instantiate StructureOrigin.StructureType (e.g a chair, etc)
	-- OriginInstance:PivotTo(ReconstructCFrame(StructureOrigin.AbsoluteWorldPosition, StructureOrigin.Rotation))
	
	--local originCF = DeserializeCFrame(StructureOrigin.AbsoluteWorldPosition) * DeserializeCFrame(StructureOrigin.Rotation)
	local originCF = DeserializeCFrame(StructureOrigin.SerializedCFrame)

	OriginInstance:PivotTo(originCF)
	OriginInstance.Parent = Model

	for _, structureComponent: StructureComponent in self.structureComponents do
		local ComponentInstance: Model =
			ReplicatedStorage.PlacementSystem.Models[structureComponent.StructureType]:Clone() -- TODO: Instantiate StructureComponent.StructureType (e.g a chair, etc)
		-- ComponentInstance:PivotTo(ReconstructCFrame(
		-- 	StructureOrigin.AbsoluteWorldPosition + structureComponent.PositionalOffset, -- Add the offset (or difference) to the origin to calculate the "end" or original position
		-- 	StructureOrigin.Rotation
		-- ))
		
		--local componentCF = originCF *  DeserializeCFrame(structureComponent.PositionalOffset) * DeserializeCFrame(structureComponent.Rotation)
		local componentCF = DeserializeCFrame(structureComponent.SerializedCFrame)
		ComponentInstance:PivotTo(componentCF)
		ComponentInstance.Parent = Model
	end
	return Model
end

--[=[ Connections ]=]
Players.PlayerAdded:Connect(RetrieveAndCachePlacementsFromStore)
ServerHandlerRemote.OnServerInvoke = HandleClientRequests

return PlacementStructure
