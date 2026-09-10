--[=[

	Inventory.spec.luau

	Includes unit tests to ensure that the InventoryClass works.

]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect
local beforeEach = JestGlobals.beforeEach

local Remotes = require(ReplicatedStorage.Remotes)
local RemoteFunction = Remotes:GetFunction("Inventory")

local InventoryClass = require(script.Parent.Parent.Parent.Classes.Inventory)




--[[
	If there is anything that doesnt have a keycode in the Toolbar then verify that the System
	puts it in the Backpack

]]


local function makeFakePlayerData(toolbar, backpack)
	return {
		Inventory = {
			Toolbar = toolbar or {},
			Backpack = backpack or {},
		},
	}
end

describe("Equip / Unequip via RemoteFunction.OnServerInvoke", function()
	local FakePlayer = { Name = "TestPlayer", UserId = 1 }

	it("returns false when equipping a Motor6D that doesn't exist in the container", function()
		local PlayerData = makeFakePlayerData()
		InventoryClass.new(FakePlayer, PlayerData)

		local fakeMotor6D = Instance.new("Motor6D")
		local response = RemoteFunction.OnServerInvoke(FakePlayer, "equip", fakeMotor6D, "Toolbar")

		expect(response).toBe(false)
		fakeMotor6D:Destroy()
	end)

	it("returns false when equipping with an invalid (non-Motor6D) ToolConnector", function()
		local PlayerData = makeFakePlayerData()
		InventoryClass.new(FakePlayer, PlayerData)

		local response = RemoteFunction.OnServerInvoke(FakePlayer, "equip", "not a motor6d", "Toolbar")

		expect(response).toBe(false)
	end)

	it("returns false when unequipping with nothing currently equipped", function()
		local PlayerData = makeFakePlayerData()
		InventoryClass.new(FakePlayer, PlayerData)

		local response = RemoteFunction.OnServerInvoke(FakePlayer, "unequip")

		expect(response).toBe(false)
	end)

	it("warns and does not error when no Inventory exists for the given Player", function()
		local UnknownPlayer = { Name = "GhostPlayer", UserId = 999 }
		expect(function()
			RemoteFunction.OnServerInvoke(UnknownPlayer, "equip", Instance.new("Motor6D"), "Toolbar")
		end).never.toThrow()
	end)
end)