package main

import "core:fmt"
import "core:strings"
import "core:flags"
import "core:os"
import "core:path/filepath"
import "core:encoding/json"
import "config"
import "util"

main :: proc() {
	Options :: struct {
		action: string `args:"pos=0,required" usage:"What action to perform. (init, build, run, etc.)"`,

		use_ols: bool `usage:"Get collections from the odin language server config (ols.json)."`,

		overflow_flags: bool `usage:"Treat extra arguments as build flags."`,

		verbose: bool `usage:"Show more logs."`,

		overflow: [dynamic]string `usage:"Extra arguments go here."`,
	}

	opt: Options

	parse_err := flags.parse(&opt, os.args[1:])

    if parse_err != nil {
        _, ok := parse_err.(flags.Help_Request);
        if ok || len(os.args) == 1 {
            fmt.println("obt - Odin build tool")
            fmt.println("")
            fmt.println("Usage:")
            fmt.println("\tobt action [-overflow-flags] [-use-ols] [-verbose] ...")
            fmt.println("Flags:")
            fmt.println("\t-action:<string>, required  | What action to perform. (init, build, run, etc.)")
            fmt.println("\tActions:                    |")
            fmt.println("\t\tinit name (builtin) | Initializes an Odin project with name")
            fmt.println("\t\t...                 | You can also run custom actions defined in obt.json!")
            fmt.println("\t                            |")
            fmt.println("\t-overflow-flags             | Treat extra arguments as build flags.")
            fmt.println("\t-use-ols                    | Get collections from the odin language server config (ols.json).")
            fmt.println("\t-verbose                    | Show more logs.")
        }

        util.print_errors(Options, parse_err, filepath.base(os.args[0]), show_help = false)
        os.exit(0 if ok else 1)
    }

	cwd, _ := os.get_working_directory(context.allocator)
	ed, _ := os.get_executable_directory(context.allocator)

	if opt.action == "init" {
		name := os.args[2]

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
		cfg.name = name

		config_text, _ := json.marshal(cfg, json.Marshal_Options{pretty = true})

		config_file, _ := os.create(util.concat(wd, "/obt.json"))

		defer os.close(config_file)
		os.write_string(config_file, strings.clone_from_bytes(config_text))

		fmt.printfln("Initialized project '%s' at %s", name, wd)
		os.chdir(wd)
		fmt.println("\nNext steps:")
		fmt.println("\tobt build\t- Build the project")
		fmt.println("\tobt run\t  - Runs the project")
	}
	else {
		config_path := util.concat(cwd, "/obt.json")
		cfg := config.load(config_path, opt.verbose)

		cmd := cfg.actions[opt.action]

		if cmd == "" {
		    fmt.eprintfln("Unknown action '%s'", opt.action)
		    os.exit(1)
		}

		cmd_expanded := config.expand_placeholders(cfg, cmd, {})
		if opt.verbose do fmt.printfln("Expanding '%s' to '%s'", cmd, cmd_expanded)

		if opt.verbose do fmt.println(cmd_expanded)
		util.exec(cmd_expanded)
	}
}
