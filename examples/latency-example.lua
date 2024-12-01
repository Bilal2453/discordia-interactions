--[[
  Usage: send `!new-button` command to get a message with components.

  Pressing the buttons will do stuff!
]]

local timer = require 'timer'
local discordia = require 'discordia'
require 'discordia-interactions'

local client = discordia.Client()
client:enableIntents('messageContent')

local Stopwatch = discordia.Stopwatch

client:on('messageCreate', function (msg)
  -- Use discordia-extensions instead of this!
  -- this is just to get the example working
  if msg.content == '!new-button' then
    client._api:createMessage(msg.channel.id, {
      content = 'Here is a button!',
      components = {
        {
          type = 1,
          components = {
            {
              type = 2,
              label = 'API Ping',
              style = 1,
              custom_id = 'api_ping',
            },
            {
              type = 2,
              label = 'API Ping Message',
              style = 3,
              custom_id = 'api_ping_msg',
            },
          },
        },
      }
    })
  end
end)

---@param intr Interaction
client:on('interactionCreate', function (intr)
  if intr.data.custom_id == 'api_ping' then
    local sw = Stopwatch()
    local msg, err = intr:replyDeferred(true)
    sw:stop()
    if not msg then
      return print(err)
    end
    intr:reply('The API latency (one-way) is ' .. (sw:getTime() / 2):toString())
    timer.sleep(3000)
    intr:deleteReply()
  elseif intr.data.custom_id == 'api_ping_msg' then
    local sw = Stopwatch()
    local msg, err = intr:reply('Calculating latency...')
    sw:stop()
    if not msg then
      return print(err)
    end
    intr:editReply('The API latency (one-way) is ' .. (sw:getTime() / 2):toString())
    timer.sleep(3000)
    intr:deleteReply()
  end
end)

client:run('Bot TOKEN')
