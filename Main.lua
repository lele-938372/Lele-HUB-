-- ╔══════════════════════════════════════════════════════════╗
-- ║              LELE HUB  |  v13.0                         ║
-- ╚══════════════════════════════════════════════════════════╝
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local HttpService=game:GetService("HttpService")
local LP=Players.LocalPlayer
local Cam=workspace.CurrentCamera
local VER="v13.0"

-- ══ FILE I/O (Delta, Xeno, Solara compatible) ══
local function SafeRead(f)
    local ok,r=pcall(function()
        if not readfile then return nil end
        if isfile and not isfile(f) then return nil end
        return readfile(f)
    end)
    return ok and r or nil
end
local function SafeWrite(f,d) pcall(function() if writefile then writefile(f,d) end end) end
local function ReadJ(f)
    local raw=SafeRead(f); if not raw or raw=="" then return {} end
    local ok,r=pcall(function() return HttpService:JSONDecode(raw) end)
    return (ok and type(r)=="table") and r or {}
end
local function WriteJ(f,d)
    local ok,str=pcall(function() return HttpService:JSONEncode(d) end)
    if ok then SafeWrite(f,str) end
end

local SF="LeleHUB_v126.json"
local KF="LeleHUB_Keys.json"
local OF="LeleHUB_Sessions.json"
local CKF="LeleHUB_CustomKeys.json"  -- persists across script reloads
local SV=ReadJ(SF); local KUSED=ReadJ(KF)
local CUSTOM_KEYS=ReadJ(CKF)  -- owner-added keys, always loaded fresh

-- ══ ANTI-DETECTION ══
-- 1) Spoof getgenv/getrenv so the script name isn't findable
pcall(function()
    local env=getgenv and getgenv() or {}
    for _,k in ipairs({"LeleHUB","leleHub","lele_hub","LELEHUB"}) do
        pcall(function() env[k]=nil end)
    end
end)
-- 2) Block decompile
pcall(function()
    if not decompile then return end
    local _dc=decompile
    decompile=function(s,...) if s==script then return "" end return _dc(s,...) end
end)
-- 3) Periodic GUI rename (anti-memory scanner)
local _guiRename=0
RunService.Heartbeat:Connect(function()
    _guiRename=_guiRename+1
    if _guiRename%600==0 then
        pcall(function() SG.Name=tostring(math.random(100000,999999)).."_r" end)
    end
end)
-- 4) Randomized no-op remote lookups (camouflage traffic)
task.spawn(function()
    while true do
        task.wait(5+math.random()*8)  -- randomized 5–13s
        pcall(function()
            local rs=game:GetService("ReplicatedStorage")
            local ev=rs:FindFirstChild("ClientEvent") or rs:FindFirstChildWhichIsA("RemoteEvent")
            local _=ev
        end)
    end
end)
-- 5) WalkSpeed jitter — randomize every few seconds so server never sees a constant value
task.spawn(function()
    while true do
        task.wait(2+math.random()*6)
        pcall(function()
            if not S.Unlocked then return end
            local char=LP.Character; if not char then return end
            local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
            -- Always jitter, even at default speed (makes pattern analysis harder)
            local base=S.WalkSpeed
            local j=math.random(-1,1)
            hum.WalkSpeed=base+j
            task.wait(0.08+math.random()*0.08)
            hum.WalkSpeed=base
        end)
    end
end)
-- 5b) JumpPower jitter
task.spawn(function()
    while true do
        task.wait(4+math.random()*8)
        pcall(function()
            if not S.Unlocked then return end
            local char=LP.Character; if not char then return end
            local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
            local base=S.JumpPower
            hum.JumpPower=base+math.random(-1,1)
            task.wait(0.1)
            hum.JumpPower=base
        end)
    end
end)
-- 6) Scan and destroy any BodyVelocity/BodyGyro added by the game (prevents interference)
local _acTick=0
RunService.Heartbeat:Connect(function()
    _acTick=_acTick+1
    if _acTick%600~=0 then return end  -- every ~10s
    pcall(function()
        if not S.Fly then return end
        local char=LP.Character; if not char then return end
        -- Remove any BodyVelocity/BodyGyro not created by us (game-side interference)
        for _,v in ipairs(char:GetDescendants()) do
            if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then
                pcall(function() v:Destroy() end)
            end
        end
    end)
end)


-- ══ MOBILE PLATFORM SPOOF ══
-- Delta: hookmetamethod → spooft TouchEnabled, GetLastInputType, DevicePlatform
-- Xeno:  hookfunction + VirtualInputManager Touch-Event → Engine meldet selbst Touch
-- Beide: RemoteEvent Scanner für Rivals und andere Spiele

local UIS = UserInputService
local VIM = pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager") or nil

-- Erkennung welcher Executor
local _isDelta = (hookmetamethod ~= nil and checkcaller ~= nil)
local _isXeno  = (not _isDelta and hookfunction ~= nil)

-- ── DELTA: hookmetamethod __index + __namecall ──
if _isDelta then
    pcall(function()
        local oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if not checkcaller() then
                if self == UIS then
                    if key == "TouchEnabled"    then return true  end
                    if key == "KeyboardEnabled" then return false end
                    if key == "MouseEnabled"    then return false end
                    if key == "GamepadEnabled"  then return false end
                end
                if self == LP then
                    if key == "DevicePlatform" then return Enum.DevicePlatform.Phone end
                end
            end
            return oldIndex(self, key)
        end))

        local oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local m = getnamecallmethod()
            if not checkcaller() and self == UIS then
                if m == "GetLastInputType" then return Enum.UserInputType.Touch end
                if m == "GetFocusedTextBox" then return nil end
            end
            return oldNamecall(self, ...)
        end))
    end)
end

-- ── XENO: hookfunction auf einzelne UIS-Methoden ──
if _isXeno then
    -- GetLastInputType immer Touch zurückgeben
    pcall(function()
        hookfunction(UIS.GetLastInputType, newcclosure(function()
            return Enum.UserInputType.Touch
        end))
    end)
    -- GetLastInputType als bound method (manche Spiele rufen es so auf)
    pcall(function()
        local orig = UIS.GetLastInputType
        UIS.GetLastInputType = function() return Enum.UserInputType.Touch end
    end)

    -- VirtualInputManager: sende echten Touch-Event damit die Engine
    -- selbst TouchEnabled=true meldet (funktioniert auf Xeno zuverlässig)
    local function SendFakeTouch()
        pcall(function()
            if not VIM then return end
            -- Touch Begin + End an Position (0,0) — für den Nutzer unsichtbar
            VIM:SendTouchEvent(0, Vector2.new(0, 0), Enum.UserInputState.Begin)
            task.wait(0.02)
            VIM:SendTouchEvent(0, Vector2.new(0, 0), Enum.UserInputState.End)
        end)
    end
    task.spawn(SendFakeTouch)

    -- Alle 8 Sekunden wiederholen damit TouchEnabled true bleibt
    task.spawn(function()
        while true do
            task.wait(8)
            SendFakeTouch()
        end
    end)
end

-- ── BEIDE: RemoteEvent Scanner (Rivals + andere Spiele) ──
-- Rivals & viele andere Spiele senden beim Join eine Platform-Remote
local function SpoofMobilePlatform()
    task.wait(0.6)
    pcall(function()
        local roots = {
            game:GetService("ReplicatedStorage"),
            game:GetService("ReplicatedFirst"),
            workspace,
            game:GetService("Players"),
        }
        local fired = {}
        local function TryFire(rem)
            if fired[rem] then return end; fired[rem]=true
            for _,v in ipairs({"Mobile","Phone","Touch",Enum.Platform.IOS,Enum.Platform.Android,2,true,"mobile","touch"}) do
                pcall(function() rem:FireServer(v) end)
            end
        end
        local function TryInvoke(rem)
            if fired[rem] then return end; fired[rem]=true
            for _,v in ipairs({"Mobile","Touch",Enum.Platform.IOS}) do
                pcall(function() rem:InvokeServer(v) end)
            end
        end
        local kws = {"platform","device","mobile","touch","input","inputtype","clienttype","devicetype"}
        for _,root in ipairs(roots) do
            for _,v in ipairs(root:GetDescendants()) do
                local n = v.Name:lower()
                for _,kw in ipairs(kws) do
                    if n:find(kw) then
                        if v:IsA("RemoteEvent") then TryFire(v) end
                        if v:IsA("RemoteFunction") then TryInvoke(v) end
                        break
                    end
                end
            end
        end
    end)
    -- Nochmal nach 3s wenn Spiel vollständig geladen ist
    task.delay(3, function()
        pcall(function()
            for _,v in ipairs(game:GetDescendants()) do
                if v:IsA("RemoteEvent") then
                    local n=v.Name:lower()
                    if n:find("platform") or n:find("device") or n:find("inputtype") then
                        pcall(function() v:FireServer("Mobile") end)
                        pcall(function() v:FireServer(Enum.Platform.IOS) end)
                    end
                end
            end
        end)
    end)
end

task.spawn(SpoofMobilePlatform)
LP.CharacterAdded:Connect(SpoofMobilePlatform)



local LANG="EN"
local TXT={
    EN={unlock="UNLOCK",enterKey="Enter your key...",discord="Discord — Get Key",
    wrongKey="❌ Invalid key!",expiredKey="⌛ Key expired!",
    aimbot="Aimbot",hardLock="Hard Lock",autoShoot="Auto Shoot",
    silentAim="Silent Aim",teamCheck="Team Check",smoothing="Smoothing",
    aimTarget="Aim Targets",head="Head",upperTorso="Upper Torso",
    lowerTorso="Lower Torso",rightArm="Right Arm",leftArm="Left Arm",
    rightLeg="Right Leg",leftLeg="Left Leg",randomTarget="🎲 Random",
    combat="Combat",killAura="Kill Aura",auraRange="Aura Range",
    reach="Reach",reachSize="Reach Size",infAmmo="Infinite Ammo",
    headTP="Head TP",headTPHeight="Height above target",headTPBtn="⬆ TELEPORT TO HEAD",
    headTPAuto="Continuous (stay above target)",headTPKey="Head TP Key",
    player="Player",walkSpeed="Walk Speed",jumpPower="Jump Power",
    noclip="No Clip",infJump="Infinite Jump",antiAFK="Anti-AFK",
    spinBot="Spin Bot",spinSpeed="Spin Speed",
    teleport="Teleport",refresh="Refresh",noPlayers="No players",
    fly="Fly",flySpeed="Fly Speed",flyPC="WASD + Space/Shift",flyMob="On-screen pad",
    esp="ESP",playerNames="Names",healthBar="Health Bar",skeleton="Skeleton",
    tracers="Tracers",drawBox="Draw Box",maxDist="Max Distance",
    fovCircle="FOV Circle",fovSize="FOV Size",crosshair="Crosshair",
    world="World",gravity="Gravity",fullbright="Fullbright",fpsBoost="FPS Boost",
    misc="Misc",wallbang="Wallbang",blackMode="Black Mode",thirdPerson="Third Person",
    tpDist="Camera Distance",settings="Settings",toggleKey="Toggle Keys",
    addKey="+ Add Key",clearKeys="Reset to P",currentKeys="Active keys:",
    rebindHint="Click button, then press any key",
    owner="Owner",onlineAll="🟢 Currently Online",onlineFree="Free Users",
    onlineLifetime="Lifetime Users",onlineVIP="VIP Users",onlineDiscord="Discord Users",
    onlineOwner="Owner Users",
    manageKeys="Key Manager",addFreeKey="Free Key",addLifetimeKey="Lifetime Key",
    addDiscordKey="Discord Key",addVIPKey="VIP Key",addOwnerKey="Owner Key",
    keyInput="New key...",addKeyBtn="ADD",noUsers="No data yet",
    existingKeys="Custom Keys (persisted):",noCustomKeys="No custom keys added yet.",
    language="Language",online="ONLINE",offline="OFFLINE",
    selectPlatform="SELECT PLATFORM",pcDesc="Mouse & Keyboard",mobDesc="Touch Screen",
    fovHit="FOV Hit"},
    DE={unlock="FREISCHALTEN",enterKey="Key eingeben...",discord="Discord — Key holen",
    wrongKey="❌ Ungültiger Key!",expiredKey="⌛ Key abgelaufen!",
    aimbot="Aimbot",hardLock="Hard Lock",autoShoot="Auto Schießen",
    silentAim="Silent Aim",teamCheck="Team Check",smoothing="Genauigkeit",
    aimTarget="Ziel",head="Kopf",upperTorso="Oberkörper",
    lowerTorso="Unterkörper",rightArm="Rechter Arm",leftArm="Linker Arm",
    rightLeg="Rechtes Bein",leftLeg="Linkes Bein",randomTarget="🎲 Zufällig",
    combat="Kampf",killAura="Kill Aura",auraRange="Reichweite",
    reach="Reach",reachSize="Größe",infAmmo="Unendlich Munition",
    headTP="Head TP",headTPHeight="Höhe über Ziel",headTPBtn="⬆ ZUM KOPF TELEPORTIEREN",
    headTPAuto="Dauerhaft (über Kopf bleiben)",headTPKey="Head TP Taste",
    player="Spieler",walkSpeed="Laufgeschwindigkeit",jumpPower="Sprungkraft",
    noclip="Durch Wände",infJump="Unendlich Springen",antiAFK="Anti-AFK",
    spinBot="Spin Bot",spinSpeed="Spin Speed",
    teleport="Teleportieren",refresh="Aktualisieren",noPlayers="Keine Spieler",
    fly="Fliegen",flySpeed="Fluggeschwindigkeit",flyPC="WASD+Leertaste/Shift",flyMob="On-Screen Steuerung",
    esp="ESP",playerNames="Namen",healthBar="Lebensbalken",skeleton="Skelett",
    tracers="Tracer",drawBox="Box zeichnen",maxDist="Max Distanz",
    fovCircle="FOV Kreis",fovSize="FOV Größe",crosshair="Fadenkreuz",
    world="Welt",gravity="Schwerkraft",fullbright="Vollhell",fpsBoost="FPS Boost",
    misc="Sonstiges",wallbang="Wallbang",blackMode="Black Mode",thirdPerson="Third Person",
    tpDist="Kamera Abstand",settings="Einstellungen",toggleKey="Menu Tasten",
    addKey="+ Taste hinzufügen",clearKeys="Reset zu P",currentKeys="Aktuelle Tasten:",
    rebindHint="Klick dann Taste drücken",
    owner="Owner",onlineAll="🟢 Gerade Online",onlineFree="Free User",
    onlineLifetime="Lifetime User",onlineVIP="VIP User",onlineDiscord="Discord User",
    onlineOwner="Owner User",
    manageKeys="Key Manager",addFreeKey="Free Key",addLifetimeKey="Lifetime Key",
    addDiscordKey="Discord Key",addVIPKey="VIP Key",addOwnerKey="Owner Key",
    keyInput="Neuer Key...",addKeyBtn="HINZU",noUsers="Noch keine Daten",
    existingKeys="Custom Keys (gespeichert):",noCustomKeys="Noch keine Custom Keys.",
    language="Sprache",online="ONLINE",offline="OFFLINE",
    selectPlatform="PLATTFORM WÄHLEN",pcDesc="Maus & Tastatur",mobDesc="Touchscreen",
    fovHit="FOV Treffer"},
}
local function L(k) return (TXT[LANG] and TXT[LANG][k]) or (TXT.EN[k]) or k end

-- ══ SETTINGS ══
local S={
    ESP=SV.ESP or false,ESPNames=SV.ESPNames or false,HealthBar=SV.HealthBar or false,
    Skeleton=SV.Skeleton or false,Tracers=SV.Tracers or false,DrawBox=SV.DrawBox or false,
    MaxDist=SV.MaxDist or 500,
    Aimbot=SV.Aimbot or false,HardLock=SV.HardLock or false,
    Autoshoot=SV.Autoshoot or false,SilentAim=SV.SilentAim or false,
    Smoothing=SV.Smoothing or 10,TeamCheck=SV.TeamCheck or false,
    FOV=SV.FOV or 180,FOVOn=(SV.FOVOn~=false),
    AimTargets=SV.AimTargets or {Head=true},AimRandom=SV.AimRandom or false,
    FOVHit=SV.FOVHit or false,
    WalkSpeed=SV.WalkSpeed or 16,JumpPower=SV.JumpPower or 50,
    NoClip=SV.NoClip or false,InfJump=SV.InfJump or false,
    Fly=false,FlySpeed=SV.FlySpeed or 60,
    AntiAFK=SV.AntiAFK or false,SpinBot=SV.SpinBot or false,SpinSpeed=SV.SpinSpeed or 10,
    KillAura=SV.KillAura or false,KillAuraRange=SV.KillAuraRange or 15,
    Reach=SV.Reach or false,ReachSize=SV.ReachSize or 10,
    Gravity=SV.Gravity or 196,Fullbright=SV.Fullbright or false,FPSBoost=SV.FPSBoost or false,
    Crosshair=SV.Crosshair or false,
    BlackMode=SV.BlackMode or false,ThirdPerson=SV.ThirdPerson or false,
    ThirdPersonDist=SV.ThirdPersonDist or 15,
    ToggleKeys=SV.ToggleKeys or {"P"},
    HeadTPKey=SV.HeadTPKey or "H",
    HeadTPHeight=SV.HeadTPHeight or 5,
    _smoothSky=SV._smoothSky or false,
    AccentRGB=SV.AccentRGB or nil,
    ESPEnemyColor=SV.ESPEnemyColor or nil,
    Key=SV.Key or nil,KeyType=SV.KeyType or nil,KeyActivated=SV.KeyActivated or nil,
    Platform=SV.Platform or nil,Lang=SV.Lang or "EN",
    Unlocked=false,IsOwner=false,
}
LANG=S.Lang or "EN"

local function Save()
    WriteJ(SF,{
        ESP=S.ESP,ESPNames=S.ESPNames,HealthBar=S.HealthBar,Skeleton=S.Skeleton,
        Tracers=S.Tracers,DrawBox=S.DrawBox,MaxDist=S.MaxDist,
        Aimbot=S.Aimbot,HardLock=S.HardLock,Autoshoot=S.Autoshoot,SilentAim=S.SilentAim,
        Smoothing=S.Smoothing,TeamCheck=S.TeamCheck,FOV=S.FOV,FOVOn=S.FOVOn,
        AimTargets=S.AimTargets,AimRandom=S.AimRandom,FOVHit=S.FOVHit,
        WalkSpeed=S.WalkSpeed,JumpPower=S.JumpPower,NoClip=S.NoClip,InfJump=S.InfJump,
        FlySpeed=S.FlySpeed,AntiAFK=S.AntiAFK,SpinBot=S.SpinBot,SpinSpeed=S.SpinSpeed,
        KillAura=S.KillAura,KillAuraRange=S.KillAuraRange,Reach=S.Reach,ReachSize=S.ReachSize,
        AccentRGB=S.AccentRGB,ESPEnemyColor=S.ESPEnemyColor,_smoothSky=S._smoothSky,
        InfAmmo=false,Gravity=S.Gravity,Fullbright=S.Fullbright,FPSBoost=S.FPSBoost,
        Wallbang=false,Crosshair=S.Crosshair,BlackMode=S.BlackMode,
        ThirdPerson=S.ThirdPerson,ThirdPersonDist=S.ThirdPersonDist,
        ToggleKeys=S.ToggleKeys,HeadTPKey=S.HeadTPKey,HeadTPHeight=S.HeadTPHeight,
        Key=S.Key,KeyType=S.KeyType,KeyActivated=S.KeyActivated,Platform=S.Platform,Lang=S.Lang,
    })
end

-- ══ KEY SYSTEM ══
local _LT=function(_) return false end
local OWNER_KEY="Lele2026"
local VIP_KEYS={["LeleStaff2026"]=true,["Lu1s2026"]=true}
local DISCORD_KEYS={["FREE_discord"]=true}
local FREE_KEYS={
    ["FREE_2026_1847"]=true,["FREE_2026_2593"]=true,["FREE_2026_3741"]=true,
    ["FREE_2026_4028"]=true,["FREE_2026_5316"]=true,["FREE_2026_6894"]=true,
    ["FREE_2026_7253"]=true,["FREE_2026_8619"]=true,["FREE_2026_9047"]=true,
    ["FREE_2026_0382"]=true,
}
local FREE_DUR=86400
local function HMS(s)
    s=math.max(0,math.floor(s))
    return string.format("%02dh %02dm %02ds",math.floor(s/3600),math.floor(s/60)%60,s%60)
end

local function ValidateKey(key)
    if not key or #key==0 then return "invalid" end
    if key==OWNER_KEY then return "owner" end
    -- Always reload custom keys so owner-added keys work immediately
    CUSTOM_KEYS=ReadJ(CKF)
    if CUSTOM_KEYS[key] then
        local ct=CUSTOM_KEYS[key].type
        if ct=="owner" then return "owner" end
        if ct=="vip" then return "vip" end
        if ct=="discord" then return "discord" end
        if ct=="lifetime" then return "lifetime" end
        if ct=="free" then
            local stored=KUSED[key]
            if stored then
                local rem=FREE_DUR-(os.time()-(stored.at or 0))
                if rem<=0 then return "expired" end
                return "free_active",rem
            end
            return "free_new",FREE_DUR
        end
    end
    if VIP_KEYS[key] then return "vip" end
    if DISCORD_KEYS[key] then return "discord" end
    local stored=KUSED[key]
    if stored then
        if stored.type=="lifetime" then return "lifetime" end
        if stored.type=="free" then
            local rem=FREE_DUR-(os.time()-(stored.at or 0))
            if rem<=0 then return "expired" end
            return "free_active",rem
        end
    end
    if FREE_KEYS[key] then return "free_new",FREE_DUR end
    if _LT(key) then return "lifetime" end
    return "invalid"
end

local function CommitKey(key,ktype)
    if ktype=="free_new" or ktype=="free_active" then
        if not KUSED[key] then KUSED[key]={type="free",at=os.time()}; WriteJ(KF,KUSED) end
        S.KeyActivated=KUSED[key].at
    elseif ktype=="lifetime" then
        if not KUSED[key] then KUSED[key]={type="lifetime",at=os.time()}; WriteJ(KF,KUSED) end
    end
    S.Key=key; S.KeyType=ktype; S.IsOwner=(ktype=="owner"); Save()
end

local function RecordSession()
    local sess=ReadJ(OF)
    local kt=S.KeyType or "?"
    -- Normalize free variants to "free" for owner panel filtering
    if kt=="free_new" or kt=="free_active" then kt="free" end
    sess[tostring(LP.UserId)]={
        name=LP.Name,display=LP.DisplayName or LP.Name,
        keyType=kt,timestamp=os.time()
    }
    WriteJ(OF,sess)
end

-- ══ THEME ══
local T={
    BG=Color3.fromRGB(8,8,14),BG2=Color3.fromRGB(11,11,20),BG3=Color3.fromRGB(16,16,28),
    Side=Color3.fromRGB(10,10,18),Panel=Color3.fromRGB(13,13,23),
    Card=Color3.fromRGB(18,18,30),CardHdr=Color3.fromRGB(14,14,26),
    Blue=Color3.fromRGB(80,120,255),BlueBr=Color3.fromRGB(130,165,255),
    BlueDim=Color3.fromRGB(40,60,140),BDark=Color3.fromRGB(20,25,60),
    Accent=Color3.fromRGB(110,148,255),
    Text=Color3.fromRGB(220,225,245),Dim=Color3.fromRGB(90,95,130),Off=Color3.fromRGB(28,28,46),
    Green=Color3.fromRGB(50,220,110),Red=Color3.fromRGB(220,60,80),
    Yellow=Color3.fromRGB(255,200,60),Orange=Color3.fromRGB(255,150,50),
    White=Color3.fromRGB(255,255,255),Purple=Color3.fromRGB(155,85,255),
    Owner=Color3.fromRGB(255,185,0),Discord=Color3.fromRGB(88,101,242),
    Line=Color3.fromRGB(32,32,54),BtnBG=Color3.fromRGB(22,28,65),
}

-- ══ SCREENGUI (anti-detection: random name, protected) ══
local _guiName=tostring(math.random(100000,999999)).."_ui"
local SG=Instance.new("ScreenGui")
SG.Name=_guiName
SG.ResetOnSpawn=false
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset=true
-- Try protected GUI parents to hide from game scripts
local _guiSet=false
pcall(function() if syn and syn.protect_gui then syn.protect_gui(SG) end end)
pcall(function() if protect_gui then protect_gui(SG) end end)
pcall(function() if gethui then SG.Parent=gethui(); _guiSet=true end end)
if not _guiSet then
    pcall(function() SG.Parent=game:GetService("CoreGui"); _guiSet=true end)
end
if not _guiSet then SG.Parent=LP.PlayerGui end

-- ══ BLUR ══
local leleBlur; pcall(function()
    for _,v in ipairs(Lighting:GetChildren()) do if v.Name=="_blur_fx" then v:Destroy() end end
    leleBlur=Instance.new("BlurEffect"); leleBlur.Name="_blur_fx"; leleBlur.Size=0; leleBlur.Parent=Lighting
end)
local function SetBlur(on)
    pcall(function()
        if not leleBlur then return end
        TweenService:Create(leleBlur,TweenInfo.new(0.35),{Size=on and 24 or 0}):Play()
    end)
end

-- ══ DRAWINGS (created after AC so color is correct) ══
local DFov,DCrossH,DCrossV

-- ══ UI HELPERS ══
local function Round(f,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 8); c.Parent=f; return c end
local function Stroke(f,col,t,tr) local s=Instance.new("UIStroke"); s.Color=col; s.Thickness=t or 1; if tr then s.Transparency=tr end; s.Parent=f; return s end
local function Grad(f,c0,c1,rot) local g=Instance.new("UIGradient"); g.Color=ColorSequence.new(c0,c1); g.Rotation=rot or 90; g.Parent=f end
local function Frame(p) local f=Instance.new("Frame"); f.BorderSizePixel=0; for k,v in pairs(p) do pcall(function() f[k]=v end) end; return f end
local function Label(p) local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; for k,v in pairs(p) do pcall(function() l[k]=v end) end; return l end
local function Button(p) local b=Instance.new("TextButton"); b.BorderSizePixel=0; for k,v in pairs(p) do pcall(function() b[k]=v end) end; return b end
local function TBox(p) local b=Instance.new("TextBox"); b.BorderSizePixel=0; for k,v in pairs(p) do pcall(function() b[k]=v end) end; return b end
local function List(f,gap,dir) local l=Instance.new("UIListLayout"); l.SortOrder=Enum.SortOrder.LayoutOrder; l.Padding=UDim.new(0,gap or 0); if dir then l.FillDirection=dir end; l.Parent=f; return l end
local function Pad(f,l,r,t,b) local p=Instance.new("UIPadding"); p.PaddingLeft=UDim.new(0,l or 0); p.PaddingRight=UDim.new(0,r or 0); p.PaddingTop=UDim.new(0,t or 0); p.PaddingBottom=UDim.new(0,b or 0); p.Parent=f end
local function Spc(p,h) Frame({Size=UDim2.new(1,0,0,h or 4),BackgroundTransparency=1,Parent=p}) end
local function Sep(p) Frame({Size=UDim2.new(1,-14,0,1),Position=UDim2.new(0,7,0,0),BackgroundColor3=T.Line,Parent=p}) end
local function Scroll(props) local s=Instance.new("ScrollingFrame"); s.BorderSizePixel=0; s.CanvasSize=UDim2.new(0,0,0,0); s.AutomaticCanvasSize=Enum.AutomaticSize.Y; for k,v in pairs(props) do pcall(function() s[k]=v end) end; return s end
local function Info(parent,txt) local row=Frame({Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=parent}); Label({Text=txt,Size=UDim2.new(1,-24,0,0),AutomaticSize=Enum.AutomaticSize.Y,Position=UDim2.new(0,12,0,5),TextColor3=T.Dim,TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,Parent=row}); Spc(row,4) end

-- ══ LOGO TEXT ══
local function LogoText(parent,h,zi)
    h=h or 60
    local f=Frame({Size=UDim2.new(1,0,0,h),BackgroundTransparency=1,Parent=parent,ZIndex=zi or 1})
    Label({Text="Lele HUB",Size=UDim2.new(1,0,0,math.floor(h*0.62)),Position=UDim2.new(0,0,0,math.floor(h*0.04)),TextColor3=T.BlueBr,TextSize=math.floor(h*0.40),Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Center,TextStrokeTransparency=0.4,TextStrokeColor3=T.Blue,ZIndex=(zi or 1)+1,Parent=f})
    Label({Text=VER,Size=UDim2.new(1,0,0,math.floor(h*0.28)),Position=UDim2.new(0,0,1,-math.floor(h*0.30)),TextColor3=T.BlueDim,TextSize=math.floor(h*0.18),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=(zi or 1)+1,Parent=f})
    local gl=Frame({Size=UDim2.new(0.45,0,0,2),AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,0),BackgroundColor3=T.Blue,BackgroundTransparency=0.3,ZIndex=(zi or 1)+1,Parent=f}); Round(gl,99); Grad(gl,T.BDark,T.BlueBr,0)
    return f
end

-- Sidebar icon buttons (−  ✕  +)
local function SideIconBtn(parent,txt,col,xAnchor,xOff,yOff,zi)
    local f=Frame({Size=UDim2.new(0,28,0,28),AnchorPoint=Vector2.new(xAnchor,0),Position=UDim2.new(xAnchor,xOff,0,yOff),BackgroundColor3=T.BtnBG,ZIndex=zi or 12,Parent=parent}); Round(f,8); Stroke(f,col,1,0.35)
    local lbl=Label({Text=txt,Size=UDim2.new(1,0,1,0),TextColor3=col,TextSize=15,Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=(zi or 12)+1,Parent=f})
    local hit=Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=(zi or 12)+2,Parent=f})
    hit.MouseEnter:Connect(function() TweenService:Create(f,TweenInfo.new(0.13),{BackgroundColor3=col}):Play(); lbl.TextColor3=T.BG end)
    hit.MouseLeave:Connect(function() TweenService:Create(f,TweenInfo.new(0.13),{BackgroundColor3=T.BtnBG}):Play(); lbl.TextColor3=col end)
    return hit,f
end

-- ══ BLACK MODE ══
local BlackOverlay=Frame({Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,ZIndex=300,Visible=false,Parent=SG})
local function ApplyBlackMode(on)
    S.BlackMode=on; Save()
    if on then
        BlackOverlay.Visible=true
        TweenService:Create(BlackOverlay,TweenInfo.new(0.4),{BackgroundTransparency=0.12}):Play()
        Lighting.Brightness=0; Lighting.ClockTime=0; Lighting.GlobalShadows=true
        Lighting.Ambient=Color3.fromRGB(0,0,0); Lighting.OutdoorAmbient=Color3.fromRGB(0,0,0)
    else
        TweenService:Create(BlackOverlay,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play()
        task.delay(0.35,function() BlackOverlay.Visible=false end)
        Lighting.Brightness=1; Lighting.GlobalShadows=true
        Lighting.Ambient=Color3.fromRGB(127,127,127); Lighting.OutdoorAmbient=Color3.fromRGB(127,127,127)
    end
end

-- ══ THIRD PERSON ══
local function ApplyThirdPerson(on,dist)
    dist=dist or S.ThirdPersonDist
    if on then
        pcall(function() LP.CameraMaxZoomDistance=dist end)
        pcall(function() LP.CameraMinZoomDistance=dist end)
    else
        pcall(function() LP.CameraMaxZoomDistance=400 end)
        pcall(function() LP.CameraMinZoomDistance=0.5 end)
    end
end

-- ══ TOAST ══
local toastQ={}; local toastBusy=false
local function Toast(msg,col,dur)
    table.insert(toastQ,{msg=msg,col=col or T.BlueBr,dur=dur or 2.5})
    if toastBusy then return end; toastBusy=true
    local function Next()
        if #toastQ==0 then toastBusy=false; return end
        local t=table.remove(toastQ,1)
        local tf=Frame({Size=UDim2.new(0,300,0,40),AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,-56),BackgroundColor3=T.BG3,ZIndex=500,Parent=SG})
        Round(tf,12); Stroke(tf,t.col,1,0.3); Grad(tf,T.BG2,T.BG3,90)
        Frame({Size=UDim2.new(0,3,0.55,0),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),BackgroundColor3=t.col,ZIndex=501,Parent=tf}); Round(tf:FindFirstChildOfClass("Frame"),99)
        Label({Text=t.msg,Size=UDim2.new(1,-16,1,0),Position=UDim2.new(0,10,0,0),TextColor3=T.Text,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=501,Parent=tf})
        TweenService:Create(tf,TweenInfo.new(0.38,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,0,0,10)}):Play()
        task.delay(t.dur,function()
            TweenService:Create(tf,TweenInfo.new(0.26),{Position=UDim2.new(0.5,0,0,-56)}):Play()
            task.wait(0.28); pcall(function() tf:Destroy() end); Next()
        end)
    end; Next()
end

-- ══ FLY MOBILE PAD ══
local flyState={f=false,b=false,l=false,r=false,u=false,d=false}
local MFly=Frame({Size=UDim2.new(0,0,0,0),BackgroundTransparency=1,Visible=false,ZIndex=90,Parent=SG})
local function BuildFlyMobile(mobile)
    for _,c in ipairs(MFly:GetChildren()) do c:Destroy() end
    if not mobile then return end
    local dp=Frame({Size=UDim2.new(0,150,0,150),Position=UDim2.new(0,12,1,-178),BackgroundColor3=T.BG3,BackgroundTransparency=0.18,ZIndex=91,Parent=MFly}); Round(dp,75); Stroke(dp,T.BlueDim,1,0.5)
    local function DBtn(icon,xp,key) local b=Button({Size=UDim2.new(0,46,0,46),Position=xp,BackgroundColor3=T.BDark,Text=icon,TextColor3=T.BlueBr,TextSize=18,Font=Enum.Font.GothamBold,ZIndex=92,Parent=dp}); Round(b,12); b.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then flyState[key]=true end end); b.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then flyState[key]=false end end) end
    DBtn("▲",UDim2.new(0.5,-23,0,6),"f"); DBtn("▼",UDim2.new(0.5,-23,1,-52),"b"); DBtn("◀",UDim2.new(0,6,0.5,-23),"l"); DBtn("▶",UDim2.new(1,-52,0.5,-23),"r")
    local ap=Frame({Size=UDim2.new(0,52,0,110),Position=UDim2.new(1,-70,1,-136),BackgroundColor3=T.BG3,BackgroundTransparency=0.18,ZIndex=91,Parent=MFly}); Round(ap,12); Stroke(ap,T.BlueDim,1,0.5)
    local function ABtn(icon,yp,key) local b=Button({Size=UDim2.new(1,-8,0,48),Position=UDim2.new(0,4,0,yp),BackgroundColor3=T.BDark,Text=icon,TextColor3=T.BlueBr,TextSize=20,Font=Enum.Font.GothamBold,ZIndex=92,Parent=ap}); Round(b,10); b.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then flyState[key]=true end end); b.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then flyState[key]=false end end) end
    ABtn("▲",4,"u"); ABtn("▼",58,"d")
end

local function EnableFly(on)
    S.Fly=on
    pcall(function()
        local char=LP.Character; if not char then return end
        local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local hum=char:FindFirstChildOfClass("Humanoid")
        -- Clean up any leftover movers from previous sessions
        for _,n in ipairs({"_bv","_bg"}) do
            local v=hrp:FindFirstChild(n); if v then v:Destroy() end
        end
        if on then
            -- NO BodyVelocity, NO BodyGyro, NO PlatformStand
            -- Use Humanoid state override instead — less detectable
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Physics)
            end
        else
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end)
    if not on then for k in pairs(flyState) do flyState[k]=false end end
end

LP.CharacterAdded:Connect(function(char)
    local wasFlying=S.Fly
    for k in pairs(flyState) do flyState[k]=false end
    task.wait(0.35)
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    hum.WalkSpeed=S.WalkSpeed; hum.JumpPower=S.JumpPower
    if S.ThirdPerson then ApplyThirdPerson(true,S.ThirdPersonDist) end
    if wasFlying then
        task.wait(0.2)
        EnableFly(true)
        if MFly then MFly.Visible=isMob end
    else
        S.Fly=false
        if MFly then MFly.Visible=false end
    end
end)

-- (Wallbang removed)

-- ══ HEAD TP VARS ══
local headTPContinuous=false
local headTPLockedTarget=nil  -- locked onto specific enemy until they die

-- Continuous Head TP loop — locks onto nearest enemy, stays until THEY are dead
task.spawn(function()
    while true do
        task.wait(0.1)
        if not S.Unlocked or not headTPContinuous then
            headTPLockedTarget=nil; continue
        end
        pcall(function()
            local myChar=LP.Character; if not myChar then return end
            local myHum=myChar:FindFirstChildOfClass("Humanoid")
            if not myHum or myHum.Health<=0 then
                headTPContinuous=false; headTPLockedTarget=nil; return
            end
            local myHRP=myChar:FindFirstChild("HumanoidRootPart"); if not myHRP then return end

            -- Check if locked target is still alive
            if headTPLockedTarget then
                local lc=headTPLockedTarget.Character
                local lh=lc and lc:FindFirstChildOfClass("Humanoid")
                local lp=lc and lc:FindFirstChild("HumanoidRootPart")
                if not lc or not lh or lh.Health<=0 or not lp then
                    headTPLockedTarget=nil  -- target died, find new one
                else
                    -- Stay above locked target
                    myHRP.CFrame=CFrame.new(lp.Position+Vector3.new(0,S.HeadTPHeight,0),lp.Position)
                    return
                end
            end

            -- Find nearest living enemy to lock onto
            local best,bestDist=nil,math.huge
            for _,p in ipairs(Players:GetPlayers()) do
                if p==LP then continue end
                local pc=p.Character; if not pc then continue end
                local ph=pc:FindFirstChild("HumanoidRootPart"); if not ph then continue end
                local hum=pc:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then continue end
                local dist=(myHRP.Position-ph.Position).Magnitude
                if dist<bestDist then bestDist=dist; best=p end
            end
            if best then
                headTPLockedTarget=best  -- lock onto this enemy
                local lp=best.Character and best.Character:FindFirstChild("HumanoidRootPart")
                if lp then myHRP.CFrame=CFrame.new(lp.Position+Vector3.new(0,S.HeadTPHeight,0),lp.Position) end
            end
        end)
    end
end)

-- ══ KEY SCREEN (arcane-style — matches main menu design) ══
local KeyBG=Frame({Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.fromRGB(6,8,14),BackgroundTransparency=0.45,ZIndex=200,Parent=SG})
SetBlur(true)

-- Same panel style as main menu
local KBox=Frame({
    Size=UDim2.new(0,460,0,480),AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=Color3.fromRGB(14,14,18),ZIndex=201,Parent=KeyBG
}); Round(KBox,12)
Instance.new("UIStroke",KBox).Color=Color3.fromRGB(35,35,45)
KBox:FindFirstChildOfClass("UIStroke").Thickness=1

-- Left accent bar (same as main menu header)
Frame({Size=UDim2.new(0,3,0.9,0),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),BackgroundColor3=Color3.fromRGB(80,140,255),ZIndex=202,Parent=KBox})

-- Header row (same style as main menu header)
local KHdr=Frame({Size=UDim2.new(1,0,0,64),BackgroundColor3=Color3.fromRGB(14,14,19),ZIndex=202,Parent=KBox}); Round(KHdr,12)
Frame({Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Color3.fromRGB(30,30,42),ZIndex=202,Parent=KHdr})
-- Icon box
local kIconBox=Frame({Size=UDim2.new(0,36,0,36),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,16,0.5,0),BackgroundColor3=Color3.fromRGB(22,22,32),ZIndex=203,Parent=KHdr}); Round(kIconBox,10)
Label({Text="🔑",Size=UDim2.new(1,0,1,0),TextSize=16,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=204,Parent=kIconBox})
Label({Text="lele hub",Size=UDim2.new(0.6,0,0,20),Position=UDim2.new(0,60,0,12),TextColor3=Color3.fromRGB(235,237,255),TextSize=15,Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=203,Parent=KHdr})
Label({Text="Enter your access key to continue",Size=UDim2.new(0.8,0,0,14),Position=UDim2.new(0,60,0,34),TextColor3=Color3.fromRGB(70,72,95),TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=203,Parent=KHdr})

-- Content area
local KContent=Frame({Size=UDim2.new(1,-32,1,-80),Position=UDim2.new(0,16,0,72),BackgroundTransparency=1,ZIndex=202,Parent=KBox})
List(KContent,10)

-- Discord row (same card style)
local discordCard=Frame({Size=UDim2.new(1,0,0,44),BackgroundColor3=Color3.fromRGB(88,101,242),ZIndex=202,Parent=KContent}); Round(discordCard,10)
local DscBtn=Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="💬  discord.gg/7KfMUGQQB9",TextColor3=Color3.fromRGB(255,255,255),TextSize=11,Font=Enum.Font.GothamBold,ZIndex=203,Parent=discordCard})
DscBtn.MouseButton1Click:Connect(function() pcall(function() if setclipboard then setclipboard("https://discord.gg/7KfMUGQQB9") end end); Toast("✅ Copied!",T.Green) end)
discordCard.MouseEnter:Connect(function() TweenService:Create(discordCard,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(108,121,255)}):Play() end)
discordCard.MouseLeave:Connect(function() TweenService:Create(discordCard,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(88,101,242)}):Play() end)

-- Language row (same row-group style)
local langGroup=Frame({Size=UDim2.new(1,0,0,44),BackgroundColor3=Color3.fromRGB(20,20,27),ZIndex=202,Parent=KContent}); Round(langGroup,10)
Label({Text="Language",Size=UDim2.new(0.5,0,1,0),Position=UDim2.new(0,16,0,0),TextColor3=Color3.fromRGB(165,167,195),TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=203,Parent=langGroup})
local ENBtn,DEBtn
local langBtnArea=Frame({Size=UDim2.new(0,120,0,28),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),BackgroundTransparency=1,ZIndex=203,Parent=langGroup})
local function RefreshLang()
    if ENBtn then
        ENBtn.BackgroundColor3=LANG=="EN" and Color3.fromRGB(80,140,255) or Color3.fromRGB(28,28,40)
        ENBtn.TextColor3=LANG=="EN" and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,102,128)
    end
    if DEBtn then
        DEBtn.BackgroundColor3=LANG=="DE" and Color3.fromRGB(80,140,255) or Color3.fromRGB(28,28,40)
        DEBtn.TextColor3=LANG=="DE" and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,102,128)
    end
end
ENBtn=Button({Size=UDim2.new(0,54,0,26),Position=UDim2.new(0,0,0.5,-13),BackgroundColor3=Color3.fromRGB(80,140,255),Text="🇬🇧 EN",TextColor3=Color3.fromRGB(255,255,255),TextSize=10,Font=Enum.Font.GothamBold,ZIndex=204,Parent=langBtnArea}); Round(ENBtn,7)
DEBtn=Button({Size=UDim2.new(0,54,0,26),Position=UDim2.new(1,-54,0.5,-13),BackgroundColor3=Color3.fromRGB(28,28,40),Text="🇩🇪 DE",TextColor3=Color3.fromRGB(100,102,128),TextSize=10,Font=Enum.Font.GothamBold,ZIndex=204,Parent=langBtnArea}); Round(DEBtn,7)
ENBtn.MouseButton1Click:Connect(function() LANG="EN"; S.Lang="EN"; Save(); RefreshLang() end)
DEBtn.MouseButton1Click:Connect(function() LANG="DE"; S.Lang="DE"; Save(); RefreshLang() end)
RefreshLang()

-- Key input (same card row style)
Label({Text="ACCESS KEY",Size=UDim2.new(1,0,0,16),BackgroundTransparency=1,TextColor3=Color3.fromRGB(55,57,78),TextSize=9,Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=202,Parent=KContent})
local KInputGroup=Frame({Size=UDim2.new(1,0,0,50),BackgroundColor3=Color3.fromRGB(20,20,27),ZIndex=202,Parent=KContent}); Round(KInputGroup,10)
local kStroke=Instance.new("UIStroke",KInputGroup); kStroke.Color=Color3.fromRGB(35,35,45); kStroke.Thickness=1
local KReal=TBox({Size=UDim2.new(1,-16,1,0),Position=UDim2.new(0,12,0,0),BackgroundTransparency=1,Text="",PlaceholderText="",TextColor3=Color3.fromRGB(1,1,1),TextTransparency=0.999,TextSize=14,Font=Enum.Font.GothamBold,ClearTextOnFocus=false,MultiLine=false,ZIndex=205,Parent=KInputGroup})
local KHint=Label({Text=L("enterKey"),Size=UDim2.new(1,-16,1,0),Position=UDim2.new(0,14,0,0),TextColor3=Color3.fromRGB(55,57,78),TextSize=12,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=203,Parent=KInputGroup})
local KDots=Label({Text="",Size=UDim2.new(1,-16,1,0),Position=UDim2.new(0,12,0,0),TextColor3=Color3.fromRGB(200,210,255),TextSize=18,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=203,Parent=KInputGroup})

local realKey=""
KReal:GetPropertyChangedSignal("Text"):Connect(function()
    realKey=KReal.Text
    KDots.Text=string.rep("●",#realKey)
    KHint.Visible=(#realKey==0)
    kStroke.Color=#realKey>0 and Color3.fromRGB(80,140,255) or Color3.fromRGB(35,35,45)
end)
KReal.Focused:Connect(function() KHint.Visible=false; kStroke.Color=Color3.fromRGB(80,140,255) end)
KReal.FocusLost:Connect(function() if #realKey==0 then KHint.Visible=true; kStroke.Color=Color3.fromRGB(35,35,45) end end)
KInputGroup.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        KReal:CaptureFocus()
    end
end)
local function ClearKeyInput() realKey=""; KReal.Text=""; KDots.Text=""; KHint.Visible=true; kStroke.Color=Color3.fromRGB(35,35,45) end

-- Unlock button (same style as head TP button in main menu)
local KSubCard=Frame({Size=UDim2.new(1,0,0,46),BackgroundColor3=Color3.fromRGB(80,140,255),ZIndex=202,Parent=KContent}); Round(KSubCard,10)
local KSub=Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="⚡  UNLOCK",TextColor3=Color3.fromRGB(255,255,255),TextSize=13,Font=Enum.Font.GothamBlack,ZIndex=203,Parent=KSubCard})
KSubCard.MouseEnter:Connect(function() TweenService:Create(KSubCard,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(110,165,255)}):Play() end)
KSubCard.MouseLeave:Connect(function() TweenService:Create(KSubCard,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(80,140,255)}):Play() end)

local KStatus=Label({Text="",Size=UDim2.new(1,0,0,24),BackgroundTransparency=1,TextColor3=T.Red,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=202,Parent=KContent})

-- ══ PLATFORM SCREEN (arcane-style) ══
local PlatBG=Frame({Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.fromRGB(10,10,14),BackgroundTransparency=0,ZIndex=190,Visible=false,Parent=SG})
local PBox=Frame({Size=UDim2.new(0,460,0,300),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=Color3.fromRGB(14,14,18),ZIndex=191,Parent=PlatBG}); Round(PBox,12)
Instance.new("UIStroke",PBox).Color=Color3.fromRGB(35,35,45)
-- Platform header
local pHdr=Frame({Size=UDim2.new(1,0,0,64),BackgroundColor3=Color3.fromRGB(14,14,19),ZIndex=192,Parent=PBox}); Round(pHdr,12)
Frame({Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Color3.fromRGB(30,30,42),ZIndex=192,Parent=pHdr})
local pIconBox=Frame({Size=UDim2.new(0,36,0,36),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,16,0.5,0),BackgroundColor3=Color3.fromRGB(22,22,32),ZIndex=193,Parent=pHdr}); Round(pIconBox,10)
Label({Text="💻",Size=UDim2.new(1,0,1,0),TextSize=16,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=194,Parent=pIconBox})
Label({Text="lele hub",Size=UDim2.new(0.6,0,0,20),Position=UDim2.new(0,60,0,12),TextColor3=Color3.fromRGB(235,237,255),TextSize=15,Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=193,Parent=pHdr})
Label({Text=L("selectPlatform"),Size=UDim2.new(0.8,0,0,14),Position=UDim2.new(0,60,0,34),TextColor3=Color3.fromRGB(70,72,95),TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=193,Parent=pHdr})

local function MPBtn(icon,lbl,sub,isLeft)
    local xp=isLeft and UDim2.new(0,16,0,80) or UDim2.new(0.5,8,0,80)
    local f=Frame({Size=UDim2.new(0.5,-24,0,100),Position=xp,BackgroundColor3=Color3.fromRGB(20,20,27),ZIndex=192,Parent=PBox}); Round(f,10)
    Instance.new("UIStroke",f).Color=Color3.fromRGB(35,35,45)
    Label({Text=icon,Size=UDim2.new(1,0,0,44),Position=UDim2.new(0,0,0,8),TextColor3=Color3.fromRGB(80,140,255),TextSize=26,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=193,Parent=f})
    Label({Text=lbl,Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,0,52),TextColor3=Color3.fromRGB(220,222,245),TextSize=12,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=193,Parent=f})
    Label({Text=sub,Size=UDim2.new(1,0,0,13),Position=UDim2.new(0,0,0,68),TextColor3=Color3.fromRGB(70,72,95),TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=193,Parent=f})
    local hit=Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=194,Parent=f})
    hit.MouseEnter:Connect(function() TweenService:Create(f,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(24,24,34)}):Play(); f:FindFirstChildOfClass("UIStroke").Color=Color3.fromRGB(80,140,255) end)
    hit.MouseLeave:Connect(function() TweenService:Create(f,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(20,20,27)}):Play(); f:FindFirstChildOfClass("UIStroke").Color=Color3.fromRGB(35,35,45) end)
    return hit
end
local PCBtn=MPBtn("🖥","PC",L("pcDesc"),true)
local MobBtn=MPBtn("📱","Mobile",L("mobDesc"),false)

-- ══ MAIN MENU ══
local MainFrame; local isMob=false; local GetAimPartFn=nil
local menuTW=980; local menuTH=560

-- ── Accent color system ──
-- AC = current accent, changeable in settings
local AC=Color3.fromRGB(80,140,255)
if S.AccentRGB then
    pcall(function() AC=Color3.fromRGB(S.AccentRGB.r,S.AccentRGB.g,S.AccentRGB.b) end)
end
-- Now create Drawings with correct AC color
DFov=Drawing.new("Circle"); DFov.Color=AC; DFov.Thickness=1.5; DFov.NumSides=128; DFov.Filled=false; DFov.Radius=S.FOV; DFov.Visible=false; DFov.ZIndex=5
DCrossH=Drawing.new("Line"); DCrossH.Color=AC; DCrossH.Thickness=1.2; DCrossH.Visible=false; DCrossH.ZIndex=5
DCrossV=Drawing.new("Line"); DCrossV.Color=AC; DCrossV.Thickness=1.2; DCrossV.Visible=false; DCrossV.ZIndex=5
local function SetAccent(col)
    AC=col; S.AccentRGB={r=col.R*255,g=col.G*255,b=col.B*255}; Save()
    pcall(function() DFov.Color=col; DCrossH.Color=col; DCrossV.Color=col end)
end

local function BuildMenu(mobile)
    isMob=mobile
    if MainFrame then MainFrame:Destroy() end
    BuildFlyMobile(mobile)

    local SW=mobile and 130 or 150
    menuTW=mobile and 400 or 980; menuTH=mobile and 580 or 560

    -- ── OUTER FRAME ──
    MainFrame=Frame({
        Size=UDim2.new(0,menuTW,0,menuTH),
        Position=UDim2.new(0.5,-menuTW/2,1.5,0),
        BackgroundColor3=Color3.fromRGB(14,14,18),
        Active=true,Parent=SG
    })
    Round(MainFrame,12)
    Instance.new("UIStroke",MainFrame).Color=Color3.fromRGB(35,35,45)
    MainFrame:FindFirstChildOfClass("UIStroke").Thickness=1

    -- Entrance anim
    TweenService:Create(MainFrame,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
        {Position=UDim2.new(0.5,-menuTW/2,0.5,-menuTH/2)}):Play()

    -- ── CUSTOM DRAG ──
    local _dragActive=false; local _dragStart; local _frameStart
    local DragZone=Frame({Size=UDim2.new(1,0,0,42),BackgroundTransparency=1,ZIndex=8,Active=true,Parent=MainFrame})
    DragZone.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            _dragActive=true; _dragStart=i.Position; _frameStart=MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not _dragActive then return end
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            local d=i.Position-_dragStart
            MainFrame.Position=UDim2.new(_frameStart.X.Scale,_frameStart.X.Offset+d.X,_frameStart.Y.Scale,_frameStart.Y.Offset+d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then _dragActive=false end
    end)

    -- ── LEFT SIDEBAR ──
    local SB=Frame({Size=UDim2.new(0,SW,1,0),BackgroundColor3=Color3.fromRGB(10,10,14),Parent=MainFrame})
    Round(SB,12)
    Frame({Size=UDim2.new(0,1,1,0),AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,0),BackgroundColor3=Color3.fromRGB(30,30,40),Parent=SB})

    -- Logo
    local LogoRow=Frame({Size=UDim2.new(1,0,0,52),BackgroundTransparency=1,Parent=SB})
    local logoLbl=Label({Text="lele hub",Size=UDim2.new(1,-14,0,22),Position=UDim2.new(0,14,0,6),
        TextColor3=Color3.fromRGB(240,242,255),TextSize=mobile and 13 or 15,
        Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Left,Parent=LogoRow})
    Label({Text=VER,Size=UDim2.new(1,-14,0,13),Position=UDim2.new(0,14,0,30),
        TextColor3=Color3.fromRGB(55,57,78),TextSize=9,Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left,Parent=LogoRow})
    -- Close & minimize
    local function TopBtn(icon,col,xOff,cb)
        local b=Button({Size=UDim2.new(0,22,0,22),AnchorPoint=Vector2.new(1,0.5),
            Position=UDim2.new(1,xOff,0.5,0),BackgroundColor3=Color3.fromRGB(22,22,30),
            Text=icon,TextColor3=col,TextSize=11,Font=Enum.Font.GothamBold,ZIndex=12,Parent=LogoRow})
        Round(b,6); b.MouseButton1Click:Connect(cb); return b
    end
    local ContentWrap,SPill,NavScroll,ProfRow  -- forward declare for minimize
    local isMin=false
    -- Buttons: minimize + close
    TopBtn("×",Color3.fromRGB(220,70,80),-4,function()
        TweenService:Create(MainFrame,TweenInfo.new(0.2,Enum.EasingStyle.Quint,Enum.EasingDirection.In),
            {Size=UDim2.new(0,menuTW,0,0),Position=UDim2.new(0.5,-menuTW/2,0.5,0)}):Play()
        task.wait(0.22); MainFrame.Visible=false
        Toast("Closed — press "..table.concat(S.ToggleKeys," / ").." to reopen",T.Dim,3)
    end)
    local MBtn=TopBtn("−",Color3.fromRGB(160,160,180),-30,function()
        isMin=not isMin
        if isMin then
            -- Collapse: show only logo row (with − button visible)
            TweenService:Create(MainFrame,TweenInfo.new(0.22,Enum.EasingStyle.Quint),
                {Size=UDim2.new(0,SW,0,52)}):Play()
            if ContentWrap then ContentWrap.Visible=false end
            if SPill then SPill.Visible=false end
            if NavScroll then NavScroll.Visible=false end
            if ProfRow then ProfRow.Visible=false end
        else
            -- Expand back to full
            TweenService:Create(MainFrame,TweenInfo.new(0.22,Enum.EasingStyle.Quint),
                {Size=UDim2.new(0,menuTW,0,menuTH)}):Play()
            if ContentWrap then ContentWrap.Visible=true end
            if SPill then SPill.Visible=true end
            if NavScroll then NavScroll.Visible=true end
            if ProfRow then ProfRow.Visible=true end
        end
        MBtn.Text=isMin and "+" or "−"
    end)

    -- Nav scroll
    NavScroll=Scroll({Size=UDim2.new(1,0,1,-100),Position=UDim2.new(0,0,0,52),
        BackgroundTransparency=1,ScrollBarThickness=0,Parent=SB})
    Pad(NavScroll,8,8,4,4); List(NavScroll,2)

    -- Profile at bottom
    ProfRow=Frame({Size=UDim2.new(1,0,0,48),AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,0,1,0),
        BackgroundColor3=Color3.fromRGB(12,12,16),Parent=SB})
    Round(ProfRow,10)
    Frame({Size=UDim2.new(1,0,0,1),BackgroundColor3=Color3.fromRGB(30,30,40),Parent=ProfRow})
    local avFrame=Frame({Size=UDim2.new(0,30,0,30),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,10,0.5,0),BackgroundColor3=Color3.fromRGB(22,22,30),Parent=ProfRow}); Round(avFrame,8)
    local avImg=Instance.new("ImageLabel"); avImg.Size=UDim2.new(1,0,1,0); avImg.BackgroundTransparency=1
    avImg.Image="rbxthumb://type=AvatarBust&id="..LP.UserId.."&w=150&h=150"; avImg.ZIndex=2; avImg.Parent=avFrame; Round(avImg,7)
    Label({Text=LP.DisplayName or LP.Name,Size=UDim2.new(1,-52,0,14),Position=UDim2.new(0,46,0,8),
        TextColor3=Color3.fromRGB(220,222,240),TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=ProfRow})
    local ktCol=S.IsOwner and T.Owner or (S.KeyType=="vip" and T.Purple or S.KeyType=="discord" and T.Discord or S.KeyType=="lifetime" and T.BlueBr or T.Green)
    local ktTxt=S.IsOwner and "👑 Owner" or (S.KeyType=="vip" and "⭐ VIP" or S.KeyType=="discord" and "💬 Discord" or S.KeyType=="lifetime" and "💎 Lifetime" or "🟢 Free")
    Label({Text=ktTxt,Size=UDim2.new(1,-52,0,12),Position=UDim2.new(0,46,0,24),
        TextColor3=ktCol,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=ProfRow})

    -- ── RIGHT CONTENT ──
    ContentWrap=Frame({Size=UDim2.new(1,-SW-1,1,0),Position=UDim2.new(0,SW+1,0,0),
        BackgroundColor3=Color3.fromRGB(16,16,21),Parent=MainFrame})
    Round(ContentWrap,12)

    -- Content header
    local Hdr=Frame({Size=UDim2.new(1,0,0,64),BackgroundColor3=Color3.fromRGB(14,14,19),Parent=ContentWrap})
    Round(Hdr,12)
    Frame({Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Color3.fromRGB(30,30,42),Parent=Hdr})
    local HdrIcon=Frame({Size=UDim2.new(0,36,0,36),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,16,0.5,0),BackgroundColor3=Color3.fromRGB(22,22,32),Parent=Hdr}); Round(HdrIcon,10)
    local HdrIconLbl=Label({Text="🎯",Size=UDim2.new(1,0,1,0),TextSize=16,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,Parent=HdrIcon})
    local HdrTitle=Label({Text="Aimbot",Size=UDim2.new(0.6,0,0,20),Position=UDim2.new(0,60,0,12),
        TextColor3=Color3.fromRGB(235,237,255),TextSize=14,Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Left,Parent=Hdr})
    local HdrSub=Label({Text="Detailed Aimbot settings",Size=UDim2.new(0.7,0,0,14),Position=UDim2.new(0,60,0,34),
        TextColor3=Color3.fromRGB(90,92,115),TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Parent=Hdr})
    -- Status pill
    SPill=Frame({Size=UDim2.new(0,110,0,26),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-14,0.5,0),BackgroundColor3=Color3.fromRGB(20,20,28),Parent=Hdr}); Round(SPill,8)
    local SDot=Frame({Size=UDim2.new(0,7,0,7),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,9,0.5,0),BackgroundColor3=Color3.fromRGB(45,45,60),Parent=SPill}); Round(SDot,99)
    local SLbl=Label({Text="OFFLINE",Size=UDim2.new(1,-22,1,0),Position=UDim2.new(0,21,0,0),
        TextColor3=Color3.fromRGB(70,72,95),TextSize=9,Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Left,Parent=SPill})

    RunService.Heartbeat:Connect(function()
        if not S.Unlocked then return end
        if S.Aimbot or S.HardLock then SDot.BackgroundColor3=AC;SLbl.Text="AIMBOT";SLbl.TextColor3=AC
        elseif S.KillAura then SDot.BackgroundColor3=T.Red;SLbl.Text="KILL AURA";SLbl.TextColor3=T.Red
        elseif S.Fly then SDot.BackgroundColor3=T.Green;SLbl.Text="FLYING";SLbl.TextColor3=T.Green
        elseif S.ESP then SDot.BackgroundColor3=Color3.fromRGB(100,220,255);SLbl.Text="ESP";SLbl.TextColor3=Color3.fromRGB(100,220,255)
        else SDot.BackgroundColor3=Color3.fromRGB(45,45,60);SLbl.Text="OFFLINE";SLbl.TextColor3=Color3.fromRGB(70,72,95) end
    end)

    -- Content scroller
    local CScroll=Scroll({Size=UDim2.new(1,-6,1,-70),Position=UDim2.new(0,3,0,66),
        BackgroundTransparency=1,ScrollBarThickness=mobile and 0 or 3,
        ScrollBarImageColor3=Color3.fromRGB(40,40,58),Parent=ContentWrap})
    Pad(CScroll,8,8,6,14); List(CScroll,6)

    local Pages={}; local NavBtns={}
    local function MakePage(name)
        local pg=Frame({Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundTransparency=1,Visible=false,Parent=CScroll})
        List(pg,6); Pages[name]=pg; return pg
    end

    -- ── NAV SECTION LABEL ──
    local function NavSection(txt)
        local f=Frame({Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,Parent=NavScroll})
        Label({Text=txt:upper(),Size=UDim2.new(1,-10,1,0),Position=UDim2.new(0,10,0,0),
            TextColor3=Color3.fromRGB(55,57,78),TextSize=9,Font=Enum.Font.GothamBlack,
            TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
    end

    -- ── NAV ITEM ──
    local activeNav=nil
    local function NavItem(icon,label,page,subtitle)
        local h=mobile and 40 or 36
        local wrap=Frame({Size=UDim2.new(1,0,0,h),BackgroundTransparency=1,Parent=NavScroll})
        local bg=Frame({Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.fromRGB(22,22,32),BackgroundTransparency=1,Parent=wrap}); Round(bg,8)
        local acBar=Frame({Size=UDim2.new(0,3,0.55,0),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),BackgroundColor3=AC,Visible=false,Parent=wrap}); Round(acBar,99)
        local iconLbl=Label({Text=icon,Size=UDim2.new(0,22,1,0),Position=UDim2.new(0,10,0,0),
            TextColor3=Color3.fromRGB(80,82,105),TextSize=12,Font=Enum.Font.GothamBold,
            TextXAlignment=Enum.TextXAlignment.Center,Parent=wrap})
        local nameLbl=Label({Text=label,Size=UDim2.new(1,-38,1,0),Position=UDim2.new(0,36,0,0),
            TextColor3=Color3.fromRGB(90,92,115),TextSize=mobile and 10 or 11,Font=Enum.Font.GothamBold,
            TextXAlignment=Enum.TextXAlignment.Left,Parent=wrap})
        local hit=Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=3,Parent=wrap})
        table.insert(NavBtns,{bg=bg,bar=acBar,iconLbl=iconLbl,nameLbl=nameLbl,page=page,icon=icon,label=label,subtitle=subtitle or "Settings"})
        hit.MouseEnter:Connect(function()
            if activeNav~=page then
                TweenService:Create(bg,TweenInfo.new(0.12),{BackgroundTransparency=0.6}):Play()
                nameLbl.TextColor3=Color3.fromRGB(140,142,165)
            end
        end)
        hit.MouseLeave:Connect(function()
            if activeNav~=page then
                TweenService:Create(bg,TweenInfo.new(0.12),{BackgroundTransparency=1}):Play()
                nameLbl.TextColor3=Color3.fromRGB(90,92,115)
            end
        end)
        hit.MouseButton1Click:Connect(function()
            if activeNav==page then return end
            activeNav=page
            for _,nb in ipairs(NavBtns) do
                TweenService:Create(nb.bg,TweenInfo.new(0.14),{BackgroundTransparency=nb.page==page and 0.2 or 1}):Play()
                nb.bar.Visible=nb.page==page
                nb.bar.BackgroundColor3=AC
                nb.iconLbl.TextColor3=nb.page==page and AC or Color3.fromRGB(80,82,105)
                nb.nameLbl.TextColor3=nb.page==page and Color3.fromRGB(225,227,255) or Color3.fromRGB(90,92,115)
                if Pages[nb.page] then Pages[nb.page].Visible=nb.page==page end
            end
            HdrTitle.Text=label; HdrSub.Text=subtitle or ("Detailed "..label.." settings"); HdrIconLbl.Text=icon
        end)
        return hit
    end

    -- ════════════════════════════════════
    -- ARCANE-STYLE COMPONENTS
    -- ════════════════════════════════════

    -- Section header inside page
    local function PageSection(parent,title)
        local f=Frame({Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,Parent=parent})
        Label({Text=title,Size=UDim2.new(1,-6,1,0),Position=UDim2.new(0,4,0,0),
            TextColor3=Color3.fromRGB(70,72,95),TextSize=9,Font=Enum.Font.GothamBlack,
            TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
    end

    -- Row container (white card-like row)
    local function RowGroup(parent)
        local f=Frame({Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundColor3=Color3.fromRGB(20,20,27),Parent=parent})
        Round(f,10); List(f,0); return f
    end

    -- Toggle row (arcane style: label left, toggle right)
    local function ArcToggle(parent,label,key,cb,first,last)
        local row=Frame({Size=UDim2.new(1,0,0,44),BackgroundTransparency=1,Parent=parent})
        if not first then
            Frame({Size=UDim2.new(1,-20,0,1),Position=UDim2.new(0,10,0,0),BackgroundColor3=Color3.fromRGB(26,26,36),Parent=row})
        end
        Label({Text=label,Size=UDim2.new(1,-72,1,0),Position=UDim2.new(0,16,0,0),
            TextColor3=S[key] and Color3.fromRGB(220,222,245) or Color3.fromRGB(120,122,148),
            TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
        -- Toggle pill
        local track=Frame({Size=UDim2.new(0,38,0,20),AnchorPoint=Vector2.new(1,0.5),
            Position=UDim2.new(1,-14,0.5,0),BackgroundColor3=S[key] and AC or Color3.fromRGB(32,32,44),Parent=row})
        Round(track,99)
        local knob=Frame({Size=UDim2.new(0,14,0,14),AnchorPoint=Vector2.new(0,0.5),
            Position=S[key] and UDim2.new(1,-17,0.5,0) or UDim2.new(0,3,0.5,0),
            BackgroundColor3=Color3.fromRGB(255,255,255),Parent=track})
        Round(knob,99)
        local nameLbl=row:FindFirstChildOfClass("TextLabel")
        local on=S[key] or false
        local hit=Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=3,Parent=row})
        hit.MouseButton1Click:Connect(function()
            on=not on; if key then S[key]=on end
            TweenService:Create(track,TweenInfo.new(0.18),{BackgroundColor3=on and AC or Color3.fromRGB(32,32,44)}):Play()
            TweenService:Create(knob,TweenInfo.new(0.18,Enum.EasingStyle.Quint),{Position=on and UDim2.new(1,-17,0.5,0) or UDim2.new(0,3,0.5,0)}):Play()
            nameLbl.TextColor3=on and Color3.fromRGB(220,222,245) or Color3.fromRGB(120,122,148)
            if cb then cb(on) end; Save()
        end)
        return row
    end

    -- Slider row
    local function ArcSlider(parent,label,key,mn,mx,cb,first)
        local row=Frame({Size=UDim2.new(1,0,0,54),BackgroundTransparency=1,Parent=parent})
        if not first then
            Frame({Size=UDim2.new(1,-20,0,1),Position=UDim2.new(0,10,0,0),BackgroundColor3=Color3.fromRGB(26,26,36),Parent=row})
        end
        Label({Text=label,Size=UDim2.new(0.55,0,0,18),Position=UDim2.new(0,16,0,8),
            TextColor3=Color3.fromRGB(165,167,195),TextSize=11,Font=Enum.Font.GothamBold,
            TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
        local vLbl=Label({Text=tostring(S[key]),Size=UDim2.new(0.4,0,0,18),Position=UDim2.new(0.58,0,0,8),
            TextColor3=Color3.fromRGB(110,112,140),TextSize=10,Font=Enum.Font.GothamBold,
            TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
        local trBG=Frame({Size=UDim2.new(1,-32,0,4),Position=UDim2.new(0,16,0,34),
            BackgroundColor3=Color3.fromRGB(30,30,42),Active=true,Parent=row}); Round(trBG,99)
        local trHit=Frame({Size=UDim2.new(1,0,0,28),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),
            BackgroundTransparency=1,Active=true,ZIndex=2,Parent=trBG})
        local pct=math.clamp((S[key]-mn)/math.max(mx-mn,1),0,1)
        local fill=Frame({Size=UDim2.new(pct,0,1,0),BackgroundColor3=AC,Parent=trBG}); Round(fill,99)
        local kn=Frame({Size=UDim2.new(0,12,0,12),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(pct,0,0.5,0),
            BackgroundColor3=Color3.fromRGB(255,255,255),ZIndex=3,Parent=trBG}); Round(kn,99)
        local drag=false
        local function Apply(i)
            local rel=math.clamp((i.Position.X-trBG.AbsolutePosition.X)/math.max(trBG.AbsoluteSize.X,1),0,1)
            local val=math.floor(mn+(mx-mn)*rel); S[key]=val
            fill.Size=UDim2.new(rel,0,1,0); kn.Position=UDim2.new(rel,0,0.5,0)
            vLbl.Text=tostring(val); if cb then cb(val) end; Save()
        end
        trHit.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
                drag=true; _dragActive=false; Apply(i) end
        end)
        trBG.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
                drag=true; _dragActive=false; Apply(i) end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if drag and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then Apply(i) end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
        end)
        return row
    end

    -- Color swatch button
    local function ColorSwatch(parent,col,onClick)
        local b=Button({Size=UDim2.new(0,24,0,24),BackgroundColor3=col,Text="",Parent=parent}); Round(b,7)
        b.MouseButton1Click:Connect(function() onClick(col) end); return b
    end

    -- ════════════════════════════════════
    -- PAGE: AIMBOT
    -- ════════════════════════════════════
    local pgAim=MakePage("aimbot")
    PageSection(pgAim,"Player Aimbot Settings")
    local aimGroup=RowGroup(pgAim)
    ArcToggle(aimGroup,"Enable",                "Aimbot",  function(on) if not on then S.HardLock=false;S.Autoshoot=false;S.SilentAim=false end end, true)
    ArcToggle(aimGroup,"Hard Lock (Camera snap)","HardLock",function(on) if on then S.Aimbot=true end end)
    ArcToggle(aimGroup,"Auto Shoot",            "Autoshoot",function(on) if on then S.Aimbot=true end end)
    ArcToggle(aimGroup,"Silent Aim",            "SilentAim",function(on) if on then S.Aimbot=true end end)
    ArcToggle(aimGroup,"Team Check",            "TeamCheck",nil)
    ArcSlider(aimGroup,"Smooth",                "Smoothing",1,100,nil)
    ArcSlider(aimGroup,"FOV",                   "FOV",30,700,function(v) DFov.Radius=v end)
    ArcSlider(aimGroup,"Distance",              "MaxDist",50,2000,nil)

    PageSection(pgAim,"Aim Target Bone")
    local boneGroup=RowGroup(pgAim)
    local AIM_PARTS_DEF={
        {k="Head",lk="head"},{k="UpperTorso",lk="upperTorso"},{k="LowerTorso",lk="lowerTorso"},
        {k="RightUpperArm",lk="rightArm"},{k="LeftUpperArm",lk="leftArm"},
        {k="RightUpperLeg",lk="rightLeg"},{k="LeftUpperLeg",lk="leftLeg"},
    }
    local function GetAimPart(char)
        if S.AimRandom then
            local pool={}
            for _,d in ipairs(AIM_PARTS_DEF) do if S.AimTargets[d.k] then local p=char:FindFirstChild(d.k); if p then table.insert(pool,p) end end end
            if #pool==0 then for _,d in ipairs(AIM_PARTS_DEF) do local p=char:FindFirstChild(d.k); if p then table.insert(pool,p) end end end
            if #pool>0 then return pool[math.random(1,#pool)] end
        else
            for _,d in ipairs(AIM_PARTS_DEF) do if S.AimTargets[d.k] then local p=char:FindFirstChild(d.k); if p then return p end end end
        end
        return char:FindFirstChild("HumanoidRootPart")
    end
    GetAimPartFn=GetAimPart
    local chipArea=Frame({Size=UDim2.new(1,-20,0,0),AutomaticSize=Enum.AutomaticSize.Y,Position=UDim2.new(0,10,0,8),BackgroundTransparency=1,Parent=boneGroup})
    local cl=List(chipArea,5,Enum.FillDirection.Horizontal); cl.Wraps=true; Spc(boneGroup,4)
    local allChipRf={}
    local function BoneChip(lbl,key,isRand)
        local active=isRand and S.AimRandom or (S.AimTargets[key] or false)
        local b=Button({Size=UDim2.new(0,0,0,24),AutomaticSize=Enum.AutomaticSize.X,
            BackgroundColor3=active and AC or Color3.fromRGB(28,28,40),
            Text=(active and "✓ " or "")..lbl,
            TextColor3=active and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,102,128),
            TextSize=9,Font=Enum.Font.GothamBold,Parent=chipArea})
        Round(b,6); Pad(b,7,7,0,0)
        local function Rf()
            local a=isRand and S.AimRandom or (S.AimTargets[key] or false)
            b.Text=(a and "✓ " or "")..lbl
            b.TextColor3=a and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,102,128)
            TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=a and AC or Color3.fromRGB(28,28,40)}):Play()
        end
        table.insert(allChipRf,Rf)
        b.MouseButton1Click:Connect(function()
            if isRand then S.AimRandom=not S.AimRandom
            else S.AimTargets[key]=not(S.AimTargets[key] or false) end
            Save(); for _,rf in ipairs(allChipRf) do rf() end
        end)
    end
    for _,d in ipairs(AIM_PARTS_DEF) do BoneChip(L(d.lk),d.k,false) end
    BoneChip("🎲 Random",nil,true)

    PageSection(pgAim,"FOV Circle")
    local fovGroup=RowGroup(pgAim)
    ArcToggle(fovGroup,"Draw FOV Border","FOVOn",function(on) DFov.Visible=on end,true)
    ArcToggle(fovGroup,"Crosshair","Crosshair",function(on) DCrossH.Visible=on; DCrossV.Visible=on end)
    ArcSlider(fovGroup,"FOV Size","FOV",30,700,function(v) DFov.Radius=v end)

    -- ════════════════════════════════════
    -- PAGE: COMBAT
    -- ════════════════════════════════════
    local pgCombat=MakePage("combat")
    PageSection(pgCombat,"Kill Aura")
    local kaGroup=RowGroup(pgCombat)
    ArcToggle(kaGroup,"Enable Kill Aura","KillAura",nil,true)
    ArcSlider(kaGroup,"Range","KillAuraRange",4,60,nil)

    PageSection(pgCombat,"Reach")
    local reachGroup=RowGroup(pgCombat)
    ArcToggle(reachGroup,"Enable Reach","Reach",function(on)
        if not on then pcall(function() local t=LP.Character and LP.Character:FindFirstChildOfClass("Tool"); local h=t and t:FindFirstChild("Handle"); if h then h.Size=Vector3.new(1,1,1) end end) end
    end,true)
    ArcSlider(reachGroup,"Reach Size","ReachSize",2,40,function(v)
        if S.Reach then pcall(function() local t=LP.Character and LP.Character:FindFirstChildOfClass("Tool"); local h=t and t:FindFirstChild("Handle"); if h then h.Size=Vector3.new(v,v,v) end end) end
    end)

    PageSection(pgCombat,"Head TP")
    local htpGroup=RowGroup(pgCombat)
    -- Height slider
    local hhRow=Frame({Size=UDim2.new(1,0,0,54),BackgroundTransparency=1,Parent=htpGroup})
    Frame({Size=UDim2.new(1,-20,0,1),Position=UDim2.new(0,10,0,0),BackgroundColor3=Color3.fromRGB(26,26,36),Parent=hhRow})
    Label({Text="Height above target",Size=UDim2.new(0.55,0,0,18),Position=UDim2.new(0,16,0,8),TextColor3=Color3.fromRGB(165,167,195),TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=hhRow})
    local hhVal=Label({Text=tostring(S.HeadTPHeight),Size=UDim2.new(0.4,0,0,18),Position=UDim2.new(0.58,0,0,8),TextColor3=Color3.fromRGB(110,112,140),TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=hhRow})
    local hhBG=Frame({Size=UDim2.new(1,-32,0,4),Position=UDim2.new(0,16,0,36),BackgroundColor3=Color3.fromRGB(30,30,42),Active=true,Parent=hhRow}); Round(hhBG,99)
    local hhHit=Frame({Size=UDim2.new(1,0,0,28),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,0,0.5,0),BackgroundTransparency=1,Active=true,ZIndex=2,Parent=hhBG})
    local hhPct=math.clamp((S.HeadTPHeight-1)/29,0,1)
    local hhFill=Frame({Size=UDim2.new(hhPct,0,1,0),BackgroundColor3=AC,Parent=hhBG}); Round(hhFill,99)
    local hhKn=Frame({Size=UDim2.new(0,12,0,12),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(hhPct,0,0.5,0),BackgroundColor3=Color3.fromRGB(255,255,255),ZIndex=3,Parent=hhBG}); Round(hhKn,99)
    local hhDrag=false
    local function ApplyHH(i)
        local rel=math.clamp((i.Position.X-hhBG.AbsolutePosition.X)/math.max(hhBG.AbsoluteSize.X,1),0,1)
        S.HeadTPHeight=math.floor(1+rel*29); hhVal.Text=tostring(S.HeadTPHeight)
        hhFill.Size=UDim2.new(rel,0,1,0); hhKn.Position=UDim2.new(rel,0,0.5,0); Save()
    end
    hhHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then hhDrag=true;_dragActive=false;ApplyHH(i) end end)
    hhBG.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then hhDrag=true;_dragActive=false;ApplyHH(i) end end)
    UserInputService.InputChanged:Connect(function(i) if hhDrag and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then ApplyHH(i) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then hhDrag=false end end)
    -- TP Button
    local htpBtnRow=Frame({Size=UDim2.new(1,0,0,46),BackgroundTransparency=1,Parent=htpGroup})
    Frame({Size=UDim2.new(1,-20,0,1),Position=UDim2.new(0,10,0,0),BackgroundColor3=Color3.fromRGB(26,26,36),Parent=htpBtnRow})
    local htpBtnW=Frame({Size=UDim2.new(1,-20,0,34),AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-6),BackgroundColor3=AC,Parent=htpBtnRow}); Round(htpBtnW,8)
    local htpBtn=Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="⬆  TELEPORT TO HEAD",TextColor3=Color3.fromRGB(255,255,255),TextSize=11,Font=Enum.Font.GothamBlack,Parent=htpBtnW})
    local function GetNearestEnemy()
        local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return nil end
        local best,bestDist=nil,math.huge
        for _,p in ipairs(Players:GetPlayers()) do
            if p==LP then continue end; local pc=p.Character; if not pc then continue end
            local ph=pc:FindFirstChild("HumanoidRootPart"); if not ph then continue end
            local hum=pc:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then continue end
            local dist=(myHRP.Position-ph.Position).Magnitude; if dist<bestDist then bestDist=dist; best=ph end
        end; return best
    end
    local function DoSingleHeadTP()
        pcall(function()
            local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
            local best=GetNearestEnemy()
            if best then myHRP.CFrame=CFrame.new(best.Position+Vector3.new(0,S.HeadTPHeight,0),best.Position)
            else Toast("❌ No enemy found!",T.Red) end
        end)
    end
    htpBtn.MouseButton1Click:Connect(DoSingleHeadTP)
    htpBtnW.MouseEnter:Connect(function() TweenService:Create(htpBtnW,TweenInfo.new(0.14),{BackgroundColor3=Color3.fromRGB(150,190,255)}):Play() end)
    htpBtnW.MouseLeave:Connect(function() TweenService:Create(htpBtnW,TweenInfo.new(0.14),{BackgroundColor3=AC}):Play() end)
    -- Continuous toggle
    local htpAutoRow=Frame({Size=UDim2.new(1,0,0,44),BackgroundTransparency=1,Parent=htpGroup})
    Frame({Size=UDim2.new(1,-20,0,1),Position=UDim2.new(0,10,0,0),BackgroundColor3=Color3.fromRGB(26,26,36),Parent=htpAutoRow})
    local htpAutoLbl=Label({Text="Continuous  ["..S.HeadTPKey.."]",Size=UDim2.new(1,-72,1,0),Position=UDim2.new(0,16,0,0),TextColor3=headTPContinuous and Color3.fromRGB(220,222,245) or Color3.fromRGB(120,122,148),TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=htpAutoRow})
    local htpTrack=Frame({Size=UDim2.new(0,38,0,20),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-14,0.5,0),BackgroundColor3=headTPContinuous and AC or Color3.fromRGB(32,32,44),Parent=htpAutoRow}); Round(htpTrack,99)
    local htpKnob=Frame({Size=UDim2.new(0,14,0,14),AnchorPoint=Vector2.new(0,0.5),Position=headTPContinuous and UDim2.new(1,-17,0.5,0) or UDim2.new(0,3,0.5,0),BackgroundColor3=Color3.fromRGB(255,255,255),Parent=htpTrack}); Round(htpKnob,99)
    local htpHit=Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=3,Parent=htpAutoRow})
    htpHit.MouseButton1Click:Connect(function()
        headTPContinuous=not headTPContinuous
        TweenService:Create(htpTrack,TweenInfo.new(0.18),{BackgroundColor3=headTPContinuous and AC or Color3.fromRGB(32,32,44)}):Play()
        TweenService:Create(htpKnob,TweenInfo.new(0.18,Enum.EasingStyle.Quint),{Position=headTPContinuous and UDim2.new(1,-17,0.5,0) or UDim2.new(0,3,0.5,0)}):Play()
        htpAutoLbl.TextColor3=headTPContinuous and Color3.fromRGB(220,222,245) or Color3.fromRGB(120,122,148)
    end)

    -- ════════════════════════════════════
    -- PAGE: MOVEMENT
    -- ════════════════════════════════════
    local pgMove=MakePage("movement")
    PageSection(pgMove,"Player Movement")
    local moveGroup=RowGroup(pgMove)
    ArcSlider(moveGroup,"Walk Speed","WalkSpeed",16,300,nil,true)
    ArcSlider(moveGroup,"Jump Power","JumpPower",50,400,nil)
    ArcToggle(moveGroup,"No Clip","NoClip",nil)
    ArcToggle(moveGroup,"Infinite Jump","InfJump",nil)
    ArcToggle(moveGroup,"Anti AFK","AntiAFK",nil)
    ArcToggle(moveGroup,"Spin Bot","SpinBot",nil)
    ArcSlider(moveGroup,"Spin Speed","SpinSpeed",1,60,nil)

    PageSection(pgMove,"Teleport to Player")
    local tpGroup=RowGroup(pgMove)
    local tpList=Scroll({Size=UDim2.new(1,-20,0,130),Position=UDim2.new(0,10,0,6),BackgroundTransparency=1,ScrollBarThickness=2,ScrollBarImageColor3=Color3.fromRGB(40,40,58),Parent=tpGroup}); List(tpList,4); Pad(tpList,0,0,4,4)
    local function RebuildTP()
        for _,c in ipairs(tpList:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
        local cnt=0
        for _,p in ipairs(Players:GetPlayers()) do
            if p==LP then continue end; cnt=cnt+1
            local btn=Button({Size=UDim2.new(1,0,0,30),BackgroundColor3=Color3.fromRGB(24,24,34),Text="⚡  "..p.Name,TextColor3=AC,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=tpList}); Round(btn,8); Pad(btn,12,0,0,0)
            btn.MouseButton1Click:Connect(function()
                pcall(function()
                    local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
                    local tc=p.Character; if not tc then return end
                    local thrp=tc:FindFirstChild("HumanoidRootPart"); if not thrp then return end
                    myHRP.CFrame=thrp.CFrame+Vector3.new(3,0,0); Toast("⚡ TP → "..p.Name,AC)
                end)
            end)
        end
        if cnt==0 then Label({Text="No players in server",Size=UDim2.new(1,0,0,28),TextColor3=Color3.fromRGB(70,72,95),TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Center,Parent=tpList}) end
    end
    RebuildTP()
    local refBtnW=Frame({Size=UDim2.new(1,-20,0,30),AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,4),BackgroundColor3=Color3.fromRGB(24,24,34),Parent=tpGroup}); Round(refBtnW,8)
    Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="🔄  Refresh",TextColor3=Color3.fromRGB(110,112,140),TextSize=10,Font=Enum.Font.GothamBold,Parent=refBtnW}).MouseButton1Click:Connect(RebuildTP)
    Spc(tpGroup,4)

    -- ════════════════════════════════════
    -- PAGE: FLY
    -- ════════════════════════════════════
    local pgFly=MakePage("fly")
    PageSection(pgFly,"Fly Settings")
    local flyGroup=RowGroup(pgFly)
    ArcToggle(flyGroup,"Enable Fly","Fly",function(on) EnableFly(on); MFly.Visible=(on and isMob) end,true)
    ArcSlider(flyGroup,"Fly Speed","FlySpeed",5,250,nil)
    local flyInfoRow=Frame({Size=UDim2.new(1,0,0,36),BackgroundTransparency=1,Parent=flyGroup})
    Frame({Size=UDim2.new(1,-20,0,1),Position=UDim2.new(0,10,0,0),BackgroundColor3=Color3.fromRGB(26,26,36),Parent=flyInfoRow})
    Label({Text=mobile and "Controls: On-screen pad" or "Controls: WASD + Space / Shift",Size=UDim2.new(1,-20,1,0),Position=UDim2.new(0,16,0,0),TextColor3=Color3.fromRGB(70,72,95),TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Parent=flyInfoRow})

    -- ════════════════════════════════════
    -- PAGE: ESP
    -- ════════════════════════════════════
    local pgESP=MakePage("esp")
    PageSection(pgESP,"ESP Settings")
    local espGroup=RowGroup(pgESP)
    ArcToggle(espGroup,"Enable ESP","ESP",function(on)
        if on then
            for _,p in ipairs(Players:GetPlayers()) do if p~=LP and p.Character then CleanESP(p); BuildESP(p) end end
        else
            for p,_ in pairs(ESPData) do CleanESP(p) end
        end
    end,true)
    ArcToggle(espGroup,"Player Names","ESPNames",nil)
    ArcToggle(espGroup,"Health Bar","HealthBar",nil)
    ArcToggle(espGroup,"Skeleton","Skeleton",function(on)
        -- Rebuild ESP so skeleton lines are created/updated
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and p.Character then CleanESP(p); BuildESP(p) end
        end
    end)
    ArcToggle(espGroup,"Tracers","Tracers",nil)
    ArcToggle(espGroup,"Draw Box","DrawBox",nil)
    ArcSlider(espGroup,"Max Distance","MaxDist",50,2000,nil)

    PageSection(pgESP,"ESP Color")
    local espColGroup=RowGroup(pgESP)
    local espColRow=Frame({Size=UDim2.new(1,0,0,48),BackgroundTransparency=1,Parent=espColGroup})
    Label({Text="Enemy Color",Size=UDim2.new(0.45,0,1,0),Position=UDim2.new(0,16,0,0),TextColor3=Color3.fromRGB(165,167,195),TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=espColRow})
    local espColors={Color3.fromRGB(255,50,50),Color3.fromRGB(255,140,0),Color3.fromRGB(255,220,0),Color3.fromRGB(0,255,120),Color3.fromRGB(0,200,255),Color3.fromRGB(200,80,255),Color3.fromRGB(255,255,255)}
    local swArea=Frame({Size=UDim2.new(0.52,0,0,28),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-14,0.5,0),BackgroundTransparency=1,Parent=espColRow}); List(swArea,5,Enum.FillDirection.Horizontal)
    for _,col in ipairs(espColors) do
        ColorSwatch(swArea,col,function(c)
            S.ESPEnemyColor={r=c.R*255,g=c.G*255,b=c.B*255}; Save()
            for p,d in pairs(ESPData) do CleanESP(p) end
            task.wait(0.05)
            for _,p in ipairs(Players:GetPlayers()) do if p~=LP and p.Character then BuildESP(p) end end
            Toast("ESP enemy color updated",AC)
        end)
    end
    Spc(espColGroup,4)

    -- ════════════════════════════════════
    -- PAGE: WORLD
    -- ════════════════════════════════════
    local pgWorld=MakePage("world")
    PageSection(pgWorld,"World Settings")
    local worldGroup=RowGroup(pgWorld)
    ArcToggle(worldGroup,"Fullbright","Fullbright",function(on)
        if on then Lighting.Brightness=10;Lighting.ClockTime=14;Lighting.FogEnd=1e5;Lighting.GlobalShadows=false;Lighting.Ambient=Color3.fromRGB(255,255,255);Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
        else Lighting.Brightness=1;Lighting.GlobalShadows=true;Lighting.Ambient=Color3.fromRGB(127,127,127);Lighting.OutdoorAmbient=Color3.fromRGB(127,127,127) end
    end,true)
    ArcToggle(worldGroup,"FPS Boost","FPSBoost",function(on)
        if on then
            pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end)
            Lighting.GlobalShadows=false;Lighting.ShadowSoftness=0;Lighting.EnvironmentDiffuseScale=0;Lighting.EnvironmentSpecularScale=0
            for _,v in ipairs(Lighting:GetChildren()) do if v:IsA("PostEffect") and v.Name~="_blur_fx" then pcall(function() v.Enabled=false end) end end
            task.defer(function() for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then pcall(function() v.Enabled=false end) end end end)
            pcall(function() workspace.Terrain.Decoration=false end)
            Toast("✅ FPS Boost active",T.Green)
        else
            pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic end)
            if not S.Fullbright then Lighting.GlobalShadows=true end
            Lighting.ShadowSoftness=0.2;Lighting.EnvironmentDiffuseScale=1;Lighting.EnvironmentSpecularScale=1
            for _,v in ipairs(Lighting:GetChildren()) do if v:IsA("PostEffect") then pcall(function() v.Enabled=true end) end end
        end
    end)
    ArcToggle(worldGroup,"Night Sky (Smooth Sky)","_smoothSky",function(on)
        if on then
            pcall(function()
                local old=Lighting:FindFirstChild("_lhSky"); if old then old:Destroy() end
                local sky=Instance.new("Sky"); sky.Name="_lhSky"
                sky.SkyboxBk="rbxassetid://159461286";sky.SkyboxDn="rbxassetid://159461316"
                sky.SkyboxFt="rbxassetid://159461286";sky.SkyboxLf="rbxassetid://159461286"
                sky.SkyboxRt="rbxassetid://159461286";sky.SkyboxUp="rbxassetid://159461328"
                sky.StarCount=3000;sky.Parent=Lighting
                Lighting.Ambient=Color3.fromRGB(80,90,140);Lighting.ClockTime=22;Lighting.Brightness=0.4
            end)
        else
            pcall(function() local s=Lighting:FindFirstChild("_lhSky"); if s then s:Destroy() end end)
            if not S.Fullbright then Lighting.Ambient=Color3.fromRGB(127,127,127);Lighting.ClockTime=14;Lighting.Brightness=1 end
        end
    end)
    ArcSlider(worldGroup,"Gravity","Gravity",5,500,function(v) workspace.Gravity=v end)

    -- ════════════════════════════════════
    -- PAGE: VISUALS
    -- ════════════════════════════════════
    local pgVisuals=MakePage("visuals")
    PageSection(pgVisuals,"Visual Effects")
    local visGroup=RowGroup(pgVisuals)
    ArcToggle(visGroup,"Black Mode","BlackMode",function(on) ApplyBlackMode(on) end,true)
    ArcToggle(visGroup,"Third Person","ThirdPerson",function(on) ApplyThirdPerson(on,S.ThirdPersonDist) end)
    ArcSlider(visGroup,"Camera Distance","ThirdPersonDist",5,60,function(v) if S.ThirdPerson then ApplyThirdPerson(true,v) end end)

    -- ════════════════════════════════════
    -- PAGE: SETTINGS
    -- ════════════════════════════════════
    local pgSettings=MakePage("settings")

    -- Menu Accent Color
    PageSection(pgSettings,"Menu Accent Color")
    local accentGroup=RowGroup(pgSettings)
    local accentRow=Frame({Size=UDim2.new(1,0,0,52),BackgroundTransparency=1,Parent=accentGroup})
    Label({Text="Accent Color",Size=UDim2.new(0.4,0,1,0),Position=UDim2.new(0,16,0,0),TextColor3=Color3.fromRGB(165,167,195),TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=accentRow})
    local accentColors={
        Color3.fromRGB(80,140,255),Color3.fromRGB(100,210,255),Color3.fromRGB(80,220,160),
        Color3.fromRGB(200,80,255),Color3.fromRGB(255,100,80),Color3.fromRGB(255,200,60),
        Color3.fromRGB(255,255,255),Color3.fromRGB(255,100,160),
    }
    local acArea=Frame({Size=UDim2.new(0.58,0,0,30),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-14,0.5,0),BackgroundTransparency=1,Parent=accentRow}); List(acArea,5,Enum.FillDirection.Horizontal)
    for _,col in ipairs(accentColors) do
        ColorSwatch(acArea,col,function(c)
            SetAccent(c)
            -- Live update all nav bars and sliders
            for _,nb in ipairs(NavBtns) do
                if nb.page==activeNav then nb.bar.BackgroundColor3=c; nb.iconLbl.TextColor3=c end
            end
            Toast("Accent updated",c)
            -- Rebuild menu to apply fully
            task.delay(0.8,function() BuildMenu(isMob) end)
        end)
    end
    Spc(accentGroup,4)

    -- Toggle Keys
    PageSection(pgSettings,"Toggle Key")
    local kbGroup=RowGroup(pgSettings)
    local kbChipArea=Frame({Size=UDim2.new(1,-20,0,0),AutomaticSize=Enum.AutomaticSize.Y,Position=UDim2.new(0,10,0,8),BackgroundTransparency=1,Parent=kbGroup})
    local kbcl=List(kbChipArea,5,Enum.FillDirection.Horizontal); kbcl.Wraps=true
    local rebinding=false
    local function RebuildKB()
        for _,c in ipairs(kbChipArea:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        for _,k in ipairs(S.ToggleKeys) do
            -- Wrap = chip + delete button side by side
            local chipWrap=Frame({Size=UDim2.new(0,0,0,26),AutomaticSize=Enum.AutomaticSize.X,BackgroundTransparency=1,Parent=kbChipArea})
            local chipL=List(chipWrap,4,Enum.FillDirection.Horizontal)
            local chip=Frame({Size=UDim2.new(0,0,0,26),AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=AC,Parent=chipWrap}); Round(chip,7); Pad(chip,10,10,0,0)
            Label({Text=k,Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,TextColor3=Color3.fromRGB(10,10,20),TextSize=10,Font=Enum.Font.GothamBlack,Parent=chip})
            local del=Button({Size=UDim2.new(0,22,0,26),BackgroundColor3=Color3.fromRGB(50,20,20),Text="×",TextColor3=Color3.fromRGB(220,60,80),TextSize=11,Font=Enum.Font.GothamBlack,Parent=chipWrap}); Round(del,7)
            local ck=k; del.MouseButton1Click:Connect(function()
                if #S.ToggleKeys<=1 then Toast("❌ Need at least 1 key!",T.Red); return end
                for i,v in ipairs(S.ToggleKeys) do if v==ck then table.remove(S.ToggleKeys,i); break end end
                Save(); RebuildKB()
            end)
            _ = chipL -- keep reference
        end
    end
    RebuildKB(); Spc(kbGroup,4)
    local addBtnW=Frame({Size=UDim2.new(1,-20,0,34),AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,4),BackgroundColor3=Color3.fromRGB(22,22,32),Parent=kbGroup}); Round(addBtnW,8)
    local addBtn=Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="+ Add Key (click then press any key)",TextColor3=Color3.fromRGB(100,102,128),TextSize=10,Font=Enum.Font.GothamBold,Parent=addBtnW})
    addBtn.MouseButton1Click:Connect(function()
        if rebinding then return end; rebinding=true
        addBtn.Text="Press any key..."; addBtnW.BackgroundColor3=AC
        local con; con=UserInputService.InputBegan:Connect(function(input,gp)
            if gp then return end
            if input.UserInputType==Enum.UserInputType.Keyboard then
                local kn=input.KeyCode.Name; local exists=false
                for _,k in ipairs(S.ToggleKeys) do if k==kn then exists=true; break end end
                if not exists then table.insert(S.ToggleKeys,kn); Save() end
                RebuildKB(); addBtn.Text="+ Add Key (click then press any key)"; addBtnW.BackgroundColor3=Color3.fromRGB(22,22,32); rebinding=false; con:Disconnect()
            end
        end)
    end)
    Spc(kbGroup,4)

    -- Key Change
    PageSection(pgSettings,"Key")
    local keyGrp=RowGroup(pgSettings)
    local kcRow=Frame({Size=UDim2.new(1,0,0,44),BackgroundTransparency=1,Parent=keyGrp})
    Label({Text="Current key:",Size=UDim2.new(0.4,0,1,0),Position=UDim2.new(0,16,0,0),TextColor3=Color3.fromRGB(120,122,148),TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=kcRow})
    local mkCol=S.IsOwner and T.Owner or (S.KeyType=="vip" and T.Purple or S.KeyType=="discord" and T.Discord or S.KeyType=="lifetime" and T.BlueBr or T.Green)
    local mkTxt=S.IsOwner and "👑 OWNER" or (S.KeyType=="vip" and "⭐ VIP" or S.KeyType=="discord" and "💬 DISCORD" or S.KeyType=="lifetime" and "💎 LIFETIME" or "🟢 FREE")
    local kcBadge=Frame({Size=UDim2.new(0,0,0,22),AutomaticSize=Enum.AutomaticSize.X,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-14,0.5,0),BackgroundColor3=mkCol,Parent=kcRow}); Round(kcBadge,7); Pad(kcBadge,8,8,0,0)
    Label({Text=mkTxt,Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,TextColor3=Color3.fromRGB(10,10,20),TextSize=9,Font=Enum.Font.GothamBlack,Parent=kcBadge})
    local chgBtnW2=Frame({Size=UDim2.new(1,-20,0,32),AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,4),BackgroundColor3=Color3.fromRGB(22,22,32),Parent=keyGrp}); Round(chgBtnW2,8)
    local chgBtn2=Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="🔑  Change Key",TextColor3=Color3.fromRGB(100,102,128),TextSize=10,Font=Enum.Font.GothamBold,Parent=chgBtnW2})
    chgBtn2.MouseButton1Click:Connect(function()
        S.Key=nil;S.KeyType=nil;S.KeyActivated=nil;S.Unlocked=false;S.IsOwner=false;Save()
        ClearKeyInput(); KStatus.Text=""
        MainFrame.Visible=false; SetBlur(true); KeyBG.Visible=true
        KBox.Size=UDim2.new(0,460,0,480); KBox.Position=UDim2.new(0.5,0,0.5,0)
    end)
    Spc(keyGrp,4)

    -- ════════════════════════════════════
    -- PAGE: OWNER
    -- ════════════════════════════════════
    if S.IsOwner then
        local pgOwner=MakePage("owner")
        local function AgeStr(ts) local age=os.time()-(ts or 0); return age<60 and age.."s" or age<3600 and math.floor(age/60).."m" or math.floor(age/3600).."h" end
        local function UserRow(parent,name,display,keyType,extra,isLive)
            local col=keyType=="owner" and T.Owner or keyType=="discord" and T.Discord or keyType=="vip" and T.Purple or keyType=="lifetime" and T.BlueBr or T.Green
            local row=Frame({Size=UDim2.new(1,0,0,36),BackgroundColor3=Color3.fromRGB(22,22,32),Parent=parent}); Round(row,8)
            if isLive then
                local dot=Frame({Size=UDim2.new(0,7,0,7),AnchorPoint=Vector2.new(0,0.5),Position=UDim2.new(0,9,0.5,0),BackgroundColor3=T.Green,Parent=row}); Round(dot,99)
                task.spawn(function() pcall(function() TweenService:Create(dot,TweenInfo.new(0.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{BackgroundTransparency=0.5}):Play() end) end)
            end
            local ox=isLive and 22 or 10
            Label({Text=display or name,Size=UDim2.new(0.58,0,0,16),Position=UDim2.new(0,ox,0,3),TextColor3=Color3.fromRGB(210,212,235),TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
            Label({Text="@"..(name or "?"),Size=UDim2.new(0.58,0,0,13),Position=UDim2.new(0,ox,0,19),TextColor3=Color3.fromRGB(70,72,95),TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,Parent=row})
            local badge=Frame({Size=UDim2.new(0,0,0,18),AutomaticSize=Enum.AutomaticSize.X,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-8,0.5,0),BackgroundColor3=col,Parent=row}); Round(badge,5); Pad(badge,5,5,0,0)
            local bl=(keyType or "?"):upper(); if extra then bl=bl.." • "..extra end
            Label({Text=bl,Size=UDim2.new(0,0,1,0),AutomaticSize=Enum.AutomaticSize.X,TextColor3=Color3.fromRGB(10,10,20),TextSize=7,Font=Enum.Font.GothamBlack,Parent=badge})
        end
        local function OwnerSection(parent,title,filterType)
            PageSection(parent,title)
            local sg=RowGroup(parent)
            local sl=Scroll({Size=UDim2.new(1,-20,0,130),Position=UDim2.new(0,10,0,6),BackgroundTransparency=1,ScrollBarThickness=2,ScrollBarImageColor3=Color3.fromRGB(40,40,58),Parent=sg}); List(sl,4); Pad(sl,0,0,4,4)
            local function Rebuild()
                for _,c in ipairs(sl:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
                local cnt=0; local sess=ReadJ(OF); local liveNames={}
                for _,p in ipairs(Players:GetPlayers()) do liveNames[p.Name]=p end
                if filterType=="live" then
                    for uid,d in pairs(sess) do cnt=cnt+1; UserRow(sl,d.name,d.display,d.keyType,AgeStr(d.timestamp),liveNames[d.name]~=nil) end
                    for _,p in ipairs(Players:GetPlayers()) do
                        if not sess[tostring(p.UserId)] then local kt; pcall(function() kt=p:GetAttribute("_lh_k") end); if kt then cnt=cnt+1; UserRow(sl,p.Name,p.DisplayName or p.Name,kt,nil,true) end end
                    end
                else
                    for uid,d in pairs(sess) do
                        local kt=d.keyType or "?"
                        local match=(filterType=="all") or (kt==filterType) or
                            (filterType=="free" and (kt=="free_new" or kt=="free_active"))
                        if not match then continue end
                        cnt=cnt+1; UserRow(sl,d.name,d.display,kt,AgeStr(d.timestamp),liveNames[d.name]~=nil)
                    end
                end
                if cnt==0 then Label({Text="No data yet",Size=UDim2.new(1,0,0,26),TextColor3=Color3.fromRGB(70,72,95),TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Center,Parent=sl}) end
            end
            Rebuild()
            local rb=Button({Size=UDim2.new(1,-20,0,28),AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,4),BackgroundColor3=Color3.fromRGB(22,22,32),Text="🔄  Refresh",TextColor3=Color3.fromRGB(100,102,128),TextSize=10,Font=Enum.Font.GothamBold,Parent=sg}); Round(rb,8); rb.MouseButton1Click:Connect(Rebuild); Spc(sg,4)
        end
        OwnerSection(pgOwner,"🟢 All Users","live")
        OwnerSection(pgOwner,"Free Users","free")
        OwnerSection(pgOwner,"Lifetime Users","lifetime")
        OwnerSection(pgOwner,"Discord Users","discord")
        OwnerSection(pgOwner,"VIP Users","vip")

        -- Key Manager
        PageSection(pgOwner,"Key Manager")
        local kmGrp=RowGroup(pgOwner)
        local function KMSection(lbl,ktype,col)
            local kRow=Frame({Size=UDim2.new(1,0,0,50),BackgroundTransparency=1,Parent=kmGrp})
            Frame({Size=UDim2.new(1,-20,0,1),Position=UDim2.new(0,10,0,0),BackgroundColor3=Color3.fromRGB(26,26,36),Parent=kRow})
            Label({Text=lbl,Size=UDim2.new(0.4,0,0,14),Position=UDim2.new(0,16,0,8),TextColor3=col,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=kRow})
            local inp=TBox({Size=UDim2.new(0.55,0,0,26),Position=UDim2.new(0,16,0,20),BackgroundColor3=Color3.fromRGB(22,22,32),PlaceholderText="New key...",PlaceholderColor3=Color3.fromRGB(60,62,85),Text="",TextColor3=Color3.fromRGB(200,202,225),TextSize=10,Font=Enum.Font.Gotham,ClearTextOnFocus=true,ZIndex=2,Parent=kRow}); Round(inp,7)
            local addW=Frame({Size=UDim2.new(0.3,0,0,26),AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,20),BackgroundColor3=col,Parent=kRow}); Round(addW,7)
            Button({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="ADD",TextColor3=Color3.fromRGB(10,10,20),TextSize=10,Font=Enum.Font.GothamBlack,Parent=addW}).MouseButton1Click:Connect(function()
                local k=inp.Text:gsub("%s","")
                if #k<3 then Toast("❌ Key too short!",T.Red); return end
                if CUSTOM_KEYS[k] then Toast("⚠ Key exists: "..k,T.Yellow); return end
                CUSTOM_KEYS[k]={type=ktype}; WriteJ(CKF,CUSTOM_KEYS); inp.Text=""
                Toast("✅ "..ktype:upper().." added: "..k,col)
            end)
        end
        KMSection("Free Key","free",T.Green); KMSection("Lifetime Key","lifetime",T.BlueBr)
        KMSection("Discord Key","discord",T.Discord); KMSection("VIP Key","vip",T.Purple); KMSection("Owner Key","owner",T.Owner)
        Spc(kmGrp,4)
    end

    -- ── BUILD NAV ──
    NavSection("BATTLE")
    NavItem("🎯","Aimbot","aimbot","Detailed Aimbot settings")
    NavItem("⚔","Combat","combat","Kill Aura, Reach & Head TP")
    NavSection("MOVEMENT")
    NavItem("👤","Movement","movement","Speed, Jump & Misc movement")
    NavItem("🚀","Fly","fly","Fly with custom speed")
    NavSection("VISUALS")
    NavItem("👁","ESP","esp","Player ESP & colors")
    NavItem("🌍","World","world","Gravity, Fullbright & FPS Boost")
    NavItem("✨","Visuals","visuals","Black Mode & Third Person")
    NavSection("MISC")
    NavItem("🔧","Settings","settings","Keybinds, colors & key")
    if S.IsOwner then NavItem("👑","Owner","owner","User management & keys") end

    -- Auto-show aimbot tab immediately
    if #NavBtns>0 then
        local nb=NavBtns[1]
        activeNav=nb.page
        nb.bg.BackgroundTransparency=0.2
        nb.bar.Visible=true; nb.bar.BackgroundColor3=AC
        nb.iconLbl.TextColor3=AC; nb.nameLbl.TextColor3=Color3.fromRGB(225,227,255)
        if Pages[nb.page] then Pages[nb.page].Visible=true end
        HdrTitle.Text=nb.label
        HdrSub.Text=nb.subtitle or ("Detailed "..nb.label.." settings")
        HdrIconLbl.Text=nb.icon
    end

    -- Apply states
    DFov.Visible=S.FOVOn; DFov.Radius=S.FOV
    DCrossH.Visible=S.Crosshair; DCrossV.Visible=S.Crosshair
    workspace.Gravity=S.Gravity
    if S.BlackMode then ApplyBlackMode(true) end
    if S.ThirdPerson then ApplyThirdPerson(true,S.ThirdPersonDist) end
    if S.Fly then MFly.Visible=isMob end
    S.Unlocked=true
    pcall(function() LP:SetAttribute("_lh_k",S.KeyType or "?") end)
    pcall(function() LP:SetAttribute("_lh_t",os.time()) end)
    pcall(function() LP:SetAttribute("_lh_n",LP.Name) end)
end

-- ══ PLATFORM SELECTION ══
local function PickPlatform(mobile)
    S.Platform=mobile and "mobile" or "pc"; Save()
    TweenService:Create(PlatBG,TweenInfo.new(0.26),{BackgroundTransparency=1}):Play()
    task.wait(0.3); PlatBG.Visible=false
    BuildMenu(mobile)
end
PCBtn.MouseButton1Click:Connect(function() PickPlatform(false) end)
MobBtn.MouseButton1Click:Connect(function() PickPlatform(true) end)
-- ══ TOGGLE KEY (works even after X close) ══
UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.UserInputType~=Enum.UserInputType.Keyboard then return end
    local kn=input.KeyCode.Name

    -- Head TP hotkey
    if S.Unlocked and kn==S.HeadTPKey then
        pcall(function()
            local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
            local best,bestDist=nil,math.huge
            for _,p in ipairs(Players:GetPlayers()) do
                if p==LP then continue end
                local pc=p.Character; if not pc then continue end
                local ph=pc:FindFirstChild("HumanoidRootPart"); if not ph then continue end
                local hum=pc:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then continue end
                local dist=(myHRP.Position-ph.Position).Magnitude
                if dist<bestDist then bestDist=dist; best=ph end
            end
            if best then myHRP.CFrame=CFrame.new(best.Position+Vector3.new(0,S.HeadTPHeight,0),best.Position)
            else Toast("❌ No enemy found!",T.Red) end
        end)
    end

    -- Menu toggle — ALWAYS reopens even after X
    for _,k in ipairs(S.ToggleKeys) do
        if kn==k then
            if MainFrame then
                MainFrame.Visible=not MainFrame.Visible
                if MainFrame.Visible then
                    -- Slide in from center if was closed
                    MainFrame.Size=UDim2.new(0,menuTW,0,menuTH)
                    MainFrame.Position=UDim2.new(0.5,-menuTW/2,0.5,-menuTH/2)
                end
            end
            break
        end
    end
end)

-- ══ KEY SUBMIT ══
local function ShakeBox()
    for _,dx in ipairs({-11,11,-7,7,-3,3,0}) do
        TweenService:Create(KBox,TweenInfo.new(0.048),{Position=UDim2.new(0.5,dx,0.5,0)}):Play()
        task.wait(0.05)
    end
end

local function Unlock(key,ktype)
    CommitKey(key,ktype); RecordSession()
    TweenService:Create(KBox,TweenInfo.new(0.26,Enum.EasingStyle.Quint,Enum.EasingDirection.In),{Size=UDim2.new(0,460,0,0),Position=UDim2.new(0.5,0,0.5,0)}):Play()
    task.wait(0.3)
    SetBlur(false)
    TweenService:Create(KeyBG,TweenInfo.new(0.26),{BackgroundTransparency=1}):Play()
    task.wait(0.3); KeyBG.Visible=false
    -- Auto-detect platform: check saved preference, else detect touch/gamepad
    if S.Platform then BuildMenu(S.Platform=="mobile"); return end
    local isMobileDevice=UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    S.Platform=isMobileDevice and "mobile" or "pc"; Save()
    BuildMenu(isMobileDevice)
end

local function DoSubmit()
    local status,remaining=ValidateKey(realKey)
    if status=="owner" then
        KStatus.TextColor3=T.Owner; KStatus.Text="👑 Owner access granted!"; task.wait(0.5); Unlock(realKey,"owner")
    elseif status=="vip" then
        KStatus.TextColor3=T.Purple; KStatus.Text="⭐ VIP access granted!"; task.wait(0.5); Unlock(realKey,"vip")
    elseif status=="discord" then
        KStatus.TextColor3=T.Discord; KStatus.Text="💬 Discord access!"; task.wait(0.5); Unlock(realKey,"discord")
    elseif status=="lifetime" then
        KStatus.TextColor3=T.Green; KStatus.Text="💎 Lifetime access!"; task.wait(0.5); Unlock(realKey,"lifetime")
    elseif status=="free_new" then
        KStatus.TextColor3=T.Yellow; KStatus.Text="⏱ Free! "..HMS(remaining or FREE_DUR); task.wait(0.6); Unlock(realKey,"free_new")
    elseif status=="free_active" then
        KStatus.TextColor3=T.Yellow; KStatus.Text="⏱ Active! "..HMS(remaining or 0); task.wait(0.5); Unlock(realKey,"free_active")
    elseif status=="expired" then
        KStatus.TextColor3=T.Red; KStatus.Text=L("expiredKey"); ClearKeyInput(); task.spawn(ShakeBox); task.delay(3,function() KStatus.Text="" end)
    else
        KStatus.TextColor3=T.Red; KStatus.Text=L("wrongKey"); ClearKeyInput(); task.spawn(ShakeBox); task.delay(2.5,function() KStatus.Text="" end)
    end
end
KSub.MouseButton1Click:Connect(DoSubmit)
KReal.FocusLost:Connect(function(enter) if enter then DoSubmit() end end)

-- Auto-unlock if saved key is valid
if S.Key then
    local status=ValidateKey(S.Key)
    if status=="owner" or status=="vip" or status=="discord" or status=="lifetime" or status=="free_new" or status=="free_active" then
        realKey=S.Key; KDots.Text=string.rep("●",#S.Key); KHint.Visible=false
        task.wait(0.5); Unlock(S.Key,S.KeyType or status)
    else
        S.Key=nil; S.KeyType=nil; S.KeyActivated=nil; Save()
    end
end

-- ══ ESP SYSTEM ══
local ESPData={}
local BONES={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},{"UpperTorso","RightUpperArm"},
    {"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
}

local function CleanESP(p)
    local d=ESPData[p]; if not d then return end
    pcall(function() if d.hl then d.hl:Destroy() end end)
    pcall(function() if d.bb then d.bb:Destroy() end end)
    if d.lines then for _,l in ipairs(d.lines) do pcall(function() l:Remove() end) end end
    if d.tracer then pcall(function() d.tracer:Remove() end) end
    if d.box then for _,l in ipairs(d.box) do pcall(function() l:Remove() end) end end
    ESPData[p]=nil
end

local function BuildESP(p)
    CleanESP(p); local char=p.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local d={lines={},box={}}

    -- Color: blue for teammates, enemy color from settings
    local isTeammate=(LP.Team~=nil and p.Team~=nil and LP.Team==p.Team)
    local enemyCol=S.ESPEnemyColor and Color3.fromRGB(S.ESPEnemyColor.r,S.ESPEnemyColor.g,S.ESPEnemyColor.b) or Color3.fromRGB(255,30,30)
    local espFill=isTeammate and Color3.fromRGB(30,80,255) or enemyCol
    local espLine=isTeammate and Color3.fromRGB(100,180,255) or Color3.fromRGB(255,255,255)
    local skelCol=isTeammate and Color3.fromRGB(100,200,255) or Color3.fromRGB(255,230,0)
    local tracCol=isTeammate and Color3.fromRGB(80,160,255) or enemyCol
    local boxCol =isTeammate and Color3.fromRGB(50,120,255) or enemyCol

    -- Highlight
    local hl=Instance.new("Highlight")
    hl.FillColor=espFill
    hl.OutlineColor=espLine
    hl.FillTransparency=0.55
    hl.OutlineTransparency=0
    hl.Adornee=char; hl.Parent=char; d.hl=hl; d.isTeammate=isTeammate

    -- BillboardGui for name + health
    local bb=Instance.new("BillboardGui")
    bb.Size=UDim2.new(0,190,0,52)
    bb.StudsOffset=Vector3.new(0,3.2,0)
    bb.AlwaysOnTop=true
    bb.Adornee=hrp; bb.Parent=char; d.bb=bb

    local nameBG=Instance.new("Frame"); nameBG.Size=UDim2.new(1,0,0,20); nameBG.BackgroundColor3=Color3.fromRGB(0,0,0); nameBG.BackgroundTransparency=0.45; nameBG.BorderSizePixel=0; nameBG.Parent=bb; Round(nameBG,4)
    local nameCol=isTeammate and Color3.fromRGB(100,200,255) or Color3.fromRGB(255,255,255)
    local nl=Label({Text=p.Name,Size=UDim2.new(1,0,1,0),TextColor3=nameCol,TextSize=13,Font=Enum.Font.GothamBlack,TextStrokeTransparency=0.15,TextStrokeColor3=Color3.fromRGB(0,0,0),TextXAlignment=Enum.TextXAlignment.Center,Parent=nameBG}); d.nameLbl=nl

    local hBG=Instance.new("Frame"); hBG.Size=UDim2.new(1,0,0,8); hBG.Position=UDim2.new(0,0,0,22); hBG.BackgroundColor3=Color3.fromRGB(0,0,0); hBG.BackgroundTransparency=0.3; hBG.BorderSizePixel=0; hBG.Parent=bb; Round(hBG,4)
    local hFill=Instance.new("Frame"); hFill.Size=UDim2.new(1,0,1,0); hFill.BackgroundColor3=Color3.fromRGB(80,255,100); hFill.BorderSizePixel=0; hFill.Parent=hBG; Round(hFill,4); d.hFill=hFill
    local hTxt=Label({Text="",Size=UDim2.new(1,0,0,14),Position=UDim2.new(0,0,0,32),TextColor3=Color3.fromRGB(255,255,255),TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center,TextStrokeTransparency=0.2,TextStrokeColor3=Color3.fromRGB(0,0,0),Parent=bb}); d.hTxt=hTxt

    for _=1,#BONES do
        local ln=Drawing.new("Line"); ln.Visible=false; ln.Thickness=1.8
        ln.Color=skelCol; ln.Transparency=0; table.insert(d.lines,ln)
    end

    local tr=Drawing.new("Line"); tr.Visible=false; tr.Thickness=1.2
    tr.Color=tracCol; tr.Transparency=0.08; d.tracer=tr

    for _=1,4 do
        local l=Drawing.new("Line"); l.Visible=false; l.Thickness=2.2
        l.Color=boxCol; l.Transparency=0.0; table.insert(d.box,l)
    end

    ESPData[p]=d
end


local function UpdateESP()
    local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local anyOn=S.ESP or S.ESPNames or S.HealthBar or S.Skeleton or S.Tracers or S.DrawBox
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        local char=p.Character
        local tooFar=false
        if myHRP and char then
            local ph=char:FindFirstChild("HumanoidRootPart")
            if ph and (myHRP.Position-ph.Position).Magnitude>S.MaxDist then tooFar=true end
        end
        if tooFar or not anyOn or not char then
            local d=ESPData[p]; if not d then continue end
            if d.hl then d.hl.Enabled=false end; if d.bb then d.bb.Enabled=false end
            if d.tracer then d.tracer.Visible=false end
            for _,l in ipairs(d.lines) do l.Visible=false end
            for _,l in ipairs(d.box) do l.Visible=false end
            continue
        end
        if not ESPData[p] then BuildESP(p) end
        local d=ESPData[p]; if not d then continue end
        if not char then CleanESP(p); continue end
        local hum=char:FindFirstChildOfClass("Humanoid")
        local hrp=char:FindFirstChild("HumanoidRootPart")
        if d.hl then d.hl.Enabled=S.ESP end
        if d.bb then d.bb.Enabled=(S.ESPNames or S.HealthBar) end
        if d.nameLbl then d.nameLbl.Visible=S.ESPNames end
        if S.HealthBar and hum and d.hFill then
            local pct=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
            d.hFill.Size=UDim2.new(pct,0,1,0)
            d.hFill.BackgroundColor3=pct>0.6 and T.Green or pct>0.3 and T.Orange or T.Red
            if d.hTxt then d.hTxt.Text=math.floor(hum.Health).."/"..math.floor(hum.MaxHealth); d.hTxt.Visible=true end
        elseif d.hTxt then d.hTxt.Visible=false end
        -- Skeleton
        for i,bp in ipairs(BONES) do
            local ln=d.lines[i]; if not ln then continue end
            if not S.Skeleton then ln.Visible=false; continue end
            local b0=char:FindFirstChild(bp[1]); local b1=char:FindFirstChild(bp[2])
            if b0 and b1 then
                local s0,v0=Cam:WorldToViewportPoint(b0.Position)
                local s1,v1=Cam:WorldToViewportPoint(b1.Position)
                if v0 and v1 then ln.From=Vector2.new(s0.X,s0.Y); ln.To=Vector2.new(s1.X,s1.Y); ln.Visible=true
                else ln.Visible=false end
            else ln.Visible=false end
        end
        -- Tracers
        if d.tracer then
            if S.Tracers and hrp then
                local sp,vis=Cam:WorldToViewportPoint(hrp.Position)
                if vis then d.tracer.From=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y-2); d.tracer.To=Vector2.new(sp.X,sp.Y); d.tracer.Visible=true; d.tracer.Transparency=0
                else d.tracer.Visible=false end
            else d.tracer.Visible=false end
        end
        -- Draw Box
        if d.box and #d.box==4 then
            if S.DrawBox and hrp then
                local head=char:FindFirstChild("Head")
                local topPos=(head and head.Position or hrp.Position)+Vector3.new(0,3,0)
                local botPos=hrp.Position-Vector3.new(0,2.8,0)
                local sp1,_=Cam:WorldToViewportPoint(topPos+Vector3.new(-1.4,0,0))
                local sp2,_=Cam:WorldToViewportPoint(topPos+Vector3.new(1.4,0,0))
                local sp3,_=Cam:WorldToViewportPoint(botPos+Vector3.new(-1.4,0,0))
                local sp4,vis=Cam:WorldToViewportPoint(botPos+Vector3.new(1.4,0,0))
                if vis then
                    local tl=Vector2.new(math.min(sp1.X,sp3.X),math.min(sp1.Y,sp2.Y))
                    local tr2=Vector2.new(math.max(sp2.X,sp4.X),math.min(sp1.Y,sp2.Y))
                    local bl=Vector2.new(math.min(sp1.X,sp3.X),math.max(sp3.Y,sp4.Y))
                    local br=Vector2.new(math.max(sp2.X,sp4.X),math.max(sp3.Y,sp4.Y))
                    d.box[1].From=tl; d.box[1].To=tr2; d.box[1].Visible=true
                    d.box[2].From=tr2; d.box[2].To=br; d.box[2].Visible=true
                    d.box[3].From=br; d.box[3].To=bl; d.box[3].Visible=true
                    d.box[4].From=bl; d.box[4].To=tl; d.box[4].Visible=true
                else for _,l in ipairs(d.box) do l.Visible=false end end
            else for _,l in ipairs(d.box) do l.Visible=false end end
        end
    end
    for p in pairs(ESPData) do if not p or not p.Parent then CleanESP(p) end end
end

local function WatchPlayer(p)
    if p==LP then return end
    p.CharacterAdded:Connect(function()
        task.wait(0.8)  -- wait longer so teams are assigned
        CleanESP(p); BuildESP(p)
        -- Also rebuild after 2s in case team is assigned late
        task.delay(2, function() if p and p.Character then CleanESP(p); BuildESP(p) end end)
    end)
    -- Watch for team changes on this specific player
    p:GetPropertyChangedSignal("Team"):Connect(function()
        task.wait(0.1); CleanESP(p)
        if p.Character then BuildESP(p) end
    end)
end
for _,p in ipairs(Players:GetPlayers()) do WatchPlayer(p) end
Players.PlayerAdded:Connect(WatchPlayer)
Players.PlayerRemoving:Connect(CleanESP)

-- ══ TEAM CHECK ══
local function SameTeam(p)
    if not S.TeamCheck then return false end
    -- Only block if BOTH players have a valid non-nil team AND they match
    -- If teams can't be detected → always treat as enemy (aimbot still works)
    local myT=LP.Team; local thT=p.Team
    if myT~=nil and thT~=nil then
        return myT==thT
    end
    -- Fallback: TeamColor — only if not default grey
    local grey=BrickColor.new("Medium stone grey")
    local myC=LP.TeamColor; local thC=p.TeamColor
    if myC~=nil and thC~=nil and myC~=grey and thC~=grey then
        return myC==thC
    end
    -- Can't determine → treat as enemy, never block aimbot
    return false
end

-- Rebuild ESP colors when OUR team changes
LP:GetPropertyChangedSignal("Team"):Connect(function()
    task.wait(0.2)
    for p,_ in pairs(ESPData) do CleanESP(p) end
    task.wait(0.1)
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and p.Character then BuildESP(p) end
    end
end)
-- Also rebuild every 5s in case teams were late-assigned
task.spawn(function()
    while true do
        task.wait(5)
        if not S.Unlocked then continue end
        -- Only rebuild players whose team color is wrong
        for _,p in ipairs(Players:GetPlayers()) do
            if p==LP then continue end
            local d=ESPData[p]; if not d then continue end
            local isTeammate=(LP.Team~=nil and p.Team~=nil and LP.Team==p.Team)
            if d.isTeammate~=isTeammate then
                CleanESP(p)
                if p.Character then BuildESP(p) end
            end
        end
    end
end)

-- ══ LINE OF SIGHT CHECK ══
local function HasLOS(fromPos, toPos)
    -- Build ignore list: our own character + target character
    local ignore={}
    if LP.Character then table.insert(ignore, LP.Character) end
    -- Raycast from our HRP to target
    local dir=toPos-fromPos
    local rp=RaycastParams.new()
    rp.FilterDescendantsInstances=ignore
    rp.FilterType=Enum.RaycastFilterType.Exclude
    local result=workspace:Raycast(fromPos, dir*1.02, rp)
    if not result then return true end -- nothing in the way
    -- Hit something — check if it's the target player's character
    local hitInst=result.Instance
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        if p.Character and hitInst:IsDescendantOf(p.Character) then return true end
    end
    return false -- hit a wall/prop
end

-- ══ GET AIMBOT TARGET ══
local function GetTarget()
    local best,bestDist=nil,math.huge
    local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local center=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y/2)
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or SameTeam(p) then continue end
        local char=p.Character; if not char then continue end
        local hrp=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health<=0 then continue end
        if myHRP and (myHRP.Position-hrp.Position).Magnitude>S.MaxDist then continue end
        local sp,vis=Cam:WorldToViewportPoint(hrp.Position)
        local d=(Vector2.new(sp.X,sp.Y)-center).Magnitude
        if not S.HardLock and d>S.FOV then continue end
        if d<bestDist then bestDist=d; best=p end
    end
    return best
end

-- ══ FOV HIT TARGET ══
local function GetEnemyInFOV()
    local center=Vector2.new(Cam.ViewportSize.X/2,Cam.ViewportSize.Y/2)
    local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local best,bestDist=nil,S.FOV
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP or SameTeam(p) then continue end
        local char=p.Character; if not char then continue end
        local hrp=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health<=0 then continue end
        if myHRP and (myHRP.Position-hrp.Position).Magnitude>S.MaxDist then continue end
        local sp,vis=Cam:WorldToViewportPoint(hrp.Position)
        local d=(Vector2.new(sp.X,sp.Y)-center).Magnitude
        if d<bestDist then bestDist=d; best=p end
    end
    return best
end

-- ══ AUTOSHOOT / FIRE HELPERS ══
local prevAimTarget=nil
local function FireShot()
    pcall(function() if mouse1press then mouse1press() end end)
    pcall(function()
        local char=LP.Character; if not char then return end
        local tool=char:FindFirstChildOfClass("Tool"); if not tool then return end
        local rem=tool:FindFirstChildOfClass("RemoteEvent"); if rem then rem:FireServer() end
        local rem2=tool:FindFirstChild("RemoteEvent"); if rem2 then rem2:FireServer() end
    end)
end
local function ReleaseShot()
    pcall(function() if mouse1release then mouse1release() end end)
end

-- ══ FOV CIRCLE HIT: when enemy in circle, clicking fires tool remote directly at them ══
-- Camera snap alone doesn't work because tools use mouse ray, not camera.
-- Instead: fire the tool's remote event directly with the enemy's aim part as target.
local _silentRestoreCF=nil

UserInputService.InputBegan:Connect(function(input,gp)
    if gp or not S.Unlocked then return end
    local isMB1=input.UserInputType==Enum.UserInputType.MouseButton1
    local isTouch=input.UserInputType==Enum.UserInputType.Touch
    if not isMB1 and not isTouch then return end

    -- FOV circle: if enemy in circle, snap cam + fire remote directly
    if S.FOVOn and not S.Aimbot and not S.HardLock then
        local enemy=GetEnemyInFOV()
        if enemy and enemy.Character and GetAimPartFn then
            local ap=GetAimPartFn(enemy.Character)
            if ap then
                -- Snap camera so raycast-based tools also hit
                _silentRestoreCF=Cam.CFrame
                Cam.CFrame=CFrame.lookAt(Cam.CFrame.Position,ap.Position)
                -- Also fire tool remote directly (covers all weapon types)
                task.defer(function()
                    pcall(function()
                        local char=LP.Character; if not char then return end
                        local tool=char:FindFirstChildOfClass("Tool"); if not tool then return end
                        local ph=enemy.Character:FindFirstChild("HumanoidRootPart")
                        for _,v in ipairs(tool:GetDescendants()) do
                            if v:IsA("RemoteEvent") then
                                pcall(function() v:FireServer(ph,ap.Position,ap) end)
                                pcall(function() v:FireServer(ap.Position) end)
                                pcall(function() v:FireServer() end)
                            end
                        end
                    end)
                end)
            end
        end
    end

    -- Silent Aim: snap camera when shooting
    if S.SilentAim and not S.Aimbot and not S.HardLock then
        local target=GetTarget()
        if target and target.Character and GetAimPartFn then
            local ap=GetAimPartFn(target.Character)
            if ap then
                _silentRestoreCF=Cam.CFrame
                Cam.CFrame=CFrame.lookAt(Cam.CFrame.Position,ap.Position)
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not S.Unlocked then return end
    local isMB1=input.UserInputType==Enum.UserInputType.MouseButton1
    local isTouch=input.UserInputType==Enum.UserInputType.Touch
    if (isMB1 or isTouch) and _silentRestoreCF then
        local saved=_silentRestoreCF; _silentRestoreCF=nil
        task.defer(function()
            if not S.Aimbot and not S.HardLock then Cam.CFrame=saved end
        end)
    end
end)

-- ══ RENDER LOOP ══
local _espFrame=0
RunService.RenderStepped:Connect(function()
    if not S.Unlocked then return end
    local cx=Cam.ViewportSize.X/2; local cy=Cam.ViewportSize.Y/2
    DFov.Position=Vector2.new(cx,cy); DFov.Radius=S.FOV; DFov.Visible=S.FOVOn
    if S.Crosshair then
        local cs=11
        DCrossH.From=Vector2.new(cx-cs,cy); DCrossH.To=Vector2.new(cx+cs,cy); DCrossH.Visible=true
        DCrossV.From=Vector2.new(cx,cy-cs); DCrossV.To=Vector2.new(cx,cy+cs); DCrossV.Visible=true
    else DCrossH.Visible=false; DCrossV.Visible=false end
    _espFrame=_espFrame+1
    -- Always throttle ESP — it's heavy (drawing, world-to-viewport conversions)
    if S.FPSBoost then
        if _espFrame%4==0 then UpdateESP() end
    else
        if _espFrame%2==0 then UpdateESP() end
    end
end)

-- ══ AIMBOT RENDER ══
-- Camera follows target + HRP rotates so weapon visually points at enemy (realistic)
local _aimJitter=0
RunService:BindToRenderStep("_r_a",Enum.RenderPriority.Camera.Value+1,function(dt)
    if not S.Unlocked then return end
    if not S.Aimbot and not S.HardLock then
        if prevAimTarget~=nil then ReleaseShot(); prevAimTarget=nil end
        return
    end
    local target=GetTarget()
    if target and target.Character and GetAimPartFn then
        local ap=GetAimPartFn(target.Character)
        if ap then
            local targetCF=CFrame.lookAt(Cam.CFrame.Position,ap.Position)
            if S.HardLock then
                _aimJitter=(_aimJitter+dt*3)%(math.pi*2)
                local jx=math.sin(_aimJitter)*0.0015
                local jy=math.cos(_aimJitter*1.3)*0.001
                Cam.CFrame=targetCF*CFrame.Angles(jx,jy,0)
            else
                local sm=math.clamp(S.Smoothing/100,0.02,0.98)
                sm=sm*sm*(3-2*sm)
                Cam.CFrame=Cam.CFrame:Lerp(targetCF,sm)
            end
            -- ── Weapon alignment: rotate HRP yaw to match camera so gun faces target ──
            -- This makes it look like you are genuinely aiming at the player.
            -- Only yaw (horizontal) is changed — pitch stays from normal movement.
            pcall(function()
                local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if myHRP then
                    local camLook=Cam.CFrame.LookVector
                    local flatLook=Vector3.new(camLook.X,0,camLook.Z)
                    if flatLook.Magnitude>0.01 then
                        local targetYaw=CFrame.new(myHRP.Position,myHRP.Position+flatLook)
                        myHRP.CFrame=myHRP.CFrame:Lerp(targetYaw,0.25)
                    end
                end
            end)
            -- Autoshoot with LOS check
            if S.Autoshoot then
                local myHRP=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                local los=myHRP and HasLOS(myHRP.Position, ap.Position) or false
                if los and prevAimTarget~=target then
                    FireShot(); prevAimTarget=target
                elseif not los and prevAimTarget==target then
                    ReleaseShot(); prevAimTarget=nil
                end
            end
        end
    else
        if prevAimTarget~=nil then
            if S.Autoshoot then ReleaseShot() end
            prevAimTarget=nil
        end
    end
end)

-- ══ HEARTBEAT ══
local afkT=0; local spinA=0
-- Kill Aura cached remotes (rebuild only when tool changes)
local _kaRemotes={}; local _kaTool=nil
local function CacheKARemotes(tool)
    _kaRemotes={}; _kaTool=tool
    if not tool then return end
    local rem=tool:FindFirstChildOfClass("RemoteEvent")
    if rem then table.insert(_kaRemotes,rem) end
    for _,v in ipairs(tool:GetDescendants()) do
        if v:IsA("RemoteEvent") and v~=rem then table.insert(_kaRemotes,v) end
    end
end
-- NoClip cached parts (rebuild only on character change)
local _ncParts={}; local _ncChar=nil
local function CacheNCParts(char)
    _ncParts={}; _ncChar=char
    for _,p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then table.insert(_ncParts,p) end
    end
end

local _hbTick=0
RunService.Heartbeat:Connect(function(dt)
    if not S.Unlocked then return end
    _hbTick=_hbTick+1
    local char=LP.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end

    -- Speed (every 6 frames ~10x/s, not every frame)
    if _hbTick%6==0 then
        if hum.WalkSpeed~=S.WalkSpeed then hum.WalkSpeed=S.WalkSpeed end
        if hum.JumpPower~=S.JumpPower then hum.JumpPower=S.JumpPower end
    end

    -- Anti AFK (unchanged — rare)
    if S.AntiAFK and tick()-afkT>18 then
        afkT=tick()
        pcall(function()
            local vim=game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true,Enum.KeyCode.W,false,game)
            task.delay(0.1,function() pcall(function() vim:SendKeyEvent(false,Enum.KeyCode.W,false,game) end) end)
        end)
    end

    -- Spin Bot (every frame — needs to be smooth)
    if S.SpinBot then
        spinA=spinA+(S.SpinSpeed*dt*60)
        local hrp=char:FindFirstChild("HumanoidRootPart")
        if hrp then pcall(function() hrp.CFrame=CFrame.new(hrp.Position)*CFrame.Angles(0,math.rad(spinA),0) end) end
    end

    -- Kill Aura (throttled to every 8 frames ~7x/s, cached remotes)
    if S.KillAura and _hbTick%8==0 then
        local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local tool=char:FindFirstChildOfClass("Tool")
        if tool~=_kaTool then CacheKARemotes(tool) end
        if not tool or #_kaRemotes==0 then return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p==LP or SameTeam(p) then continue end
            local pc=p.Character; if not pc then continue end
            local ph=pc:FindFirstChild("HumanoidRootPart"); if not ph then continue end
            local ph2=pc:FindFirstChildOfClass("Humanoid"); if not ph2 or ph2.Health<=0 then continue end
            local origCF=ph.CFrame
            local fakePos=hrp.Position+Vector3.new(math.random(-2,2),0,math.random(-2,2))
            pcall(function() ph.CFrame=CFrame.new(fakePos) end)
            for _,rem in ipairs(_kaRemotes) do
                pcall(function() rem:FireServer(ph) end)
                pcall(function() rem:FireServer() end)
            end
            task.defer(function() pcall(function() ph.CFrame=origCF end) end)
        end
    end

    -- Reach (every 4 frames)
    if S.Reach and _hbTick%4==0 then
        local tool=char:FindFirstChildOfClass("Tool")
        local h=tool and tool:FindFirstChild("Handle")
        if h then pcall(function() h.Size=Vector3.new(S.ReachSize,S.ReachSize,S.ReachSize) end) end
    end
end)

-- ══ STEPPED: NoClip (cached parts, every 3 frames) ══
local _ncTick=0
RunService.Stepped:Connect(function()
    if not S.Unlocked or not S.NoClip then return end
    _ncTick=_ncTick+1; if _ncTick%3~=0 then return end
    local char=LP.Character; if not char then return end
    if char~=_ncChar then CacheNCParts(char) end
    for _,p in ipairs(_ncParts) do
        pcall(function() if p and p.Parent then p.CanCollide=false end end)
    end
end)

-- ══ INFINITE JUMP ══
UserInputService.JumpRequest:Connect(function()
    if not S.Unlocked or not S.InfJump then return end
    local char=LP.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
end)

-- ══ FLY (no BodyVelocity / no PlatformStand — undetected) ══
RunService.RenderStepped:Connect(function()
    if not S.Unlocked or not S.Fly then return end
    local char=LP.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    -- Keep state as Physics (no PlatformStand, no BodyVelocity needed)
    pcall(function()
        local st=hum:GetState()
        if st~=Enum.HumanoidStateType.Physics then
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)
    local dir=Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) or flyState.f then dir=dir+Cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) or flyState.b then dir=dir-Cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) or flyState.l then dir=dir-Cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) or flyState.r then dir=dir+Cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) or flyState.u then dir=dir+Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or flyState.d then dir=dir-Vector3.new(0,1,0) end
    -- Direct velocity on HRP — no extra Instance created, nothing to scan
    pcall(function()
        if dir.Magnitude>0 then
            hrp.AssemblyLinearVelocity=dir.Unit*S.FlySpeed
            -- Align rotation to camera smoothly
            local targetCF=CFrame.new(hrp.Position)*CFrame.Angles(0,(Cam.CFrame*CFrame.Angles(0,0,0)).LookVector:Cross(Vector3.new(0,1,0)).Y>=0 and math.atan2(-Cam.CFrame.LookVector.X,-Cam.CFrame.LookVector.Z) or math.atan2(Cam.CFrame.LookVector.X,Cam.CFrame.LookVector.Z),0)
            hrp.CFrame=hrp.CFrame:Lerp(targetCF,0.18)
        else
            hrp.AssemblyLinearVelocity=Vector3.zero
        end
    end)
end)

print("⚡ LELE HUB "..VER.." LOADED — Keys: "..table.concat(S.ToggleKeys,"/"))

-- ══ LIFETIME KEYS (obfuscated char arrays) ══
;(function()
    local function D(t) local s="" for _,v in ipairs(t) do s=s..string.char(v) end return s end
    local LK={}
    LK[D{108,105,102,101,116,105,109,101,95,50,48,50,54,95,49,48,48,49}]=true
    LK[D{108,105,102,101,116,105,109,101,95,50,48,50,54,95,50,48,52,55}]=true
    LK[D{108,105,102,101,116,105,109,101,95,50,48,50,54,95,51,56,57,50}]=true
    LK[D{108,105,102,101,116,105,109,101,95,50,48,50,54,95,52,52,49,53}]=true
    LK[D{108,105,102,101,116,105,109,101,95,50,48,50,54,95,53,55,54,51}]=true
    LK[D{108,105,102,101,116,105,109,101,95,50,48,50,54,95,54,48,50,56}]=true
    LK[D{108,105,102,101,116,105,109,101,95,50,48,50,54,95,55,51,51,52}]=true
    LK[D{108,105,102,101,116,105,109,101,95,50,48,50,54,95,56,53,57,49}]=true
    LK[D{108,105,102,101,116,105,109,101,95,50,48,50,54,95,57,50,55,48}]=true
    LK[D{108,105,102,101,116,105,109,101,95,50,48,50,54,95,48,56,54,52}]=true
    _LT=function(k) return LK[k]==true end
end)()
