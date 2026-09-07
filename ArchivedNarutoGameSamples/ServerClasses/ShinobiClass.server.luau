local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ShinobiTypes = require(ReplicatedStorage.Types.Shinobi)
local ItemTypes = require(ReplicatedStorage.Types.Items)
local StatsTypes = require(ReplicatedStorage.Types.Stats)
local TagUserTypes = require(ReplicatedStorage.Types.TagUser)

local Shinobi: ShinobiTypes.Shinobi = {}
Shinobi.__index = Shinobi

local activeShinobi: { [Player]: ShinobiTypes.Shinobi } = {}

-- core philosophy: Any changes to properties that gets saved will be written directly to Shinobi.Data.
-- Otherwise, they'll be a direct property of Shinobi
-- This is essentially what Tyrone did

--[=[
    Instantiates a new member of the Shinobi class.
    --TODO: Add types for the InventoryClass
]=]
function Shinobi.new(
	Player: Player,
	Data: ShinobiTypes.PlayerData,
	TagUser: TagUserTypes.TagUser,
	Inventory
): ShinobiTypes.Shinobi
	warn("FIRED!")
	local self: ShinobiTypes.Shinobi = setmetatable({}, Shinobi)
	self.Player = Player
	self.Data = Data
	self.TagUser = TagUser
	self.Inventory = Inventory

	self.States = {
		IsBlocking = false,
	}

	self.CoreDecrementMultiplier = 1 -- USE Shinobi:changeCoreDecrementMultiplier) TO CHANGE 

	warn(self)
	activeShinobi[Player] = self
	return self
end

--[=[
    Updates the core decrement multiplier.
    A higher value > 1 causes cores to decrement much faster.
    A lower value < 1 causes cores to decrement slowly.

    Zone.luau will execute this function for any given Shinobi to induce effects caused by
    Temperature swings. 

]=]
function Shinobi:changeCoreDecrementMultiplier(newMultiplierValue: number)
	self.CoreDecrementMultiplier = newMultiplierValue
end
--[=[
    A convienent method for easily accessing a player's
    chakra amount. 
]=]
function Shinobi:getChakraAmount()
	return self.Data.Stats.Body.ChakraAmount
end
--[=[
    Retrieves a Shinobi object for a player, allowing the function caller
        to access its attributes and methods.
]=]
function Shinobi:getShinobiFromPlayer(Player: Player): ShinobiTypes.Shinobi | nil
	warn(activeShinobi)
	return activeShinobi[Player]
end

--[=[
    Update a Shinobi's Cores when they eat something.
]=]
function Shinobi:Consume(Consumable: ItemTypes.Consumable)
	local Cores: StatsTypes.Cores = self.Data.Stats.Cores
	Cores.Wellbeing += Consumable.Protein
	Cores.Chakra += Consumable.Carbs
end

return Shinobi
