local E, L, V, P, G = unpack(ElvUI)
local M = E:GetModule("Misc")
local B = E:GetModule("Bags")
local LC = E.Libs.Compat

local _G = _G
local next = next
local select = select
local format = format
local strmatch = strmatch
local hooksecurefunc = hooksecurefunc

local CreateFrame = CreateFrame
local AcceptGroup = AcceptGroup
local CanGuildBankRepair = CanGuildBankRepair
local CanMerchantRepair = CanMerchantRepair
local GetGuildBankWithdrawMoney = GetGuildBankWithdrawMoney
local GetInstanceInfo = GetInstanceInfo
local GetItemInfo = GetItemInfo
local GetQuestItemLink = GetQuestItemLink
local GetFriendInfo = GetFriendInfo
local GetGuildRosterInfo = GetGuildRosterInfo
local GetNumQuestChoices = GetNumQuestChoices
local GetNumFriends = GetNumFriends
local GetQuestItemInfo = GetQuestItemInfo
local GetNumGuildMembers = GetNumGuildMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local GetRepairAllCost = GetRepairAllCost
local HasLFGRestrictions = HasLFGRestrictions
local InCombatLockdown = InCombatLockdown
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local IsAddOnLoaded = IsAddOnLoaded
local IsShiftKeyDown = IsShiftKeyDown
local LeaveParty = LeaveParty
local RaidNotice_AddMessage = RaidNotice_AddMessage
local RepairAllItems = RepairAllItems
local SendChatMessage = SendChatMessage
local StaticPopup_Hide = StaticPopup_Hide
local UninviteUnit = UninviteUnit
local UnitGUID = UnitGUID
local UnitInRaid = UnitInRaid
local UnitName = UnitName
local IsInGuild = IsInGuild
local PlaySoundFile = PlaySoundFile
local GetNumFactions = GetNumFactions
local GetFactionInfo = GetFactionInfo
local ExpandAllFactionHeaders = ExpandAllFactionHeaders
local SetWatchedFactionIndex = SetWatchedFactionIndex

local IsInGroup = LC.IsInGroup
local IsInRaid = LC.IsInRaid
local GetNumGroupMembers = LC.GetNumGroupMembers
local UnitIsGroupLeader = LC.UnitIsGroupLeader

local ERR_GUILD_NOT_ENOUGH_MONEY = ERR_GUILD_NOT_ENOUGH_MONEY
local ERR_NOT_ENOUGH_MONEY = ERR_NOT_ENOUGH_MONEY
local MAX_PARTY_MEMBERS = MAX_PARTY_MEMBERS
local UNKNOWN = UNKNOWN

local INTERRUPT_MSG = L["Interrupted %s's |cff71d5ff|Hspell:%d:0|h[%s]|h|r!"]

function M:ErrorFrameToggle(event)
	if not E.db.general.hideErrorFrame then return end

	if event == 'PLAYER_REGEN_DISABLED' then
		_G.UIErrorsFrame:UnregisterEvent('UI_ERROR_MESSAGE')
	else
		_G.UIErrorsFrame:RegisterEvent('UI_ERROR_MESSAGE')
	end
end

function M:ZoneTextToggle()
	if E.db.general.hideZoneText then
		_G.ZoneTextFrame:UnregisterAllEvents()
	else
		_G.ZoneTextFrame:RegisterEvent('ZONE_CHANGED')
		_G.ZoneTextFrame:RegisterEvent('ZONE_CHANGED_INDOORS')
		_G.ZoneTextFrame:RegisterEvent('ZONE_CHANGED_NEW_AREA')
	end
end

do
	function M:COMBAT_LOG_EVENT_UNFILTERED(_, _, event, sourceGUID, _, _, destGUID, destName, _, _, _, _, spellID, spellName)
		local inGroup = IsInGroup()
		if not inGroup then return end

		local announce = spellName and (destGUID ~= E.myguid) and (sourceGUID == E.myguid or sourceGUID == UnitGUID('pet')) and strmatch(event, '_INTERRUPT')
		if not announce then return end -- No announce-able interrupt from player or pet, exit.

		local inRaid, inPartyLFG = IsInRaid(), HasLFGRestrictions()

		--Skirmish/non-rated arenas need to use INSTANCE_CHAT but IsPartyLFG() returns 'false'
		local _, instanceType = GetInstanceInfo()
		if instanceType == 'arena' then
			local isArena, isRegistered = IsActiveBattlefieldArena()
			if isArena or not isRegistered then
				inPartyLFG = true
			end

			inRaid = false --IsInRaid() returns true for arenas and they should not be considered a raid
		end

		local name, msg = destName or UNKNOWN
		if E.locale == 'msMX' or E.locale == 'esES' or E.locale == 'ptBR' then -- name goes after
			msg = format(INTERRUPT_MSG, spellID, spellName, name) or format(INTERRUPT_MSG, spellName, name)
		else
			msg = format(INTERRUPT_MSG, name, spellID, spellName) or format(INTERRUPT_MSG, name, spellName)
		end


		local channel = E.db.general.interruptAnnounce
		if channel == 'PARTY' then
			SendChatMessage(msg, inPartyLFG and 'INSTANCE_CHAT' or 'PARTY')
		elseif channel == 'RAID' then
			SendChatMessage(msg, inPartyLFG and 'INSTANCE_CHAT' or (inRaid and 'RAID' or 'PARTY'))
		elseif channel == 'RAID_ONLY' and inRaid then
			SendChatMessage(msg, inPartyLFG and 'INSTANCE_CHAT' or 'RAID')
		elseif channel == 'SAY' and instanceType ~= 'none' then
			SendChatMessage(msg, 'SAY')
		elseif channel == 'YELL' and instanceType ~= 'none' then
			SendChatMessage(msg, 'YELL')
		elseif channel == 'EMOTE' then
			SendChatMessage(msg, 'EMOTE')
		end
	end
end

function M:COMBAT_TEXT_UPDATE(_, messagetype, faction, rep)
	if not E.db.general.autoTrackReputation then return end

	if messagetype == 'FACTION' then
		local data = (rep and rep > 0) and E:GetWatchedFactionInfo()
		if data and faction ~= data.name then
			ExpandAllFactionHeaders()

			for i = 1, GetNumFactions() do
				if faction == GetFactionInfo(i) then
					SetWatchedFactionIndex(i)
					break
				end
			end
		end
	end
end

do -- Auto Repair Functions
	local STATUS, TYPE, COST, canRepair
	function M:AttemptAutoRepair(playerOverride)
		STATUS, TYPE, COST, canRepair = '', E.db.general.autoRepair, GetRepairAllCost()

		if canRepair and COST > 0 then
			local tryGuild = not playerOverride and TYPE == 'GUILD' and IsInGuild()
			local useGuild = tryGuild and CanGuildBankRepair() and COST <= GetGuildBankWithdrawMoney()
			if not useGuild then TYPE = 'PLAYER' end

			RepairAllItems(useGuild)

			--Delay this a bit so we have time to catch the outcome of first repair attempt
			E:Delay(0.5, M.AutoRepairOutput)
		end
	end

	function M:AutoRepairOutput()
		if TYPE == 'GUILD' then
			if STATUS == 'GUILD_REPAIR_FAILED' then
				M:AttemptAutoRepair(true) --Try using player money instead
			else
				E:Print(L["Your items have been repaired using guild bank funds for: "]..E:FormatMoney(COST, B.db.moneyFormat, not B.db.moneyCoins))
			end
		elseif TYPE == 'PLAYER' then
			if STATUS == 'PLAYER_REPAIR_FAILED' then
				E:Print(L["You don't have enough money to repair."])
			else
				E:Print(L["Your items have been repaired for: "]..E:FormatMoney(COST, B.db.moneyFormat, not B.db.moneyCoins))
			end
		end
	end

	function M:UI_ERROR_MESSAGE(_, messageType)
		if messageType == ERR_GUILD_NOT_ENOUGH_MONEY then
			STATUS = 'GUILD_REPAIR_FAILED'
		elseif messageType == ERR_NOT_ENOUGH_MONEY then
			STATUS = 'PLAYER_REPAIR_FAILED'
		end
	end
end

function M:MERCHANT_CLOSED()
	M:UnregisterEvent('UI_ERROR_MESSAGE')
	M:UnregisterEvent('UPDATE_INVENTORY_DURABILITY')
	M:UnregisterEvent('MERCHANT_CLOSED')
end

function M:MERCHANT_SHOW()
	if E.db.bags.vendorGrays.enable then E:Delay(0.5, B.VendorGrays, B) end

	if E.db.general.autoRepair == 'NONE' or IsShiftKeyDown() or not CanMerchantRepair() then return end

	--Prepare to catch 'not enough money' messages
	M:RegisterEvent('UI_ERROR_MESSAGE')

	--Use this to unregister events afterwards
	M:RegisterEvent('MERCHANT_CLOSED')

	M:AttemptAutoRepair()
end

function M:DisbandRaidGroup()
	if InCombatLockdown() then return end -- Prevent user error in combat

	local myIndex = UnitInRaid('player')
	if myIndex then
		local _, myRank = GetRaidRosterInfo(myIndex)
		if myRank == 2 then -- real raid leader
			for i = 1, GetNumGroupMembers() do
				if i ~= myIndex then -- dont kick yourself
					local name = GetRaidRosterInfo(i)
					if name then
						UninviteUnit(name)
					end
				end
			end
		end
	elseif not myIndex and UnitIsGroupLeader('player') then
		for i = MAX_PARTY_MEMBERS, 1, -1 do
			local name = UnitName('party'..i)
			if name then
				UninviteUnit(name)
			end
		end
	end

	LeaveParty()
end

function M:PVPMessageEnhancement(_, msg)
	if not E.db.general.enhancedPvpMessages then return end
	local _, instanceType = GetInstanceInfo()
	if instanceType == 'pvp' or instanceType == 'arena' then
		RaidNotice_AddMessage(_G.RaidBossEmoteFrame, msg, _G.ChatTypeInfo.RAID_BOSS_EMOTE)
	end
end

function M:AutoInvite(_, leaderName)
	if not E.db.general.autoAcceptInvite then return end

	if _G.MiniMapLFGFrame:IsShown() then return end
	if IsInGroup() or IsInRaid() then return end

	local numFriends = GetNumFriends()

	if numFriends > 0 then
		_G.ShowFriends()

		for i = 1, numFriends do
			if GetFriendInfo(i) == leaderName then
				AcceptGroup()
				StaticPopup_Hide('PARTY_INVITE')
				return
			end
		end
	end

	if not IsInGuild() then return end

	_G.GuildRoster()

	for i = 1, GetNumGuildMembers() do
		if GetGuildRosterInfo(i) == leaderName then
			AcceptGroup()
			StaticPopup_Hide('PARTY_INVITE')
			return
		end
	end
end

function M:RESURRECT_REQUEST()
	if E.db.general.resurrectSound then
		PlaySoundFile(E.Media.Sounds.Resurrect, 'Master')
	end
end

function M:ADDON_LOADED(_, addon)
	if addon == 'Blizzard_InspectUI' then
		M:SetupInspectPageInfo()
	end
end

function M:QUEST_COMPLETE()
	if not E.db.general.questRewardMostValueIcon then return end

	local firstItem = _G.QuestInfoItem1
	if not firstItem then return end

	local numQuests = GetNumQuestChoices()
	if numQuests < 2 then return end

	local bestValue, bestItem = 0
	for i = 1, numQuests do
		local questLink = GetQuestItemLink('choice', i)
		local sellPrice = questLink and select(11, GetItemInfo(questLink))
		if sellPrice and sellPrice > 0 then
			local _, _, amount = GetQuestItemInfo('choice', i)
			local totalValue = (amount and amount > 0) and (sellPrice * amount) or 0
			if totalValue > bestValue then
				bestValue = totalValue
				bestItem = i
			end
		end
	end

	if bestItem then
		local btn = _G['QuestInfoItem'..bestItem]
		if btn and btn.type == 'choice' then
			M.QuestRewardGoldIconFrame:ClearAllPoints()
			M.QuestRewardGoldIconFrame:Point('TOPRIGHT', btn, 'TOPRIGHT', -2, -2)
			M.QuestRewardGoldIconFrame:Show()
		end
	end
end

function M:Initialize()
	M.Initialized = true

	M:LoadRaidMarker()
	M:LoadLootRoll()
	M:LoadChatBubbles()
	M:LoadLoot()
	M:ToggleItemLevelInfo(true)
	M:ZoneTextToggle()

	M:RegisterEvent('MERCHANT_SHOW')
	M:RegisterEvent('RESURRECT_REQUEST')
	M:RegisterEvent('PLAYER_REGEN_DISABLED', 'ErrorFrameToggle')
	M:RegisterEvent('PLAYER_REGEN_ENABLED', 'ErrorFrameToggle')
	M:RegisterEvent('CHAT_MSG_BG_SYSTEM_HORDE', 'PVPMessageEnhancement')
	M:RegisterEvent('CHAT_MSG_BG_SYSTEM_ALLIANCE', 'PVPMessageEnhancement')
	M:RegisterEvent('CHAT_MSG_BG_SYSTEM_NEUTRAL', 'PVPMessageEnhancement')
	M:RegisterEvent('PARTY_INVITE_REQUEST', 'AutoInvite')
	M:RegisterEvent('RAID_ROSTER_UPDATE', 'AutoInvite')
	M:RegisterEvent('COMBAT_TEXT_UPDATE')
	M:RegisterEvent('QUEST_COMPLETE')
	M:RegisterEvent('ADDON_LOADED')

	for _, addon in next, { 'Blizzard_InspectUI' } do
		if IsAddOnLoaded(addon) then
			M:ADDON_LOADED(nil, addon)
		end
	end

	do	-- questRewardMostValueIcon
		local MostValue = CreateFrame('Frame', 'ElvUI_QuestRewardGoldIconFrame', _G.QuestInfoRewardsFrame)
		MostValue:SetFrameStrata('HIGH')
		MostValue:Size(19)
		MostValue:Hide()

		MostValue.Icon = MostValue:CreateTexture(nil, 'OVERLAY')
		MostValue.Icon:SetAllPoints(MostValue)
		MostValue.Icon:SetTexture(E.Media.Textures.Coins)
		MostValue.Icon:SetTexCoord(0.33, 0.66, 0.022, 0.66)

		M.QuestRewardGoldIconFrame = MostValue

		hooksecurefunc(_G.QuestFrameRewardPanel, 'Hide', function()
			if M.QuestRewardGoldIconFrame then
				M.QuestRewardGoldIconFrame:Hide()
			end
		end)
	end

	if E.db.general.interruptAnnounce ~= 'NONE' then
		M:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	end
end

E:RegisterModule(M:GetName())
