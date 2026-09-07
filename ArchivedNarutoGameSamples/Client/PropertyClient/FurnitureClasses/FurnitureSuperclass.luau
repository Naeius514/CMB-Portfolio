local Furniture = {}
Furniture.__index = Furniture

local UIPrompt = require(game.StarterPlayer.StarterPlayerScripts.PromptModule)

export type FurnitureObject = {
	Adornee: Model,
	Prompt: ProximityPrompt,
	Connections: {},

	ActivatePromptConnections: () -> nil,
	DeactivatePromptConnections: () -> nil,
}

--[=[

    Instantiates a member of the Furniture class,
    providing basic functionality for all furniture. 

    The superclass is only to be instantiated by a subclass in its constructor.
]=]
function Furniture.new(Adornee: Model)
	assert(typeof(Adornee) == "Instance" and Adornee:IsA("Model"), "All Furniture must be a Model.")
	warn(Adornee.PrimaryPart)
	assert(
		Adornee.PrimaryPart ~= nil,
		"All Furniture (a Roblox Model) must have a PrimaryPart. No PrimaryPart found for: " .. Adornee:GetFullName()
	)

	local self = setmetatable({}, Furniture)
	self.Adornee = Adornee
	self.Prompt = Instance.new("ProximityPrompt")
	self.Connections = {}
	self.__index = self -- This is a superclass for other furniture;

	self.Prompt.Parent = Adornee
	self:ActivatePromptConnections()

	UIPrompt.new(Adornee.PrimaryPart, {
		{
			DisplayText = "Hello!",
			Callback = function()
				print("hola!")
			end,
		},

		{
			DisplayText = "Hello!",
			Callback = function()
				print("hola!")
			end,
		},

		{
			DisplayText = "Hello!",
			Callback = function()
				print("hola!")
			end,
		},

		{
			DisplayText = "Hello!",
			Callback = function()
				print("hola!")
			end,
		},
		{
			DisplayText = "Hello!",
			Callback = function()
				print("hola!")
			end,
		},
		{
			DisplayText = "AHORA!!",
			Callback = function()
				print("hola!")
			end,
		},
	})
	return self
end

--[=[
    Activates connections that makes the Furniture's proximity prompt work.
]=]
function Furniture:ActivatePromptConnections()
	local Prompt = self.Prompt
	table.insert(
		self.Connections,
		Prompt.PromptShown:Connect(function()
			warn("Prompt has been displayed for", self.Adornee)
		end)
	)

	table.insert(
		self.Connections,
		Prompt.PromptHidden:Connect(function()
			warn("Prompt is no longer displayed for", self.Adornee)
		end)
	)
end

function Furniture:DeactivatePromptConnections()
	for index in pairs(self.Connections) do
		table.remove(self.Connections, index)
	end
end

return Furniture
