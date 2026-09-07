local RunService = game:GetService("RunService");
local Players = game:GetService("Players");

local Camera = workspace.CurrentCamera;
local LocalPlayer = Players.LocalPlayer;

local RigHumRtPart = workspace:WaitForChild("TemplateR6"):WaitForChild("HumanoidRootPart")

local CENTER_OF_SCREEN = 0.5

local Highlight = Instance.new("Highlight");

-- TODO: Use a Frame (GuiObject) to fill in the color for a one-eye dojutsu instead of ColorCorrection

--[=[
    Determines if a target is on the left-side of screen
    or the right-side of screen.

    This is necessary for the one-eye dojutsu whether a player only has, say
    for example a sharingan in a single eye. The effects of this sharingan (or any given dojutsu) should only
    be displayed on the side of the screen that corresponds to which side of the user's face
    the dojutsu is on (for example)  

    If the target is on the LEFT SIDE of the screen, the ratio is < 0.5
    If the taregt is on the RIGHT SIDE of the screen, the ratio is > 0.5.
]=]
RunService.RenderStepped:Connect(function()
		
	local ViewportSize = Camera.ViewportSize
	local ViewportPoint: Vector3 = Camera:WorldToViewportPoint(RigHumRtPart.Position)
	
	
	local pos = ViewportPoint.X/ViewportSize.X
	LocalPlayer:WaitForChild("PlayerGui").ScreenGui.Reference.Position = UDim2.fromScale(pos, 0)
	
	-- TODO: Discern whether the user's eye is on the right side or left side of screen.
		-- pos > CENTER_OF_SCREEN = the eye is on the RIGHT SIDE 
	
	-- Target is on the LEFT SIDE of the screen
	if pos > CENTER_OF_SCREEN then
		Highlight.Parent = RigHumRtPart.Parent;
		
	else
		
		Highlight.Parent = nil;
	end
	
end)