# Inspur apig-monitoring
Kong plugin to log the metircs of an api and send to the destination address by http request

##Project Structure
```
apig-monitoring
├─ apig-monitoring-0.1.0-1.rockspec 
└─ kong
   └─ plugins
      └─ apig-monitoring
         ├─ handler.lua 
         ├─ schema.lua 
         ├─ log.lua 
         └─ counter.lua 
```
## Configuration
The configuration of schema
```
config.httpEndpoint   the destination address of meritc data sent by http request
```

## Example
declarative configuration file:
```
plugins:
- name: apig-monitoring
  config:
    httpEndpoint: 10.110.54.151:8080/metricsManager
```

## Tips
1. The metric data stores in the local shared memory of  ngx.shared.kong_rate_limiting_counters
2. You can build a custom memory by ngx.shared.dict 
3. The metirc is stored by key-value, and the key consists of metric name and the service of api,for example,
```json
{
  "requestCount:demo1Service": 10, 
  "httpStatus2xx:demo1Service": 10,
  "httpStatus4xx:demo1Service": 0,
  "httpStatus5xx:demo1Service": 0,
  "resTime:demo1Service":100,
  "reqTrafficData:demo1Service": 20480,
  "resTrafficData:demo1Service": 2048,
  "allErrorCount:demo1Service": 0,
  "requestCount:demo2Service": 20, 
  "httpStatus2xx:demo2Service": 20,
  "httpStatus4xx:demo2Service": 0,
  "httpStatus5xx:demo2Service": 0,
  "resTime:demo2Service":1200,
  "reqTrafficData:demo2Service": 10240,
  "resTrafficData:demo2Service": 1024,
  "allErrorCount:demo2Service": 0,

}

```
4. The json like step 3 is sent by http request in request body

## Installation
```
$ git clone https://github.com/kakascx/apig-monitoring.git /opt/kong/plugins 
$ cd /opt/kong/plugins/apig-monitoring
$ luarocks make
