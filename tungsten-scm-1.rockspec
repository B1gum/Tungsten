package = "tungsten"
version = "scm-1"

source = {
  url = "git+https://github.com/B1gum/Tungsten",
}

description = {
  summary = "Neovim plugin: LaTeX -> CAS integration",
  detailed = "Installs parser dependencies used by Tungsten.",
  homepage = "https://github.com/B1gum/Tungsten",
  license = "MIT",
}

dependencies = {
  "lua >= 5.1",
  "lpeg",
  "lpeglabel",
  "luafilesystem",
  "penlight",
}

build = {
  type = "builtin",
}
