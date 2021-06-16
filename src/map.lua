-- AutoMap: Copyright 2021 Vincent Robinson under the MIT license. See `license.txt` for more info.

-- An interface for modifying a map in a WAD. A `Map` object can also be used as a temporary
-- object for copying and pasting large chunks of geometry, such as with `Map.copy` and
-- `Map:merge`.
Map = Object:inherit()

function Map:_init()
	self.things = {}
	self.linedefs = {}
	self.sidedefs = {}
	self.vertices = {}
	self.sectors = {}
end

-- Create a new blank map of the specified name.
function Map.new(name)
	local self = Map()

	self.name = name

	return self
end

-- Create a new map as a copy of another map.
function Map.copy(other)
	local self = Map()

	self.name = name
	self:merge(other)

	return self
end

function Map:_add_lump(lump, name, var, ctor, size)
	assert(lump.name == name, "Invalid map lumps: no " .. name)
	for i = 1, #lump.content, size do
		self[var][#self[var] + 1] = ctor.from_string(lump.content:sub(i, i + size - 1))
	end
end

-- Create a map from a set of map lumps from a WAD file including the map marker.
function Map.from_lumps(lumps)
	local self = Map()

	local lump = lumps[1]
	assert(lump.content == "", "Invalid map lumps: no map marker")
	self.name = lump.name

	-- Out of order since some things depend on others for table cross-references.
	self:_add_lump(lumps[2], "THINGS",   "things",   Thing,   10)
	self:_add_lump(lumps[6], "SECTORS",  "sectors",  Sector,  26)
	self:_add_lump(lumps[4], "SIDEDEFS", "sidedefs", Sidedef, 30)
	self:_add_lump(lumps[5], "VERTEXES", "vertices", Vertex,  4 )
	self:_add_lump(lumps[3], "LINEDEFS", "linedefs", Linedef, 14)

	return self
end

function Map:_to_lump(name, var)
	local to_concat = {}
	for _, whatever in ipairs(self[var]) do
		to_concat[#to_concat + 1] = whatever:to_string()
	end

	return Lump.new(name, table.concat(to_concat))
end

-- Convert this map to a set of lumps for writing to a WAD.
function Map:to_lumps()
	return {
		Lump.new(self.name, ""),
		self:_to_lump("THINGS",   "things"  ),
		self:_to_lump("LINEDEFS", "linedefs"),
		self:_to_lump("SIDEDEFS", "sidedefs"),
		self:_to_lump("VERTEXES", "vertices"),
		self:_to_lump("SECTORS",  "sectors" )
	}
end

function Map:_copy_table(other, var, ctor, func)
	for _, stuff in ipairs(self[var]) do
		local copied = ctor.copy(stuff)
		if func then
			func(copied)
		end
		self[var][#self[var] + 1] = copied
	end
end

-- Adds all of some map's geometry to this one. No attempts to correct overlapping geometry
-- is made.
function Map:merge(other)
	self:_copy_table(other, "things",   Thing  )
	self:_copy_table(other, "linedefs", Linedef, function(linedef)
		linedef.vertices[1] = linedef.vertices[1] + #self.vertices
		linedef.vertices[2] = linedef.vertices[2] + #self.vertices

		linedef.sidedefs[1] = linedef.sidedefs[1] + #self.sidedefs
		linedef.sidedefs[2] = linedef.sidedefs[2] + #self.sidedefs
	end)
	self:_copy_table(other, "sidedefs", Sidedef, function(sidedef)
		sidedef.sector = sidedef.sector + #self.sidedefs
	end)
	self:_copy_table(other, "vertices", Vertex )
	self:_copy_table(other, "sectors",  Sector )
end

-- An interface for modifying things
Thing = Object:inherit()
Thing._lookup = {
	x     = 1,
	y     = 2,
	angle = 3,
	type  = 4,
	flags = 5
}

Thing.flag = {
	EXTRA   = 0x1,
	FLIP    = 0x2,
	SPECIAL = 0x4,
	AMBUSH  = 0x8
}

-- Construct a `Thing` with default values.
function Thing.new()
	local self = Thing()

	self.x     = 0
	self.y     = 0
	self.angle = 0
	self.type  = 0
	self.flags = 0

	return self
end

-- Create a new `Thing` as a copy of another `Thing`.
function Thing.copy(other)
	local self = Thing()

	self.x     = other.x
	self.y     = other.y
	self.angle = other.angle
	self.type  = self.type
	self.flags = self.flags

	return self
end

-- Construct a `Thing` object from a single binary thing.
function Thing.from_string(content)
	local self = Thing()

	self.x, self.y, self.angle, self.type, self.flags = string.unpack("< i2 i2 i2 I2 I2", content)

	return self
end

-- Return the binary representation of this thing as a string.
function Thing:to_string()
	return string.pack("< i2 i2 i2 I2 I2", self.x, self.y, self.angle, self.type, self.flags)
end

-- Get/set the type of the thing without packed parameter information.
function Thing:get_type()
	return self.type & 0x0FFF
end
function Thing:set_type(type)
	self.type = (self.type & 0xF000) | (type & 0x0FFF)
end

-- Get/set the parameter of the thing without packed type information.
function Thing:get_param()
	return self.type >> 12
end
function Thing:set_param(param)
	self.type = (self.type & 0x0FFF) | ((param << 12) & 0xF000)
end

-- Get/set the flags of the thing without packed height information.
function Thing:get_flags()
	return self.flags & 0x000F
end
function Thing:set_flags(flags)
	self.flags = (self.flags & 0xFFF0) | (flags & 0x000F)
end

-- Get/set the height of the thing without packed flag information.
function Thing:get_height()
	return self.flags >> 4
end
function Thing:set_height(height)
	self.flags = (self.flags & 0x000F) | ((height << 4) & 0xFFF0)
end

-- An interface for modifying linedefs
Linedef = Object:inherit()
Linedef._lookup = {
	vertices = 1,
	flags    = 2,
	action   = 3,
	tag      = 4,
	sidedefs = 5
}

Linedef.flag = {
	IMPASSABLE         = 0x1,
	BLOCK_ENEMIES      = 0x2,
	DOUBLE_SIDED       = 0x4,
	UPPER_UNPEGGED     = 0x8,
	LOWER_UNPEGGED     = 0x10,
	SLOPE_SKEW         = 0x20,
	NOT_CLIMBABLE      = 0x40,
	NO_MIDTEXTURE_SKEW = 0x80,
	PEG_MIDTEXTURE     = 0x100,
	SOLID_MIDTEXTURE   = 0x200,
	REPEAT_MIDTEXTURE  = 0x400,
	NETGAME_ONLY       = 0x800,
	NO_NETGAME         = 0x1000,
	EFFECT_6           = 0x2000,
	BOUNCY_WALL        = 0x4000,
	TRANSFER_LINE      = 0x8000
}

-- Construct a `Linedef` object with default values. If `vertices` and `sidedefs[1]` are not
-- provided, then they must be set to a value at a later time.
-- The default value for flags will be `DOUBLE_SIDED` if there are two sidedefs provided,
-- `IMPASSABLE` if only one, and 0 if the sidedefs are not yet filled in.
function Linedef.new(vertices, sidedefs)
	local self = Linedef()

	vertices = vertices or {}
	sidedefs = sidedefs or {}

	local flags = 0
	if sidedefs[2] then
		flags = DOUBLE_SIDED
	elseif sidedefs[1] then
		flags = IMPASSABLE
	end

	self.vertices = {
		vertices[1] or 0,
		vertices[2] or 0
	}
	self.flags    = flags
	self.action   = 0
	self.tag      = 0
	self.sidedefs = {
		sidedefs[1] or 0,
		sidedefs[2] or 0
	}

	return self
end

-- Create a new `Linedef` as a copy of another `Linedef`. If any `vertices` or `sidedefs` are
-- provided, they will be the new vertices and sidedefs indices, otherwise the other's vertices
-- and sidedefs will be used.
function Linedef.copy(other, vertices, sidedefs)
	local self = Linedef()

	vertices = vertices or {}
	sidedefs = sidedefs or {}

	self.vertices = {
		vertices[1] or other.vertices[1],
		vertices[2] or other.vertices[2]
	}
	self.flags       = other.flags
	self.action      = other.action
	self.tag         = other.tag
	self.sidedefs = {
		sidedefs[1] or other.sidedefs[1],
		sidedefs[2] or other.sidedefs[2]
	}

	return self
end

-- Construct a `Linedef` object from a single binary linedef.
function Linedef.from_string(content)
	local self = Linedef()

	self.vertices = {}
	self.sidedefs = {}

	self.vertices[1], self.vertices[2], self.flags, self.action, self.tag,
			self.sidedefs[1], self.sidedefs[2] = string.unpack("< i2 i2 I2 I2 I2 I2 I2", content)

	self.vertices[1] = self.vertices[1] + 1
	self.vertices[2] = self.vertices[2] + 1

	self.sidedefs[1] = self.sidedefs[1] + 1
	if self.sidedefs[2] == 0xFFFF then
		self.sidedefs[2] = 0
	else
		self.sidedefs[2] = self.sidedefs[2] + 1
	end

	return self
end

-- Return the binary representation of this linedef as a string. A swap table of vertices and
-- sidedefs must be provided to convert table references into integer reference.
function Linedef:to_string()
	local sidedef_2 = 0xFFFF
	if self.sidedefs[2] ~= 0 then
		sidedef_2 = self.sidedefs[2] - 1
	end

	return string.pack("< i2 i2 I2 I2 I2 I2 I2", self.vertices[1] - 1, self.vertices[2] - 1,
			self.flags, self.action, self.tag, self.sidedefs[1] - 1, sidedef_2)
end

-- Get the n'th vertex that this linedef points to, assuming it is a part of map `map`.
function Linedef:get_vertex(map, n)
	return map.vertices[self.vertices[n]]
end

-- Get the n'th sidedef that this linedef points to, assuming it is a part of map `map`. If
-- there is no linedef `n`, returns nil.
function Linedef:get_sidedef(map, n)
	return map.sidedefs[self.sidedefs[n]]
end

-- An interface for modifying sidedefs
Sidedef = Object:inherit()
Sidedef._lookup = {
	x_offset   = 1,
	y_offset   = 2,
	upper_pic  = 3,
	middle_pic = 4,
	lower_pic  = 5,
	sector     = 6
}

-- Construct a `Sidedef` object with default values. If `sector` is not provided, then it must
-- be set to a value at a later time before insertion into the map.
function Sidedef.new(sector)
	local self = Sidedef()

	self.x_offset   = 0
	self.y_offset   = 0
	self.upper_pic  = ""
	self.middle_pic = ""
	self.lower_pic  = ""
	self.sector     = sector or 0

	return self
end

-- Create a new `Sidedef` as a copy of another `Sidedef`. If `sector` is provided, this will be
-- the new sector number, otherwise the other's sector will be used.
function Sidedef.copy(other, sector)
	local self = Sidedef()

	self.x_offset   = other.x_offset
	self.y_offset   = other.y_offset
	self.upper_pic  = other.upper_pic
	self.middle_pic = other.middle_pic
	self.lower_pic  = other.lower_pic
	self.sector     = sector or other.sector

	return self
end

-- Construct a `Sidedef` object from a single binary sidedef. A table of sectors must have been
-- provided before calling this function so integer references can be turned into table references.
function Sidedef.from_string(content)
	local self = Sidedef()

	self.x_offset, self.y_offset, self.upper_pic, self.middle_pic, self.lower_pic,
			self.sector = string.unpack("< i2 i2 c8 c8 c8 i2", content)

	self.upper_pic  = auto._trim_c8(self.upper_pic )
	self.middle_pic = auto._trim_c8(self.middle_pic)
	self.lower_pic  = auto._trim_c8(self.lower_pic )

	self.sector = self.sector + 1

	return self
end

-- Return the binary representation of this sidedef as a string. A swap table of sectors must be
-- provided to convert table references into integer reference.
function Sidedef:to_string()
	return string.pack("< i2 i2 c8 c8 c8 i2", self.x_offset, self.y_offset,
			self.upper_pic, self.middle_pic, self.lower_pic, self.sector - 1)
end

-- Get the sector that this sidedef points to, assuming it is a part of map `map`
function Sidedef:get_sector(map)
	return map.sectors[self.sector]
end

-- An interface for modifying vertices
Vertex = Object:inherit()
Vertex._lookup = {
	x = 1,
	y = 2
}

-- Construct a `Vertex` object. If `x` and `y` are not provided, they will be set to zero.
function Vertex.new(x, y)
	local self = Vertex()

	self.x = x or 0
	self.y = y or 0

	return self
end

-- Create a new `Vertex` as a copy of another `Vertex`.
function Vertex.copy(other)
	local self = Vertex()

	self.x = other.x
	self.y = other.y

	return self
end

-- Construct a `Vertex` object from a single binary vertex.
function Vertex.from_string(content)
	local self = Vertex()

	self.x, self.y = string.unpack("< i2 i2", content)

	return self
end

-- Return the binary representation of this vertex as a string.
function Vertex:to_string()
	return string.pack("< i2 i2", self.x, self.y)
end

-- An interface for modifying sectors
Sector = Object:inherit()
Sector._lookup = {
	floor       = 1,
	ceiling     = 2,
	floor_pic   = 3,
	ceiling_pic = 4,
	brightness  = 5,
	special     = 6,
	tag         = 7
}

-- Construct a `Sector` object with default values.
function Sector.new()
	local self = Sector()

	self.floor       = 0
	self.ceiling     = 0
	self.floor_pic   = ""
	self.ceiling_pic = ""
	self.brightness  = 255
	self.special     = 0
	self.tag         = 0

	return self
end

-- Create a new `Sector` as a copy of another `Sector`.
function Sector.copy(other)
	local self = Sector()

	self.floor       = other.floor
	self.ceiling     = other.ceiling
	self.floor_pic   = other.floor_pic
	self.ceiling_pic = other.floor_pic
	self.brightness  = other.brightness
	self.special     = other.special
	self.tag         = other.tag

	return self
end

-- Construct a `Sector` object from a single binary sector.
function Sector.from_string(content)
	local self = Sector()

	self.floor, self.ceiling, self.floor_pic, self.ceiling_pic, self.brightness, self.special,
			self.tag = string.unpack("< i2 i2 c8 c8 i2 I2 I2", content)

	self.floor_pic   = auto._trim_c8(self.floor_pic)
	self.ceiling_pic = auto._trim_c8(self.ceiling_pic)

	return self
end

-- Return the binary representation of this sector as a string.
function Sector:to_string()
	return string.pack("< i2 i2 c8 c8 i2 I2 I2", self.floor, self.ceiling,
			self.floor_pic, self.ceiling_pic, self.brightness, self.special, self.tag)
end

-- Get/set each group of sector specials independently of the others. `group` must be between
-- one and four.
function Sector:get_special(group)
	local shift = (group - 1) * 4
	return (self.special & (0x000F << shift)) >> shift
end
function Sector:set_special(group, special)
	local shift = (group - 1) * 4
	local mask = 0x000F << shift
	self.special = (self.special & ~mask) | ((special << shift) & mask)
end
