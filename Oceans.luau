
--[=[

    Oceans.luau
    
    Ability to instantiate an ocean. 
    Primarily intended for Kirigakure.
    Comment samples explaining the logic is provided.

]=]

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UNDERWATER_BLUR_INTENSITY = 12

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

--local Janitor = require(ReplicatedStorage.Packages.Janitor);
local ZonePlus = require(ReplicatedStorage.Packages.ZonePlus)
--local Signal = require(ReplicatedStorage.Packages.Signal)

type OceanWave = {
	Direction: Vector3, -- The direction the wave is traveling
	Amplitude: number, -- The height of the wave
	Speed: number, -- How fast the wave moves via "B" in, for example, sin(Bx)
	PhaseOffset: number, -- Any additional offset
}

local Ocean = {}
Ocean.__index = Ocean

--[=[

    Constructs a new ocean object.

    @param CFrame CFrame The position and orientation of the ocean
    @param Size table The size of the ocean along the XZ plane.
    @param gridSize number The number of VERTICIES (i.e 20x20) along the XZ plane.
    @param oceanWaves {OceanWave}

]=]
---comment

function Ocean.new(CFrame: CFrame, Size: { X: number, Z: number }, gridSize: number, oceanWaves: { OceanWave })
	local self = setmetatable({}, Ocean)

	self.editableMesh = AssetService:CreateEditableMesh()
	self.gridSize = gridSize -- Makes a grid size of, say, 20x20. 20 verticies along the X. 20 verticies along the Z. 400 in total.
	self.Size = Vector3.new(Size.X, 0, Size.Z)
	self.CFrame = CFrame

	self.vertexIds = {}
	self.initialPositionsOfVerticies = {}

	self.oceanWaves = oceanWaves

	self.isPlayerOnOcean = false

	self.animateOceanConnection = nil -- RBXScriptSignal

	--self.janitor = Janitor.new()

	-- The order matters:
	self:_createGridOfVerticies()
	self:_createQuads()
	self:_applyGerstnerWaves()

	self.meshPart = self:_instantiateMesh(true)
	self.connections = {}
	self.zone = self:_createZone(true)

	return self
end

function Ocean:_createZone(visualizeZoneWithPart: boolean)
	local zoneSize = self.Size + Vector3.new(0, 25, 0)
	local zone = ZonePlus.fromRegion(self.CFrame, zoneSize)

	-- local zone = ZonePlus.new(
	--     self.meshPart
	-- )

	table.insert(
		self.connections,
		zone.localPlayerEntered:Connect(function()
			print("You are on the ocean!")
			self.isPlayerOnOcean = true
		end)
	)

	table.insert(
		self.connections,
		zone.localPlayerExited:Connect(function()
			print("You are not on the ocean!")
			self.isPlayerOnOcean = false
		end)
	)

	if visualizeZoneWithPart then
		local visualizer = Instance.new("Part")
		visualizer.CFrame = self.CFrame
		visualizer.Size = zoneSize
		visualizer.Transparency = 0.65
		visualizer.Anchored = true
		visualizer.Name = "ZoneVisualizer"
		visualizer.CanCollide = false
		visualizer.Parent = workspace
	end

	return zone
end
function Ocean:getWaveHeightAt(x: number, z: number): number
	local position = Vector3.new(x, 0, z)
	local totalHeight = 0
	local TIME = os.clock()

	for _, oceanWave in pairs(self.oceanWaves) do
		local dot = oceanWave.Direction:Dot(position)
		totalHeight += oceanWave.Amplitude * math.cos(oceanWave.Speed * (dot - TIME) + oceanWave.PhaseOffset)
	end

	return totalHeight
end

--[=[
    Creates a grid of verticies on the XZ plane of the mesh.
    Where the X-axis represents the columns and the Z-axis represents the rows.
    Because this is a grid, there will be a vertex at every possible (x, z) pair.


    Assume the grid is 5x5
    In the example below,
    Z is the vertical axis. 
    X is the horizontal axis
    "V" denotes "VERTEX"

    Z

    5   V  V  V  V  V
    4   V  V  V  V  V 
    3   V  V  V  V  V
    2   V  V  V  V  V
    1   V  V  V  V  V

    X   1  2  3  4  5 

    As you can see, there is a vertex at every possible (x, z) pair.
    (1,1), (1,2), (1,3), (1,4), (1,5)
    (2,1), (2,2), (2,3), (2,4), (2,5)
    (3,1)...



    Each Vertex has an ORIGINAL/STARTING/INITIAL POSITION and
    Each Vertex has a VertexID that is used by the EditablEditableMesh.

    Because this is a grid, the VertexIDs and Original Positions are stored in two separate 2D Tables named
    "vertexIds" and "initialPositionsOfVerticies" respectively.

    vertexIDs[x][z] gives you the vertex ID at any grid position.
    initialPositionsOfVerticies[x][z] gives you the original/initial position at any grid position.
    This is necessary because the verticies will eventually be displaced by the offset created by sine/cos,
    and the initial starting point is needed to be used as a reference.

]=]
function Ocean:_createGridOfVerticies()
	-- the variables "x" and "z" correspond to the XZ axes respectively.
	for x = 1, self.gridSize do
		local initialPositionColumn = {}
		local vertexIdColumn = {}

		for z = 1, self.gridSize do
			local Position = Vector3.new(x, 0, z)
			table.insert(vertexIdColumn, self.editableMesh:AddVertex(Position))
			table.insert(initialPositionColumn, Position)
		end
		table.insert(self.vertexIds, vertexIdColumn)
		table.insert(self.initialPositionsOfVerticies, initialPositionColumn)
	end
end

--[[
    Given a grid of verticies created using Ocean:_createGridOfVerticies()
    The verticies are not "connected" to each other. They're just placed down. 

    This method essentially uses the "knife" tool in Blender to 
    create the cuts between verticies.
    
    quad = 2 right triangles = square
    To do this, you can connect the verticies by "cutting out" / drawing 2 right triangles between
    neighboring verticies. Cutting out 2 right triangles in this manner creates squares, 
    which can also refer to a "quad."

    Specifically, it makes a square with a diagonal going from one corner to another. 
    The square is not just the outer box -- because each right triangle has a hypotenuse.
    the diagonal is the shared edge between the two triangles. 
        
    The verticies of the first triangle in relation to any given vertex is:
    (x, z) (x + 1, z), (x, z + 1)

    The verticies of the second triangle is
    (x + 1, z), (x + 1, z + 1), (x, z + 1).

    Suppose you have a grid that is 5x5
   
    Z

    5   V--V--V--V--V
        |\ |\ |\ |\ |
    4   V--V--V--V--V
        |\ |\ |\ |\ |
    3   V--V--V--V--V
        |\ |\ |\ |\ |
    2   V--V--V--V--V
        |\ |\ |\ |\ |
    1   V--V--V--V--V

    X   1  2  3  4  5


    Each |\ | is one quad — two triangles. 
    The squares only exist in the INTERIOR of the GRID. 
    The rightmost column (X=5) and top row (Z=5) are only ever right/top edges — they never start a square. 
    So the loop only starts squares from X=1 to X=4 and Z=1 to Z=4, which is gridSize - 1.

    If you have 5 vertices along an axis, you can only make 4 squares — 
    because the last vertex has no neighbor to its right to complete a square with.
    So the loop goes to 4 (gridSize - 1), not 5 (gridSize.)



]]
function Ocean:_createQuads()
	local VertexIDs = self.vertexIds
	local eMesh = self.editableMesh

	for x = 1, self.gridSize - 1 do
		for z = 1, self.gridSize - 1 do
			-- Carve out Triangle 1
			eMesh:AddTriangle(VertexIDs[x][z], VertexIDs[x + 1][z], VertexIDs[x][z + 1])

			-- Carve out Triangle 2
			eMesh:AddTriangle(VertexIDs[x + 1][z], VertexIDs[x + 1][z + 1], VertexIDs[x][z + 1])

			-- Carving out both creates a square/quad where both triangles share a diagonal.
		end
	end
end

--[=[
    
    Applies the "gerstner waves" by transforming each vertex
    in the grid above appropriately using sine and cosine.

    Furthermore, if there are multiple waves, their displacement will be
    summed together, causing what appears to be "separate" or "distinct" waves to result
    in a unified motion that depicts all of the waves.

]=]
function Ocean:_applyGerstnerWaves()
	local function createWave(initialPositionOfVertex: Vector3, oceanWave: OceanWave): Vector3
		local TIME = os.clock()
		--[[ 
        
            Leveraging the "projection" interpretation of the the dot product 
            The Vector "Direction" is used as a custom axis, and the result of the dot product
            is a "projection" as it attempts to model (or "project") the "initialPositionOfVertex" (which is currently relative to the world)
            onto the custom axis as a 1D coordinate--as if the "custom axis" were 1D axis or number line. 

            It's  can traverse along
        ]]
		local CoordinateAlongCustomAxis = oceanWave.Direction:Dot(initialPositionOfVertex)

		--[[
         its actually INITIAL POSITION + SINUSOIDAL OFFSET -->  The oscilation caused by the waves are added as an OFFSET *from* the original position. 
         Ex: x_new = initial_position + amplitude * math.sin(x)...
         We are not adding it here because it will be added in the Heartbeat to avoid adding it to the sum more than once.
        ]]

		--[[
            A custom direction vector is always "this much X," "this much Y," "this much Z"
            The * waveDirection.X  is division dressed up as multiplicaction. You're allocating how much of the "direction" to give to the X and Z components.
            To preseve the amount units that is defined in each dimension/axis of the custom direction vector. 
        ]]

		local x_new = oceanWave.Amplitude
			* math.sin(oceanWave.Speed * (CoordinateAlongCustomAxis - TIME) + oceanWave.PhaseOffset)
			* oceanWave.Direction.X
		local z_new = oceanWave.Amplitude
			* math.sin(oceanWave.Speed * (CoordinateAlongCustomAxis - TIME) + oceanWave.PhaseOffset)
			* oceanWave.Direction.Z

		local y_new = oceanWave.Amplitude
			* math.cos(oceanWave.Speed * (CoordinateAlongCustomAxis - TIME) + oceanWave.PhaseOffset)

		return Vector3.new(x_new, y_new, z_new)
	end

	self.animateOceanConnection = RunService.Heartbeat:Connect(function()
		for x = 1, self.gridSize - 1 do
			for z = 1, self.gridSize - 1 do
				local vertexId = self.vertexIds[x][z]
				local initialPosition = self.initialPositionsOfVerticies[x][z] :: Vector3

				local sum = initialPosition -- + more will be added
				for _, oceanWave: OceanWave in pairs(self.oceanWaves) do
					local waveDisplacement = createWave(initialPosition, oceanWave)
					sum += waveDisplacement
				end

				-- The wave displacement is applied at every vertex
				self.editableMesh:SetPosition(vertexId, sum)
			end
		end
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = { self.meshPart }

		local origin = Character.HumanoidRootPart.Position
		local direction = Vector3.new(0, -10, 0)
		local result = workspace:Raycast(origin, direction, raycastParams)

		if result then
			local waveY = self:getWaveHeightAt(origin.X, origin.Z)
			local currentCFrame = Character.HumanoidRootPart.CFrame
			Character.HumanoidRootPart.CFrame = CFrame.new(
				origin.X,
				result.Position.Y + waveY + Character["Left Leg"].Size.Y + 0.5,
				origin.Z
			) * currentCFrame.Rotation
		end
		if self.isPlayerOnOcean then
		end
	end)
end

function Ocean:_instantiateMesh(displayPivotPoint: boolean)
	local meshPart = AssetService:CreateMeshPartAsync(Content.fromObject(self.editableMesh))

	meshPart.Name = "Ocean"
	meshPart.CastShadow = false -- MAY NEED TO CHANGE?
	meshPart.Anchored = true

	-- Appearance:
	meshPart.Material = Enum.Material.Glacier
	meshPart.Transparency = 0.5
	meshPart.Color = Color3.fromRGB(0, 85, 255)

	meshPart.Size = self.Size

	-- Positioning:
	--[[ 
        The Pivot Point is in a corner of the mesh.
        So, we are essentially calculating the center of the mesh
        And then translating the ocean relative to that center manually.

        self.CFrame * meshPart.PivotOffset:Inverse() == CFrame - PivotOffset
        Subtraction dressed up as division.
    ]]
	meshPart.PivotOffset = (CFrame.new(self.Size.X / 2, 0, self.Size.Z / 2))
	meshPart.CFrame = self.CFrame * meshPart.PivotOffset:Inverse()

	if displayPivotPoint then
		local PIVOT = Instance.new("Part")
		PIVOT.Size = Vector3.new(3, 3, 3)
		PIVOT.Color = Color3.fromRGB(255, 0, 0)
		PIVOT.CFrame = self.CFrame --* meshPart.PivotOffset:Inverse();
		PIVOT.Anchored = true
		PIVOT.Parent = workspace
	end
	meshPart.Parent = workspace

	return meshPart
end

function Ocean:grantUnderwaterEffects()
	local ColorCorrection = Instance.new("ColorCorrectionEffect")
	ColorCorrection.TintColor = self.meshPart.Color
	ColorCorrection.Parent = game.Lighting

	local UnderwaterBlur = Instance.new("BlurEffect")
	UnderwaterBlur.Size = UNDERWATER_BLUR_INTENSITY
	UnderwaterBlur.Parent = game.Lighting
end

return Ocean
