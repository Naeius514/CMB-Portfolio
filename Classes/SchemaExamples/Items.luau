--[=[
    Declares types for various items within the Shinobi World.
]=]

-- TODO: May need to fix these all being strings
-- TODO: Include a "Name" attribute for each Item type. So different swords: Chokuto vs Katana, etc.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DojutsuTypes = require(ReplicatedStorage.Types.Dojutsu)

export type Tool = {
	Motor6D: Motor6D,
	ItemData: Item,
}
export type Item = { -- Uppermost
	--Type: "Item";
	Adornee: Model | Part, -- The visible component of the item, like a sword's body; needed for the Tool.
} --Consumable | Sword | Clothing | Scroll | Artifact;

export type Consumable = Item & { -- Subclass of Item
	Name: string,
	Type: "Consumable",
	Protein: number, -- Increases the Wellbeing Core
	Carbs: number, -- Increases the Chakra Core
	--TODO: Add attributes for injuries.
} --"Consumable";
export type TONIC = Consumable & {}

export type EyeItem = Item & { -- A handheld dojutsu (acquirable after scooping). See DOJUTSUSettings for explicit definitions
	Type: "EyeItem",
	DojutsuType: DojutsuTypes.DojutsuType,
}
export type Sword = "Sword"
export type Clothing = "Clothing"
export type Scroll = "Scroll"
export type Artifact = Model & {}

return {}
