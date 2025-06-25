--[[
  Copyright 2021-2024 Bilal2453

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]]

local discordia = require("discordia")
local resolver = require("client/resolver")
local enums = require("enums")
local bit = require("bit")

local bor = bit.bor
local class = discordia.class
local classes = class.classes
local intrType = enums.interactionType
local messageFlag = assert(enums.messageFlag)
local resolveMessage = resolver.message
local callbackType = enums.interactionCallbackType
local channelType = discordia.enums.channelType

local Snowflake = classes.Snowflake
local Permissions = discordia.Permissions

---Represents a [Discord Interaction](https://discord.com/developers/docs/interactions/receiving-and-responding#interactions)
---allowing you to receive and respond to user interactions.
---
---Note that on `interactionCreate` event Discord sends *partial* Guild/Channel/Member objects,
---that means, any object obtained with the Interaction may or may not have specific properties set.
---@class Interaction: Snowflake
---@field applicationId string The application's unique snowflake ID.
---@field type number The Interaction's type, see `enums.interactionType`.
---@field guildId string? The Snowflake ID of the guild the interaction was sent from, if any.
---@field guild Guild? The Guild object the interaction was sent from. Equivalent to `Client:getGuild(Interaction.guildId)`.
---@field channelId string The Snowflake ID of the channel the interaction was sent from. Should always be provided, but keep in mind Discord flags it as optional for future-proofing.
---@field channel Channel? The Channel object the interaction was sent from. Equivalent to `Client:getChannel(Interaction.channelId)`. Can be `GuildTextChannel`, `GuildVoiceChannel` or `PrivateChannel`.
---@field message Message? The message the components that invoked this interaction are attached to. Only provided for components-based interactions.
---@field member Member? The member who invoked this interaction, if it was invoked in the context of a guild.
---@field user User? The user that invoked this interaction, should be always available but always check.
---@field data table The raw data of the interaction. See [Interaction Data Structure](https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-object-resolved-data-structure). Should be always available but Discord may not provide it in the future for some scenarios.
---@field token string The interaction token. This is a secret and shouldn't be exposed, if leaked anyone can send messages on behalf of your bot.
---@field version string The interaction version, currently this is always set to `1`.
---@field appPermissions Permissions The permissions the app has in the source location of the interaction.
---@field locale string? The locale settings of the user who executed this interaction, see [languages](https://discord.com/developers/docs/reference#locales) for list of possible values. Always available except on PING interactions.
---@field guildLocale string The guild's preferred locale, if the interaction was executed in a guild, see [languages](https://discord.com/developers/docs/reference#locales) for list of possible values.
---@field entitlements table An array of raw [Entitlement](https://discord.com/developers/docs/resources/entitlement#entitlement-object) objects for monetized apps the user that invoked this interaction has.
---@field integrationOwners table Mapping of installation contexts that the interaction was authorized for to related user or guild IDs. See [Authorizing Integration Owners Object](https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-object-authorizing-integration-owners-object) for details
---@field context number? The context in which this interaction was invoked, see `enums.interactionContextType`.
---<!method-tags:http>
---@type Interaction | fun(data: table, parent: Client): Interaction
local Interaction, get = class("Interaction", Snowflake)

---@type table
local getter = get

---@param data table
---@param parent Client
---@protected
---<!ignore>
function Interaction:__init(data, parent)
  Snowflake.__init(self, data, parent)
  self._data = data.data
  self._initialRes = false -- have we sent a response yet?
  self._deferred = false -- is the response we sent (if we have) deferred?
  self:_loadMore(data)
end

---@protected
function Interaction:_load(data)
  Snowflake._load(self, data)
  return self:_loadMore(data)
end

---@protected
function Interaction:_loadMore(data)
  self:_loadGuild(data)
  self:_loadChannel(data)
  self:_loadMember(data)
  self:_loadMessage(data)
  self._entitlements = data.entitlements
  self._authorizing_integration_owners = data.authorizing_integration_owners
end

---@protected
function Interaction:_loadGuild(data)
  if not data.guild_id then
    return
  end
  -- retrieve guild from cache if possible
  self._guild = self.parent:getGuild(data.guild_id)
  if self._guild then
    return
  end
  -- use the partial object
  if data.guild then
    local guild = data.guild
    -- required fields for initialization
    guild.stickers = guild.stickers or {}
    guild.emojis = guild.emojis or {}
    guild.roles = guild.roles or {}
    -- create and cache the partial guild
    self._guild = self.parent._guilds:_insert(guild)
    self._guild._partial = true
  end
end

local function insertChannel(client, data, parent)
  if data.guild_id and parent then
    if data.type == channelType.text or data.type == channelType.news then
      return parent._text_channels:_insert(data)
    elseif data.type == channelType.voice then
      return parent._voice_channels:_insert(data)
    elseif data.type == channelType.category then
      return parent._categories:_insert(data)
    end
  elseif data.type == channelType.private then
    return client._private_channels:_insert(data)
  elseif data.type == channelType.group then
    return client._group_channels:_insert(data)
  end
end

---@protected
function Interaction:_loadChannel(data)
  local channelId = data.channel_id
  if not channelId then
    return
  end
  -- first try retrieving it from cache
  self._channel = self.parent:getChannel(channelId)
  if self._channel then
    return
  end
  -- otherwise, use the partial channel object
  if data.channel then
    data.channel.permission_overwrites = {}
    self._channel = insertChannel(self.parent, data.channel, self._guild)
  end
end

---@protected
function Interaction:_loadMember(data)
  if data.member and self._guild then
    self._member = self._guild._members:_insert(data.member)
    self._user = self.parent._users:_insert(data.member.user)
  elseif data.user then
    self._user = self.parent._users:_insert(data.user)
  end
end

---@protected
function Interaction:_loadMessage(data)
  if not data.message or not self._channel then
    return
  end
  self._message = self._channel._messages:_insert(data.message)
end

---@protected
---@return (Message|boolean)?, string? err
function Interaction:_sendMessage(payload, files, deferred)
  local data, err = self.parent._api:createInteractionResponse(self.id, self._token, {
    type = deferred and callbackType.deferredChannelMessage or callbackType.channelMessage,
    data = payload,
  }, files)
  if data then
    self._initialRes = true
    self._deferred = deferred or false
    if self._channel and self._channel._messages then
      return self._channel._messages:_insert(data.resource.message)
    else
      return true
    end
  else
    return nil, err
  end
end

---@protected
---@return (Message|boolean)?, string? err
function Interaction:_sendFollowup(payload, files)
  local data, err = self.parent._api:createWebhookMessage(self._application_id, self._token, payload, files)
  if data then
    if self._channel then
      return self._channel._messages:_insert(data)
    else
      return true
    end
  else
    return nil, err
  end
end

---Sends an interaction reply. An initial response is sent on the first call,
---if an initial response has already been sent a followup message is sent instead.
---If the initial response was a deferred response, calling this will edit the deferred message.
---
---Returns Message on success, otherwise `nil, err`.
---If `Interaction.channel` was not available, `true` will be returned instead of Message.
---@param content string|table
---@param isEphemeral? boolean
---@return Message|boolean
function Interaction:reply(content, isEphemeral)
  isEphemeral = isEphemeral and true or type(content) == "table" and content.ephemeral
  local msg, files = resolveMessage(content)
  if not msg then
    return nil, files
  end
  -- handle flag masking
  if isEphemeral then
    msg.flags = bor(type(msg.flags) == "number" and msg.flags or 0, messageFlag.ephemeral)
  end
  -- choose desired method depending on the context
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
---A deferred reply displays "Bot is thinking..." to users, and once `:reply` is called again, the deferred message will be edited.
---
---Returns Message on success, otherwise `nil, err`.
---If `Interaction.channel` was not available, `true` will be returned instead of Message.
---@param isEphemeral? boolean
---@return Message|boolean
function Interaction:replyDeferred(isEphemeral)
  assert(not self._initialRes, "only the initial response can be deferred")
  local msg = isEphemeral and {flags = messageFlag.ephemeral} or nil
  return self:_sendMessage(msg, nil, true)
end

---Fetches a previously sent interaction response.
---If `id` was not provided, the original interaction response is fetched instead.
---@param id? Message-ID-Resolvable
---@return Message
function Interaction:getReply(id)
  id = resolver.messageId(id) or "@original"
  local data, err = self.parent._api:getWebhookMessage(self._application_id, self._token, id)
  if data then
    return self._channel._messages:_insert(data)
  else
    return nil, err
  end
end

---Modifies a previously sent interaction response.
---If `id` was not provided, the initial interaction response is edited instead.
---@param content table|string
---@param id? Message-ID-Resolvable
---@return boolean
function Interaction:editReply(content, id)
  id = resolver.messageId(id) or "@original"
  local msg, files = resolveMessage(content)
  local data, err = self.parent._api:editWebhookMessage(self._application_id, self._token, id, msg, files)
  if data then
    return true
  else
    return false, err
  end
end

---Deletes a previously sent response. If response `id` was not provided, original interaction response is deleted instead.
---If `id` was not provided, the initial interaction response is deleted instead.
---
---Returns `true` on success, otherwise `false, err`.
---@param id? Message-ID-Resolvable
---@return boolean
function Interaction:deleteReply(id)
  id = resolver.messageId(id) or "@original"
  local data, err = self.parent._api:deleteWebhookMessage(self._application_id, self._token, id)
  if data then
    return true
  else
    return false, err
  end
end

function Interaction:_sendUpdate(payload, files)
  local data, err = self.parent._api:createInteractionResponse(self.id, self._token, {
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
  assert(t == "string" or t == "table", "bad argument #2 to update (expected table|string, got " .. t .. ')')
  local msg, files = resolveMessage(content)
  if not self._initialRes then
    return self:_sendUpdate(msg, files)
  end
  local data, err = self.parent._api:editMessage(self._message._parent._id, self._message._id, msg, files)
  if data then
    self._message:_setOldContent(data)
    self._message:_load(data)
    return true
  else
    return false, err
  end
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
---`choices` is an array of tables with the fields `name` and `value`.
---For example: `{{name = "choice#1", value = "val1"}, {name = "choice#2", value = "val2"}}`.
---
---See [option choice structure](https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-option-choice-structure) for more information on how to set a locale.
---
---Returns `true` on success, otherwise `false, err`.
---@param choices table
---@return boolean
function Interaction:autocomplete(choices)
  assert(self._type == intrType.applicationCommandAutocomplete, "APPLICATION_COMMAND_AUTOCOMPLETE is only supported by application-based commands!")
  choices = resolver.autocomplete(choices) ---@diagnostic disable-line: cast-local-type
  assert(choices, "bad argument #1 to autocomplete (expected table, got " .. type(choices) .. ')')
  assert(#choices <= 25, "choices must not exceed 25")
  local data, err = self.parent._api:createInteractionResponse(self.id, self._token, {
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
  local data, err = self.parent._api:createInteractionResponse(self.id, self._token, {
    type = callbackType.modal,
    data = payload,
  })
  if data then
    return true
  else
    return false, err
  end
end

---Responds to an interaction by opening a Modal, also known as Text Inputs.
---By default this method takes the [raw structure](https://discord.com/developers/docs/interactions/message-components#text-inputs) defined by Discord
---but other extensions may also provide their own abstraction, see for example [discordia-modals](https://github.com/Bilal2453/discordia-modals/wiki/Modal).
---
---Returns `true` on success, otherwise `false, err`.
---@param modal table
---@return boolean
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

function getter:appPermissions()
  return Permissions(self._app_permissions)
end

function getter:entitlements()
  return self._entitlements
end

function getter:integrationOwners()
  return self._authorizing_integration_owners
end

function getter:context()
  return self._context
end

return Interaction
