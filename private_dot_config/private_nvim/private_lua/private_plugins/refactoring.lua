-- ABOUTME: Adds the missing async.nvim dependency for refactoring.nvim.
-- ABOUTME: refactoring.nvim switched from plenary.async to lewis6991/async.nvim.
return {
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "lewis6991/async.nvim",
    },
  },
}
