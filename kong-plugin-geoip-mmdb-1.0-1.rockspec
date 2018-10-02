package = "kong-plugin-geoip-mmdb"
version = "1.0-1"
source = {
  url = "TBD"
}
description = {
  summary = "A Kong plugin for geoip blocking using maxmind"
  license = "MIT"
}
dependencies = {
  "lua ~> 5.1",
  "mmdblua ~> 0.1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.geoip-mmdb.handler"] = "kong/plugins/geoip-mmdb/handler.lua",
    ["kong.plugins.geoip-mmdb.schema"]  = "kong/plugins/geoip-mmdb/schema.lua"
  }
}
