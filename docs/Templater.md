- [Usage](#usage)
- [Detection rules](#detection-rules)
- [Context](#context)
- [Options](#options)

When `templater.enabled = true`, obsidian.nvim will automatically detect templates that contain JavaScript (Templater) syntax and execute them via an external templater command instead of the built-in `{{var}}` substitution.

This is useful if you already use the [Templater](https://github.com/nicepkg/templater) CLI or a compatible tool and want to keep using its JavaScript template syntax inside obsidian.nvim.

## Usage

```lua
require("obsidian").setup {
  -- other fields ...

  templater = {
    enabled = true,
    cmd = "templater",
    args = { "--stdin" },
    env = {},
    pipe_stdin = true,
  },
}
```

With the above configuration, any template file that contains Templater-style JavaScript will be run through `templater --stdin` instead of the built-in substitution engine. The template content is piped to the command's stdin, and the stdout replaces the template body.

If the templater command fails (non-zero exit or missing binary), obsidian.nvim logs a warning and falls back to the built-in `{{var}}` substitution so note creation is not interrupted.

## Detection rules

A template is treated as a Templater template when its content matches **any** of the following:

- A literal `<%` marker (covers `<%`, `<%=`, `<%#`, `<%*`, `<%-`, etc.), or
- A fenced code block starting with `` ```js `` within the first 10 lines of the file.

Plain markdown and standard `{{var}}` placeholders do not trigger detection.

## Context

When the templater command runs, obsidian.nvim passes a JSON context object via the `TEMPLATER_CONTEXT` environment variable (and also through stdin depending on the tool). The context contains:

```json
{
  "type": "clone_template",
  "template_name": "my-template.md",
  "partial_note": { "id": "...", "title": "...", "aliases": [...], "tags": [...], "path": "..." },
  "destination_path": "path/to/new note.md",
  "templates_dir": "path/to/templates",
  "date": "2026-06-24",
  "time": "18:00"
}
```

`partial_note` is only present for `clone_template` (when creating a new note from a template), not for `insert_template`.

## Options

```lua
---@class obsidian.config.TemplaterOpts
---
--- When enabled, obsidian.nvim will automatically detect templates containing JavaScript
--- (Templater syntax) and execute them via the templater integration instead of using
--- the built-in {{{ variable substitution.
---
---@field enabled boolean|?
--- The command to use to execute templater.
---@field cmd string
--- Additional command-line arguments to pass when invoking templater.
---@field args? string[]
--- Environment variables to set when running templater.
---@field env? table<string, string>
--- When `true`, the template content is piped to `cmd` via stdin (default).
--- When `false`, the template file path is appended as the last argument.
---@field pipe_stdin? boolean
templater = {
  enabled = false,
  cmd = "templater",
  args = { "--stdin" },
  env = {},
  pipe_stdin = true,
}
```
