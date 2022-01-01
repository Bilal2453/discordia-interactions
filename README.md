# Introduction

discordia-interactions is a library that makes receiving [Discord Interactions](https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-type) over WebSocket connection possible in the Luvit Discord wrapper [Discordia 2](https://github.com/SinisterRectus/discordia), as well as providing the required methods to respond to the interaction. Although this library does not implement any specific feature such as Message Components or Slash Commands, it act as the base of supporting said features, for example, I've built [discordia-components](https://github.com/Bilal2453/discordia-components/) upon this library, which fully provide support for Message Components (such as buttons and select menus).

## Documentation

The library is documented at the [Wiki](https://github.com/Bilal2453/discordia-interactions/wiki), it is mostly complete but small details are still missing.

## Installing

Due to a bug in Lit, the Lit upstream version of this library won't install, you have to manually clone it.

1. Run `git clone https://github.com/Bilal2453/discordia-interactions.git`.
2. Make sure the cloned folder name is `discordia-interactions`.
3. Move the `discordia-interactions` folder to your project `deps` folder. 

# Examples

```lua
local discordia = require("discordia")
require("discordia-interactions") -- Modifies Discordia and adds interactionCreate event

local client = discordia.Client()
local intrType = discordia.enums.interactionType

client:on("interactionCreate", function(interaction)
  -- Ephemeral reply to an interaction
  interaction:reply("Hello There! This is ephemeral reply", true)
  -- Send a followup reply
  interaction:reply {
    -- send a file with interactions info
    file = { -- identical to the Discordia field
      "info.txt",
      "Bot received an interaction of the type " .. intrType(interaction.type) .. " from the user " .. interaction.user.name
    },
    -- try to mention the user
    mention = interaction.member or interaction.user,
    -- suppress all mentions
    allowed_mentions = { -- if Discordia's send doesn't handle said field, library'll treat it as raw
      parse = {}
    }
  }
  if interaction.type == intrType.messageComponent then
    -- update the message the component was attached to
    interaction:update {
      embed = {
        title = "Wow! You have actually used the component!",
        color = 0x00ff00,
      }
    }
  end
end)

client:run("Bot TOKEN")
```
