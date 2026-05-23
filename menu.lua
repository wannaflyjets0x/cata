-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Player and Camera
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = game.Workspace.CurrentCamera

-- Global State
local MenuState = {
    IsOpen = false,
    Draggable = true,
    CloseKey = Enum.KeyCode.F6 -- Example key to toggle menu
}

-- Function to create a basic frame (menu window)
local function createMenuFrame(name, size, position, title)
    local frame = Instance.new("ScreenLabel")
    frame.Name = name
    frame.Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset)
    frame.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30) -- Dark gray background
    frame.BorderColor3 = Color3.fromRGB(50, 50, 50)
    frame.BorderSizePixel = 1
    frame.Active = true
    frame.Selectable = true
    frame.Draggable = MenuState.Draggable
    frame.Parent = playerGui

    -- Title Bar
    local titleBar = Instance.new("ScreenLabel")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 30) -- 30 pixels tall
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    titleBar.BorderColor3 = Color3.fromRGB(50, 50, 50)
    titleBar.BorderSizePixel = 1
    titleBar.Text = title or name
    titleBar.TextColor3 = Color3.fromRGB(200, 200, 200)
    titleBar.TextXAlignment = Enum.TextXAlignment.Left
    titleBar.TextYAlignment = Enum.TextYAlignment.Center
    titleBar.TextScaled = false
    titleBar.Font = Enum.Font.SourceSansBold
    titleBar.TextSize = 16
    titleBar.PaddingBottom = 5
    titleBar.PaddingLeft = 10
    titleBar.PaddingRight = 5
    titleBar.PaddingTop = 5
    titleBar.Parent = frame

    -- Close Button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Position = UDim2.new(1, -25, 0, 5) -- Positioned on the right side of the title bar
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Red
    closeButton.BorderColor3 = Color3.fromRGB(50, 50, 50)
    closeButton.BorderSizePixel = 1
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.TextSize = 12
    closeButton.Parent = titleBar

    closeButton.MouseButton1Click:Connect(function()
        frame.Visible = false
        MenuState.IsOpen = false
    end)

    -- Make frame draggable (only the title bar should initiate drag)
    local isDragging = false
    local dragOffset = Vector2.new(0, 0)

    titleBar.InputBegan:Connect(function(input, gameProcessedEvent)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and MenuState.Draggable then
            isDragging = true
            dragOffset = input.Position - frame.AbsolutePosition.XY
        end
    end)

    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging and MenuState.Draggable then
            frame.Position = UDim2.new(0, input.Position.X - dragOffset.X, 0, input.Position.Y - dragOffset.Y)
        end
    end)

    return frame
end

-- Function to create a basic button
local function createMenuButton(parent, text, onClicked, size, position)
    local button = Instance.new("TextButton")
    button.Name = text
    button.Parent = parent
    button.Size = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset)
    button.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset)
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 45) -- Slightly lighter dark gray
    button.BorderColor3 = Color3.fromRGB(50, 50, 50)
    button.BorderSizePixel = 1
    button.Text = text
    button.TextColor3 = Color3.fromRGB(200, 200, 200)
    button.Font = Enum.Font.SourceSans
    button.TextSize = 14
    button.TextWrapped = true
    button.TextXAlignment = Enum.TextXAlignment.Center
    button.TextYAlignment = Enum.TextYAlignment.Center

    button.MouseButton1Click:Connect(onClicked)
    return button
end

-- Create the main menu window
local menuFrame = createMenuFrame("MainMenu", UDim2.new(0.3, 0, 0.4, 0), UDim2.new(0.05, 0, 0.05, 0), "My Game Script")
menuFrame.Visible = false -- Start hidden

-- Add some placeholder sections/buttons to the menu
local mainSection = Instance.new("ScrollingFrame")
mainSection.Name = "MainSection"
mainSection.Size = UDim2.new(1, 0, 1, -30) -- Full width, less title bar height
mainSection.Position = UDim2.new(0, 0, 0, 30) -- Below title bar
mainSection.CanvasSize = UDim2.new(0, 0, 0, 200) -- Adjust as needed for content
mainSection.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
mainSection.BorderColor3 = Color3.fromRGB(50, 50, 50)
mainSection.BorderSizePixel = 1
mainSection.Parent = menuFrame

-- Example Toggle Button
local autoFarmToggle = createMenuButton(mainSection, "Toggle Auto-Farm", function()
    print("Auto-Farm Toggled!")
    -- Add actual auto-farm logic toggle here
end, UDim2.new(0.9, 0, 0, 30), UDim2.new(0.05, 0, 0, 10))

-- Example Slider (conceptual - actual slider implementation is more complex)
local farmRangeSliderLabel = Instance.new("ScreenLabel")
farmRangeSliderLabel.Name = "FarmRangeLabel"
farmRangeSliderLabel.Text = "Farm Range: 50"
farmRangeSliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
farmRangeSliderLabel.Size = UDim2.new(0.5, 0, 0, 20)
farmRangeSliderLabel.Position = UDim2.new(0.05, 0, 0, 50)
farmRangeSliderLabel.Parent = mainSection
-- Add actual slider functionality here (e.g., using UIObjects and input handling)

local autoFarmToggle2 = createMenuButton(mainSection, "Toggle Ore Farming", function()
    print("Ore Farming Toggled!")
    -- Add actual ore farming toggle logic here
end, UDim2.new(0.9, 0, 0, 30), UDim2.new(0.05, 0, 0, 100))

local autoBerryToggle = createMenuButton(mainSection, "Toggle Berry Farming", function()
    print("Berry Farming Toggled!")
    -- Add actual berry farming toggle logic here
end, UDim2.new(0.9, 0, 0, 30), UDim2.new(0.05, 0, 0, 140))

-- Input handling for opening/closing the menu
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end -- Ignore if Roblox processed the input

    if input.KeyCode == MenuState.CloseKey then
        MenuState.IsOpen = not MenuState.IsOpen
        menuFrame.Visible = MenuState.IsOpen
    end
end)

-- You'll need to make this script run on the client (e.g., in StarterPlayerScripts)
-- This is a basic structure, and you'll need to add:
-- 1. Actual game interaction logic (finding ores, walking, collecting)
-- 2. More sophisticated UI elements (sliders, checkboxes, etc.)
-- 3. Potentially executor-specific drawing functions if you want ESP
