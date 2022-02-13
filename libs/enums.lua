local enums = {}

enums.interactionType = {
  ping                            = 1,
  applicationCommand              = 2,
  messageComponent                = 3,
  applicationCommandAutocomplete  = 4,
  modalSubmit                     = 5,
}

enums.interactionCallbackType = {
  pong                                  = 1,
  channelMessage                        = 4,
  deferredChannelMessage                = 5,
  deferredUpdateMessage                 = 6,
  updateMessage                         = 7,
  applicationCommandAutocompleteResult  = 8,
  modal                                 = 9,
}

enums.appCommandType = {
  chatInput = 1,
  user      = 2,
  message   = 3,
}

enums.appCommandOptionType = {
  subCommand      = 1,
  subCommandGroup = 2,
  string          = 3,
  integer         = 4,
  boolean         = 5,
  user            = 6,
  channel         = 7,
  role            = 8,
  mentionable     = 9,
  number          = 10,
  attachment      = 11,
}

enums.appCommandPermissionType = {
  role = 1,
  user = 2,
}

enums.componentType = {
  actionRow   = 1,
  button      = 2,
  selectMenu  = 3,
  textInput   = 4,
}

enums.messageFlag = {
  hasThread = 0x00000020,
  ephemeral = 0x00000040,
  loading   = 0x00000080,
}

return enums
