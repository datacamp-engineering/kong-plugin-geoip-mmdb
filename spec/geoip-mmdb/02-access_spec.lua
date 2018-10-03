local helpers = require "spec.helpers"

describe("Plugin: geoip-mmdb (access)", function()
  local client
  local plugin
  local dao

  setup(function()
    local bp, _
    bp, _, dao = helpers.get_db_utils('postgres')

    local api1 = assert(bp.routes:insert { 
      hosts = { "test1.com" },
    })

    assert(bp.plugins:insert {
      route_id = api1.id,
      name = "geoip-mmdb",
      config = {
        blacklist_iso = {'RU', 'UA'},
        blacklist_geoname = {'703883'},
        whitelist_ips = {'212.120.189.11', '83.242.96.11'},
        database_file = "/tmp/geolite/GeoLite2-City_20180925/GeoLite2-City.mmdb"
      }
    })

    assert(helpers.start_kong {
      custom_plugins = "geoip-mmdb",
      real_ip_header = "X-Forwarded-For",
      real_ip_recursive = "on",
      trusted_ips    = "0.0.0.0/0",
      nginx_conf     = "/kong/spec/fixtures/custom_nginx.template",
    })
  end)

  teardown(function()
    helpers.stop_kong()
  end)

  before_each(function()
    client = helpers.proxy_client()
  end)

  after_each(function()
    if client then client:close() end
  end)

  describe("passing request", function()
    it("allows a normal request through", function()
      local res = assert(client:send {
        method  = "GET",
        path    = "/status/200",
        headers = {
          ["Host"] = "test1.com",
          ["X-Forwarded-For"] = "1.1.1.1"
        }
      })
      local body = assert.res_status(200, res)
    end)
  end)

  describe("blacklist_geoname", function()
    it("blocks a request that's blacklisted", function()
      local res = assert(client:send {
        method  = "GET",
        path    = "/status/200",
        headers = {
          ["Host"] = "test1.com",
          ["X-Forwarded-For"] = "212.120.189.12"
        }
      })
      local body = assert.res_status(403, res)
    end)
    it("allows if in whitelist", function()
      local res = assert(client:send {
        method  = "GET",
        path    = "/status/200",
        headers = {
          ["Host"] = "test1.com",
          ["X-Forwarded-For"] = "212.120.189.11"
        }
      })
      local body = assert.res_status(200, res)
    end)
  end)

  describe("blacklist_iso", function()
    it("blocks a request that's blacklisted", function()
      local res = assert(client:send {
        method  = "GET",
        path    = "/status/200",
        headers = {
          ["Host"] = "test1.com",
          ["X-Forwarded-For"] = "93.171.18.56"
        }
      })
      local body = assert.res_status(403, res)
    end)
    it("allows if in whitelist", function()
      local res = assert(client:send {
        method  = "GET",
        path    = "/status/200",
        headers = {
          ["Host"] = "test1.com",
          ["X-Forwarded-For"] = "83.242.96.11"
        }
      })
      local body = assert.res_status(200, res)
    end)
  end)
end)
