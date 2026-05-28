package config

import "../util"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:text/regex"

Collection :: struct {
	name: string `json:"name"`,
	path: string `json:"path"`,
}

Build_Config :: struct {
	src:                 string `json:"src"`,
	out:                 string `json:"out"`,
	flags:               []string `json:"flags"`,
	collections:         [dynamic]Collection `json:"collections"`,
	use_ols_collections: bool `json:"useOlsCollections"`,
}

Action :: struct {
	command:     string `json:"command"`,
	description: string `json:"description"`,
}

Config :: struct {
	schema:  string `json:"$schema"`,
	name:    string `json:"name"`,
	actions: map[string]Action `json:"actions"`,
	build:   Build_Config `json:"build"`,
}

Ols_Config :: struct {
	collections: []Collection `json:"collections"`,
}

default_config :: proc() -> (cfg: Config) {
	cfg = {
		schema = "https://raw.githubusercontent.com/fo-od/obt/refs/heads/main/schema/obt.schema.json",
		name = "myproject",
		build = {
			src = "src",
			out = "build",
			flags = {},
			collections = {},
			use_ols_collections = false,
		},
	}

	// default actions (from obt.json)
	cfg.actions["build"] = Action {
		command     = "odin build ${src} -out:${out}/${name} ${flags}",
		description = "Build the project",
	}
	cfg.actions["run"] = Action {
		command     = "odin run ${src} ${flags}",
		description = "Run the project",
	}
	cfg.actions["check"] = Action {
		command     = "odin check ${src}",
		description = "Check the project",
	}

	return
}

load :: proc(path: string, verbose, use_ols: bool) -> (cfg: Config, default: bool) {
	cfg = default_config()

	if verbose do fmt.println("Reading config file at:", path)
	data, read_err := os.read_entire_file(util.concat(path, "/obt.json"), context.allocator)
	if read_err != nil {
		if verbose do fmt.eprintln("Failed to read config file at", path, ":", read_err, "\nFalling back to default config.")
		default = true
		return
	}

	if verbose do fmt.println("Parsing config...")
	unmarshal_err := json.unmarshal(data, &cfg)
	if unmarshal_err != nil {
		if verbose do fmt.eprintln("Failed to parse config json", path, ":", unmarshal_err, "\nFalling back to default config.")
		default = true
		return
	}

	if cfg.build.use_ols_collections || use_ols {
		if verbose do fmt.println("Reading ols config file at:", util.concat(path, "/ols.json"))
		ols_data, read_err := os.read_entire_file(
			util.concat(path, "/ols.json"),
			context.allocator,
		)
		if read_err != nil {
			fmt.eprintln("Failed to read ols.json at", util.concat(path, "/ols.json"))
			return
		}

		ols_cfg: Ols_Config
		if verbose do fmt.println("Parsing config...")
		unmarshal_err := json.unmarshal(ols_data, &ols_cfg)
		if unmarshal_err != nil {
			if verbose do fmt.eprintln("Failed to parse ols.json", path, ":", unmarshal_err)
			return
		}

		for collection in ols_cfg.collections {
			append(&cfg.build.collections, collection)
			if verbose do fmt.printfln("Adding %v to collections", collection)
		}
	}

	return
}

placeholder_split :: proc(s: string) -> (tokens: [dynamic]string) {
	itr, _ := regex.create_iterator(s, `\$\{[^}]+\}|\||\s+|[^\s$|{}]+`)
	defer regex.destroy(itr)

	match, i, ok := regex.match_iterator(&itr)
	defer regex.destroy(match)
	append(&tokens, match.groups[0])

	for ok {
		match, i, ok = regex.match_iterator(&itr)

		if !ok do break

		append(&tokens, match.groups[0])
	}

	return
}

/*
Expand all config placeholders in a string

Placeholders:
 - ${name}: Project name
 - ${src}: Source directory
 - ${out}: Output/build directory
 - ${flags}: Build flags (includes collections)
 - ${overflow}: Rest of overflow arguments, starting at the highest used ${n} + 1
 - ${n}: Index n of overflow arguments
*/
expand_placeholders :: proc(
	config: Config,
	s: string,
	overflow: []string,
	verbose: bool,
) -> string {
	cmd := placeholder_split(s)
	sb := strings.builder_make()

	flags: string
	flags_sb := strings.builder_make()

	strings.write_string(&flags_sb, strings.join(config.build.flags, " "))

	for collection in config.build.collections {
		strings.write_string(
			&flags_sb,
			fmt.tprintf("-collection:%s=%s", collection.name, collection.path),
		)
	}

	n: uint = 0

	for tok, i in cmd {
		if strings.starts_with(tok, "${") && strings.ends_with(tok, "}") {
			index_str := tok
			index_str = strings.trim_prefix(index_str, "${")
			index_str = strings.trim_suffix(index_str, "}")
			index, ok := strconv.parse_uint(index_str)

			if ok {
				if len(overflow) != 0 && index <= len(overflow) - 1 {
					strings.write_string(&sb, overflow[index])
					if index > n || n == 0 {
						n = index + 1
					}
				} else {
					if verbose do fmt.printfln("Couldn't find '%v', leaving empty.", tok)
				}
			} else {
				switch tok {
				case "${name}":
					strings.write_string(&sb, config.name)
				case "${src}":
					strings.write_string(&sb, config.build.src)
				case "${out}":
					strings.write_string(&sb, config.build.out)
				case "${flags}":
					strings.write_string(&sb, flags)
				case "${overflow}":
					strings.write_string(&sb, strings.join(overflow[n:], " "))
				}
			}
		} else {
			strings.write_string(&sb, tok)
		}
	}

	return strings.to_string(sb)
}

