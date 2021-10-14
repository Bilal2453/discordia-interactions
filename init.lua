--[[
  Copyright 2021 Bilal2453

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

-- Patch Discordia's event handler to include Interactions listening
do
  local client = discordia.Client() -- tmp client object to easily patch some properties
  local events = client._events
  for k, v in pairs(EventHandler) do
    events[k] = v
  end
end

-- Patch Discordia's enums to include interaction types
do
  local discordiaEnums = discordia.enums
  local enum = discordiaEnums.enum
  for k, v in pairs(enums) do
    discordiaEnums[k] = enum(v)
  end
end

-- Patch Discordia's API wrapper to include some missing endpoints
do
  local api = discordia.class.classes.API
  API.request = api.request
  for k, v in pairs(API) do
    rawset(api, k, v)
  end
end
