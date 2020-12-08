local Monitor = {}
Monitor.__index = Monitor
Monitor.initialized = false

local Metric = {}
local ngx = ngx
local kong = kong
function Metric:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

local Counter = Metric:new()
--for example, value=1，label_values=json-suncx
function Counter:inc(value, label_values)
   self.monitor:inc(self.name, self.label_names, label_values, value or 1)
end

function Monitor.init(dict_name)
    local self = setmetatable({}, Monitor)
    dict_name = dict_name or "kong_rate_limiting_counters"
    self.dict = ngx.shared[dict_name]
    if self.dict == nil then
        ngx.log(ngx.ERR,
          "Dictionary '", dict_name, "' does not seem to exist. ",
          "Please define the dictionary using `lua_shared_dict`.")
        return self
    end

    self.registered = {}
    self.initialized = true

    return self
end

-------------------------------------------
-- name     Monitor:counter
-- function register a counter
-- param    name:        metirc name     string
--          label_name:  service name    string
-- return   Counter instance
-------------------------------------------

--例如name = http_status_2xx，label_names=service
function Monitor:counter(name, label_names)
    if not self.initialized then
      ngx.log(ngx.ERR, "Counter has not been initialized")
      return
    end
  
    if self.registered[name] then
      ngx.log(ngx.ERR, "Duplicate metric " .. name)
      return
    end
    self.registered[name] = true

    return Counter:new{name=name, label_names=label_names, monitor=self}
end

-- Set a given dictionary key.
-- This overwrites existing values, so it should only be used when initializing
-- metrics or when explicitely overwriting the previous value of a metric.
function Monitor:set_key(key, value)
    local ok, err = self.dict:safe_set(key, value)
    if not ok then
        kong.err.log("can't set key:" .. key .. " in ngx.shared.DICT",err)
        return
    end
end
-- name：http_status_2xx
-- label_names：service
-- label_values： json-sucnx
-- value：1
function Monitor:inc(name, label_names, label_values, value)
    local key = name .. ":" .. label_values
    if value == nil then value = 1 end
  
    local newval, err = self.dict:incr(key, value)
    if newval then
      return
    end
    -- Yes, this looks like a race, so I guess we might under-report some values
    -- when multiple workers simultaneously try to create the same metric.
    -- Hopefully this does not happen too often (shared dictionary does not get
    -- reset during configuation reload).
    if err == "not found" then
      self:set_key(key, value)
      return
    end
    -- Unexpected error
    kong.err.log("can't find or set key:" .. key .. " in ngx.shared.DICT",err)
    return
end

return Monitor