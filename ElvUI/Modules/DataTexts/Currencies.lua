local E, L, V, P, G = unpack(ElvUI)
local DT = E:GetModule('DataTexts')
local LC = E.Libs.Compat

local _G = _G
local format, gsub, match, tonumber, wipe = format, string.gsub, string.match, tonumber, wipe
local pairs, ipairs, unpack, tostring = pairs, ipairs, unpack, tostring

local BreakUpLargeNumbers = LC.BreakUpLargeNumbers
local GetMoney = GetMoney

local GUILDCONTROL_OPTION16 = GUILDCONTROL_OPTION16

local iconString, db = '|T%s:20:20:0:0:64:64:4:60:4:60|t'
DT.CurrencyList = { GOLD = GUILDCONTROL_OPTION16, BACKPACK = 'Backpack' }

local function OnClick()
	_G.ToggleCharacter('TokenFrame')
end

local function AddInfo(id)
	local info, name, icon = DT:CurrencyInfo(id)
	if name then
		local textRight = '%s'
		if db.maxCurrency and info.maxQuantity and info.maxQuantity > 0 then
			textRight = '%s / '..E:ShortValue(BreakUpLargeNumbers(info.maxQuantity))
		end

		DT.tooltip:AddDoubleLine(format('%s %s', icon, name), format(textRight, BreakUpLargeNumbers(info.quantity)), 1, 1, 1, 1, 1, 1)
	end
end

local shownHeaders = {}
local function AddHeader(id, addLine)
	if (not db.headers) or shownHeaders[id] then return end

	if addLine then
		DT.tooltip:AddLine(' ')
	end

	DT.tooltip:AddLine(db.tooltipData[id][1])
	shownHeaders[id] = true
end

local goldText
local function OnEvent(self)
	goldText = E:FormatMoney(GetMoney(), db.goldFormat or 'BLIZZARD', not db.goldCoins)

	local displayed = db.displayedCurrency
	if displayed == 'BACKPACK' then
		local displayString
		for i = 1, 3 do
			local info = DT:BackpackCurrencyInfo(i)
			if info and info.quantity then
				iconString = match(info and info.iconFileID or '', E.myfaction) ~= nil and gsub(iconString, '4:60:4:60', '4:38:2:36') or iconString
				displayString = (i > 1 and displayString..' ' or '')..format('%s %s', format(iconString, info.iconFileID), E:ShortValue(info.quantity))
			end
		end

		self.text:SetText(displayString or goldText)
	elseif displayed == 'GOLD' then
		self.text:SetText(goldText)
	else
		local id = tonumber(displayed)
		if not id then return end

		local info, name, icon = DT:CurrencyInfo(id)
		if not name then return end

		local style = db.displayStyle
		if style == 'ICON' then
			self.text:SetFormattedText('%s %s', icon, E:ShortValue(info.quantity))
		elseif style == 'ICON_TEXT' then
			self.text:SetFormattedText('%s %s: %s', icon, name, E:ShortValue(info.quantity))
		else --ICON_TEXT_ABBR
			self.text:SetFormattedText('%s %s: %s', icon, E:AbbreviateString(name), E:ShortValue(info.quantity))
		end
	end
end

local function OnEnter()
	DT.tooltip:ClearLines()

	wipe(shownHeaders)
	local addLine, addLine2
	for _, info in ipairs(db.tooltipData) do
		local _, id, header = unpack(info)
		if id and db.idEnable[id] then
			AddHeader(header, addLine)
			AddInfo(id)
			addLine = true
		end
	end

	if addLine then
		DT.tooltip:AddLine(' ')
	end

	for id, info in pairs(E.global.datatexts.customCurrencies) do
		if info and not DT.CurrencyList[tostring(id)] and info.currencyTooltip then
			AddInfo(id)
			addLine2 = true
		end
	end

	if addLine2 then
		DT.tooltip:AddLine(' ')
	end

	DT.tooltip:AddDoubleLine(L["Gold"]..':', goldText, nil, nil, nil, 1, 1, 1)
	DT.tooltip:Show()
end

local function ApplySettings(self)
	if not db then
		db = E.global.datatexts.settings[self.name]
	end
end

DT:RegisterDatatext('Currencies', nil, { 'PLAYER_MONEY', 'SEND_MAIL_MONEY_CHANGED', 'SEND_MAIL_COD_CHANGED', 'PLAYER_TRADE_MONEY', 'TRADE_MONEY_CHANGED', 'CHAT_MSG_CURRENCY', 'CURRENCY_DISPLAY_UPDATE' }, OnEvent, nil, OnClick, OnEnter, nil, _G.CURRENCY, nil, ApplySettings)
