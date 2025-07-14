-- SCRIPT START MARKER: Look for this in F9 console to confirm script execution
print("Made By Hydroxonium")
-- YOUR USERNAME MUST BE CHANGED IN THE SCRIPT FOR IT TO WORK, Ctrl + F "Googol" and replace Googol with your IGN.
print("Make sure your username in put into the code!!!")
-- Essential Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
 
-- Configuration
local MAX_STAGES = 50     -- Max number of stages to loop through (Stage_2 to Stage_50)
local DELAY_BETWEEN_STAGES = 0.1 -- seconds to wait at each stage after completing a teleport
 
-- TELEPORT STEP SYSTEM CONFIGURATION
local TELEPORT_LIFT_HEIGHT = 100       -- How high the car lifts up from its current position
local TELEPORT_LIFT_DURATION = 0.02     -- Time in seconds to lift up
local TELEPORT_TRAVEL_DURATION = 0.05   -- Time in seconds to travel horizontally (adjust based on distance)
local TELEPORT_DROP_DURATION = 0.02     -- Time in seconds to drop down
 
-- IMPORTANT: These are the tweaked landing offsets provided by the user
local LANDING_X_OFFSET = 0
local LANDING_Z_OFFSET = 10
local LANDING_HEIGHT_OFFSET = 5
 
-- NEW: Coordinates for the final teleport destination (after Stage 50)
local FINAL_TELEPORT_COORDS = Vector3.new(-447.99993896484375, 20.25012969970703, -15591)
 
-- NEW: Delay AFTER landing on Stage 51 but BEFORE trying to click any buttons
-- This is the delay you requested.
local DELAY_AFTER_FINAL_TELEPORT_AND_BEFORE_CLICKS = 4.0
 
-- NEW: Config for automatic button presses
local AUTO_CLICK_BUTTONS_AFTER_FINAL_TELEPORT = true -- Set to false to disable this feature
local DELAY_BETWEEN_BUTTON_CLICKS = 0.1 -- Small delay between consecutive clicks, if needed
-- Paths to the buttons (ensure these are correct in PlayerGui)
-- IMPORTANT: Verify these paths EXACTLY in PlayerGui during runtime!
local BUTTON_CLAIM_PATH_ROOT = "Main" -- Root parent of ClaimButton
local BUTTON_CLAIM_PATH_RELATIVE = "Rewards.ClaimButton" -- Path relative to BUTTON_CLAIM_PATH_ROOT
 
local BUTTON_DRAW_PATH_ROOT = "Bottom" -- Root parent of DrawButton
local BUTTON_DRAW_PATH_RELATIVE = "DrawButton.Draw.TextButton" -- Path relative to BUTTON_DRAW_PATH_ROOT
 
local BUTTON_DONE_PATH_ROOT = "Bottom" -- Root parent of DoneButton
local BUTTON_DONE_PATH_RELATIVE = "Frame.Frame.DoneButton" -- Path relative to BUTTON_DONE_PATH_ROOT
 
-- How long to wait for each GUI parent/button to appear
local GUI_WAIT_TIMEOUT = 15 -- seconds
 
 
-- Global loop control variable
local looping = false
local currentStageIndex = 2 -- Start from Stage 2
 
-- --- GUI Creation ---
print("--- [CarStageTeleportScript] Attempting to create GUI... ---")
 
local player = Players.LocalPlayer
if not player then
    warn("[CarStageTeleportScript] LocalPlayer not found immediately. Waiting for PlayerAdded...")
    Players.PlayerAdded:Wait() -- Wait for a player to be added (should be LocalPlayer)
    player = Players.LocalPlayer
    if not player then
        warn("[CarStageTeleportScript] Failed to get LocalPlayer even after waiting. GUI cannot be created. Exiting script.")
        return -- Exit script if player is still unreachable
    end
end
 
local playerGui = player:WaitForChild("PlayerGui", 10) -- Wait up to 10 seconds for PlayerGui
if not playerGui then
    warn("[CarStageTeleportScript] PlayerGui not found for LocalPlayer after 10 seconds. GUI cannot be created. Exiting script.")
    return -- Exit script if PlayerGui is unreachable
end
 
local gui = Instance.new("ScreenGui")
gui.Name = "CarStageTeleportGUI"
gui.ResetOnSpawn = false -- Keeps the GUI visible even if you respawn
gui.Parent = playerGui
print("[CarStageTeleportScript] ScreenGui created and parented to PlayerGui.")
 
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 180)
frame.Position = UDim2.new(0.5, -120, 0.5, -90)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
print("[CarStageTeleportScript] GUI Frame created and parented.")
 
local function createButton(text, yPos, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 220, 0, 40)
    button.Position = UDim2.new(0, 10, 0, yPos)
    button.Text = text
    button.BackgroundColor3 = color
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 18
    button.Parent = frame
    return button
end
 
local startButton = createButton("Start Teleport Loop (Car)", 10, Color3.fromRGB(50, 200, 100))
local stopButton = createButton("Stop Teleport Loop", 60, Color3.fromRGB(255, 170, 0))
local killButton = createButton("Kill Script & GUI", 110, Color3.fromRGB(200, 50, 50))
print("[CarStageTeleportScript] GUI Buttons created.")
 
-- --- Car & Spawners Setup ---
local spawnersFolder = Workspace:FindFirstChild("Spawners")
 
-- Function to update start button status based on game objects availability
local function updateStartButtonStatus(currentCar) -- Now takes car as argument
    if not currentCar then
        startButton.Text = "Car Missing!"
        startButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        warn("[CarStageTeleportScript] Googol_Car not found in workspace.Cars!")
    elseif not currentCar.PrimaryPart then
        startButton.Text = "Car PrimaryPart Missing!"
        startButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        warn("[CarStageTeleportScript] Car model '" .. currentCar.Name .. "' does not have a PrimaryPart set!")
    elseif not spawnersFolder then
        startButton.Text = "Spawners Folder Missing!"
        startButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        warn("[CarStageTeleportScript] Folder 'Spawners' not found in workspace!")
    else
        startButton.Text = "Start Teleport Loop (Car)"
        startButton.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
    end
end
updateStartButtonStatus(Workspace.Cars:FindFirstChild("Googol_Car")) -- Initial check
 
-- --- Stepped Teleport Function for Car ---
-- This function teleports the car in three smooth steps: lift, travel, drop.
-- It can now accept a Vector3 directly for the target position.
local function steppedTeleportCar(carInstance: Model, targetDestination: Model | BasePart | Vector3)
    print("[steppedTeleportCar] Initiating stepped teleport...")
    if not carInstance or not carInstance.PrimaryPart then
        warn("[steppedTeleportCar] Car instance or its PrimaryPart is missing. Cannot teleport.")
        return false -- Indicate failure
    end
    if not targetDestination then
        warn("[steppedTeleportCar] Target destination is missing. Cannot teleport.")
        return false -- Indicate failure
    end
 
    local startCFrame = carInstance:GetPivot()
 
    local targetPos: Vector3
    if typeof(targetDestination) == "Vector3" then
        targetPos = targetDestination
    elseif targetDestination:IsA("BasePart") then
        targetPos = targetDestination.Position
    elseif targetDestination:IsA("Model") then
        if targetDestination.PrimaryPart then
            targetPos = targetDestination.PrimaryPart.Position
        else
            targetPos = targetDestination:GetPivot().Position
        end
    else
        warn("[steppedTeleportCar] Invalid targetDestination type. Must be a BasePart, Model, or Vector3.")
        return false -- Indicate failure
    end
 
    -- Calculate destination CFrames for each step
    local carRotation = startCFrame.Rotation -- Maintain current car rotation throughout the steps
 
    -- 1. Lift CFrame: Directly above the current car position
    local liftCFrame = CFrame.new(
        startCFrame.X,
        startCFrame.Y + TELEPORT_LIFT_HEIGHT, -- Lift straight up from current Y
        startCFrame.Z
    ) * carRotation
 
    -- 2. Horizontal Travel CFrame: Moves to the target X/Z at the lifted height
    local horizontalTravelCFrame = CFrame.new(
        targetPos.X, -- No X offset here, car moves to exact target X
        liftCFrame.Y,                       -- Stay at lifted height
        targetPos.Z   -- No Z offset here, car moves to exact target Z
    ) * carRotation
 
    -- 3. Final Landing CFrame: On the target stage (with ALL offsets)
    local finalLandingCFrame = CFrame.new(
        targetPos.X + LANDING_X_OFFSET,     -- Final X position with offset
        targetPos.Y + LANDING_HEIGHT_OFFSET, -- Final Y (height) position with offset
        targetPos.Z + LANDING_Z_OFFSET      -- Final Z position with offset
    ) * carRotation
 
    local currentCFrame = startCFrame
    local success = true
 
    -- STEP 1: Lift Up
    print("[steppedTeleportCar] Lifting car up...")
    local startTime = tick()
    local elapsedTime = 0
    while elapsedTime < TELEPORT_LIFT_DURATION and looping do
        elapsedTime = tick() - startTime
        local alpha = math.min(elapsedTime / TELEPORT_LIFT_DURATION, 1)
        local interpolatedCFrame = currentCFrame:Lerp(liftCFrame, alpha)
 
        local pcallSuccess, err = pcall(function()
            carInstance:PivotTo(interpolatedCFrame)
        end)
        if not pcallSuccess then warn("[steppedTeleportCar] Error during lift:", err); success = false; break end
        task.wait() -- Yield to allow smooth movement
    end
    if not looping then return false end -- Stop if loop was canceled mid-teleport
    if not success then return false end
 
    -- STEP 2: Travel Horizontally
    print("[steppedTeleportCar] Moving car horizontally...")
    currentCFrame = carInstance:GetPivot() -- Get current CFrame after lift
    startTime = tick()
    elapsedTime = 0
    while elapsedTime < TELEPORT_TRAVEL_DURATION and looping do
        elapsedTime = tick() - startTime
        local alpha = math.min(elapsedTime / TELEPORT_TRAVEL_DURATION, 1)
        local interpolatedCFrame = currentCFrame:Lerp(horizontalTravelCFrame, alpha)
 
        local pcallSuccess, err = pcall(function()
            carInstance:PivotTo(interpolatedCFrame)
        end)
        if not pcallSuccess then warn("[steppedTeleportCar] Error during horizontal travel:", err); success = false; break end
        task.wait()
    end
    if not looping then return false end
    if not success then return false end
 
    -- STEP 3: Drop Down
    print("[steppedTeleportCar] Dropping car down...")
    currentCFrame = carInstance:GetPivot() -- Get current CFrame after horizontal travel
    startTime = tick()
    elapsedTime = 0
    while elapsedTime < TELEPORT_DROP_DURATION and looping do
        elapsedTime = tick() - startTime
        local alpha = math.min(elapsedTime / TELEPORT_DROP_DURATION, 1)
        local interpolatedCFrame = currentCFrame:Lerp(finalLandingCFrame, alpha)
 
        local pcallSuccess, err = pcall(function()
            carInstance:PivotTo(interpolatedCFrame)
        end)
        if not pcallSuccess then warn("[steppedTeleportCar] Error during drop:", err); success = false; break end
        task.wait()
    end
    if not looping then return false end
    if not success then return false end
 
    print("[steppedTeleportCar] Stepped teleport complete.")
    return true
end
 
-- --- GUI Button Connections ---
startButton.MouseButton1Click:Connect(function()
    print("[CarStageTeleportScript] Start button clicked.")
    if looping then
        print("[CarStageTeleportScript] Teleport loop is already running. By Hydroxonium")
        return
    end
 
    -- Re-find the car every time the button is pressed
    local car = Workspace.Cars:FindFirstChild("Googol_Car")
 
    -- Re-check essential components before starting the loop
    if not car or not car.PrimaryPart then
        warn("[CarStageTeleportScript] Cannot start teleport: Car or its PrimaryPart is missing. Check F9 console for details.")
        updateStartButtonStatus(car)
        return
    end
    if not spawnersFolder then
        warn("[CarStageTeleportScript] Cannot start teleport: Spawners folder is missing. Check F9 console for details.")
        updateStartButtonStatus(car)
        return
    end
 
    looping = true
    startButton.Text = "Teleporting..."
    stopButton.Text = "Stop Teleport Loop" -- Reset stop button text
    currentStageIndex = 2 -- Reset stage index for a new run
 
    -- Run the loop in a separate thread so GUI remains responsive
    task.spawn(function()
        print("[CarStageTeleportScript] Starting teleport loop in new thread.")
        while looping do
            if currentStageIndex <= MAX_STAGES then
                -- Teleport to a numbered stage
                local stageName = "Stage_" .. currentStageIndex
                local targetStage = spawnersFolder:FindFirstChild(stageName)
 
                if targetStage then
                    print("[CarStageTeleportScript] Attempting stepped teleport to " .. stageName)
                    local success = steppedTeleportCar(car, targetStage) 
                    if success then
                        print("[CarStageTeleportScript] Teleported to " .. stageName .. ". Waiting " .. DELAY_BETWEEN_STAGES .. " seconds.")
                        task.wait(DELAY_BETWEEN_STAGES) -- Wait at the stage only if teleport was successful
                    else
                        warn("[CarStageTeleportScript] Stepped teleport failed for " .. stageName .. ". Skipping and waiting briefly.")
                        task.wait(DELAY_BETWEEN_STAGES / 2) -- Shorter wait on failure
                    end
                else
                    warn("[CarStageTeleportScript] " .. stageName .. " not found in workspace.Spawners! Skipping to next stage.")
                    task.wait(DELAY_BETWEEN_STAGES / 2) -- Shorter wait if stage isn't found
                end
 
                -- Increment stage index for next iteration
                currentStageIndex = currentStageIndex + 1
            else
                -- Teleport to the final fixed coordinates after all stages
                print("[CarStageTeleportScript] All stages visited. Performing final teleport to fixed coordinates.")
                local success = steppedTeleportCar(car, FINAL_TELEPORT_COORDS)
                if success then
                    print("[CarStageTeleportScript] Final teleport successful.")
 
                    -- ***** NEW: Delay AFTER final teleport and BEFORE button clicks *****
                    print("[CarStageTeleportScript] Waiting " .. DELAY_AFTER_FINAL_TELEPORT_AND_BEFORE_CLICKS .. " seconds before attempting button clicks.")
                    task.wait(DELAY_AFTER_FINAL_TELEPORT_AND_BEFORE_CLICKS)
 
                    -- ***** NEW: Automatic Button Presses (Order: Claim -> Draw -> Done) *****
                    if AUTO_CLICK_BUTTONS_AFTER_FINAL_TELEPORT then
                        local function clickGUIButton(rootPath, relativePath)
                            local foundRoot = playerGui:WaitForChild(rootPath, GUI_WAIT_TIMEOUT)
                            if foundRoot then
                                local button = foundRoot:WaitForChild(relativePath:gsub("%.", ":"), GUI_WAIT_TIMEOUT)
                                if button and button:IsA("TextButton") then
                                    print("[CarStageTeleportScript] Clicking button: " .. rootPath .. "." .. relativePath)
                                    local pcallSuccess, err = pcall(function()
                                        button:Click()
                                    end)
                                    if not pcallSuccess then
                                        warn("[CarStageTeleportScript] Error clicking button " .. rootPath .. "." .. relativePath .. ": " .. err)
                                    end
                                else
                                    warn("[CarStageTeleportScript] Button not found or not TextButton at path: " .. rootPath .. "." .. relativePath .. " (after waiting)")
                                end
                            else
                                warn("[CarStageTeleportScript] Root GUI element not found at path: " .. rootPath .. " (after waiting)")
                            end
                        end
 
                        -- Attempt to click buttons in order
                        clickGUIButton(BUTTON_CLAIM_PATH_ROOT, BUTTON_CLAIM_PATH_RELATIVE)
                        task.wait(DELAY_BETWEEN_BUTTON_CLICKS) 
                        clickGUIButton(BUTTON_DRAW_PATH_ROOT, BUTTON_DRAW_PATH_RELATIVE)
                        task.wait(DELAY_BETWEEN_BUTTON_CLICKS) 
                        clickGUIButton(BUTTON_DONE_PATH_ROOT, BUTTON_DONE_PATH_RELATIVE)
 
                        print("[CarStageTeleportScript] Attempted to click configured GUI buttons.")
                    end
                    -- ***** END NEW *****
 
                else
                    warn("[CarStageTeleportScript] Final teleport failed.")
                    task.wait(1) -- Shorter wait on final teleport failure
                end
                looping = false -- Stop the loop after the final teleport sequence
            end
        end
        startButton.Text = "Start Teleport Loop (Car)" -- Reset button text when loop stops
        print("[CarStageTeleportScript] Teleport loop stopped.")
    end)
end)
 
stopButton.MouseButton1Click:Connect(function()
    print("[CarStageTeleportScript] Stop button clicked.")
    if not looping then
        print("[CarStageTeleportScript] Teleport loop is not currently running.")
        return
    end
    looping = false
    local originalStopText = stopButton.Text
    stopButton.Text = "Stopping..."
    task.delay(0.5, function() -- Wait 0.5 seconds
        stopButton.Text = originalStopText
    end)
    print("[CarStageTeleportScript] Loop signal sent. Awaiting thread termination.")
end)
 
killButton.MouseButton1Click:Connect(function()
    print("[CarStageTeleportScript] Kill Script & GUI button clicked. Terminating.")
    looping = false -- Signal any active loop to stop
    if gui then gui:Destroy() end -- Remove the ScreenGui and all its children
    -- script:Destroy() 
end)
 
print("Script Correctly Executed, By Hydroxonium")