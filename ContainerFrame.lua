--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local GetSlotId = addon.GetSlotId 
local GetBagSlotFromId = addon.GetBagSlotFromId

local ITEM_SIZE = addon.ITEM_SIZE
local ITEM_SPACING = addon.ITEM_SPACING
local SECTION_SPACING = addon. SECTION_SPACING
local BAG_WIDTH = addon.BAG_WIDTH
local BAG_INSET = addon.BAG_INSET
local TOP_PADDING = addon.TOP_PADDING

--------------------------------------------------------------------------------
-- Widget scripts
--------------------------------------------------------------------------------

local function CloseButton_OnClick(button)
	button:GetParent():Hide()
end

local function BagSlotButton_OnClick(button)
	if button:GetChecked() then
		button.panel:Show()
	else
		button.panel:Hide()
	end
end

local function BagSlotButton_OnEnter(button)
	GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT", -8, 0)
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Equipped bags", 1, 1, 1)
	GameTooltip:AddLine("Click to show/hide the equipped bags so you can change them.")
	GameTooltip:Show()
end

local function BagSlotButton_OnLeave(button)
	if GameTooltip:GetOwner() == button then
		GameTooltip:Hide()
	end
end

--------------------------------------------------------------------------------
-- Bag creation
--------------------------------------------------------------------------------

local containerClass, containerProto = addon:NewClass("Containter", "Frame", "AceEvent-3.0", "AceBucket-3.0")

function addon:CreateContainerFrame(...) return containerClass:Create(...) end

local bagSlots = {}
function containerProto:OnCreate(name, bags, isBank)
	self:SetParent(UIParent)
	self:EnableMouse(true)
	self:SetScale(0.8)
	self:SetFrameStrata("HIGH")

	self:SetBackdrop(addon.BACKDROP)
	self:SetBackdropColor(0, 0, 0, 1)
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)

	self.name = name
	self.bags = bags
	self.isBank = isBank
	self.buttons = {}
	self.content = {}
	self.stacks = {}
	self.sections = {}
	
	self.added = {}
	self.removed = {}

	for bag in pairs(self.bags) do
		self.content[bag] = { size = 0 }
		tinsert(bagSlots, bag)
	end
	
	local bagSlotPanel = addon:CreateBagSlotPanel(self, name, bagSlots, isBank)
	bagSlotPanel:Hide()
	wipe(bagSlots)

	local closeButton = CreateFrame("Button", nil, self, "UIPanelCloseButton")
	self.closeButton = closeButton
	closeButton:SetPoint("TOPRIGHT")
	closeButton:SetScript('OnClick', CloseButton_OnClick)

	local bagSlotButton = CreateFrame("CheckButton", nil, self)
	bagSlotButton:SetNormalTexture([[Interface\Buttons\Button-Backpack-Up]])
	bagSlotButton:SetCheckedTexture([[Interface\Buttons\CheckButtonHilight]])
	bagSlotButton:GetCheckedTexture():SetBlendMode("ADD")
	bagSlotButton:SetScript('OnClick', BagSlotButton_OnClick)
	bagSlotButton:SetScript('OnEnter', BagSlotButton_OnEnter)
	bagSlotButton:SetScript('OnLeave', BagSlotButton_OnLeave)
	bagSlotButton.panel = bagSlotPanel
	bagSlotButton:SetWidth(18)
	bagSlotButton:SetHeight(18)
	bagSlotButton:SetPoint("TOPLEFT", BAG_INSET, -BAG_INSET)

	local title = self:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
	title:SetText(name)
	title:SetTextColor(1, 1, 1)
	title:SetHeight(18)
	title:SetJustifyH("LEFT")
	title:SetPoint("TOPLEFT", bagSlotButton, "TOPRIGHT", 4, 0)
	title:SetPoint("RIGHT", closeButton, "LEFT", -4, 0)
end

function containerProto:ToString() return self.name or self:GetName() end

--------------------------------------------------------------------------------
-- Scripts & event handlers
--------------------------------------------------------------------------------

function containerProto:OnShow()
	self:Debug('OnShow')
	if self.isBank then
		self:RegisterEvent('BANKFRAME_CLOSED', "Hide")
	end
	self.bucketHandle = self:RegisterBucketEvent('BAG_UPDATE', 0.1, "BagsUpdated")
	self:RegisterEvent('EQUIPMENT_SWAP_FINISHED')
	self:RegisterEvent('EQUIPMENT_SWAP_PENDING')
	self:UpdateAllContent(event)
end

function containerProto:OnHide()
	self:UnregisterAllEvents()
	self:UnregisterAllBuckets()
end

function containerProto:EQUIPMENT_SWAP_PENDING(event)
	if self.bucketHandle then
		self:UnregisterBucketEvent(self.bucketHandle)
		self.bucketHandle = nil
	end
end

function containerProto:EQUIPMENT_SWAP_FINISHED(event)
	if not self.bucketHandle then
		self.bucketHandle = self:RegisterBucketEvent('BAG_UPDATE', 0.1, "BagsUpdated")
		self:UpdateAllContent(event)
	end
end

--------------------------------------------------------------------------------
-- Bag content scanning
--------------------------------------------------------------------------------

function containerProto:UpdateContent(event, bag)
	self:Debug('UpdateContent', event, bag)
	local added, removed = self.added, self.removed
	local content = self.content[bag]
	local newSize = GetContainerNumSlots(bag)
	content.family = select(2, GetContainerNumFreeSlots(bag))
	for slot = 1, newSize do
		local oldItem, newItem = content[slot], (GetContainerItemLink(bag, slot) or false)
		if oldItem ~= newItem then
			content[slot] = newItem
			local slotId = GetSlotId(bag, slot)
			added[slotId] = newItem
			removed[slotId] = oldItem
		end
	end
	for slot = content.size, newSize + 1, -1 do
		removed[GetSlotId(bag, slot)] = content[slot]
		content[slot] = nil
	end
	content.size = newSize
end

function containerProto:UpdateAllContent(event)
	for bag in pairs(self.bags) do
		self:UpdateContent("OnShow", bag)
	end
	return self:Update('OnShow', true)
end

function containerProto:HasContentChanged()
	return not not (next(self.added) or next(self.removed))
end

function containerProto:BagsUpdated(bags)
	self:Debug('BagsUpdated', bags)
	for bag in pairs(bags) do
		if self.bags[bag] then
			self:UpdateContent("BagsUpdated", bag)
		end
	end
	if self:HasContentChanged() then
		self:Debug('BagsUpdated: content changed')
		return self:Update("BagsUpdated")
	else
		self:Debug('BagsUpdated: only update buttons')
		for i, button in pairs(self.buttons) do
			if bags[button.bag] then
				button:FullUpdate("BagsUpdated")
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Item dispatching
--------------------------------------------------------------------------------

function containerProto:GetStackButton(key)
	local stack = self.stacks[key]
	if not stack then
		stack = addon:AcquireStackButton(key)
		self.stacks[key] = stack
	end
	return stack
end

function containerProto:GetSection(name)
	local section = self.sections[name]
	if not section then
		section = addon:AcquireSection(self, name)
		self.sections[name] = section
	end
	return section
end

function containerProto:DispatchItem(slotId, link)
	local sectionName, stackType, stackData
	local bag, slot = GetBagSlotFromId(slotId)
	if link then
		local itemId = tonumber(link:match('item:(%d+)'))
		sectionName, stackType, stackData = addon:Filter(bag, slot, itemId, link)
	else
		sectionName, stackType, stackData = "Free", 'free', '-'
	end
	local button = self.buttons[slotId]
	if stackType then
		local key = strjoin(':', tostringall(stackType, stackData, self.content[bag].family))
		button = self:GetStackButton(key)
		button:AddSlot(slotId)
	elseif not button then
		button = addon:AcquireItemButton()
		button:SetBagSlot(bag, slot)
	end
	local section = self:GetSection(sectionName)
	section:AddItemButton(slotId, button)
	self.buttons[slotId] = button
end

function containerProto:RemoveSlot(slotId)
	local button = self.buttons[slotId]
	if button then
		self.buttons[slotId] = nil
		if button:IsStack() then
			button:RemoveSlot(slotId)
			if button:IsEmpty() then
				self:Debug('Removing empty stack', button)
				self.stacks[button:GetKey()] = nil
				button:Release()
			end
		else
			self:Debug('Removing item', button)
			button:Release()
		end
	end
end

function containerProto:Update(event, forceLayout)
	local dirtyLayout = forceLayout	

	if self:HasContentChanged() then
		self:Debug('Updating on', event)
		
		local added, removed = self.added, self.removed

		local n
		if next(removed) then
			n = 0
			for slotId in pairs(removed) do
				self:RemoveSlot(slotId)
				n = n + 1
			end	
			self:Debug('Removed', n, 'items')
			wipe(removed)
		end

		if next(added) then
			addon:PreFilter(event, self)
			n = 0
			for slotId, link in pairs(added) do
				self:DispatchItem(slotId, link)
				n = n + 1
			end
			self:Debug('Added', n, 'items')
			wipe(added)
			addon:PostFilter(event, self)		
		end

		for name, section in pairs(self.sections) do
			if section:DispatchDone(event) then
				dirtyLayout = true
			end
		end
	end

	if dirtyLayout then
		self:Debug('Update: dirty layout')
		self:Layout(event, forceLayout)
	end
end

--------------------------------------------------------------------------------
-- Section layout
--------------------------------------------------------------------------------

local function CompareSections(a, b)
	local numA, numB = a.count, b.count
	if numA == numB then
		return a.name < b.name
	else
		return numA > numB
	end
end

local function GetBestSection(sections, remainingWidth)
	local bestIndex, leastWasted
	for index, section in ipairs(sections) do
		local wasted = remainingWidth - section:GetWidth()
		if wasted >= 0 and (not leastWasted or wasted < leastWasted) then
			bestIndex, leastWasted = index, wasted
		end
	end
	if bestIndex then
		return tremove(sections, bestIndex)
	end
end

local orderedSections = {}
function containerProto:Layout(event, forceLayout)
	self:Debug('Layout required')
	
	for name, section in pairs(self.sections) do
		if section:LayoutButtons(event, forceLayout) then
			tinsert(orderedSections, section)
		else
			section:Release()
			self.sections[name] = nil
		end
	end

	table.sort(orderedSections, CompareSections)

	local bagWidth = ITEM_SIZE * BAG_WIDTH + ITEM_SPACING * (BAG_WIDTH - 1)
	local y, realWidth = 0, 0

	while next(orderedSections) do
		local rowHeight, x = 0, 0
		local section = tremove(orderedSections, 1)
		while section do
			section:SetPoint('TOPLEFT', BAG_INSET + x, - TOP_PADDING - y)
			section:Show()
			
			local sectionWidth = section:GetWidth()
			realWidth = math.max(realWidth, x + sectionWidth)
			rowHeight = math.max(rowHeight, section:GetHeight())
			
			x = x + sectionWidth + SECTION_SPACING
			
			section = GetBestSection(orderedSections, bagWidth - x)
		end
		y = y + rowHeight + ITEM_SPACING
	end

	self:SetWidth(BAG_INSET * 2 + realWidth)
	self:SetHeight(BAG_INSET + TOP_PADDING + y - ITEM_SPACING)
end
