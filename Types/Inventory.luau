--[=[

    Defines all Types for the Inventory Class
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShinobiTypes = require(ReplicatedStorage.Types.Shinobi)

export type InventoryObject = {

	-- Properties
	DeserializedInventory: DeserializedInventory,
	Player: Player,
	Data: ShinobiTypes.PlayerData,
	EquippedTool: DeserializedStandaloneTool | nil; -- The currently equipped tool
	carryCapacity: number,

	-- Constructor
	new: (Player: Player, Data: ShinobiTypes.PlayerData) -> InventoryObject,

	-- Add Tools
	AddStandaloneTool: (ObjectType: "Item" | "Jutsu", ObjectData: ItemDescription | JutsuDescription, IsTemporary: boolean, PositionInFolder: nil | number, OverrideWeight: boolean, DoIReturn: boolean | nil) -> DeserializedStandaloneTool | nil;
	AddFolderTool: (toolsToAdd: toolsToAdd) -> nil;
	AddDojutsu: () -> nil;

	-- Remove Tools
	RemoveStandaloneTool: () -> nil;
	RemoveFolderTool: () -> nil;
	RemoveDojutsu: () -> nil;

	Serialize: () -> nil;
}

export type DeserializedInventory = {
	Tools: { [Motor6D]: DeserializedStandaloneTool | DeserializedFolderTool }, -- The key is represented using Motor6D because the Motor6D is how the client will be able to tell the server which tool to equip.
	Accessories: {},
	--Dojutsu: DojutsuInventory, -- REMOVING. Use Data.Inventory.Dojutsu instead  Separate inventory solely for Dojutsu
}

export type SerializedInventory = { 
	Toolbar: {SerializedStandaloneTool | SerializedFolderTool}, -- The index/number determines the position in the toolbar
	Backpack: {SerializedStandaloneTool | SerializedFolderTool}, -- Same thing as a Toolbar technically except not visible within the immediate toolbar
	Accessories: {};
	Dojutsu: DojutsuInventory,  -- Separate inventory solely for Dojutsu
};

export type ClientInventory = {
	Toolbar: {[number]: DeserializedStandaloneTool | DeserializedFolderTool};
	Backpack: { DeserializedStandaloneTool | DeserializedFolderTool };
	Accessories: {};
	Dojutsu: DojutsuInventory;
}

--[=[   STANDALONE TOOLS    ]=]
export type SerializedStandaloneTool = {
	group: "standalonetool",
	type: "Jutsu" | "Item",
	contents: string, --Name of the item or the jutsu (string). Name will be serialized into the datastores to be retrieved later.
}

export type DeserializedStandaloneTool = {
	keycode: number | string,
	group: "standalonetool",
	type: "Jutsu" | "Item",
	tool: ToolObject, -- the actual object that was originally represented in SerializedStandaloneTool using SerializedStandaloneTool.contents encapsulated within a Tool object
}

export type ClientStandaloneTool = {
	group: "standalonetool",
	type: "Jutsu" | "Item",
	tool: ToolObject, -- the actual object that was originally represented in SerializedStandaloneTool using SerializedStandaloneTool.contents encapsulated within a Tool object
}

--[=[   FOLDER TOOLS    ]=]
export type SerializedFolderTool = {
	group: "foldertool",
	folder: { [string]: SerializedStandaloneTool | DojutsuSerializedTool },
}

export type DeserializedFolderTool = {
	keycode: number | string, -- Opens the folder
	group: "foldertool",
	folder: { [string]: DeserializedStandaloneTool | DojutsuDeserializedTool },
}

export type ClientFolderTool = {
	group: "foldertool",
	folder: { [string]: ClientStandaloneTool },
}

--[=[   TOOL CLASS    ]=]

export type ToolObject = {
	ObjectData: ItemDescription | JutsuDescription, --
	Motor6D: Motor6D, -- The actual connector that bridges `Item.Adornee` with the Character's arm
	IsTemporary: boolean,
	IsEquipped: boolean,

	new: (ObjectData: ItemDescription | JutsuDescription, IsTemporary: boolean) -> ToolObject,
}

--[=[	ITEMS & JUTSU	]=]
export type ItemDescription = {
	name: string,
	type: "Item",
	adornee: Model | Part, -- The handheld object that appears in the player's hand when equipped
	weight: number, -- However much weight the Item takes to store an item
}

export type JutsuDescription = {
	type: "Jutsu",
	name: string,
	minimumDamage: number,
	maximumDamage: number,

	--Tool: Tool, -- Represents the Jutsu in the Toolbar. When invoked, the Server will execute serverCallback and request nearby clients execute clientCallback.
	serverCallback: ModuleScript | (JutsuDescription) -> any, -- Point to a module in ServerScriptService; needs to be kept confidential from Client
	clientCallback: (JutsuDescription) -> any, -- Include the Client-sided code here directly.
}

--[=[	 DOJUTSU	]=]
export type DojutsuInventory = {
	Inventory: {[DojutsuType & DojutsuSuffix]: DojutsuProperties | DojutsuMSProperties};
	MissingEyes: {
		Left: boolean;
		Right: boolean
	}
};
export type DojutsuType = "Sharingan" | "Byakugan" | "Rinnegan";
export type DojutsuSuffix = "_Left" | "_Right" | "_Left_MS" | "_Right_MS" | "_Both";
export type DojutsuProperties = {
	abilities: {DojutsuSerializedTool};
	evolution: number;
	strain: number;
}
export type DojutsuMSProperties = DojutsuProperties & {isEternal: boolean};
export type DojutsuSerializedTool = {
	group: "dojutsutool";
	dojutsuType: DojutsuType;
	type: "Jutsu" | "Item";
	contents: string; --Name of the item or the jutsu (string). Name will be serialized into the datastores to be retrieved later.
}
export type DojutsuDeserializedTool = {
	keycode: number | string;
	group: "dojutsutool";
	dojutsuType: DojutsuType;
	type: "Jutsu" | "Item";
	tool: ToolObject; -- the actual object that was originally represented in SerializedStandaloneTool using SerializedStandaloneTool.contents encapsulated within a Tool object
}


--[=[	CLIENT	]=]
export type ClientDojutsuObject = {
    activationState: boolean;
    type: DojutsuType;
    sideOfFace: DojutsuSuffix;

    _vision: ColorCorrectionEffect | Frame;
	new: (Dojutsu: DojutsuType & DojutsuSuffix, Properties: DojutsuProperties | DojutsuMSProperties) -> nil;
	Toggle: (activationState: boolean) -> nil;
};


return {};