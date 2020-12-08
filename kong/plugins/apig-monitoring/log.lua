local cjson = require "cjson"
local url = require "socket.url"
local http = require "resty.http"

local _M = {}

local kong = kong
local timer_every = ngx.timer.every
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local _os_getenv = os.getenv

local cjson_encode = cjson.encode
local shm = ngx.shared.kong_rate_limiting_counters
local APIGKEY = "apigateway"

local metrics = {}
local monitor

-------------------------------------------
-- name     init
-- function initialize counters
-- return   [error] ngx shared dict 'kong_rate_limiting_counters' not found

-------------------------------------------
local function init()
    local dict = "kong_rate_limiting_counters"
    if not ngx.shared.kong_rate_limiting_counters then
        kong.log.err("apig-monitoring: ngx shared dict 'kong_rate_limiting_counters' not found")
        return
    end
    monitor = require("kong.plugins.apig-monitoring.counter").init(dict)

    -- initialize counters of every metric
    metrics.request_count = monitor:counter("requestCount", "service")
    metrics.status2xx = monitor:counter("httpStatus2xx", "service")
    metrics.status4xx = monitor:counter("httpStatus4xx", "service")
    metrics.status5xx = monitor:counter("httpStatus5xx", "service")
    metrics.reqTrafficData = monitor:counter("reqTrafficData", "service")
    metrics.resTrafficData = monitor:counter("resTrafficData", "service")
    metrics.resTime = monitor:counter("resTime", "service")
    kong.log("init finish")
end

-------------------------------------------
-- name     increment
-- function count the metrics of an api
-- param    message: the original message of an api  [table]
-- return   [error] can not log metrics because of an initialization
--          [error] can not record because of no service
-------------------------------------------
local function increment(message)
    if not metrics then
        kong.log.err("can not log metrics because of an initialization,pls check 'kong_rate_limiting_counters'shared dict in your nginx template ")
        return
    end
    local service
    if message and message.service then
        service = message.service.name
    else
        kong.log.err("can not record because of no service")
        return
    end

    local status = message.response.status

    -- total number of access
    if next(message.request) then
        metrics.request_count:inc(1, service)
    end

    -- the number of 2xx response,for example service=json-suncx
    if status >= 200 and status < 300 then
        metrics.status2xx:inc(1, service)
    end

    -- the number of 4xx response,for example service=json-suncx
    if status >= 400 and status < 500 then
        metrics.status4xx:inc(1, service)
    end

    --the number of 5xx response,for example service=json-suncx
    if status >= 500 and status < 600 then
        metrics.status5xx:inc(1, service)
    end

    -- ingress bandwidth
    local request_size = tonumber(message.request.size)
    if request_size and request_size > 0 then
        metrics.reqTrafficData:inc(request_size, service)
    end

    -- egress bandwidth
    local response_size = tonumber(message.response.size)
    if response_size and response_size > 0 then
        metrics.resTrafficData:inc(response_size, service)
    end

    -- response total latency
    local response_time = tonumber(message.latencies.proxy)
    if response_time and response_time >= 0 then
        metrics.resTime:inc(response_time, service)
    end

    kong.log("increment finish")
end

-------------------------------------------
-- name     parse_url
-- function parse the url of destination
-- return   parsed_url，result of parse url including host,port,path and query [table]
-------------------------------------------
local function parse_url(host_url)
    local parsed_url = url.parse(host_url)
    kong.log("authority is: ",parsed_url.authority)
    if not parsed_url.port then
        if parsed_url.scheme == "http" then
            parsed_url.port = 80
        elseif parsed_url.scheme == "https" then
            parsed_url.port = 443
        end
    end

    return parsed_url
end

-------------------------------------------
-- name     get_usage
-- function get the metrics from ngx shared dict 'kong_rate_limiting_counters'
-- return   usage    data sent by request body   table
-------------------------------------------
local function get_usage()
    local usage = {}
    local keys = shm:get_keys(0)
    for _, key in pairs(keys) do
        local value, err = shm:get(key)
        if not value then
            kong.log.err("not found" .. key .. "in shm", err)
        end
        usage[key] = value
    end
    return usage
end

-------------------------------------------
-- name     do_http_request
-- function send the metirc data to de destination address by http request
-- param    premature:  the flag of timer
--          parsed_url: destination address      [table]
-------------------------------------------
local function do_http_request(premature, parsed_url)
    if not premature then
        local content_type = "application/json;charset=UTF-8"
        local host = parsed_url.host
        local port = tonumber(parsed_url.port)

        local httpc = http.new()
        httpc:set_timeout(5000)
        local ok, err = httpc:connect(host, port)

        if not ok then
            kong.log.err("failed to connect to " .. host .. ":" .. tostring(port) .. ": " .. err)
            return
        end

        if parsed_url.scheme == "https" then
            local _, err = httpc:ssl_handshake(true, host, false)
            if err then
                kong.log.err("failed to do SSL handshake with " .. host .. ":" .. tostring(port) .. ": " .. err)
                return
            end
        end

        local usage = get_usage()
        -- local env = _os_getenv("HOSTNAME")
        -- usage["podName"] = env
        usage = cjson_encode(usage)
        
        local res, err = httpc:request({
            method = 'POST',
            path = parsed_url.path,
            query = parsed_url.query,
            headers = {
                ["Host"] = parsed_url.host,
                ["Content-Type"] = content_type,
                ["Content-Length"] = #usage,
                ["apigkey"] = APIGKEY,
            },
            body = usage,
        })

        if not res then
            kong.log.err("failed request to ", host, ":", tostring(port), ": ", err)
            return
        end
        
        local status = res.status
        if status >= 300 then
            local response_body = res:read_body()
            kong.log("response status is: ",status)
            kong.log("body is:",response_body)
            kong.log("usage is", usage)
        end
    end
end

function _M.execute(message, conf,initialized,requested)
    if not initialized then
        init()
        initialized = true
    end
    increment(message)
    local http_endpoint = conf.httpEndpoint
    local parsed_url = parse_url(http_endpoint)

    if not requested then
        local ok, err = timer_every(30, do_http_request, parsed_url)
        if not ok then
            kong.log.err("failed to create timer: ", err)
        end
        requested = true
        kong.log("finish timer")
    end

    return initialized,requested

end

return _M
