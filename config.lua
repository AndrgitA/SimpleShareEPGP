CUSTOM_SEPGP_UKNOWN_GUILD_NAME = "CUSTOM_SEPGP_UKNOWN_GUILD_NAME";

sepgp_config = {
  -- Who can edit table; Кто может редактировать таблицу.
  -- isAdmin
  canEditDB = {
    [CUSTOM_SEPGP_UKNOWN_GUILD_NAME] = {
    },
  },

  -- Who can edit settings addon and edit table; Кто может вносить изменения в аддон и изменять таблицу.
  -- isRoot
  canChangeAll = {
    [CUSTOM_SEPGP_UKNOWN_GUILD_NAME] = {
    },
  },
};

--[[
  For Example

  {
    [id] = {price, "T3.5"},
  
    Or
  
    [id] = {price},
  }
]]
sepgp_custom_prices = {

};