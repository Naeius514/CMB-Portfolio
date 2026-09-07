--[=[

    Handler for Shinobi and Lore Actors.
]=]

-- TODO: Put the TYPES in ServerScriptService or something; the client may not need to see all that information.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CORE_DECREMENT_WAIT_PERIOD = 10
local CORE_DECREMENT_RATE = (100 / 600) -- Core Amount / Second 

-- Dependencies (make sure none of these yield)
local XPService = require(script.Parent.Classes.ProgressionClass);
local ShinobiClass = require(script.Parent.Classes.Shinobi);
local InventoryClass = require(script.Parent.Classes.InventoryClass);
local DataManager = require(script.Parent.Classes.DataManager);
local PropertyClass = require(script.Parent.Classes.Property);
local CoresClass = require(script.Parent.Classes.Cores);
local TagUser = require(script.Parent.Classes.TagUser);
local ToolClass = require(script.Parent.Classes.ToolClass);

--TODO: Loading of individual modular components (like Properties) might error/fail, obstructing other objects (like Inventory or whatever else) from loading--obstructing the flow of logic.
local StoredObjectsForAllPlayers: {[Player]: PlayerObjects} = {};
type PlayerObjects = {
	Data: any,
	Progression: any,
	Cores: any,
	TagUser: any,
	Inventory: any,
	Shinobi: any
}
local function OnPlayerAdded(Player: Player)
	task.wait(2)

	local PlayerObjects: PlayerObjects = {}

	-- Retrieve the data of the newly joining user.
	PlayerObjects.Data = DataManager:GetDataFor(Player);

	-- Create Progression (XPService) object
	PlayerObjects.Progression = XPService.new(PlayerObjects.Data);

	-- Create a Cores object for the player;
	PlayerObjects.Cores = CoresClass.new(Player, PlayerObjects.Data.Stats.Cores);

	-- Instantiate a TagUser object for the player
	PlayerObjects.TagUser = TagUser.new(Player);
	Player.CharacterAdded:Connect(function()
		PlayerObjects.TagUser:Setup(); -- Initialise health and other vitals each time they respawn
	end)

	-- Instantiate an Inventory object for the player
	PlayerObjects.Inventory = InventoryClass.new(Player, PlayerObjects.Data);

	-- Instantiate a Shinobi object for them.
	PlayerObjects.Shinobi = ShinobiClass.new(Player, PlayerObjects.Data, PlayerObjects.TagUser, PlayerObjects.Inventory);

	-- -- Load their properties into the game
	-- if Data.Properties then -- TODO: may need to check if the table is just empty instead of nil
	--     warn("HELLO!")
	--     PropertyClass(Player, Data);
	-- end

	StoredObjectsForAllPlayers[Player] = PlayerObjects;
end

local function OnPlayerLeaving(Player: Player)
	-- Serialize their Inventory
	local PlayerObjects = StoredObjectsForAllPlayers[Player];
	PlayerObjects.Inventory:Serialize();
	-- TODO: Write this to the DataManager

	-- Remove them from the table
	StoredObjectsForAllPlayers[Player] = nil;
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerLeaving)
