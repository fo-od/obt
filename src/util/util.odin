package util

import "core:flags"
import "core:fmt"
import "core:os"
import "core:strings"

concat :: proc(args: ..string) -> string {
	return strings.concatenate(args[:])
}

get_input :: proc(prompt: string) -> (input: string) {
	buf: [256]byte
	fmt.print(prompt)
	n, err := os.read(os.stdin, buf[:])
	if err != nil {
		fmt.eprintln("Error reading:", err)
		return
	}
	// n-1 to remove newline
	input = strings.clone(string(buf[:n - 1]))
	return
}

fprint :: proc(f: ^os.File, args: []string, sep := "\n") {
	content := strings.join(args, sep)
	os.write_string(f, content)
}

exec :: proc {
	exec_args,
	exec_string,
}

exec_args :: proc(args: []string, stdout := true) -> (exit_code: int, out: Maybe(string)) {
	if stdout {
		process, _ := os.process_start(
			{command = args, stdin = os.stdin, stdout = os.stdout, stderr = os.stderr},
		)
		state, _ := os.process_wait(process)

		return state.exit_code, nil
	} else {
		out_r, out_w, _ := os.pipe()

		process, _ := os.process_start(
			{command = args, stdin = os.stdin, stdout = out_w, stderr = os.stderr},
		)
		state, _ := os.process_wait(process)
		os.close(out_w)

		out, _ := os.read_entire_file(out_r, context.allocator)
		os.close(out_r)

		return state.exit_code, strings.clone_from_bytes(out)
	}
}

exec_string :: proc(cmd: string, stdout := true) -> (exit_code: int, out: Maybe(string)) {
	return exec_args(strings.split(cmd, " "), stdout)
}

/*
Print out any errors that may have resulted from parsing.

All error messages print to STDERR, while usage goes to STDOUT, if requested.

Inputs:
- data_type: The typeid of the data structure to describe, if usage is requested.
- error: The error returned from `parse`.
- style: The argument parsing style, required to show flags in the proper style, when usage is shown.
- show_help: Show help message if requested.
*/
@(optimization_mode = "favor_size")
print_errors :: proc(
	data_type: typeid,
	error: flags.Error,
	program: string,
	style: flags.Parsing_Style = .Odin,
	show_help := true,
) {
	stderr := os.to_stream(os.stderr)
	stdout := os.to_stream(os.stdout)

	switch specific_error in error {
	case flags.Parse_Error:
		fmt.wprintfln(
			stderr,
			"[%T.%v] %s",
			specific_error,
			specific_error.reason,
			specific_error.message,
		)
	case flags.Open_File_Error:
		if os.exists(specific_error.filename) {
			flags: string
			if specific_error.flags == {.Read} {
				flags = "read-only"
			} else if specific_error.flags == {.Write} {
				flags = "write-only"
			} else if specific_error.flags == {.Read, .Write} {
				flags = "read/write"
			}

			if flags != "" {
				fmt.wprintfln(
					stderr,
					"[%T#%i] Unable to open %q with perms 0o%o as %s",
					specific_error,
					specific_error.errno,
					specific_error.filename,
					u16(transmute(u32)specific_error.perms),
					flags,
				)
			} else {
				fmt.wprintfln(
					stderr,
					"[%T#%i] Unable to open %q with perms 0o%o and flags %v",
					specific_error,
					specific_error.errno,
					specific_error.filename,
					u16(transmute(u32)specific_error.perms),
					specific_error.flags,
				)
			}
		} else {
			fmt.wprintfln(
				stderr,
				"[%T#%i] Unable to open %q. File not found",
				specific_error,
				specific_error.errno,
				specific_error.filename,
			)
		}
	case flags.Validation_Error:
		fmt.wprintfln(stderr, "[%T] %s", specific_error, specific_error.message)
	case flags.Help_Request:
		if show_help do flags.write_usage(stdout, data_type, program, style)
	}
}

