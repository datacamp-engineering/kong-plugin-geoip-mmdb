local schemas_validation = require "kong.dao.schemas_validation"
local schema             = require "kong.plugins.geoip-mmdb.schema"


local v = schemas_validation.validate_entity


describe("valid schema", function()
  it("should accept a valid whitelist", function()
    assert(v({whitelist_ips = {"127.0.0.1", "127.0.0.2"}}, schema))
  end)
  it("should accept a valid blacklist_iso", function()
    assert(v({blacklist_iso = {"RU", "UA"}}, schema))
  end)

  describe("errors", function()
    it("whitelist_ips should not accept invalid types", function()
      local ok, err = v({whitelist_ips = 12}, schema)
      assert.False(ok)
      assert.same({whitelist_ips = "whitelist_ips is not an array"}, err)
    end)
    it("whitelist should not accept invalid IPs", function()
      local ok, err = v({whitelist_ips = "hello"}, schema)
      assert.False(ok)
      assert.same({whitelist_ips = "cannot parse 'hello': Invalid IP"}, err)

      ok, err = v({whitelist_ips = {"127.0.0.1", "127.0.0.2", "hello"}}, schema)
      assert.False(ok)
      assert.same({whitelist_ips = "cannot parse 'hello': Invalid IP"}, err)
    end)
    it("blacklist_iso should not accept invalid types", function()
      local ok, err = v({blacklist_iso = 12}, schema)
      assert.False(ok)
      assert.same({blacklist_iso = "blacklist_iso is not an array"}, err)
    end)
  end)
end)

