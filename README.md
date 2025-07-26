# Agent Rules CodeCompanion Extension

Automatically add project rules to your [CodeCompanion](https://codecompanion.olimorris.dev) chat context

## 🚀 Overview

[@arnm](https://github.com/arnm) graciously [shared this extension with the community](https://github.com/olimorris/codecompanion.nvim/discussions/1718), so all credit goes to them. From the original discussion post:

> Every project has its own unique set of rules and guidelines—often scattered across different files. Remembering which files to include in your AI chat is a real cognitive burden. This extension solves that by automatically detecting and attaching all relevant rule files (like `.rules`, `AGENT.md`, and more) to your chat context. No more manual selection or forgetting important context!
>
> It works just like other agentic tools you know and love (Cursor, ClaudeCode, etc.):
>
> - Keeps your AI up-to-date with the latest project rules.
> - Removes the overhead of managing context files yourself.
> - Runs quietly in the background, always keeping your chat in sync.
>
> Add rules in two main ways. In both cases, the rules file for the paths extracted are found and added:
>
> - When you add a file/buffer reference
> - By default, when you do @files operations (edit, create, read). You can define you own extract from message function

I literally just copy-pasta'd 🍜 it and used it to learn how to wire-up [CodeCompanion Extensions](https://codecompanion.olimorris.dev/extending/extensions.html). And yes, this README was AI generated for the most part. I added this bit and tweaked some stuff.

## ✨ Features

- **Automatic Detection**: Finds rule files (like `.rules`, `AGENT.md`, `CLAUDE.md`, etc.) in your project
- **Path-Based Context**: When you reference a file, the extension finds all relevant rule files in that path's hierarchy
- **Command Integration**: Works automatically with `/buffer` and `/file` commands
- **Tool Integration**: Tracks references in AI tool outputs (for file reads, edits, and creation)
- **Configurable**: Customize which files are considered "rules"
- **Toggle Controls**: Enable/disable the extension as needed

## 📋 Supported Rule Files

By default, the extension recognizes these rule files:

- `.ai/rules.md`
- `.clinerules`
- `.codecompanionrules`
- `.cursorrules`
- `.github/copilot-instructions.md`
- `.goosehints`
- `.rules`
- `.windsurfrules`
- `AGENT.md`
- `AGENTS.md`
- `CLAUDE.md`

## 📦 Installation

### Using a plugin manager (recommended)

#### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "olimorris/codecompanion.nvim",
  dependencies = {
    -- other dependencies...
    "minusfive/codecompanion-agent-rules", -- replace with your actual repo
  },
  opts = {
    -- other codecompanion options...
    extensions = {
      agent_rules = {
        enabled = true,
        opts = {
          -- Optional: override defaults
          rules_filenames = {
            ".rules",
            "AGENT.md",
            -- Add your custom rule filenames here
          },
          debug = false,
        }
      }
    }
  }
}
```

### Manual Installation

1. Clone this repository to your Neovim plugins directory
2. Add the extension to your CodeCompanion config

```lua
require("codecompanion").setup({
  extensions = {
    agent_rules = {
      enabled = true,
      opts = {
        -- Optional: override defaults
        rules_filenames = {
          ".rules",
          "AGENT.md",
          -- Add your custom rule filenames here
        },
        debug = false,
      }
    }
  }
})
```

## ⚙️ Configuration

The extension provides these configuration options:

```lua
agent_rules = {
  opts = {
    -- List of filenames to look for as rule files
    rules_filenames = {
      ".ai/rules.md",
      ".clinerules",
      ".codecompanionrules",
      ".cursorrules",
      ".github/copilot-instructions.md",
      ".goosehints",
      ".rules",
      ".windsurfrules",
      "AGENT.md",
      "AGENTS.md",
      "CLAUDE.md",
    },

    -- Enable debug logging
    debug = false,

    -- Enable/disable the extension
    enabled = true,

    -- Optional: Custom function to extract file paths from messages
    -- If not provided, default patterns will be used
    extract_file_paths_from_chat_message = nil,
  }
}
```

## 🔧 Commands

The extension provides these commands:

- `:CodeCompanionRulesProcess` - Re-evaluate rule references now
- `:CodeCompanionRulesDebug` - Toggle debug logging
- `:CodeCompanionRulesEnable` - Enable the extension
- `:CodeCompanionRulesDisable` - Disable the extension

## 🤝 How It Works

1. When you reference a file in your chat (via paste, `/file`, `/buffer`, etc.), the extension:
   - Captures the file path
   - Searches for rule files in that file's directory and all parent directories up to your project root
   - Automatically adds relevant rule files to your chat context

2. When you use AI tools that read, modify, or create files, the extension automatically captures those paths and includes relevant rules.

3. Rules are added as "pinned" references, so they remain in context throughout your chat session.

## 🚫 Troubleshooting

If the extension isn't working as expected:

1. Enable debug mode with `:CodeCompanionRulesDebug`
2. Check the logs for insights into what's happening
3. Try manually triggering with `:CodeCompanionRulesProcess`
4. Make sure your rule files match the configured filenames

## 🙏 Credits

- [CodeCompanion](https://github.com/olimorris/codecompanion.nvim) - The main plugin this extends
- Original implementation by [arnm](https://github.com/arnm)
- Inspired by agentic code tools like [Cursor](https://docs.cursor.com/context/rules), [ClaudeCode](https://docs.anthropic.com/en/docs/claude-code/memory#how-claude-looks-up-memories), etc.
- [Discussion thread](https://github.com/olimorris/codecompanion.nvim/discussions/1718)
