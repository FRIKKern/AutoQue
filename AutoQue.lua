-- AutoQue Addon
-- Automatically accepts LFG role checks with inactivity auto-disable feature

-- Initialize the addon namespace
local addonName, addonTable = ...

-- Create the main addon table
local AutoQue = {}
_G.AutoQue = AutoQue -- For debugging purposes

-- Declare variables for libraries
local LibDBIcon
local AutoQueLDB

-- Initialize Saved Variables
local defaultSettings = {
    active = true,
    inactivityDuration = 300, -- Default to 5 minutes
    autoDisable = true,
    toggleOnAccept = true, -- Updated option to toggle on manual accept
    lastAcceptedTime = GetTime(),
    minimap = { hide = false }, -- Minimap button settings
}

-- Create a frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("LFG_ROLE_CHECK_SHOW")
frame:RegisterEvent("LFG_ROLE_CHECK_HIDE") -- To handle role check end

-- Event handler function
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            -- Initialize or update settings
            if not AutoQueDB then
                AutoQueDB = {}
            end
            for k, v in pairs(defaultSettings) do
                if AutoQueDB[k] == nil then
                    AutoQueDB[k] = v
                end
            end
            AutoQue:Initialize()
        end
    elseif event == "LFG_ROLE_CHECK_SHOW" then
        AutoQue:HandleRoleCheck()
    elseif event == "LFG_ROLE_CHECK_HIDE" then
        AutoQue:RemoveAcceptButtonHook()
    end
end)

-- Function to handle role checks
function AutoQue:HandleRoleCheck()
    if AutoQueDB.active then
        CompleteLFGRoleCheck(true)
        print("|cffb048f8AutoQue:|r Role check accepted.")
        -- Update the last accepted time
        AutoQueDB.lastAcceptedTime = GetTime()
    else
        -- If the addon is inactive, set up a hook to detect manual acceptance
        if AutoQueDB.toggleOnAccept and not self.acceptButtonHooked then
            -- Determine the correct accept button
            local acceptButton = self:GetRoleCheckAcceptButton()
            if acceptButton then
                self.originalAcceptButtonOnClick = acceptButton:GetScript("OnClick")
                acceptButton:SetScript("OnClick", function(...)
                    -- Call the original function
                    if self.originalAcceptButtonOnClick then
                        self.originalAcceptButtonOnClick(...)
                    end
                    -- Toggle the addon's active state
                    AutoQue:ToggleActive()
                    print("|cffb048f8AutoQue:|r Toggled auto-accept on due to role check acceptance.")
                    -- Remove the hook after acceptance
                    AutoQue:RemoveAcceptButtonHook()
                end)
                self.acceptButtonHooked = true
            else
                print("|cffb048f8AutoQue:|r Error: Accept button not found.")
            end
        end
    end
end

-- Function to determine the correct accept button based on the role check popup
function AutoQue:GetRoleCheckAcceptButton()
    -- LFDRoleCheckPopup is used for Dungeon Finder
    if LFDRoleCheckPopup and LFDRoleCheckPopupAcceptButton and LFDRoleCheckPopup:IsShown() then
        return LFDRoleCheckPopupAcceptButton
    -- LFGInvitePopup is used for other LFG types
    elseif LFGInvitePopup and LFGInvitePopupAcceptButton and LFGInvitePopup:IsShown() then
        return LFGInvitePopupAcceptButton
    else
        return nil
    end
end

-- Function to remove the accept button hook
function AutoQue:RemoveAcceptButtonHook()
    if self.acceptButtonHooked then
        local acceptButton = self:GetRoleCheckAcceptButton()
        if acceptButton and self.originalAcceptButtonOnClick then
            acceptButton:SetScript("OnClick", self.originalAcceptButtonOnClick)
        end
        self.acceptButtonHooked = false
        self.originalAcceptButtonOnClick = nil
    end
end

-- Function to update the minimap icon and tooltip
function AutoQue:UpdateIconAndTooltip()
    -- Update the minimap icon and data object icon
    local iconTexture = AutoQueDB.active and "Interface/COMMON/Indicator-Green.png" or "Interface/COMMON/Indicator-Red.png"
    if LibDBIcon and LibDBIcon:IsRegistered("AutoQue") then
        local button = LibDBIcon:GetMinimapButton("AutoQue")
        button.icon:SetTexture(iconTexture)
    end
    if AutoQueLDB then
        AutoQueLDB.icon = iconTexture
    end

    -- Refresh the tooltip if it's being shown
    if self.minimapButton and GameTooltip:IsOwned(self.minimapButton) then
        AutoQue:UpdateTooltip()
    end
end

-- Function to toggle the active state
function AutoQue:ToggleActive()
    AutoQueDB.active = not AutoQueDB.active
    if AutoQueDB.active then
        AutoQueDB.lastAcceptedTime = GetTime() -- Reset the timer when re-enabled
        print("|cffb048f8AutoQue:|r Enabled.")
    else
        print("|cffb048f8AutoQue:|r Disabled.")
    end

    -- Update the icon and tooltip
    AutoQue:UpdateIconAndTooltip()
end

-- Function to check for inactivity and auto-disable if necessary
function AutoQue:CheckInactivity()
    if AutoQueDB.active and AutoQueDB.autoDisable then
        local currentTime = GetTime()
        if (currentTime - AutoQueDB.lastAcceptedTime) >= AutoQueDB.inactivityDuration then
            AutoQueDB.active = false
            print("|cffb048f8AutoQue:|r Automatically disabled due to inactivity.")
            -- Update the icon and tooltip
            AutoQue:UpdateIconAndTooltip()
        end
    end
end

-- Function to update the tooltip
function AutoQue:UpdateTooltip()
    GameTooltip:ClearLines()
    GameTooltip:AddLine("AutoQue")
    local active = AutoQueDB and AutoQueDB.active
    GameTooltip:AddLine(active and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")

    -- Add the time remaining before auto-disable, if applicable
    if AutoQueDB.active and AutoQueDB.autoDisable then
        local timeRemaining = AutoQueDB.inactivityDuration - (GetTime() - AutoQueDB.lastAcceptedTime)
        if timeRemaining > 0 then
            local minutes = math.floor(timeRemaining / 60)
            local seconds = math.floor(timeRemaining % 60)
            GameTooltip:AddLine(string.format("Auto-disable in: %d:%02d", minutes, seconds))
        else
            GameTooltip:AddLine("Auto-disable in: 0:00")
        end
    end

    GameTooltip:AddLine("|cff00ff00Left-click|r to toggle.")
    GameTooltip:AddLine("|cff00ff00Right-click|r to open settings.")
    GameTooltip:Show()
end

-- Function to initialize the addon
function AutoQue:Initialize()
    -- Include necessary libraries
    local LDB = LibStub("LibDataBroker-1.1", true)
    LibDBIcon = LibStub("LibDBIcon-1.0", true)

    -- Create the data object for the minimap icon
    if LDB then
        AutoQueLDB = LDB:NewDataObject("AutoQue", {
            type = "data source",
            text = "AutoQue",
            icon = AutoQueDB.active and "Interface/COMMON/Indicator-Green.png" or "Interface/COMMON/Indicator-Red.png",
            OnClick = function(self, button)
                if button == "LeftButton" then
                    AutoQue:ToggleActive()
                elseif button == "RightButton" then
                    AutoQue:OpenOptionsPanel()
                end
            end,
            OnEnter = function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                AutoQue:UpdateTooltip()

                -- Start a timer to update the tooltip every second
                if not AutoQue.tooltipTimer then
                    AutoQue.tooltipTimer = C_Timer.NewTicker(1, function()
                        if GameTooltip:IsOwned(self) then
                            AutoQue:UpdateTooltip()
                        else
                            -- If the tooltip is no longer owned by us, cancel the timer
                            AutoQue.tooltipTimer:Cancel()
                            AutoQue.tooltipTimer = nil
                        end
                    end)
                end
            end,
            OnLeave = function(self)
                GameTooltip:Hide()
                if AutoQue.tooltipTimer then
                    AutoQue.tooltipTimer:Cancel()
                    AutoQue.tooltipTimer = nil
                end
            end,
        })
    end

    -- Register the minimap icon
    if LibDBIcon and AutoQueLDB then
        LibDBIcon:Register("AutoQue", AutoQueLDB, AutoQueDB.minimap)
        if AutoQueDB.minimap.hide then
            LibDBIcon:Hide("AutoQue")
        else
            LibDBIcon:Show("AutoQue")
        end
        -- Store the minimap button reference
        self.minimapButton = LibDBIcon:GetMinimapButton("AutoQue")
    end

    -- Start the inactivity check timer
    self.inactivityTicker = C_Timer.NewTicker(1, function() AutoQue:CheckInactivity() end)

    -- Ensure the accept button is unhooked on initialization
    self.acceptButtonHooked = false
    self.originalAcceptButtonOnClick = nil

    -- Create the options panel
    AutoQue:CreateOptionsPanel()
end

-- Function to create the options panel
function AutoQue:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "AutoQueOptionsPanel", UIParent)
    panel.name = "AutoQue"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("AutoQue Settings")

    -- Checkbox for auto-disable feature
    local autoDisableCheckbox = CreateFrame("CheckButton", "AutoQueAutoDisableCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    autoDisableCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    autoDisableCheckbox.text = _G[autoDisableCheckbox:GetName() .. "Text"]
    autoDisableCheckbox.text:SetText("Enable auto-disable after inactivity")
    autoDisableCheckbox:SetChecked(AutoQueDB.autoDisable)
    autoDisableCheckbox:SetScript("OnClick", function(self)
        AutoQueDB.autoDisable = self:GetChecked()
    end)

    -- Slider label
    local durationSliderLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    durationSliderLabel:SetPoint("TOPLEFT", autoDisableCheckbox, "BOTTOMLEFT", 0, -20)
    durationSliderLabel:SetText("Inactivity Duration (minutes)")

    -- Slider for inactivity duration
    local durationSlider = CreateFrame("Slider", "AutoQueDurationSlider", panel, "OptionsSliderTemplate")
    durationSlider:SetPoint("TOPLEFT", durationSliderLabel, "BOTTOMLEFT", 0, -10)
    durationSlider:SetMinMaxValues(60, 1800) -- 1 minute to 30 minutes
    durationSlider:SetValueStep(60)
    durationSlider:SetObeyStepOnDrag(true)
    durationSlider:SetValue(AutoQueDB.inactivityDuration)
    durationSlider:SetWidth(200)
    _G[durationSlider:GetName() .. 'Low']:SetText('1')
    _G[durationSlider:GetName() .. 'High']:SetText('30')
    _G[durationSlider:GetName() .. 'Text']:SetText('') -- Hide default text

    -- Display the slider value
    local durationSliderValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    durationSliderValue:SetPoint("LEFT", durationSlider, "RIGHT", 10, 0)
    durationSliderValue:SetText(string.format("%d minutes", AutoQueDB.inactivityDuration / 60))

    -- Update the value display when the slider changes
    durationSlider:SetScript("OnValueChanged", function(self, value)
        AutoQueDB.inactivityDuration = value
        durationSliderValue:SetText(string.format("%d minutes", value / 60))
    end)

    -- Checkbox for toggle on accept feature
    local toggleCheckbox = CreateFrame("CheckButton", "AutoQueToggleCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    toggleCheckbox:SetPoint("TOPLEFT", durationSlider, "BOTTOMLEFT", -10, -30)
    toggleCheckbox.text = _G[toggleCheckbox:GetName() .. "Text"]
    toggleCheckbox.text:SetText("Toggle auto-accept when accepting role check")
    toggleCheckbox:SetChecked(AutoQueDB.toggleOnAccept)
    toggleCheckbox:SetScript("OnClick", function(self)
        AutoQueDB.toggleOnAccept = self:GetChecked()
    end)

    -- Refresh function to update the panel
    panel.refresh = function()
        autoDisableCheckbox:SetChecked(AutoQueDB.autoDisable)
        durationSlider:SetValue(AutoQueDB.inactivityDuration)
        durationSliderValue:SetText(string.format("%d minutes", AutoQueDB.inactivityDuration / 60))
        toggleCheckbox:SetChecked(AutoQueDB.toggleOnAccept)
    end

    panel:SetScript("OnShow", panel.refresh)

    -- Store the panel reference
    self.optionsPanel = panel

    -- Register the panel
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- Use the new Settings API for Dragonflight and later
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.optionsCategory = category
    else
        -- Fallback for older versions of WoW
        InterfaceOptions_AddCategory(panel)
    end
end

-- Function to open the options panel
function AutoQue:OpenOptionsPanel()
    if Settings and Settings.OpenToCategory and self.optionsCategory then
        -- Use the new Settings API
        Settings.OpenToCategory(self.optionsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory and self.optionsPanel then
        -- Fallback for older versions
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    else
        print("|cffb048f8AutoQue:|r Unable to open options panel.")
    end
end
