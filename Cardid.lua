--[[
  ╔══════════════════════════════════════════════════════════════╗
  ║       CAR DRIVING INDONESIA (CDID) — CLIENT HUB  v1.1       ║
  ║  Reverse-engineered from VehicleController + CDID tune data  ║
  ║                                                              ║
  ║  TABS:  🚗 Vehicle | 👤 Player | 🏁 Race | 👁 ESP | 🌍 World ║
  ╚══════════════════════════════════════════════════════════════╝
  
  CHANGELOG v1.1
  - Fixed: 'continue' keyword removed (Lua 5.1 syntax error — crash cause)
  - Fixed: Game renamed to CDID throughout
  - Fixed: getNet() now correctly resolves RS.NetworkContainer first
  - Fixed: FluentStepper signature aligned with UiTemplate.lua
  - Added: Full pcall guard around all remote calls
  - Added: Auto-reapply walkspeed/jumppower on character respawn
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
local Workspace        = workspace
local RS               = game:GetService("ReplicatedStorage")
local lp               = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────
--  GUI TARGET  (executor-safe)
-- ─────────────────────────────────────────────────────────────
local guiTarget
if type(gethui) == "function" then
    guiTarget = gethui()
else
    local ok, cg = pcall(function() return CoreGui end)
    guiTarget = ok and cg or lp:WaitForChild("PlayerGui")
end

-- Kill old instances
for _, n in ipairs({"CDID_HubGui", "CDID_HubGui_Load"}) do
    local old = guiTarget:FindFirstChild(n)
    if old then old:Destroy() end
end

-- ─────────────────────────────────────────────────────────────
--  NETWORK HELPERS
--  Confirmed layout from Live_Remote_Logs.txt:
--    RS.NetworkContainer.RemoteEvents.ErrorLogSystem (FireServer)
--    RS.NetworkContainer.RemoteFunctions.Leaderboard (InvokeServer)
--    RS.NetworkContainer.RemoteFunctions.GetServerTime (InvokeServer)
--    DriveSeat.FE_Lights (FireServer — direct child of DriveSeat)
-- ─────────────────────────────────────────────────────────────
local function getNetContainer()
    -- Confirmed path from dump lines 16017-16045
    return RS:FindFirstChild("NetworkContainer")
        or Workspace:FindFirstChild("NetworkContainer")
end

local function safeFireEvent(eventName, ...)
    local nc = getNetContainer()
    if not nc then return end
    local ev = nc:FindFirstChild("RemoteEvents")
    if not ev then return end
    local rem = ev:FindFirstChild(eventName)
    if rem then
        pcall(function(...) rem:FireServer(...) end, ...)
    end
end

local function safeInvoke(funcName, ...)
    local nc = getNetContainer()
    if not nc then return nil end
    local rf = nc:FindFirstChild("RemoteFunctions")
    if not rf then return nil end
    local rem = rf:FindFirstChild(funcName)
    if not rem then return nil end
    local args = {...}
    local ok, res = pcall(function() return rem:InvokeServer(table.unpack(args)) end)
    return ok and res or nil
end

-- ─────────────────────────────────────────────────────────────
--  VEHICLE HELPERS
--  Vehicle model: Workspace.Vehicles.[PlayerName]sCar
--  Confirmed from dump line 38: v_u_28._VehicleName = p25.CarData.CarName.Value
-- ─────────────────────────────────────────────────────────────
local function getMyVehicle()
    local vf = Workspace:FindFirstChild("Vehicles")
    if not vf then return nil end
    return vf:FindFirstChild(lp.Name .. "sCar")
end

local function getMyDriveSeat()
    local v = getMyVehicle()
    if not v then return nil end
    return v:FindFirstChild("DriveSeat")
end

local function getMyCarData()
    local v = getMyVehicle()
    if not v then return nil end
    return v:FindFirstChild("CarData")
end

local function getMyValues()
    local ds = getMyDriveSeat()
    if not ds then return nil end
    return ds:FindFirstChild("Values")
end

local function getChar()
    return lp.Character
end

local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ─────────────────────────────────────────────────────────────
--  LOADING SCREEN
-- ─────────────────────────────────────────────────────────────
local loadGui = Instance.new("ScreenGui")
loadGui.Name              = "CDID_HubGui_Load"
loadGui.IgnoreGuiInset    = true
loadGui.ResetOnSpawn      = false
loadGui.Parent            = guiTarget

local bg = Instance.new("Frame", loadGui)
bg.Size                  = UDim2.new(1,0,1,0)
bg.BackgroundColor3       = Color3.fromRGB(4,5,9)
bg.BorderSizePixel        = 0

local vig = Instance.new("UIGradient", bg)
vig.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0,0,0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6,8,14)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0,0,0)),
})
vig.Rotation = 45
vig.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   0.6),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1,   0.6),
})

local function makeLbl(parent, y, txt, size, color, font)
    local l = Instance.new("TextLabel", parent)
    l.Size               = UDim2.new(1,0,0,size+10)
    l.Position           = UDim2.new(0,0,y,0)
    l.BackgroundTransparency = 1
    l.Text               = txt
    l.TextColor3         = color
    l.Font               = font or Enum.Font.GothamBlack
    l.TextSize           = size
    return l
end

makeLbl(bg, 0.20, "CAR DRIVING INDONESIA", 34,
    Color3.fromRGB(0,170,120), Enum.Font.GothamBlack)
makeLbl(bg, 0.34, "CLIENT HUB  ·  v1.1  ·  CDID RE", 13,
    Color3.fromRGB(60,130,100), Enum.Font.GothamBold)

local barTrack = Instance.new("Frame", bg)
barTrack.Size             = UDim2.new(0.5,0,0,5)
barTrack.Position         = UDim2.new(0.25,0,0.68,0)
barTrack.BackgroundColor3 = Color3.fromRGB(14,18,28)
barTrack.BorderSizePixel  = 0
Instance.new("UICorner", barTrack).CornerRadius = UDim.new(0,3)

local barFill = Instance.new("Frame", barTrack)
barFill.Size              = UDim2.new(0,0,1,0)
barFill.BackgroundColor3  = Color3.fromRGB(0,170,120)
barFill.BorderSizePixel   = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0,3)

local barTxt = Instance.new("TextLabel", bg)
barTxt.Size               = UDim2.new(1,0,0,18)
barTxt.Position           = UDim2.new(0,0,0.72,0)
barTxt.BackgroundTransparency = 1
barTxt.TextColor3         = Color3.fromRGB(40,90,65)
barTxt.Font               = Enum.Font.Code
barTxt.TextSize           = 12

-- Speed lines (aesthetic)
math.randomseed(42)
local speedLines = {}
for i = 1, 14 do
    local ln  = Instance.new("Frame", bg)
    local yp  = math.random(10,90)/100
    local w   = math.random(60,180)/1000
    local xp  = math.random(0,80)/100
    ln.Size              = UDim2.new(w,0,0,1)
    ln.Position          = UDim2.new(xp,0,yp,0)
    ln.BackgroundColor3  = Color3.fromRGB(0,170,120)
    ln.BorderSizePixel   = 0
    ln.BackgroundTransparency = 0.55 + math.random()*0.35
    speedLines[i] = {f=ln, sp=math.random(40,130)/100, x=xp, w=w}
end

local loadConn = RunService.Heartbeat:Connect(function(dt)
    for _, sl in ipairs(speedLines) do
        sl.x = sl.x + sl.sp * dt * 0.15
        if sl.x > 1 then sl.x = -sl.w end
        sl.f.Position = UDim2.new(sl.x, 0, sl.f.Position.Y.Scale, 0)
    end
end)

local function SetProg(pct, msg)
    TweenService:Create(barFill, TweenInfo.new(0.25,
        Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(pct/100,0,1,0)}):Play()
    barTxt.Text = string.format("  %d%%  —  %s", math.floor(pct), msg)
end

-- ─────────────────────────────────────────────────────────────
--  THEME
-- ─────────────────────────────────────────────────────────────
local T = {
    Bg      = Color3.fromRGB(16, 18, 23),
    Side    = Color3.fromRGB(11, 13, 18),
    Acc     = Color3.fromRGB(0,  170, 120),
    AccDim  = Color3.fromRGB(0,  100, 72),
    Txt     = Color3.fromRGB(235,235,235),
    Sub     = Color3.fromRGB(140,140,145),
    Btn     = Color3.fromRGB(26, 28, 35),
    Strk    = Color3.fromRGB(48, 50, 60),
    Red     = Color3.fromRGB(215,55, 55),
    Orng    = Color3.fromRGB(255,152,0),
    Grn     = Color3.fromRGB(0,  210,100),
    Ylw     = Color3.fromRGB(255,215,0),
    Blu     = Color3.fromRGB(60, 130,255),
}

-- ─────────────────────────────────────────────────────────────
--  MAIN GUI SCAFFOLD
-- ─────────────────────────────────────────────────────────────
local SG = Instance.new("ScreenGui", guiTarget)
SG.Name           = "CDID_HubGui"
SG.ResetOnSpawn   = false
SG.IgnoreGuiInset = true

-- Minimise toggle icon
local MinIcon = Instance.new("TextButton", SG)
MinIcon.Size                 = UDim2.new(0,45,0,45)
MinIcon.Position             = UDim2.new(0.5,-22,0.05,0)
MinIcon.BackgroundColor3     = T.Bg
MinIcon.BackgroundTransparency = 0.1
MinIcon.Text                 = "🚗"
MinIcon.TextSize             = 22
MinIcon.Visible              = false
Instance.new("UICorner", MinIcon).CornerRadius = UDim.new(1,0)
local MinStk = Instance.new("UIStroke", MinIcon)
MinStk.Color     = T.Acc
MinStk.Thickness = 2

-- Main window
local MW = Instance.new("Frame", SG)
MW.Size                  = UDim2.new(0,490,0,330)
MW.Position              = UDim2.new(0.5,-245,0.5,-165)
MW.BackgroundColor3      = T.Bg
MW.BackgroundTransparency = 0.04
MW.Active                = true
Instance.new("UICorner", MW).CornerRadius = UDim.new(0,10)
local MWStr = Instance.new("UIStroke", MW)
MWStr.Color       = T.Strk
MWStr.Transparency = 0.3

-- Top bar
local TopBar = Instance.new("Frame", MW)
TopBar.Size               = UDim2.new(1,0,0,32)
TopBar.BackgroundTransparency = 1

local TitleL = Instance.new("TextLabel", TopBar)
TitleL.Size               = UDim2.new(0.75,0,1,0)
TitleL.Position           = UDim2.new(0,14,0,0)
TitleL.Text               = "🚗  CAR DRIVING INDONESIA HUB"
TitleL.Font               = Enum.Font.GothamBold
TitleL.TextColor3         = T.Acc
TitleL.TextSize           = 12
TitleL.TextXAlignment     = Enum.TextXAlignment.Left
TitleL.BackgroundTransparency = 1

local Sep = Instance.new("Frame", MW)
Sep.Size             = UDim2.new(1,-20,0,1)
Sep.Position         = UDim2.new(0,10,0,32)
Sep.BackgroundColor3 = T.Strk
Sep.BorderSizePixel  = 0

local function TopBtn(txt, pos, col, fn)
    local b = Instance.new("TextButton", TopBar)
    b.Size               = UDim2.new(0,28,0,22)
    b.Position           = pos
    b.BackgroundTransparency = 1
    b.Text               = txt
    b.TextColor3         = col
    b.Font               = Enum.Font.GothamBold
    b.TextSize           = 12
    b.MouseButton1Click:Connect(fn)
    return b
end

TopBtn("✕", UDim2.new(1,-32,0.5,-11), Color3.fromRGB(255,80,80), function()
    SG:Destroy()
end)
TopBtn("—", UDim2.new(1,-62,0.5,-11), T.Sub, function()
    MW.Visible    = false
    MinIcon.Visible = true
end)
MinIcon.MouseButton1Click:Connect(function()
    MW.Visible    = true
    MinIcon.Visible = false
end)

-- Drag
local function MakeDraggable(obj, handle)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = i.Position
            startPos  = obj.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            obj.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
MakeDraggable(MW, TopBar)
MakeDraggable(MinIcon, MinIcon)

-- Sidebar
local Sidebar = Instance.new("Frame", MW)
Sidebar.Size                  = UDim2.new(0,115,1,-33)
Sidebar.Position              = UDim2.new(0,0,0,33)
Sidebar.BackgroundColor3      = T.Side
Sidebar.BackgroundTransparency = 0.3
Sidebar.BorderSizePixel       = 0
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0,10)
local SbLayout = Instance.new("UIListLayout", Sidebar)
SbLayout.Padding             = UDim.new(0,5)
SbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", Sidebar).PaddingTop = UDim.new(0,10)

-- Content area
local CA = Instance.new("Frame", MW)
CA.Size               = UDim2.new(1,-125,1,-38)
CA.Position           = UDim2.new(0,120,0,38)
CA.BackgroundTransparency = 1

-- ─────────────────────────────────────────────────────────────
--  COMPONENT LIBRARY
-- ─────────────────────────────────────────────────────────────
local AllTabs    = {}
local AllTabBtns = {}

local function Tab(name, icon)
    local tf = Instance.new("ScrollingFrame", CA)
    tf.Size               = UDim2.new(1,0,1,0)
    tf.BackgroundTransparency = 1
    tf.ScrollBarThickness = 2
    tf.ScrollBarImageColor3 = T.AccDim
    tf.Visible            = false
    tf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tf.CanvasSize         = UDim2.new(0,0,0,0)
    tf.BorderSizePixel    = 0
    local lay = Instance.new("UIListLayout", tf)
    lay.Padding = UDim.new(0,7)
    Instance.new("UIPadding", tf).PaddingTop = UDim.new(0,6)

    local tb = Instance.new("TextButton", Sidebar)
    tb.Size               = UDim2.new(0.92,0,0,30)
    tb.BackgroundColor3   = T.Acc
    tb.BackgroundTransparency = 1
    tb.Text               = "  "..icon.." "..name
    tb.TextColor3         = T.Sub
    tb.Font               = Enum.Font.GothamMedium
    tb.TextSize           = 11
    tb.TextXAlignment     = Enum.TextXAlignment.Left
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0,6)

    local ind = Instance.new("Frame", tb)
    ind.Size              = UDim2.new(0,3,0.6,0)
    ind.Position          = UDim2.new(0,2,0.2,0)
    ind.BackgroundColor3  = T.Acc
    ind.Visible           = false
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1,0)

    tb.MouseButton1Click:Connect(function()
        for _, t in ipairs(AllTabs)    do t.f.Visible = false end
        for _, b in ipairs(AllTabBtns) do
            b.b.BackgroundTransparency = 1
            b.b.TextColor3 = T.Sub
            b.i.Visible = false
        end
        tf.Visible             = true
        tb.BackgroundTransparency = 0.82
        tb.TextColor3          = T.Txt
        ind.Visible            = true
    end)

    table.insert(AllTabs,    {f = tf})
    table.insert(AllTabBtns, {b = tb, i = ind})
    return tf
end

local function Sect(parent, txt)
    local l = Instance.new("TextLabel", parent)
    l.Size               = UDim2.new(0.98,0,0,18)
    l.BackgroundTransparency = 1
    l.Text               = txt
    l.TextColor3         = T.AccDim
    l.Font               = Enum.Font.GothamBold
    l.TextSize           = 10
    l.TextXAlignment     = Enum.TextXAlignment.Left
end

local function Btn(parent, txt, fn)
    local b = Instance.new("TextButton", parent)
    b.Size               = UDim2.new(0.98,0,0,35)
    b.BackgroundColor3   = T.Btn
    b.Text               = txt
    b.Font               = Enum.Font.GothamBold
    b.TextColor3         = T.Txt
    b.TextSize           = 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke", b).Color        = T.Strk
    b.MouseButton1Click:Connect(fn)
    return b
end

local function InfoLbl(parent, txt)
    local l = Instance.new("TextLabel", parent)
    l.Size               = UDim2.new(0.98,0,0,28)
    l.BackgroundColor3   = T.Btn
    l.BackgroundTransparency = 0.3
    l.Text               = "  "..txt
    l.Font               = Enum.Font.GothamMedium
    l.TextColor3         = T.Sub
    l.TextSize           = 10
    l.TextXAlignment     = Enum.TextXAlignment.Left
    Instance.new("UICorner", l).CornerRadius = UDim.new(0,7)
    return l
end

local function Toggle(parent, title, desc, fn)
    local state = false
    local row = Instance.new("TextButton", parent)
    row.Size              = UDim2.new(0.98,0,0,50)
    row.BackgroundColor3  = T.Btn
    row.Text              = ""
    row.AutoButtonColor   = false
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke", row).Color        = T.Strk

    local tl = Instance.new("TextLabel", row)
    tl.Size               = UDim2.new(0.72,0,0.5,0)
    tl.Position           = UDim2.new(0,10,0,5)
    tl.Text               = title
    tl.Font               = Enum.Font.GothamMedium
    tl.TextColor3         = T.Txt
    tl.TextSize           = 12
    tl.TextXAlignment     = Enum.TextXAlignment.Left
    tl.BackgroundTransparency = 1

    local dl = Instance.new("TextLabel", row)
    dl.Size               = UDim2.new(0.72,0,0.5,0)
    dl.Position           = UDim2.new(0,10,0.5,0)
    dl.Text               = desc
    dl.Font               = Enum.Font.Gotham
    dl.TextColor3         = T.Sub
    dl.TextSize           = 9
    dl.TextXAlignment     = Enum.TextXAlignment.Left
    dl.BackgroundTransparency = 1

    local pill = Instance.new("Frame", row)
    pill.Size             = UDim2.new(0,44,0,22)
    pill.Position         = UDim2.new(1,-54,0.5,-11)
    pill.BackgroundColor3 = T.Btn
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1,0)
    local ps = Instance.new("UIStroke", pill)
    ps.Color    = T.Strk
    ps.Thickness = 1

    local pt = Instance.new("TextLabel", pill)
    pt.Size               = UDim2.new(1,0,1,0)
    pt.Text               = "OFF"
    pt.Font               = Enum.Font.GothamBold
    pt.TextColor3         = T.Sub
    pt.TextSize           = 9
    pt.BackgroundTransparency = 1

    local function setV(on)
        state             = on
        pill.BackgroundColor3 = on and T.Acc or T.Btn
        ps.Color          = on and T.Acc or T.Strk
        pt.Text           = on and "ON" or "OFF"
        pt.TextColor3     = on and Color3.new(1,1,1) or T.Sub
        row.BackgroundColor3 = on and Color3.fromRGB(22,36,28) or T.Btn
    end
    setV(false)
    row.MouseButton1Click:Connect(function()
        local want = not state
        local res  = fn(want)
        setV(res ~= nil and res or want)
    end)
    return setV
end

local function Slider(parent, label, minV, maxV, defV, fn)
    local row = Instance.new("Frame", parent)
    row.Size              = UDim2.new(0.98,0,0,62)
    row.BackgroundColor3  = T.Btn
    row.BorderSizePixel   = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke", row).Color        = T.Strk

    local nl = Instance.new("TextLabel", row)
    nl.Size               = UDim2.new(0.55,0,0,20)
    nl.Position           = UDim2.new(0,10,0,6)
    nl.BackgroundTransparency = 1
    nl.Text               = label
    nl.TextColor3         = T.Txt
    nl.Font               = Enum.Font.GothamMedium
    nl.TextSize           = 11
    nl.TextXAlignment     = Enum.TextXAlignment.Left

    local vl = Instance.new("TextLabel", row)
    vl.Size               = UDim2.new(0.40,0,0,20)
    vl.Position           = UDim2.new(0.58,0,0,6)
    vl.BackgroundTransparency = 1
    vl.Font               = Enum.Font.GothamBold
    vl.TextSize           = 12
    vl.TextXAlignment     = Enum.TextXAlignment.Right

    local trk = Instance.new("Frame", row)
    trk.Size              = UDim2.new(1,-20,0,6)
    trk.Position          = UDim2.new(0,10,0,36)
    trk.BackgroundColor3  = Color3.fromRGB(14,18,28)
    trk.BorderSizePixel   = 0
    Instance.new("UICorner", trk).CornerRadius = UDim.new(0,3)

    local fl = Instance.new("Frame", trk)
    fl.BorderSizePixel    = 0
    fl.Size               = UDim2.new(0,0,1,0)
    Instance.new("UICorner", fl).CornerRadius  = UDim.new(0,3)

    local knob = Instance.new("Frame", trk)
    knob.Size             = UDim2.new(0,14,0,14)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel  = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0,7)

    -- min / max captions
    local function mkCap(pos, txt, align)
        local l = Instance.new("TextLabel", row)
        l.Size               = UDim2.new(0,40,0,10)
        l.Position           = pos
        l.BackgroundTransparency = 1
        l.Text               = txt
        l.TextColor3         = T.Sub
        l.Font               = Enum.Font.Code
        l.TextSize           = 8
        l.TextXAlignment     = align
    end
    mkCap(UDim2.new(0,10,0,50),  tostring(minV),          Enum.TextXAlignment.Left)
    mkCap(UDim2.new(1,-50,0,50), tostring(maxV).." MAX",  Enum.TextXAlignment.Right)

    local function applyPct(pct)
        pct = math.clamp(pct,0,1)
        local val = math.clamp(math.round(minV + pct*(maxV-minV)), minV, maxV)
        fn(val)
        local rp = (val-minV)/(maxV-minV)
        fl.Size          = UDim2.new(rp,0,1,0)
        knob.Position    = UDim2.new(rp,-7,0.5,-7)
        local col        = rp >= 1 and T.Red or T.Acc
        vl.Text          = tostring(val)
        vl.TextColor3    = col
        fl.BackgroundColor3 = col
        knob.BackgroundColor3 = rp >= 1 and T.Red or Color3.new(1,1,1)
    end
    applyPct((defV-minV)/(maxV-minV))

    local dragging = false
    local function fromInput(inp)
        local ax = trk.AbsolutePosition.X
        local aw = trk.AbsoluteSize.X
        applyPct((inp.Position.X - ax) / aw)
    end
    knob.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    trk.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; fromInput(i)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then
            fromInput(i)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

local function Stepper(parent, label, fmt, getV, decFn, incFn)
    local row = Instance.new("Frame", parent)
    row.Size              = UDim2.new(0.98,0,0,38)
    row.BackgroundColor3  = T.Btn
    row.BorderSizePixel   = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke", row).Color        = T.Strk

    local lbl = Instance.new("TextLabel", row)
    lbl.Size              = UDim2.new(0.52,0,1,0)
    lbl.Position          = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text              = string.format(fmt, getV())
    lbl.TextColor3        = T.Txt
    lbl.Font              = Enum.Font.GothamMedium
    lbl.TextSize          = 11
    lbl.TextXAlignment    = Enum.TextXAlignment.Left

    local function mkB(sym, xoff, fn2)
        local b = Instance.new("TextButton", row)
        b.Size            = UDim2.new(0,28,0,26)
        b.Position        = UDim2.new(1,xoff,0.5,-13)
        b.BackgroundColor3 = Color3.fromRGB(40,42,52)
        b.TextColor3      = T.Txt
        b.Text            = sym
        b.Font            = Enum.Font.GothamBold
        b.TextSize        = 14
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
        b.MouseButton1Click:Connect(function()
            fn2(); lbl.Text = string.format(fmt, getV())
        end)
    end
    mkB("<", -62, decFn)
    mkB(">", -30, incFn)
    return lbl
end

-- ═══════════════════════════════════════════════════════════════
--  STATE VARIABLES
-- ═══════════════════════════════════════════════════════════════
-- Vehicle
local origTopSpeed    = 0
local fuelFreezeConn  = nil
local boostConn       = nil
local lightLoopConn   = nil

-- Player
local flyActive      = false
local flySpeed       = 60
local flyBV          = nil
local flyBG          = nil
local noclipActive   = false
local noclipConn     = nil
local myWalkSpeed    = 16
local myJumpPower    = 50

-- ESP
local espActive      = false
local espObjects     = {}   -- list of instances + connections to clean up

-- Race
local raceAutoJoin   = false
local autoJoinThread = nil

-- World
local antiAfkActive  = false
local timeVal        = 14.0

-- ═══════════════════════════════════════════════════════════════
--  LOADING — TAB 1: VEHICLE
-- ═══════════════════════════════════════════════════════════════
SetProg(15, "Hooking Vehicle Controller...")
task.wait(0.15)

local TabV = Tab("Vehicle", "🚗")

--  ── SPEED ──────────────────────────────────────────────────
Sect(TabV, "  ⚡ SPEED")

--[[
  EXPLOIT: VehicleController reads Lighting.TopSpeed.Value at spawn AND on
  PropertyChanged (dump lines 58-76). Self.TopSpeed is then used by SpeedLimiter
  every Heartbeat (line 408). Writing 9999 bypasses the cap without any server call.
]]
Toggle(TabV, "Speed Unlock", "Bypass Lighting.TopSpeed cap (write 9999)",
function(v)
    if v then
        origTopSpeed = Lighting.TopSpeed.Value
        Lighting.TopSpeed.Value = 9999
        -- Patch live InterfaceTemplate if already in a car
        local veh = getMyVehicle()
        if veh then
            local tune = veh:FindFirstChild("A-Chassis Tune")
            if tune then
                pcall(function()
                    local iface = tune:FindFirstChild("A-Chassis Interface")
                    if iface and iface:FindFirstChild("TopSpeed") then
                        iface.TopSpeed.Value = 9999
                    end
                end)
            end
        end
    else
        Lighting.TopSpeed.Value = origTopSpeed > 0 and origTopSpeed or 200
    end
    return v
end)

--  ── FUEL ───────────────────────────────────────────────────
Sect(TabV, "  ⛽ FUEL")

--[[
  EXPLOIT: CarData.Fuel (NumberValue) is decremented locally by the Fuel module
  every Heartbeat at line 1410-1411 of the dump. We freeze it client-side
  by resetting it to 100 before the module can subtract from it.
]]
Toggle(TabV, "Fuel Freeze", "Reset CarData.Fuel to 100% every frame",
function(v)
    if v then
        fuelFreezeConn = RunService.Heartbeat:Connect(function()
            local cd = getMyCarData()
            if cd and cd:FindFirstChild("Fuel") and cd.Fuel.Value < 99 then
                cd.Fuel.Value = 100
            end
        end)
    else
        if fuelFreezeConn then fuelFreezeConn:Disconnect(); fuelFreezeConn = nil end
    end
    return v
end)

Btn(TabV, "Instant Refuel (+100%)", function()
    local cd = getMyCarData()
    if cd and cd:FindFirstChild("Fuel") then
        cd.Fuel.Value = 100
    end
end)

--  ── BOOST ──────────────────────────────────────────────────
Sect(TabV, "  🚀 BOOST / NITRO")

--[[
  EXPLOIT: DriveSeat.Values.Boost / BoostTurbo / BoostSuper are NumberValues
  read by VehicleController.UpdateDriveVars (dump lines 301-325) and fired via
  DataReceiver. Flooding them at max value on Heartbeat = always-full boost.
]]
Toggle(TabV, "Infinite Boost", "Keep Boost, BoostTurbo, BoostSuper at 100",
function(v)
    if v then
        boostConn = RunService.Heartbeat:Connect(function()
            local vals = getMyValues()
            if not vals then return end
            for _, nm in ipairs({"Boost","BoostTurbo","BoostSuper"}) do
                local nv = vals:FindFirstChild(nm)
                if nv and nv.Value < 100 then nv.Value = 100 end
            end
        end)
    else
        if boostConn then boostConn:Disconnect(); boostConn = nil end
    end
    return v
end)

--  ── LIGHTS ─────────────────────────────────────────────────
Sect(TabV, "  💡 LIGHTS")

--[[
  EXPLOIT: DriveSeat.FE_Lights:FireServer(action, lightType, bool)
  Confirmed in Live_Remote_Logs.txt on every car.  Valid actions from dump:
  "updateLights" with types: drl, brake, reverse, foglight, highbeam, beam
  "blinkers" with: Left, Right, Hazards
]]
Btn(TabV, "Toggle High Beam", function()
    local ds = getMyDriveSeat()
    if ds and ds:FindFirstChild("FE_Lights") then
        local lights = ds:FindFirstChild("Lights")
        local cur = lights and lights.Value or false
        pcall(function() ds.FE_Lights:FireServer("updateLights","highbeam", not cur) end)
    end
end)

Btn(TabV, "Toggle Fog Lights", function()
    local ds = getMyDriveSeat()
    if ds and ds:FindFirstChild("FE_Lights") then
        pcall(function() ds.FE_Lights:FireServer("updateLights","foglight", true) end)
    end
end)

Btn(TabV, "Hazard Lights ON", function()
    local ds = getMyDriveSeat()
    if ds and ds:FindFirstChild("FE_Lights") then
        pcall(function() ds.FE_Lights:FireServer("blinkers","Hazards") end)
    end
end)

Toggle(TabV, "Strobe DRL Loop", "Rapidly toggles DRL on/off (strobo effect)",
function(v)
    if v then
        local on = true
        lightLoopConn = RunService.Heartbeat:Connect(function()
            local ds = getMyDriveSeat()
            if ds and ds:FindFirstChild("FE_Lights") then
                pcall(function() ds.FE_Lights:FireServer("updateLights","drl",on) end)
                on = not on
            end
        end)
    else
        if lightLoopConn then lightLoopConn:Disconnect(); lightLoopConn = nil end
        -- restore DRL on
        local ds = getMyDriveSeat()
        if ds and ds:FindFirstChild("FE_Lights") then
            pcall(function() ds.FE_Lights:FireServer("updateLights","drl",true) end)
        end
    end
    return v
end)

--  ── MISC VEHICLE ───────────────────────────────────────────
Sect(TabV, "  🔄 MISC VEHICLE")

Btn(TabV, "Auto-Flip Car", function()
    -- Moves DriveSeat up by 4 studs upright — same logic as the in-game AutoFlip
    local ds = getMyDriveSeat()
    if ds then
        pcall(function()
            ds.CFrame = CFrame.new(ds.Position + Vector3.new(0,4,0))
        end)
    end
end)

Btn(TabV, "Teleport to Dealership", function()
    -- CmdrClient.RemoteFunction:InvokeServer("teleportdealership") — dump line 5350
    local ok = false
    local cmdr = RS:FindFirstChild("CmdrClient")
    if cmdr then
        local rf = cmdr:FindFirstChild("RemoteFunction")
        if rf then
            pcall(function() rf:InvokeServer("teleportdealership"); ok = true end)
        end
    end
    if not ok then
        -- Fallback: find nearest part named "Dealership" in workspace
        local best, bdist = nil, math.huge
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v.Name == "Dealership" and v:IsA("BasePart") then
                local hrp = getHRP()
                if hrp then
                    local d = (v.Position - hrp.Position).Magnitude
                    if d < bdist then bdist = d; best = v end
                end
            end
        end
        if best then
            local hrp = getHRP()
            if hrp then hrp.CFrame = best.CFrame * CFrame.new(0,5,0) end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  TAB 2: PLAYER
-- ═══════════════════════════════════════════════════════════════
SetProg(35, "Building Player Tab...")
task.wait(0.1)

local TabP = Tab("Player", "👤")

--  ── FLY ────────────────────────────────────────────────────
Sect(TabP, "  ✈️ FLY")

--[[
  Standard Roblox fly technique: inject BodyVelocity + BodyGyro into HRP.
  PlatformStand=true disables humanoid physics so we have full control.
  Works alongside A-Chassis because fly acts on the Character, not the vehicle.
  Controls: W/A/S/D = directional, Space = up, LeftCtrl = down, LShift = 2.5× speed.
]]
Toggle(TabP, "Fly Mode", "WASD + Space/LeftCtrl  |  LShift = boost",
function(v)
    local hrp = getHRP()
    if not hrp and v then return false end

    if v then
        flyBV           = Instance.new("BodyVelocity", hrp)
        flyBV.Velocity  = Vector3.new(0,0,0)
        flyBV.MaxForce  = Vector3.new(1e5,1e5,1e5)
        flyBV.P         = 1e4

        flyBG           = Instance.new("BodyGyro", hrp)
        flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5)
        flyBG.P         = 1e4
        flyBG.CFrame    = hrp.CFrame

        local hum = getHum()
        if hum then hum.PlatformStand = true end

        RunService:BindToRenderStep("CDID_Fly",
            Enum.RenderPriority.Input.Value + 1,
        function()
            if not flyBV or not flyBV.Parent then return end
            local cam   = Workspace.CurrentCamera
            local spd   = flySpeed
            local dir   = Vector3.new(0,0,0)
            local UIS   = UserInputService
            if UIS:IsKeyDown(Enum.KeyCode.W)           then dir = dir + cam.CFrame.LookVector  end
            if UIS:IsKeyDown(Enum.KeyCode.S)           then dir = dir - cam.CFrame.LookVector  end
            if UIS:IsKeyDown(Enum.KeyCode.A)           then dir = dir - cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D)           then dir = dir + cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space)       then dir = dir + Vector3.new(0,1,0)    end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0)    end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift)   then spd = spd * 2.5                   end
            if dir.Magnitude > 0 then
                flyBV.Velocity = dir.Unit * spd
                flyBG.CFrame   = CFrame.new(Vector3.new(), dir)
            else
                flyBV.Velocity = Vector3.new(0,0,0)
            end
        end)
    else
        RunService:UnbindFromRenderStep("CDID_Fly")
        if flyBV and flyBV.Parent then flyBV:Destroy() end
        if flyBG and flyBG.Parent then flyBG:Destroy() end
        flyBV = nil; flyBG = nil
        local hum = getHum()
        if hum then hum.PlatformStand = false end
    end
    flyActive = v
    return v
end)

Slider(TabP, "Fly Speed", 20, 500, 60, function(val)
    flySpeed = val
end)

--  ── NOCLIP ─────────────────────────────────────────────────
Sect(TabP, "  👻 NOCLIP")

--[[
  Every Heartbeat set CanCollide=false on every BasePart in the character.
  This runs faster than the server can re-enable collision, making the character
  pass through walls, other players, and vehicle bodies.
]]
Toggle(TabP, "NoClip", "Walk through walls, terrain and vehicles",
function(v)
    if v then
        noclipConn = RunService.Heartbeat:Connect(function()
            local c = getChar()
            if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    end
    noclipActive = v
    return v
end)

--  ── MOVEMENT ───────────────────────────────────────────────
Sect(TabP, "  🏃 MOVEMENT")

Slider(TabP, "Walk Speed", 8, 200, 16, function(val)
    myWalkSpeed = val
    local hum = getHum()
    if hum then hum.WalkSpeed = val end
end)

Slider(TabP, "Jump Power", 10, 300, 50, function(val)
    myJumpPower = val
    local hum = getHum()
    if hum then hum.JumpPower = val end
end)

Btn(TabP, "Reset to Normal (16 WS / 50 JP)", function()
    myWalkSpeed = 16; myJumpPower = 50
    local hum = getHum()
    if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
end)

-- Re-apply on respawn
lp.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    task.wait(0.3)
    hum.WalkSpeed  = myWalkSpeed
    hum.JumpPower  = myJumpPower
    if noclipActive and not noclipConn then
        noclipConn = RunService.Heartbeat:Connect(function()
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
    end
    if flyActive then
        flyActive = false   -- will need re-enable after respawn
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  TAB 3: RACE
-- ═══════════════════════════════════════════════════════════════
SetProg(55, "Hooking Race Remotes...")
task.wait(0.1)

local TabR = Tab("Race", "🏁")

Sect(TabR, "  📋 LEADERBOARD")

--[[
  RemoteFunctions.Leaderboard:InvokeServer() — spotted 10+ times in Live_Remote_Logs.txt
  and confirmed at dump line 10884. Returns the current race leaderboard.
]]
local lbLbl = InfoLbl(TabR, "[ Press Pull to fetch ]")
Btn(TabR, "Pull Live Leaderboard", function()
    lbLbl.Text = "  Fetching..."
    task.spawn(function()
        local res = safeInvoke("Leaderboard")
        if type(res) == "table" then
            local lines = {}
            for i, row in ipairs(res) do
                if i > 6 then break end
                local name = type(row) == "table"
                    and (row.Name or row.PlayerName or row[1] or "?")
                    or tostring(row)
                table.insert(lines, string.format("#%d %s", i, name))
            end
            lbLbl.Text = "  " .. table.concat(lines, "  ·  ")
        elseif type(res) == "string" then
            lbLbl.Text = "  " .. res
        else
            lbLbl.Text = "  No data returned"
        end
    end)
end)

Sect(TabR, "  🏎️ SENTUL RACE")

--[[
  RemoteFunctions.SentulRace:InvokeServer("Enter", carName) — dump line 11129.
  The car name comes from CarData.CarName.Value on the player's active vehicle.
]]
local rsLbl = InfoLbl(TabR, "Race status: idle")

local function getActiveCarName()
    local cd = getMyCarData()
    return cd and cd:FindFirstChild("CarName") and cd.CarName.Value or "Default"
end

Btn(TabR, "Enter Sentul Race (active car)", function()
    rsLbl.Text = "  Joining..."
    task.spawn(function()
        local res = safeInvoke("SentulRace", "Enter", getActiveCarName())
        rsLbl.Text = "  " .. (res and tostring(res) or "No response")
    end)
end)

Btn(TabR, "Leave Sentul Race", function()
    task.spawn(function()
        local res = safeInvoke("SentulRace", "Leave", getActiveCarName())
        rsLbl.Text = "  " .. (res and tostring(res) or "Left / no response")
    end)
end)

Sect(TabR, "  ⏱ TIME TRIAL")

--[[
  RemoteFunctions.TimeTrial:InvokeServer(carName) — dump line 11178.
]]
local ttLbl = InfoLbl(TabR, "[ Time Trial result ]")
Btn(TabR, "Invoke Time Trial", function()
    task.spawn(function()
        local res = safeInvoke("TimeTrial", getActiveCarName())
        ttLbl.Text = "  " .. (res and tostring(res) or "No result")
    end)
end)

Sect(TabR, "  🤖 AUTO RACE")

Toggle(TabR, "Auto Re-enter Race", "Re-joins Sentul race every 28 s",
function(v)
    raceAutoJoin = v
    if v then
        autoJoinThread = task.spawn(function()
            while raceAutoJoin do
                pcall(function()
                    safeInvoke("SentulRace", "Enter", getActiveCarName())
                end)
                task.wait(28)
            end
        end)
    end
    return v
end)

-- ═══════════════════════════════════════════════════════════════
--  TAB 4: ESP
-- ═══════════════════════════════════════════════════════════════
SetProg(72, "Building ESP...")
task.wait(0.1)

local TabE = Tab("ESP", "👁")

local function espClean()
    for _, obj in ipairs(espObjects) do
        if typeof(obj) == "RBXScriptConnection" then
            pcall(function() obj:Disconnect() end)
        elseif typeof(obj) == "Instance" and obj.Parent then
            pcall(function() obj:Destroy() end)
        end
    end
    espObjects = {}
end

local function espBillboard(adornee, dataFn, nameColor)
    local bb = Instance.new("BillboardGui")
    bb.Name           = "CDID_ESP"
    bb.AlwaysOnTop    = true
    bb.Size           = UDim2.new(0,130,0,44)
    bb.StudsOffset    = Vector3.new(0,3.5,0)
    bb.Adornee        = adornee
    bb.Parent         = adornee

    local bg2 = Instance.new("Frame", bb)
    bg2.Size                  = UDim2.new(1,0,1,0)
    bg2.BackgroundColor3      = Color3.fromRGB(8,10,16)
    bg2.BackgroundTransparency = 0.45
    Instance.new("UICorner", bg2).CornerRadius = UDim.new(0,5)

    local nl = Instance.new("TextLabel", bg2)
    nl.Size               = UDim2.new(1,-4,0.55,0)
    nl.Position           = UDim2.new(0,2,0,2)
    nl.BackgroundTransparency = 1
    nl.Font               = Enum.Font.GothamBold
    nl.TextSize           = 11
    nl.TextColor3         = nameColor or T.Acc
    nl.Text               = ""

    local il = Instance.new("TextLabel", bg2)
    il.Size               = UDim2.new(1,-4,0.42,0)
    il.Position           = UDim2.new(0,2,0.56,0)
    il.BackgroundTransparency = 1
    il.Font               = Enum.Font.Code
    il.TextSize           = 9
    il.TextColor3         = T.Sub
    il.Text               = ""

    local hbg = Instance.new("Frame", bg2)
    hbg.Size              = UDim2.new(1,-4,0,3)
    hbg.Position          = UDim2.new(0,2,1,-5)
    hbg.BackgroundColor3  = Color3.fromRGB(25,25,25)
    hbg.BorderSizePixel   = 0
    Instance.new("UICorner", hbg).CornerRadius = UDim.new(1,0)

    local hfl = Instance.new("Frame", hbg)
    hfl.Size              = UDim2.new(1,0,1,0)
    hfl.BackgroundColor3  = T.Grn
    hfl.BorderSizePixel   = 0
    Instance.new("UICorner", hfl).CornerRadius = UDim.new(1,0)

    local conn = RunService.Heartbeat:Connect(function()
        if not bb.Parent then return end
        local d = dataFn()
        if not d then return end
        nl.Text  = d.name or ""
        il.Text  = d.info or ""
        local hp = math.clamp(d.hp or 1, 0, 1)
        hfl.Size = UDim2.new(hp,0,1,0)
        hfl.BackgroundColor3 = hp > 0.5 and T.Grn or (hp > 0.25 and T.Orng or T.Red)
    end)

    table.insert(espObjects, bb)
    table.insert(espObjects, conn)
end

local function espBuild()
    espClean()
    local myHRP = getHRP()

    for _, plr in ipairs(Players:GetPlayers()) do
        -- NOTE: Lua 5.1 — no 'continue'. Use if/then to skip self.
        if plr ~= lp then
            local function attachChar(char)
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                -- Highlight (2022+ supported by most executors)
                pcall(function()
                    local hl = Instance.new("Highlight", char)
                    hl.Name             = "CDID_ESP_HL"
                    hl.FillColor        = Color3.fromRGB(0,140,90)
                    hl.OutlineColor     = Color3.fromRGB(0,220,150)
                    hl.FillTransparency = 0.72
                    table.insert(espObjects, hl)
                end)

                -- Billboard
                espBillboard(hrp, function()
                    if not plr.Character then return nil end
                    local pHRP = plr.Character:FindFirstChild("HumanoidRootPart")
                    if not pHRP then return nil end
                    local mHRP = getHRP()
                    local dist = mHRP and (pHRP.Position - mHRP.Position).Magnitude or 0
                    local hum  = plr.Character:FindFirstChildOfClass("Humanoid")
                    local hp   = hum and (hum.Health / math.max(hum.MaxHealth,1)) or 1

                    -- Check if player is in a CDID vehicle
                    local vf  = Workspace:FindFirstChild("Vehicles")
                    local carTxt = "on foot"
                    if vf then
                        local cv = vf:FindFirstChild(plr.Name.."sCar")
                        if cv then
                            local cd = cv:FindFirstChild("CarData")
                            carTxt = cd and cd:FindFirstChild("CarName")
                                and ("🚗 "..cd.CarName.Value) or "driving"
                        end
                    end
                    return {
                        name = plr.Name,
                        info = string.format("%.0f st  |  %s", dist, carTxt),
                        hp   = hp,
                    }
                end, Color3.fromRGB(0,200,140))
            end

            if plr.Character then attachChar(plr.Character) end

            local conn2 = plr.CharacterAdded:Connect(function(char)
                if espActive then
                    task.wait(1.2)
                    attachChar(char)
                end
            end)
            table.insert(espObjects, conn2)
        end
    end

    -- Vehicle-only ESP (parked / unoccupied cars)
    local vf = Workspace:FindFirstChild("Vehicles")
    if vf then
        for _, veh in ipairs(vf:GetChildren()) do
            local ds = veh:FindFirstChild("DriveSeat")
            if ds then
                local cd      = veh:FindFirstChild("CarData")
                local carName = cd and cd:FindFirstChild("CarName") and cd.CarName.Value or veh.Name
                local ownName = veh.Name:gsub("sCar$","")
                espBillboard(ds, function()
                    return {
                        name = "🚗 "..carName,
                        info = ownName,
                        hp   = 1,
                    }
                end, T.Ylw)
            end
        end
    end
end

-- New player hook
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        if espActive then
            task.wait(1.2)
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                espBillboard(hrp, function()
                    if not plr.Character then return nil end
                    local pHRP = plr.Character:FindFirstChild("HumanoidRootPart")
                    if not pHRP then return nil end
                    local mHRP = getHRP()
                    local dist = mHRP and (pHRP.Position - mHRP.Position).Magnitude or 0
                    local hum  = plr.Character:FindFirstChildOfClass("Humanoid")
                    local hp   = hum and (hum.Health / math.max(hum.MaxHealth,1)) or 1
                    return {name = plr.Name, info = string.format("%.0f st",dist), hp = hp}
                end, Color3.fromRGB(0,200,140))
            end
        end
    end)
end)

Sect(TabE, "  👁 PLAYER / CAR ESP")

Toggle(TabE, "ESP", "BillboardGUI + Highlight on all players & cars",
function(v)
    espActive = v
    if v then espBuild() else espClean() end
    return v
end)

Btn(TabE, "Refresh ESP", function()
    if espActive then espBuild() end
end)

Sect(TabE, "  📊 MY VEHICLE INFO")

local vi1 = InfoLbl(TabE, "Car: —")
local vi2 = InfoLbl(TabE, "Fuel: —")
local vi3 = InfoLbl(TabE, "HP: —")
local vi4 = InfoLbl(TabE, "Odometer: —")

task.spawn(function()
    while task.wait(2) do
        local cd = getMyCarData()
        if cd then
            local carN = cd:FindFirstChild("CarName")
            local fuel = cd:FindFirstChild("Fuel")
            local cust = cd:FindFirstChild("Customizeable")
            local hpNV = cust and cust:FindFirstChild("Horsepower")
            local v    = getMyVehicle()
            local odo  = v and v:GetAttribute("Odometer")

            vi1.Text = "  Car: " .. (carN and carN.Value or "?")
            vi2.Text = "  Fuel: " .. (fuel and string.format("%.1f%%", fuel.Value) or "?")
            vi3.Text = "  HP: "   .. (hpNV and tostring(hpNV.Value) or "?")
            vi4.Text = "  ODO: "  .. (odo and string.format("%.1f km", odo) or "?")
        else
            vi1.Text = "  Car: not spawned"
            vi2.Text = "  Fuel: —"
            vi3.Text = "  HP: —"
            vi4.Text = "  ODO: —"
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
--  TAB 5: WORLD
-- ═══════════════════════════════════════════════════════════════
SetProg(88, "Building World Tab...")
task.wait(0.1)

local TabW = Tab("World", "🌍")

Sect(TabW, "  🕐 TIME OF DAY")

Stepper(TabW, "Time of Day", "🕐  %.1f h",
    function() return timeVal end,
    function() timeVal = math.max(0, timeVal-1);  Lighting.ClockTime = timeVal end,
    function() timeVal = math.min(24, timeVal+1); Lighting.ClockTime = timeVal end
)

Btn(TabW, "Night  (22:00)", function()
    timeVal = 22; Lighting.ClockTime = 22
end)
Btn(TabW, "Golden Hour  (18:00)", function()
    timeVal = 18; Lighting.ClockTime = 18
end)
Btn(TabW, "Noon  (12:00)", function()
    timeVal = 12; Lighting.ClockTime = 12
end)
Btn(TabW, "Dawn  (06:00)", function()
    timeVal = 6; Lighting.ClockTime = 6
end)

Sect(TabW, "  🔕 ANTI-AFK")

--[[
  Roblox auto-kicks after ~20 min idle. VirtualUser:Button2Down simulates a click
  every 55 seconds so the idle timer never triggers.
]]
Toggle(TabW, "Anti-AFK", "Simulates input every 55 s to avoid kick",
function(v)
    antiAfkActive = v
    if v then
        task.spawn(function()
            local VU = game:GetService("VirtualUser")
            while antiAfkActive do
                task.wait(55)
                if not antiAfkActive then break end
                pcall(function()
                    VU:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                    task.wait(0.1)
                    VU:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                end)
            end
        end)
    end
    return v
end)

Sect(TabW, "  🔊 AUDIO")

--[[
  EXPLOIT: player attribute "MuteSirine" checked at dump lines 87-103.
  Setting it TRUE zeroes out all lightbar/siren sound volumes client-side.
]]
Toggle(TabW, "Mute Siren / Lightbar", "Sets MuteSirine attribute on local player",
function(v)
    lp:SetAttribute("MuteSirine", v)
    return v
end)

Sect(TabW, "  🖥 PERFORMANCE")

Toggle(TabW, "Unlock FPS (setfpscap 0)", "Requires executor support",
function(v)
    if v then pcall(function() setfpscap(0)  end)
    else      pcall(function() setfpscap(60) end)
    end
    return v
end)

Sect(TabW, "  🔌 SESSION")

Btn(TabW, "Rejoin Server", function()
    pcall(function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, lp)
    end)
end)

Btn(TabW, "Get Server Time", function()
    task.spawn(function()
        local t = safeInvoke("GetServerTime")
        print("[CDID Hub] Server time:", t)
    end)
end)

-- ═══════════════════════════════════════════════════════════════
--  ACTIVATE FIRST TAB
-- ═══════════════════════════════════════════════════════════════
SetProg(100, "Ready!")
task.wait(0.45)

if AllTabs[1] and AllTabBtns[1] then
    AllTabs[1].f.Visible               = true
    AllTabBtns[1].b.BackgroundTransparency = 0.82
    AllTabBtns[1].b.TextColor3         = T.Txt
    AllTabBtns[1].i.Visible            = true
end

-- ═══════════════════════════════════════════════════════════════
--  DISMISS LOADING SCREEN
-- ═══════════════════════════════════════════════════════════════
loadConn:Disconnect()
TweenService:Create(bg, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
    {BackgroundTransparency = 1}):Play()
for _, d in ipairs(loadGui:GetDescendants()) do
    pcall(function()
        if d:IsA("TextLabel") then
            TweenService:Create(d, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
        elseif d:IsA("Frame") then
            TweenService:Create(d, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
        end
    end)
end
task.wait(0.6)
pcall(function() loadGui:Destroy() end)

-- ═══════════════════════════════════════════════════════════════
--  CLEANUP ON DESTROY
-- ═══════════════════════════════════════════════════════════════
SG.Destroying:Connect(function()
    -- Stop all loops
    pcall(function() RunService:UnbindFromRenderStep("CDID_Fly") end)
    if fuelFreezeConn then fuelFreezeConn:Disconnect() end
    if boostConn      then boostConn:Disconnect() end
    if noclipConn     then noclipConn:Disconnect() end
    if lightLoopConn  then lightLoopConn:Disconnect() end
    if flyBV and flyBV.Parent  then flyBV:Destroy() end
    if flyBG and flyBG.Parent  then flyBG:Destroy() end
    espClean()
    antiAfkActive = false
    raceAutoJoin  = false

    -- Restore state
    Lighting.TopSpeed.Value = origTopSpeed > 0 and origTopSpeed or 200
    local hum = getHum()
    if hum then
        hum.PlatformStand = false
        hum.WalkSpeed     = 16
        hum.JumpPower     = 50
    end
    lp:SetAttribute("MuteSirine", false)
    pcall(function() setfpscap(60) end)
end)

print("[CDID Hub v1.1] ✅ All tabs loaded. Game: Car Driving Indonesia")
