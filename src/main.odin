package main

import "core:flags"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:path/filepath"
import "core:encoding/json"
import "config"
import "util"

print_help :: proc() {
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

main :: proc() {
	Options :: struct {
		action: string,

		use_ols: bool,

		overflow_flags: bool,

		verbose: bool,

		overflow: [dynamic]string,
	}

	opt: Options

	parse_err: flags.Error

	for arg, i in os.args[1:] {
	    rest := os.args[i+2:]

	    if len(os.args) == 1 {
			parse_err = flags.Parse_Error{.Missing_Flag, "Missing action, look at 'obt -help' for more information."}
		}

		// put args after -- into overflow
		if arg == "--" {
		    append(&opt.overflow, ..rest)
			break
		}

		if i == 0 {
		    // print help message if requested
		    if arg == "-h" || arg == "-help" || arg == "--help" || arg == "help" {
				parse_err = true
			}
			else {
			    // set action
			    if strings.starts_with(arg, "-action:") {
					opt.action = arg[8:]
				} else if arg != "-use-ols" && arg != "-overflow-flags" && arg != "-verbose" {
				    opt.action = arg
				} else {
				    parse_err = flags.Parse_Error{.Missing_Flag, "Missing action, look at 'obt -help' for more information."}
				}
			}
		}
		else {
		    switch arg {
			case "-use-ols": opt.use_ols = true
			case "-overflow-flags": opt.overflow_flags = true
			case "-verbose": opt.verbose = true
			case:
			    append(&opt.overflow, arg)
			}
		}
	}

    if parse_err != nil {
        _, ok := parse_err.(flags.Help_Request);
        if ok {
            print_help()
        }

        util.print_errors(Options, parse_err, filepath.base(os.args[0]), show_help = false)
        os.exit(0 if ok else 1)
    }

    fmt.println(opt.overflow[:])

    /******************
     * Action parsing *
     ******************/

	cwd, _ := os.get_working_directory(context.allocator)
	ed, _ := os.get_executable_directory(context.allocator)

	if opt.action == "init" {
	    // initialize a project
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
	    // parse custom action
		config_path := util.concat(cwd, "/obt.json")
		cfg := config.load(config_path, opt.verbose)

		cmd := cfg.actions[opt.action]

		if cmd == "" {
		    fmt.eprintfln("Unknown action '%s'", opt.action)
		    os.exit(1)
		}

		if opt.use_ols {
		    // TODO: read ols collections and add to config
		}

		cmd_expanded := config.expand_placeholders(cfg, cmd, opt.overflow[:]) if opt.overflow_flags else config.expand_placeholders(cfg, cmd, {})
		if opt.verbose do fmt.printfln("Expanding '%s' to '%s'", cmd, cmd_expanded)

		if opt.verbose do fmt.printfln("Running '%s'", cmd_expanded)
		util.exec(cmd_expanded)
	}
}
