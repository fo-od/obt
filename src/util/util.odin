package util

import "core:strings"
import "core:fmt"
import "core:os"

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
	input = strings.clone(string(buf[:n-1]))
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
