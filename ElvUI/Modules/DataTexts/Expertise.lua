local E, L, V, P, G = unpack(ElvUI)
local DT = E:GetModule('DataTexts')

local format = format
local strjoin = strjoin

local GetExpertise = GetExpertise
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local GetExpertisePercent = GetExpertisePercent
local GetInventoryItemLink = GetInventoryItemLink
local GetInventorySlotInfo = GetInventorySlotInfo
local GetSpellInfo = GetSpellInfo
local IsUsableSpell = IsUsableSpell

local CR_EXPERTISE_TOOLTIP = CR_EXPERTISE_TOOLTIP
local STAT_EXPERTISE = STAT_EXPERTISE
local CR_EXPERTISE = CR_EXPERTISE

local displayString, expertisePercentDisplay, ttStr = '', '', ''
local expertisePercent, offhandExpertisePercent = 0, 0
local expertiseRating, expertiseBonusRating = 0, 0
local expertise, offhandExpertise = 0, 0

local function IsDualWielding()
	local mainHandLink = GetInventoryItemLink('player', GetInventorySlotInfo('MAINHANDSLOT'))
	local offHandLink = GetInventoryItemLink('player', GetInventorySlotInfo('SECONDARYHANDSLOT'))

	if IsUsableSpell(GetSpellInfo(674)) and (mainHandLink and offHandLink) then
		return true
	else
		return false
	end
end

local function OnEvent(self)
	expertise, offhandExpertise = GetExpertise()
	expertisePercent, offhandExpertisePercent = GetExpertisePercent()
	expertiseRating, expertiseBonusRating = GetCombatRating(CR_EXPERTISE), GetCombatRatingBonus(CR_EXPERTISE)

	if IsDualWielding() then
		expertisePercentDisplay = format('%.2f%% / %.2f%%', expertisePercent, offhandExpertisePercent)
		ttStr = '%s / %s'
	else
		expertisePercentDisplay = format('%.2f%%', expertisePercent)
		ttStr = '%s'
	end

	self.text:SetFormattedText(displayString, STAT_EXPERTISE..': ', expertisePercentDisplay)
end

local function OnEnter()
	DT.tooltip:ClearLines()

	DT.tooltip:AddDoubleLine(STAT_EXPERTISE, format(ttStr, expertise, offhandExpertise), 1, 1, 1)
	DT.tooltip:AddLine(format(CR_EXPERTISE_TOOLTIP, expertisePercentDisplay, expertiseRating, expertiseBonusRating))

	DT.tooltip:Show()
end

local function ApplySettings(_, hex)
	displayString = strjoin('', '%s', hex, '%s|r')
end

DT:RegisterDatatext('Expertise', L["Enhancements"], { 'UNIT_STATS', 'UNIT_AURA', 'ACTIVE_TALENT_GROUP_CHANGED', 'PLAYER_TALENT_UPDATE' }, OnEvent, nil, nil, OnEnter, nil, STAT_EXPERTISE, nil, ApplySettings)
