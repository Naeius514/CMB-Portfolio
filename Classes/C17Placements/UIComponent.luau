local TextService = game:GetService("TextService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
--[=[
    
    Declaratively creates the UI for PlacementStructure.client.luau

]=]

local STRUCTURE_UI_X = 165
local STRUCTURE_UI_Y = 130
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local FONT = Font.fromEnum(Enum.Font.TitilliumWeb)
FONT.Bold = true

--[=[
    Creates a small, versatile widget that performs:
        - Saving
        - Loading
        - Deletion

    If this widget is used for LOADING or DELETION, the widget displays:
        - The structure's name in a TextLabel 
        - A TextButton that allows them to LOAD or DELETE.

    If this widget is being used for SAVING, the widget displays:
        - The name to save the structure using a TextBox
        - A TextButton that allows them to initiate the SAVE.

    @params ButtonType "Load" | "Delete" | "Save" The type of button to create. Is the button intended to load, delete, or save?
    @params HeaderType "TextLabel" | "TextBox" The type of instance to initialise the header as -- a textbutton or a textbox.
    @params HeaderText string The text to display in the Header IF it is used for LOADING or DELETION instead of SAVING.
    @return Frame The parent container that contains the Header and Button.
]=]

type EditOperations = "Load" | "Save" | "Delete"
local Component = {}


local MODES = {
	[1] ="Load",
	[2] = "Save",
	[3] = "Delete"
}

--[=[
	Allows the player to cycle through the MODES
]=]
function Component:updateMode(): EditOperations
	local currentModeIndex = table.find(MODES, self.mode);
	local nextMode = if currentModeIndex > 2 then 1 else currentModeIndex + 1;
	self.mode = MODES[nextMode];
	self.tree.ParentContainer.HelperButton.Visible = false

	-- Cleanup and rerender.
	self:doCleaning();
	self:render();
end


function Component:createStructureUI(self, ButtonType: EditOperations, HeaderText: string | nil): Frame
	assert(
		ButtonType == "Load" or ButtonType == "Delete" or ButtonType == "Save",
		"ButtonType must be LOAD or DELETE or SAVE."
	)

	local Container = Instance.new("Frame")
	Container.Size = UDim2.fromOffset(STRUCTURE_UI_X, 60)
	Container.AnchorPoint = Vector2.new(0.5, 0)
	Container.BackgroundTransparency = 1

	local HeaderType = if ButtonType == "Save" then "TextBox" else "TextLabel"
	local Header: TextLabel | TextBox = Instance.new(HeaderType)
	if HeaderType == "TextBox" then
		Header.Text = ""
		Header.PlaceholderText = "Enter Structure Name"
	else
		Header.Text = (HeaderText or "NOT FOUND")
	end
	--Header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

	Header.TextColor3 = TEXT_COLOR
	Header.RichText = true
	Header.TextWrapped = true
	Header.TextSize = 17
	Header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Header.BackgroundTransparency = ButtonType == "Save" and 0.5 or 1
	Header.Size = UDim2.fromScale(1, 0.7)
	Header.FontFace = FONT
	Header.Name = "Header"

	local Button = Instance.new("TextButton")
	Button.TextColor3 = TEXT_COLOR
	Button.FontFace = FONT
	Button.Size = UDim2.fromScale(1, 0.3)
	Button.Position = UDim2.fromScale(0, 1)
	Button.AnchorPoint = Vector2.new(0, 1)
	Button.Text = ButtonType
	Button.BackgroundTransparency = 0.8
	Instance.new("UICorner").Parent = Button
	Button.TextSize = 14
	Button.Name = "Button"

	Button.MouseButton1Click:Connect(function()
		-- A structure name is necessary in order to save.
		if 
			ButtonType == "Save" and
			string.len(Header.Text) == 0
		then
			warn("No structure name entered.")
			return
		end
		
		-- If all eligibility is met, then proceed with the request.
		self.sendRequestToServerCallback(ButtonType, Header.Text, self.loadWithModifiedPos);
	end)

	-- Parent
	Header.Parent = Container
	Button.Parent = Container

	return Container
end




function Component:init(SavedStructures: {}, SendRequestToServerCallback: () -> nil)
	self.connections = {}
	self.savedStructures = {{Name = "Item A"}, {Name = "Item B"}, {Name = "Item A"} }--SavedStructures
	self.mode = "Load" :: EditOperations
	self.loadWithModifiedPos = true
	self.tree = nil
	self.sendRequestToServerCallback = SendRequestToServerCallback
	self.ScaleTargets = {}
	self:render();
end


function Component:instantiateHelperButton()

	local Button = Instance.new("TextButton")
	Button.Size = UDim2.fromOffset(100, 40)
	Button.Position = UDim2.fromScale(0.4, 0.07)
	Button.BackgroundTransparency = 0.8
	Button.Text = self.loadWithModifiedPos == true and "Toggle Original" or "Toggle Modified"
	Button.FontFace = FONT
	Button.TextSize = 17
	Button.TextColor3 = Color3.fromRGB(255, 255, 255)
	Button.BackgroundColor3 = Color3.fromRGB(113, 113, 115)
	Button.Name = "HelperButton"
	Instance.new("UICorner").Parent = Button

	table.insert(self.connections, Button.MouseButton1Click:Connect(function()
		print("HELLo!")
		self.loadWithModifiedPos = not self.loadWithModifiedPos 
		if self.loadWithModifiedPos then
			Button.Text = "Loading Original Position"
		else
			Button.Text = "Loading Modified Position"
		end
		Button.Text = self.loadWithModifiedPos == true and "Toggle Original" or "Toggle Modified"
		
	end))
	return Button	
end

function Component:addToScaleTargets(GuiObject: GuiObject, Size: Vector2, Scale: number)
	local UIScale = Instance.new("UIScale")

	self.ScaleTargets[UIScale] = {
		Size = Size,
		Scale = Scale
	}
	UIScale.Parent = GuiObject
end
function Component:render()

	-- Create TREE
	local Tree = Instance.new("ScreenGui");
	Tree.Name = "Placement"

	-- Parent Container

	local ParentContainer = Instance.new("Frame")
	ParentContainer.BackgroundColor3 = Color3.new(0, 0, 0)
	ParentContainer.BackgroundTransparency = 0.5
	ParentContainer.Size = UDim2.fromOffset(175, 200)
	ParentContainer.Position = UDim2.fromScale(0.08, 0.5)
	ParentContainer.Parent = Tree
	ParentContainer.Name = "ParentContainer"
	Instance.new("UICorner").Parent = ParentContainer

	self:addToScaleTargets(ParentContainer, Vector2.new(175, 200), 0.4)


	-- Create mode cycler
	local ModeCycler = Instance.new("TextButton")
	ModeCycler.Parent = ParentContainer
	ModeCycler.Position = UDim2.fromScale(0.06, 0.07)
	ModeCycler.Size = UDim2.fromOffset(50, 40)
	ModeCycler.Text = "Mode: " .. self.mode
	ModeCycler.BackgroundTransparency = 0.8
	ModeCycler.BackgroundColor3 = Color3.fromRGB(113, 113, 115)
	ModeCycler.TextColor3 = Color3.fromRGB(255, 255, 255)
	ModeCycler.TextWrapped = true
	ModeCycler.TextSize = 17
	ModeCycler.FontFace = FONT

	Instance.new("UICorner").Parent = ModeCycler

	ModeCycler.MouseButton1Click:Connect(function()
		self:updateMode();
	end)

	-- Create helper button
	local HelperButton = Component:instantiateHelperButton()
	HelperButton.Parent = ParentContainer

	-- Create the Load/delete container

	if self.mode == "Load" or self.mode == "Delete" then
		-- Create container
		local LoadAndDeleteContainer = Instance.new("ScrollingFrame")
		LoadAndDeleteContainer.Size = UDim2.fromOffset(STRUCTURE_UI_X, STRUCTURE_UI_Y)
		LoadAndDeleteContainer.AnchorPoint = Vector2.new(0.5, 0)
		LoadAndDeleteContainer.Position = UDim2.fromScale(0.5, 0.3)
		LoadAndDeleteContainer.BackgroundTransparency = 0.5
		LoadAndDeleteContainer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

		-- Create UIListLayout
		local UIListLayout = Instance.new("UIListLayout")
		UIListLayout.Padding = UDim.new(0, 10)
		UIListLayout.Parent = LoadAndDeleteContainer

		-- Create UICorner
		local UICorner = Instance.new("UICorner")
		UICorner.Parent = LoadAndDeleteContainer

		-- Create the structures
		for _, savedStructure in pairs(self.savedStructures) do
			warn(savedStructure)
			local Option = self:createStructureUI(self, self.mode, savedStructure.Name)
			Option.Parent = LoadAndDeleteContainer
		end

		LoadAndDeleteContainer.Parent = ParentContainer
	elseif self.mode == "Save" then
		-- Make a save widget
		local SaveOption = self:createStructureUI(self, "Save")
		SaveOption.Position = UDim2.fromScale(0.5, 0.3)-- TODO: DO THIS!!!

		SaveOption.Parent = ParentContainer
	end
	self.tree = Tree
	Tree.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

function Component:doCleaning()
	for index, connection in self.connections do
		connection:Disconnect()
		table.remove(self.connections, index)
	end
	if self.tree then
		self.tree:Destroy()
	end
end


local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local Camera = Workspace.CurrentCamera
local TopInset, BottomInset = GuiService:GetGuiInset()
function Component:UpdateUISize()
	local size = Camera.ViewportSize - (TopInset + BottomInset)
	for target, options in pairs(self.ScaleTargets) do
		target.Scale = 1 / math.max(
			options.Size.X / size.X,
			options.Size.Y / size.Y
		) * options.Scale
	end
end

-- Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
-- 	Component:UpdateUISize()
-- end)



return Component