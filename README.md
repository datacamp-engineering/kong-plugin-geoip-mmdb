# kong-plugin-geoip-mmdb

A Kong plugin that will verify incoming IP Addresses, validate the location is allowed and update headers if required.

## How it works
When enabled, this plugin will verify the remote address of the client, validate that it is not coming from a blocked country (i.e `blacklist_iso`) or is part of a privileged IP range (i.e `whitelist_ips`) and possibly add the country to an header for the backend service (i.e `enable_country_injection`) 

This plugin can also be used in conjunction with other Kong plugins like Rate limiting etc.

## Plugin schema/configuration
| Parameter | Default  | Required | description |
| --- | --- | --- | --- |
| `name` || true | plugin name, has to be `geoip-mmdb` |
| `config.whitelist_ips` |  | false | array of IPs that can access the API despite any country restriction |
| `config.blacklist_iso` |  | false | Array of countries that should not access the API |
| `config.enable_country_injection` | false | false | Flag to add the country of location of the client as an header to the backend service |
| `config.country_header_iso` | X-Country-Code | false | 2 digit Code (ISO-3166 alpha2) of the country of location of the client |
| `config.country_header_name` |  | false | Name of the header to add the country name (in english). If empty, this header will not be added|
| `config.error_status` | 403 | false | HTTP status code sent back to the client when blocked |
| `config.error_message` | This site is unavailable in your country | false | Message sent back to the client when blocked |

## Configuration

### Prevent countries to access APIs

To block a country, the code needs to be added to the list `blacklist_iso`. This is a 2-digit code following the ISO-3166 alpha2 norm.

```yaml
blacklist_iso: ['RU', 'KP']
```

### Whitelist IPs to access APIs

To whitelist an IP, it needs to be added to the `whitelist_ips` list.

```yaml
whitelist_ips: ['10.34.12.21']
```

### Enable country extraction

Following plugin configuration options can be used to enable country injection rules. Individual configuration details are explained above in __*"Plugin schema/configuration"*__ section.

* enable_country_injection
* country_header_iso
* country_header_name


#### Examples


```yaml
- name: echoService
  url: {url}
  routes:
   - name: echoRoute
     paths: [/echo-request]
     methods: [GET]
     plugins:
     - name: geoip-mmdb
       config:
        enable_country_injection: true
        blacklist_iso: ['RU', 'KP']
        whitelist_ips: ['10.34.12.21']
        country_header_name: X-Country-Name
```

## Installation - Betclic Internal


### Dowload the plugin from github
```bash
git clone git@github.com:betclicgroup/kong-plugin-geoip-mmdb.git /tmp/mmdb
```

### Deploy the plugin on Lua
```bash
sudo mv /tmp/mmdb/kong/plugins/geoip-mmdb /usr/local/share/lua/5.1/kong/plugins/geoip-mmdb
```

### Enable the plugin on Kong configuration

update and redeploy `kong.conf` following these [instructions](https://github.com/betclicgroup/kong-configuration-front/tree/master/application#plugin-installations)
