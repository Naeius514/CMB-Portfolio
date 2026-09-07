local FurnitureSuperclass = require(script.Parent.FurnitureSuperclass)

local Bed = setmetatable({}, { __index = FurnitureSuperclass })
Bed.__index = Bed

function Bed.new(Adornee)
	local self = FurnitureSuperclass.new(Adornee)
	setmetatable(self, Bed)
	warn("Bed!")

	return self
end

return Bed
