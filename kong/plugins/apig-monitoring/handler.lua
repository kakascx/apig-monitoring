local basic_serializer = require "kong.plugins.log-serializers.basic"
local log = require "kong.plugins.apig-monitoring.log"

local BasePlugin = require "kong.plugins.base_plugin"

local ngx = ngx
local initialized = false
local requested = false

local MonitoringPlugin = BasePlugin:extend()

MonitoringPlugin.PRIORITY = 10
MonitoringPlugin.VERSION = "3.5.0"

function MonitoringPlugin:new()
    MonitoringPlugin.super.new(self, "apig-monitoring")

end

function MonitoringPlugin:log(conf)
    MonitoringPlugin.super.log(self)
    local message = basic_serializer.serialize(ngx)
    initialized,requested = log.execute(message,conf,initialized,requested)
end

return MonitoringPlugin
