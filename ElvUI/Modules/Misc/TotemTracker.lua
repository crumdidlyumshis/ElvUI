local E, L, V, P, G = unpack(ElvUI)
local TM = E:GetModule('TotemTracker')
local AB = E:GetModule('ActionBars')

local _G = _G

local CreateFrame = CreateFrame
local GetTotemInfo = GetTotemInfo
local MAX_TOTEMS = MAX_TOTEMS

local priority = E.myclass == 'SHAMAN' and { [1]=1, [2]=2, [3]=4, [4]=3 } or TOTEM_PRIORITIES


function TM:UpdateButton(button, totem)
	if not (button and totem) then return end

	local haveTotem, _, startTime, duration, icon = GetTotemInfo(totem:GetID() or totem.slot)
	button:SetShown(haveTotem and duration > 0)

	if haveTotem then
		button.icon:SetTexture(icon)
		button.cooldown:SetCooldown(startTime, duration)

		if totem:GetParent() ~= button.holder then
			totem:ClearAllPoints()
			totem:SetParent(button.holder)
			totem:SetAllPoints(button.holder)
		end
	end
end

function TM:Update()
	for i = 1, MAX_TOTEMS do
		TM:UpdateButton(TM.bar[priority[i]], _G['TotemFrameTotem'..i])
	end
end

function TM:PositionAndSize()
	if not E.private.general.totemTracker then return end

	for i = 1, MAX_TOTEMS do
		local button = TM.bar[i]
		local prevButton = TM.bar[i-1]
		local width = TM.db.size
		local height = TM.db.keepSizeRatio and TM.db.size or TM.db.height

		button:Size(width, height)
		button:ClearAllPoints()

		AB:TrimIcon(button)

		if TM.db.growthDirection == 'HORIZONTAL' and TM.db.sortDirection == 'ASCENDING' then
			if i == 1 then
				button:Point('LEFT', TM.bar, 'LEFT', TM.db.spacing, 0)
			elseif prevButton then
				button:Point('LEFT', prevButton, 'RIGHT', TM.db.spacing, 0)
			end
		elseif TM.db.growthDirection == 'VERTICAL' and TM.db.sortDirection == 'ASCENDING' then
			if i == 1 then
				button:Point('TOP', TM.bar, 'TOP', 0, -TM.db.spacing)
			elseif prevButton then
				button:Point('TOP', prevButton, 'BOTTOM', 0, -TM.db.spacing)
			end
		elseif TM.db.growthDirection == 'HORIZONTAL' and TM.db.sortDirection == 'DESCENDING' then
			if i == 1 then
				button:Point('RIGHT', TM.bar, 'RIGHT', -TM.db.spacing, 0)
			elseif prevButton then
				button:Point('RIGHT', prevButton, 'LEFT', -TM.db.spacing, 0)
			end
		else
			if i == 1 then
				button:Point('BOTTOM', TM.bar, 'BOTTOM', 0, TM.db.spacing)
			elseif prevButton then
				button:Point('BOTTOM', prevButton, 'TOP', 0, TM.db.spacing)
			end
		end
	end

	if TM.db.growthDirection == 'HORIZONTAL' then
		TM.bar:Width(TM.db.size * MAX_TOTEMS + TM.db.spacing * MAX_TOTEMS + TM.db.spacing)
		TM.bar:Height(TM.db.size + TM.db.spacing * 2)
	else
		TM.bar:Height(TM.db.size * MAX_TOTEMS + TM.db.spacing * MAX_TOTEMS + TM.db.spacing)
		TM.bar:Width(TM.db.size + TM.db.spacing * 2)
	end

	TM:Update()
end

function TM:Initialize()
	TM.Initialized = true

	if not E.private.general.totemTracker then return end

	local bar = CreateFrame('Frame', 'ElvUI_TotemTracker', E.UIParent)
	bar:Point('BOTTOMLEFT', E.UIParent, 'BOTTOMLEFT', 490, 4)

	TM.bar = bar
	TM.db = E.db.general.totems

	for i = 1, MAX_TOTEMS do
		local button = CreateFrame('Button', bar:GetName()..'Totem'..i, bar)
		button:SetID(i)
		button:SetTemplate()
		button:StyleButton()
		button:Hide()

		button.db = TM.db

		button.holder = CreateFrame('Frame', nil, button)
		button.holder:SetAlpha(0)
		button.holder:SetAllPoints()

		button.icon = button:CreateTexture(nil, 'ARTWORK')
		button.icon:SetInside()

		button.cooldown = CreateFrame('Cooldown', button:GetName()..'Cooldown', button, 'CooldownFrameTemplate')
		button.cooldown:SetReverse(true)
		button.cooldown:SetInside()

		E:RegisterCooldown(button.cooldown)

		TM.bar[i] = button
	end

	TM:PositionAndSize()

	TM:RegisterEvent('PLAYER_TOTEM_UPDATE', 'Update')
	TM:RegisterEvent('PLAYER_ENTERING_WORLD', 'Update')
	TM:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED', 'Update')

	E:CreateMover(bar, 'TotemTrackerMover', L["Totem Tracker"], nil, nil, nil, nil, nil, 'general,totems')
end

local function InitializeCallback()
	TM:Initialize()
end

E:RegisterModule(TM:GetName(), InitializeCallback)
