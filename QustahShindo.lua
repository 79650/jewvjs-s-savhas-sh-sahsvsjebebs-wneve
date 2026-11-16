-- Qustāh · Shindo Life · V1.68

-- After a teleport the hub reloads itself from this raw link (queue_on_teleport)
local rawLink = "https://raw.githubusercontent.com/79650/jewvjs-s-savhas-sh-sahsvsjebebs-wneve/refs/heads/main/QustahShindo.lua"

local env = (getgenv and getgenv()) or _G

if game.GameId ~= 1511883870 then                               -- Shindo Life only
	warn("Qustāh Shindo: this game is not Shindo Life, script not loaded")
	return
end
repeat task.wait() until game:IsLoaded()

if env.QustahShindoCore and env.QustahShindoCore.Unload then
	pcall(env.QustahShindoCore.Unload)
end
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/79650/gwanjkcdsjawbdnjascdas-ui-lib/refs/heads/main/qustah-ui-lib/dist/qustah-ui-lib.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

----- Places -----
local places = {
	mainMenu = 4616652839, myHome = 5451410109, dungeonSelect = 7524809704, tournament = 6602058266,
}
local function placeKind()
	local id = game.PlaceId
	if id == places.mainMenu then return "menu" end
	if id == places.myHome then return "home" end
	if id == places.dungeonSelect then return "dungeonselect" end
	if id == places.tournament then return "tournament" end
	if workspace:FindFirstChild("dungeons") then return "dungeon" end
	if workspace:FindFirstChild("cutscene") then return "eventboss" end
	if workspace:FindFirstChild("bossbattle") then return "bossbattle" end
	return "map"
end
local placeType = placeKind()
local placeTypeNames = {
	menu = "Main menu", home = "My Home", dungeonselect = "Dungeon select", tournament = "Tournament",
	dungeon = "Dungeon", eventboss = "Event boss", bossbattle = "Boss battle", map = "Map",
}
local function placeName() return placeTypeNames[placeType] or "Map" end

local queue = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
local hubQueued = false
local hubStopFile = "QustahShindoHub.stop"
local rellStopFile = "QustahShindoRELL.stop"
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
local function queueHub()                                       -- re-open the hub after a teleport
	if not queue or not (isfile and writefile and delfile) then return end
	if not queuePermission(hubStopFile, true) or hubQueued then return end
	local code = ("loadstring(game:HttpGet(%q, true))()"):format(rawLink)
	local ok, result = pcall(queue, guardQueue(hubStopFile, code))
	hubQueued = ok and result ~= false
end

----- Shared helpers -----
local function statz() return LocalPlayer:FindFirstChild("statz") end
local function mainGui() return LocalPlayer.PlayerGui:FindFirstChild("Main") end
local function character() return LocalPlayer.Character end
local function rootPart() local c = character() return c and c:FindFirstChild("HumanoidRootPart") end
local function fire(...)                                         -- startevent: spins, claims, teleports...
	local ev = LocalPlayer:FindFirstChild("startevent")
	if ev then ev:FireServer(...) end
end
local function combat(...)                                       -- the character's combat remote: keys, M1
	local c = character()
	local u = c and c:FindFirstChild("combat") and c.combat:FindFirstChild("update")
	if u then u:FireServer(...) end
end
local function rellCoinOut()                                      -- the game's "Not Enough RELL Coin." notification
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
-- Mission state: the game's own "currentmission" value (ObjectValue). The mission UI stays open after a mission ends, so it is not reliable;
-- if currentmission is missing (older builds etc.) the mission UI is used as a fallback.
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
local function missionInfo(m)                                    -- mission text, type and target position
	local function val(n) local o = m and m:FindFirstChild(n) return o and o.Value end
	local t = val("target")
	local pos
	if typeof(t) == "Instance" and t:IsA("BasePart") then pos = t.Position
	elseif typeof(t) == "Instance" and t:IsA("Model") then pos = t:GetPivot().Position
	elseif typeof(t) == "Vector3" then pos = t end
	local text, objective = val("text"), val("objective")
	return type(text) == "string" and text or nil, type(objective) == "string" and objective or nil, pos
end
local function fireVC(command)                                   -- fires workspace.VC.RemoteEvent directly (no chat message is sent)
	local vc = workspace:FindFirstChild("VC")
	local re = vc and vc:FindFirstChild("RemoteEvent")
	if re then re:FireServer(command) return true end
	return false
end
local function cancelMission() return fireVC("!cancel") end
-- Display names: every entry in alljutsu has a REALNAME value. Lists show that name; the code name is used internally.
local Names = { code = {}, label = {} }                          -- code[display] = code name, label[code name] = display
local function realName(inst)
	local r = inst and inst:FindFirstChild("REALNAME")
	local v = r and r.Value
	return (type(v) == "string" and v ~= "") and v or nil
end
local function labelFor(code, inst)
	if Names.label[code] then return Names.label[code] end
	local n = realName(inst) or code
	if Names.code[n] and Names.code[n] ~= code then n = n .. " (" .. code .. ")" end   -- two entries with the same display name
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
-- anyHealth: also count mobs whose health is 0 on the client but which are still alive on the server.
-- (We set their health to 0 locally while attacking; the Humanoid is removed once the mob really dies. DogeHub checks the same thing.)
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
local function susanooNPCs()                                      -- is there a mob that cannot be hit (full susanoo)?
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
	if cam and (pos - cam.CFrame.Position).Magnitude > 0.001 then cam.CFrame = CFrame.new(cam.CFrame.Position, pos) end
end

local Window, unloadThis
-- Hub loops: all of them stop on Unload, an error in one iteration does not kill the loop, and errors are reported to Settings › Info.
local hub = { Running = true, Conns = {}, Err = {}, Cleanup = {} }
local function hubError(tag, err)
	local now = os.clock()
	if hub.Err[tag] and now - hub.Err[tag] < 10 then return end    -- report the same source at most once every 10 s
	hub.Err[tag] = now
	if Window then pcall(function() Window:ReportError(tag, tostring(err)) end) end
end
local function loop(tag, interval, fn)                          -- interval: a number or a function returning a number
	task.spawn(function()
		while hub.Running do
			local okDelay, delay = pcall(function() return type(interval) == "function" and interval() or interval end)
			if not okDelay then hubError(tag .. " interval", delay) end
			task.wait(okDelay and type(delay) == "number" and delay == delay and delay >= 0 and delay < math.huge and delay or 0.25)
			if not hub.Running then break end
			local ok, err = pcall(fn)
			if not ok then hubError(tag, err) end
		end
	end)
end
local function hubConnect(signal, fn)
	local c = signal:Connect(function(...)
		if not hub.Running then return end
		local ok, err = pcall(fn, ...)
		if not ok then hubError("Event", err) end
	end)
	hub.Conns[#hub.Conns + 1] = c
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

-- invisible platform that prevents falling (kept under the feet while farming)
local Platform
local platformUsers = 0
local platformFixed                                              -- boss safe spot: the platform stays fixed there
local SafePart                                                   -- boss safe zone (client-side floor)
local function platformOn()
	platformUsers += 1
	if Platform then return end
	Platform = Instance.new("Part")
	Platform.Anchored, Platform.Transparency, Platform.Size, Platform.CanCollide = true, 1, Vector3.new(6, 1, 6), true
	Platform.Parent = workspace
	task.spawn(function()
		local mine = Platform
		while Platform == mine do                                  -- if it is rebuilt, the old loop exits
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
local function hubStop()                                         -- Unload: loops, events, platform
	hub.Running = false
	queuePermission(hubStopFile, false)
	queuePermission(rellStopFile, false)
	for _, fn in ipairs(hub.Cleanup) do pcall(fn) end
	table.clear(hub.Cleanup)
	for _, c in ipairs(hub.Conns) do pcall(function() c:Disconnect() end) end
	table.clear(hub.Conns)
	platformUsers = 0
	platformFixed = nil
	if Platform then pcall(function() Platform:Destroy() end) Platform = nil end
	if SafePart then pcall(function() SafePart:Destroy() end) SafePart = nil end
end
-- Boss safe spot: 1000 studs above the mission giver's talk part (the part with the scroll).
-- The mission does not end right after the boss dies and full-susanoo bosses cannot be hit, so we wait here until the next boss.
local safeHeight = 1000
local function giverTalkPart(giver)
	local mg = giver and giver:FindFirstChild("missiongiver")
	return mg and mg:FindFirstChild("HumanoidRootPart")
end
-- Safe zone: an 85x85 client-side floor. You can move freely on it (no constant teleporting);
-- if you walk off or fall, you are put back in the middle.
local safeSize = Vector3.new(85, 2, 85)
-- Distance from the root part to the feet while standing. Reading the animated leg position is unreliable
-- (QustahInfo measured 3.26 while running and 2.04 while falling; the real floor distance was 2.88), so the rig's own size is used:
-- R6: half the root + leg height (0.96 + 1.92 = 2.88) · R15: HipHeight + half the root.
local function rootToFeet(c, r)
	local h = c:FindFirstChildOfClass("Humanoid")
	local r15 = h and select(2, pcall(function() return h.RigType == Enum.HumanoidRigType.R15 end)) == true
	if r15 and h.HipHeight > 0 then return h.HipHeight + r.Size.Y / 2 end
	local leg = c:FindFirstChild("Left Leg") or c:FindFirstChild("Right Leg")
	if leg and leg:IsA("BasePart") then return r.Size.Y / 2 + leg.Size.Y end
	return r.Size.Y / 2 + 2
end
local function safeStandCF(part)                                  -- exactly on top of the floor (+0.15 margin), never inside it
	local c, r = character(), rootPart()
	local up = part.Size.Y / 2 + 0.15 + ((c and r) and rootToFeet(c, r) or 3)
	return part.CFrame * CFrame.new(0, up, 0)
end
-- The game's movement systems (wall walk / tree jump / water walk) probably detect the ground from parts in workspace.map;
-- with our part at the workspace root in the Default collision group the character sank into it.
-- So the safe floor is cloned from a real ground part of the map and parented next to it (workspace.map).
local function mapGroundTemplate()
	local r, c = rootPart(), character()
	if r then                                                     -- first, the part under your feet
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { c, SafePart, Platform }
		local hit = workspace:Raycast(r.Position, Vector3.new(0, -60, 0), params)
		local p = hit and hit.Instance
		if p and p:IsA("Part") and p.Anchored and p.CanCollide and p.Parent and p.Parent ~= workspace.CurrentCamera then return p end
	end
	local map = workspace:FindFirstChild("map")                  -- otherwise a large, flat part from the map
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
		pcall(function() SafePart:ClearAllChildren() end)           -- do not copy textures, scripts etc.
		SafePart.Name = "QustahSafe"
		SafePart.Anchored, SafePart.CanCollide, SafePart.Size = true, true, safeSize
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
local function onSafePart(r, part)                               -- is the player on the floor (with some room for jumping)
	local rel = part.CFrame:PointToObjectSpace(r.Position)
	return math.abs(rel.X) <= part.Size.X / 2 + 1 and math.abs(rel.Z) <= part.Size.Z / 2 + 1 and rel.Y > -1 and rel.Y < 60
end
local function goSafe(giver)
	local talk = giverTalkPart(giver)
	if not talk then return false end
	local part = safePartAt(CFrame.new(talk.Position + Vector3.new(0, safeHeight, 0)))
	platformFixed = part.CFrame * CFrame.new(0, -12, 0)            -- the follow platform is parked below the floor so the two do not overlap and push you around
	local r = rootPart()
	if r and not onSafePart(r, part) then tpTo(safeStandCF(part)) r.AssemblyLinearVelocity = Vector3.zero end
	return true
end
local function leaveSafe()
	platformFixed = nil
	if SafePart then SafePart:Destroy() SafePart = nil end
end
-- Anti-slide: on the safe floor, horizontal velocity is cleared while no movement key is pressed (leftover momentum from teleports etc.)
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

-- attack an NPC: stand above / behind it, face it, press keys + M1
local Attack = { Height = 0, Distance = 10, Mode = "Legacy (M1 + E)" }   -- Height / Distance are fixed (no setting); Legacy is on by default (as in DogeHub)
-- Melee / Legacy distance depends on the fighting style (as in DogeHub): short-range styles 7, others 10 studs
local shortStyles = { [""] = true, boxing = true, jeetkunedo = true, muaythai = true, mma = true }
local function meleeDistance()
	local st = LocalPlayer:FindFirstChild("statz")
	local fs = st and st:FindFirstChild("fightingstyle")
	if not fs or shortStyles[fs.Value] then return 7 end
	return 10
end
local function attackNPC(v)
	local hrp = v:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local ae = v:FindFirstChild("antiexploit")                     -- remove the mob's protection (as in NukeVsCity)
	if ae then ae:Destroy() end
	lookAt(hrp.Position)
	if Attack.Mode == "Melee (M1)" then
		tpTo(hrp.CFrame * CFrame.new(0, 0, meleeDistance()))
		combat("mouse1", true)
	elseif Attack.Mode == "Legacy (M1 + E)" then                -- stay close, both M1 and E
		tpTo(hrp.CFrame * CFrame.new(0, 0, meleeDistance()))
		combat("mouse1", true)
		combat("key", "e") combat("key", "eend")
	else
		tpTo(hrp.CFrame * CFrame.new(0, Attack.Height, Attack.Distance))
		for _ = 1, 3 do combat("key", "e") combat("key", "eend") end
	end
	pcall(function() v.Humanoid.Health = -v.Humanoid.Health end)   -- set health to its negative, as NukePlat does (client side)
	hub.AuraTarget = v                                           -- let the kill aura hit the farm's current target
end

----- Window -----
Window = Lib:CreateWindow({
	Title = "Qustāh",
	Version = "V1.68",
	Folder = "QustahShindo",
	Tags = { "SHINDO" },
	ToggleKey = Enum.KeyCode.RightShift,
	Size = Vector2.new(600, 440),
	PageTabs = "Header",                                          -- page names sit in the title row, like Dashboard / Settings
	OnClose = function() if unloadThis then unloadThis() end end,
})

Window:DashboardTab({ Info = {
	{ "Location", placeName() },
	{ "Spin", tostring(statz() and statz():FindFirstChild("spins") and statz().spins.Value or "-") },
	{ "Rank", tostring(statz() and statz():FindFirstChild("prestige") and statz().prestige:FindFirstChild("rank") and statz().prestige.rank.Value or "-") },
	{ "queue_on_teleport", queue and "Yes" or "No" },
} })

local Tabs = {
	Farm = Window:Tab({ Title = "Farm", Icon = "swords" }),
	Spin = placeType == "menu" and Window:Tab({ Title = "Spin", Icon = "dices" }) or nil,   -- spins only work in the main menu
	Combat = Window:Tab({ Title = "Combat", Icon = "crosshair", Compact = true }),
	Visuals = Window:Tab({ Title = "Visuals", Icon = "eye" }),
	Player = Window:Tab({ Title = "Player", Icon = "user-round-cog" }),
	Loadout = Window:Tab({ Title = "Loadout", Icon = "dna" }),
	Server = Window:Tab({ Title = "Server", Icon = "server", Compact = true }),
}
-- Player tab: four pages, Player (game features), Movement, Teleports and Colors
local playerPage = Tabs.Player:Page("Player")
local movementPage = Tabs.Player:Page("Movement", { Compact = true })
local teleportsPage = Tabs.Player:Page("Teleports")
local colorsPage = Tabs.Player:Page("Colors")

if placeType == "tournament" then
	Window:Notify({ Title = "Tournament", Content = "You are in tournament mode. Exploiting here can easily get you banned.", Icon = "triangle-alert", Color = "warning" })
end

----- Universal: Silent Aim · ESP · World · Player · Server -----
do
----- Services -----
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
-- The real reference for hook comparisons: a cloneref copy is not == to the game's workspace
local RealWorkspace = workspace
local FindFirstChild = game.FindFirstChild                      -- a plain call so no namecall happens inside the hook

local env = (getgenv and getgenv()) or _G

local Running = true
local Connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    Connections[#Connections + 1] = c
    return c
end

local newcclosure = newcclosure or function(f) return f end
local vec2, vec3, cframe, rgb = Vector2.new, Vector3.new, CFrame.new, Color3.new
local floor, clamp, max, min, rad, tan = math.floor, math.clamp, math.max, math.min, math.rad, math.tan
local black, white = rgb(0, 0, 0), rgb(1, 1, 1)

----- Settings -----
local settings = {
    -- silent aim
    SA_Enabled = false, SA_HitChance = 100, SA_Part = "Head", SA_Priority = "Mouse",
    SA_Methods = { Raycast = true, FindPartOnRay = true, ["Mouse.Hit"] = true },
    SA_TeamCheck = false, SA_VisCheck = false, SA_IgnoreFriends = false, SA_MaxDist = 1000, SA_SafeOrigin = true,
    SA_Predict = false, SA_PredStrength = 100, SA_Whitelist = {},
    -- fov
    FOV_Show = true, FOV_Radius = 120, FOV_Sides = 64, FOV_Thick = 1, FOV_Color = rgb(1, 1, 1), FOV_Alpha = 0,
    FOV_Filled = false, FOV_Origin = "Mouse", FOV_TargetLine = false,
    -- esp
    ESP_Enabled = false, ESP_TeamCheck = true, ESP_MaxDist = 1500,
    Box = true, BoxStyle = "Corner", BoxCorner = 30, BoxFill = false, BoxFillAlpha = 0.85, HealthBar = true, ModeBar = true, Outline = true,
    HealthPreset = "Classic", ModePreset = "Ocean", ModeFlash = true,
    Name = true, DisplayName = true, HealthText = true, Distance = true, DistUnit = "Studs", Weapon = true, TextSize = 13,
    Chams = true, ChamsWalls = true, ChamsFill = 0.6, ChamsOutline = rgb(1, 1, 1),
    Tracer = false, TracerFrom = "Bottom", Skeleton = false, LookDir = false, HeadDot = false,
    LineThick = 1, LineAlpha = 0, LineRainbow = false,                -- shared style of tracer, look direction, skeleton and head dot
    ColEnemy = rgb(1, 0.23, 0.23), ColAlly = rgb(0.23, 1, 0.42), ColHidden = rgb(1, 0.69, 0.23), ColTarget = rgb(0.75, 0.45, 1),
    UseTeamColor = false, VisColor = true, Fade = true, Perf = false,
    -- world
    Fullbright = false, NoFog = false, CustomTime = false, ClockTime = 14, NoShadows = false,
    CustomAmbient = false, Ambient = rgb(0.7, 0.7, 0.7),
    -- player
    SpeedOn = false, WalkSpeed = 16, JumpOn = false, JumpPower = 50, InfJump = false,
    NoClip = false, AntiAfk = true, ClickTP = false, UnlockZoom = false,
    -- server
    StaffAlert = false, StaffGroup = 0, StaffRank = 1, StaffAction = "Notify", AutoRejoin = false,
}
local function set(key) return function(v) settings[key] = v end end
local function toSet(list)
    local out = {}
    for _, v in ipairs(type(list) == "table" and list or {}) do out[v] = true end
    return out
end

----- Render: Drawing -----
-- Everything on screen is drawn with the executor's Drawing API (no Roblox GUI objects).
local Render = { Available = type(Drawing) == "table" and type(Drawing.new) == "function" }
Render.Unsupported = {}
function Render.new(kind)
    if Render.Unsupported[kind] then return nil end
    local ok, object = pcall(Drawing.new, kind)
    if not ok or not object then                                -- a shape this executor lacks is skipped, not reported
        Render.Unsupported[kind] = true
        return nil
    end
    return object
end
function Render.remove(o)
    pcall(function() o:Remove() end)
end
function Render.flush() end                                      -- Drawing objects update immediately

----- Helpers -----
local function getCharacter(plr)
    local char = plr and plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return end
    return char, hum, root
end
-- Shindo keeps the real health in the character's "fakehealth" value; Humanoid.Health is only the fallback.
local function healthValue(hum)
    local char = hum.Parent
    local fake = char and FindFirstChild(char, "fakehealth")
    return (fake and fake:IsA("ValueBase") and tonumber(fake.Value)) or hum.Health
end
local function healthOf(hum)                                      -- current, max
    local hp = healthValue(hum)
    return hp, math.max(hum.MaxHealth, hp, 1)
end
local function isAlive(hum) return hum and healthValue(hum) > 0 end
-- Shindo's mode meter: character.combat.mode (IntConstrainedValue, normally 0-100). Returns 0-1, or nil without one.
local function modeOf(char)
    local combat = FindFirstChild(char, "combat")
    local mode = combat and FindFirstChild(combat, "mode")
    if not (mode and mode:IsA("ValueBase")) then return nil end
    local value = tonumber(mode.Value)
    if not value then return nil end
    local okMax, maxValue = pcall(function() return mode.MaxValue end)
    maxValue = (okMax and tonumber(maxValue) and maxValue > 0) and maxValue or 100
    return clamp(value / maxValue, 0, 1)
end
-- mode bar colour (Visuals › Style › Mode bar colors): fades from the preset's first colour (empty) to its second
-- (full); with "Flash when full" a full bar pulses to white
local modePresets = {
    Ocean = { Color3.fromRGB(30, 58, 138), Color3.fromRGB(90, 216, 255) },
    Aurora = { Color3.fromRGB(45, 212, 191), Color3.fromRGB(167, 139, 250) },
    Sunset = { Color3.fromRGB(249, 115, 22), Color3.fromRGB(236, 72, 153) },
    Toxic = { Color3.fromRGB(22, 163, 74), Color3.fromRGB(217, 249, 157) },
}
local function modeColorFor(mode)
    local preset = modePresets[settings.ModePreset] or modePresets.Ocean
    local color = preset[1]:Lerp(preset[2], clamp(mode or 1, 0, 1))
    if settings.ModeFlash and mode and mode >= 0.999 then
        color = color:Lerp(Color3.new(1, 1, 1), (math.sin(os.clock() * 8) + 1) / 2 * 0.7)
    end
    return color
end
local function isTeammate(plr)
    if not plr.Team or not LocalPlayer.Team then return false end
    if plr.Neutral or LocalPlayer.Neutral then return false end
    return plr.Team == LocalPlayer.Team
end
local function toScreen(pos)
    local v, on = Camera:WorldToViewportPoint(pos)
    return vec2(v.X, v.Y), on, v.Z
end
-- health bar colour by the chosen preset (Visuals › Style › Health bar colors); "Classic" goes red → yellow → green
local healthPresets = {
    Cool = { rgb(0.71, 0.55, 0.91), rgb(0.5, 0.71, 1) },
    Mono = { rgb(0.36, 0.38, 0.42), rgb(0.93, 0.94, 0.96) },
    Heat = { rgb(1, 0.23, 0.23), rgb(1, 0.82, 0.23) },
}
local function healthColor(p)
    p = clamp(p, 0, 1)
    local preset = healthPresets[settings.HealthPreset]
    if preset then return preset[1]:Lerp(preset[2], p) end
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

-- visibility: up to 10 raycasts per player per second (cached)
local VisParams = RaycastParams.new()
VisParams.FilterType = Enum.RaycastFilterType.Exclude
VisParams.IgnoreWater = true
local VisCache = {}
local function isVisible(plr, char, part)
    local now = os.clock()
    local c = VisCache[plr]
    if c and c.char == char and c.part == part and c.camera == Camera and now - c.t < 0.1 then return c.v end
    VisParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    local origin = Camera.CFrame.Position
    local hit = Workspace:Raycast(origin, part.Position - origin, VisParams)
    local visible = (hit == nil) or hit.Instance:IsDescendantOf(char)
    VisCache[plr] = { t = now, v = visible, char = char, part = part, camera = Camera }
    return visible
end

----- Silent Aim: target selection -----
local Silent = { Target = nil, Hooked = false, IndexHooked = false }
local CanHook = typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" and typeof(checkcaller) == "function"
local RandomPick = {}

local function pickPart(plr, char, mousePos)
    local mode = settings.SA_Part
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
    local best, bestD = nil, math.huge                          -- "Closest": the part closest to the cursor
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
    if settings.FOV_Origin == "Center" then return Camera.ViewportSize / 2 end
    return UserInputService:GetMouseLocation()
end

local function findTarget()
    if not settings.SA_Enabled then return nil end
    local origin = fovOrigin()
    local best, bestScore = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not settings.SA_Whitelist[plr.UserId] then
            local char, hum, root = getCharacter(plr)
            if char and isAlive(hum) and not (settings.SA_TeamCheck and isTeammate(plr)) and not (settings.SA_IgnoreFriends and isFriend(plr)) then
                local dist = (root.Position - Camera.CFrame.Position).Magnitude
                if dist <= settings.SA_MaxDist then
                    local part = pickPart(plr, char, origin)
                    if part then
                        local sp, on = toScreen(part.Position)
                        local fovDist = (sp - origin).Magnitude
                        if on and fovDist <= settings.FOV_Radius and (not settings.SA_VisCheck or isVisible(plr, char, part)) then
                            local score = fovDist
                            if settings.SA_Priority == "Distance" then score = dist
                            elseif settings.SA_Priority == "Health" then score = healthValue(hum) end
                            if score < bestScore then
                                local pos = part.Position
                                if settings.SA_Predict and settings.SA_PredStrength > 0 then              -- 100% = a 1000 studs/s projectile
                                    pos = pos + part.AssemblyLinearVelocity * (dist / 1000) * (settings.SA_PredStrength / 100)
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

local function roll() return math.random(1, 100) <= settings.SA_HitChance end
local function fromShooter(origin)                               -- only redirect rays fired from your own weapon
    if not settings.SA_SafeOrigin then return true end
    if (origin - Camera.CFrame.Position).Magnitude < 25 then return true end
    -- note: calling char:FindFirstChild (a namecall) inside the hook breaks the game's original call
    local char = LocalPlayer.Character
    local head = char and FindFirstChild(char, "Head")
    return head ~= nil and (origin - head.Position).Magnitude < 25
end

local setnamecall = setnamecallmethod
local function installNamecallHook()
    if Silent.Hooked or not CanHook then return Silent.Hooked end
    local old
    local function callOld(method, self, ...)                  -- restore the method name if it changed in between
        if setnamecall then setnamecall(method) end
        return old(self, ...)
    end
    local wrapper = newcclosure(function(self, ...)
        if Running and settings.SA_Enabled and not checkcaller() then
            local t = Silent.Target
            if t then
                local method = getnamecallmethod()
                if self == RealWorkspace then
                    if method == "Raycast" and settings.SA_Methods.Raycast then
                        local origin, direction = ...
                        if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" and fromShooter(origin) and roll() then
                            local args = table.pack(...)
                            local to = t.Position - origin
                            args[2] = to.Unit * max(direction.Magnitude, to.Magnitude + 2)
                            return callOld(method, self, table.unpack(args, 1, args.n))
                        end
                    elseif (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist")
                        and settings.SA_Methods.FindPartOnRay then
                        local ray = ...
                        if typeof(ray) == "Ray" and fromShooter(ray.Origin) and roll() then
                            local args = table.pack(...)
                            local to = t.Position - ray.Origin
                            args[1] = Ray.new(ray.Origin, to.Unit * max(ray.Direction.Magnitude, to.Magnitude + 2))
                            return callOld(method, self, table.unpack(args, 1, args.n))
                        end
                    end
                elseif self == Camera and (method == "ScreenPointToRay" or method == "ViewportPointToRay")
                    and settings.SA_Methods.ScreenPointToRay and roll() then
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

local function installIndexHook()                                -- Mouse.Hit / Mouse.Target (only installed when selected)
    if Silent.IndexHooked or not CanHook then return Silent.IndexHooked end
    local old
    local wrapper = newcclosure(function(self, key)
        if Running and self == Mouse and settings.SA_Enabled and not checkcaller() then
            local t = Silent.Target
            if t then
                if key == "Hit" and settings.SA_Methods["Mouse.Hit"] and roll() then return cframe(t.Position) end
                if key == "Target" and settings.SA_Methods["Mouse.Target"] and roll() then return t.Part end
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

----- ESP -----
local esp = { Entries = {}, Frame = 0 }
local skeletonR15 = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local skeletonR6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }

local function entry(plr)
    local e = esp.Entries[plr]
    if not e then
        e = { Obj = {}, Stamp = {}, Vis = {} }
        esp.Entries[plr] = e
    end
    return e
end
local function use(e, key, kind)                                 -- objects are created on first use
    local o = e.Obj[key]
    if not o then
        o = Render.new(kind)
        if not o then return nil end
        e.Obj[key] = o
    end
    e.Stamp[key] = esp.Frame
    e.Vis[key] = true
    return o
end
-- Hides the objects not used this frame. Visibility is tracked by us: on some executors Drawing
-- properties cannot be read (o.Visible always returns nil), which used to leave ESP on screen after a player left the view.
local function hideUnused(e, all)
    for key, o in pairs(e.Obj) do
        if e.Vis[key] and (all or e.Stamp[key] ~= esp.Frame) then
            local ok = pcall(function() o.Visible = false end)
            e.Vis[key] = false
            if not ok then
                Render.remove(o)
                e.Obj[key], e.Stamp[key] = nil, nil
            end
        end
    end
end
local function removeEntry(plr)
    local e = esp.Entries[plr]
    if not e then return end
    for _, o in pairs(e.Obj) do Render.remove(o) end
    esp.Entries[plr] = nil
    VisCache[plr] = nil
    RandomPick[plr] = nil
end

local function drawLine(e, key, a, b, color, thick, alpha)
    if settings.Outline then
        local o = use(e, key .. "_o", "Line")
        if o then o.From, o.To, o.Color, o.Thickness, o.Transparency, o.ZIndex, o.Visible = a, b, black, thick + 2, alpha, 1, true end
    end
    local l = use(e, key, "Line")
    if l then l.From, l.To, l.Color, l.Thickness, l.Transparency, l.ZIndex, l.Visible = a, b, color, thick, alpha, 2, true end
end
local function drawText(e, key, text, pos, color, size, alpha, center)
    local t = use(e, key, "Text")
    if not t then return nil end
    t.Text, t.Position, t.Color, t.Size, t.Transparency, t.Center, t.Outline, t.ZIndex, t.Visible =
        text, pos, color, size, alpha, center, true, 3, true
    return t
end

-- Chams drawn with Drawing (no Highlight): every visible body part is projected to the screen and its outline
-- (the convex hull of its 8 corners) is filled with two Quads; the hull edges get thin Lines in the outline colour.
local function hull(points)                                       -- monotone chain, counter-clockwise
    table.sort(points, function(a, b) return a.X < b.X or (a.X == b.X and a.Y < b.Y) end)
    local function cross(o, a, b) return (a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X) end
    local lower, upper = {}, {}
    for _, p in ipairs(points) do
        while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do lower[#lower] = nil end
        lower[#lower + 1] = p
    end
    for i = #points, 1, -1 do
        local p = points[i]
        while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do upper[#upper] = nil end
        upper[#upper + 1] = p
    end
    lower[#lower] = nil
    upper[#upper] = nil
    for _, p in ipairs(upper) do lower[#lower + 1] = p end
    return lower
end
local cornerSigns = {
    vec3(1, 1, 1), vec3(1, 1, -1), vec3(1, -1, 1), vec3(1, -1, -1),
    vec3(-1, 1, 1), vec3(-1, 1, -1), vec3(-1, -1, 1), vec3(-1, -1, -1),
}
local function updateChams(e, char, color, alpha)
    local fillAlpha = (1 - settings.ChamsFill) * alpha
    local n = 0
    for _, part in ipairs(char:GetChildren()) do
        if n >= 16 then break end
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
            local cf, half = part.CFrame, part.Size / 2
            local points, behind = {}, false
            for i, sign in ipairs(cornerSigns) do
                local p, _, depth = toScreen((cf * CFrame.new(half * sign)).Position)
                if depth <= 0 then behind = true break end
                points[i] = p
            end
            if not behind then
                local h = hull(points)
                if #h >= 3 then
                    n += 1
                    local key = "cham" .. n
                    local q1 = use(e, key .. "a", "Quad")
                    if q1 then
                        q1.PointA, q1.PointB, q1.PointC, q1.PointD = h[1], h[2], h[3], h[4] or h[3]
                        q1.Color, q1.Filled, q1.Thickness, q1.Transparency, q1.ZIndex, q1.Visible = color, true, 1, fillAlpha, 0, true
                    end
                    if #h > 4 then
                        local q2 = use(e, key .. "b", "Quad")
                        if q2 then
                            q2.PointA, q2.PointB, q2.PointC, q2.PointD = h[1], h[4], h[5], h[6] or h[5]
                            q2.Color, q2.Filled, q2.Thickness, q2.Transparency, q2.ZIndex, q2.Visible = color, true, 1, fillAlpha, 0, true
                        end
                    end
                    for i = 1, #h do
                        local l = use(e, key .. "e" .. i, "Line")
                        if l then
                            l.From, l.To, l.Color, l.Thickness, l.Transparency, l.ZIndex, l.Visible =
                                h[i], h[i % #h + 1], settings.ChamsOutline, 1, alpha, 1, true
                        end
                    end
                end
            end
        end
    end
end

local function updatePlayer(plr)
    local e = entry(plr)
    local char, hum, root = getCharacter(plr)
    if not (settings.ESP_Enabled and char and isAlive(hum)) or (settings.ESP_TeamCheck and isTeammate(plr)) then
        e.chamsReady = false
        return hideUnused(e)
    end
    local dist = (root.Position - Camera.CFrame.Position).Magnitude
    if dist > settings.ESP_MaxDist then
        e.chamsReady = false
        return hideUnused(e)
    end
    if e.char ~= char then e.char, e.chamsReady = char, false end
    local head = char:FindFirstChild("Head") or root
    local enemy = not isTeammate(plr)
    local color = enemy and settings.ColEnemy or settings.ColAlly
    if settings.UseTeamColor and plr.Team then color = plr.TeamColor.Color end
    local visible = true
    if settings.VisColor and enemy then
        visible = isVisible(plr, char, head)
        if not visible then color = settings.ColHidden end
    end
    if Silent.Target and Silent.Target.Player == plr then color = settings.ColTarget end
    local alpha = settings.Fade and clamp(1 - dist / (settings.ESP_MaxDist * 1.15), 0.35, 1) or 1

    local rootScreen, onScreen = toScreen(root.Position)
    if onScreen and settings.Chams and (settings.ChamsWalls or isVisible(plr, char, head)) then
        -- Performance mode only defers the costly hulls; text, bars and visibility always update.
        if not settings.Perf or dist <= 400 or not e.chamsReady or (esp.Frame + plr.UserId) % 2 == 0 then
            local ok, err = pcall(updateChams, e, char, color, alpha)
            e.chamsReady = ok
            if not ok then
                for key in pairs(e.Obj) do if key:sub(1, 4) == "cham" then e.Stamp[key] = nil end end
                hubError("ESP Chams", err)
            end
        else
            for key in pairs(e.Obj) do
                if key:sub(1, 4) == "cham" and e.Vis[key] then e.Stamp[key] = esp.Frame end
            end
        end
    else
        e.chamsReady = false
    end

    if not onScreen then
        return hideUnused(e)
    end

    -- box: the top of the head and the bottom of the feet are projected (stable, not affected by accessories)
    local top = toScreen(root.Position + vec3(0, 2.6, 0))
    local bottom = toScreen(root.Position - vec3(0, 3, 0))
    local h = max(bottom.Y - top.Y, 6)
    local w = h * 0.62
    local boxLeft, boxTop = floor(rootScreen.X - w / 2), floor(top.Y)
    local boxRight, boxBottom = floor(boxLeft + w), floor(boxTop + h)

    if settings.Box then
        if settings.BoxFill then
            local f = use(e, "fill", "Square")
            if f then f.Position, f.Size, f.Color, f.Filled, f.Transparency, f.ZIndex, f.Visible = vec2(boxLeft, boxTop), vec2(boxRight - boxLeft, boxBottom - boxTop), color, true, (1 - settings.BoxFillAlpha) * alpha, 0, true end
        end
        local frac = settings.BoxStyle == "Full" and 1 or settings.BoxCorner / 100
        local cx, cy = (boxRight - boxLeft) / 2 * frac, (boxBottom - boxTop) / 2 * frac
        drawLine(e, "b1", vec2(boxLeft, boxTop), vec2(boxLeft + cx, boxTop), color, 1, alpha)
        drawLine(e, "b2", vec2(boxLeft, boxTop), vec2(boxLeft, boxTop + cy), color, 1, alpha)
        drawLine(e, "b3", vec2(boxRight, boxTop), vec2(boxRight - cx, boxTop), color, 1, alpha)
        drawLine(e, "b4", vec2(boxRight, boxTop), vec2(boxRight, boxTop + cy), color, 1, alpha)
        drawLine(e, "b5", vec2(boxLeft, boxBottom), vec2(boxLeft + cx, boxBottom), color, 1, alpha)
        drawLine(e, "b6", vec2(boxLeft, boxBottom), vec2(boxLeft, boxBottom - cy), color, 1, alpha)
        drawLine(e, "b7", vec2(boxRight, boxBottom), vec2(boxRight - cx, boxBottom), color, 1, alpha)
        drawLine(e, "b8", vec2(boxRight, boxBottom), vec2(boxRight, boxBottom - cy), color, 1, alpha)
    end

    local health, maxHealth = healthOf(hum)
    local hp = clamp(health / maxHealth, 0, 1)
    local barX = boxLeft - 6
    if settings.HealthBar and h >= 18 then
        local bg = use(e, "hb_bg", "Square")
        if bg then bg.Position, bg.Size, bg.Color, bg.Filled, bg.Transparency, bg.ZIndex, bg.Visible = vec2(barX - 1, boxTop - 1), vec2(4, h + 2), black, true, alpha, 1, true end
        local bar = use(e, "hb", "Square")
        if bar then bar.Position, bar.Size, bar.Color, bar.Filled, bar.Transparency, bar.ZIndex, bar.Visible = vec2(barX, boxTop + h * (1 - hp)), vec2(2, h * hp), healthColor(hp), true, alpha, 2, true end
    end
    local leftEdge = settings.HealthBar and h >= 18 and barX - 1 or boxLeft    -- where the next thing on the left may start
    local mode = settings.ModeBar and h >= 18 and modeOf(char)
    if mode then                                                        -- mode meter, just left of the health bar
        local modeX = leftEdge - 5
        local bg = use(e, "mb_bg", "Square")
        if bg then bg.Position, bg.Size, bg.Color, bg.Filled, bg.Transparency, bg.ZIndex, bg.Visible = vec2(modeX - 1, boxTop - 1), vec2(4, h + 2), black, true, alpha, 1, true end
        local bar = use(e, "mb", "Square")
        if bar then bar.Position, bar.Size, bar.Color, bar.Filled, bar.Transparency, bar.ZIndex, bar.Visible = vec2(modeX, boxTop + h * (1 - mode)), vec2(2, h * mode), modeColorFor(mode), true, alpha, 2, true end
        leftEdge = modeX - 1
    end

    local size = settings.TextSize
    if settings.Name then
        local name = settings.DisplayName and plr.DisplayName or plr.Name
        drawText(e, "name", name, vec2(rootScreen.X, boxTop - size - 4), color, size, alpha, true)
    end
    if settings.HealthText then
        local ok, err = pcall(function()
            local txt = tostring(floor(health + 0.5))
            local textSize = size - 1
            local t = use(e, "hp", "Text")
            if not t then return end
            t.Text, t.Size, t.Color = txt, textSize, healthColor(hp)
            t.Center, t.Outline, t.Transparency, t.ZIndex = false, true, alpha, 3
            local okB, bounds = pcall(function() return t.TextBounds end)
            local estimate = #txt * textSize * 0.6
            local tw = okB and typeof(bounds) == "Vector2" and bounds.X > 0 and bounds.X or estimate
            local yMin = boxTop - 2
            local yMax = max(yMin, boxBottom - textSize)
            local y = clamp(boxTop + h * (1 - hp) - textSize / 2, yMin, yMax)
            t.Position, t.Visible = vec2(leftEdge - 2 - tw, y), true
        end)
        if not ok then
            local broken = e.Obj.hp
            if broken then Render.remove(broken) end
            e.Obj.hp, e.Stamp.hp, e.Vis.hp = nil, nil, nil
            hubError("ESP Health Text", err)
        end
    end
    local bottomLine = {}
    if settings.Distance then
        bottomLine[#bottomLine + 1] = settings.DistUnit == "Meters" and (floor(dist * 0.28) .. "m") or (floor(dist) .. " studs")
    end
    if settings.Weapon then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then bottomLine[#bottomLine + 1] = tool.Name end
    end
    if #bottomLine > 0 then
        drawText(e, "info", table.concat(bottomLine, "  ·  "), vec2(rootScreen.X, boxBottom + 3), rgb(0.87, 0.87, 0.87), size - 1, alpha, true)
    end
    if not visible and settings.VisColor then
        drawText(e, "wall", "behind wall", vec2(rootScreen.X, boxBottom + 4 + size), settings.ColHidden, size - 2, alpha * 0.9, true)
    end

    -- line style (Visuals › Extra › Line style): one thickness / transparency for every line, optionally rainbow
    local lineColor = settings.LineRainbow and Color3.fromHSV((os.clock() * 0.25) % 1, 0.75, 1) or color
    local lineAlpha = alpha * (1 - settings.LineAlpha)
    local lineThick = settings.LineThick
    if settings.HeadDot then
        local hs = toScreen(head.Position)
        local c = use(e, "head", "Circle")
        if c then
            c.Position, c.Radius, c.Color, c.Filled, c.NumSides, c.Thickness, c.Transparency, c.ZIndex, c.Visible =
                hs, max(2, h / 22), lineColor, true, 12, 1, lineAlpha, 2, true
        end
    end
    if settings.Tracer then
        local vs = Camera.ViewportSize
        local from = settings.TracerFrom == "Mouse" and UserInputService:GetMouseLocation()
            or settings.TracerFrom == "Center" and vs / 2 or vec2(vs.X / 2, vs.Y)
        drawLine(e, "tracer", from, vec2(rootScreen.X, boxBottom), lineColor, lineThick, lineAlpha * 0.8)
    end
    if settings.LookDir then
        local a = toScreen(head.Position)
        local b = toScreen(head.Position + head.CFrame.LookVector * 4)
        drawLine(e, "look", a, b, lineColor, lineThick, lineAlpha)
    end
    if settings.Skeleton then
        local pairsList = char:FindFirstChild("UpperTorso") and skeletonR15 or skeletonR6
        for i, pair in ipairs(pairsList) do
            local p1, p2 = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
            if p1 and p2 then
                local a, onA = toScreen(p1.Position)
                local b, onB = toScreen(p2.Position)
                if onA and onB then drawLine(e, "sk" .. i, a, b, lineColor, lineThick, lineAlpha) end
            end
        end
    end
    hideUnused(e)
end

-- FOV circle and target line (global objects)
local Global = { Obj = {}, Stamp = {}, Vis = {} }
local function updateGlobal()
    if settings.SA_Enabled and settings.FOV_Show then
        local c = use(Global, "fov", "Circle")
        if c then
            c.Position, c.Radius, c.Color, c.NumSides, c.Thickness, c.Filled, c.Transparency, c.ZIndex, c.Visible =
                fovOrigin(), settings.FOV_Radius, settings.FOV_Color, settings.FOV_Sides, settings.FOV_Thick, settings.FOV_Filled, (1 - settings.FOV_Alpha) * (settings.FOV_Filled and 0.25 or 1), 4, true
        end
    end
    local t = Silent.Target
    if settings.SA_Enabled and settings.FOV_TargetLine and t then
        local sp, on = toScreen(t.Position)
        if on then
            local l = use(Global, "tline", "Line")
            if l then l.From, l.To, l.Color, l.Thickness, l.Transparency, l.ZIndex, l.Visible = fovOrigin(), sp, settings.ColTarget, 1, 1, 4, true end
        end
    end
    hideUnused(Global)
end

----- World (Lighting) -----
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
local brightAmbient = rgb(0.7, 0.7, 0.7)
local function updateWorld()
    local ambient = (settings.CustomAmbient and settings.Ambient) or (settings.Fullbright and brightAmbient) or nil
    local shadows
    if settings.NoShadows or settings.Fullbright then shadows = false end
    worldProperty("Brightness", settings.Fullbright and 2 or nil)
    worldProperty("Ambient", ambient)
    worldProperty("OutdoorAmbient", ambient)
    worldProperty("GlobalShadows", shadows)
    worldProperty("ClockTime", settings.CustomTime and settings.ClockTime or nil)
    worldProperty("FogStart", settings.NoFog and 1e6 or nil)
    worldProperty("FogEnd", settings.NoFog and 1e6 or nil)
    fogDensity(settings.NoFog)
end

----- Player (movement) -----
local NoClipParts = {}
local function stopNoClip()
    for part, was in pairs(NoClipParts) do
        if part.Parent then part.CanCollide = was end
    end
    table.clear(NoClipParts)
end
local Defaults = setmetatable({}, { __mode = "k" })
local originalZoom
local function restorePlayer()
    for hum, d in pairs(Defaults) do
        if d.WalkSpeed then pcall(function() hum.WalkSpeed = d.WalkSpeed end) end
        if d.JumpPower then pcall(function()
            hum.JumpPower, hum.UseJumpPower = d.JumpPower, d.UseJumpPower
        end) end
    end
    table.clear(Defaults)
    if originalZoom then LocalPlayer.CameraMaxZoomDistance = originalZoom originalZoom = nil end
end
hub.Cleanup[#hub.Cleanup + 1] = restorePlayer

connect(RunService.Stepped, function()
    if not Running then return end
    local char = LocalPlayer.Character
    if settings.NoClip and char then
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
    if originalZoom and not settings.UnlockZoom then
        LocalPlayer.CameraMaxZoomDistance = originalZoom
        originalZoom = nil
    elseif settings.UnlockZoom then
        originalZoom = originalZoom or LocalPlayer.CameraMaxZoomDistance
        LocalPlayer.CameraMaxZoomDistance = 1e4
    end
    if not char then return end
    local d = Defaults[hum] or {}
    Defaults[hum] = d
    if settings.SpeedOn then
        d.WalkSpeed = d.WalkSpeed or hum.WalkSpeed
        hum.WalkSpeed = settings.WalkSpeed
    elseif d.WalkSpeed then
        hum.WalkSpeed, d.WalkSpeed = d.WalkSpeed, nil
    end
    if settings.JumpOn then
        if d.JumpPower == nil then d.JumpPower, d.UseJumpPower = hum.JumpPower, hum.UseJumpPower end
        hum.UseJumpPower, hum.JumpPower = true, settings.JumpPower
    elseif d.JumpPower then
        hum.JumpPower, hum.UseJumpPower = d.JumpPower, d.UseJumpPower
        d.JumpPower, d.UseJumpPower = nil, nil
    end
end)

connect(UserInputService.JumpRequest, function()
    if not (Running and settings.InfJump) then return end
    local _, hum = getCharacter(LocalPlayer)
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

connect(UserInputService.InputBegan, function(input, processed)
    if processed or not (Running and settings.ClickTP) then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local _, _, root = getCharacter(LocalPlayer)
        local hit = Mouse.Hit
        if root and hit then root.CFrame = cframe(hit.Position + vec3(0, 3, 0)) * (root.CFrame - root.CFrame.Position) end
    end
end)

connect(LocalPlayer.Idled, function()
    if not (Running and settings.AntiAfk) then return end
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

----- Server -----

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
    if not (settings.StaffAlert and settings.StaffGroup > 0) or plr == LocalPlayer then return end
    task.spawn(function()
        local ok, rank = pcall(function() return plr:GetRankInGroup(settings.StaffGroup) end)
        if not (Running and settings.StaffAlert and ok and rank and rank >= settings.StaffRank) then return end
        notify("Staff in game", ("%s (rank %d) joined the server"):format(plr.Name, rank), "shield-alert", "danger")
        if settings.StaffAction == "Hop" then serverHop("Random")
        elseif settings.StaffAction == "Leave" then LocalPlayer:Kick("Qustāh: staff joined, left the game") end
    end)
end

----- Combat -----
do
local Combat = Tabs.Combat
local Aim = Combat:Card({ Title = "Silent Aim", Icon = "target", Desc = "Redirects your shots to the target without moving the camera" })
if not CanHook then
    Combat.Pages[1]:Warning("Your executor doesn't support hookmetamethod; Silent Aim won't work.", { Title = "No hook", Level = "danger" })
end
local function refreshAimStatus()
    local m = settings.SA_Methods
    local wantsNamecall = m.Raycast or m.FindPartOnRay or m.ScreenPointToRay
    local wantsIndex = m["Mouse.Hit"] or m["Mouse.Target"]
    local active, failed = false, false
    if settings.SA_Enabled and CanHook then
        if wantsNamecall then
            local ok = installNamecallHook()
            active, failed = active or ok, failed or not ok
        end
        if wantsIndex then
            local ok = installIndexHook()
            active, failed = active or ok, failed or not ok
        end
    end
    local limited = not CanHook or settings.SA_Enabled and (failed or not active)
    Window:SetModule("Silent Aim", limited and "Limited" or (active and "On" or "Off"),
        limited and "Hook unavailable or no method selected" or nil, { Icon = "target", Tab = "Combat" })
end
local saToggle = Aim:Toggle({ Title = "Enabled", Flag = "sa_enabled", Default = false, Bindable = true,
    Callback = function(on)
        settings.SA_Enabled = on
        if not on then Silent.Target = nil end
        refreshAimStatus()
    end })
if not CanHook then saToggle:Lock("Executor doesn't support hooks") end
Aim:Slider({ Title = "Hit chance", Flag = "sa_hitchance", Min = 0, Max = 100, Default = 100, Suffix = "%", Callback = set("SA_HitChance") })
Aim:Segment({ Title = "Target part", Flag = "sa_part", Items = { "Head", "Torso", "Random", "Closest" }, Default = "Head", Wide = true, Callback = set("SA_Part") })
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
        settings.SA_Methods = toSet(list)
        refreshAimStatus()
    end })

local Checks = Combat:Card({ Title = "Checks", Icon = "shield-check", Side = "Left" })
Checks:Toggle({ Title = "Visibility check", Desc = "Don't target players behind walls", Flag = "sa_vischeck", Default = false, Callback = set("SA_VisCheck") })
Checks:Toggle({ Title = "Safe origin", Desc = "Only change shots that come from you", Flag = "sa_safe", Default = true, Callback = set("SA_SafeOrigin") })
Checks:Slider({ Title = "Max distance", Flag = "sa_maxdist", Min = 50, Max = 3000, Default = 1000, Step = 10, Suffix = " studs", Callback = set("SA_MaxDist") })
Checks:Toggle({ Title = "Prediction", Desc = "Aim ahead of moving targets", Flag = "sa_predict", Default = false, Callback = set("SA_Predict") })
Checks:Slider({ Title = "Prediction strength", Flag = "sa_predstr", Min = 0, Max = 300, Default = 100, Step = 5, Suffix = "%", DependsOn = { Flag = "sa_predict", Reason = "" }, Callback = set("SA_PredStrength") })

-- Right column: the preview first, then the FOV basics (colour as swatches) and its style
local PreviewCard = Combat:Card({ Title = "Preview", Icon = "scan", Side = "Right" })
local fovPreview = PreviewCard:FovPreview({ Height = 140 })
local function refreshFov()
    fovPreview:Update({ Radius = settings.FOV_Radius, Sides = settings.FOV_Sides, Thickness = settings.FOV_Thick, Color = settings.FOV_Color,
        Transparency = settings.FOV_Alpha, Filled = settings.FOV_Filled, FillColor = settings.FOV_Color, FillTransparency = 0.85, Visible = settings.FOV_Show })
end
local function fovSet(key) return function(v) settings[key] = v refreshFov() end end
local FovCard = Combat:Card({ Title = "FOV", Icon = "circle-dashed", Side = "Right" })
FovCard:Toggle({ Title = "Show FOV", Flag = "fov_show", Default = true, Callback = fovSet("FOV_Show") })
FovCard:Slider({ Title = "Radius", Flag = "fov_radius", Min = 10, Max = 600, Default = 120, Suffix = " px", Callback = fovSet("FOV_Radius") })
-- quick colours; the picker in "FOV style" holds the saved colour (any colour, with transparency), the swatches only set it
local fovSwatches, fovPicker
local fovSyncing = false                                           -- picker -> dots update must not come back to the picker
fovSwatches = FovCard:Swatches({ Title = "Color", Style = "Dots", Default = "White", Items = {
    { "White", Color3.fromRGB(255, 255, 255) }, { "Red", Color3.fromRGB(224, 70, 70) }, { "Blue", Color3.fromRGB(127, 180, 255) },
    { "Green", Color3.fromRGB(91, 210, 122) }, { "Gold", Color3.fromRGB(242, 184, 75) }, { "Violet", Color3.fromRGB(180, 139, 232) },
}, Custom = function(open) if fovPicker and fovPicker.SetOpen then fovPicker:SetOpen(open) end end,
    Callback = function(color) if fovPicker and not fovSyncing then fovPicker:Set(color) end end })
FovCard:Segment({ Title = "Origin", Flag = "fov_origin", Items = { "Mouse", "Center" }, Default = "Mouse", Callback = set("FOV_Origin") })
local FovStyle = Combat:Card({ Title = "FOV style", Icon = "sliders-horizontal", Side = "Right" })
FovStyle:Slider({ Title = "Sides", Flag = "fov_sides", Min = 3, Max = 64, Default = 64, Callback = fovSet("FOV_Sides") })
FovStyle:Slider({ Title = "Thickness", Flag = "fov_thick", Min = 1, Max = 5, Default = 1, Callback = fovSet("FOV_Thick") })
fovPicker = FovStyle:ColorPicker({ Title = "Custom color", Flag = "fov_color", Default = white, Alpha = true, Transparency = 0,
    Callback = function(c, t)
        settings.FOV_Color = c
        if t ~= nil then settings.FOV_Alpha = t end
        if fovSwatches then                                          -- a preset colour lights its dot, any other none
            fovSyncing = true
            pcall(fovSwatches.Set, fovSwatches, c, true)
            fovSyncing = false
        end
        refreshFov()
    end })
FovStyle:Toggle({ Title = "Filled", Flag = "fov_filled", Default = false, Callback = fovSet("FOV_Filled") })
FovStyle:Toggle({ Title = "Target line", Desc = "Line from FOV center to target", Flag = "fov_tline", Default = false, Callback = set("FOV_TargetLine") })
refreshFov()
end

----- Visuals -----
do
local Visuals = Tabs.Visuals
local EspPage = Visuals:Page("ESP")
local ExtraPage = Visuals:Page("Extra", { Compact = true })
local StylePage = Visuals:Page("Style")

local General = EspPage:Card({ Title = "General", Icon = "scan-eye" })
General:Toggle({ Title = "ESP enabled", Flag = "esp_enabled", Default = false, Bindable = true,
    Callback = function(on)
        settings.ESP_Enabled = on
        Window:SetModule("ESP", on and "On" or "Off", nil, { Icon = "eye", Tab = "Visuals" })
        if on and not Render.Available then notify("ESP", "Your executor has no Drawing API, ESP can't draw", "triangle-alert", "warning") end
    end })
General:Toggle({ Title = "Team check", Desc = "Don't show teammates", Flag = "esp_team", Default = true, Callback = set("ESP_TeamCheck") })
General:Slider({ Title = "Max distance", Flag = "esp_maxdist", Min = 100, Max = 5000, Default = 1500, Step = 50, Suffix = " studs", Callback = set("ESP_MaxDist") })

local BoxCard = EspPage:Card({ Title = "Box", Icon = "square-dashed", Side = "Left" })
BoxCard:Toggle({ Title = "Box", Flag = "esp_box", Default = true, Callback = set("Box") })
BoxCard:Segment({ Title = "Style", Flag = "esp_boxstyle", Items = { "Corner", "Full" }, Default = "Corner", Callback = set("BoxStyle") })
BoxCard:Slider({ Title = "Corner size", Flag = "esp_corner", Min = 10, Max = 100, Default = 30, Suffix = "%",
    DependsOn = { Flag = "esp_boxstyle", Value = "Corner", Mode = "Hide", Reason = "" }, Callback = set("BoxCorner") })
BoxCard:Toggle({ Title = "Fill", Flag = "esp_fill", Default = false, Callback = set("BoxFill") })
BoxCard:Slider({ Title = "Fill transparency", Flag = "esp_fillalpha", Min = 0, Max = 100, Default = 85, Suffix = "%", DependsOn = { Flag = "esp_fill", Reason = "" },
    Callback = function(v) settings.BoxFillAlpha = v / 100 end })
BoxCard:Toggle({ Title = "Health bar", Flag = "esp_hbar", Default = true, Callback = set("HealthBar") })
BoxCard:Toggle({ Title = "Mode bar", Desc = "Shindo mode meter, next to the health bar", Flag = "esp_mbar", Default = true, Callback = set("ModeBar") })
BoxCard:Toggle({ Title = "Outline", Flag = "esp_outline", Default = true, Callback = set("Outline") })

----- ESP live preview -----
-- Your own character (a still copy in a Viewport) with the ESP drawn over it as it would look in game: box, fill,
-- health and mode bars, name, health number and the distance / weapon line. Values are your real ones
-- (fakehealth, combat.mode, held tool) and follow the settings at once. Drawn in the menu, so this part is GUI.
local PreviewCard = EspPage:Card({ Title = "Preview", Icon = "scan-eye", Side = "Right" })
local espView = PreviewCard:Viewport({ Height = 190, Spin = false })
do
    local holder = espView.View and espView.View.Parent
    local overlay, parts = nil, {}
    local function frame(name, z)
        local f = Instance.new("Frame")
        f.Name, f.BorderSizePixel, f.ZIndex, f.Visible = name, 0, z or 2, false
        f.Parent = overlay
        parts[name] = f
        return f
    end
    local function text(name)
        local t = Instance.new("TextLabel")
        t.Name, t.BackgroundTransparency, t.ZIndex, t.Visible = name, 1, 3, false
        t.Font, t.TextStrokeTransparency, t.TextStrokeColor3 = Enum.Font.GothamMedium, 0.2, Color3.new(0, 0, 0)
        t.Size = UDim2.fromOffset(200, 16)
        t.Parent = overlay
        parts[name] = t
        return t
    end
    if holder then
        overlay = Instance.new("Frame")
        overlay.Name, overlay.BackgroundTransparency, overlay.Size, overlay.ZIndex = "EspOverlay", 1, UDim2.fromScale(1, 1), 2
        overlay.Parent = holder
        frame("fill", 2)
        for i = 1, 8 do frame("o" .. i, 2) frame("b" .. i, 3) end            -- box edges: outline under, colour over
        frame("hbBg", 2) frame("hb", 3) frame("mbBg", 2) frame("mb", 3)
        text("name") text("hp") text("info")
    end
    -- a line as a frame (only straight ones are needed here)
    local function bar(f, x, y, w, h, color, z)
        f.Position, f.Size, f.BackgroundColor3, f.Visible = UDim2.fromOffset(x, y), UDim2.fromOffset(math.max(w, 1), math.max(h, 1)), color, true
        if z then f.ZIndex = z end
    end
    local function shown(gui)
        while gui do
            if gui:IsA("GuiObject") and not gui.Visible then return false end
            if gui:IsA("LayerCollector") then return gui.Enabled end
            gui = gui.Parent
        end
        return false
    end
    local function project(point, size)
        local cam = espView.Camera
        local rel = cam.CFrame:PointToObjectSpace(point)
        if rel.Z >= -0.01 then return nil end
        local f = 1 / math.tan(math.rad(cam.FieldOfView / 2))
        local sx = (rel.X / -rel.Z) * f / (size.X / size.Y)
        local sy = (rel.Y / -rel.Z) * f
        return vec2((sx + 1) / 2 * size.X, (1 - sy) / 2 * size.Y)
    end
    local function hideAll() for _, f in pairs(parts) do f.Visible = false end end
    local function drawPreview()
        if not overlay then return end
        hideAll()
        local model = espView.Model
        local root = model and model:FindFirstChild("HumanoidRootPart")
        local size = holder.AbsoluteSize
        if not root or size.X < 10 or size.Y < 10 then return end
        local top, bottom = project(root.Position + vec3(0, 2.6, 0), size), project(root.Position - vec3(0, 3, 0), size)
        if not (top and bottom) then return end
        local h = math.max(bottom.Y - top.Y, 6)
        local w = h * 0.62
        local x1, y1, x2, y2 = top.X - w / 2, top.Y, top.X + w / 2, top.Y + h
        local color = settings.ColEnemy
        local outline = settings.Outline
        if settings.BoxFill then
            bar(parts.fill, x1, y1, w, h, color)
            parts.fill.BackgroundTransparency = settings.BoxFillAlpha
        end
        if settings.Box then
            local edges
            if settings.BoxStyle == "Corner" then
                local cx, cy = w * settings.BoxCorner / 100 / 2, h * settings.BoxCorner / 100 / 2
                edges = { { x1, y1, cx, 1 }, { x1, y1, 1, cy }, { x2 - cx, y1, cx, 1 }, { x2 - 1, y1, 1, cy },
                          { x1, y2 - 1, cx, 1 }, { x1, y2 - cy, 1, cy }, { x2 - cx, y2 - 1, cx, 1 }, { x2 - 1, y2 - cy, 1, cy } }
            else
                edges = { { x1, y1, w, 1 }, { x1, y2 - 1, w, 1 }, { x1, y1, 1, h }, { x2 - 1, y1, 1, h } }
            end
            for i, e in ipairs(edges) do
                if outline then bar(parts["o" .. i], e[1] - 1, e[2] - 1, e[3] + 2, e[4] + 2, Color3.new(0, 0, 0)) end
                bar(parts["b" .. i], e[1], e[2], e[3], e[4], color)
            end
        end
        local char = character()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local health, maxHealth = 100, 100
        if hum then health, maxHealth = healthOf(hum) end
        local hp = clamp(health / maxHealth, 0, 1)
        local leftEdge = x1
        if settings.HealthBar then
            bar(parts.hbBg, x1 - 7, y1 - 1, 4, h + 2, Color3.new(0, 0, 0))
            bar(parts.hb, x1 - 6, y1 + h * (1 - hp), 2, h * hp, healthColor(hp))
            leftEdge = x1 - 7
        end
        local mode = settings.ModeBar and char and modeOf(char)
        if mode then
            bar(parts.mbBg, leftEdge - 5, y1 - 1, 4, h + 2, Color3.new(0, 0, 0))
            bar(parts.mb, leftEdge - 4, y1 + h * (1 - mode), 2, h * mode, modeColorFor(mode))
            leftEdge = leftEdge - 5
        end
        local textSize = settings.TextSize
        if settings.Name then
            local t = parts.name
            t.Text, t.TextColor3, t.TextSize = settings.DisplayName and LocalPlayer.DisplayName or LocalPlayer.Name, color, textSize
            t.TextXAlignment, t.Position, t.Visible = Enum.TextXAlignment.Center, UDim2.fromOffset(top.X - 100, y1 - textSize - 6), true
        end
        if settings.HealthText then
            local t = parts.hp
            t.Text, t.TextColor3, t.TextSize = tostring(math.floor(health + 0.5)), healthColor(hp), textSize - 1
            t.TextXAlignment, t.Visible = Enum.TextXAlignment.Right, true
            t.Position = UDim2.fromOffset(leftEdge - 3 - 200, clamp(y1 + h * (1 - hp) - textSize / 2, y1 - 2, y2 - textSize))
        end
        local line = {}
        if settings.Distance then line[#line + 1] = settings.DistUnit == "Meters" and "12m" or "42 studs" end
        if settings.Weapon then
            local tool = char and char:FindFirstChildOfClass("Tool")
            line[#line + 1] = tool and tool.Name or "No tool"
        end
        if #line > 0 then
            local t = parts.info
            t.Text, t.TextColor3, t.TextSize = table.concat(line, "  ·  "), rgb(0.87, 0.87, 0.87), textSize - 1
            t.TextXAlignment, t.Position, t.Visible = Enum.TextXAlignment.Center, UDim2.fromOffset(top.X - 100, y2 + 3), true
        end
    end
    -- the copy follows your character (respawns, outfit changes need a respawn); drawn ~15 times a second, only while on screen
    local function loadCharacter(char)
        if not char then return end
        task.spawn(function()
            char:WaitForChild("HumanoidRootPart", 10)
            task.wait(0.5)                                              -- clothes and accessories load a moment later
            if hub.Running and LocalPlayer.Character == char then pcall(function() espView:SetObject(char) end) end
        end)
    end
    loadCharacter(LocalPlayer.Character)
    hubConnect(LocalPlayer.CharacterAdded, loadCharacter)
    local last = 0
    hubConnect(RunService.Heartbeat, function()
        local now = os.clock()
        if now - last < 1 / 15 or not (overlay and shown(holder)) then return end
        last = now
        drawPreview()
    end)
end

local TextCard = EspPage:Card({ Title = "Text", Icon = "type", Side = "Right" })
TextCard:Toggle({ Title = "Name", Flag = "esp_name", Default = true, Callback = set("Name") })
TextCard:Toggle({ Title = "Use display name", Flag = "esp_dname", Default = true, DependsOn = { Flag = "esp_name", Reason = "" }, Callback = set("DisplayName") })
TextCard:Toggle({ Title = "Health number", Flag = "esp_hptext", Default = true, Callback = set("HealthText") })
TextCard:Toggle({ Title = "Distance", Flag = "esp_dist", Default = true, Callback = set("Distance") })
TextCard:Segment({ Title = "Unit", Flag = "esp_unit", Items = { "Studs", "Meters" }, Default = "Studs", DependsOn = { Flag = "esp_dist", Reason = "" }, Callback = set("DistUnit") })
TextCard:Toggle({ Title = "Weapon", Desc = "Held tool", Flag = "esp_weapon", Default = true, Callback = set("Weapon") })
TextCard:Slider({ Title = "Text size", Flag = "esp_tsize", Min = 9, Max = 20, Default = 13, Suffix = " px", Callback = set("TextSize") })

do -- Visuals › Extra and Style (a block: their locals end here)
local Chams = ExtraPage:Card({ Title = "Chams", Icon = "paint-bucket" })
----- Chams preview -----
-- Your character (a still copy) painted the way chams would paint it: each part tinted by the fill colour and
-- transparency, and its outline drawn in the outline colour (same part hulls as the in-game chams). Menu GUI.
do
    local chamsView = Chams:Viewport({ Height = 150, Spin = false })
    local holder = chamsView.View and chamsView.View.Parent
    local overlay, lines, originals = nil, {}, {}
    if holder then
        overlay = Instance.new("Frame")
        overlay.Name, overlay.BackgroundTransparency, overlay.Size, overlay.ZIndex = "ChamsOverlay", 1, UDim2.fromScale(1, 1), 2
        overlay.Parent = holder
    end
    local function line(i)
        local f = lines[i]
        if not f then
            f = Instance.new("Frame")
            f.Name, f.BorderSizePixel, f.AnchorPoint, f.ZIndex = "Edge" .. i, 0, Vector2.new(0.5, 0.5), 3
            f.Parent = overlay
            lines[i] = f
        end
        return f
    end
    local function shown(gui)
        while gui do
            if gui:IsA("GuiObject") and not gui.Visible then return false end
            if gui:IsA("LayerCollector") then return gui.Enabled end
            gui = gui.Parent
        end
        return false
    end
    local function project(point, size)
        local cam = chamsView.Camera
        local rel = cam.CFrame:PointToObjectSpace(point)
        if rel.Z >= -0.01 then return nil end
        local f = 1 / math.tan(math.rad(cam.FieldOfView / 2))
        return vec2(((rel.X / -rel.Z) * f / (size.X / size.Y) + 1) / 2 * size.X, (1 - (rel.Y / -rel.Z) * f) / 2 * size.Y)
    end
    local function drawChamsPreview()
        if not overlay then return end
        local model = chamsView.Model
        local used = 0
        if model then
            local fillAlpha = settings.Chams and (1 - settings.ChamsFill) or 0
            local size = holder.AbsoluteSize
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    if not originals[part] then originals[part] = part.Color end
                    part.Color = originals[part]:Lerp(settings.ColEnemy, fillAlpha)          -- the fill
                    if settings.Chams and part.Transparency < 1 and part.Parent == model and size.X > 10 then
                        local cf, half, points = part.CFrame, part.Size / 2, {}
                        for i, sign in ipairs(cornerSigns) do
                            local p2 = project((cf * CFrame.new(half * sign)).Position, size)
                            if not p2 then points = nil break end
                            points[i] = p2
                        end
                        local h = points and hull(points)
                        if h and #h >= 3 then
                            for i = 1, #h do                                                    -- the outline
                                local a, b = h[i], h[i % #h + 1]
                                used += 1
                                local f = line(used)
                                local d = b - a
                                f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
                                f.Size = UDim2.fromOffset(math.max(d.Magnitude, 1), 1)
                                f.Rotation = math.deg(math.atan2(d.Y, d.X))
                                f.BackgroundColor3, f.Visible = settings.ChamsOutline, true
                            end
                        end
                    end
                end
            end
        end
        for i = used + 1, #lines do lines[i].Visible = false end
    end
    local function loadCharacter(char)
        if not char then return end
        task.spawn(function()
            char:WaitForChild("HumanoidRootPart", 10)
            task.wait(0.5)
            if hub.Running and LocalPlayer.Character == char then
                table.clear(originals)
                pcall(function() chamsView:SetObject(char) end)
            end
        end)
    end
    loadCharacter(LocalPlayer.Character)
    hubConnect(LocalPlayer.CharacterAdded, loadCharacter)
    local last = 0
    hubConnect(RunService.Heartbeat, function()
        local now = os.clock()
        if now - last < 1 / 15 or not (overlay and shown(holder)) then return end
        last = now
        drawChamsPreview()
    end)
end
Chams:Toggle({ Title = "Chams", Flag = "esp_chams", Default = true, Style = "Switch", Callback = set("Chams") })
Chams:Toggle({ Title = "Through walls", Flag = "esp_chamswalls", Default = true, Style = "Switch", DependsOn = { Flag = "esp_chams", Reason = "" }, Callback = set("ChamsWalls") })
Chams:Slider({ Title = "Fill transparency", Flag = "esp_chamsfill", Min = 0, Max = 100, Default = 60, Suffix = "%", DependsOn = { Flag = "esp_chams", Reason = "" },
    Callback = function(v) settings.ChamsFill = v / 100 end })
Chams:ColorPicker({ Title = "Outline color", Flag = "esp_chamsout", Default = white, DependsOn = { Flag = "esp_chams", Reason = "" }, Callback = set("ChamsOutline") })

local Lines = ExtraPage:Card({ Title = "Lines", Icon = "spline", Side = "Right" })
Lines:Toggle({ Title = "Tracer", Flag = "esp_tracer", Default = false, Callback = set("Tracer") })
Lines:Segment({ Title = "Tracer from", Flag = "esp_tracerfrom", Items = { "Bottom", "Center", "Mouse" }, Default = "Bottom", DependsOn = { Flag = "esp_tracer", Reason = "" }, Callback = set("TracerFrom") })
Lines:Toggle({ Title = "Skeleton", Flag = "esp_skeleton", Default = false, Callback = set("Skeleton") })
Lines:Toggle({ Title = "Look direction", Desc = "Shows where they are looking", Flag = "esp_look", Default = false, Callback = set("LookDir") })
Lines:Toggle({ Title = "Head dot", Flag = "esp_headdot", Default = false, Callback = set("HeadDot") })

local LineStyle = ExtraPage:Card({ Title = "Line style", Icon = "sliders-horizontal", Side = "Right" })
LineStyle:Slider({ Title = "Thickness", Flag = "esp_linethick", Min = 1, Max = 4, Default = 1, Suffix = " px", Callback = set("LineThick") })
LineStyle:Slider({ Title = "Transparency", Flag = "esp_linealpha", Min = 0, Max = 90, Default = 0, Suffix = "%", Callback = function(v) settings.LineAlpha = v / 100 end })
LineStyle:Toggle({ Title = "Rainbow", Desc = "Tracer, skeleton, look direction and head dot cycle colors", Flag = "esp_linerainbow", Default = false, Callback = set("LineRainbow") })

local Colors = StylePage:Card({ Title = "Colors", Icon = "palette" })
Colors:ColorPicker({ Title = "Enemy", Flag = "col_enemy", Default = settings.ColEnemy, Callback = set("ColEnemy") })
Colors:ColorPicker({ Title = "Behind wall", Flag = "col_hidden", Default = settings.ColHidden, Callback = set("ColHidden") })
Colors:ColorPicker({ Title = "Silent aim target", Flag = "col_target", Default = settings.ColTarget, Callback = set("ColTarget") })
Colors:Toggle({ Title = "Use team color", Flag = "col_team", Default = false, Callback = set("UseTeamColor") })
Colors:Divider({ Title = "Filters" })                               -- the filters live in the same card
local Filters = Colors
Filters:Toggle({ Title = "Visibility color", Desc = "Different color behind walls", Flag = "esp_viscolor", Default = true, Callback = set("VisColor") })
Filters:Toggle({ Title = "Fade with distance", Flag = "esp_fade", Default = true, Callback = set("Fade") })
Filters:Toggle({ Title = "Performance mode", Desc = "Update distant chams every other frame", Flag = "esp_perf", Default = false, Callback = set("Perf") })

-- bar colours on the right, health over mode
local HealthColors = StylePage:Card({ Title = "Health bar colors", Icon = "heart", Side = "Right" })
HealthColors:Swatches({ Title = "From empty to full", Flag = "esp_hpcolors", Default = "Classic", Columns = 2, Items = {
    { "Classic", Color3.fromRGB(255, 59, 59), Color3.fromRGB(91, 210, 74) },
    { "Cool", healthPresets.Cool[1], healthPresets.Cool[2] },
    { "Mono", healthPresets.Mono[1], healthPresets.Mono[2] },
    { "Heat", healthPresets.Heat[1], healthPresets.Heat[2] },
}, Callback = function(_, name) settings.HealthPreset = name end })
local ModeColors = StylePage:Card({ Title = "Mode bar colors", Icon = "zap", Side = "Right" })
ModeColors:Swatches({ Title = "From empty to full", Flag = "esp_modecolors", Default = "Ocean", Columns = 2, Items = {
    { "Ocean", modePresets.Ocean[1], modePresets.Ocean[2] }, { "Aurora", modePresets.Aurora[1], modePresets.Aurora[2] },
    { "Sunset", modePresets.Sunset[1], modePresets.Sunset[2] }, { "Toxic", modePresets.Toxic[1], modePresets.Toxic[2] },
}, Callback = function(_, name) settings.ModePreset = name end })
ModeColors:Toggle({ Title = "Flash when full", Desc = "The bar pulses while mode is at 100%", Flag = "esp_modeflash", Default = true, Callback = set("ModeFlash") })
end

----- World -----
local World = Visuals:Page("World", { Compact = true })
local Light = World:Card({ Title = "Lighting", Icon = "lightbulb" })
Light:Toggle({ Title = "Fullbright", Flag = "w_fullbright", Default = false, Callback = set("Fullbright") })
Light:Toggle({ Title = "No fog", Flag = "w_nofog", Default = false, Callback = set("NoFog") })
Light:Toggle({ Title = "No shadows", Flag = "w_noshadows", Default = false, Callback = set("NoShadows") })
Light:Button({ Title = "Restore lighting", Icon = "rotate-ccw", Style = "Ghost", Callback = function()
    for _, flag in ipairs({ "w_fullbright", "w_nofog", "w_noshadows", "w_customtime", "w_customamb" }) do Window:SetFlag(flag, false) end
    restoreWorld()
end })

-- Sky: a small picture of the sky at the chosen hour (the game's own hour while Custom time is off)
local SkyCard = World:Card({ Title = "Sky · Ambient", Icon = "sun", Side = "Right" })
local skyCanvas = SkyCard:Canvas({ Height = 74 })
local drawSky
do
    -- sky colours over the day: { hour, top, bottom }
    local keys = {
        { 0, rgb(0.04, 0.06, 0.16), rgb(0.1, 0.13, 0.28) }, { 5, rgb(0.15, 0.2, 0.4), rgb(0.95, 0.6, 0.4) },
        { 7, rgb(0.45, 0.66, 0.9), rgb(0.85, 0.9, 0.95) }, { 12, rgb(0.29, 0.56, 0.89), rgb(0.75, 0.88, 1) },
        { 17, rgb(0.36, 0.56, 0.85), rgb(1, 0.85, 0.63) }, { 19, rgb(0.23, 0.25, 0.48), rgb(0.95, 0.48, 0.29) },
        { 21, rgb(0.08, 0.1, 0.23), rgb(0.29, 0.23, 0.42) }, { 24, rgb(0.04, 0.06, 0.16), rgb(0.1, 0.13, 0.28) },
    }
    local function at(hour)
        hour = hour % 24
        for i = 1, #keys - 1 do
            local a, b = keys[i], keys[i + 1]
            if hour >= a[1] and hour <= b[1] then
                local t = (hour - a[1]) / (b[1] - a[1])
                return a[2]:Lerp(b[2], t), a[3]:Lerp(b[3], t)
            end
        end
        return keys[1][2], keys[1][3]
    end
    local frame = skyCanvas.Frame
    local parts = {}
    if frame then
        parts.sky = Instance.new("Frame")
        parts.sky.BorderSizePixel, parts.sky.Size, parts.sky.BackgroundColor3 = 0, UDim2.fromScale(1, 1), Color3.new(1, 1, 1)
        parts.gradient = Instance.new("UIGradient")
        parts.gradient.Rotation = 90
        parts.gradient.Parent = parts.sky
        parts.sky.Parent = frame
        parts.body = Instance.new("Frame")                         -- the sun by day, the moon by night
        parts.body.AnchorPoint, parts.body.Size, parts.body.BorderSizePixel = Vector2.new(0.5, 0.5), UDim2.fromOffset(12, 12), 0
        local round = Instance.new("UICorner")
        round.CornerRadius = UDim.new(1, 0)
        round.Parent = parts.body
        parts.body.Parent = frame
        parts.ground = Instance.new("Frame")                        -- the ground, tinted by the ambient colour
        parts.ground.BorderSizePixel, parts.ground.AnchorPoint = 0, Vector2.new(0, 1)
        parts.ground.Position, parts.ground.Size = UDim2.fromScale(0, 1), UDim2.new(1, 0, 0, 14)
        parts.ground.Parent = frame
        parts.label = Instance.new("TextLabel")
        parts.label.BackgroundTransparency, parts.label.Position, parts.label.Size = 1, UDim2.fromOffset(8, 5), UDim2.new(1, -16, 0, 14)
        parts.label.TextXAlignment, parts.label.TextSize, parts.label.Font = Enum.TextXAlignment.Left, 11, Enum.Font.GothamMedium
        parts.label.TextColor3, parts.label.TextStrokeTransparency = Color3.new(1, 1, 1), 0.6
        parts.label.Parent = frame
    end
    function drawSky()
        if not parts.sky then return end
        local hour = settings.CustomTime and settings.ClockTime or (tonumber(Lighting.ClockTime) or 12)
        local top, bottom = at(hour)
        parts.gradient.Color = ColorSequence.new(top, bottom)
        local day = hour >= 6 and hour < 18
        local t = day and (hour - 6) / 12 or ((hour + 6) % 24) / 12      -- 0..1 across the sky
        parts.body.Position = UDim2.new(0.08 + t * 0.84, 0, 0.75 - math.sin(t * math.pi) * 0.55, 0)
        parts.body.BackgroundColor3 = day and rgb(1, 0.86, 0.45) or rgb(0.9, 0.92, 1)
        local ambient = settings.CustomAmbient and settings.Ambient or Lighting.Ambient
        parts.ground.BackgroundColor3 = rgb(0.16, 0.24, 0.12):Lerp(ambient, 0.35)
        local h, m = math.floor(hour), math.floor((hour % 1) * 60 + 0.5)
        if m == 60 then h, m = h + 1, 0 end
        parts.label.Text = string.format("%02d:%02d · %s%s", h % 24, m, day and "Day" or "Night", settings.CustomTime and "" or " (game)")
    end
end
local function skySet(key) return function(v) settings[key] = v drawSky() end end
SkyCard:Toggle({ Title = "Custom time", Flag = "w_customtime", Default = false, Callback = skySet("CustomTime"),
    Slider = { Flag = "w_clock", Min = 0, Max = 24, Step = 0.5, Default = 14, Suffix = " h", Callback = skySet("ClockTime") } })
loop("Sky preview", 2, function() if not settings.CustomTime then drawSky() end end)   -- follows the game's hour while it is not set
drawSky()

SkyCard:Divider({ Title = "Ambient" })
local AmbientCard = SkyCard
AmbientCard:Toggle({ Title = "Custom ambient", Flag = "w_customamb", Default = false, Callback = skySet("CustomAmbient") })
local ambientSwatches, ambientPicker
local ambientSyncing = false
ambientSwatches = AmbientCard:Swatches({ Title = "Color", Style = "Dots", Default = "Grey", DependsOn = { Flag = "w_customamb", Reason = "" }, Items = {
    { "Grey", Color3.fromRGB(180, 180, 180) }, { "Warm", Color3.fromRGB(255, 217, 160) }, { "Cold", Color3.fromRGB(160, 196, 255) },
    { "Violet", Color3.fromRGB(192, 160, 255) }, { "Green", Color3.fromRGB(160, 255, 192) },
}, Custom = function(open) if ambientPicker and ambientPicker.SetOpen then ambientPicker:SetOpen(open) end end,
    Callback = function(color) if ambientPicker and not ambientSyncing then ambientPicker:Set(color) end end })
ambientPicker = AmbientCard:ColorPicker({ Title = "Custom color", Flag = "w_ambient", Default = settings.Ambient, DependsOn = { Flag = "w_customamb", Reason = "" },
    Callback = function(c)
        settings.Ambient = c
        if ambientSwatches then
            ambientSyncing = true
            pcall(ambientSwatches.Set, ambientSwatches, c, true)
            ambientSyncing = false
        end
        drawSky()
    end })
end

----- Movement -----
do
-- Each feature is set up when switched on and drops all of its connections when switched off. If the same scripts were also
-- run on their own (getgenv().AlwaysRunStop / fv / puppetdash / WiderDashStop), those are stopped first so two copies never run.
local Move = {}
local moveCfg = { PuppetSpeed = 200, PuppetLimit = 5, PuppetGap = 0.3, DashSpeed = 125, Fov = nil }
local genv = (getgenv and getgenv()) or _G

-- Always Run: keeps combat.run on
function Move.alwaysRun()
    if type(genv.AlwaysRunStop) == "function" then genv.AlwaysRunStop() end
    local p = LocalPlayer
    local links, watched = {}, {}
    local function clear()
        for _, c in ipairs(links) do c:Disconnect() end
        for _, c in pairs(watched) do c:Disconnect() end
        links, watched = {}, {}
    end
    local function bind(h)
        clear()
        local function check(v)
            if watched[v] or v.Name ~= "run" or not v:IsA("BoolValue")
                or v.Parent ~= h:FindFirstChild("combat") then return end
            local function apply()
                if v:IsDescendantOf(h) and not v.Value then v.Value = true end
            end
            watched[v] = v:GetPropertyChangedSignal("Value"):Connect(apply)
            apply()
        end
        links[1] = h.DescendantAdded:Connect(check)
        links[2] = h.DescendantRemoving:Connect(function(v)
            if watched[v] then watched[v]:Disconnect() watched[v] = nil end
        end)
        for _, v in ipairs(h:GetDescendants()) do check(v) end
    end
    local a = p.CharacterAdded:Connect(bind)
    local b = p.CharacterRemoving:Connect(clear)
    if p.Character then bind(p.Character) end
    return function() a:Disconnect() b:Disconnect() clear() end
end

-- FOV: applies the slider value; while flyjutsu is active (and during the 1.2 s tween after it ends) the game cannot change the FOV.
-- Always active while the hub is running (no separate toggle).
function Move.flyFov()
    if type(genv.fv) == "function" then genv.fv() end
    local p = LocalPlayer
    local connections, characterConnections = {}, {}
    local cameraConnection, camera, character
    local locked, saved, writing, alive = false, nil, false, true
    local revision = 0
    local function isFly(v)
        return v.Name == "flyjutsu" and v:IsA("LocalScript")
    end
    local function hasFly()
        if character then
            for _, v in ipairs(character:GetChildren()) do
                if isFly(v) then return true end
            end
        end
        return false
    end
    local function enforce()
        if locked and camera and saved and not writing and camera.FieldOfView ~= saved then
            writing = true
            camera.FieldOfView = saved
            writing = false
        end
    end
    local function bindCamera()
        if cameraConnection then cameraConnection:Disconnect() end
        camera = workspace.CurrentCamera
        if not camera then return end
        if not locked or saved == nil then saved = moveCfg.Fov or camera.FieldOfView end
        cameraConnection = camera:GetPropertyChangedSignal("FieldOfView"):Connect(enforce)
        enforce()
    end
    local function begin()
        revision = revision + 1
        if not locked then saved = moveCfg.Fov or (camera and camera.FieldOfView) or nil end
        locked = true
        enforce()
    end
    local function finish()
        if hasFly() then return end
        revision = revision + 1
        local token = revision
        -- flyjutsu tweens the FOV over 1 s when it ends
        task.delay(1.2, function()
            if alive and revision == token and not hasFly() then
                enforce()
                locked = false
            end
        end)
    end
    local function bindCharacter(h)
        for _, c in ipairs(characterConnections) do c:Disconnect() end
        characterConnections = {}
        revision = revision + 1
        locked = false
        character = h
        characterConnections[1] = h.ChildAdded:Connect(function(v)
            if isFly(v) then begin() end
        end)
        characterConnections[2] = h.ChildRemoved:Connect(function(v)
            if isFly(v) then finish() end
        end)
        if hasFly() then begin() end
    end
    bindCamera()
    connections[1] = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
    connections[2] = p.CharacterAdded:Connect(bindCharacter)
    if p.Character then bindCharacter(p.Character) end
    Move.setFov = function(v)                                       -- slider: apply immediately; the value is also kept while flying
        moveCfg.Fov = v
        saved = v
        if camera then writing = true camera.FieldOfView = v writing = false end
    end
    return function()
        Move.setFov = nil
        alive = false
        revision = revision + 1
        locked = false
        if cameraConnection then cameraConnection:Disconnect() end
        for _, c in ipairs(connections) do c:Disconnect() end
        for _, c in ipairs(characterConnections) do c:Disconnect() end
    end
end

-- Puppet: directional puppet jumps in the air (count, gap and speed come from moveCfg)
function Move.puppet()
    if type(genv.puppetdash) == "function" then genv.puppetdash() end
    if type(genv.pd) == "function" then genv.pd() end
    local p = LocalPlayer
    local u = UserInputService
    local r = RunService
    local alive, connections, characterLinks = true, {}, {}
    local h, hum, root, animator, used, last, epoch = nil, nil, nil, nil, 0, 0, 0
    local tracks, owned = {}, {}
    local baseJumpPower, appliedJumpPower, jumpSound
    local pending = false
    local ids = { front = "13193731783", right = "13193698000", left = "13193705218", back = "13193769102" }
    local byId = {}
    for direction, id in pairs(ids) do byId[id] = direction end
    local function restoreJump()
        if hum and hum.Parent and appliedJumpPower and hum.JumpPower == appliedJumpPower and baseJumpPower then
            hum.JumpPower = baseJumpPower
        end
        appliedJumpPower = nil
    end
    local function clear()
        restoreJump()
        epoch = epoch + 1
        pending = false
        for _, c in ipairs(characterLinks) do c:Disconnect() end
        characterLinks = {}
        for _, t in pairs(tracks) do pcall(function() t:Stop() t:Destroy() end) end
        tracks, owned = {}, {}
        if jumpSound then jumpSound:Destroy() jumpSound = nil end
    end
    local function allowed()
        if not h or p.Character ~= h or not hum or not root or not animator or hum.Health <= 0 or root.Anchored then return false end
        if hum.FloorMaterial ~= Enum.Material.Air or hum.PlatformStand or h:FindFirstChild("stayonground") then return false end
        local fake = h:FindFirstChild("fakehealth")
        if fake and fake.Value <= 0 then return false end
        local c = h:FindFirstChild("combat")
        if not c or c:FindFirstChild("attacked") or c:FindFirstChild("landed") then return false end
        for _, name in ipairs({ "wallwalk", "ragdoll", "disable", "canrun", "canrunfromslice" }) do
            local v = c:FindFirstChild(name)
            if v and v.Value then return false end
        end
        if root:FindFirstChild("flyattachment") or root:FindFirstChild("stick") then return false end
        local statz = p:FindFirstChild("statz")
        local race = statz and statz:FindFirstChild("race")
        return (race and race.Value == "puppet") or workspace:FindFirstChild("EggEvent") ~= nil
    end
    local function cameraDirection(dir, fallback)
        local camera = workspace.CurrentCamera
        local d = camera and ((dir == "left" or dir == "right") and camera.CFrame.RightVector or camera.CFrame.LookVector) or fallback
        d = Vector3.new(d.X, 0, d.Z)
        if d.Magnitude <= .001 then d = Vector3.new(fallback.X, 0, fallback.Z) end
        d = d.Magnitude > .001 and d.Unit or Vector3.new(0, 0, -1)
        return (dir == "back" or dir == "right") and -d or d
    end
    local function direction()
        local d = hum.MoveDirection
        d = Vector3.new(d.X, 0, d.Z)
        if d.Magnitude <= .001 then return end
        d = d.Unit
        local camera = workspace.CurrentCamera
        local dir = "front"
        if camera then
            local cf = CFrame.lookAt(root.Position, root.Position + d)
            local offset = camera.CFrame.Position - root.Position
            local function near(axis)
                return offset.Magnitude > .001 and offset.Unit:Dot(axis.Unit) >= .5
            end
            if near((cf * CFrame.Angles(0, math.pi / 2, 0)).LookVector) then dir = "right"
            elseif near((cf * CFrame.Angles(0, -math.pi / 2, 0)).LookVector) then dir = "left"
            elseif near(cf.LookVector) then dir = "back" end
        end
        return dir, cameraDirection(dir, d)
    end
    local function releaseDash()
        local v = root:FindFirstChild("dashvelocity")
        if not v or not v:IsA("LinearVelocity") or v.VelocityConstraintMode ~= Enum.VelocityConstraintMode.Plane then return end
        local q = root.AssemblyLinearVelocity
        local a, b = v.PrimaryTangentAxis, v.SecondaryTangentAxis
        local d = a * v.PlaneVelocity.X + b * v.PlaneVelocity.Y
        if d.Magnitude > 150 then d = d.Unit * 150 end
        v:Destroy()
        root.AssemblyLinearVelocity = q - a * q:Dot(a) - b * q:Dot(b) + d
        local attachment = root:FindFirstChild("DashAttachment")
        if attachment and not root:FindFirstChild("dashvelocity") then attachment:Destroy() end
    end
    local function boost(d)
        if not root or not root.Parent then return end
        local q = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(d.X * moveCfg.PuppetSpeed, q.Y, d.Z * moveCfg.PuppetSpeed)
    end
    local function bind(character)
        clear()
        h, hum, root, animator = character, nil, nil, nil
        used, last = 0, 0
        local token = epoch
        task.spawn(function()
            local a = character:WaitForChild("Humanoid", 5)
            local b = character:WaitForChild("HumanoidRootPart", 5)
            local c = a and a:WaitForChild("Animator", 5)
            if not alive or token ~= epoch or not a or not b or not c then return end
            hum, root, animator = a, b, c
            baseJumpPower = a.FloorMaterial ~= Enum.Material.Air and a.JumpPower or nil
            appliedJumpPower = nil
            jumpSound = Instance.new("Sound")
            jumpSound.SoundId = "rbxassetid://9165300727"
            jumpSound.Volume = 1
            jumpSound.Parent = character
            local function landed()
                if used == 0 and not appliedJumpPower then return end
                used = 0 epoch = epoch + 1 last = 0 pending = false
                for _, track in pairs(tracks) do
                    if track.IsPlaying then track:Stop(.05) end
                end
                restoreJump()
            end
            characterLinks[#characterLinks + 1] = a.StateChanged:Connect(function(_, state)
                if state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Dead then landed() end
            end)
            characterLinks[#characterLinks + 1] = a:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
                if a.FloorMaterial ~= Enum.Material.Air then landed() end
            end)
            characterLinks[#characterLinks + 1] = c.AnimationPlayed:Connect(function(track)
                local id = track.Animation and track.Animation.AnimationId:match("%d+")
                if not byId[id] or owned[track] or a.FloorMaterial ~= Enum.Material.Air then return end
                used = used + 1 last = os.clock()
                -- the game's own puppet jump sets jump power to 1.5x before playing the animation
                baseJumpPower = a.JumpPower / 1.5
                local d = cameraDirection(byId[id], a.MoveDirection)
                local currentRoot, currentEpoch = root, epoch
                task.spawn(function()
                    r.PreSimulation:Wait()
                    if alive and epoch == currentEpoch and root == currentRoot and currentRoot.Parent and a.FloorMaterial == Enum.Material.Air then boost(d) end
                end)
            end)
        end)
    end
    connections[#connections + 1] = u.JumpRequest:Connect(function()
        local limit, gap = moveCfg.PuppetLimit, moveCfg.PuppetGap
        if not alive or pending or used < 2 or used >= limit or os.clock() - last < gap or not allowed() then return end
        local token, count = epoch, used
        local dir, d = direction()
        if not dir then return end
        pending = true
        task.delay(.05, function()
            if not alive or token ~= epoch then return end
            pending = false
            if used ~= count or used >= limit or os.clock() - last < gap or not allowed() then return end
            used = used + 1
            last = os.clock()
            releaseDash()
            if baseJumpPower then
                appliedJumpPower = baseJumpPower * 1.5
                hum.JumpPower = appliedJumpPower
            end
            local combat = h:FindFirstChild("combat")
            local remote = combat and combat:FindFirstChild("update")
            if remote and remote:IsA("RemoteEvent") then
                remote:FireServer("puppetboost")
                local deflect = combat:FindFirstChild("deflect")
                if deflect and deflect.Value then remote:FireServer("sublog") end
            end
            boost(d)
            local t = tracks[dir]
            if not t then
                local animation = Instance.new("Animation")
                animation.AnimationId = "rbxassetid://" .. ids[dir]
                local ok, value = pcall(function() return animator:LoadAnimation(animation) end)
                animation:Destroy()
                if ok then t = value tracks[dir] = t owned[t] = true end
            end
            for _, other in ipairs(animator:GetPlayingAnimationTracks()) do
                local id = other.Animation and other.Animation.AnimationId:match("%d+")
                if byId[id] then other:Stop() end
            end
            if t then t.Priority = Enum.AnimationPriority.Action4 t:Play() end
            local jump = tracks.jump
            if not jump then
                local animation = Instance.new("Animation")
                animation.AnimationId = "rbxassetid://9126997146"
                local ok, value = pcall(function() return animator:LoadAnimation(animation) end)
                animation:Destroy()
                if ok then jump = value tracks.jump = jump owned[jump] = true end
            end
            if jump then jump.Priority = Enum.AnimationPriority.Action3 jump:Play() end
            if jumpSound then jumpSound:Play() end
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            for _, other in ipairs(animator:GetPlayingAnimationTracks()) do
                if other.Animation and other.Animation.AnimationId:match("%d+") == "9102156017" then other:Stop() end
            end
            local marker = Instance.new("IntValue")
            marker.Name = "dbljump" marker.Parent = h
            game:GetService("Debris"):AddItem(marker, 1)
            last = os.clock()
        end)
    end)
    connections[#connections + 1] = p.CharacterAdded:Connect(bind)
    connections[#connections + 1] = p.CharacterRemoving:Connect(function(character)
        if character == h then clear() h, hum, root, animator = nil, nil, nil, nil end
    end)
    if p.Character then bind(p.Character) end
    return function()
        alive = false clear()
        for _, c in ipairs(connections) do c:Disconnect() end
    end
end

-- Wider dash: fixed dash speed from moveCfg (left alone while right click is held)
function Move.widerDash()
    if type(genv.WiderDashStop) == "function" then genv.WiderDashStop() end
    local connection = RunService.PreSimulation:Connect(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            return
        end
        local dash = root:FindFirstChild("dashvelocity")
        if not dash or not dash:IsA("LinearVelocity")
            or dash.VelocityConstraintMode ~= Enum.VelocityConstraintMode.Plane then
            return
        end
        local velocity = dash.PlaneVelocity
        if velocity.Magnitude > 0 then
            dash.PlaneVelocity = velocity.Unit * moveCfg.DashSpeed
        end
    end)
    return function() connection:Disconnect() end
end

local moveStops = {}
local function moveToggle(key)                                      -- toggle → start / stop
    return function(on)
        if moveStops[key] then pcall(moveStops[key]) moveStops[key] = nil end
        if on then
            local ok, stop = pcall(Move[key])
            if ok then moveStops[key] = stop else hubError(key, stop) end
        end
    end
end
hub.Cleanup[#hub.Cleanup + 1] = function()
    for k, stop in pairs(moveStops) do pcall(stop) moveStops[k] = nil end
end
hub.MoveStops = moveStops                                           -- for tests

local moveTab = movementPage
moveStops.flyFov = Move.flyFov()                                    -- FOV protection is always on

local Basic = moveTab:Card({ Title = "Movement", Icon = "footprints" })
Basic:Toggle({ Title = "Always run", Flag = "mv_run", Default = false, Callback = moveToggle("alwaysRun") })
Basic:Toggle({ Title = "NoClip", Flag = "p_noclip", Default = false, Callback = set("NoClip") })
Basic:Toggle({ Title = "Click TP", Flag = "p_clicktp", Default = false, Callback = set("ClickTP") })

-- Puppet Jump and Wider dash: their on / off switch sits in the card header
local Puppet = moveTab:Card({ Title = "Puppet Jump", Icon = "zap", Side = "Right" })
Puppet:HeaderSwitch({ Flag = "mv_puppet", Default = false, Callback = moveToggle("puppet") })
Puppet:Slider({ Title = "Speed", Flag = "mv_puppetspeed", Min = 50, Max = 400, Default = 200, DependsOn = { Flag = "mv_puppet", Reason = "" },
    Callback = function(v) moveCfg.PuppetSpeed = v end })
Puppet:Stepper({ Title = "Count", Flag = "mv_puppetcount", Min = 2, Max = 10, Default = 5, DependsOn = { Flag = "mv_puppet", Reason = "" },
    Callback = function(v) moveCfg.PuppetLimit = v end })

local Cam = moveTab:Card({ Title = "Camera", Icon = "camera" })
Cam:Slider({ Title = "FOV", Flag = "mv_fov", Min = 30, Max = 120, Default = 70, Callback = function(v)
    if Move.setFov then Move.setFov(v) else moveCfg.Fov = v end
end })
Cam:Toggle({ Title = "Unlock zoom", Flag = "p_zoom", Default = false, Callback = set("UnlockZoom") })

local Dash = moveTab:Card({ Title = "Wider dash", Icon = "wind", Side = "Right" })
Dash:HeaderSwitch({ Flag = "mv_dash", Default = false, Callback = moveToggle("widerDash") })
Dash:Slider({ Title = "Speed", Flag = "mv_dashspeed", Min = 50, Max = 300, Default = 125, Suffix = " studs/s", DependsOn = { Flag = "mv_dash", Reason = "" },
    Callback = function(v) moveCfg.DashSpeed = v end })

----- Player: general -----
local Spec = playerPage:Card({ Title = "Spectate", Icon = "video", Side = "Right" })
local specList = Spec:PlayerList({ Title = "Player", Multi = false, Height = 120 })
local specRow = Spec:Row({ Widths = { 2, 1 } })
specRow:Button({ Title = "Spectate", Icon = "eye", Style = "Primary", Callback = function()
    local chosen = specList:GetPlayers()
    if chosen and chosen[1] then spectate(chosen[1]) end
end })
specRow:Button({ Title = "Stop", Icon = "square", Style = "Ghost", Callback = function() spectate(nil) end })
hub.PlayerLateCards = { PlayerMisc, Spec }                          -- moved below the Shindo cards
end

----- Server -----
-- Layout C: server browser on the left (fill bar + ping + one-click Join), Options and Job ID on the right.
local Server = Tabs.Server
local SrvCard = Server:Card({ Title = "Servers", Icon = "server", Desc = "Pick by player count and ping" })

-- ServerList: not part of the lib, drawn by hand into the card body (bound to theme colours)
local util = Lib.Util
local theme = Lib.Theme
local srvBox = util.create("Frame", { Name = "ServerList", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = SrvCard:_order(), Parent = SrvCard.body })
util.list(srvBox, 5)
local srvRows, srvCache, srvSort = {}, {}, "Asc"
local maxServers = 8

local function pingLevel(ms)
    if ms < 80 then return 4 elseif ms < 150 then return 3 elseif ms < 250 then return 2 end
    return 1
end
local function myPing()
    local ok, p = pcall(function() return LocalPlayer:GetNetworkPing() * 2000 end)   -- one way → round trip
    return ok and floor(p) or 0
end

local function srvRow(order, s, current)
    local row = util.create("Frame", { Name = "Server", Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, LayoutOrder = order, Parent = srvBox })
    theme.bind(row, "BackgroundColor3", "input")
    util.corner(row, 8)
    theme.bind(util.stroke(row), "Color", current and "edge" or "line")
    local id = util.label(row, "#" .. string.sub(s.id or "", 1, 6), 10, { Position = UDim2.new(0, 9, 0, 0), Size = UDim2.new(0.2, -4, 1, 0) })
    theme.bind(id, "TextColor3", current and "heading" or "text")
    local pct = (s.maxPlayers or 0) > 0 and math.clamp((s.playing or 0) / s.maxPlayers, 0, 1) or 0
    local bar = util.create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.2, 4, 0.5, 0), Size = UDim2.new(0.17, 0, 0, 4), BorderSizePixel = 0, Parent = row })
    theme.bind(bar, "BackgroundColor3", "buttonEdge")
    util.corner(bar, 2)
    local fill = util.create("Frame", { Size = UDim2.new(pct, 0, 1, 0), BorderSizePixel = 0, Parent = bar })
    theme.bind(fill, "BackgroundColor3", "accent")
    util.corner(fill, 2)
    local cnt = util.label(row, ("%d/%d"):format(s.playing or 0, s.maxPlayers or 0), 9, { Position = UDim2.new(0.39, 4, 0, 0), Size = UDim2.new(0.12, 0, 1, 0) })
    theme.bind(cnt, "TextColor3", "muted")
    local ms = floor(s.ping or 0)
    local lvl = pingLevel(ms)
    for k = 1, 4 do
        local b = util.create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.52, (k - 1) * 4, 0.5, 6), Size = UDim2.fromOffset(2.5, 2 + k * 2), BorderSizePixel = 0, Parent = row })
        theme.bind(b, "BackgroundColor3", k <= lvl and (lvl >= 3 and "success" or "warning") or "buttonEdge")
        util.corner(b, 1)
    end
    local pl = util.label(row, ms > 0 and (ms .. " ms") or "-", 9, { Position = UDim2.new(0.52, 20, 0, 0), Size = UDim2.new(0.16, 0, 1, 0) })
    theme.bind(pl, "TextColor3", "muted")
    local btn = util.create("TextButton", { Text = current and "Rejoin" or "Join", TextSize = 9, Font = Enum.Font.GothamMedium, AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(54, 20), BorderSizePixel = 0, Parent = row })
    theme.bind(btn, "BackgroundColor3", "buttonEdge")
    theme.bind(btn, "TextColor3", "heading")
    util.corner(btn, 6)
    btn.MouseEnter:Connect(function() theme.tweenTo(btn, "BackgroundColor3", "hover", 0.1) end)
    btn.MouseLeave:Connect(function() theme.tweenTo(btn, "BackgroundColor3", "buttonEdge", 0.1) end)
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
    for i = 1, math.min(#list, maxServers) do srvRows[#srvRows + 1] = srvRow(10 + i, list[i], false) end
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
        srvBusy = false
        if not Running then return end
        srvCache = ok and list or {}
        local drawn, err = pcall(drawServers)
        if not drawn then hubError("Server list", err) end
    end)
end
srvCurrent = srvRow(1, { id = game.JobId, playing = #Players:GetPlayers(), maxPlayers = Players.MaxPlayers, ping = myPing() }, true)

local srvBtns = SrvCard:Row()
srvBtns:Button({ Title = "Refresh", Icon = "refresh-cw", Cooldown = 3, Callback = refreshServers })
srvBtns:Button({ Title = "Emptiest", Icon = "shuffle", Callback = function() srvSort = "Smallest" drawServers() end })
srvBtns:Button({ Title = "Lowest ping", Icon = "wifi", Callback = function() srvSort = "Ping" drawServers() end })
SrvCard:Button({ Title = "Random hop", Icon = "shuffle", Style = "Ghost", Cooldown = 5, Callback = function() serverHop("Random") end })
task.delay(1, function() if Running then refreshServers() end end)

-- the "Players" info the old code expected → now updates the "you are here" row in the list
local playersInfo = { Set = function()
    local n, m = #Players:GetPlayers(), Players.MaxPlayers
    srvCurrent.cnt.Text = ("%d/%d"):format(n, m)
    srvCurrent.fill.Size = UDim2.new(m > 0 and n / m or 0, 0, 1, 0)
    local p = myPing()
    srvCurrent.pl.Text = p > 0 and (p .. " ms") or "-"
end }

local Opt = Server:Card({ Title = "Options", Icon = "settings-2", Side = "Right" })
Opt:ListItem({ Title = "Staff alert", Icon = "shield-alert", Toggle = true, Flag = "s_staff", Default = false, Callback = function(on)
    settings.StaffAlert = on
    if on then for _, p in ipairs(Players:GetPlayers()) do checkStaff(p) end end
end })
local staffDependency = { Flag = "s_staff", Mode = "Hide", Reason = "" }
Opt:Input({ Title = "Group ID", Placeholder = "game's group ID", Flag = "s_group", Numeric = true, DependsOn = staffDependency,
    Callback = function(text) settings.StaffGroup = tonumber(text) or 0 end })
Opt:Slider({ Title = "Min rank", Flag = "s_rank", Min = 1, Max = 255, Default = 1, DependsOn = staffDependency, Callback = set("StaffRank") })
Opt:Segment({ Title = "Action", Flag = "s_action", Items = { "Notify", "Hop", "Leave" }, Default = "Notify", DependsOn = staffDependency, Callback = set("StaffAction") })
Opt:ListItem({ Title = "Auto rejoin on kick", Icon = "refresh-cw", Toggle = true, Flag = "s_autorejoin", Default = false, Callback = set("AutoRejoin") })
Opt:ListItem({ Title = "Re-execute after teleport", Icon = "scroll-text", Toggle = true, Flag = "misc_queue", Default = false,
    Desc = queue and "Hub reopens after teleport" or "Executor doesn't have queue_on_teleport",
    Callback = function(on)
        if on then queueHub() else queuePermission(hubStopFile, false) end
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

----- Settings + startup -----
Window:SetModule("ESP", "Off", nil, { Icon = "eye", Tab = "Visuals" })
Window:SetModule("Silent Aim", CanHook and "Off" or "Limited", not CanHook and "no hook" or nil, { Icon = "target", Tab = "Combat" })

Window:OnKick(function()
    if settings.AutoRejoin then task.delay(2, function() if Running and settings.AutoRejoin then rejoin() end end) end
end)

----- Loops -----
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    Camera = Workspace.CurrentCamera
end)
connect(Players.PlayerRemoving, function(plr)
    removeEntry(plr)
    FriendCache[plr.UserId] = nil
    if Spectating == plr then spectate(nil) end
end)
connect(Players.PlayerAdded, checkStaff)

-- Every part runs in its own pcall: an error in one player's ESP does not freeze the FOV, other players or the world.
-- (Previously a single ESP error stopped the rest of the frame, including the FOV circle.)
local function safe(tag, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then hubError(tag, err) end                       -- reports the same error at most once every 10 s
    return ok
end
Render.safe = safe

connect(RunService.RenderStepped, function()
    if not Running then return end
    esp.Frame += 1
    if not Camera then
        Silent.Target = nil
        hideUnused(Global, true)
        for _, e in pairs(esp.Entries) do e.chamsReady = false hideUnused(e, true) end
        return
    end
    if not safe("Silent Aim", function() Silent.Target = findTarget() end) then Silent.Target = nil end
    if Render.Available then                                     -- no Drawing API: nothing can be drawn
        safe("FOV", updateGlobal)                                -- FOV first: it is drawn whatever happens to the ESP
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and not safe("ESP", updatePlayer, plr) then
                local e = esp.Entries[plr]                       -- do not leave a half-drawn frame on screen
                if e then hideUnused(e, true) end
            end
        end
    end
    safe("World", updateWorld)
    if Spectating then
        local _, hum = getCharacter(Spectating)
        if hum and Camera.CameraSubject ~= hum then Camera.CameraSubject = hum end
    end
    Render.flush()
end)

task.spawn(function()                                            -- player table, every 2 seconds
    while Running do
        local rows = {}
        local _, _, myRoot = getCharacter(LocalPlayer)
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local _, hum, root = getCharacter(plr)
                local dist = (myRoot and root) and floor((root.Position - myRoot.Position).Magnitude) or "-"
                rows[#rows + 1] = { plr.Name, plr.Team and plr.Team.Name or "-", hum and floor(healthValue(hum)) or 0, dist }
            end
        end
        pcall(function()
            playerTable:SetItems(rows)
            playersInfo:Set(#Players:GetPlayers() .. " / " .. Players.MaxPlayers)
        end)
        task.wait(2)
    end
end)

----- Unload -----
env.QustahShindoCore = {
    Unload = function()
        if not Running then return end
        Running = false
        pcall(hubStop)                                           -- farm / spin / player loops and the platform
        for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
        for plr in pairs(esp.Entries) do removeEntry(plr) end
        for _, o in pairs(Global.Obj) do Render.remove(o) end
        stopNoClip()
        restoreWorld()
        spectate(nil)
        env.QustahShindoCore = nil
        pcall(function() Window:Destroy() end)
    end,
}
unloadThis = env.QustahShindoCore.Unload
end

----- Farm -----
do
	local Farm = Tabs.Farm
	local QuestPage = Farm:Page("Quests")
	local MentorPage = Farm:Page("Mentor", { Compact = true })
	local DailyPage = Farm:Page("Daily", { Compact = true })

	local farm = {
		Scroll = false, Boss = false,
		BossSpecific = false, BossSel = {},   -- as in DogeHub: Specific (multi-select) / Random
		StuckAfter = 60,                                         -- cancel stuck missions (no setting, handled internally)
		Stats = {}, AutoRank = false, RankAfterMax = false, RankRC = false, RankStop = false, RankStopAt = 500,
		-- Mentor and Daily use separate keys so turning one off does not stop the other
		PunchM = false, PunchD = false, TreeM = false, TreeD = false, Shoot = false, Rush = false, Chi = false, DailyBoss = false,
	}
	local greenScroll = "http://www.roblox.com/asset/?id=5459241648"
	if env.QustahShindoCore then env.QustahShindoCore.Farm, env.QustahShindoCore.Hub = farm, hub end   -- for tests

	local function timerReady(giver)                            -- has the boss mission giver's cooldown finished
		local ok, txt = pcall(function() return giver.missiongiver.timer.time.time.Text end)
		return ok and (txt == "00:00" or txt == "59:59")
	end
	local function talkTo(giver)
		local mg = giver:FindFirstChild("missiongiver")
		if not (mg and mg:FindFirstChild("HumanoidRootPart") and mg:FindFirstChild("CLIENTTALK")) then return end
		tpTo(mg.HumanoidRootPart.CFrame + Vector3.new(0, -0.8, 0))
		mg.CLIENTTALK:FireServer(LocalPlayer)
	end
	-- the missions folder lists every boss; only the bosses on this map contain a "missiongiver" (the NPC you talk to)
	local bossFolders = { "bossdropmission", "sengokubossfight" }
	local function bossGivers()
		local out = {}
		for _, folderName in ipairs(bossFolders) do
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
	local function names(list)
		local out, seen = {}, {}
		for _, g in ipairs(list) do
			if not seen[g.Name] then seen[g.Name] = true out[#out + 1] = g.Name end
		end
		table.sort(out)
		return out
	end
	local function greenInfo(v)                                       -- is this a green "defeat" giver, and is it giving a mission right now
		local gm = v:FindFirstChild("Head") and v.Head:FindFirstChild("givemission")
		local typ = v:FindFirstChild("Talk") and v.Talk:FindFirstChild("typ")
		if not (gm and typ and typ.Value == "defeat" and gm:FindFirstChild("color") and gm.color.Image == greenScroll) then return false end
		return true, gm.Enabled and v:FindFirstChild("HumanoidRootPart") ~= nil and v:FindFirstChild("CLIENTTALK") ~= nil
	end
	local function acceptScrollQuest(alive)                          -- take a green scroll "defeat" mission
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
	local bossGiver                                              -- giver of the boss mission currently in progress
	local lastGiver                                              -- last boss giver, used for the safe spot
	local bossKilled = false                                     -- did we actually kill a mob during this boss mission
	local function giverTaken(g)                                 -- is someone else already doing this boss mission
		local p = g:FindFirstChild("position")
		local p1 = p and p:FindFirstChild("p1")
		return p1 ~= nil and p1:FindFirstChild("inmission") ~= nil
	end
	local progressAt = os.clock()                               -- last progress (mob died / mission started)
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
	-- Only this mission's mobs: those whose type appears in the mission text and are within 500 studs of the mission point.
	-- If none are found the filter is relaxed step by step (type only → distance only → everything during a boss mission).
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
			-- As in DogeHub: keep hitting until the mob's Humanoid is removed (it died on the server) or the mission ends.
			-- Health is not checked: we set it to 0 locally so it always looks "dead", which made us leave before the boss was killed.
			while flagFn() and inMission() and v.Parent and v:FindFirstChild("Humanoid") do
				pcall(attackNPC, v)                                   -- keep the loop alive if the mob is removed mid-attack
				task.wait(0.05)
			end
			if not (v.Parent and v:FindFirstChild("Humanoid")) then
				progressAt = os.clock()
				if bossGiver then bossKilled = true end
			end
		end
		-- boss mission: the boss is really dead or cannot be hit (full susanoo) → wait at the safe spot until the mission ends.
		-- If the boss has not spawned yet, wait in place (moving away might stop it from loading at all).
		if bossGiver and flagFn() and inMission() and #missionMobs() == 0 and (bossKilled or susanooNPCs() > 0) then
			goSafe(bossGiver)
		end
	end

	local lastMission
	local function farmAlive()
		return hub.Running and (farm.Scroll or farm.Boss or farm.DailyBoss)
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
		if not farmAlive() then if SafePart or platformFixed then leaveSafe() end return end   -- farm turned off: remove the safe floor
		if placeType ~= "map" or hub.ScrollBusy then return end
		hub.FarmBusy = true
		local ok, err = pcall(function()
			local cur = currentMission()
			if cur ~= lastMission then lastMission, progressAt = cur, os.clock() end
			if cur then
				local _, objective = missionInfo(cur)
				if objective and objective ~= "Mission" then          -- a mission type the farm cannot do
					if cancelMission() then notify("Auto farm", "Mission type '" .. objective .. "', cancelled", "circle-x", "warning") end
					task.wait(1)
					return
				end
			end
			if inMission() and farm.StuckAfter > 0 and os.clock() - progressAt > farm.StuckAfter then   -- stuck
				if cancelMission() then notify("Auto farm", farm.StuckAfter .. "s without progress, mission cancelled", "circle-x", "warning") end
				progressAt = os.clock()
				leaveSafe()
				task.wait(1)
				return
			end
			if inMission() then killMissionMobs(farmAlive) return end
			bossGiver, bossKilled = nil, false                       -- mission finished
			if farm.Boss and acceptFrom(bossGivers(), (farm.BossSpecific and #farm.BossSel > 0 and farm.BossSel) or "Random", function() return hub.Running and farm.Boss end) then
				return
			end
			if hub.Running and farm.DailyBoss and acceptFrom(dailyBossGivers(), "Random", function() return hub.Running and farm.DailyBoss end) then return end
			if hub.Running and farm.Scroll and not inMission() then
				leaveSafe()
				acceptScrollQuest(function() return hub.Running and farm.Scroll end)
				return
			end
			-- only boss farm is on and no boss is ready: wait above the last boss until the next one
			if (farm.Boss or farm.DailyBoss) and lastGiver and lastGiver.Parent then goSafe(lastGiver) end
		end)
		hub.FarmBusy = false
		if not farmAlive() then leaveSafe() end
		if not ok then error(err, 0) end
	end)

	-- Like DogeHub's "Quests" page: Auto Farm · Configurations · Boss Farm Settings
	local autoFarmCard = QuestPage:Card({ Title = "Auto Farm", Icon = "scroll-text" })
	local function farmToggle(card, title, key)
		card:Toggle({ Title = title, Flag = "farm_" .. key:lower(), Default = false, Callback = function(on)
			if on ~= farm[key] then if on then platformOn() else platformOff() end end
			farm[key] = on
		end })
	end
	farmToggle(autoFarmCard, "Green Scroll Farm", "Scroll")
	farmToggle(autoFarmCard, "Boss Farm", "Boss")
	-- (auto rank stops once your spins reach this; the amount sits on the same line)
	autoFarmCard:Toggle({ Title = "Stop at spins", Flag = "rank_stop", Default = false, Callback = function(v) farm.RankStop = v end,
		Slider = { Flag = "rank_stopat", Min = 50, Max = 1000, Step = 10, Default = 500, Callback = function(v) farm.RankStopAt = v end } })

	local Conf = QuestPage:Card({ Title = "Configurations", Icon = "sliders-horizontal", Side = "Right" })
	Conf:Toggle({ Title = "Legacy Farm Mode", Flag = "farm_legacy", Default = true, Callback = function(v)
		Attack.Mode = v and "Legacy (M1 + E)" or "Jutsu (E)"
	end })
	Conf:Toggle({ Title = "NPC Kill Aura", Flag = "farm_aura", Default = false, Callback = function(v) hub.FarmAura = v end })

	-- Specific / Random: turning one on turns the other off (as in DogeHub)
	local function pickCard(title, icon, what, list, keySpecific, keySel, flagPrefix)
		local pickedCard = QuestPage:Card({ Title = title, Icon = icon })
		pickedCard:Toggle({ Title = "Specific " .. what, Flag = flagPrefix .. "specific", Default = false, Callback = function(v)
			farm[keySpecific] = v
			if v then Window:SetFlag(flagPrefix .. "random", false) end
		end })
		-- multi-select: several bosses can be ticked and whichever is ready first is taken (nothing ticked behaves like Random)
		local dd = pickedCard:Dropdown({ Title = "Specific " .. what:lower() .. " to kill", Flag = flagPrefix .. "pick", Items = list, Default = {}, Multi = true,
			AllowNone = true, Search = true, Callback = function(v) farm[keySel] = type(v) == "table" and v or { v } end })
		pickedCard:Toggle({ Title = "Random " .. what .. "es", Flag = flagPrefix .. "random", Default = true, Callback = function(v)
			if v then Window:SetFlag(flagPrefix .. "specific", false) end
		end })
		return pickedCard, dd
	end
	local bossList = names(bossGivers())
	local BossSet, bossDD = pickCard("Boss Farm Settings", "skull", "Boss", bossList, "BossSpecific", "BossSel", "farm_boss")
	local bossTotal = 0
	local bossBar = BossSet:Progress({ Title = "Bosses on map", Desc = "Ready to fight", Value = 0, Max = 1,
		Format = function(v) return bossTotal > 0 and ("%d / %d ready"):format(v, bossTotal) or "none" end })

	local function refreshList(dd, list, keySel, flag)
		dd:SetItems(list, true)
		local keep = {}                                          -- drop selections that are not on this map
		for _, n in ipairs(farm[keySel]) do if table.find(list, n) then keep[#keep + 1] = n end end
		if #keep ~= #farm[keySel] then Window:SetFlag(flag, keep) farm[keySel] = keep end
	end
	local function refreshBosses()
		refreshList(bossDD, names(bossGivers()), "BossSel", "farm_bosspick")
	end
	-- boss counters: "ready / total" (ready = cooldown finished and nobody has taken it)
	local function updateCounts()
		local bReady, bTotal = 0, 0
		for _, g in ipairs(bossGivers()) do
			bTotal += 1
			if timerReady(g) and not giverTaken(g) then bReady += 1 end
		end
		bossTotal = bTotal
		bossBar:SetMax(math.max(bTotal, 1))
		bossBar:Set(bReady)
	end
	pcall(updateCounts)
	loop("Farm counts", 2, updateCounts)
	-- Boss NPCs may load later (distant ones): the lists refresh by themselves when a missiongiver appears or disappears
	local pending = false
	local function queueRefresh(obj)
		if obj.Name ~= "missiongiver" or pending then return end
		pending = true
		task.delay(0.5, function() pending = false if hub.Running then pcall(refreshBosses) end end)
	end
	local watched = {}
	local function watchBossFolder(f)
		if watched[f] or not table.find(bossFolders, f.Name) then return end
		watched[f] = true
		hubConnect(f.DescendantAdded, queueRefresh)                  -- the missions folder itself may also arrive later
		hubConnect(f.DescendantRemoving, queueRefresh)
		queueRefresh({ Name = "missiongiver" })
	end
	for _, folderName in ipairs(bossFolders) do
		local f = workspace:FindFirstChild(folderName)
		if f then watched[f] = true hubConnect(f.DescendantAdded, queueRefresh) hubConnect(f.DescendantRemoving, queueRefresh) end
	end
	hubConnect(workspace.ChildAdded, watchBossFolder)

	local Rank = QuestPage:Card({ Title = "Auto rank", Icon = "crown", Side = "Right" })
	Rank:Toggle({ Title = "Auto rank", Desc = "Ranks up at level 1000", Flag = "rank_on", Default = false, Callback = function(v) farm.AutoRank = v end })
	Rank:Toggle({ Title = "Rank up after MAX", Flag = "rank_max", Default = false, Callback = function(v) farm.RankAfterMax = v end })
	Rank:Toggle({ Title = "Use RELL coins", Flag = "rank_rc", Default = false, Callback = function(v) farm.RankRC = v end })
	loop("Auto rank", 0.3, function()
		local s = statz()
		if not (farm.AutoRank and s) then return end
		local spins = s:FindFirstChild("spins")
		if farm.RankStop and spins and spins.Value >= farm.RankStopAt then
			Window:SetFlag("rank_on", false)
			notify("Auto rank", "Spin target reached, stopped", "crown")
			return
		end
		if farm.RankRC then
			if rellCoinOut() then
				Window:SetFlag("rank_rc", false)
				notify("Auto rank", "Out of RELL Coins", "triangle-alert", "warning")
			else
				fire("maxlvlpres2")
			end
		end
		local lvl = s:FindFirstChild("lvl") and s.lvl:FindFirstChild("lvl")
		if lvl and lvl.Value >= 1000 then
			fire(farm.RankAfterMax and "maxlvlpres" or "rankup")
		end
	end)

	local Stats = QuestPage:Card({ Title = "Auto stats", Icon = "gauge" })
	Stats:Dropdown({ Title = "Stats", Flag = "farm_stats", Multi = true, Items = { "chakra", "ninjutsu", "taijutsu", "health" }, Default = {},
		Callback = function(list) farm.Stats = type(list) == "table" and list or {} end })
	loop("Auto stats", 0.25, function()
		if #farm.Stats == 0 then return end
		local s = statz()
		local pts = s and s:FindFirstChild("mastery") and s.mastery:FindFirstChild("points")
		if pts and pts.Value > 0 then
			for _, stat in ipairs(farm.Stats) do
				for _, amt in ipairs({ 1, 17, 288 }) do fire("addstat", stat, amt) end
			end
		end
	end)
	if placeType ~= "map" then QuestPage:Warning("Missions only work on a map (now: " .. placeName() .. ").", { Level = "info" }) end

	----- Mentor -----
	local mentors = { "Narumaki", "Jiso Seishin", "Shindai Akuma", "Ryuji Kenichi", "Bruce Kenichi" }
	local rank = statz() and statz():FindFirstChild("prestige") and statz().prestige:FindFirstChild("rank") and statz().prestige.rank.Value or "?"
	local mentorCard = MentorPage:Card({ Title = "Mentor", Icon = "graduation-cap", Desc = "Requires S rank or higher (your rank: " .. tostring(rank) .. ")" })
	mentorCard:Button({ Title = "Go to mentor", Icon = "map-pin", Style = "Primary", Callback = function()
		local sensei = workspace:FindFirstChild("sensei")
		if sensei and sensei:FindFirstChild("missions") then
			for _, name in ipairs(mentors) do
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
	mentorCard:Toggle({ Title = "Auto punch", Desc = "Punch missions", Flag = "mt_punch", Default = false, Callback = function(v) farm.PunchM = v end })
	mentorCard:Toggle({ Title = "Auto tree jump", Desc = "Tree jump missions", Flag = "mt_tree", Default = false, Callback = function(v) farm.TreeM = v end })
	mentorCard:Toggle({ Title = "Auto kunai shoot", Desc = "Target board missions", Flag = "mt_shoot", Default = false, Callback = function(v) farm.Shoot = v end })
	mentorCard:Button({ Title = "Kenjutsu training", Icon = "sword", Callback = function() fire("trainkenmaster") end })

	-- Progress: read from statz.senseifolder (trainings done per mentor, today's count, completed) and the
	-- running mission's amount / maxamount when the game gives one
	local progressCard = MentorPage:Card({ Title = "Progress", Icon = "activity", Side = "Right" })
	local mentorNow = progressCard:Info({ Title = "Current mentor", Value = "-" })
	local missionActive = false
	local missionBar = progressCard:Progress({ Title = "Current mission", Value = 0, Max = 1,
		Format = function(value, maxValue) return missionActive and (tostring(value) .. " / " .. tostring(maxValue)) or "No mission" end })
	local mentorRows = {}
	for _, name in ipairs(mentors) do mentorRows[name] = progressCard:Info({ Title = name, Value = "-" }) end
	local function missionAmounts()
		local cm = LocalPlayer:FindFirstChild("currentmission")
		local mission = cm and cm.Value
		local amount = mission and mission:FindFirstChild("amount")
		local maxAmount = mission and mission:FindFirstChild("maxamount")
		if amount and maxAmount and tonumber(maxAmount.Value) and maxAmount.Value > 0 then return tonumber(amount.Value) or 0, maxAmount.Value end
	end
	loop("Mentor progress", 1, function()
		local st = statz()
		local folder = st and st:FindFirstChild("senseifolder")
		local current = st and st:FindFirstChild("currentsensei")
		mentorNow:Set(current and current.Value ~= "" and tostring(current.Value) or "None")
		for name, row in pairs(mentorRows) do
			local v = folder and folder:FindFirstChild(name)
			if v then
				local done = v:FindFirstChild("completed")
				local today = v:FindFirstChild("dailytrainings")
				row:Set((done and done.Value) and "Completed" or string.format("%s done · %s today", tostring(v.Value), tostring(today and today.Value or 0)))
			else
				row:Set("-")
			end
		end
		local amount, maxAmount = missionAmounts()
		missionActive = amount ~= nil
		if amount then
			missionBar:SetMax(maxAmount)
			missionBar:Set(amount)
		else
			missionBar:SetMax(1)
			missionBar:Set(0)
		end
	end)
	loop("Mentor", 0.05, function()
		if hub.FarmBusy or hub.ScrollBusy then return end
		if farm.PunchM or farm.PunchD or farm.Shoot then
			if farm.Shoot then
				local mine = workspace.Terrain:FindFirstChild(LocalPlayer.Name)
				local aim = mine and mine:FindFirstChild("kunaiaim")
				if aim then lookAt(aim.Position) end
			end
			combat("mouse1", true)
		end
		if farm.TreeM or farm.TreeD then combat("takemovement2") end
	end)

	----- Daily -----
	local autoDailyCard = DailyPage:Card({ Title = "Auto daily", Icon = "repeat", Side = "Left" })
	autoDailyCard:HeaderButton({ Title = "Claim all", Icon = "gift", Callback = function()      -- claims every daily and main mission
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
	autoDailyCard:Toggle({ Title = "M1", Flag = "dl_m1", Default = false, Callback = function(v) farm.PunchD = v end })
	autoDailyCard:Toggle({ Title = "Rush", Flag = "dl_rush", Default = false, Callback = function(v) farm.Rush = v end })
	autoDailyCard:Toggle({ Title = "Chi charge", Flag = "dl_chi", Default = false, Callback = function(v) farm.Chi = v end })
	autoDailyCard:Toggle({ Title = "Tree jumps", Flag = "dl_tree", Default = false, Callback = function(v) farm.TreeD = v end })
	autoDailyCard:Toggle({ Title = "Daily boss quests", Flag = "dl_boss", Default = false, Callback = function(v)
		if v ~= farm.DailyBoss then if v then platformOn() else platformOff() end end   -- platform, as in boss farm
		farm.DailyBoss = v
	end })
	-- Schedule: starts the dailies on a new day, claims each one when it is done (and stops its toggle), tells you when
	-- all are done. A new day is noticed when a daily's progress goes back down (the game's daily reset).
	local scheduleCard = DailyPage:Card({ Title = "Schedule", Icon = "clock", Side = "Right" })
	local schedule = { Start = false, Claim = true, Notify = false }
	scheduleCard:Toggle({ Title = "Start at reset", Desc = "Begins the dailies right after the reset", Flag = "dl_start", Default = false, Callback = function(v) schedule.Start = v end })
	scheduleCard:Toggle({ Title = "Claim when done", Desc = "Claims a finished daily and turns it off", Flag = "dl_claim", Default = true, Callback = function(v) schedule.Claim = v end })
	scheduleCard:Toggle({ Title = "Notify when all done", Flag = "dl_notify", Default = false, Callback = function(v) schedule.Notify = v end })
	local nextReset = scheduleCard:Info({ Title = "Next reset", Value = "-" })
	-- daily quest type -> Auto daily toggle
	local dailyFlags = { punch = "dl_m1", rush = "dl_rush", chakra = "dl_chi", treejump = "dl_tree", fightboss = "dl_boss" }
	local dailyState = { dl_m1 = "PunchD", dl_rush = "Rush", dl_chi = "Chi", dl_tree = "TreeD", dl_boss = "DailyBoss" }   -- flag -> farm field
	local lastAmount, allDoneSaid = {}, false
	loop("Daily schedule", 2, function()
		-- countdown to 00:00 UTC (Roblox's day; shown until the game's own reset is seen to differ)
		local now = os.time()
		local left = 86400 - now % 86400
		nextReset:Set(string.format("%02d:%02d:%02d", math.floor(left / 3600), math.floor(left % 3600 / 60), left % 60))
		local st = statz()
		local m = st and st:FindFirstChild("mission")
		if not m then return end
		local reset, tracked, done = false, 0, 0
		for i = 1, 14 do
			local q = m:FindFirstChild("dailyquest" .. i)
			local flag = q and dailyFlags[tostring(q.Value)]
			if flag then
				local amount, maxAmount, claimed = q:FindFirstChild("amount"), q:FindFirstChild("maxamount"), q:FindFirstChild("claim")
				local a, mx = tonumber(amount and amount.Value) or 0, tonumber(maxAmount and maxAmount.Value) or 0
				if lastAmount[i] and a < lastAmount[i] then reset = true end
				lastAmount[i] = a
				local finished = mx > 0 and a >= mx
				local running = farm[dailyState[flag]] == true
				if running or finished then tracked += 1 end
				if finished then
					done += 1
					if schedule.Claim then
						if claimed and claimed.Value == false then fire("claim", q) end
						if running then Window:SetFlag(flag, false) end
					end
				end
			end
		end
		if reset then
			allDoneSaid = false
			if schedule.Start then
				for i = 1, 14 do
					local q = m:FindFirstChild("dailyquest" .. i)
					local flag = q and dailyFlags[tostring(q.Value)]
					if flag then Window:SetFlag(flag, true) end
				end
				notify("Daily", "New day: dailies started", "clock")
			end
		end
		if schedule.Notify and not allDoneSaid and tracked > 0 and done >= tracked then
			allDoneSaid = true
			notify("Daily", "All dailies are done", "check")
		end
	end)

	loop("Daily", 0.05, function()
		if hub.FarmBusy or hub.ScrollBusy then return end
		if farm.Rush then combat("rushw") end
		if farm.Chi then combat("key", "c") combat("key", "cend") end
	end)

end

----- Spin -----
if Tabs.Spin then                                                 -- main menu only
	local Spin = Tabs.Spin
	local InfPage = Spin:Page("Inf Spin")
	local RellPage = Spin:Page("Auto RELL")

	----- Inf Spin -----
	local saveFile = "QustahShindo/infspin.json"
	local infSpin = {
		Elements = {}, Bloodlines = {}, Kenjutsu = {}, Races = {},
		ElemSlots = { "1", "2" }, BlSlots = { "1", "2" }, KenSlots = { "1" },
		On = { Element = false, Bloodline = false, Kenjutsu = false, Race = false },
		ResetAt = 0, AutoSave = true, Delay = 0.25,
	}
	local function persist()                                    -- keep the selections across rejoins
		if not writefile then return end
		pcall(function()
			if makefolder and isfolder and not isfolder("QustahShindo") then makefolder("QustahShindo") end
			writefile(saveFile, HttpService:JSONEncode(infSpin))
		end)
	end
	local fromFile                                               -- state read from the json (restored after AutoLoad)
	pcall(function()
		if isfile and isfile(saveFile) then
			local data = HttpService:JSONDecode(readfile(saveFile))
			if type(data) ~= "table" then return end
			local clean = {}
			for k, default in pairs(infSpin) do
				local v = data[k]
				if type(v) == type(default) then
					if k == "On" then
						clean.On = {}
						for name in pairs(default) do clean.On[name] = v[name] == true end
					elseif type(v) == "table" then
						clean[k] = {}
						for _, item in ipairs(v) do if type(item) == "string" then table.insert(clean[k], item) end end
					elseif type(v) ~= "number" or (v == v and math.abs(v) < math.huge) then
						clean[k] = v
					end
				end
			end
			if clean.Delay then clean.Delay = math.clamp(clean.Delay, 0.1, 2) end
			if clean.ResetAt then clean.ResetAt = math.clamp(math.floor(clean.ResetAt), 0, 100) end
			for k, v in pairs(clean) do infSpin[k] = v end
			fromFile = clean
		end
	end)

	local function lists()
		local alljutsu = ReplicatedStorage:FindFirstChild("alljutsu")
		local el, kg, ken, race = {}, {}, {}, {}
		local function add(t, n, inst)                              -- add it to the list under its display name
			n = labelFor(n, inst)
			if not table.find(t, n) then t[#t + 1] = n end
		end
		local rare = workspace:FindFirstChild("RAREKGS")
		if alljutsu then
			if rare then                                        -- this week's rotating limiteds
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
	local elementList, bloodlineList, kenjutsuList, raceList = lists()
	local function orDash(t) return #t > 0 and t or { "-" } end

	local function has(list, v) return v ~= nil and v ~= "" and table.find(list, v) ~= nil end
	local function gp(name) return LocalPlayer:FindFirstChild("gamepasses") and LocalPlayer.gamepasses:FindFirstChild(name) ~= nil end
	local function saveAndLeave()
		fire("band", "Eye")
		task.wait(1)
		if hub.Running and not env.RELL_RUNNING then fire("arenateleport", places.myHome) end
	end
	local function resetAndRejoin()
		queueHub()
		fire("band", "\128")
		task.wait()
		if hub.Running and not env.RELL_RUNNING then TeleportService:Teleport(game.PlaceId, LocalPlayer) end
	end

	-- single loop: for every enabled category, spin in turn until the wanted result arrives
	-- A category that is on but has an empty "Wanted" or "Slots" list is skipped (an empty list used to count as "got it" and saved / left).
	local categories = {
		{ on = "Element", flag = "is_elem_on", wanted = "Elements", slots = "ElemSlots", label = "Elements" },
		{ on = "Bloodline", flag = "is_bl_on", wanted = "Bloodlines", slots = "BlSlots", label = "Bloodlines" },
		{ on = "Kenjutsu", flag = "is_ken_on", wanted = "Kenjutsu", slots = "KenSlots", label = "Kenjutsu" },
		{ on = "Race", flag = "is_race_on", wanted = "Races", label = "Race" },
	}
	local function asList(v) return type(v) == "table" and v or {} end
	local function ready(c)                                     -- enabled and the list is not empty
		if not infSpin.On[c.on] then return false end
		if #asList(infSpin[c.wanted]) == 0 then return false, "Wanted is empty" end
		if c.slots and #asList(infSpin[c.slots]) == 0 then return false, "Slots is empty" end
		return true
	end
	local warned = {}
	local function warning(key, message)
		if warned[key] == message then return end
		warned[key] = message
		notify("Inf Spin", message, "triangle-alert", "warning")
	end
	loop("Inf Spin", function() return tonumber(infSpin.Delay) or 0.25 end, function()
		if placeType ~= "menu" or env.RELL_RUNNING or env.RELLOpening then return end
		local s = statz()
		if not (s and s:FindFirstChild("spins") and s:FindFirstChild("main")) then return end
		local active = {}
		for _, c in ipairs(categories) do
			local ok, why = ready(c)
			if ok then active[c.on] = true warned[c.on] = nil
			elseif why and not warned[c.on] then
				warned[c.on] = true
				notify("Inf Spin", c.label .. ": " .. why .. ", skipped", "triangle-alert", "warning")
			end
		end
		if not next(active) then return end
		local delay = tonumber(infSpin.Delay) or 0.25
		local pending, blocked, low, sent = false, false, false, false
		local function check(c, val, unlocked, cost, send, label)
			if not hub.Running or env.RELL_RUNNING or env.RELLOpening or not infSpin.On[c] then blocked = true return end
			if not val or not unlocked then
				blocked = true
				warning(label, label .. " slot not found or locked")
				return
			end
			warned[label] = nil
			if has(infSpin[c == "Element" and "Elements" or c == "Bloodline" and "Bloodlines" or c == "Race" and "Races" or "Kenjutsu"], val.Value) then return end
			pending = true
			if cost == 0 or s.spins.Value >= infSpin.ResetAt + cost then
				sent = cost > 0 or sent
				send()
				task.wait(delay)
			else
				low = true
			end
		end
		if active.Element then
			for _, n in ipairs(asList(infSpin.ElemSlots)) do
				local slot = "element" .. n
				check("Element", s.main:FindFirstChild(slot), (tonumber(n) or 9) <= 2 or gp(slot), 1,
					function() fire("spin", slot) end, slot)
			end
		end
		if active.Bloodline then
			for _, n in ipairs(asList(infSpin.BlSlots)) do
				local slot = "kg" .. n
				check("Bloodline", s.main:FindFirstChild(slot), (tonumber(n) or 9) <= 2 or gp("genkai" .. n), 1,
					function() fire("spin", slot) end, slot)
			end
		end
		if active.Kenjutsu then
			for _, n in ipairs(asList(infSpin.KenSlots)) do
				local key = n == "1" and "breathingstyle" or "breathingstyle2"
				local unlocked = n == "1" or (s:FindFirstChild("unlocked") and s.unlocked:FindFirstChild("kenjutsuslot2"))
				check("Kenjutsu", s:FindFirstChild(key), unlocked, 10, function()
					if n == "1" then fire("spinBREATHING") else fire("spinBREATHING", key) end
				end, key)
			end
		end
		if active.Race then
			if rellCoinOut() then                                   -- out of coins: turn off the race spin instead of firing remotes for nothing
				infSpin.On.Race = false
				Window:SetFlag("is_race_on", false)
				persist()
				notify("Inf Spin", "Out of RELL Coins, race spin stopped", "triangle-alert", "warning")
				active.Race = nil
				if not next(active) then return end
			else
				check("Race", s:FindFirstChild("race"), true, 0, function() fire("spinrace") end, "Race")
			end
		end
		if not hub.Running or env.RELL_RUNNING or env.RELLOpening or blocked then return end
		if not pending then
			for _, c in ipairs(categories) do
				if active[c.on] then infSpin.On[c.on] = false Window:SetFlag(c.flag, false) end
			end
			persist()
			notify("Inf Spin", "Got what you wanted" .. (infSpin.AutoSave and ", kaydediliyor" or ""), "sparkles", "success")
			if infSpin.AutoSave then saveAndLeave() end
		elseif low and not sent then
			persist()
			notify("Inf Spin", "Out of spins, resetting and rejoining", "rotate-ccw")
			resetAndRejoin()
			task.wait(5)
		end
	end)

	local function category(page, side, title, icon, listKey, items, slotKey, slotItems, onFlag, onKey, desc)
		local c = page:Card({ Title = title, Icon = icon, Side = side, Desc = desc })
		-- lists show display names; saves and spin checks use code names
		local dd = c:Dropdown({ Title = "Wanted", Flag = onFlag .. "_list", Multi = true, Items = orDash(items), Default = mapList(infSpin[listKey], toLabel), Search = true,
			Callback = function(list) infSpin[listKey] = mapList(list, toCode) persist() end })
		if slotKey then
			c:Dropdown({ Title = "Slots", Flag = onFlag .. "_slots", Multi = true, Items = slotItems, Default = infSpin[slotKey],
				Callback = function(list) infSpin[slotKey] = list persist() end })
		end
		c:Toggle({ Title = "Start spinning", Flag = onFlag, Default = infSpin.On[onKey], Callback = function(on)
			if on and (env.RELL_RUNNING or env.RELLOpening) then
				task.defer(function() Window:SetFlag(onFlag, false) end)
				return notify("Inf Spin", "Stop Auto Spin RELL first", "triangle-alert", "warning")
			end
			infSpin.On[onKey] = on
			persist()
			if on and placeType ~= "menu" then notify("Inf Spin", "Only works in the main menu", "triangle-alert", "warning") end
		end })
		return dd
	end
	local ddE = category(InfPage, "Left", "Elements", "flame", "Elements", elementList, "ElemSlots", { "1", "2", "3", "4" }, "is_elem_on", "Element")
	local ddB = category(InfPage, "Right", "Bloodlines", "dna", "Bloodlines", bloodlineList, "BlSlots", { "1", "2", "3", "4" }, "is_bl_on", "Bloodline")
	local ddK = category(InfPage, "Left", "Kenjutsu", "sword", "Kenjutsu", kenjutsuList, "KenSlots", { "1", "2" }, "is_ken_on", "Kenjutsu", "Each spin costs 10 spins")
	local ddR = category(InfPage, "Right", "Race", "user-round", "Races", raceList, nil, nil, "is_race_on", "Race", "Costs RELL Coins, not reset")

	local Set = InfPage:Card({ Title = "Settings", Icon = "settings-2", Wide = "Bottom" })
	Set:Slider({ Title = "Reset when spins reach", Desc = "Rolls back the save and rejoins when spins drop to this", Flag = "is_reset", Min = 0, Max = 100,
		Default = infSpin.ResetAt, Callback = function(v) infSpin.ResetAt = v persist() end })
	Set:Slider({ Title = "Spin delay", Flag = "is_delay", Min = 0.1, Max = 2, Step = 0.05, Default = infSpin.Delay, Suffix = " s",
		Callback = function(v) infSpin.Delay = v persist() end })
	Set:Toggle({ Title = "Save when done", Desc = "Saves and goes to My Home when you get what you want", Flag = "is_autosave", Default = infSpin.AutoSave,
		Callback = function(v) infSpin.AutoSave = v persist() end })
	local row = Set:Row()
	row:Button({ Title = "Refresh lists", Icon = "refresh-cw", Callback = function()
		elementList, bloodlineList, kenjutsuList, raceList = lists()
		ddE:SetItems(orDash(elementList), true) ddB:SetItems(orDash(bloodlineList), true) ddK:SetItems(orDash(kenjutsuList), true) ddR:SetItems(orDash(raceList), true)
	end })
	row:Button({ Title = "Reset spins", Icon = "rotate-ccw", Confirm = "Sure?", Callback = resetAndRejoin })
	row:Button({ Title = "Save spins", Icon = "save", Style = "Soft", Confirm = "Sure?", Callback = saveAndLeave })
	if (infSpin.On.Element or infSpin.On.Bloodline or infSpin.On.Kenjutsu) and placeType == "menu" then queueHub() end
	-- Do not let the settings profile (AutoLoad) turn Inf Spin off: restore the json state after a rejoin
	hub.AfterAutoLoad = hub.AfterAutoLoad or {}
	hub.AfterAutoLoad[#hub.AfterAutoLoad + 1] = function()
		if type(fromFile) ~= "table" then return end
		local function put(flag, v) if v ~= nil then Window:SetFlag(flag, v) end end
		put("is_elem_on_list", fromFile.Elements) put("is_bl_on_list", fromFile.Bloodlines)
		put("is_ken_on_list", fromFile.Kenjutsu) put("is_race_on_list", fromFile.Races)
		put("is_elem_on_slots", fromFile.ElemSlots) put("is_bl_on_slots", fromFile.BlSlots) put("is_ken_on_slots", fromFile.KenSlots)
		put("is_reset", fromFile.ResetAt) put("is_delay", fromFile.Delay) put("is_autosave", fromFile.AutoSave)
		local on = type(fromFile.On) == "table" and fromFile.On or {}
		for _, c in ipairs(categories) do put(c.flag, on[c.on] == true) end
	end

	----- Auto Spin RELL -----
	-- Auto Spin RELL now loads from its own raw link (not embedded in this script) and reloads itself from that link after a rejoin
	local rellLink = "https://raw.githubusercontent.com/79650/dg3b2352313124scjd3124sanhgcdsahncdas457hs1amgdcankjcj/refs/heads/main/rellauto"
	local function openRell()
		if env.RELL_RUNNING then return true end
		if env.RELLOpening then return false end
		for _, c in ipairs(categories) do
			if infSpin.On[c.on] then
				notify("Auto Spin RELL", "Stop Inf Spin first", "triangle-alert", "warning")
				return false
			end
		end
		queuePermission(rellStopFile, not env.RELL_NOQUEUE)
		env.RELLOpening = true
		env.RELL_BOOT_CANCEL = false
		local okGet, src = pcall(function() return game:HttpGet(rellLink, true) end)
		if not hub.Running or env.RELL_BOOT_CANCEL then
			env.RELLOpening = false
			return false
		end
		local fn = okGet and type(src) == "string" and loadstring(src)
		if not fn then
			env.RELLOpening = false
			notify("Auto Spin RELL", "Couldn't download the script (raw link)", "triangle-alert", "danger")
			return false
		end
		task.spawn(function()                                  -- it waits for the menu to load while opening: do not lock the button
			local ok, err = pcall(fn)
			if not ok then warn("Auto Spin RELL:", err) if env.RELLStop then pcall(env.RELLStop) end end
		end)
		for _ = 1, 40 do                                        -- wait up to ~20 s for it to start running
			if env.RELL_RUNNING or env.RELL_BOOT_CANCEL then break end
			task.wait(0.5)
		end
		env.RELLOpening = false
		return env.RELL_RUNNING == true
	end
	hub.Cleanup[#hub.Cleanup + 1] = function()
		env.RELL_BOOT_CANCEL = true
		if env.RELLStop then env.RELLStop() end
	end
	local RellCard = RellPage:Card({ Title = "Auto Spin RELL", Icon = "dices", Desc = "Spins bloodlines until you get RELL" })
	RellCard:Button({ Title = "Open Auto Spin RELL", Icon = "app-window", Style = "Primary", Callback = function()
		if placeType ~= "menu" then
			return notify("Auto Spin RELL", "Only works in the main menu (now: " .. placeName() .. ")", "triangle-alert", "warning")
		end
		if openRell() then Window:SetModule("Auto Spin RELL", "On", nil, { Icon = "dices", Tab = "Spin" }) end
	end })
	RellCard:Slider({ Title = "Spin delay", Flag = "rell_delay", Min = 0.3, Max = 3, Step = 0.1, Default = 1, Suffix = " s",
		Callback = function(v) env.RELL_DELAY = v end })
	RellCard:Toggle({ Title = "Re-run after rejoin", Desc = "Continues automatically with queue_on_teleport", Flag = "rell_queue", Default = true,
		Callback = function(on)
			env.RELL_NOQUEUE = not on
			queuePermission(rellStopFile, on and env.RELL_RUNNING == true)
			if on and env.RELL_RUNNING and env.RELLQueue then env.RELLQueue() end
		end })
	RellCard:Button({ Title = "Stop", Icon = "circle-stop", Style = "Danger", Callback = function()
		env.RELL_BOOT_CANCEL = true
		if env.RELLStop then env.RELLStop() end
		queuePermission(rellStopFile, false)
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
	Window:SetModule("Auto Spin RELL", env.RELL_RUNNING and "On" or "Off", nil, { Icon = "dices", Tab = "Spin" })
end

----- Player: Shindo -----
do
	local playerTab = playerPage                                      -- Game · NPC kill aura · Scroll snipe, with Misc / Spectate below
	local shindo = { NoCombat = false, Unbreak = false, Aura = false, Scroll = false, ScrollSpawn = true }

	-- one card with two sections: Defense (immortal, unbreakable, combat) and Utility (kill aura, scroll snipe, anti-AFK)
	local Game = playerTab:Card({ Title = "Player", Icon = "user", Side = "Left" })
	Game:Divider({ Title = "Defense" })
	Game:Toggle({ Title = "Disable in combat", Desc = "Teleport / leave even while in combat", Flag = "sh_nocombat", Default = false, Callback = function(v) shindo.NoCombat = v end })
	Game:Toggle({ Title = "Immortal", Desc = "Get up instantly when knocked down (no knockdown)", Flag = "sh_immortal", Default = false,
		Callback = function(v) shindo.Immortal = v end })
	hubConnect(RunService.Heartbeat, function()
		if not shindo.Immortal then return end
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
	hub.Cleanup[#hub.Cleanup + 1] = restoreBlocks
	Game:Toggle({ Title = "Unbreakable blocks", Desc = "Block can't be broken", Flag = "sh_unbreak", Default = false, Callback = function(v)
		shindo.Unbreak = v
		if v then applyBlocks(character()) else restoreBlocks() end
	end })
	hubConnect(LocalPlayer.CharacterAdded, function(c)
		if not shindo.Unbreak then return end
		task.wait(2.5)
		if hub.Running and shindo.Unbreak and character() == c then applyBlocks(c) end
	end)
	hubConnect(RunService.Stepped, function()
		if shindo.NoCombat and LocalPlayer:FindFirstChild("incombat") then LocalPlayer.incombat.Value = false end
	end)

	local Aura = Game
	Aura:Divider({ Title = "Utility" })
	Aura:Toggle({ Title = "NPC Kill Aura", Flag = "sh_aura", Default = false, Callback = function(v) shindo.Aura = v end })
	-- Kill aura: hits only the current target. If the farm is attacking a mob it is that mob, otherwise the closest valid NPC.
	-- The target's "antiexploit" is removed and its health is set to its negative, as NukePlat does (Health = -Health, 5 times; client side).
	-- Runs when either Player > NPC kill aura or Farm > Configurations is on.
	local function isValidNPC(npc)
		if not npc:IsA("Model") then return false end
		local head = npc:FindFirstChild("Head")
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		local root = npc:FindFirstChild("HumanoidRootPart")
		return head and head:IsA("BasePart") and humanoid and root and root:IsA("BasePart")
			and npc:FindFirstChild("npctype")
			and npc.Name:lower():find("npc")
			and head.Position.Y > -1000
			and humanoid.Health > 0
	end
	local function auraTarget(r, folder)
		local t = hub.AuraTarget                                     -- the farm's target: kept until it dies on the server, even if its health already reads 0 locally
		if t and t.Parent == folder and t:FindFirstChild("Humanoid") and t:FindFirstChild("HumanoidRootPart") then return t end
		hub.AuraTarget = nil
		local best, bestD
		for _, npc in ipairs(folder:GetChildren()) do
			if isValidNPC(npc) then
				local d = (npc.HumanoidRootPart.Position - r.Position).Magnitude
				if not bestD or d < bestD then best, bestD = npc, d end
			end
		end
		return best
	end
	hubConnect(RunService.Heartbeat, function()
		if not (hub.Running and (shindo.Aura or hub.FarmAura)) then return end
		local r = rootPart()
		local folder = workspace:FindFirstChild("npc")
		if not (r and folder) then return end
		local npc = auraTarget(r, folder)
		if not npc then return end
		pcall(function()
			local ae = npc:FindFirstChild("antiexploit")
			if ae then ae:Remove() end
			npc.Humanoid.Health = -npc.Humanoid.Health
			npc.Humanoid.Health = -npc.Humanoid.Health
			npc.Humanoid.Health = -npc.Humanoid.Health
			npc.Humanoid.Health = -npc.Humanoid.Health
			npc.Humanoid.Health = -npc.Humanoid.Health
		end)
	end)

	local Scroll = Game
	Scroll:Toggle({ Title = "Scroll snipe", Desc = "Grabs scrolls that spawn on the map", Flag = "sh_scroll", Default = false, Callback = function(v) shindo.Scroll = v end })
	Scroll:Toggle({ Title = "Teleport to spawn after", Flag = "sh_scrollspawn", Default = true, Callback = function(v) shindo.ScrollSpawn = v end })
	Game:Toggle({ Title = "Anti-AFK", Desc = "Prevents the 20 minute idle kick", Flag = "p_antiafk", Default = true, Callback = function(v) settings.AntiAfk = v end })
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
		if not shindo.Scroll or hub.FarmBusy or inMission() then return end
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
						hub.ScrollBusy = true
						local ok, err = pcall(function()
							for _ = 1, 12 do
								if not hub.Running or not shindo.Scroll or inMission() then return end
								if hasScroll(v.Name) then
									ignored[v] = true
									notify("Scroll snipe", v.Name .. " collected", "scroll", "success")
									if shindo.ScrollSpawn then toSpawn() end
									return
								end
								task.wait(0.15)
							end
							retryAfter[v] = os.clock() + 3
							if hub.Running and shindo.Scroll and shindo.ScrollSpawn and not inMission() then toSpawn() end
						end)
						hub.ScrollBusy = false
						if not ok then error(err, 0) end
						return
					end
				end
			end
		end
	end)
	-- Misc and Spectate were created first; move them to the end so the Shindo cards appear on top
	for i, card in ipairs(hub.PlayerLateCards or {}) do
		pcall(function() card.frame.LayoutOrder = 1000 + i end)
	end
end

----- Teleport -----
local teleportData = {
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
	-- Only what exists on the current map is shown: the Locations card needs saved spots for this place,
	-- and each quick spot appears once its target is found (rechecked every few seconds, parts can stream in late).
	-- a teleport made from this page remembers where you stood, so Quick › Back can return there
	local function teleportFromPage(target)
		local r = rootPart()
		if r then hub.TeleportBack = r.CFrame end
		tpTo(target)
		if hub.QuickTiles then hub.QuickTiles:SetTileVisible("Back", true) end
	end
	local here = teleportData[game.PlaceId] or {}
	local names, byName = {}, {}
	for _, p in ipairs(here) do names[#names + 1] = p[1] byName[p[1]] = p end
	if #names > 0 then
		-- a searchable list: four places show at once, the rest scroll; each row shows how far it is and has a Go button
		local places = teleportsPage:Card({ Title = "Locations", Icon = "map-pin", Desc = #names .. " places on this map" })
		local function distanceText(p)
			local r = rootPart()
			if not r then return nil end
			local d = (r.Position - Vector3.new(p[2], p[3], p[4])).Magnitude
			return d >= 1000 and string.format("%.1fk studs", d / 1000) or string.format("%d studs", math.floor(d + 0.5))
		end
		local items = {}
		for _, p in ipairs(here) do items[#items + 1] = { Title = p[1], Desc = distanceText(p), Icon = "map-pin" } end
		local placeList = places:ItemList({ Items = items, Button = "Go", Rows = 4, Placeholder = "Search " .. #names .. " places",
			Empty = "No place with that name", Callback = function(item)
				local p = byName[item.Title]
				if p then teleportFromPage(CFrame.new(p[2], p[3], p[4])) end
			end })
		loop("Teleport distances", 2, function()                    -- distances follow you around
			for _, p in ipairs(here) do placeList:SetDesc(p[1], distanceText(p)) end
		end)
	end

	-- each spot returns the CFrame to teleport to, or nil when it is not on this map
	local spots = {
		{ "Spawn", "house", function()
			local sp = workspace:FindFirstChild("SpawnLocation")
			return sp and sp.CFrame + Vector3.new(0, 3, 0)
		end },
		{ "Duel pads", "swords", function()
			local d = workspace:FindFirstChild("map2") and workspace.map2:FindFirstChild("duel")
			local pad = d and d:FindFirstChild("pad", true)
			if pad and not pad:IsA("BasePart") then pad = pad:FindFirstChildWhichIsA("BasePart", true) end
			return pad and pad.CFrame + Vector3.new(0, 3, 0)
		end },
		{ "Ramen", "soup", function()
			local r = workspace:FindFirstChild("EAT") and workspace.EAT:FindFirstChild("Ramen")
			local part = r and (r:IsA("BasePart") and r or r:FindFirstChildWhichIsA("BasePart", true))
			return part and part.CFrame + Vector3.new(0, 3, 0)
		end },
		{ "Mentor", "graduation-cap", function()
			local s = workspace:FindFirstChild("sensei")
			local g = s and s:FindFirstChild("missions") and s.missions:GetChildren()[1]
			local hrp = g and g:FindFirstChild("missiongiver") and g.missiongiver:FindFirstChild("HumanoidRootPart")
			if hrp then return hrp.CFrame + Vector3.new(0, 0, 4) end
			local ken = workspace:FindFirstChild("Ken Mentor")
			return ken and ken:FindFirstChild("HumanoidRootPart") and ken.HumanoidRootPart.CFrame + Vector3.new(-6, 4, 0)
		end },
		{ "Susanoo", "sparkles", function()
			local s = workspace:FindFirstChild("Susanoo Customizer")
			local part = s and (s:FindFirstChild("HumanoidRootPart") or s:FindFirstChildWhichIsA("BasePart", true))
			return part and part.CFrame + Vector3.new(0, 3, 4)
		end },
	}
	-- Quick: icon tiles, three to a row; a spot that is not on this map is hidden (rechecked every 5 s).
	-- Back returns to where you stood before the last teleport made from this page.
	local quick = teleportsPage:Card({ Title = "Quick", Icon = "zap", Side = "Right" })
	local items = {}
	for _, spot in ipairs(spots) do
		items[#items + 1] = { Title = spot[1], Icon = spot[2], Callback = function()
			local ok, target = pcall(spot[3])
			if ok and target then teleportFromPage(target) else notify("Teleport", spot[1] .. " is not on this map", "triangle-alert", "warning") end
		end }
	end
	items[#items + 1] = { Title = "Back", Icon = "rotate-ccw", Visible = false, Callback = function()
		if hub.TeleportBack then
			local back = hub.TeleportBack
			hub.TeleportBack = nil
			tpTo(back)
		end
	end }
	local quickTiles = quick:Tiles({ Columns = 3, Height = 52, Align = "Center", Items = items })
	hub.QuickTiles = quickTiles
	local function refreshSpots()
		for _, spot in ipairs(spots) do
			local ok, target = pcall(spot[3])
			quickTiles:SetTileVisible(spot[1], ok and target ~= nil)
		end
		quickTiles:SetTileVisible("Back", hub.TeleportBack ~= nil)
	end
	refreshSpots()
	loop("Teleport spots", 5, refreshSpots)

	-- AFK spots only exist in My Home
	if placeType == "home" then
		local afk = teleportsPage:Card({ Title = "AFK", Icon = "bed", Side = "Right" })
		local function apartment()
			local map = workspace:FindFirstChild("map")
			return map and map:FindFirstChild(LocalPlayer.Name .. "apartment")
		end
		for _, a in ipairs({ { "Bed", "afkreward", "bed" }, { "Ramen", "Ramen", "soup" } }) do
			afk:Button({ Title = a[1], Icon = a[3], Align = "Left", Callback = function()
				local ap = apartment()
				local part = ap and ap:FindFirstChild(a[2])
				if part then tpTo(part.CFrame) else notify("AFK", a[1] .. " not found", "triangle-alert", "warning") end
			end })
		end
		local seatRow = afk:Row({ Gap = 4 })
		for i = 1, 4 do
			seatRow:Button({ Title = "Seat " .. i, Size = "Small", Callback = function()
				local ap = apartment()
				local model = ap and ap:FindFirstChild("Model")
				local seats = {}
				if model then for _, s in ipairs(model:GetChildren()) do if s:IsA("Seat") then seats[#seats + 1] = s end end end
				if seats[i] then tpTo(seats[i].CFrame) else notify("AFK", "Seat " .. i .. " not found", "triangle-alert", "warning") end
			end })
		end
	end
end

----- Character colors -----
-- Hair / body / beard colour through the game's own remote: startevent:FireServer(part, "r,g,b") with values 0-1.
-- Rainbow cycles the hue on a timer; turning it off (or unloading) puts back the colours you had before.
do
	local partNames = { Hair = "haircolor", Body = "skin", Beard = "beardcolor" }
	local groups = { hair = { "haircolor", "beardcolor" }, body = { "skin" } }
	local rainbow = { hair = false, body = false, sync = true }
	local interval, hue = 1, 0
	local selected = "haircolor"
	local colors, animated, restore, started = {}, {}, {}, {}

	local function parseHex(text)
		text = type(text) == "string" and text:match("^%s*#?(%x%x%x%x%x%x)%s*$")
		return text and Color3.fromHex(text)
	end
	local function currentColor(part)                             -- the colour the game has saved for this part
		local s = statz()
		local character = s and s:FindFirstChild("character")
		local value = character and character:FindFirstChild(part)
		local v = value and value:IsA("ValueBase") and value.Value
		if typeof(v) == "Color3" then return v end
		if typeof(v) == "BrickColor" then return v.Color end
		if type(v) ~= "string" then return nil end
		local a, b, c = v:match("^%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$")
		a, b, c = tonumber(a), tonumber(b), tonumber(c)
		if a and b and c and a >= 0 and a <= 1 and b >= 0 and b <= 1 and c >= 0 and c <= 1 then return Color3.new(a, b, c) end
		return parseHex(v)
	end
	local function send(part, color)
		local remote = LocalPlayer:FindFirstChild("startevent")
		if not (remote and remote:IsA("RemoteEvent")) then return false end
		return pcall(function() remote:FireServer(part, ("%.9f,%.9f,%.9f"):format(color.R, color.G, color.B)) end)
	end
	local function groupOf(part) return part == "skin" and "body" or "hair" end
	local function restoreGroup(group)
		for _, part in ipairs(groups[group]) do
			if animated[part] and restore[part] then send(part, restore[part]) end
			restore[part], animated[part] = nil, nil
		end
	end

	local card = colorsPage:Card({ Title = "Character colors", Icon = "palette" })
	local picker
	card:Segment({ Title = "Part", Flag = "cc_part", Items = { "Hair", "Body", "Beard" }, Default = "Hair", Callback = function(v)
		selected = partNames[v] or "haircolor"
		colors[selected] = colors[selected] or currentColor(selected)
		if picker then picker:Set(animated[selected] or colors[selected] or Color3.new(1, 1, 1), true) end
	end })
	picker = card:ColorPicker({ Title = "Color", Default = currentColor(selected) or Color3.new(1, 1, 1), Callback = function(color)
		if not rainbow[groupOf(selected)] then colors[selected] = color end
	end })
	card:Button({ Title = "Apply", Icon = "check", Style = "Primary", Callback = function()
		if rainbow[groupOf(selected)] then
			return notify("Character colors", "Turn the rainbow off for this part first", "rainbow", "warning")
		end
		local color = colors[selected] or picker:Get()
		colors[selected] = color
		local label = selected == "skin" and "Body" or selected == "beardcolor" and "Beard" or "Hair"
		if send(selected, color) then notify("Character colors", label .. " color sent", "palette")
		else notify("Character colors", "Could not send the color", "triangle-alert", "warning") end
	end })

	local rb = colorsPage:Card({ Title = "Rainbow", Icon = "rainbow", Side = "Right" })
	local function rainbowToggle(title, group, flag, default)
		rb:Toggle({ Title = title, Flag = flag, Default = default, Callback = function(on)
			if group == "sync" then rainbow.sync = on return end
			if on == rainbow[group] then return end
			rainbow[group] = on
			if on then
				started[group] = os.clock()
				for _, part in ipairs(groups[group]) do restore[part] = currentColor(part) or false end   -- false: nothing to put back
			else
				restoreGroup(group)
			end
		end })
	end
	rainbowToggle("Hair / beard", "hair", "cc_rb_hair", false)
	rainbowToggle("Body", "body", "cc_rb_body", false)
	rainbowToggle("Sync", "sync", "cc_rb_sync", true)
	rb:Slider({ Title = "Interval", Flag = "cc_rb_interval", Min = 0.25, Max = 5, Step = 0.05, Default = 1, Suffix = " s",
		Callback = function(v) interval = v end })

	hub.Cleanup[#hub.Cleanup + 1] = function() restoreGroup("hair") restoreGroup("body") end
	task.spawn(function()
		while hub.Running do
			local dt = task.wait(interval)
			if not hub.Running then break end
			hue = (hue + dt * 0.18) % 1
			for group, parts in pairs(groups) do
				if rainbow[group] then
					local h = rainbow.sync and hue or ((os.clock() - (started[group] or 0)) * 0.18) % 1
					local color = Color3.fromHSV(h, 1, 1)
					for _, part in ipairs(parts) do
						if restore[part] ~= nil and send(part, color) then
							animated[part] = color
							if selected == part then picker:Set(color, true) end
						end
					end
				end
			end
		end
	end)
end

----- Loadout -----
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
----- Selection lists -----
local function childNames(folder)              -- lists show the game's original (code) names
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
	if alljutsu then                               -- the game's own markers: ELEMENT / KG
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
local emptyList = { "-" }
local function sourceOf(key, code)              -- object to read REALNAME from
	local aj = ReplicatedStorage:FindFirstChild("alljutsu")
	if not aj then return nil end
	if key == "kenjutsu" then local f = aj:FindFirstChild("ALLKENSTYLES") return f and f:FindFirstChild(code) end
	if key == "style" then local f = aj:FindFirstChild("FIGHTINGSTYLES") return f and f:FindFirstChild(code) end
	if key == "cloth" then return nil end
	return aj:FindFirstChild(code)
end
local function itemsOf(key)                    -- alphabetically sorted name list (the game's display names)
	local out = {}
	for code in pairs(Lists[key] or {}) do out[#out + 1] = labelFor(code, sourceOf(key, code)) end
	table.sort(out, function(a, b) return a:lower() < b:lower() end)
	return #out > 0 and out or emptyList
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

----- Loadout -----
local Loadout = Tabs.Loadout:Page("Changer", { Compact = true })

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

----- RC Shop -----
local Shop = Tabs.Loadout:Page("RC Shop", { Compact = true })
local ShopCard = Shop:Card({ Title = "Shop", Icon = "store" })
ShopCard:Button({ Title = "Show RC Shop", Icon = "eye", Toggle = true, OnTitle = "Hide RC Shop", OnIcon = "eye-off",   -- no Flag: the shop must not open by itself on startup
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

task.delay(4, function() if hub.Running then refreshLists(true) end end)    -- if the menu loads late, read the lists once more
end

----- Lock icon -----
-- While the setting it depends on is off, the row is greyed out; only a small lock is shown next to the title (no text).
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

----- Startup -----
Window:SettingsTab({ Compact = true })
Window.Config:LoadAutoLoad()
for _, fn in ipairs(hub.AfterAutoLoad or {}) do pcall(fn) end
Window:Notify({ Title = "Qustāh Shindo", Content = "Loaded · " .. placeName() .. " · RShift to toggle", Icon = "sparkles" })
