-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

-- vim config
vim.opt.relativenumber = true

-- for Github copilot
vim.g.copilot_assume_mapped = true

-- general
lvim.format_on_save.enabled = false
lvim.transparent_window = true

-- keybindings
lvim.keys.normal_mode["<C-s>"] = ":w<cr>"
lvim.keys.normal_mode["<S-l>"] = ":BufferLineCycleNext<CR>"
lvim.keys.normal_mode["<S-h>"] = ":BufferLineCyclePrev<CR>"
lvim.keys.normal_mode["<C-i>"] = "<C-o>"
lvim.keys.normal_mode["<C-o>"] = "<C-i>"
lvim.keys.normal_mode["<Tab>"] = false


lvim.builtin.which_key.mappings["-"] = { "<cmd>sp<cr>", "Split Panel" }
lvim.builtin.which_key.mappings["_"] = { "<cmd>vsp<cr>", "Split Panel Vertically" }

-- lsp keybindings
lvim.lsp.buffer_mappings.normal_mode['gr'] = { "<cmd>Telescope lsp_references<cr>", "Goto reference" }
lvim.lsp.buffer_mappings.normal_mode['gd'] = { "<cmd>Telescope lsp_definitions<cr>", "Goto definition" }

-- treesitter
lvim.builtin.treesitter.highlight.enable = true
lvim.builtin.treesitter.autotag.enable = true

-- neovim plugins
lvim.plugins = {
  -- { "abzcoding/zephyr-nvim" },  -- not working
  -- colorschemes
  { "catppuccin/nvim" },
  { "joshdick/onedark.vim" },
  -- extentions
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && yarn install",
    init = function() vim.g.mkdp_filetypes = { "markdown" } end,
    ft = { "markdown" }
  },
  { "Iron-E/nvim-libmodal" },
  { "Iron-E/nvim-typora" },
  { "plasticboy/vim-markdown" },
  { "wakatime/vim-wakatime" },
  { "norcalli/nvim-colorizer.lua" },
  { "ybian/smartim" },
  {
    "github/copilot.vim",
    build = ":Copilot setup"
  },
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
  },
  -- auto tag closing for tsx
  {
    "windwp/nvim-ts-autotag",
  }
}
