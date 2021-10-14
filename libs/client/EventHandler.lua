local Interaction = require("containers/Interaction")
local events = {}

events.INTERACTION_CREATE = function(d, client)
  local interaction = Interaction(d, client)
  return client:emit("interactionCreate", interaction)
end

return events
