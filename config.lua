CUSTOM_SEPGP_UKNOWN_GUILD_NAME = "CUSTOM_SEPGP_UKNOWN_GUILD_NAME";

sepgp_config = {
  -- Who can edit table; Кто может редактировать таблицу.
  canEditDB = {
    ["CKAZKA"] = {
      -- if guild rank equal "Warlord"; Если звание в гильдии равно "Warlord"
      { rank = "Warlord" }, 
    },
    ["Going to Death"] = {
      { name = "Andrgitdruid" },
    },
    [CUSTOM_SEPGP_UKNOWN_GUILD_NAME] = {
      { name = "Andrgitlock" },
      { name = "Invpartthree" },
    },
  },

  -- Who can edit settings addon and edit table; Кто может вносить изменения в аддон и изменять таблицу.
  canChangeAll = {
    ["CKAZKA"] = {
      -- if guild rank equal "Warlord"; Если звание в гильдии равно "Warlord"
      { rank = "Warlord" },
    },
    ["Going to Death"] = {
      { name = "Andrgitdruid" },
    },
    [CUSTOM_SEPGP_UKNOWN_GUILD_NAME] = {
      { name = "Andrgitlock" },
      { name = "Invpartthree" },
    },
  },
};