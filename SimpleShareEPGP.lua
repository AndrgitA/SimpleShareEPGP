SimpleShareEPGP = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceHook-2.1", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "FuBarPlugin-2.0")
SimpleShareEPGP:SetModuleMixins("AceDebug-2.0")
local D = AceLibrary("Dewdrop-2.0")
local BZ = AceLibrary("Babble-Zone-2.2")
local C = AceLibrary("Crayon-2.0")
local BC = AceLibrary("Babble-Class-2.2")
local DF = AceLibrary("Deformat-2.0")
local G = AceLibrary("Gratuity-2.0")
local T = AceLibrary("Tablet-2.0")
local L = AceLibrary("AceLocale-2.2"):new("shootyepgp")

local UnitName, GetRaidRosterInfo = UnitName, GetRaidRosterInfo;

SimpleShareEPGP.VARS = {
  basegp = 100,
  minep = 0,
  baseaward_ep = 100,
  decay = 0.9,
  max = 1000,
  maxloglines = 500,
  prefix = "SEPGP_ANDRGIT_MOD",
  bop = C:Red("BoP"),
  boe = C:Yellow("BoE"),
  nobind = C:White("NoBind"),
  msgp = "Mainspec GP",
  osgp = "Offspec GP",
  bankde = "Bank-D/E",
  reminder = C:Red("Unassigned"),
  undefinedClass = "UNDEFINED_CLASS",
  defaultSayChannel = "RAID",
  unknownGuildName = CUSTOM_SEPGP_UKNOWN_GUILD_NAME or "CUSTOM_SEPGP_UKNOWN_GUILD_NAME",
  minimalItemLootQualiti = 3,
}

SimpleShareEPGP._playerName = (UnitName("player"))
SimpleShareEPGP.isAdmin = false;
SimpleShareEPGP.isRoot = false;
SimpleShareEPGP.classNames = {
  Warlock = L["Warlock"],
  Warrior = L["Warrior"],
  Hunter = L["Hunter"],
  Mage = L["Mage"],
  Priest = L["Priest"],
  Druid = L["Druid"],
  Paladin = L["Paladin"],
  Shaman = L["Shaman"],
  Rogue = L["Rogue"],
};
SimpleShareEPGP.SUPER_WOW = true;

if (not GetPlayerBuffID or not CombatLogAdd or not SpellInfo or not ExportFile) then
  SimpleShareEPGP.SUPER_WOW = false;
end

SimpleShareEPGPConfig = {};
SimpleShareEPGPConfigDefault = {
  sayChannel = SimpleShareEPGP.VARS.defaultSayChannel,
  groupbyclass = false,
  groupbyarmor = false,
  groupbyrole = false,
  raidonly = false,
  debug = {},
};

SimpleSharedEPGPCharacterConfig = {};
SimpleSharedEPGPCharacterConfigDefault = {
  decay = SimpleShareEPGP.VARS.decay,
  minep = SimpleShareEPGP.VARS.minep,
  progress = "T1",
  discount = 0.25,
};

sepgp_table_db = {};

local out = "|cff9664c8shootyepgp:|r %s"
local raidStatus,lastRaidStatus
local lastUpdate = 0
local needInit,needRefresh = true
local shooty_debugchat
local running_check,running_bid
local partyUnit,raidUnit = {},{}
local hexColorQuality = {}
local bids_blacklist = {},{}
local bidlink = {
  ["ms"]=L["|cffFF3333|Hshootybid:1:$ML|h[Mainspec/NEED]|h|r"],
  ["os"]=L["|cff009900|Hshootybid:2:$ML|h[Offspec/GREED]|h|r"]
}
local options
do
  for i=1,40 do
    raidUnit[i] = "raid"..i
  end
  for i=1,4 do
    partyUnit[i] = "party"..i
  end
  for i=-1,6 do
    hexColorQuality[ITEM_QUALITY_COLORS[i].hex] = i
  end
end

--[[
  OPTIONS FOR ROOT

  Share Settings
]]
function SimpleShareEPGP.isRootUnit()
  --  temporary solution
  if (SimpleShareEPGP:lootMaster()) then
    return true;
  else 
    return false;
  end

  if (SimpleShareEPGP.isRoot) then
    return true;
  end

  if (not sepgp_config) then
    return false;
  end

  local canChangeAll = sepgp_config.canChangeAll;
  if (not canChangeAll) then
    return false;
  end

  local playerName = SimpleShareEPGP._playerName;
  local playerGuildName, playerGuildRankName, playerGuildRankIndex = GetGuildInfo("player");
  
  if (not playerGuildName) then
    playerGuildName = SimpleShareEPGP.VARS.unknownGuildName;
  end

  for gName, gData in pairs(canChangeAll) do
    if (gName == playerGuildName and type(gData) == "table") then
      for i = 1, table.getn(gData) do
        if (
          gData[i].rank == playerGuildName or
          gData[i].name == playerName
        ) then
          SimpleShareEPGP.isRoot = true;
          return true;
        end
      end
    end
  end

  return false;
end


--[[
  OPTIONS FOR ADMIN

  +EPs to Member
  +EPs to Raid
  +GPs to Member
  Add new member
  Remove member
  Set Class to Member
  Raid Only
  Reporting channel
  Decay EPGP
  Set Decay %
  Offspec Price %
  Set Minimum EP
  Reset EPGP

  Import
]]
function SimpleShareEPGP.isAdminUnit()
  --  temporary solution
  if (SimpleShareEPGP:lootMaster()) then
    return true;
  else 
    return false;
  end


  if (SimpleShareEPGP.isAdmin) then
    return true;
  end

  if (not sepgp_config) then
    return false;
  end

  local canEditDB = sepgp_config.canEditDB;
  if (not canEditDB) then
    return false;
  end

  local playerName = SimpleShareEPGP._playerName;
  local playerGuildName, playerGuildRankName, playerGuildRankIndex = GetGuildInfo("player");

  if (not playerGuildName) then
    playerGuildName = SimpleShareEPGP.VARS.unknownGuildName;
  end

  for gName, gData in pairs(canEditDB) do
    if (gName == playerGuildName and type(gData) == "table") then
      for i = 1, table.getn(gData) do
        if (
          gData[i].rank == playerGuildName or
          gData[i].name == playerName
        ) then
          SimpleShareEPGP.isAdmin = true;
          return true;
        end
      end
    end
  end

  return false;
end

local admincmd, membercmd = {
  type = "group",
  handler = SimpleShareEPGP,
  args = {
    bids = {
      type = "execute",
      name = L["Bids"],
      desc = L["Show Bids Table."],
      func = function()
        sepgp_bids:Toggle()
      end,
      order = 1,
    },
    show = {
      type = "execute",
      name = L["Standings"],
      desc = L["Show Standings Table."],
      func = function()
        sepgp_standings:Toggle()
      end,
      order = 2,
    },    
    clearloot = {
      type = "execute",
      name = L["ClearLoot"],
      desc = L["Clear Loot Table."],
      func = function()
        SimpleShareEPGP:ClearLoot();
      end,
      order = 3,
    },
    clearlogs = {
      type = "execute",
      name = L["ClearLogs"],
      desc = L["Clear Logs Table."],
      func = function()
        SimpleShareEPGP:ClearLogs();
      end,
      order = 4,
    },
    progress = {
      type = "execute",
      name = L["Progress"],
      desc = L["Print Progress Multiplier."],
      func = function()
        SimpleShareEPGP:defaultPrint(SimpleSharedEPGPCharacterConfig.progress);
      end,
      order = 5,
    },
    offspec = {
      type = "execute",
      name = L["Offspec"],
      desc = L["Print Offspec Price."],
      func = function()
        SimpleShareEPGP:defaultPrint(string.format("%s%%", SimpleSharedEPGPCharacterConfig.discount * 100));
      end,
      order = 6,
    },    
    restart = {
      type = "execute",
      name = L["Restart"],
      desc = L["Restart shootyepgp if having startup problems."],
      func = function() 
        SimpleShareEPGP:OnEnable()
        SimpleShareEPGP:defaultPrint(L["Restarted"])
      end,
      order = 7,
    },
    export_super_wow = {
      type = "execute",
      name = L["ExportFile (SuperWoW)"],
      desc = L["Export standings with SuperWoW function to csv"],
      func = function()
        sepgp_export_superwow();  
      end,
      order = 8,
    },
  }
},{
  type = "group",
  handler = SimpleShareEPGP,
  args = {
    -- show = {
    --   type = "execute",
    --   name = L["Standings"],
    --   desc = L["Show Standings Table."],
    --   func = function()
    --     sepgp_standings:Toggle()
    --   end,
    --   order = 1,
    -- },
    -- progress = {
    --   type = "execute",
    --   name = L["Progress"],
    --   desc = L["Print Progress Multiplier."],
    --   func = function()
    --     SimpleShareEPGP:defaultPrint(SimpleSharedEPGPCharacterConfig.progress);
    --   end,
    --   order = 2,
    -- },
    -- offspec = {
    --   type = "execute",
    --   name = L["Offspec"],
    --   desc = L["Print Offspec Price."],
    --   func = function()
    --     SimpleShareEPGP:defaultPrint(string.format("%s%%", SimpleSharedEPGPCharacterConfig.discount * 100));
    --   end,
    --   order = 3,
    -- },
    restart = {
      type = "execute",
      name = L["Restart"],
      desc = L["Restart shootyepgp if having startup problems."],
      func = function() 
        SimpleShareEPGP:OnEnable()
        SimpleShareEPGP:defaultPrint(L["Restarted"])
      end,
      order = 4,
    },    
  }}
  --[[{
    type = "execute",
    name = "Standings",
    desc = "Show Standings Table.",
    func = function()
      sepgp_standings:Toggle()
    end,
  }]]  
  SimpleShareEPGP.cmdtable = function() 
  if (SimpleShareEPGP.isAdminUnit()) then
    return admincmd
  else
    return membercmd
  end
end
SimpleShareEPGP.bids_main, SimpleShareEPGP.bids_off, SimpleShareEPGP.bid_item = {}, {}, {};
SimpleShareEPGP.timer = CreateFrame("Frame")
SimpleShareEPGP.timer.cd_text = ""
SimpleShareEPGP.timer:Hide()
SimpleShareEPGP.timer:SetScript("OnUpdate",function() SimpleShareEPGP.OnUpdate(this,arg1) end)
SimpleShareEPGP.timer:SetScript("OnEvent",function() 
end)

function SimpleShareEPGP:InitAddonVariables()
  if (not SimpleShareEPGPConfig) then
    SimpleShareEPGPConfig = {};
  end
  
  for i, v in pairs(SimpleShareEPGPConfigDefault) do
    if (SimpleShareEPGPConfig[i] == nil) then
      SimpleShareEPGPConfig[i] = v;
    end
  end

  if (not SimpleSharedEPGPCharacterConfig) then
    SimpleSharedEPGPCharacterConfig = {};
  end

  for i, v in pairs(SimpleSharedEPGPCharacterConfigDefault) do
    if (SimpleSharedEPGPCharacterConfig[i] == nil) then
      SimpleSharedEPGPCharacterConfig[i] = v;
    end
  end

  if (SimpleSharedEPGPLog == nil) then
    SimpleSharedEPGPLog = {};
  end

  if (SimpleSharedEPGPLooted == nil) then
    SimpleSharedEPGPLooted = {};
  end
end

function SimpleShareEPGP:buildMenu()
  if not (options) then
    options = {
      type = "group",
      desc = L["shootyepgp options"],
      handler = self,
      args = { }
    };
    options.args["ep"] = {
      type = "group",
      name = L["+EPs to Member"],
      desc = L["Account EPs for member."],
      order = 10,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,
    }
    options.args["ep_raid"] = {
      type = "text",
      name = L["+EPs to Raid"],
      desc = L["Award EPs to all raid members."],
      order = 20,
      get = "suggestedAwardEP",
      set = function(v) SimpleShareEPGP:award_raid_ep(tonumber(v)) end,
      usage = "<EP>",
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,
      validate = function(v)
        local n = tonumber(v)
        return n and n >= 0 and n < SimpleShareEPGP.VARS.max
      end
    }
    options.args["gp"] = {
      type = "group",
      name = L["+GPs to Member"],
      desc = L["Account GPs for member."],
      order = 30,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,
    }
    options.args["class"] = {
      type = "group",
      name = L["Set Class to Member"],
      desc = L["Choose one of classes for Undefined Class member"],
      order = 41,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,
    }
    options.args["new_member"] = {
      type = "group",
      name = L["Add new member"],
      desc = L["Add new member for DB"],
      order = 42,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,
    }
    options.args["remove_member"] = {
      type = "group",
      name = L["Remove member"],
      desc = L["Remove member from DB"],
      order = 43,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,
    };
    options.args["raid_only"] = {
      type = "toggle",
      name = L["Raid Only"],
      desc = L["Only show members in raid."],
      order = 80,
      get = function() return SimpleShareEPGPConfig.raidonly end,
      set = function(v) 
        SimpleShareEPGPConfig.raidonly = not SimpleShareEPGPConfig.raidonly
        SimpleShareEPGP:SetRefresh(true)
      end,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end
    }
    options.args["progress_tier_header"] = {
      type = "header",
      name = string.format(L["Progress Setting: %s"], SimpleSharedEPGPCharacterConfig.progress),
      order = 85,
      hidden = function()
        return SimpleShareEPGP.isAdminUnit();
      end,
    }
    options.args["progress_tier"] = {
      type = "text",
      name = L["Raid Progress"],
      desc = L["Highest Tier the Guild is raiding.\nUsed to adjust GP Prices.\nUsed for suggested EP awards."],
      order = 90,
      hidden = function()
        return true;
        -- return not SimpleShareEPGP.isAdminUnit();
      end,
      get = function() return SimpleSharedEPGPCharacterConfig.progress end,
      set = function(v) 
        SimpleSharedEPGPCharacterConfig.progress = v;
        SimpleShareEPGP:refreshPRTablets()
        if (SimpleShareEPGP.isRootUnit()) then
          SimpleShareEPGP:shareSettings(true)
        end
      end,
      validate = { ["T3"]=L["4.Naxxramas"], ["T2.5"]=L["3.Temple of Ahn\'Qiraj"], ["T2"]=L["2.Blackwing Lair"], ["T1"]=L["1.Molten Core"]},
    }
    options.args["report_channel"] = {
      type = "text",
      name = L["Reporting channel"],
      desc = L["Channel used by reporting functions."],
      order = 95,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,
      get = function() return SimpleShareEPGPConfig.sayChannel end,
      set = function(v) SimpleShareEPGPConfig.sayChannel = v end,
      validate = { "PARTY", "RAID", "GUILD", "OFFICER" },
    }    
    options.args["decay"] = {
      type = "execute",
      name = L["Decay EPGP"],
      desc = string.format(L["Decays all EPGP by %s%%"],(1-(SimpleSharedEPGPCharacterConfig.decay or SimpleShareEPGP.VARS.decay))*100),
      order = 100,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,      
      func = function() StaticPopup_Show("SHOOTY_EPGP_CONFIRM_DECAY") end
    }    
    options.args["set_decay"] = {
      type = "range",
      name = L["Set Decay %"],
      desc = L["Set Decay percentage (Admin only)."],
      order = 110,
      usage = "<Decay>",
      get = function() return (1.0 - SimpleSharedEPGPCharacterConfig.decay) end,
      set = function(v) 
        SimpleSharedEPGPCharacterConfig.decay = (1 - v);
        options.args["decay"].desc = string.format(L["Decays all EPGP by %s%%"], (1 - SimpleSharedEPGPCharacterConfig.decay) * 100)
        if (SimpleShareEPGP.isRootUnit()) then
          SimpleShareEPGP:shareSettings(true)
        end
      end,
      min = 0.01,
      max = 0.5,
      step = 0.01,
      bigStep = 0.05,
      isPercent = true,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,    
    }
    options.args["set_discount_header"] = {
      type = "header",
      name = string.format(L["Offspec Price: %s%%"], SimpleSharedEPGPCharacterConfig.discount * 100),
      order = 111,
      hidden = function()
        return SimpleShareEPGP.isAdminUnit();
      end,
    }
    options.args["set_discount"] = {
      type = "range",
      name = L["Offspec Price %"],
      desc = L["Set Offspec Items GP Percent."],
      order = 115,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,
      get = function() return SimpleSharedEPGPCharacterConfig.discount end,
      set = function(v) 
        SimpleSharedEPGPCharacterConfig.discount = v;
        if (SimpleShareEPGP.isRootUnit()) then
          SimpleShareEPGP:shareSettings(true);
        end
      end,
      min = 0,
      max = 1,
      step = 0.05,
      isPercent = true
    }
    options.args["set_min_ep_header"] = {
      type = "header",
      name = string.format(L["Minimum EP: %s"], SimpleSharedEPGPCharacterConfig.minep),
      order = 117,
      hidden = function()
        return SimpleShareEPGP.isAdminUnit();
      end,
    }
    options.args["set_min_ep"] = {
      type = "text",
      name = L["Minimum EP"],
      desc = L["Set Minimum EP"],
      usage = "<minep>",
      order = 118,
      get = function() return SimpleSharedEPGPCharacterConfig.minep end,
      set = function(v) 
        SimpleSharedEPGPCharacterConfig.minep = tonumber(v);
        SimpleShareEPGP:refreshPRTablets();
        if (SimpleShareEPGP.isRootUnit()) then
          SimpleShareEPGP:shareSettings(true)
        end        
      end,
      validate = function(v) 
        local n = tonumber(v)
        return n and n >= 0 and n <= SimpleShareEPGP.VARS.max
      end,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,
    }
    options.args["reset"] = {
      type = "execute",
      name = L["Reset EPGP"],
      desc = string.format(L["Resets everyone\'s EPGP to 0/%d (Admin only)."], SimpleShareEPGP.VARS.basegp),
      order = 120,
      hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end,
      func = function() StaticPopup_Show("SHOOTY_EPGP_CONFIRM_RESET") end
    }
  end
  if (needInit) or (needRefresh) then
    local members = SimpleShareEPGP:buildRosterTable()
    -- self:debugPrint(string.format(L["Scanning %d members for EP/GP data. (%s)"],table.getn(members),(SimpleShareEPGPConfig.raidonly and "Raid" or "Full")))
    options.args["ep"].args = SimpleShareEPGP:buildClassMemberTable(members,"ep")
    options.args["gp"].args = SimpleShareEPGP:buildClassMemberTable(members,"gp")
    options.args["class"].args = SimpleShareEPGP:buildChooseClassMember(members);
    options.args["new_member"].args = SimpleShareEPGP:buildClassNewMember();
    options.args["remove_member"].args = SimpleShareEPGP:buildClassRemoveMember(members);
    if (needInit) then needInit = false end
    if (needRefresh) then needRefresh = false end
  end
  return options
end

function SimpleShareEPGP:OnInitialize() -- ADDON_LOADED (1) unless LoD
  SimpleShareEPGP:InitAddonVariables();

  self:RegisterDB("simple_share_epgp_fubar")
  self:RegisterDefaults("char",{})
  --table.insert(SimpleShareEPGPConfig.debug,{[date("%b/%d %H:%M:%S")]="OnInitialize"})
end

function SimpleShareEPGP:OnEnable() -- PLAYER_LOGIN (2)
  --table.insert(SimpleShareEPGPConfig.debug,{[date("%b/%d %H:%M:%S")]="OnEnable"})
  SimpleShareEPGP._playerLevel = UnitLevel("player")
  SimpleShareEPGP.extratip = (SimpleShareEPGP.extratip) or CreateFrame("GameTooltip","shootyepgp_tooltip",UIParent,"GameTooltipTemplate")
  SimpleShareEPGP._versionString = GetAddOnMetadata("SimpleShareEPGP", "Version")
  SimpleShareEPGP._websiteString = GetAddOnMetadata("SimpleShareEPGP", "X-Website")

  self:RegisterEvent("RAID_ROSTER_UPDATE",function()
    SimpleShareEPGP:updateRaidRosterInfo();
    SimpleShareEPGP:SetRefresh(true)
    SimpleShareEPGP:testLootPrompt()
  end)
  self:RegisterEvent("PARTY_MEMBERS_CHANGED",function()
    SimpleShareEPGP:updateRaidRosterInfo();
    SimpleShareEPGP:SetRefresh(true)
    SimpleShareEPGP:testLootPrompt()
  end)
  self:RegisterEvent("PLAYER_ENTERING_WORLD",function()
    SimpleShareEPGP:updateRaidRosterInfo();
    SimpleShareEPGP:SetRefresh(true)
    SimpleShareEPGP:testLootPrompt()
  end)
  self:RegisterEvent("CHAT_MSG_RAID","captureLootCall")
  self:RegisterEvent("CHAT_MSG_RAID_LEADER","captureLootCall")
  self:RegisterEvent("CHAT_MSG_RAID_WARNING","captureLootCall")
  self:RegisterEvent("CHAT_MSG_WHISPER","captureBid")
  self:RegisterEvent("CHAT_MSG_LOOT","captureLoot")
  self:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED","tradeLoot")
  self:RegisterEvent("TRADE_ACCEPT_UPDATE","tradeLoot")

  if AceLibrary("AceEvent-2.0"):IsFullyInitialized() then
    self:AceEvent_FullyInitialized()
  else
    self:RegisterEvent("AceEvent_FullyInitialized")
  end
end

function SimpleShareEPGP:OnDisable()
  --table.insert(SimpleShareEPGPConfig.debug,{[date("%b/%d %H:%M:%S")]="OnDisable"})
  self:UnregisterAllEvents()
end

function SimpleShareEPGP:AceEvent_FullyInitialized() -- SYNTHETIC EVENT, later than PLAYER_LOGIN, PLAYER_ENTERING_WORLD (3)
  --table.insert(SimpleShareEPGPConfig.debug,{[date("%b/%d %H:%M:%S")]="AceEvent_FullyInitialized"})
  if self._hasInitFull then return end
  
  for i=1,NUM_CHAT_WINDOWS do
    local tab = getglobal("ChatFrame"..i.."Tab")
    local cf = getglobal("ChatFrame"..i)
    local tabName = tab:GetText()
    if tab ~= nil and (string.lower(tabName) == "debug") then
      shooty_debugchat = cf
      ChatFrame_RemoveAllMessageGroups(shooty_debugchat)
      shooty_debugchat:SetMaxLines(1024)
      break
    end
  end

  local delay = 2
  if self:IsEventRegistered("AceEvent_FullyInitialized") then
    self:UnregisterEvent("AceEvent_FullyInitialized")
    delay = 3
  end  
  if not self:IsEventScheduled("shootyepgpChannelInit") then
    self:ScheduleEvent("shootyepgpChannelInit",self.delayedInit,delay,self)
  end

  -- if pfUI loaded, skin the extra tooltip
  if not IsAddOnLoaded("pfUI-addonskins") then
    if (pfUI) and pfUI.api and pfUI.api.CreateBackdrop and pfUI_config and pfUI_config.tooltip and pfUI_config.tooltip.alpha then
      pfUI.api.CreateBackdrop(SimpleShareEPGP.extratip, nil, nil, tonumber(pfUI_config.tooltip.alpha))
    end
  end
  -- hook GiveMasterLoot to catch loot assign to members too far for chat parsing
  self:SecureHook("GiveMasterLoot")
  -- hook SetItemRef to parse our client bid links
  self:Hook("SetItemRef")
  -- hook tooltip to add our GP values
  self:TipHook()
  -- hook LootFrameItem_OnClick to add our own click handlers for bid calls
  self:SecureHook("LootFrameItem_OnClick")
  -- hook ContainerFrameItemButton_OnClick to add our own click handlers for bid calls
  self:Hook("ContainerFrameItemButton_OnClick")
  -- hook pfUI loot module :(
  if pfUI ~= nil and pfUI.loot ~= nil and type(pfUI.loot.UpdateLootFrame) == "function" then
    self:SecureHook(pfUI.loot, "UpdateLootFrame", "pfUI_UpdateLootFrame")
  end

  self._hasInitFull = true
end

SimpleShareEPGP._lastRosterRequest = false
function SimpleShareEPGP:OnMenuRequest()
  local now = GetTime()
  if not self._lastRosterRequest or (now - self._lastRosterRequest > 2) then
    self._lastRosterRequest = now
    self:SetRefresh(true)
  end
  self._options = self:buildMenu()
  D:FeedAceOptionsTable(self._options)
end

function SimpleShareEPGP:TipHook()
  self:SecureHook(GameTooltip, "SetHyperlink", function(this, itemstring)
    SimpleShareEPGP:AddDataToTooltip(GameTooltip, nil, itemstring)
  end)
  self:SecureHook(GameTooltip, "SetBagItem", function(this, bag, slot)
    local itemLink = GetContainerItemLink(bag, slot)
    local ml_tip
    if (itemLink) then
      local is_master = (SimpleShareEPGP:lootMaster()) and true or nil
      local link_found, _, itemColor, itemString, itemName = string.find(itemLink, "^(|c%x+)|H(.+)|h(%[.+%])")
      if (link_found) then
        local bind = self:itemBinding(itemString) or ""
        ml_tip = is_master and bind == SimpleShareEPGP.VARS.boe
        if (ml_tip) then
          local frame = GetMouseFocus()
          if (frame) and (frame.IsFrameType ~= nil) and (frame:IsFrameType("Button"))  then
            if not (frame._hasExtraClicks) then
              frame:RegisterForClicks("LeftButtonUp","RightButtonUp","MiddleButtonUp")
              frame._hasExtraClicks = true              
            end
          end
        end
      end
    end
    SimpleShareEPGP:AddDataToTooltip(GameTooltip, itemLink, nil, ml_tip)
  end
  )
  self:SecureHook(GameTooltip, "SetLootItem", function(this, slot)
    local is_master = (SimpleShareEPGP:lootMaster()) and true or nil
    if (is_master) then
      local frame = GetMouseFocus()
      if (frame) and (frame.IsFrameType ~= nil) and (frame:IsFrameType("Button"))  then
        if not (frame._hasExtraClicks) then
          frame:RegisterForClicks("LeftButtonUp","RightButtonUp","MiddleButtonUp")
          frame._hasExtraClicks = true              
        end
      end
    end
    SimpleShareEPGP:AddDataToTooltip(GameTooltip, GetLootSlotLink(slot), nil, is_master)
  end
  )
  self:SecureHook(GameTooltip, "SetLootRollItem", function(this, id)
    SimpleShareEPGP:AddDataToTooltip(GameTooltip, GetLootRollItemLink(id))
  end
  ) 
  self:HookScript(GameTooltip, "OnHide", function()
    if SimpleShareEPGP.extratip:IsVisible() then SimpleShareEPGP.extratip:Hide() end
    self.hooks[GameTooltip]["OnHide"]()
  end
  )
  self:HookScript(ItemRefTooltip, "OnHide", function()
    if SimpleShareEPGP.extratip:IsVisible() then SimpleShareEPGP.extratip:Hide() end
    self.hooks[ItemRefTooltip]["OnHide"]()
  end
  )
  if (AtlasLootTooltip) then
    self:SecureHook(AtlasLootTooltip, "SetHyperlink", function(this, itemstring)
      SimpleShareEPGP:AddDataToTooltip(AtlasLootTooltip,nil,itemstring)
    end)
    self:HookScript(AtlasLootTooltip, "OnHide", function()
      if SimpleShareEPGP.extratip:IsVisible() then SimpleShareEPGP.extratip:Hide() end
      self.hooks[AtlasLootTooltip]["OnHide"]()
    end)
  end
end

function SimpleShareEPGP:delayedInit()
  -- migrate EPGP storage if needed
  self:parseVersion(SimpleShareEPGP._versionString)
  local major_ver = self._version.major

  sepgp_table_db = SimpleShareEPGP:init_table_db()

  -- init options and comms
  self._options = self:buildMenu()
  self:RegisterChatCommand({"/simpleshareepgp","/ssepgp"},self.cmdtable())
  self:RegisterEvent("CHAT_MSG_ADDON","addonComms")  
  -- broadcast our version
  local addonMsg = string.format("VERSION;%s;%d",SimpleShareEPGP._versionString,major_ver)
  self:anounceAddonMessage(addonMsg)
  if (SimpleShareEPGP.isRootUnit()) then
    self:shareSettings()
  end
  self:defaultPrint(string.format(L["v%s Loaded."],SimpleShareEPGP._versionString))
  
  -- update prices from config.lua
  if (sepgp_prices and sepgp_custom_prices) then
    sepgp_prices:UpdatePrices(sepgp_custom_prices);
  end
end

function SimpleShareEPGP:AddDataToTooltip(tooltip,itemlink,itemstring,is_master)
  local price
  if (itemstring) then
    price = sepgp_prices:GetPrice(itemstring, SimpleSharedEPGPCharacterConfig.progress);
  elseif (itemlink) then
    price = sepgp_prices:GetPrice(itemlink, SimpleSharedEPGPCharacterConfig.progress);
  end
  if not price then return end
  local line_limit, left1,right1
  if (is_master) then 
    line_limit = 27 
    left1,right1 = C:Yellow(L["Alt Click/RClick/MClick"]), C:Orange(L["Call for: MS/OS/Both"])
  else 
    line_limit = 28 
  end
  local ep,gp = (self:get_ep_value(self._playerName) or 0), (self:get_gp_value(self._playerName) or SimpleShareEPGP.VARS.basegp)
  local off_price = math.floor(price * SimpleSharedEPGPCharacterConfig.discount)
  local pr,new_pr,new_pr_off = ep/gp, ep/(gp+price), ep/(gp+off_price)
  local pr_delta = new_pr - pr
  local pr_delta_off = new_pr_off - pr
  local textRight = string.format(L["gp:|cff32cd32%d|r gp_os:|cff20b2aa%d|r"],price,off_price)
  local textRight2 = string.format(L["pr:|cffff0000%.02f|r(%.02f) pr_os:|cffff0000%.02f|r(%.02f)"],pr_delta,new_pr,pr_delta_off,new_pr_off)
  if (tooltip:NumLines() < line_limit) then
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("|cff9664c8shootyepgp|r",textRight)
    tooltip:AddDoubleLine(" ",textRight2)
    if (is_master) then
      tooltip:AddDoubleLine(left1,right1)
    end
    tooltip:Show()
  else
    SimpleShareEPGP.extratip:ClearLines()
    SimpleShareEPGP.extratip:SetOwner(tooltip,"ANCHOR_NONE")
    SimpleShareEPGP.extratip:ClearAllPoints()
    if (EnhTooltip) and EnhancedTooltip:IsVisible() then
      SimpleShareEPGP.extratip:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, 5)
      SimpleShareEPGP.extratip:SetPoint("BOTTOMRIGHT", tooltip, "TOPRIGHT", 0, 5)          
    else
      SimpleShareEPGP.extratip:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, -5)
      SimpleShareEPGP.extratip:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", 0, -5)
    end
    SimpleShareEPGP.extratip:SetText("|cff9664c8shootyepgp|r")
    SimpleShareEPGP.extratip:AddDoubleLine(" ",textRight)
    SimpleShareEPGP.extratip:AddDoubleLine(" ",textRight2)
    if (is_master) then
      SimpleShareEPGP.extratip:AddDoubleLine(left1,right1)
    end
    SimpleShareEPGP.extratip:Show()
  end
end

function SimpleShareEPGP:OnUpdate(elapsed)
  SimpleShareEPGP.timer.count_down = SimpleShareEPGP.timer.count_down - elapsed
  lastUpdate = lastUpdate + elapsed
  if SimpleShareEPGP.timer.count_down <= 0 then
    running_check = nil
    SimpleShareEPGP.timer:Hide()
    SimpleShareEPGP.timer.cd_text = L["|cffff0000Finished|r"]
  else
    SimpleShareEPGP.timer.cd_text = string.format(L["|cff00ff00%02d|r|cffffffffsec|r"],SimpleShareEPGP.timer.count_down)
  end
  if lastUpdate > 0.5 then
    lastUpdate = 0
  end
end

function SimpleShareEPGP:SetItemRef(link, name, button)
  if string.sub(link,1,9) == "shootybid" then
    local _,_,bid,masterlooter = string.find(link,"shootybid:(%d+):(%w+)")
    if bid == "1" then
      bid = "+"
    elseif bid == "2" then
      bid = "-"
    else
      bid = nil
    end
    if not self:verifyRaidMember(masterlooter) then
      masterlooter = nil
    end
    if (bid and masterlooter) then
      SendChatMessage(bid,"WHISPER",nil,masterlooter)
    end
    return
  end
  self.hooks["SetItemRef"](link, name, button)
  if (link and name and ItemRefTooltip) then
    if (strsub(link, 1, 4) == "item") then
      if (ItemRefTooltip:IsVisible()) then
        if (not DressUpFrame:IsVisible()) then
          self:AddDataToTooltip(ItemRefTooltip, link)
        end
        ItemRefTooltip.isDisplayDone = nil
      end
    end
  end
end

function SimpleShareEPGP:LootFrameItem_OnClick(button,data)
  if not IsAltKeyDown() then return end
  if not UnitInRaid("player") then return end
  if not (self:lootMaster()) then 
    self:defaultPrint(L["Need MasterLooter to perform Bid Calls!"])
    UIErrorsFrame:AddMessage(L["Need MasterLooter to perform Bid Calls!"],1,0,0)
    return 
  end
  local slot, quality
  if data ~= nil then
    slot,quality = data:GetID(), data.quality
  else
    slot = LootFrame.selectedSlot or 0
    quality = LootFrame.selectedQuality or -1
    if not (this._hasExtraClicks) then 
      this:RegisterForClicks("LeftButtonUp","RightButtonUp","MiddleButtonUp")
      this._hasExtraClicks = true
    end
  end

  if (LootSlotIsItem(slot) and quality >= SimpleShareEPGP.VARS.minimalItemLootQualiti) then 
    local itemLink = GetLootSlotLink(slot)
    if (itemLink) then
      if button == "LeftButton" then
        self:widestAudience(string.format(L["Whisper %s a + for %s (mainspec)"],SimpleShareEPGP._playerName,itemLink))
      elseif button == "RightButton" then
        self:widestAudience(string.format(L["Whisper %s a - for %s (offspec)"],SimpleShareEPGP._playerName,itemLink))
      elseif button == "MiddleButton" then
        self:widestAudience(string.format(L["Whisper %s a + or - for %s (mainspec or offspec)"],SimpleShareEPGP._playerName,itemLink))
      end
    end
  end
end

function SimpleShareEPGP:ContainerFrameItemButton_OnClick(button,ignoreModifiers)
  if not IsAltKeyDown() then 
    return self.hooks["ContainerFrameItemButton_OnClick"](button,ignoreModifiers) 
  end
  if not UnitInRaid("player") then 
    return self.hooks["ContainerFrameItemButton_OnClick"](button,ignoreModifiers) 
  end
  if not (self:lootMaster()) then
    self:defaultPrint(L["Need MasterLooter to perform Bid Calls!"])
    UIErrorsFrame:AddMessage(L["Need MasterLooter to perform Bid Calls!"],1,0,0)
    return self.hooks["ContainerFrameItemButton_OnClick"](button,ignoreModifiers) 
  end
  if not (this._hasExtraClicks) then
    this:RegisterForClicks("LeftButtonUp","RightButtonUp","MiddleButtonUp")
    this._hasExtraClicks = true
  end
  local bag,slot = this:GetParent():GetID(), this:GetID()
  local itemLink = GetContainerItemLink(bag, slot)
  if (itemLink) then
    local link_found, _, itemColor, itemString, itemName = string.find(itemLink, "^(|c%x+)|H(.+)|h(%[.+%])")
    if (link_found) then
      local bind = self:itemBinding(itemString) or ""
      if (bind == self.VARS.boe) then
        if button == "LeftButton" then
          self:widestAudience(string.format(L["Whisper %s a + for %s (mainspec)"],SimpleShareEPGP._playerName,itemLink))
          return
        elseif button == "RightButton" then
          self:widestAudience(string.format(L["Whisper %s a - for %s (offspec)"],SimpleShareEPGP._playerName,itemLink))
          return
        elseif button == "MiddleButton" then
          self:widestAudience(string.format(L["Whisper %s a + or - for %s (mainspec or offspec)"],SimpleShareEPGP._playerName,itemLink))
          return
        end    
      end      
    end
  end
  return self.hooks["ContainerFrameItemButton_OnClick"](button,ignoreModifiers) 
end

function SimpleShareEPGP:pfUI_UpdateLootFrame()
  for slotid, pflootitem in pairs(pfUI.loot.slots) do
    if not self:IsHooked(pflootitem,"OnClick") then
      pflootitem:RegisterForClicks("LeftButtonUp","RightButtonUp","MiddleButtonUp")
      self:HookScript(pflootitem,"OnClick",function()
          self:LootFrameItem_OnClick(arg1,this)
          self.hooks[this]["OnClick"](this,arg1)
        end)
    end
  end
end

-------------------
-- Communication
-------------------
function SimpleShareEPGP:flashFrame(frame)
  local tabFlash = getglobal(frame:GetName().."TabFlash")
  if ( not frame.isDocked or (frame == SELECTED_DOCK_FRAME) or UIFrameIsFlashing(tabFlash) ) then
    return
  end
  tabFlash:Show()
  UIFrameFlash(tabFlash, 0.25, 0.25, 60, nil, 0.5, 0.5)
end

function SimpleShareEPGP:debugPrint(msg)
  if (shooty_debugchat) then
    shooty_debugchat:AddMessage(string.format(out,msg))
    self:flashFrame(shooty_debugchat)
  else
    self:defaultPrint(msg)
  end
end

function SimpleShareEPGP:defaultPrint(msg)
  if not DEFAULT_CHAT_FRAME:IsVisible() then
    FCF_SelectDockFrame(DEFAULT_CHAT_FRAME)
  end
  DEFAULT_CHAT_FRAME:AddMessage(string.format(out,msg))
end

function SimpleShareEPGP:bidPrint(link, masterlooter, need, greed, bid)
  local mslink = string.gsub(bidlink["ms"],"$ML",masterlooter)
  local oslink = string.gsub(bidlink["os"],"$ML",masterlooter)
  local msg = string.format(L["Click $MS or $OS for %s"],link)
  if (need and greed) then
    msg = string.gsub(msg,"$MS",mslink)
    msg = string.gsub(msg,"$OS",oslink)
  elseif (need) then
    msg = string.gsub(msg,"$MS",mslink)
    msg = string.gsub(msg,L["or $OS "],"")
  elseif (greed) then
    msg = string.gsub(msg,"$OS",oslink)
    msg = string.gsub(msg,L["$MS or "],"")
  elseif (bid) then
    msg = string.gsub(msg,"$MS",mslink)
    msg = string.gsub(msg,"$OS",oslink)  
  end
  local _, count = string.gsub(msg,"%$","%$")
  if (count > 0) then return end
  local chatframe
  if (SELECTED_CHAT_FRAME) then
    chatframe = SELECTED_CHAT_FRAME
  else
    if not DEFAULT_CHAT_FRAME:IsVisible() then
      FCF_SelectDockFrame(DEFAULT_CHAT_FRAME)
    end
    chatframe = DEFAULT_CHAT_FRAME
  end
  if (chatframe) then
    chatframe:AddMessage(" ")
    chatframe:AddMessage(string.format(out,msg),NORMAL_FONT_COLOR.r,NORMAL_FONT_COLOR.g,NORMAL_FONT_COLOR.b)
  end
end

function SimpleShareEPGP:simpleSay(msg)
  SendChatMessage(string.format("shootyepgp: %s",msg), SimpleShareEPGPConfig.sayChannel)
end

function SimpleShareEPGP:adminSay(msg)
  if (SimpleShareEPGP.isAdminUnit()) then
    SendChatMessage(string.format("shootyepgp: %s",msg), SimpleShareEPGPConfig.sayChannel)
  end
end

function SimpleShareEPGP:widestAudience(msg)
  local channel = "SAY"
  if UnitInRaid("player") then
    if (IsRaidLeader() or IsRaidOfficer()) then
      channel = "RAID_WARNING"
    else
      channel = "RAID"
    end
  elseif UnitExists("party1") then
    channel = "PARTY"
  end
  SendChatMessage(msg, channel)
end

function SimpleShareEPGP:addonMessage(message,channel,sender)
  SendAddonMessage(self.VARS.prefix,message,channel,sender)
end

function SimpleShareEPGP:addonComms(prefix, message, channel, sender)
  -- we don't care for messages from other addons
  if (not prefix == self.VARS.prefix) then
    return
  end

  -- we don't care for messages from ourselves
  if (sender == self._playerName) then
    return
  end

  local senderData = self:verifyMember(sender, true) or self:verifyRaidMember(sender);

  -- only accept DB or raider members
  if (not senderData) then
    return;
  end
  
  local who,what,amount
  for name,epgp,change in string.gfind(message,"([^;]+);([^;]+);([^;]+)") do
    who=name
    what=epgp
    amount=tonumber(change)
  end

  if (who) and (what) and (amount) then
    local msg
    if (who == self._playerName) then
      if what == "EP" then
        if amount < 0 then
          msg = string.format(L["You have received a %d EP penalty."], amount)
        else
          msg = string.format(L["You have been awarded %d EP."], amount)
        end
      elseif what == "GP" then
        msg = string.format(L["You have gained %d GP."], amount)
      end
    elseif who == "ALL" and what == "DECAY" then
      msg = string.format(L["%s%% decay to EP and GP."], amount)
    elseif who == "RAID" and what == "AWARD" then
      msg = string.format(L["%d EP awarded to Raid."], amount)
    elseif who == "VERSION" then
      local out_of_date, version_type = self:parseVersion(self._versionString, what)
      if (out_of_date) and self._newVersionNotification == nil then
        self._newVersionNotification = true -- only inform once per session
        self:defaultPrint(string.format(L["New %s version available: |cff00ff00%s|r"], version_type, what));
        self:defaultPrint(string.format(L["Visit %s to update."], self._websiteString));
      end
      if (SimpleShareEPGP.isRootUnit()) then
        self:shareSettings()
      end
    elseif who == "SETTINGS" then
      for progress,discount,decay,minep in string.gfind(what, "([^:]+):([^:]+):([^:]+):([^:]+)") do
        discount = tonumber(discount)
        decay = tonumber(decay)
        minep = tonumber(minep)
        local settings_notice
        if (progress and progress ~= SimpleSharedEPGPCharacterConfig.progress) then
          SimpleSharedEPGPCharacterConfig.progress = progress;
          settings_notice = L["New raid progress"];
        end
        if (discount and discount ~= SimpleSharedEPGPCharacterConfig.discount) then
          SimpleSharedEPGPCharacterConfig.discount = discount
          if (settings_notice) then
            settings_notice = settings_notice..L[", offspec price %"]
          else
            settings_notice = L["New offspec price %"]
          end
        end
        if (minep and minep ~= SimpleSharedEPGPCharacterConfig.minep) then
          SimpleSharedEPGPCharacterConfig.minep = minep;
          settings_notice = L["New Minimum EP"];
          SimpleShareEPGP:refreshPRTablets();
        end
        if decay and decay ~= SimpleSharedEPGPCharacterConfig.decay then
          SimpleSharedEPGPCharacterConfig.decay = decay;
          if (SimpleShareEPGP.isAdminUnit()) then
            if (settings_notice) then
              settings_notice = settings_notice..L[", decay %"]
            else
              settings_notice = L["New decay %"]
            end
          end
        end
        if (settings_notice) and settings_notice ~= "" then
          local sender_rank = string.format("%s",C:Colorize(BC:GetHexColor(class), sender));
          settings_notice = settings_notice..string.format(L[" settings accepted from %s"], sender_rank);
          self:defaultPrint(settings_notice);
          self._options.args["progress_tier_header"].name = string.format(L["Progress Setting: %s"], SimpleSharedEPGPCharacterConfig.progress);
          self._options.args["set_discount_header"].name = string.format(L["Offspec Price: %s%%"], SimpleSharedEPGPCharacterConfig.discount * 100);
          self._options.args["set_min_ep_header"].name = string.format(L["Minimum EP: %s"], SimpleSharedEPGPCharacterConfig.minep);
        end
      end
    end
    if msg and msg~="" then
      self:defaultPrint(msg)
      -- self:my_epgp()
    end
  end
end

function SimpleShareEPGP:anounceAddonMessage(msg)
  -- self:addonMessage(msg, "GUILD");
  self:addonMessage(msg, "RAID");
end

function SimpleShareEPGP:shareSettings(force)
  --TODO: need to think through a synchronization system
  return;

  -- local now = GetTime()
  -- if self._lastSettingsShare == nil or (now - self._lastSettingsShare > 30) or (force) then
  --   self._lastSettingsShare = now
  --   local addonMsg = string.format("SETTINGS;%s:%s:%s:%s;1", SimpleSharedEPGPCharacterConfig.progress,SimpleSharedEPGPCharacterConfig.discount,SimpleSharedEPGPCharacterConfig.decay,SimpleSharedEPGPCharacterConfig.minep)
  --   self:anounceAddonMessage(addonMsg);
  -- end
end

function SimpleShareEPGP:refreshPRTablets()
  --if not T:IsAttached("sepgp_standings") then
  sepgp_standings:Refresh()
  --end
  --if not T:IsAttached("sepgp_bids") then
  sepgp_bids:Refresh()
  --end
end

---------------------
-- EPGP Helpers
---------------------
function SimpleShareEPGP:init_notes_value(name)
  if (not name) then
    return
  end

  local table_db = SimpleShareEPGP:init_table_db();

  if (not table_db[name]) then
    table_db[name] = {
      ep = 0,
      gp = SimpleShareEPGP.VARS.basegp,
      class = SimpleShareEPGP.VARS.undefinedClass,
    };
  end
  return table_db[name];
end

function SimpleShareEPGP:clean_note_value(name)
  local table_db = SimpleShareEPGP:init_table_db();

  if (not table_db[name]) then
    return;
  end

  local newDB = SimpleShareEPGP:clean_table_db();
  for i, v in pairs(table_db) do
    if (i ~= name) then
      newDB[i] = v;
    end
  end
end
  
function SimpleShareEPGP:set_class_value(name, class)
  local data = SimpleShareEPGP:init_notes_value(name);

  data.class = class or SimpleShareEPGP.VARS.undefinedClass;
  return data;
end

function SimpleShareEPGP:get_class_value(name)
  local table_db = SimpleShareEPGP:init_table_db();
  if (not table_db[name]) then
    return;
  end

  return table_db[name].class;
end

---------------------
-- EPGP Operations
---------------------
function SimpleShareEPGP:set_ep_value(name, ep)
  local data = SimpleShareEPGP:init_notes_value(name);

  if (ep) then
    data.ep = math.max(0, ep);
  end
  return data;
end

function SimpleShareEPGP:set_gp_value(name, gp)
  local data = SimpleShareEPGP:init_notes_value(name);

  if (gp) then
    data.gp = math.max(SimpleShareEPGP.VARS.basegp, gp);
  end
  return data;
end

function SimpleShareEPGP:get_ep_value(name)
  local table_db = SimpleShareEPGP:init_table_db();
  if (not table_db[name]) then
    return;
  end

  return table_db[name].ep;
end

function SimpleShareEPGP:get_gp_value(name)
  local table_db = SimpleShareEPGP:init_table_db();
  if (not table_db[name]) then
    return;
  end

  return table_db[name].gp;
end

function SimpleShareEPGP:award_raid_ep(ep) -- awards ep to raid members in zone
  if GetNumRaidMembers()>0 then
    for i = 1, GetNumRaidMembers(true) do
      local name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i)
      if (name) then
        local dbValue = SimpleShareEPGP:init_notes_value(name);
        dbValue.class = class;
        self:give_ep_value(name, ep);
      end
    end
    self:simpleSay(string.format(L["Giving %d ep to all raidmembers"], ep))
    self:addToLog(string.format(L["Giving %d ep to all raidmembers"], ep))    
    local addonMsg = string.format("RAID;AWARD;%s",ep)
    self:addonMessage(addonMsg, "RAID");
    self:refreshPRTablets()
  else UIErrorsFrame:AddMessage(L["You aren't in a raid dummy"], 1, 0, 0) end
end

function SimpleShareEPGP:give_ep_value(name, ep)
  if (not SimpleShareEPGP.isAdminUnit()) then
    return
  end
  
  local newep = ep + (self:get_ep_value(name) or 0);
  self:set_ep_value(name, newep);
  self:debugPrint(string.format(L["Giving %d ep to %s."], ep, name));
  if ep < 0 then -- inform admins and victim of penalties
    local msg = string.format(L["%s EP Penalty to %s."],ep,name);
    self:adminSay(msg);
    self:addToLog(msg);
    local addonMsg = string.format("%s;%s;%s",name,"EP",ep)
    self:anounceAddonMessage(addonMsg);
  end
end

function SimpleShareEPGP:give_gp_value(name, gp)
  if (not SimpleShareEPGP.isAdminUnit()) then
    return;
  end

  local oldgp = (self:get_gp_value(name) or SimpleShareEPGP.VARS.basegp); 
  local newgp = gp + oldgp;
  self:set_gp_value(name, newgp);
  self:debugPrint(string.format(L["Giving %d gp to %s."], gp, name));
  local msg = string.format(L["Awarding %d GP to %s. (Previous: %d, New: %d)"], gp, name, oldgp, math.max(SimpleShareEPGP.VARS.basegp, newgp));
  self:adminSay(msg);
  self:addToLog(msg);
  local addonMsg = string.format("%s;%s;%s", name, "GP", gp);
  self:anounceAddonMessage(addonMsg);
end

function SimpleShareEPGP:decay_epgp_value()
  if (not SimpleShareEPGP.isAdminUnit()) then
    return;
  end

  local table_db = SimpleShareEPGP:init_table_db();

  for i, v in pairs(table_db) do
    local name = i;
    local ep, gp = v.ep, v.gp;

    if (ep and gp) then
      self:set_ep_value(name, self:num_round(ep * SimpleSharedEPGPCharacterConfig.decay));
      self:set_gp_value(name, self:num_round(gp * SimpleSharedEPGPCharacterConfig.decay));
    end
  end

  local msg = string.format(L["All EP and GP decayed by %s%%"],(1 - SimpleSharedEPGPCharacterConfig.decay) * 100)
  self:simpleSay(msg)
  self:adminSay(msg)
  local addonMsg = string.format("ALL;DECAY;%s", (1 - (SimpleSharedEPGPCharacterConfig.decay or SimpleShareEPGP.VARS.decay)) *100)
  self:anounceAddonMessage(addonMsg)
  self:addToLog(msg)
  self:refreshPRTablets() 
end

function SimpleShareEPGP:reset_value()
  if (not SimpleShareEPGP.isAdminUnit()) then
    return
  end

  local table_db = SimpleShareEPGP:init_table_db();

  for i, v in pairs(table_db) do
    local name = i;
    self:set_ep_value(name, 0);
    self:set_gp_value(name, SimpleShareEPGP.VARS.basegp);
  end

  local msg = L["All EP and GP has been reset to 0/%d."]
  self:debugPrint(string.format(msg,SimpleShareEPGP.VARS.basegp))
  self:adminSay(string.format(msg,SimpleShareEPGP.VARS.basegp))
  self:addToLog(string.format(msg,SimpleShareEPGP.VARS.basegp))
end

function SimpleShareEPGP:capcalc(ep,gp,gain)
  -- CAP_EP = EP_GAIN*DECAY/(1-DECAY) CAP_PR = CAP_EP/base_gp
  local pr = ep/gp
  local ep_decayed = self:num_round(ep * SimpleSharedEPGPCharacterConfig.decay)
  local gp_decayed = math.max(SimpleShareEPGP.VARS.basegp,self:num_round(gp * SimpleSharedEPGPCharacterConfig.decay))
  local pr_decay = tonumber(string.format("%.03f",pr))-tonumber(string.format("%.03f",ep_decayed/gp_decayed))
  if (pr_decay < 0.5) then 
    pr_decay = 0 
  else
    pr_decay = -tonumber(string.format("%.02f",pr_decay))
  end
  local cycle_gain = tonumber(gain)
  local cap_ep, cap_pr
  if (cycle_gain) then
    cap_ep = self:num_round(cycle_gain * SimpleSharedEPGPCharacterConfig.decay / (1 - SimpleSharedEPGPCharacterConfig.decay))
    cap_pr = tonumber(string.format("%.03f",cap_ep/SimpleShareEPGP.VARS.basegp))
  end
  return pr_decay, cap_ep, cap_pr
end

function SimpleShareEPGP:my_epgp_announce()
  local ep, gp = (self:get_ep_value(self._playerName) or 0), (self:get_gp_value(self._playerName) or SimpleShareEPGP.VARS.basegp)
  local pr = ep/gp
  local msg = string.format(L["You now have: %d EP %d GP |cffffff00%.03f|r|cffff7f00PR|r."], ep,gp,pr)
  self:defaultPrint(msg)
  local pr_decay, cap_ep, cap_pr = self:capcalc(ep,gp)
  if pr_decay < 0 then
    msg = string.format(L["Close to EPGP Cap. Next Decay will change your |cffff7f00PR|r by |cffff0000%.4g|r."],pr_decay)
    self:defaultPrint(msg)
  end
end

function SimpleShareEPGP:my_epgp()
  self:ScheduleEvent("shootyepgpRosterRefresh",self.my_epgp_announce,3,self)
end

---------
-- Menu
---------
SimpleShareEPGP.hasIcon = "Interface\\PetitionFrame\\GuildCharter-Icon"
SimpleShareEPGP.title = "custom shootyepgp"
SimpleShareEPGP.defaultMinimapPosition = 180
SimpleShareEPGP.defaultPosition = "RIGHT"
SimpleShareEPGP.cannotDetachTooltip = true
SimpleShareEPGP.tooltipHiddenWhenEmpty = false
SimpleShareEPGP.independentProfile = true

function SimpleShareEPGP:OnTooltipUpdate()
  local hint = L["|cffffff00Right-Click|r for Options."]
  if (SimpleShareEPGP.isAdminUnit()) then
    hint = string.format("%s \n%s%s", L["|cffffff00Click|r to toggle Standings."], hint, L[" \n|cffffff00Alt+Click|r to toggle Bids. \n|cffffff00Shift+Click|r to toggle Loot. \n|cffffff00Ctrl+Shift+Click|r to toggle Logs."]);
  else
    hint = string.format(hint,"");
  end
  T:SetHint(hint);
end

function SimpleShareEPGP:OnClick()
  local is_admin = SimpleShareEPGP.isAdminUnit();

  -- now any leftclick for not admin ignored
  if (not is_admin) then
    return;
  end

  if (IsControlKeyDown() and IsShiftKeyDown() and is_admin) then
    SimpleSharedEPGPLogs:Toggle()
  elseif (IsShiftKeyDown() and is_admin) then
    SimpleSharedEPGPLoot:Toggle()      
  elseif (IsAltKeyDown() and is_admin) then
    sepgp_bids:Toggle()
  else
    sepgp_standings:Toggle()
  end
end

function SimpleShareEPGP:SetRefresh(flag)
  needRefresh = flag
  if (flag) then
    self:refreshPRTablets()
  end
end

function SimpleShareEPGP:ClearLogs()
  SimpleSharedEPGPLog = {};
  SimpleSharedEPGPLogs:Refresh();
  SimpleShareEPGP:defaultPrint(L["Logs cleared"]);
end

function SimpleShareEPGP:ClearLoot()
  SimpleSharedEPGPLooted = {};
  SimpleSharedEPGPLoot:Refresh();
  SimpleShareEPGP:defaultPrint(L["Loot info cleared"]);
end

function SimpleShareEPGP:clean_table_db()
  sepgp_table_db = {};
  return sepgp_table_db;
end

function SimpleShareEPGP:init_table_db()
  if (not sepgp_table_db) then
    sepgp_table_db = {};
  end

  return sepgp_table_db;
end

function SimpleShareEPGP:updateRaidRosterInfo()
  if (GetNumRaidMembers() < 1) then
    return;
  end

  for i = 1, GetNumRaidMembers(true) do
    local raiderName, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i)
    if (raiderName) then
      local dbValue = SimpleShareEPGP:init_notes_value(raiderName);
      dbValue.class = class;
    end
  end
end

function SimpleShareEPGP:buildRosterTable()
  local table_db = SimpleShareEPGP:init_table_db();

  local g, r = { }, { }
  if (SimpleShareEPGPConfig.raidonly) and GetNumRaidMembers() > 0 then
    for i = 1, GetNumRaidMembers(true) do
      local name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i);
      
      if (name) then
        local dbValue = SimpleShareEPGP:init_notes_value(name);
        dbValue.class = class;
        r[name] = class;
      end
    end
  end
  
  for i, v in pairs(table_db) do
    local name = i;
    local class = v.class or SimpleShareEPGP.VARS.undefinedClass;
    if (SimpleShareEPGPConfig.raidonly and next(r)) then
      if (r[name]) then
        table.insert(g, {["name"]=name, ["class"]=class});
      end
    else
      table.insert(g, {["name"]=name, ["class"]=class});
    end
  end

  return g;
end

function SimpleShareEPGP:buildChooseClassMember(roster)
  local c = { };

  table.sort(roster, function(a,b)
    return a and b and a.name and b.name and a.name > b.name;
  end);
  local validateValues = {};

  local classToColorValue = {};
  local colorToClassValue = {};

  for class, _ in pairs(SimpleShareEPGP.classNames) do
    local colorClassValue = C:Colorize(BC:GetHexColor(class), class);
    table.insert(validateValues, colorClassValue);
    classToColorValue[class] = colorClassValue;
    colorToClassValue[colorClassValue] = class;
  end

  for _, member in ipairs(roster) do
    local class, name = member.class, member.name;
    
    if (not c[name]) then
      c[name] = {};
      c[name].type = "text";
      c[name].name = C:Colorize(BC:GetHexColor(class), name);
      c[name].desc = "set class value for member";
      c[name].hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end;
      c[name].get = function() return classToColorValue[class] end;
      c[name].set = function(v) SimpleShareEPGP:set_class_value(name, colorToClassValue[v]); SimpleShareEPGP:refreshPRTablets();  end --SimpleShareEPGP:buildMenu();
      c[name].validate = validateValues;
    end
  end

  return c;
end

function SimpleShareEPGP:buildClassRemoveMember(roster)
  local c = { };

  for i, member in ipairs(roster) do
    local class, name = member.class, member.name
    if (class) and (c[class] == nil) then
      c[class] = { };
      c[class].type = "group";
      c[class].name = C:Colorize(BC:GetHexColor(class), class);
      c[class].desc = L["Group remove member"];
      c[class].hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end;
      c[class].args = { };
    end
    if (name) and (c[class].args[name] == nil) then
      c[class].args[name] = { };
      c[class].args[name].type = "execute";
      c[class].args[name].name = name;
      c[class].args[name].desc = L["Remove this member"];
      c[class].args[name].func = function()
        SimpleShareEPGP:clean_note_value(name);
        SimpleShareEPGP:defaultPrint(C:Colorize(BC:GetHexColor(class), name).." "..L["Member removed from DB"]);
        SimpleShareEPGP:refreshPRTablets();
      end;
    end
  end

  return c;
end

function SimpleShareEPGP:buildClassNewMember()
  local c = {};

  for class, className in pairs(SimpleShareEPGP.classNames) do
    local _class = class;
    if (c[class] == nil) then
      c[class] = { };
    end
    c[class]._class = class;
    c[class].type = "text";
    c[class].name = C:Colorize(BC:GetHexColor(class), className);
    c[class].desc = L["Name for new class member"];
    c[class].hidden = function()
      return not SimpleShareEPGP.isAdminUnit();
    end
    c[class].get = function() return "" end;
    c[class].usage = "<new_member>";
    c[class].set = function(v)
      local newValueDB = SimpleShareEPGP:init_notes_value(v);
      newValueDB.class = _class;
      SimpleShareEPGP:refreshPRTablets();
      SimpleShareEPGP:defaultPrint(L["New member added in DB"]..": "..C:Colorize(BC:GetHexColor(_class), v));
    end;
    c[class].validate = function(v) 
      return (string.len(v) > 2) and (SimpleShareEPGP:verifyMember(v, true) == nil);
    end;
  end

  return c;
end

function SimpleShareEPGP:buildClassMemberTable(roster,epgp)
  local desc,usage
  if epgp == "ep" then
    desc = L["Account EPs to %s."]
    usage = "<EP>"
  elseif epgp == "gp" then
    desc = L["Account GPs to %s."]
    usage = "<GP>"
  end
  local c = { }
  for i,member in ipairs(roster) do
    local class,name = member.class, member.name
    if (class) and (c[class] == nil) then
      c[class] = { }
      c[class].type = "group"
      c[class].name = C:Colorize(BC:GetHexColor(class),class)
      c[class].desc = class .. " members"
      c[class].hidden = function()
        return not SimpleShareEPGP.isAdminUnit();
      end
      c[class].args = { }
    end
    if (name) and (c[class].args[name] == nil) then
      c[class].args[name] = { }
      c[class].args[name].type = "text"
      c[class].args[name].name = name
      c[class].args[name].desc = string.format(desc,name)
      c[class].args[name].usage = usage
      if epgp == "ep" then
        c[class].args[name].get = "suggestedAwardEP"
        c[class].args[name].set = function(v) SimpleShareEPGP:give_ep_value(name, tonumber(v)) SimpleShareEPGP:refreshPRTablets() end
      elseif epgp == "gp" then
        c[class].args[name].get = false
        c[class].args[name].set = function(v) SimpleShareEPGP:give_gp_value(name, tonumber(v)) SimpleShareEPGP:refreshPRTablets() end
      end
      c[class].args[name].validate = function(v) return (type(v) == "number" or tonumber(v)) and tonumber(v) < SimpleShareEPGP.VARS.max end
    end
  end
  return c
end


function SimpleShareEPGP:getCharacterData(name)
  local table_db = SimpleShareEPGP:init_table_db();
  if (not name or type(table_db[name]) ~= "table") then
    return nil;
  end

  return table_db[name];
end

---------
-- Bids
---------
local lootCall = {}
lootCall.whisp = {
  "^(w)[%s%p%c]+.+",".+[%s%p%c]+(w)$",".+[%s%p%c]+(w)[%s%p%c]+.*",".*[%s%p%c]+(w)[%s%p%c]+.+",
  "^(whisper)[%s%p%c]+.+",".+[%s%p%c]+(whisper)$",".+[%s%p%c]+(whisper)[%s%p%c]+.*",".*[%s%p%c]+(whisper)[%s%p%c]+.+",
  ".+[%s%p%c]+(bid)[%s%p%c]*.*",".*[%s%p%c]*(bid)[%s%p%c]+.+"
}
lootCall.ms = {
  ".+(%+).*",".*(%+).+", 
  "^(ms)[%s%p%c]+.+",".+[%s%p%c]+(ms)$",".+[%s%p%c]+(ms)[%s%p%c]+.*",".*[%s%p%c]+(ms)[%s%p%c]+.+", 
  ".+(mainspec).*",".*(mainspec).+"
}
lootCall.os = {
  ".+(%-).*",".*(%-).+", 
  "^(os)[%s%p%c]+.+",".+[%s%p%c]+(os)$",".+[%s%p%c]+(os)[%s%p%c]+.*",".*[%s%p%c]+(os)[%s%p%c]+.+", 
  ".+(offspec).*",".*(offspec).+"
}
lootCall.bs = { -- blacklist
  "^(roll)[%s%p%c]+.+",".+[%s%p%c]+(roll)$",".*[%s%p%c]+(roll)[%s%p%c]+.*"
}
function SimpleShareEPGP:captureLootCall(text, sender)
  if not (string.find(text, "|Hitem:", 1, true)) then
    return;
  end

  local linkstriptext, count = string.gsub(text,"|c%x+|H[eimt:%d]+|h%[[%w%s',%-]+%]|h|r"," ; ");
  if count > 1 then
    return;
  end
  
  local lowtext = string.lower(linkstriptext);
  local whisperkw_found, mskw_found, oskw_found, link_found, blacklist_found;

  for _,f in ipairs(lootCall.bs) do
    blacklist_found = string.find(lowtext,f);
    if (blacklist_found) then
      return;
    end
  end

  local _, itemLink, itemColor, itemString, itemName;

  for _,f in ipairs(lootCall.whisp) do
    whisperkw_found = string.find(lowtext,f);
    if (whisperkw_found) then
      break;
    end
  end

  for _,f in ipairs(lootCall.ms) do
    mskw_found = string.find(lowtext,f);
    if (mskw_found) then
      break;
    end
  end

  for _,f in ipairs(lootCall.os) do
    oskw_found = string.find(lowtext,f);
    if (oskw_found) then
      break;
    end
  end

  if (whisperkw_found) or (mskw_found) or (oskw_found) then
    _,_,itemLink = string.find(text,"(|c%x+|H[eimt:%d]+|h%[[%w%s',%-]+%]|h|r)")
    if (itemLink) and (itemLink ~= "") then
      link_found, _, itemColor, itemString, itemName = string.find(itemLink, "^(|c%x+)|H(.+)|h(%[.+%])")
    end
    if (link_found) then
      local quality = hexColorQuality[itemColor] or -1;
      if (quality >= SimpleShareEPGP.VARS.minimalItemLootQualiti) then
        if (IsRaidLeader() or self:lootMaster()) and (sender == self._playerName) then
          self:clearBids(true)
          SimpleShareEPGP.bid_item.link = itemString
          SimpleShareEPGP.bid_item.linkFull = itemLink
          SimpleShareEPGP.bid_item.name = string.format("%s%s|r", itemColor, itemName)
          self:ScheduleEvent("shootyepgpBidTimeout", self.clearBids, 300, self)
          running_bid = true
          self:debugPrint("Capturing Bids for 5min.")
          sepgp_bids:Toggle(true)
        end
        self:bidPrint(itemLink, sender, mskw_found, oskw_found, whisperkw_found);
      end
    end
  end
end

local lootBid = {}
lootBid.ms = {"(%+)",".+(%+).*",".*(%+).+",".*(%+).*","(ms)","(need)"}
lootBid.os = {"(%-)",".+(%-).*",".*(%-).+",".*(%-).*","(os)","(greed)"}
function SimpleShareEPGP:captureBid(text, sender)
  if (not running_bid) then
    return;
  end

  if not (IsRaidLeader() or self:lootMaster()) then
    return;
  end

  if (not SimpleShareEPGP.bid_item.link) then
    return
  end

  local mskw_found, oskw_found;

  -- main spec parser
  for _,f in ipairs(lootBid.ms) do
    mskw_found = string.find(text, f);
    if (mskw_found) then
      break;
    end
  end

  -- off spec parser
  for _,f in ipairs(lootBid.os) do
    oskw_found = string.find(text, f);
    if (oskw_found) then
      break
    end
  end

  -- not any found
  if not (mskw_found or oskw_found) then
    return;
  end

  -- already have
  if (bids_blacklist[sender]) then
    return;
  end


  local member = self:verifyRaidMember(sender);
  if (not member) then
    return;
  end

  local ep = member.ep or 0; 
  local gp = member.gp or SimpleShareEPGP.VARS.basegp;
  local class = member.class or SimpleShareEPGP.VARS.undefinedClass;

  if (mskw_found) then
    bids_blacklist[sender] = true;
    table.insert(SimpleShareEPGP.bids_main, {sender, class, ep, gp, ep/gp});
  elseif (oskw_found) then
    bids_blacklist[sender] = true
    table.insert(SimpleShareEPGP.bids_off, {sender, class, ep, gp, ep/gp});
  end
  sepgp_bids:Toggle(true);
end

function SimpleShareEPGP:clearBids(reset)
  if reset~=nil then
    self:debugPrint(L["Clearing old Bids"])
  end
  SimpleShareEPGP.bid_item = {}
  SimpleShareEPGP.bids_main = {}
  SimpleShareEPGP.bids_off = {}
  bids_blacklist = {}
  if self:IsEventScheduled("shootyepgpBidTimeout") then
    self:CancelScheduledEvent("shootyepgpBidTimeout")
  end
  running_bid = false
  sepgp_bids._counterText = ""
  sepgp_bids:Refresh()
end

----------------
-- Loot Tracker
----------------
-- /script DEFAULT_CHAT_FRAME:AddMessage("\124cffa335ee\124Hitem:16864:0:0:0:0:0:0:0:0\124h[Belt of Might]\124h\124r");
-- test: "You receive loot: \124cffa335ee\124Hitem:16866:0:0:0\124h[Helm of Might]\124h\124r."
-- test: /run SimpleShareEPGP:captureLoot("Raerlas receives loot: \124cffa335ee\124Hitem:16846:0:0:0\124h[Giantstalker's Helmet]\124h\124r.")
-- test: /run SimpleShareEPGP:captureLoot("You receive loot: \124cffa335ee\124Hitem:16864:0:0:0\124h[Belt of Might]\124h\124r.")
SimpleShareEPGP.loot_index = {
  time=1,
  player=2,
  player_c=3,
  item=4,
  bind=5,
  price=6,
  off_price=7,
  action=8,
  update=9
}
function SimpleShareEPGP:captureLoot(message)
  if not (UnitInRaid("player") and self:lootMaster() and SimpleShareEPGP.isAdminUnit()) then return end
  local who,what,amount,player,itemLink
  who,what,amount = DF:Deformat(message,LOOT_ITEM_MULTIPLE)
  if (amount) then -- skip multiples / stacks
  else
    player, itemLink = DF:Deformat(message,LOOT_ITEM)
  end
  who,what,amount = YOU, DF:Deformat(message,LOOT_ITEM_SELF_MULTIPLE)
  if (amount) then -- skip multiples / stacks
  else
    if not (player and itemLink) then
      player, itemLink = YOU, DF:Deformat(message, LOOT_ITEM_SELF)
    end
  end
  if not (player and itemLink) then return end
  self:processLoot(player,itemLink,"chat")
end

function SimpleShareEPGP:GiveMasterLoot(slot, index)
  if LootSlotIsItem(slot) then
    local texture, itemname, quantity, quality = GetLootSlotInfo(slot)
    if (quantity == 1 and quality >= SimpleShareEPGP.VARS.minimalItemLootQualiti) then -- not a stack and rare or higher
      local itemLink = GetLootSlotLink(slot);
      local player = GetMasterLootCandidate(index);
      if not (player and itemLink) then
        return ;
      end

      self:processLoot(player, itemLink, "masterloot");
    end
  end
end

function SimpleShareEPGP:findLootReminder(itemLink)
  for i,data in ipairs(SimpleSharedEPGPLooted) do
    if data[self.loot_index.item] == itemLink and data[self.loot_index.action] == self.VARS.reminder then
      return data;
    end
  end
end

function SimpleShareEPGP:tradeLoot(playerState,targetState)
  if not (UnitInRaid("player") and self:lootMaster() and SimpleShareEPGP.isAdminUnit()) then
    return;
  end

  if (playerState ~= nil and targetState ~= nil) and playerState == 1 and targetState == 1 then
    local itemLink
    for id=1,MAX_TRADABLE_ITEMS do
      itemLink = GetTradePlayerItemLink(id)
      if (itemLink) then
        break  
      end
    end
    if (itemLink) then
      local link_found, _, itemColor, itemString, itemName = string.find(itemLink, "^(|c%x+)|H(.+)|h(%[.+%])")
      if (link_found) then
        local price = sepgp_prices:GetPrice(itemString, SimpleSharedEPGPCharacterConfig.progress);
        if not (price) or price == 0 then
          return
        end
        local bind = self:itemBinding(itemString)
        if (not bind) or (bind ~= self.VARS.boe) then return end
        if UnitExists("target") and UnitIsPlayer("target") and UnitCanCooperate("player","target") and (not UnitIsUnit("player","target")) then
          local tradeTarget = UnitName("target")
          local verifyMember = self:verifyRaidMember(tradeTarget);
          if (not verifyMember) then
            return
          end

          local target_color = C:Colorize(BC:GetHexColor(verifyMember.class), tradeTarget)
          local timestamp = date("%b/%d %H:%M:%S")
          local data = self:findLootReminder(itemLink)
          if (data) then
            data[self.loot_index.time] = timestamp
            data[self.loot_index.player] = tradeTarget
            data[self.loot_index.player_c] = target_color
            data[self.loot_index.update] = 1
            local dialog = StaticPopup_Show("SHOOTY_EPGP_AUTO_GEARPOINTS", data[self.loot_index.player_c], data[self.loot_index.item], data)
            if (dialog) then
              dialog.data = data
            end
          end
        end
      end
    end
  end
end

SimpleShareEPGP.item_bind_patterns = {
  CRAFT = "("..ITEM_SPELL_TRIGGER_ONUSE..")",
  BOP = "("..ITEM_BIND_ON_PICKUP..")",
  QUEST = "("..ITEM_BIND_QUEST..")",
  BOU = "("..ITEM_BIND_ON_EQUIP..")",
  BOE = "("..ITEM_BIND_ON_USE..")"
}
function SimpleShareEPGP:itemBinding(item)
  G:SetHyperlink(item)
  if G:Find(self.item_bind_patterns.CRAFT,2,4,nil,true) then
  else
    if G:Find(self.item_bind_patterns.BOP,2,4,nil,true) then
      return SimpleShareEPGP.VARS.bop
    elseif G:Find(self.item_bind_patterns.QUEST,2,4,nil,true) then
      return SimpleShareEPGP.VARS.bop
    elseif G:Find(self.item_bind_patterns.BOE,2,4,nil,true) then
      return SimpleShareEPGP.VARS.boe
    elseif G:Find(self.item_bind_patterns.BOU,2,4,nil,true) then
      return SimpleShareEPGP.VARS.boe
    else
      return SimpleShareEPGP.VARS.nobind
    end
  end
  return
end

function SimpleShareEPGP:addOrUpdateLoot(data,update)
  if not (update) then
    table.insert(SimpleSharedEPGPLooted, data)
  end
end

function SimpleShareEPGP:testLootPrompt()
  raidStatus = UnitInRaid("player") and true or false
  if lastRaidStatus == nil then
    lastRaidStatus = raidStatus
  end
  if (raidStatus == false) and (lastRaidStatus == true) then
    local hasLoot = table.getn(SimpleSharedEPGPLooted)
    local dialog = StaticPopup_FindVisible("SHOOTY_EPGP_CLEAR_LOOT")
    if (not (dialog)) and (hasLoot > 0) then
      StaticPopup_Show("SHOOTY_EPGP_CLEAR_LOOT",hasLoot)
    end
  end
  lastRaidStatus = raidStatus
end

------------
-- Logging
------------
function SimpleShareEPGP:addToLog(line,skipTime)
  local over = table.getn(SimpleSharedEPGPLog) - SimpleShareEPGP.VARS.maxloglines + 1;
  if (over > 0) then
    for i=1,over do
      table.remove(SimpleSharedEPGPLog, 1);
    end
  end

  local timestamp;
  if (skipTime) then
    timestamp = "";
  else
    timestamp = date("%b/%d %H:%M:%S");
  end

  table.insert(SimpleSharedEPGPLog, {timestamp, line});
end

------------
-- Utility 
------------
function SimpleShareEPGP:num_round(i)
  return math.floor(i+0.5)
end

function SimpleShareEPGP:strsplit(delimiter, subject)
  local delimiter, fields = delimiter or ":", {}
  local pattern = string.format("([^%s]+)", delimiter)
  string.gsub(subject, pattern, function(c) fields[table.getn(fields)+1] = c end)
  return unpack(fields)
end

function SimpleShareEPGP:processLootDupe(player,itemName,source)
  local now = GetTime()
  local player_name = player == YOU and self._playerName or player
  local player_item = string.format("%s%s",player_name,itemName)
  if ((self._lastPlayerItem) and self._lastPlayerItem == player_item)
  and ((self._lastPlayerItemTime) and (now - self._lastPlayerItemTime) < 3)
  and ((self._lastPlayerItemSource) and self._lastPlayerItemSource ~= source) then
    return true, player_item, now
  end
  return false, player_item, now
end

function SimpleShareEPGP:processLoot(player, itemLink, source)
  local link_found, _, itemColor, itemString, itemName = string.find(itemLink, "^(|c%x+)|H(.+)|h(%[.+%])");
  if (link_found) then
    local dupe, player_item, now = self:processLootDupe(player, itemName, source);
    
    if dupe then
      return;
    end

    local bind = self:itemBinding(itemString)
    
    if not (bind) then
      return
    end

    local price = sepgp_prices:GetPrice(itemString, SimpleSharedEPGPCharacterConfig.progress);
    if (not (price)) or (price == 0) then
      return
    end
    if player == YOU then
      player = self._playerName
    end

    local verifyMember = self:verifyRaidMember(player);
    if (not verifyMember) then
      return;
    end

    self._lastPlayerItem, self._lastPlayerItemTime, self._lastPlayerItemSource = player_item, now, source;
    local player_color = C:Colorize(BC:GetHexColor(verifyMember.class), player);
    local off_price = math.floor(price * SimpleSharedEPGPCharacterConfig.discount);
    local quality = hexColorQuality[itemColor] or -1;
    local timestamp = date("%b/%d %H:%M:%S");
    local data = {
      [self.loot_index.time] = timestamp,
      [self.loot_index.player] = player,
      [self.loot_index.player_c] = player_color,
      [self.loot_index.item] = itemLink,
      [self.loot_index.bind] = bind,
      [self.loot_index.price] = price,
      [self.loot_index.off_price] = off_price,
    };
    local dialog = StaticPopup_Show("SHOOTY_EPGP_AUTO_GEARPOINTS", data[self.loot_index.player_c], data[self.loot_index.item], data);
    if (dialog) then
      dialog.data = data
    end
  end
end

function SimpleShareEPGP:verifyMember(name, silent)
  local table_db = SimpleShareEPGP:init_table_db();
  if (not name or not table_db[name]) then
    if not (silent) then
      self:defaultPrint(string.format(L["%s not found member!"], name ))
    end
    return;
  end

  return table_db[name];
end

function SimpleShareEPGP:verifyRaidMember(name)
  if (not name) then
    return;
  end

  if (GetNumRaidMembers() > 0) then
    for i = 1, GetNumRaidMembers(true) do
      local raiderName, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i)
      if (name == raiderName) then
        local dbValue = SimpleShareEPGP:init_notes_value(name);
        dbValue.class = class;
        return dbValue;
      end
    end
  end

  return;
end

function SimpleShareEPGP:inRaid(name)
  for i=1,GetNumRaidMembers() do
    if name == (UnitName(raidUnit[i])) then
      return true;
    end
  end
  return false;
end

function SimpleShareEPGP:lootMaster()
  local method, lootmasterID = GetLootMethod()
  if method == "master" and lootmasterID == 0 then
    return true
  else
    return false
  end
end

function SimpleShareEPGP:make_escable(framename,operation)
  local found
  for i,f in ipairs(UISpecialFrames) do
    if f==framename then
      found = i
    end
  end
  if not found and operation=="add" then
    table.insert(UISpecialFrames,framename)
  elseif found and operation=="remove" then
    table.remove(UISpecialFrames,found)
  end
end

local raidZones = {[L["Molten Core"]]="T1",[L["Onyxia\'s Lair"]]="T1.5",[L["Blackwing Lair"]]="T2",[L["Ahn\'Qiraj"]]="T2.5",[L["Naxxramas"]]="T3"}
local zone_multipliers = {
  ["T3"] =   {["T3"]=1,["T2.5"]=0.75,["T2"]=0.5,["T1.5"]=0.25,["T1"]=0.25},
  ["T2.5"] = {["T3"]=1,["T2.5"]=1,   ["T2"]=0.7,["T1.5"]=0.4, ["T1"]=0.4},
  ["T2"] =   {["T3"]=1,["T2.5"]=1,   ["T2"]=1,  ["T1.5"]=0.5, ["T1"]=0.5},
  ["T1"] =   {["T3"]=1,["T2.5"]=1,   ["T2"]=1,  ["T1.5"]=1,   ["T1"]=1}
}
function SimpleShareEPGP:suggestedAwardEP()
  local currentTier, zoneEN, zoneLoc, checkTier, multiplier
  local inInstance, instanceType = IsInInstance()
  if (inInstance == nil) or (instanceType ~= nil and instanceType == "none") then
    currentTier = "T1.5"   
  end
  if (inInstance) and (instanceType == "raid") then
    zoneLoc = GetRealZoneText()
    if (BZ:HasReverseTranslation(zoneLoc)) then
      zoneEN = BZ:GetReverseTranslation(zoneLoc)
      checkTier = raidZones[zoneEN]
      if (checkTier) then
        currentTier = checkTier
      end
    end
  end
  if not currentTier then 
    return SimpleShareEPGP.VARS.baseaward_ep;
  else
    multiplier = zone_multipliers[SimpleSharedEPGPCharacterConfig.progress][currentTier];
  end
  if (multiplier) then
    return multiplier*SimpleShareEPGP.VARS.baseaward_ep;
  else
    return SimpleShareEPGP.VARS.baseaward_ep;
  end
end

function SimpleShareEPGP:parseVersion(version,otherVersion)
  if not SimpleShareEPGP._version then SimpleShareEPGP._version = {} end
  for major,minor,patch in string.gfind(version,"(%d+)[^%d]?(%d*)[^%d]?(%d*)") do
    SimpleShareEPGP._version.major = tonumber(major)
    SimpleShareEPGP._version.minor = tonumber(minor)
    SimpleShareEPGP._version.patch = tonumber(patch)
  end
  if (otherVersion) then
    if not SimpleShareEPGP._otherversion then SimpleShareEPGP._otherversion = {} end
    for major,minor,patch in string.gfind(otherVersion,"(%d+)[^%d]?(%d*)[^%d]?(%d*)") do
      SimpleShareEPGP._otherversion.major = tonumber(major)
      SimpleShareEPGP._otherversion.minor = tonumber(minor)
      SimpleShareEPGP._otherversion.patch = tonumber(patch)      
    end
    if (SimpleShareEPGP._otherversion.major ~= nil and SimpleShareEPGP._version.major ~= nil) then
      if (SimpleShareEPGP._otherversion.major < SimpleShareEPGP._version.major) then -- we are newer
        return
      elseif (SimpleShareEPGP._otherversion.major > SimpleShareEPGP._version.major) then -- they are newer
        return true, "major"        
      else -- tied on major, go minor
        if (SimpleShareEPGP._otherversion.minor ~= nil and SimpleShareEPGP._version.minor ~= nil) then
          if (SimpleShareEPGP._otherversion.minor < SimpleShareEPGP._version.minor) then -- we are newer
            return
          elseif (SimpleShareEPGP._otherversion.minor > SimpleShareEPGP._version.minor) then -- they are newer
            return true, "minor"
          else -- tied on minor, go patch
            if (SimpleShareEPGP._otherversion.patch ~= nil and SimpleShareEPGP._version.patch ~= nil) then
              if (SimpleShareEPGP._otherversion.patch < SimpleShareEPGP._version.patch) then -- we are newer
                return
              elseif (SimpleShareEPGP._otherversion.patch > SimpleShareEPGP._version.patch) then -- they are newwer
                return true, "patch"
              end
            elseif (SimpleShareEPGP._otherversion.patch ~= nil and SimpleShareEPGP._version.patch == nil) then -- they are newer
              return true, "patch"
            end
          end    
        elseif (SimpleShareEPGP._otherversion.minor ~= nil and SimpleShareEPGP._version.minor == nil) then -- they are newer
          return true, "minor"
        end
      end
    end
  end
end

function SimpleShareEPGP:camelCase(word)
  return string.gsub(word,"(%a)([%w_']*)",function(head,tail) 
    return string.format("%s%s",string.upper(head),string.lower(tail)) 
    end)
end

-------------
-- Dialogs
-------------
StaticPopupDialogs["SHOOTY_EPGP_CLEAR_LOOT"] = {
  text = L["There are %d loot drops stored. It is recommended to clear loot info before a new raid. Do you want to clear it now?"],
  button1 = TEXT(YES),
  button2 = L["Show me"],
  OnAccept = function()
    SimpleShareEPGP:ClearLoot();
  end,
  OnCancel = function(_,reason)
    if reason == "clicked" then
      SimpleSharedEPGPLoot:Toggle(true)
      SimpleShareEPGP:defaultPrint(L["Loot info can be cleared at any time from the Tablet context menu or '/shooty clearloot' command"])
    end
  end,
  timeout = 0,
  whileDead = 1,
  exclusive = 0,
  hideOnEscape = 1
}

StaticPopupDialogs["SHOOTY_EPGP_CONFIRM_RESET"] = {
  text = L["|cffff0000Are you sure you want to Reset ALL EPGP?|r"],
  button1 = TEXT(OKAY),
  button2 = TEXT(CANCEL),
  OnAccept = function()
    SimpleShareEPGP:reset_value();
    SimpleShareEPGP:refreshPRTablets();
  end,
  timeout = 0,
  whileDead = 1,
  exclusive = 1,
  showAlert = 1,
  hideOnEscape = 1
}

StaticPopupDialogs["SHOOTY_EPGP_CONFIRM_DECAY"] = {
  text = L["|cffff0000Are you sure you want to Decay EPGP?|r"],
  button1 = TEXT(OKAY),
  button2 = TEXT(CANCEL),
  OnAccept = function()
    SimpleShareEPGP:decay_epgp_value();
    SimpleShareEPGP:refreshPRTablets();
  end,
  timeout = 0,
  whileDead = 1,
  exclusive = 1,
  showAlert = 1,
  hideOnEscape = 1
}

local sepgp_auto_gp_menu = {
  --{text = "Choose an Action", isTitle = true},
  {text = L["Add MainSpec GP"], func = function()
    local dialog = StaticPopup_FindVisible("SHOOTY_EPGP_AUTO_GEARPOINTS")
    if (dialog) then
      local data = dialog.data
      local player, price = data[SimpleShareEPGP.loot_index.player], data[SimpleShareEPGP.loot_index.price]
      SimpleShareEPGP:give_gp_value((player==YOU and SimpleShareEPGP._playerName or player),price)
      SimpleShareEPGP:refreshPRTablets()
      data[SimpleShareEPGP.loot_index.action] = SimpleShareEPGP.VARS.msgp
      local update = data[SimpleShareEPGP.loot_index.update] ~= nil
      SimpleShareEPGP:addOrUpdateLoot(data,update)
      StaticPopup_Hide("SHOOTY_EPGP_AUTO_GEARPOINTS")
      SimpleSharedEPGPLoot:Refresh()
    end
  end},
  {text = L["Add OffSpec GP"], func = function()
    local dialog = StaticPopup_FindVisible("SHOOTY_EPGP_AUTO_GEARPOINTS")
    if (dialog) then
      local data = dialog.data
      local player, off_price = data[SimpleShareEPGP.loot_index.player], data[SimpleShareEPGP.loot_index.off_price]
      SimpleShareEPGP:give_gp_value((player==YOU and SimpleShareEPGP._playerName or player),off_price)
      SimpleShareEPGP:refreshPRTablets()
      data[SimpleShareEPGP.loot_index.action] = SimpleShareEPGP.VARS.osgp
      local update = data[SimpleShareEPGP.loot_index.update] ~= nil
      SimpleShareEPGP:addOrUpdateLoot(data,update)
      StaticPopup_Hide("SHOOTY_EPGP_AUTO_GEARPOINTS")
      SimpleSharedEPGPLoot:Refresh()
    end
  end},
  {text = L["Bank or D/E"], func = function()
    local dialog = StaticPopup_FindVisible("SHOOTY_EPGP_AUTO_GEARPOINTS")
    if (dialog) then
      local data = dialog.data
      data[SimpleShareEPGP.loot_index.action] = SimpleShareEPGP.VARS.bankde
      local update = data[SimpleShareEPGP.loot_index.update] ~= nil
      SimpleShareEPGP:addOrUpdateLoot(data,update)
      StaticPopup_Hide("SHOOTY_EPGP_AUTO_GEARPOINTS")
      SimpleSharedEPGPLoot:Refresh()
    end
  end}
}
StaticPopupDialogs["SHOOTY_EPGP_AUTO_GEARPOINTS"] = {
  text = L["%s looted %s. What do you want to do?"],
  button1 = L["GP Actions"],
  button2 = L["Remind me Later"],
  OnAccept = function()
    SimpleShareEPGP:EasyMenu(sepgp_auto_gp_menu, SimpleShareEPGP._menuFrame, this, 0, 0, "MENU", 1)
    return true
  end,
  OnCancel = function(data,reason)
    if reason == "override" or reason == "clicked" then
      data[SimpleShareEPGP.loot_index.action] = SimpleShareEPGP.VARS.reminder
      local update = data[SimpleShareEPGP.loot_index.update] ~= nil
      SimpleShareEPGP:addOrUpdateLoot(data,update)
      SimpleSharedEPGPLoot:Refresh()
      return
    elseif reason == "timeout" then
      return
    end
  end,
  OnShow = function()
    SimpleShareEPGP._menuFrame = SimpleShareEPGP._menuFrame or CreateFrame("Frame", "sepgp_auto_gp_menuframe", UIParent, "UIDropDownMenuTemplate")
  end,
  OnHide = function()
    CloseDropDownMenus()
  end,
  timeout = 0,
  exclusive = 1,
  whileDead = 1,
  hideOnEscape = 1
}
function SimpleShareEPGP:EasyMenu_Initialize(level, menuList)
  for i, info in ipairs(menuList) do
    if (info.text) then
      info.index = i
      UIDropDownMenu_AddButton( info, level )
    end
  end
end
function SimpleShareEPGP:EasyMenu(menuList, menuFrame, anchor, x, y, displayMode, level)
  if ( displayMode == "MENU" ) then
    menuFrame.displayMode = displayMode
  end
  UIDropDownMenu_Initialize(menuFrame, function() SimpleShareEPGP:EasyMenu_Initialize(level, menuList) end, displayMode, level)
  ToggleDropDownMenu(1, nil, menuFrame, anchor, x, y)
end

-- GLOBALS: sepgp_prices,sepgp_standings,sepgp_bids
