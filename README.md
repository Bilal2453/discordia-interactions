# Introduction

![Version](https://img.shields.io/github/v/release/Bilal2453/discordia-interactions)
![License](https://img.shields.io/github/license/Bilal2453/discordia-interactions)

discordia-interactions is an extension library that enables [Discordia](https://github.com/SinisterRectus/discordia) to receive and respond to [Discord Interactions](https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-type).
This is done over the gateway websocket connection that [Discordia](https://github.com/SinisterRectus/discordia) offers, and aims to be very extensible so other extensions and libraries can build upon without having to worry about compatibility with each other.

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

## Deprecation form Discordia

When using a library, you make a contract with that library, it's that what it documents is what it will do. In Discordia for example when the wiki says
that `Guild.memberCount` is never `nil`, then you can simply trust that and never check whether the property is nil or not, because Discordia guarantees that as part of the contract it made with you.

By using any third-party extension, said contract is automatically broken. (Note: So is modifying the library internally, the same arguments can be made against any method of modifying the library! not just extensions.)

One thing that Discord broke their promises with are Partial Objects. Partial objects are normal objects but with almost none of the required properties that Discordia promises you to always have, for example `Guild.memberCount` is `nil` because Discord does not send that on partial objects. It only sends the bare minimum that represents what a thing is, for example a partial Guild only has the guild ID and the supported features array.

discordia-interactions pre 2.0.0 version tried to keep the oauth Discordia makes with the user by selling its soul to the devil and transparently request the full objects from the API gateway instead of using the partial objects Discord sends, breaking one of the most important design philosophies of Discordia (that of never making additional HTTP requests in the background) but keeping away the complexity Discord introduced with partial objects from the end user.

Sadly, when Discord introduced User Installed Apps, this is no more possible to keep, because in that context *we cannot request objects from the API*, as they are pretty much kept a secret and only the minimum amount of information is provided, as such starting from version 2.0.0, the library breaks this contract and makes a new one with you: Any object obtained by an Interaction is partial and most likely *WILL NOT* have all of the properties set; if you want the full object request it from the API, or otherwise operate with those objects with caution.

The partial objects more specifically are `Guild`, `Channel` and `Member`. They are cached by Discordia, so iterating the Discordia cache might get you one of them, when the full version is given by Discord (if at all) then cached version is updated with the full one.
You may check if a Guild instance is partial by checking `Guild._partial` (you may only check Guild).

This change sadly adds complexity to the user, but it was absolutely required in order to support User Installed Apps and continue with the development.

## Examples

**Take a look at the [examples](https://github.com/Bilal2453/discordia-interactions/tree/main/examples) directory for the actual examples.**

Here is a bit of a usage run down:

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

While it is not hard to merge this extension into Discordia, you are discouraged from doing that. From what I have noticed multiple people are merging this into the Discordia code instead of just using the extensions, and while they might have some reasons to do that, it will make life a lot harder for maintainability, for example when a new discordia-interactions release comes out it will become pretty much a manual job to hand pick the patches to apply, and it creates *more* incompatibility instead of solving any, this is *EXPLICITLY* an extension for good reasons, otherwise I could've simply PRed this into Discordia and called it a day, which is a lot easier to me than developing an extension.

### License

This project is licensed under the Apache License 2.0, see [LICENSE] for more information.
Make sure to include the original copyright notice when copying!
