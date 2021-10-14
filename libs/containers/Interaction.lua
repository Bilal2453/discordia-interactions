local discordia = require("discordia")
local Resolver = require("client/Resolver")
local enums = require("enums")
local bit = require("bit")

local bor = bit.bor
local class = discordia.class
local classes = class.classes
local Snowflake = classes.Snowflake
local messageFlag = enums.messageFlag

local Interaction, get = class("Interaction", Snowflake)

function Interaction:__init(data, parent)
  Snowflake.__init(self, data, parent)
  self._api = parent._api -- a bit easier to navigate

  -- Handle guild and guild_id
  do local guildId = data.guild_id
    self._guild = guildId and parent._guilds:get(guildId)
    if not self._guild and guildId then
      local guild = self._api:getGuild(guildId)
      self._guild = parent._guilds:_insert(guild)
    end
  end

  -- Handle channel and channel_id
  do local channelId = data.channel_id
    if not channelId then goto skip_channel_handling end
    -- First try retrieving it from cache
    if self._guild then
      self._channel = self._guild._text_channels:get(channelId)
    elseif not data.guild_id then
      self._channel = parent._private_channels:get(channelId)
    end
    -- Last resort, request the channel object from the API if wasn't cached
    if not self._channel then
      local channel = self._api:getChannel(channelId)
      if not channel then goto skip_channel_handling end -- somehow channel not available

      local guild = channel.guild and parent._guilds:_insert(channel.guild)
      if guild then
        self._channel = guild._text_channels:_insert(channel)
      elseif channel.type == 1 then
        self._channel = parent._private_channels:_insert(channel)
      end
    end
    ::skip_channel_handling::
  end

  -- Handle user and member
  do
    if data.user then
      self._user = parent._users:_insert(data.user)
    end
    if data.member and self._guild then
      self._member = self._guild._members:_insert(data.member)
    end
  end

  -- Handle message
  do
    if not data.message then goto skip_message_handling end
    if self._channel then
      self._message = self._channel._messages:_insert(data.message)
    elseif data.message.channel then
      local guild, cache = data.message.guild, nil
      if guild then
        guild = parent._guilds:_insert(guild)
        cache = guild._text_channels:_insert(data.message.channel)
      else
        cache = parent._private_channels:_insert(data.message.channel)
      end
      self._message = cache and cache._messages:_insert(data.message)
    end
    ::skip_message_handling::
  end

  -- Define Interaction state tracking
  self._initialRes = false
  self._deferred = false
end

function Interaction:_sendMessage(payload, deferred)
  local data, err = self._api:createInteractionResponse(self.id, self._token, {
    type = deferred and 5 or 4,
    data = payload
  })
  if data then
    self._initialRes = true
    self._deferred = deferred or false
    return true
  else
    return false, err
  end
end

function Interaction:_sendFollowup(msg)
  local data, err = self._api:executeWebhook(self._application_id, self._token, msg)
  return data and self._channel._messages:_insert(data), err
end

function Interaction:reply(msg, isEphemeral)
  local msgType = type(msg)
  if msgType == "table" then
    isEphemeral = isEphemeral and true or msg.ephemeral
    msg.ephemeral = nil
  else
    msg = {content = tostring(msg)}
  end

  -- Handle ephemeral flags setting
  if isEphemeral then
    msg.flags = bor(type(msg.flags) == "number" or 0, messageFlag.ephemeral)
  end

  -- Choose desired method depending on the context
  local method
  if self._deferred then
    method = self.editReply
  elseif self._initialRes then
    method = self._sendFollowup
  else
    method = self._sendMessage
  end
  return method(self, msg) -- TODO: make sure returns are constant, or should they not be constant?
end

function Interaction:replyDeferred(isEphemeral)
  local msg = isEphemeral and {flags = messageFlag.ephemeral} or nil
  return self:_sendMessage(msg, true)
end

function Interaction:getReply(id)
  id = Resolver.messageId(id) or "@original"
  local data, err = self._api:getWebhookMessage(self._application_id, self._token, id)
  return data and self._channel._messages:_insert(data), err
end

function Interaction:editReply(payload, id)
  id = Resolver.messageId(id) or self._message.id
  payload = type(payload) == "table" and payload or {content = tostring(payload)}
  local data, err = self._api:editWebhookMessage(self._application_id, self._token, id, payload)
  return data and true, err
end

function Interaction:deleteReply(id)
  id = Resolver.messageId(id) or "@original"
  local data, err = self._api:deleteWebhookMessage(self._application_id, self._token, id)
  return data and true, err
end

function Interaction:_sendUpdate(payload)
  local data, err = self._api:createInteractionResponse(self.id, self._token, {
    type = payload and 7 or 6,
    data = payload
  })
  if data then
    self._initialRes = true
    self._deferred = not payload and true
    return true
  else
    return false, err
  end
end

function Interaction:update(msg)
  assert(self._message, "UPDATE_MESSAGE is only supported by components-based interactions!")
  if msg == nil and not self._initialRes then
    return self:_sendUpdate()
  elseif type(msg) ~= "table" then
    msg = {content = tostring(msg)}
  end
  if self._initialRes then
    return self._message:_modify(msg) -- TODO: make sure returns here are constant with _sendUpdate returns
  else
    return self:_sendUpdate(msg)
  end
end

function Interaction:updateDeferred()
  return self:_sendUpdate()
end

function get.applicationId(self)
  return self._application_id
end

function get.type(self)
  return self._type
end

function get.guildId(self)
  return self._guild_id
end

function get.guild(self)
  return self._guild
end

function get.channelId(self)
  return self._channel_id
end

function get.channel(self)
  return self._channel
end

function get.message(self)
  return self._message
end

function get.member(self)
  return self._member
end

function get.user(self)
  return self._user
end

function get.data(self)
  return self._data
end

function get.token(self)
  return self._token
end

function get.version(self)
  return self._version
end

return Interaction
