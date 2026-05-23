--[[
    'Simple Auto-Farmer Script'
    Supports: Sulfur Ore, Stone Ore, Iron Ore, Berries
    Features:
        - Menu-driven UI (basic implementation using Roblox GUI)
        - Auto-walk to nearest ore/berry
        - Auto-mine ores
        - Auto-collect berries
        - ESP for ores and berries with distance
        - F6 key to toggle menu
]]

-- ══════════════════════════════════════════════
--  GLOBAL STATE
-- ══════════════════════════════════════════════
local _G = _G or {} -- Use existing _G if available, otherwise create a new table

if _G.menuInit == nil then
    _G.menuInit       = true
    _G.menuOpen       = true
    _G.menuX          = 120
    _G.menuY          = 80
    _G.dragging       = false
    _G.dragOX         = 0
    _G.dragOY         = 0
    _G.prevClick      = false
    _G.prevF6         = false
    _G.activeTab      = 1

    -- Visuals
    _G.sulfurESP      = false
    _G.ironESP        = false
    _G.stoneESP       = false
    _G.berryESP       = true -- Defaulting berries to true for testing

    -- Auto-Farm Toggles
    _G.autoFarmSulfur = false
    _G.autoFarmStone  = false
    _G.autoFarmIron   = false
    _G.autoFarmBerries= false

    -- Auto-Farm Settings
    _G.farmRange      = 100 -- Maximum distance to search for resources
    _G.berryInteractKey = Enum.KeyCode.E -- Key to interact with berries
    _G.mineKey        = Enum.KeyCode.LeftMouse -- Key to simulate mining (usually left mouse)

    -- Rainbow state
    _G.rainbowHue     = 0
end

-- ══════════════════════════════════════════════
--  LAYOUT & PALETTE
-- ══════════════════════════════════════════════
local menuW    = 290
local HEADER_H = 28
local TAB_H    = 30
local BTN_H    = 32
local PAD      = 7

local C = {
    bg        = {20,  14,  28},
    hdr       = {48,  24,  72},
    border    = {200, 100, 190},
    borderDim = {80,  45,  95},
    text      = {255, 215, 248},
    textDim   = {150, 120, 162},
    tabAct    = {130,  50, 155},
    tabIn     = {36,   20,  50},
    on        = {235,  90, 175},
    off       = {70,   35,  80},
    close     = {210,  55, 110},
    row1      = {30,   16,  42},
    row2      = {24,   12,  36},
    accent    = {255, 155, 230},
}

-- ══════════════════════════════════════════════
--  ROBLOX SERVICES
-- ══════════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

-- ══════════════════════════════════════════════
--  LOCAL PLAYER & CHARACTER CACHING
-- ══════════════════════════════════════════════
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local PlayerModule = Players:WaitForChild(LocalPlayer.Name)
local Character = nil
local Humanoid = nil
local RootPart = nil

local function updatePlayerCharacter()
    Character = PlayerModule.Character
    if Character then
        Humanoid = Character:FindFirstChildOfClass("Humanoid")
        RootPart = Character:FindFirstChild("HumanoidRootPart")
    else
        Humanoid = nil
        RootPart = nil
    end
end

LocalPlayer.CharacterAdded:Connect(updatePlayerCharacter)
updatePlayerCharacter() -- Initial call

-- ══════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════
local function inRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function getDistance(pos1, pos2)
    if not pos1 or not pos2 then return math.huge end
    local dx = pos1.X - pos2.X
    local dy = pos1.Y - pos2.Y
    local dz = pos1.Z - pos2.Z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local KNOWN_PARTS = {
    "Torso", "UpperTorso", "HumanoidRootPart", "Head",
    "RootPart", "Handle", "PrimaryPart", "Base", "Mesh"
}
local function getModelPosition(model)
    if not model then return nil end

    -- Try to get the primary part or a known part
    for _, partName in ipairs(KNOWN_PARTS) do
        local part = model:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            return part.Position
        end
    end

    -- Fallback: try to get position from any BasePart child
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") then
            return child.Position
        end
    end
    return nil
end

-- Function to simulate key press (requires executor support)
local function simulateKeyPress(keyCode)
    -- This is highly dependent on the executor. Many executors don't provide
    -- a direct way to simulate key presses that affect the game's input state.
    -- If your executor has a function like `executor.SendKeyEvent(keyCode)`, use it.
    -- For now, we'll print a message.
    print(`Simulating key press for: {keyCode}`)
end

-- ══════════════════════════════════════════════
--  AUTO-FARMING LOGIC
-- ══════════════════════════════════════════════
local currentFarmTarget = nil
local path = nil
local currentWaypointIndex = 0
local isMovingToTarget = false

local function findClosestResource(resourceType)
    local closestResource = nil
    local minDist = math.huge
    local player = LocalPlayer
    local playerPos = RootPart and RootPart.Position or player.Character and player.Character.HumanoidRootPart and player.Character.HumanoidRootPart.Position

    if not playerPos then return nil end

    local resourceModels = {}

    -- Collect all potential resources
    local surovinys = Workspace:FindFirstChild("Suroviny")
    if surovinys then
        for _, obj in ipairs(suroviny:GetChildren()) do
            local objName = obj.Name
            local objPos = getModelPosition(obj)
            if objPos and getDistance(playerPos, objPos) <= _G.farmRange then
                if resourceType == "ore" then
                    if objName == "SulfurOre" or objName == "StoneOre" or objName == "IronOre" then
                        table.insert(resourceModels, obj)
                    end
                elseif resourceType == "berry" then
                    -- Adjust these names based on actual in-game berry models
                    if objName:find("Berry", 1, true) or objName:find("Plant", 1, true) then
                        table.insert(resourceModels, obj)
                    end
                end
            end
        end
    end

    -- Find the closest among the collected resources
    for _, res in ipairs(resourceModels) do
        local resPos = getModelPosition(res)
        local dist = getDistance(playerPos, resPos)
        if dist < minDist then
            minDist = dist
            closestResource = res
        end
    end
    return closestResource
end

local function moveToPosition(targetPosition)
    if not RootPart or not Humanoid then return false end

    -- Calculate path
    path = pathfindingService:CreatePath()
    local success, errorMessage = pcall(function()
        path:ComputeAsync(RootPart.Position, targetPosition)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        if waypoints and #waypoints > 0 then
            currentWaypointIndex = 1
            isMovingToTarget = true
            -- Move to the first waypoint
            Humanoid.MoveToFinished:Connect(function(reached)
                if not isMovingToTarget then return end -- If already moved on or cancelled

                if currentWaypointIndex < #waypoints then
                    currentWaypointIndex = currentWaypointIndex + 1
                    local nextWaypoint = waypoints[currentWaypointIndex].Position
                    Humanoid.MoveTo(nextWaypoint)
                else
                    -- Reached the final target position
                    isMovingToTarget = false
                    targetReached = true -- Mark target as reached
                end
            end)
            Humanoid.MoveTo(waypoints[currentWaypointIndex].Position)
            return true
        else
            -- Target is too close or path is blocked
            print("No path waypoints found.")
            return false
        end
    else
        print("Pathfinding failed:", errorMessage or "Unknown error")
        return false
    end
end

local function interactWithResource(resource)
    local resourceName = resource.Name
    local resourcePos = getModelPosition(resource)

    if not resourcePos then return end

    -- If it's a berry, try to interact with 'E'
    if resourceName:find("Berry", 1, true) or resourceName:find("Plant", 1, true) then
        simulateKeyPress(_G.berryInteractKey)
        -- After interaction, consider the resource "used" for now
        currentFarmTarget = nil
        isMovingToTarget = false
        targetReached = false
    -- If it's an ore, simulate attacking
    elseif resourceName == "SulfurOre" or resourceName == "StoneOre" or resourceName == "IronOre" then
        -- In a real game, you'd need to trigger an attack action.
        -- This might involve equipping a tool and playing an animation.
        -- For this script, we'll just print a message.
        print(`Mining: {resourceName}`)
        -- Placeholder for attacking logic. You might need to find a tool and use it.
        -- Example: local tool = character:FindFirstChildOfClass("Tool")
        -- if tool then tool:Activate() end
        -- Once mined, we need to know when it's depleted or gone. This is tricky without game specifics.
        -- For now, we'll just assume it's depleted and find a new target.
        currentFarmTarget = nil
        isMovingToTarget = false
        targetReached = false
    end
end

RunService.Heartbeat:Connect(function(deltaTime)
    if not LocalPlayer or not LocalPlayer.Character or not Humanoid or not RootPart then
        updatePlayerCharacter() -- Try to re-initialize if player/character is missing
        return
    end

    -- Toggle menu with F6
    local userInputState = UserInputService:IsKeyDown(Enum.KeyCode.F6)
    if userInputState and not _G.prevF6 then
        _G.menuOpen = not _G.menuOpen
    end
    _G.prevF6 = userInputState

    -- If menu is closed, we can't interact with it
    if not _G.menuOpen then return end

    -- Menu dragging logic
    local mouse = UserInputService:GetMouseLocation()
    local clicked = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)

    if clicked and not _G.prevClick then
        if inRect(mouse.X, mouse.Y, _G.menuX, _G.menuY, menuW, HEADER_H) and
           not inRect(mouse.X, mouse.Y, _G.menuX + menuW - 26, _G.menuY + 5, 18, HEADER_H - 10) then
            _G.dragging = true
            _G.dragOX = mouse.X - _G.menuX
            _G.dragOY = mouse.Y - _G.menuY
        end
    end
    if not clicked then
        _G.dragging = false
    end
    if _G.dragging then
        _G.menuX = mouse.X - _G.dragOX
        _G.menuY = mouse.Y - _G.dragOY
    end
    _G.prevClick = clicked

    -- Auto-farming execution
    local farmingActive = _G.autoFarmSulfur or _G.autoFarmStone or _G.autoFarmIron or _G.autoFarmBerries
    if farmingActive then
        if not currentFarmTarget or targetReached then
            -- Find a new target
            currentFarmTarget = nil
            targetReached = false

            if _G.autoFarmBerries then
                currentFarmTarget = findClosestResource("berry")
            end
            if not currentFarmTarget and (_G.autoFarmSulfur or _G.autoFarmStone or _G.autoFarmIron) then
                currentFarmTarget = findClosestResource("ore")
            end

            -- If a target is found, start moving towards it
            if currentFarmTarget then
                moveToPosition(getModelPosition(currentFarmTarget))
            else
                -- No targets found, keep walking
                Humanoid.MoveTo(RootPart.Position + Vector3.new(0,0,1)) -- Move forward slightly
            end
        elseif isMovingToTarget then
            -- If moving to target, continue pathfinding
            -- The Humanoid.MoveToFinished event will handle the next steps
        elseif targetReached then
            -- If target is reached, interact with it
            interactWithResource(currentFarmTarget)
        end
    else
        -- Farming disabled, reset state
        currentFarmTarget = nil
        isMovingToTarget = false
        targetReached = false
    end
end)

-- ══════════════════════════════════════════════
--  DRAWING FUNCTIONS (ESP)
-- ══════════════════════════════════════════════
local function drawESP()
    local player = LocalPlayer
    local playerPos = RootPart and RootPart.Position

    if not playerPos then return end

    -- Ores
    if _G.sulfurESP then
        local sulfurOre = findClosestResource("ore") -- Find one instance for drawing
        if sulfurOre and dx9.GetName(sulfurOre) == "SulfurOre" then
            local sulfurPos = getModelPosition(sulfurOre)
            local dist = getDistance(playerPos, sulfurPos)
            local screenPos = Workspace.CurrentCamera:WorldToScreenPoint(sulfurPos)
            if screenPos.Z > 0 and screenPos.X > 0 and screenPos.Y > 0 then
                local label = "Sulfur Ore [" .. dist .. "m]"
                dx9.DrawText(label, screenPos.X, screenPos.Y, Color3.new(1, 1, 0), false, dx9.GetTextSize(label))
            end
        end
    end
    if _G.ironESP then
        local ironOre = findClosestResource("ore") -- Find one instance for drawing
        if ironOre and dx9.GetName(ironOre) == "IronOre" then
            local ironPos = getModelPosition(ironOre)
            local dist = getDistance(playerPos, ironPos)
            local screenPos = Workspace.CurrentCamera:WorldToScreenPoint(ironPos)
            if screenPos.Z > 0 and screenPos.X > 0 and screenPos.Y > 0 then
                local label = "Iron Ore [" .. dist .. "m]"
                dx9.DrawText(label, screenPos.X, screenPos.Y, Color3.new(1, 0.5, 0), false, dx9.GetTextSize(label))
            end
        end
    end
    if _G.stoneESP then
        local stoneOre = findClosestResource("ore") -- Find one instance for drawing
        if stoneOre and dx9.GetName(stoneOre) == "StoneOre" then
            local stonePos = getModelPosition(stoneOre)
            local dist = getDistance(playerPos, stonePos)
            local screenPos = Workspace.CurrentCamera:WorldToScreenPoint(stonePos)
            if screenPos.Z > 0 and screenPos.X > 0 and screenPos.Y > 0 then
                local label = "Stone Ore [" .. dist .. "m]"
                dx9.DrawText(label, screenPos.X, screenPos.Y, Color3.new(0.7, 0.7, 0.8), false, dx9.GetTextSize(label))
            end
        end
    end
    if _G.berryESP then
        local berry = findClosestResource("berry") -- Find one instance for drawing
        if berry then
            local berryPos = getModelPosition(berry)
            local dist = getDistance(playerPos, berryPos)
            local screenPos = Workspace.CurrentCamera:WorldToScreenPoint(berryPos)
            if screenPos.Z > 0 and screenPos.X > 0 and screenPos.Y > 0 then
                local label = "Berry [" .. dist .. "m]"
                dx9.DrawText(label, screenPos.X, screenPos.Y, Color3.new(0.4, 0.9, 0.4), false, dx9.GetTextSize(label))
            end
        end
    end
end

-- ══════════════════════════════════════════════
--  ROBLOX GUI FOR MENU
-- ══════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoFarmMenu"
ScreenGui.Parent = PlayerGui

local MenuFrame = Instance.new("Frame")
MenuFrame.Name = "MenuFrame"
MenuFrame.Size = UDim2.new(0, menuW, 0, HEADER_H + TAB_H + PAD + (_G.activeTab ~= 5 and (#visualItems + #exploitItems + #animalItems + #militaryItems) or #advancedItems) * (BTN_H + PAD) + PAD)
MenuFrame.Position = UDim2.new(0, _G.menuX, 0, _G.menuY)
MenuFrame.BackgroundColor3 = C.bg
MenuFrame.BorderSizePixel = 1
MenuFrame.BorderColor3 = C.border
MenuFrame.Parent = ScreenGui

-- Header
local HeaderFrame = Instance.new("Frame")
HeaderFrame.Name = "HeaderFrame"
HeaderFrame.Size = UDim2.new(1, 0, 0, HEADER_H)
HeaderFrame.BackgroundColor3 = C.hdr
HeaderFrame.BorderColor3 = C.border
HeaderFrame.BorderSizePixel = 1
HeaderFrame.Parent = MenuFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, -30, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 7)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Auto-Farm | F6 to Toggle"
TitleLabel.TextColor3 = C.accent
TitleLabel.TextScaled = true
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.Parent = HeaderFrame

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 18, 0, HEADER_H - 10)
CloseButton.Position = UDim2.new(1, -24, 0, 5)
CloseButton.BackgroundColor3 = C.close
CloseButton.BorderColor3 = C.border
CloseButton.BorderSizePixel = 1
CloseButton.Text = "x"
CloseButton.TextColor3 = C.text
CloseButton.TextScaled = true
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.Parent = HeaderFrame

-- Tabs
local TabsFrame = Instance.new("Frame")
TabsFrame.Name = "TabsFrame"
TabsFrame.Size = UDim2.new(1, 0, 0, TAB_H)
TabsFrame.Position = UDim2.new(0, 0, 0, HEADER_H)
TabsFrame.Parent = MenuFrame

local tabs = {"Visuals", "Exploit", "Animals", "Military", "Advanced"}
local tabButtons = {}
local tabW = menuW / #tabs

for i, tabName in ipairs(tabs) do
    local button = Instance.new("TextButton")
    button.Name = "TabButton_" .. i
    button.Size = UDim2.new(0, tabW, 1, 0)
    button.Position = UDim2.new(0, (i - 1) * tabW, 0, 0)
    button.BackgroundColor3 = C.tabIn
    button.BorderColor3 = C.borderDim
    button.BorderSizePixel = 1
    button.Text = tabName
    button.TextColor3 = C.textDim
    button.TextScaled = true
    button.Font = Enum.Font.SourceSansBold
    button.Parent = TabsFrame

    button.MouseButton1Click:Connect(function()
        _G.activeTab = i
    end)
    table.insert(tabButtons, button)
end

-- Content Area (Buttons)
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -PAD * 2, 0, 0)
ContentFrame.Position = UDim2.new(0, PAD, 0, HEADER_H + TAB_H + PAD)
ContentFrame.Parent = MenuFrame

local visualItems = {
    {"Sulfur Ore ESP",    "sulfurESP",        C.accent},
    {"Iron Ore ESP",      "ironESP",          {255, 140,  40}},
    {"Stone Ore ESP",     "stoneESP",         {185, 185, 205}},
    {"Berries ESP",       "berryESP",         {100, 230, 100}},
}
local exploitItems = {
    {"Small Chest ESP",   "chestSmallESP",    {220, 175,  90}},
    {"Large Chest ESP",   "chestLargeESP",    {230, 135,  55}},
    {"Private Chest ESP", "chestPrivESP",     {175, 100, 225}},
    {"Dropped Loot ESP",  "lootESP",          {110, 215, 255}},
}
local animalItems = {
    {"Pig ESP",       "pigESP",           {255, 185, 200}},
    {"Bear ESP",      "bearESP",          {210, 145,  90}},
    {"Wolf ESP",      "wolfESP",          {180, 180, 200}},
}
local militaryItems = {
    {"Military Crate ESP","militaryCrateESP", {220, 200,  60}},
}
local advancedItems = {
    {"Show Distance",      "showDist",        {100, 220, 255}},
    {"Closest Rainbow ESP","closestRainbow",  {255, 100, 200}},
    {"Farm Range",         "farmRange",       C.accent}, -- Placeholder for range setting
    {"Farm Sulfur",        "autoFarmSulfur",  C.on},
    {"Farm Stone",         "autoFarmStone",   C.on},
    {"Farm Iron",          "autoFarmIron",    C.on},
    {"Farm Berries",       "autoFarmBerries", C.on},
}

local function getItemsForTab()
    if _G.activeTab == 1 then return visualItems  end
    if _G.activeTab == 2 then return exploitItems end
    if _G.activeTab == 3 then return animalItems  end
    if _G.activeTab == 4 then return militaryItems end
    if _G.activeTab == 5 then return advancedItems end
    return visualItems
end

local function updateMenuSize()
    local items = getItemsForTab()
    local numItems = #items
    local contentHeight = numItems * (BTN_H + PAD) + PAD
    MenuFrame.Size = UDim2.new(0, menuW, 0, HEADER_H + TAB_H + PAD + contentHeight)
end

-- Function to create toggle buttons
local function createToggle(parent, text, toggleStateName, initialValue, accentColor)
    local button = Instance.new("Frame")
    button.Name = "Toggle_" .. toggleStateName
    button.Size = UDim2.new(1, 0, 0, BTN_H)
    button.BackgroundColor3 = C.row1
    button.BorderSizePixel = 1
    button.BorderColor3 = C.borderDim
    button.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -indW - PAD*2, 1, 0)
    label.Position = UDim2.new(0, PAD + 4, 0, 0) -- Offset for accent line
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = C.text
    label.TextScaled = true
    label.Font = Enum.Font.SourceSans
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = button

    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(0, 4, 1, 0)
    accentLine.BackgroundColor3 = accentColor or C.accent
    accentLine.Position = UDim2.new(0, PAD, 0, 0)
    accentLine.Parent = button

    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "ToggleFrame"
    toggleFrame.Size = UDim2.new(0, indW, 0, BTN_H - 16)
    toggleFrame.Position = UDim2.new(1, -indW - PAD, 0, 8)
    toggleFrame.BackgroundColor3 = _G[toggleStateName] and C.on or C.off
    toggleFrame.BorderSizePixel = 1
    toggleFrame.BorderColor3 = _G[toggleStateName] and C.border or C.borderDim
    toggleFrame.Parent = button

    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.Size = UDim2.new(1, 0, 1, 0)
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Text = _G[toggleStateName] and "ON" or "OFF"
    toggleLabel.TextColor3 = C.text
    toggleLabel.TextScaled = true
    toggleLabel.Font = Enum.Font.SourceSansBold
    toggleLabel.Parent = toggleFrame

    button.MouseButton1Click:Connect(function()
        _G[toggleStateName] = not _G[toggleStateName]
        toggleFrame.BackgroundColor3 = _G[toggleStateName] and C.on or C.off
        toggleFrame.BorderColor3 = _G[toggleStateName] and C.border or C.borderDim
        toggleLabel.Text = _G[toggleStateName] and "ON" or "OFF"
    end)

    return button
end

-- Function to create input fields (e.g., for farm range)
local function createInputField(parent, labelText, valueGetterName, valueSetterName, suffix)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, BTN_H)
    frame.BackgroundColor3 = C.row2
    frame.BorderSizePixel = 1
    frame.BorderColor3 = C.borderDim
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, -PAD, 1, 0)
    label.Position = UDim2.new(0, PAD, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = C.text
    label.TextScaled = true
    label.Font = Enum.Font.SourceSans
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local input = Instance.new("TextBox")
    input.Name = "Input_" .. valueGetterName
    input.Size = UDim2.new(0.5, -PAD, 1, 0)
    input.Position = UDim2.new(0.5, PAD, 0, 0)
    input.BackgroundColor3 = C.off
    input.BorderColor3 = C.borderDim
    input.BorderSizePixel = 1
    input.Text = tostring(_G[valueGetterName]) .. (suffix or "")
    input.TextColor3 = C.text
    input.TextScaled = true
    input.Font = Enum.Font.SourceSansBold
    input.Parent = frame
    input.ClearTextOnFocus = false
    input.TextEditable = true

    input.FocusLost:Connect(function(enterPressed)
        local newValue = tonumber(input.Text)
        if newValue then
            _G[valueSetterName or valueGetterName] = newValue
            input.Text = tostring(_G[valueGetterName]) .. (suffix or "")
        else
            input.Text = tostring(_G[valueGetterName]) .. (suffix or "") -- Revert if invalid
        end
    end)

    return frame
end

-- Function to draw the menu and its elements
local function drawMenu()
    local items = getItemsForTab()
    local currentY = 0

    -- Draw toggles
    for i, item in ipairs(items) do
        local label, key2, accentCol = item[1], item[2], item[3]
        local button = createToggle(ContentFrame, label, key2, _G[key2], accentCol)
        button.Position = UDim2.new(0, 0, 0, currentY)
        currentY = currentY + BTN_H + PAD
    end

    -- Draw input fields if applicable
    if _G.activeTab == 5 then
        local farmRangeInput = createInputField(ContentFrame, "Farm Range", "farmRange", "farmRange", "m")
        farmRangeInput.Position = UDim2.new(0, 0, 0, currentY)
        currentY = currentY + BTN_H + PAD
    end

    -- Adjust the size of the content frame based on the number of items
    ContentFrame.Size = UDim2.new(1, 0, 0, currentY)
    -- Update the main menu frame size
    MenuFrame.Size = UDim2.new(0, menuW, 0, HEADER_H + TAB_H + PAD + ContentFrame.Size.Y.Offset + PAD)
end

-- Function to draw ESP elements
local function drawESP()
    local player = LocalPlayer
    local playerPos = RootPart and RootPart.Position

    if not playerPos then return end

    local function drawResourceESP(resource, color, label)
        local resPos = getModelPosition(resource)
        if not resPos then return end

        local dist = getDistance(playerPos, resPos)
        if dist > _G.farmRange then return end

        local screenPos = Workspace.CurrentCamera:WorldToScreenPoint(resPos)
        if screenPos.Z > 0 and screenPos.X > 0 and screenPos.Y > 0 then
            local text = label .. " [" .. math.floor(dist) .. "m]"
            local textSize = dx9.GetTextSize(text) -- Assuming dx9 is available for text size
            local x, y = screenPos.X, screenPos.Y

            -- Draw outline first
            dx9.DrawText(text, x - textSize.X/2 + 1, y - textSize.Y/2 + 1, Color3.new(0, 0, 0), false, textSize)
            -- Draw main text
            dx9.DrawText(text, x - textSize.X/2, y - textSize.Y/2, color, false, textSize)
        end
    end

    -- Find and draw ores
    local surovinys = Workspace:FindFirstChild("Suroviny")
    if surovinys then
        for _, obj in ipairs(suroviny:GetChildren()) do
            local objName = obj.Name
            local objPos = getModelPosition(obj)

            if objPos then
                local dist = getDistance(playerPos, objPos)
                if dist <= _G.farmRange then
                    if _G.sulfurESP and objName == "SulfurOre" then
                        drawResourceESP(obj, Color3.new(1, 1, 0), "Sulfur Ore")
                    elseif _G.ironESP and objName == "IronOre" then
                        drawResourceESP(obj, Color3.new(1, 0.5, 0), "Iron Ore")
                    elseif _G.stoneESP and objName == "StoneOre" then
                        drawResourceESP(obj, Color3.new(0.7, 0.7, 0.8), "Stone Ore")
                    end
                end
            end
        end
    end

    -- Find and draw berries
    if _G.berryESP then
        local resourceModels = {}
        local searchFolders = {"Objects", "Props"} -- Adjust these folders if needed
        for _, folderName in ipairs(searchFolders) do
            local folder = Workspace:FindFirstChild(folderName)
            if folder then
                for _, obj in ipairs(folder:GetChildren()) do
                    local objName = obj.Name
                    local objPos = getModelPosition(obj)
                    if objPos and getDistance(playerPos, objPos) <= _G.farmRange then
                        if objName:find("Berry", 1, true) or objName:find("Plant", 1, true) then
                            drawResourceESP(obj, Color3.new(0.4, 0.9, 0.4), "Berry")
                        end
                    end
                end
            end
        end
    end
end


-- Main loop for drawing and updates
RunService.Heartbeat:Connect(function(deltaTime)
    -- Update player character reference if needed
    if not Character or not Humanoid or not RootPart then
        updatePlayerCharacter()
    end

    -- Input handling for menu
    local mouseLocation = UserInputService:GetMouseLocation()
    local isMouseDown = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    local f6Pressed = UserInputService:IsKeyDown(Enum.KeyCode.F6)

    -- Toggle menu with F6
    if f6Pressed and not _G.prevF6 then
        _G.menuOpen = not _G.menuOpen
    end
    _G.prevF6 = f6Pressed

    -- Menu drag logic
    if isMouseDown and not _G.prevClick then
        if inRect(mouseLocation.X, mouseLocation.Y, _G.menuX, _G.menuY, menuW, HEADER_H) and
           not inRect(mouseLocation.X, mouseLocation.Y, _G.menuX + menuW - 26, _G.menuY + 5, 18, HEADER_H - 10) then
            _G.dragging = true
            _G.dragOX = mouseLocation.X - _G.menuX
            _G.dragOY = mouseLocation.Y - _G.menuY
        end
    end
    if not isMouseDown then
        _G.dragging = false
    end
    if _G.dragging then
        _G.menuX = mouseLocation.X - _G.dragOX
        _G.menuY = mouseLocation.Y - _G.dragOY
        MenuFrame.Position = UDim2.new(0, _G.menuX, 0, _G.menuY)
    end
    _G.prevClick = isMouseDown

    -- Draw the menu if it's open
    if _G.menuOpen then
        -- Update menu size based on active tab and toggled items
        updateMenuSize()
        -- Redraw the menu elements
        drawMenu()
    end

    -- Draw ESP elements if enabled
    if _G.sulfurESP or _G.ironESP or _G.stoneESP or _G.berryESP then
        drawESP()
    end

    -- Auto-farming execution
    local farmingActive = _G.autoFarmSulfur or _G.autoFarmStone or _G.autoFarmIron or _G.autoFarmBerries
    if farmingActive then
        if not currentFarmTarget or targetReached then
            currentFarmTarget = nil
            targetReached = false
            isMovingToTarget = false
            path = nil

            if _G.autoFarmBerries then
                currentFarmTarget = findClosestResource("berry")
            end
            if not currentFarmTarget and (_G.autoFarmSulfur or _G.autoFarmStone or _G.autoFarmIron) then
                currentFarmTarget = findClosestResource("ore")
            end

            if currentFarmTarget then
                moveToPosition(getModelPosition(currentFarmTarget))
            else
                -- If no targets are found, keep moving forward to explore
                if Humanoid and RootPart then
                    Humanoid.MoveTo(RootPart.Position + Vector3.new(0, 0, 1))
                end
            end
        elseif isMovingToTarget then
            -- Pathfinding is ongoing, humanoid will move based on MoveToFinished
            -- If the target is very close, we might need to interact directly
            local targetPos = getModelPosition(currentFarmTarget)
            if targetPos and getDistance(RootPart.Position, targetPos) < 5 then -- Threshold for interaction
                isMovingToTarget = false
                targetReached = true -- Mark as reached to trigger interaction
            end
        elseif targetReached then
            -- Target reached, interact
            interactWithResource(currentFarmTarget)
        end
    else
        -- Farming disabled, reset state
        currentFarmTarget = nil
        isMovingToTarget = false
        targetReached = false
        path = nil
        if Humanoid then
            Humanoid.MoveTo(RootPart.Position) -- Stop movement if farming is off
        end
    end
end)

-- Function to properly clean up the GUI when the script is disabled or reloaded
local function cleanup()
    if ScreenGui then
        ScreenGui:Destroy()
    end
end

-- Handle script disabling (e.g., when the executor unloads it)
-- Note: This might not work perfectly with all executors.
-- A more robust solution might involve a function to be called explicitly to disable.
RunService.Heartbeat:Connect(function()
    -- This is a basic cleanup; you might need a more sophisticated way
    -- to handle script disabling if your executor requires it.
end)

--[[
    To use this script:
    1. Copy the entire code.
    2. Paste it into your executor.
    3. Press F6 to open/close the menu.
    4. Enable the desired ESP and auto-farm options.
    5. Ensure your executor supports `dx9` for drawing text and shapes,
       and `game:GetService("PathfindingService")` for movement.
       The `simulateKeyPress` function is a placeholder and might need
       executor-specific implementation for actual key presses.
]]
