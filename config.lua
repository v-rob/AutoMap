return {
	-- The format that the input WAD file name has to follow, where `%name%` can be any
	-- identifier. For instance, `raw_%name%` could match `raw_fun_level.wad`, but not
	-- `fun_level.wad` since that doesn't have the required `raw_` prefix.
	input_format = "raw_%name%",
	-- The format that the output WAD file will follow, where `%name%` will equal the same in
	-- `input_name`. For instance, `%name%` with an input of `raw_fun_level.wad` with the
	-- format `raw_%name%` would output a file named `fun_level.wad`.
	output_format = "%name%",

	-- The path to the nodebuilder executable.
	nodebuilder_path = "/Program Files (x86)/Zone Builder/Compilers/Nodebuilders/ZenNode.exe",
	-- Parameters to pass to the nodebuilder when running at normal optimization levels.
	-- `%input%` will be replaced with the input WAD file path, and `%output%` will be replaced
	-- with the output WAD file path.
	nodebuilder_params_normal = "%input% -o %output%",
	-- Parameters to pass to the nodebuilder when running at fast speeds at the cost of
	-- optimization. `%input%` and `%output%` have the same meaning as `nodebuilder_params_normal`.
	nodebuilder_params_fast = "-n3 -nq -rz %input% -o %output%",
}
