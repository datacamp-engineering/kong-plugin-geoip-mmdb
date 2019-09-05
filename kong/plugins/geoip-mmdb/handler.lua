local plugin = require("kong.plugins.base_plugin"):extend()
local iputils = require "resty.iputils"
local mmdb = require "mmdb"
local ngx = require "ngx"
local dbfile = "/etc/kong/GeoLite2-Country.mmdb"

local req_set_header = ngx.req.set_header

local new_tab
do
  local ok
  ok, new_tab = pcall(require, "table.new")
  if not ok then
    new_tab = function() return {} end
  end
end

plugin.PRIORITY = 991
plugin.VERSION = "0.1.0"

local cache = {}
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

local function block_respond(conf)
  ngx.status = conf.error_status
  ngx.say(conf.error_message)
  ngx.exit(ngx.HTTP_OK)
end

local geodb

function plugin:new()
  plugin.super.new(self, "geoip-mmdb")
end

function plugin:init_worker()
  plugin.super.init_worker(self)
  local ok, err = iputils.enable_lrucache()
  if not ok then
    ngx.log(ngx.ERR, "[geoip-mmdb] Could not enable lrucache: ", err)
  end
  geodb = assert(mmdb.read(dbfile))
end

function plugin:access(conf)
  plugin.super.access(self)

  local remote_addr = ngx.var.remote_addr

  local geo_data = geodb:search_ipv4(remote_addr)

  -- Inject country header
  if conf.enable_country_injection then
    ngx.log(ngx.DEBUG, "Starting to extract country headers")
    if geo_data ~= nil and geo_data.country ~= nil and geo_data.country.iso_code ~= nil  then
      ngx.log(ngx.DEBUG, "Adding header ->" .. conf.country_header_iso ..":"..geo_data.country.iso_code)
      req_set_header(conf.country_header_iso, geo_data.country.iso_code)  
    else
      ngx.log(ngx.ERR,"Header value missing in " .. conf.country_header_iso )
      req_set_header(conf.country_header_iso, "Unknown") 
    end
    if conf.country_header_name ~= nil and geo_data ~= nil and geo_data.country ~= nil and geo_data.country.names.en ~= nil  then
      ngx.log(ngx.DEBUG, "Adding header ->" .. conf.country_header_name ..":"..geo_data.country.names.en)
      req_set_header(conf.country_header_name, geo_data.country.names.en)  
    else
      ngx.log(ngx.ERR,"Header value missing in " .. conf.country_header_name )
      req_set_header(conf.country_header_name, "Unknown") 
    end
  end

  -- check whitelist IP
  if conf.whitelist_ips and #conf.whitelist_ips > 0 then
    if iputils.ip_in_cidrs(remote_addr, cidr_cache(conf.whitelist_ips)) then
      return
    end
  end

  -- Block excluded countries
  if conf.blacklist_iso and #conf.blacklist_iso > 0 and geo_data ~= nil and geo_data.country ~= nil and geo_data.country.iso_code ~= nil then
    for i,line in ipairs(conf.blacklist_iso) do
      if line == geo_data.country.iso_code then
        block_respond(conf)
      end
    end
  end

end

return plugin
