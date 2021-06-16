-- AutoMap: Copyright 2021 Vincent Robinson under the MIT license. See `license.txt` for more info.

-- An interface for modifying a lump
Lump = Object:inherit()
Lump._lookup = {
	name = 1,
	content = 2
}

-- Create a new lump with the specified name and binary string content
function Lump.new(name, content)
	local self = Lump()

	self.name = name
	self.content = content

	return self
end

-- Copy an existing lump
function Lump.copy(other)
	local self = Lump()

	self.name = other.name
	self.content = other.content

	return self
end

-- An interface for modifying WAD files. All functions, unless otherwise specified, get the last
-- lump in the file of the specified name if there are duplicates since that is the one that
-- will override the rest. Also, all functions return copies of the lumps, not references.
Wad = Object:inherit()

-- Construct a `Wad` object from a binary WAD string, usually read from a file.
function Wad:_init(contents)
	local wad_type, num_lumps, dir_idx, lumps_idx = string.unpack("< c4 I4 I4", contents)
	-- Lua indexes by one, not zero like C, so any offset values read from the file must be
	-- increased by one to index into the Lua string correctly.
	dir_idx = dir_idx + 1

	assert(wad_type == "IWAD" or wad_type == "PWAD", "WAD is not an IWAD or PWAD")
	self.wad_type = wad_type

	self.lumps = {}

	for i = 1, num_lumps do
		local lump_offset, lump_size, lump_name
		lump_offset, lump_size, lump_name, dir_idx = string.unpack("< I4 I4 c8", contents, dir_idx)
		lump_offset = lump_offset + 1

		local lump_content = contents:sub(lump_offset, lump_offset + lump_size - 1)

		self.lumps[i] = Lump.new(auto._trim_c8(lump_name), lump_content)
	end
end

-- Converts this `Wad` object to the actual binary WAD format for writing to a file.
function Wad:to_string()
	local lumps = {}
	for _, lump in ipairs(self.lumps) do
		lumps[#lumps + 1] = lump.content
	end
	local lump_data = table.concat(lumps)

	local header = string.pack("< c4 I4 I4", self.wad_type, #self.lumps, #lump_data + 12)

	local dir = {}
	local lump_offset = 12
	for _, lump in ipairs(self.lumps) do
		local lump_size = #lump.content
		dir[#dir + 1] = string.pack("< I4 I4 c8", lump_offset, lump_size, lump.name)
		lump_offset = lump_offset + lump_size
	end
	local dir_data = table.concat(dir)

	return header .. lump_data .. dir_data
end

-- Returns the last lump with the specified name or nil if there is no such lump.
function Wad:get_lump(name)
	local index = self:get_lump_index(name)
	if not index then
		return nil
	end
	return self.lumps[i]
end

-- Returns the index of the last lump with the specified name or nil if there is no such lump.
function Wad:get_lump_index(name)
	for i = #self.lumps, 1, -1 do
		local lump = self.lumps[i]
		if lump.name == name then
			return i
		end
	end
	return nil
end

-- Returns the index of the last lump with the specified name before the lump at the specified
-- index or nil if there is no such lump.
function Wad:get_before_index(name, index)
	for i = index - 1, 1 do
		local lump = self.lumps[i]
		if lump.name == name then
			return i
		end
	end
	return nil
end

-- Iterator that iterates over the lumps in this WAD from first to last. If there are any
-- duplicates, only the last one will be included, unless it is in the optional table
-- `allow_dups`. Returns the index and the lump.
-- Usage example: `for i, lump in wad:iter() do print(i, lump.name) end`
function Wad:iter(allow_dups)
	local seen = {}
	local indices = {}
	allow_dups = allow_dups or {}

	for i = #self.lumps, 1, -1 do
		local lump_name = self.lumps[i].name
		if allow_dups[lump_name] or not seen[lump_name] then
			seen[lump_name] = true
			indices[#indices + 1] = i
		end
	end

	local i = #indices + 1
	return function()
			i = i - 1
			if i == 0 then
				return nil
			end
			local index = indices[i]
			return index, self.lumps[index]
		end
end

-- Get a list of all lumps with the specified prefix.
function Wad:get_lumps_with_prefix(prefix)
	local indices = self:get_lump_indices_with_prefix(prefix)
	local ret = {}

	for i, index in ipairs(indices) do
		ret[i] = Lump.copy(self.lumps[index])
	end

	return ret
end

-- Get a list of the indices of all lumps with the specified prefix.
function Wad:get_lump_indices_with_prefix(prefix)
	local ret = {}

	for i, lump in self:iter() do
		local lump_name = lump.name
		if lump_name:sub(1, #prefix) == prefix then
			ret[#ret + 1] = i
		end
	end

	return ret
end

-- Get a list of all lumps inside the markers `<(alt_)name>_START` to `<(alt_)name>_END`.
-- `alt_name` is optional if both are the same.
function Wad:get_lumps_in_markers(name, alt_name)
	local indices = self:get_lump_indices_in_markers(name, alt_name)
	local ret = {}

	for i, index in ipairs(indices) do
		ret[i] = Lump.copy(self.lumps[index])
	end

	return ret
end

-- Get a list of the indices of all lumps inside the markers `<(alt_)name>_START` to
-- `<(alt_)name>_END`. `alt_name` is optional if both are the same.
function Wad:get_lump_indices_in_markers(name, alt_name)
	alt_name = alt_name or name

	local ret = {}
	local in_image = false

	local start_1 = name .. "_START"
	local start_2 = alt_name .. "_START"
	local end_1   = name .. "_END"
	local end_2   = alt_name .. "_END"

	for i, lump in self:iter{[start_1] = true, [start_2] = true, [end_1] = true, [end_2] = true} do
		local lump_name = lump.name

		if lump.content == "" then
			if lump_name == start_1 or lump_name == start_2 then
				in_image = true
			elseif lump_name == end_1 or lump_name == end_1 then
				in_image = false
			end
		end

		if in_image then
			ret[#ret + 1] = i
		end
	end

	return ret
end

-- Set of actions for finding and replacing map lumps. The true/false specifies whether that
-- lump will be included/replaced.
Wad._map_lump_actions = {
	{"THINGS",   true},
	{"LINEDEFS", true},
	{"SIDEDEFS", true},
	{"VERTEXES", true}, -- Apparently, id Software doesn't know how to spell "vertices"...
	{"SEGS",     false},
	{"SSECTORS", false},
	{"NODES",    false},
	{"SECTORS",  true},
	{"REJECT",   false}, -- REJECT and BLOCKMAP are necessary for removal
	{"BLOCKMAP", false}
}

-- Returns all the map lumps under and including the map marker at `index` in the WAD or nil if
-- there is no such map or some lumps are missing or in incorrect order. Lumps created by a
-- nodebuilder are not included if present. PWADs with only some of the lumps are not supported
-- and will return nil.
function Wad:get_map_lumps(index)
	local ret = {}

	local lump = self.lumps[index]
	if lump.content ~= "" then
		return nil
	end
	ret[1] = Lump.copy(lump)
	index = index + 1

	for _, action in ipairs(self._map_lump_actions) do
		if action[1] == "REJECT" then
			-- We don't need REJECT or BLOCKMAP, so return right now. Also, if we don't, the
			-- function will fail if there are no more lumps, due to the next if statement.
			return ret
		end

		if index > #self.lumps then
			return nil
		end

		local lump = self.lumps[index]
		if lump.name == action[1] then
			if action[2] == true then
				ret[#ret + 1] = Lump.copy(lump)
			end
			index = index + 1
		else
			if action[2] == true then
				return nil
			end -- Else continue on without doing anything
		end
	end

	return ret
end

-- Insert a lump into the WAD before the index provided. If no position is provided, the lump
-- is inserted at the end.
function Wad:insert_lump(lump, index)
	table.insert(self.lumps, index, Lump.copy(lump))
end

-- Insert a set of lumps into the WAD, such as a set of map lumps (in which case the map
-- marker must be included), before the index provided. If no position is provided, the lumps
-- are inserted at the end.
function Wad:insert_lumps(lumps, index)
	for _, lump in ipairs(lumps) do
		table.insert(self.lumps, index, Lump.copy(lump))
		if index then
			index = index + 1
		end
	end
end

-- Replace the last lump with the same name as `lump` with `lump`. Returns true if the lump
-- was found and replaced.
function Wad:replace_lump(lump)
	local index = self:get_lump_index(lump.name)
	if not index then
		return false
	end

	self.lumps[index] = Lump.copy(lump)
	return true
end

-- Attempts to find and replace a set of map lumps with the new lumps under `lumps` (the map
-- marker must be included). If any nodebuilder-built lumps are present in the WAD, they will
-- be deleted. Returns true if a set of lumps was found and replaced.
function Wad:replace_map_lumps(lumps)
	local index = self:get_lump_index(lumps[1].name)
	if not index then
		return false
	end

	-- Only start replacing if all the right lumps have been found at this position.
	if not self:get_map_lumps(index) then
		return false
	end

	if self.lumps[index].content ~= "" then
		return false
	end
	self.lumps[index] = Lump.copy(lumps[1])
	index = index + 1

	local replace_index = 2
	for _, action in ipairs(self._map_lump_actions) do
		if index > #self.lumps then
			if action[1] == "REJECT" or action[1] == "BLOCKMAP" then
				-- If they weren't there, we don't have to remove them
				return true
			end
			return false
		end

		if action[2] == true then
			local replace_lump = lumps[replace_index]

			assert(replace_lump.name == action[1], "Invalid lumps passed to Wad:replace_map_lumps")
			if self.lumps[index].name ~= action[1] then
				return false
			end

			self.lumps[index] = Lump.copy(replace_lump)

			index = index + 1
			replace_index = replace_index + 1
		else
			if self.lumps[index].name == action[1] then
				table.remove(self.lumps, index)
			end
		end
	end

	return true
end

-- Attempts to replace a lump of the same name with this one if found, otherwise simply
-- inserting the lump.
function Wad:set_lump(lump)
	if not self:replace_lump(lump) then
		self:insert_lump(lump)
	end
end

-- Attempts to replace a list of map lumps like `Wad:replace_map_lumps` if found, otherwise
-- simply inserting the map lumps.
function Wad:set_map_lumps(lumps)
	if not self:replace_map_lumps(lumps) then
		self:insert_lumps(lumps)
	end
end
