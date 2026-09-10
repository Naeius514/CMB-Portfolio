local Players = game:GetService("Players");
local LocalPlayer = Players.LocalPlayer;

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait();

local TreeDetectionParams = OverlapParams.new()
TreeDetectionParams.FilterType = Enum.RaycastFilterType.Exclude -- TODO: Figure out how to use Include so it only sees trees
TreeDetectionParams.FilterDescendantsInstances = {Character}


local MAX_JUMP_RANGE = 50 -- Branches can be at most X studs away from you
local MIN_JUMP_RANGE = 5 -- Branches must be at least X studs away from you (no need to jump to a branch you're standing on?)
local CONE_OF_VISION_LIMIT = 0.7 -- Only branches within the user's "cone of vision" are considered between (1 and X)
local FREQUENCY = 1.25 -- How "frequent" or how fast the highlight oscilates

local DETECTION_SIZE = Vector3.one * MAX_JUMP_RANGE -- The Y-Axis height shouldn't be too big.
local HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(84, 255, 5)
local HIGHLIGHT_MAX_OUTLINE_TRANSPARENCY = 0.5

type Tree = {
	Leaves: Folder,
	Branches: Folder,
	Trunk: BasePart
} & Model


--[=[
	Handles branch logic after official Trees have been passed in
	from FilterTrees()
]=]
local function Branches(Tree: Tree)

	-- Filter branches for each tree
	for _, branch: BasePart in Tree.Branches:GetChildren() do

		-- Cast a ray to each branch to find any obstructions in the way of the path
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude -- We are only looking for obstructions that are in the way, so the tree does not need to be considered in this cast
		Params.FilterDescendantsInstances = {Tree} 

		local Direction = (branch.Position - Character.PrimaryPart.Position);
		local Dot = Character.PrimaryPart.CFrame.LookVector:Dot(Direction.Unit)
		warn("DOT:", Dot)
		if 
			(Direction.Magnitude >= MIN_JUMP_RANGE and Direction.Magnitude <= MAX_JUMP_RANGE) and -- Treat "Direction" as a Distance vector for a moment and make sure its within suitable range.
			(Dot <= 1 and Dot >= CONE_OF_VISION_LIMIT) -- Only branches within the user's "cone of vision" are considered between (1 and 0.7)
		then


			local Result = workspace:Raycast(
				Character.PrimaryPart.Position,
				Direction,
				Params
			)

			-- If no result has been found, then the path is clear:
			if not Result then
				warn("Magnitude", Direction.Magnitude, Dot)
				-- Highlight branches that are accessible to the player
				local Highlight = Instance.new("Highlight");
				Highlight.FillTransparency = 1;
				Highlight.OutlineColor = HIGHLIGHT_OUTLINE_COLOR;
				Highlight.OutlineTransparency = HIGHLIGHT_MAX_OUTLINE_TRANSPARENCY;
				Highlight.Parent = branch;
				
				while true do
					print("hello!")
					Highlight.OutlineTransparency = 
						1 - (HIGHLIGHT_MAX_OUTLINE_TRANSPARENCY) * math.abs(math.sin(FREQUENCY * os.clock())) -- Need "1 - " to invert the sine wave; because fully transparent = 1
					task.wait()
				end
			end

		end
	end
end


local function FindTrees()

	-- GET TREE CANDIDATES
	local Position = CFrame.new(Character.PrimaryPart.Position)
	local TreeCandidates = workspace:GetPartBoundsInBox(
		Position,
		DETECTION_SIZE,
		TreeDetectionParams
	)

	-- visualize the detection ranges
	local Part = Instance.new("Part")
	Part.CFrame = Position
	Part.Size = DETECTION_SIZE
	Part.Transparency = 0.5
	Part.CanCollide = false
	Part.Anchored = true
	Part.Color = Color3.fromRGB(255, 0, 0)
	Part.Name = "MAX_DISTANCE_VISUALIZER"
	Part.Parent = workspace

	local Min = Part:Clone()
	Min.Color = Color3.fromRGB(0, 0, 255)
	Min.Size = Vector3.one * MIN_JUMP_RANGE
	Min.Parent = workspace
	Min.Name = "MIN_DISTANCE_VISUALIZER"

	task.spawn(function()
		task.wait(30)
		Part:Destroy()
		Min:Destroy()
	end)


	-- FILTER THROUGH THE CANDIDATES TO FIND TREES
	local Trees: { Tree } = {}
	for _, treeChild:BasePart in pairs(TreeCandidates) do

		-- Models are not detected in the spatial query, so we must use once of its children to find the Tree model.
		local tree: Tree = treeChild:FindFirstAncestorOfClass("Model")

		if 
			tree and
			not Trees[tree] and
			(tree:HasTag("Tree") or tree.Name == "Tree")
		then
			Trees[tree] = tree
		end
	end

	-- Iterate through each Tree and find its branches
	warn("TREES", Trees)
	for _, Tree in pairs(Trees) do
		Branches(Tree)
	end

end

Character.Humanoid.Jumping:Connect(FindTrees)