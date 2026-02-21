local GetTime = GetTime;
local string_find, string_format = string.find, string.format;
local tonumber = tonumber;
local string_gfind = string.gfind or string.gmatch;

local L = AceLibrary("AceLocale-2.2"):new("SimpleShareEPGPLocale");

local consumerData = {
  token = "",
  source = "",

  controlSumm = 0,
  count = 0,
  buffer = nil,
  
  countAtStart = 0,
  controlSummAtEnd = 0,
};

local prefixSyncStart = "SYNCS";
local prefixSyncMessage = "SYNCM";
local prefixSyncEnd = "SYNCE";

local syncChannel = "RAID";
local limitChunkSize = 5;
local triggerDone = nil;

SimpleShareEPGPSync = SimpleShareEPGP:NewModule("SimpleShareEPGPSync", "AceDB-2.0");
SimpleShareEPGPSync.prefixSyncStart = prefixSyncStart;
SimpleShareEPGPSync.prefixSyncMessage = prefixSyncMessage;
SimpleShareEPGPSync.prefixSyncEnd = prefixSyncEnd;
SimpleShareEPGPSync.isSyncing = false;
SimpleShareEPGPSync.isStartingSync = false;
SimpleShareEPGPSync.isEndSync = false;

function SimpleShareEPGPSync:initConsumerData(token, source, countAtStart)
  if (not token or not source or not countAtStart) then
    return;
  end

  consumerData.token = token;
  consumerData.source = source;
  consumerData.controlSumm = 0;
  consumerData.countAtStart = countAtStart;
  consumerData.count = 0;
  consumerData.buffer = {};
end

function SimpleShareEPGPSync:isCanShareStart(silence)
  if (not SimpleShareEPGPCharacterConfig.syncEnabled) then
    if (not silence) then
      SimpleShareEPGP:defaultPrint(L["You are not enable sync option"]);
      UIErrorsFrame:AddMessage(L["You are not enable sync option"], 1, 0, 0);
    end
    return false;
  end

  if (not SimpleShareEPGP:isAdminUnit()) then
    if (not silence) then
      SimpleShareEPGP:defaultPrint(L["You are not admin"]);
      UIErrorsFrame:AddMessage(L["You are not admin"], 1, 0, 0);
    end
    return false;
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
  if (not ChatThrottleLib) then
    return;
  end

  ChatThrottleLib:SendAddonMessage("BULK", SimpleShareEPGP.VARS.prefix, msg, syncChannel);
end

local function getStartSyncMessage(text, token)
  return string_format("%s;%s;%s", prefixSyncStart, text, token);
end

local function getSyncMessage(text, token)
  return string_format("%s;%s;%s", prefixSyncMessage, text, token);
end

local function getEndSyncMessage(text, token)
  return string_format("%s;%s;%s", prefixSyncEnd, text, token);
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
  SimpleShareEPGPSync:anounceSyncMessage(getStartSyncMessage(tmpMessage, token));


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
      SimpleShareEPGPSync:anounceSyncMessage(getSyncMessage(tmpMessage, token));
      tmpMessage = "";
    end
  end

  if (countInMessage > 0) then
    SimpleShareEPGPSync:anounceSyncMessage(getSyncMessage(tmpMessage, token));
  end

  -- controlValue
  tmpMessage = string_format("%d", controlValue);
  SimpleShareEPGPSync:anounceSyncMessage(getEndSyncMessage(tmpMessage, token));

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
    SimpleShareEPGPSync:initConsumerData(token, sender, countAtStart);
    SimpleShareEPGPSync.isSyncing = true;
  end
end

function SimpleShareEPGPSync:parseSyncMessage(data, token, sender)
  if (consumerData.token ~= token or consumerData.source ~= sender) then
    return;
  end

  for index, name, ep, gp, class in string_gfind(data, "([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)%*") do
    index = tonumber(index);
    ep = tonumber(ep);
    gp = tonumber(gp);
    if (not (index and ep and gp and name)) then
      return;
    end

    if (not class or not SimpleShareEPGP.classNames[class]) then
      class = SimpleShareEPGP.VARS.undefinedClass;
    end

    consumerData.buffer[name] = {
      ep = ep,
      gp = gp,
      class = class,
    };

    consumerData.count = consumerData.count + 1;
    consumerData.controlSumm = consumerData.controlSumm + index + ep + gp;
  end

  SimpleShareEPGPSync:ValidationApplySync();
end

function SimpleShareEPGPSync:parseEndSync(data, token, sender)
  if (consumerData.token ~= token or consumerData.source ~= sender) then
    return;
  end

  local _, _, controllSumm = string_find(data, "(%d+)");
  controllSumm = tonumber(controllSumm);

  if (controllSumm > 0) then
    consumerData.controlSummAtEnd = controllSumm;
  end

  SimpleShareEPGPSync.isSyncing = false;

  SimpleShareEPGPSync:ValidationApplySync();
end

function SimpleShareEPGPSync:parserMessage(command, data, token, sender)
  if (command == prefixSyncStart) then
    SimpleShareEPGPSync:parseStartSync(data, token, sender);
    
  elseif (command == prefixSyncMessage) then
    SimpleShareEPGPSync:parseSyncMessage(data, token, sender);
  elseif (command == prefixSyncEnd) then
    SimpleShareEPGPSync:parseEndSync(data, token, sender);
  end
end

function SimpleShareEPGPSync:ValidationApplySync()
  if (SimpleShareEPGPSync.isSyncing ~= false) then
    return false;
  end

  local realCount = 0;
  for _ in pairs(consumerData.buffer) do
    realCount = realCount + 1;
  end

  if (realCount ~= consumerData.count) then
    return false;
  end

  if (consumerData.controlSummAtEnd ~= consumerData.controlSumm) then
    return false;
  end

  if (triggerDone) then
    triggerDone(consumerData.buffer, consumerData.source);
  end

  return true;
end