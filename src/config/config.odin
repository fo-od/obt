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
	use_ols_collections: bool `json:"useOlsCollections"`,
}

default :: proc() -> (cfg: Config) {
	cfg = {
		schema = "https://raw.githubusercontent.com/fo-od/obt/refs/heads/main/schema/obt.schema.json",
		project = {
			name = "myproject",
			collections = {},
		},
		build = {
			src = "src",
			out = ".build",
			flags = {},
		},
		use_ols_collections = false,
	}

	cfg.actions = make(map[string]string, 3, context.allocator)
	cfg.actions["build"] = "odin build ${src} -out:${out}/${name} ${flags}"
	cfg.actions["run"]   = "odin run ${src} ${flags}"
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


/*
 Expand all config placeholders in a string

 Placeholders:
  - ${name}: Project name
  - ${src}: Source directory
  - ${out}: Output/build directory
  - ${flags}: Build flags (includes collections)
*/
expand_placeholders :: proc(config: Config, i: string, overflow: []string) -> (o: string) {
    o = i
    o, _ = strings.replace_all(o, "${name}", config.project.name)
    o, _ = strings.replace_all(o, "${src}", config.build.src)
    o, _ = strings.replace_all(o, "${out}", config.build.out)

    if strings.contains(o, "${flags}") {
        flags := strings.builder_make()

        strings.write_string(&flags, strings.join(config.build.flags, " "))

        for collection in config.project.collections {
            strings.write_string(&flags, fmt.tprintf("-collection:%s=%s", collection.name, collection.path))
        }

        for flag in overflow {
            strings.write_string(&flags, flag)
        }

        o, _ = strings.replace_all(o, "${flags}", strings.to_string(flags))
    }

    return
}
