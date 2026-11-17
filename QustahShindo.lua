-- Qustāh · Shindo Life · V2.05

-- After a teleport the hub reloads itself from this raw link (queue_on_teleport)
local rawLink = "https://raw.githubusercontent.com/79650/jewvjs-s-savhas-sh-sahsvsjebebs-wneve/refs/heads/main/QustahShindo.lua"

local env = (getgenv and getgenv()) or _G
-- the code queued for teleports: always the latest hub from GitHub
local function reloadSource() return ("loadstring(game:HttpGet(%q, true))()"):format(rawLink) end

if game.GameId ~= 1511883870 then                               -- Shindo Life only
	warn("Qustāh Shindo: this game is not Shindo Life, script not loaded")
	return
end
repeat task.wait() until game:IsLoaded()

local function stopMentorBoss()
	local stop = env.QustahMentorBossStop
	if type(stop) == "function" then pcall(stop) end
	local prior = env.QustahMentorBoss
	env.QustahMentorBoss, env.QustahMentorBossStop = nil, nil
	if prior then pcall(function() prior:Disconnect() end) end
end
stopMentorBoss()
if env.QustahShindoCore and env.QustahShindoCore.Unload then
	pcall(env.QustahShindoCore.Unload)
end

----- Mentor boss (headless) -----
-- The 5th mentor task takes you to the training boss map (workspace.bossbattle). While Farm › Mentor › Auto mentor is
-- on (the file below exists), the hub opens there without its window: it only teleports above each NPC, sets its
-- health to its negative (as the kill aura does) and presses M1. When the boss dies the game sends you back, and the
-- hub queued for that teleport opens normally and carries on with the next mentor task.
local mentorAutoFile = "QustahShindoMentor.on"
local canReadMentor, autoMentor = false, false
if type(isfile) == "function" then canReadMentor, autoMentor = pcall(isfile, mentorAutoFile) end
if workspace:FindFirstChild("bossbattle") and canReadMentor and autoMentor then
	local player = game:GetService("Players").LocalPlayer
	local queueFn = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
	if queueFn then pcall(queueFn, reloadSource()) end
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Qustāh", Text = "Mentor boss: farming, the menu opens back on the map", Duration = 6 })
	end)
	local function bossTarget()
		local folder = workspace:FindFirstChild("npc")
		for _, v in ipairs(folder and folder:GetChildren() or {}) do
			local hum, root, head = v:FindFirstChild("Humanoid"), v:FindFirstChild("HumanoidRootPart"), v:FindFirstChild("Head")
			if v:IsA("Model") and v:FindFirstChild("npctype") and string.find(v.Name, "npc") and hum and root and head
				and head.Position.Y > -1000 and hum.Health > 0 then
				return v
			end
		end
	end
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local target = root and bossTarget()
		if not target then return end
		local anti = target:FindFirstChild("antiexploit")
		if anti then pcall(function() anti:Destroy() end) end
		root.CFrame = target.HumanoidRootPart.CFrame * CFrame.new(0, 7, 0.3)
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - target.HumanoidRootPart.Position).Magnitude > 0.001 then
			camera.CFrame = CFrame.new(camera.CFrame.Position, target.HumanoidRootPart.Position)
		end
		pcall(function() target.Humanoid.Health = -target.Humanoid.Health end)
		local update = char:FindFirstChild("combat") and char.combat:FindFirstChild("update")
		if update then update:FireServer("mouse1", true) end
	end)
	env.QustahMentorBoss = connection
	env.QustahMentorBossStop = function()
		connection:Disconnect()
		if env.QustahMentorBoss == connection then env.QustahMentorBoss, env.QustahMentorBossStop = nil, nil end
	end
	return
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
	local code = reloadSource()
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
local function whenVisible(object, fn)
	if not object then return fn end
	local visible = false
	local function run(...)
		if hub.Running and visible then return fn(...) end
	end
	if Lib.Util.watchInView then
		hub.Cleanup[#hub.Cleanup + 1] = Lib.Util.watchInView(object, function(on)
			visible = on
			if on and hub.Running then
				local ok, err = pcall(fn)
				if not ok then hubError("Visible panel", err) end
			end
		end)
	else
		return function(...)
			if hub.Running and Lib.Util.inView(object) then return fn(...) end
		end
	end
	return run
end
local function notify(title, content, icon, color)
	if Window then Window:Notify({ Title = title, Content = content, Icon = icon or "bell", Color = color }) end
end
local function setValue(getter, value, label)
	local ok, err = pcall(function()
		local obj = getter()
		if not obj or not obj:IsA("ValueBase") then error("Value not found", 0) end
		obj.Value = value
	end)
	if ok then
		notify(label, tostring(value) .. " set", "check")
	else
		hubError(label, err)
		notify(label, "Could not set value (" .. placeName() .. ")", "triangle-alert", "warning")
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
	if Attack.Mode == "Legacy (M1 + E)" then                -- stay close, both M1 and E
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
	Version = "V2.05",
	Folder = "QustahShindo",
	Tags = { "SHINDO" },
	ToggleKey = Enum.KeyCode.RightShift,
	Size = Vector2.new(600, 440),
	PageTabs = "Header",                                          -- page names sit in the title row, like Dashboard / Settings
	AccentGlow = true,                                            -- (default settings: gg.json)
	ResetButtons = false,                                         -- no reset icons for now (an element can ask for one with Reset = true)
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
local floor, clamp = math.floor, math.clamp
local black, white = rgb(0, 0, 0), rgb(1, 1, 1)

----- Settings -----
local settings = {
    -- silent aim
    SA_Enabled = false, SA_HitChance = 100, SA_Part = "Head", SA_Priority = "Mouse",
    SA_InfRange = false,                                             -- Parvus-style ScreenPointToRay (see the hook)
    SA_VisCheck = false, SA_MaxDist = 1000,
    SA_Predict = false, SA_PredStrength = 100,
    -- fov
    FOV_Show = true, FOV_Radius = 120, FOV_Sides = 64, FOV_Thick = 1, FOV_Color = rgb(1, 1, 1), FOV_Alpha = 0,
    FOV_Filled = false, FOV_Origin = "Mouse", FOV_TargetLine = false,
    -- esp
    ESP_Enabled = true, ESP_MaxDist = 2500, PlayerLimit = 30, Pins = {},
    HealthBar = true, ModeBar = true,
    HealthPreset = "Ice", ModePreset = "Aurora", HealthBarStyle = "Smooth", ModeBarStyle = "Stripes",
    HealthBarOpacity = 1, ModeBarOpacity = 1,
    Name = true, User = true, HealthText = true, Distance = true, TextSize = 14,
    HealthSegments = 5, ModeText = false, ModeSegments = 1,
    Chams = true, ChamsFill = 0.65, ChamsOutlineAlpha = 0.35,
    ChamsColor = rgb(0, 0, 0), ChamsOutline = rgb(1, 1, 1),
    DistanceThrottle = false, OffscreenSleep = false,
    ColTarget = rgb(0.75, 0.45, 1),
    -- world
    Fullbright = false, NoFog = false, CustomTime = false, ClockTime = 14, NoShadows = false,
    CustomAmbient = false, Ambient = rgb(0.7, 0.7, 0.7),
    -- player
    NoClip = false, AntiAfk = true, ClickTP = false, UnlockZoom = false,
    -- server
    StaffAlert = false, StaffGroup = 0, StaffRank = 1, StaffAction = "Notify", AutoRejoin = false,
}
local function set(key) return function(v) settings[key] = v end end
----- Render: Drawing -----
-- Only the on-screen FOV and target line use Drawing; ESP uses BillboardGui.
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

----- Helpers -----
local function getCharacter(plr)
    local char = plr and plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return end
    return char, hum, root
end
----- Health -----
-- Measured in game: for your own character Humanoid.Health changes first (and alone reaches 0 when you die); for
-- other players the server's "fakehealth" value changes first, sometimes a frame earlier, and alone reaches 0 when
-- they die. So your health is read from the Humanoid and everyone else's from fakehealth (the Humanoid while it is
-- missing, e.g. just after a respawn). The maximum is Humanoid.MaxHealth; when the game leaves it below the current
-- health, the health itself is used so the bar never shows more than full.
local function healthValue(hum)
    local char = hum.Parent
    if char and char ~= LocalPlayer.Character then
        local fake = FindFirstChild(char, "fakehealth")
        local value = fake and fake:IsA("ValueBase") and tonumber(fake.Value)
        if value then return value end
    end
    return tonumber(hum.Health) or 0
end
local function healthMax(hum, health) return math.max(tonumber(hum.MaxHealth) or 1, health or 0, 1) end
local function isAlive(hum) return hum and healthValue(hum) > 0 end
-- Bar colour presets (Visuals › Style): three stops each, from empty through the middle to full. A preset's colour
-- at p (0..1) is read along its stops; the bars show the stops as a gradient (see esp.Gradient).
local function hex(h) return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)) end
local modePresets = {
    { "Ocean", hex("1d3fa8"), hex("3b82f6"), hex("67e8f9") },
    { "Aurora", hex("7c3aed"), hex("22d3ee"), hex("34d399") },
    { "Sunset", hex("9d2c8f"), hex("f43f5e"), hex("fdba74") },
    { "Toxic", hex("166534"), hex("22c55e"), hex("d9f99d") },
    { "Violet", hex("4c1d95"), hex("a855f7"), hex("f5b8ff") },
    { "Gold", hex("92400e"), hex("f59e0b"), hex("fde68a") },
}
local healthPresets = {
    { "Classic", hex("e5484d"), hex("f5a524"), hex("3dd68c") },
    { "Ice", hex("4f5bd5"), hex("3fa9f5"), hex("9ff3ff") },
    { "Mint", hex("0f766e"), hex("2dd4bf"), hex("d1fae5") },
    { "Ember", hex("7f1d1d"), hex("f05a28"), hex("ffd166") },
    { "Candy", hex("ff4d8d"), hex("c06cff"), hex("7cc8ff") },
    { "Mono", hex("3a3d45"), hex("8a8f9a"), hex("f4f5f7") },
}
for _, list in ipairs({ modePresets, healthPresets }) do
    for _, preset in ipairs(list) do list[preset[1]] = preset end
end
-- colour of a preset at p: along its stops (entries 2..n)
local function presetAt(preset, p)
    p = clamp(p or 1, 0, 1)
    local count = #preset - 1
    local scaled = p * (count - 1)
    local index = math.min(math.floor(scaled), count - 2)
    return preset[2 + index]:Lerp(preset[3 + index], scaled - index)
end
local function modeColorFor(mode)
    return presetAt(modePresets[settings.ModePreset] or modePresets.Ocean, mode)
end
local function toScreen(pos)
    local v, on = Camera:WorldToViewportPoint(pos)
    return vec2(v.X, v.Y), on, v.Z
end
-- health bar colour by the chosen preset (Visuals › Style › Health bar colors); "Classic" goes red → yellow → green
local function healthColor(p)
    return presetAt(healthPresets[settings.HealthPreset] or healthPresets.Classic, p)
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
local Silent = { Target = nil, Hooked = false }
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
    local origin = fovOrigin()
    local best, bestScore = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char, hum, root = getCharacter(plr)
            if char and isAlive(hum) then
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

local function installNamecallHook()
    if Silent.Hooked or not CanHook then return Silent.Hooked end
    local state = env.QustahShindoNamecallV1
    if not state then
        state = {}
        local wrapper = newcclosure(function(self, ...)
            local handler = state.handler
            if handler then
                local ray = handler(self)
                if ray then return ray end
            end
            return state.previous(self, ...)
        end)
        local ok, previous = pcall(hookmetamethod, game, "__namecall", wrapper)
        if not ok or type(previous) ~= "function" then
            hubError("Silent Aim __namecall", previous or "Hook did not return the original function")
            return false
        end
        state.previous = previous
        env.QustahShindoNamecallV1 = state
    end
    local function redirect(self)
        local target = Silent.Target
        if not (Running and settings.SA_Enabled and target and Camera and self == Camera) or checkcaller() then return end
        local method = getnamecallmethod()
        if (method ~= "ScreenPointToRay" and method ~= "ViewportPointToRay") or not roll() then return end
        local direction = target.Position - Camera.CFrame.Position
        if direction.Magnitude <= 0.001 then return end
        if settings.SA_InfRange then return Ray.new(target.Position, direction) end
        return Ray.new(Camera.CFrame.Position, direction.Unit)
    end
    state.handler = redirect
    Silent.Hooked = true
    hub.Cleanup[#hub.Cleanup + 1] = function()
        if state.handler == redirect then state.handler = nil end
        Silent.Hooked = false
    end
    return true
end

----- ESP -----
local esp = { Frame = 0 }

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
    if esp.DropPanel then esp.DropPanel(plr) end
    VisCache[plr] = nil
    RandomPick[plr] = nil
end

----- ESP (Qustah layout) -----
-- The ESP of Qustah (code revision 464), ported as it is: a BillboardGui (300 x 78, 3 studs above the head, always on
-- top) per player with, from the top, the mode bar ("MD" text on its right), the segmented health bar, the name with
-- the [username] in grey and the dodge cooldown icon, then "health / max" and "[distance studs]"; a Highlight for
-- the chams. Nearest players, Target pins, distance throttle and offscreen sleep work as there.
-- Our own additions stay on top: the health / mode colour presets and bar styles. Everything lives in the `esp` table (the main chunk is near Luau's 200 local limit).
esp.Panels = {}
esp.Colors = { back = Color3.fromRGB(18, 18, 18), split = Color3.fromRGB(8, 8, 8),
    red = Color3.fromRGB(195, 85, 85), green = Color3.fromRGB(115, 185, 130) }
esp.DodgeImage = "rbxassetid://11600642540"
-- 1234 → "1.23K", 999.6K → "1M" (as in revision 464)
function esp.Compact(number)
    number = math.max(tonumber(number) or 0, 0)
    local divisor, suffix = 1, ""
    if number >= 1e9 then divisor, suffix = 1e9, "B"
    elseif number >= 1e6 then divisor, suffix = 1e6, "M"
    elseif number >= 1e3 then divisor, suffix = 1e3, "K"
    else return tostring(math.floor(number + 0.5)) end
    local value = number / divisor
    if value >= 999.5 and divisor < 1e9 then
        divisor, suffix = divisor * 1e3, divisor == 1e3 and "M" or "B"
        value = number / divisor
    end
    local decimals = value < 10 and 2 or value < 100 and 1 or 0
    local text = string.format("%." .. decimals .. "f", value)
    if decimals > 0 then text = text:gsub("%.?0+$", "") end
    return text .. suffix
end
-- mode amount and its capacity: MaxValue (IntConstrainedValue) or a MaxValue / Max attribute; nil capacity = unknown
function esp.ModeInfo(char)
    local combat = FindFirstChild(char, "combat")
    local mode = combat and FindFirstChild(combat, "mode")
    if not (mode and mode:IsA("ValueBase")) then return nil end
    local value = tonumber(mode.Value)
    if not value then return nil end
    local capacity
    local okMax, maxValue = pcall(function() return mode.MaxValue end)
    if okMax and tonumber(maxValue) and maxValue > 0 then capacity = maxValue end
    if not capacity then
        local okAttr, attr = pcall(function() return mode:GetAttribute("MaxValue") or mode:GetAttribute("Max") end)
        if not okAttr then attr = nil end
        if type(attr) == "number" and attr > 0 and attr ~= math.huge then capacity = attr end
    end
    return value, capacity
end
-- Dodge: the player's key slot holding Taijutsu Body / Dodge, and its "cooldown" value (looked up every 2 s per player)
esp.DodgeCache = setmetatable({}, { __mode = "k" })
function esp.IsDodgeName(text)
    local name = tostring(text):lower():gsub("[%s_%-]", "")
    return name == "taijutsubody" or name == "taijutsudodge" or name == "taijutsubodydodge"
end
function esp.DodgeCooldown(plr)
    local now = os.clock()
    local cached = esp.DodgeCache[plr]
    if not cached or now - cached.t > 2 then
        local value
        local statz = FindFirstChild(plr, "statz")
        local keys = statz and FindFirstChild(statz, "keys")
        if keys then
            local best
            for _, v in ipairs(keys:GetDescendants()) do
                if v:IsA("StringValue") and v.Name ~= "cooldown" and esp.IsDodgeName(v.Value) then
                    local slot = v
                    while slot.Parent and slot.Parent ~= keys do slot = slot.Parent end
                    if slot.Parent == keys and (not best or slot.Name < best.Name) then best = slot end
                end
            end
            value = best and best:FindFirstChild("cooldown", true)
        end
        cached = { t = now, v = value }
        esp.DodgeCache[plr] = cached
    end
    local v = cached.v
    if not (v and v.Parent and v:IsA("ValueBase")) then return nil end
    return tonumber(v.Value)
end

-- where the billboards and highlights live: gethui() (hidden from the game) > CoreGui > PlayerGui
function esp.Root()
    if esp.Folder and esp.Folder.Parent then return esp.Folder end
    local parent
    local ok, hidden = pcall(function() return gethui and gethui() end)
    if ok and typeof(hidden) == "Instance" then parent = hidden end
    if not parent then
        local okCore = pcall(function()
            local test = Instance.new("Folder")
            test.Parent = game:GetService("CoreGui")
            test:Destroy()
        end)
        if okCore then parent = game:GetService("CoreGui") end
    end
    parent = parent or LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local folder = Instance.new("Folder")
    folder.Name = "QustahESP"
    folder.Parent = parent
    esp.Folder = folder
    return folder
end

function esp.New(class, parent, props)
    local object = Instance.new(class)
    for property, value in pairs(props) do object[property] = value end
    object.Parent = parent
    return object
end
-- The 300 x 78 block, built inside `parent` (the BillboardGui in game, a plain frame in the menu preview).
-- Returns the panel: its parts and the segment counts it was built with.
function esp.BuildPanel(parent)
    local segments = clamp(math.floor(settings.HealthSegments + 0.5), 1, 10)
    local modeSegments = clamp(math.floor(settings.ModeSegments + 0.5), 1, 10)
    local panel = { segments = segments, modeSegments = modeSegments, peak = 1 }
    local bar = esp.New("Frame", parent, { Name = "HealthBar", Size = UDim2.fromOffset(110, 8), Position = UDim2.new(0.5, -55, 0, 14),
        BackgroundColor3 = esp.Colors.back, BackgroundTransparency = 0.05, BorderSizePixel = 0, ClipsDescendants = true })
    bar:SetAttribute("Base", 0.05)
    esp.New("UICorner", bar, { CornerRadius = UDim.new(0, 3) })
    esp.New("UIStroke", bar, { Color = Color3.new(), Thickness = 1.25, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round })
    -- one fill with one gradient over the whole bar; the segments are only the dark divider lines on top
    panel.healthFill = esp.New("Frame", bar, { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, ClipsDescendants = true })
    esp.New("UICorner", panel.healthFill, { CornerRadius = UDim.new(0, 2) })
    panel.healthGradient = esp.New("UIGradient", panel.healthFill, { Name = "Gradient" })
    esp.Stripes(panel.healthFill, 110)
    for index = 1, segments - 1 do
        esp.New("Frame", bar, { Size = UDim2.fromOffset(1, 8), Position = UDim2.new(index / segments, 0, 0, 0), BackgroundColor3 = esp.Colors.split, BorderSizePixel = 0, ZIndex = 3 })
    end
    panel.bar = bar
    panel.name = esp.New("TextLabel", parent, { Name = "PlayerName", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 25), BackgroundTransparency = 1,
        RichText = true, TextColor3 = Color3.fromRGB(240, 240, 240), TextStrokeColor3 = Color3.new(), TextStrokeTransparency = 0.2,
        Font = Enum.Font.GothamBold, TextSize = 14, Text = "" })
    panel.health = esp.New("TextLabel", parent, { Name = "HealthText", Size = UDim2.fromOffset(127, 17), Position = UDim2.new(0.5, -127, 0, 47), BackgroundTransparency = 1,
        RichText = true, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(235, 235, 235), TextStrokeColor3 = Color3.new(),
        TextStrokeTransparency = 0.25, Font = Enum.Font.GothamBold, TextSize = 11, Text = "" })
    panel.distance = esp.New("TextLabel", parent, { Name = "Distance", Size = UDim2.fromOffset(127, 17), Position = UDim2.new(0.5, 3, 0, 47), BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 190, 190), TextStrokeColor3 = Color3.new(),
        TextStrokeTransparency = 0.25, Font = Enum.Font.GothamBold, TextSize = 11, Text = "[0 studs]" })
    local modeBar = esp.New("Frame", parent, { Name = "ModeBar", Size = UDim2.fromOffset(110, 8), Position = UDim2.new(0.5, -55, 0, 2),
        BackgroundColor3 = esp.Colors.back, BackgroundTransparency = 0.05, BorderSizePixel = 0, ClipsDescendants = true })
    esp.New("UICorner", modeBar, { CornerRadius = UDim.new(0, 3) })
    esp.New("UIStroke", modeBar, { Color = Color3.new(), Thickness = 1.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
    panel.modeFill = esp.New("Frame", modeBar, { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
    esp.New("UICorner", panel.modeFill, { CornerRadius = UDim.new(0, 2) })
    panel.modeGradient = esp.New("UIGradient", panel.modeFill, { Name = "Gradient" })
    panel.modeFill.ClipsDescendants = true
    esp.Stripes(panel.modeFill, 110)
    for index = 1, modeSegments - 1 do
        esp.New("Frame", modeBar, { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(index / modeSegments, 0), BackgroundColor3 = esp.Colors.split, BorderSizePixel = 0, ZIndex = 3 })
    end
    panel.modeBar = modeBar
    panel.modeLabel = esp.New("TextLabel", parent, { Name = "ModeAmount", Size = UDim2.fromOffset(100, 14), Position = UDim2.new(0.5, 61, 0, -1),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(190, 150, 230),
        TextStrokeColor3 = Color3.new(), TextStrokeTransparency = 0.25, Font = Enum.Font.GothamBold, TextSize = 10, Text = "", Visible = false })
    panel.dodgeIcon = esp.New("ImageLabel", parent, { Name = "Dodge", Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(270, 29),
        BackgroundTransparency = 1, Image = esp.DodgeImage, Visible = false })
    panel.dodgeLabel = esp.New("TextLabel", panel.dodgeIcon, { Size = UDim2.fromScale(1, 1), ZIndex = panel.dodgeIcon.ZIndex + 1, BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(235, 235, 235), TextStrokeTransparency = 0, Font = Enum.Font.GothamBold, TextSize = 15, Text = "", Visible = false })
    return panel
end
function esp.Escape(text) return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
-- The bars show the preset as a real gradient over their whole width (like its swatch): a fill that ends at
-- `to` shows the colours from `from` to `to` of the preset (sampled 5 times, so 3-colour presets come out right).
-- Bar styles (Visuals › Style): Smooth eases the gradient (the end colours stay longer, the middle passes quicker);
-- Stripes is the same with light diagonal stripes on top. Sampled 9 times so the eased curve comes out right.
function esp.Gradient(colorAt, from, to)
    local points = {}
    for i = 0, 8 do
        local p = from + (to - from) * i / 8
        points[#points + 1] = ColorSequenceKeypoint.new(i / 8, colorAt(p * p * (3 - 2 * p)))
    end
    return ColorSequence.new(points)
end
-- the stripes: a white frame over a fill (as wide as the full slot, so the stripes keep their spacing while the
-- fill shrinks; the fill clips it) whose transparency alternates every ~6 px, tilted by the gradient rotation
-- bar opacity (Visuals › Style): the bar's back, outline, fill, dividers and stripes together; texts are not touched.
-- A frame's own see-through amount at 100% is kept in its "Base" attribute (0 when unset: fill, dividers; the back
-- 0.05, the stripes 0.7, their holder 1), so one value scales them all.
function esp.Fade(frame, opacity)
    frame.BackgroundTransparency = 1 - opacity * (1 - (frame:GetAttribute("Base") or 0))
end
function esp.BarOpacity(bar, opacity)
    if bar:GetAttribute("Opacity") == opacity then return end
    bar:SetAttribute("Opacity", opacity)
    bar.BackgroundTransparency = 1 - opacity * 0.95
    for _, d in ipairs(bar:GetDescendants()) do
        if d:IsA("UIStroke") then d.Transparency = 1 - opacity
        elseif d:IsA("Frame") then esp.Fade(d, opacity) end
    end
end
-- Stripes: diagonal "/" lines every 6 px over the fill, each made of four 2 px steps (a rotated frame would not be
-- clipped by the fill, and a rotated gradient barely tilts on an 8 px tall bar). The holder is as wide as the bar, so
-- the stripes keep their place while the fill shrinks; it is filled the first time Stripes is chosen.
function esp.Stripes(fill, width)
    local holder = esp.New("Frame", fill, { Name = "Stripes", Size = UDim2.new(0, width, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true,
        BorderSizePixel = 0, ZIndex = 2, Visible = false })
    holder:SetAttribute("Base", 1)
    holder:SetAttribute("Width", width)
    return holder
end
function esp.StripeSequence(step)
    esp.StripeSequences = esp.StripeSequences or {}
    if esp.StripeSequences[step] then return esp.StripeSequences[step] end
    local phase = 3 - step
    local function marked(x) return (x - phase) % 6 < 3 end
    local function point(x, on) return NumberSequenceKeypoint.new(x / 24, on and 0 or 1) end
    local points = { point(0, marked(0)) }
    for x = 1, 24 do
        if marked(x - 1) ~= marked(x) then
            points[#points + 1] = point(x - 0.02, marked(x - 1))
            points[#points + 1] = point(x, marked(x))
        end
    end
    if points[#points].Time < 1 then points[#points + 1] = point(24, marked(24)) end
    local sequence = NumberSequence.new(points)
    esp.StripeSequences[step] = sequence
    return sequence
end
function esp.ShowStripes(holder, on, opacity)
    if on and not holder:GetAttribute("Built") then
        for step = 0, 3 do
            local sequence = esp.StripeSequence(step)
            for x = 0, holder:GetAttribute("Width") - 1, 24 do
                local line = esp.New("Frame", holder, { Position = UDim2.fromOffset(x, step * 2), Size = UDim2.fromOffset(24, 2),
                    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 })
                line:SetAttribute("Base", 0.7)
                esp.New("UIGradient", line, { Transparency = sequence })
                esp.Fade(line, opacity)
            end
        end
        holder:SetAttribute("Built", true)
    end
    esp.SetIf(holder, "Visible", on)
end
function esp.SetIf(object, property, value) if object[property] ~= value then object[property] = value end end
-- Fills the panel. info = { display, user, health (nil: unavailable or hidden), maxHealth, downed, mode, modeCap, distance, dodge }
function esp.UpdatePanel(panel, info)
    -- name: display name, [username] in grey
    esp.SetIf(panel.name, "Visible", settings.Name or settings.User)
    local nameText = settings.Name and esp.Escape(info.display) or ""
    if settings.User then nameText = nameText .. (settings.Name and " " or "") .. '<font color="#AFAFAF">[' .. esp.Escape(info.user) .. "]</font>" end
    esp.SetIf(panel.name, "Text", nameText)
    esp.SetIf(panel.name, "TextSize", settings.TextSize)
    esp.SetIf(panel.bar, "Visible", settings.HealthBar)
    esp.SetIf(panel.health, "Visible", settings.HealthText)
    if settings.HealthBar or settings.HealthText then
        local health = info.health and math.max(info.health, 0)
        local maximum = math.max(info.maxHealth or 1, 1)
        if settings.HealthBar then
            esp.ShowStripes(panel.healthFill.Stripes, settings.HealthBarStyle == "Stripes", settings.HealthBarOpacity)
            esp.BarOpacity(panel.bar, settings.HealthBarOpacity)
            local ratio = clamp((health or 0) / maximum, 0, 1)
            esp.SetIf(panel.healthFill, "Size", UDim2.fromScale(ratio, 1))
            local key = settings.HealthPreset .. "|" .. math.floor(ratio * 100 + 0.5)
            if ratio > 0 and panel.healthKey ~= key then
                panel.healthKey = key
                panel.healthGradient.Color = esp.Gradient(healthColor, 0, ratio)
            end
        end
        if settings.HealthText then
            local healthText = health and (esp.Compact(health) .. " / " .. esp.Compact(maximum)) or "--"
            esp.SetIf(panel.health, "Text", healthText .. (info.downed and " · Death" or ""))
        end
    end
    -- mode: the bar (relative to the highest value seen when the game gives no maximum) and "MD 50 / 100"
    local hasMode = settings.ModeBar and info.mode ~= nil
    esp.SetIf(panel.modeBar, "Visible", hasMode)
    esp.SetIf(panel.modeLabel, "Visible", hasMode and settings.ModeText)
    if hasMode then
        esp.ShowStripes(panel.modeFill.Stripes, settings.ModeBarStyle == "Stripes", settings.ModeBarOpacity)
        esp.BarOpacity(panel.modeBar, settings.ModeBarOpacity)
        local mode = info.mode
        panel.peak = math.max(panel.peak, mode)
        local ratio = clamp(mode / (info.modeCap or panel.peak), 0, 1)
        esp.SetIf(panel.modeFill, "Size", UDim2.fromScale(ratio, 1))
        -- the preset's gradient from empty up to the current amount (redone only when it changes)
        local key = settings.ModePreset .. "|" .. math.floor(ratio * 100 + 0.5)
        if panel.modeKey ~= key then
            panel.modeKey = key
            panel.modeGradient.Color = esp.Gradient(modeColorFor, 0, math.max(ratio, 0.001))
        end
        if settings.ModeText then
            esp.SetIf(panel.modeLabel, "TextColor3", modeColorFor(ratio))
            esp.SetIf(panel.modeLabel, "Text", "MD " .. esp.Compact(mode) .. (info.modeCap and (" / " .. esp.Compact(info.modeCap)) or " · relative"))
        end
    end
    -- dodge icon right after the name: the cooldown in red while it counts down
    local textWidth = tonumber(panel.name.TextBounds and panel.name.TextBounds.X) or 0
    local iconSize = settings.TextSize
    esp.SetIf(panel.dodgeIcon, "Size", UDim2.fromOffset(iconSize, iconSize))
    esp.SetIf(panel.dodgeIcon, "Position", UDim2.new(0.5, math.ceil(textWidth / 2) + 3, 0, 25 + (22 - iconSize) / 2))
    esp.SetIf(panel.dodgeLabel, "TextSize", math.max(8, math.floor(iconSize * 0.7 + 0.5)))
    local cooldown = info.dodge
    esp.SetIf(panel.dodgeIcon, "Visible", cooldown ~= nil and (settings.Name or settings.User))
    esp.SetIf(panel.dodgeLabel, "Visible", cooldown ~= nil and cooldown > 0)
    if cooldown then
        esp.SetIf(panel.dodgeLabel, "Text", cooldown > 0 and tostring(math.ceil(cooldown)) or "")
        esp.SetIf(panel.dodgeIcon, "ImageTransparency", cooldown > 0 and 0.25 or 0)
        esp.SetIf(panel.dodgeLabel, "TextColor3", cooldown > 0 and esp.Colors.red or esp.Colors.green)
    end
    -- health text and distance centred together under the name
    esp.SetIf(panel.distance, "Visible", settings.Distance)
    esp.SetIf(panel.distance, "Text", "[" .. esp.Compact(info.distance or 0) .. " studs]")
    local hpWidth = settings.HealthText and (tonumber(panel.health.TextBounds and panel.health.TextBounds.X) or 0) or 0
    local distanceWidth = settings.Distance and (tonumber(panel.distance.TextBounds and panel.distance.TextBounds.X) or 0) or 0
    local gap = (hpWidth > 0 and distanceWidth > 0) and 8 or 0
    local total = hpWidth + distanceWidth + gap
    esp.SetIf(panel.health, "Size", UDim2.fromOffset(math.max(hpWidth, 1), 17))
    esp.SetIf(panel.distance, "Size", UDim2.fromOffset(math.max(distanceWidth, 1), 17))
    esp.SetIf(panel.health, "Position", UDim2.new(0.5, -total / 2, 0, 47))
    esp.SetIf(panel.distance, "Position", UDim2.new(0.5, -total / 2 + hpWidth + gap, 0, 47))
end

-- one entry per player: the billboard on the head and the highlight on the character (rebuilt when the character,
-- its head or the segment counts change)
function esp.DropPanel(plr)
    local item = esp.Panels[plr]
    if not item then return end
    pcall(function() item.gui:Destroy() end)
    if item.highlight then item.highlight:Destroy() end
    esp.Panels[plr] = nil
end
function esp.PanelFor(plr, char, head)
    local item = esp.Panels[plr]
    if item and (item.char ~= char or item.head ~= head or not item.gui.Parent) then
        esp.DropPanel(plr)
        item = nil
    end
    if item then return item end
    local root = esp.Root()
    local gui = esp.New("BillboardGui", root, { Name = plr.Name, Adornee = head, Size = UDim2.fromOffset(300, 78), StudsOffset = Vector3.new(0, 3, 0),
        AlwaysOnTop = true, MaxDistance = settings.ESP_MaxDist, Enabled = false, ResetOnSpawn = false })
    item = { char = char, head = head, gui = gui, lastRefresh = 0 }
    esp.Panels[plr] = item
    return item
end
function esp.HidePanel(item)
    if item.gui.Parent then esp.SetIf(item.gui, "Enabled", false) end
    if item.highlight and item.highlight.Parent then esp.SetIf(item.highlight, "Enabled", false) end
end
-- ESP off (or no camera): the panels and highlights are removed, not kept hidden (Stripes alone are ~70 objects a
-- panel); they are built again as players come into view
function esp.DropAll()
    esp.Selection = nil
    for plr in pairs(esp.Panels) do esp.DropPanel(plr) end
end
esp.StyleKeys = { "Name", "User", "TextSize", "Distance", "HealthText", "HealthBar", "ModeBar", "ModeText",
    "HealthPreset", "ModePreset", "HealthBarStyle", "ModeBarStyle", "HealthBarOpacity", "ModeBarOpacity" }
function esp.SelectPlayers(camera, now, limit)
    local camPos = camera.CFrame.Position
    local candidates = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local head = char and char:FindFirstChild("Head")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if head and head:IsA("BasePart") and root and root:IsA("BasePart") and hum then
                local dist = (camPos - root.Position).Magnitude
                local pinned = settings.Pins[plr.UserId] == true
                if pinned or dist <= settings.ESP_MaxDist then
                    candidates[#candidates + 1] = { plr = plr, char = char, head = head, root = root, hum = hum, dist = dist, pinned = pinned }
                end
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.dist == b.dist then return a.plr.UserId < b.plr.UserId end
        return a.dist < b.dist
    end)
    local entries = {}
    local normal = 0
    for _, c in ipairs(candidates) do
        if c.pinned then
            entries[#entries + 1] = c
        elseif normal < limit then
            normal += 1
            entries[#entries + 1] = c
        end
    end
    return { entries = entries, refreshAt = now + 0.25, camera = camera,
        pins = settings.Pins, range = settings.ESP_MaxDist, limit = limit }
end
function esp.UpdatePanels()
    local camera = Workspace.CurrentCamera
    if not settings.ESP_Enabled or not camera then
        if esp.Selection or next(esp.Panels) then esp.DropAll() end
        return
    end
    local now = os.clock()
    local limit = clamp(math.floor(settings.PlayerLimit or 30), 5, 30)
    local selection = esp.Selection
    if not selection or now >= selection.refreshAt or selection.camera ~= camera
        or selection.limit ~= limit or selection.range ~= settings.ESP_MaxDist or selection.pins ~= settings.Pins then
        selection = esp.SelectPlayers(camera, now, limit)
        esp.Selection = selection
    end
    local selected, camPos = {}, camera.CFrame.Position
    esp.Style = esp.Style or {}
    for _, key in ipairs(esp.StyleKeys) do
        if esp.Style[key] ~= settings[key] then
            esp.Style[key] = settings[key]
            esp.StyleRevision = (esp.StyleRevision or 0) + 1
        end
    end
    for _, c in ipairs(selection.entries) do
        if c.plr.Parent and c.plr.Character == c.char and c.head.Parent == c.char
            and c.root.Parent == c.char and c.hum.Parent == c.char then
            c.dist = (camPos - c.root.Position).Magnitude
            if c.pinned or c.dist <= settings.ESP_MaxDist then
                selected[c.plr] = true
                local ok, err = pcall(esp.RefreshPanel, c, now, camera)
                if not ok then
                    local item = esp.Panels[c.plr]
                    if item then esp.HidePanel(item) end
                    hubError("ESP", err)
                end
            end
        end
    end
    for plr, item in pairs(esp.Panels) do
        if plr.Parent == nil or plr.Character ~= item.char or not item.head.Parent
            or (not selected[plr] and now - (item.lastSelected or 0) > 2) then
            esp.DropPanel(plr)
        elseif not selected[plr] then
            esp.HidePanel(item)
        end
    end
end
function esp.RefreshPanel(c, now, camera)
    -- Test the same camera-relative offset used by BillboardGui. Only the panel's data is throttled.
    local point, onScreen = camera:WorldToViewportPoint(c.head.Position + camera.CFrame.UpVector * 3)
    local visible = onScreen and point.Z > 0
    local chams = settings.Chams and (visible or not settings.OffscreenSleep)
    if not visible and not chams then
        local existing = esp.Panels[c.plr]
        if existing then esp.HidePanel(existing) end
        return
    end
    local item = esp.PanelFor(c.plr, c.char, c.head)
    item.lastSelected = now
    local wasVisible = item.gui.Enabled
    esp.SetIf(item.gui, "MaxDistance", c.pinned and 1e9 or settings.ESP_MaxDist)
    esp.SetIf(item.gui, "Enabled", visible)
    if chams and (not item.highlight or not item.highlight.Parent) then
        item.highlight = esp.New("Highlight", esp.Root(), { Name = c.plr.Name, Adornee = c.char,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false })
    end
    local h = item.highlight
    if h and h.Parent then
        esp.SetIf(h, "Enabled", chams)
        if chams then
            esp.SetIf(h, "FillColor", settings.ChamsColor)
            esp.SetIf(h, "OutlineColor", settings.ChamsOutline)
            esp.SetIf(h, "FillTransparency", settings.ChamsFill)
            esp.SetIf(h, "OutlineTransparency", settings.ChamsOutlineAlpha)
        end
    end
    if not visible then return end
    local panel = item.panel
    if not panel or panel.segments ~= clamp(math.floor(settings.HealthSegments + 0.5), 1, 10)
        or panel.modeSegments ~= clamp(math.floor(settings.ModeSegments + 0.5), 1, 10) then
        if item.content then item.content:Destroy() end
        item.content = esp.New("Frame", item.gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
        item.panel = esp.BuildPanel(item.content)
        wasVisible = false
    end
    if wasVisible and settings.DistanceThrottle and not c.pinned and c.dist > settings.ESP_MaxDist * 0.55
        and now - item.lastRefresh < 0.45 and item.styleRevision == esp.StyleRevision then return end
    item.lastRefresh, item.styleRevision = now, esp.StyleRevision
    local mode, modeCap
    if settings.ModeBar then mode, modeCap = esp.ModeInfo(c.char) end
    esp.UpdatePanel(item.panel, {
        display = c.plr.DisplayName, user = c.plr.Name,
        health = (settings.HealthBar or settings.HealthText) and healthValue(c.hum) or nil, maxHealth = healthMax(c.hum, healthValue(c.hum)),
        downed = c.char:FindFirstChild("stayonground") ~= nil,
        mode = mode, modeCap = modeCap, distance = c.dist, dodge = esp.DodgeCooldown(c.plr),
    })
end

function esp.DestroyPanels()
    for plr in pairs(esp.Panels) do esp.DropPanel(plr) end
    if esp.Folder then pcall(function() esp.Folder:Destroy() end) esp.Folder = nil end
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
local Atmospheres = { items = {} }
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
function Atmospheres.add(obj)
    if not obj:IsA("Atmosphere") or Atmospheres.items[obj] then return end
    local entry = { original = obj.Density }
    Atmospheres.items[obj] = entry
    local function suppress()
        if settings.NoFog and Atmospheres.items[obj] == entry and obj.Density ~= 0 then obj.Density = 0 end
    end
    entry.connection = obj:GetPropertyChangedSignal("Density"):Connect(suppress)
    suppress()
end
function Atmospheres.remove(obj)
    local entry = Atmospheres.items[obj]
    if not entry then return end
    Atmospheres.items[obj] = nil
    entry.connection:Disconnect()
    pcall(function() if obj.Density == 0 then obj.Density = entry.original end end)
end
local function fogDensity(on)
    if on and not Atmospheres.added then
        Atmospheres.added = Lighting.ChildAdded:Connect(Atmospheres.add)
        Atmospheres.removed = Lighting.ChildRemoved:Connect(Atmospheres.remove)
        for _, obj in ipairs(Lighting:GetChildren()) do Atmospheres.add(obj) end
    elseif not on and Atmospheres.added then
        Atmospheres.added:Disconnect()
        Atmospheres.removed:Disconnect()
        Atmospheres.added, Atmospheres.removed = nil, nil
        for obj in pairs(Atmospheres.items) do Atmospheres.remove(obj) end
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
local NoClip = { parts = {}, changed = {} }
function NoClip.restore(part)
    if NoClip.changed[part] then
        NoClip.changed[part] = nil
        pcall(function() part.CanCollide = true end)
    end
end
local function stopNoClip()
    if NoClip.added then NoClip.added:Disconnect() NoClip.removed:Disconnect() end
    NoClip.added, NoClip.removed, NoClip.character = nil, nil, nil
    for part in pairs(NoClip.changed) do NoClip.restore(part) end
    table.clear(NoClip.parts)
end
function NoClip.bind(char)
    stopNoClip()
    NoClip.character = char
    local function add(obj)
        if obj:IsA("BasePart") then NoClip.parts[obj] = true end
    end
    NoClip.added = char.DescendantAdded:Connect(add)
    NoClip.removed = char.DescendantRemoving:Connect(function(obj)
        NoClip.parts[obj] = nil
        NoClip.restore(obj)
    end)
    for _, obj in ipairs(char:GetDescendants()) do add(obj) end
end
local originalZoom
hub.Cleanup[#hub.Cleanup + 1] = function()
    if originalZoom then LocalPlayer.CameraMaxZoomDistance = originalZoom originalZoom = nil end
end

connect(RunService.Stepped, function()
    if not Running then return end
    local char = LocalPlayer.Character
    if settings.NoClip and char then
        if NoClip.character ~= char then NoClip.bind(char) end
        for part in pairs(NoClip.parts) do
            if part.CanCollide then
                NoClip.changed[part] = true
                part.CanCollide = false
            end
        end
    elseif NoClip.character then
        stopNoClip()
    end
end)

connect(RunService.Heartbeat, function()
    if not Running then return end
    if originalZoom and not settings.UnlockZoom then
        LocalPlayer.CameraMaxZoomDistance = originalZoom
        originalZoom = nil
    elseif settings.UnlockZoom then
        originalZoom = originalZoom or LocalPlayer.CameraMaxZoomDistance
        if LocalPlayer.CameraMaxZoomDistance ~= 1e4 then LocalPlayer.CameraMaxZoomDistance = 1e4 end
    end
end)

connect(UserInputService.InputBegan, function(input, processed)
    if processed or not (Running and settings.ClickTP) then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local _, _, root = getCharacter(LocalPlayer)
        local hit = Mouse.Hit
        if root and hit then root.CFrame = cframe(hit.Position + vec3(0, 3, 0)) * (root.CFrame - root.CFrame.Position) end
    end
end)

----- Anti-AFK -----
do
-- With getconnections the game's idle handlers are switched off, so the 20 minute kick never fires and no input is sent.
-- Without it, a fake right click answers the Idled event instead.
local disabledIdle = {}
local fallbackIdle
local function releaseIdle()
    if fallbackIdle then fallbackIdle:Disconnect() fallbackIdle = nil end
    for _, c in ipairs(disabledIdle) do pcall(function() c:Enable() end) end
    table.clear(disabledIdle)
end
local function applyAntiAfk()
    if not (Running and settings.AntiAfk) then releaseIdle() return end
    if fallbackIdle or #disabledIdle > 0 then return end
    if type(getconnections) == "function" then
        local ok, links = pcall(getconnections, LocalPlayer.Idled)
        if ok and type(links) == "table" then
            for _, c in ipairs(links) do
                pcall(function()
                    -- If the executor cannot report the prior state, leave it alone.
                    if c.Enabled == true and type(c.Enable) == "function" and type(c.Disable) == "function" then
                        c:Disable()
                        disabledIdle[#disabledIdle + 1] = c
                    end
                end)
            end
        end
    end
    if #disabledIdle == 0 then
        fallbackIdle = LocalPlayer.Idled:Connect(function()
            if not (Running and settings.AntiAfk) then return end
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.zero)
            end)
        end)
    end
end
hub.SetAntiAfk = function(v) settings.AntiAfk = v applyAntiAfk() end
applyAntiAfk()
hub.Cleanup[#hub.Cleanup + 1] = releaseIdle
end

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
local hopBusy = false
local function serverHop(mode)
    if not Running or hopBusy then return end
    hopBusy = true
    local ok, err = pcall(function()
        local list = fetchServers()
        if not Running then return end
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
        if Running then TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, LocalPlayer) end
    end)
    -- Coalesce staff checks that finish just after the first request.
    task.delay(ok and 3 or 0, function() hopBusy = false end)
    if not ok then hubError("Server hop", err) end
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
    local active = settings.SA_Enabled and CanHook and installNamecallHook()
    local limited = not CanHook or settings.SA_Enabled and not active
    Window:SetModule("Silent Aim", limited and "Limited" or (active and "On" or "Off"),
        limited and "Hook unavailable" or nil, { Icon = "target", Tab = "Combat" })
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
Aim:Toggle({ Title = "Inf range", Desc = "Hits the target at any distance (Parvus method)", Flag = "sa_infrange", Default = false,
    DependsOn = { Flag = "sa_enabled", Mode = "Hide", Reason = "" }, Callback = set("SA_InfRange") })

local Checks = Combat:Card({ Title = "Checks", Icon = "shield-check", Side = "Left" })
Checks:Toggle({ Title = "Visibility check", Desc = "Don't target players behind walls", Flag = "sa_vischeck", Default = false, Callback = set("SA_VisCheck") })
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
local StylePage = Visuals:Page("Style")

-- Card tabs: ESP (Range / Performance), Elements (Text / Health / Mode) on the left; Preview and Chams (Fill / Outline)
-- on the right; Target pins below.
local General = EspPage:Card({ Title = "ESP", Icon = "scan-eye", Side = "Left" })
General:Toggle({ Title = "ESP enabled", Flag = "esp_enabled", Default = true, Bindable = true,
    Callback = function(on)
        settings.ESP_Enabled = on
        Window:SetModule("ESP", on and "On" or "Off", nil, { Icon = "eye", Tab = "Visuals" })
    end })
local EspTabs = General:Tabs({ "Range", "Performance" })
EspTabs.Range:Slider({ Title = "Range", Flag = "esp_maxdist", Min = 100, Max = 5000, Default = 2500, Step = 50, Suffix = " studs", Callback = set("ESP_MaxDist") })
EspTabs.Range:Slider({ Title = "Nearest players", Desc = "Closest unpinned players; pins are extra", Flag = "esp_limit", Min = 5, Max = 30, Default = 30, Callback = set("PlayerLimit") })
EspTabs.Performance:Toggle({ Title = "Distance throttle", Desc = "Far ESP updates less often", Flag = "esp_throttle", Default = false, Callback = set("DistanceThrottle") })
EspTabs.Performance:Toggle({ Title = "Offscreen sleep", Desc = "Pauses ESP outside the screen", Flag = "esp_sleep", Default = false, Callback = set("OffscreenSleep") })

-- player info, health and mode: the overhead block (see "ESP overhead")
local ElementTabs = EspPage:Card({ Title = "Elements", Icon = "layers", Side = "Left" }):Tabs({ "Text", "Health", "Mode" })
do
local InfoCard = ElementTabs.Text
InfoCard:Toggle({ Title = "Name", Desc = "The player's visible name", Flag = "esp_name", Default = true, Callback = set("Name") })
InfoCard:Toggle({ Title = "Username", Desc = "The account name, in grey", Flag = "esp_user", Default = true, Callback = set("User") })
InfoCard:Toggle({ Title = "Distance", Flag = "esp_dist", Default = true, Callback = set("Distance") })
InfoCard:Slider({ Title = "Name text size", Flag = "esp_tsize", Min = 10, Max = 20, Default = 14, Suffix = " px", Callback = set("TextSize") })

local HealthCard = ElementTabs.Health
HealthCard:Toggle({ Title = "Health bar", Desc = "Segmented health indicator", Flag = "esp_hbar", Default = true, Callback = set("HealthBar") })
HealthCard:Toggle({ Title = "Health text", Desc = "Current / maximum health", Flag = "esp_hptext", Default = true, Callback = set("HealthText") })
HealthCard:Slider({ Title = "Health bar segments", Flag = "esp_hpseg", Min = 1, Max = 10, Default = 5, DependsOn = { Flag = "esp_hbar", Reason = "" }, Callback = set("HealthSegments") })
end

----- ESP live preview -----
-- The overhead panel exactly as the in-game BillboardGui shows it (esp.BuildPanel / UpdatePanel), on a soft blurred
-- colour background; no character. Values are your real ones (Humanoid health, combat.mode, your dodge cooldown) and
-- follow the settings at once. Drawn in the menu, so this part is GUI.
local PreviewCard = EspPage:Card({ Title = "Preview", Icon = "scan-eye", Side = "Right" })
local espCanvas = PreviewCard:Canvas({ Height = 170 })
do
    local holder = espCanvas.Frame
    if holder then
        holder.ClipsDescendants = true
        -- background: a dark gradient with a few large, very soft colour blobs (a blurred look)
        local back = Instance.new("Frame")
        back.Name, back.Size, back.BorderSizePixel, back.BackgroundColor3 = "Backdrop", UDim2.fromScale(1, 1), 0, Color3.new(1, 1, 1)
        local tint = Instance.new("UIGradient")
        tint.Color = ColorSequence.new(Color3.fromRGB(28, 30, 52), Color3.fromRGB(18, 38, 44))
        tint.Rotation = 20
        tint.Parent = back
        back.Parent = holder
        for _, blob in ipairs({
            { 0.18, 0.30, 170, Color3.fromRGB(96, 70, 190) }, { 0.80, 0.25, 150, Color3.fromRGB(40, 140, 170) },
            { 0.55, 0.95, 190, Color3.fromRGB(190, 70, 120) }, { 0.05, 1.00, 120, Color3.fromRGB(40, 120, 90) },
        }) do
            local glow = Instance.new("Frame")
            glow.AnchorPoint, glow.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(blob[1], blob[2])
            glow.Size, glow.BorderSizePixel, glow.BackgroundColor3 = UDim2.fromOffset(blob[3], blob[3]), 0, blob[4]
            local round = Instance.new("UICorner")
            round.CornerRadius = UDim.new(1, 0)
            round.Parent = glow
            local fade = Instance.new("UIGradient")                     -- bright centre fading out to nothing: the blur
            fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 1) })
            fade.Parent = glow
            glow.Parent = back
        end
    end
    ----- Preview controls -----
    -- Two capsules along the bottom of the preview (HP, MD): the six colour presets as gradient dots, a Smooth / Stripes
    -- switch and the bar opacity (scroll on it, or click for 100 / 75 / 50 / 25 %; the page does not scroll meanwhile).
    -- They set the same flags as Visuals › Style, so both stay in step; refreshControls() follows the settings when they
    -- change elsewhere. A capsule dims and ignores clicks while its bar is off; hovering a control shows its name.
    local refreshControls = function() end
    if holder then
        local controls = Instance.new("Frame")
        controls.Name, controls.BackgroundTransparency, controls.ZIndex = "Controls", 1, 8
        controls.AnchorPoint, controls.Position, controls.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -7), UDim2.fromOffset(240, 48)
        controls.Parent = holder
        local list = Instance.new("UIListLayout")
        list.Padding, list.HorizontalAlignment, list.SortOrder = UDim.new(0, 4), Enum.HorizontalAlignment.Center, Enum.SortOrder.LayoutOrder
        list.Parent = controls
        local function make(class, parent, props)
            local object = Instance.new(class)
            for key, value in pairs(props) do object[key] = value end
            object.Parent = parent
            return object
        end
        local function round(object, radius) make("UICorner", object, { CornerRadius = UDim.new(0, radius) }) end
        local function tip(button, text)
            button.MouseEnter:Connect(function() if Window._tip then pcall(Window._tip, Window, text) end end)
            button.MouseLeave:Connect(function() if Window._hideTip then pcall(Window._hideTip, Window) end end)
        end
        local function capsule(order, label, presets, keys)
            local dimmable = {}                                  -- { object, property, normal } faded while the bar is off
            local frame = make("Frame", controls, { Name = label, LayoutOrder = order, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22),
                BackgroundColor3 = Color3.fromRGB(11, 12, 16), BackgroundTransparency = 0.22, BorderSizePixel = 0, ZIndex = 8 })
            round(frame, 11)
            make("UIStroke", frame, { Color = Color3.new(1, 1, 1), Transparency = 0.92, Thickness = 1 })
            make("UIPadding", frame, { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 7) })
            make("UIListLayout", frame, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })
            local title = make("TextLabel", frame, { LayoutOrder = 1, Size = UDim2.fromOffset(16, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 9,
                TextColor3 = Color3.fromRGB(154, 158, 168), Text = label, ZIndex = 9 })
            dimmable[#dimmable + 1] = { title, "TextTransparency", 0 }
            local function usable() return settings[keys.barSetting] ~= false end
            -- colours
            local rings = {}
            local dots = make("Frame", frame, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), BackgroundTransparency = 1 })
            make("UIListLayout", dots, { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 2) })
            for index, preset in ipairs(presets) do
                local name = preset[1]
                local button = make("TextButton", dots, { Name = name, LayoutOrder = index, Size = UDim2.fromOffset(15, 15), BackgroundTransparency = 1, Text = "",
                    AutoButtonColor = false, ZIndex = 9 })
                local ring = make("Frame", button, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 9 })
                round(ring, 8)
                rings[name] = make("UIStroke", ring, { Color = Color3.fromRGB(238, 240, 244), Thickness = 1.5, Transparency = 1 })
                local dot = make("Frame", button, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(9, 9),
                    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 10 })
                round(dot, 5)
                dimmable[#dimmable + 1] = { dot, "BackgroundTransparency", 0 }
                button.MouseEnter:Connect(function() if usable() then dot.Size = UDim2.fromOffset(11, 11) end end)
                button.MouseLeave:Connect(function() dot.Size = UDim2.fromOffset(9, 9) end)
                tip(button, name)
                local points = {}
                for i = 2, #preset do points[#points + 1] = ColorSequenceKeypoint.new((i - 2) / (#preset - 2), preset[i]) end
                make("UIGradient", dot, { Color = ColorSequence.new(points), Rotation = 35 })
                button.Activated:Connect(function() if usable() then Window:SetFlag(keys.colors, name) end end)
            end
            -- Smooth / Stripes: a plain bar and a striped bar
            local switch = make("Frame", frame, { LayoutOrder = 3, Size = UDim2.fromOffset(43, 17), BackgroundColor3 = Color3.fromRGB(11, 12, 16), BorderSizePixel = 0, ZIndex = 9 })
            round(switch, 8)
            local options = {}
            for index, style in ipairs({ "Smooth", "Stripes" }) do
                local button = make("TextButton", switch, { Name = style, Position = UDim2.fromOffset(1 + (index - 1) * 21, 1), Size = UDim2.fromOffset(20, 15),
                    BackgroundColor3 = Color3.fromRGB(42, 44, 52), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 9 })
                round(button, 7)
                local icon = make("Frame", button, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(11, 5),
                    BackgroundColor3 = Color3.fromRGB(207, 211, 220), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 10 })
                round(icon, 2)
                if style == "Stripes" then
                    icon.BackgroundColor3 = Color3.fromRGB(92, 97, 108)
                    for i = 0, 3 do
                        make("Frame", icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(i * 4, 2.5), Size = UDim2.fromOffset(2, 10), Rotation = 35,
                            BackgroundColor3 = Color3.fromRGB(207, 211, 220), BorderSizePixel = 0, ZIndex = 11 })
                    end
                end
                options[style] = { button = button, icon = icon }
                tip(button, style)
                button.Activated:Connect(function() if usable() then Window:SetFlag(keys.style, style) end end)
            end
            -- opacity: scroll to change by 5 %, click for the next of 100 / 75 / 50 / 25 %
            local opacity = make("TextButton", frame, { LayoutOrder = 4, Size = UDim2.fromOffset(28, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
                TextSize = 9, TextColor3 = Color3.fromRGB(154, 158, 168), Text = "100%", AutoButtonColor = false, ZIndex = 9 })
            dimmable[#dimmable + 1] = { opacity, "TextTransparency", 0 }
            tip(opacity, "Opacity · scroll or click")
            local function setOpacity(value)
                if usable() then Window:SetFlag(keys.opacity, clamp(math.floor(value + 0.5), 10, 100)) end
            end
            -- while the mouse is on the number the wheel changes it, not the page
            local scroller
            opacity.MouseEnter:Connect(function()
                local node = opacity.Parent
                while node and not node:IsA("ScrollingFrame") do node = node.Parent end
                if node and node.ScrollingEnabled then scroller = node node.ScrollingEnabled = false end
            end)
            local function releaseScroll()
                if scroller then pcall(function() scroller.ScrollingEnabled = true end) scroller = nil end
            end
            opacity.MouseLeave:Connect(releaseScroll)
            hub.Cleanup[#hub.Cleanup + 1] = releaseScroll
            opacity.Activated:Connect(function()
                local now = math.floor((settings[keys.opacitySetting] or 1) * 100 + 0.5)
                local steps = { 100, 75, 50, 25 }
                local nextValue = steps[1]
                for i, step in ipairs(steps) do if now >= step - 2 then nextValue = steps[i + 1] or steps[1] break end end
                setOpacity(nextValue)
            end)
            opacity.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseWheel then
                    setOpacity((settings[keys.opacitySetting] or 1) * 100 + (input.Position.Z > 0 and 5 or -5))
                end
            end)
            return function()
                local preset, style = settings[keys.presetSetting], settings[keys.styleSetting]
                for name, ring in pairs(rings) do ring.Transparency = name == preset and 0 or 1 end
                for name, option in pairs(options) do
                    local on = name == style
                    option.button.BackgroundTransparency = on and 0 or 1
                    option.icon.BackgroundTransparency = on and 0 or 0.55
                    for _, stripe in ipairs(option.icon:GetChildren()) do
                        if stripe:IsA("Frame") then stripe.BackgroundTransparency = on and 0 or 0.55 end
                    end
                end
                opacity.Text = math.floor((settings[keys.opacitySetting] or 1) * 100 + 0.5) .. "%"
                local off = not usable()
                for _, item in ipairs(dimmable) do item[1][item[2]] = off and 0.65 or item[3] end
                frame.BackgroundTransparency = off and 0.5 or 0.22
            end
        end
        local refreshHealth = capsule(1, "HP", healthPresets, { colors = "esp_hpcolors", style = "esp_hpstyle", opacity = "esp_hpopacity",
            presetSetting = "HealthPreset", styleSetting = "HealthBarStyle", opacitySetting = "HealthBarOpacity", barSetting = "HealthBar" })
        local refreshMode = capsule(2, "MD", modePresets, { colors = "esp_modecolors", style = "esp_mdstyle", opacity = "esp_mdopacity",
            presetSetting = "ModePreset", styleSetting = "ModeBarStyle", opacitySetting = "ModeBarOpacity", barSetting = "ModeBar" })
        local shownKey
        refreshControls = function()
            local key = table.concat({ settings.HealthPreset, settings.HealthBarStyle, settings.HealthBarOpacity, tostring(settings.HealthBar),
                settings.ModePreset, settings.ModeBarStyle, settings.ModeBarOpacity, tostring(settings.ModeBar) }, "|")
            if key == shownKey then return end
            shownKey = key
            refreshHealth()
            refreshMode()
        end
    end

    local box, panel
    local function drawPreview()
        if not holder then return end
        if panel and (panel.segments ~= clamp(math.floor(settings.HealthSegments + 0.5), 1, 10)
            or panel.modeSegments ~= clamp(math.floor(settings.ModeSegments + 0.5), 1, 10)) then
            box:Destroy()
            box, panel = nil, nil
        end
        if not box then
            box = Instance.new("Frame")
            box.Name, box.BackgroundTransparency, box.Size, box.ZIndex = "Panel", 1, UDim2.fromOffset(300, 78), 5
            box.AnchorPoint, box.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12)   -- the top part; the controls are below
            box.Parent = holder
            panel = esp.BuildPanel(box)
        end
        local char = character()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local mode, modeCap
        if char and settings.ModeBar then mode, modeCap = esp.ModeInfo(char) end
        esp.UpdatePanel(panel, {
            display = LocalPlayer.DisplayName, user = LocalPlayer.Name,
            health = hum and healthValue(hum) or nil, maxHealth = hum and healthMax(hum, healthValue(hum)) or 100,
            downed = char ~= nil and char:FindFirstChild("stayonground") ~= nil,
            mode = mode, modeCap = modeCap, distance = 42, dodge = esp.DodgeCooldown(LocalPlayer),
        })
    end
    local function shown(gui)
        while gui do
            if gui:IsA("GuiObject") and not gui.Visible then return false end
            if gui:IsA("LayerCollector") then return gui.Enabled end
            gui = gui.Parent
        end
        return false
    end
    local last = 0
    local function previewTick()
        local now = os.clock()
        if now - last < 1 / 15 then return end
        last = now
        drawPreview()
        refreshControls()
    end
    if holder and Lib.Util.watchInView then
        local connection
        local function disconnect() if connection then connection:Disconnect() connection = nil end end
        local stop = Lib.Util.watchInView(holder, function(visible)
            disconnect()
            if visible and hub.Running then
                last = 0
                connection = RunService.Heartbeat:Connect(function()
                    if hub.Running then
                        local ok, err = pcall(previewTick)
                        if not ok then hubError("ESP preview", err) end
                    end
                end)
            end
        end)
        hub.Cleanup[#hub.Cleanup + 1] = function() stop() disconnect() end
    else
        hubConnect(RunService.Heartbeat, function() if holder and shown(holder) then previewTick() end end)
    end
end

do
local ModeCard = ElementTabs.Mode
ModeCard:Toggle({ Title = "Mode bar", Desc = "Shows player mode HP", Flag = "esp_mbar", Default = true, Callback = set("ModeBar") })
ModeCard:Toggle({ Title = "Mode text", Desc = "Current mode amount", Flag = "esp_mtext", Default = false, DependsOn = { Flag = "esp_mbar", Reason = "" }, Callback = set("ModeText") })
ModeCard:Slider({ Title = "Mode bar segments", Flag = "esp_mseg", Min = 1, Max = 10, Default = 1, DependsOn = { Flag = "esp_mbar", Reason = "" }, Callback = set("ModeSegments") })


-- Target Pins: pinned players ignore the range and the nearest-players limit
local PinsCard = EspPage:Card({ Title = "Target pins", Icon = "pin", Wide = "Bottom", Desc = "Pinned players ignore range and Nearest players" })
PinsCard:PlayerList({ Flag = "esp_pins", Multi = true, Height = 120, Callback = function(ids)
    local pins = {}
    for _, id in ipairs(type(ids) == "table" and ids or { ids }) do if tonumber(id) then pins[tonumber(id)] = true end end
    settings.Pins = pins
end })
end

do -- Visuals › ESP (Chams) and Style (a block: their locals end here)
local Chams = EspPage:Card({ Title = "Chams", Icon = "paint-bucket", Side = "Right" })
Chams:Toggle({ Title = "Chams", Flag = "esp_chams", Default = true, Style = "Switch", Callback = set("Chams") })
local ChamsTabs = Chams:Tabs({ "Fill", "Outline" })
ChamsTabs.Fill:Slider({ Title = "Fill transparency", Flag = "esp_chamsfill", Min = 0, Max = 100, Default = 65, Suffix = "%", DependsOn = { Flag = "esp_chams", Reason = "" },
    Callback = function(v) settings.ChamsFill = v / 100 end })
ChamsTabs.Outline:Slider({ Title = "Outline transparency", Flag = "esp_chamsoutalpha", Min = 0, Max = 100, Default = 35, Suffix = "%", DependsOn = { Flag = "esp_chams", Reason = "" },
    Callback = function(v) settings.ChamsOutlineAlpha = v / 100 end })
ChamsTabs.Fill:ColorPicker({ Title = "Fill color", Flag = "esp_chamscolor", Default = black, DependsOn = { Flag = "esp_chams", Reason = "" }, Callback = set("ChamsColor") })
ChamsTabs.Outline:ColorPicker({ Title = "Outline color", Flag = "esp_chamsout", Default = white, DependsOn = { Flag = "esp_chams", Reason = "" }, Callback = set("ChamsOutline") })


-- bar colours: health on the left, mode on the right
local BarColors = StylePage:Card({ Title = "Bar colors", Icon = "palette", Side = "Left" })
local ColorTabs = BarColors:Tabs({ "Health", "Mode" })
local HealthColors = ColorTabs.Health
HealthColors:Segment({ Title = "Bar style", Flag = "esp_hpstyle", Items = { "Smooth", "Stripes" }, Default = "Smooth", Callback = set("HealthBarStyle") })
HealthColors:Slider({ Title = "Opacity", Flag = "esp_hpopacity", Min = 10, Max = 100, Default = 100, Suffix = "%", Callback = function(v) settings.HealthBarOpacity = v / 100 end })
HealthColors:Swatches({ Title = "From empty to full", Flag = "esp_hpcolors", Default = "Ice", Columns = 2, Items = healthPresets,
    Callback = function(_, name) settings.HealthPreset = name end })
local ModeColors = ColorTabs.Mode
ModeColors:Segment({ Title = "Bar style", Flag = "esp_mdstyle", Items = { "Smooth", "Stripes" }, Default = "Stripes", Callback = set("ModeBarStyle") })
ModeColors:Slider({ Title = "Opacity", Flag = "esp_mdopacity", Min = 10, Max = 100, Default = 100, Suffix = "%", Callback = function(v) settings.ModeBarOpacity = v / 100 end })
ModeColors:Swatches({ Title = "From empty to full", Flag = "esp_modecolors", Default = "Aurora", Columns = 2, Items = modePresets,
    Callback = function(_, name) settings.ModePreset = name end })
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
        local visible = Lib.Util.inView or Lib.Util.shown
        if not parts.sky or not visible(frame) then return end
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
loop("Sky preview", 2, function() if not settings.CustomTime then drawSky() end end)
if skyCanvas.Frame and Lib.Util.watchInView then
    hub.Cleanup[#hub.Cleanup + 1] = Lib.Util.watchInView(skyCanvas.Frame, function(visible)
        if visible and hub.Running then drawSky() end
    end)
end
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
    local originalFov, lastFov
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
    local function writeFov(value)
        if not camera or camera.FieldOfView == value then return end
        if originalFov == nil then originalFov = camera.FieldOfView end
        lastFov = value
        writing = true
        camera.FieldOfView = value
        writing = false
    end
    local function releaseCamera()
        if cameraConnection then cameraConnection:Disconnect() cameraConnection = nil end
        if camera and originalFov ~= nil and math.abs(camera.FieldOfView - lastFov) < 0.001 then
            camera.FieldOfView = originalFov
        end
        originalFov, lastFov = nil, nil
    end
    local function enforce()
        if locked and camera and saved and not writing then writeFov(saved) end
    end
    local function bindCamera()
        releaseCamera()
        camera = workspace.CurrentCamera
        if not camera then return end
        if not locked or saved == nil then saved = moveCfg.Fov or camera.FieldOfView end
        cameraConnection = camera:GetPropertyChangedSignal("FieldOfView"):Connect(enforce)
        if moveCfg.Fov then writeFov(moveCfg.Fov) end
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
        writeFov(v)
    end
    return function()
        Move.setFov = nil
        alive = false
        revision = revision + 1
        locked = false
        releaseCamera()
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
hub.PlayerLateCards = { Spec }                                      -- moved below the Shindo cards
end

----- Server -----
-- Layout C: server browser on the left (fill bar + ping + one-click Join), Options and Job ID on the right.
local Server = Tabs.Server
local SrvCard = Server:Card({ Title = "Servers", Icon = "server", Desc = "Pick by player count and ping" })

-- ServerList: not part of the lib, drawn by hand into the card body (bound to theme colours)
local util = Lib.Util
local theme = Lib.Theme
-- the list scrolls inside the card: its height is set so the card ends on the same line as Options + Job ID beside it
local srvBox = util.create("ScrollingFrame", { Name = "ServerList", BackgroundTransparency = 1, BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 160), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 2, ScrollBarImageTransparency = 0.4,
    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, ElasticBehavior = Enum.ElasticBehavior.Never,
    LayoutOrder = SrvCard:_order(), Parent = SrvCard.body })
theme.bind(srvBox, "ScrollBarImageColor3", "muted")
-- rows go in an inner frame (a UIPadding on a ScrollingFrame sizes its children from the unpadded width);
-- the 1 px inset keeps the row outlines from being clipped at the edges
local srvList = util.create("Frame", { Name = "Rows", BackgroundTransparency = 1, Position = UDim2.fromOffset(1, 1),
    Size = UDim2.new(1, -2, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = srvBox })
util.list(srvList, 5)
local srvRows, srvCache, srvSort = {}, {}, "Asc"
local maxServers = 40

local function pingLevel(ms)
    if ms < 80 then return 4 elseif ms < 150 then return 3 elseif ms < 250 then return 2 end
    return 1
end
local function myPing()
    local ok, p = pcall(function() return LocalPlayer:GetNetworkPing() * 2000 end)   -- one way → round trip
    return ok and floor(p) or 0
end

local function srvRow(order, s, current)
    local row = util.create("Frame", { Name = "Server", Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, LayoutOrder = order, Parent = srvList })
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
if Server.FitHeight then Server:FitHeight(SrvCard, srvBox, { Min = 110, Fallback = 220 }) end
if Lib.Util.watchInView then
    local requested = false
    hub.Cleanup[#hub.Cleanup + 1] = Lib.Util.watchInView(srvBox, function(visible)
        if visible and Running and not requested then requested = true refreshServers() end
    end)
else
    task.delay(1, function() if Running then refreshServers() end end)
end

-- the "you are here" row: player count and your ping
local function updateCurrentServer()
    local n, m = #Players:GetPlayers(), Players.MaxPlayers
    srvCurrent.cnt.Text = ("%d/%d"):format(n, m)
    srvCurrent.fill.Size = UDim2.new(m > 0 and n / m or 0, 0, 1, 0)
    local p = myPing()
    srvCurrent.pl.Text = p > 0 and (p .. " ms") or "-"
end

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
Window:SetModule("ESP", settings.ESP_Enabled and "On" or "Off", nil, { Icon = "eye", Tab = "Visuals" })
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

-- A deadline-based 25 Hz target: work time is not added to the next interval.
-- Frame scheduling still limits the observable rate on low-FPS clients.
do
    local period, nextRefresh = 1 / 25, 0
    connect(RunService.Heartbeat, function()
        if not Running then return end
        local now = os.clock()
        if now < nextRefresh then return end
        if nextRefresh == 0 then nextRefresh = now end
        nextRefresh = nextRefresh + (math.floor((now - nextRefresh) / period) + 1) * period
        safe("ESP", esp.UpdatePanels)
    end)
end

connect(RunService.RenderStepped, function()
    if not Running then return end
    esp.Frame += 1
    if not Camera then
        Silent.Target = nil
        hideUnused(Global, true)
        esp.DropAll()
        return
    end
    if settings.SA_Enabled and Silent.Hooked then
        local ok, target = pcall(findTarget)
        Silent.Target = ok and target or nil
        if not ok then hubError("Silent Aim", target) end
    else
        Silent.Target = nil
    end
    if Render.Available then                                     -- no Drawing API: nothing can be drawn
        safe("FOV", updateGlobal)                                -- FOV circle and target line (Combat)
    end
    if settings.CustomAmbient or settings.Fullbright or settings.NoShadows or settings.CustomTime or settings.NoFog
        or next(WorldOriginal) or Atmospheres.added then safe("World", updateWorld) end
    if Spectating then
        local _, hum = getCharacter(Spectating)
        if hum and Camera.CameraSubject ~= hum then Camera.CameraSubject = hum end
    end
end)

-- player table: refreshed every 2 seconds while it can be seen (scrolled out of the page or on another tab: skipped),
-- and at once when it comes into view
do
    local function refreshPlayerTable()
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
            updateCurrentServer()
        end)
    end
    local row = playerTable.Row
    local seen = Lib.Util.inView or Lib.Util.shown
    local function visible() return not (row and seen) or seen(row) end
    if row and Lib.Util.watchInView then
        hub.Cleanup[#hub.Cleanup + 1] = Lib.Util.watchInView(row, function(shown) if shown and Running then refreshPlayerTable() end end)
    end
    task.spawn(function()
        while Running do
            if visible() then refreshPlayerTable() end
            task.wait(2)
        end
    end)
end

----- Unload -----
env.QustahShindoCore = {
    Unload = function()
        if not Running then return end
        Running = false
        pcall(hubStop)                                           -- farm / spin / player loops and the platform
        for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
        pcall(esp.DestroyPanels)
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
		PunchM = false, PunchD = false, TreeM = false, TreeD = false, Shoot = false, Deflect = false, MentorBoss = false,
		MentorAuto = false, MentorTask = nil, Rush = false, Chi = false, DailyBoss = false,
	}
	local missionTasks = {
		["[Objective: Push-Up Training]"] = "punch", ["[Objective: Tree-Jump Training]"] = "tree",
		["[Objective: Accuracy Training]"] = "shoot", ["[Objective: Deflecting Training]"] = "deflect",
	}
	local function mentorTaskFromUI()
		local m = missionUI()
		local title = m and m.Visible and m:FindFirstChild("title")
		return title and missionTasks[title.Text] or nil
	end
	function hub.MentorBusy()
		return (hub.MentorPendingUntil or 0) > os.clock()
			or (farm.MentorAuto and mentorTaskFromUI() ~= nil)
	end
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
	local progressAt = os.clock()
	local lastMission, lastAmount, cancelAt
	local function checkStuck(mission)
		local amount = mission and mission:FindFirstChild("amount")
		local progress = amount and amount:IsA("ValueBase") and tonumber(amount.Value)
		if progress and (not lastAmount or progress > lastAmount) then
			lastAmount, progressAt, cancelAt = progress, os.clock(), nil
		end
		if farm.StuckAfter <= 0 or os.clock() - progressAt < farm.StuckAfter then return false end
		if not cancelAt or os.clock() - cancelAt >= 5 then
			cancelAt = os.clock()
			if cancelMission() then notify("Auto farm", "Mission timed out; waiting for cancellation", "circle-x", "warning") end
		end
		return true
	end
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
		local mission = currentMission()
		local list = missionMobs()
		if #list > 0 then leaveSafe() end
		for _, v in ipairs(list) do
			-- As in DogeHub: keep hitting until the mob's Humanoid is removed (it died on the server) or the mission ends.
			-- Health is not checked: we set it to 0 locally so it always looks "dead", which made us leave before the boss was killed.
			while flagFn() and inMission() and currentMission() == mission and v.Parent and v:FindFirstChild("Humanoid") do
				if checkStuck(mission) then leaveSafe() return end
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
		if placeType ~= "map" or hub.ScrollBusy or hub.MentorBusy() then return end
		hub.FarmBusy = true
		local ok, err = pcall(function()
			local cur = currentMission()
			if cur ~= lastMission then lastMission, progressAt, lastAmount, cancelAt = cur, os.clock(), nil, nil end
			if cur then
				local _, objective = missionInfo(cur)
				if objective and objective ~= "Mission" then          -- a mission type the farm cannot do
					if cancelMission() then notify("Auto farm", "Mission type '" .. objective .. "', cancelled", "circle-x", "warning") end
					task.wait(1)
					return
				end
			end
			if inMission() and checkStuck(cur) then leaveSafe() return end
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

	-- Selection: Random (whichever boss is ready) or Specific (only the ticked ones; the list shows only then)
	local function pickCard(title, icon, what, list, keySpecific, keySel, flagPrefix)
		local pickedCard = QuestPage:Card({ Title = title, Icon = icon })
		pickedCard:Segment({ Title = "Selection", Flag = flagPrefix .. "mode", Items = { "Random", "Specific" },
			Default = "Random", Callback = function(v) farm[keySpecific] = v == "Specific" end })
		local dd = pickedCard:Dropdown({ Title = "Bosses", Flag = flagPrefix .. "pick", Items = list, Default = {}, Multi = true,
			AllowNone = true, Search = true,
			DependsOn = { Flag = flagPrefix .. "mode", Value = "Specific", Mode = "Hide" },
			Callback = function(v) farm[keySel] = type(v) == "table" and v or { v } end })
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
	loop("Farm counts", 2, whenVisible(BossSet.frame, updateCounts))
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

	local Stats = QuestPage:Card({ Title = "Auto stats", Icon = "gauge", Side = "Right" })
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
	local mentorCard = MentorPage:Card({ Title = "Mentor", Icon = "graduation-cap" })
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
	-- Auto mentor: takes a mission from this map's mentor when none is running and does it by its title (the five
	-- trainings below). The fifth (boss) runs on the boss map without the menu; see "Mentor boss (headless)" at the top.
	mentorCard:Toggle({ Title = "Auto mentor", Flag = "mt_auto", Default = false, Callback = function(v)
		farm.MentorAuto = v
		if not v then farm.MentorTask, hub.MentorPendingUntil = nil, nil end
		pcall(function()
			if v then writefile(mentorAutoFile, "1") queueHub() elseif isfile(mentorAutoFile) then delfile(mentorAutoFile) end
		end)
	end })
	mentorCard:Divider({ Title = "Tasks" })
	mentorCard:Toggle({ Title = "Push-ups", Flag = "mt_punch", Default = false, Callback = function(v) farm.PunchM = v end })
	mentorCard:Toggle({ Title = "Tree jumps", Flag = "mt_tree", Default = false, Callback = function(v) farm.TreeM = v end })
	mentorCard:Toggle({ Title = "Accuracy", Flag = "mt_shoot", Default = false, Callback = function(v) farm.Shoot = v end })
	mentorCard:Toggle({ Title = "Deflecting", Flag = "mt_deflect", Default = false, Callback = function(v) farm.Deflect = v end })
	mentorCard:Toggle({ Title = "Boss", Flag = "mt_boss", Default = false, Callback = function(v) farm.MentorBoss = v end })
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
	loop("Mentor progress", 1, whenVisible(progressCard.frame, function()
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
	end))
	-- a task runs when its toggle is on or Auto mentor picked it
	local function doing(task, manual) return manual or farm.MentorTask == task end
	-- where the kunai targets stand, from each map's mentor (as DogeHub has them)
	local kunaiSpots = {
		[5451398863] = { "Narumaki", Vector3.new(-22, 0, -45) }, [6901575446] = { "Jiso Seishin", Vector3.new(50, 0, 10) },
		[5451401540] = { "Shindai Akuma", Vector3.new(-100, 7, -170) }, [5431071837] = { "Ryuji Kenichi", Vector3.new(0, 320, -300) },
	}
	local function mentorGiver(name)
		local sensei = workspace:FindFirstChild("sensei")
		local g = sensei and sensei:FindFirstChild("missions") and sensei.missions:FindFirstChild(name)
		return g and g:FindFirstChild("missiongiver") and g.missiongiver:FindFirstChild("HumanoidRootPart") and g
	end
	local lastSpotTp = 0
	local function toKunaiSpot()                                   -- every 5 s, as the game moves you away after a throw
		local spot = kunaiSpots[game.PlaceId]
		local g = spot and mentorGiver(spot[1])
		if g and os.clock() - lastSpotTp > 5 then
			lastSpotTp = os.clock()
			tpTo(g.missiongiver.HumanoidRootPart.CFrame + spot[2])
		end
	end
	local function aimAtKunai()
		local mine = workspace.Terrain:FindFirstChild(LocalPlayer.Name)
		local aim = mine and mine:FindFirstChild("kunaiaim")
		if aim then lookAt(aim.Position) end
	end
	local lastTalk = 0
	loop("Auto mentor", 0.25, function()
		if not farm.MentorAuto then return end
		if placeType == "bossbattle" then farm.MentorTask = "boss" return end
		local m = missionUI()
		if m and m.Visible then
			farm.MentorTask = mentorTaskFromUI()
			return
		end
		farm.MentorTask = nil
		if hub.FarmBusy or hub.ScrollBusy or inMission() then return end
		if os.clock() - lastTalk < 1.5 then return end              -- no mission: ask this map's mentor for one
		lastTalk = os.clock()
		for _, name in ipairs(mentors) do
			local g = mentorGiver(name)
			if g then
				leaveSafe()
				hub.MentorPendingUntil = os.clock() + 1.5
				talkTo(g)
				return
			end
		end
	end)
	loop("Mentor", 0.05, function()
		if hub.FarmBusy or hub.ScrollBusy then return end
		local shoot, deflect = doing("shoot", farm.Shoot), doing("deflect", farm.Deflect)
		if shoot or deflect then
			toKunaiSpot()
			aimAtKunai()                                             -- deflecting: face the kunai; accuracy: face and throw
		end
		if doing("punch", farm.PunchM) or farm.PunchD or shoot then combat("mouse1", true) end
		if doing("tree", farm.TreeM) or farm.TreeD then combat("takemovement2") end
		if doing("boss", farm.MentorBoss) then                       -- the boss map, when the menu is open there
			local target
			local folder = workspace:FindFirstChild("npc")
			for _, v in ipairs(folder and folder:GetChildren() or {}) do
				local hum, root = v:FindFirstChild("Humanoid"), v:FindFirstChild("HumanoidRootPart")
				if v:IsA("Model") and v:FindFirstChild("npctype") and string.find(v.Name, "npc") and hum and root and hum.Health > 0 then target = v break end
			end
			if target then
				local anti = target:FindFirstChild("antiexploit")
				if anti then pcall(function() anti:Destroy() end) end
				tpTo(target.HumanoidRootPart.CFrame * CFrame.new(0, 7, 0.3))
				lookAt(target.HumanoidRootPart.Position)
				pcall(function() target.Humanoid.Health = -target.Humanoid.Health end)
				combat("mouse1", true)
			end
		end
	end)
	-- Auto mentor stays on across teleports while its file is there
	if isfile and pcall(isfile, mentorAutoFile) and isfile(mentorAutoFile) then task.defer(function() Window:SetFlag("mt_auto", true) end) end

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
	-- Next reset: a countdown to 00:00 UTC (Roblox's day) until the game's own reset has been seen once; from then on
	-- to that time of day (kept in a file, so it is known on the next run too)
	local nextReset = scheduleCard:Info({ Title = "Next reset", Value = "-" })
	local resetFile = "QustahShindoReset.txt"
	local resetAt                                                -- seconds after 00:00 UTC, nil = not seen yet
	pcall(function()
		if isfile and readfile and isfile(resetFile) then resetAt = tonumber(readfile(resetFile)) end
	end)
	loop("Daily countdown", 1, function()
		local target = resetAt or 0
		local left = (target - os.time() % 86400) % 86400
		if left == 0 then left = 86400 end
		nextReset:Set(string.format("%02d:%02d:%02d", math.floor(left / 3600), math.floor(left % 3600 / 60), left % 60)
			.. (resetAt and " · seen" or " · UTC"))
	end)
	-- daily quest type -> Auto daily toggle
	local dailyFlags = { punch = "dl_m1", rush = "dl_rush", chakra = "dl_chi", treejump = "dl_tree", fightboss = "dl_boss" }
	local dailyState = { dl_m1 = "PunchD", dl_rush = "Rush", dl_chi = "Chi", dl_tree = "TreeD", dl_boss = "DailyBoss" }   -- flag -> farm field
	local lastAmount, allDoneSaid = {}, false
	local claimAt = setmetatable({}, { __mode = "k" })
	loop("Daily schedule", 2, function()
		local st = statz()
		local m = st and st:FindFirstChild("mission")
		if not m then return end
		local reset, groups, now = false, {}, os.clock()
		for i = 1, 14 do
			local q = m:FindFirstChild("dailyquest" .. i)
			local flag = q and q:IsA("ValueBase") and dailyFlags[tostring(q.Value)]
			if flag then
				local amount, maxAmount, claimed = q:FindFirstChild("amount"), q:FindFirstChild("maxamount"), q:FindFirstChild("claim")
				local a = amount and amount:IsA("ValueBase") and tonumber(amount.Value)
				local mx = maxAmount and maxAmount:IsA("ValueBase") and tonumber(maxAmount.Value)
				local previous = lastAmount[i]
				if a ~= nil and mx and mx > 0 then
					if previous and previous.flag == flag and a < previous.amount then reset = true end
					lastAmount[i] = { flag = flag, amount = a }
				end
				local group = groups[flag]
				if not group then group = { total = 0, done = 0 } groups[flag] = group end
				group.total += 1
				if a ~= nil and mx and mx > 0 and a >= mx then
					group.done += 1
					if schedule.Claim and claimed and claimed:IsA("BoolValue") and not claimed.Value
						and now >= (claimAt[q] or 0) then
						claimAt[q] = now + 6
						fire("claim", q)
					end
				end
			else
				lastAmount[i] = nil
			end
		end
		if reset then
			allDoneSaid = false
			table.clear(claimAt)
			-- remember when the game reset (to the minute; the check runs every 2 s)
			resetAt = math.floor(os.time() % 86400 / 60) * 60
			pcall(function() if writefile then writefile(resetFile, tostring(resetAt)) end end)
			if schedule.Start then
				for flag, group in pairs(groups) do
					if group.done < group.total then Window:SetFlag(flag, true) end
				end
				notify("Daily", "Game reset detected: dailies started", "clock")
			end
		end
		local tracked, done = 0, 0
		for flag, group in pairs(groups) do
			local running = farm[dailyState[flag]] == true
			if running or group.done == group.total then
				tracked += group.total
				done += group.done
			end
			if schedule.Claim and running and group.total == group.done then Window:SetFlag(flag, false) end
		end
		if schedule.Notify and not allDoneSaid and tracked > 0 and done >= tracked then
			allDoneSaid = true
			notify("Daily", "Tracked dailies are done", "check")
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
	local PlayerCard = Game
	Game = PlayerCard:Section({ Title = "Defense", Opened = true })
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

	local Aura = PlayerCard:Section({ Title = "Utility", Opened = true })
	Aura:Toggle({ Title = "NPC Kill Aura", Flag = "sh_aura", Default = false, Callback = function(v) shindo.Aura = v end })
	-- Spam E: presses and releases E every frame (chakra charge / interact spam while farming)
	Aura:Toggle({ Title = "Spam E", Flag = "sh_spame", Default = false, Callback = function(v) shindo.SpamE = v end })
	hubConnect(RunService.Stepped, function()
		if not (hub.Running and shindo.SpamE) then return end
		combat("key", "e")
		combat("key", "eend")
	end)
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
	----- Display rank -----
	-- Client side only: other players still see your real rank. "Real" puts the original value back.
	do
		local ranks = { "Real", "RELL", "F 0", "D 1", "D 2", "D 3", "C 1", "C 2", "C 3", "B 1", "B 2", "B 3", "A 1", "A 2", "A 3",
			"S 1", "S 2", "S 3", "V 1", "V 2", "V 3", "X 1", "X 2", "X 3", "Y 1", "Y 2", "Y 3", "Z 1", "Z 2", "Z 3",
			"MAX-69", "MAX-420", "MAX-666", "MAX-999", "GOD", "Dragon", "Hacker", "???" }
		local realRank
		local function rankValue()
			local ls = LocalPlayer:FindFirstChild("leaderstats")
			return ls and ls:FindFirstChild("Rank")
		end
		local function applyRank()
			local rv = rankValue()
			if not rv then return end
			local want = shindo.DisplayRank
			if want and want ~= "Real" then
				if realRank == nil then realRank = rv.Value end
				if rv.Value ~= want then pcall(function() rv.Value = want end) end
			elseif realRank ~= nil then
				pcall(function() rv.Value = realRank end)
				realRank = nil
			end
		end
		Aura:Dropdown({ Title = "Display rank", Flag = "sh_rank", Default = "Real", Items = ranks, Callback = function(v)
			shindo.DisplayRank = v
			applyRank()
		end })
		loop("Display rank", 1, applyRank)                         -- the server rewrites it on rank-up, so it is reapplied
		hub.Cleanup[#hub.Cleanup + 1] = function() shindo.DisplayRank = "Real" applyRank() end
	end
	Aura:Toggle({ Title = "Anti-AFK", Desc = "Prevents the 20 minute idle kick", Flag = "p_antiafk", Default = true, Callback = function(v)
		if hub.SetAntiAfk then hub.SetAntiAfk(v) end
	end })
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
		if not shindo.Scroll or hub.FarmBusy or (hub.MentorBusy and hub.MentorBusy()) or inMission() then return end
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
		loop("Teleport distances", 2, whenVisible(placeList.Row, function()                    -- distances follow you around
			for _, p in ipairs(here) do placeList:SetDesc(p[1], distanceText(p)) end
		end))
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
		{ "Logs", "axe", function()
			local folder = workspace:FindFirstChild("npc")
			if not folder then return nil end
			for _, v in ipairs(folder:GetChildren()) do
				local hrp = v.Name == "logtraining" and v:FindFirstChild("HumanoidRootPart")
				local head = v:FindFirstChild("Head")
				if hrp and head and head.Position.Y > -1000 then return hrp.CFrame * CFrame.new(0, 2, 10) end
			end
		end },
		{ "Training", "dumbbell", function()
			-- training spots differ per map: a platform, seats or pads inside workspace.training
			local names = { [5255237254] = "Part", [5824792748] = "MeshPart", [6602103757] = "Meshes/mounty_Cube.003" }
			local want = names[game.PlaceId]
			local folder = workspace:FindFirstChild("training")
			if not (want and folder) then return nil end
			for _, v in ipairs(folder:GetChildren()) do
				if v.Name == want and v:IsA("BasePart") then return v.CFrame * CFrame.new(0, want == "Part" and 1 or 2, 0) end
			end
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
	local picker

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
			if animated[part] then
				local original = restore[part]
				if original and send(part, original) then
					colors[part] = original
				else
					colors[part] = currentColor(part) or colors[part] or Color3.new(1, 1, 1)
				end
				if hub.Running and picker and selected == part then picker:Set(colors[part], true) end
			end
			restore[part], animated[part] = nil, nil
		end
	end

	local card = colorsPage:Card({ Title = "Character colors", Icon = "palette" })
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
	for _, root in pairs({ customization = gui:FindFirstChild("Customization") and gui.Customization:FindFirstChild("Genkaibag"),
		inGame = gui:FindFirstChild("ingame") and gui.ingame:FindFirstChild("Menu") }) do
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
	for key, dd in pairs(dropdowns) do
		local ok, err = pcall(function()
			dd:SetItems(itemsOf(key), true)
			pickSet(key)(dd:Get())
		end)
		if not ok then hubError("Loadout refresh", err) end
	end
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
-- Rows on screen follow their title (text / position changes); a flag change repaints them once.
do
	local marks = {}
	for _, el in pairs(Window.flags or {}) do
		local row = type(el) == "table" and el.Row
		local title = row and row:FindFirstChild("Title")
		if title then
			local ok, img = pcall(function()
				return Lib.Icons.Image("lock", { Size = UDim2.fromOffset(10, 10), Color = Color3.fromRGB(150, 155, 168) })
			end)
			if ok and img then
				img.AnchorPoint, img.ZIndex, img.Visible, img.Parent = Vector2.new(0, 0.5), 23, false, row
				local mark = { row = row, visible = false }
				function mark.paint()
					local show = el._depLocked == true and title.Parent ~= nil
					img.Visible = show
					if show then
						img.Position = UDim2.fromOffset(
							title.AbsolutePosition.X - row.AbsolutePosition.X + title.TextBounds.X + 5,
							title.AbsolutePosition.Y - row.AbsolutePosition.Y + title.AbsoluteSize.Y / 2)
					end
				end
				local links = {}
				local function clear()
					for _, c in ipairs(links) do c:Disconnect() end
					table.clear(links)
				end
				local stop = Lib.Util.watchInView(row, function(visible)
					clear()
					mark.visible = visible and hub.Running
					if mark.visible then
						mark.paint()
						for _, spec in ipairs({ { title, "TextBounds" }, { title, "AbsolutePosition" }, { title, "AbsoluteSize" }, { row, "AbsolutePosition" } }) do
							links[#links + 1] = spec[1]:GetPropertyChangedSignal(spec[2]):Connect(mark.paint)
						end
					else img.Visible = false end
				end)
				marks[#marks + 1] = mark
				hub.Cleanup[#hub.Cleanup + 1] = function() stop() clear() end
			end
		end
	end
	-- The dependents list runs from its end, so this runs before the rows' own DependsOn checks: the repaint waits a
	-- step to see the new lock states, and several flag changes in a row share one repaint.
	local queued = false
	Window._dependents = Window._dependents or {}
	Window._dependents[#Window._dependents + 1] = function()
		if not hub.Running then return false end
		if not queued then
			queued = true
			task.defer(function()
				queued = false
				for _, mark in ipairs(marks) do
					if mark.visible and mark.row.Parent then mark.paint() end
				end
			end)
		end
		return true
	end
end

----- Startup -----
Window:SettingsTab({ Compact = true })
Window.Config:LoadAutoLoad()
for _, fn in ipairs(hub.AfterAutoLoad or {}) do pcall(fn) end
Window:Notify({ Title = "Qustāh Shindo", Content = "Loaded · " .. placeName() .. " · RShift to toggle", Icon = "sparkles" })
