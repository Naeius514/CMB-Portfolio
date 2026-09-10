--[=[

	XPService.spec.luau

	This module contains unit tests for the XPService.luau.

]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

local XPService = require(ServerScriptService.Classes.XPService)

local function requirementForRank(rank: number): number
	return math.pow(135 / 100, rank)
end

describe("Make sure a LetterRank value exists for every possible numerical Ranks 1-21", function()
	it.each({
		{ 1, "F-" },
		{ 2, "F" },
		{ 3, "F+" },

		{ 4, "E-" },
		{ 5, "E" },
		{ 6, "E+" },

		{ 7, "D-" },
		{ 8, "D" },
		{ 9, "D+" },

		{ 10, "C-" },
		{ 11, "C" },
		{ 12, "C+" },

		{ 13, "B-" },
		{ 14, "B" },
		{ 15, "B+" },

		{ 16, "A-" },
		{ 17, "A" },
		{ 18, "A+" },

		{ 19, "S-" },
		{ 20, "S" },
		{ 21, "S+" },
	})("Make sure that Rank %d maps to %s", function(rank, expectedLetter)
		expect(XPService:getLetterRank(rank)).toBe(expectedLetter)
	end)

	it("Make sure LetterRanks after 21 do NOT exist.", function()
		for rank = 22, 1000 do
			expect(XPService:getLetterRank(rank)).toBeNil()
		end
	end)
end)

describe("GrantXP", function()
	it("For XPService:GrantXP(RewardType: string) Do nothing if RewardType has no corresponding multiplier", function()
		-- Mock Player Data
		local service = XPService.new({
			Stats = {
				Progression = {
					Rank = 1,
					XP = 50,
				},
			},
		})

		service:GrantXP("NotARealRewardType")
		expect(service.Data.Stats.Progression.XP).toBe(50)
		expect(service.Data.Stats.Progression.Rank).toBe(1)
	end)

	it("Ensure that XP is AWARDED as a percentage of the next rank's requirement", function()
		-- Mock Player Data
		local service = XPService.new({ Stats = { Progression = { Rank = 1, XP = 0 } } })

		service:GrantXP("Kill") -- multiplier: 0.05
		local expectedXP = 0.05 * requirementForRank(2)
		expect(service.Data.Stats.Progression.XP).toBeCloseTo(expectedXP, 6)
	end)

	it("Ensure that player ranks up by exactly one when XP meets the next rank's requirement", function()
		local nextReq = requirementForRank(2)
		local service = XPService.new({ Stats = { Progression = { Rank = 1, XP = nextReq } } })
		service:GrantXP("Kill")
		expect(service.Data.Stats.Progression.Rank).toBe(2)
	end)
end)

describe("RemoveXP", function()
	it("Do nothing if RewardType has no corresponding multiplier", function()
		local service = XPService.new({ Stats = { Progression = { Rank = 5, XP = 1000 } } })
		service:RemoveXP("NotARealRewardType")
		expect(service.Data.Stats.Progression.XP).toBe(1000)
		expect(service.Data.Stats.Progression.Rank).toBe(5)
	end)

	it("Ensure that XP is REMOVED as a percentage of the current rank's requirement", function()
		local service = XPService.new({ Stats = { Progression = { Rank = 5, XP = 1000 } } })
		service:RemoveXP("Kill") -- multiplier: 0.05
		local expectedLoss = 0.05 * requirementForRank(5)
		expect(service.Data.Stats.Progression.XP).toBeCloseTo(1000 - expectedLoss, 6)
	end)

	it("Do not derank below Rank 1", function()
		local service = XPService.new({ Stats = { Progression = { Rank = 1, XP = 0 } } })
		service:RemoveXP("Killed")
		expect(service.Data.Stats.Progression.Rank).toBe(1)
	end)
end)
