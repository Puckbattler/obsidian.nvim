local api = require "obsidian.api"
local log = require "obsidian.log"
local PickerName = require("obsidian.config").Picker

---@class obsidian.Picker
---@field find_files fun(opts: obsidian.PickerFindOpts|?)
---@field grep fun(opts: obsidian.PickerGrepOpts|?)
---@field pick fun(values: obsidian.PickerEntry[]|string[], opts: obsidian.PickerPickOpts|?)
local M = {}

local state = {}
M.state = state

local picker_plugins = {
  [string.lower(PickerName.telescope)] = { "telescope.nvim" },
  [string.lower(PickerName.fzf_lua)] = { "fzf-lua" },
  [string.lower(PickerName.mini)] = { "mini.nvim", "mini.pick" },
  [string.lower(PickerName.snacks)] = { "snacks.nvim" },
  ["snacks.pick"] = { "snacks.nvim" },
}

---@param picker_name string
---@return boolean
local function picker_available(picker_name)
  local plugins = picker_plugins[string.lower(picker_name)]
  if plugins == nil then
    return false
  end

  for _, plugin in ipairs(plugins) do
    if api.get_plugin_info(plugin) ~= nil then
      return true
    end
  end

  return false
end

-------------------------------------------------------------------
--- Abstract methods that need to be implemented by subclasses. ---
-------------------------------------------------------------------

---@class obsidian.PickerMappingOpts
---
---@field desc string
---@field callback fun(...: obsidian.PickerEntry|string)
---@field fallback_to_query boolean|?
---@field keep_open boolean|?
---@field allow_multiple boolean|?

---@alias obsidian.PickerMappingTable table<string, obsidian.PickerMappingOpts>

---@class obsidian.PickerFindOpts
---
---@field prompt_title string|?
---@field dir string|obsidian.Path|?
---@field callback fun(path: string)|?
---@field query string|?
---@field include_non_markdown boolean|?

---@class obsidian.PickerGrepOpts
---
---@field prompt_title string|?
---@field dir string|obsidian.Path|?
---@field query string|?
---@field callback fun(entry: obsidian.PickerEntry)|?

---@class obsidian.PickerEntry: vim.quickfix.entry

---@class obsidian.PickerPickOpts
---
---@field prompt_title string|?
---@field callback fun(value: obsidian.PickerEntry, ...: obsidian.PickerEntry)|?
---@field allow_multiple boolean|?
---@field format_item (fun(value: obsidian.PickerEntry): string)|?

------------------------------------------------------------------
--- Concrete methods with a default implementation subclasses. ---
------------------------------------------------------------------

--- Find notes by filename.
---
---@param opts { prompt_title: string|?, query: string|?, callback: fun(path: string)|?, dir: obsidian.Path|? }|? Options.
---
--- Options:
---  `prompt_title`: Title for the prompt window.
---  `callback`: Callback to run with the selected note path.
---  `no_default_mappings`: Don't apply picker's default mappings.
M.find_notes = function(opts)
  state.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts or {}

  state.class = M.find_files {
    query = opts.query,
    prompt_title = opts.prompt_title or "Notes",
    dir = opts.dir or Obsidian.dir,
    callback = opts.callback,
  }
end

--- Grep search in notes.
---
---@param opts { prompt_title: string|?, query: string|?, callback: fun(entry: obsidian.PickerEntry)|?, no_default_mappings: boolean|?, dir: obsidian.Path|? }|? Options.
---
--- Options:
---  `prompt_title`: Title for the prompt window.
---  `query`: Initial query to grep for.
---  `callback`: Callback to run with the selected path.
---  `no_default_mappings`: Don't apply picker's default mappings.
M.grep_notes = function(opts)
  state.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts or {}

  M.grep {
    prompt_title = opts.prompt_title or "Grep notes",
    dir = opts.dir or Obsidian.dir,
    query = opts.query,
    callback = opts.callback or api.open_note,
  }
end

--- Open picker with a list of notes.
---
---@param notes obsidian.Note[]
---@param opts { prompt_title: string|?, callback: fun(note: obsidian.Note, ...: obsidian.Note), allow_multiple: boolean|?, no_default_mappings: boolean|? }|? Options.
---
--- Options:
---  `prompt_title`: Title for the prompt window.
---  `callback`: Callback to run with the selected note(s).
---  `allow_multiple`: Allow multiple selections to pass to the callback.
M.pick_note = function(notes, opts)
  state.calling_bufnr = vim.api.nvim_get_current_buf()

  opts = opts or {}

  -- Launch picker with results.
  ---@type obsidian.PickerEntry[]
  local entries = {}
  for _, note in ipairs(notes) do
    assert(note.path, "note has no path")
    local rel_path = assert(note.path:vault_relative_path { strict = true })
    local display_name = note:display_name()
    entries[#entries + 1] = {
      value = note,
      display = display_name,
      ordinal = rel_path .. " " .. display_name,
      filename = tostring(note.path),
    }
  end

  M.pick(entries, {
    prompt_title = opts.prompt_title or "Notes",
    callback = function(v)
      opts.callback(v.user_data)
    end,
    allow_multiple = opts.allow_multiple,
  })
end

-- ---@param key string|?
-- ---@return boolean
-- local function key_is_set(key)
--   if key ~= nil and string.len(key) > 0 then
--     return true
--   else
--     return false
--   end
-- end

-- --- Get selection mappings to use for `pick_tag()`.
-- ---@return obsidian.PickerMappingTable
-- M._tag_selection_mappings = function()
--   ---@type obsidian.PickerMappingTable
--   local mappings = {}
--
--   if key_is_set(Obsidian.opts.picker.tag_mappings.tag_note) then
--     mappings[Obsidian.opts.picker.tag_mappings.tag_note] = {
--       desc = "tag note",
--       callback = Mappings.tag_note,
--       fallback_to_query = true,
--       keep_open = true,
--       allow_multiple = true,
--     }
--   end
--
--   if key_is_set(Obsidian.opts.picker.tag_mappings.insert_tag) then
--     mappings[Obsidian.opts.picker.tag_mappings.insert_tag] = {
--       desc = "insert tag",
--       callback = Mappings.insert_tag,
--       fallback_to_query = true,
--     }
--   end
--
--   return mappings
-- end

--- Get the default Picker.
---
---@param picker_name obsidian.config.Picker
M.get = function(picker_name)
  local patch = function(modname)
    for name, f in pairs(require(modname)) do
      M[name] = f
    end
  end

  if picker_name == false then
    patch "obsidian.picker._default"
    return M
  end

  if picker_name then
    picker_name = string.lower(picker_name)
    if not picker_available(picker_name) then
      log.warn_once('Configured picker "%s" is not available; falling back to native picker', picker_name)
      patch "obsidian.picker._default"
      return M
    end
  else
    for _, name in ipairs { PickerName.telescope, PickerName.fzf_lua, PickerName.mini, PickerName.snacks } do
      if picker_available(name) then
        return M.get(name)
      end
    end
  end

  if picker_name == string.lower(PickerName.telescope) then
    patch "obsidian.picker._telescope"
  elseif picker_name == string.lower(PickerName.mini) then
    patch "obsidian.picker._mini"
  elseif picker_name == string.lower(PickerName.fzf_lua) then
    patch "obsidian.picker._fzf"
    -- or statement added for backwards compatibility
  elseif picker_name == string.lower(PickerName.snacks) or picker_name == "snacks.pick" then
    patch "obsidian.picker._snacks"
  else
    patch "obsidian.picker._default"
  end
  return M
end

return M
