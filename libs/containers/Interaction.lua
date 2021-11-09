--[=[
@c Interaction x Snowflake
@p data table
@p parent Client
@d Represents a [Discord Interaction](https://discord.com/developers/docs/interactions/receiving-and-responding#interactions)
allowing you to respond and reply to user interactions.
]=]

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
  self._data = data.data

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

--[=[
@m reply
@t http
@p data string/table
@op isEphemeral boolean
@r ??
@d Constructs a new reply to said interaction. If this is the first reply an initial one is sent,
if previous reply was a deferred response, this will edit it to provided content,
otherwise if previous reply is fully sent, this sends a followup response.

Returns may not be constant because blame Discord.
]=]
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
  if self._initialRes or self._deferred then
    method = self._sendFollowup
  else
    method = self._sendMessage
  end
  return method(self, msg) -- TODO: make sure returns are constant, or should they not be constant?
end

--[=[
@m replyDeferred
@t http
@op isEphemeral boolean
@r boolean
@d Constructs an initial response that's deferred.
Deferred reply can only be an initial response, and when used it will basically send a message that says
"Bot is thinking...", and once `:reply` is used again it will edit that message.

Returns `true` on success, otherwise `false, err`.
]=]
function Interaction:replyDeferred(isEphemeral)
  local msg = isEphemeral and {flags = messageFlag.ephemeral} or nil
  return self:_sendMessage(msg, true)
end

--[=[
@m getReply
@t http
@op id Message-ID-Resolvable
@r Message
@d Returns a reply message with the provided id, if no id was provided the original response message is returned.

**Ephemeral Messages Cannot be Retrieved**
]=]
function Interaction:getReply(id)
  id = Resolver.messageId(id) or "@original"
  local data, err = self._api:getWebhookMessage(self._application_id, self._token, id)
  return data and self._channel._messages:_insert(data), err
end

--[=[
@m editReply
@t http
@p payload table/string
@op id Message-ID-Resolvable
@r Message
@d Modifies a response message with the provided id, if no id was provided original response is modified instead.
`payload` is raw Message-alike table, if string is provided it is treated as `content` field

**Ephemeral Messages Cannot be Modified**
]=]
function Interaction:editReply(payload, id)
  id = Resolver.messageId(id) or self._message.id
  payload = type(payload) == "table" and payload or {content = tostring(payload)}
  local data, err = self._api:editWebhookMessage(self._application_id, self._token, id, payload)
  return data and true, err
end

--[=[
@m deleteReply
@t http
@p payload table/string
@r Message
@d Modifies a response message with the provided id, if no id was provided original response is modified instead.
`payload` is raw Message-alike table, if string is provided it is treated as `content` field

**Ephemeral Messages Cannot be Modified**
]=]
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

--[=[
@m update
@t http
@p data table/string
@r Message
@d Responds to a component-based interaction by modifying the original bot's message. `msg` is similar to editReply.

Returns the original modified bot message (?).
]=]
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

--[=[
@m updateDeferred
@t http
@r Message
@d Responds to a component-based interaction by acknowledging the interaction,
where the next used `reply`/`update` methods will update the original bot message.

Returns the original bot message (?).
]=]
function Interaction:updateDeferred()
  return self:_sendUpdate()
end

--[=[@p applicationId string A unique snowflake ID of the application.]=]
function get.applicationId(self)
  return self._application_id
end

--[=[@p type number The Interaction type, see interactionType enum.]=]
function get.type(self)
  return self._type
end

--[=[@p guildId string/nil A snowflake ID of the guild the interaction was made in if any.]=]
function get.guildId(self)
  return self._guild_id
end

--[=[@p guild Guild/nil The guild object of self.guildId if any.]=]
function get.guild(self)
  return self._guild
end

--[=[@p channelId string A snowflake ID of the channel the interaction was made in.
Should always be provided, but keep in mind Discord flag it as optional for future-proofing.]=]
function get.channelId(self)
  return self._channel_id
end

--[=[@p channel channel/nil The channel object of self.channelId.]=]
function get.channel(self)
  return self._channel
end

--[=[@p message message/nil The message the interaction was used on. Currently only for components-based interactions.]=]
function get.message(self)
  return self._message
end

--[=[@p member member/nil The member who made the interaction if it was in guild.]=]
function get.member(self)
  return self._member
end

--[=[@p user member The user who made the interaction, should exists always.]=]
function get.user(self)
  return self._user
end

--[=[@p data table The raw data of the interaction. See [Interaction Data Structure](https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-object-resolved-data-structure)]=]
function get.data(self)
  return self._data
end

--[=[@p token string The interaction token. What allows you to responds to a specific interaction.
This is a secret and shouldn't be exposed, if leaked anyone can send messages on behalf of your bot]=]
function get.token(self)
  return self._token
end

--[=[@p version string The interaction version. (aka not useful at all)]=]
function get.version(self)
  return self._version
end

return Interaction
