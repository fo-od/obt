package config

import "core:strings"
import "core:os"
import "core:fmt"
import "core:encoding/json"

Collection :: struct {
	name: string `json:"name"`,
	path: string `json:"path"`,
}

Project :: struct {
	name: string `json:"name"`,
	version: string `json:"version"`,
	description: string `json:"description"`,
	author: string `json:"author"`,
	collections: []Collection `json:"collections"`,
}

Build_Config :: struct {
	src: string `json:"src"`,
	out: string `json:"out"`,
	flags: []string `json:"flags"`,
}

Config :: struct {
    schema: string `json:"$schema"`,
	project: Project `json:"project"`,
	actions: map[string]string `json:"actions"`,
	build: Build_Config `json:"build"`,
	use_ols_config: bool `json:"useOlsConfig"`,
}

default :: proc() -> (cfg: Config) {
	cfg = {
		schema = "https://raw.githubusercontent.com/fo-od/obt/refs/heads/main/schema/obt.schema.json",
		project = {
			name = "myproject",
			version = "0.1.0",
		},
		build = {
			src = "src",
			out = ".build",
			flags = {},
		},
		use_ols_config = false,
	}

	cfg.actions = make(map[string]string, 3, context.allocator)
	cfg.actions["build"] = "odin build ${src} -out:${out}/${name}"
	cfg.actions["run"]   = "odin run ${src}"
	cfg.actions["check"] = "odin check ${src}"

	return
}

load :: proc(path: string, verbose: bool) -> (cfg: Config) {
	cfg = default()

	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		if verbose do fmt.eprintln("Failed to read config file at", path, ":", read_err, "\nFalling back to default config.")
		return
	}

	unmarshal_err := json.unmarshal(data, &cfg)
	if unmarshal_err != nil {
		if verbose do fmt.eprintln("Failed to parse config json", path, ":", unmarshal_err, "\nFalling back to default config.")
		return
	}

	return
}


/* Placeholders:
    - ${name}: Project name
    - ${version}: Project version
    - ${src}: Source directory
    - ${out}: Output/build directory
*/
expand_placeholders :: proc(config: Config, i: string) -> (o: string) {
    o = i
    o, _ = strings.replace_all(o, "${name}", config.project.name)
    o, _ = strings.replace_all(o, "${version}", config.project.version)
    o, _ = strings.replace_all(o, "${src}", config.build.src)
    o, _ = strings.replace_all(o, "${out}", config.build.out)

    return
}
