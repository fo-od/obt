package main

import "cli"
import "config"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "util"

main :: proc() {
	cli.parse()

	if cli.opt.verbose do fmt.printfln("Overflow: %v", cli.opt.overflow)

	/******************
     * Action parsing *
     ******************/

	cwd, _ := os.get_working_directory(context.allocator)

	if cli.opt.action == "init" {
		// initialize a project
		name := os.args[2]

		wd: string
		// handle target directory
		if strings.starts_with(name, "/") {
			wd = name
		} else if strings.starts_with(name, "./") {
			wd = util.concat(cwd, "/", name[2:])
		} else {
			wd = util.concat(cwd, "/", name)
		}

		os.mkdir_all(util.concat(wd, "/src"))
		main_file, _ := os.create(util.concat(wd, "/src/main.odin"))

		util.fprint(
			main_file,
			{
				"package main",
				"",
				"import \"core:fmt\"",
				"",
				"main :: proc() {",
				"	fmt.println(\"Hellope world!\")",
				"}",
			},
		)

		gitignore, _ := os.create(util.concat(wd, "/.gitignore"))

		util.fprint(
			gitignore,
			{"# Build output", ".build/", "", "# OS files", ".DS_Store", "Thumbs.db", ""},
		)

		cfg := config.default_config()
		cfg.name = name

		config_text, _ := json.marshal(cfg, json.Marshal_Options{pretty = true})

		config_file, _ := os.create(util.concat(wd, "/obt.json"))

		defer os.close(config_file)
		os.write_string(config_file, strings.clone_from_bytes(config_text))

		fmt.printfln("Initialized project '%s' at %s", name, wd)
		fmt.println("Next steps:")
		fmt.println("\tobt build  - Build the project")
		fmt.println("\tobt run    - Runs the project")
	} else if cli.opt.action == "info" {
		config_path := util.concat(cwd, "/obt.json")
		cfg, default := config.load(config_path, cli.opt.verbose)

		if default {
			fmt.println("Couldn't find obt.json! Are you sure you're in a project?")
			os.exit(1)
		}
		// TODO: show project info (name, actions, build flags...)
		fmt.println("Project Information:")
		fmt.printfln("Name: %v", cfg.name)
		fmt.printfln("Source directory: %v", cfg.build.src)
		fmt.printfln("Build directory: %v", cfg.build.out)
	} else {
		// parse custom action
		config_path := util.concat(cwd, "/obt.json")
		cfg, default := config.load(config_path, cli.opt.verbose)

		cli.opt.default_cfg = default

		action := cfg.actions[cli.opt.action]

		if action.command == "" {
			fmt.eprintfln("Unknown action '%s'", cli.opt.action)
			os.exit(1)
		}

		if cli.opt.use_ols {
			// TODO: read ols collections and add to config
		}

		cmd_expanded := config.expand_placeholders(
			cfg,
			action.command,
			cli.opt.overflow[:],
			cli.opt.verbose,
		)
		if cli.opt.verbose do fmt.printfln("Expanding '%s' to '%s'", action.command, cmd_expanded)

		if cli.opt.verbose do fmt.printfln("Running '%s'", cmd_expanded)
		util.exec(cmd_expanded)
	}
}

