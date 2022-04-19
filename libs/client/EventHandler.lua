local Interaction = require("containers/Interaction")
local events = {
  interaction_create_prelisteners = {}
}

events.INTERACTION_CREATE = function(d, client)
  local interaction = Interaction(d, client)
  for _, v in pairs(events.interaction_create_prelisteners) do
    v(interaction, client)
  end
  return client:emit("interactionCreate", interaction)
end

return events
