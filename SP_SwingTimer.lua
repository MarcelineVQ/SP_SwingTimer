
local version = "4.1.1"

local defaults = {
	x = 0,
	y = -150,
	w = 200,
	h = 10,
	b = 2,
	a = 1,
	s = 1,
	move = "off",
	icons = 1,
	bg = 1,
	timers = 1,
	style = 2,
	show_oh = true,
}

local default_bg = nil

local settings = {
	x = "Bar X position",
	y = "Bar Y position",
	w = "Bar width",
	h = "Bar height",
	b = "Border height",
	a = "Alpha between 0 and 1",
	s = "Bar scale",
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
local combat = false
local configmod = false;
local player_guid = nil
st_timer = 0
st_timerMax = 1
st_timerOff = 0
st_timerOffMax = 1
local flurry_fresh = nil
local last_hit_mh = true

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
		Slam = "Slam",
		RS = "Raptor Strike",
		Maul = "Maul",
		HolyStrike = "Holy Strike" -- Turtle wow
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
		Slam = "Heurtoir",
		RS = "Attaque du raptor",
		Maul = "Mutiler",
		HolyStrike = "Frappe sacrée" -- Tortue wow
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
	for i=1,40 do
		local _,s,id = UnitBuff("player",i)
		if id then
			if SpellInfo(id) == "Flurry" then
				-- print("wasflurry: ".. GetTime())
				if s == 3 and flurry_fresh == nil then
					-- ^ this could just be a refresh, make sure it was nil before
					flurry_fresh = true
				else
					flurry_fresh = false
				end
				return
			end
		else
			break
		end
	end
	-- no flurry present but it was present (~= nil), adjust upcoming times
	if flurry_fresh ~= nil then
		if last_hit_mh then
			st_timer = st_timer * 1.3
			st_timerMax = st_timerMax * 1.3
		else
			st_timerOff = st_timerOff * 1.3
			st_timerOffMax = st_timerOffMax * 1.3
		end
	end
	flurry_fresh = nil
end

--------------------------------------------------------------------------------

local function UpdateAppearance()
	SP_ST_Frame:ClearAllPoints()
	SP_ST_FrameOFF:ClearAllPoints()
	
	SP_ST_Frame:SetPoint("TOPLEFT", SP_ST_GS["x"], SP_ST_GS["y"])
	SP_ST_maintimer:SetPoint("RIGHT", "SP_ST_Frame", "RIGHT", -2, 0)
	SP_ST_maintimer:SetFont("Fonts\\FRIZQT__.TTF", SP_ST_GS["h"])
	SP_ST_maintimer:SetTextColor(1,1,1,1);

	SP_ST_FrameOFF:SetPoint("TOPLEFT", "SP_ST_Frame", "BOTTOMLEFT", 0, 1);
	SP_ST_offtimer:SetPoint("RIGHT", "SP_ST_FrameOFF", "RIGHT", -2, 0)
	SP_ST_offtimer:SetFont("Fonts\\FRIZQT__.TTF", SP_ST_GS["h"])
	SP_ST_offtimer:SetTextColor(1,1,1,1);
	if (SP_ST_GS["bg"] ~= 0) then SP_ST_Frame:SetBackdrop(default_bg) else SP_ST_Frame:SetBackdrop(nil) end
	if (SP_ST_GS["bg"] ~= 0) then SP_ST_FrameOFF:SetBackdrop(default_bg) else SP_ST_FrameOFF:SetBackdrop(nil) end

	if (SP_ST_GS["icons"] ~= 0) then
		SP_ST_mainhand:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("MainHandSlot")));
		SP_ST_mainhand:SetHeight(SP_ST_GS["h"]+1);
		SP_ST_mainhand:SetWidth(SP_ST_GS["h"]+1);
		-- SP_ST_mainhand:SetDrawLayer("OVERLAY");
		SP_ST_offhand:SetTexture(GetInventoryItemTexture("player", GetInventorySlotInfo("SecondaryHandSlot")));
		SP_ST_offhand:SetHeight(SP_ST_GS["h"]+1);
		SP_ST_offhand:SetWidth(SP_ST_GS["h"]+1);
		-- SP_ST_offhand:SetDrawLayer("OVERLAY");
	else 
		SP_ST_mainhand:SetTexture(nil);
		SP_ST_mainhand:SetWidth(0);
		SP_ST_offhand:SetTexture(nil);
		SP_ST_offhand:SetWidth(0);
	end

	if (SP_ST_GS["timers"] ~= 0) then
		SP_ST_maintimer:Show();
		SP_ST_offtimer:Show();
	else
		SP_ST_maintimer:Hide();
		SP_ST_offtimer:Hide();
	end
	
	SP_ST_FrameTime:ClearAllPoints()
	SP_ST_FrameTime2:ClearAllPoints()

	local style = SP_ST_GS["style"]
	if style == 1 or style == 2 then
		SP_ST_mainhand:SetPoint("LEFT", "SP_ST_Frame", "LEFT");
		SP_ST_offhand:SetPoint("LEFT", "SP_ST_FrameOFF", "LEFT");
		SP_ST_FrameTime:SetPoint("LEFT", "SP_ST_mainhand", "LEFT")
		SP_ST_FrameTime2:SetPoint("LEFT", "SP_ST_FrameOFF", "LEFT")
	elseif style == 3 or style == 4 then
		SP_ST_mainhand:SetPoint("RIGHT", "SP_ST_Frame", "RIGHT");
		SP_ST_offhand:SetPoint("RIGHT", "SP_ST_FrameOFF", "RIGHT");
		SP_ST_FrameTime:SetPoint("RIGHT", "SP_ST_mainhand", "RIGHT")
		SP_ST_FrameTime2:SetPoint("RIGHT", "SP_ST_offhand", "RIGHT")
	else
		SP_ST_mainhand:SetTexture(nil);
		SP_ST_mainhand:SetWidth(0);
		SP_ST_offhand:SetTexture(nil);
		SP_ST_offhand:SetWidth(0);
		SP_ST_FrameTime:SetPoint("CENTER", "SP_ST_Frame", "CENTER")
		SP_ST_FrameTime2:SetPoint("CENTER", "SP_ST_FrameOFF", "CENTER")
	end

	SP_ST_Frame:SetWidth(SP_ST_GS["w"])
	SP_ST_Frame:SetHeight(SP_ST_GS["h"])
	SP_ST_FrameOFF:SetWidth(SP_ST_GS["w"])
	SP_ST_FrameOFF:SetHeight(SP_ST_GS["h"])

	SP_ST_FrameTime:SetWidth(SP_ST_GS["w"] - SP_ST_mainhand:GetWidth())
	SP_ST_FrameTime:SetHeight(SP_ST_GS["h"] - SP_ST_GS["b"])
	SP_ST_FrameTime2:SetWidth(SP_ST_GS["w"] - SP_ST_offhand:GetWidth())
	SP_ST_FrameTime2:SetHeight(SP_ST_GS["h"] - SP_ST_GS["b"])

	SP_ST_Frame:SetAlpha(SP_ST_GS["a"])
	SP_ST_Frame:SetScale(SP_ST_GS["s"])
	SP_ST_FrameOFF:SetAlpha(SP_ST_GS["a"])
	SP_ST_FrameOFF:SetScale(SP_ST_GS["s"])
end

local function GetWeaponSpeed(off)
	local speedMH, speedOH = UnitAttackSpeed("player")
	if (off) then 
		return speedOH; 
	else
		return speedMH;
	end
end

local function isDualWield()
	return (GetWeaponSpeed(true) ~= nil);
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
	else SP_ST_FrameOFF:Hide();
	end
end

local function ResetTimer(off)
	if (not off) then
		st_timerMax = GetWeaponSpeed(off)
		st_timer = GetWeaponSpeed(off)
		-- if (isDualWield() and st_timerOff < 0.2) then
		-- 	st_timerOff = 0.2;
		-- end
	else
		st_timerOffMax = GetWeaponSpeed(off)
		st_timerOff = GetWeaponSpeed(off)
		-- if (isDualWield() and st_timer < 0.2) then
		-- 	st_timer = 0.2;
		-- end
	end

	SP_ST_Frame:Show()
	if (isDualWield()) then SP_ST_FrameOFF:Show() end
end

local function TestShow()
	ResetTimer(false)
end

local function UpdateDisplay()
	local style = SP_ST_GS["style"]
	local show_oh = SP_ST_GS["show_oh"]
	if SP_ST_InRange() then
		SP_ST_FrameTime:SetVertexColor(1.0, 1.0, 1.0);
		SP_ST_FrameTime2:SetVertexColor(1.0, 1.0, 1.0);
	else
		SP_ST_FrameTime:SetVertexColor(1.0, 0, 0);
		SP_ST_FrameTime2:SetVertexColor(1.0, 0, 0);
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

-- local clipping = false
-- local HC_Timer = CreateFrame("Frame")
-- this can't work, can't automate SpellStopCasting() with a timer
-- function HeroicClip()
-- 	-- if not hs_slot then
-- 	-- 	print("Heroic Strike needs to be on your bars to use HeroicClip")
-- 	-- end
-- 	if clipping then return end
-- 	CastSpellByName("Heroic Strike")
-- 	clipping = true
-- 	local elapsed = 0
-- 	local dur = st_timer - UnitAttackSpeed("player") * 0.8
-- 	HC_Timer:SetScript("OnUpdate", function ()
-- 		dur = dur - arg1
-- 		print(dur)
-- 		if dur < 0 then
-- 			print("wark")
-- 			SpellStopCasting()
-- 			clipping = false
-- 			HC_Timer:SetScript("OnUpdate", nil)
-- 		end
-- 	end)

-- 	-- if IsCurrentAction(hs_slot) else hs_is_queued = false
-- 	-- /run if not _a then for i=1,72 do if IsAttackAction(i) then _a=i end end end if not IsCurrentAction(_a)then UseAction(_a)end if st_timer>UnitAttackSpeed"player"*0.9 then CastSpellByName"Slam()" end
-- end

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
	this:RegisterEvent("PLAYER_AURAS_CHANGED")
	this:RegisterEvent("PLAYER_ENTERING_WORLD")
	this:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	end

function SP_ST_OnEvent()
	if (event == "ADDON_LOADED" and arg1 == "SP_SwingTimer") then
		if (SP_ST_GS == nil) then
			StaticPopup_Show("SP_ST_Install")
		end
		default_bg = SP_ST_Frame:GetBackdrop()

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

	elseif (event == "PLAYER_ENTER_COMBAT") then
		if isDualWield() then ResetTimer(true) end

	elseif (event == "PLAYER_AURAS_CHANGED") then
		CheckFlurry()
	elseif (evet == "ACTIONBAR_SLOT_CHANGED") then
		SP_ST_Check_Actions(arg1)
	elseif (event == "UNIT_CASTEVENT" and arg1 == player_guid) then
		if arg4 == 6603 then -- 6603 == autoattack then
			if arg3 == "MAINHAND" then
				last_hit_mh = true
				-- print("mainhand hit")
				ResetTimer(false)
				if flurry_fresh then
					st_timer = st_timer / 1.3
					st_timerMax = st_timerMax / 1.3
				end
			elseif arg3 == "OFFHAND" then
				last_hit_mh = false
				-- print("offhand hit")
				ResetTimer(true)
				if flurry_fresh then
					st_timerOff = st_timerOff / 1.3
					st_timerOffMax = st_timerOffMax / 1.3
				end
			end
			return
		end
		local spellname = SpellInfo(arg4)
		for _,v in L['combatSpells'] do
			if spellname == v and arg3 == "CAST" then
				-- print(spellname)
				last_hit_mh = true
				-- print("mainhand hit")
				ResetTimer(false)
				if flurry_fresh then
					st_timer = st_timer / 1.3
					st_timerMax = st_timerMax / 1.3
				end
				return
			end
		end
		if spellname == "Flurry" and flurry_fresh == nil then
			flurry_fresh = true
      -- print("wasflurry cast: ".. GetTime())
		end

	elseif (event == "UNIT_INVENTORY_CHANGED") then
		if (arg1 == "player") then
			local oldWep = weapon
			local oldOff = offhand

			UpdateWeapon()
			if (combat and oldWep ~= weapon) then
				ResetTimer(false)
			end
			if (combat and isDualWield() and oldOff ~= offhand) then
				ResetTimer(true)
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
	if (st_timer > 0) then
		st_timer = st_timer - delta
		if (st_timer < 0) then
			st_timer = 0
		end
	end
	if (st_timerOff > 0) then
		st_timerOff = st_timerOff - delta
		if (st_timerOff < 0) then
			st_timerOff = 0
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
	end
	TestShow()
end

SlashCmdList["SPSWINGTIMER"] = ChatHandler
