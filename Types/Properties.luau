--[=[

    Declares types for properties/territories within the Shinobi World.

]=]

local Items = require(script.Parent.Items)

export type Properties = { Property }

export type Unit = (Model | Folder) & { -- Represents the structure physical property in the Workspace. It is the physical building the address points to.
	Furniture: Folder,
	PropertyId: string, -- ACCESSED USING :GetAttribute() -- Used as 2-step verification. Address and PropertyId of the physical and logical properties must both match. Generated using :GUID()
}
export type ResidentialBuilding = (Model | Folder) & {
	Units: Unit,
}

export type Category = "RESIDENCE" | "BUSINESS"
export type Property = { -- Represents the "logical" property in the Player's data.
	Address: string,
	Storage: { Items.Item },
	Category: Category,
	PropertyId: string, -- Used as 2-step verification. Address and PropertyId of the physical and logical properties must both match. Generated using :GUID()
	OwnedModules: {}?, -- Modules that "add onto" existing furniture within the Property TODO: Define owned furniture
}

export type ActiveProperty = Property & {
	Owner: Player, -- Could be an Organization
	Building: Unit,
} -- An actively loaded-in property in the game. The logical and physical structures are temporarily merged.

export type Furniture = Model -- The Furniture's PrimaryPart will be where ProximityPrompt is placed.

return {}
