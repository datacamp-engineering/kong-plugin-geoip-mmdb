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
        blacklist_iso = {'PT'},
        blacklist_geoname = {'703883'},
        whitelist_ips = {'5.59.38.1', '5.43.0.1'},
        database_file = "/tmp/geolite/latest/GeoLite2-City.mmdb"
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
      assert.res_status(200, res)
    end)
  end)

  describe("blacklist_geoname", function()
    it("blocks a request that's blacklisted", function()
      local res = assert(client:send {
        method  = "GET",
        path    = "/status/200",
        headers = {
          ["Host"] = "test1.com",
          ["X-Forwarded-For"] = "5.59.38.0"
        }
      })
      assert.res_status(403, res)
    end)
    it("allows if in whitelist", function()
      local res = assert(client:send {
        method  = "GET",
        path    = "/status/200",
        headers = {
          ["Host"] = "test1.com",
          ["X-Forwarded-For"] = "5.59.38.1"
        }
      })
      assert.res_status(200, res)
    end)
  end)

  describe("blacklist_iso", function()
    it("blocks a request that's blacklisted", function()
      local res = assert(client:send {
        method  = "GET",
        path    = "/status/200",
        headers = {
          ["Host"] = "test1.com",
          ["X-Forwarded-For"] = "5.43.0.0"
        }
      })
      assert.res_status(403, res)
    end)
    it("allows if in whitelist", function()
      local res = assert(client:send {
        method  = "GET",
        path    = "/status/200",
        headers = {
          ["Host"] = "test1.com",
          ["X-Forwarded-For"] = "5.43.0.1"
        }
      })
      assert.res_status(200, res)
    end)
  end)
end)
