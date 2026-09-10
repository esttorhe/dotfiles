-- ABOUTME: obsidian.nvim for the second_brain vault, on the actively maintained
-- ABOUTME: obsidian-nvim fork using its current (3.x) option names.

return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- latest release rather than latest commit
  lazy = true,
  event = { "BufReadPre " .. vim.fn.expand("~") .. "/workspace/github.com/esttorhe/second_brain/**.md" },
  opts = {
    -- The `:Obsidian<Verb>` commands are dropped in 4.0; use `:Obsidian verb`.
    legacy_commands = false,

    workspaces = {
      {
        name = "second_brain",
        path = "~/workspace/github.com/esttorhe/second_brain",
      },
    },

    -- Dailies live at Journal/<year>/YYYY.MM.DD.md. `date_format` is allowed to
    -- carry path components; obsidian takes the stem of the result as the ID.
    daily_notes = {
      folder = "Journal",
      date_format = "%Y/%Y.%m.%d",
    },

    -- Zettelkasten IDs: a timestamp plus a slug of the title, so a note titled
    -- 'My new note' becomes '1657296016-my-new-note.md'.
    note_id_func = function(title)
      local suffix = ""
      if title ~= nil then
        -- If title is given, transform it into valid file name.
        suffix = title:gsub(" ", " "):gsub("[^A-Za-z0-9-]", ""):lower()
      else
        -- If title is nil, just add 4 random uppercase letters to the suffix.
        for _ = 1, 4 do
          suffix = suffix .. string.char(math.random(65, 90))
        end
      end
      return tostring(os.time()) .. "-" .. suffix
    end,

    templates = {
      folder = "templates",
      date_format = "%Y-%m-%d-%a",
      time_format = "%H:%M",
    },

    picker = {
      name = "snacks.picker",
    },

    -- Open notes in the Obsidian app at the current line.
    open = {
      use_advanced_uri = true,
    },

    -- render-markdown.nvim owns markdown rendering. Obsidian's own UI module
    -- draws a second set of overlays over the same buffer, which double-renders
    -- list markers and headings. Upstream also plans to remove it.
    ui = {
      enable = false,
    },
  },
}
