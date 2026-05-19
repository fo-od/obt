package config

Collection :: struct {
	name: string `json:"name"`,
	path: string `json:"path"`,
}

Project :: struct {
	name: string `json:"name"`,
	version: string `json:"version"`,
	description: string `json:"description"`,
	author: string `json:"author"`,
	collections: []Collection `json:"collections"`,
}

Build_Config :: struct {
	src: string `json:"src"`,
	out: string `json:"out"`,
	flags: []string `json:"flags"`,
}

Config :: struct {
    schema: string `json:"$schema"`,
	project: Project `json:"project"`,
	actions: map[string]string `json:"actions"`,
	build: Build_Config `json:"build"`,
	use_ols_config: bool `json:"useOlsConfig"`,
}

TEMPLATE :: Config{
    schema = "https://raw.githubusercontent.com/fo-od/obt/refs/heads/main/schema/obt.schema.json",
    project = {
        name="projectName",
        version="0.1.0"
    },
    build = {
        src="src",
        out=".build"
    }
}
