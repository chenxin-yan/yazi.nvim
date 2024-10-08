---@module "plenary.path"

local assert = require("luassert")
local mock = require("luassert.mock")
local match = require("luassert.match")
local spy = require("luassert.spy")
package.loaded["yazi.process.yazi_process"] =
  require("spec.yazi.helpers.fake_yazi_process")
local fake_yazi_process = require("spec.yazi.helpers.fake_yazi_process")
local yazi_process = require("yazi.process.yazi_process")

local plugin = require("yazi")

describe("opening a file", function()
  after_each(function()
    package.loaded["yazi.process.yazi_process"] = yazi_process
  end)

  before_each(function()
    mock.revert(fake_yazi_process)
    package.loaded["yazi.process.yazi_process"] = mock(fake_yazi_process)
    plugin.setup({
      -- keymaps can only work with a real yazi process
      keymaps = false,
    })
  end)

  ---@param files string[]
  local function assert_opened_yazi_with_files(files)
    local call = mock(fake_yazi_process).start.calls[1]

    ---@type Path[]
    local actual_files = call.vals[3]
    assert.is_equal(type(actual_files), "table")

    local file_names = vim.tbl_map(function(file)
      return file.filename
    end, actual_files)

    for _, file in ipairs(files) do
      assert.is_true(type(file) == "string")
    end

    assert.is(files, file_names)
  end

  it("opens yazi with the current file selected", function()
    fake_yazi_process.setup_created_instances_to_instantly_exit({})

    -- the file name should have a space as well as special characters, in order to test that
    vim.api.nvim_command("edit " .. vim.fn.fnameescape("/abc/test file-$1.txt"))
    plugin.yazi({
      chosen_file_path = "/tmp/yazi_filechosen",
    })

    assert_opened_yazi_with_files({ "/abc/test file-$1.txt" })
  end)

  it("opens yazi with the current directory selected", function()
    fake_yazi_process.setup_created_instances_to_instantly_exit({})

    vim.api.nvim_command("edit /tmp/")

    plugin.yazi({
      chosen_file_path = "/tmp/yazi_filechosen",
    })

    assert_opened_yazi_with_files({ "/tmp/" })
  end)

  it(
    "calls the yazi_closed_successfully hook when a file is selected in yazi's chooser",
    function()
      local target_file = "/abc/test-file-potato.txt"

      fake_yazi_process.setup_created_instances_to_instantly_exit({
        selected_files = { target_file },
      })

      ---@param state YaziClosedState
      ---@diagnostic disable-next-line: unused-local
      local spy_hook = spy.new(function(chosen_file, _config, state)
        assert.equals(target_file, chosen_file)
        assert.equals("/abc", state.last_directory.filename)
      end)

      vim.api.nvim_command("edit /abc/test-file.txt")

      plugin.yazi({
        chosen_file_path = "/tmp/yazi_filechosen",
        ---@diagnostic disable-next-line: missing-fields
        hooks = {
          ---@diagnostic disable-next-line: assign-type-mismatch
          yazi_closed_successfully = spy_hook,
        },
      })

      assert
        .spy(spy_hook)
        .was_called_with(target_file, match.is_table(), match.is_table())
    end
  )

  it("calls the yazi_opened hook when yazi is opened", function()
    local spy_yazi_opened_hook = spy.new()

    vim.api.nvim_command("edit /abc/yazi_opened_hook_file.txt")

    plugin.yazi({
      ---@diagnostic disable-next-line: missing-fields
      hooks = {
        ---@diagnostic disable-next-line: assign-type-mismatch
        yazi_opened = spy_yazi_opened_hook,
      },
    })

    assert
      .spy(spy_yazi_opened_hook)
      .was_called_with("/abc/yazi_opened_hook_file.txt", match.is_number(), match.is_table())
  end)

  it("calls the open_file_function to open the selected file", function()
    local target_file = "/abc/test-file-lnotial.txt"
    fake_yazi_process.setup_created_instances_to_instantly_exit({
      selected_files = { target_file },
    })
    local spy_open_file_function = spy.new()

    vim.api.nvim_command("edit " .. target_file)

    plugin.yazi({
      chosen_file_path = "/tmp/yazi_filechosen",
      ---@diagnostic disable-next-line: assign-type-mismatch
      open_file_function = spy_open_file_function,
    })

    assert
      .spy(spy_open_file_function)
      .was_called_with(target_file, match.is_table(), match.is_table())
  end)
end)

describe("opening multiple files", function()
  local target_file_1 = "/abc/test-file-multiple-1.txt"
  local target_file_2 = "/abc/test-file-multiple-2.txt"

  it("can open multiple files", function()
    fake_yazi_process.setup_created_instances_to_instantly_exit({
      selected_files = { target_file_1, target_file_2 },
    })

    local spy_open_multiple_files = spy.new()
    plugin.yazi({
      ---@diagnostic disable-next-line: missing-fields
      hooks = {
        ---@diagnostic disable-next-line: assign-type-mismatch
        yazi_opened_multiple_files = spy_open_multiple_files,
      },
      chosen_file_path = "/tmp/yazi_filechosen-123",
    })

    assert.spy(spy_open_multiple_files).was_called_with({
      target_file_1,
      target_file_2,
    }, match.is_table(), match.is_table())
  end)
end)
