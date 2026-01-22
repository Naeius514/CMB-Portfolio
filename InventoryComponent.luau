local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIScale = require(ReplicatedStorage.Shared.UIScale)
local ClientResources = require(script.Parent.Parent.ClientResources)
local ContainerContents = require(script.Parent.UIContainerContents)
local GoodSignal = require(ReplicatedStorage.Packages.Signal)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LocalPlayer = Players.LocalPlayer
local StorageEvent = Remotes:GetEvent("StorageEvent")
local SIZE = 55
local PADDING = 5
local InventoryComponent = {}
InventoryComponent.__index = InventoryComponent

local function NewItemSlotComponent(Index, Tool, Location)
	-- Object Properties
	local self = setmetatable({}, InventoryComponent)
	self.Slot = self.UI.Templates.ItemTemplate:Clone() :: TextButton

	-- Internal Variables
	local EditMode = self.EditMode
	local IsSlotFilled = if Tool then true else false
	local Garbage = {}
	local Substitutions = {}
	local Cleanup = function()
		for _, Connection in Garbage do
			Connection:Disconnect()
		end

		for _, Substitution in Substitutions do
			Substitution:Destroy()
		end
	end

	if Location == "Backpack" then
		self.Slot.Text = Tool.Name
		self.Slot.Parent = self.UI.Backpack.Holder
	elseif Location == "Toolbar" then
		self.Slot.Parent = self.UI
		self.Slot.Position = UDim2.fromOffset(
			(SIZE + PADDING) * (Index - 1), --  (trueIndex - 1) is necessary for the index to begin at 0.
			0
		)
		self.Slot.Text = if IsSlotFilled then Tool.Name else ""
		self.Slot.Number.Text = Index
	end

	self._onEditMode:Connect(function()
		warn(Location)
		if EditMode.Enabled == false then
			Cleanup()
			-- clean up backpack stuff
		elseif EditMode.Enabled == true then
			warn(Location, EditMode.ActiveHoverElement)
			if EditMode.ActiveHoverElement then
				if self.Slot == EditMode.ActiveHoverElement then -- Is this particular ItemComponent instance the exact same ItemComponent instance that we have selected?

					-- BACKPACK/TOOLBAR OPTION
					if Location == "Toolbar" then -- If the current location is the Toolbar, we want to be able to move it back into the backpack
						table.insert(
							Garbage,
							self.UI.Backpack.Holder.MouseButton1Click:Connect(function()
								local ToolData = ClientResources.Inventory.Toolbar[Index]
								ClientResources.Inventory.Toolbar[Index] = nil
								table.insert(ClientResources.Inventory.Backpack, ToolData)
								warn(ClientResources)

								EditMode.Enabled = false
								EditMode.ActiveHoverElement = nil
								EditMode.ActiveHoverElementIndex = nil

								Cleanup()
								self._onEditMode:Fire()
								self:render()
							end)
						)
					end

					-- CRATE/CONTAINER OPTION
					if ContainerContents.Container then --If a container is connected, then make it so if the UI is clicked (via MouseButton1Click), an item can be added to that container
						table.insert(
							Garbage,
							self.UI.Parent.ContainerContents.Holder.MouseButton1Click:Connect(function()
								-- if you click the container contents holder, you're adding things into the active container (container currently hooked up to the UI)
								StorageEvent:FireServer(
									"TransferItemToCrate",
									ClientResources.Inventory.Toolbar[Index] :: Tool,
									ContainerContents.Container.Adornee
								)

								EditMode.Enabled = false
								EditMode.ActiveHoverElement = nil
								EditMode.ActiveHoverElementIndex = nil

								Cleanup()
								self._onEditMode:Fire()
								warn(ClientResources.Inventory.Toolbar)
							end)
						)
					end
				end

				if EditMode.ActiveHoverElement ~= self.Slot then -- Is this particular ItemComponent instance different from the ItemComponent instance that we have selected?
					table.insert(
						Garbage,
						self.Slot.MouseEnter:Connect(function()
							local Substitution = self.Slot:Clone()
							table.insert(Substitutions, Substitution)

							self.Slot.BackgroundTransparency = 1
							self.Slot.Number.BackgroundTransparency = 1

							self.Slot.TextTransparency = 1
							self.Slot.Number.TextTransparency = 1

							Substitution.Parent = self.Slot.Parent
							Substitution.Position = UDim2.fromOffset(
								(SIZE + PADDING) * (EditMode.ActiveHoverElementIndex - 1), --  (trueIndex - 1) is necessary for the index to begin at 0.
								0
							)

							table.insert(
								Garbage,
								self.Slot.MouseLeave:Connect(function()
									self.Slot.BackgroundTransparency = 0.4
									self.Slot.Number.BackgroundTransparency = 1

									self.Slot.TextTransparency = 0
									self.Slot.Number.TextTransparency = 0

									Substitution:Destroy()
								end)
							)

							table.insert(
								Garbage,
								self.Slot.MouseButton1Down:Connect(function()
									-- Execute the Swap
									local A = ClientResources.Inventory.Toolbar[Index]
									local B = ClientResources.Inventory.Toolbar[EditMode.ActiveHoverElementIndex]

									local newTable = {
										[Index] = B,
										[EditMode.ActiveHoverElementIndex] = A,
									}

									for itemIndex, item in ClientResources.Inventory.Toolbar do
										if itemIndex == Index or itemIndex == EditMode.ActiveHoverElementIndex then
											continue
										end
										newTable[itemIndex] = item
									end

									ClientResources.Inventory.Toolbar = newTable

									-- Clean up and return to non-edit mode.
									EditMode.Enabled = false
									EditMode.ActiveHoverElement = nil
									EditMode.ActiveHoverElementIndex = nil

									Cleanup()
									self._onEditMode:Fire()
									self:render()
								end)
							)
						end)
					)
				end
			elseif EditMode.ActiveHoverElement == nil then
				print(Location)
				table.insert(
					Garbage,
					self.Slot.MouseButton1Down:Connect(function()
						print("hallo")
						local Substitution = self.Slot:Clone()
						Substitution.ZIndex = 0

						table.insert(
							Garbage,
							RunService.RenderStepped:Connect(function()
								local Location = UserInputService:GetMouseLocation()
								Substitution.Parent = Players.LocalPlayer.PlayerGui.Inventory
								Substitution.Position = UDim2.fromOffset(Location.X, Location.Y - 1)
								Substitution.AnchorPoint = Vector2.new(0.5, 0.5)
							end)
						)

						self.Slot.Visible = false

						EditMode.Enabled = true
						EditMode.ActiveHoverElement = self.Slot
						EditMode.ActiveHoverElementIndex = Index
						self._onEditMode:Fire()

						table.insert(Substitutions, Substitution)
					end)
				)
			end
		end
	end)

	function self:Destroy()
		self.Slot:Destroy()
	end

	return self
end

function InventoryComponent:init()
	local self = InventoryComponent
	self.UI = LocalPlayer:WaitForChild("PlayerGui").Inventory.ToolBar
	self.Items = {}
	self.BackpackItems = {}
	self.EditMode = {
		Enabled = false,
		ActiveHoverElement = nil,
	}
	self._onEditMode = GoodSignal.new()

	UIScale.new(self.Slot, Vector2.new(660, 55), 0.35)

	ContextActionService:BindAction("ToggleEditMode", function(_, UserInputState, InputObject)
		if UserInputState == Enum.UserInputState.End then
			return
		end

		self.EditMode.Enabled = not self.EditMode.Enabled

		self:render() -- This must render first before connections are enabled.
		self._onEditMode:Fire(self.EditMode)
	end, false, Enum.KeyCode.Backquote)

	self._onEditMode:Connect(function()
		if self.EditMode.Enabled then
			return
		end

		for _, UISlot in self.BackpackItems do
			UISlot:Destroy()
		end
	end)

	self:render()

	return self
end

function InventoryComponent:render()
	self:DoCleaning() -- Cleanup from last render
	self.UI.Backpack.Visible = self.EditMode.Enabled

	if not self.EditMode.Enabled then
		local TrueIndex = 0
		for PseudoIndex, Tool in ClientResources.Inventory.Toolbar do
			TrueIndex += 1

			local Slot = self.UI.Templates.ItemTemplate:Clone()
			Slot.Text = Tool.Name
			Slot.Number.Text = PseudoIndex
			Slot.Parent = self.UI
			Slot.Position = UDim2.fromOffset(
				(SIZE + PADDING) * (TrueIndex - 1), --  (trueIndex - 1) is necessary for the index to begin at 0.
				0
			)
			table.insert(self.Items, Slot)
		end
		self.UI.Size = UDim2.fromOffset((SIZE + PADDING) * TrueIndex, 55)
	else
		for index = 1, 10 do
			local Tool = ClientResources.Inventory.Toolbar[index]
			local UISlot = NewItemSlotComponent(index, Tool, "Toolbar")
			table.insert(self.Items, UISlot)
		end
		self.UI.Size = UDim2.fromOffset((SIZE + PADDING) * 10, 55)

		-- Setup backpack
		for index, Tool in ClientResources.Inventory.Backpack do
			local UISlot = NewItemSlotComponent(index, Tool, "Backpack")
			table.insert(self.BackpackItems, UISlot)
		end
	end
end

function InventoryComponent:DoCleaning()
	for _, UISlot in self.Items do
		UISlot:Destroy()
	end
end

return InventoryComponent
