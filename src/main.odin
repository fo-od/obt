package main

import "core:strings"
import "core:flags"
import "core:os"
import "core:fmt"
import "core:encoding/json"
import "config"
import "util"

load_config :: proc(path: string) -> (cfg: config.Config, err: union{os.Error, json.Unmarshal_Error}) {
    data: []byte

	data, err = os.read_entire_file(path, context.allocator)
	if err != nil {
		fmt.eprintln("Failed to read config:", err)
		return
	}

	err = json.unmarshal(data, &cfg)
	if err != nil {
		fmt.eprintln("Failed to parse config:", err)
		return
	}

	return
}

main :: proc() {
	Options :: struct {
		action: string `args:"pos=0,required" usage:"What action to perform. (init, build, run, etc.)"`,

		use_ols: bool `usage:"Use the ols.json file for getting collections."`,

		verbose: bool `usage:"Show more logs."`,
	}

	opt: Options

	flags.parse_or_exit(&opt, os.args)

	cwd, _ := os.get_working_directory(context.allocator)
	ed, _ := os.get_executable_directory(context.allocator)

	switch opt.action {
	case "init":
		name := util.get_input("Name of project: ")
		author := util.get_input("Author of project: ")

		wd := util.concat(cwd, "/", name)

		os.mkdir_all(util.concat(wd, "/src"))
		main_file, _ := os.create(util.concat(wd, "/src/main.odin"))

		util.fprint(main_file, {
			"package main",
			"",
			"import \"core:fmt\"",
			"",
			"main :: proc() {",
			"	fmt.println(\"Hellope world!\")",
			"}"
		})

		fmt.println(util.concat(ed, "/src/resources/obt.json"))

		cfg := config.TEMPLATE
		cfg.project.name = name
		cfg.project.author = author

		config_text, _ := json.marshal(cfg, json.Marshal_Options{pretty = true})

		config_file, _ := os.create(util.concat(wd, "/obt.json"))

		defer os.close(config_file)
		os.write_string(config_file, strings.clone_from_bytes(config_text))

	case "build", "run":
		config_path := util.concat(cwd, "/obt.json")
		if !os.exists(config_path) {
			fmt.println("Couldn't open obt.json from cwd, using template.")
			config_path = util.concat(ed, "/src/resources/obt.json")
		}
	}
}
