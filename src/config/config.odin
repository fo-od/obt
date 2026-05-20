package config

import "core:strconv"
import "core:strings"
import "core:os"
import "core:fmt"
import "core:encoding/json"
import "core:text/regex"

Collection :: struct {
	name: string `json:"name"`,
	path: string `json:"path"`,
}

Build_Config :: struct {
	src: string `json:"src"`,
	out: string `json:"out"`,
	flags: []string `json:"flags"`,
	collections: []Collection `json:"collections"`,
	use_ols_collections: bool `json:"useOlsCollections"`,
	treat_overflow_as_flags: bool `json:"treatOverflowAsFlags"`,
}

Config :: struct {
    schema: string `json:"$schema"`,
    name: string `json:"name"`,
	actions: map[string]string `json:"actions"`,
	build: Build_Config `json:"build"`,
}

default_config :: proc() -> (cfg: Config) {
	cfg = {
		schema = "https://raw.githubusercontent.com/fo-od/obt/refs/heads/main/schema/obt.schema.json",
		name = "myproject",
		build = {
			src = "src",
			out = ".build",
			flags = {},
			collections = {},
			use_ols_collections = false,
			treat_overflow_as_flags = false,
		},
	}

	cfg.actions = make(map[string]string, 3, context.allocator)
	cfg.actions["build"] = "odin build ${0}|${src} -out:${out}/${name} ${flags}"
	cfg.actions["run"]   = "odin run ${0}|${src} ${flags}"
	cfg.actions["check"] = "odin check ${0}|${src}"

	return
}

load :: proc(path: string, verbose: bool) -> (cfg: Config, default: bool) {
	cfg = default_config()

	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		if verbose do fmt.eprintln("Failed to read config file at", path, ":", read_err, "\nFalling back to default config.")
		default = true
		return
	}

	unmarshal_err := json.unmarshal(data, &cfg)
	if unmarshal_err != nil {
		if verbose do fmt.eprintln("Failed to parse config json", path, ":", unmarshal_err, "\nFalling back to default config.")
		default = true
		return
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
 - ${n}: Index n of overflow arguments

Doing '${n}|${variable}' will prioritize '${n}', and fall back to '${variable}'.
*/
expand_placeholders :: proc(config: Config, s: string, overflow: []string, treat_overflow_as_flags: bool, verbose: bool) -> string {
    cmd := placeholder_split(s)
    sb := strings.builder_make()

    flags: string
    flags_sb := strings.builder_make()

    strings.write_string(&flags_sb, strings.join(config.build.flags, " "))

    for collection in config.build.collections {
        strings.write_string(&flags_sb, fmt.tprintf("-collection:%s=%s", collection.name, collection.path))
    }

    if treat_overflow_as_flags {
        for flag in overflow {
            strings.write_string(&flags_sb, flag)
        }
    }

    flags = strings.to_string(flags_sb)

    skip: u8
    for tok, i in cmd {
        if skip > 0 {
            skip -= 1
            continue
        }

        prev := cmd[i-1] if i != 0 else ""
        next := cmd[i+1] if i != len(cmd)-1 else ""

        is_var := strings.starts_with(tok, "${") && strings.ends_with(tok, "}")

        if is_var {
            index_str := tok
            index_str = strings.trim_prefix(index_str, "${")
            index_str = strings.trim_suffix(index_str, "}")
            index, ok := strconv.parse_uint(index_str)

            ok = false if treat_overflow_as_flags else ok

            if ok {
                if len(overflow) != 0 && index <= len(overflow)-1 {
                    strings.write_string(&sb, overflow[index])
                    skip = 2
                }
                else if next == "|" {
                    next_var := cmd[i+2] if i != len(cmd)-2 else ""

                    if next_var != "" {
                        skip = 1
                        switch tok {
                        case "${name}": strings.write_string(&sb, config.name)
                        case "${src}": strings.write_string(&sb, config.build.src)
                        case "${out}": strings.write_string(&sb, config.build.out)
                        }
                    }
                }
                else {
                    if verbose do fmt.printfln("Couldn't find '%v', leaving empty.", tok)
                }
            }
            else {
                switch tok {
                case "${name}": strings.write_string(&sb, config.name)
                case "${src}": strings.write_string(&sb, config.build.src)
                case "${out}": strings.write_string(&sb, config.build.out)
                case "${flags}": strings.write_string(&sb, flags)
                }
            }
        }
        else {
            strings.write_string(&sb, tok)
        }
    }

    return strings.to_string(sb)
}
