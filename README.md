> Extension to support receiving and responding to Discord interactions over WS.

This is still unreleased and WIP. Do expect breaking changes in the future.

# Examples

```lua
local discordia = require("discordia")
require("discordia-interactions") -- Patches Discordia and adds an event

local client = discordia.Client()
client:on("interactionCreate", function(interaction)
  interaction:reply("Hello World! this is ephemeral reply!", true)
end)

client:run("Bot TOKEN")
```
