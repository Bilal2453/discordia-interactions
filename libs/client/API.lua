local API = {} -- API:request is defined in init.lua
local f = string.format

-- endpoints are never patched into Discordia
-- therefor not defining them in their own file, although the actual requests are
local endpoints = {
  INTERACTION_CALLBACK  = "/interactions/%s/%s/callback",
  INTERACTION_WEBHOOK   = "/webhooks/%s/%s",
  INTERACTION_MESSAGES  = "/webhooks/%s/%s/messages/%s",
  CHANNEL_MESSAGE       = "/channels/%s/messages/%s",
}

function API:createInteractionResponse(id, token, payload, files)
  local endpoint = f(endpoints.INTERACTION_CALLBACK, id, token)
  return self:request("POST", endpoint, payload, nil, files)
end

function API:createWebhookMessage(id, token, payload, files) -- same as executeWebhook but allows files
	local endpoint = f(endpoints.INTERACTION_WEBHOOK, id, token)
	return self:request("POST", endpoint, payload, nil, files)
end

function API:getWebhookMessage(id, token, msg_id)
  local endpoint = f(endpoints.INTERACTION_MESSAGES, id, token, msg_id)
  return self:request("GET", endpoint)
end

function API:deleteWebhookMessage(id, token, msg_id)
  local endpoint = f(endpoints.INTERACTION_MESSAGES, id, token, msg_id)
  return self:request("DELETE", endpoint)
end

function API:editWebhookMessage(id, token, msg_id, payload, files)
  local endpoint = f(endpoints.INTERACTION_MESSAGES, id, token, msg_id)
  return self:request("PATCH", endpoint, payload, nil, files)
end

function API:editMessage(channel_id, message_id, payload, files) -- patch Discordia's to allow files field
	local endpoint = f(endpoints.CHANNEL_MESSAGE, channel_id, message_id)
	return self:request("PATCH", endpoint, payload, nil, files)
end

return API
