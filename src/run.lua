-- AutoMap: Copyright 2021 Vincent Robinson under the MIT license. See `license.txt` for more info.

-- These functions need to be used by this script even after sandboxing.
local _dofile = dofile
local _loadfile = loadfile
local _open = io.open
local _arg = arg

local function read_wad()
	local path = _arg[1]

	local file = _open(path, "rb")
	assert(file, "Unable to open " .. path)

	auto.wad = Wad(file:read("a"))

	file:close()
end

local function write_wad()
	local path = _arg[2]

	local file = _open(path, "wb")
	assert(file, "Unable to open " .. path)

	file:write(auto.wad:to_string())

	file:close()
end

-- Sandbox the global environment before running any script files. A virus in a map file would
-- be bad. Basically, the only things that need removing are things that load Lua code and
-- things that can modify or view the filesystem. Nothing else matters since this is run in
-- a separate process from `init.lua`.
arg = nil

collectgarbage = nil
dofile = nil
load = nil
loadfile = nil
require = nil

debug = nil
package = nil

io.close = nil
io.flush = nil
io.open = nil
io.popen = nil
io.tmpfile = nil

os.execute = nil
os.getenv = nil
os.remove = nil
os.rename = nil
os.setlocale = nil
os.tmpname = nil

-- Load all the library files. To ensure security, libraries do not have access to forbidden
-- functions directly, only the privileged scripts `init.lua` and `run.lua` which require them.
auto = {}

_dofile("src/helpers.lua")
_dofile("src/wad.lua")
_dofile("src/map.lua")

read_wad()

-- Now run each AutoMap Lua file.
for i = 3, #_arg, 2 do
	local err = "Error in lump " .. _arg[i + 1] .. ":\n"

	local func, message = _loadfile(_arg[i], "t")
	assert(func, err .. (message or ""))

	local success, message = pcall(func)
	assert(success, err .. (message or ""))
end

for _, map in pairs(auto.maps) do
	auto.save_map(auto.wad, map)
end

write_wad()
