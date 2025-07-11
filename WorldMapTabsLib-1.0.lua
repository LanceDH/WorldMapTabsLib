local lib, oldminor = LibStub:NewLibrary('WorldMapTabsLib-1.0', 0);

if not lib then return; end

----------------------
-- Default Mixin
----------------------
WMTL_DefaultTabMixin = CreateFromMixins(QuestLogTabButtonMixin);

function WMTL_DefaultTabMixin:OnMouseDown(button)
	if (not self.Icon) then return; end
	QuestLogTabButtonMixin.OnMouseDown(self, button);
end

function WMTL_DefaultTabMixin:OnMouseUp(button, upInside)
	if (not self.Icon) then return; end
	QuestLogTabButtonMixin.OnMouseUp(self, button, upInside);
end

function WMTL_DefaultTabMixin:OnEnter()
	if (not self.tooltipText) then return; end
	QuestLogTabButtonMixin.OnEnter(self);
end

function WMTL_DefaultTabMixin:SetChecked(checked)
	if (not self.Icon or not self.SelectedTexture) then return; end

	local alpha = 1;
	if (self.activeAtlas) then
		-- Ensure inactiveAtlas isn't empty
		if (not self.inactiveAtlas) then
			self.inactiveAtlas = self.activeAtlas;
		end

		QuestLogTabButtonMixin.SetChecked(self, checked);

		if(not checked) then
			alpha = self.activeAtlas == self.inactiveAtlas and 0.55 or 1;
		end

		if (not self.useAtlasSize) then
			self.Icon:SetSize(28, 28);
		end

	elseif (self.activeTexture) then
		-- Ensure inactiveTexture isn't empty
		if (not self.inactiveTexture) then
			self.inactiveTexture = self.activeTexture;
		end

		if (checked) then
			self.Icon:SetTexture(self.activeTexture);
		else
			self.Icon:SetTexture(self.inactiveTexture or self.activeTexture);
			alpha = self.activeTexture == self.inactiveTexture and 0.55 or 1;
		end
		self.Icon:SetSize(28, 28);
		self.SelectedTexture:SetShown(checked);
	end

	self.Icon:SetAlpha(alpha);
end

----------------------
-- Local Functions
----------------------

local MAX_TABS_PER_COLUMN = 8;

local function PlaceTabs()
	local totalIndex = 0;

	if (QuestMapFrame.QuestsTab:IsShown()) then totalIndex = totalIndex + 1; end
	if (QuestMapFrame.EventsTab:IsShown()) then totalIndex = totalIndex + 1; end
	if (QuestMapFrame.MapLegendTab:IsShown()) then totalIndex = totalIndex + 1; end

	local anchorTab = QuestMapFrame.MapLegendTab;

	local shownTabs = {};
	for k, tab in ipairs(lib.tabs) do
		if (tab:IsShown()) then
			tab:ClearAllPoints();
			
			local column = floor(totalIndex / MAX_TABS_PER_COLUMN);
			local row = totalIndex % MAX_TABS_PER_COLUMN;

			if (row == 0) then
				if (column == 1) then
					anchorTab = QuestMapFrame.QuestsTab;
				else
					anchorTab = shownTabs[#shownTabs + 1 - MAX_TABS_PER_COLUMN];
				end

				tab:SetPoint("TOPLEFT", anchorTab, "TOPRIGHT", 0, 0);
			else
				tab:SetPoint("TOPLEFT", anchorTab, "BOTTOMLEFT", 0, -3);
			end
	
			anchorTab = tab;

			totalIndex = totalIndex + 1;
			tinsert(shownTabs, tab);
		end
	end
end

local function OnMouseUpInternal(tab, button, upInside)
	if (button == "LeftButton" and upInside) then
		QuestMapFrame:SetDisplayMode(tab.displayMode);
	end
end

local function OnShowInternal(tab)
	PlaceTabs();
end

local function OnHideInternal(tab)
	-- If the active tab gets hidden, revert to official quest tab
	if (QuestMapFrame.displayMode == tab.displayMode) then
		QuestMapFrame:SetDisplayMode(QuestLogDisplayMode.Quests);
	end

	PlaceTabs();
end

local BASE_TAB_ID = 100;

local function RegisterTab(tab)
	local id = BASE_TAB_ID + #lib.tabs;
	tab.displayMode = id;
	tinsert(lib.tabs, tab);

	-- In case the provided tab doesn't have parentArray set, add it manually
	local alreadyInArray = false;
	for _, v in ipairs(QuestMapFrame.TabButtons) do
		if (v == tab) then
			alreadyInArray = true;
			break;
		end
	end

	if (not alreadyInArray) then
		tinsert(QuestMapFrame.TabButtons, tab);
	end

	tab:Show();
	tab:SetChecked(false);

	tab:HookScript("OnMouseUp", OnMouseUpInternal);
	tab:HookScript("OnShow", OnShowInternal);
	tab:HookScript("OnHide", OnHideInternal);
	
	PlaceTabs();
end

----------------------
-- Public functions
----------------------

-- Create a basic tab using provided data, or from a provided template
function lib:CreateTab(data, name)
	if (not lib.tabs) then
		lib.tabs = {};
	end

	name = name or ("WMTL_Tab_" .. #lib.tabs);
	local usingTemplate = type(data) =="string";
	local template = usingTemplate and data or "QuestLogTabButtonTemplate";
	local newTab = CreateFrame("BUTTON", name, QuestMapFrame, template);
	if(not usingTemplate) then
		Mixin(newTab, WMTL_DefaultTabMixin);
	end

	if (type(data) == "table") then
		newTab.tooltipText = data.tooltipText;
		newTab.useAtlasSize = data.useAtlasSize;
		newTab.activeAtlas = data.activeAtlas;
		newTab.inactiveAtlas = data.inactiveAtlas or newTab.activeAtlas;
		newTab.activeTexture = data.activeTexture;
		newTab.inactiveTexture = data.inactiveTexture or newTab.activeTexture;
	end

	RegisterTab(newTab);

	return newTab;
end

-- Add a custom made tab to the list
function lib:AddCustomTab(tab)
	if (not lib.tabs) then
		lib.tabs = {};
	end

	tab:SetParent(QuestMapFrame);
	RegisterTab(tab);

	return tab;
end

-- Create a base content frame attached to the provided tab
-- Attached to the QuestMapFrame and will show and hide if the tab is selected
function lib:CreateContentFrameForTab(tab, template, name)
	if (not tab.displayMode) then return; end

	name = name or ("WMTL_ContentFrame" .. tab.displayMode);
	local contentFrame = CreateFrame("Frame", name, QuestMapFrame, template);
	contentFrame:SetAllPoints(QuestMapFrame);
	lib:LinkTabToContentFrame(tab, contentFrame)
	return contentFrame;
end

-- Attach an existing frame to a tab, making it show or hide if the tab is selected
function lib:LinkTabToContentFrame(tab, contentFrame)
	if (not tab or not tab.displayMode or not contentFrame) then return; end
	
	contentFrame.displayMode = tab.displayMode;
	contentFrame:SetParent(QuestMapFrame);

	-- In case the provided tab doesn't have parentArray set, add it manually
	local alreadyInArray = false;
	for _, v in ipairs(QuestMapFrame.ContentFrames) do
		if (v == contentFrame) then
			alreadyInArray = true;
			break;
		end
	end

	if (not alreadyInArray) then
		tinsert(QuestMapFrame.ContentFrames, contentFrame);
	end

	-- Hide the frame because we're probably starting on the official quest log
	contentFrame:Hide();
end