local plugin = require("kong.plugins.base_plugin"):extend()
local responses = require "kong.tools.responses"
local iputils = require "resty.iputils"
local mmdb = require "mmdb"

local new_tab
do
  local ok
  ok, new_tab = pcall(require, "table.new")
  if not ok then
    new_tab = function() return {} end
  end
end


local cache = {}


plugin.PRIORITY = 991
plugin.VERSION = "0.1.0"

local function cidr_cache(cidr_tab)
  local cidr_tab_len = #cidr_tab

  local parsed_cidrs = new_tab(cidr_tab_len, 0) -- table of parsed cidrs to return

  -- build a table of parsed cidr blocks based on configured
  -- cidrs, either from cache or via iputils parse
  -- TODO dont build a new table every time, just cache the final result
  for i = 1, cidr_tab_len do
    local cidr        = cidr_tab[i]
    local parsed_cidr = cache[cidr]

    if parsed_cidr then
      parsed_cidrs[i] = parsed_cidr

    else
      -- if we dont have this cidr block cached,
      -- parse it and cache the results
      local lower, upper = iputils.parse_cidr(cidr)

      cache[cidr] = { lower, upper }
      parsed_cidrs[i] = cache[cidr]
    end
  end

  return parsed_cidrs
end

function plugin:new()
  plugin.super.new(self, "geoip-mmdb")
end

function plugin:init_worker()
  plugin.super.init_worker(self)
  local ok, err = iputils.enable_lrucache()
  if not ok then
    ngx.log(ngx.ERR, "[geoip-mmdb] Could not enable lrucache: ", err)
  end
end

function plugin:access(conf)
  plugin.super.access(self)

  local remote_addr
  local forwarded_for = ngx.req.get_headers()["x-forwarded-for"]
  if fowarded_for then
    remote_addr = forwarded_for[1]
  else
    remote_addr = ngx.var.remote_addr
  end

  local geodb = assert(mmdb.read("/app/GeoLite2-City_20180925/GeoLite2-City.mmdb"))
  local geo_data = geodb:search_ipv4(remote_addr)

  ngx.req.set_header("X-ISO-COUNTRY", geo_data.country.iso_code)
  ngx.req.set_header("X-SOURCE", remote_addr)

  if conf.whitelist_ips and #conf.whitelist_ips > 0 then
    if iputils.ip_in_cidrs(remote_addr, cidr_cache(conf.whitelist_ips)) then
      return
    end
  end

  for i,line in ipairs(conf.blacklist_iso) do
    if line == geo_data.country.iso_code then
      return responses.send_HTTP_FORBIDDEN()
    end
  end
end

return plugin
