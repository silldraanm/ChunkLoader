local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

local unrendered = ReplicatedStorage.Unrendered
if not unrendered then
	unrendered = Instance.new("Folder")
	unrendered.Name = "Unrendered"
	unrendered.Parent = ReplicatedStorage
end

local player = Players.LocalPlayer
local character = player.Character
local hrp: Part = character:WaitForChild("HumanoidRootPart")
local humanoid: Humanoid = character:WaitForChild("Humanoid")

local Constructor = {}

local ChunkLoader = {}
ChunkLoader.__index = ChunkLoader

type ChunkLoader = typeof(ChunkLoader)

local function GetTableNumItems(tbl)
	local num = 0
	for _, item in tbl do
		if item then
			num += 1
		end
	end

	return num
end

function Constructor.new(renderDistance: number, chunkSize: number, dontUnrender: {Instance}): ChunkLoader
	local self = setmetatable({}, ChunkLoader)
	self.renderDistance = renderDistance
	self.chunkSize = chunkSize
	
	self.renderedChunks = {}
	self.cache = {}
	self.dontUnrender = dontUnrender
	
	return self
end



-- Add more instances to the dontUnrender list
function ChunkLoader:DontUnrender(instances: Instance | {Instance})
	if typeof(instances) == "Instance" then
		table.insert(self.dontUnrender, instances)
	elseif typeof(instances) == "table" then
		for _, inst in instances do
			table.insert(self.dontUnrender, inst)
		end
	end
end

-- Gets the position of a chunk using the specified position
function ChunkLoader:GetChunkPosition(position: Vector3)
	local x = math.floor(position.X / self.chunkSize)
	local z = math.floor(position.Z / self.chunkSize)

	-- Calculate the corner position
	local cornerX = x * self.chunkSize
	local cornerZ = z * self.chunkSize

	return Vector2.new(cornerX, cornerZ)
end

-- Updates a specific chunk using the chunkPosition
function ChunkLoader:UpdateChunk(reference: Vector3, chunkPosition: Vector2)
	if not self.cache[chunkPosition] then 
		return 
	end
	local cache = self.cache[chunkPosition]
	
	for element: BasePart, parent: Instance in cache.elements do
		if element.Parent == nil then continue end
		if table.find(self.dontUnrender, element, 1) then continue end
		
		local closestPoint = element:GetClosestPointOnSurface(reference)
		local distance = (closestPoint-reference).Magnitude
		
		if distance > self.renderDistance*self.chunkSize then
			element.Parent = unrendered
			self.renderedChunks[chunkPosition] = nil
		else
			element.Parent = parent
			self.renderedChunks[chunkPosition] = true
		end
	end
end

-- Updates all chunks
function ChunkLoader:UpdateChunks()
	for position: Vector2, _ in self.cache do
		-- Change origin to whatever youd like the chunks to render from
		local origin = hrp.Position
		self:UpdateChunk(origin, position)
	end
end

-- Fills cache to be rendered or unrendered, can be called multiple times but recommended to only call at game startup
function ChunkLoader:FillCache(origin: Vector3, radius: number)
	local originChunk = self:GetChunkPosition(origin)
	local chunkHeight = 500
	
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams:AddToFilter(self.dontUnrender)
	
	local processedChunks = 0
	local playerCharacterFilter = {}

	-- Gather all player characters once and add to the filter
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(playerCharacterFilter, player.Character)
		end
	end
	overlapParams:AddToFilter(playerCharacterFilter)
	
	warn("Filling cache...")

	for dx = -radius, radius do
		for dz = -radius, radius do
			local chunkPosition = Vector2.new(originChunk.X + (dx * self.chunkSize), originChunk.Y + (dz * self.chunkSize))
			local cframe = CFrame.new(chunkPosition.X + self.chunkSize/2, 0, chunkPosition.Y + self.chunkSize/2)
			local size = Vector3.new(self.chunkSize, chunkHeight, self.chunkSize)

			local query = workspace:GetPartBoundsInBox(cframe, size, overlapParams)
			local elements = {}

			for _, part in query do
				elements[part] = part.Parent
			end
			-- Check if elements are empty, this saves on memory by not storing empty chunks
			if GetTableNumItems(elements) < 2 then continue end
			
			self.cache[chunkPosition] = { elements = elements }

			processedChunks += 1
			if processedChunks % 20 == 0 then
				RunService.Heartbeat:Wait()
			end
		end
		RunService.Heartbeat:Wait()  -- Extra wait after completing each row
	end
	
	warn("Cache filled!")
end

-- Autoupdates chunks every renderstep
function ChunkLoader:BindToRenderStepped()
	RunService:BindToRenderStep(
		"ChunkLoader",
		Enum.RenderPriority.Camera.Value,
		function()
			self:UpdateChunks()
		end
	)
end

-- Autoadds any instances to the cache
function ChunkLoader:CacheAddedDescendants()
	game.DescendantAdded:Connect(function(descendant: BasePart|Model)
		if not descendant:IsA("BasePart") or not descendant:IsA("Model") then return end
		
		local chunkPosition = descendant:GetPivot().Position
		
		self.cache[chunkPosition] = self.cache[chunkPosition] or {}
		local cache = self.cache[chunkPosition]

		self.cache[chunkPosition].elements = cache.elements or {}

		if descendant:IsA("BasePart") then
			self.cache[chunkPosition].elements[descendant] = descendant.Parent
		elseif descendant:IsA("Model") then
			for _, constituent: Instance in descendant:GetDescendants() do
				if not constituent:IsA("BasePart") then continue end
				
				self.cache[chunkPosition].elements[constituent] = constituent.Parent
			end
		end
	end)
end

function ChunkLoader:UnbindFromRenderStepped()
	RunService:UnbindFromRenderStep("ChunkLoader")
end

return Constructor