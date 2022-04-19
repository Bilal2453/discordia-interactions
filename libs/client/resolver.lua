--[[
	The code in this file is not injected into Discordia.
	It is only used internally in this library.

	Code below is taken from original Discordia source code and modified to work
	for our usecase. This file is licensed under the Apache License 2.0.
--]]

--[[
													Apache License 2.0

	Copyright (c) 2016-2022 SinisterRectus (Original author of Discordia)
	Copyright (c) 2021-2022 Bilal2453 (Modified message resolver to support raw fields)

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

local fs = require("fs")
local ffi = require("ffi")
local splitPath = require("pathjoin").splitPath

local istype = ffi.istype
local int64_t = ffi.typeof('int64_t')
local uint64_t = ffi.typeof('uint64_t')
local resolver = {}

local function int(obj)
	local t = type(obj)
	if t == 'string' then
		if tonumber(obj) then
			return obj
		end
	elseif t == 'cdata' then
		if istype(int64_t, obj) or istype(uint64_t, obj) then
			return tostring(obj):match('%d*')
		end
	elseif t == 'number' then
		return string.format('%i', obj)
  end
end

function resolver.messageId(obj)
	if type(obj) == "table" and obj.__name == "Message" then
		return obj.id
	end
	return int(obj)
end

function resolver.file(obj, files)
  local obj_type = type(obj)
  if obj_type == "string" then
    local data, err = fs.readFileSync(obj)
    if not data then
      return nil, err
    end
    files = files or {}
    table.insert(files, {table.remove(splitPath(obj)), data})
  elseif obj_type == "table" and type(obj[1]) == "string" and type(obj[2]) == "string" then
    files = files or {}
    table.insert(files, obj)
  else
    return nil, "Invalid file object: " .. tostring(obj)
  end
  return files
end

function resolver.mention(obj, mentions)
  if type(obj) == "table" and obj.mentionString then
    mentions = mentions or {}
    table.insert(mentions, obj.mentionString)
  else
    return nil, "Unmentionable object: " .. tostring(obj)
  end
  return mentions
end

local message_blacklisted_fields = {
  content = true, code = true, mention = true,
  mentions = true, file = true, files = true,
  reference = true, payload_json = true, embed = true,
}

resolver.message_resolvers = {}
resolver.message_wrappers = {}

function resolver.message(content)
  local err
  for _, v in pairs(resolver.message_resolvers) do
    local c = v(content)
    if c then
      content = c
      break
    end
  end
  if type(content) == "table" then
    ---@type table
    local tbl = content
    content = tbl.content

    if type(tbl.code) == "string" then
      content = string.format("```%s\n%s\n```", tbl.code, content)
    elseif tbl.code == true then
      content = string.format("```\n%s\n```", content)
    end

    local mentions
    if tbl.mention then
      mentions, err = resolver.mention(tbl.mention)
      if err then
        return nil, err
      end
    end
    if type(tbl.mentions) == "table" then
      for _, mention in ipairs(tbl.mentions) do
        mentions, err = mention(mention, mentions)
        if err then
          return nil, err
        end
      end
    end

    if mentions then
      table.insert(mentions, content)
      content = table.concat(mentions, ' ')
    end

    if tbl.embed then
      if type(tbl.embeds) == 'table' then
        tbl.embeds[#tbl.embeds + 1] = tbl.embed
      elseif tbl.embeds == nil then
        tbl.embeds = {tbl.embed}
      end
    end

    local files
    if tbl.file then
      files, err = resolver.file(tbl.file)
      if err then
        return nil, err
      end
    end
    if type(tbl.files) == "table" then
      for _, file in ipairs(tbl.files) do
        files, err = resolver.file(file, files)
        if err then
          return nil, err
        end
      end
    end

    local refMessage, refMention
    if tbl.reference then
      refMessage = {message_id = resolver.messageId(tbl.reference.message)}
      refMention = {
        parse = {"users", "roles", "everyone"},
        replied_user = not not tbl.reference.mention,
      }
    end

    local result = {
      content = content,
      message_reference = tbl.message_reference or refMessage,
      allowed_mentions = tbl.allowed_mentions or refMention,
    }
    for k, v in pairs(tbl) do
      if not message_blacklisted_fields[k] then
        result[k] = v
      end
    end

    for _, v in pairs(resolver.message_wrappers) do
      v(result, files)
    end

    return result, files
  else
    return {content = content}
  end
end

resolver.autocomplete_resolvers = {}
resolver.autocomplete_wrappers = {}

function resolver.autocomplete(choices)
  for _, v in pairs(resolver.modal_resolvers) do
    local c = v(choices)
    if c then
      choices = c
      break
    end
  end
  if type(choices) ~= "table" then return end
  for _, v in pairs(resolver.modal_wrappers) do
    v(choices)
  end
  return choices
end

resolver.modal_resolvers = {}
resolver.modal_wrappers = {}

function resolver.modal(content)
  for _, v in pairs(resolver.modal_resolvers) do
    local c = v(content)
    if c then
      content = c
      break
    end
  end
  assert(type(content) == "table")
  for _, v in pairs(resolver.modal_wrappers) do
    v(content)
  end
  return content
end

return resolver
