local typedefs = require "kong.db.schema.typedefs"

return {
  name = "apig-monitoring",
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          -- NOTE: any field added here must be also included in the handler's get_queue_id method
          { httpEndpoint = typedefs.url({ required = true }) },
    }, }, },
  },
}