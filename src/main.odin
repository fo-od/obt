package main

import "core:flags"
import "core:os"
import "core:fmt"
import "core:encoding/json"

main :: proc() {
	Options :: struct {
		use_ols: bool `usage:"Use the ols.json file for getting collections."`,
	}

	opt: Options

	flags.parse_or_exit(&opt, os.args)

	cwd, _ := os.get_working_directory(context.allocator)

	fmt.println(cwd)
}
