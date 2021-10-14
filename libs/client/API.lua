local API = {} -- API:request is defined in init.lua
local f = string.format

-- endpoints are never patched into Discordia
-- therefor not defining them in their own file
local endpoints = {
  INTERACTION_CALLBACK  = "/interactions/%s/%s/callback",
  INTERACTION_MESSAGES  = "/webhooks/%s/%s/messages/%s",
}

function API:createInteractionResponse(id, token, payload)
  local endpoint = f(endpoints.INTERACTION_CALLBACK, id, token)
  return self:request("POST", endpoint, payload)
end

function API:getWebhookMessage(id, token, msg_id)
  local endpoint = f(endpoints.INTERACTION_MESSAGES, id, token, msg_id)
  return self:request("GET", endpoint)
end

function API:deleteWebhookMessage(id, token, msg_id)
  local endpoint = f(endpoints.INTERACTION_MESSAGES, id, token, msg_id)
  return self:request("DELETE", endpoint)
end

function API:editWebhookMessage(id, token, msg_id, payload)
  local endpoint = f(endpoints.INTERACTION_MESSAGES, id, token, msg_id)
  return self:request("PATCH", endpoint, payload)
end

return API
