--[=[

    Inventory.luau

    A class that provides a way to load in a player's inventory--
    their tools, dojutsu, jutsu, etc.
    
    Each Inventory "object" should be instantiated per player 
    and should be retrievable from their Shinobi object.

   During live gameplay,

**THE SERVER ONLY CARES ABOUT MOTOR6Ds**
The Server does not care about Foldertools or the Toolbar or the Backpack. 
The Server does not care about Keycodes for Tool validation.
	1. During deserialization, it will pull all of the standalones outside of the Folder (and Toolbar and Backpack) and they'll live in the same area/space as tools that were already standalone. 
	It effectively "discards" the whole "Containers" concept entirely and all Tools live in this O(1) hashmap.
	The Client cares about FolderTools and Toolbar and Backpack for organization, but when the Client asks to equip a tool, it'll simply send the tool's Motor6D
	During Serialization, the Server will ask the client for its organizational/structure and make everything tidy (nested into folders and such) again

Its kind of like putting your toys away after playing with them. From toys all over the same floor to distinct compartments.

	-- 	For the SERVER, all tools -- regardless of container or Folder -- live flat
	-- 	in a single hashmap, keyed by Motor6D:
	-- 	self.DeserializedInventory.Tools = {
	-- 		[Motor6D] = DeserializedStandaloneTool
	-- 		[Motor6D] = DeserializedStandaloneTool
	-- 		[Motor6D] = DeserializedStandaloneTool
	-- 	}

	-- 	For the CLIENT, organizes tools in the format of:
	-- 	Toolbar = {
	-- 		[Position/Keycode] = DeserializedStandaloneTool (just an example of an extra tool here)
	-- 		[Position/Keycode] = DeserializedFolderTool {
	-- 			group: "foldertool",
	-- 			folder: { 
	-- 				[Position/Keycode]: DeserializedStandaloneTool;
	-- 				[Position/Keycode]: DeserializedStandaloneTool;
	-- 				[Position/Keycode]: DeserializedStandaloneTool;
	-- 			},
	-- 		}
	-- 	}

]=]

--TODO: Create static methods that can convert a Tool from FolderTool format to StandaloneTool format

local ReplicatedStorage = game:GetService("ReplicatedStorage");
local ServerScriptService = game:GetService("ServerScriptService");
local ServerStorage = game:GetService("ServerStorage");

local Types = require(ReplicatedStorage.Types.Inventory);
local ShinobiTypes = require(ReplicatedStorage.Types.Shinobi);

local ToolClass = require(ServerScriptService.Classes.ToolClass);
local DojutsuClass = require(ServerScriptService.Classes.DojutsuClass);
local DojutsuLegality = require(ServerScriptService.Classes.DojutsuClass.DojutsuLegality);
local Remotes = require(ReplicatedStorage.Remotes);

local RemoteEvent = Remotes:GetEvent("Inventory");
local RemoteFunction = Remotes:GetFunction("Inventory");

local DojutsuEvent = Remotes:GetEvent("Dojutsu");

local Local = {};
local Inventories: {[Player]: Types.InventoryObject} = {}

local InventoryClass: Types.InventoryObject = {};
InventoryClass.__index = InventoryClass;

local DefaultFolderKeys = {"E", "R", "T", "Z", "X", --[[extra:]] "C", "V", "B"} -- when tools are automatically added to the Inventory, use these "default" --TODO: Player could store defaults and we can just use those
-- Once all the keys are unavailable, ADdStandaloneTool() will simply start adding numerical keycodes--OR you could just have it unequippable (maybe besides clicking it) until the player assigns a keycode

-- TODO: Enforce FolderTool limit of 5 entries
-- TODO: Make it so backpacks ignore keycodes (its UI-selection based). When an item from the backpack is dragged to the Toolbar, IT NEEDS TO BE ASSIGNED A NEW KEYCODE!!!
-- 	TODO: Make it so that Carry Capacity is recomputed when the player resets
-- TODO: Use :AddStandaloneTool() so that weight is considered -- IF NO WEIGHT IS AVAILABLE ON THE PERSON THEN IT NEEDS TO BE TRANSFERRED TO A PROPERTY
-- TODO: Make it so DojutsuTools are stored in an additional table besides .Tools for ease of access 

function InventoryClass.new(Player: Player, Data: ShinobiTypes.PlayerData): Types.InventoryObject
	local self: Types.InventoryObject = setmetatable({}, InventoryClass)

	self.Player = Player
	self.Data = Data
	self.EquippedTool = nil; -- The currently equipped tool
	self.DeserializedInventory = {
		Tools = {};
		Accessories = {},
	}
	self.carryCapacity = Local.getCarryCapacity(20); 



	-- Initialise the Object by deserializing Inventory to be used in live gameplay
	Local.Deserialize(self);
	Inventories[self.Player] = self;
	warn(self);


	-- task.spawn(function()
	-- 	task.wait(10);
	-- 	print("FIRING!!!") --turn to test case
	-- 	for Motor, tool in pairs(self.DeserializedInventory.Tools) do
	-- 		if tool.keycode == "R" then
	-- 			self:RemoveStandaloneTool(Motor)
	-- 		end
	-- 	end
	-- end)
	return self;
end

--[=[
	Handles incoming transmissions from the client.
]=]
local function RecieveUpdatesFromClient(Player: Player, command, ...)
	local Inventory = Inventories[Player];
	if Inventory then
		if command == "equip" then
			Local.Equip(Inventory, ...);
		elseif command == "unequip" then
			Local.Unequip(Inventory);
		end
	else
		warn(("No inventory found for %s (%s)"):format(Player.Name, Player.UserId));
	end
end

--[=[

	Computes the carry capacity for the player depending on their physical strength
	The carry capacity should not decrease during live gameplay

]=]
function Local.getCarryCapacity(PhysicalStrength: number): number
	return PhysicalStrength + 25;
end

--[=[
	@param PositionInFolder boolean | nil | number IF THE StandaloneTool lives inside of a folder, provide the position in the folder. OTHERWISE, leave nil or use "false."
	@param DoIAddOrReturn boolean Returns the DeserializedTool instead of directly adding it to the inventory. This is used by :AddFolderTool().
]=]
--TODO: Update the client when a tool is added
function InventoryClass:AddStandaloneTool(ObjectType: "Item" | "Jutsu", ObjectData: Types.ItemDescription | Types.JutsuDescription, IsTemporary: boolean, PositionInFolder: nil | number, OverrideWeight: boolean, DoIReturn: boolean | nil): Types.DeserializedStandaloneTool | nil
	-- FIX: removed the empty duplicate "if ObjectType == Item" stub that had no body -- its comment
	-- ("Compare the Item's Weight...") describes exactly what the real check below already does.

	if 
		ObjectType == "Jutsu" or 
		(ObjectType == "Item" and
		(OverrideWeight == true or ObjectData.weight <= self.carryCapacity))
		-- FIX: OverrideWeight now actually overrides the weight check (was previously requiring
		-- OverrideWeight == false AND passing the check, meaning OverrideWeight = true could never
		-- add anything). Confirm this matches your intent: OverrideWeight = true means "add regardless
		-- of weight."
	then
		-- Construct a ToolObject
		local ToolObject = ToolClass.new(self.Player, ObjectData, IsTemporary);

		-- FIX: numberOfOccupiedSlots now counts self.DeserializedInventory.Tools (the new flat table),
		-- not the old .Toolbar, which no longer exists on self.DeserializedInventory.

		local keycode: number | string;

		if not PositionInFolder then
			local numberOfOccupiedSlots = 0;
			for _ in pairs(self.DeserializedInventory.Tools) do
				numberOfOccupiedSlots += 1;
			end

			-- FIX: removed the stray "#" in front of numberOfOccupiedSlots (it's already a number, not a
			-- table/string, so "#" errored). keycode is simply the slot count itself now.
			keycode = if numberOfOccupiedSlots < 10 then numberOfOccupiedSlots else "";
		elseif PositionInFolder and type(PositionInFolder) == "number" then
			keycode = DefaultFolderKeys[PositionInFolder] or PositionInFolder;
		end

		

		-- Construct a DeserializedStandaloneTool.
		local DeserializedTool: Types.DeserializedStandaloneTool = {
			keycode = keycode; -- do this
			group = "standalonetool";
			type = ObjectType;
			tool = ToolObject;
		}

		-- FIX: both branches now write to the same flat .Tools hashmap (per the new "Server doesn't
		-- care about containers" design) -- the old .Toolbar/.Backpack split no longer applies here.
		self.DeserializedInventory.Tools[ToolObject.Motor6D] = DeserializedTool;

		if DoIReturn == true then
			return DeserializedTool;
		end
	end
end

--[=[

]=]

type toolsToAdd = {
	["Item" | "Jutsu"]: {
		ObjectData: Types.ItemDescription | Types.JutsuDescription,
		IsTemporary: boolean,
		OverrideWeight: boolean
	}
}
function InventoryClass:AddFolderTool(toolsToAdd: toolsToAdd)

	-- Construct the DeserializedFolderTool for the Client. The Server does not care about Folder tools.
	-- FIX: keycode needs a real value -- this previously had no value at all and would not parse.
	-- Using the same slot-counting approach as AddStandaloneTool, since a FolderTool also needs to
	-- occupy a Toolbar/Backpack slot from the Client's perspective. Confirm this is the right source
	-- for a FolderTool's keycode.
	local numberOfOccupiedSlots = 0;
	for _ in pairs(self.DeserializedInventory.Tools) do
		numberOfOccupiedSlots += 1;
	end

	local FolderTool: Types.DeserializedFolderTool = {
		keycode = if numberOfOccupiedSlots < 10 then numberOfOccupiedSlots else "";
		group = "foldertool";
		folder = {};
		-- FIX: folder table added -- previously missing entirely, so sub-tools had nowhere to go.
	};

	local index = 1; -- Used for "position in toolbar."
	for ObjectType, Tool in pairs(toolsToAdd) do
		-- Construct a StandaloneTool. This will add to the Inventory as a StandaloneTool. It will hand back the Tool so we can package it up for the Client to use
		local DeserializedSubTool = self:AddStandaloneTool(ObjectType, Tool.ObjectData, Tool.IsTemporary, index, Tool.OverrideWeight, true);
		-- FIX: was reassigning the loop variable "Tool" (shadowing the input) and never storing the
		-- result anywhere. Now captured in its own local and inserted into FolderTool.folder below.

		if DeserializedSubTool ~= nil then
			FolderTool.folder[DeserializedSubTool.keycode] = DeserializedSubTool;
			-- FIX: this line is new -- previously the folder was never actually populated.
		end
		index += 1;
	end

	return FolderTool;
	-- FIX: added a return -- previously the constructed FolderTool was built and then discarded,
	-- never handed back to whatever called :AddFolderTool().
end


--[=[
	Adds a Dojutsu to a Player's Inventory

	@param Eye Types.DojutsuType & Types.DojutsuSuffix The full eye key to add (e.g. "Sharingan_Left").
	@param Properties Types.DojutsuProperties | Types.DojutsuMSProperties The Dōjutsu's data to store.
	@return boolean whether the addition succeeded or failed.
]=]
function InventoryClass:AddDojutsu(Eye: Types.DojutsuType & Types.DojutsuSuffix, Properties: Types.DojutsuProperties | Types.DojutsuMSProperties): boolean
	local Dojutsu: Types.DojutsuInventory = self.Data.Inventory.Dojutsu;

	-- Make a mock table with the new dojutsu inserted, without touching the real Inventory yet.
	local MockInventory: {[string]: Types.DojutsuProperties | Types.DojutsuMSProperties} = table.clone(Dojutsu.Inventory);
	MockInventory[Eye] = Properties;

	local MockDojutsuInventory: Types.DojutsuInventory = {
		Inventory = MockInventory,
		MissingEyes = Dojutsu.MissingEyes,
	};

	-- Run the format suite against that mock table. If it fails, reject the addition.
	if not DojutsuLegality.IsLegal(MockDojutsuInventory) then
		return false;
	end

	-- The mock passed -- commit it for real.
	Dojutsu.Inventory[Eye] = Properties;

	-- Honestly, if the Server needs to update anything pertaining to Dojutsu, the easiest path is to simply use "initialise" again for the client command.
	DojutsuEvent:FireClient(self.Player, "initialise", Dojutsu);

	-- TODO: Add DojutsuTools to the player
	-- Ability Jutsu that Dojutsu get is not serialized to the Datastores. It’s just written into a file and gets read from when the shizz gets loaded in
	-- for _, tool in pairs(Dojutsu.Inventory)

	-- RemoteEvent:FireClient(self.Player, "addtool", )

	return true;
end

--[=[
	Updates .MissingEyes within the DojutsuInventory.

	This method will only change exactly what is specified, or else
		nothing will be modified.

	@param LeftEye boolean | nil Pass true/false to set the Left eye's missing state; leave nil to not change it.
	@param RightEye boolean | nil Pass true/false to set the Right eye's missing state; leave nil to not change it.
	@return boolean whether the addition succeeded or failed.
]=]
function InventoryClass:UpdateMissingEyes(LeftEye: boolean?, RightEye: boolean?): boolean
	local Dojutsu: Types.DojutsuInventory = self.Data.Inventory.Dojutsu;

	-- FIX: "if LeftEye/RightEye is nil, keep the existing value" -- using a proper nil-check
	-- instead of "or", since "or" can't tell the difference between false and nil, and would
	-- silently ignore an explicit false (e.g. clearing a missing eye back to present).
	local NewLeft = if LeftEye ~= nil then LeftEye else Dojutsu.MissingEyes.Left;
	local NewRight = if RightEye ~= nil then RightEye else Dojutsu.MissingEyes.Right;

	-- FIX: check the RESULTING state (NewLeft/NewRight), not just the raw arguments passed in --
	-- this catches the case where only one eye is being updated this call, but the existing
	-- value of the OTHER eye would still result in both eyes missing.
	if NewLeft == true and NewRight == true then
		return false;
	end

	Dojutsu.MissingEyes.Left = NewLeft;
	Dojutsu.MissingEyes.Right = NewRight;
	warn("WORKING!!!", self.Player)
	DojutsuEvent:FireClient(self.Player, "initialise", Dojutsu);

	return true;
end


--[=[

	Removes a StandaloneTool from the Player's inventory.
	This method is not capable of removing DojutsuTools or entire FolderTools.

	Because the Server does not care about folders, there will not
	be a separate RemoveFolder. If a StandaloneTool lives inside of a Folder,
	ask the client to remove it.

	It will be removed and will not be serialized on the Server.

	@param ToolConnector Motor6D The Motor6D identifying which tool to remove.
	@return boolean whether the removal succeeded or failed.
]=]
function InventoryClass:RemoveStandaloneTool(ToolConnector: Motor6D): boolean
	if
		not ToolConnector or
		typeof(ToolConnector) ~= "Instance" or
		not ToolConnector:IsA("Motor6D")
	then
		return false;
	end

	local DeserializedTool = self.DeserializedInventory.Tools[ToolConnector];
	if DeserializedTool == nil then
		return false;
	end

	-- This method is explicitly not capable of removing DojutsuTools.
	if DeserializedTool.group ~= "standalonetool" then
		return false;
	end

	-- If this tool is currently equipped, unequip it first so self.EquippedTool
	-- doesn't end up pointing at a tool that no longer exists.
	if self.EquippedTool == DeserializedTool then
		Local.Unequip(self);
	end

	self.DeserializedInventory.Tools[ToolConnector] = nil;
	
	-- TODO: Ask the client to remove the tool on its end.
	RemoteEvent:FireClient(self.Player, "removetool", ToolConnector);
	return true;
end



--[=[
	Removes a Dojutsu from a Player's Inventory

	@param Eye Types.DojutsuType & Types.DojutsuSuffix The full eye key to remove (e.g. "Sharingan_Left").
	@return boolean whether the removal succeeded or failed.
]=]
	-- TODO: Ask the client to remove the dojutsu on its end.
function InventoryClass:RemoveDojutsu(Eye: Types.DojutsuType & Types.DojutsuSuffix): boolean
	local Dojutsu: Types.DojutsuInventory = self.Data.Inventory.Dojutsu;

	-- Nothing to remove if this eye key doesn't exist.
	if Dojutsu.Inventory[Eye] == nil then
		return false;
	end

	-- Make a mock table with the dojutsu removed, without touching the real Inventory yet.
	local MockInventory: {[string]: Types.DojutsuProperties | Types.DojutsuMSProperties} = table.clone(Dojutsu.Inventory);
	MockInventory[Eye] = nil;

	local MockDojutsuInventory: Types.DojutsuInventory = {
		Inventory = MockInventory,
		MissingEyes = Dojutsu.MissingEyes,
	};

	-- Run the format suite against that mock table. If it fails, reject the removal.
	-- (A removal could theoretically be illegal too -- e.g. removing one half of a
	-- Mangekyou pair might need to be handled deliberately rather than left as-is.)
	if not DojutsuLegality.IsLegal(MockDojutsuInventory) then
		return false;
	end

	-- The mock passed -- commit it for real.
	Dojutsu.Inventory[Eye] = nil;

	-- TODO: Remove/zap all DojutsuTools that pertain to this Eye from the Server's
	-- .Tools container (same pattern as regular Tool removal -- see the
	-- "If a Player loses a Dojutsu" notes for the intended flow).

	-- Honestly, if the Server needs to update anything pertaining to Dojutsu, the easiest path is to simply use "initialise" again for the client command.

	DojutsuEvent:FireClient(self.Player, "initialise", Dojutsu);
	-- TODO: Remove DojutsuTools from the player
	local DojutsuType = string.split(Eye, "_")[1];
	RemoteEvent:FireClient(self.Player, "removedojutsutool", DojutsuType);

	return true;
end


-- If a Player loses a Dōjutsu:

-- 1. Server does not care about Folders or Keycodes

-- 2. All DōjutsuTools that pertain to the DōjutsuTool being lost
--    can be zapped from the Server's .Tools container

-- 3. **The Server asks the Client to Remove the Tool (on its own end)** DON'T FORGET THIS

-- 4. When Tools get Serialized, it will no longer be there.



--[=[

	Equips a tool from the Inventory

	The server will automatically unequip a tool if it recieves a new equipped request
]=]
-- FIX: ContainerType is no longer used for lookup, since the Server only keeps one flat
-- .Tools hashmap now -- a tool's Motor6D alone is enough to find it, regardless of which
-- container the Client considers it to be in. Left the parameter in the signature since the
-- Client still sends it (harmless to receive, just unused here) -- remove it from both sides
-- if you'd rather clean that up.
function Local.Equip(self: Types.InventoryObject, ToolConnector: Motor6D, ContainerType: "Toolbar" | "Backpack"): boolean

	warn("HELLO!!!")
	-- Perform sanity checks
	if 
		ToolConnector and
		typeof(ToolConnector) == "Instance" and
		ToolConnector:IsA("Motor6D")
	then
		-- Attempt to locate the tool via Motor6D in the flat Tools hashmap.
		local DeserializedTool = self.DeserializedInventory.Tools[ToolConnector];
		if DeserializedTool then -- If it was found then equip it via the underlying ToolObject

			if self.EquippedTool then
				-- Do not allow the client to equip a tool that has already been equipped.
				if self.EquippedTool == DeserializedTool then
					return false;
				else -- If a different tool is equipped, then unequip the currently active tool to equip this one.
					Local.Unequip(self);
				end
			end

			DeserializedTool.tool:Equip();
			self.EquippedTool = DeserializedTool;
			return true;
		else -- If it was not found then return
			return false;
		end
	else
		return false;
	end
end

--[=[
	Unequips the actively equipped tool.
]=]
function Local.Unequip(self: Types.InventoryObject): boolean
	if self.EquippedTool then
		self.EquippedTool.tool:Unequip();
		self.EquippedTool = nil;
		return true;
	end
	return false;
end

--[=[

	Serializes all tools so that they can be saved into the Datastore.
	To be called by whatever script manages players leaving the game.

	This method is called from the PlayerService which will invoke the
	DataManager to write to the SerializedInventory.

	TODO IMPORTANT: Before serializing anything, the server needs to authenticate the client
		tool using the Motor6Ds.

]=]
function InventoryClass:Serialize(): Types.SerializedInventory

	-- Ping the client and ask for the current organizational structure of the Inventory
	local ClientInventory: Types.ClientInventory = RemoteFunction:InvokeClient(self.Player, "terminate");

	local SerializedInventory: Types.SerializedInventory = {
		Toolbar = {};
		Backpack = {};
	}

	--[=[
		Converts a single DeserializedStandaloneTool or DojutsuDeserializedTool back into its
		Serialized form, by converting its ObjectData back into the String that originally
		represented it.
	]=]
	-- FIX: now handles DeserializedTool.group == "dojutsutool" as well, producing a
	-- DojutsuSerializedTool (carrying dojutsuType) instead of a SerializedStandaloneTool.
	local function SerializeStandaloneTool(
		DeserializedTool: Types.DeserializedStandaloneTool | Types.DojutsuDeserializedTool
	): Types.SerializedStandaloneTool | Types.DojutsuSerializedTool
		-- Convert the ObjectData back into a string that represents it
		local contents = DeserializedTool.tool.ObjectData.Name;

		-- Make sure that Module still exists (in case it got deleted for whatever reason)
		if
			(DeserializedTool.type == "Item" and not ServerStorage.Items:FindFirstChild(contents))
			or (DeserializedTool.type == "Jutsu" and not ReplicatedStorage.JutsuShared:FindFirstChild(contents))
		then
			warn(("Could not find module for **%s**"):format(contents));
		end

		if DeserializedTool.group == "dojutsutool" then
			local SerializedTool: Types.DojutsuSerializedTool = {
				group = "dojutsutool";
				dojutsuType = DeserializedTool.dojutsuType;
				type = DeserializedTool.type;
				contents = contents;
			}
			return SerializedTool;
		end

		local SerializedTool: Types.SerializedStandaloneTool = {
			group = DeserializedTool.group;
			type = DeserializedTool.type;
			contents = contents;
		}

		return SerializedTool;
	end

	--[=[
		Iterates through a Container (Toolbar or Backpack) from the ClientInventory,
		converting every DeserializedStandaloneTool, DojutsuDeserializedTool, and
		DeserializedFolderTool within it back into their Serialized forms, and stores
		the result in SerializedInventory.
	]=]
	local function SerializeContainers(
		Container: {
			[number]: Types.DeserializedStandaloneTool | Types.DeserializedFolderTool | Types.DojutsuDeserializedTool,
		},
		ContainerType: "Toolbar" | "Backpack"
	)
		for index, DeserializedTool in pairs(Container) do
			if DeserializedTool.group == "standalonetool" or DeserializedTool.group == "dojutsutool" then
				SerializedInventory[ContainerType][index] = SerializeStandaloneTool(DeserializedTool);

			elseif DeserializedTool.group == "foldertool" then
				local SerializedFolder = {};

				for folderIndex, SubTool in pairs(DeserializedTool.folder) do
					SerializedFolder[folderIndex] = SerializeStandaloneTool(SubTool);
				end

				local SerializedFolderTool: Types.SerializedFolderTool = {
					group = "foldertool";
					folder = SerializedFolder;
				};

				SerializedInventory[ContainerType][index] = SerializedFolderTool;
			end
		end
	end

	SerializeContainers(ClientInventory.Toolbar, "Toolbar");
	SerializeContainers(ClientInventory.Backpack, "Backpack");

	self.Data.Inventory.Toolbar = SerializedInventory.Toolbar;
	self.Data.Inventory.Backpack = SerializedInventory.Backpack;

	return SerializedInventory;
end

--[=[
    Deserializes all tools from the Datastores 
    so that they are available for live gameplay.
	This includes Standalones, Folders, and even DojutsuTools that are organized and saved.

	After, it will invoke the DojutsuClass to initialise the other components
	of Dojutsu beyond their tools.

    NOTE: The Server discards the concept of "Folders", "Toolbar", and "Backpack" entirely.
    Every StandaloneTool -- regardless of where it originally lived -- is flattened into
    the same O(1) Motor6D-keyed hashmap: self.DeserializedInventory.Tools.

    The Client still cares about Toolbar/Backpack/Folder structure for organization/display,
    so ClientInventory retains that shape. When the Client equips a tool, it sends the
    tool's Motor6D directly -- the Server never needs to know or care which container or
    folder (if any) that tool came from.

    (During Serialization, the Client's organizational structure is what
    gets asked for and used to rebuild folders for storage.)
]=]
function Local.Deserialize(self: Types.InventoryObject)
	local UnpackToolsFromContainer: () -> nil -- function to be defined later
	local DeserializeTool: () -> nil
	local ClientInventory = {
		Toolbar = {},
		Backpack = {},
		Dojutsu = {},
		Accessories = {},
	}

	-- --[=[

	-- 	Organizes a single deserialized sub-tool (from inside a Folder) into the CLIENT's nested
	-- 	folder view, either updating an existing folder entry in ClientInventory
	-- 	or creating one if this is the first sub-tool found for that Folder.

	-- 	@param SubTool DeserializedStandaloneTool | DojutsuDeserializedTool The Tool that lives inside the Folder being organized.
	-- 	@param ParentFolderSerializedTool SerializedFolderTool The original Serialized form of the Folder that SubTool belongs to.
	-- 	@param ParentPositionInToolbar number | string The Folder's own position/keycode within its container (Toolbar or Backpack).
	-- 	@param ParentContainerType "Toolbar" | "Backpack" Which container the parent Folder itself lives in.
	-- ]=]
	local function OrganizeToolsInFolder(
		SubTool: Types.DeserializedStandaloneTool | Types.DojutsuDeserializedTool,
		ParentFolderSerializedTool: Types.SerializedFolderTool,
		ParentPositionInToolbar: number | string,
		ParentContainerType: "Toolbar" | "Backpack"
	): nil
		local ClientFolder = ClientInventory[ParentContainerType][ParentPositionInToolbar]
		if ClientFolder then
			ClientFolder.folder[SubTool.keycode] = SubTool;
		else
			ClientInventory[ParentContainerType][ParentPositionInToolbar] = {
				keycode = ParentPositionInToolbar,
				group = ParentFolderSerializedTool.group,
				folder = {
					[SubTool.keycode] = SubTool,
				},
			}
		end
	end

	-- --[=[
	-- 	Iterates through all StandaloneTools from one of the following "containers":
	-- 		1. Toolbar
	-- 		2. Backpack
	-- 		3. Any provided Folder Tool
	-- 	It hands it off to the method "DeserializeTool" for deserialization.
	-- 	The function is called from inside "DeserializeTool" to invoke on Folder Tools.

	-- 	@param Container { [number]: SerializedStandaloneTool | SerializedFolderTool | DojutsuSerializedTool } The Serialized tools to iterate through and deserialize.
	-- 	@param ContainerType "Toolbar" | "Backpack" | "Folder" Which kind of container Container represents.
	-- 	@param FolderArgs { ParentFolderSerializedTool: SerializedFolderTool, ParentPositionInToolbar: number | string, ParentContainerType: "Toolbar" | "Backpack" }? Only provided when ContainerType is "Folder" -- carries the parent Folder's identity so its sub-tools can be organized back into it via OrganizeToolsInFolder.
	-- ]=]
	function UnpackToolsFromContainer(
		Container: { [number]: Types.SerializedStandaloneTool | Types.SerializedFolderTool | Types.DojutsuSerializedTool },
		ContainerType: "Toolbar" | "Backpack" | "Folder",
		FolderArgs: {
			ParentFolderSerializedTool: Types.SerializedFolderTool,
			ParentPositionInToolbar: number | string,
			ParentContainerType: "Toolbar" | "Backpack",
		}?
	)
		for positionInToolbar, serializedTool in pairs(Container) do
			-- NOTE: RootContainerType is no longer needed by DeserializeTool for Server-side caching
			-- (everything flattens into .Tools regardless), but it's still passed through here since
			-- OrganizeToolsInFolder needs ParentContainerType to build the CLIENT's Toolbar/Backpack view.
			local DeserializedTool: Types.DeserializedStandaloneTool | nil = DeserializeTool(
				serializedTool,
				positionInToolbar,
				ContainerType
			)
			if DeserializedTool and ContainerType == "Folder" and FolderArgs then
				OrganizeToolsInFolder(
					DeserializedTool,
					FolderArgs.ParentFolderSerializedTool,
					FolderArgs.ParentPositionInToolbar,
					FolderArgs.ParentContainerType
				)
			end
		end
	end

	-- --[=[
	--  	Deserializes Standalone Tools (and DojutsuTools, which share the same shape).

	--  	This method is called for Inventory.Toolbar and Inventory.Backpack.
	--  	and is called recursively for FolderTools (deserialize the standalones/dojutsu tools inside of them),

	-- 		FIX: now also accepts/handles SerializedTool.group == "dojutsutool", since FolderTools can contain
	-- 		both StandaloneTools and DojutsuTools per the Types file (SerializedFolderTool.folder allows both).
	-- 		DojutsuSerializedTool/DojutsuDeserializedTool share the same Item/Jutsu resolution and Motor6D
	-- 		caching as StandaloneTools -- the only real difference is the extra dojutsuType field being carried
	-- 		through, so both are handled in one shared branch rather than duplicating this logic.

	--  	@param SerializedTool SerializedStandaloneTool | SerializedFolderTool | DojutsuSerializedTool The Serialized tool (or Folder containing them) to deserialize.
	--  	@param PositionInToolbar number | string The tool's position/keycode within its container.
	--  	@param ContainerType "Toolbar" | "Backpack" | "Folder" Which kind of container SerializedTool was found in.

	--  	@return DeserializedStandaloneTool | DojutsuDeserializedTool | nil the method returns the tool if it
	--  		is called recursively on FolderTools. For Toolbar and Backpack, the Tools are simply added to
	--  		the InventoryObject itself and the method returns nothing.
	-- ]=]

	function DeserializeTool(
		SerializedTool: Types.SerializedStandaloneTool | Types.SerializedFolderTool | Types.DojutsuSerializedTool,
		PositionInToolbar: number | string,
		ContainerType: "Toolbar" | "Backpack" | "Folder"
	): Types.DeserializedStandaloneTool | Types.DojutsuDeserializedTool | nil
		if SerializedTool.group == "standalonetool" or SerializedTool.group == "dojutsutool" then
			local ObjectData: Types.ItemDescription | Types.JutsuDescription
			local Object: ModuleScript = if SerializedTool.type == "Item"
				then ServerStorage.Items:FindFirstChild(SerializedTool.contents)
				elseif SerializedTool.type == "Jutsu" then ReplicatedStorage.JutsuShared:FindFirstChild(
					SerializedTool.contents
				)
				else nil;

			if Object == nil then
				return;
			else
				ObjectData = require(Object);
			end

			local ToolObject = ToolClass.new(self.Player, ObjectData, false);

			local DeserializedTool: Types.DeserializedStandaloneTool | Types.DojutsuDeserializedTool
			if SerializedTool.group == "dojutsutool" then
				DeserializedTool = {
					keycode = PositionInToolbar,
					group = "dojutsutool",
					dojutsuType = SerializedTool.dojutsuType,
					type = SerializedTool.type,
					tool = ToolObject,
				}
			else
				DeserializedTool = {
					keycode = PositionInToolbar,
					group = SerializedTool.group,
					type = SerializedTool.type,
					tool = ToolObject,
				}
			end

			-- Both StandaloneTools and DojutsuTools flatten into the same Motor6D-keyed hashmap.
			self.DeserializedInventory.Tools[ToolObject.Motor6D] = DeserializedTool;

			if ContainerType == "Toolbar" or ContainerType == "Backpack" then
				ClientInventory[ContainerType][DeserializedTool.keycode] = DeserializedTool;
			elseif ContainerType == "Folder" then
				return DeserializedTool;
			end
		elseif SerializedTool.group == "foldertool" then
			UnpackToolsFromContainer(SerializedTool.folder, "Folder", {
				ParentFolderSerializedTool = SerializedTool,
				ParentPositionInToolbar = PositionInToolbar,
				ParentContainerType = ContainerType,
			});
		end
	end

	local Toolbar = UnpackToolsFromContainer(self.Data.Inventory.Toolbar, "Toolbar");
	local Backpack = UnpackToolsFromContainer(self.Data.Inventory.Backpack, "Backpack");

	--[[	DOJUTSU		]]
	-- While the unpackaging of DojutsuTools was handled above handed
	-- unpackage the other components of Dojutsu using this method.
	DojutsuClass:Initialise(self.Player, self.Data.Inventory.Dojutsu);

	RemoteEvent:FireClient(self.Player, "initialise", ClientInventory);
end


RemoteEvent.OnServerEvent:Connect(RecieveUpdatesFromClient);
RemoteFunction.OnServerInvoke = RecieveUpdatesFromClient;


return InventoryClass