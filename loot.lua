local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")
local L = AceLibrary("AceLocale-2.2"):new("SimpleShareEPGPLocale")

SimpleShareEPGPLoot = SimpleShareEPGP:NewModule("SimpleShareEPGPLoot", "AceDB-2.0")

function SimpleShareEPGPLoot:OnEnable()
  if not T:IsRegistered("SimpleShareEPGPLoot") then
    T:Register("SimpleShareEPGPLoot",
      "children", function()
        T:SetTitle(L["loot info"])
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() SimpleShareEPGPLoot:Refresh() end
        )
        D:AddLine(
          "text", L["Clear"],
          "tooltipText", L["Clear Loot."],
          "func", function() SimpleShareEPGP:ClearLoot() end
        )        
      end      
    )
  end
  if not T:IsAttached("SimpleShareEPGPLoot") then
    T:Open("SimpleShareEPGPLoot")
  end
end

function SimpleShareEPGPLoot:OnDisable()
  T:Close("SimpleShareEPGPLoot")
end

function SimpleShareEPGPLoot:Refresh()
  T:Refresh("SimpleShareEPGPLoot")
end

function SimpleShareEPGPLoot:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "SimpleShareEPGPLoot" then
      SimpleShareEPGP:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("SimpleShareEPGPLoot") then
            T:Attach("SimpleShareEPGPLoot")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end  
end

function SimpleShareEPGPLoot:Top()
  if T:IsRegistered("SimpleShareEPGPLoot") and (T.registry.SimpleShareEPGPLoot.tooltip) then
    T.registry.SimpleShareEPGPLoot.tooltip.scroll=0
  end  
end

function SimpleShareEPGPLoot:Toggle(forceShow)
  self:Top()
  if T:IsAttached("SimpleShareEPGPLoot") then
    T:Detach("SimpleShareEPGPLoot") -- show
    if (T:IsLocked("SimpleShareEPGPLoot")) then
      T:ToggleLocked("SimpleShareEPGPLoot")
    end
    self:setHideScript()
  else
    if (forceShow) then
      SimpleShareEPGPLoot:Refresh()
    else
      T:Attach("SimpleShareEPGPLoot") -- hide
    end
  end  
end

function SimpleShareEPGPLoot:BuildLootTable()
  table.sort(SimpleShareEPGPLooted, function(a,b)
    if (a[1] ~= b[1]) then return a[1] > b[1]
    else return a[2] > b[2] end
  end)
  return SimpleShareEPGPLooted;
end

function SimpleShareEPGPLoot:OnClickItem(data)

end

function SimpleShareEPGPLoot:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 5,
      "text",  C:Orange(L["Time"]),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange(L["Item"]),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   0, "child_justify2", "LEFT",
      "text3", C:Orange(L["Binds"]),  "child_text3R",   0, "child_text3G",   1, "child_text3B",   0, "child_justify3", "CENTER",
      "text4", C:Orange(L["Looter"]),  "child_text4R",   0, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT",
      "text5", C:Orange(L["GP Action"]),  "child_text5R",   0, "child_text5G",   1, "child_text5B",   0, "child_justify5", "RIGHT"         
    )
  local t = self:BuildLootTable()
  for i = 1, table.getn(t) do
    local timestamp,player,player_color,itemLink,bind,price,off_price,action = unpack(t[i])
    cat:AddLine(
      "text", timestamp,
      "text2", itemLink,
      "text3", bind,
      "text4", player_color,
      "text5", action--,
--      "func", "OnClickItem", "arg1", self, "arg2", t[i]
    )
  end
end
