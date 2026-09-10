--[[
The purpose of this module is to manage and track all relevant player-specific data and states, 
including rank, village affiliation, currency, and status effects (such as being stunned or bleeding), 
as well as providing functionality to modify these states and saved data
]]

--[[
The aim of this system is to optimize character state replication, 
minimize network and memory usage, and eliminate unnecessary data 
transmission. For example, two players on opposite ends of the map 
don’t need to know if the other is stunned or blocking, yet if we use
folders, valueobjects, attributes, or any other instances which automatically
replicate to all clients, then resources are still being consumed to transmit this data, 
negatively and unnecessarily impacting performance. Additionally, the replication of extra metadata, 
such as properties from Folders and ValueObjects, leads to further memory waste and is the reason behind 
the OOP approach.

Source: https://devforum.roblox.com/t/lets-talk-about-attributes-valueobjects-and-instances/1918761

If a client requires real-time access to a player's state, they can request a 
subscription. The server will then send updates using FireClient() on a 
RemoteEvent whenever the state changes, with the understanding that the 
subscription will be revoked when no longer needed. The client is responsible 
for organizing its own records. If a client needs to retrieve specific information 
without requiring long-term real-time access, they can use InvokeServer to request 
the necessary state.

If a server script needs access to a player's state, this module can be 
required, and :GetActorFromPlayer() can be used to retrieve the relevant data.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

-- Modules

local CharacterAppearance = require(script.Parent.CharacterAppearance)
local Sift = require(ReplicatedStorage.Packages.Sift)
local GoodSignal = require(ReplicatedStorage.Packages.Signal)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Types = require(ReplicatedStorage.Shared.Types)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Constants
local KNOCKED_HEALTH_THRESHOLD = 1 -- A player's health must be less than or equal to this value to be considered K.O'ed or Knocked

-- Variables
local NetworkSubscription = Remotes:GetEvent("NetworkSubscription")
local TagHumanoid = require(script.Parent.TagHumanoid)

-- Object
local PlayerObject = {}
PlayerObject.__index = PlayerObject
PlayerObject.Players = {}

-- Constructor
function PlayerObject.new(Player: Player, Profile)
	local self = setmetatable({}, PlayerObject)

	-- Public Variables
	self.Player = Player
	self.Profile = Profile -- Saved Data

	-- Load in accessories, genetics, etc
	self.CharacterAppearance = CharacterAppearance.new(Player, Profile)

	self.States = { -- Status Effects
		IsAttacking = false,
		IsBlocking = false,
		IsDodging = false,
		IsStunned = false,
		IsBleeding = false,
		IsKnocked = false,
		IsCasting = false, -- Is weaving handsigns to perform a jutsu

		PunchDisabled = false,
		ComboCount = 0, -- for M1s

		Chakra = 0,
		Stamina = 0,
		Strength = 0,
		LastAttackedBy = nil,
	}

	-- Private Variables
	self._stateChangedListener = GoodSignal.new() -- Other scripts may connect
	self._activeStun = false
	self:_initialiseSubscriptions()

	PlayerObject.Players[Player] = self -- Make sure to remove the player from this table when leave

	return self
end

-- Private Methods
function PlayerObject:InitialiseSubscriptions()
	-- Initialise Network Subscriptions
	--[[
		How it works:
		Clients can "subscribe" to this server-sided PlayerObject to recieve a notification whenever the state it has subscribed has changed
	]]
	-- This copies the States table and replaces each state's (key) value with a table which will include all players who are subscribed to that specific state.
	self._eventSubscriptions = Sift.Dictionary.copy(self.States)
	for SubscriptionType in self._eventSubscriptions do
		self._eventSubscriptions[SubscriptionType] = {} :: { Player }
	end

	self._stateChangedListener:Connect(function(UpdatedCharacterStatus: Types.CharacterStatus)
		local Status = self:GetStatus(UpdatedCharacterStatus)
		if Status == nil then
			return
		end

		for _, Subscriber in self._eventSubscriptions[UpdatedCharacterStatus] do
			warn(Subscriber)
			NetworkSubscription:FireClient(
				Subscriber,
				Types.SubscriptionOptions.UpdateLocalCache,
				self.Player,
				UpdatedCharacterStatus,
				Status
			)
		end
	end)

	self:SubscribeTo(self.Player, "IsStunned")
	self:SubscribeTo(self.Player, "ComboCount")
end

-- Public Methods
function PlayerObject:GetPlayerObject(Player: Player)
	--TODO: Check if "Player" could be an NPC (which of course wouldn't be found in Players service)
	if not Player then
		return
	end

	Player = Players:FindFirstChild(Player.Name)
	if not Player then
		return
	end

	local Object = self.Players[Player]
	return Object or false
end

-- Use this function in other server scripts instead of simply requiring it and using PlayerObject.States.IsStunned for example
function PlayerObject:GetStatus(StatusName: Types.CharacterStatus)
	return self.States[StatusName]
end

function PlayerObject:SubscribeTo(Subscriber: Player, StatusName: Types.CharacterStatus)
	table.insert(self._eventSubscriptions[StatusName], Subscriber)

	NetworkSubscription:FireClient(
		Subscriber,
		Types.SubscriptionOptions.UpdateLocalCache,
		self.Player,
		"NewSubscription"
	)
end

function PlayerObject:UpdateStatus(StatusToUpdate, Value, FireUpdateSignal)
	self.States[StatusToUpdate] = Value

	if FireUpdateSignal ~= true then
		self._stateChangedListener:Fire(StatusToUpdate)
	end
end

function PlayerObject:TagHumanoid(Attacker, ListOfEffects: { Damage: number, Stun: number, Bleed: number }) -- Alternative to individually calling :Stun, :TakeDamage, etc
	for EffectName, Effect in ListOfEffects do
		if TagHumanoid[EffectName] then
			TagHumanoid[EffectName](self, Effect, Attacker)
		end
	end
end

function PlayerObject:TakeDamage(DamageAmount, AttackedBy: Player?)
	local Character = self.Player.Character
	local Humanoid = Character.Humanoid

	local Health = math.max(Humanoid.Health - DamageAmount, KNOCKED_HEALTH_THRESHOLD)
	Humanoid.Health = Health

	-- Player is KNOCKED
	if Health <= KNOCKED_HEALTH_THRESHOLD then
		self.States.IsKnocked = true
		self._stateChangedListener:Fire("IsKnocked")

		local Connection

		-- Logic to unknock a player if they regain health
		Connection = self.Player.Character.Humanoid:GetPropertyChangedSignal("Health"):Connect(function(L)
			if Character.Humanoid.Health > KNOCKED_HEALTH_THRESHOLD then
				self.States.IsKnocked = false
				self._stateChangedListener:Fire("IsKnocked")

				Connection:Disconnect()
				Connection = nil
			end
		end)
	end

	if AttackedBy and typeof(AttackedBy) == "Instance" and AttackedBy:IsA("Player") then
		self.States.LastAttackedBy = AttackedBy
		-- TODO: Fire the subscription signal.
	end
end

-- @Params: AddToStunDuration: If the player is already stunned, will stack the duration ontop of the current stun duration.
-- If AddToStunDuration is false and the player is currently stunned, the function will disregard the stun request.
function PlayerObject:Stun(Duration: number, StackStunDuration: boolean) --Rename to IsCompounding
	if self.States.IsStunned and not StackStunDuration then
		return
	end

	local Character = if self.IsNPC then self.Player else self.Player.Character
	local Humanoid = Character.Humanoid
	local StartTime = tick()

	-- TODO: Wrap this into a loop so that if an exploiter tries to update their speed, it will set it back to 0.
	-- TODO: Prohibit jumping.
	Humanoid.WalkSpeed = 0

	if self._activeStun then -- Check self.IsStunned too?
		self._activeStun.promise:cancel()
		Duration = Duration + (StartTime - self._activeStun.timeStarted)
	else
		self.States.IsStunned = true
		self._stateChangedListener:Fire("IsStunned")
	end

	self._activeStun = {
		timeStarted = StartTime,
		promise = Promise.delay(Duration):andThen(function()
			Humanoid.WalkSpeed = 16 -- Ease back up
			self.States.IsStunned = false
			self._stateChangedListener:Fire("IsStunned")
			self._activeStun = false
		end),
	}
end

return PlayerObject
