local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")
local L = AceLibrary("AceLocale-2.2"):new("SimpleShareEPGPLocale")
local _G = getfenv(0)

SimpleShareEPGPStandings = SimpleShareEPGP:NewModule("SimpleShareEPGPStandings", "AceDB-2.0")
local groupings = {
  "groupbyclass",
  "groupbyarmor",
  "groupbyrole",
}
local PLATE, MAIL, LEATHER, CLOTH = 4,3,2,1
local DPS, CASTER, HEALER, TANK = 4,3,2,1
local class_to_armor = {
  PALADIN = PLATE,
  WARRIOR = PLATE,
  HUNTER = MAIL,
  SHAMAN = MAIL,
  DRUID = LEATHER,
  ROGUE = LEATHER,
  MAGE = CLOTH,
  PRIEST = CLOTH,
  WARLOCK = CLOTH,
}
local armor_text = {
  [CLOTH] = L["CLOTH"],
  [LEATHER] = L["LEATHER"],
  [MAIL] = L["MAIL"],
  [PLATE] = L["PLATE"],
}
local class_to_role = {
  PALADIN = {HEALER,DPS,TANK,CASTER},
  PRIEST = {HEALER,CASTER},
  DRUID = {HEALER,TANK,DPS,CASTER},
  SHAMAN = {HEALER,DPS,CASTER},
  MAGE = {CASTER},
  WARLOCK = {CASTER},
  ROGUE = {DPS},
  HUNTER = {DPS},
  WARRIOR = {TANK,DPS},
}
local role_text = {
  [TANK] = L["TANK"],
  [HEALER] = L["HEALER"],
  [CASTER] = L["CASTER"],
  [DPS] = L["PHYS DPS"],
}
local SimpleShareEPGPExport = CreateFrame("Frame", "SimpleShareEPGPExportFrame", UIParent)
SimpleShareEPGPExport:SetWidth(250)
SimpleShareEPGPExport:SetHeight(150)
SimpleShareEPGPExport:SetPoint('TOP', UIParent, 'TOP', 0,-80)
SimpleShareEPGPExport:SetFrameStrata('DIALOG')
SimpleShareEPGPExport:Hide()
SimpleShareEPGPExport:SetBackdrop({
  bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
  edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = {left = 5, right = 5, top = 5, bottom = 5}
})
SimpleShareEPGPExport:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
SimpleShareEPGPExport:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
SimpleShareEPGPExport.action = CreateFrame("Button","SimpleShareEPGPExportAction", SimpleShareEPGPExport, "UIPanelButtonTemplate")
SimpleShareEPGPExport.action:SetWidth(100)
SimpleShareEPGPExport.action:SetHeight(22)
SimpleShareEPGPExport.action:SetPoint("BOTTOM",0,-20)
SimpleShareEPGPExport.action:SetText("Import")
SimpleShareEPGPExport.action:Hide()
SimpleShareEPGPExport.action:SetScript("OnClick",function() SimpleShareEPGPStandings.import() end)
SimpleShareEPGPExport.title = SimpleShareEPGPExport:CreateFontString(nil,"OVERLAY")
SimpleShareEPGPExport.title:SetPoint("TOP",0,-5)
SimpleShareEPGPExport.title:SetFont("Fonts\\ARIALN.TTF", 12)
SimpleShareEPGPExport.title:SetWidth(200)
SimpleShareEPGPExport.title:SetJustifyH("LEFT")
SimpleShareEPGPExport.title:SetJustifyV("CENTER")
SimpleShareEPGPExport.title:SetShadowOffset(1, -1)
SimpleShareEPGPExport.edit = CreateFrame("EditBox", "SimpleShareEPGPExportEdit", SimpleShareEPGPExport)
SimpleShareEPGPExport.edit:SetMultiLine(true)
SimpleShareEPGPExport.edit:SetAutoFocus(true)
SimpleShareEPGPExport.edit:EnableMouse(true)
SimpleShareEPGPExport.edit:SetMaxLetters(0)
SimpleShareEPGPExport.edit:SetHistoryLines(1)
SimpleShareEPGPExport.edit:SetFont('Fonts\\ARIALN.ttf', 12, 'THINOUTLINE')
SimpleShareEPGPExport.edit:SetWidth(290)
SimpleShareEPGPExport.edit:SetHeight(190)
SimpleShareEPGPExport.edit:SetScript("OnEscapePressed", function() 
  SimpleShareEPGPExport.edit:SetText("")
  SimpleShareEPGPExport:Hide() 
end)
SimpleShareEPGPExport.edit:SetScript("OnEditFocusGained", function()
  SimpleShareEPGPExport.edit:HighlightText()
end)
SimpleShareEPGPExport.edit:SetScript("OnCursorChanged", function() 
  SimpleShareEPGPExport.edit:HighlightText()
end)
SimpleShareEPGPExport.AddSelectText = function(txt)
  SimpleShareEPGPExport.edit:SetText(txt)
  SimpleShareEPGPExport.edit:HighlightText()
end
SimpleShareEPGPExport.scroll = CreateFrame("ScrollFrame", "SimpleShareEPGPExportScroll", SimpleShareEPGPExport, 'UIPanelScrollFrameTemplate')
SimpleShareEPGPExport.scroll:SetPoint('TOPLEFT', SimpleShareEPGPExport, 'TOPLEFT', 8, -30)
SimpleShareEPGPExport.scroll:SetPoint('BOTTOMRIGHT', SimpleShareEPGPExport, 'BOTTOMRIGHT', -30, 8)
SimpleShareEPGPExport.scroll:SetScrollChild(SimpleShareEPGPExport.edit)
SimpleShareEPGP:make_escable("SimpleShareEPGPExportFrame","add")

function SimpleShareEPGPStandings:GetExportData()
  local t = {};
  local table_db = SimpleShareEPGP:init_table_db();
  for i, v in pairs(table_db) do
    local name = i;
    local ep = v.ep or 0;
    local gp = v.gp or SimpleShareEPGP.VARS.basegp;
    local class = "";

    if (v.class and SimpleShareEPGP.classNames[v.class]) then
      class = v.class;
    end
    table.insert(t, {name, ep, gp, ep/gp, class});
  end

  table.sort(t, function(a,b)
    if (a[4] ~= b[4]) then
      return tonumber(a[4]) > tonumber(b[4]);
    end
    return tostring(a[1]) < tostring(b[1]);
  end);

  local txt = "Name;EP;GP;PR;Class\n"
  for _,val in ipairs(t) do
    txt = string.format("%s%s;%d;%d;%.4f;%s\n", txt, val[1], val[2], val[3], val[4], val[5])
  end
  return txt;
end

function SimpleShareEPGPStandings:Export()
  SimpleShareEPGPExport.action:Hide();
  SimpleShareEPGPExport.title:SetText(C:Gold(L["Ctrl-C to copy. Esc to close."]));
  
  SimpleShareEPGPExport:Show();
  
  local txt = SimpleShareEPGPStandings:GetExportData();
  SimpleShareEPGPExport.AddSelectText(txt);
end

function SimpleShareEPGPExportSuperWoW()  
  if (not SimpleShareEPGP.SUPER_WOW) then
    return;
  end

  local timestamp = date("%d_%m_%yT%H_%M_%S");
  local txt = SimpleShareEPGPStandings:GetExportData();

  ExportFile(timestamp, txt);
  SimpleShareEPGP:defaultPrint(string.format("%s %s.txt", L["Export data with SuperWoW ExportFile"], timestamp));
end

function SimpleShareEPGPStandings:Import()
  if (not SimpleShareEPGP.isAdminUnit()) then return end
  SimpleShareEPGPExport.action:Show()
  SimpleShareEPGPExport.title:SetText(C:Red("Ctrl-V to paste data. Esc to close."))
  SimpleShareEPGPExport.AddSelectText(L.IMPORT_WARNING)
  SimpleShareEPGPExport:Show()
end

function SimpleShareEPGPStandings.import()
  if (not SimpleShareEPGP.isAdminUnit()) then return end
  local text = SimpleShareEPGPExport.edit:GetText()
  local importFaildString = L["Failed to import:\n"];
  local errorFlag = false;

  local tmpTable = {};
  for line in string.gfind(text,"[^\r\n]+") do
    local name,ep,gp,pr,class = SimpleShareEPGP:strsplit(";",line);
    ep,gp,pr = tonumber(ep),tonumber(gp),tonumber(pr);
    if (name) and (ep) and (gp) then
      table.insert(tmpTable, {name, ep, gp, pr, class});
    else
      importFaildString = string.format("%s%s\n",importFaildString,line)
      errorFlag = true;
    end
  end

  if (errorFlag) then
    SimpleShareEPGPExport.edit:SetText(importFaildString);
    SimpleShareEPGP:defaultPrint(L["Import cancelled due to invalid data"]);
  else
    SimpleShareEPGP:clean_table_db();
    local name, ep, gp, pr, class;
    
    for i=1,table.getn(tmpTable) do
      name, ep, gp, pr, class = tmpTable[i][1], tmpTable[i][2], tmpTable[i][3], tmpTable[i][4], tmpTable[i][5];
      SimpleShareEPGP:set_ep_value(name, ep);
      SimpleShareEPGP:set_gp_value(name, gp);
      if (class and SimpleShareEPGP.classNames[class]) then
        SimpleShareEPGP:set_class_value(name, class);
      end
    end
    SimpleShareEPGP:ClearLogs();

    SimpleShareEPGPExport.edit:SetText(L["Import finished"]);
    SimpleShareEPGP:defaultPrint(string.format(L["Imported %d members."], table.getn(tmpTable)));
  end
  SimpleShareEPGP:refreshPRTablets();
end

local class_cache = setmetatable({},{__index = function(t,k)
  local class
  if BC:HasReverseTranslation(k) then
    class = string.upper(BC:GetReverseTranslation(k))
  else
    class = string.upper(k)
  end
  if (class) then
    rawset(t,k,class)
    return class
  end
  return k
end})
function SimpleShareEPGPStandings:getArmorClass(class)
  class = class_cache[class]
  return class_to_armor[class] or 0
end

function SimpleShareEPGPStandings:getRolesClass(roster)
  local roster_num = table.getn(roster)
  for i=1,roster_num do
    local player = roster[i]
    local name, lclass, armor_class, ep, gp, pr = unpack(player)
    local class = class_cache[lclass]
    local roles = class_to_role[class]
    if not (roles) then
      player[3]=0
    else
      for i,role in ipairs(roles) do
        if i==1 then
          player[3]=role
        else
          table.insert(roster,{player[1],player[2],role,player[4],player[5],player[6]})
        end
      end      
    end
  end
  return roster
end 

function SimpleShareEPGPStandings:OnEnable()
  if not T:IsRegistered("SimpleShareEPGPStandings") then
    T:Register("SimpleShareEPGPStandings",
      "children", function()
        T:SetTitle(L["standings"])
        self:OnTooltipUpdate()
      end,
  		"showTitleWhenDetached", true,
  		"showHintWhenDetached", true,
  		"cantAttach", true,
  		"menu", function()
        D:AddLine(
          "text", L["Raid Only"],
          "tooltipText", L["Only show members in raid."],
          "checked", SimpleShareEPGPConfig.raidonly,
          "func", function() SimpleShareEPGPStandings:ToggleRaidOnly() end
        )      
        D:AddLine(
          "text", L["Group by class"],
          "tooltipText", L["Group members by class."],
          "checked", SimpleShareEPGPConfig.groupbyclass,
          "func", function() SimpleShareEPGPStandings:ToggleGroupBy("groupbyclass") end
        )
        D:AddLine(
          "text", L["Group by armor"],
          "tooltipText", L["Group members by armor."],
          "checked", SimpleShareEPGPConfig.groupbyarmor,
          "func", function() SimpleShareEPGPStandings:ToggleGroupBy("groupbyarmor") end
        )
        D:AddLine(
          "text", L["Group by roles"],
          "tooltipText", L["Group members by roles."],
          "checked", SimpleShareEPGPConfig.groupbyrole,
          "func", function() SimpleShareEPGPStandings:ToggleGroupBy("groupbyrole") end
        )
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() SimpleShareEPGPStandings:Refresh() end
        )

        if (SimpleShareEPGP.SUPER_WOW) then
          D:AddLine(
            "text", L["ExportFile (SuperWoW)"],
            "tooltipText", L["Export standings with SuperWoW function to csv"],
            "func", function() SimpleShareEPGPExportSuperWoW() end
          );
        end

        D:AddLine(
          "text", L["Export"],
          "tooltipText", L["Export standings to csv."],
          "func", function() SimpleShareEPGPStandings:Export() end
        )
        if (SimpleShareEPGP.isAdminUnit()) then
          D:AddLine(
            "text", L["Import"],
            "tooltipText", L["Import standings from csv."],
            "func", function() SimpleShareEPGPStandings:Import() end
          )
        end
  		end
    )
  end
  if not T:IsAttached("SimpleShareEPGPStandings") then
    T:Open("SimpleShareEPGPStandings")
  end
end

function SimpleShareEPGPStandings:OnDisable()
  T:Close("SimpleShareEPGPStandings")
end

function SimpleShareEPGPStandings:Refresh()
  T:Refresh("SimpleShareEPGPStandings")
end

function SimpleShareEPGPStandings:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "SimpleShareEPGPStandings" then
      SimpleShareEPGP:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("SimpleShareEPGPStandings") then
            T:Attach("SimpleShareEPGPStandings")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end  
end

function SimpleShareEPGPStandings:Top()
  if T:IsRegistered("SimpleShareEPGPStandings") and (T.registry.SimpleShareEPGPStandings.tooltip) then
    T.registry.SimpleShareEPGPStandings.tooltip.scroll=0
  end  
end

function SimpleShareEPGPStandings:Toggle(forceShow)
  self:Top()
  if T:IsAttached("SimpleShareEPGPStandings") then -- hidden
    T:Detach("SimpleShareEPGPStandings") -- show
    if (T:IsLocked("SimpleShareEPGPStandings")) then
      T:ToggleLocked("SimpleShareEPGPStandings")
    end
    self:setHideScript()
  else
    if (forceShow) then
      SimpleShareEPGPStandings:Refresh()
    else
      T:Attach("SimpleShareEPGPStandings") -- hide
    end
  end  
end

function SimpleShareEPGPStandings:ToggleGroupBy(setting)
  for _,value in ipairs(groupings) do
    if value ~= setting then
      SimpleShareEPGPConfig[value] = false;
    else
      SimpleShareEPGPConfig[setting] = not SimpleShareEPGPConfig[setting];
    end
  end
  self:Top()
  self:Refresh()
end

function SimpleShareEPGPStandings:ToggleRaidOnly()
  SimpleShareEPGPConfig.raidonly = not SimpleShareEPGPConfig.raidonly;
  self:Top()
  SimpleShareEPGP:SetRefresh(true)
end

local pr_sorter_standings = function(a,b)
  if SimpleShareEPGPCharacterConfig.minep > 0 then
    local a_over = a[4] - SimpleShareEPGPCharacterConfig.minep >= 0
    local b_over = b[4] - SimpleShareEPGPCharacterConfig.minep >= 0
    if a_over and b_over or (not a_over and not b_over) then
      if a[6] ~= b[6] then
        return tonumber(a[6]) > tonumber(b[6]);
      -- elseif a[4] ~= b[4] then
      --   return tonumber(a[4]) > tonumber(b[4]);
      end
      return tostring(a[1]) < tostring(b[1]);
    elseif a_over and (not b_over) then
      return true
    elseif b_over and (not a_over) then
      return false
    end
  else
    if a[6] ~= b[6] then
      return tonumber(a[6]) > tonumber(b[6]);
    -- elseif a[4] ~= b[4] then
    --   return tonumber(a[4]) > tonumber(b[4]);
    end
    return tostring(a[1]) < tostring(b[1]);
  end
end
-- Builds a standings table with record:
-- name, class, armor_class, roles, EP, GP, PR
-- and sorted by PR
function SimpleShareEPGPStandings:BuildStandingsTable()
  local table_db = SimpleShareEPGP:init_table_db();
  local t = { }
  local r = { }
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
  
  for i,v in pairs(table_db) do
    local name = i;
    local ep = (v.ep or 0);
    local gp = (v.gp or SimpleShareEPGP.VARS.basegp);
    local class = (v.class or SimpleShareEPGP.VARS.undefinedClass);

    local armor_class = self:getArmorClass(class);
    if (SimpleShareEPGPConfig.raidonly and next(r)) then
      if (r[name]) then
        table.insert(t, {name, class, armor_class, ep, gp, ep/gp});
      end
    else
      table.insert(t, {name, class, armor_class, ep, gp, ep/gp});
    end
  end

  if (SimpleShareEPGPConfig.groupbyclass) then
    table.sort(t, function(a,b)
      if (a[2] ~= b[2]) then return a[2] > b[2]
      else return pr_sorter_standings(a,b) end
    end)
  elseif (SimpleShareEPGPConfig.groupbyarmor) then
    table.sort(t, function(a,b)
      if (a[3] ~= b[3]) then return a[3] > b[3]
      else return pr_sorter_standings(a,b) end
    end)
  elseif (SimpleShareEPGPConfig.groupbyrole) then
    t = self:getRolesClass(t) -- we are subbing role into armor_class to avoid extra table creation
    table.sort(t, function(a,b)
    if (a[3] ~= b[3]) then return a[3] > b[3]
      else return pr_sorter_standings(a,b) end
    end)   
  else
    table.sort(t, pr_sorter_standings)
  end
  return t
end

function SimpleShareEPGPStandings:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 5,
      "text",  C:Copper(L["№"]),      "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",  "justify",  "LEFT",
      "text2", C:Copper(L["Name"]),   "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "LEFT",  "justify2", "LEFT",
      "text3", C:Copper(L["ep"]),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT", "justify3", "RIGHT",
      "text4", C:Copper(L["gp"]),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   1, "child_justify4", "RIGHT", "justify4", "RIGHT",
      "text5", C:Copper(L["pr"]),     "child_text5R",   1, "child_text5G",   1, "child_text5B",   0, "child_justify5", "RIGHT", "justify5", "RIGHT"
    )
  local t = self:BuildStandingsTable()
  local separator
  for i = 1, table.getn(t) do
    local name, class, armor_class, ep, gp, pr = unpack(t[i])
    if (SimpleShareEPGPConfig.groupbyarmor) or (SimpleShareEPGPConfig.groupbyrole) then
      if not (separator) then
        if (SimpleShareEPGPConfig.groupbyarmor) then
          separator = armor_text[armor_class]
        elseif (SimpleShareEPGPConfig.groupbyrole) then
          separator = role_text[armor_class]
        end
        if (separator) then
          cat:AddLine(
            "text", C:Green(separator),
            "text2", "",
            "text3", "",
            "text4", "",
            "text5", ""
          )
        end
      else
        local last_separator = separator
        if (SimpleShareEPGPConfig.groupbyarmor) then
          separator = armor_text[armor_class]
        elseif (SimpleShareEPGPConfig.groupbyrole) then
          separator = role_text[armor_class]
        end
        if (separator) and (separator ~= last_separator) then
          cat:AddLine(
            "text", C:Green(separator),
            "text2", "",
            "text3", "",
            "text4", "",
            "text5", ""
          )          
        end
      end
    end
    local text = C:Colorize(BC:GetHexColor(class), name)
    local text2, text4
    if SimpleShareEPGPCharacterConfig.minep > 0 and ep < SimpleShareEPGPCharacterConfig.minep then
      text2 = C:Red(string.format("%.4g", ep))
      text4 = C:Red(string.format("%.4g", pr))
    else
      text2 = string.format("%.4g", ep)
      text4 = string.format("%.4g", pr)
    end
    local text3 = string.format("%.4g", gp)    
    if (SimpleShareEPGP._playerName and SimpleShareEPGP._playerName == name) then
      text = string.format("(*)%s",text)
      local pr_decay = SimpleShareEPGP:capcalc(ep,gp)
      if pr_decay < 0 then
        text4 = string.format("%s(|cffff0000%.4g|r)",text4,pr_decay)
      end
    end
    cat:AddLine(
      "text", C:Silver(i),
      "text2", text,
      "text3", text2,
      "text4", text3,
      "text5", text4
    )
  end
end
