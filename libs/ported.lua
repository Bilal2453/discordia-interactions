--[[
    This code is not injected into Discordia;
  It is identical to the one used in Discordia, only defined here for ease of access.
    Code below is copied from SinisterRectus/Discordia with minor modifications,
  All rights reserved for the original maintainer.
--]]

local fs = require("fs")
local Resolver = require("client/Resolver")
local splitPath = require("pathjoin").splitPath

local function parseFile(obj, files)
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

local function parseMention(obj, mentions)
  if type(obj) == "table" and obj.mentionString then
    mentions = mentions or {}
    table.insert(mentions, obj.mentionString)
  else
    return nil, "Unmentionable object: " .. tostring(obj)
  end
  return mentions
end

local blacklisted_fields = {
  content = true, code = true, mention = true,
  mentions = true, file = true, files = true,
  reference = true, payload_json = true,
}

local function parseMessage(content)
  local err
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
      mentions, err = parseMention(tbl.mention)
      if err then
        return nil, err
      end
    end
    if type(tbl.mentions) == "table" then
      for _, mention in ipairs(tbl.mentions) do
        mentions, err = parseMention(mention, mentions)
        if err then
          return nil, err
        end
      end
    end

    if mentions then
      table.insert(mentions, content)
      content = table.concat(mentions, ' ')
    end

    local files
    if tbl.file then
      files, err = parseFile(tbl.file)
      if err then
        return nil, err
      end
    end
    if type(tbl.files) == "table" then
      for _, file in ipairs(tbl.files) do
        files, err = parseFile(file, files)
        if err then
          return nil, err
        end
      end
    end

    local refMessage, refMention
    if tbl.reference then
      refMessage = {message_id = Resolver.messageId(tbl.reference.message)}
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
      if not blacklisted_fields[k] then
        result[k] = v
      end
    end

    return result, files
  else
    return {content = content}
  end
end

return {
  parseMessage = parseMessage,
}
