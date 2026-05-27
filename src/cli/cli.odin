package cli

import "../util"
import "core:flags"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

Options :: struct {
	action:      string,
	use_ols:     bool,
	verbose:     bool,
	default_cfg: bool,
	overflow:    [dynamic]string,
}

opt: Options

print_help :: proc() {
	fmt.println("obt - Odin build tool")
	fmt.println("")
	fmt.println("Usage:")
	fmt.println("\tobt action [-overflow-flags] [-use-ols] [-verbose] ...")
	fmt.println("Flags:")
	fmt.println("\t-action:<string>, required  | What action to perform. (init, build, run, etc.)")
	fmt.println("\tActions:                    |")
	fmt.println("\t    - init name (builtin)   | Initializes an Odin project with name.")
	fmt.println("\t    - info (builtin)        | Displays the project's info.")
	fmt.println("\t    - ...                   | You can also run custom actions defined in obt.json!")
	fmt.println("\t                            |")
	fmt.println("\t-use-ols                    | Get collections from the odin language server config (ols.json).")
	fmt.println("\t-verbose                    | Show more logs.")
	fmt.println("\t--                          | Puts the following arguments into overflow.")
}

parse :: proc() {
	parse_err: flags.Error

	for arg, i in os.args[1:] {
		// dont continue parsing if theres been an error
		if parse_err != nil do break

		rest := os.args[i + 2:]

		// show help message if no args given
		if len(os.args) == 1 {
			parse_err = flags.Parse_Error {
				.Missing_Flag,
				"Missing action, look at 'obt -help' for more information.",
			}
			continue
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
			} else {
				// set action
				if strings.starts_with(arg, "-action:") {
					opt.action = arg[8:]
				} else if arg != "-use-ols" && arg != "-overflow-flags" && arg != "-verbose" {
					opt.action = arg
				} else {
					parse_err = flags.Parse_Error {
						.Missing_Flag,
						"Missing action, look at 'obt -help' for more information.",
					}
					continue
				}
			}
		} else {
			switch arg {
			case "-use-ols":
				opt.use_ols = true
			case "-verbose":
				opt.verbose = true
			case:
				append(&opt.overflow, arg)
			}
		}
	}

	if parse_err != nil {
		_, ok := parse_err.(flags.Help_Request)
		if ok {
			print_help()
		}

		util.print_errors(Options, parse_err, filepath.base(os.args[0]), show_help = false)
		os.exit(0 if ok else 1)
	}
}

