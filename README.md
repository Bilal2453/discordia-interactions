# Introduction

discordia-interactions is an extension library that enables [Discordia](https://github.com/SinisterRectus/discordia) to receive and respond to [Discord Interactions](https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-type).
This is done over the gateway websocket connection [Discordia](https://github.com/SinisterRectus/discordia) offers, and aims to be very extensible so other extensions and libraries can build upon without having to worry about compatibility with each other.

This only implements the interactions portion, for App commands such as Message Components or Slash Commands you need to use a second extension library alongside this one, for example [discordia-components](https://github.com/Bilal2453/discordia-components/) adds support for Message Components such as buttons and select menus.

## Supported responses

- [x] Text Replies.
- [x] Deferred Text Replies.
- [x] Update Replies.
- [x] Autocomplete Replies.
- [x] Modal Replies.
- [ ] Premium Required Replies. (deprecated by Discord)
- [ ] Launch Activity Replies.

## Installing

Due to a bug in Lit, the Lit upstream version of this library won't install, you have to manually clone it.

1. Run `cd PATH` replace `PATH` with your bot's directory path.
2. Run `git clone https://github.com/Bilal2453/discordia-interactions.git ./deps/discordia-interactions`.
3. Make sure you now have a folder `discordia-interactions` in your `deps` directory after running the last command.

## Documentation

The library is fully documented over at the [Wiki](https://github.com/Bilal2453/discordia-interactions/wiki), for any questions and support feel free to contact me on our [Discordia server](https://discord.gg/sinisterware), especially if you are writing a library using this!

## Building other extensions

This library offers multiple wrapping stages for other libraries to integrate with, allowing you to control the data flow and hook at different stages. For example I built a little Slash command library for the [Discordia Wiki bot](https://github.com/Bilal2453/discordia-wiki-bot), and [this is](https://github.com/Bilal2453/discordia-wiki-bot/blob/da42b124646bc718e17db89fac0c15456da4520f/libs/slash.lua#L140-L144) how it hooks into discordia-interactions to implement a new `slashCommand` event.
You can hook an `interactionCreate` event pre-listener, resolve user inputs to Interaction methods with your own resolver, or wrap resolved values.

## Examples

Here is a simple example that gets executed when you click a button or invoke the interaction in other means.

```lua
local discordia = require("discordia")
require("discordia-interactions") -- Adds the interactionCreate event and applies other patches

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

## Developers Notes

While it is not hard to merge this into Discordia, you are discouraged from doing that. From what I have noticed multiple people are merging this into the Discordia code instead of just using the extensions, and while they might have some reasons to do that, it will make life a lot harder for maintainability, for example when a new discordia-interactions release comes out it will become pretty much a manual job to hand pick the patches to apply, and it creates *more* incompatibility instead of solving any, this is *EXPLICITLY* an extension for good reasons, otherwise I could've simply PRed this into Discordia and called it a day, which is a lot easier to me than doing this.
