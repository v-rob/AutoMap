-- AutoMap: Copyright 2021 Vincent Robinson under the MIT license. See `license.txt` for more info.

function deepcopy(t, seen)
	if type(t) ~= "table" then
		return t
	end

	if seen[t] then
		return seen[t]
	end

	local copy = {}
	seen[t] = copy

	for k, v in next, t, nil do
		copy[deepcopy(k, seen)] = deepcopy(v, seen)
	end

	setmetatable(copy, getmetatable(t))

	return copy
end

-- Returns a deep copy of table `t`. Properly handles reference loops. Metatables are preserved
-- and not copied. Can be used to copy classes with no explicit `copy` constructor, but if the
-- class does have such a constructor, use that instead of `table.copy`.
function table.copy(t)
	return deepcopy(t, {})
end

-- Trim zero bytes from the end of c8 strings
function auto._trim_c8(str)
	for i = 1, 8 do
		if str:sub(i, i) == "\0" then
			str = str:sub(1, i - 1)
			break
		end
	end
	return str
end

function auto.load_map(wad, name)
	local i = wad:get_lump_index(name)
	assert(i, "No map " .. name .. " found")
	return Map.from_lumps(wad:get_map_lumps(i))
end

function auto.save_map(wad, map)
	wad:set_map_lumps(map:to_lumps())
end

auto.maps = {}

setmetatable(auto.maps, {
	__index = function(t, k)
		local map = rawget(t, k)
		if not map then
			map = auto.load_map(auto.wad, k)
			rawset(t, k, map)
		end
		return map
	end,
	__newindex = function(t, k, v)
		error("Cannot write directly to auto.maps")
	end
})

--[[ `Object`: The object that all AutoMap classes are derived from.

A new class is created like:

	[local] MyClass = Object:inherit()

Methods and class variables can be added directly to `NewClass`, such as:

	function MyClass:my_function(param)
		self.member_variable = param
	end

	MyClass.class_var = {this = true, that = false}

Class variables are variables that will have the same value for all class instantiations.

Methods/class variables that should only be used internally should be prefixed with a
single underscore, like `MyClass:_private_function`.

To instantiate an object, just call it like a function: `MyClass([...])`. This calls the
member function `MyClass:_init` (if it exists) with the parameters provided.

	function MyClass:_init(var, other_var)
		self.var = var
		self.other_var = other_var
	end

	local my_object = MyClass(5, 7)

	assert(my_object.var == 5 and my_object.other_var == 7)

If a constructor can have multiple different parameter sets, instead of overloading the
constructor (which becomes messy quickly), add multiple constructors. Note how this must use
dot syntax, not colon, and that `self` must be explicitly made and returned:

	function MyClass:_init()
		print("MyClass constructor called")
	end

	function MyClass.new(name)
		local self = MyClass()
		self.name = name
		return self
	end

	function MyClass.copy(other)
		local self = MyClass()
		self.name = other.name
		return self
	end

	local new_object = MyClass.new("cheese")
	local copied_object = MyClass.copy(new_object)

	assert(new_object.name == copied_object.name)

To save memory, objects can map member variable names to integers internally, like so:

	MyClass._lookup = {
		var = 1,
		other_var = 2
	}

	local my_object = MyClass(5, 7)
	-- `my_object` is `{5, 7}` internally instead of the more memory-hungry `{var=5, other_var=7}`.

	assert(my_object.var == my_object[1] and my_object.other_var == my_object[2])

To get the type of an object, do `getmetatable(my_object)`, which returns the class that it was
instantiated from:

	local my_object = MyClass(5, 7)
	assert(getmetatable(my_object) == MyClass)

Finally, to inherit from another class, just call `Class:inherit()` on that class, just like
with `Object`:

	MyClass = Object:inherit()
	MyClass.class_var = 5

	SubClass = MyClass:inherit()
	assert(SubClass.class_var == 5)
]]
Object = {}

-- Call the class constructor on `__call` if it exists.
local function class_ctor(self, ...)
	local o = self:inherit()

	local init = o._init
	if init then
		init(o, ...)
	end

	return o
end

local function class_index(self, key)
	local mt = getmetatable(self)
	local lookup = mt.__loopup

	-- First look for a key that is mapped to an integer for memory reasons
	local lookup_key = lookup and lookup[key]
	if lookup_key then
		return rawget(self, lookup_key)
	end

	-- Then look for a key of the specified name
	local value = rawget(self, key)
	if value then
		return value
	end

	-- Otherwise, return the metatable value
	return mt[key]
end

local function class_newindex(self, key, value)
	local lookup = getmetatable(self)._lookup
	-- First look for a key mapped to an integer
	local lookup_key = lookup and lookup[key]
	if lookup_key then
		rawset(self, lookup_key, value)
	end

	-- Otherwise just set the value given
	rawset(self, key, value)
end

function Object:inherit()
	local o = setmetatable({}, self)
	self.__call = class_ctor
	self.__index = class_index
	self.__newindex = class_newindex
	return o
end
