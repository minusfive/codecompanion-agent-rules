--=============================================================================
-- agent_rules – CodeCompanion extension to detect and load rules into context
-- author: https://github.com/arnm
-- source: https://gist.github.com/arnm/514bfa053abbf6adc18c47ed206429e0
-- discussion: https://github.com/olimorris/codecompanion.nvim/discussions/1718
--=============================================================================

---@class CodeCompanionChatMessage
---@field content? string
---@field opts? table
---@field opts.context_id? string
---@field role? string
---@field id? any
---@field cycle? any

---@class CodeCompanionRulesConfig
---@field rules_filenames string[]
---@field debug boolean
---@field enabled boolean
---@field extract_file_paths_from_chat_message? fun(message:CodeCompanionChatMessage):string[]|nil

local M = {} -- public module table

--──────────────────────────────────────────────────────────────────────────────
--  Configuration
--──────────────────────────────────────────────────────────────────────────────
---@type CodeCompanionRulesConfig
M.config = {
  rules_filenames = {
    ".ai/rules.md",
    ".rules",
    ".goosehints",
    ".cursorrules",
    ".windsurfrules",
    ".clinerules",
    ".github/copilot-instructions.md",
    "AGENT.md",
    "AGENTS.md",
    "CLAUDE.md",
    ".codecompanionrules",
  },
  debug = false,
  enabled = true,
  extract_file_paths_from_chat_message = nil,
}

--──────────────────────────────────────────────────────────────────────────────
--  Per-buffer caches
--──────────────────────────────────────────────────────────────────────────────
local enabled = {} ---@type table<number,boolean>
local fingerprint = {} ---@type table<number,string>

--──────────────────────────────────────────────────────────────────────────────
--  Small helpers
--──────────────────────────────────────────────────────────────────────────────
local function log(msg)
  if M.config.debug then print("[Rules] " .. msg) end
end

local function notify(msg, level)
  vim.schedule(
    function()
      vim.notify("[CodeCompanionRules] " .. msg, level or vim.log.levels.INFO, { title = "CodeCompanionRules" })
    end
  )
end

local function normalize(p) return vim.fn.fnamemodify(p, ":p"):gsub("/$", "") end
local function clean(p) return p:gsub("^[`\"'%s]+", ""):gsub("[`\"'%s]+$", "") end

local function hash(list)
  if #list == 0 then return "" end
  table.sort(list)
  return table.concat(list, "|")
end

local function is_file_context_item(ctx)
  return (type(ctx.id) == "string" and (ctx.id:match("^<file>") or ctx.id:match("^<buf>")))
    or (type(ctx.source) == "string" and (ctx.source:match("%.file$") or ctx.source:match("%.buffer$")))
end

local function id_to_path(id) return id:match("^<file>(.*)</file>$") or id:match("^<buf>(.*)</buf>$") or id end

------------------------------------------------------------------------
-- Find the *first* existing file from a list of names in a directory
------------------------------------------------------------------------
local function find_first_file(dir, names)
  for _, name in ipairs(names) do
    local path = dir .. "/" .. name
    if vim.fn.filereadable(path) == 1 then return path end
  end
end

--──────────────────────────────────────────────────────────────────────────────
--  Extract paths mentioned in chat
--──────────────────────────────────────────────────────────────────────────────
local function collect_paths(bufnr)
  if not M.config.enabled then return {} end
  local chat = require("codecompanion.strategies.chat").buf_get_chat(bufnr)
  if not chat then return {} end

  local proj = normalize(vim.fn.getcwd())
  local out, seen = {}, {}

  local function is_rule_file(p)
    local name = vim.fn.fnamemodify(p, ":t")
    return vim.tbl_contains(M.config.rules_filenames, name)
  end

  local function add(p)
    p = normalize(clean(p))
    if is_rule_file(p) then return end
    if p ~= "" and not seen[p] and p:match("^" .. vim.pesc(proj)) then
      table.insert(out, p)
      seen[p] = true
    end
  end

  -- context_items
  for _, r in ipairs(chat.context_items or {}) do
    if is_file_context_item(r) then add(r.path ~= "" and r.path or id_to_path(r.id)) end
  end

  -- messages
  for _, msg in ipairs(chat.messages) do
    if msg.opts and msg.opts.context_id then
      local p = msg.opts.context_id:match("^<file>([^<]+)</file>$") or msg.opts.context_id:match("^<buf>([^<]+)</buf>$")
      if p then add(p) end
    end

    if msg.content then
      -- Check if custom extraction function is provided
      local cb = M.config.extract_file_paths_from_chat_message
      if type(cb) == "function" then
        local ok, extra = pcall(cb, msg)
        if ok and type(extra) == "table" then
          for _, p in ipairs(extra) do
            add(p)
          end
        end
      else
        -- Only use default patterns if no custom function is provided
        for p in msg.content:gmatch("%*%*Insert Edit Into File Tool%*%*: `([^`]+)`") do
          add(p)
        end
        for p in msg.content:gmatch("%*%*Create File Tool%*%*: `([^`]+)`") do
          add(p)
        end
        for p in msg.content:gmatch("%*%*Read File Tool%*%*: Lines %d+ to %-?%d+ of ([^:]+):") do
          add(p)
        end
      end
    end
  end

  log(("collect_paths -> %d path(s)"):format(#out))
  return out
end

--──────────────────────────────────────────────────────────────────────────────
--  Ascend directories to find rule files
--──────────────────────────────────────────────────────────────────────────────
local function collect_rules(paths)
  if not M.config.enabled then return {} end
  local proj = normalize(vim.fn.getcwd())
  local out, seen = {}, {}

  local function ascend(dir)
    dir = normalize(dir)
    while dir ~= "/" and dir:match("^" .. vim.pesc(proj)) do
      local f = find_first_file(dir, M.config.rules_filenames)
      if f and not seen[f] then
        out[#out + 1] = f
        seen[f] = true
      end
      local parent = vim.fn.fnamemodify(dir, ":h")
      if parent == dir then break end
      dir = parent
    end
  end

  for _, p in ipairs(paths) do
    ascend(vim.fn.fnamemodify(p, ":h"))
  end

  table.sort(out, function(a, b) return select(2, a:gsub("/", "")) > select(2, b:gsub("/", "")) end)
  log(("collect_rules -> %d rule file(s)"):format(#out))
  return out
end

--──────────────────────────────────────────────────────────────────────────────
--  Keep chat.context_items in sync with rule files
--──────────────────────────────────────────────────────────────────────────────
local function sync_context(bufnr, rule_files)
  if not M.config.enabled then return end

  ---------------------------------------------------------------------------
  -- helpers
  ---------------------------------------------------------------------------
  local function context_opts(opts)
    -- enforce exactly the flags we want on every rule–managed context_item
    return vim.tbl_extend("force", opts or {}, {
      rules_managed = true,
      pinned = true,
      watched = false,
    })
  end

  local function rerender_context(chat)
    -- wipe the old “> Context:” block and ask CodeCompanion to draw it again
    vim.schedule(function()
      local start = chat.header_line + 1
      local i, last = start, vim.api.nvim_buf_line_count(chat.bufnr)
      while i < last do
        local l = vim.api.nvim_buf_get_lines(chat.bufnr, i, i + 1, false)[1] or ""
        if l == "" or l:match("^> ") then
          i = i + 1
        else
          break
        end
      end
      if i > start then
        chat.ui:unlock_buf()
        vim.api.nvim_buf_set_lines(chat.bufnr, start, i, false, {})
        -- chat.ui:lock_buf()
      end
      if chat.context and chat.context.render then
        chat.ui:unlock_buf()
        chat.context:render()
        -- chat.ui:lock_buf()
      end
      chat.ui:unlock_buf()
    end)
  end

  ---------------------------------------------------------------------------
  -- 0. fetch chat object
  ---------------------------------------------------------------------------
  local chat = require("codecompanion.strategies.chat").buf_get_chat(bufnr)
  if not chat then return end

  ---------------------------------------------------------------------------
  -- 1. desired context_items  ▸  keyed by project-relative path
  ---------------------------------------------------------------------------
  ---@type table<string,{id:string,bufnr?:integer}>
  local desired = {}
  for _, abs in ipairs(rule_files) do
    local rel = vim.fn.fnamemodify(abs, ":.")
    local bn = vim.fn.bufnr(rel)
    local id = (bn ~= -1 and vim.api.nvim_buf_is_loaded(bn)) and ("<buf>" .. rel .. "</buf>")
      or ("<file>" .. rel .. "</file>")
    desired[rel] = { id = id, bufnr = (id:match("^<buf>") and bn or nil) }
  end

  ---------------------------------------------------------------------------
  -- 2. existing context_items  ▸  de-duplicate & index by path
  ---------------------------------------------------------------------------
  ---@type table<string, CodeCompanion.Chat.Context>
  local existing = {}
  for i = #chat.context_items, 1, -1 do
    local r = chat.context_items[i]
    if is_file_context_item(r) then
      local path = id_to_path(r.id)
      if existing[path] then -- duplicate → remove
        table.remove(chat.context_items, i)
      else
        existing[path] = r -- first occurrence wins
      end
    end
  end

  ---------------------------------------------------------------------------
  -- 3. ensure every desired context_item exists & is normalised
  ---------------------------------------------------------------------------
  local added_cnt = 0
  for path, want in pairs(desired) do
    local r = existing[path]
    if not r then
      local opts = context_opts({})
      if want.bufnr then
        require("codecompanion.strategies.chat.slash_commands.buffer")
          .new({ Chat = chat })
          :output({ bufnr = want.bufnr, path = path }, opts)
      else
        require("codecompanion.strategies.chat.slash_commands.file").new({ Chat = chat }):output({ path = path }, opts)
      end
      r = chat.context_items[#chat.context_items] -- last one is the context_item we just added
      added_cnt = added_cnt + 1
    end
    r.opts = context_opts(r.opts) -- normalise flags
  end

  ---------------------------------------------------------------------------
  -- 4. drop obsolete rule-managed context_items
  ---------------------------------------------------------------------------
  local removed_cnt = 0
  for i = #chat.context_items, 1, -1 do
    local r = chat.context_items[i]
    if r.opts and r.opts.rules_managed then
      local p = id_to_path(r.id)
      if not desired[p] then
        local context_id = r.id
        table.remove(chat.context_items, i)
        -- also purge any messages that still reference it
        for j = #chat.messages, 1, -1 do
          local m = chat.messages[j]
          if m.opts and m.opts.context_id == context_id then table.remove(chat.messages, j) end
        end
        removed_cnt = removed_cnt + 1
      end
    end
  end

  ---------------------------------------------------------------------------
  -- 5. feedback + context re-render
  ---------------------------------------------------------------------------
  if added_cnt + removed_cnt > 0 then
    log(string.format("sync_context → +%d -%d", added_cnt, removed_cnt))
    notify(
      (added_cnt > 0 and ("Added %d rule context_item(s)"):format(added_cnt) or nil),
      (removed_cnt > 0 and ("Removed %d obsolete context_item(s)"):format(removed_cnt) or nil)
    )
    rerender_context(chat)
  else
    log("sync_context → no change")
  end
end

--──────────────────────────────────────────────────────────────────────────────
--  Main worker
--──────────────────────────────────────────────────────────────────────────────
local function process(bufnr)
  if not M.config.enabled then return end
  log("process -> begin")
  local paths = collect_paths(bufnr)
  local fp = hash(paths)

  if fingerprint[bufnr] == fp then
    log("process -> fingerprint unchanged, skipping")
    return
  end
  fingerprint[bufnr] = fp

  sync_context(bufnr, collect_rules(paths))
  log("process -> done")
end

--──────────────────────────────────────────────────────────────────────────────
--  Event handlers
--──────────────────────────────────────────────────────────────────────────────
local function on_mode(bufnr)
  if not M.config.enabled then return end
  enabled[bufnr] = true
  process(bufnr)
end
local function on_submit(bufnr)
  if not M.config.enabled then return end
  process(bufnr)
end
local function on_tool(bufnr)
  if not M.config.enabled then return end
  process(bufnr)
end
local function on_clear(bufnr)
  enabled[bufnr], fingerprint[bufnr] = nil, nil
end

--──────────────────────────────────────────────────────────────────────────────
--  Setup
--──────────────────────────────────────────────────────────────────────────────

-- HACK: /file triggers process immediately but /buffer does not for some reason
local function patch_buffer_slash_command()
  if _G.__codecompanion_rules_buffer_patch then return end
  _G.__codecompanion_rules_buffer_patch = true

  local ok, BufferCmd = pcall(require, "codecompanion.strategies.chat.slash_commands.buffer")
  if not ok then
    vim.schedule(
      function() vim.notify("[CodeCompanionRules] Could not patch /buffer slash-command", vim.log.levels.WARN) end
    )
    return
  end

  local util = require("codecompanion.utils")
  local old_output = BufferCmd.output

  function BufferCmd:output(...)
    old_output(self, ...)
    vim.schedule(function() util.fire("ToolFinished", { bufnr = self.Chat.bufnr }) end)
  end

  vim.notify(
    "[CodeCompanionRules] Patched /buffer slash-command",
    vim.log.levels.INFO,
    { title = "CodeCompanionRules" }
  )
end

function M.setup(opts)
  if opts then M.config = vim.tbl_deep_extend("force", M.config, opts) end
  patch_buffer_slash_command()

  log(vim.inspect(M.config))

  local grp = vim.api.nvim_create_augroup("CodeCompanionRules", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = grp,
    pattern = "CodeCompanionChatCreated",
    callback = function() on_mode(vim.api.nvim_get_current_buf()) end,
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    group = grp,
    pattern = "i:n",
    callback = function()
      if vim.bo.filetype == "codecompanion" then on_mode(vim.api.nvim_get_current_buf()) end
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = grp,
    pattern = "CodeCompanionChatSubmitted",
    callback = function() on_submit(vim.api.nvim_get_current_buf()) end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = grp,
    pattern = { "CodeCompanionToolFinished", "CodeCompanionChatStopped" },
    callback = function() on_tool(vim.api.nvim_get_current_buf()) end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = grp,
    pattern = { "CodeCompanionChatCleared", "CodeCompanionChatClosed" },
    callback = function() on_clear(vim.api.nvim_get_current_buf()) end,
  })

  vim.api.nvim_create_user_command(
    "CodeCompanionRulesProcess",
    function() on_mode(vim.api.nvim_get_current_buf()) end,
    { desc = "Re-evaluate rule context_items now" }
  )

  vim.api.nvim_create_user_command("CodeCompanionRulesDebug", function()
    M.config.debug = not M.config.debug
    log("CodeCompanion-Rules debug = " .. tostring(M.config.debug))
  end, { desc = "Toggle rules debug" })

  -- enable/disable commands
  vim.api.nvim_create_user_command("CodeCompanionRulesEnable", function()
    M.config.enabled = true
    notify("Extension enabled")
    on_mode(vim.api.nvim_get_current_buf())
  end, { desc = "Enable CodeCompanion-Rules extension" })

  vim.api.nvim_create_user_command("CodeCompanionRulesDisable", function()
    M.config.enabled = false
    -- clear all per-buffer caches
    for bufnr in pairs(enabled) do
      enabled[bufnr] = nil
    end
    for bufnr in pairs(fingerprint) do
      fingerprint[bufnr] = nil
    end
    notify("Extension disabled")
  end, { desc = "Disable CodeCompanionRules extension" })
end

return M
