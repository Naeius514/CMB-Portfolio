local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Genetics = require(script.Parent.Genetics);
local Stats = require(script.Parent.Stats);

export type PlayerData = {
    Genetics: Genetics.Genetics;
    Properties: { Properties.Property };
    Inventory: { 
        Toolbar: {Inventory.SerializedStandaloneTool | Inventory.SerializedFolderTool}, -- The index/number determines the position in the toolbar
        Backpack: {Inventory.SerializedStandaloneTool | Inventory.SerializedFolderTool}, -- Same thing as a Toolbar technically except not visible within the immediate toolbar
        Accessories: {};
        Dojutsu: DojutsuInventory,  -- Separate inventory solely for Dojutsu
    };
    Stats: Stats.Stats;
}


export type Shinobi = {
    Data: PlayerData;
    TagUser: TagUser.TagUser;
    CoreDecrementMultiplier: number;
    States: {
        IsBlocking: boolean;
    }
}

return {};