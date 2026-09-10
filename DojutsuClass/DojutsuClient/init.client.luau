
--[=[

    DojutsuClient.client.luau

    A centralized manager that manages all three dojutsu functionality
    from above. Controls activation keys.

    This localscript will be copied by the Server and manually given out to clients that need it.

    This is to be parented into the Player's PlayerGui because
        1) The Server cannot view PlayerScripts (where scripts from StarterPlayerScripts are added at runtime)
        2) The Server is capable of viewing other client's PlayerGui's
        3) Other clients are incapable of each other's PlayerGuis
        4) LocalScripts run for a client if placed in PlayerGui.
]=]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Types = require(ReplicatedStorage.Types.Inventory);

local Remotes = require(ReplicatedStorage.Remotes);
local RemoteEvent = Remotes:GetEvent("Dojutsu");

local MissingEyesComponent = require(script.Components.MissingEyes);

local ActivationKeys: {[Types.DojutsuType]: string} = {
    ["Sharingan"] = "G";
    ["Byakugan"] = "H";
    ["Rinnegan"] = "J";
};



local DojutsuInventory: Types.DojutsuInventory = {}; -- To be provided by the Server.

local LocalDojutsuObjects: {[Types.DojutsuType]: Types.ClientDojutsuObject} = {}; -- Contains local-sided Sharingan, Byakugan, or Rinnegan object (see child modules.)


--[=[
    Grants the local Client the ability to activate their equipped Dōjutsu.

    Instantiates a DojutsuObject for every Dōjutsu found in the given Inventory,
    and binds each one's activation key (per ActivationKeys) so holding the key
    toggles that Dōjutsu on, and releasing it toggles the Dōjutsu back off.
]=]
local function Initialise(Inventory: Types.DojutsuInventory)
    print("Hello!")
    DojutsuInventory = Inventory;

    -- Initialise the MissingEyes
    if Inventory.MissingEyes.Left ~= false or Inventory.MissingEyes.Right ~= false then
        MissingEyesComponent:init(Inventory);
    end

    -- Instantiate a DojutsuObject (class/module) for each Dojutsu found in the Inventory
    for Eye: Types.DojutsuType & Types.DojutsuSuffix, Properties in pairs(DojutsuInventory.Inventory) do
        local DojutsuType, DojutsuSuffix: Types.DojutsuType = unpack(string.split(Eye, "_"));
        local DojutsuObject: Types.ClientDojutsuObject;
        do
            -- Find and require the module that implements this specific Dōjutsu type
            -- (e.g. a "Sharingan" ModuleScript sitting as a child of this script).
            warn(DojutsuType)
            local DojutsuModule: Types.ClientDojutsuObject = require(script.Modules:FindFirstChild(DojutsuType));
            -- Verify the module is legit
            if DojutsuModule then
                -- Construct the actual DojutsuObject instance for this eye, and cache it
                -- for lookup elsewhere (e.g. when toggling or removing this Dōjutsu later).
                DojutsuObject = DojutsuModule.new(DojutsuType, DojutsuSuffix, Properties);
                LocalDojutsuObjects[DojutsuType] = DojutsuObject;
            end            
        end
        warn(DojutsuObject)
        if not DojutsuObject then
            -- No valid module was found/instantiated for this Dōjutsu type -- skip binding
            -- an activation key for it entirely.
            continue;
        end
        warn("CAS BINDING")
        -- Bind this Dōjutsu's activation key: pressing it  toggles the Dōjutsu on,
        -- releasing it toggles the Dōjutsu back off.
        ContextActionService:BindAction(DojutsuType, function(_, userInputState, inputObject: InputObject)

            if userInputState == Enum.UserInputState.Begin then
                DojutsuObject:Toggle(true);
                -- Turn on the Dojutsu
                -- Make all DojutsuTools that pertain to this eye work

            else
                -- Turn off the Dojutus
                DojutsuObject:Toggle(false);
            end

        end, false, Enum.KeyCode[ActivationKeys[DojutsuType]]);
    end
end

--[=[

	This method recieves updates from the Server and
	can send a response.

	~~Both the RemoteEvent and RemoteFunction are bound to this method.
	So, if the Server sent something using the RemoteFunction, a response
	can be generated from this method.~~
    (copied and pasted from InventoryClient)

]=]
local function RecieveUpdatesFromServer(command, ...)
    warn("Hello!!!")

    -- Honestly, if the Server needs to update anything the easiest path is to simply use "initialise" again.
	if command == "initialise" then
		Initialise(...);
    end
end


RemoteEvent.OnClientEvent:Connect(RecieveUpdatesFromServer)