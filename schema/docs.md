# obt configuration
---
## Overview
The configuration is stored in obt.json.  
It should be in the root directory of the project.

Example project tree:
```js
project
 ├─╴.build/
 ├─╴src/
 │  └─╴main.odin
 ├─╴.gitignore
 ├─╴obt.json
 └─╴README.md
```

## Default Configuration
This will be used when obt.json cannot be found.
```json
{
	"$schema": "https://raw.githubusercontent.com/fo-od/obt/refs/heads/main/schema/obt.schema.json",
	"name": "myproject",
	"actions": {
		"build": {
			"command": "odin build ${src} -out:${out}/${name} ${flags}",
			"description": "Build the project"
		},
		"run": {
			"command": "odin run ${src} ${flags}",
			"description": "Run the project"
		},
		"check": {
			"command": "odin check ${src}",
			"description": "Check the project"
		}
	},
	"build": {
		"src": "src",
		"out": "build",
		"flags": [],
		"collections": [],
		"useOlsCollections": true
	}
}
```

---

## Custom Actions
In the config, you can define custom actions.

The default actions are:
- init (hardcoded)
- build
- run
- check

### Defining an Action
The structure of an action looks like this:
``` json
{
  ...
  "actions": {
    "myaction": { // name of action
      "description": "Displays text", // description of the action (optional)
      "command": "echo ${0}", // command to run, look at variables section for defined variables
    }
  }
  ...
}
```

### Variables
Variables use this template: `${var_name}`

Available variables:
- name: Name of the project defined by the config.
- src: Source dircetory defined by the config.
- out: Output/build directory defined by the config.
- flags: Build flags defined in `obt.json`.
- overflow: Overflowed arguments, starts at the highest used `${n}`, exclusive.
- n where n is an integer >= 0: Expands to `overflow[n]`, or empty if `overflow[n]` doesn't exist.
