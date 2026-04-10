local FIRST_DANCE_READY_SPELL_ID = 470678
local FIRST_DANCE_LOADING_SPELL_ID = 470677

local ADDON_NAME = "FirstDance"
local ICON_DURATION = 6

local DEFAULTS = {
    showIcon = true,
    iconOffsetX = 0,
    iconOffsetY = 120,
    iconSize = 72,
    readyTtsEnabled = true,
    readyText = "First Dance",
    readyRate = 2,
    readyVolume = 100,
}

local countdownTicker
local countdownExpiresAt
local iconPreviewActive
local iconFrame
local configPanel

local function InitDB()
    if not FirstDanceDB then
        FirstDanceDB = {}
    end

    if FirstDanceDB.iconSize == nil then
        FirstDanceDB.iconSize = FirstDanceDB.iconSizeX or FirstDanceDB.iconSizeY or DEFAULTS.iconSize
    end

    for key, value in pairs(DEFAULTS) do
        if FirstDanceDB[key] == nil then
            FirstDanceDB[key] = value
        end
    end
end

local function SpeakText(text, rate, volume)
    local voices = C_VoiceChat.GetTtsVoices()
    if not voices or #voices == 0 then
        return
    end

    local voice = voices[1]
    C_VoiceChat.SpeakText(voice.voiceID, text, rate or 0, volume or 100, true)
end

local function ClampVolume(value, fallback)
    return math.max(0, math.min(100, tonumber(value) or fallback))
end

local function ClampInteger(value, minimum, maximum, fallback)
    local number = tonumber(value)
    if number == nil then
        return fallback
    end

    return math.max(minimum, math.min(maximum, math.floor(number + 0.5)))
end

local function GetReadyRate(value, fallback)
    local rate = tonumber(value)
    if rate == nil then
        return fallback
    end

    return rate
end

local function PlayReadySound()
    if not FirstDanceDB.readyTtsEnabled then
        return
    end

    SpeakText(
        FirstDanceDB.readyText or DEFAULTS.readyText,
        FirstDanceDB.readyRate or DEFAULTS.readyRate,
        FirstDanceDB.readyVolume or DEFAULTS.readyVolume
    )
end

local function GetSpellIconTexture(spellID)
    local getSpellTexture = rawget(_G, "GetSpellTexture")
    if getSpellTexture then
        return getSpellTexture(spellID)
    end

    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end

    return nil
end

local function ClearCooldownFrame(cooldownFrame)
    if not cooldownFrame then
        return
    end

    local clearCooldown = rawget(_G, "CooldownFrame_Clear")
    if clearCooldown then
        clearCooldown(cooldownFrame)
        return
    end

    if cooldownFrame.Clear then
        cooldownFrame:Clear()
    end
end

local function UpdateCountdownText()
    if not iconFrame or not iconFrame:IsShown() or not countdownExpiresAt then
        return
    end

    local remaining = countdownExpiresAt - GetTime()
    if remaining <= 0 then
        iconFrame.countdownText:SetText("")
        return
    end

    iconFrame.countdownText:SetText(tostring(math.ceil(remaining)))
end

local function ApplyIconLayout()
    if not iconFrame then
        return
    end

    local size = FirstDanceDB.iconSize or DEFAULTS.iconSize
    local offsetX = FirstDanceDB.iconOffsetX or DEFAULTS.iconOffsetX
    local offsetY = FirstDanceDB.iconOffsetY or DEFAULTS.iconOffsetY

    iconFrame:ClearAllPoints()
    iconFrame:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
    iconFrame:SetSize(size, size)
end

local function StopCountdown()
    if countdownTicker then
        countdownTicker:Cancel()
        countdownTicker = nil
    end

    countdownExpiresAt = nil
    iconPreviewActive = false

    if iconFrame then
        ClearCooldownFrame(iconFrame.cooldown)
        iconFrame.countdownText:SetText("")
        iconFrame:Hide()
    end
end

local function ShowIconPreview()
    StopCountdown()

    if not iconFrame then
        return
    end

    local texture = GetSpellIconTexture(FIRST_DANCE_LOADING_SPELL_ID) or GetSpellIconTexture(FIRST_DANCE_READY_SPELL_ID)
    if texture then
        iconFrame.icon:SetTexture(texture)
    end

    iconPreviewActive = true
    ApplyIconLayout()
    ClearCooldownFrame(iconFrame.cooldown)
    iconFrame.countdownText:SetText("6")
    iconFrame:Show()
end

local function StartCountdown(forceShow)
    StopCountdown()

    if not iconFrame then
        return
    end

    if not forceShow and not FirstDanceDB.showIcon then
        return
    end

    local texture = GetSpellIconTexture(FIRST_DANCE_LOADING_SPELL_ID) or GetSpellIconTexture(FIRST_DANCE_READY_SPELL_ID)
    if texture then
        iconFrame.icon:SetTexture(texture)
    end

    ApplyIconLayout()
    countdownExpiresAt = GetTime() + ICON_DURATION
    iconFrame.cooldown:SetCooldown(GetTime(), ICON_DURATION)
    iconFrame:Show()
    UpdateCountdownText()

    countdownTicker = C_Timer.NewTicker(0.1, function()
        UpdateCountdownText()

        if countdownExpiresAt and GetTime() >= countdownExpiresAt then
            countdownTicker:Cancel()
            countdownTicker = nil

            if iconPreviewActive then
                countdownExpiresAt = nil
                ClearCooldownFrame(iconFrame.cooldown)
                iconFrame.countdownText:SetText("1")
                return
            end

            StopCountdown()
        end
    end)
end

local function CreateCountdownIcon()
    local frame = CreateFrame("Button", "FirstDanceCountdownIcon", UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local screenX, screenY = self:GetCenter()
        local uiCenterX, uiCenterY = UIParent:GetCenter()
        local newX = math.max(-800, math.min(800, math.floor(screenX - uiCenterX + 0.5)))
        local newY = math.max(-600, math.min(600, math.floor(screenY - uiCenterY + 0.5)))
        FirstDanceDB.iconOffsetX = newX
        FirstDanceDB.iconOffsetY = newY
        ApplyIconLayout()
        if configPanel then
            if configPanel.offsetXSlider then configPanel.offsetXSlider:SetValue(newX) end
            if configPanel.offsetYSlider then configPanel.offsetYSlider:SetValue(newY) end
        end
    end)
    frame:Hide()

    local icon = frame:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexture(GetSpellIconTexture(FIRST_DANCE_LOADING_SPELL_ID) or 134400)
    frame.icon = icon

    local border = frame:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    frame.border = border

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    frame.cooldown = cooldown

    local countdownText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    countdownText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    countdownText:SetText("")
    frame.countdownText = countdownText

    local Masque = LibStub and LibStub("Masque", true)
    if Masque then
        local group = Masque:Group("FirstDance")
        group:AddButton(frame, {
            Icon     = frame.icon,
            Border   = frame.border,
            Cooldown = frame.cooldown,
        })
    end

    return frame
end

local function CreateSlider(parent, labelText, anchor, offsetY, minValue, maxValue, step, initialValue, onValueChanged)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    label:SetText(labelText)

    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("RIGHT", parent.InsetBg, "RIGHT", -8, 0)
    valueText:SetPoint("TOP", label, "TOP", 0, 0)
    valueText:SetText(tostring(initialValue))

    local incrementButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    incrementButton:SetSize(24, 20)
    incrementButton:SetPoint("RIGHT", valueText, "LEFT", -4, 0)
    incrementButton:SetPoint("TOP", label, "TOP", 0, 2)
    incrementButton:SetText(">")

    local decrementButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    decrementButton:SetSize(24, 20)
    decrementButton:SetPoint("RIGHT", incrementButton, "LEFT", -2, 0)
    decrementButton:SetPoint("TOP", label, "TOP", 0, 2)
    decrementButton:SetText("<")

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    slider:SetPoint("TOPRIGHT", parent.InsetBg, "TOPRIGHT", -86, 0)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(initialValue)

    local low = slider.Low or _G[slider:GetName() and slider:GetName() .. "Low"]
    local high = slider.High or _G[slider:GetName() and slider:GetName() .. "High"]
    local text = slider.Text or _G[slider:GetName() and slider:GetName() .. "Text"]
    if low then
        low:SetText(tostring(minValue))
    end
    if high then
        high:SetText(tostring(maxValue))
    end
    if text then
        text:SetText("")
    end

    local function SnapValue(value)
        return math.max(minValue, math.min(maxValue, math.floor((value / step) + 0.5) * step))
    end

    local function SetSliderValue(value)
        slider:SetValue(SnapValue(value))
    end

    slider:SetScript("OnValueChanged", function(_, value)
        local snappedValue = SnapValue(value)
        valueText:SetText(tostring(snappedValue))
        onValueChanged(snappedValue)
    end)

    decrementButton:SetScript("OnClick", function()
        SetSliderValue(slider:GetValue() - step)
    end)

    incrementButton:SetScript("OnClick", function()
        SetSliderValue(slider:GetValue() + step)
    end)

    return slider
end

local function CreateConfigPanel()
    local panel = CreateFrame("Frame", "FirstDanceConfigPanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(420, 470)
    panel:SetPoint("CENTER")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetScript("OnHide", function()
        if iconPreviewActive then
            StopCountdown()
        end
    end)
    panel:Hide()

    panel.TitleText:SetText("First Dance")

    local inset = panel.InsetBg
    local pad = 14

    local iconCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    iconCheck:SetPoint("TOPLEFT", inset, "TOPLEFT", pad, -pad)
    iconCheck:SetChecked(FirstDanceDB.showIcon)
    iconCheck:SetScript("OnClick", function(self)
        FirstDanceDB.showIcon = self:GetChecked() and true or false
        if not FirstDanceDB.showIcon then
            StopCountdown()
        end
    end)

    local iconCheckLabel = iconCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconCheckLabel:SetPoint("LEFT", iconCheck, "RIGHT", 2, 0)
    iconCheckLabel:SetText("Show loading icon")

    local testIconButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testIconButton:SetSize(90, 22)
    testIconButton:SetPoint("LEFT", iconCheckLabel, "RIGHT", 18, 0)
    testIconButton:SetText("Test Icon")
    testIconButton:SetScript("OnClick", function()
        ShowIconPreview()
    end)

    local offsetXSlider = CreateSlider(
        panel,
        "Icon offset X:",
        iconCheck,
        -28,
        -800,
        800,
        1,
        FirstDanceDB.iconOffsetX or DEFAULTS.iconOffsetX,
        function(value)
            FirstDanceDB.iconOffsetX = ClampInteger(value, -800, 800, DEFAULTS.iconOffsetX)
            ApplyIconLayout()
        end
    )

    local offsetYSlider = CreateSlider(
        panel,
        "Icon offset Y:",
        offsetXSlider,
        -28,
        -600,
        600,
        1,
        FirstDanceDB.iconOffsetY or DEFAULTS.iconOffsetY,
        function(value)
            FirstDanceDB.iconOffsetY = ClampInteger(value, -600, 600, DEFAULTS.iconOffsetY)
            ApplyIconLayout()
        end
    )

    local sizeSlider = CreateSlider(
        panel,
        "Icon size:",
        offsetYSlider,
        -28,
        24,
        256,
        1,
        FirstDanceDB.iconSize or DEFAULTS.iconSize,
        function(value)
            FirstDanceDB.iconSize = ClampInteger(value, 24, 256, DEFAULTS.iconSize)
            ApplyIconLayout()
        end
    )

    panel.offsetXSlider = offsetXSlider
    panel.offsetYSlider = offsetYSlider

    local readyCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    readyCheck:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -18)
    readyCheck:SetChecked(FirstDanceDB.readyTtsEnabled)
    readyCheck:SetScript("OnClick", function(self)
        FirstDanceDB.readyTtsEnabled = self:GetChecked() and true or false
    end)

    local readyCheckLabel = readyCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    readyCheckLabel:SetPoint("LEFT", readyCheck, "RIGHT", 2, 0)
    readyCheckLabel:SetText("Enable ready TTS")

    local readyTextLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    readyTextLabel:SetPoint("TOPLEFT", readyCheck, "BOTTOMLEFT", 0, -18)
    readyTextLabel:SetText("Ready spoken text:")

    local readyTextBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    readyTextBox:SetSize(280, 22)
    readyTextBox:SetPoint("TOPLEFT", readyTextLabel, "BOTTOMLEFT", 0, -4)
    readyTextBox:SetAutoFocus(false)
    readyTextBox:SetText(FirstDanceDB.readyText or DEFAULTS.readyText)
    readyTextBox:SetScript("OnEditFocusLost", function(self)
        FirstDanceDB.readyText = self:GetText()
    end)
    readyTextBox:SetScript("OnEnterPressed", function(self)
        FirstDanceDB.readyText = self:GetText()
        self:ClearFocus()
    end)

    local testButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testButton:SetSize(70, 22)
    testButton:SetPoint("LEFT", readyTextBox, "RIGHT", 6, 0)
    testButton:SetText("Test")
    testButton:SetScript("OnClick", function()
        FirstDanceDB.readyText = readyTextBox:GetText()
        PlayReadySound()
    end)

    local readyRateLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    readyRateLabel:SetPoint("TOPLEFT", readyTextBox, "BOTTOMLEFT", 0, -14)
    readyRateLabel:SetText("Ready rate:")

    local readyRateBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    readyRateBox:SetSize(55, 22)
    readyRateBox:SetPoint("LEFT", readyRateLabel, "RIGHT", 6, 0)
    readyRateBox:SetAutoFocus(false)
    readyRateBox:SetNumeric(false)
    readyRateBox:SetText(tostring(FirstDanceDB.readyRate or DEFAULTS.readyRate))
    readyRateBox:SetScript("OnEditFocusLost", function(self)
        FirstDanceDB.readyRate = GetReadyRate(self:GetText(), DEFAULTS.readyRate)
        self:SetText(tostring(FirstDanceDB.readyRate))
    end)
    readyRateBox:SetScript("OnEnterPressed", function(self)
        FirstDanceDB.readyRate = GetReadyRate(self:GetText(), DEFAULTS.readyRate)
        self:SetText(tostring(FirstDanceDB.readyRate))
        self:ClearFocus()
    end)

    local readyVolumeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    readyVolumeLabel:SetPoint("LEFT", readyRateBox, "RIGHT", 20, 0)
    readyVolumeLabel:SetText("Ready volume:")

    local readyVolumeBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    readyVolumeBox:SetSize(55, 22)
    readyVolumeBox:SetPoint("LEFT", readyVolumeLabel, "RIGHT", 6, 0)
    readyVolumeBox:SetAutoFocus(false)
    readyVolumeBox:SetNumeric(true)
    readyVolumeBox:SetText(tostring(FirstDanceDB.readyVolume or DEFAULTS.readyVolume))
    readyVolumeBox:SetScript("OnEditFocusLost", function(self)
        FirstDanceDB.readyVolume = ClampVolume(self:GetText(), DEFAULTS.readyVolume)
        self:SetText(tostring(FirstDanceDB.readyVolume))
    end)
    readyVolumeBox:SetScript("OnEnterPressed", function(self)
        FirstDanceDB.readyVolume = ClampVolume(self:GetText(), DEFAULTS.readyVolume)
        self:SetText(tostring(FirstDanceDB.readyVolume))
        self:ClearFocus()
    end)

    local hintText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hintText:SetPoint("TOPLEFT", readyRateLabel, "BOTTOMLEFT", 0, -18)
    hintText:SetWidth(360)
    hintText:SetJustifyH("LEFT")
    hintText:SetText("Drag the icon to reposition it. Use /firstdance or /fd to open settings. Test Icon stays visible until the config panel closes.")

    return panel
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

eventFrame:SetScript("OnEvent", function(_, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitDB()
        iconFrame = CreateCountdownIcon()
        ApplyIconLayout()
        configPanel = CreateConfigPanel()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        StopCountdown()
        return
    end

    if event ~= "SPELL_UPDATE_COOLDOWN" then
        return
    end

    local spellID, baseSpellID = arg1, ...
    if spellID == FIRST_DANCE_LOADING_SPELL_ID or baseSpellID == FIRST_DANCE_LOADING_SPELL_ID then
        StartCountdown(false)
        return
    end

    if spellID == FIRST_DANCE_READY_SPELL_ID or baseSpellID == FIRST_DANCE_READY_SPELL_ID then
        StopCountdown()
        PlayReadySound()
    end
end)

SLASH_FIRSTDANCECONFIG1 = "/firstdance"
SLASH_FIRSTDANCECONFIG2 = "/fd"
rawset(SlashCmdList, "FIRSTDANCECONFIG", function()
    if not configPanel then
        return
    end

    if configPanel:IsShown() then
        configPanel:Hide()
    else
        configPanel:Show()
    end
end)