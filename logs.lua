local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")
local CP = AceLibrary("Compost-2.0")
local L = AceLibrary("AceLocale-2.2"):new("shootyepgp")

SimpleSharedEPGPLogs = SimpleShareEPGP:NewModule("SimpleSharedEPGPLogs", "AceDB-2.0")
SimpleSharedEPGPLogs.tmp = CP:Acquire()

function SimpleSharedEPGPLogs:OnEnable()
  if not T:IsRegistered("SimpleSharedEPGPLogs") then
    T:Register("SimpleSharedEPGPLogs",
      "children", function()
        T:SetTitle(L["shootyepgp logs"])
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() SimpleSharedEPGPLogs:Refresh() end
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
  if not T:IsAttached("SimpleSharedEPGPLogs") then
    T:Open("SimpleSharedEPGPLogs")
  end
end

function SimpleSharedEPGPLogs:OnDisable()
  T:Close("SimpleSharedEPGPLogs")
end

function SimpleSharedEPGPLogs:Refresh()
  T:Refresh("SimpleSharedEPGPLogs")
end

function SimpleSharedEPGPLogs:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "SimpleSharedEPGPLogs" then
      SimpleShareEPGP:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("SimpleSharedEPGPLogs") then
            T:Attach("SimpleSharedEPGPLogs")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end  
end

function SimpleSharedEPGPLogs:Top()
  if T:IsRegistered("SimpleSharedEPGPLogs") and (T.registry.SimpleSharedEPGPLogs.tooltip) then
    T.registry.SimpleSharedEPGPLogs.tooltip.scroll=0
  end  
end

function SimpleSharedEPGPLogs:Toggle(forceShow)
  self:Top()
  if T:IsAttached("SimpleSharedEPGPLogs") then
    T:Detach("SimpleSharedEPGPLogs") -- show
    if (T:IsLocked("SimpleSharedEPGPLogs")) then
      T:ToggleLocked("SimpleSharedEPGPLogs")
    end
    self:setHideScript()
  else
    if (forceShow) then
      SimpleSharedEPGPLogs:Refresh()
    else
      T:Attach("SimpleSharedEPGPLogs") -- hide
    end
  end  
end

function SimpleSharedEPGPLogs:reverse(arr)
  CP:Recycle(SimpleSharedEPGPLogs.tmp)
  for _,val in ipairs(arr) do
    table.insert(SimpleSharedEPGPLogs.tmp,val)
  end
  local i, j = 1, table.getn(SimpleSharedEPGPLogs.tmp)
  while i < j do
    SimpleSharedEPGPLogs.tmp[i], SimpleSharedEPGPLogs.tmp[j] = SimpleSharedEPGPLogs.tmp[j], SimpleSharedEPGPLogs.tmp[i]
    i = i + 1
    j = j - 1
  end
  return SimpleSharedEPGPLogs.tmp
end

function SimpleSharedEPGPLogs:BuildLogsTable()
  -- {timestamp,line}
  return self:reverse(SimpleSharedEPGPLog)
end

function SimpleSharedEPGPLogs:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 2,
      "text",  C:Orange(L["Time"]),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange(L["Action"]),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT"
    )
  local t = SimpleSharedEPGPLogs:BuildLogsTable()
  for i = 1, table.getn(t) do
    local timestamp, line = unpack(t[i])
    cat:AddLine(
      "text", C:Silver(timestamp),
      "text2", line
    )
  end  
end

-- GLOBALS: sepgp_bids
