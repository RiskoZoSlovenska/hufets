package = "hufets"
version = "0.1.0-1"
source = {
   url = "git+https://github.com/RiskoZoSlovenska/hufets",
   tag = "0.1.0",
}
description = {
   summary = "Human-Friendly Expressions for Text Searching",
   detailed = "HUFETS is a minimalistic \"regex\" for searching within written text. It's meant to be forgiving to write and readable even by non-programmers.",
   homepage = "https://github.com/RiskoZoSlovenska/hufets",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
   "lpeg",
}
build = {
   type = "builtin",
   modules = {
      hufets = "hufets.lua",
   },
}
