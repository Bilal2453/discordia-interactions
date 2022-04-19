--[[
                          Apache License 2.0

   Copyright (c) 2022 Bilal2453

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
local EventHandler = require("client/EventHandler")
local enums = require("enums")
local API = require("client/API")

-- Patch Discordia's enums to include some of the missing fields
do
  local discordia_enums = discordia.enums
  local enum = discordia_enums.enum
  for k, v in pairs(enums) do
    if not discordia_enums[k] then -- compatibility with other extensions provided enums
      discordia_enums[k] = enum(v)
    else
      local new_enum = v
      for n, m in pairs(discordia_enums[k]) do
        if not new_enum[n] then
          new_enum[n] = m
        end
      end
      discordia_enums[k] = enum(new_enum)
    end
  end
end

-- Patch Discordia's API wrapper to include some of the missing endpoints
-- Do note, one major patch (that should affect nothing) is of API.editMessage, was patched to include files support.
do
  local discordia_api = discordia.class.classes.API
  API.request = discordia_api.request
  for k, v in pairs(API) do
    rawset(discordia_api, k, v)
  end
end

-- Patch Discordia's event handler to add interactionCreate event
do
  local client = discordia.Client { -- tmp client object to quickly patch events
    logFile = '', -- do not create a log file
  }
  local events = client._events
  for k, v in pairs(EventHandler) do
    if rawget(events, k) then -- compatiblity with other libraries
      local old_event = events[k]
      events[k] = function(...)
        v(...)
        return old_event(...)
      end
    else
      events[k] = v
    end
  end
end

return {
  EventHandler = EventHandler,
  Interaction = require("containers/Interaction"),
  resolver = require("client/resolver"),
}
