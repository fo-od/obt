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
// TODO: put default config here
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
      "command": "echo ${myvar}", // command to run, look at variables section for defined variables
      "variables": { // define your own variables
        "myvar": { // name of custom variable
          "value": "${overflow}", // what the variable expands to
          "default": "Hellope!" // what the variable will fallback to, if there is an error parsing the primary value.
        }
      }
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
- overflow: Overflowed arguments.
- n where n is an integer >= 0: Expands to and consumes `overflow[n]`, or empty if `overflow[n]` doesn't exist.

### Custom Variables
As you have seen previously, you can define custom variables for your action.  
Usually the value will relate to `${n}` or `${overflow}`.

``` json
{
  ...
  "actions": {
    "say": {
      "command": "echo ${1} ${0} ${myvar}",
      "variables": {
        "myvar": {
          "value": "${overflow}",
          "default": "Hellope!"
        }
      }
    }
  }
  ...
}
```

### Conditionals
With variables, sometimes you want to do different things based on what the user inputs.  
You can check if a variable contains a string, and have two different outputs based on that.
Or, you can have a variable that is only used when a condition is true.

Here is an example action using conditionals.
``` json
{
  "build": {
    "command": "odin build ${dir}",
    "variables": {
      "dir": {
        "value": "${'/' in $0 ? $0 : $src}"
      }
    }
  }
}
```
> [!NOTE]
Whitespace is required when using conditionals.
Conditionals must also be wrapped in `${...}`

Here are the three different conditions you can use:
- `'str' in $var`
- `'str' prefixes $var` - checks if the `$var` starts with `str`
- `'str' suffixes $var`
