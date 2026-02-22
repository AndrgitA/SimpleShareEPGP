local GetTime = GetTime;
local string_find, string_format = string.find, string.format;
local tonumber = tonumber;
local string_gfind = string.gfind or string.gmatch;
local UnitInRaid = UnitInRaid;

local L = AceLibrary("AceLocale-2.2"):new("SimpleShareEPGPLocale");

local sourceData = {
  token = "",
  source = "",

  controlSumm = 0,
  count = 0,
  buffer = nil,
  
  countAtStart = 0,
  controlSummAtEnd = 0,
};

local syncChannel = "RAID";
local limitChunkSize = 5;
local triggerDone = nil;

SimpleShareEPGPSync = SimpleShareEPGP:NewModule("SimpleShareEPGPSync", "AceDB-2.0");
SimpleShareEPGPSync.isSyncing = false;
SimpleShareEPGPSync.isStartingSync = false;
SimpleShareEPGPSync.isEndSync = false;

function SimpleShareEPGPSync:initSourceData(token, source, countAtStart)
  if (not token or not source or not countAtStart) then
    return;
  end

  sourceData.token = token;
  sourceData.source = source;
  sourceData.controlSumm = 0;
  sourceData.countAtStart = countAtStart;
  sourceData.count = 0;
  sourceData.buffer = {};
end

function SimpleShareEPGPSync:isCanShareStart(silence)
  -- if (not SimpleShareEPGPCharacterConfig.syncEnabled) then
  --   if (not silence) then
  --     SimpleShareEPGP:defaultPrint(L["You are not enable sync option"]);
  --     UIErrorsFrame:AddMessage(L["You are not enable sync option"], 1, 0, 0);
  --   end
  --   return false;
  -- end

  if (not SimpleShareEPGP:isAdminUnit()) then
    if (not silence) then
      SimpleShareEPGP:defaultPrint(L["You are not admin"]);
      UIErrorsFrame:AddMessage(L["You are not admin"], 1, 0, 0);
    end
    return false;
  end

  if (not UnitInRaid("player")) then
    if (not silence) then
      SimpleShareEPGP:defaultPrint(L["You are not in Raid"]);
      UIErrorsFrame:AddMessage(L["You are not in Raid"], 1, 0, 0);
      return false;
    end
  end
  
  if (not SimpleShareEPGP:lootMaster()) then 
    if (not silence) then
      SimpleShareEPGP:defaultPrint(L["You are not MasterLooter"]);
      UIErrorsFrame:AddMessage(L["You are not MasterLooter"], 1, 0, 0);
    end
    return false;
  end

  return true;
end

function SimpleShareEPGPSync:CreateToken()
  local token = SimpleShareEPGP:strsplit(".", GetTime());

  return token;
end

function SimpleShareEPGPSync:anounceSyncMessage(msg)
  if (not ChatThrottleLib or not msg or msg == "") then
    return;
  end

  ChatThrottleLib:SendAddonMessage("BULK", SimpleShareEPGP.VARS.prefix, msg, syncChannel);
end

local function getSyncMessage(cmd, text, token)
  if (not (cmd and text and token)) then
    return "";
  end
  return string_format("%s;%s;%s", cmd, text, token);
end

function SimpleShareEPGPSync:StartSync()
  if (not SimpleShareEPGPSync:isCanShareStart()) then
    return;
  end

  local db = SimpleShareEPGP:GetCopyDB();
  
  if (type(db) ~= "table") then
    return;
  end

  local flatDB = {};
  local name, ep, gp, class;
  for i, v in pairs(db) do
    name = i;
    ep = v.ep or 0;
    gp = v.gp or SimpleShareEPGP.VARS.basegp;
    class = "";
    
    if (v.class and SimpleShareEPGP.classNames[v.class]) then
      class = v.class;
    end
    
    table.insert(flatDB, {name, ep, gp, class});
  end

  local countFlatDBLines = table.getn(flatDB);

  -- break if empty db;
  if (countFlatDBLines == 0) then
    return;
  end

  local token = SimpleShareEPGPSync:CreateToken();
  
  -- isLootMasterFlag:CountChunks
  local tmpMessage = string_format("%d:%d", 1, countFlatDBLines);
  SimpleShareEPGPSync:anounceSyncMessage(getSyncMessage(SimpleShareEPGP.CMD_ADDON_MSG.SYNCS, tmpMessage, token));


  tmpMessage = "";
  local countInMessage = 0;
  local controlValue = 0;
  
  for i,v in ipairs(flatDB) do
    countInMessage = countInMessage + 1;
    controlValue = controlValue + i + v[2] + v[3];
    -- index:name:ep:gp:class$
    tmpMessage = string_format("%s%d:%s:%d:%d:%s*", tmpMessage, i, v[1], v[2], v[3], v[4]);
    
    if (countInMessage == limitChunkSize) then
      countInMessage = 0;
      SimpleShareEPGPSync:anounceSyncMessage(getSyncMessage(SimpleShareEPGP.CMD_ADDON_MSG.SYNCM, tmpMessage, token));
      tmpMessage = "";
    end
  end

  if (countInMessage > 0) then
    SimpleShareEPGPSync:anounceSyncMessage(getSyncMessage(SimpleShareEPGP.CMD_ADDON_MSG.SYNCM, tmpMessage, token));
  end

  -- controlValue
  tmpMessage = string_format("%d", controlValue);
  SimpleShareEPGPSync:anounceSyncMessage(getSyncMessage(SimpleShareEPGP.CMD_ADDON_MSG.SYNCE, tmpMessage, token));

  SimpleShareEPGP:defaultPrint(L["Data transfer completed."]);
end

function SimpleShareEPGPSync:RegisterDoneSync(func)
  if (type(func) ~= "function") then
    return;
  end

  triggerDone = func;
end

function SimpleShareEPGPSync:parseStartSync(data, token, sender)
  local _, _, isMasterLooter, countAtStart = string_find(data, "(%d+):(%d+)");
  isMasterLooter = tonumber(isMasterLooter);
  countAtStart = tonumber(countAtStart);
  if (isMasterLooter == 1 and countAtStart > 0) then
    SimpleShareEPGPSync:initSourceData(token, sender, countAtStart);
    SimpleShareEPGPSync.isSyncing = true;
  end
end

function SimpleShareEPGPSync:parseSyncMessage(data, token, sender)
  if (sourceData.token ~= token or sourceData.source ~= sender) then
    return;
  end

  for index, name, ep, gp, class in string_gfind(data, "([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)%*") do
    index = tonumber(index);
    ep = tonumber(ep);
    gp = tonumber(gp);
    if (not (index and ep and gp and name)) then
      -- break all sync process, if u have bad data
      sourceData.token = "";
      SimpleShareEPGPSync.isSyncing = false;
      return;
    end

    if (not class or not SimpleShareEPGP.classNames[class]) then
      class = SimpleShareEPGP.VARS.undefinedClass;
    end

    sourceData.buffer[name] = {
      ep = ep,
      gp = gp,
      class = class,
    };

    sourceData.count = sourceData.count + 1;
    sourceData.controlSumm = sourceData.controlSumm + index + ep + gp;
  end

  SimpleShareEPGPSync:ValidationApplySync();
end

function SimpleShareEPGPSync:parseEndSync(data, token, sender)
  if (sourceData.token ~= token or sourceData.source ~= sender) then
    return;
  end

  local _, _, controllSumm = string_find(data, "(%d+)");
  controllSumm = tonumber(controllSumm);

  if (controllSumm > 0) then
    sourceData.controlSummAtEnd = controllSumm;
  end

  SimpleShareEPGPSync.isSyncing = false;

  SimpleShareEPGPSync:ValidationApplySync();
end

function SimpleShareEPGPSync:parserMessage(command, data, token, sender)
  if (command == SimpleShareEPGP.CMD_ADDON_MSG.SYNCS) then
    SimpleShareEPGPSync:parseStartSync(data, token, sender);
    
  elseif (command == SimpleShareEPGP.CMD_ADDON_MSG.SYNCM) then
    SimpleShareEPGPSync:parseSyncMessage(data, token, sender);
  elseif (command == SimpleShareEPGP.CMD_ADDON_MSG.SYNCE) then
    SimpleShareEPGPSync:parseEndSync(data, token, sender);
  end
end

function SimpleShareEPGPSync:ValidationApplySync()
  if (SimpleShareEPGPSync.isSyncing ~= false) then
    return false;
  end

  local realCount = 0;
  for _ in pairs(sourceData.buffer) do
    realCount = realCount + 1;
  end

  if (realCount ~= sourceData.count) then
    return false;
  end

  if (sourceData.controlSummAtEnd ~= sourceData.controlSumm) then
    return false;
  end

  if (triggerDone) then
    triggerDone(sourceData.buffer, sourceData.source);
  end

  return true;
end