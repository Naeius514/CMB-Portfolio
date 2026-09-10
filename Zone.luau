--[=[
    Zone.luau

    Zones are objects that border areas following the
    game's addressing scheme. 

    They are capable of tracking information that happens inside of itself
    which can be useful to other Classes.

    Workspace --> Country --> Region --> Subregion --> Town.

    Furthermore, this Class instantiates the Zones for each area automatically,
    and exposes the Zones for other scripts.
    The Constructor is only used internally.

    REQUIREMENTS TO CONSTRUCT A ZONE:
    1. A "_BOUNDARY" part is required in each region to determine any given region's
    bounds. 
    2. Countries must have a CS tag named "COUNTRY" as Zones are only constructed from Countries as the root. 
    
    TODO: Add a autodetection system that 

    TODO: Maybe make oceans use Zones from this module
]=]

--[[
TODO:
    1. FIX TIMEZONE DAY/NIGHT CYCLES
    2. ADD TEMPERATURE DIPS AT NIGHT USING SINE WAVE
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalSettings = require(ReplicatedStorage.GlobalSettings)
local WeatherTypes = require(ReplicatedStorage.Types.Weather)
local ZonePlus = require(ReplicatedStorage.Packages.ZonePlus)

local ShinobiClass = require(script.Parent.Shinobi)

local Zone: ZoneInstance = {}
Zone.__index = Zone

export type Zone = {
	Zone: any, -- specifically an instance of the ZonePlus module we're using.
	WeatherData: WeatherTypes.Weather & { LocalMaxTemp: number },
	Parent: Zone,
}

type ZoneDetails = {
	CFrame: CFrame,
	Size: Vector3,
}

local DAMAGE_INTERVAL = 60 -- In seconds. Is the "Second" in DAMAGE per SECOND.

--[=[
    Randomizes the temperature for a given area's Weather.
    and assigns a LocalMaxTemp.

    The Max value will always be the current temperature of the current Area.
    It's still in a range so the child has bounds to randomize its value between.
]=]
local function RandomizeTemperatureForArea(AreaWeather: WeatherTypes.Weather): WeatherTypes.Temperature
	local CurrentSeason: WeatherTypes.Season = AreaWeather.CurrentSeason or "Normal"
	local SelectedCurrentTemp: WeatherTypes.Temperature = nil -- Will be assigned momentarily

	local randomizedLocalMaximumTemp =
		math.random(AreaWeather.Temperatures[CurrentSeason].Min, AreaWeather.Temperatures[CurrentSeason].Max)

	SelectedCurrentTemp = {
		Min = AreaWeather.Temperatures[CurrentSeason].Min, -- Retain the original minimum value.
		Max = randomizedLocalMaximumTemp, -- The value we just randomized.
	}
	return SelectedCurrentTemp
end

--[=[
    Recursive function used by InstantiateZones that creates Zones for areas (countries, regions, subregions, etc)
        
    
    Uses the "_Boundary" parts associated with each region to determine
    the boundary of the Zone

    Randomizes temperature values for the Zone -- writes directly to the temperature values nested within the Seasons.
    So only read from the Current Season.

    @param Parent Zone | "Root" The parent zone of this zone. If the parent is declared "NoParent," it is the
        highest in its hierarchy and has no parents.
]=]
local function LoadBoundary(Area: Folder, WeatherData: WeatherTypes.Weather, Parent: Zone | "NoParent")
	local BoundaryPart: Part = Area:FindFirstChild("_BOUNDARY")
	local ZONE: Zone = nil -- Will be assigned momentarily

	if not BoundaryPart then
		warn("SERVER: Boundary NOT FOUND for: ", Area.Name)
		return -- Nothing downstream can proceed without a valid ZONE.
	end

	-- This is where the Parent is assigned.
	-- Zones that don't have a Parent will be given: "NoParent"
	-- Zones with Parents will have an actual Zone instance for their Parent property.
	ZONE = Zone.new(Parent, Area.Name, {
		CFrame = BoundaryPart.CFrame,
		Size = BoundaryPart.Size,
	}, WeatherData)
	--BoundaryPart:Destroy(); -- Represents the current Zone just created. COMMENTED OUT: Destroys before the Client gets to load it in

	for _, SubArea: Folder in pairs(Area:GetChildren()) do -- Could possibly switch to using CS tags like below
		if SubArea:IsA("Folder") then
			-- Then instantiate SubArea as one of its children

			-- Retrieve its Weather Data first
			-- Does this SubArea have unique Weather Patterns authorized?
			local CustomRegionWeather: WeatherTypes.Weather = ZONE.WeatherData.RegionsThatDeviate[SubArea.Name]
			local ChildWeatherDataToBeUsed: WeatherTypes.Weather = nil -- Will be assigned momentarily
			if CustomRegionWeather then -- They may or may not have custom weather patterns authorized
				-- Assigns the custom region weather as the weather to be used
				ChildWeatherDataToBeUsed = CustomRegionWeather
			else
				-- Otherwise:
				-- Assign a temperature that is computed relative to the current ZONE's (or the child's to-be parent's) temperature range.
				-- Cloned (not a direct reference) so mutating the child's temperature doesn't corrupt
				-- the parent's WeatherData or any sibling SubAreas sharing the same table.
				ChildWeatherDataToBeUsed = table.clone(WeatherData)
				ChildWeatherDataToBeUsed.Temperatures = table.clone(WeatherData.Temperatures)

				-- Modify the temperatures only for the current season.
				local CurrentSeason: WeatherTypes.Season = WeatherData.CurrentSeason or "Normal"
				ChildWeatherDataToBeUsed.Temperatures[CurrentSeason] = RandomizeTemperatureForArea(WeatherData) -- The WeatherData of the current ZONE is passed; not the child's.
			end
			-- Now instantiate it as a child
			LoadBoundary(SubArea, ChildWeatherDataToBeUsed, ZONE)
		end
	end
end

--[=[
    Instantiates Zones for the SERVER.

    Attempts to load the Weather patterns for the Zone.
]=]
local function InstantiateZonesOnServer()
	for _, Area: Folder in pairs(CollectionService:GetTagged("COUNTRY")) do
		-- Attempt to find the weather data of this COUNTRY
		local WeatherData = GlobalSettings.COUNTRY_WEATHER_DATA[Area.Name]
		if WeatherData then
			-- Load the boundaries of this country and all of its children using the recursive function below:
			LoadBoundary(Area, WeatherData, "NoParent")
		else
			warn("ERROR LOADING WEATHER DATA: NO WEATHER DATA FOUND FOR COUNTRY: " .. Area.Name .. "")
		end
	end
end

local COMPRESSION = 1 / 10 -- Controls how how slow the damage curve increases by compressing it. Vertical stretch/compression = a in a(x^2)
-- Tuned by feel; feel free to change

--[=[
    Computes the core drain or health damage from being in extreme temperatures.
]=]
local function getDamageFromExtremeTemperatures(currentTemp: number)
	if currentTemp <= GlobalSettings.EXTREME_TEMPERATURES.EXTREME_COLD_TEMP then
		return COMPRESSION * (currentTemp - GlobalSettings.EXTREME_TEMPERATURES.EXTREME_COLD_TEMP) ^ 2
	elseif currentTemp >= GlobalSettings.EXTREME_TEMPERATURES.EXTREME_HEAT_TEMP then
		return COMPRESSION * (currentTemp - GlobalSettings.EXTREME_TEMPERATURES.EXTREME_HEAT_TEMP) ^ 2
	end
end

export type ZoneInstance = {

	Name: string,
	Parent: Zone | "NoParent",
	Zone: any,
	WeatherData: WeatherTypes.Weather,
	TemperatureInCurrentSeason: WeatherTypes.Temperature,
	PlayersInZone: { Player },

	--[=[
        Checks if the player is within an extreme temperature

    ]=]
	AttemptToInduceExtremeTemperatureConditions: (Player: Player) -> nil,
}
function Zone.new(
	Parent: Zone | "NoParent",
	Name: string,
	ZoneDetails: ZoneDetails,
	WeatherData: WeatherTypes.Weather
): ZoneInstance
	local self: ZoneInstance = setmetatable({}, Zone)
	self.Name = Name
	self.Parent = Parent
	self.Zone = ZonePlus.fromRegion(ZoneDetails.CFrame, ZoneDetails.Size)
	self.WeatherData = WeatherData
	self.TemperatureInCurrentSeason = self.WeatherData.Temperatures[WeatherData.CurrentSeason or "Normal"].Max -- Max is always the current temp.
	self.PlayersInZone = {} :: { Player }

	local visualizer = Instance.new("Part")
	visualizer.Anchored = true
	visualizer.CFrame = ZoneDetails.CFrame
	visualizer.Size = ZoneDetails.Size
	visualizer.Transparency = 0.5
	visualizer.CanCollide = false
	visualizer.Parent = workspace
	visualizer.Color = Color3.fromRGB(0, 0, 255)

	warn(Zone, self)
	-- TODO: Recount players within the Zone occassionally
	self.Zone.playerEntered:Connect(function(Player: Player)
		self.PlayersInZone[Player] = Player

		self:AttemptToInduceExtremeTemperatureConditions(Player)
		print(Player.Name .. " entered: ", self.Name)
		print("Temperature:", self.WeatherData.Temperatures.Normal.Max)
	end)

	self.Zone.playerExited:Connect(function(Player: Player)
		self.PlayersInZone[Player] = Player

		print(Player.Name .. " left: ", self.Name)
	end)

	warn(self)

	return self
end

--[=[
    Checks if the player is within an extreme temperature range
    and induces the suitable consequences.



]=]
function Zone:AttemptToInduceExtremeTemperatureConditions(Player: Player)
	local Temperature = self.TemperatureInCurrentSeason

	-- Determines if the user is in an extreme temperature range
	local IsExtreme: "COLD" | "HOT" | "NEITHER" = if Temperature
			< GlobalSettings.EXTREME_TEMPERATURES.EXTREME_COLD_TEMP
		then "COLD"
		elseif Temperature > GlobalSettings.EXTREME_TEMPERATURES.EXTREME_HEAT_TEMP then "HOT"
		else "NEITHER"

	-- If IsExtreme ~= "NEITHER", then the player is in extreme temperature that is either too hot or too cold
	if IsExtreme ~= "NEITHER" then
		warn("IS EXTREME: ", IsExtreme, Temperature)

		-- Check cores
		local Shinobi = ShinobiClass:getShinobiFromPlayer(Player)
		warn(Shinobi)
		local Cores = Shinobi.Data.Stats.Cores

		-- Determine if any core is above zero.
		local IsAnyCoreHigherThanZero = false
		for _, core in pairs(Cores) do
			if core > 0 then
				IsAnyCoreHigherThanZero = true
				break
			end
		end

		local damage = getDamageFromExtremeTemperatures(Temperature)
		print("XDAMAGE: ", damage)
		Shinobi.TagUser:DamagePerSecond({
			DamagePerSecondRate = damage / DAMAGE_INTERVAL,
			-- After "DAMAGE_INTERVAL" seconds, the amount "damage" will be dealt
			-- But, we apply the damage using DeltaTime via :DamagePerSecond, so it appears to happen continously rather than in discrete chunks.
		})

		-- if IsAnyCoreHigherThanZero then -- If so, drain the cores faster.
		--     local damage = getDamageFromExtremeTemperatures(Temperature);
		--     warn(damage);
		--     Shinobi:changeCoreDecrementMultiplier(damage);

		-- end
	else
		warn("IS NOT EXTREME:", Temperature)
	end
end

InstantiateZonesOnServer()
return {}
