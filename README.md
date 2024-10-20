# ChunkLoader
INSTRUCTIONS:

Copy the chunkLoaderModule code and paste it into a ModuleScript inside Studio.

Then just require the module inside of a LocalScript and you're set!

Code example:

---------------------------------------------------------------------------------------
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local modules = ReplicatedStorage.Modules

local ChunkLoader = require(modules.OOP.ChunkLoader)

local chunkSize = 64
local renderDistance = 5 -- (chunks)

local Chunks = ChunkLoader.new(renderDistance, chunkSize, {workspace.WaterLayer})

Chunks:FillCache(workspace.SpawnLocation.Position, 100) -- 100 means 100 chunks of size chunkSize around SpawnLocation's position

Chunks:BindToRenderStepped() -- Updates cached chunks every RenderStep

---------------------------------------------------------------------------------------
