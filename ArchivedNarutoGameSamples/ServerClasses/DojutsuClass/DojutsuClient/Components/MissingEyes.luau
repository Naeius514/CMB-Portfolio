--[=[

    A UI Component oriented around Missing Eyes.
    Ability to activate the Black screen on either side of the face 
    Ability to deactivate the Black screen (if, for example, the eyes are healed).

]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Types = require(ReplicatedStorage.Types.Inventory);
local Component: Component = {};
local Local = {};
local X_SIZE = 0.475

local LocalPlayer = Players.LocalPlayer;

type Component = {
    Tree: ScreenGui;
    DojutsuInventory: Types.DojutsuInventory;
}

--[=[
    Initialises the component.

    To reinitialise after initialising once already, simply
    Call this method again with the updated DojutsuInventory.
]=]
function Component:init(DojutsuInventory: Types.DojutsuInventory)
    warn("Missing eyes loaded!!!")
    self.DojutsuInventory = DojutsuInventory;
    Local.render();
end

function Local.render()


    local self = Component;



    local MissingEyes = self.DojutsuInventory.MissingEyes;
    assert(not (MissingEyes.Left and MissingEyes.Right), "Only one eye can be missing at a time.");

    -- If the tree already existed previously, then we will destroy and rebuild it.
    if self.Tree then
        self.Tree:Destroy();
    end


    self.Tree = Instance.new("ScreenGui"); -- it may already exist from previous initialisation
    self.Tree.IgnoreGuiInset = true;

    -- This is the actual frame that will be used to block vision.
    local Frame = Instance.new("Frame"); -- it may already exist from previous initialisation
    Frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0);
    Frame.Size = UDim2.fromScale(X_SIZE, 1);
    
    if MissingEyes.Left == true and MissingEyes.Right == false then
        Frame.Position = UDim2.fromScale(0, 0);
        Frame.AnchorPoint = Vector2.new(0, 0);
    elseif MissingEyes.Left == false and MissingEyes.Right == true then
        Frame.Position = UDim2.fromScale(1, 0);
        Frame.AnchorPoint = Vector2.new(1, 0);
    end

    Frame.Parent = self.Tree;
    self.Tree.Parent = LocalPlayer:WaitForChild("PlayerGui");
end



return Component;