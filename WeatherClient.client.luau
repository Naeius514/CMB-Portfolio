local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GlobalSettings = require(ReplicatedStorage.GlobalSettings)

local WeatherTypes = require(ReplicatedStorage.Types.Weather)
local WeatherClient = {}

--[=[
    Computes the Global Coordinated Time (GCT)

    currentTime = The current time  or How far we've progressed into the current day, measured in seconds.
    currentTime =  (currentTime % SECONDS_PER_DAY)
        The remainder gives the "excess" of the calculation, telling us how far into the day we are.
        returns a number between 0-1

    currentTime * FULL_DAY_CYCLE = currentTime * 24 Hours 
        This scales up that number into the full 0-24 hour cycle. 

    GCT = (currentTime / SECONDS_PER_DAY) * 24 [Could be Day 3, 4, etc]
]=]
function WeatherClient:getGCT()
	local currentTime = os.clock() % GlobalSettings.SECONDS_PER_DAY
	return (currentTime / GlobalSettings.SECONDS_PER_DAY) * GlobalSettings.FULL_DAY_CYCLE
end

function WeatherClient:getTimeInTimezone(Timezone: WeatherTypes.Timezone)
	local TimezoneShift = GlobalSettings.TIMEZONESHIFTS[Timezone]
	if TimezoneShift then
		return (self:getGCT() + TimezoneShift) % GlobalSettings.FULL_DAY_CYCLE -- Using modulo to ensire it wraps between 0-24. 
	end
end

--[=[
    The Timezone shifts are
    directly plugged into the sinusoidal
    sin( (1/24) * (currentClockTimeGCT - Shift) ) * 2 = Day/Night Cycle Wave

    Creating a value between -1 and 1 that corresponds to the normal 24-hour clock
    associated with the Timezone that can be used to assist in the creation of other systems.
]=]
function WeatherClient:NormalizeDayNightCycle(Timezone: WeatherTypes.Timezone)
	local TimezoneShift = GlobalSettings.TIMEZONESHIFTS[Timezone]
	if TimezoneShift then
		local angle = (1 / 24) * (self:getGCT() - TimezoneShift) * (2 * math.pi)
		return math.sin(angle)
	end
end

return WeatherClient
