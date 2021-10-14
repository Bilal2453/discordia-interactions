--[[
    This code is not injected into Discordia;
      It is identical to the one used in Discordia, only defined here for ease of access.
    Code below is copied from SinisterRectus/Discordia with small modifications,
      All rights reserved for the original maintainer.
--]]
local ffi = require("ffi")

local istype = ffi.istype
local int64_t = ffi.typeof('int64_t')
local uint64_t = ffi.typeof('uint64_t')
local Resolver = {}

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

function Resolver.messageId(obj)
	if type(obj) == "table" and obj.__name == "Message" then
		return obj.id
	end
	return int(obj)
end

return Resolver
