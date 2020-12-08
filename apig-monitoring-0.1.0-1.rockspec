package = "apig-monitoring"  
version = "0.1.0-1"               

local pluginName = package:match("^(.+)$")  -- "apig-monitoring"

supported_platforms = {"linux", "macosx"}
source = {
  url = "http://github.com/Kong/kong-plugin.git",
  tag = "0.1.0"
}

description = {
  summary = "Kong is a scalable and customizable API Management Layer built on top of Nginx.",
  homepage = "http://getkong.org",
  license = "Apache 2.0"
}

dependencies = {
}

build = {
  type = "builtin",
  modules = {
    -- TODO: add any additional files that the plugin consists of
    ["kong.plugins."..pluginName..".handler"] = "kong/plugins/"..pluginName.."/handler.lua",
    ["kong.plugins."..pluginName..".schema"] = "kong/plugins/"..pluginName.."/schema.lua",
	["kong.plugins."..pluginName..".log"] = "kong/plugins/"..pluginName.."/log.lua",
	["kong.plugins."..pluginName..".counter"] = "kong/plugins/"..pluginName.."/counter.lua",
  }
}
