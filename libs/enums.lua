local enums = {}

enums.interactionType = {
  ping                = 1,
  applicationCommand  = 2,
  messageComponent    = 3,
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
}

enums.appCommandPermissionType = {
  role = 1,
  user = 2,
}

enums.componentType = {
  actionRow   = 1,
  button      = 2,
  selectMenu  = 3,
}

enums.buttonStyle = {
  primary   = 1,
  secondary = 2,
  success   = 3,
  danger    = 4,
  link      = 5,
}

enums.messageFlag = {
	crossposted           = 0x00000001,
	isCrosspost           = 0x00000002,
	suppressEmbeds        = 0x00000004,
	sourceMessageDeleted  = 0x00000008,
	urgent                = 0x00000010,
  hasThread             = 0x00000020,
  ephemeral             = 0x00000040,
  loading               = 0x00000080,
}

return enums
