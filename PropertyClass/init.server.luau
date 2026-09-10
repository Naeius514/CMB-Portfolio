--[=[

    Creates and manages properties authoritatively on the Server.


    The "Addressing Scheme" (the way the map is organized)
    is important in order for this system to work. The system needs to be able to
    find the address of a property, same as in real life.
    
    The addressing system it currently uses is:
    Workspace --> Country --> Region --> Town/Subregion --> Building --> Units --> Property Unit (like an Apartment Unit or Business?)

    A "Subregion" doesn't need to literally be a fully fleshed town. It can be as simple as 
    a small lake somewhere. The function of the Subregion is to further differentiate by another level.

    The target Property must ALWAYS be a CHILD or GREAT GRANDCHILD of Town/Subregion following this addressing scheme:
        - Subregion.Property;
        - Subregion.Building.*Units.Property*
    Meaning: a Property must always be 5 layers or 7 layers down from game.Workspace.


    the target Property must have a unique Name in the workspace: Consider like Hotel format or something. 
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ShinobiTypes = require(ReplicatedStorage.Types.Shinobi)
local PropertyTypes = require(ReplicatedStorage.Types.Properties)
local Remotes = require(ReplicatedStorage.Remotes)

local PropertyRemote = Remotes:GetEvent("Property")
local Properties = {}

-- TODO: when you make the save feature, throw an error if the "PropertyId" attribute is not found in the property unit.
-- TODO: the property tables might be getting passed in by memory reference

--[=[
    Locates and authenticates the legitimacy of the Address, Property Category, & PropertyId 
    Converts all found Properties into ACTIVEPROPERTIES.
]=]
local function LocateProperty(Owner: Player, Property: PropertyTypes.Property): PropertyTypes.ActiveProperty
	warn(1)
	--
	if Property.Category then
		warn(2)
		-- The address will be something like Workspace.Country.Region... (so we split delimitted by the period)
		local Address = string.split(Property.Address, ".")

		-- Count each delimitted string to identify whether the property lives as a standalone building (5 levels) or lives within a building (7 levels)
		local Type = if #Address == 5 then "Standalone" elseif #Address == 7 then "Unit" else -1
		if Type == -1 then
			warn("Trouble finding Property from address!")
			return
		end

		-- Identify the exact Unit by converting the string to an actual "file path" using FindFirstChild
		local assembledAddress: Instance | PropertyTypes.ResidentialBuilding = Workspace

		for index, area in pairs(Address) do
			if string.lower(area) == "workspace" then -- we already have workspace defined above
				continue
			else
				assembledAddress = assembledAddress:FindFirstChild(area)
				warn(assembledAddress)
			end
		end
		warn(assembledAddress, typeof(assembledAddress))

		-- Exit if not recognized as a Property
		if
			typeof(assembledAddress) ~= "Instance"
			or not assembledAddress:HasTag(Property.Category)
			or assembledAddress:GetAttribute("PropertyId") ~= Property.PropertyId
		then
			warn("Invalid property")
			return
		end

		-- TODO: Check if another player somehow owns this property and resolve conflict.

		-- TODO: Add the player and the property to a table cache of all players and their loaded properties for later retrieval

		-- CONVERT INTO AN ACTIVE PROPERTY

		-- Add the physical property building to the logical property table to create an ActiveProperty
		local ActiveProperty: PropertyTypes.ActiveProperty = Property
		Property = nil

		ActiveProperty.Building = assembledAddress
		ActiveProperty.Owner = Owner

		return ActiveProperty
	end
end

--[=[
    Informs clients about a property.
    Always used when a property has just been created. May need to be recalled if the player walks away or something.
    TODO: May need to update so that it talks to the NetworkManager for optimized networking. 
]=]
local function InformClientsAboutProperty(ActiveProperty: PropertyTypes.ActiveProperty)
	PropertyRemote:FireAllClients("new", ActiveProperty)
end

local function TerminatePropertyOnClient(Client: Player, Owner: Player, Building: PropertyTypes.Unit)
	PropertyRemote:FireClient(Client, "remove", Owner, Building)
end
--[=[

    The server does not need to be aware of the Prompts or Furniture classes. 
    To authenticate usage of furniture, the Server simply confirms if:
        - The property is currently in-use (is an ActiveProperty); and
        - Proximity check between the player attempting to use the furniture to ensure reasonable distance;

]=]

--[=[
    An exposed method used to load a player's properties into the game.
]=]
local function Load(Player: Player, Data: ShinobiTypes.PlayerData)
	local Properties: { PropertyTypes.Property } = Data.Properties

	for _, property: PropertyTypes.Property in pairs(Properties) do
		local ActiveProperty = LocateProperty(Player, property) -- Locate and authenticate the validity of a property
		if ActiveProperty then
			InformClientsAboutProperty(ActiveProperty) -- Load the furniture into the game.
		end

		task.wait(5)
		TerminatePropertyOnClient(Player, Player, ActiveProperty.Building)
	end
end

return Load
