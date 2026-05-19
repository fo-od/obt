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
