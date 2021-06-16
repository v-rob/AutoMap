-- AutoMap: Copyright 2021 Vincent Robinson under the MIT license. See `license.txt` for more info.

print("---> AutoMap Version 1.0.0 (c) 2021 Vincent Robinson\n")

-- The global namespace for all AutoMap functions.
auto = {}

dofile("src/helpers.lua")
dofile("src/wad.lua")
-- No need to include any other files for this control script.

-- Get the directory delimiter for the system. This is a standard way to do it, not a hack.
local DIR_DELIM = package.config:sub(1, 1)

-- Place a string in double quotes
local function quote(str)
	return "\"" .. str .. "\""
end

-- Replace an identifier in a string without formatting. The identifier must be present.
local function replace_ident(s, ident, repl)
	local first, last = s:find(ident, 1, true)
	return s:sub(1, first - 1) .. repl .. s:sub(last + 1)
end

--[[ Parse the input WAD path and return other necessary paths based on the configuration.
	Specifically, it returns a table with the following:
	* input_path: The path that was provided to this function
	* input_name: The name of the input file
	* output_path: The path that the output file should be at
	* output_name: The name that the output file should have
	* dir: The directory containing both the input and output files
]]
local function parse_input_path(config, input_path)
	local paths = {}
	paths.input_path = input_path

	-- Get the directory of the WAD file by finding the last slash (of either type since
	-- Windows can use `/` as well)
	paths.dir = ""
	paths.input_name = input_path
	for i = #input_path, 1, -1 do
		local c = input_path:sub(i, i)
		if c == "/" or c == "\\" then
			paths.dir = input_path:sub(1, i)
			paths.input_name = input_path:sub(i + 1)
			break
		end
	end

	-- Find the first and last character of the shared part of the input and output names
	local input_format = config.input_format
	local first, format_last = input_format:find("%name%", 1, true)
	local actual_last = format_last - #input_format + #paths.input_name

	-- Ensure that the input WAD follows the naming conventions, or else there may be problems
	assert(paths.input_name:sub(1, first - 1) == input_format:sub(1, first - 1) and
			paths.input_name:sub(actual_last + 1) == input_format:sub(format_last + 1),
			"Input WAD does not follow naming conventions")

	paths.output_name = replace_ident(config.output_format, "%name%",
			paths.input_name:sub(first, actual_last))
	paths.output_path = paths.dir .. paths.output_name

	return paths
end

-- Run the nodebuilder on the output file
local function run_nodebuilder(config, to_nodebuild, output_path)
	if to_nodebuild == "no_nodebuild" then
		return
	end

	local params
	if to_nodebuild == "normal" then
		params = config.nodebuilder_params_normal
	else
		params = config.nodebuilder_params_fast
	end

	local quoted_output = quote(output_path)
	params = replace_ident(params, "%input%",  quoted_output)
	params = replace_ident(params, "%output%", quoted_output)

	local command = quote(config.nodebuilder_path) .. " " .. params
	if DIR_DELIM == "\\" then
		-- This is to circumvent very stupid problems with `cmd /C`, which `os.execute` uses.
		-- See <https://stackoverflow.com/questions/9964865/c-system-not-working-when-there-
		-- are-spaces-in-two-different-parameters>
		command = quote(command)
	end

	io.write("\n---> ")
	local success, status, code = os.execute(command)
	assert(success, "Nodebuilding failed: " .. status .. " code " .. code)
end

-- Runs all AutoMap Lua lumps in the specified WAD. A separate instance of the Lua interpreter
-- is opened to more completely sandbox it and prevent vulnerabilities.
local function run_autolua_lumps(paths, wad)
	local lumps = wad:get_lumps_with_prefix("AML_")

	local args = {paths.input_path, paths.output_path}
	local to_remove = {}

	for _, lump in ipairs(lumps) do
		local name = os.tmpname()
		local file = assert(io.open(name, "w"))
		file:write(lump.content)

		args[#args + 1] = quote(name) .. " " .. quote(lump.name)
		to_remove[#to_remove + 1] = name

		file:close()
	end

	-- In this one case of running a command, Windows requires `\` instead of `/`
	local command = "lua" .. DIR_DELIM .. "lua54 -W src/run.lua " .. table.concat(args, " ")
	if DIR_DELIM == "\\" then
		command = quote(command)
	end
	local success, status, code = os.execute(command)

	for _, name in ipairs(to_remove) do
		os.remove(name)
	end

	assert(success, "Running AutoMap Lua lumps failed: " .. status .. " code " .. code)
end

local function read_wad(path)
	local file = io.open(path, "rb")
	assert(file, "Unable to open " .. path)

	local wad = Wad(file:read("a"))

	file:close()

	return wad
end

-- Parse command line arguments
assert(#arg == 2, "Incorrect number of command line arguments")

-- How the wad file should be built with a nodebuilder.
local to_nodebuild = arg[1]
-- Path to the WAD file being processed.
local wad_path = arg[2]
-- Configuration options from `config.lua`
local config = dofile("config.lua")

local paths = parse_input_path(config, wad_path)

print("Preprocessing: " .. paths.input_name .. "\n")

run_autolua_lumps(paths, read_wad(paths.input_path))

print("\nPreprocessing saved to " .. paths.output_path)

run_nodebuilder(config, to_nodebuild, paths.output_path)
