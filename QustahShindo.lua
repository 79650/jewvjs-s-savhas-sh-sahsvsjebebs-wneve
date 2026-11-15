--[[
    Qustāh · Shindo Life  ·  V1.33
    UI: qustah-ui-lib · sadece Shindo Life'ta açılır (GameId kontrolü)

    Sekmeler: Dashboard · Farm · Spin · Combat · Visuals · Player · Teleport · Loadout · Server · Settings
]]

-- Script'i GitHub'a koyarsan raw linkini yaz; boş kalırsa kendi kaynağını kuyruğa ekler.
local SCRIPT_URL = "https://raw.githubusercontent.com/79650/jewvjs-s-savhas-sh-sahsvsjebebs-wneve/refs/heads/main/QustahShindo.lua"

local SOURCE = [============[
local SCRIPT_URL, SELF_SOURCE = ...
local ENV = (getgenv and getgenv()) or _G

if game.GameId ~= 1511883870 then                               -- sadece Shindo Life
	warn("Qustāh Shindo: this game is not Shindo Life, script not loaded")
	return
end
repeat task.wait() until game:IsLoaded()

if ENV.QustahShindoCore and ENV.QustahShindoCore.Unload then
	pcall(ENV.QustahShindoCore.Unload)
end
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/79650/gwanjkcdsjawbdnjascdas-ui-lib/refs/heads/main/qustah-ui-lib/dist/qustah-ui-lib.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------ yerler
local PLACE = {
	MAIN_MENU = 4616652839, MY_HOME = 5451410109, DUNGEON_SELECT = 7524809704, TOURNAMENT = 6602058266,
}
local function placeKind()
	local id = game.PlaceId
	if id == PLACE.MAIN_MENU then return "menu" end
	if id == PLACE.MY_HOME then return "home" end
	if id == PLACE.DUNGEON_SELECT then return "dungeonselect" end
	if id == PLACE.TOURNAMENT then return "tournament" end
	if workspace:FindFirstChild("dungeons") then return "dungeon" end
	if workspace:FindFirstChild("cutscene") then return "eventboss" end
	if workspace:FindFirstChild("bossbattle") then return "bossbattle" end
	return "map"
end
local KIND = placeKind()
local KIND_NAME = {
	menu = "Main menu", home = "My Home", dungeonselect = "Dungeon select", tournament = "Tournament",
	dungeon = "Dungeon", eventboss = "Event boss", bossbattle = "Boss battle", map = "Map",
}
local function placeName() return KIND_NAME[KIND] or "Map" end

local queue = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
local hubQueued = false
local HUB_QUEUE_STOP = "QustahShindoHub.stop"
local RELL_QUEUE_STOP = "QustahShindoRELL.stop"
local function queuePermission(path, allowed)
	if not (isfile and writefile and delfile) then return false end
	return pcall(function()
		if allowed then
			if isfile(path) then delfile(path) end
		else
			writefile(path, "1")
		end
	end)
end
local function guardQueue(path, code)
	return ("if not isfile or isfile(%q) then return end\n%s"):format(path, code)
end
local function queueHub()                                       -- teleporttan sonra hub kendini tekrar açar
	if not queue or not (isfile and writefile and delfile) then return end
	if not queuePermission(HUB_QUEUE_STOP, true) or hubQueued then return end
	local code = SCRIPT_URL ~= "" and ("loadstring(game:HttpGet(%q, true))()"):format(SCRIPT_URL)
		or ("local s = %q\nloadstring(s)(%q, s)"):format(SELF_SOURCE, SCRIPT_URL)
	local ok, result = pcall(queue, guardQueue(HUB_QUEUE_STOP, code))
	hubQueued = ok and result ~= false
end

------------------------------------------------------------------ ortak yardımcılar
local function statz() return LocalPlayer:FindFirstChild("statz") end
local function mainGui() return LocalPlayer.PlayerGui:FindFirstChild("Main") end
local function character() return LocalPlayer.Character end
local function rootPart() local c = character() return c and c:FindFirstChild("HumanoidRootPart") end
local function fire(...)                                         -- startevent: spin, claim, teleport...
	local ev = LocalPlayer:FindFirstChild("startevent")
	if ev then ev:FireServer(...) end
end
local function combat(...)                                       -- karakterin combat remote'u: tuşlar, m1
	local c = character()
	local u = c and c:FindFirstChild("combat") and c.combat:FindFirstChild("update")
	if u then u:FireServer(...) end
end
local function rellCoinOut()                                      -- oyunun "Not Enough RELL Coin." bildirimi
	local n = LocalPlayer.PlayerGui:FindFirstChild("notifui")
	local k = n and n:FindFirstChild("keymove")
	local t = k and k:FindFirstChild("Tex")
	return t ~= nil and t.Text == "Not Enough RELL Coin."
end
local function tpTo(cf)
	local r = rootPart()
	if r and cf then r.CFrame = cf end
end
local function missionUI()
	local m = mainGui()
	return m and m:FindFirstChild("ingame") and m.ingame:FindFirstChild("Missionstory")
end
-- Görev durumu: oyunun kendi "currentmission" değeri (ObjectValue). Görev ekranı bitince kapanmadığı için ona güvenilmez;
-- currentmission yoksa (eski sürüm vb.) yedek olarak görev ekranına bakılır.
local function currentMission()
	local cm = LocalPlayer:FindFirstChild("currentmission")
	if cm and cm:IsA("ObjectValue") then return cm.Value, true end
	return nil, false
end
local function inMission()
	local cur, known = currentMission()
	if known then return cur ~= nil end
	local m = missionUI()
	return m ~= nil and m.Visible and m:FindFirstChild("title") and m.title.Text == "[Objective: Mission]"
end
local function missionInfo(m)                                    -- görev yazısı, tipi, hedef konumu
	local function val(n) local o = m and m:FindFirstChild(n) return o and o.Value end
	local t = val("target")
	local pos
	if typeof(t) == "Instance" and t:IsA("BasePart") then pos = t.Position
	elseif typeof(t) == "Instance" and t:IsA("Model") then pos = t:GetPivot().Position
	elseif typeof(t) == "Vector3" then pos = t end
	local text, objective = val("text"), val("objective")
	return type(text) == "string" and text or nil, type(objective) == "string" and objective or nil, pos
end
local function cancelMission()                                   -- oyunun kendi "!cancel" komutu
	local vc = workspace:FindFirstChild("VC")
	local re = vc and vc:FindFirstChild("RemoteEvent")
	if re then re:FireServer("!cancel") return true end
	return false
end
-- Oyundaki gerçek isimler: alljutsu içindeki her şeyin REALNAME değeri var. Listelerde onu gösterip arkada kod adını kullanırız.
local Names = { code = {}, label = {} }                          -- code[gösterilen] = kod adı, label[kod adı] = gösterilen
local function realName(inst)
	local r = inst and inst:FindFirstChild("REALNAME")
	local v = r and r.Value
	return (type(v) == "string" and v ~= "") and v or nil
end
local function labelFor(code, inst)
	if Names.label[code] then return Names.label[code] end
	local n = realName(inst) or code
	if Names.code[n] and Names.code[n] ~= code then n = n .. " (" .. code .. ")" end   -- aynı isimli iki şey varsa
	Names.label[code], Names.code[n] = n, code
	return n
end
local function toCode(x) return Names.code[x] or x end
local function toLabel(code) return Names.label[code] or code end
local function mapList(list, fn)
	local out = {}
	for _, v in ipairs(type(list) == "table" and list or {}) do out[#out + 1] = fn(v) end
	return out
end
-- anyHealth: canı istemcide 0'lanmış ama sunucuda hâlâ yaşayan mob'ları da say.
-- (Saldırırken canı kendi ekranımızda 0 yapıyoruz; mob gerçekten ölünce Humanoid'i silinir. DogeHub da buna bakıyor.)
local function validNPC(v, anyHealth)
	return v:IsA("Model") and v:FindFirstChild("npctype") and v.Name:lower():find("npc")
		and v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v:FindFirstChild("Head")
		and v.Head.Position.Y > -1000 and (anyHealth or v.Humanoid.Health > 0) and not v:FindFirstChild("fullsusanoo")
end
local function npcs(anyHealth)
	local folder = workspace:FindFirstChild("npc")
	local out = {}
	if folder then
		for _, v in ipairs(folder:GetChildren()) do
			if validNPC(v, anyHealth) then out[#out + 1] = v end
		end
	end
	return out
end
local function susanooNPCs()                                      -- vurulamayan (susanoo'lu) mob var mı
	local folder = workspace:FindFirstChild("npc")
	if not folder then return 0 end
	local n = 0
	for _, v in ipairs(folder:GetChildren()) do
		if v:IsA("Model") and v:FindFirstChild("npctype") and v:FindFirstChild("fullsusanoo") and v:FindFirstChild("Humanoid") then n += 1 end
	end
	return n
end
local function lookAt(pos)
	local cam = workspace.CurrentCamera
	cam.CFrame = CFrame.new(cam.CFrame.Position, pos)
end

local Window, unloadThis
-- Hub'ın kendi döngüleri: kapatınca (Unload) hepsi durur, bir turda hata olursa döngü ölmez, hata Settings › Info'ya düşer.
local HUB = { Running = true, Conns = {}, Err = {}, Cleanup = {} }
local function hubError(tag, err)
	local now = os.clock()
	if HUB.Err[tag] and now - HUB.Err[tag] < 10 then return end    -- aynı yerden 10 sn'de bir rapor
	HUB.Err[tag] = now
	if Window then pcall(function() Window:ReportError(tag, tostring(err)) end) end
end
local function loop(tag, interval, fn)                          -- interval: sayı ya da sayı döndüren fonksiyon
	task.spawn(function()
		while HUB.Running do
			task.wait(type(interval) == "function" and interval() or interval)
			if not HUB.Running then break end
			local ok, err = pcall(fn)
			if not ok then hubError(tag, err) end
		end
	end)
end
local function hubConnect(signal, fn)
	local c = signal:Connect(function(...)
		if not HUB.Running then return end
		local ok, err = pcall(fn, ...)
		if not ok then hubError("Event", err) end
	end)
	HUB.Conns[#HUB.Conns + 1] = c
	return c
end
local function notify(title, content, icon, color)
	if Window then Window:Notify({ Title = title, Content = content, Icon = icon or "bell", Color = color }) end
end
local function setValue(getter, value, label)
	local ok, obj = pcall(getter)
	if ok and obj then
		obj.Value = value
		notify(label, value .. " set", "check")
	else
		notify(label, "Not found here (" .. placeName() .. ")", "triangle-alert", "warning")
	end
end

-- uçmayı önleyen görünmez platform (farm sırasında ayağın altında durur)
local Platform
local platformUsers = 0
local platformFixed                                              -- boss güvenli noktası: platform orada sabit durur
local SafePart                                                   -- boss güvenli bölgesi (istemci tarafı zemin)
local function platformOn()
	platformUsers += 1
	if Platform then return end
	Platform = Instance.new("Part")
	Platform.Anchored, Platform.Transparency, Platform.Size, Platform.CanCollide = true, 1, Vector3.new(6, 1, 6), true
	Platform.Parent = workspace
	task.spawn(function()
		local mine = Platform
		while Platform == mine do                                  -- yeniden kurulursa eski döngü biter
			local r = rootPart()
			if platformFixed then Platform.CFrame = platformFixed
			elseif r then Platform.CFrame = r.CFrame * CFrame.new(0, -3.4, 0) end
			RunService.RenderStepped:Wait()
		end
	end)
end
local function platformOff()
	platformUsers = math.max(platformUsers - 1, 0)
	if platformUsers == 0 and Platform then Platform:Destroy() Platform = nil end
end
local function hubStop()                                         -- Unload: döngüler, eventler, platform
	HUB.Running = false
	queuePermission(HUB_QUEUE_STOP, false)
	queuePermission(RELL_QUEUE_STOP, false)
	for _, fn in ipairs(HUB.Cleanup) do pcall(fn) end
	table.clear(HUB.Cleanup)
	for _, c in ipairs(HUB.Conns) do pcall(function() c:Disconnect() end) end
	table.clear(HUB.Conns)
	platformUsers = 0
	platformFixed = nil
	if Platform then pcall(function() Platform:Destroy() end) Platform = nil end
	if SafePart then pcall(function() SafePart:Destroy() end) SafePart = nil end
end
-- Boss güvenli noktası: görev vericinin konuşma kısmının (scroll'lu kısım) 1000 stud üstü.
-- Boss öldükten sonra görev hemen bitmiyor, susanoo'lu boss'a da vurulamıyor: sıradaki boss'a kadar burada beklenir.
local SAFE_HEIGHT = 1000
local function giverTalkPart(giver)
	local mg = giver and giver:FindFirstChild("missiongiver")
	return mg and mg:FindFirstChild("HumanoidRootPart")
end
-- Güvenli bölge: istemci tarafında 85x85'lik bir zemin. Üstünde serbestçe dolaşırsın (sürekli ışınlama yok);
-- zeminin dışına çıkar ya da düşersen ortasına geri konursun.
local SAFE_SIZE = Vector3.new(85, 2, 85)
-- Kök parçanın ayak tabanına uzaklığı (ayakta dururken). Animasyondaki bacak konumuna bakmak yanıltıyor
-- (QustahInfo: koşarken 3.26, düşerken 2.04 çıktı, gerçek zemin mesafesi 2.88). Bu yüzden rig'in kendi ölçüsü kullanılır:
-- R6: kökün yarısı + bacak boyu (0.96 + 1.92 = 2.88) · R15: HipHeight + kökün yarısı.
local function rootToFeet(c, r)
	local h = c:FindFirstChildOfClass("Humanoid")
	local r15 = h and select(2, pcall(function() return h.RigType == Enum.HumanoidRigType.R15 end)) == true
	if r15 and h.HipHeight > 0 then return h.HipHeight + r.Size.Y / 2 end
	local leg = c:FindFirstChild("Left Leg") or c:FindFirstChild("Right Leg")
	if leg and leg:IsA("BasePart") then return r.Size.Y / 2 + leg.Size.Y end
	return r.Size.Y / 2 + 2
end
local function safeStandCF(part)                                  -- zeminin tam üstü (+0.15 pay), içine girmeden
	local c, r = character(), rootPart()
	local up = part.Size.Y / 2 + 0.15 + ((c and r) and rootToFeet(c, r) or 3)
	return part.CFrame * CFrame.new(0, up, 0)
end
-- Oyunun kendi zemini: oyunun hareket sistemi (wallwalk / tree jump / waterwalk) yeri workspace.map'teki parçalara bakarak
-- buluyor olabilir; bizim parça workspace'in kökünde, Default collision grubundayken karakter partın içine gömülüyordu.
-- Bu yüzden güvenli zemin, haritadaki gerçek bir zemin parçasından kopyalanır ve onun yanına (workspace.map) konur.
local function mapGroundTemplate()
	local r, c = rootPart(), character()
	if r then                                                     -- önce ayağının altındaki parça
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { c, SafePart, Platform }
		local hit = workspace:Raycast(r.Position, Vector3.new(0, -60, 0), params)
		local p = hit and hit.Instance
		if p and p:IsA("Part") and p.Anchored and p.CanCollide and p.Parent and p.Parent ~= workspace.CurrentCamera then return p end
	end
	local map = workspace:FindFirstChild("map")                  -- yoksa haritadan düz, büyükçe bir parça
	if map then
		for _, p in ipairs(map:GetChildren()) do
			if p:IsA("Part") and p.Anchored and p.CanCollide and p.Size.X >= 8 and p.Size.Z >= 8 then return p end
		end
	end
end
local function safePartAt(cf)
	if not SafePart or not SafePart.Parent then
		local tpl = mapGroundTemplate()
		local ok, clone = pcall(function() return tpl and tpl:Clone() end)
		SafePart = (ok and clone) or Instance.new("Part")
		pcall(function() SafePart:ClearAllChildren() end)           -- doku, script vb. kopyalanmasın
		SafePart.Name = "QustahSafe"
		SafePart.Anchored, SafePart.CanCollide, SafePart.Size = true, true, SAFE_SIZE
		pcall(function() SafePart.CanQuery, SafePart.CanTouch = true, true end)
		pcall(function() SafePart.Shape = Enum.PartType.Block end)
		SafePart.Transparency = 0.6
		if not (ok and clone) then
			SafePart.Material = Enum.Material.Plastic
			SafePart.Color = Color3.fromRGB(120, 125, 140)
		end
		SafePart.CFrame = cf
		local map = workspace:FindFirstChild("map")
		SafePart.Parent = (tpl and tpl.Parent and tpl.Parent ~= workspace.CurrentCamera and tpl.Parent) or map or workspace
	end
	if SafePart.CFrame ~= cf then SafePart.CFrame = cf end
	return SafePart
end
local function onSafePart(r, part)                               -- zeminin üstünde mi (biraz zıplama payıyla)
	local rel = part.CFrame:PointToObjectSpace(r.Position)
	return math.abs(rel.X) <= part.Size.X / 2 + 1 and math.abs(rel.Z) <= part.Size.Z / 2 + 1 and rel.Y > -1 and rel.Y < 60
end
local function goSafe(giver)
	local talk = giverTalkPart(giver)
	if not talk then return false end
	local part = safePartAt(CFrame.new(talk.Position + Vector3.new(0, SAFE_HEIGHT, 0)))
	platformFixed = part.CFrame * CFrame.new(0, -12, 0)            -- takip eden platform zeminin altına park edilir (üst üste binip kaydırmasın)
	local r = rootPart()
	if r and not onSafePart(r, part) then tpTo(safeStandCF(part)) r.AssemblyLinearVelocity = Vector3.zero end
	return true
end
local function leaveSafe()
	platformFixed = nil
	if SafePart then SafePart:Destroy() SafePart = nil end
end
-- Kaymayı önle: güvenli zeminde tuşa basmıyorsan yatay hızın sıfırlanır (ışınlanmadan kalan ivme vb.)
hubConnect(RunService.Heartbeat, function()
	if not SafePart then return end
	local c = character()
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not (r and h and onSafePart(r, SafePart)) then return end
	if h.MoveDirection.Magnitude < 0.05 then
		local v = r.AssemblyLinearVelocity
		if math.abs(v.X) + math.abs(v.Z) > 0.1 then r.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0) end
	end
end)

-- bir NPC'ye saldır: üstünde/arkasında dur, kameranı çevir, tuş + m1
local Attack = { Height = 0, Distance = 10, Mode = "Legacy (M1 + E)" }   -- Height / Distance sabit (ayarı yok); Legacy varsayılan açık (DogeHub gibi)
-- Melee / Legacy mesafesi dövüş stiline göre (DogeHub'daki gibi): kısa menzilli stiller 7, diğerleri 10 stud
local SHORT_STYLES = { [""] = true, boxing = true, jeetkunedo = true, muaythai = true, mma = true }
local function meleeDistance()
	local st = LocalPlayer:FindFirstChild("statz")
	local fs = st and st:FindFirstChild("fightingstyle")
	if not fs or SHORT_STYLES[fs.Value] then return 7 end
	return 10
end
local function attackNPC(v)
	local hrp = v:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local ae = v:FindFirstChild("antiexploit")                     -- mob'un korumasını kaldır (NukeVsCity'deki gibi)
	if ae then ae:Destroy() end
	lookAt(hrp.Position)
	if Attack.Mode == "Melee (M1)" then
		tpTo(hrp.CFrame * CFrame.new(0, 0, meleeDistance()))
		combat("mouse1", true)
	elseif Attack.Mode == "Legacy (M1 + E)" then                -- yakında dur, hem M1 hem E
		tpTo(hrp.CFrame * CFrame.new(0, 0, meleeDistance()))
		combat("mouse1", true)
		combat("key", "e") combat("key", "eend")
	else
		tpTo(hrp.CFrame * CFrame.new(0, Attack.Height, Attack.Distance))
		for _ = 1, 3 do combat("key", "e") combat("key", "eend") end
	end
	pcall(function() v.Humanoid.Health = 0 end)                -- DogeHub'daki gibi, istemci tarafı
end

------------------------------------------------------------------ PENCERE
Window = Lib:CreateWindow({
	Title = "Qustāh",
	Version = "V1.33",
	Folder = "QustahShindo",
	Tags = { "SHINDO" },
	ToggleKey = Enum.KeyCode.RightShift,
	Size = Vector2.new(600, 440),
	OnClose = function() if unloadThis then unloadThis() end end,
})

Window:DashboardTab({ Info = {
	{ "Konum", placeName() },
	{ "Spin", tostring(statz() and statz():FindFirstChild("spins") and statz().spins.Value or "-") },
	{ "Rank", tostring(statz() and statz():FindFirstChild("prestige") and statz().prestige:FindFirstChild("rank") and statz().prestige.rank.Value or "-") },
	{ "queue_on_teleport", queue and "Yes" or "No" },
} })

local Tabs = {
	Farm = Window:Tab({ Title = "Farm", Icon = "swords" }),
	Spin = Window:Tab({ Title = "Spin", Icon = "dices" }),
	Combat = Window:Tab({ Title = "Combat", Icon = "crosshair" }),
	Visuals = Window:Tab({ Title = "Visuals", Icon = "eye" }),
	Player = Window:Tab({ Title = "Player", Icon = "person-standing" }),
	Teleport = Window:Tab({ Title = "Teleport", Icon = "map-pin" }),
	Loadout = Window:Tab({ Title = "Loadout", Icon = "dna" }),
	Server = Window:Tab({ Title = "Server", Icon = "server" }),
}

if KIND == "tournament" then
	Window:Notify({ Title = "Tournament", Content = "You are in tournament mode. Exploiting here can easily get you banned.", Icon = "triangle-alert", Color = "warning" })
end

------------------------------------------------------------------ UNIVERSAL (Silent Aim · ESP · World · Player · Server)
do
------------------------------------------------------------------------ servisler
local function service(name)
    local s = game:GetService(name)
    return (cloneref and cloneref(s)) or s
end
local Players = service("Players")
local RunService = service("RunService")
local UserInputService = service("UserInputService")
local Workspace = service("Workspace")
local Lighting = service("Lighting")
local TeleportService = service("TeleportService")
local HttpService = service("HttpService")
local VirtualUser = service("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera
-- Hook'ta karşılaştırma için gerçek referans: cloneref kopyası oyunun workspace'ine == ile eşit sayılmaz
local RealWorkspace = workspace
local FindFirstChild = game.FindFirstChild                      -- hook içinde namecall yapmamak için düz çağrı

local ENV = (getgenv and getgenv()) or _G

local Running = true
local Connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    Connections[#Connections + 1] = c
    return c
end

local newcclosure = newcclosure or function(f) return f end
local V2, V3, CF, C3 = Vector2.new, Vector3.new, CFrame.new, Color3.new
local floor, clamp, max, min, rad, tan = math.floor, math.clamp, math.max, math.min, math.rad, math.tan
local BLACK, WHITE = C3(0, 0, 0), C3(1, 1, 1)

------------------------------------------------------------------------ ayarlar (UI callback'leri doldurur)
local S = {
    -- silent aim
    SA_Enabled = false, SA_HitChance = 100, SA_Part = "Head", SA_Priority = "Mouse",
    SA_Methods = { Raycast = true, FindPartOnRay = true, ["Mouse.Hit"] = true },
    SA_TeamCheck = false, SA_VisCheck = false, SA_IgnoreFriends = false, SA_MaxDist = 1000, SA_SafeOrigin = true,
    SA_Predict = false, SA_PredStrength = 100, SA_Whitelist = {},
    -- fov
    FOV_Show = true, FOV_Radius = 120, FOV_Sides = 64, FOV_Thick = 1, FOV_Color = C3(1, 1, 1), FOV_Alpha = 0,
    FOV_Filled = false, FOV_Origin = "Mouse", FOV_TargetLine = false,
    -- esp
    ESP_Enabled = false, ESP_TeamCheck = true, ESP_MaxDist = 1500,
    Box = true, BoxStyle = "Corner", BoxCorner = 30, BoxFill = false, BoxFillAlpha = 0.85, HealthBar = true, Outline = true,
    Name = true, DisplayName = true, HealthText = true, Distance = true, DistUnit = "Studs", Weapon = true, TextSize = 13,
    Chams = false, ChamsWalls = true, ChamsFill = 0.6, ChamsOutline = C3(1, 1, 1),
    Tracer = false, TracerFrom = "Bottom", Skeleton = false, LookDir = false, HeadDot = false,
    Arrows = false, ArrowRadius = 150, ArrowSize = 14,
    ColEnemy = C3(1, 0.23, 0.23), ColAlly = C3(0.23, 1, 0.42), ColHidden = C3(1, 0.69, 0.23), ColTarget = C3(0.75, 0.45, 1),
    UseTeamColor = false, VisColor = true, Fade = true, Perf = false,
    -- world
    Fullbright = false, NoFog = false, CustomTime = false, ClockTime = 14, NoShadows = false,
    CustomAmbient = false, Ambient = C3(0.7, 0.7, 0.7),
    -- player
    SpeedOn = false, WalkSpeed = 16, JumpOn = false, JumpPower = 50, InfJump = false,
    Fly = false, FlySpeed = 60, NoClip = false, AntiAfk = true, ClickTP = false,
    CamFOV = 70, OverrideFOV = false, UnlockZoom = false,
    -- server
    StaffAlert = false, StaffGroup = 0, StaffRank = 1, StaffAction = "Notify", AutoRejoin = false,
}
local function set(key) return function(v) S[key] = v end end
local function toSet(list)
    local out = {}
    for _, v in ipairs(type(list) == "table" and list or {}) do out[v] = true end
    return out
end

------------------------------------------------------------------------ Render: Roblox GUI
local function guiParent()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    local ok2, core = pcall(function() return service("CoreGui") end)
    if ok2 and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local Overlay = Instance.new("ScreenGui")
Overlay.Name = HttpService:GenerateGUID(false)
Overlay.IgnoreGuiInset = true
Overlay.ResetOnSpawn = false
Overlay.DisplayOrder = 999
Overlay.ZIndexBehavior = Enum.ZIndexBehavior.Global
pcall(function() if protectgui then protectgui(Overlay) elseif syn and syn.protect_gui then syn.protect_gui(Overlay) end end)
Overlay.Parent = guiParent()

local HighlightFolder = Instance.new("Folder")
HighlightFolder.Name = "h"
HighlightFolder.Parent = Overlay

local Render = { Mode = "GUI" }

-- Çizim özelliklerinde Transparency = opaklık (1 = tam görünür).
local Shim, Dirty = {}, {}
local function frame(props)
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    f.AnchorPoint = V2(0.5, 0.5)
    f.Visible = false
    for k, v in pairs(props or {}) do f[k] = v end
    f.Parent = Overlay
    return f
end
local function placeLine(f, a, b, p)
    local d = b - a
    f.Size = UDim2.fromOffset(d.Magnitude, p.Thickness or 1)
    f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    f.Rotation = math.deg(math.atan2(d.Y, d.X))
    f.BackgroundColor3 = p.Color
    f.BackgroundTransparency = 1 - (p.Transparency or 1)
    f.ZIndex = (p.ZIndex or 1) + 1
    f.Visible = true
end
local Apply = {
    Line = function(o, p)
        if not p.Visible then o.f.Visible = false return end
        placeLine(o.f, p.From or Vector2.zero, p.To or Vector2.zero, p)
    end,
    Square = function(o, p)
        local f = o.f
        f.Visible = p.Visible
        if not p.Visible then return end
        f.AnchorPoint = Vector2.zero
        f.Position = UDim2.fromOffset((p.Position or Vector2.zero).X, (p.Position or Vector2.zero).Y)
        f.Size = UDim2.fromOffset((p.Size or Vector2.zero).X, (p.Size or Vector2.zero).Y)
        f.BackgroundColor3 = p.Color
        f.BackgroundTransparency = p.Filled and (1 - (p.Transparency or 1)) or 1
        o.stroke.Enabled = not p.Filled
        o.stroke.Color = p.Color
        o.stroke.Thickness = p.Thickness or 1
        o.stroke.Transparency = 1 - (p.Transparency or 1)
        f.ZIndex = (p.ZIndex or 1) + 1
    end,
    Circle = function(o, p)
        local n = math.clamp(math.floor(p.NumSides or 64), 3, 64)
        if not p.Visible then
            o.f.Visible = false
            for _, f in ipairs(o.edges or {}) do f.Visible = false end
            return
        end
        local r, center = p.Radius or 1, p.Position or Vector2.zero
        o.f.Visible = p.Filled == true
        if o.f.Visible then
            o.f.Size = UDim2.fromOffset(r * 2, r * 2)
            o.f.Position = UDim2.fromOffset(center.X, center.Y)
            o.f.BackgroundColor3 = p.Color
            o.f.BackgroundTransparency = 1 - (p.Transparency or 1)
            o.f.ZIndex = (p.ZIndex or 1) + 1
        end
        local edges = o.edges or {}
        rawset(o, "edges", edges)
        for i, f in ipairs(edges) do
            if i > n or p.Filled or n == 64 then f.Visible = false end
        end
        if not p.Filled and n == 64 then
            o.f.Visible = true
            o.f.Size = UDim2.fromOffset(r * 2, r * 2)
            o.f.Position = UDim2.fromOffset(center.X, center.Y)
            o.f.BackgroundTransparency = 1
            o.f.ZIndex = (p.ZIndex or 1) + 1
            o.stroke.Enabled = true
            o.stroke.Color = p.Color
            o.stroke.Thickness = p.Thickness or 1
            o.stroke.Transparency = 1 - (p.Transparency or 1)
        elseif p.Filled then
            o.stroke.Enabled = false
        else
            local step = 2 * math.pi / n
            for i = 1, n do
                edges[i] = edges[i] or frame()
                local a, b = (i - 1) * step, i * step
                placeLine(edges[i], center + V2(math.cos(a), math.sin(a)) * r,
                    center + V2(math.cos(b), math.sin(b)) * r, p)
            end
        end
    end,
    Text = function(o, p)
        local l = o.f
        l.Visible = p.Visible
        if not p.Visible then return end
        l.Text = p.Text or ""
        l.TextSize = p.Size or 13
        l.TextColor3 = p.Color
        l.TextTransparency = 1 - (p.Transparency or 1)
        l.TextStrokeTransparency = p.Outline and (1 - (p.Transparency or 1)) * 0.6 + 0.4 or 1
        l.AnchorPoint = p.Center and V2(0.5, 0) or Vector2.zero
        local b = l.TextBounds
        l.Size = UDim2.fromOffset(b.X, b.Y)
        l.Position = UDim2.fromOffset((p.Position or Vector2.zero).X, (p.Position or Vector2.zero).Y)
        l.ZIndex = (p.ZIndex or 1) + 1
    end,
    Triangle = function(o, p)
        for _, f in ipairs(o.lines) do f.Visible = false end
        if not p.Visible then return end
        local pts = { p.PointA or Vector2.zero, p.PointB or Vector2.zero, p.PointC or Vector2.zero }
        if not p.Filled then
            for i = 1, 3 do placeLine(o.lines[i], pts[i], pts[i % 3 + 1], p) end
            return
        end
        local base = (pts[1] + pts[3]) / 2
        local span, axis = pts[3] - pts[1], pts[2] - base
        if axis.Magnitude < 1 then return end
        local rows = math.clamp(math.ceil(axis.Magnitude), 1, 60)
        local props = { Thickness = axis.Magnitude / rows + 0.35, Color = p.Color, Transparency = p.Transparency, ZIndex = p.ZIndex }
        for i = 1, rows do
            local t = (i - 0.5) / rows
            local mid = base + axis * t
            local half = span * ((1 - t) / 2)
            o.lines[i] = o.lines[i] or frame()
            placeLine(o.lines[i], mid - half, mid + half, props)
        end
    end,
}
local ShimMeta = {}
ShimMeta.__index = function(self, k)
    if k == "Remove" or k == "Destroy" then return Shim.remove end
    if k == "TextBounds" then return self.kind == "Text" and self.f.TextBounds or Vector2.zero end
    return rawget(self, "p")[k]
end
ShimMeta.__newindex = function(self, k, v)
    local p = rawget(self, "p")
    if p[k] == v then return end
    p[k] = v
    if not rawget(self, "dirty") then
        rawset(self, "dirty", true)
        Dirty[#Dirty + 1] = self
    end
end
function Shim.new(kind)
    local o = { kind = kind, p = { Visible = false, Color = WHITE, Transparency = 1, Thickness = 1, ZIndex = 1 }, dirty = false }
    if kind == "Text" then
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.Code
        l.TextStrokeColor3 = BLACK
        l.Visible = false
        l.Parent = Overlay
        o.f = l
    elseif kind == "Triangle" then
        o.lines = { frame(), frame(), frame() }
    else
        o.f = frame()
        if kind == "Square" or kind == "Circle" then
            o.stroke = Instance.new("UIStroke")
            o.stroke.Parent = o.f
            if kind == "Circle" then
                local c = Instance.new("UICorner")
                c.CornerRadius = UDim.new(1, 0)
                c.Parent = o.f
            end
        end
    end
    return setmetatable(o, ShimMeta)
end
function Shim.remove(o)
    rawset(o, "removed", true)
    if o.edges then for _, f in ipairs(o.edges) do f:Destroy() end end
    if o.f then o.f:Destroy() end
    if o.lines then for _, l in ipairs(o.lines) do l:Destroy() end end
end
function Render.new(kind) return Shim.new(kind) end
function Render.remove(o)
    pcall(function() if o.Remove then o:Remove() else o:Destroy() end end)
end
function Render.flush()
    if #Dirty == 0 then return end
    for i = 1, #Dirty do
        local o = Dirty[i]
        rawset(o, "dirty", false)
        if not rawget(o, "removed") then Render.safe("GUI drawing", Apply[o.kind], o, rawget(o, "p")) end
        Dirty[i] = nil
    end
end

------------------------------------------------------------------------ yardımcılar
local function getCharacter(plr)
    local char = plr and plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return end
    return char, hum, root
end
local function isAlive(hum) return hum and hum.Health > 0 end
local function isTeammate(plr)
    if not plr.Team or not LocalPlayer.Team then return false end
    if plr.Neutral or LocalPlayer.Neutral then return false end
    return plr.Team == LocalPlayer.Team
end
local function toScreen(pos)
    local v, on = Camera:WorldToViewportPoint(pos)
    return V2(v.X, v.Y), on, v.Z
end
local function healthColor(p)
    p = clamp(p, 0, 1)
    if p < 0.5 then return Color3.fromRGB(255, floor(510 * p), 0) end
    return Color3.fromRGB(floor(255 - (p - 0.5) * 510), 255, 0)
end

local FriendCache = {}
local function isFriend(plr)
    local cached = FriendCache[plr.UserId]
    if cached ~= nil then return cached end
    local ok, res = pcall(function() return LocalPlayer:IsFriendsWith(plr.UserId) end)
    FriendCache[plr.UserId] = ok and res or false
    return FriendCache[plr.UserId]
end

-- görünürlük: oyuncu başına saniyede 10 kez raycast (önbellekli)
local VisParams = RaycastParams.new()
VisParams.FilterType = Enum.RaycastFilterType.Exclude
VisParams.IgnoreWater = true
local VisCache = {}
local function isVisible(plr, char, part)
    local now = os.clock()
    local c = VisCache[plr]
    if c and now - c.t < 0.1 then return c.v end
    VisParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    local origin = Camera.CFrame.Position
    local hit = Workspace:Raycast(origin, part.Position - origin, VisParams)
    local visible = (hit == nil) or hit.Instance:IsDescendantOf(char)
    VisCache[plr] = { t = now, v = visible }
    return visible
end

------------------------------------------------------------------------ Silent Aim: hedef seçimi
local Silent = { Target = nil, Hooked = false, IndexHooked = false }
local CanHook = typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" and typeof(checkcaller) == "function"
local RandomPick = {}

local function pickPart(plr, char, mousePos)
    local mode = S.SA_Part
    if mode == "Head" then return char:FindFirstChild("Head") end
    if mode == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
    local parts = {}
    for _, name in ipairs({ "Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso" }) do
        local p = char:FindFirstChild(name)
        if p then parts[#parts + 1] = p end
    end
    if #parts == 0 then return end
    if mode == "Random" then
        local r = RandomPick[plr]
        if not r or os.clock() - r.t > 1 or not r.part.Parent then
            r = { t = os.clock(), part = parts[math.random(1, #parts)] }
            RandomPick[plr] = r
        end
        return r.part
    end
    local best, bestD = nil, math.huge                          -- "Closest": imlece en yakın parça
    for _, p in ipairs(parts) do
        local sp, on = toScreen(p.Position)
        if on then
            local d = (sp - mousePos).Magnitude
            if d < bestD then best, bestD = p, d end
        end
    end
    return best
end

local function fovOrigin()
    if S.FOV_Origin == "Center" then return Camera.ViewportSize / 2 end
    return UserInputService:GetMouseLocation()
end

local function findTarget()
    if not S.SA_Enabled then return nil end
    local origin = fovOrigin()
    local best, bestScore = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not S.SA_Whitelist[plr.UserId] then
            local char, hum, root = getCharacter(plr)
            if char and isAlive(hum) and not (S.SA_TeamCheck and isTeammate(plr)) and not (S.SA_IgnoreFriends and isFriend(plr)) then
                local dist = (root.Position - Camera.CFrame.Position).Magnitude
                if dist <= S.SA_MaxDist then
                    local part = pickPart(plr, char, origin)
                    if part then
                        local sp, on = toScreen(part.Position)
                        local fovDist = (sp - origin).Magnitude
                        if on and fovDist <= S.FOV_Radius and (not S.SA_VisCheck or isVisible(plr, char, part)) then
                            local score = fovDist
                            if S.SA_Priority == "Distance" then score = dist
                            elseif S.SA_Priority == "Health" then score = hum.Health end
                            if score < bestScore then
                                local pos = part.Position
                                if S.SA_Predict and S.SA_PredStrength > 0 then              -- %100 = 1000 stud/s mermi varsayımı
                                    pos = pos + part.AssemblyLinearVelocity * (dist / 1000) * (S.SA_PredStrength / 100)
                                end
                                best, bestScore = { Player = plr, Part = part, Position = pos }, score
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function roll() return math.random(1, 100) <= S.SA_HitChance end
local function fromShooter(origin)                               -- sadece senin silahından çıkan ışınları değiştir
    if not S.SA_SafeOrigin then return true end
    if (origin - Camera.CFrame.Position).Magnitude < 25 then return true end
    -- dikkat: hook'un içinde char:FindFirstChild (namecall) yapılırsa oyunun asıl çağrısı bozulur
    local char = LocalPlayer.Character
    local head = char and FindFirstChild(char, "Head")
    return head ~= nil and (origin - head.Position).Magnitude < 25
end

local setnamecall = setnamecallmethod
local function installNamecallHook()
    if Silent.Hooked or not CanHook then return Silent.Hooked end
    local old
    local function callOld(method, self, ...)                  -- metot adı arada değiştiyse geri koy
        if setnamecall then setnamecall(method) end
        return old(self, ...)
    end
    local wrapper = newcclosure(function(self, ...)
        if Running and S.SA_Enabled and not checkcaller() then
            local t = Silent.Target
            if t then
                local method = getnamecallmethod()
                if self == RealWorkspace then
                    if method == "Raycast" and S.SA_Methods.Raycast then
                        local origin, direction = ...
                        if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" and fromShooter(origin) and roll() then
                            local args = table.pack(...)
                            local to = t.Position - origin
                            args[2] = to.Unit * max(direction.Magnitude, to.Magnitude + 2)
                            return callOld(method, self, table.unpack(args, 1, args.n))
                        end
                    elseif (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist")
                        and S.SA_Methods.FindPartOnRay then
                        local ray = ...
                        if typeof(ray) == "Ray" and fromShooter(ray.Origin) and roll() then
                            local args = table.pack(...)
                            local to = t.Position - ray.Origin
                            args[1] = Ray.new(ray.Origin, to.Unit * max(ray.Direction.Magnitude, to.Magnitude + 2))
                            return callOld(method, self, table.unpack(args, 1, args.n))
                        end
                    end
                elseif self == Camera and (method == "ScreenPointToRay" or method == "ViewportPointToRay")
                    and S.SA_Methods.ScreenPointToRay and roll() then
                    local origin = Camera.CFrame.Position
                    return Ray.new(origin, (t.Position - origin).Unit)
                end
            end
        end
        return old(self, ...)
    end)
    local ok, result = pcall(hookmetamethod, game, "__namecall", wrapper)
    if not ok or type(result) ~= "function" then
        hubError("Silent Aim __namecall", result or "Hook did not return the original function")
        return false
    end
    old = result
    Silent.Hooked = true
    return true
end

local function installIndexHook()                                -- Mouse.Hit / Mouse.Target (sadece seçilince kurulur)
    if Silent.IndexHooked or not CanHook then return Silent.IndexHooked end
    local old
    local wrapper = newcclosure(function(self, key)
        if Running and self == Mouse and S.SA_Enabled and not checkcaller() then
            local t = Silent.Target
            if t then
                if key == "Hit" and S.SA_Methods["Mouse.Hit"] and roll() then return CF(t.Position) end
                if key == "Target" and S.SA_Methods["Mouse.Target"] and roll() then return t.Part end
            end
        end
        return old(self, key)
    end)
    local ok, result = pcall(hookmetamethod, game, "__index", wrapper)
    if not ok or type(result) ~= "function" then
        hubError("Silent Aim __index", result or "Hook did not return the original function")
        return false
    end
    old = result
    Silent.IndexHooked = true
    return true
end

------------------------------------------------------------------------ ESP
local ESP = { Entries = {}, Frame = 0 }
local SKELETON_R15 = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local SKELETON_R6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }

local function entry(plr)
    local e = ESP.Entries[plr]
    if not e then
        e = { Obj = {}, Stamp = {}, Vis = {} }
        ESP.Entries[plr] = e
    end
    return e
end
local function use(e, key, kind)                                 -- objeler ilk ihtiyaçta oluşur
    local o = e.Obj[key]
    if not o then
        o = Render.new(kind)
        e.Obj[key] = o
    end
    e.Stamp[key] = ESP.Frame
    e.Vis[key] = true
    return o
end
-- Bu karede kullanılmayan objeleri gizler. Görünürlüğü kendimiz tutuyoruz: bazı executor'larda Drawing
-- özellikleri okunamıyor (o.Visible hep nil döner), eskiden bu yüzden ekrandan çıkan oyuncunun ESP'si ekranda kalıyordu.
local function hideUnused(e, all)
    for key, o in pairs(e.Obj) do
        if e.Vis[key] and (all or e.Stamp[key] ~= ESP.Frame) then
            e.Vis[key] = false
            pcall(function() o.Visible = false end)
        end
    end
end
local function removeEntry(plr)
    local e = ESP.Entries[plr]
    if not e then return end
    for _, o in pairs(e.Obj) do Render.remove(o) end
    if e.Highlight then e.Highlight:Destroy() end
    ESP.Entries[plr] = nil
    VisCache[plr] = nil
    RandomPick[plr] = nil
end

local function drawLine(e, key, a, b, color, thick, alpha)
    if S.Outline then
        local o = use(e, key .. "_o", "Line")
        o.From, o.To, o.Color, o.Thickness, o.Transparency, o.ZIndex, o.Visible = a, b, BLACK, thick + 2, alpha, 1, true
    end
    local l = use(e, key, "Line")
    l.From, l.To, l.Color, l.Thickness, l.Transparency, l.ZIndex, l.Visible = a, b, color, thick, alpha, 2, true
end
local function drawText(e, key, text, pos, color, size, alpha, center)
    local t = use(e, key, "Text")
    t.Text, t.Position, t.Color, t.Size, t.Transparency, t.Center, t.Outline, t.ZIndex, t.Visible =
        text, pos, color, size, alpha, center, true, 3, true
    return t
end

local function updateChams(e, char, color, show)
    if not show then
        if e.Highlight then e.Highlight.Enabled = false end
        return
    end
    local h = e.Highlight
    if not h or not h.Parent then
        h = Instance.new("Highlight")
        h.Parent = HighlightFolder
        e.Highlight = h
    end
    if h.Adornee ~= char then h.Adornee = char end
    h.FillColor = color
    h.FillTransparency = S.ChamsFill
    h.OutlineColor = S.ChamsOutline
    h.OutlineTransparency = 0
    h.DepthMode = S.ChamsWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
    h.Enabled = true
end

local function updatePlayer(plr)
    local e = entry(plr)
    local char, hum, root = getCharacter(plr)
    if not (S.ESP_Enabled and char and isAlive(hum)) or (S.ESP_TeamCheck and isTeammate(plr)) then
        updateChams(e, nil, nil, false)
        return hideUnused(e)
    end
    local dist = (root.Position - Camera.CFrame.Position).Magnitude
    if dist > S.ESP_MaxDist then
        updateChams(e, nil, nil, false)
        return hideUnused(e)
    end
    if S.Perf and dist > 400 and (ESP.Frame + plr.UserId) % 2 == 1 then   -- uzaktakiler iki karede bir
        for key in pairs(e.Obj) do e.Stamp[key] = ESP.Frame end
        return
    end

    local head = char:FindFirstChild("Head") or root
    local enemy = not isTeammate(plr)
    local color = enemy and S.ColEnemy or S.ColAlly
    if S.UseTeamColor and plr.Team then color = plr.TeamColor.Color end
    local visible = true
    if S.VisColor and enemy then
        visible = isVisible(plr, char, head)
        if not visible then color = S.ColHidden end
    end
    if Silent.Target and Silent.Target.Player == plr then color = S.ColTarget end
    local alpha = S.Fade and clamp(1 - dist / (S.ESP_MaxDist * 1.15), 0.35, 1) or 1

    updateChams(e, char, color, S.Chams)

    local rootScreen, onScreen = toScreen(root.Position)
    if not onScreen then
        if S.Arrows then                                         -- ekran dışı ok
            local rel = Camera.CFrame:PointToObjectSpace(root.Position)
            local dir = V2(rel.X, rel.Z)
            if dir.Magnitude > 0 then
                dir = dir.Unit
                local center = Camera.ViewportSize / 2
                local r, s = S.ArrowRadius, S.ArrowSize
                local perp = V2(-dir.Y, dir.X)
                local base = center + dir * r
                local tri = use(e, "arrow", "Triangle")
                tri.PointA, tri.PointB, tri.PointC = base + perp * (s / 2), center + dir * (r + s * 2), base - perp * (s / 2)
                tri.Color, tri.Filled, tri.Thickness, tri.Transparency, tri.ZIndex, tri.Visible = color, true, 1, alpha, 2, true
            end
        end
        return hideUnused(e)
    end

    -- kutu: kafa üstü ve ayak altı ekrana çevrilir (sabit, aksesuarlardan etkilenmez)
    local top = toScreen(root.Position + V3(0, 2.6, 0))
    local bottom = toScreen(root.Position - V3(0, 3, 0))
    local h = max(bottom.Y - top.Y, 6)
    local w = h * 0.62
    local L, T = floor(rootScreen.X - w / 2), floor(top.Y)
    local R, B = floor(L + w), floor(T + h)

    if S.Box then
        if S.BoxFill then
            local f = use(e, "fill", "Square")
            f.Position, f.Size, f.Color, f.Filled, f.Transparency, f.ZIndex, f.Visible = V2(L, T), V2(R - L, B - T), color, true, (1 - S.BoxFillAlpha) * alpha, 0, true
        end
        local frac = S.BoxStyle == "Full" and 1 or S.BoxCorner / 100
        local cx, cy = (R - L) / 2 * frac, (B - T) / 2 * frac
        drawLine(e, "b1", V2(L, T), V2(L + cx, T), color, 1, alpha)
        drawLine(e, "b2", V2(L, T), V2(L, T + cy), color, 1, alpha)
        drawLine(e, "b3", V2(R, T), V2(R - cx, T), color, 1, alpha)
        drawLine(e, "b4", V2(R, T), V2(R, T + cy), color, 1, alpha)
        drawLine(e, "b5", V2(L, B), V2(L + cx, B), color, 1, alpha)
        drawLine(e, "b6", V2(L, B), V2(L, B - cy), color, 1, alpha)
        drawLine(e, "b7", V2(R, B), V2(R - cx, B), color, 1, alpha)
        drawLine(e, "b8", V2(R, B), V2(R, B - cy), color, 1, alpha)
    end

    local hp = clamp(hum.Health / max(hum.MaxHealth, 1), 0, 1)
    local barX = L - 6
    if S.HealthBar and h >= 18 then
        local bg = use(e, "hb_bg", "Square")
        bg.Position, bg.Size, bg.Color, bg.Filled, bg.Transparency, bg.ZIndex, bg.Visible = V2(barX - 1, T - 1), V2(4, h + 2), BLACK, true, alpha, 1, true
        local bar = use(e, "hb", "Square")
        bar.Position, bar.Size, bar.Color, bar.Filled, bar.Transparency, bar.ZIndex, bar.Visible = V2(barX, T + h * (1 - hp)), V2(2, h * hp), healthColor(hp), true, alpha, 2, true
    end

    local size = S.TextSize
    if S.Name then
        local name = S.DisplayName and plr.DisplayName or plr.Name
        drawText(e, "name", name, V2(rootScreen.X, T - size - 4), color, size, alpha, true)
    end
    if S.HealthText and hp < 1 then                              -- can sayısı barın üst ucunu takip eder
        local txt = tostring(floor(hum.Health + 0.5))
        local t = drawText(e, "hp", txt, V2(0, 0), healthColor(hp), size - 1, alpha, false)
        local okB, bounds = pcall(function() return t.TextBounds end)  -- bazı Drawing'lerde TextBounds yok
        local tw = (okB and typeof(bounds) == "Vector2" and bounds.X > 0) and bounds.X or #txt * (size - 1) * 0.55
        local bx = (S.HealthBar and barX - 3 or L - 3) - tw
        t.Position = V2(bx, clamp(T + h * (1 - hp) - size / 2, T - 2, B - size))
    end
    local bottomLine = {}
    if S.Distance then
        bottomLine[#bottomLine + 1] = S.DistUnit == "Meters" and (floor(dist * 0.28) .. "m") or (floor(dist) .. " studs")
    end
    if S.Weapon then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then bottomLine[#bottomLine + 1] = tool.Name end
    end
    if #bottomLine > 0 then
        drawText(e, "info", table.concat(bottomLine, "  ·  "), V2(rootScreen.X, B + 3), C3(0.87, 0.87, 0.87), size - 1, alpha, true)
    end
    if not visible and S.VisColor then
        drawText(e, "wall", "behind wall", V2(rootScreen.X, B + 4 + size), S.ColHidden, size - 2, alpha * 0.9, true)
    end

    if S.HeadDot then
        local hs = toScreen(head.Position)
        local c = use(e, "head", "Circle")
        c.Position, c.Radius, c.Color, c.Filled, c.NumSides, c.Thickness, c.Transparency, c.ZIndex, c.Visible =
            hs, max(2, h / 22), color, true, 12, 1, alpha, 2, true
    end
    if S.Tracer then
        local vs = Camera.ViewportSize
        local from = S.TracerFrom == "Mouse" and UserInputService:GetMouseLocation()
            or S.TracerFrom == "Center" and vs / 2 or V2(vs.X / 2, vs.Y)
        drawLine(e, "tracer", from, V2(rootScreen.X, B), color, 1, alpha * 0.8)
    end
    if S.LookDir then
        local a = toScreen(head.Position)
        local b = toScreen(head.Position + head.CFrame.LookVector * 4)
        drawLine(e, "look", a, b, color, 1, alpha)
    end
    if S.Skeleton then
        local pairsList = char:FindFirstChild("UpperTorso") and SKELETON_R15 or SKELETON_R6
        for i, pair in ipairs(pairsList) do
            local p1, p2 = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
            if p1 and p2 then
                local a, onA = toScreen(p1.Position)
                local b, onB = toScreen(p2.Position)
                if onA and onB then drawLine(e, "sk" .. i, a, b, color, 1, alpha) end
            end
        end
    end
    hideUnused(e)
end

-- FOV çemberi ve hedef çizgisi (global objeler)
local Global = { Obj = {}, Stamp = {}, Vis = {} }
local function updateGlobal()
    if S.SA_Enabled and S.FOV_Show then
        local c = use(Global, "fov", "Circle")
        c.Position, c.Radius, c.Color, c.NumSides, c.Thickness, c.Filled, c.Transparency, c.ZIndex, c.Visible =
            fovOrigin(), S.FOV_Radius, S.FOV_Color, S.FOV_Sides, S.FOV_Thick, S.FOV_Filled, (1 - S.FOV_Alpha) * (S.FOV_Filled and 0.25 or 1), 4, true
    end
    local t = Silent.Target
    if S.SA_Enabled and S.FOV_TargetLine and t then
        local sp, on = toScreen(t.Position)
        if on then
            local l = use(Global, "tline", "Line")
            l.From, l.To, l.Color, l.Thickness, l.Transparency, l.ZIndex, l.Visible = fovOrigin(), sp, S.ColTarget, 1, 1, 4, true
        end
    end
    hideUnused(Global)
end

------------------------------------------------------------------------ World (Lighting)
local WorldOriginal = {}
local Atmospheres = setmetatable({}, { __mode = "k" })
local function worldProperty(key, wanted)
    if wanted == nil then
        if WorldOriginal[key] ~= nil then
            Lighting[key] = WorldOriginal[key]
            WorldOriginal[key] = nil
        end
    else
        if WorldOriginal[key] == nil then WorldOriginal[key] = Lighting[key] end
        if Lighting[key] ~= wanted then Lighting[key] = wanted end
    end
end
local function fogDensity(on)
    if on then
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then
                if Atmospheres[a] == nil then Atmospheres[a] = a.Density end
                if a.Density ~= 0 then a.Density = 0 end
            end
        end
    else
        for a, d in pairs(Atmospheres) do pcall(function() a.Density = d end) end
        table.clear(Atmospheres)
    end
end
local function restoreWorld()
    for key in pairs(WorldOriginal) do worldProperty(key, nil) end
    fogDensity(false)
end
local brightAmbient = C3(0.7, 0.7, 0.7)
local function updateWorld()
    local ambient = (S.CustomAmbient and S.Ambient) or (S.Fullbright and brightAmbient) or nil
    local shadows
    if S.NoShadows or S.Fullbright then shadows = false end
    worldProperty("Brightness", S.Fullbright and 2 or nil)
    worldProperty("Ambient", ambient)
    worldProperty("OutdoorAmbient", ambient)
    worldProperty("GlobalShadows", shadows)
    worldProperty("ClockTime", S.CustomTime and S.ClockTime or nil)
    worldProperty("FogStart", S.NoFog and 1e6 or nil)
    worldProperty("FogEnd", S.NoFog and 1e6 or nil)
    fogDensity(S.NoFog)
end

------------------------------------------------------------------------ Player (hareket)
local NoClipParts = {}
local function stopNoClip()
    for part, was in pairs(NoClipParts) do
        if part.Parent then part.CanCollide = was end
    end
    table.clear(NoClipParts)
end
local Defaults = setmetatable({}, { __mode = "k" })
local Cameras = setmetatable({}, { __mode = "k" })
local originalZoom
local flyRoot
local function restoreCamera()
    for cam, fov in pairs(Cameras) do cam.FieldOfView = fov end
    table.clear(Cameras)
end
local function restorePlayer()
    for hum, d in pairs(Defaults) do
        if d.WalkSpeed then pcall(function() hum.WalkSpeed = d.WalkSpeed end) end
        if d.JumpPower then pcall(function()
            hum.JumpPower, hum.UseJumpPower = d.JumpPower, d.UseJumpPower
        end) end
    end
    table.clear(Defaults)
    if originalZoom then LocalPlayer.CameraMaxZoomDistance = originalZoom originalZoom = nil end
    if flyRoot and flyRoot.Parent then flyRoot.AssemblyLinearVelocity = Vector3.zero end
    flyRoot = nil
    restoreCamera()
end
HUB.Cleanup[#HUB.Cleanup + 1] = restorePlayer

connect(RunService.Stepped, function()
    if not Running then return end
    local char = LocalPlayer.Character
    if S.NoClip and char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                if NoClipParts[p] == nil then NoClipParts[p] = true end
                p.CanCollide = false
            end
        end
    elseif next(NoClipParts) then
        stopNoClip()
    end
end)

connect(RunService.Heartbeat, function()
    if not Running then return end
    local char, hum, root = getCharacter(LocalPlayer)
    if originalZoom and not S.UnlockZoom then
        LocalPlayer.CameraMaxZoomDistance = originalZoom
        originalZoom = nil
    elseif S.UnlockZoom then
        originalZoom = originalZoom or LocalPlayer.CameraMaxZoomDistance
        LocalPlayer.CameraMaxZoomDistance = 1e4
    end
    if Camera and S.OverrideFOV then
        if Cameras[Camera] == nil then Cameras[Camera] = Camera.FieldOfView end
        if Camera.FieldOfView ~= S.CamFOV then Camera.FieldOfView = S.CamFOV end
    elseif not S.OverrideFOV and next(Cameras) then
        restoreCamera()
    end
    if flyRoot and (not S.Fly or flyRoot ~= root) then
        if flyRoot.Parent then flyRoot.AssemblyLinearVelocity = Vector3.zero end
        flyRoot = nil
    end
    if not char then return end
    local d = Defaults[hum] or {}
    Defaults[hum] = d
    if S.SpeedOn then
        d.WalkSpeed = d.WalkSpeed or hum.WalkSpeed
        hum.WalkSpeed = S.WalkSpeed
    elseif d.WalkSpeed then
        hum.WalkSpeed, d.WalkSpeed = d.WalkSpeed, nil
    end
    if S.JumpOn then
        if d.JumpPower == nil then d.JumpPower, d.UseJumpPower = hum.JumpPower, hum.UseJumpPower end
        hum.UseJumpPower, hum.JumpPower = true, S.JumpPower
    elseif d.JumpPower then
        hum.JumpPower, hum.UseJumpPower = d.JumpPower, d.UseJumpPower
        d.JumpPower, d.UseJumpPower = nil, nil
    end
    if S.Fly and Camera then                                                -- WASD + Space / LeftCtrl, kamera yönünde
        local look = Camera.CFrame
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += look.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= look.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += look.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= look.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += V3(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= V3(0, 1, 0) end
        flyRoot = root
        root.AssemblyLinearVelocity = (move.Magnitude > 0 and move.Unit or Vector3.zero) * S.FlySpeed
    end
end)

connect(UserInputService.JumpRequest, function()
    if not (Running and S.InfJump) then return end
    local _, hum = getCharacter(LocalPlayer)
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

connect(UserInputService.InputBegan, function(input, processed)
    if processed or not (Running and S.ClickTP) then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local _, _, root = getCharacter(LocalPlayer)
        local hit = Mouse.Hit
        if root and hit then root.CFrame = CF(hit.Position + V3(0, 3, 0)) * (root.CFrame - root.CFrame.Position) end
    end
end)

connect(LocalPlayer.Idled, function()
    if not (Running and S.AntiAfk) then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)
end)

-- spectate
local Spectating = nil
local function spectate(plr)
    Spectating = plr
    local _, hum = getCharacter(plr or LocalPlayer)
    if hum and Camera then Camera.CameraSubject = hum end
end

------------------------------------------------------------------------ Server

local function rejoin()
    if #Players:GetPlayers() <= 1 then
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
end
local function fetchServers()
    local list, cursor = {}, nil
    for _ = 1, 3 do
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100%s")
            :format(game.PlaceId, cursor and ("&cursor=" .. cursor) or "")
        local ok, data = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
        if not ok or type(data) ~= "table" or type(data.data) ~= "table" then break end
        for _, s in ipairs(data.data) do
            if s.id ~= game.JobId and (s.playing or 0) < (s.maxPlayers or 0) then list[#list + 1] = s end
        end
        cursor = data.nextPageCursor
        if not cursor then break end
    end
    return list
end
local function serverHop(mode)
    local list = fetchServers()
    if #list == 0 then
        notify("Server hop", "No suitable server found", "server-off", "warning")
        return
    end
    local pick
    if mode == "Smallest" then
        table.sort(list, function(a, b) return (a.playing or 0) < (b.playing or 0) end)
        pick = list[1]
    elseif mode == "Lowest ping" then
        table.sort(list, function(a, b) return (a.ping or 9999) < (b.ping or 9999) end)
        pick = list[1]
    else
        pick = list[math.random(1, #list)]
    end
    notify("Server hop", ("Joining a server with %d/%d players"):format(pick.playing or 0, pick.maxPlayers or 0), "shuffle")
    TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, LocalPlayer)
end

local function checkStaff(plr)
    if not (S.StaffAlert and S.StaffGroup > 0) or plr == LocalPlayer then return end
    task.spawn(function()
        local ok, rank = pcall(function() return plr:GetRankInGroup(S.StaffGroup) end)
        if not (ok and rank and rank >= S.StaffRank) then return end
        notify("Staff in game", ("%s (rank %d) joined the server"):format(plr.Name, rank), "shield-alert", "danger")
        if S.StaffAction == "Hop" then serverHop("Random")
        elseif S.StaffAction == "Leave" then LocalPlayer:Kick("Qustāh: staff joined, left the game") end
    end)
end

------------------------------------------------------------------------ PENCERE
------------------------------------------------------------------------ COMBAT
do
local Combat = Tabs.Combat
local Aim = Combat:Card({ Title = "Silent Aim", Icon = "target", Desc = "Redirects your shots to the target without moving the camera" })
if not CanHook then
    Combat.Pages[1]:Warning("Your executor doesn't support hookmetamethod; Silent Aim won't work.", { Title = "No hook", Level = "danger" })
end
local function refreshAimStatus()
    local m = S.SA_Methods
    local wantsNamecall = m.Raycast or m.FindPartOnRay or m.ScreenPointToRay
    local wantsIndex = m["Mouse.Hit"] or m["Mouse.Target"]
    local active, failed = false, false
    if S.SA_Enabled and CanHook then
        if wantsNamecall then
            local ok = installNamecallHook()
            active, failed = active or ok, failed or not ok
        end
        if wantsIndex then
            local ok = installIndexHook()
            active, failed = active or ok, failed or not ok
        end
    end
    local limited = not CanHook or S.SA_Enabled and (failed or not active)
    Window:SetModule("Silent Aim", limited and "Limited" or (active and "On" or "Off"),
        limited and "Hook unavailable or no method selected" or nil, { Icon = "target", Tab = "Combat" })
end
local saToggle = Aim:Toggle({ Title = "Enabled", Flag = "sa_enabled", Default = false, Bindable = true,
    Callback = function(on)
        S.SA_Enabled = on
        if not on then Silent.Target = nil end
        refreshAimStatus()
    end })
if not CanHook then saToggle:Lock("Executor doesn't support hooks") end
Aim:Slider({ Title = "Hit chance", Flag = "sa_hitchance", Min = 0, Max = 100, Default = 100, Suffix = "%", Callback = set("SA_HitChance") })
Aim:Segment({ Title = "Target part", Flag = "sa_part", Items = { "Head", "Torso", "Random", "Closest" }, Default = "Head", Callback = set("SA_Part") })
Aim:Dropdown({ Title = "Priority", Flag = "sa_priority", Default = "Mouse", Items = {
    { Title = "Mouse", Icon = "mouse-pointer", Desc = "Closest to cursor" },
    { Title = "Distance", Icon = "ruler", Desc = "Closest to you" },
    { Title = "Health", Icon = "heart", Desc = "Lowest health" },
}, Callback = set("SA_Priority") })
Aim:Dropdown({ Title = "Methods", Flag = "sa_methods", Multi = true,
    Help = "The function the game uses when shooting. If it doesn't work, try another one.",
    Items = { "Raycast", "FindPartOnRay", "ScreenPointToRay", "Mouse.Hit", "Mouse.Target" },
    Default = { "Raycast", "FindPartOnRay", "Mouse.Hit" },
    Callback = function(list)
        S.SA_Methods = toSet(list)
        refreshAimStatus()
    end })

local Checks = Combat:Card({ Title = "Checks", Icon = "shield-check", Side = "Right" })
Checks:Toggle({ Title = "Visibility check", Desc = "Don't target players behind walls", Flag = "sa_vischeck", Default = false, Callback = set("SA_VisCheck") })
Checks:Toggle({ Title = "Safe origin", Desc = "Only change shots that come from you", Flag = "sa_safe", Default = true, Callback = set("SA_SafeOrigin") })
Checks:Slider({ Title = "Max distance", Flag = "sa_maxdist", Min = 50, Max = 3000, Default = 1000, Step = 10, Suffix = " studs", Callback = set("SA_MaxDist") })
Checks:Toggle({ Title = "Prediction", Desc = "Aim ahead of moving targets", Flag = "sa_predict", Default = false, Callback = set("SA_Predict") })
Checks:Slider({ Title = "Prediction strength", Flag = "sa_predstr", Min = 0, Max = 300, Default = 100, Step = 5, Suffix = "%", DependsOn = { Flag = "sa_predict", Reason = "" }, Callback = set("SA_PredStrength") })

local FovCard = Combat:Card({ Title = "FOV", Icon = "circle-dashed" })
local fovPreview
local function refreshFov()
    if fovPreview then
        fovPreview:Update({ Radius = S.FOV_Radius, Sides = S.FOV_Sides, Thickness = S.FOV_Thick, Color = S.FOV_Color,
            Transparency = S.FOV_Alpha, Filled = S.FOV_Filled, FillColor = S.FOV_Color, FillTransparency = 0.85, Visible = S.FOV_Show })
    end
end
local function fovSet(key) return function(v) S[key] = v refreshFov() end end
FovCard:Toggle({ Title = "Show FOV", Flag = "fov_show", Default = true, Callback = fovSet("FOV_Show") })
FovCard:Slider({ Title = "Radius", Flag = "fov_radius", Min = 10, Max = 600, Default = 120, Suffix = " px", Callback = fovSet("FOV_Radius") })
FovCard:Slider({ Title = "Sides", Flag = "fov_sides", Min = 3, Max = 64, Default = 64, Callback = fovSet("FOV_Sides") })
FovCard:Slider({ Title = "Thickness", Flag = "fov_thick", Min = 1, Max = 5, Default = 1, Callback = fovSet("FOV_Thick") })
FovCard:ColorPicker({ Title = "Color", Flag = "fov_color", Default = WHITE, Alpha = true, Transparency = 0,
    Callback = function(c, t) S.FOV_Color = c S.FOV_Alpha = t or 0 refreshFov() end })
FovCard:Toggle({ Title = "Filled", Flag = "fov_filled", Default = false, Callback = fovSet("FOV_Filled") })
FovCard:Segment({ Title = "Origin", Flag = "fov_origin", Items = { "Mouse", "Center" }, Default = "Mouse", Callback = set("FOV_Origin") })
FovCard:Toggle({ Title = "Target line", Desc = "Line from FOV center to target", Flag = "fov_tline", Default = false, Callback = set("FOV_TargetLine") })
local PreviewCard = Combat:Card({ Title = "Preview", Icon = "scan", Side = "Right" })
fovPreview = PreviewCard:FovPreview({ Height = 140 })
refreshFov()
end

------------------------------------------------------------------------ VISUALS
do
local Visuals = Tabs.Visuals
local EspPage = Visuals:Page("ESP")
local ExtraPage = Visuals:Page("Extra")
local StylePage = Visuals:Page("Style")

local General = EspPage:Card({ Title = "General", Icon = "scan-eye" })
General:Toggle({ Title = "ESP enabled", Flag = "esp_enabled", Default = false, Bindable = true,
    Callback = function(on)
        S.ESP_Enabled = on
        Window:SetModule("ESP", on and "On" or "Off", Render.Mode == "GUI" and "GUI mode" or nil, { Icon = "eye", Tab = "Visuals" })
    end })
General:Toggle({ Title = "Team check", Desc = "Don't show teammates", Flag = "esp_team", Default = true, Callback = set("ESP_TeamCheck") })
General:Slider({ Title = "Max distance", Flag = "esp_maxdist", Min = 100, Max = 5000, Default = 1500, Step = 50, Suffix = " studs", Callback = set("ESP_MaxDist") })
General:Info({ Title = "Render mode", Value = "Roblox GUI" })

local BoxCard = EspPage:Card({ Title = "Box", Icon = "square-dashed", Side = "Right" })
BoxCard:Toggle({ Title = "Box", Flag = "esp_box", Default = true, Callback = set("Box") })
BoxCard:Segment({ Title = "Style", Flag = "esp_boxstyle", Items = { "Corner", "Full" }, Default = "Corner", Callback = set("BoxStyle") })
BoxCard:Slider({ Title = "Corner size", Flag = "esp_corner", Min = 10, Max = 100, Default = 30, Suffix = "%",
    DependsOn = { Flag = "esp_boxstyle", Value = "Corner", Mode = "Hide", Reason = "" }, Callback = set("BoxCorner") })
BoxCard:Toggle({ Title = "Fill", Flag = "esp_fill", Default = false, Callback = set("BoxFill") })
BoxCard:Slider({ Title = "Fill transparency", Flag = "esp_fillalpha", Min = 0, Max = 100, Default = 85, Suffix = "%", DependsOn = { Flag = "esp_fill", Reason = "" },
    Callback = function(v) S.BoxFillAlpha = v / 100 end })
BoxCard:Toggle({ Title = "Health bar", Flag = "esp_hbar", Default = true, Callback = set("HealthBar") })
BoxCard:Toggle({ Title = "Outline", Flag = "esp_outline", Default = true, Callback = set("Outline") })

local TextCard = EspPage:Card({ Title = "Text", Icon = "type" })
TextCard:Toggle({ Title = "Name", Flag = "esp_name", Default = true, Callback = set("Name") })
TextCard:Toggle({ Title = "Use display name", Flag = "esp_dname", Default = true, DependsOn = { Flag = "esp_name", Reason = "" }, Callback = set("DisplayName") })
TextCard:Toggle({ Title = "Health number", Flag = "esp_hptext", Default = true, Callback = set("HealthText") })
TextCard:Toggle({ Title = "Distance", Flag = "esp_dist", Default = true, Callback = set("Distance") })
TextCard:Segment({ Title = "Unit", Flag = "esp_unit", Items = { "Studs", "Meters" }, Default = "Studs", DependsOn = { Flag = "esp_dist", Reason = "" }, Callback = set("DistUnit") })
TextCard:Toggle({ Title = "Weapon", Desc = "Held tool", Flag = "esp_weapon", Default = true, Callback = set("Weapon") })
TextCard:Slider({ Title = "Text size", Flag = "esp_tsize", Min = 9, Max = 20, Default = 13, Suffix = " px", Callback = set("TextSize") })

local Chams = ExtraPage:Card({ Title = "Chams", Icon = "paint-bucket" })
Chams:Toggle({ Title = "Chams", Desc = "Colors the character", Flag = "esp_chams", Default = false, Callback = set("Chams") })
Chams:Toggle({ Title = "Through walls", Flag = "esp_chamswalls", Default = true, DependsOn = { Flag = "esp_chams", Reason = "" }, Callback = set("ChamsWalls") })
Chams:Slider({ Title = "Fill transparency", Flag = "esp_chamsfill", Min = 0, Max = 100, Default = 60, Suffix = "%", DependsOn = { Flag = "esp_chams", Reason = "" },
    Callback = function(v) S.ChamsFill = v / 100 end })
Chams:ColorPicker({ Title = "Outline color", Flag = "esp_chamsout", Default = WHITE, DependsOn = { Flag = "esp_chams", Reason = "" }, Callback = set("ChamsOutline") })
Chams:Paragraph({ Title = "Note", Content = "Roblox shows at most 31 Highlights at once; in full servers, far players may not be colored." })

local Lines = ExtraPage:Card({ Title = "Lines", Icon = "spline", Side = "Right" })
Lines:Toggle({ Title = "Tracer", Flag = "esp_tracer", Default = false, Callback = set("Tracer") })
Lines:Segment({ Title = "Tracer from", Flag = "esp_tracerfrom", Items = { "Bottom", "Center", "Mouse" }, Default = "Bottom", DependsOn = { Flag = "esp_tracer", Reason = "" }, Callback = set("TracerFrom") })
Lines:Toggle({ Title = "Skeleton", Flag = "esp_skeleton", Default = false, Callback = set("Skeleton") })
Lines:Toggle({ Title = "Look direction", Desc = "Shows where they are looking", Flag = "esp_look", Default = false, Callback = set("LookDir") })
Lines:Toggle({ Title = "Head dot", Flag = "esp_headdot", Default = false, Callback = set("HeadDot") })

local Arrows = ExtraPage:Card({ Title = "Offscreen arrows", Icon = "navigation" })
Arrows:Toggle({ Title = "Arrows", Desc = "Direction of off-screen players", Flag = "esp_arrows", Default = false, Callback = set("Arrows") })
Arrows:Slider({ Title = "Distance from center", Flag = "esp_arrowrad", Min = 80, Max = 300, Default = 150, Suffix = " px", DependsOn = { Flag = "esp_arrows", Reason = "" }, Callback = set("ArrowRadius") })
Arrows:Slider({ Title = "Size", Flag = "esp_arrowsize", Min = 8, Max = 28, Default = 14, Suffix = " px", DependsOn = { Flag = "esp_arrows", Reason = "" }, Callback = set("ArrowSize") })

local Colors = StylePage:Card({ Title = "Colors", Icon = "palette" })
Colors:ColorPicker({ Title = "Enemy", Flag = "col_enemy", Default = S.ColEnemy, Callback = set("ColEnemy") })
Colors:ColorPicker({ Title = "Behind wall", Flag = "col_hidden", Default = S.ColHidden, Callback = set("ColHidden") })
Colors:ColorPicker({ Title = "Silent aim target", Flag = "col_target", Default = S.ColTarget, Callback = set("ColTarget") })
Colors:Toggle({ Title = "Use team color", Flag = "col_team", Default = false, Callback = set("UseTeamColor") })

local Filters = StylePage:Card({ Title = "Filters", Icon = "sliders-horizontal", Side = "Right" })
Filters:Toggle({ Title = "Visibility color", Desc = "Different color behind walls", Flag = "esp_viscolor", Default = true, Callback = set("VisColor") })
Filters:Toggle({ Title = "Fade with distance", Flag = "esp_fade", Default = true, Callback = set("Fade") })
Filters:Toggle({ Title = "Performance mode", Desc = "Draw players 400+ studs away every other frame", Flag = "esp_perf", Default = false, Callback = set("Perf") })

------------------------------------------------------------------------ WORLD
local World = Visuals:Page("World")
local Light = World:Card({ Title = "Lighting", Icon = "lightbulb" })
Light:Toggle({ Title = "Fullbright", Flag = "w_fullbright", Default = false, Callback = set("Fullbright") })
Light:Toggle({ Title = "No fog", Flag = "w_nofog", Default = false, Callback = set("NoFog") })
Light:Toggle({ Title = "No shadows", Flag = "w_noshadows", Default = false, Callback = set("NoShadows") })
local TimeCard = World:Card({ Title = "Time and color", Icon = "clock", Side = "Right" })
TimeCard:Toggle({ Title = "Custom time", Flag = "w_customtime", Default = false, Callback = set("CustomTime") })
TimeCard:Slider({ Title = "Clock time", Flag = "w_clock", Min = 0, Max = 24, Step = 0.5, Default = 14, DependsOn = { Flag = "w_customtime", Reason = "" }, Callback = set("ClockTime") })
TimeCard:Toggle({ Title = "Custom ambient", Flag = "w_customamb", Default = false, Callback = set("CustomAmbient") })
TimeCard:ColorPicker({ Title = "Ambient", Flag = "w_ambient", Default = S.Ambient, DependsOn = { Flag = "w_customamb", Reason = "" }, Callback = set("Ambient") })
TimeCard:Button({ Title = "Restore lighting", Icon = "rotate-ccw", Style = "Ghost", Callback = function()
    for _, flag in ipairs({ "w_fullbright", "w_nofog", "w_noshadows", "w_customtime", "w_customamb" }) do Window:SetFlag(flag, false) end
    restoreWorld()
end })
end

------------------------------------------------------------------------ PLAYER
do
local PlayerTab = Tabs.Player:Page("Movement")
local Move = PlayerTab:Card({ Title = "Movement", Icon = "footprints" })
Move:Toggle({ Title = "Fly", Desc = "WASD + Space / Ctrl", Icon = "plane", Flag = "p_fly", Default = false, Bind = Enum.KeyCode.F, Bindable = true, Callback = set("Fly") })
Move:Slider({ Title = "Fly speed", Flag = "p_flyspeed", Min = 10, Max = 300, Default = 60, DependsOn = { Flag = "p_fly", Reason = "" }, Callback = set("FlySpeed") })
Move:Toggle({ Title = "NoClip", Icon = "ghost", Flag = "p_noclip", Default = false, Bind = Enum.KeyCode.N, Bindable = true, Callback = set("NoClip") })

local Misc = PlayerTab:Card({ Title = "Misc", Icon = "wand-sparkles", Side = "Right" })
Misc:Toggle({ Title = "Anti-AFK", Desc = "Prevents the 20 minute idle kick", Flag = "p_antiafk", Default = true, Callback = set("AntiAfk") })
Misc:Toggle({ Title = "Click TP", Desc = "Ctrl + left click", Flag = "p_clicktp", Default = false, Callback = set("ClickTP") })
Misc:Toggle({ Title = "Override FOV", Flag = "p_camfov_on", Default = false, Callback = set("OverrideFOV") })
Misc:Slider({ Title = "Camera FOV", Flag = "p_camfov", Min = 30, Max = 120, Default = 70,
    DependsOn = { Flag = "p_camfov_on", Reason = "" }, Callback = set("CamFOV") })
Misc:Toggle({ Title = "Unlock zoom", Flag = "p_zoom", Default = false, Callback = set("UnlockZoom") })

local Spec = PlayerTab:Card({ Title = "Spectate", Icon = "video", Side = "Right" })
local specList = Spec:PlayerList({ Title = "Player", Multi = false, Height = 120 })
local specRow = Spec:Row({ Widths = { 2, 1 } })
specRow:Button({ Title = "Spectate", Icon = "eye", Style = "Primary", Callback = function()
    local chosen = specList:GetPlayers()
    if chosen and chosen[1] then spectate(chosen[1]) end
end })
specRow:Button({ Title = "Stop", Icon = "square", Style = "Ghost", Callback = function() spectate(nil) end })
end

------------------------------------------------------------------------ SERVER
-- Düzen C: solda sunucu tarayıcı (doluluk çubuğu + ping + tek tık Join), sağda Seçenekler ve Job ID.
local Server = Tabs.Server
local SrvCard = Server:Card({ Title = "Servers", Icon = "server", Desc = "Pick by player count and ping" })

-- ServerList: lib'de yok, kartın gövdesine elle çiziliyor (tema renklerine bağlı)
local UI_ = Lib.Util
local TH = Lib.Theme
local srvBox = UI_.create("Frame", { Name = "ServerList", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = SrvCard:_order(), Parent = SrvCard.body })
UI_.list(srvBox, 5)
local srvRows, srvCache, srvSort = {}, {}, "Asc"
local SRV_MAX = 8

local function pingLevel(ms)
    if ms < 80 then return 4 elseif ms < 150 then return 3 elseif ms < 250 then return 2 end
    return 1
end
local function myPing()
    local ok, p = pcall(function() return LocalPlayer:GetNetworkPing() * 2000 end)   -- tek yön → gidiş-dönüş
    return ok and floor(p) or 0
end

local function srvRow(order, s, current)
    local row = UI_.create("Frame", { Name = "Server", Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, LayoutOrder = order, Parent = srvBox })
    TH.bind(row, "BackgroundColor3", "input")
    UI_.corner(row, 8)
    TH.bind(UI_.stroke(row), "Color", current and "edge" or "line")
    local id = UI_.label(row, "#" .. string.sub(s.id or "", 1, 6), 10, { Position = UDim2.new(0, 9, 0, 0), Size = UDim2.new(0.2, -4, 1, 0) })
    TH.bind(id, "TextColor3", current and "heading" or "text")
    local pct = (s.maxPlayers or 0) > 0 and math.clamp((s.playing or 0) / s.maxPlayers, 0, 1) or 0
    local bar = UI_.create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.2, 4, 0.5, 0), Size = UDim2.new(0.17, 0, 0, 4), BorderSizePixel = 0, Parent = row })
    TH.bind(bar, "BackgroundColor3", "buttonEdge")
    UI_.corner(bar, 2)
    local fill = UI_.create("Frame", { Size = UDim2.new(pct, 0, 1, 0), BorderSizePixel = 0, Parent = bar })
    TH.bind(fill, "BackgroundColor3", "accent")
    UI_.corner(fill, 2)
    local cnt = UI_.label(row, ("%d/%d"):format(s.playing or 0, s.maxPlayers or 0), 9, { Position = UDim2.new(0.39, 4, 0, 0), Size = UDim2.new(0.12, 0, 1, 0) })
    TH.bind(cnt, "TextColor3", "muted")
    local ms = floor(s.ping or 0)
    local lvl = pingLevel(ms)
    for k = 1, 4 do
        local b = UI_.create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.52, (k - 1) * 4, 0.5, 6), Size = UDim2.fromOffset(2.5, 2 + k * 2), BorderSizePixel = 0, Parent = row })
        TH.bind(b, "BackgroundColor3", k <= lvl and (lvl >= 3 and "success" or "warning") or "buttonEdge")
        UI_.corner(b, 1)
    end
    local pl = UI_.label(row, ms > 0 and (ms .. " ms") or "-", 9, { Position = UDim2.new(0.52, 20, 0, 0), Size = UDim2.new(0.16, 0, 1, 0) })
    TH.bind(pl, "TextColor3", "muted")
    local btn = UI_.create("TextButton", { Text = current and "Rejoin" or "Join", TextSize = 9, Font = Enum.Font.GothamMedium, AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(54, 20), BorderSizePixel = 0, Parent = row })
    TH.bind(btn, "BackgroundColor3", "buttonEdge")
    TH.bind(btn, "TextColor3", "heading")
    UI_.corner(btn, 6)
    btn.MouseEnter:Connect(function() TH.tweenTo(btn, "BackgroundColor3", "hover", 0.1) end)
    btn.MouseLeave:Connect(function() TH.tweenTo(btn, "BackgroundColor3", "buttonEdge", 0.1) end)
    btn.Activated:Connect(function()
        if current then rejoin() return end
        notify("Server", ("Joining a server with %d/%d players"):format(s.playing or 0, s.maxPlayers or 0), "log-in")
        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
    end)
    return { row = row, cnt = cnt, fill = fill, pl = pl }
end

local srvCurrent
local function drawServers()
    for _, r in ipairs(srvRows) do r.row:Destroy() end
    table.clear(srvRows)
    local list = table.clone(srvCache)
    if srvSort == "Smallest" then table.sort(list, function(a, b) return (a.playing or 0) < (b.playing or 0) end)
    elseif srvSort == "Ping" then table.sort(list, function(a, b) return (a.ping or 9999) < (b.ping or 9999) end) end
    for i = 1, math.min(#list, SRV_MAX) do srvRows[#srvRows + 1] = srvRow(10 + i, list[i], false) end
    SrvCard:SetDesc(#srvCache > 0 and ("Servers: %d · %s"):format(#srvCache, srvSort == "Smallest" and "emptiest first" or srvSort == "Ping" and "lowest ping first" or "default order")
        or "No servers found · press Refresh")
end
local srvBusy = false
local function refreshServers()
    if srvBusy then return end
    srvBusy = true
    SrvCard:SetDesc("Loading…")
    task.spawn(function()
        local ok, list = pcall(fetchServers)
        srvCache = ok and list or {}
        pcall(drawServers)
        srvBusy = false
    end)
end
srvCurrent = srvRow(1, { id = game.JobId, playing = #Players:GetPlayers(), maxPlayers = Players.MaxPlayers, ping = myPing() }, true)

local srvBtns = SrvCard:Row()
srvBtns:Button({ Title = "Refresh", Icon = "refresh-cw", Cooldown = 3, Callback = refreshServers })
srvBtns:Button({ Title = "Emptiest", Icon = "shuffle", Callback = function() srvSort = "Smallest" drawServers() end })
srvBtns:Button({ Title = "Lowest ping", Icon = "wifi", Callback = function() srvSort = "Ping" drawServers() end })
SrvCard:Button({ Title = "Random hop", Icon = "shuffle", Style = "Ghost", Cooldown = 5, Callback = function() serverHop("Random") end })
task.delay(1, function() if Running then refreshServers() end end)

-- eski kodun beklediği "Players" bilgisi → artık listedeki "buradasın" satırını günceller
local playersInfo = { Set = function()
    local n, m = #Players:GetPlayers(), Players.MaxPlayers
    srvCurrent.cnt.Text = ("%d/%d"):format(n, m)
    srvCurrent.fill.Size = UDim2.new(m > 0 and n / m or 0, 0, 1, 0)
    local p = myPing()
    srvCurrent.pl.Text = p > 0 and (p .. " ms") or "-"
end }

local Opt = Server:Card({ Title = "Options", Icon = "settings-2", Side = "Right" })
Opt:ListItem({ Title = "Staff alert", Icon = "shield-alert", Toggle = true, Flag = "s_staff", Default = false, Callback = function(on)
    S.StaffAlert = on
    if on then for _, p in ipairs(Players:GetPlayers()) do checkStaff(p) end end
end })
local STAFF_DEP = { Flag = "s_staff", Mode = "Hide", Reason = "" }
Opt:Input({ Title = "Group ID", Placeholder = "game's group ID", Flag = "s_group", Numeric = true, DependsOn = STAFF_DEP,
    Callback = function(text) S.StaffGroup = tonumber(text) or 0 end })
Opt:Slider({ Title = "Min rank", Flag = "s_rank", Min = 1, Max = 255, Default = 1, DependsOn = STAFF_DEP, Callback = set("StaffRank") })
Opt:Segment({ Title = "Action", Flag = "s_action", Items = { "Notify", "Hop", "Leave" }, Default = "Notify", DependsOn = STAFF_DEP, Callback = set("StaffAction") })
Opt:ListItem({ Title = "Auto rejoin on kick", Icon = "refresh-cw", Toggle = true, Flag = "s_autorejoin", Default = false, Callback = set("AutoRejoin") })
Opt:ListItem({ Title = "Re-execute after teleport", Icon = "scroll-text", Toggle = true, Flag = "misc_queue", Default = false,
    Desc = queue and "Hub reopens after teleport" or "Executor doesn't have queue_on_teleport",
    Callback = function(on)
        if on then queueHub() else queuePermission(HUB_QUEUE_STOP, false) end
    end })

local JobCard = Server:Card({ Title = "Job ID", Icon = "hash", Side = "Right" })
JobCard:Info({ Title = "This server", Value = string.sub(game.JobId, 1, 8), Copy = game.JobId })
JobCard:ActionInput({ Icon = "log-in", Placeholder = "Job ID", Button = "Join",
    Validate = function(text) if text == "" then return nil end return #text >= 30, #text >= 30 and "Looks valid" or "Job ID is too short" end,
    Callback = function(jobId) TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer) end })

local PlayersCard = Server:Card({ Title = "Players", Icon = "users", Wide = "Bottom" })
local playerTable = PlayersCard:Table({ Height = 150, Search = true,
    Columns = { "Name", { Title = "Team", Width = 0.22 }, { Title = "HP", Align = "Right", Width = 0.14 }, { Title = "Dist", Align = "Right", Width = 0.16 } },
    Items = {}, SortBy = "Dist",
    OnRowClick = function(row)
        local plr = Players:FindFirstChild(tostring(row[1]))
        if plr then spectate(plr) notify("Spectate", plr.Name .. " izleniyor", "eye") end
    end })

------------------------------------------------------------------------ Settings + açılış
Window:SetModule("ESP", "Off", Render.Mode == "GUI" and "GUI mode" or nil, { Icon = "eye", Tab = "Visuals" })
Window:SetModule("Silent Aim", CanHook and "Off" or "Limited", not CanHook and "no hook" or nil, { Icon = "target", Tab = "Combat" })

Window:OnKick(function()
    if S.AutoRejoin then task.delay(2, function() if Running and S.AutoRejoin then rejoin() end end) end
end)

------------------------------------------------------------------------ döngüler
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    Camera = Workspace.CurrentCamera
end)
connect(Players.PlayerRemoving, function(plr)
    removeEntry(plr)
    FriendCache[plr.UserId] = nil
    if Spectating == plr then spectate(nil) end
end)
connect(Players.PlayerAdded, checkStaff)

-- Her parça kendi pcall'ında: bir oyuncunun ESP'si hata verirse FOV / diğer oyuncular / world donmaz.
-- (Eskiden ESP'deki tek bir hata karenin geri kalanını, FOV çemberi dahil, durduruyordu.)
local function safe(tag, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then hubError(tag, err) end                       -- aynı hatayı 10 sn'de bir raporlar
    return ok
end
Render.safe = safe

connect(RunService.RenderStepped, function()
    if not Running then return end
    ESP.Frame += 1
    if not Camera then Silent.Target = nil return end
    if not safe("Silent Aim", function() Silent.Target = findTarget() end) then Silent.Target = nil end
    safe("FOV", updateGlobal)                                    -- FOV önce: ESP ne olursa olsun çizilir
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not safe("ESP", updatePlayer, plr) then
            local e = ESP.Entries[plr]                           -- yarıda kalan çizim ekranda asılı kalmasın
            if e then hideUnused(e, true) end
        end
    end
    safe("World", updateWorld)
    if Spectating then
        local _, hum = getCharacter(Spectating)
        if hum and Camera.CameraSubject ~= hum then Camera.CameraSubject = hum end
    end
    Render.flush()
end)

task.spawn(function()                                            -- oyuncu tablosu, 2 saniyede bir
    while Running do
        local rows = {}
        local _, _, myRoot = getCharacter(LocalPlayer)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local _, hum, root = getCharacter(plr)
                local dist = (myRoot and root) and floor((root.Position - myRoot.Position).Magnitude) or "-"
                rows[#rows + 1] = { plr.Name, plr.Team and plr.Team.Name or "-", hum and floor(hum.Health) or 0, dist }
            end
        end
        pcall(function()
            playerTable:SetItems(rows)
            playersInfo:Set(#Players:GetPlayers() .. " / " .. Players.MaxPlayers)
        end)
        task.wait(2)
    end
end)

------------------------------------------------------------------------ unload
ENV.QustahShindoCore = {
    Unload = function()
        if not Running then return end
        Running = false
        pcall(hubStop)                                           -- farm / spin / player döngüleri ve platform
        for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
        for plr in pairs(ESP.Entries) do removeEntry(plr) end
        for _, o in pairs(Global.Obj) do Render.remove(o) end
        stopNoClip()
        restoreWorld()
        spectate(nil)
        pcall(function() Overlay:Destroy() end)
        ENV.QustahShindoCore = nil
        pcall(function() Window:Destroy() end)
    end,
}
unloadThis = ENV.QustahShindoCore.Unload
end

------------------------------------------------------------------ FARM
do
	local Farm = Tabs.Farm
	local QuestPage = Farm:Page("Quests")
	local MentorPage = Farm:Page("Mentor")
	local DailyPage = Farm:Page("Daily")

	local F = {
		Scroll = false, Boss = false, Beast = false,
		BossSpecific = false, BossSel = {}, BeastSpecific = false, BeastSel = {},   -- DogeHub gibi: Specific (toplu seçim) / Random
		StuckAfter = 60,                                         -- takılan görevi iptal (ayar yok, scriptin kendi işi)
		Done = { Boss = 0 },                                     -- bu oturumda alınan boss görevleri
		Stats = {}, AutoRank = false, RankAfterMax = false, RankRC = false, RankStop = false, RankStopAt = 500,
		-- Mentor ve Daily ayrı anahtarlar: birini kapatmak ötekini durdurmasın
		PunchM = false, PunchD = false, TreeM = false, TreeD = false, Shoot = false, Rush = false, Chi = false, DailyBoss = false,
	}
	local GREEN_SCROLL = "http://www.roblox.com/asset/?id=5459241648"
	if ENV.QustahShindoCore then ENV.QustahShindoCore.Farm = F end   -- testler için

	local function timerReady(giver)                            -- boss/beast görev vericisinin süresi doldu mu
		local ok, txt = pcall(function() return giver.missiongiver.timer.time.time.Text end)
		return ok and (txt == "00:00" or txt == "59:59")
	end
	local function talkTo(giver)
		local mg = giver:FindFirstChild("missiongiver")
		if not (mg and mg:FindFirstChild("HumanoidRootPart") and mg:FindFirstChild("CLIENTTALK")) then return end
		tpTo(mg.HumanoidRootPart.CFrame + Vector3.new(0, -0.8, 0))
		mg.CLIENTTALK:FireServer(LocalPlayer)
	end
	-- missions klasöründe bütün boss'lar var; sadece bu haritadakilerin içinde "missiongiver" (konuşulan NPC) olur
	local BOSS_FOLDERS = { "bossdropmission", "sengokubossfight" }
	local function bossGivers()
		local out = {}
		for _, folderName in ipairs(BOSS_FOLDERS) do
			local f = workspace:FindFirstChild(folderName)
			local missions = f and f:FindFirstChild("missions")
			if missions then
				for _, g in ipairs(missions:GetChildren()) do
					if g:FindFirstChild("missiongiver") then out[#out + 1] = g end
				end
			end
		end
		return out
	end
	-- Beast (kuyruklu canavar) görevleri: missions klasörü olan diğer klasörler (tailbeastbossmission vb.), DogeHub'daki gibi
	local BEAST_SKIP = { sensei = true, bossdropmission = true, sengokubossfight = true }
	local function beastGivers()
		local out = {}
		for _, f in ipairs(workspace:GetChildren()) do
			local missions = not BEAST_SKIP[f.Name] and f:FindFirstChild("missions")
			if missions then
				for _, g in ipairs(missions:GetChildren()) do
					if g:FindFirstChild("missiongiver") then out[#out + 1] = g end
				end
			end
		end
		return out
	end
	local function names(list)
		local out, seen = {}, {}
		for _, g in ipairs(list) do
			if not seen[g.Name] then seen[g.Name] = true out[#out + 1] = g.Name end
		end
		table.sort(out)
		return out
	end
	local function greenInfo(v)                                       -- yeşil "defeat" vericisi mi, şu an görev veriyor mu
		local gm = v:FindFirstChild("Head") and v.Head:FindFirstChild("givemission")
		local typ = v:FindFirstChild("Talk") and v.Talk:FindFirstChild("typ")
		if not (gm and typ and typ.Value == "defeat" and gm:FindFirstChild("color") and gm.color.Image == GREEN_SCROLL) then return false end
		return true, gm.Enabled and v:FindFirstChild("HumanoidRootPart") ~= nil and v:FindFirstChild("CLIENTTALK") ~= nil
	end
	local function acceptScrollQuest(alive)                          -- yeşil scroll "defeat" görevi al
		local givers = workspace:FindFirstChild("missiongivers")
		if not givers or not alive() then return end
		for _, v in ipairs(givers:GetChildren()) do
			local green, open = greenInfo(v)
			if green and open then
				tpTo(v.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0))
				for _ = 1, 20 do
					if not alive() or inMission() then break end
					v.CLIENTTALK:FireServer()
					v.CLIENTTALK:FireServer("accept")
					task.wait(0.1)
					if inMission() or not alive() then break end
				end
				return true
			end
		end
	end
	local bossGiver                                              -- şu an görevini yaptığımız boss'un vericisi
	local lastGiver                                              -- güvenli nokta için son boss vericisi
	local bossKilled = false                                     -- bu boss görevinde gerçekten bir mob öldürdük mü
	local function giverTaken(g)                                 -- başka biri bu boss'un görevinde mi
		local p = g:FindFirstChild("position")
		local p1 = p and p:FindFirstChild("p1")
		return p1 ~= nil and p1:FindFirstChild("inmission") ~= nil
	end
	local progressAt = os.clock()                               -- son ilerleme (mob öldü / görev başladı)
	local function acceptFrom(list, pick, alive)
		for _, g in ipairs(list) do
			if not alive() or inMission() then return inMission() end
			local wanted = pick == "Random" or (type(pick) == "table" and table.find(pick, g.Name) ~= nil) or g.Name == pick
			if wanted and timerReady(g) and not giverTaken(g) then
				leaveSafe()
				talkTo(g)
				task.wait(1.5)
				if inMission() then bossGiver, lastGiver, bossKilled, progressAt = g, g, false, os.clock() return true end
			end
		end
	end
	-- Sadece bu görevin mob'ları: tipi görev yazısında geçen ve görev noktasına 500 stud içinde olanlar.
	-- Bulunamazsa sırayla gevşetilir (sadece tip → sadece mesafe → boss görevinde hepsi).
	local function missionMobs()
		local all = npcs(true)
		local cur = currentMission()
		if not cur then return all end
		local text, _, pos = missionInfo(cur)
		local function pick(useText, useDist)
			local out = {}
			for _, v in ipairs(all) do
				local nt = v:FindFirstChild("npctype")
				local t = nt and nt:IsA("ValueBase") and nt.Value or nil
				local okText = not useText or (text and type(t) == "string" and t ~= "" and text:find(t, 1, true) ~= nil)
				local okDist = not useDist or (pos and (v.HumanoidRootPart.Position - pos).Magnitude < 500)
				if okText and okDist and t ~= "Sengoku2" then out[#out + 1] = v end
			end
			return out
		end
		local list = (text and pos) and pick(true, true) or {}
		if #list == 0 and text then list = pick(true, false) end
		if #list == 0 and pos then list = pick(false, true) end
		if #list == 0 and bossGiver then list = all end
		return list
	end
	local function killMissionMobs(flagFn)
		local list = missionMobs()
		if #list > 0 then leaveSafe() end
		for _, v in ipairs(list) do
			-- DogeHub gibi: mob'un Humanoid'i silinene (sunucuda ölene) ya da görev bitene kadar vur.
			-- Can'a bakmıyoruz: istemcide 0 yaptığımız için hep "ölü" görünür, boss kesilmeden kaçıyorduk.
			while flagFn() and inMission() and v.Parent and v:FindFirstChild("Humanoid") do
				pcall(attackNPC, v)                                   -- mob tam o an silinirse döngü kopmasın
				task.wait(0.05)
			end
			if not (v.Parent and v:FindFirstChild("Humanoid")) then
				progressAt = os.clock()
				if bossGiver then bossKilled = true end
			end
		end
		-- boss görevi: boss gerçekten öldü ya da susanoo'lu olduğu için vurulamıyor → görev bitene kadar güvenli noktada bekle.
		-- Boss henüz doğmadıysa yerinde bekler (uzaklaşırsak hiç yüklenmeyebilir).
		if bossGiver and flagFn() and inMission() and #missionMobs() == 0 and (bossKilled or susanooNPCs() > 0) then
			goSafe(bossGiver)
		end
	end

	local lastMission
	local function farmAlive()
		return HUB.Running and (F.Scroll or F.Boss or F.Beast or F.DailyBoss)
	end
	local function dailyBossGivers()
		local s = statz()
		local m = s and s:FindFirstChild("mission")
		local bdm = workspace:FindFirstChild("bossdropmission")
		local givers = bdm and bdm:FindFirstChild("missions")
		local list, seen = {}, {}
		if not (m and givers) then return list end
		for _, q in ipairs(m:GetChildren()) do
			local goal = q:FindFirstChild("objective")
			local claimed = q:FindFirstChild("claim")
			if q:IsA("ValueBase") and q.Value == "fightboss" and goal and not (claimed and claimed.Value) then
				local g = givers:FindFirstChild(goal.Value)
				if g and not seen[g] then list[#list + 1], seen[g] = g, true end
			end
		end
		return list
	end
	loop("Auto farm", 0.2, function()
		if not farmAlive() then if SafePart or platformFixed then leaveSafe() end return end   -- farm kapandı: güvenli zemini kaldır
		if KIND ~= "map" or HUB.ScrollBusy then return end
		HUB.FarmBusy = true
		local ok, err = pcall(function()
			local cur = currentMission()
			if cur ~= lastMission then lastMission, progressAt = cur, os.clock() end
			if cur then
				local _, objective = missionInfo(cur)
				if objective and objective ~= "Mission" then          -- farm'ın yapamayacağı görev tipi
					if cancelMission() then notify("Auto farm", "Mission type '" .. objective .. "', cancelled", "circle-x", "warning") end
					task.wait(1)
					return
				end
			end
			if inMission() and F.StuckAfter > 0 and os.clock() - progressAt > F.StuckAfter then   -- takıldı
				if cancelMission() then notify("Auto farm", F.StuckAfter .. "s without progress, mission cancelled", "circle-x", "warning") end
				progressAt = os.clock()
				leaveSafe()
				task.wait(1)
				return
			end
			if inMission() then killMissionMobs(farmAlive) return end
			bossGiver, bossKilled = nil, false                       -- görev bitti
			if F.Beast and acceptFrom(beastGivers(), (F.BeastSpecific and #F.BeastSel > 0 and F.BeastSel) or "Random", function() return HUB.Running and F.Beast end) then
				return
			end
			if F.Boss and acceptFrom(bossGivers(), (F.BossSpecific and #F.BossSel > 0 and F.BossSel) or "Random", function() return HUB.Running and F.Boss end) then
				F.Done.Boss += 1
				return
			end
			if HUB.Running and F.DailyBoss and acceptFrom(dailyBossGivers(), "Random", function() return HUB.Running and F.DailyBoss end) then return end
			if HUB.Running and F.Scroll and not inMission() then
				leaveSafe()
				acceptScrollQuest(function() return HUB.Running and F.Scroll end)
				return
			end
			-- sadece boss farm açık ve hazır boss yok: sıradaki boss'a kadar son boss'un üstünde bekle
			if (F.Boss or F.Beast or F.DailyBoss) and lastGiver and lastGiver.Parent then goSafe(lastGiver) end
		end)
		HUB.FarmBusy = false
		if not farmAlive() then leaveSafe() end
		if not ok then error(err, 0) end
	end)

	-- DogeHub'ın "Quests" sayfası gibi: Auto Farm · Configurations · Boss Farm Settings · Beasts Farm Settings
	local Q = QuestPage:Card({ Title = "Auto Farm", Icon = "scroll-text" })
	local function farmToggle(card, title, key)
		card:Toggle({ Title = title, Flag = "farm_" .. key:lower(), Default = false, Callback = function(on)
			if on ~= F[key] then if on then platformOn() else platformOff() end end
			F[key] = on
		end })
	end
	farmToggle(Q, "Green Scroll Farm", "Scroll")
	farmToggle(Q, "Boss Farm", "Boss")
	farmToggle(Q, "Beasts Farm", "Beast")

	local Conf = QuestPage:Card({ Title = "Configurations", Icon = "sliders-horizontal", Side = "Right" })
	Conf:Toggle({ Title = "Legacy Farm Mode", Flag = "farm_legacy", Default = true, Callback = function(v)
		Attack.Mode = v and "Legacy (M1 + E)" or "Jutsu (E)"
	end })
	Conf:Toggle({ Title = "NPC Kill Aura", Flag = "farm_aura", Default = false, Callback = function(v) HUB.FarmAura = v end })

	-- Specific / Random: biri açılınca öteki kapanır (DogeHub'daki gibi)
	local function pickCard(title, icon, what, list, keySpecific, keySel, flagPrefix)
		local C = QuestPage:Card({ Title = title, Icon = icon })
		C:Toggle({ Title = "Specific " .. what, Flag = flagPrefix .. "specific", Default = false, Callback = function(v)
			F[keySpecific] = v
			if v then Window:SetFlag(flagPrefix .. "random", false) end
		end })
		-- toplu seçim: birden fazla boss işaretlenebilir, sırayla hangisi hazırsa o alınır (hiçbiri seçili değilse Random gibi)
		local dd = C:Dropdown({ Title = "Specific " .. what:lower() .. " to kill", Flag = flagPrefix .. "pick", Items = list, Default = {}, Multi = true,
			AllowNone = true, Search = true, Callback = function(v) F[keySel] = type(v) == "table" and v or { v } end })
		C:Toggle({ Title = "Random " .. what .. (what == "Beast" and "s" or "es"), Flag = flagPrefix .. "random", Default = true, Callback = function(v)
			if v then Window:SetFlag(flagPrefix .. "specific", false) end
		end })
		return C, dd
	end
	local bossList = names(bossGivers())
	local BossSet, bossDD = pickCard("Boss Farm Settings", "skull", "Boss", bossList, "BossSpecific", "BossSel", "farm_boss")
	local bossTotal = 0
	local bossBar = BossSet:Progress({ Title = "Bosses on map", Desc = "Ready to fight", Value = 0, Max = 1,
		Format = function(v) return bossTotal > 0 and ("%d / %d ready"):format(v, bossTotal) or "none" end })
	local sessionRow = BossSet:Info({ Title = "Bosses this session", Value = "0" })
	local beastList = names(beastGivers())
	local _, beastDD = pickCard("Beasts Farm Settings", "flame", "Beast", beastList, "BeastSpecific", "BeastSel", "farm_beast")

	local function refreshList(dd, list, keySel, flag)
		dd:SetItems(list, true)
		local keep = {}                                          -- seçililerden bu haritada olmayanları çıkar
		for _, n in ipairs(F[keySel]) do if table.find(list, n) then keep[#keep + 1] = n end end
		if #keep ~= #F[keySel] then Window:SetFlag(flag, keep) F[keySel] = keep end
	end
	local function refreshBosses()
		refreshList(bossDD, names(bossGivers()), "BossSel", "farm_bosspick")
		refreshList(beastDD, names(beastGivers()), "BeastSel", "farm_beastpick")
	end
	-- boss sayaçları: "hazır / toplam" (hazır = süresi dolmuş, kimse almamış)
	local function updateCounts()
		local bReady, bTotal = 0, 0
		for _, g in ipairs(bossGivers()) do
			bTotal += 1
			if timerReady(g) and not giverTaken(g) then bReady += 1 end
		end
		bossTotal = bTotal
		bossBar:SetMax(math.max(bTotal, 1))
		bossBar:Set(bReady)
		sessionRow:Set(tostring(F.Done.Boss))
	end
	pcall(updateCounts)
	loop("Farm counts", 2, updateCounts)
	-- Boss NPC'leri sonradan yüklenebilir (uzaktakiler): missiongiver gelince / gidince listeler kendiliğinden yenilenir
	local pending = false
	local function queueRefresh(obj)
		if obj.Name ~= "missiongiver" or pending then return end
		pending = true
		task.delay(0.5, function() pending = false if HUB.Running then pcall(refreshBosses) end end)
	end
	local watched = {}
	local function watchBossFolder(f, initial)                     -- boss klasörleri + beast klasörleri (missions'ı olan)
		if watched[f] or BEAST_SKIP[f.Name] and not table.find(BOSS_FOLDERS, f.Name) then return end
		if not (table.find(BOSS_FOLDERS, f.Name) or f:FindFirstChild("missions")) then return end
		watched[f] = true
		hubConnect(f.DescendantAdded, queueRefresh)                  -- missions klasörü de sonradan gelebilir
		hubConnect(f.DescendantRemoving, queueRefresh)
		if not initial then queueRefresh({ Name = "missiongiver" }) end
	end
	for _, f in ipairs(workspace:GetChildren()) do watchBossFolder(f, true) end
	hubConnect(workspace.ChildAdded, function(f)
		watchBossFolder(f)
		if not watched[f] and f:IsA("Folder") and not BEAST_SKIP[f.Name] then   -- missions klasörü sonradan gelirse
			local c
			c = f.ChildAdded:Connect(function(ch)
				if ch.Name == "missions" then c:Disconnect() watchBossFolder(f) end
			end)
			table.insert(HUB.Cleanup, function() c:Disconnect() end)
		end
	end)

	local Rank = QuestPage:Card({ Title = "Auto rank", Icon = "crown", Side = "Right" })
	Rank:Toggle({ Title = "Auto rank", Desc = "Ranks up at level 1000", Flag = "rank_on", Default = false, Callback = function(v) F.AutoRank = v end })
	Rank:Toggle({ Title = "Rank up after MAX", Flag = "rank_max", Default = false, Callback = function(v) F.RankAfterMax = v end })
	Rank:Toggle({ Title = "Use RELL coins", Flag = "rank_rc", Default = false, Callback = function(v) F.RankRC = v end })
	Rank:Toggle({ Title = "Stop at spins", Flag = "rank_stop", Default = false, Callback = function(v) F.RankStop = v end })
	Rank:Slider({ Title = "Stop when spins reach", Flag = "rank_stopat", Min = 50, Max = 1000, Default = 500, DependsOn = { Flag = "rank_stop", Reason = "" },
		Callback = function(v) F.RankStopAt = v end })
	loop("Auto rank", 0.3, function()
		local s = statz()
		if not (F.AutoRank and s) then return end
		local spins = s:FindFirstChild("spins")
		if F.RankStop and spins and spins.Value >= F.RankStopAt then
			Window:SetFlag("rank_on", false)
			notify("Auto rank", "Spin target reached, stopped", "crown")
			return
		end
		if F.RankRC then
			if rellCoinOut() then
				Window:SetFlag("rank_rc", false)
				notify("Auto rank", "Out of RELL Coins", "triangle-alert", "warning")
			else
				fire("maxlvlpres2")
			end
		end
		local lvl = s:FindFirstChild("lvl") and s.lvl:FindFirstChild("lvl")
		if lvl and lvl.Value >= 1000 then
			fire(F.RankAfterMax and "maxlvlpres" or "rankup")
		end
	end)

	local Stats = QuestPage:Card({ Title = "Auto stats", Icon = "gauge" })
	Stats:Dropdown({ Title = "Stats", Flag = "farm_stats", Multi = true, Items = { "chakra", "ninjutsu", "taijutsu", "health" }, Default = {},
		Callback = function(list) F.Stats = type(list) == "table" and list or {} end })
	loop("Auto stats", 0.25, function()
		if #F.Stats == 0 then return end
		local s = statz()
		local pts = s and s:FindFirstChild("mastery") and s.mastery:FindFirstChild("points")
		if pts and pts.Value > 0 then
			for _, stat in ipairs(F.Stats) do
				for _, amt in ipairs({ 1, 17, 288 }) do fire("addstat", stat, amt) end
			end
		end
	end)
	if KIND ~= "map" then QuestPage:Warning("Missions only work on a map (now: " .. placeName() .. ").", { Level = "info" }) end

	------------------------------------------------ Mentor
	local MENTORS = { "Narumaki", "Jiso Seishin", "Shindai Akuma", "Ryuji Kenichi", "Bruce Kenichi" }
	local rank = statz() and statz():FindFirstChild("prestige") and statz().prestige:FindFirstChild("rank") and statz().prestige.rank.Value or "?"
	local M = MentorPage:Card({ Title = "Mentor", Icon = "graduation-cap", Desc = "Requires S rank or higher (your rank: " .. tostring(rank) .. ")" })
	M:Button({ Title = "Go to mentor", Icon = "map-pin", Style = "Primary", Callback = function()
		local sensei = workspace:FindFirstChild("sensei")
		if sensei and sensei:FindFirstChild("missions") then
			for _, name in ipairs(MENTORS) do
				local g = sensei.missions:FindFirstChild(name)
				if g then talkTo(g) return notify("Mentor", name .. " talked to", "graduation-cap") end
			end
		end
		local ken = workspace:FindFirstChild("Ken Mentor")
		if ken and ken:FindFirstChild("HumanoidRootPart") then
			tpTo(ken.HumanoidRootPart.CFrame + Vector3.new(-6, 4, 0))
			return notify("Mentor", "Went to Ken Mentor", "graduation-cap")
		end
		notify("Mentor", "No mentor on this map", "triangle-alert", "warning")
	end })
	M:Toggle({ Title = "Auto punch", Desc = "Punch missions", Flag = "mt_punch", Default = false, Callback = function(v) F.PunchM = v end })
	M:Toggle({ Title = "Auto tree jump", Desc = "Tree jump missions", Flag = "mt_tree", Default = false, Callback = function(v) F.TreeM = v end })
	M:Toggle({ Title = "Auto kunai shoot", Desc = "Target board missions", Flag = "mt_shoot", Default = false, Callback = function(v) F.Shoot = v end })
	M:Button({ Title = "Kenjutsu training", Icon = "sword", Callback = function() fire("trainkenmaster") end })
	loop("Mentor", 0.05, function()
		if HUB.FarmBusy or HUB.ScrollBusy then return end
		if F.PunchM or F.PunchD or F.Shoot then
			if F.Shoot then
				local mine = workspace.Terrain:FindFirstChild(LocalPlayer.Name)
				local aim = mine and mine:FindFirstChild("kunaiaim")
				if aim then lookAt(aim.Position) end
			end
			combat("mouse1", true)
		end
		if F.TreeM or F.TreeD then combat("takemovement2") end
	end)

	------------------------------------------------ Daily
	local D = DailyPage:Card({ Title = "Rewards", Icon = "gift" })
	D:Button({ Title = "Claim all missions", Icon = "gift", Style = "Primary", Callback = function()
		local st = statz()
		local m = st and st:FindFirstChild("mission")
		if m then
			for i = 1, 14 do
				local q = m:FindFirstChild("dailyquest" .. i)
				if q then fire("claim", q) end
			end
		end
		local mm = st and st:FindFirstChild("mainmission")
		if mm then
			for _, n in ipairs({ "arena", "arenax", "conquest", "masterelement", "masterkg", "resetbounty", "resetlegend", "shindowar", "storymissions", "warmode", "tournament" }) do
				local q = mm:FindFirstChild(n)
				if q then fire("claim2", q) end
			end
		end
		notify("Missions", "Requested daily and main mission rewards", "gift")
	end })
	local DA = DailyPage:Card({ Title = "Auto daily", Icon = "repeat", Side = "Right" })
	DA:Toggle({ Title = "M1", Flag = "dl_m1", Default = false, Callback = function(v) F.PunchD = v end })
	DA:Toggle({ Title = "Rush", Flag = "dl_rush", Default = false, Callback = function(v) F.Rush = v end })
	DA:Toggle({ Title = "Chi charge", Flag = "dl_chi", Default = false, Callback = function(v) F.Chi = v end })
	DA:Toggle({ Title = "Tree jumps", Flag = "dl_tree", Default = false, Callback = function(v) F.TreeD = v end })
	DA:Toggle({ Title = "Daily boss quests", Flag = "dl_boss", Default = false, Callback = function(v)
		if v ~= F.DailyBoss then if v then platformOn() else platformOff() end end   -- boss farm gibi platform
		F.DailyBoss = v
	end })
	loop("Daily", 0.05, function()
		if HUB.FarmBusy or HUB.ScrollBusy then return end
		if F.Rush then combat("rushw") end
		if F.Chi then combat("key", "c") combat("key", "cend") end
	end)

end

------------------------------------------------------------------ SPIN
do
	local Spin = Tabs.Spin
	local InfPage = Spin:Page("Inf Spin")
	local RellPage = Spin:Page("Auto RELL")

	------------------------------------------------ Inf Spin (element / bloodline / kenjutsu / race)
	local SAVE_FILE = "QustahShindo/infspin.json"
	local I = {
		Elements = {}, Bloodlines = {}, Kenjutsu = {}, Races = {},
		ElemSlots = { "1", "2" }, BlSlots = { "1", "2" }, KenSlots = { "1" },
		On = { Element = false, Bloodline = false, Kenjutsu = false, Race = false },
		ResetAt = 0, AutoSave = true, Delay = 0.25,
	}
	local function persist()                                    -- seçimler rejoin'den sonra da kalsın
		if not writefile then return end
		pcall(function()
			if makefolder and isfolder and not isfolder("QustahShindo") then makefolder("QustahShindo") end
			writefile(SAVE_FILE, HttpService:JSONEncode(I))
		end)
	end
	local fromFile                                               -- json'dan okunan hal (AutoLoad'dan sonra geri yüklenir)
	pcall(function()
		if isfile and isfile(SAVE_FILE) then
			local data = HttpService:JSONDecode(readfile(SAVE_FILE))
			for k, v in pairs(data) do I[k] = v end
			fromFile = HttpService:JSONDecode(readfile(SAVE_FILE))
		end
	end)

	local function lists()
		local alljutsu = ReplicatedStorage:FindFirstChild("alljutsu")
		local el, kg, ken, race = {}, {}, {}, {}
		local function add(t, n, inst)                              -- listeye gerçek ismiyle ekle
			n = labelFor(n, inst)
			if not table.find(t, n) then t[#t + 1] = n end
		end
		local rare = workspace:FindFirstChild("RAREKGS")
		if alljutsu then
			if rare then                                        -- bu haftanın dönen limited'leri
				for _, v in ipairs(rare:GetChildren()) do
					local j = alljutsu:FindFirstChild(v.Name)
					if v.Name ~= "KGTEMPLATE" and j and v:FindFirstChild("tim") and v.tim.Value ~= "N/A" then
						if j:FindFirstChild("ELEMENT") then add(el, v.Name, j) end
						if j:FindFirstChild("KG") then add(kg, v.Name, j) end
					end
				end
			end
			for _, v in ipairs(alljutsu:GetChildren()) do
				if v:FindFirstChild("ELEMENT") and not v:FindFirstChild("limited") then add(el, v.Name, v) end
				if v:FindFirstChild("KG") and not v:FindFirstChild("cantspin") and not v:FindFirstChild("limited") then add(kg, v.Name, v) end
			end
			local ks = alljutsu:FindFirstChild("ALLKENSTYLES")
			if ks then
				for _, v in ipairs(ks:GetChildren()) do
					if v:FindFirstChild("BREATHINGSTYLE") and not v:FindFirstChild("limited") then add(ken, v.Name, v) end
				end
			end
		end
		pcall(function()
			for _, v in ipairs(mainGui().RaceCustom.Frame.ScrollingFrame:GetChildren()) do
				if v:FindFirstChild("icon") and (not v.icon:FindFirstChild("lock") or not v.icon.lock.Visible) then add(race, v.Name) end
			end
		end)
		pcall(function()
			for dna, r in pairs({ celestialdna = "celestial", snakedna = "snake", sharkdna = "shark", puppetdna = "puppet" }) do
				if statz().unlocked:FindFirstChild(dna) then add(race, r) end
			end
		end)
		for _, t in ipairs({ el, kg, ken, race }) do table.sort(t) end
		return el, kg, ken, race
	end
	local EL, KGS, KEN, RACE = lists()
	local function orDash(t) return #t > 0 and t or { "-" } end

	local function has(list, v) return v ~= nil and v ~= "" and table.find(list, v) ~= nil end
	local function gp(name) return LocalPlayer:FindFirstChild("gamepasses") and LocalPlayer.gamepasses:FindFirstChild(name) ~= nil end
	local function saveAndLeave()
		fire("band", "Eye")
		task.wait(1)
		if HUB.Running and not ENV.RELL_RUNNING then fire("arenateleport", PLACE.MY_HOME) end
	end
	local function resetAndRejoin()
		queueHub()
		fire("band", "\128")
		task.wait()
		if HUB.Running and not ENV.RELL_RUNNING then TeleportService:Teleport(game.PlaceId, LocalPlayer) end
	end

	-- tek döngü: açık olan her kategori için, istenen gelene kadar sırayla spin
	-- Bir kategori açık ama "Wanted" ya da "Slots" boşsa o kategori atlanır (eskiden boş liste = "geldi" sayılıp kaydedip çıkıyordu).
	local CAT = {
		{ on = "Element", flag = "is_elem_on", wanted = "Elements", slots = "ElemSlots", label = "Elements" },
		{ on = "Bloodline", flag = "is_bl_on", wanted = "Bloodlines", slots = "BlSlots", label = "Bloodlines" },
		{ on = "Kenjutsu", flag = "is_ken_on", wanted = "Kenjutsu", slots = "KenSlots", label = "Kenjutsu" },
		{ on = "Race", flag = "is_race_on", wanted = "Races", label = "Race" },
	}
	local function asList(v) return type(v) == "table" and v or {} end
	local function ready(c)                                     -- açık + listesi dolu
		if not I.On[c.on] then return false end
		if #asList(I[c.wanted]) == 0 then return false, "Wanted is empty" end
		if c.slots and #asList(I[c.slots]) == 0 then return false, "Slots is empty" end
		return true
	end
	local warned = {}
	local function warning(key, message)
		if warned[key] == message then return end
		warned[key] = message
		notify("Inf Spin", message, "triangle-alert", "warning")
	end
	loop("Inf Spin", function() return tonumber(I.Delay) or 0.25 end, function()
		if KIND ~= "menu" or ENV.RELL_RUNNING or ENV.RELLOpening then return end
		local s = statz()
		if not (s and s:FindFirstChild("spins") and s:FindFirstChild("main")) then return end
		local active = {}
		for _, c in ipairs(CAT) do
			local ok, why = ready(c)
			if ok then active[c.on] = true warned[c.on] = nil
			elseif why and not warned[c.on] then
				warned[c.on] = true
				notify("Inf Spin", c.label .. ": " .. why .. ", skipped", "triangle-alert", "warning")
			end
		end
		if not next(active) then return end
		local delay = tonumber(I.Delay) or 0.25
		local pending, blocked, low, sent = false, false, false, false
		local function check(c, val, unlocked, cost, send, label)
			if not HUB.Running or ENV.RELL_RUNNING or ENV.RELLOpening or not I.On[c] then blocked = true return end
			if not val or not unlocked then
				blocked = true
				warning(label, label .. " slot not found or locked")
				return
			end
			warned[label] = nil
			if has(I[c == "Element" and "Elements" or c == "Bloodline" and "Bloodlines" or c == "Race" and "Races" or "Kenjutsu"], val.Value) then return end
			pending = true
			if cost == 0 or s.spins.Value >= I.ResetAt + cost then
				sent = cost > 0 or sent
				send()
				task.wait(delay)
			else
				low = true
			end
		end
		if active.Element then
			for _, n in ipairs(asList(I.ElemSlots)) do
				local slot = "element" .. n
				check("Element", s.main:FindFirstChild(slot), (tonumber(n) or 9) <= 2 or gp(slot), 1,
					function() fire("spin", slot) end, slot)
			end
		end
		if active.Bloodline then
			for _, n in ipairs(asList(I.BlSlots)) do
				local slot = "kg" .. n
				check("Bloodline", s.main:FindFirstChild(slot), (tonumber(n) or 9) <= 2 or gp("genkai" .. n), 1,
					function() fire("spin", slot) end, slot)
			end
		end
		if active.Kenjutsu then
			for _, n in ipairs(asList(I.KenSlots)) do
				local key = n == "1" and "breathingstyle" or "breathingstyle2"
				local unlocked = n == "1" or (s:FindFirstChild("unlocked") and s.unlocked:FindFirstChild("kenjutsuslot2"))
				check("Kenjutsu", s:FindFirstChild(key), unlocked, 10, function()
					if n == "1" then fire("spinBREATHING") else fire("spinBREATHING", key) end
				end, key)
			end
		end
		if active.Race then
			if rellCoinOut() then                                   -- coin bitti: race spinini kapat, boşuna remote atma
				I.On.Race = false
				Window:SetFlag("is_race_on", false)
				persist()
				notify("Inf Spin", "Out of RELL Coins, race spin stopped", "triangle-alert", "warning")
				active.Race = nil
				if not next(active) then return end
			else
				check("Race", s:FindFirstChild("race"), true, 0, function() fire("spinrace") end, "Race")
			end
		end
		if not HUB.Running or ENV.RELL_RUNNING or ENV.RELLOpening or blocked then return end
		if not pending then
			for _, c in ipairs(CAT) do
				if active[c.on] then I.On[c.on] = false Window:SetFlag(c.flag, false) end
			end
			persist()
			notify("Inf Spin", "Got what you wanted" .. (I.AutoSave and ", kaydediliyor" or ""), "sparkles", "success")
			if I.AutoSave then saveAndLeave() end
		elseif low and not sent then
			persist()
			notify("Inf Spin", "Out of spins, resetting and rejoining", "rotate-ccw")
			resetAndRejoin()
			task.wait(5)
		end
	end)

	local function category(page, side, title, icon, listKey, items, slotKey, slotItems, onFlag, onKey, desc)
		local c = page:Card({ Title = title, Icon = icon, Side = side, Desc = desc })
		-- listede gerçek isimler görünür, kayıtta / spin kontrolünde kod adları kullanılır
		local dd = c:Dropdown({ Title = "Wanted", Flag = onFlag .. "_list", Multi = true, Items = orDash(items), Default = mapList(I[listKey], toLabel), Search = true,
			Callback = function(list) I[listKey] = mapList(list, toCode) persist() end })
		if slotKey then
			c:Dropdown({ Title = "Slots", Flag = onFlag .. "_slots", Multi = true, Items = slotItems, Default = I[slotKey],
				Callback = function(list) I[slotKey] = list persist() end })
		end
		c:Toggle({ Title = "Start spinning", Flag = onFlag, Default = I.On[onKey], Callback = function(on)
			if on and (ENV.RELL_RUNNING or ENV.RELLOpening) then
				task.defer(function() Window:SetFlag(onFlag, false) end)
				return notify("Inf Spin", "Stop Auto Spin RELL first", "triangle-alert", "warning")
			end
			I.On[onKey] = on
			persist()
			if on and KIND ~= "menu" then notify("Inf Spin", "Only works in the main menu", "triangle-alert", "warning") end
		end })
		return dd
	end
	local ddE = category(InfPage, "Left", "Elements", "flame", "Elements", EL, "ElemSlots", { "1", "2", "3", "4" }, "is_elem_on", "Element")
	local ddB = category(InfPage, "Right", "Bloodlines", "dna", "Bloodlines", KGS, "BlSlots", { "1", "2", "3", "4" }, "is_bl_on", "Bloodline")
	local ddK = category(InfPage, "Left", "Kenjutsu", "sword", "Kenjutsu", KEN, "KenSlots", { "1", "2" }, "is_ken_on", "Kenjutsu", "Each spin costs 10 spins")
	local ddR = category(InfPage, "Right", "Race", "user-round", "Races", RACE, nil, nil, "is_race_on", "Race", "Costs RELL Coins, not reset")

	local Set = InfPage:Card({ Title = "Settings", Icon = "settings-2", Wide = "Bottom" })
	Set:Slider({ Title = "Reset when spins reach", Desc = "Rolls back the save and rejoins when spins drop to this", Flag = "is_reset", Min = 0, Max = 100,
		Default = I.ResetAt, Callback = function(v) I.ResetAt = v persist() end })
	Set:Slider({ Title = "Spin delay", Flag = "is_delay", Min = 0.1, Max = 2, Step = 0.05, Default = I.Delay, Suffix = " s",
		Callback = function(v) I.Delay = v persist() end })
	Set:Toggle({ Title = "Save when done", Desc = "Saves and goes to My Home when you get what you want", Flag = "is_autosave", Default = I.AutoSave,
		Callback = function(v) I.AutoSave = v persist() end })
	local row = Set:Row()
	row:Button({ Title = "Refresh lists", Icon = "refresh-cw", Callback = function()
		EL, KGS, KEN, RACE = lists()
		ddE:SetItems(orDash(EL), true) ddB:SetItems(orDash(KGS), true) ddK:SetItems(orDash(KEN), true) ddR:SetItems(orDash(RACE), true)
	end })
	row:Button({ Title = "Reset spins", Icon = "rotate-ccw", Confirm = "Sure?", Callback = resetAndRejoin })
	row:Button({ Title = "Save spins", Icon = "save", Style = "Soft", Confirm = "Sure?", Callback = saveAndLeave })
	if KIND ~= "menu" then InfPage:Warning("Inf Spin only works in the main menu (now: " .. placeName() .. "). Your picks are saved.", { Level = "info" }) end
	if (I.On.Element or I.On.Bloodline or I.On.Kenjutsu) and KIND == "menu" then queueHub() end
	-- Ayar profili (AutoLoad) Inf Spin'i kapatmasın: rejoin sonrası json'daki hali geri koy
	HUB.AfterAutoLoad = HUB.AfterAutoLoad or {}
	HUB.AfterAutoLoad[#HUB.AfterAutoLoad + 1] = function()
		if type(fromFile) ~= "table" then return end
		local function put(flag, v) if v ~= nil then Window:SetFlag(flag, v) end end
		put("is_elem_on_list", fromFile.Elements) put("is_bl_on_list", fromFile.Bloodlines)
		put("is_ken_on_list", fromFile.Kenjutsu) put("is_race_on_list", fromFile.Races)
		put("is_elem_on_slots", fromFile.ElemSlots) put("is_bl_on_slots", fromFile.BlSlots) put("is_ken_on_slots", fromFile.KenSlots)
		put("is_reset", fromFile.ResetAt) put("is_delay", fromFile.Delay) put("is_autosave", fromFile.AutoSave)
		local on = type(fromFile.On) == "table" and fromFile.On or {}
		for _, c in ipairs(CAT) do put(c.flag, on[c.on] == true) end
	end

	------------------------------------------------ Auto Spin RELL (ayrı pencere)
	-- Auto Spin RELL artık kendi raw'ından açılıyor (script içine gömülü değil); rejoin sonrası da kendini o linkten açar
	local RELL_URL = "https://raw.githubusercontent.com/79650/dg3b2352313124scjd3124sanhgcdsahncdas457hs1amgdcankjcj/refs/heads/main/rellauto"
	local function openRell()
		if ENV.RELL_RUNNING then return true end
		if ENV.RELLOpening then return false end
		for _, c in ipairs(CAT) do
			if I.On[c.on] then
				notify("Auto Spin RELL", "Stop Inf Spin first", "triangle-alert", "warning")
				return false
			end
		end
		queuePermission(RELL_QUEUE_STOP, not ENV.RELL_NOQUEUE)
		ENV.RELLOpening = true
		ENV.RELL_BOOT_CANCEL = false
		local okGet, src = pcall(function() return game:HttpGet(RELL_URL, true) end)
		local fn = okGet and type(src) == "string" and loadstring(src)
		if not fn then
			ENV.RELLOpening = false
			notify("Auto Spin RELL", "Couldn't download the script (raw link)", "triangle-alert", "danger")
			return false
		end
		task.spawn(function()                                  -- açılırken menünün yüklenmesini bekliyor: butonu kilitlemesin
			local ok, err = pcall(fn)
			if not ok then warn("Auto Spin RELL:", err) if ENV.RELLStop then pcall(ENV.RELLStop) end end
		end)
		for _ = 1, 40 do                                        -- en fazla ~20 sn çalışmaya başlamasını bekle
			if ENV.RELL_RUNNING or ENV.RELL_BOOT_CANCEL then break end
			task.wait(0.5)
		end
		ENV.RELLOpening = false
		return ENV.RELL_RUNNING == true
	end
	HUB.Cleanup[#HUB.Cleanup + 1] = function()
		ENV.RELL_BOOT_CANCEL = true
		if ENV.RELLStop then ENV.RELLStop() end
	end
	local RellCard = RellPage:Card({ Title = "Auto Spin RELL", Icon = "dices", Desc = "Spins bloodlines until you get RELL" })
	RellCard:Button({ Title = "Open Auto Spin RELL", Icon = "app-window", Style = "Primary", Callback = function()
		if KIND ~= "menu" then
			return notify("Auto Spin RELL", "Only works in the main menu (now: " .. placeName() .. ")", "triangle-alert", "warning")
		end
		if openRell() then Window:SetModule("Auto Spin RELL", "On", nil, { Icon = "dices", Tab = "Spin" }) end
	end })
	RellCard:Slider({ Title = "Spin delay", Flag = "rell_delay", Min = 0.3, Max = 3, Step = 0.1, Default = 1, Suffix = " s",
		Callback = function(v) ENV.RELL_DELAY = v end })
	RellCard:Toggle({ Title = "Re-run after rejoin", Desc = "Continues automatically with queue_on_teleport", Flag = "rell_queue", Default = true,
		Callback = function(on)
			ENV.RELL_NOQUEUE = not on
			queuePermission(RELL_QUEUE_STOP, on and ENV.RELL_RUNNING == true)
			if on and ENV.RELL_RUNNING and ENV.RELLQueue then ENV.RELLQueue() end
		end })
	RellCard:Button({ Title = "Stop", Icon = "circle-stop", Style = "Danger", Callback = function()
		ENV.RELL_BOOT_CANCEL = true
		if ENV.RELLStop then ENV.RELLStop() end
		queuePermission(RELL_QUEUE_STOP, false)
		local g = LocalPlayer.PlayerGui:FindFirstChild("QustahRELL")
		if g then g:Destroy() end
		Window:SetModule("Auto Spin RELL", "Off", nil, { Icon = "dices", Tab = "Spin" })
		notify("Auto Spin RELL", "Stopped, won't run on the next rejoin", "circle-stop")
	end })

	local SpinsCard = RellPage:Card({ Title = "Spins", Icon = "gauge", Side = "Right" })
	local spinsInfo = SpinsCard:Info({ Title = "Spins left", Value = "-" })
	local slotInfo = SpinsCard:Info({ Title = "Bloodlines", Value = "-" })
	local elemInfo = SpinsCard:Info({ Title = "Elements", Value = "-" })
	local function join(s, prefix)
		local list = {}
		local main = s:FindFirstChild("main")
		for i = 1, 4 do
			local v = main and main:FindFirstChild(prefix .. i)
			if v and v.Value ~= "" then list[#list + 1] = v.Value end
		end
		return #list > 0 and table.concat(list, ", ") or "-"
	end
	loop("Spins", 1, function()
		local s = statz()
		if not s then return end
		local spins = s:FindFirstChild("spins")
		spinsInfo:Set(spins and tostring(spins.Value) or "-")
		slotInfo:Set(join(s, "kg"))
		elemInfo:Set(join(s, "element"))
	end)
	Window:SetModule("Auto Spin RELL", ENV.RELL_RUNNING and "On" or "Off", nil, { Icon = "dices", Tab = "Spin" })
end

------------------------------------------------------------------ PLAYER › Shindo
do
	local P = Tabs.Player:Page("Shindo")
	local G = { NoCombat = false, Unbreak = false, Aura = false, Scroll = false, ScrollSpawn = true }

	local Game = P:Card({ Title = "Game", Icon = "wand-sparkles" })
	Game:Toggle({ Title = "Disable in combat", Desc = "Teleport / leave even while in combat", Flag = "sh_nocombat", Default = false, Callback = function(v) G.NoCombat = v end })
	Game:Toggle({ Title = "Immortal", Desc = "Get up instantly when knocked down (no knockdown)", Flag = "sh_immortal", Default = false,
		Callback = function(v) G.Immortal = v end })
	hubConnect(RunService.Heartbeat, function()
		if not G.Immortal then return end
		local c = character()
		if not c then return end
		local st = c:FindFirstChild("stayonground")
		if st then st:Destroy() end
		local r = c:FindFirstChild("HumanoidRootPart")
		local ko = r and r:FindFirstChild("KO")
		if ko then ko:Destroy() end
		local h = c:FindFirstChildOfClass("Humanoid")
		if h and not h.AutoRotate then h.AutoRotate = true end
	end)
	local moved = setmetatable({}, { __mode = "k" })
	local function restoreBlocks()
		for scriptObject, parent in pairs(moved) do
			if parent.Parent and scriptObject.Parent == parent:FindFirstChild("gunfolder") then
				pcall(function() scriptObject.Parent = parent end)
			end
		end
		table.clear(moved)
	end
	local function applyBlocks(c)
		local object = c and c:FindFirstChild("blockbreaker")
		local folder = c and c:FindFirstChild("gunfolder")
		if object and folder then
			object.Parent = folder
			moved[object] = c
		end
	end
	HUB.Cleanup[#HUB.Cleanup + 1] = restoreBlocks
	Game:Toggle({ Title = "Unbreakable blocks", Desc = "Block can't be broken", Flag = "sh_unbreak", Default = false, Callback = function(v)
		G.Unbreak = v
		if v then applyBlocks(character()) else restoreBlocks() end
	end })
	hubConnect(LocalPlayer.CharacterAdded, function(c)
		if not G.Unbreak then return end
		task.wait(2.5)
		if HUB.Running and G.Unbreak and character() == c then applyBlocks(c) end
	end)
	hubConnect(RunService.Stepped, function()
		if G.NoCombat and LocalPlayer:FindFirstChild("incombat") then LocalPlayer.incombat.Value = false end
	end)

	local Aura = P:Card({ Title = "NPC kill aura", Icon = "skull", Side = "Right" })
	Aura:Toggle({ Title = "NPC Kill Aura", Flag = "sh_aura", Default = false, Callback = function(v) G.Aura = v end })
	-- DogeHub'ın NPCKEELAURA'sının birebir aynısı: her Heartbeat'te, menzil sınırı yok (KILL_RANGE = 0),
	-- workspace.npc'deki geçerli her NPC'nin canı 4 kez 0'a çekilir (istemci tarafı).
	-- Tek fark: DogeHub'da Misc ve Quests'teki iki toggle'ın İKİSİ de açık olmadan çalışmıyordu (keel and keel2);
	-- burada ikisinden biri yeterli (Player > NPC kill aura ya da Farm > Configurations).
	local function isValidNPC(npc)
		return npc:IsA("Model")
			and npc:FindFirstChild("npctype")
			and npc.Name:lower():find("npc")
			and npc:FindFirstChild("HumanoidRootPart")
			and npc:FindFirstChild("Humanoid")
			and npc:FindFirstChild("Head") and npc.Head.CFrame.Y > -1000
			and npc.Humanoid.Health > 0
	end
	hubConnect(RunService.Heartbeat, function()
		if not (G.Aura or HUB.FarmAura) then return end
		local r = rootPart()
		local folder = workspace:FindFirstChild("npc")
		if not (r and folder) then return end
		for _, npc in ipairs(folder:GetChildren()) do
			if isValidNPC(npc) then
				pcall(function()
					npc.Humanoid.Health = 0
					npc.Humanoid.Health = 0
					npc.Humanoid.Health = 0
					npc.Humanoid.Health = 0
				end)
			end
		end
	end)

	local Scroll = P:Card({ Title = "Scroll snipe", Icon = "scroll", Desc = "Grabs scrolls that spawn on the map" })
	Scroll:Toggle({ Title = "Scroll snipe", Flag = "sh_scroll", Default = false, Callback = function(v) G.Scroll = v end })
	Scroll:Toggle({ Title = "Teleport to spawn after", Flag = "sh_scrollspawn", Default = true, Callback = function(v) G.ScrollSpawn = v end })
	local function toSpawn()
		local sp = workspace:FindFirstChild("SpawnLocation")
		if sp then return tpTo(sp.CFrame + Vector3.new(0, 3, 0)) end
		local spawns = workspace:FindFirstChild("spawns")
		if spawns then
			for _, v in ipairs(spawns:GetChildren()) do
				if v:IsA("BasePart") then return tpTo(v.CFrame + Vector3.new(0, 3, 0)) end
			end
		end
	end
	local ignored = setmetatable({}, { __mode = "k" })
	local retryAfter = setmetatable({}, { __mode = "k" })
	local function hasScroll(name)
		local s = statz()
		local u = s and s:FindFirstChild("unlocked")
		return u and (u:FindFirstChild(name) or u:FindFirstChild(name .. "scroll"))
	end
	loop("Scroll snipe", 0.3, function()
		if not G.Scroll or HUB.FarmBusy or inMission() then return end
		for _, folder in ipairs({ workspace, workspace:FindFirstChild("GLOBALTIME") }) do
			for _, v in ipairs(folder:GetChildren()) do
				local sh = v:IsA("Model") and v:FindFirstChild("sh")
				if sh and sh:IsA("BasePart") and sh.Position.Y > -1000 and sh.Position.Y < 2000
					and not ignored[v] and os.clock() >= (retryAfter[v] or 0) then
					if hasScroll(v.Name) then
						ignored[v] = true
					else
						tpTo(sh.CFrame)
						local cd = sh:FindFirstChildWhichIsA("ClickDetector")
						if cd and fireclickdetector then pcall(fireclickdetector, cd) end
						combat("mouse1", true)
						HUB.ScrollBusy = true
						local ok, err = pcall(function()
							for _ = 1, 12 do
								if not HUB.Running or not G.Scroll or inMission() then return end
								if hasScroll(v.Name) then
									ignored[v] = true
									notify("Scroll snipe", v.Name .. " collected", "scroll", "success")
									if G.ScrollSpawn then toSpawn() end
									return
								end
								task.wait(0.15)
							end
							retryAfter[v] = os.clock() + 3
							if HUB.Running and G.Scroll and G.ScrollSpawn and not inMission() then toSpawn() end
						end)
						HUB.ScrollBusy = false
						if not ok then error(err, 0) end
						return
					end
				end
			end
		end
	end)
end

------------------------------------------------------------------ TELEPORT
local TP_DATA = {
    [4601350809] = {
        { "Kage Office", 11984, 991, -17752 },
        { "The Top of Kage Office", 11980, 1130, -17770 },
        { "Obelisk Small Round Structure", 11670, 730, -17600 },
        { "Arena Auditorium", 11975, 657, -15950 },
        { "Shikai Forest (X)", 13593.5, 515, -15769 },
        { "Ryuji Cave (X)", 13863.5, 713, -17094 },
        { "Ryuji Cave Entrance 1", 13790.7, 526.5, -16774 },
        { "Ryuji Cave Entrance 2", 13854.7, 518.8, -16967.5 },
        { "Ryuji Cave Laboratory", 13712, 537, -16903.5 },
        { "Cobra Place", 13781, 426, -16740 },
        { "Shindai Valley (X)", 14383.5, 518, -17560 },
        { "House Outside the Village", 15405, 498, -16150 },
        { "Tree Top 1", 11858, 970, -16385 },
        { "Tree Top 2", 12195, 1036, -17110 },
        { "Tree Top 3", 12670, 925, -17222 },
        { "Tree Top 4", 12470, 873, -16410 },
        { "Tree Top 5", 13023, 844, -16741 },
        { "Obelisk Bridge 1", 11670, 849, -16505 },
        { "Obelisk Bridge 2", 11670, 849, -17147 },
        { "Obelisk Bridge 3", 11830, 849, -17455 },
        { "Obelisk Bridge 4", 12295, 865, -17743 },
        { "Obelisk Bridge 5", 12475, 849, -17455 },
        { "Water Area 1", 12752, 845, -16722 },
        { "Water Area 2", 14441, 471, -16648 },
        { "Water Area 3", 15325, 471, -16700 },
    },
    [4601350656] = {
        { "Kage Office", 18020, 944, -19220 },
        { "The Back of Kage Office", 18085, 884, -19615 },
        { "Arena Auditorium", 17255, 668, -18197 },
        { "Nimbus Bridge", 16660, 724, -18780 },
        { "Samurai Bridge (X)", 15635, 597, -17740 },
        { "Snow Area", 14655, 779, -18915 },
        { "Sovereign Summit (X)", 14047, 633, -19355 },
        { "Sovereign Summit Entrance 1", 14046, 641, -19162 },
        { "Sovereign Summit Entrance 2", 14148, 640, -19404 },
        { "Water Area 1", 15785, 488, -18645 },
        { "Water Area 2", 13690, 618, -18225 },
        { "Water Area 3", 15512, 471, -16455 },
    },
    [4601350214] = {
        { "Ember Gate 1", 18200, 657, -15810 },
        { "Ember Gate 2", 18405, 657, -16165 },
        { "Ember Gate 3", 18407, 657, -15457 },
        { "Ember Bridge", 18525, 658, -15810 },
        { "Kage Office", 18900, 691, -15805 },
        { "Academy Rooftop", 18757, 710, -16130 },
        { "Ember Military Police Force", 18881, 678, -15995 },
        { "Arena Auditorium", 18014, 678, -15527 },
        { "Ember Hideout", 19500, 726, -15870 },
        { "Houses Outside the Village", 17485, 624, -16357 },
        { "Mount Maki (X)", 17424, 934, -17003 },
        { "Flat Area 1", 16990, 594, -15330 },
        { "Flat Area 2", 18358, 652, -15115 },
        { "Water Area 1", 17085, 568, -16100 },
        { "Water Area 2", 18407, 631, -16700 },
        { "Water Area 3", 18223, 650, -14283 },
        { "Tree Top 1", 18700, 788, -15934 },
        { "Tree Top 2", 18199, 826, -15471 },
        { "Tree Top 3", 18364, 848, -16272 },
    },
    [4601350760] = {
        { "Kage Office", 16275, 821, -10925 },
        { "Entrance of Haze Village", 16781, 661, -12080 },
        { "Arena Auditorium", 17185, 677, -10525 },
        { "Temple Structure", 16195, 666, -11830 },
        { "Great Narumaki Bridge (X)", 16230, 661, -13020 },
        { "Tree Top (Kage Office)", 16260, 968, -10900 },
        { "Tree Top 1", 16682, 849, -11226 },
        { "Tree Top 2", 17228, 930, -10840 },
        { "Tree Top 3", 16867, 812, -12232 },
        { "Tree Top 4", 16416, 768, -13180 },
        { "Tree Top 5", 16320, 842, -14157 },
        { "Tree Top 6", 17972, 907, -13836 },
        { "Zabuza & Haku's Grave Easter Egg", 16378, 802, -12477 },
        { "Secret Place (Atlantis???)", 15851, 488, -11598 },
    },
    [4601350394] = {
        { "Kage Office", 12845, 297, -12945 },
        { "That 1 House that's on the High Ground", 12910, 321, -13210 },
        { "Arena Auditorium", 12680, 255, -13930 },
        { "Bridge 1", 12835, 331, -13735 },
        { "Bridge 2", 12885, 370, -14210 },
        { "Bridge 3", 13700, 408, -14355 },
        { "Sand Area 1", 13195, 245, -13840 },
        { "Sand Area 2", 13075, 400, -15025 },
        { "Sand Area 3", 13690, 400, -14930 },
        { "Grass Area", 14890, 497, -15760 },
        { "House Outside the Village", 15410, 498, -16145 },
        { "Summoning Jutsu Easter Egg", 14415.5, 688, -15799.5 },
        { "Secret Underground Structure", 13744, 303, -14704 },
    },
    [5451405681] = {
        { "Vinland Gate 1", 21035, 647, -11490 },
        { "Vinland Gate 2", 19436, 647, -12445 },
        { "Vinland Gate 3", 18560, 647, -11460 },
        { "Kage Office", 19705, 1109, -11190 },
        { "The Top of Kage Office", 19707.5, 1266, -11175 },
        { "Small Park Under the Kage Office", 19645, 871, -11265 },
        { "Top of the Mountain", 19735, 1378, -10115 },
        { "Shikai Forest (X)", 19164, 659, -13335 },
        { "Main Pipe 1 (head)", 20725, 722, -13635 },
        { "Main Pipe 1 (end)", 20395, 959, -11930 },
        { "Main Pipe 2 (head)", 19365, 722, -13647 },
        { "Main Pipe 2 (end)", 19368.8, 691, -12205 },
    },
    [5431071837] = {
        { "That 1 Rock in the Middle", 19688, 698, -11544 },
        { "The River", 19750, 652, -11910 },
        { "Under the Map 1", 19750, 652, -11550 },
        { "Under the Map 2", 19750, 652, -12250 },
        { "Hill Area 1", 20450, 772, -10910 },
        { "Hill Area 2", 19260, 782, -10865 },
        { "Hill Area 3", 19300, 935, -12780 },
        { "Hill Area 4", 19630, 837, -12805 },
        { "Outside the Map 1", 21300, 652, -13600 },
        { "Outside the Map 2", 18100, 652, -13600 },
        { "Outside the Map 3", 18100, 652, -10300 },
        { "Outside the Map 4", 21430, 652, -10300 },
    },
    [5447073001] = {
        { "Top of the Building", 19930, 963, -12185 },
        { "DES Exams", 20265, 331, -12347 },
        { "Bridge 1", 19370, 680, -11907 },
        { "Bridge 2", 20730, 680, -12030 },
        { "Bridge 3", 20745, 677, -11690 },
    },
    [6901575446] = {
        { "Entrance of Tempest", 19660, 648, -11612 },
        { "Tempest Training Field", 19275, 662, -11655 },
    },
    [6986372023] = {
        { "Blaze Gate 1", 19467, 670, -10903 },
        { "Blaze Gate 2", 19550, 670, -11360 },
        { "Blaze Gate 3", 19824, 670, -11893 },
        { "Blaze Gate 4", 19513, 670, -12417 },
        { "Blaze Gate 5", 19255, 670, -12818 },
        { "Bridge 1", 19230, 657, -11283 },
        { "Bridge 2", 18950, 657, -11830 },
        { "Bridge 3", 19055, 657, -12370 },
        { "Kage Office", 18280, 741, -12000 },
        { "Small Pond", 18400, 665, -11490 },
        { "Academy Rooftop", 18881, 763, -10957 },
        { "Blaze Military Police Force", 18365, 694, -11750 },
        { "Hospital", 18860, 670, -12612 },
        { "Arena Auditorium", 18595, 690, -11532 },
        { "Blaze Hideout", 18055, 298, -12222 },
        { "Entrance of Blaze Hideout", 18309.8, 695, -12153 },
        { "Forest of Embers (X)", 19980, 669, -12640 },
        { "Top of the Building in Forest of Embers", 20505, 960, -13330 },
        { "DES Exams (X)", 21203.7, 335, -13461.1 },
    },
    [5451398863] = {
        { "In Front of The Bridge 1", 20645, 762, -13250 },
        { "In Front of The Bridge 2", 20645, 762, -11050 },
        { "On The Bridge 1", 20645, 762, -12945 },
        { "On The Bridge 2", 20645, 762, -12250 },
        { "On The Bridge 3", 20645, 762, -11345 },
        { "On The Bridge 4", 20645, 729, -12945 },
        { "On The Bridge 5", 20645, 729, -12250 },
        { "On The Bridge 6", 20645, 729, -11345 },
        { "Under The Bridge 1", 20645, 665, -11300 },
        { "Under The Bridge 2", 20645, 656, -12250 },
        { "Under The Bridge 3", 20645, 665, -13000 },
        { "Houses", 20650, 767, -13645 },
        { "Island 1", 20160, 779, -12000 },
        { "Island 2", 21053, 761, -11645 },
    },
    [5451401540] = {
        { "Statue 1", 19140, 1005, -11073 },
        { "Statue 2", 18854, 1006, -11070 },
        { "Under the Waterfall", 18980, 631, -11065 },
        { "Flat Area 1", 18170, 643, -13270 },
        { "Flat Area 2", 19365, 644, -12890 },
        { "Flat Area 3", 18975, 684, -11790 },
        { "Water Area 1", 19290, 812, -10565 },
        { "Water Area 2", 18220, 812, -11125 },
        { "Water Area 3", 18865, 631, -13410 },
        { "Water Area 4", 18620, 631, -12750 },
    },
    [6602103757] = {
        { "Pond 1", 21010, 649, -13075 },
        { "Pond 2", 20470, 649, -13540 },
        { "Pond 3", 21200, 649, -13667 },
    },
    [5255237254] = {
        { "Bridge 1", 20345, 661, -12660 },
        { "Bridge 2", 20165, 691, -11050 },
        { "Water Pond", 21010, 670, -10800 },
        { "Oil Pond 1", 20573, 651, -12328 },
        { "Oil Pond 2", 18768, 651, -10870 },
        { "Flat Area Outside the Map", 21565, 627, -11660 },
    },
    [5824792748] = {
        { "Ryuji Cave Entrance", 18764, 916, -10865 },
        { "Ryuji Cave Laboratory", 18900, 938, -10560 },
        { "Snake Sage Place", 18982, 717, -10967 },
        { "Cobra Place", 18780, 656, -11400 },
        { "Open Area 1", 18745, 902, -11355 },
        { "Open Area 2", 18725, 957, -10390 },
        { "Open Area 3", 18737, 1040, -10670 },
    },
}
do
	local T = Tabs.Teleport
	local MapPage = T:Page("Map")
	local ServerPage = T:Page("Servers")

	local Places = MapPage:Card({ Title = "Locations", Icon = "map-pin", Desc = "This map's locations" })
	local here = TP_DATA[game.PlaceId] or {}
	local names, byName = {}, {}
	for _, p in ipairs(here) do names[#names + 1] = p[1] byName[p[1]] = p end
	local chosen
	Places:Dropdown({ Title = "Location", Flag = "tp_loc", Items = #names > 0 and names or { "-" }, Search = true, Callback = function(v) chosen = v end })
	Places:Button({ Title = "Teleport", Icon = "map-pin", Style = "Primary", Callback = function()
		local p = byName[chosen or ""]
		if p then tpTo(CFrame.new(p[2], p[3], p[4])) else notify("Teleport", "Pick one from the list first", "list", "warning") end
	end })
	if #names == 0 then Places:Paragraph({ Title = "Note", Content = "No saved locations for this map. Use the quick spots on the right." }) end

	local Quick = MapPage:Card({ Title = "Quick", Icon = "zap", Side = "Right" })
	local function quick(title, icon, fn)
		Quick:Button({ Title = title, Icon = icon, Align = "Left", Callback = function()
			local ok = fn()
			if not ok then notify("Teleport", title .. " is not on this map", "triangle-alert", "warning") end
		end })
	end
	quick("Spawn", "house", function()
		local sp = workspace:FindFirstChild("SpawnLocation")
		if sp then tpTo(sp.CFrame + Vector3.new(0, 3, 0)) return true end
	end)
	quick("Duel pads", "swords", function()
		local d = workspace:FindFirstChild("map2") and workspace.map2:FindFirstChild("duel")
		local pad = d and d:FindFirstChild("pad", true)
		if pad and not pad:IsA("BasePart") then pad = pad:FindFirstChildWhichIsA("BasePart", true) end
		if pad then tpTo(pad.CFrame + Vector3.new(0, 3, 0)) return true end
	end)
	quick("Ramen", "soup", function()
		local r = workspace:FindFirstChild("EAT") and workspace.EAT:FindFirstChild("Ramen")
		local part = r and (r:IsA("BasePart") and r or r:FindFirstChildWhichIsA("BasePart", true))
		if part then tpTo(part.CFrame + Vector3.new(0, 3, 0)) return true end
	end)
	quick("Mentor", "graduation-cap", function()
		local s = workspace:FindFirstChild("sensei")
		local g = s and s:FindFirstChild("missions") and s.missions:GetChildren()[1]
		local hrp = g and g:FindFirstChild("missiongiver") and g.missiongiver:FindFirstChild("HumanoidRootPart")
		if hrp then tpTo(hrp.CFrame + Vector3.new(0, 0, 4)) return true end
		local ken = workspace:FindFirstChild("Ken Mentor")
		if ken and ken:FindFirstChild("HumanoidRootPart") then tpTo(ken.HumanoidRootPart.CFrame + Vector3.new(-6, 4, 0)) return true end
	end)
	quick("Susanoo customizer", "sparkles", function()
		local s = workspace:FindFirstChild("Susanoo Customizer")
		local part = s and (s:FindFirstChild("HumanoidRootPart") or s:FindFirstChildWhichIsA("BasePart", true))
		if part then tpTo(part.CFrame + Vector3.new(0, 3, 4)) return true end
	end)

	local Afk = MapPage:Card({ Title = "AFK (My Home)", Icon = "bed", Side = "Right" })
	local function apartment()
		local map = workspace:FindFirstChild("map")
		return map and map:FindFirstChild(LocalPlayer.Name .. "apartment")
	end
	local AFK = { { "Bed", "afkreward" }, { "Ramen", "Ramen" } }
	for _, a in ipairs(AFK) do
		Afk:Button({ Title = a[1], Icon = a[1] == "Bed" and "bed" or "soup", Align = "Left", Callback = function()
			local ap = apartment()
			local part = ap and ap:FindFirstChild(a[2])
			if part then tpTo(part.CFrame) else notify("AFK", "Only in My Home", "triangle-alert", "warning") end
		end })
	end
	local seatRow = Afk:Row({ Gap = 4 })
	for i = 1, 4 do
		seatRow:Button({ Title = "Seat " .. i, Size = "Small", Callback = function()
			local ap = apartment()
			local model = ap and ap:FindFirstChild("Model")
			local seats = {}
			if model then for _, s in ipairs(model:GetChildren()) do if s:IsA("Seat") then seats[#seats + 1] = s end end end
			if seats[i] then tpTo(seats[i].CFrame) else notify("AFK", "Seat not found (are you in My Home?)", "triangle-alert", "warning") end
		end })
	end

	local S = ServerPage:Card({ Title = "Map teleport", Icon = "map", Desc = "From the menu's map list" })
	local maps = {}
	pcall(function()
		for _, v in ipairs(mainGui().ingame.Menu.ArenaTab.List:GetChildren()) do
			if v:FindFirstChild("place") then maps[#maps + 1] = v.Name end
		end
		table.sort(maps)
	end)
	local mapPick
	S:Dropdown({ Title = "Map", Flag = "tp_map", Items = #maps > 0 and maps or { "-" }, Search = true, Callback = function(v) mapPick = v end })
	S:Button({ Title = "Teleport to map", Icon = "plane", Style = "Primary", Callback = function()
		local ok, place = pcall(function() return mainGui().ingame.Menu.ArenaTab.List[mapPick].place.Value end)
		if ok and place then fire("rpgteleport", place) else notify("Map teleport", "Pick one from the list first", "list", "warning") end
	end })
	local Priv = ServerPage:Card({ Title = "Private server", Icon = "lock", Side = "Right" })
	local code = ""
	Priv:Input({ Title = "Code", Placeholder = "private server code", Flag = "tp_pscode", Finished = false, Callback = function(t) code = t end })
	Priv:Button({ Title = "Join private server", Icon = "log-in", Callback = function()
		if code == "" then return notify("Private server", "Enter the code first", "triangle-alert", "warning") end
		fire("teleporttoprivate", code)
	end })
end

------------------------------------------------------------------ LOADOUT
do
local function showBloodlineCodes()
	local gui = mainGui()
	if not gui then return notify("Code names", "Menu not found", "triangle-alert", "warning") end
	local count = 0
	for _, root in ipairs({ gui:FindFirstChild("Customization") and gui.Customization:FindFirstChild("Genkaibag"),
		gui:FindFirstChild("ingame") and gui.ingame:FindFirstChild("Menu") }) do
		local tab = root and (root:FindFirstChild("BossTab", true))
		if tab then
			for _, v in ipairs(tab:GetChildren()) do
				if v:FindFirstChild("name") then
					v.name.Text = v.Name
					if v:FindFirstChild("rarity") then v.rarity.Text = "Please enter these names" end
					count += 1
				end
			end
		end
	end
	notify("Code names", count > 0 and ("Showed " .. count .. " code names in the bloodline bag") or "Open the bloodline bag and try again", "scan-search")
end

local function refreshRCNames()
	pcall(function()
		local shop = mainGui().RYOshop.Shoplimited.BossTabb
		for i = 1, 3 do shop["bg" .. i].kg.name.Text = workspace.RCGENKAI["item" .. i].Value end
	end)
end
local function showShopCodes()
	local ok = pcall(function()
		local items = mainGui().RYOshop.ShopItems
		for _, v in ipairs(items.bigshop:GetChildren()) do
			if v:FindFirstChild("purchase") then v.purchase.Text = v.Name end
		end
		for _, v in ipairs(items.limitedshop:GetChildren()) do
			if v:FindFirstChild("kg") then v.kg.ryo2.Text = v.Name end
		end
	end)
	refreshRCNames()
	notify("Code names", ok and "Showed code names in the RC Shop" or "RC Shop not found", ok and "scan-search" or "triangle-alert", not ok and "warning" or nil)
end
local function setShopVisible(on)
	pcall(function()
		local gui = mainGui()
		gui.RYOshop.Visible = on
		gui.Blur.Visible = not on
		gui.ingame.Menu.Visible = not on
	end)
end
------------------------------------------------------------------ seçim listeleri (oyunun kendi verisinden okunur)
local function childNames(folder)              -- listede oyunun orijinal (kod) adları görünür
	local out = {}
	if folder then
		for _, v in ipairs(folder:GetChildren()) do out[v.Name] = true end
	end
	return out
end

local Lists = {}
local function buildLists()
	local alljutsu = ReplicatedStorage:FindFirstChild("alljutsu")
	local gui = mainGui()
	local el, bl = {}, {}
	if alljutsu then                               -- oyunun kendi işaretleri: ELEMENT / KG
		for _, v in ipairs(alljutsu:GetChildren()) do
			if v:FindFirstChild("ELEMENT") then el[v.Name] = true end
			if v:FindFirstChild("KG") then bl[v.Name] = true end
		end
	end
	Lists.element = el
	Lists.bloodline = bl
	Lists.kenjutsu = childNames(alljutsu and alljutsu:FindFirstChild("ALLKENSTYLES"))
	Lists.style = childNames(alljutsu and alljutsu:FindFirstChild("FIGHTINGSTYLES"))
	local shop = gui and gui:FindFirstChild("RYOshop") and gui.RYOshop:FindFirstChild("ShopItems")
	Lists.cloth = childNames(shop and shop:FindFirstChild("bigshop"))
	local limited = childNames(shop and shop:FindFirstChild("limitedshop"))
	for code in pairs(bl) do limited[code] = true end
	Lists.limited = limited
end
local function count(map) local n = 0 for _ in pairs(map) do n += 1 end return n end
local EMPTY = { "-" }
local function sourceOf(key, code)              -- REALNAME'in okunacağı obje
	local aj = ReplicatedStorage:FindFirstChild("alljutsu")
	if not aj then return nil end
	if key == "kenjutsu" then local f = aj:FindFirstChild("ALLKENSTYLES") return f and f:FindFirstChild(code) end
	if key == "style" then local f = aj:FindFirstChild("FIGHTINGSTYLES") return f and f:FindFirstChild(code) end
	if key == "cloth" then return nil end
	return aj:FindFirstChild(code)
end
local function itemsOf(key)                    -- alfabetik sıralı ad listesi (oyundaki gerçek isimler)
	local out = {}
	for code in pairs(Lists[key] or {}) do out[#out + 1] = labelFor(code, sourceOf(key, code)) end
	table.sort(out, function(a, b) return a:lower() < b:lower() end)
	return #out > 0 and out or EMPTY
end

local picks = { element = nil, bloodline = nil, kenjutsu = nil, style = nil, cloth = nil, limited = nil }
local dropdowns = {}
local function pickSet(key) return function(v) picks[key] = (v ~= "-" and v ~= nil) and toCode(v) or nil end end
local function need(key, label)
	local v = picks[key]
	if not v then notify(label, "Pick one from the list first", "list", "warning") end
	return v
end
local function refreshLists(silent)
	buildLists()
	for key, dd in pairs(dropdowns) do pcall(function() dd:SetItems(itemsOf(key), true) end) end
	if not silent then
		notify("Lists refreshed", ("%d bloodlines · %d elements · %d kenjutsu · %d styles · %d clothes"):format(
			count(Lists.bloodline), count(Lists.element), count(Lists.kenjutsu), count(Lists.style), count(Lists.cloth)), "refresh-cw")
	end
end
buildLists()

------------------------------------------------------------------ LOADOUT
local Loadout = Tabs.Loadout:Page("Changer")

local Elem = Loadout:Card({ Title = "Element", Icon = "flame", Desc = "Change element slots" })
dropdowns.element = Elem:Dropdown({ Title = "Element", Flag = "ld_elem", Items = itemsOf("element"), Search = true, Callback = pickSet("element") })
local elemRow = Elem:Row({ Gap = 4 })
for i = 1, 4 do
	elemRow:Button({ Title = "Slot " .. i, Size = "Small", Callback = function()
		local v = need("element", "Element") if not v then return end
		setValue(function() return statz().main["element" .. i] end, v, "Element slot " .. i)
	end })
end

local Blood = Loadout:Card({ Title = "Bloodline", Icon = "dna", Side = "Right", Desc = "Change bloodline slots" })
dropdowns.bloodline = Blood:Dropdown({ Title = "Bloodline", Flag = "ld_bl", Items = itemsOf("bloodline"), Search = true, Callback = pickSet("bloodline") })
local blRow = Blood:Row({ Gap = 4 })
for i = 1, 4 do
	blRow:Button({ Title = "Slot " .. i, Size = "Small", Callback = function()
		local v = need("bloodline", "Bloodline") if not v then return end
		setValue(function() return statz().main["kg" .. i] end, v, "Bloodline slot " .. i)
	end })
end

local Ken = Loadout:Card({ Title = "Kenjutsu", Icon = "sword" })
dropdowns.kenjutsu = Ken:Dropdown({ Title = "Kenjutsu", Flag = "ld_ken", Items = itemsOf("kenjutsu"), Search = true, Callback = pickSet("kenjutsu") })
Ken:Button({ Title = "Equip kenjutsu", Icon = "sword", Style = "Primary", Callback = function()
	local v = need("kenjutsu", "Kenjutsu") if not v then return end
	setValue(function() return statz().breathingstyle end, v, "Kenjutsu")
end })

local Martial = Loadout:Card({ Title = "Martial art", Icon = "hand-fist", Side = "Right" })
dropdowns.style = Martial:Dropdown({ Title = "Fighting style", Flag = "ld_fs", Items = itemsOf("style"), Search = true, Callback = pickSet("style") })
local fsRow = Martial:Row()
fsRow:Button({ Title = "Change animation", Icon = "repeat", Size = "Small", Callback = function()
	local v = need("style", "Animasyon") if not v then return end
	setValue(function() return statz().fightingstyle end, v, "Animasyon")
end })
fsRow:Button({ Title = "Buy style", Icon = "store", Size = "Small", Style = "Soft", Confirm = "Sure?", Callback = function()
	local v = need("style", "Fighting style") if not v then return end
	local aj = ReplicatedStorage:FindFirstChild("alljutsu")
	local fsFolder = aj and aj:FindFirstChild("FIGHTINGSTYLES")
	local style = fsFolder and fsFolder:FindFirstChild(v)
	if not style then return notify("Fighting style", v .. " not found", "triangle-alert", "warning") end
	fire("selectmartialstyle", style)
	notify("Fighting style", v .. " requested", "store")
end })

local Tools = Loadout:Card({ Title = "Lists", Icon = "list", Wide = "Bottom" })
local toolRow = Tools:Row()
toolRow:Button({ Title = "Refresh lists", Icon = "refresh-cw", Callback = function() refreshLists(false) end })
toolRow:Button({ Title = "Show code names", Icon = "scan-search", Callback = showBloodlineCodes })
Tools:Paragraph({ Title = "Note", Content = "Lists show the game's real names. If a list is empty, press Refresh lists once you're fully in the game. Changes are client side." })

------------------------------------------------------------------ RC SHOP
local Shop = Tabs.Loadout:Page("RC Shop")
local ShopCard = Shop:Card({ Title = "Shop", Icon = "store" })
ShopCard:Button({ Title = "Show RC Shop", Icon = "eye", Toggle = true, OnTitle = "Hide RC Shop", OnIcon = "eye-off",   -- Flag yok: açılışta mağaza kendiliğinden açılmasın
	Callback = function(on) setShopVisible(on) end })
ShopCard:Button({ Title = "Show code names", Icon = "scan-search", Callback = showShopCodes })
ShopCard:Button({ Title = "Refresh lists", Icon = "refresh-cw", Style = "Ghost", Callback = function() refreshLists(false) end })
ShopCard:Paragraph({ Title = "Note", Content = "Changes shop items on your screen only. If the clothing list is empty, open the RC Shop once and press Refresh lists." })

local Cloth = Shop:Card({ Title = "Clothings", Icon = "shirt", Side = "Right", Desc = "4-hour shop" })
dropdowns.cloth = Cloth:Dropdown({ Title = "Clothing", Flag = "rc_cloth", Items = itemsOf("cloth"), Search = true, Callback = pickSet("cloth") })
local clothRow = Cloth:Row({ Gap = 4 })
for i = 1, 4 do
	clothRow:Button({ Title = "Slot " .. i, Size = "Small", Callback = function()
		local v = need("cloth", "Clothing") if not v then return end
		setValue(function() return workspace["4hourshop"]["item" .. i] end, v, "Clothing slot " .. i)
	end })
end

local Rare = Shop:Card({ Title = "Limited bloodlines", Icon = "dna", Desc = "RC Genkai shop" })
dropdowns.limited = Rare:Dropdown({ Title = "Limited bloodline", Flag = "rc_rare", Items = itemsOf("limited"), Search = true, Callback = pickSet("limited") })
local rareRow = Rare:Row({ Gap = 4 })
for i = 1, 3 do
	rareRow:Button({ Title = "Slot " .. i, Size = "Small", Callback = function()
		local v = need("limited", "Limited bloodline") if not v then return end
		setValue(function() return workspace.RCGENKAI["item" .. i] end, v, "Limited slot " .. i)
		refreshRCNames()
	end })
end

task.delay(4, function() if HUB.Running then refreshLists(true) end end)    -- menü geç yüklenirse listeleri bir kez daha oku
end

------------------------------------------------------------------ kilit ikonu
-- Bağlı olduğu ayar kapalıyken satır grileşir; başlığın yanında sadece küçük bir kilit görünür (yazı yok).
do
	local marks = {}
	for _, el in pairs(Window.flags or {}) do
		local row = type(el) == "table" and el.Row
		local title = row and row:FindFirstChild("Title")
		if title and not marks[el] then
			local ok, img = pcall(function()
				return Lib.Icons.Image("lock", { Size = UDim2.fromOffset(10, 10), Color = Color3.fromRGB(150, 155, 168) })
			end)
			if ok and img then
				img.AnchorPoint = Vector2.new(0, 0.5)
				img.ZIndex = 23
				img.Visible = false
				img.Parent = row
				marks[el] = { img = img, title = title }
			end
		end
	end
	loop("Lock icons", 0.15, function()
			for el, m in pairs(marks) do
				local show = el._depLocked == true and m.title.Parent ~= nil
				m.img.Visible = show
				if show then
					local row = el.Row
					m.img.Position = UDim2.fromOffset(
						m.title.AbsolutePosition.X - row.AbsolutePosition.X + m.title.TextBounds.X + 5,
						m.title.AbsolutePosition.Y - row.AbsolutePosition.Y + m.title.AbsoluteSize.Y / 2)
				end
			end
	end)
end

------------------------------------------------------------------ açılış
Window:SettingsTab()
Window.Config:LoadAutoLoad()
for _, fn in ipairs(HUB.AfterAutoLoad or {}) do pcall(fn) end
Window:Notify({ Title = "Qustāh Shindo", Content = "Loaded · " .. placeName() .. " · RShift to toggle", Icon = "sparkles" })

]============]

loadstring(SOURCE)(SCRIPT_URL, SOURCE)