export type Temperature = {
	Max: number,
	Min: number,
}

-- A "Storm" is any modifier that changes the scenery and atmosphere. Could even be fog or light rain. May need to define a module that defines each Storm.
-- Each type is essentially
type Storm = "Thunderstorm" | "Sandstorm" -- Add more as needed

type RegionName = string

--[[
For the field titled "RegionsThatDeviate"
 If the RegionName explicitly matches the name of any region or subregion in the workspace,
 then that Region will be allowed to have its OWN unique weather patterns that are allowed to
 completely DEVIATE from the rest of the hierarchy.

 It is best practice to do
    Workspace.Country.Region.Name or Workspace.Country.Region.Subregion.Name when declaring to ensure 100% matchup.
 ]]

export type Weather = {
	CurrentSeason: Season, -- HARDCODE THIS IN GLOBALSETTINGS.LUAU!
	Timezone: Timezone,
	Temperatures: {
		Normal: Temperature,
		Summer: Temperature,
		Winter: Temperature,
	},
	Storms: { Storm },

	RegionsThatDeviate: { [RegionName]: { Weather } },
}

export type Season = "Normal" | "Summer" | "Winter"
-- "Normal" is what the Area would look like if there weren't seasons. It will always be assumed to be the default if CurrentSeason is not specified.

export type Timezone = "RST" | "AST" | "LST" | "WST" | "MST"

export type Timezones = {

	-- Master Clock = Global Coordinated Time (GCT)
	RST: number, -- Rock Standard Time
	AST: number, -- Ame Standard Time
	LST: number, -- Leaf Standard Time
	WST: number, -- Whirpools Standard Time
	MST: number, -- Mist Standard Time
}

return {}
