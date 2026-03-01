--[[
  ╔══════════════════════════════════════════════════════════╗
  ║         MIDNIGHT CHASERS — CLIENT HUB  v1.0             ║
  ║  Built from: Full_Logic_Dump + UiTemplate + CDID data   ║
  ║                                                          ║
  ║  TABS:                                                   ║
  ║   🚗 Vehicle  — Speed, Fuel, Boost, Lights, Flip        ║
  ║   👤 Player   — Fly, NoClip, WalkSpeed, JumpPower        ║
  ║   🏁 Race     — Auto-Enter, LeaderPull, TimeTrial        ║
  ║   👁 ESP      — BillboardGUI player overlay             ║
  ║   🌍 World    — Time-of-Day, Anti-AFK, FPS cap          ║
  ╚══════════════════════════════════════════════════════════╝
]]

-- ─────────────────────────────────────────────────────────────
--  SERVICES
-- ─────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")
local Workspace        = game:GetService("Workspace")
local lp               = Players.LocalPlayer

-- GUI mount (executor-safe)
local guiTarget = (type(gethui) == "function" and gethui())
    or (pcall(function() return CoreGui end) and CoreGui)
    or lp:WaitForChild("PlayerGui")

-- Kill old instances
for _, n in ipairs({"MC_HubGui", "MC_HubGui_Load"}) do
    if guiTarget:FindFirstChild(n) then guiTarget[n]:Destroy() end
end

-- ─────────────────────────────────────────────────────────────
--  NETWORK HELPER  (mirrors game's own Network module layout)
--  ReplicatedStorage > NetworkContainer > RemoteEvents/Functions
-- ─────────────────────────────────────────────────────────────
local RS = game:GetService("ReplicatedStorage")
local NetContainer

local function getNet()
    -- Check both RS and workspace (game uses both per dump line 16017-16032)
    if NetContainer then return NetContainer end
    NetContainer = RS:FindFirstChild("NetworkContainer")
    if not NetContainer then
        NetContainer = Workspace:FindFirstChild("NetworkContainer")
    end
    return NetContainer
end

local function fireNet(eventName, ...)
    local nc = getNet()
    if not nc then return end
    local ev = nc:FindFirstChild("RemoteEvents")
    if ev and ev:FindFirstChild(eventName) then
        ev[eventName]:FireServer(...)
    end
end

local function invokeNet(funcName, ...)
    local nc = getNet()
    if not nc then return nil end
    local rf = nc:FindFirstChild("RemoteFunctions")
    if rf and rf:FindFirstChild(funcName) then
        local ok, res = pcall(function() return rf[funcName]:InvokeServer(...) end)
        if ok then return res end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────
--  VEHICLE HELPER
-- ─────────────────────────────────────────────────────────────
local function getMyVehicle()
    -- Vehicle model lives at Workspace.Vehicles.[Username]sCar
    local vehicleFolder = Workspace:FindFirstChild("Vehicles")
    if not vehicleFolder then return nil end
    local name = lp.Name .. "sCar"
    return vehicleFolder:FindFirstChild(name)
end

local function getMyDriveSeat()
    local v = getMyVehicle()
    return v and v:FindFirstChild("DriveSeat") or nil
end

local function getMyCarData()
    local v = getMyVehicle()
    return v and v:FindFirstChild("CarData") or nil
end

local function getMyValuesFolder()
    local ds = getMyDriveSeat()
    return ds and ds:FindFirstChild("Values") or nil
end

local function getMyTune()
    -- A-Chassis Tune is a ModuleScript directly in the vehicle model
    local v = getMyVehicle()
    if not v then return nil end
    local t = v:FindFirstChild("A-Chassis Tune")
    if not t then return nil end
    local ok, tune = pcall(require, t)
    return ok and tune or nil
end

-- ─────────────────────────────────────────────────────────────
--  LOADING SCREEN
-- ─────────────────────────────────────────────────────────────
local loadGui = Instance.new("ScreenGui")
loadGui.Name = "MC_HubGui_Load"
loadGui.IgnoreGuiInset = true
loadGui.ResetOnSpawn = false
loadGui.Parent = guiTarget

local bg = Instance.new("Frame", loadGui)
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(4, 5, 9)
bg.BorderSizePixel = 0

local vig = Instance.new("UIGradient", bg)
vig.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6, 8, 14)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
})
vig.Rotation = 45
vig.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.6),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1, 0.6)
})

local titleLbl = Instance.new("TextLabel", bg)
titleLbl.Size = UDim2.new(1, 0, 0, 50)
titleLbl.Position = UDim2.new(0, 0, 0.22, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "MIDNIGHT CHASERS HUB"
titleLbl.TextColor3 = Color3.fromRGB(0, 170, 120)
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 36

local subLbl = Instance.new("TextLabel", bg)
subLbl.Size = UDim2.new(1, 0, 0, 24)
subLbl.Position = UDim2.new(0, 0, 0.36, 0)
subLbl.BackgroundTransparency = 1
subLbl.Text = "A-CHASSIS EXPLOIT FRAMEWORK  ·  v1.0"
subLbl.TextColor3 = Color3.fromRGB(60, 130, 100)
subLbl.Font = Enum.Font.GothamBold
subLbl.TextSize = 13

local barTrack = Instance.new("Frame", bg)
barTrack.Size = UDim2.new(0.5, 0, 0, 5)
barTrack.Position = UDim2.new(0.25, 0, 0.68, 0)
barTrack.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
barTrack.BorderSizePixel = 0
Instance.new("UICorner", barTrack).CornerRadius = UDim.new(0, 3)

local barFill = Instance.new("Frame", barTrack)
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(0, 170, 120)
barFill.BorderSizePixel = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 3)

local barTxt = Instance.new("TextLabel", bg)
barTxt.Size = UDim2.new(1, 0, 0, 18)
barTxt.Position = UDim2.new(0, 0, 0.72, 0)
barTxt.BackgroundTransparency = 1
barTxt.TextColor3 = Color3.fromRGB(40, 90, 65)
barTxt.Font = Enum.Font.Code
barTxt.TextSize = 12

-- Speed lines
local speedLines = {}
math.randomseed(42)
for i = 1, 14 do
    local ln = Instance.new("Frame", bg)
    local yp = math.random(10, 90) / 100
    local w  = math.random(60, 180) / 1000
    local xp = math.random(0, 80) / 100
    ln.Size = UDim2.new(w, 0, 0, 1)
    ln.Position = UDim2.new(xp, 0, yp, 0)
    ln.BackgroundColor3 = Color3.fromRGB(0, 170, 120)
    ln.BorderSizePixel = 0
    ln.BackgroundTransparency = 0.55 + math.random() * 0.35
    speedLines[i] = {frame = ln, speed = math.random(40, 130) / 100, x = xp, w = w}
end

local loadAnimConn = RunService.Heartbeat:Connect(function(dt)
    for _, sl in ipairs(speedLines) do
        sl.x = sl.x + sl.speed * dt * 0.15
        if sl.x > 1 then sl.x = -sl.w end
        sl.frame.Position = UDim2.new(sl.x, 0, sl.frame.Position.Y.Scale, 0)
    end
end)

local function SetProg(pct, msg)
    TweenService:Create(barFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(pct / 100, 0, 1, 0)}):Play()
    barTxt.Text = string.format("  %d%%  —  %s", math.floor(pct), msg)
end

-- ─────────────────────────────────────────────────────────────
--  THEME
-- ─────────────────────────────────────────────────────────────
local Theme = {
    Background = Color3.fromRGB(18, 20, 25),
    Sidebar    = Color3.fromRGB(12, 14, 19),
    Accent     = Color3.fromRGB(0, 170, 120),
    AccentDim  = Color3.fromRGB(0, 110, 78),
    Text       = Color3.fromRGB(235, 235, 235),
    SubText    = Color3.fromRGB(140, 140, 145),
    Button     = Color3.fromRGB(28, 30, 37),
    Stroke     = Color3.fromRGB(50, 52, 62),
    Red        = Color3.fromRGB(215, 55, 55),
    Orange     = Color3.fromRGB(255, 152, 0),
    Green      = Color3.fromRGB(0, 210, 100),
    Yellow     = Color3.fromRGB(255, 215, 0),
    Blue       = Color3.fromRGB(60, 130, 255),
}

-- ─────────────────────────────────────────────────────────────
--  MAIN GUI SCAFFOLD
-- ─────────────────────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui", guiTarget)
ScreenGui.Name = "MC_HubGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local ToggleIcon = Instance.new("TextButton", ScreenGui)
ToggleIcon.Size = UDim2.new(0, 45, 0, 45)
ToggleIcon.Position = UDim2.new(0.5, -22, 0.05, 0)
ToggleIcon.BackgroundColor3 = Theme.Background
ToggleIcon.BackgroundTransparency = 0.1
ToggleIcon.Text = "🚗"
ToggleIcon.TextSize = 22
ToggleIcon.Visible = false
Instance.new("UICorner", ToggleIcon).CornerRadius = UDim.new(1, 0)
local IconStroke = Instance.new("UIStroke", ToggleIcon)
IconStroke.Color = Theme.Accent
IconStroke.Thickness = 2

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 480, 0, 320)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -160)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BackgroundTransparency = 0.05
MainFrame.Active = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Theme.Stroke
MainStroke.Transparency = 0.3

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundTransparency = 1

local TitleLbl = Instance.new("TextLabel", TopBar)
TitleLbl.Size = UDim2.new(0.7, 0, 1, 0)
TitleLbl.Position = UDim2.new(0, 14, 0, 0)
TitleLbl.Text = "🚗  MIDNIGHT CHASERS HUB"
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextColor3 = Theme.Accent
TitleLbl.TextSize = 12
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.BackgroundTransparency = 1

local Sep = Instance.new("Frame", MainFrame)
Sep.Size = UDim2.new(1, -20, 0, 1)
Sep.Position = UDim2.new(0, 10, 0, 32)
Sep.BackgroundColor3 = Theme.Stroke
Sep.BorderSizePixel = 0

local function AddCtrl(text, pos, color, cb)
    local b = Instance.new("TextButton", TopBar)
    b.Size = UDim2.new(0, 28, 0, 22)
    b.Position = pos
    b.BackgroundTransparency = 1
    b.Text = text
    b.TextColor3 = color
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.MouseButton1Click:Connect(cb)
    return b
end

AddCtrl("✕", UDim2.new(1, -32, 0.5, -11), Color3.fromRGB(255, 80, 80), function()
    ScreenGui:Destroy()
end)
AddCtrl("—", UDim2.new(1, -62, 0.5, -11), Theme.SubText, function()
    MainFrame.Visible = false; ToggleIcon.Visible = true
end)
ToggleIcon.MouseButton1Click:Connect(function()
    MainFrame.Visible = true; ToggleIcon.Visible = false
end)

-- Drag
local function EnableDrag(obj, handle)
    local drag, start, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; start = i.Position; startPos = obj.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
EnableDrag(MainFrame, TopBar)
EnableDrag(ToggleIcon, ToggleIcon)

-- Sidebar
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size = UDim2.new(0, 112, 1, -33)
Sidebar.Position = UDim2.new(0, 0, 0, 33)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BackgroundTransparency = 0.35
Sidebar.BorderSizePixel = 0
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)
local SL = Instance.new("UIListLayout", Sidebar)
SL.Padding = UDim.new(0, 5)
SL.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", Sidebar).PaddingTop = UDim.new(0, 10)

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -122, 1, -38)
ContentArea.Position = UDim2.new(0, 117, 0, 38)
ContentArea.BackgroundTransparency = 1

-- ─────────────────────────────────────────────────────────────
--  UI COMPONENT BUILDERS (exact same API as UiTemplate.lua)
-- ─────────────────────────────────────────────────────────────
local AllTabs    = {}
local AllTabBtns = {}

local function CreateTab(name, icon)
    local tf = Instance.new("ScrollingFrame", ContentArea)
    tf.Size = UDim2.new(1, 0, 1, 0)
    tf.BackgroundTransparency = 1
    tf.ScrollBarThickness = 2
    tf.ScrollBarImageColor3 = Theme.AccentDim
    tf.Visible = false
    tf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tf.CanvasSize = UDim2.new(0, 0, 0, 0)
    tf.BorderSizePixel = 0
    local lay = Instance.new("UIListLayout", tf)
    lay.Padding = UDim.new(0, 7)
    Instance.new("UIPadding", tf).PaddingTop = UDim.new(0, 6)

    local tb = Instance.new("TextButton", Sidebar)
    tb.Size = UDim2.new(0.92, 0, 0, 30)
    tb.BackgroundColor3 = Theme.Accent
    tb.BackgroundTransparency = 1
    tb.Text = "  " .. icon .. " " .. name
    tb.TextColor3 = Theme.SubText
    tb.Font = Enum.Font.GothamMedium
    tb.TextSize = 11
    tb.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)

    local ind = Instance.new("Frame", tb)
    ind.Size = UDim2.new(0, 3, 0.6, 0)
    ind.Position = UDim2.new(0, 2, 0.2, 0)
    ind.BackgroundColor3 = Theme.Accent
    ind.Visible = false
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)

    tb.MouseButton1Click:Connect(function()
        for _, t in pairs(AllTabs)    do t.Frame.Visible = false end
        for _, b in pairs(AllTabBtns) do
            b.Btn.BackgroundTransparency = 1
            b.Btn.TextColor3 = Theme.SubText
            b.Ind.Visible = false
        end
        tf.Visible = true
        tb.BackgroundTransparency = 0.82
        tb.TextColor3 = Theme.Text
        ind.Visible = true
    end)
    table.insert(AllTabs,    {Frame = tf})
    table.insert(AllTabBtns, {Btn = tb, Ind = ind})
    return tf
end

local function Section(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(0.98, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.AccentDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
end

local function AddButton(parent, text, cb)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0.98, 0, 0, 35)
    btn.BackgroundColor3 = Theme.Button
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Theme.Text
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    Instance.new("UIStroke", btn).Color = Theme.Stroke
    btn.MouseButton1Click:Connect(cb)
    return btn
end

local function AddLabel(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(0.98, 0, 0, 28)
    lbl.BackgroundColor3 = Theme.Button
    lbl.Text = "  " .. text
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextColor3 = Theme.SubText
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 7)
    return lbl
end

local function FluentToggle(parent, title, desc, callback)
    local state = false
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0.98, 0, 0, 48)
    btn.BackgroundColor3 = Theme.Button
    btn.Text = ""
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    Instance.new("UIStroke", btn).Color = Theme.Stroke

    local tx = Instance.new("TextLabel", btn)
    tx.Size = UDim2.new(0.72, 0, 0.5, 0)
    tx.Position = UDim2.new(0, 10, 0, 5)
    tx.Text = title
    tx.Font = Enum.Font.GothamMedium
    tx.TextColor3 = Theme.Text
    tx.TextSize = 12
    tx.TextXAlignment = Enum.TextXAlignment.Left
    tx.BackgroundTransparency = 1

    local sub = Instance.new("TextLabel", btn)
    sub.Size = UDim2.new(0.72, 0, 0.5, 0)
    sub.Position = UDim2.new(0, 10, 0.5, 0)
    sub.Text = desc
    sub.Font = Enum.Font.Gotham
    sub.TextColor3 = Theme.SubText
    sub.TextSize = 9
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.BackgroundTransparency = 1

    local pill = Instance.new("Frame", btn)
    pill.Size = UDim2.new(0, 42, 0, 22)
    pill.Position = UDim2.new(1, -52, 0.5, -11)
    pill.BackgroundColor3 = Theme.Button
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
    local ps = Instance.new("UIStroke", pill); ps.Color = Theme.Stroke; ps.Thickness = 1
    local pillTxt = Instance.new("TextLabel", pill)
    pillTxt.Size = UDim2.new(1, 0, 1, 0)
    pillTxt.Text = "OFF"
    pillTxt.Font = Enum.Font.GothamBold
    pillTxt.TextColor3 = Theme.SubText
    pillTxt.TextSize = 9
    pillTxt.BackgroundTransparency = 1

    local function setV(on)
        state = on
        pill.BackgroundColor3 = on and Theme.Accent or Theme.Button
        ps.Color = on and Theme.Accent or Theme.Stroke
        pillTxt.Text = on and "ON" or "OFF"
        pillTxt.TextColor3 = on and Color3.new(1, 1, 1) or Theme.SubText
        btn.BackgroundColor3 = on and Color3.fromRGB(24, 38, 30) or Theme.Button
    end
    setV(false)
    btn.MouseButton1Click:Connect(function()
        local res = callback(not state)
        setV(res ~= nil and res or not state)
    end)
    return setV
end

local function FluentSlider(parent, label, minV, maxV, defaultV, setV)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(0.98, 0, 0, 62)
    row.BackgroundColor3 = Theme.Button
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)
    Instance.new("UIStroke", row).Color = Theme.Stroke

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(0.55, 0, 0, 20)
    nameLbl.Position = UDim2.new(0, 10, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = label
    nameLbl.TextColor3 = Theme.Text
    nameLbl.Font = Enum.Font.GothamMedium
    nameLbl.TextSize = 11
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size = UDim2.new(0.40, 0, 0, 20)
    valLbl.Position = UDim2.new(0.58, 0, 0, 6)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 12
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(1, -20, 0, 6)
    track.Position = UDim2.new(0, 10, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)

    local fill = Instance.new("Frame", track)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 7)

    local minTxt = Instance.new("TextLabel", row)
    minTxt.Size = UDim2.new(0, 30, 0, 10)
    minTxt.Position = UDim2.new(0, 10, 0, 50)
    minTxt.BackgroundTransparency = 1
    minTxt.Text = tostring(minV)
    minTxt.TextColor3 = Theme.SubText
    minTxt.Font = Enum.Font.Code
    minTxt.TextSize = 8
    minTxt.TextXAlignment = Enum.TextXAlignment.Left

    local maxTxt = Instance.new("TextLabel", row)
    maxTxt.Size = UDim2.new(0, 40, 0, 10)
    maxTxt.Position = UDim2.new(1, -50, 0, 50)
    maxTxt.BackgroundTransparency = 1
    maxTxt.Text = tostring(maxV) .. " MAX"
    maxTxt.TextColor3 = Theme.Red
    maxTxt.Font =
