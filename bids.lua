local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")
local L = AceLibrary("AceLocale-2.2"):new("shootyepgp")

sepgp_bids = SimpleShareEPGP:NewModule("sepgp_bids", "AceDB-2.0", "AceEvent-2.0")

function sepgp_bids:OnEnable()
  if not T:IsRegistered("sepgp_bids") then
    T:Register("sepgp_bids",
      "children", function()
        T:SetTitle(L["shootyepgp bids"])
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() sepgp_bids:Refresh() end
        )
      end      
    )
  end
  if not T:IsAttached("sepgp_bids") then
    T:Open("sepgp_bids")
  end
end

function sepgp_bids:OnDisable()
  T:Close("sepgp_bids")
end

function sepgp_bids:Refresh()
  T:Refresh("sepgp_bids")
end

function sepgp_bids:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "sepgp_bids" then
      SimpleShareEPGP:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("sepgp_bids") then
            T:Attach("sepgp_bids")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end  
end

function sepgp_bids:Top()
  if T:IsRegistered("sepgp_bids") and (T.registry.sepgp_bids.tooltip) then
    T.registry.sepgp_bids.tooltip.scroll=0
  end  
end

function sepgp_bids:Toggle(forceShow)
  self:Top()
  if T:IsAttached("sepgp_bids") then
    T:Detach("sepgp_bids") -- show
    if (T:IsLocked("sepgp_bids")) then
      T:ToggleLocked("sepgp_bids")
    end
    self:setHideScript()
  else
    if (forceShow) then
      sepgp_bids:Refresh()
    else
      T:Attach("sepgp_bids") -- hide
    end
  end  
end

function sepgp_bids:announceWinnerMS(name, pr)
  SimpleShareEPGP:widestAudience(string.format(L["Winning Mainspec Bid: %s (%.03f PR)"],name,pr))
end

function sepgp_bids:announceWinnerOS(name, pr)
  SimpleShareEPGP:widestAudience(string.format(L["Winning Offspec Bid: %s (%.03f PR)"],name,pr))
end

function sepgp_bids:countdownCounter()
  self._counter = (self._counter or 6) - 1
  if GetNumRaidMembers()>0 and self._counter > 0 then
    self._counterText = C:Yellow(tostring(self._counter))
    SimpleShareEPGP:widestAudience(tostring(self._counter))
    --SendChatMessage(tostring(self._counter),"RAID")
    self:Refresh()
  end
end

function sepgp_bids:countdownFinish(reset)
  if self:IsEventScheduled("shootyepgpBidCountdown") then
    self:CancelScheduledEvent("shootyepgpBidCountdown")
  end
  self._counter = 6
  if (reset) then
    self._counterText = C:Green("Starting")
  else
    self._counterText = C:Red("Finished")
  end
  self:Refresh()
end

function sepgp_bids:bidCountdown()
  self:countdownFinish(true)
  self:ScheduleRepeatingEvent("shootyepgpBidCountdown",self.countdownCounter,1,self)
  self:ScheduleEvent("shootyepgpBidCountdownFinish",self.countdownFinish,6,self)
end

local pr_sorter_bids = function(a,b)
  if (SimpleSharedEPGPCharacterConfig.minep > 0) then
    local a_over = a[3] - SimpleSharedEPGPCharacterConfig.minep >= 0
    local b_over = b[3] - SimpleSharedEPGPCharacterConfig.minep >= 0
    if a_over and b_over or (not a_over and not b_over) then
      if a[5] ~= b[5] then
        return tonumber(a[5]) > tonumber(b[5])
      else
        return tonumber(a[3]) > tonumber(b[3])
      end
    elseif a_over and (not b_over) then
      return true
    elseif b_over and (not a_over) then
      return false
    end
  else
    if a[5] ~= b[5] then
      return tonumber(a[5]) > tonumber(b[5])
    else
      return tonumber(a[3]) > tonumber(b[3])
    end
  end
end

function sepgp_bids:BuildBidsTable()
  -- {name,class,ep,gp,ep/gp[,main]}
  table.sort(SimpleShareEPGP.bids_main, pr_sorter_bids);
  table.sort(SimpleShareEPGP.bids_off, pr_sorter_bids);
  return SimpleShareEPGP.bids_main, SimpleShareEPGP.bids_off;
end

function sepgp_bids:OnTooltipUpdate()
  if not (SimpleShareEPGP.bid_item and SimpleShareEPGP.bid_item.link) then return end
  local link = SimpleShareEPGP.bid_item.link;
  local itemName = SimpleShareEPGP.bid_item.name;
  local price = SimpleShareEPGPPrices:GetPrice(link, SimpleSharedEPGPCharacterConfig.progress);
  local offspec;
  if not price then 
    price = "<n/a>";
    offspec = "<n/a>";
  else
    offspec = math.floor(price * SimpleSharedEPGPCharacterConfig.discount);
  end
  local bidcat = T:AddCategory(
      "columns", 3,    
      "text", C:Orange("Bid Item"), "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("GP Cost"),     "child_text2R", 50/255, "child_text2G", 205/255, "child_text2B", 50/255, "child_justify2", "RIGHT",
      "text3", C:Orange("OffSpec"),  "child_text3R", 32/255, "child_text3G", 178/255, "child_text3B", 170/255, "child_justify3", "RIGHT",      
      "hideBlankLine", true
    )
  bidcat:AddLine(
      "text", itemName,
      "text2", price,
      "text3", offspec
    )
  local countdownHeader = T:AddCategory(
      "columns", 2,
      "text","","child_textR",  1, "child_textG",  1, "child_textB",  1,"child_justify", "LEFT",
      "text2","","child_text2R",  1, "child_text2G",  1, "child_text2B",  1,"child_justify2", "CENTER",
      "hideBlankLine", true
    )
  countdownHeader:AddLine(
      "text", C:Green(L["Countdown"]), 
      "text2", self._counterText, 
      "func", "bidCountdown", "arg1", self
    )  
  local maincatHeader = T:AddCategory(
      "columns", 1,
      "text", C:Gold("MainSpec Bids")
    ):AddLine("text","")
  local maincat = T:AddCategory(
      "columns", 5,
      "text",  C:Orange("Name"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("ep"),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT",
      "text3", C:Orange("gp"),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange("pr"),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT",
      "text5", C:Orange("Main"),     "child_text5R",   1, "child_text5G",   1, "child_text5B",   0, "child_justify5", "RIGHT",      
      "hideBlankLine", true
    )
  local tm = self:BuildBidsTable()
  for i = 1, table.getn(tm) do
    local name, class, ep, gp, pr, main = unpack(tm[i])
    local namedesc
    if (main) then
      namedesc = string.format("%s(%s)", C:Colorize(BC:GetHexColor(class), name), L["Alt"])
    else
      namedesc = C:Colorize(BC:GetHexColor(class), name)
    end
    local text2, text4
    if SimpleSharedEPGPCharacterConfig.minep > 0 and ep < SimpleSharedEPGPCharacterConfig.minep then
      text2 = C:Red(string.format("%.4g", ep))
      text4 = C:Red(string.format("%.4g", pr))
    else
      text2 = string.format("%.4g", ep)
      text4 = string.format("%.4g", pr)
    end   
    maincat:AddLine(
      "text", namedesc,
      "text2", text2,
      "text3", string.format("%.4g", gp),
      "text4", text4,
      "text5", (main or ""),
      "func", "announceWinnerMS", "arg1", self, "arg2", name, "arg3", pr
    )
  end
  local offcatHeader = T:AddCategory(
      "columns", 1,
      "text", C:Silver("OffSpec Bids")
    ):AddLine("text","") 
  local offcat = T:AddCategory(
      "columns", 5,
      "text",  C:Orange("Name"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("ep"),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT",
      "text3", C:Orange("gp"),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange("pr"),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT",
      "text5", C:Orange("Main"),     "child_text5R",   1, "child_text5G",   1, "child_text5B",   0, "child_justify5", "RIGHT",      
      "hideBlankLine", true
    )
  local _,to = self:BuildBidsTable()
  for i = 1, table.getn(to) do
    local name, class, ep, gp, pr, main = unpack(to[i])
    local namedesc
    if (main) then
      namedesc = string.format("%s%(%s%)", C:Colorize(BC:GetHexColor(class), name), L["Alt"])
    else
      namedesc = C:Colorize(BC:GetHexColor(class), name)
    end
    local text2, text4
    if SimpleSharedEPGPCharacterConfig.minep > 0 and ep < SimpleSharedEPGPCharacterConfig.minep then
      text2 = C:Red(string.format("%.4g", ep))
      text4 = C:Red(string.format("%.4g", pr))
    else
      text2 = string.format("%.4g", ep)
      text4 = string.format("%.4g", pr)
    end    
    offcat:AddLine(
      "text", namedesc,
      "text2", text2,
      "text3", string.format("%.4g", gp),
      "text4", text4,
      "text5", (main or ""),
      "func", "announceWinnerOS", "arg1", self, "arg2", name, "arg3", pr
    )
  end   
end

-- GLOBALS: sepgp_standings,sepgp_bids
