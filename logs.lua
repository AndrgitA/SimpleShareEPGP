local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")
local CP = AceLibrary("Compost-2.0")
local L = AceLibrary("AceLocale-2.2"):new("SimpleShareEPGPLocale")

SimpleShareEPGPLogs = SimpleShareEPGP:NewModule("SimpleShareEPGPLogs", "AceDB-2.0")
SimpleShareEPGPLogs.tmp = CP:Acquire()

function SimpleShareEPGPLogs:OnEnable()
  if not T:IsRegistered("SimpleShareEPGPLogs") then
    T:Register("SimpleShareEPGPLogs",
      "children", function()
        T:SetTitle(L["logs"])
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() SimpleShareEPGPLogs:Refresh() end
        )
        D:AddLine(
          "text", L["Clear"],
          "tooltipText", L["Clear Logs."],
          "func", function()
            SimpleShareEPGP:ClearLogs();
          end
        )
      end      
    )
  end
  if not T:IsAttached("SimpleShareEPGPLogs") then
    T:Open("SimpleShareEPGPLogs")
  end
end

function SimpleShareEPGPLogs:OnDisable()
  T:Close("SimpleShareEPGPLogs")
end

function SimpleShareEPGPLogs:Refresh()
  T:Refresh("SimpleShareEPGPLogs")
end

function SimpleShareEPGPLogs:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "SimpleShareEPGPLogs" then
      SimpleShareEPGP:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("SimpleShareEPGPLogs") then
            T:Attach("SimpleShareEPGPLogs")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end  
end

function SimpleShareEPGPLogs:Top()
  if T:IsRegistered("SimpleShareEPGPLogs") and (T.registry.SimpleShareEPGPLogs.tooltip) then
    T.registry.SimpleShareEPGPLogs.tooltip.scroll=0
  end  
end

function SimpleShareEPGPLogs:Toggle(forceShow)
  self:Top()
  if T:IsAttached("SimpleShareEPGPLogs") then
    T:Detach("SimpleShareEPGPLogs") -- show
    if (T:IsLocked("SimpleShareEPGPLogs")) then
      T:ToggleLocked("SimpleShareEPGPLogs")
    end
    self:setHideScript()
  else
    if (forceShow) then
      SimpleShareEPGPLogs:Refresh()
    else
      T:Attach("SimpleShareEPGPLogs") -- hide
    end
  end  
end

function SimpleShareEPGPLogs:reverse(arr)
  CP:Recycle(SimpleShareEPGPLogs.tmp)
  for _,val in ipairs(arr) do
    table.insert(SimpleShareEPGPLogs.tmp,val)
  end
  local i, j = 1, table.getn(SimpleShareEPGPLogs.tmp)
  while i < j do
    SimpleShareEPGPLogs.tmp[i], SimpleShareEPGPLogs.tmp[j] = SimpleShareEPGPLogs.tmp[j], SimpleShareEPGPLogs.tmp[i]
    i = i + 1
    j = j - 1
  end
  return SimpleShareEPGPLogs.tmp
end

function SimpleShareEPGPLogs:BuildLogsTable()
  -- {timestamp,line}
  return self:reverse(SimpleShareEPGPLog)
end

function SimpleShareEPGPLogs:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 2,
      "text",  C:Orange(L["Time"]),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange(L["Action"]),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT"
    )
  local t = SimpleShareEPGPLogs:BuildLogsTable()
  for i = 1, table.getn(t) do
    local timestamp, line = unpack(t[i])
    cat:AddLine(
      "text", C:Silver(timestamp),
      "text2", line
    )
  end  
end
