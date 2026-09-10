--[=[

    Declares types for character/player/npc Stats.

]=]

export type Stats = {
	Progression: Progression,
	Body: Body,
	Cores: Cores,
}

export type Body = {
	ChakraAmount: number,
	ChakraPotency: number,
	ChakraControl: number,
	Vitality: number, -- Maximum health.
	PhysicalStrength: number,
}

export type Cores = {
	Wellbeing: number,
	Chakra: number,
	Marking: number,
}

export type Progression = {
	XP: number, -- Experience Points needed to Rank Up
	JP: number, -- Jutsu Points that can unlock Jutsu from the library
	Rank: number -- The current rank the Player is at

}
return {}
