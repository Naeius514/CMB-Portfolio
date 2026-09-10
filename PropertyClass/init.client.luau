local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PropertyTypes = require(ReplicatedStorage.Types.Properties)

local Classes = script.FurnitureClasses
local FurnitureSuperclass = require(Classes.FurnitureSuperclass)

local Remotes = require(ReplicatedStorage.Remotes)
local PropertyRemote = Remotes:GetEvent("Property")

local FurnitureClasses = {
	-- Wardrobe = require(Classes.Wardrobe);
	-- Cabinet = require(Classes.Cabinet);
	Bed = require(Classes.Bed),
}

local ClientProperties = {} -- static class

local LoadedProperties: StoredPropertyEntry = {}

type StoredPropertyEntry = {
	[Player]: { [PropertyTypes.Unit]: ClientActiveProperty },
}

type ClientActiveProperty = PropertyTypes.ActiveProperty & { FurnitureObject: FurnitureSuperclass.FurnitureObject } -- ActiveProperty with added attributes for clients
--[=[
    Handles requests sent from the Server.
]=]
local function RecieveUpdatesFromServer(Request, ...)
	warn("Recieved!", Request, ...)
	if Request == "new" then
		ClientProperties:InstantiateActiveProperty(...)
	elseif Request == "remove" then
		ClientProperties:RemoveActiveProperty(...)
	end
end

--[=[
    Creates a property and instantiate da furniture and loads the player's addon furniture.
]=]
-- TODO: "Owner" could be an Organization.
function ClientProperties:InstantiateActiveProperty(ActiveProperty: PropertyTypes.ActiveProperty)
	local ClientActiveProperty: ClientActiveProperty
	for _, furniture: PropertyTypes.Furniture in (ActiveProperty.Building.Furniture:GetChildren()) do
		-- Index the name of the furniture directly in the FurnitureClass table to find it
		-- Probably has a faster looktime than iterating one by one
		local FurnitureClass = FurnitureClasses[furniture.Name]
		warn("CLASS: ", FurnitureClass)
		if not FurnitureClass then
			continue
		else
			local FurnitureObject = FurnitureClass.new(furniture)
			ClientActiveProperty = ActiveProperty
			ClientActiveProperty.FurnitureObject = FurnitureObject
		end
	end

	-- Store the Property for later retrieval
	self:StoreProperty(ClientActiveProperty) -- TODO: A player might have multiple properties.
end

--[=[
    Removes and disconnects an ActiveProperty. 
    It *may* still exist on the Server, but the client no longer
    needs to be aware of it.

    Maybe because they walked too far away from it or something.
]=]
function ClientProperties:RemoveActiveProperty(Owner: Player, Building: PropertyTypes.Unit)
	print(LoadedProperties, Owner, Building)
	local Property: ClientActiveProperty = LoadedProperties[Owner][Building]
	if Property then
		warn(Property.FurnitureObject)
		Property.FurnitureObject:DeactivatePromptConnections()
		LoadedProperties[Owner][Building] = nil

		-- If there weren't anymore loaded properties for this Owner,
		-- Remove them from the table to prevent a memory leak.
		if #LoadedProperties[Owner] == 0 then
			LoadedProperties[Owner] = nil
		end
	end
	warn("Property", Building, "removed from cache.")
	warn(LoadedProperties)
end

function ClientProperties:StoreProperty(ClientActiveProperty: ClientActiveProperty)
	local storedProperties = LoadedProperties[ClientActiveProperty.Owner]

	-- If a player already has an entry or entries for a property, then:
	if storedProperties then
		-- Simply append the property to the table
		storedProperties[ClientActiveProperty.Building] = ClientActiveProperty
	else -- Otherwise:
		-- Create an entirely new table
		storedProperties = {}
		storedProperties[ClientActiveProperty.Building] = ClientActiveProperty

		-- Add the property to the owner's list of active properties.
		LoadedProperties[ClientActiveProperty.Owner] = storedProperties
	end

	warn(LoadedProperties)
end

PropertyRemote.OnClientEvent:Connect(RecieveUpdatesFromServer)
