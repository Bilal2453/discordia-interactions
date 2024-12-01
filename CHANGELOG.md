# Changelog

## 2.0.0

- More stable returns on `Interaction.reply` initial replies. (Commit 2b559fa)
- Add `interactionContextType` and `applicationIntegrationType` enumerators. (Commit 2b559fa)
- Add new getters: `appPermissions`, `entitlements`, `context` and `integrationOwners`. (Commits 2b559fa, 696b70d)
- Add a post-listener for `interactionCreate`, at `discordia_interactions.EventHandler.interaction_create_postlisteners`. (Commit 048c30b)
- **Breaking Change**: Partial objects are now used for `Guild`, `Channel` and `Member`, no fetching is done behind the scene anymore. (Commits 5a9180e, 696b70d)
- **Breaking Change**: `Interaction.replyDeferred` may now return a Message when `self.channel` is available. (Commit 2b559fa)
- **Breaking Change**: Remove the support for a non-array input to `Interaction.autocomplete`. (Commit 2b559fa)
- Fix `Interaction.editReply` when ID is not provided. (Commit 2b559fa)
- Fix the autocomplete resolver using the wrong wrapper table.

## 1.2.1

- Add support for interactions invoked in `GuildVoiceChannel` instances. (Commit 8832674)
- Fix fetching issue on Guild caches. (Commit 8832674)
- Fix attempts to index nil `self._channel` property. (Commit a9be099)
- Fix `self._message` being `false` instead of `nil` on fetching failure. (Commit d0f95f5)
- Fix inserting a nil Guild instance into cache when fetching fails. (Commit bfd410e)
- Fix message flags being ignored if it had some flags already set. (Commit af32efc)

## 1.1.0

- Add pre-listeners to EventHandler, allowing other extension authors to interact with the library.
- Add an assert instead of returning nil when resolving.
- Add the ability to wrap resolvers by other extensions to allow further user input.
- Add support for modal responses.
- Expose our internal EventHandler instance.
