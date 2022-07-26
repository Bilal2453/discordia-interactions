local discordia = require("discordia")
local resolver = require("client/resolver")
local enums = require("enums")
local bit = require("bit")

local bor = bit.bor
local class = discordia.class
local classes = class.classes
local intrType = enums.interactionType
local Snowflake = classes.Snowflake
local messageFlag = enums.messageFlag
local resolveMessage = resolver.message
local callbackType = enums.interactionCallbackType
local channelType = discordia.enums.channelType

---Represents a [Discord Interaction](https://discord.com/developers/docs/interactions/receiving-and-responding#interactions)
---allowing you to respond and reply to user interactions.
---@class Interaction: Snowflake
---@field applicationId string The application's unique snowflake ID.
---@field type number The Interaction's type, see interactionType enum for info.
---@field guildId string? The Snowflake ID of the guild the interaction happened at, if any.
---@field guild Guild? The Guild object the interaction happened at. Equivalent to `Client:getGuild(Interaction.guildId)`.
---@field channelId string The Snowflake ID of the channel the interaction was made at. Should always be provided, but keep in mind Discord flags it as optional for future-proofing.
---@field channel Channel? The Channel object the interaction exists at. Equivalent to `Client:getChannel(Interaction.channelId)`. Can be `GuildTextChannel` or `PrivateChannel`.
---@field message Message? The message the interaction was attached to. Currently only provided for components-based interactions.
---@field member Member? The member who interacted with the application in a guild.
---@field user User? The User object of who interacted with the application, should always be available..
---@field data table The raw data of the interaction. See [Interaction Data Structure](https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-object-resolved-data-structure).
---@field token string The interaction token. What allows you to responds to a specific interaction. This is a secret and shouldn't be exposed, if leaked anyone can send messages on behalf of your bot.
---@field version string The interaction version. (Currently not useful at all)
---@field locale string The locale settings of the user who executed this interaction.
---@field guildLocale string The guild's preferred locale, if said interaction was executed in a guild.
---<!method-tags:http>
---@type Interaction | fun(data: table, parent: Client): Interaction
local Interaction, get = class("Interaction", Snowflake)

---@type table
local getter = get

function Interaction:__init(data, parent)
  Snowflake.__init(self, data, parent)
  self._api = parent._api -- a bit easier to navigate
  self._data = data.data

  -- Handle guild and guild_id
  do local guildId = data.guild_id
    self._guild = guildId and parent._guilds:get(guildId)
    if not self._guild and guildId then
      local guild = self._api:getGuild(guildId)
      if guild then
        self._guild = parent._guilds:_insert(guild)
      end
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
    elseif data.user then
      self._user = parent._users:_insert(data.user)
    end
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
    if not self._message then self._message = nil end
    ::skip::
  end

  -- Define Interaction state tracking
  self._initialRes = false
  self._deferred = false
end

function Interaction:_sendMessage(payload, files, deferred)
  local data, err = self._api:createInteractionResponse(self.id, self._token, {
    type = deferred and callbackType.deferredChannelMessage or callbackType.channelMessage,
    data = payload,
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

---Sends an interaction reply. An initial response is sent on first call of this,
---if an initial response was already sent a followup message is sent instead.
---If initial response was a deferred response, calling this will properly edit the deferred message.
---
---Returns may not be consistent because blame Discord.
---On initial response, expect this to return a boolean value representing success otherwise `false, err`.
---To get the sent reply in that case use `Interaction:getReply()`.
---On followups and edits, this will return the sent/edited message, otherwise `false, err`.
---@param content string|table
---@param isEphemeral? boolean
---@return boolean|Message
function Interaction:reply(content, isEphemeral)
  isEphemeral = isEphemeral and true or type(content) == "table" and content.ephemeral
  local msg, files = resolveMessage(content)

  -- Handle flag masking
  if isEphemeral then
    msg.flags = bor(type(msg.flags) == "number" and msg.flags or 0, messageFlag.ephemeral)
  end

  -- Choose desired method depending on the context
  local method
  if self._initialRes or self._deferred then
    method = self._sendFollowup
  else
    method = self._sendMessage
  end
  return method(self, msg, files)
end

---Sends a deferred interaction reply.
---Deferred replies can only be sent as initial responses.
---A deferred reply displays "Bot is thinking..." to users, and once `:reply` is called again, deferred message will be edited.
---
---Returns `true` on success, otherwise `false, err`.
---@param isEphemeral? boolean
---@return boolean
function Interaction:replyDeferred(isEphemeral)
  assert(not self._initialRes, "only the initial response can be deferred")
  local msg = isEphemeral and {flags = messageFlag.ephemeral} or nil
  return self:_sendMessage(msg, nil, true)
end

---@alias Message-ID-Resolvable table

---Fetches a previously sent interaction response.
---If response `id` was not provided, the original interaction response is fetched instead.
---
---Note: **Ephemeral messages cannot be retrieved once sent.**
---@param id? Message-ID-Resolvable
---@return Message
function Interaction:getReply(id)
  id = resolver.messageId(id) or "@original"
  local data, err = self._api:getWebhookMessage(self._application_id, self._token, id)
  return data and self._channel._messages:_insert(data), err
end

---Modifies a previously sent interaction response.
---If response `id` was not provided, initial interaction response is edited instead.
---
---Note: **Ephemeral messages cannot be modified once sent.**
---@param content table|string
---@param id? Message-ID-Resolvable
---@return Message
function Interaction:editReply(content, id)
  id = resolver.messageId(id) or self._message.id
  local msg, files = resolveMessage(content)
  local data, err = self._api:editWebhookMessage(self._application_id, self._token, id, msg, files)
  return data and true, err
end

---Deletes a previously sent response. If response `id` was not provided, original interaction response is deleted instead.
---
---Returns `true` on success, otherwise `false, err`.
---
---Note: **Ephemeral messages cannot be deleted once sent.**
---@param id? Message-ID-Resolvable
---@return boolean
function Interaction:deleteReply(id)
  id = resolver.messageId(id) or "@original"
  local data, err = self._api:deleteWebhookMessage(self._application_id, self._token, id)
  return data and true, err
end

function Interaction:_sendUpdate(payload, files)
  local data, err = self._api:createInteractionResponse(self.id, self._token, {
    type = payload and callbackType.updateMessage or callbackType.deferredUpdateMessage,
    data = payload,
  }, files)
  if data then
    self._initialRes = true
    self._deferred = not payload and true
    return true
  else
    return false, err
  end
end

---Responds to a component-based interaction by editing the message that the component is attached to.
---
---Returns `true` on success, otherwise `false, err`.
---@param content table|string
---@return boolean
function Interaction:update(content)
  local t = type(content)
  assert(self._message, "UPDATE_MESSAGE is only supported by components-based interactions!")
  assert(t == "string" or t == "table", "bad argument #2 to update (expected table|string)")
  local msg, files = resolveMessage(content)
  if not self._initialRes then
    return self:_sendUpdate(msg, files)
  end
  local data, err = self._api:editMessage(self._message._parent._id, self._message._id, msg, files)
  if data then
    self._message:_setOldContent(data)
    self._message:_load(data)
    return true
  end
  return false, err
end

---Responds to a component-based interaction by acknowledging the interaction.
---Once `update` is called, the components message will be edited.
---
---Returns `true` on success, otherwise `false, err`.
---@return boolean
function Interaction:updateDeferred()
  assert(self._message, "DEFERRED_UPDATE_MESSAGE is only supported by components-based interactions!")
  assert(not self._initialRes, "only the initial response can be deferred")
  return self:_sendUpdate()
end

---Responds to an autocomplete interaction.
---`choices` is either a table that has `name` and `value` fields, or an array of said tables.
---For example: `{{name = "choice#1", value = "val1"}, {name = "choice#2", value = "val2"}}`.
---
---Returns `true` on success, otherwise `false, err`.
---@param choices table
---@return boolean
function Interaction:autocomplete(choices)
  assert(self._type == intrType.applicationCommandAutocomplete, "APPLICATION_COMMAND_AUTOCOMPLETE is only supported by application-based commands!")
  choices = resolver.autocomplete(choices)
  assert(type(choices) == "table", 'bad argument #1 to autocomplete (expected table)')
  if choices.name and choices.value then
    choices = {choices}
  end
  assert(#choices < 26, 'choices must not exceeds 25 choice')
  local data, err = self._api:createInteractionResponse(self.id, self._token, {
    type = callbackType.applicationCommandAutocompleteResult,
    data = {
      choices = choices,
    },
  })
  if data then
    return true
  else
    return false, err
  end
end

function Interaction:_sendModal(payload)
  local data, err = self._api:createInteractionResponse(self.id, self._token, {
    type = callbackType.modal,
    data = payload,
  })
  if data then
    return true
  else
    return false, err
  end
end

function Interaction:modal(modal)
  modal = resolver.modal(modal)
  return self:_sendModal(modal)
end

function getter:applicationId()
  return self._application_id
end

function getter:type()
  return self._type
end

function getter:guildId()
  return self._guild_id
end

function getter:guild()
  return self._guild
end

function getter:channelId()
  return self._channel_id
end

function getter:channel()
  return self._channel
end

function getter:message()
  return self._message
end

function getter:member()
  return self._member
end

function getter:user()
  return self._user
end

function getter:data()
  return self._data
end

function getter:token()
  return self._token
end

function getter:version()
  return self._version
end

function getter:locale()
  return self._locale
end

function getter:guildLocale()
  return self._guild_locale
end

return Interaction
