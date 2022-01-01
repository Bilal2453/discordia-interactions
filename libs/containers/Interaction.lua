--[=[
@c Interaction x Snowflake
@p data table
@p parent Client
@d Represents a [Discord Interaction](https://discord.com/developers/docs/interactions/receiving-and-responding#interactions)
allowing you to respond and reply to user interactions.
]=]

local discordia = require("discordia")
local Resolver = require("client/Resolver")
local ported = require("ported")
local enums = require("enums")
local bit = require("bit")

local bor = bit.bor
local class = discordia.class
local classes = class.classes
local Snowflake = classes.Snowflake
local messageFlag = enums.messageFlag
local parseMessage = ported.parseMessage
local callbackType = enums.interactionCallbackType
local channelType = discordia.enums.channelType

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
    if not channelId then goto skip end
    -- First try retrieving it from cache
    if self._guild then
      self._channel = self._guild._text_channels:get(channelId)
    elseif not data.guild_id then
      self._channel = parent._private_channels:get(channelId)
    end
    -- Last resort, request the channel object from the API if wasn't cached
    if not self._channel then
      local channel = self._api:getChannel(channelId)
      if not channel then goto skip end -- somehow channel not available

      local guild = channel.guild and parent._guilds:_insert(channel.guild)
      if guild then
        self._channel = guild._text_channels:_insert(channel)
      elseif channel.type == channelType.private then
        self._channel = parent._private_channels:_insert(channel)
      end
    end
    ::skip::
  end

  -- Handle user and member
  do
    if data.member and self._guild then
      self._member = self._guild._members:_insert(data.member)
      self._user = parent._users:_insert(data.member.user)
      goto skip
    end
    if data.user then
      self._user = parent._users:_insert(data.user)
    end
    ::skip::
  end

  -- Handle message
  do
    if not data.message then goto skip end
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
    ::skip::
  end

  -- Define Interaction state tracking
  self._initialRes = false
  self._deferred = false
end

function Interaction:_sendMessage(payload, files, deferred)
  local data, err = self._api:createInteractionResponse(self.id, self._token, {
    type = deferred and callbackType.deferredChannelMessage or callbackType.channelMessage,
    data = payload
  }, files)
  if data then
    self._initialRes = true
    self._deferred = deferred or false
    return true
  else
    return false, err
  end
end

function Interaction:_sendFollowup(payload, files)
  local data, err = self._api:createWebhookMessage(self._application_id, self._token, payload, files)
  return data and self._channel._messages:_insert(data), err
end

--[=[
@m reply
@t http
@p content string/table
@op isEphemeral boolean
@r TODO
@d Sends an interaction reply. An initial response is sent on first call of this,
if an initial response was already sent a followup message is sent instead.
If initial response was a deferred response, calling this will properly edit the deferred message.

Returns may not be consistent because blame Discord.
]=]
function Interaction:reply(content, isEphemeral)
  isEphemeral = isEphemeral and true or type(content) == "table" and content.ephemeral
  local msg, files = parseMessage(content)

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
  return method(self, msg, files) -- TODO: make sure returns are consistent, or it's fine like this?
end

--[=[
@m replyDeferred
@t http
@op isEphemeral boolean
@r boolean
@d Sends a deferred interaction reply.
Deferred replies can only be sent as initial responses.
A deferred reply displays "Bot is thinking..." to users, and once `:reply` is called again, deferred message will be edited.

Returns `true` on success, otherwise `false, err`.
]=]
function Interaction:replyDeferred(isEphemeral)
  local msg = isEphemeral and {flags = messageFlag.ephemeral} or nil
  return self:_sendMessage(msg, nil, true)
end

--[=[
@m getReply
@t http
@op id Message-ID-Resolvable
@r Message
@d Fetches a previously sent interaction response. If response `id` was not provided, the original interaction response is fetched instead.

Note: **Ephemeral messages cannot be retrieved once sent.**
]=]
function Interaction:getReply(id)
  id = Resolver.messageId(id) or "@original"
  local data, err = self._api:getWebhookMessage(self._application_id, self._token, id)
  return data and self._channel._messages:_insert(data), err
end

--[=[
@m editReply
@t http
@p content table/string
@op id Message-ID-Resolvable
@r Message
@d Modifies a previously sent interaction response. If response `id` was not provided, initial interaction response is edited instead.

Note: **Ephemeral messages cannot be modified once sent.**
]=]
function Interaction:editReply(content, id)
  id = Resolver.messageId(id) or self._message.id
  local msg, files = parseMessage(content)
  local data, err = self._api:editWebhookMessage(self._application_id, self._token, id, msg, files)
  return data and true, err
end

--[=[
@m deleteReply
@t http
@op id Message-ID-Resolvable
@r boolean
@d Deletes a previously sent response. If response `id` was not provided, original interaction response is deleted instead.

Returns `true` on success, otherwise `false, err`.
Note: **Ephemeral messages cannot be deleted once sent.**
]=]
function Interaction:deleteReply(id)
  id = Resolver.messageId(id) or "@original"
  local data, err = self._api:deleteWebhookMessage(self._application_id, self._token, id)
  return data and true, err
end

function Interaction:_sendUpdate(payload, files)
  local data, err = self._api:createInteractionResponse(self.id, self._token, {
    type = payload and callbackType.updateMessage or callbackType.deferredUpdateMessage,
    data = payload
  }, files)
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
@p content table/string
@r boolean
@d Responds to a component-based interaction by modifying the original bot's message the components were attached to.

Returns `true` on success, otherwise `false, err`.
]=]
function Interaction:update(content)
  assert(self._message, "UPDATE_MESSAGE is only supported by components-based interactions!")
  local msg, files = parseMessage(content)
  if not msg and not self._initialRes then
    return self:_sendUpdate()
  end
  if self._initialRes then
    local data, err = self._api:editMessage(self._message._parent._id, self._message._id, msg, files)
    if data then
      self._message:_setOldContent(data)
      self._message:_load(data)
      return true
    end
    return false, err
  else
    return self:_sendUpdate(msg, files)
  end
end

--[=[
@m updateDeferred
@t http
@r boolean
@d Responds to a component-based interaction by acknowledging the interaction,
where the next used `reply`/`update` methods will update the original bot message.

Returns `true` on success, otherwise `false, err`.
]=]
function Interaction:updateDeferred()
  return self:_sendUpdate()
end

--[=[@p applicationId string A unique snowflake ID of the application.]=]
function get:applicationId()
  return self._application_id
end

--[=[@p type number The Interaction type, see interactionType enum.]=]
function get:type()
  return self._type
end

--[=[@p guildId string/nil The Snowflake ID of the guild the interaction happened at, if any.]=]
function get:guildId()
  return self._guild_id
end

--[=[@p guild Guild/nil The Guild object the interaction happened at. Equivalent to `Client:getGuild(Interaction.guildId)`.]=]
function get:guild()
  return self._guild
end

--[=[@p channelId string The Snowflake ID of the channel the interaction was made at.
Should always be provided, but keep in mind Discord flags it as optional for future-proofing.]=]
function get:channelId()
  return self._channel_id
end

--[=[@p channel channel/nil The Channel object the interaction exists at.
Equivalent to `Client:getChannel(Interaction.channelId)`.]=]
function get:channel()
  return self._channel
end

--[=[@p message message/nil The message the interaction was attached to. Currently only provided for components-based interactions.]=]
function get:message()
  return self._message
end

--[=[@p member member/nil The member who interacted with the application in a guild.]=]
function get:member()
  return self._member
end

--[=[@p user user The User object of who interacted with the application, should always be available.]=]
function get:user()
  return self._user
end

--[=[@p data table The raw data of the interaction. See [Interaction Data Structure](https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-object-resolved-data-structure)]=]
function get:data()
  return self._data
end

--[=[@p token string The interaction token. What allows you to responds to a specific interaction.
This is a secret and shouldn't be exposed, if leaked anyone can send messages on behalf of your bot.]=]
function get:token()
  return self._token
end

--[=[@p version string The interaction version. (Currently not useful at all)]=]
function get:version()
  return self._version
end

--[=[@p locale string The user's client language and locale.]=]
function get:locale()
  return self._locale
end

return Interaction
