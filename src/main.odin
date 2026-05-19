package main

import "core:fmt"
import "core:strings"
import "core:flags"
import "core:os"
import "core:encoding/json"
import "config"
import "util"

main :: proc() {
	Options :: struct {
		action: string `args:"pos=0,required" usage:"What action to perform. (init, build, run, etc.)"`,

		use_ols: bool `usage:"Use ols.json for getting collections."`,

		verbose: bool `usage:"Show more logs."`,
	}

	opt: Options

	flags.parse_or_exit(&opt, os.args)

	cwd, _ := os.get_working_directory(context.allocator)
	ed, _ := os.get_executable_directory(context.allocator)

	if opt.action == "init" {
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

		gitignore, _ := os.create(util.concat(wd, "/.gitignore"))

		util.fprint(gitignore, {
		    "# Build output",
            ".build/",
            "",
            "# OS files",
            ".DS_Store",
            "Thumbs.db",
            ""
		})

		cfg := config.default()
		cfg.project.name = name
		cfg.project.author = author

		config_text, _ := json.marshal(cfg, json.Marshal_Options{pretty = true})

		config_file, _ := os.create(util.concat(wd, "/obt.json"))

		defer os.close(config_file)
		os.write_string(config_file, strings.clone_from_bytes(config_text))
		fmt.printfln("Initialized project '%s' at %s", name, wd)
	} else {
		config_path := util.concat(cwd, "/obt.json")
		cfg := config.load(config_path, opt.verbose)

		cmd := cfg.actions[opt.action]

		if cmd == "" {
		    fmt.eprintfln("Unknown action '%s'", opt.action)
		    os.exit(1)
		}

		cmd_expanded := config.expand_placeholders(cfg, cmd)
		if opt.verbose do fmt.printfln("Expanding '%s' to '%s'", cmd, cmd_expanded)

		fmt.println(cmd_expanded)
		util.exec(cmd_expanded)
	}
}
