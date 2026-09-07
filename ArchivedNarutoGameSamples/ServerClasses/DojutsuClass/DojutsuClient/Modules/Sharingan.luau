--[=[

]=]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Types = require(ReplicatedStorage.Types.Inventory);
local Settings = require(ReplicatedStorage.GlobalSettings.DojutsuSettings).Sharingan.VisualSettings;


local Sharingan: Types.ClientDojutsuObject = {};


--[=[
    Initialises a new Sharingan class.
    This is more like a "static class," and therefore has no metatable action.
]=]
function Sharingan:new(DojutsuType: Types.DojutsuType, Suffix: Types.DojutsuSuffix, Properties: Types.DojutsuProperties | Types.DojutsuMSProperties)
    print("Instantiated!")
    local self = Sharingan;
    self.activationState = false;
    self.type = DojutsuType;
    self.sideOfFace = Suffix;
    self.isMonocular = if Suffix == "Left" or Suffix == "Right" then true else false;

    if self.isMonocular == false then
        self._vision = Instance.new("ColorCorrectionEffect");
        self._vision.Parent = Lighting;
    else
        self._vision = Instance.new("Frame");
        -- TODO: Set parent;
    end

    return self;

end

--[=[
    Toggles the Sharingan on/off.

    If it turns on, the vision "starts." When turned off,
    the vision "ends" and all methods that made it work are cleaned up.
]=]
function Sharingan:Toggle(activationState: boolean)
    self.activationState = activationState;

    if self.activationState == true then
        if self.isMonocular == false then
            self._vision.TintColor = Settings.TintColor;
            self._vision.Contrast = Settings.Contrast;
            self._vision.Saturation = Settings.Saturation;
            self._vision.Brightness = Settings.Brightness;
        else
            self._vision.BackgroundColor3 = Settings.TintColor;
        end
    end
end


return Sharingan;