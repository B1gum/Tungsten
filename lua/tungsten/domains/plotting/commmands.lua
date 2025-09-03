local health = require("tungsten.domains.plotting.health")

local M = {}

function M.check_dependencies_command()
  local report = health.check_dependencies()
  local lines = {
    string.format("wolframscript: %s", report.wolframscript and "OK" or "missing"),
    string.format("python: %s", report.python and "OK" or "missing"),
    string.format("matplotlib: %s", report.matplotlib and "OK" or "missing"),
    string.format("sympy: %s", report.sympy and "OK" or "missing"),
  }
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Tungsten PlotCheck" })
end

M.commands = {
  {
    name = "TungstenPlotCheck",
    func = M.check_dependencies_command,
    opts = { desc = "Check plotting dependencies" },
  },
}

return M
