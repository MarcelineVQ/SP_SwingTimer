
local version = "6.0.0"

local defaults = {
	x = 0,
	y = -150,
	w = 200,
	h = 10,
	b = 2,
	a = 1,
	s = 1,
	vo = -2,
	ho = 0,
	move = "off",
	icons = 1,
	bg = 1,
	timers = 1,
	style = 2,
	show_oh = true,
	show_range = true,
}

local default_bg1 = nil
local default_bg2 = nil
local default_bg3 = nil

local settings = {
	x = "Bar X position",
	y = "Bar Y position",
	w = "Bar width",
	h = "Bar height",
	b = "Border height",
	a = "Alpha between 0 and 1",
	s = "Bar scale",
	vo = "Offhand bar vertical offset",
	ho = "Offhand bar horizontal offset",
	icons = "Show weapon icons (1 = show, 0 = hide)",
	bg = "Show background (1 = show, 0 = hide)",
	timers = "Show weapon timers (1 = show, 0 = hide)",
	style = "Choose 1, 2, 3, 4, 5 or 6",
	move = "Enable bars movement",
}

local armorDebuffs = {
	["Interface\\Icons\\Ability_Warrior_Sunder"] = 450, 
	["Interface\\Icons\\Spell_Shadow_Unholystrength"] = 640, 
	["Interface\\Icons\\Spell_Nature_Faeriefire"] = 505, 
	["Interface\\Icons\\Ability_Warrior_Riposte"] = 2550,
	["Interface\\Icons\\Inv_Axe_12"] = 200
}
local combatStrings = {
	SPELLLOGSELFOTHER,			-- Your %s hits %s for %d.
	SPELLLOGCRITSELFOTHER,		-- Your %s crits %s for %d.
	SPELLDODGEDSELFOTHER,		-- Your %s was dodged by %s.
	SPELLPARRIEDSELFOTHER,		-- Your %s is parried by %s.
	SPELLMISSSELFOTHER,			-- Your %s missed %s.
	SPELLBLOCKEDSELFOTHER,		-- Your %s was blocked by %s.
	SPELLDEFLECTEDSELFOTHER,	-- Your %s was deflected by %s.
	SPELLEVADEDSELFOTHER,		-- Your %s was evaded by %s.
	SPELLIMMUNESELFOTHER,		-- Your %s failed. %s is immune.
	SPELLLOGABSORBSELFOTHER,	-- Your %s is absorbed by %s.
	SPELLREFLECTSELFOTHER,		-- Your %s is reflected back by %s.
	SPELLRESISTSELFOTHER		-- Your %s was resisted by %s.
}
for index in combatStrings do
	for _, pattern in {"%%s", "%%d"} do
		combatStrings[index] = gsub(combatStrings[index], pattern, "(.*)")
	end
end
--------------------------------------------------------------------------------
local weapon = nil
local offhand = nil
local range = nil
local combat = false
local configmod = false;
local player_guid = nil
local paused_swing = nil
local paused_swingOH = nil
st_timer = 0
st_timerMax = 1
st_timerOff = 0
st_timerOffMax = 1
st_timerRange = 0
st_timerRangeMax = 1
local range_fader = 0
local flurry_fresh = nil
local flurry_count = -1

--------------------------------------------------------------------------------
local loc = {};
loc["enUS"] = {
	hit = "You hit",
	crit = "You crit",
	glancing = "glancing",
	block = "blocked",
	Warrior = "Warrior",
	combatSpells = {
		HS = "Heroic Strike",
		Cleave = "Cleave",
		-- Slam = "Slam",
		RS = "Raptor Strike",
		Maul = "Maul",
		-- HolyStrike = "Holy Strike", -- Turtle wow
		MongooseBite = "Mongoose Bite", -- Turtle wow
	}
}
loc["frFR"] = {
	hit = "Vous touchez",
	crit = "Vous infligez un coup critique",
	glancing = "érafle",
	block = "bloqué",
	Warrior = "Guerrier",
	combatSpells = {
		HS = "Frappe héroïque",
		Cleave = "Enchainement",
		-- Slam = "Heurtoir",
		RS = "Attaque du raptor",
		Maul = "Mutiler",
		-- HolyStrike = "Frappe sacrée" -- Tortue wow
	}
}
local L = loc[GetLocale()];
if (L == nil) then 
	L = loc['enUS']; 
end
--------------------------------------------------------------------------------
StaticPopupDialogs["SP_ST_Install"] = {
	text = TEXT("Thanks for installing SP_SwingTimer " ..version .. "! Use the chat command /st to change the settings."),
	button1 = TEXT(YES),
	timeout = 0,
	hideOnEscape = 1,
}
--------------------------------------------------------------------------------
function MakeMovable(frame)
    frame:SetMovable(true);
    frame:RegisterForDrag("LeftButton");
    frame:SetScript("OnDragStart", function() this:StartMoving() end);
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end);
end
--------------------------------------------------------------------------------
local function print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 0.5)
end
local function SplitString(s,t)
	local l = {n=0}
	local f = function (s)
		l.n = l.n + 1
		l[l.n] = s
	end
	local p = "%s*(.-)%s*"..t.."%s*"
	s = string.gsub(s,"^%s+","")
	s = string.gsub(s,"%s+$","")
	s = string.gsub(s,p,f)
	l.n = l.n + 1
	l[l.n] = string.gsub(s,"(%s%s*)$","")
	return l
end

-- This function is realy useful
local function has_value (tab, val)
    for value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    if (tab[val] ~= nil) then
        return true
    end

    return false
end

local function sp_round(number, decimals)
    local power = 10^decimals
    return math.floor(number * power) / power
end

--------------------------------------------------------------------------------

local function UpdateSettings()
	if not SP_ST_GS then SP_ST_GS = {} end
	for option, value in defaults do
		if SP_ST_GS[option] == nil then
			SP_ST_GS[option] = value
		end
	end
end

--------------------------------------------------------------------------------

local function UpdateHeroicStrike()
	local _, class = UnitClass("player")
	if class ~= "WARRIOR" then
		return
	end
	TrackedActionSlots = {}
	local SPActionSlot = 0;
	for SPActionSlot = 1, 120 do
		local SPActionText = GetActionText(SPActionSlot);
		local SPActionTexture = GetActionTexture(SPActionSlot);
		
		if SPActionTexture then
			if (SPActionTexture == "Interface\\Icons\\Ability_Rogue_Ambush" or SPActionTexture == "Interface\\Icons\\Ability_Warrior_Cleave") then
				tinsert(TrackedActionSlots, SPActionSlot);
			elseif SPActionText then
				SPActionText = string.lower(SPActionText)
				if (SPActionText == "cleave" or SPActionText == "heroic strike" or SPActionText == "heroicstrike" or SPActionText == "hs") then
					tinsert(TrackedActionSlots, SPActionSlot);
				end
			end
		end
	end

end

--------------------------------------------------------------------------------

local function HeroicStrikeQueued()
	if not getn(TrackedActionSlots) then
		return nil
	end
	for _, actionslotID in ipairs(TrackedActionSlots) do
		if IsCurrentAction(actionslotID) then
			return true
		end
	end
	return nil
end

--------------------------------------------------------------------------------

-- flurry check
local function CheckFlurry()
  local c = 0
  while GetPlayerBuff(c,"HELPFUL") ~= -1 do
    local id = GetPlayerBuffID(c)
		if SpellInfo(id) == "Flurry" then
			return GetPlayerBuffApplications(c)
		end
		c = c + 1
  end
	return -1
end

--------------------------------------------------------------------------------

local function UpdateAppearance()
	SP_ST_Frame:ClearAllPoints()
	SP_ST_FrameOFF:ClearAllPoints()
	SP_ST_FrameRange:ClearAllPoints()
	
	SP_ST_Frame:SetPoint("TOPLEFT", SP_ST_GS["x"], SP_ST_GS["y"])
	SP_ST_maintimer:SetPoint("RIGHT", "SP_ST_Frame", "RIGHT", -2, 0)
	SP_ST_maintimer:SetFont("Fonts\\FRIZQT__.TTF", SP_ST_GS["h"])
	SP_ST_maintimer:SetTextColor(1,1,1,1);

	SP_ST_FrameOFF:SetPoint("TOPLEFT", "SP_ST_Frame", "BOTTOMLEFT", SP_ST_GS["ho"], SP_ST_GS["vo"]);
	SP_ST_offtimer:SetPoint("RIGHT", "SP_ST_FrameOFF", "RIGHT", -2, 0)
	SP_ST_offtimer:SetFont("Fonts\\FRIZQT__.TTF", SP_ST_GS["h"])
	SP_ST_offtimer:SetTextColor(1,1,1,1);
	if (SP_ST_GS["bg"] ~= 0) then SP_ST_Frame:SetBackdrop(default_bg1) else SP_ST_Frame:SetBackdrop(nil) end
	if (SP_ST_GS["bg"] ~= 0) then SP_ST_FrameOFF:SetBackdrop(default_bg2) else SP_ST_FrameOFF:SetBackdrop(nil) end

	SP_ST_FrameRange:SetPoint("TOPLEFT", "SP_ST_FrameOFF", "BOTTOMLEFT", SP_ST_GS["ho"], SP_ST_GS["vo"]);
	SP_ST_rangetimer:SetPoint("RIGHT", "SP_ST_FrameRange", "RIGHT", -2, 0)
	SP_ST_rangetimer:SetFont("Fonts\\FRIZQT__.TTF", SP_ST_GS["h"])
	SP_ST_rangetimer:SetTextColor(1,1,1,1);
	if (SP_ST_GS["bg"] ~= 0) then SP_ST_Frame:SetBackdrop(default_bg3) else SP_ST_Frame:SetBackdrop(nil) end
	-- if (SP_ST_GS["bg"] ~= 0) then SP_ST_FrameOFF:SetBackdrop(default_bg2) else SP_ST_FrameOFF:SetBackdrop(nil) end

	if (SP_ST_GS["icons"] ~= 0) then
		SP_ST_mainhand:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("MainHandSlot")));
		SP_ST_mainhand:SetHeight(SP_ST_GS["h"]+1);
		SP_ST_mainhand:SetWidth(SP_ST_GS["h"]+1);
		-- SP_ST_mainhand:SetDrawLayer("OVERLAY");
		SP_ST_offhand:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("SecondaryHandSlot")));
		SP_ST_offhand:SetHeight(SP_ST_GS["h"]+1);
		SP_ST_offhand:SetWidth(SP_ST_GS["h"]+1);
		-- SP_ST_offhand:SetDrawLayer("OVERLAY");
		SP_ST_range:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("RangedSlot")));
		SP_ST_range:SetHeight(SP_ST_GS["h"]+1);
		SP_ST_range:SetWidth(SP_ST_GS["h"]+1);
		-- SP_ST_offhand:SetDrawLayer("OVERLAY");
	else 
		SP_ST_mainhand:SetTexture(nil);
		SP_ST_mainhand:SetWidth(0);
		SP_ST_offhand:SetTexture(nil);
		SP_ST_offhand:SetWidth(0);
		SP_ST_range:SetTexture(nil);
		SP_ST_range:SetWidth(0);
	end

	if (SP_ST_GS["timers"] ~= 0) then
		SP_ST_maintimer:Show();
		SP_ST_offtimer:Show();
		SP_ST_rangetimer:Show();
	else
		SP_ST_maintimer:Hide();
		SP_ST_offtimer:Hide();
		SP_ST_rangetimer:Hide();
	end
	
	SP_ST_FrameTime:ClearAllPoints()
	SP_ST_FrameTime2:ClearAllPoints()
	SP_ST_FrameTime3:ClearAllPoints()

	local style = SP_ST_GS["style"]
	if style == 1 or style == 2 then
		SP_ST_mainhand:SetPoint("LEFT", "SP_ST_Frame", "LEFT");
		SP_ST_offhand:SetPoint("LEFT", "SP_ST_FrameOFF", "LEFT");
		SP_ST_range:SetPoint("LEFT", "SP_ST_FrameRange", "LEFT");
		SP_ST_FrameTime:SetPoint("LEFT", "SP_ST_mainhand", "LEFT")
		SP_ST_FrameTime2:SetPoint("LEFT", "SP_ST_FrameOFF", "LEFT")
		SP_ST_FrameTime3:SetPoint("LEFT", "SP_ST_FrameRange", "LEFT")
	elseif style == 3 or style == 4 then
		SP_ST_mainhand:SetPoint("RIGHT", "SP_ST_Frame", "RIGHT");
		SP_ST_offhand:SetPoint("RIGHT", "SP_ST_FrameOFF", "RIGHT");
		SP_ST_range:SetPoint("RIGHT", "SP_ST_FrameRange", "RIGHT");
		SP_ST_FrameTime:SetPoint("RIGHT", "SP_ST_mainhand", "RIGHT")
		SP_ST_FrameTime2:SetPoint("RIGHT", "SP_ST_offhand", "RIGHT")
		SP_ST_FrameTime3:SetPoint("RIGHT", "SP_ST_offrange", "RIGHT")
	else
		SP_ST_mainhand:SetTexture(nil);
		SP_ST_mainhand:SetWidth(0);
		SP_ST_offhand:SetTexture(nil);
		SP_ST_offhand:SetWidth(0);
		SP_ST_range:SetTexture(nil);
		SP_ST_range:SetWidth(0);
		SP_ST_FrameTime:SetPoint("CENTER", "SP_ST_Frame", "CENTER")
		SP_ST_FrameTime2:SetPoint("CENTER", "SP_ST_FrameOFF", "CENTER")
		SP_ST_FrameTime3:SetPoint("CENTER", "SP_ST_FrameRange", "CENTER")
	end

	SP_ST_Frame:SetWidth(SP_ST_GS["w"])
	SP_ST_Frame:SetHeight(SP_ST_GS["h"])
	SP_ST_FrameOFF:SetWidth(SP_ST_GS["w"])
	SP_ST_FrameOFF:SetHeight(SP_ST_GS["h"])
	SP_ST_FrameRange:SetWidth(SP_ST_GS["w"])
	SP_ST_FrameRange:SetHeight(SP_ST_GS["h"])

	SP_ST_FrameTime:SetWidth(SP_ST_GS["w"] - SP_ST_mainhand:GetWidth())
	SP_ST_FrameTime:SetHeight(SP_ST_GS["h"] - SP_ST_GS["b"])
	SP_ST_FrameTime2:SetWidth(SP_ST_GS["w"] - SP_ST_offhand:GetWidth())
	SP_ST_FrameTime2:SetHeight(SP_ST_GS["h"] - SP_ST_GS["b"])
	SP_ST_FrameTime3:SetWidth(SP_ST_GS["w"] - SP_ST_range:GetWidth())
	SP_ST_FrameTime3:SetHeight(SP_ST_GS["h"] - SP_ST_GS["b"])

	SP_ST_Frame:SetAlpha(SP_ST_GS["a"])
	SP_ST_Frame:SetScale(SP_ST_GS["s"])
	SP_ST_FrameOFF:SetAlpha(SP_ST_GS["a"])
	SP_ST_FrameOFF:SetScale(SP_ST_GS["s"])
	SP_ST_FrameRange:SetAlpha(SP_ST_GS["a"])
	SP_ST_FrameRange:SetScale(SP_ST_GS["s"])
end

local function GetWeaponSpeed(off,ranged)
	local speedMH, speedOH = UnitAttackSpeed("player")
	if off and not ranged then
		return speedOH
	elseif not off and ranged then
		local rangedAttackSpeed, minDamage, maxDamage, physicalBonusPos, physicalBonusNeg, percent = UnitRangedDamage("player")
		return rangedAttackSpeed
	else
		return speedMH
	end
end

local function isDualWield()
	return (GetWeaponSpeed(true) ~= nil)
end

local function hasRanged()
	return (GetWeaponSpeed(nil,true) ~= nil)
end

local function ShouldResetTimer(off)
	if not st_timerMax then st_timerMax = GetWeaponSpeed(false) end
	if not st_timerOffMax and isDualWield() then st_timerOffMax = GetWeaponSpeed(true) end
	local percentTime
	if (off) then
		percentTime = st_timerOff / st_timerOffMax
	else 
		percentTime = st_timer / st_timerMax
	end
	
	return (percentTime < 0.025)
end

local function ClosestSwing()
	if not st_timerMax then st_timerMax = GetWeaponSpeed(false) end
	if not st_timerOffMax then st_timerOffMax = GetWeaponSpeed(true) end
	local percentLeftMH = st_timer / st_timerMax
	local percentLeftOH = st_timerOff / st_timerOffMax
	return (percentLeftMH > percentLeftOH)
end

local function UpdateWeapon()
	weapon = GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))
	if (SP_ST_GS["icons"] ~= 0) then
		SP_ST_mainhand:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("MainHandSlot")));
	end
	if (isDualWield()) then
		offhand = GetInventoryItemLink("player", GetInventorySlotInfo("SecondaryHandSlot"))
		if (SP_ST_GS["icons"] ~= 0) then
			SP_ST_offhand:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("SecondaryHandSlot")));
		end
	else
		SP_ST_FrameOFF:Hide()
	end
	if hasRanged() then
		range = GetInventoryItemLink("player", GetInventorySlotInfo("RangedSlot"))
		if (SP_ST_GS["icons"] ~= 0) then
			SP_ST_range:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("RangedSlot")))
		end
	else
		SP_ST_FrameRange:Hide()
	end
end

local function ResetTimer(off,ranged)
	if not off and not ranged then
		st_timerMax = GetWeaponSpeed(off)
		st_timer = GetWeaponSpeed(off)
	elseif off and not ranged then
		st_timerOffMax = GetWeaponSpeed(off)
		st_timerOff = GetWeaponSpeed(off)
	else
		range_fader = GetTime()
		st_timerRangeMax = GetWeaponSpeed(false,true)
		st_timerRange = GetWeaponSpeed(false,true)
	end

	if not off and not ranged then SP_ST_Frame:Show() end
	if (isDualWield()) then SP_ST_FrameOFF:Show() end
	if (hasRanged()) then SP_ST_FrameRange:Show() end
end

local function TestShow()
	ResetTimer(false)
end


local function UpdateDisplay()
	local style = SP_ST_GS["style"]
	local show_oh = SP_ST_GS["show_oh"]
	local show_range = SP_ST_GS["show_range"]
	if SP_ST_InRange() then
		SP_ST_FrameTime:SetVertexColor(1.0, 1.0, 1.0);
		SP_ST_FrameTime2:SetVertexColor(1.0, 1.0, 1.0);
		SP_ST_Frame:SetBackdropColor(0,0,0,0.8);
		SP_ST_FrameOFF:SetBackdropColor(0,0,0,0.8);
	else
		SP_ST_FrameTime:SetVertexColor(1.0, 0, 0);
		SP_ST_FrameTime2:SetVertexColor(1.0, 0, 0);
		SP_ST_Frame:SetBackdropColor(1,0,0,0.8);
		SP_ST_FrameOFF:SetBackdropColor(1,0,0,0.8);
	end
	if CheckInteractDistance("target",4) then
		SP_ST_FrameTime3:SetVertexColor(1.0, 1.0, 1.0);
		SP_ST_FrameRange:SetBackdropColor(0,0,0,0.8);
	else
		SP_ST_FrameTime3:SetVertexColor(1.0, 0, 0);
		SP_ST_FrameRange:SetBackdropColor(1,0,0,0.8);
	end
	-- most classes won't want ranged indicator to stay up all the time
	if GetTime() - 10 > range_fader then
		SP_ST_FrameRange:Hide()
	end

	if (st_timer <= 0) then
		if style == 2 or style == 4 or style == 6 then
			--nothing
		else
			SP_ST_FrameTime:Hide()
		end

		if (not combat and not configmod) then
			SP_ST_Frame:Hide()
		end
	else
		SP_ST_FrameTime:Show()
		local width = SP_ST_GS["w"]
		local size = (st_timer / st_timerMax) * width
		if style == 2 or style == 4 or style == 6 then
			size = width - size
		end
		if (size > width) then
			size = width
			SP_ST_FrameTime:SetTexture(1, 0.8, 0.8, 1)
		else
			SP_ST_FrameTime:SetTexture(1, 1, 1, 1)
		end
		SP_ST_FrameTime:SetWidth(size)
		if (SP_ST_GS["timers"] ~= 0) then
			local showtmr = sp_round(st_timer, 1);
			if (math.floor(showtmr) == showtmr) then
				showtmr = showtmr..".0";
			end
			SP_ST_maintimer:SetText(showtmr);
		end
	end

	if (hasRanged() and show_range) then
		if (st_timerRange <= 0) then
			if style == 2 or style == 4 or style == 6 then
				--nothing
			else
				SP_ST_FrameTime3:Hide()
			end

			if (not combat and not configmod) then
				SP_ST_FrameRange:Hide()
			end
		else
			SP_ST_FrameTime3:Show()
			local width = SP_ST_GS["w"]
			local size2 = (st_timerRange / st_timerRangeMax) * width
			if style == 2 or style == 4 or style == 6 then
				size2 = width - size2
			end
			if (size2 > width) then
				size2 = width
				SP_ST_FrameTime3:SetTexture(1, 0.8, 0.8, 1)
			else
				SP_ST_FrameTime3:SetTexture(1, 1, 1, 1)
			end
			SP_ST_FrameTime3:SetWidth(size2)
			if (SP_ST_GS["timers"] ~= 0) then
				local showtmr = sp_round(st_timerRange, 1);
				if (math.floor(showtmr) == showtmr) then
					showtmr = showtmr..".0";
				end
				SP_ST_rangetimer:SetText(showtmr);
			end
		end
	else
		SP_ST_FrameRange:Hide()
	end

	if (isDualWield() and show_oh) then
		if (st_timerOff <= 0) then
			if style == 2 or style == 4 or style == 6 then
				--nothing
			else
				SP_ST_FrameTime2:Hide()
			end

			if (not combat and not configmod) then
				SP_ST_FrameOFF:Hide()
			end
		else
			SP_ST_FrameTime2:Show()
			local width = SP_ST_GS["w"]
			local size2 = (st_timerOff / st_timerOffMax) * width
			if style == 2 or style == 4 or style == 6 then
				size2 = width - size2
			end
			if (size2 > width) then
				size2 = width
				SP_ST_FrameTime2:SetTexture(1, 0.8, 0.8, 1)
			else
				SP_ST_FrameTime2:SetTexture(1, 1, 1, 1)
			end
			SP_ST_FrameTime2:SetWidth(size2)
			if (SP_ST_GS["timers"] ~= 0) then
				local showtmr = sp_round(st_timerOff, 1);
				if (math.floor(showtmr) == showtmr) then
					showtmr = showtmr..".0";
				end
				SP_ST_offtimer:SetText(showtmr);
			end
		end
	else
		SP_ST_FrameOFF:Hide()
	end
end

--------------------------------------------------------------------------------

-- register action bars changing or world enter and identify an instant attack like backstab or sinister strike or hamstring or sunder armor or bloodthirst
-- check these slots for range

local instants = {
	["Backstab"] = 1,
	["Sinister Strike"] = 1,
	["Kick"] = 1,
	["Expose Armor"] = 1,
	["Eviscerate"] = 1,
	["Rupture"] = 1,
	["Kidney Shot"] = 1,
	["Garrote"] = 1,
	["Ambush"] = 1,
	["Cheap Shot"] = 1,
	["Gouge"] = 1,
	["Feint"] = 1,
	["Ghosly Strike"] = 1,
	["Hemorrhage"] = 1,
	-- ["Riposte"] = 1, -- maybe

	["Hamstring"] = 1,
	["Sunder Armor"] = 1,
	["Bloodthirst"] = 1,
	["Mortal Strike"] = 1,
	["Shield Slam"] = 1,
	["Overpower"] = 1,
	["Revenge"] = 1,
	["Pummel"] = 1,
	["Shield Bash"] = 1,
	["Disarm"] = 1,
	["Execute"] = 1,
	["Taunt"] = 1,
	["Mocking Blow"] = 1,
	["Slam"] = 1,
	["Decisive Strike"] = 1,
	["Rend"] = 1,

	["Crusader Strike"] = 1,

	["Storm Strike"] = 1,

	["Savage Bite"] = 1,
	["Growl"] = 1,
	["Bash"] = 1,
	["Swipe"] = 1,
	["Claw"] = 1,
	["Rip"] = 1,
	["Ferocious Bite"] = 1,
	["Shred"] = 1,
	["Rake"] = 1,
	["Cower"] = 1,
	["Ravage"] = 1,
	["Pounce"] = 1,

	["Wing Clip"] = 1,
	["Disengage"] = 1,
	["Carve"] = 1, -- twow
	-- ["Counterattack"] = 1, -- maybe
}

local range_check_slot = nil
function SP_ST_Check_Actions(slot)
	if slot then
		local name,actionType,identifier = GetActionText(slot);

		if actionType and identifier and actionType == "SPELL" then
			local name,rank,texture = SpellInfo(identifier)
			if instants[name] then
				range_check_slot = i
			end
		end
		return
	end

	for i=1,120 do
		local name,actionType,identifier = GetActionText(i);
		-- if ActionHasRange(i) then
		-- 	print(SpellInfo(identifier))
		-- end

		if actionType and identifier and actionType == "SPELL" then
			local name,rank,texture = SpellInfo(identifier)
			if instants[name] then
				range_check_slot = i
				-- print(range_check_slot)
				-- print(name)
				return
			end
		end
	end
	-- no hits?
	range_check_slot = nil
end

function SP_ST_InRange()
	-- if the slot is nil anyway then there's no sense being red all the time
	return range_check_slot == nil or IsActionInRange(range_check_slot) == 1
end

function rangecheck()
	print(SP_ST_InRange() and "yes" or "no")
end

function SP_ST_OnLoad()
	this:RegisterEvent("ADDON_LOADED")
	this:RegisterEvent("PLAYER_REGEN_ENABLED")
	this:RegisterEvent("PLAYER_REGEN_DISABLED")
	this:RegisterEvent("UNIT_INVENTORY_CHANGED")
	this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
	this:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
	this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES")
	this:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
	this:RegisterEvent("UNIT_CASTEVENT")
	-- this:RegisterEvent("UNIT_AURA")
	-- this:RegisterEvent("PLAYER_AURAS_CHANGED")
	this:RegisterEvent("PLAYER_ENTERING_WORLD")
	this:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	end

function SP_ST_OnEvent()
	if (event == "ADDON_LOADED" and arg1 == "SP_SwingTimer") then
		if (SP_ST_GS == nil) then
			StaticPopup_Show("SP_ST_Install")
		end
		default_bg1 = SP_ST_Frame:GetBackdrop()
		default_bg2 = SP_ST_FrameOFF:GetBackdrop()
		default_bg3 = SP_ST_FrameRange:GetBackdrop()

		if (SP_ST_GS ~= nil) then 
			for k,v in pairs(defaults) do
				if (SP_ST_GS[k] == nil) then
					SP_ST_GS[k] = defaults[k];
				end
			end
		end

		UpdateSettings()
		UpdateWeapon()
		UpdateAppearance()
		if not st_timerMax then st_timerMax = GetWeaponSpeed(false) end
		if not st_timerOffMax and isDualWield() then st_timerOffMax = GetWeaponSpeed(true) end
		if not st_timerRangeMax and isDualWield() then st_timerRangeMax = GetWeaponSpeed(nil,true) end
		print("SP_SwingTimer " .. version .. " loaded. Options: /st")
	elseif (event == "PLAYER_REGEN_ENABLED")
		or (event == "PLAYER_ENTERING_WORLD") then
		_,player_guid = UnitExists("player")
		if UnitAffectingCombat('player') then combat = true else combat = false end
		CheckFlurry()
		UpdateDisplay()
		SP_ST_Check_Actions()

	elseif (event == "PLAYER_REGEN_DISABLED") then
		combat = true
		CheckFlurry()
	elseif (event == "PLAYER_ENTER_COMBAT") then
		if isDualWield() then ResetTimer(true) end
		flurry_count = CheckFlurry()
	elseif (evet == "ACTIONBAR_SLOT_CHANGED") then
		SP_ST_Check_Actions(arg1)
	elseif (event == "UNIT_CASTEVENT" and arg1 == player_guid) then
		local spell = SpellInfo(arg4)
		if spell == "Flurry" then
			if flurry_count < 1 then -- track a completely fresh flurry for timing
				flurry_fresh = true
			end
			flurry_count = 3
		end
		if arg4 == 6603 then -- 6603 == autoattack then
			-- print("swing, flurry "..flurry_count..(flurry_fresh and ", is fresh" or ""))
			if arg3 == "MAINHAND" then
				-- print(format("mh %.3f",GetWeaponSpeed(false)))
				-- print("mainhand hit")
				ResetTimer(false)

				if flurry_fresh then -- fresh flurry, decrease the swing cooldown of the next swing
					st_timer = st_timer / 1.3
					st_timerMax = st_timerMax / 1.3
					flurry_fresh = false
				end
				if flurry_count == 0 then -- used up last flurry
					st_timer = st_timer * 1.3
					st_timerMax = st_timerMax * 1.3
				end
			elseif arg3 == "OFFHAND" then
				-- print(format("oh %.3f",GetWeaponSpeed(true)))
				-- print("offhand hit")
				ResetTimer(true)

				if flurry_fresh then -- fresh flurry, decrease the swing cooldown of the next swing
					st_timerOff = st_timerOff / 1.3
					st_timerOffMax = st_timerOffMax / 1.3
					flurry_fresh = false
				end
				if flurry_count == 0 then -- used up last flurry
					st_timerOff = st_timerOff * 1.3
					st_timerOffMax = st_timerOffMax * 1.3
				end
			end
			flurry_count = flurry_count - 1 -- swing occured, reduce flurry counter
			return
		elseif arg3 == "CAST" and arg4 == 5019 then
		-- wand shoot, treat wand as offhand, no reason no to
			ResetTimer(nil,true)
			return
		end
	  if SpellInfo(arg4) == "Slam" then
			if arg3 == "START" then
				paused_swing = st_timer
				paused_swingOH = st_timerOff
			else --fail
				st_timer = paused_swing
				st_timerOff = paused_swingOH
				paused_swing = nil
				paused_swingOH = nil
				-- slam resets OH swing
				-- ResetTimer(true)
			end
			return
		end

		local spellname = SpellInfo(arg4)
		for _,v in L['combatSpells'] do
			if spellname == v and arg3 == "CAST" then
				-- print(spellname .. " " .. flurry_count)
				-- print(format("sp %.3f",GetWeaponSpeed(false)) .. " " .. flurry_count)
				ResetTimer(false)
				if flurry_fresh then
					st_timer = st_timer / 1.3
					st_timerMax = st_timerMax / 1.3
				end
				if flurry_count == 0 then -- used up last flurry
					st_timer = st_timer * 1.3
					st_timerMax = st_timerMax * 1.3
				end
				flurry_count = flurry_count - 1 -- swing occured, reduce flurry counter
				return
			end
		end
		-- if spellname == "Flurry" and flurry_fresh == nil then
			-- flurry_fresh = true
      -- print("wasflurry cast: ".. GetTime())
		-- end

	elseif (event == "UNIT_INVENTORY_CHANGED") then
		if (arg1 == "player") then
			local oldWep = weapon
			local oldOff = offhand
			local oldRange = range

			UpdateWeapon()
			if (combat and oldWep ~= weapon) then
				ResetTimer(false)
			end

			if offhand then
				-- don't forget OH timer just because you put on a shield, you might still care, especially for macros
				local _,_,itemId = string.find(offhand,"item:(%d+)")
				local _name,_link,_,_lvl,wep_type,_subtype,_ = GetItemInfo(itemId)
				if (combat and isDualWield() and ((oldOff ~= offhand) and (wep_type and wep_type == "Weapon"))) then
					ResetTimer(true)
				end
			end

			if (combat and oldRange ~= range) then
				ResetTimer(nil,true)
			end

		end

	elseif (event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES") or (event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE") or (event == "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES") or (event == "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE") then
		if (string.find(arg1, ".* attacks. You parry.")) or (string.find(arg1, ".* was parried.")) then
			-- Only the upcoming swing gets parry haste benefit
			if (isDualWield()) then
				if st_timerOff < st_timer then
					local minimum = GetWeaponSpeed(true) * 0.20
					local reduct = GetWeaponSpeed(true) * 0.40
					st_timerOff = st_timerOff - reduct
					if st_timerOff < minimum then
						st_timer = minimum
					end
					return -- offhand gets the parry haste benefit, return
				end
			end	

			local minimum = GetWeaponSpeed(false) * 0.20
			if (st_timer > minimum) then
				local reduct = GetWeaponSpeed(false) * 0.40
				local newTimer = st_timer - reduct
				if (newTimer < minimum) then
					st_timer = minimum
				else
					st_timer = newTimer
				end
			end
		end
	end
end

function SP_ST_OnUpdate(delta)
	if (st_timer > 0) and not paused_swing then
		st_timer = st_timer - delta
		if (st_timer < 0) then
			st_timer = 0
		end
	end
	if (st_timerOff > 0) and not paused_swingOH then
		st_timerOff = st_timerOff - delta
		if (st_timerOff < 0) then
			st_timerOff = 0
		end
	end
	if (st_timerRange > 0) then
		st_timerRange = st_timerRange - delta
		if (st_timerRange < 0) then
			st_timerRange = 0
		end
	end
	UpdateDisplay()
end

--------------------------------------------------------------------------------

SLASH_SPSWINGTIMER1 = "/st"
SLASH_SPSWINGTIMER2 = "/swingtimer"

local function ChatHandler(msg)
	local vars = SplitString(msg, " ")
	for k,v in vars do
		if v == "" then
			v = nil
		end
	end
	local cmd, arg = vars[1], vars[2]
	if cmd == "reset" then
		SP_ST_GS = nil
		UpdateSettings()
		UpdateAppearance()
		print("Reset to defaults.")
	elseif cmd == "move" then
		if (arg == "on") then
			configmod = true;
			SP_ST_Frame:Show();
			SP_ST_FrameOFF:Show();
			MakeMovable(SP_ST_Frame);
		else
			SP_ST_Frame:SetMovable(false);
			_,_,_,SP_ST_GS["x"], SP_ST_GS["y"]= SP_ST_Frame:GetPoint()
			configmod = false;
			UpdateAppearance();
		end
	elseif cmd == "offhand" then
		SP_ST_GS["show_oh"] = not SP_ST_GS["show_oh"]
		print("toggled showing offhand: " .. (SP_ST_GS["show_oh"] and "on" or "off"))
	elseif cmd == "range" then
		SP_ST_GS["show_range"] = not SP_ST_GS["show_range"]
		print("toggled showing range weapon: " .. (SP_ST_GS["show_range"] and "on" or "off"))
	elseif settings[cmd] ~= nil then
		if arg ~= nil then
			local number = tonumber(arg)
			if number then
				SP_ST_GS[cmd] = number
				UpdateAppearance()
			else
				print("Error: Invalid argument")
			end
		end
		print(format("%s %s %s (%s)",
			SLASH_SPSWINGTIMER1, cmd, SP_ST_GS[cmd], settings[cmd]))
	else
		for k, v in settings do
			print(format("%s %s %s (%s)",
				SLASH_SPSWINGTIMER1, k, SP_ST_GS[k], v))
		end
		print("/st offhand (Toggle offhand display)")
		print("/st range (Toggle range wep display)")
	end
	TestShow()
end

SlashCmdList["SPSWINGTIMER"] = ChatHandler
