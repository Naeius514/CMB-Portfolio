--[=[

    XPService.luau

    This module handles all things pertaining to ranking, progression, XP, JP, etc.

]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage");

local ShinobiTypes = require(ReplicatedStorage.Types.Shinobi);
local ProgressionSettings = require(ReplicatedStorage.GlobalSettings.ProgressionSettings);


local Local = {};
local XPService: Progression = {};
XPService.__index = XPService;

-- These are relative multipliers (fractions of the current/next rank's XP requirement),
-- NOT flat XP amounts. See Milestone Curve documentation for why.
Local.GrantXPTable =
	{
		Kill = 0.05,
		Mission = 0.15,
		Artifact = 0.30,
		Killed = 0.45,
	}
type XPGrantTypes = "Kill" | "Mission" | "Artifact" | "Killed";

type Progression = {
	Data: ShinobiTypes.PlayerData,
}

--[=[

    Instantiates an Progression (XPService) object.
    An object is instantiated for every player via ShinobiService.luau

]=]
function XPService.new(PlayerData: ShinobiTypes.PlayerData): Progression
	local self: Progression = setmetatable({}, XPService);
	self.Data = PlayerData;

	return self;
end

--[=[
    Computes XP needed for each rank from the milestone curve.
]=]
function XPService:getRequirementsForRank(Rank: number): number
	-- Compute the XP requirement based on the Milestone Curve formula (as shown in the Documentation) and return the value
	return math.pow((135 / 100), Rank);
end

--[=[
    Grants XP to the player and allows them to rank up.
    The RewardType's multiplier is applied as a percentage of the XP required
    for the player's NEXT rank, so rewards automatically scale with the curve.
]=]
function XPService:GrantXP(RewardType: XPGrantTypes)
	-- Access Progression information from PlayerData.Stats.Progression
	local ProgressionData = self.Data.Stats.Progression;

	-- The GrantXP table contains relative multipliers, not flat XP.
	local relative_multiplier = Local.GrantXPTable[RewardType];
	if relative_multiplier == nil then
		return;
	end

	-- Guard against computing requirements for a nonexistent Rank 22.
	if ProgressionData.Rank >= 21 then
		return;
	end

	local xp_to_give = relative_multiplier * self:getRequirementsForRank(ProgressionData.Rank + 1);
	ProgressionData.XP += xp_to_give;

	-- If XP meets the requirements for the next rank, rank up.
	-- Loop in case a large XP gain crosses multiple rank thresholds at once.
	while ProgressionData.Rank < 21 do
		local XP_Requirement = self:getRequirementsForRank(ProgressionData.Rank + 1);
		if ProgressionData.XP < XP_Requirement then
			break;
		end
		ProgressionData.Rank = math.clamp(ProgressionData.Rank + 1, 1, 21);
	end
end

--[=[
    Removes XP from the player. Too much XP loss results in a derank.
    The RewardType's multiplier is applied as a percentage of the XP required
    for the player's CURRENT rank, so penalties automatically scale with the curve.
]=]
function XPService:RemoveXP(RewardType: XPGrantTypes)
	-- Access XP & Rank information from PlayerData.Stats.Progression
	local ProgressionData = self.Data.Stats.Progression;

	-- The GrantXP table contains relative multipliers, not flat XP.
	local relative_multiplier = Local.GrantXPTable[RewardType];
	if relative_multiplier == nil then
		return;
	end

	local currentRankRequirement = self:getRequirementsForRank(ProgressionData.Rank);
	local xp_to_take = relative_multiplier * currentRankRequirement;

	ProgressionData.XP -= xp_to_take;

	-- If XP falls below the requirements of the rank they are on, derank the player.
	-- Loop in case a large XP loss crosses multiple rank thresholds at once.
	while ProgressionData.Rank > 1 do
		local XP_Requirement = self:getRequirementsForRank(ProgressionData.Rank);
		if ProgressionData.XP >= XP_Requirement then
			break;
		end
		ProgressionData.Rank = math.clamp(ProgressionData.Rank - 1, 1, 21);
	end
end

--[=[
    Converts a numerical rank value to a String 
    letter rank value.

    NumericalRank number The numerical rank value to convert to a letter rank value.
]=]
function XPService:getLetterRank(NumericalRank: number): string?
	return ProgressionSettings.RANKS[NumericalRank];
end

--[=[
	Exposes an interface that the module that handles global bounty value can use 
	to obtain the Rank component for its computations.
]=]
function XPService:getRankComponentForBountyComputation(Rank: number): number
	return 100 * self:getRequirementsForRank(Rank);
end

return XPService;