local Interaction = require("containers/Interaction")
local events = {
  interaction_create_prelisteners = {},
  interaction_create_postlisteners = {},
}

local function emitListeners(listeners, ...)
  for _, v in pairs(listeners) do
    v(...)
  end
end

function events.INTERACTION_CREATE(d, client)
  local interaction = Interaction(d, client)
  emitListeners(events.interaction_create_prelisteners, interaction, client)
  client:emit("interactionCreate", interaction)
  emitListeners(events.interaction_create_postlisteners, interaction, client)
end

-- This code is part of Discordia
local function checkReady(shard)
	for _, v in pairs(shard._loading) do
		if next(v) then return end
	end
	shard._ready = true
	shard._loading = nil
	collectgarbage()
	local client = shard._client
	client:emit('shardReady', shard._id)
	for _, other in pairs(client._shards) do
		if not other._ready then return end
	end
	return client:emit('ready')
end

function events.GUILD_CREATE(d, client, shard)
	if client._options.syncGuilds and not d.unavailable and not client._user._bot then
		shard:syncGuilds({d.id})
	end
	local guild = client._guilds:get(d.id)
	if guild then
    if guild._partial then
      guild._partial = nil
      guild:_load(d)
			guild:_makeAvailable(d)
      return client:emit('guildCreate', guild)
    elseif guild._unavailable and not d.unavailable then
			guild:_load(d)
			guild:_makeAvailable(d)
			client:emit('guildAvailable', guild)
		end
		if shard._loading then
			shard._loading.guilds[d.id] = nil
			return checkReady(shard)
		end
	else
		guild = client._guilds:_insert(d)
		return client:emit('guildCreate', guild)
	end
end

return events
