-- Event Magnet Farm: standalone client script; HTTP is used only to list
-- public servers for the optional one-time startup hop. No file writes/hooks.
-- Run only one movement/farm script at a time. Stop the other auto scripts first.
-- Detect replicated events; farm living NPCs whose Name/DisplayName contains
-- "magnetized" (case insensitive). Generic Magnet tags are diagnostic only.
-- Optional overrides BEFORE running: getgenv().EventMagnetConfig = { Enabled = false }
local env = (type(getgenv) == "function" and getgenv()) or _G
local previous = env.EventMagnetFarm
if type(previous) == "table" and type(previous.Destroy) == "function" then
    previous.Destroy()
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Tags = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")
if not game:IsLoaded() then game.Loaded:Wait() end
local player = Players.LocalPlayer
while not player do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    player = Players.LocalPlayer
end
assert(player, "EventMagnetFarm must run on the client")
local config = {
    Enabled = true, Speed = 190, Weapon = "Melee", ScanInterval = 0.5,
    AttackInterval = 0.25, AttackRange = 10, HoverHeight = 6,
    TargetTimeout = 120, NoDamageTimeout = 12, NoProgressTimeout = 12,
    RetryDelay = 20, LogLimit = 80,
    Patrol = true, PatrolHeight = 12, PatrolWait = 15, SpawnTimeout = 30,
    PatrolArrival = 6, SpawnRadius = 180,
    SpawnSettleTime = 5,
    CampSettleTime = 2,
    Sea1IslandMode = true, IslandWait = 6, IslandSpawnTimeout = 12,
    UsePortalFruit = true, PortalLongDistance = 750, PortalMinSaving = 250,
    PortalTargetRadius = 3000, PortalCooldown = 8, GatewayOpenTimeout = 3,
    GatewayArrivalTimeout = 5, GatewayArrivalRadius = 500,
    GatewayMoveThreshold = 250,
    FruitEnabled = true, FruitESPEnabled = true, FruitESPUpdateInterval = 0.1,
    FruitScanInterval = 1, FruitPickupDistance = 6, FruitPickupConfirm = 2,
    FruitPickupAttempts = 3, FruitRetryDelay = 60,
    StoreFruit = true, StoreRetryDelay = 15, StoreAttempts = 3,
    StartupHop = true, StartupDelay = 5, CurrentPlayerLimit = 4,
    TargetExistingPlayers = 3, HopMaxPages = 3, HopCandidates = 3,
    HopRequestRetries = 3, HopRetryDelay = 60, HopTeleportTimeout = 8,
}
local overrides = env.EventMagnetConfig
-- Seed coordinates copied from auto_farm_level.lua QuestDatabase (not executed).
-- Historical fallback only; live EnemySpawns adds points for the current map.
local seedRoutes = {
    [1] = {
        { "Bandit", Vector3.new(1185.03, 16.48, 1618.34) },
        { "Monkey", Vector3.new(-1610.96, 21.70, 142.13) },
        { "Gorilla", Vector3.new(-1237.52, 6.27, -485.45) },
        { "Pirate", Vector3.new(-1215.17, 4.75, 3915.22) },
        { "Brute", Vector3.new(-1379.88, 14.85, 4132.89) },
        { "Desert Bandit", Vector3.new(990.22, 6.43, 4440.89) },
        { "Desert Officer", Vector3.new(1573.49, 13.91, 4426.68) },
        { "Snow Bandit", Vector3.new(1288.75, 105.77, -1451.98) },
        { "Snowman", Vector3.new(1288.75, 105.77, -1451.98) },
        { "Chief Petty Officer", Vector3.new(-4892.47, 21.05, 4280.97) },
        { "Sky Bandit", Vector3.new(-4981.49, 717.67, -2614.93) },
        { "Dark Master", Vector3.new(-5251.27, 388.58, -2270.82) },
        { "Prisoner", Vector3.new(5412.35, 1.65, 502.82) },
        { "Dangerous Prisoner", Vector3.new(5544.75, 1.65, 689.47) },
        { "Toga Warrior", Vector3.new(-1805.88, 7.35, -2758.62) },
        { "Gladiator", Vector3.new(-1432.88, 7.35, -3130.98) },
        { "Mil. Soldier", Vector3.new(-5414.28, 12.23, 8466.82) },
        { "Mil. Spy", Vector3.new(-5822.48, 86.85, 8828.21) },
        { "Fishman Warrior", Vector3.new(60846.54, 43.19, 1378.89) },
        { "Fishman Commando", Vector3.new(61794.75, 43.19, 1464.38) },
        { "God's Guard", Vector3.new(-4714.29, 845.27, -1885.64) },
        { "Shanda", Vector3.new(-7678.43, 5566.94, -499.78) },
        { "Royal Squad", Vector3.new(-7725.29, 5610.45, -1445.69) },
        { "Royal Soldier", Vector3.new(-7861.64, 5610.45, -1774.22) },
        { "Galley Pirate", Vector3.new(5591.95, 38.50, 3971.95) },
        { "Galley Captain", Vector3.new(5654.49, 38.50, 4945.89) },
    },
    [2] = {
        { "Raider", Vector3.new(-738.74, 82.98, 2378.96) },
        { "Mercenary", Vector3.new(-962.77, 72.98, 1438.45) },
        { "Swan Pirate", Vector3.new(878.89, 121.72, 1221.75) },
        { "Factory Staff", Vector3.new(295.34, 73.10, -56.32) },
        { "Marine Lieutenant", Vector3.new(-2824.52, 73.01, -3038.98) },
        { "Marine Captain", Vector3.new(-1867.75, 73.01, -3320.12) },
        { "Zombie", Vector3.new(-5642.45, 48.51, -720.89) },
        { "Vampire", Vector3.new(-6018.98, 6.45, -1312.45) },
        { "Snow Trooper", Vector3.new(508.89, 401.55, -5578.45) },
        { "Winter Warrior", Vector3.new(1185.74, 429.85, -5189.65) },
        { "Lab Subordinate", Vector3.new(-5778.45, 15.95, -4468.89) },
        { "Horned Warrior", Vector3.new(-6402.12, 15.95, -5812.45) },
        { "Magma Ninja", Vector3.new(-5212.89, 15.95, -4822.45) },
        { "Lava Pirate", Vector3.new(-5245.78, 15.95, -4720.12) },
        { "Ship Deckhand", Vector3.new(1185.45, 125.06, 32989.12) },
        { "Ship Engineer", Vector3.new(912.45, 125.06, 33022.45) },
        { "Ship Steward", Vector3.new(912.45, 125.06, 33455.78) },
        { "Ship Officer", Vector3.new(1055.89, 125.06, 33312.45) },
        { "Arctic Warrior", Vector3.new(6022.45, 28.19, -6245.89) },
        { "Snow Lurker", Vector3.new(5522.78, 28.19, -6812.45) },
        { "Sea Soldier", Vector3.new(-3245.89, 237.28, -9812.45) },
        { "Water Fighter", Vector3.new(-3389.12, 237.28, -10512.78) },
    },
    [3] = {
        { "Pirate Millionaire", Vector3.new(-375.45, 43.76, 5322.89) },
        { "Pistol Billionaire", Vector3.new(-180.12, 43.76, 5912.45) },
        { "Dragon Crew Warrior", Vector3.new(6412.89, 51.68, -985.45) },
        { "Dragon Crew Archer", Vector3.new(6612.45, 51.68, -1250.78) },
        { "Female Islander", Vector3.new(5212.89, 601.62, 1022.45) },
        { "Giant Islander", Vector3.new(4822.45, 601.62, 589.12) },
        { "Marine Commodore", Vector3.new(2455.89, 27.81, -6512.45) },
        { "Marine Rear Admiral", Vector3.new(1912.45, 27.81, -7022.78) },
        { "Fishman Raider", Vector3.new(-10312.45, 331.66, -8412.89) },
        { "Fishman Captain", Vector3.new(-10822.89, 331.66, -9012.45) },
        { "Forest Pirate", Vector3.new(-13455.89, 331.78, -7312.45) },
        { "Mythological Pirate", Vector3.new(-13688.12, 331.78, -7912.89) },
        { "Jungle Pirate", Vector3.new(-9122.45, 142.13, 5788.89) },
        { "Musketeer Pirate", Vector3.new(-8822.89, 142.13, 6012.45) },
        { "Reborn Skeleton", Vector3.new(-8755.12, 142.13, 6212.89) },
        { "Living Zombie", Vector3.new(-10122.45, 142.13, 5912.89) },
        { "Demonic Soul", Vector3.new(-9512.89, 175.13, 6112.45) },
        { "Posessed Mummy", Vector3.new(-9612.45, 6.13, 6212.89) },
        { "Peanut Scout", Vector3.new(-2312.45, 38.10, -10412.89) },
        { "Peanut President", Vector3.new(-1912.89, 38.10, -10512.45) },
        { "Ice Cream Chef", Vector3.new(-612.45, 65.82, -11122.89) },
        { "Ice Cream Commander", Vector3.new(-1022.89, 65.82, -11212.45) },
        { "Cookie Crafter", Vector3.new(-2312.45, 37.80, -12212.89) },
        { "Cake Guard", Vector3.new(-1712.89, 37.80, -12312.45) },
        { "Baking Staff", Vector3.new(-1612.45, 37.79, -12912.89) },
        { "Head Baker", Vector3.new(-2112.89, 37.79, -13012.45) },
        { "Cocoa Warrior", Vector3.new(412.45, 25.33, -12412.89) },
        { "Chocolate Bar Battler", Vector3.new(52.89, 25.33, -12612.45) },
        { "Sweet Thief", Vector3.new(-912.45, 15.93, -14612.89) },
        { "Candy Rebel", Vector3.new(-1388.89, 15.93, -14712.45) },
        { "Candy Pirate", Vector3.new(-1122.45, 15.94, -15212.89) },
        { "Snow Demon", Vector3.new(-1512.89, 15.94, -15312.45) },
        { "Isle Outlaw", Vector3.new(-16212.45, 54.87, -312.89) },
        { "Island Boy", Vector3.new(-16812.89, 54.87, -412.45) },
        { "Sun-kissed Warrior", Vector3.new(-16312.45, 54.87, -689.12) },
        { "Isle Champion", Vector3.new(-16788.89, 54.87, -789.45) },
        { "Serpent Hunter", Vector3.new(-16212.45, 54.87, -1212.89) },
        { "Submerged Stalker", Vector3.new(-16812.89, 54.87, -1312.45) },
    },
}

-- Known Portal arrival anchors. Camp/mob coordinates are matched to the nearest
-- anchor, then translated to the actual World Warp label through aliases below.
local portalDestinations = {
    [2] = {
        ["Cafe"] = Vector3.new(-382, 74, 356),
        ["Colosseum"] = Vector3.new(-1836, 46, 1642),
        ["Dark Arena"] = Vector3.new(3948, 13, -3479),
        ["Docks 1"] = Vector3.new(-923, 8, 1810),
        ["Docks 2"] = Vector3.new(-13, 39, 2708),
        ["Docks 3"] = Vector3.new(-1944, 9, -2594),
        ["Docks 4"] = Vector3.new(-5798, 1, -5021),
        ["Doghouse"] = Vector3.new(-1984, 125, -82),
        ["Graveyard"] = Vector3.new(-5710, 126, -775),
        ["Haunted Ship"] = Vector3.new(937, 125, 32879),
        ["Lab"] = Vector3.new(-5542, 335, -5924),
        ["Lava"] = Vector3.new(-5280, 7, -5618),
        ["Mansion"] = Vector3.new(-494, 339, 593),
        ["Raid"] = Vector3.new(-6503, 251, -4495),
        ["Remote"] = Vector3.new(4766, 8, 2911),
        ["Skull"] = Vector3.new(-2956.24341, 123.399323, -9981.06934),
        ["Snow"] = Vector3.new(1210, 429, -4663),
        ["Winter Castle"] = Vector3.new(5544.71777, 60.1393852, -6359.08887),
    },
    [3] = {
        ["Cake Land"] = Vector3.new(-2098.97046, 76.39494, -12128.3594),
        ["Chocolate Land"] = Vector3.new(379.13962, 130.20599, -12720.8398),
        ["Great Tree"] = Vector3.new(4345.09375, 575.05243, -6159.00439),
        ["Haunted Castle"] = Vector3.new(-9515.00098, 149.18877, 5534.05029),
        ["Hydra Arena"] = Vector3.new(5020.9458, 174.08646, -2011.18506),
        ["Hydra Town"] = Vector3.new(5229.995, 604.345, 345.154),
        ["Ice Cream Land"] = Vector3.new(-917.54852, 63.36414, -10858.6963),
        ["Peanut Land"] = Vector3.new(-2037.80017, 13.65112, -9948.20215),
        ["Port"] = Vector3.new(-342.43436, 23.83155, 5547.3457),
        ["Sea Castle"] = Vector3.new(-5502.17871, 323.6709, -2863.46167),
        ["Tiki Outpost"] = Vector3.new(-16456.4629, 530.25195, 436.23181),
        ["Turtle Center"] = Vector3.new(-12007.9795, 339.15549, -9178.58008),
        ["Turtle Entrance"] = Vector3.new(-10163.9648, 340.29028, -8320.76758),
        ["Turtle Mansion"] = Vector3.new(-12538.4219, 339.39359, -7817.0708),
        ["Turtle Mountain"] = Vector3.new(-12856.6133, 852.7536, -10715.2305),
    },
}

-- Several farm camps belong to one large World Warp region. The first alias is
-- the canonical route key and the remaining values tolerate older UI labels.
local portalRouteAliases = {
    [2] = {
        ["Cafe"] = {"Kingdom of Rose", "Cafe"},
        ["Colosseum"] = {"Kingdom of Rose", "Colosseum"},
        ["Docks 1"] = {"Kingdom of Rose", "Docks 1"},
        ["Docks 2"] = {"Kingdom of Rose", "Docks 2"},
        ["Doghouse"] = {"Kingdom of Rose", "Doghouse"},
        ["Mansion"] = {"Kingdom of Rose", "Mansion"},
        ["Dark Arena"] = {"Dark Arena"},
        ["Remote"] = {"Green Zone", "Remote"},
        ["Graveyard"] = {"Graveyard"}, ["Docks 3"] = {"Graveyard", "Docks 3"},
        ["Docks 4"] = {"Hot and Cold", "Docks 4"},
        ["Lab"] = {"Hot and Cold", "Lab"}, ["Lava"] = {"Hot and Cold", "Lava"},
        ["Raid"] = {"Hot and Cold", "Raid"},
        ["Haunted Ship"] = {"Cursed Ship", "Haunted Ship"},
        ["Snow"] = {"Ice Castle", "Snow"},
        ["Winter Castle"] = {"Ice Castle", "Winter Castle"},
        ["Skull"] = {"Forgotten Island", "Skull"},
    },
    [3] = {
        ["Port"] = {"Port Town", "Port"},
        ["Hydra Arena"] = {"Hydra Island", "Hydra Arena"},
        ["Hydra Town"] = {"Hydra Island", "Hydra Town"},
        ["Great Tree"] = {"Great Tree"},
        ["Sea Castle"] = {"Castle on the Sea", "Castle On The Sea", "Sea Castle"},
        ["Haunted Castle"] = {"Haunted Castle"},
        ["Turtle Center"] = {"Floating Turtle", "Turtle Center"},
        ["Turtle Entrance"] = {"Floating Turtle", "Turtle Entrance"},
        ["Turtle Mansion"] = {"Floating Turtle", "Turtle Mansion"},
        ["Turtle Mountain"] = {"Floating Turtle", "Turtle Mountain"},
        ["Cake Land"] = {"Sea of Treats", "Cake Land"},
        ["Chocolate Land"] = {"Sea of Treats", "Chocolate Land"},
        ["Ice Cream Land"] = {"Sea of Treats", "Ice Cream Land"},
        ["Peanut Land"] = {"Sea of Treats", "Peanut Land"},
        ["Tiki Outpost"] = {"Tiki Outpost"},
    },
}

-- Mesh fallback shared by Fruit pickup and ESP. Direct Tool/Model names remain
-- the primary signal and Portal-Portal is never classified as an item Fruit.
local fruitNamesByMeshId = {
    ["15100283484"] = "Light Fruit", ["15116730102"] = "Love Fruit",
    ["15100273645"] = "Dough Fruit", ["15116967784"] = "Spider Fruit",
    ["15112263502"] = "Shadow Fruit", ["15104782377"] = "Blade Fruit",
    ["15060012861"] = "Rocket Fruit", ["15106768588"] = "Leopard Fruit",
    ["15112469964"] = "Falcon Fruit", ["15708895165"] = "T-Rex Fruit",
    ["19001642259"] = "Dragon East Fruit", ["86024571204851"] = "Gas Fruit",
    ["15100246632"] = "Phoenix Fruit", ["14661873358"] = "Sound Fruit",
    ["15111584216"] = "Flame Fruit", ["15105281957"] = "Spring Fruit",
    ["15116740364"] = "Bomb Fruit", ["15104817760"] = "Rubber Fruit",
    ["15057683975"] = "Spin Fruit", ["15105350415"] = "Magma Fruit",
    ["15482881956"] = "Kitsune Fruit", ["15100485671"] = "Barrier Fruit",
    ["18955022385"] = "Dragon West Fruit", ["101378450824208"] = "Yeti Fruit",
    ["15116721173"] = "Pain Fruit", ["10395893751"] = "Venom Fruit",
    ["11908375285"] = "Spirit Fruit", ["15100433167"] = "Ice Fruit",
    ["15100299740"] = "Gravity Fruit", ["15107005807"] = "Spike Fruit",
    ["15116696973"] = "Smoke Fruit", ["15112600534"] = "Diamond Fruit",
    ["15112333093"] = "Ghost Fruit", ["15057718441"] = "Quake Fruit",
    ["15111517529"] = "Sand Fruit", ["15100313696"] = "Buddha Fruit",
    ["15116747420"] = "Rumble Fruit", ["15100384816"] = "Blizzard Fruit",
    ["15111553409"] = "Dark Fruit", ["14661837634"] = "Mammoth Fruit",
    ["15100184583"] = "Control Fruit",
}
local fruitColors = {
    ["Leopard Fruit"] = Color3.fromRGB(255, 170, 0),
    ["Dragon East Fruit"] = Color3.fromRGB(255, 0, 0),
    ["Dragon West Fruit"] = Color3.fromRGB(255, 80, 80),
    ["Kitsune Fruit"] = Color3.fromRGB(200, 100, 255),
    ["Spirit Fruit"] = Color3.fromRGB(120, 200, 255),
    ["Venom Fruit"] = Color3.fromRGB(180, 60, 200),
    ["Dough Fruit"] = Color3.fromRGB(255, 220, 180),
    ["Light Fruit"] = Color3.fromRGB(255, 255, 150),
}
if type(overrides) == "table" then
    for key, value in pairs(config) do
        if type(overrides[key]) == type(value) then config[key] = overrides[key] end
    end
end
for key, value in pairs(config) do
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error("Invalid EventMagnetConfig." .. key)
        end
        config[key] = math.max(value, 0.05)
    end
end
config.LogLimit = math.clamp(math.floor(config.LogLimit), 10, 300)
config.ScanInterval = math.max(config.ScanInterval, 0.2)
config.AttackInterval = math.max(config.AttackInterval, 0.1)
config.Speed = math.clamp(config.Speed, 1, 500)
config.AttackRange = math.clamp(config.AttackRange, 7, 30)
config.HoverHeight = math.clamp(config.HoverHeight, 1, config.AttackRange - 2)
config.PatrolWait = math.max(config.PatrolWait, config.ScanInterval * 2)
config.SpawnTimeout = math.max(config.SpawnTimeout, config.PatrolWait)
config.IslandWait = math.max(config.IslandWait, config.ScanInterval * 2)
config.IslandSpawnTimeout = math.max(config.IslandSpawnTimeout, config.IslandWait)
config.CampSettleTime = math.max(config.CampSettleTime, config.ScanInterval * 2)
config.FruitPickupAttempts = math.clamp(math.floor(config.FruitPickupAttempts), 1, 10)
config.StoreAttempts = math.clamp(math.floor(config.StoreAttempts), 1, 10)
config.CurrentPlayerLimit = math.max(1, math.floor(config.CurrentPlayerLimit))
config.TargetExistingPlayers = math.clamp(math.floor(config.TargetExistingPlayers),
    0, math.max(0, config.CurrentPlayerLimit - 1))
config.HopMaxPages = math.clamp(math.floor(config.HopMaxPages), 1, 10)
config.HopCandidates = math.clamp(math.floor(config.HopCandidates), 1, 10)
config.HopRequestRetries = math.clamp(math.floor(config.HopRequestRetries), 1, 5)

local alive, enabled = true, config.Enabled
local connections, remotes, mobs = {}, {}, {}
local targets, logs = {}, {}
local skipped = setmetatable({}, { __mode = "k" })
local target, targetSince, lastDamage, lastHP, attackSince
local bestDistance, lastProgress = math.huge, 0
local moveRoot, moveHumanoid, floatForce, oldPlatform
local collisionState = {}
local eventCount, deliveryCount = 0, 0
local status = "Dang quet..."
local scanClock, attackClock, uiClock, fruitScanClock, fruitESPClock = 0, 0, 0, 0, 0
local lastError = -math.huge
local api = {}
env.EventMagnetFarm = api
local patrol = { points = {}, pass = 1, current = nil, refresh = 0,
    arrived = nil, started = nil, best = math.huge, progress = 0 }
local action = { kind = nil, token = 0 }
local portal = { retryAt = 0, lastResult = "Chua dung", destination = nil, forCombat = false }
local fruitRecords = setmetatable({}, { __mode = "k" })
local storeRecords = setmetatable({}, { __mode = "k" })
local fruitTask = { target = nil, started = nil, best = math.huge, progress = 0 }
local hop = { busy = false, retryAt = 0, status = "Cho kiem tra dau phien" }
local sessionSerial = (tonumber(env.__EventMagnetSessionSerial) or 0) + 1
env.__EventMagnetSessionSerial = sessionSerial
local serverChoiceMemory = env.__EventMagnetServerChoice
if type(serverChoiceMemory) ~= "table" then
    serverChoiceMemory = {}
    env.__EventMagnetServerChoice = serverChoiceMemory
end

local function contains(text, word)
    return string.find(string.lower(tostring(text or "")), word, 1, true) ~= nil
end
local function short(text, length)
    return string.sub(tostring(text):gsub("[%c]", " "), 1, length or 150)
end
local function path(instance)
    local ok, result = pcall(function() return instance:GetFullName() end)
    return ok and short(result, 220) or "<removed>"
end
local function log(kind, message)
    table.insert(logs, { time = os.clock(), kind = kind, text = short(message, 260) })
    if #logs > config.LogLimit then table.remove(logs, 1) end
end
local function connect(signal, callback)
    local connection = signal:Connect(function(...)
        if alive then callback(...) end
    end)
    table.insert(connections, connection)
    return connection
end
local function rootOf(model)
    local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
    return root and root:IsA("BasePart") and root or nil
end
local function livingNPC(model)
    if not model or not model:IsDescendantOf(workspace) then return nil end
    if Players:GetPlayerFromCharacter(model) then return nil end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = rootOf(model)
    if humanoid and humanoid.Health > 0 and root then return humanoid, root end
end
local function isMagnetized(model, humanoid)
    return contains(model.Name, "magnetized") or contains(humanoid.DisplayName, "magnetized")
end
local function releaseMovement()
    if floatForce then floatForce:Destroy(); floatForce = nil end
    if moveHumanoid and moveHumanoid.Parent then moveHumanoid.PlatformStand = oldPlatform end
    if moveRoot and moveRoot.Parent then
        moveRoot.AssemblyLinearVelocity = Vector3.zero
        moveRoot.AssemblyAngularVelocity = Vector3.zero
    end
    for part, original in pairs(collisionState) do
        if part.Parent then part.CanCollide = original end
    end
    collisionState = {}
    moveRoot, moveHumanoid, oldPlatform = nil, nil, nil
end
local function actionIsCurrent(kind, token)
    return alive and enabled and sessionSerial == env.__EventMagnetSessionSerial
        and action.kind == kind and action.token == token
end
local function beginAction(kind)
    if action.kind then return nil end
    action.token = action.token + 1
    action.kind = kind
    return action.token
end
local function endAction(kind, token)
    if action.kind == kind and action.token == token then action.kind = nil end
end
local function cancelAction(reason)
    local oldKind = action.kind
    if oldKind and reason then log("ACTION", oldKind .. ": " .. reason) end
    action.token = action.token + 1
    action.kind = nil
    portal.destination, portal.forCombat = nil, false
    if oldKind == "hop" then
        hop.busy = false
        hop.status = "Hop tam dung de uu tien Magnetized"
    end
    releaseMovement()
end
local function hasLiveMagnetized()
    for _, model in ipairs(targets) do
        local humanoid = livingNPC(model)
        if humanoid and isMagnetized(model, humanoid)
            and (skipped[model] or 0) <= os.clock() then return true end
    end
    return false
end
local function resetTarget(reason, skip)
    if target and skip then skipped[target] = os.clock() + config.RetryDelay end
    if target and reason then log("FARM", short(target.Name, 80) .. ": " .. reason) end
    target, attackSince = nil, nil
    bestDistance = math.huge
    patrol.arrived, patrol.started, patrol.best = nil, nil, math.huge
    patrol.seenAt = nil
    releaseMovement()
end
function api.SetEnabled(value)
    if not alive then return end
    enabled = value == true
    cancelAction(enabled and "bat lai" or "da dung")
    if enabled and not hop.checked then hop.readyAt = nil end
    resetTarget()
    status = enabled and "Dang tim Magnetized..." or "Da dung farm; van theo doi event"
end
function api.GetTargets()
    local result = {}
    for model in pairs(mobs) do
        local humanoid, root = livingNPC(model)
        if humanoid and isMagnetized(model, humanoid) then
            table.insert(result, { model = model, name = model.Name,
                displayName = humanoid.DisplayName, health = humanoid.Health,
                position = root.Position, evidence = "Name/DisplayName contains magnetized" })
        end
    end
    return result
end
function api.GetLogs()
    local copy = {}
    for i, entry in ipairs(logs) do
        copy[i] = { time = entry.time, kind = entry.kind, text = entry.text }
    end
    return copy
end
function api.GetEvents()
    local result = {}
    for instance, record in pairs(remotes) do
        table.insert(result, { path = path(instance), class = instance.ClassName,
            received = record.received, magnetName = contains(instance.Name, "magnet") })
    end
    return result
end

-- Keep metadata only: never serialize arbitrary remote payloads or invoke a
-- discovered remote. RemoteFunctions are catalogued without replacing callbacks.
local function observeEvent(instance, initial)
    if remotes[instance] then return end
    local isRemote = instance:IsA("RemoteEvent") or instance:IsA("UnreliableRemoteEvent")
    local isBindable = instance:IsA("BindableEvent")
    if not isRemote and not isBindable and not instance:IsA("RemoteFunction") then return end
    local record = { received = 0, lastLog = -math.huge }
    remotes[instance] = record
    eventCount = eventCount + 1
    if not initial or contains(instance.Name, "magnet") then
        log(initial and "EVENT EXISTING" or "EVENT NEW", instance.ClassName .. " " .. path(instance))
    end
    if isRemote or isBindable then
        local signal = isRemote and instance.OnClientEvent or instance.Event
        record.connection = signal:Connect(function(...)
            if not alive then return end
            record.received = record.received + 1
            deliveryCount = deliveryCount + 1
            local now = os.clock()
            if now - record.lastLog >= 2 then
                record.lastLog = now
                log("EVENT RECEIVED", path(instance) .. " | args=" .. select("#", ...)
                    .. " | total=" .. record.received)
            end
        end)
    end
    record.rename = instance:GetPropertyChangedSignal("Name"):Connect(function()
        if alive then log("EVENT RENAMED", path(instance)) end
    end)
    record.destroy = instance.Destroying:Connect(function()
        if record.connection then record.connection:Disconnect() end
        record.rename:Disconnect()
        record.destroy:Disconnect()
        remotes[instance] = nil
        eventCount = eventCount - 1
    end)
end
local function observeMob(instance)
    if instance:IsA("Humanoid") then
        local model = instance.Parent
        if model and model:IsA("Model") then mobs[model] = mobs[model] or {} end
    end
end
-- Subscribe before initial scan so spawns during startup are not missed.
connect(game.DescendantAdded, function(instance) observeEvent(instance, false) end)
connect(workspace.DescendantAdded, observeMob)
for _, instance in ipairs(game:GetDescendants()) do observeEvent(instance, true) end
for _, instance in ipairs(workspace:GetDescendants()) do observeMob(instance) end

local function magnetMarkers(model, humanoid, root)
    local found = {}
    for _, instance in ipairs({ model, humanoid, root }) do
        for key, value in pairs(instance:GetAttributes()) do
            if contains(key, "magnet") and value ~= false then
                table.insert(found, "attribute:" .. short(key, 50))
            end
        end
        for _, tag in ipairs(Tags:GetTags(instance)) do
            if contains(tag, "magnet") then table.insert(found, "tag:" .. short(tag, 50)) end
        end
    end
    table.sort(found)
    return table.concat(found, ", ")
end
local function scanMobs()
    targets = {}
    for model, record in pairs(mobs) do
        if not model:IsDescendantOf(workspace) then
            mobs[model] = nil
        else
            local humanoid, root = livingNPC(model)
            local confirmed = humanoid and isMagnetized(model, humanoid) or false
            local markers = humanoid and magnetMarkers(model, humanoid, root) or ""
            if confirmed then
                table.insert(targets, model)
                if not record.confirmed then log("MAGNETIZED", path(model)) end
            end
            if markers ~= "" and markers ~= record.markers then
                log("MAGNET CANDIDATE", path(model) .. " | " .. markers)
            end
            record.confirmed, record.markers = confirmed, markers
        end
    end
end

local function normalizeAssetId(value)
    return value ~= nil and string.match(tostring(value), "%d+") or nil
end
local function fruitAnchor(instance)
    if not instance or not instance.Parent then return nil end
    if instance:IsA("BasePart") then return instance end
    local handle = instance:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then return handle end
    if instance:IsA("Model") and instance.PrimaryPart then return instance.PrimaryPart end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end
local function identifyWorldFruit(instance)
    if not instance or instance.Parent ~= workspace then return nil end
    local name, anchor
    if instance:IsA("Tool") and contains(instance.Name, "fruit") then
        name, anchor = instance.Name, fruitAnchor(instance)
    elseif instance:IsA("Model") then
        for _, descendant in ipairs(instance:GetDescendants()) do
            local meshId
            if descendant:IsA("MeshPart") then
                meshId, anchor = descendant.MeshId, descendant
            elseif descendant:IsA("SpecialMesh") then
                meshId, anchor = descendant.MeshId, descendant.Parent
            end
            name = fruitNamesByMeshId[normalizeAssetId(meshId)]
            if name then break end
        end
        if not name and contains(instance.Name, "fruit") then name = instance.Name end
        anchor = anchor or fruitAnchor(instance)
    end
    if not name or not anchor or not anchor:IsA("BasePart") then return nil end
    if instance:FindFirstChild("Ignored") or anchor:FindFirstChild("Ignored") then return nil end
    return name, anchor
end
local function removeFruitRecord(instance)
    local record = fruitRecords[instance]
    if not record then return end
    if record.billboard then record.billboard:Destroy() end
    if record.highlight then record.highlight:Destroy() end
    fruitRecords[instance] = nil
    if fruitTask.target == instance then
        fruitTask.target, fruitTask.started = nil, nil
        releaseMovement()
    end
end
local function createFruitVisual(record)
    if not config.FruitESPEnabled or record.billboard then return end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EventMagnetFruitESP"
    billboard.Adornee, billboard.AlwaysOnTop = record.part, true
    billboard.LightInfluence = 0
    billboard.Size, billboard.StudsOffsetWorldSpace = UDim2.fromOffset(250, 38), Vector3.new(0, 3, 0)
    local text = Instance.new("TextLabel")
    text.BackgroundColor3, text.BackgroundTransparency = Color3.new(0, 0, 0), 0.35
    text.Size, text.Font, text.TextSize = UDim2.fromScale(1, 1), Enum.Font.SourceSansBold, 18
    text.TextStrokeTransparency = 0
    text.TextColor3 = fruitColors[record.name] or Color3.new(1, 1, 1)
    text.Parent, billboard.Parent = billboard, record.part
    local highlight = Instance.new("Highlight")
    highlight.Name = "EventMagnetFruitHighlight"
    highlight.Adornee = record.instance:IsA("Model") and record.instance or record.part
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor, highlight.OutlineColor = text.TextColor3, text.TextColor3
    highlight.FillTransparency, highlight.OutlineTransparency = 0.82, 0
    highlight.Parent = record.part
    record.billboard, record.label, record.highlight = billboard, text, highlight
end
local function addFruitRecord(instance)
    if fruitRecords[instance] then return false end
    local name, part = identifyWorldFruit(instance)
    if not name then return false end
    local record = { instance = instance, name = name, part = part, distance = math.huge,
        retryAt = 0, attempts = 0 }
    fruitRecords[instance] = record
    createFruitVisual(record)
    log("FRUIT", "Phat hien " .. short(name, 80))
    return true
end
local function refreshFruits()
    for _, child in ipairs(workspace:GetChildren()) do addFruitRecord(child) end
    for instance, record in pairs(fruitRecords) do
        if not instance:IsDescendantOf(workspace) then
            removeFruitRecord(instance)
        else
            local name, part = identifyWorldFruit(instance)
            if not name then removeFruitRecord(instance)
            else record.name, record.part = name, part end
        end
    end
end
local function updateFruitESP(root)
    for instance, record in pairs(fruitRecords) do
        if not instance:IsDescendantOf(workspace) or not record.part or not record.part.Parent then
            removeFruitRecord(instance)
        else
            record.distance = root and (record.part.Position - root.Position).Magnitude or math.huge
            createFruitVisual(record)
            if record.billboard then
                record.billboard.Adornee = record.part
                record.billboard.Enabled = config.FruitESPEnabled and root ~= nil
                record.highlight.Enabled = config.FruitESPEnabled and root ~= nil
                record.label.Text = record.name .. " [" .. math.floor(record.distance + 0.5) .. " studs]"
            end
        end
    end
end
local function isOwnedFruitTool(item)
    return item and item:IsA("Tool") and contains(item.Name, "fruit")
        and item:FindFirstChild("Handle") ~= nil
end
local function getFruitOriginalName(item)
    if not item then return nil end
    local ok, value = pcall(function() return item:GetAttribute("OriginalName") end)
    if ok and type(value) == "string" and value ~= "" then return value end
    local child = item:FindFirstChild("OriginalName")
    if child and child:IsA("StringValue") and child.Value ~= "" then return child.Value end
end
local function fruitIdentity(value)
    local name = string.lower(tostring(value or "")):gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("%s+fruit$", "")
    name = name:gsub("[%(%)]", ""):gsub("%s+", " ")
    for separator = 1, #name do
        if string.sub(name, separator, separator) == "-" then
            local left, right = string.sub(name, 1, separator - 1), string.sub(name, separator + 1)
            if left ~= "" and left == right then return left end
        end
    end
    return name
end
local function ownedFruitMatches(record, item)
    if item == record.instance then return true end
    local wanted = fruitIdentity(record.name)
    return fruitIdentity(item.Name) == wanted
        or fruitIdentity(getFruitOriginalName(item)) == wanted
end
local function ownedFruitTools()
    local result = {}
    for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if isOwnedFruitTool(item) then table.insert(result, item) end
            end
        end
    end
    return result
end
local function inventoryFruitCount(commF, storageName)
    local ok, rows = pcall(function() return commF:InvokeServer("getInventoryFruits") end)
    if not ok or type(rows) ~= "table" then return nil end
    local count = 0
    for _, row in pairs(rows) do
        if type(row) == "table" and row.Name == storageName then count = count + 1 end
    end
    return count
end
local function responseConfirmsStore(response)
    if response == true then return true end
    if type(response) == "table" and (response.Success == true or response.Stored == true) then return true end
    if type(response) == "string" then
        local lowered = string.lower(response)
        return lowered == "success" or lowered == "stored" or lowered == "stored."
            or contains(lowered, "stored successfully") or contains(lowered, "successfully stored")
    end
    return false
end
local function responseRejectsStore(response)
    if response == false then return true end
    local lowered = string.lower(tostring(response or ""))
    return contains(lowered, "full") or contains(lowered, "maximum")
        or contains(lowered, "cannot store") or contains(lowered, "already have")
end
local function getStoreSummary()
    local owned, blocked, waiting = ownedFruitTools(), 0, 0
    for _, item in ipairs(owned) do
        local record = storeRecords[item]
        if record and record.blocked then blocked = blocked + 1
        elseif record and record.retryAt > os.clock() then waiting = waiting + 1 end
    end
    return owned, blocked, waiting
end
local function startStore(item, force)
    if not config.StoreFruit or action.kind then return false end
    local record = storeRecords[item] or { attempts = 0, retryAt = 0, blocked = false }
    storeRecords[item] = record
    if not force and (record.blocked or record.retryAt > os.clock()) then return false end
    local storageName = getFruitOriginalName(item)
    if not storageName then
        record.retryAt = os.clock() + config.StoreRetryDelay
        record.last = "Cho OriginalName"
        return false
    end
    local remotesFolder = RS:FindFirstChild("Remotes")
    local commF = remotesFolder and remotesFolder:FindFirstChild("CommF_")
    if not commF then
        record.retryAt = os.clock() + config.StoreRetryDelay
        record.last = "Khong tim thay CommF_"
        return false
    end
    local token = beginAction("store")
    if not token then return false end
    releaseMovement()
    task.spawn(function()
        local before = inventoryFruitCount(commF, storageName)
        if not actionIsCurrent("store", token) or hasLiveMagnetized() then
            endAction("store", token); return
        end
        record.attempts = record.attempts + 1
        local ok, response = pcall(function()
            return commF:InvokeServer("StoreFruit", storageName, item)
        end)
        if not actionIsCurrent("store", token) then return end
        local deadline = os.clock() + 1.5
        while actionIsCurrent("store", token) and os.clock() < deadline do task.wait(0.1) end
        if not actionIsCurrent("store", token) then return end
        local after = inventoryFruitCount(commF, storageName)
        if not actionIsCurrent("store", token) then return end
        local confirmed = ok and (responseConfirmsStore(response)
            or (before ~= nil and after ~= nil and after > before))
        if confirmed then
            record.blocked, record.last = false, "Da luu xac nhan"
            record.retryAt, record.attempts = os.clock() + config.StoreRetryDelay, 0
            log("STORE", short(item.Name, 80) .. ": da luu")
        else
            local permanent = ok and responseRejectsStore(response)
            record.blocked = permanent or record.attempts >= config.StoreAttempts
            record.retryAt = os.clock() + config.StoreRetryDelay
            record.last = ok and "Chua xac nhan luu" or short(response, 100)
            log("STORE", short(item.Name, 80) .. ": " .. record.last
                .. (record.blocked and "; chan hop" or "; se thu lai"))
        end
        endAction("store", token)
    end)
    return true
end
function api.GetFruits()
    local result = {}
    for _, record in pairs(fruitRecords) do
        table.insert(result, { instance = record.instance, name = record.name,
            distance = record.distance, attempts = record.attempts, retryAt = record.retryAt })
    end
    table.sort(result, function(a, b) return a.distance < b.distance end)
    return result
end
function api.RetryStore()
    for _, item in ipairs(ownedFruitTools()) do
        local record = storeRecords[item]
        if record then record.blocked, record.retryAt, record.attempts = false, 0, 0 end
    end
    return true
end
connect(workspace.ChildAdded, function(child)
    task.defer(function() if alive then addFruitRecord(child) end end)
end)
connect(workspace.ChildRemoved, removeFruitRecord)
refreshFruits()

-- A single movement owner serves both patrol and combat.
local function flyTo(root, humanoid, destination, dt, facing)
    if moveRoot ~= root then
        releaseMovement()
        moveRoot, moveHumanoid, oldPlatform = root, humanoid, humanoid.PlatformStand
        floatForce = Instance.new("BodyVelocity")
        floatForce.Name = "EventMagnetFloat"
        floatForce.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        floatForce.Velocity = Vector3.zero
        floatForce.Parent = root
    end
    humanoid.PlatformStand = true
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    local delta = destination - root.Position
    local position = root.Position
    if delta.Magnitude > 0.01 then
        position = position + delta.Unit * math.min(config.Speed * math.clamp(dt, 0, 0.1), delta.Magnitude)
    end
    if facing and (facing - position).Magnitude > 0.01 then
        root.CFrame = CFrame.lookAt(position, facing)
    else
        root.CFrame = CFrame.new(position) * root.CFrame.Rotation
    end
end
local sea = ({
    [2753915549] = 1, [85211729168715] = 1,
    [4442272183] = 2, [79091703265657] = 2,
    [7449423635] = 3, [100117331123089] = 3,
})[game.PlaceId]
hop.readyAt = nil
hop.checked = serverChoiceMemory[game.JobId] == true

local function portalTool()
    local character, backpack = player.Character, player:FindFirstChildOfClass("Backpack")
    return (character and character:FindFirstChild("Portal-Portal"))
        or (backpack and backpack:FindFirstChild("Portal-Portal"))
end
local function portalSkillReady(tool)
    if not tool then return false, "Khong co Portal-Portal" end
    local data = player:FindFirstChild("Data")
    local devilFruit = data and data:FindFirstChild("DevilFruit")
    if devilFruit and devilFruit.Value ~= "Portal-Portal" then return false, "Chua dung trai Portal" end
    local level = tool:FindFirstChild("Level")
    local mastery = level and tonumber(level.Value)
    if mastery and mastery < 200 then return false, "Portal C chua du mastery" end
    return true, mastery and ("Mastery " .. math.floor(mastery)) or "Portal san sang"
end
local function normalizePortalText(value)
    return string.lower(tostring(value or "")):gsub("[^%w]", "")
end
local function portalAliases(name)
    local aliases = portalRouteAliases[sea] or {}
    return aliases[name] or { name }
end
local function portalRouteKey(name)
    local aliases = portalAliases(name)
    return normalizePortalText(aliases[1] or name)
end
local function nearestPortalAnchor(position)
    local nearestName, nearestDistance
    for name, anchor in pairs(portalDestinations[sea] or {}) do
        local distance = (position - anchor).Magnitude
        if not nearestDistance or distance < nearestDistance then
            nearestName, nearestDistance = name, distance
        end
    end
    if nearestDistance and nearestDistance <= config.PortalTargetRadius then
        return nearestName, nearestDistance
    end
end
local function bestPortalFor(targetPosition, rootPosition)
    local bestName, bestPosition, bestSaving
    local direct = (targetPosition - rootPosition).Magnitude
    for name, position in pairs(portalDestinations[sea] or {}) do
        local remaining = (targetPosition - position).Magnitude
        local saving = direct - remaining
        if remaining <= config.PortalTargetRadius and saving >= config.PortalMinSaving
            and (not bestSaving or saving > bestSaving) then
            bestName, bestPosition, bestSaving = name, position, saving
        end
    end
    return bestName, bestPosition
end
local function findGatewayButton(scrolling, destinationName)
    local buttons = {}
    for _, descendant in ipairs(scrolling:GetDescendants()) do
        if descendant:IsA("GuiButton") then table.insert(buttons, descendant) end
    end
    local function buttonLabels(button)
        local labels = { button.Name }
        if button:IsA("TextButton") then table.insert(labels, button.Text) end
        for _, descendant in ipairs(button:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                table.insert(labels, descendant.Text)
            end
        end
        return labels
    end
    local aliases = portalAliases(destinationName)
    for _, alias in ipairs(aliases) do
        local wanted = normalizePortalText(alias)
        for _, button in ipairs(buttons) do
            for _, label in ipairs(buttonLabels(button)) do
                if normalizePortalText(label) == wanted then return button, alias end
            end
        end
    end
    -- Some game versions append the Sea/status to the visible button label.
    for _, alias in ipairs(aliases) do
        local wanted = normalizePortalText(alias)
        if #wanted >= 5 then
            for _, button in ipairs(buttons) do
                for _, label in ipairs(buttonLabels(button)) do
                    if string.find(normalizePortalText(label), wanted, 1, true) then
                        return button, alias
                    end
                end
            end
        end
    end
end
local function activateExactButton(button)
    if type(firesignal) == "function" then
        local ok = pcall(function() firesignal(button.MouseButton1Click) end)
        if ok then return true end
    end
    local getConnections = rawget(env, "getconnections")
    if type(getConnections) ~= "function" and type(getconnections) == "function" then
        getConnections = getconnections
    end
    if type(getConnections) == "function" then
        local ok, list = pcall(getConnections, button.MouseButton1Click)
        if ok and type(list) == "table" then
            local fired = false
            for _, connection in pairs(list) do
                local gotFunction, callback = pcall(function() return connection.Function end)
                if gotFunction and type(callback) == "function"
                    and pcall(callback) then fired = true end
            end
            if fired then return true end
        end
    end
    return pcall(function() button:Activate() end)
end
local function tryStartPortal(targetPosition, root, humanoid, forCombat)
    local distance = (targetPosition - root.Position).Magnitude
    if not config.UsePortalFruit or not (sea == 2 or sea == 3)
        or distance < config.PortalLongDistance or os.clock() < portal.retryAt
        or action.kind then return false end
    local name = bestPortalFor(targetPosition, root.Position)
    if not name then return false end
    local tool = portalTool()
    local usable, reason = portalSkillReady(tool)
    if not usable then
        portal.retryAt, portal.lastResult = os.clock() + config.PortalCooldown, reason
        return false
    end
    local currentName = nearestPortalAnchor(root.Position)
    if currentName and portalRouteKey(currentName) == portalRouteKey(name) then
        portal.lastResult = "Cung vung " .. tostring(portalAliases(name)[1]) .. "; bay 190"
        return false
    end
    local token = beginAction("portal")
    if not token then return false end
    portal.destination, portal.forCombat = name, forCombat == true
    portal.retryAt = os.clock() + config.PortalCooldown
    local oldPosition = root.Position
    local oldDistance = distance
    releaseMovement()
    task.spawn(function()
        local success, detail = false, "Gateway khong mo"
        local ok, runtimeError = xpcall(function()
            if not actionIsCurrent("portal", token)
                or (hasLiveMagnetized() and not forCombat) then return end
            if tool.Parent ~= player.Character then humanoid:EquipTool(tool); task.wait(0.15) end
            if not actionIsCurrent("portal", token)
                or (hasLiveMagnetized() and not forCombat) then return end
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.C, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.C, false, game)
            end)
            local deadline = os.clock() + config.GatewayOpenTimeout
            local gateway
            while actionIsCurrent("portal", token) and os.clock() < deadline do
                local playerGui = player:FindFirstChildOfClass("PlayerGui")
                local main = playerGui and playerGui:FindFirstChild("Main")
                gateway = main and main:FindFirstChild("Gateway")
                if gateway and gateway.Visible then break end
                task.wait(0.1)
            end
            if not actionIsCurrent("portal", token)
                or (hasLiveMagnetized() and not forCombat) then return end
            if not gateway or not gateway.Visible then return end
            local content = gateway:FindFirstChild("MainContent")
            local scrolling = content and content:FindFirstChild("ScrollingFrame")
            local button, matched = scrolling and findGatewayButton(scrolling, name)
            local routeLabel = matched or portalAliases(name)[1] or name
            if not button then detail = "Khong co nut " .. tostring(routeLabel); return end
            if not activateExactButton(button) then detail = "Khong bam duoc nut " .. tostring(routeLabel); return end
            detail = "Da bam " .. tostring(routeLabel) .. "; cho xac nhan"
            local arrivalDeadline = os.clock() + config.GatewayArrivalTimeout
            while actionIsCurrent("portal", token) and os.clock() < arrivalDeadline do
                local character = player.Character
                local newRoot = rootOf(character)
                if newRoot then
                    local newDistance = (targetPosition - newRoot.Position).Magnitude
                    local moved = (newRoot.Position - oldPosition).Magnitude
                    if newDistance <= config.GatewayArrivalRadius
                        or (moved >= config.GatewayMoveThreshold
                            and newDistance <= oldDistance - config.GatewayMoveThreshold) then
                        success, detail = true, "Da xac nhan World Warp " .. tostring(routeLabel)
                        break
                    end
                end
                task.wait(0.2)
            end
            if not success then
                detail = "Da bam " .. tostring(routeLabel) .. " nhung chua xac nhan dich chuyen"
            end
        end, function(err) return tostring(err) end)
        pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.C, false, game) end)
        if actionIsCurrent("portal", token) then
            portal.lastResult = ok and detail or short(runtimeError, 100)
            log("PORTAL", portal.lastResult)
            portal.destination, portal.forCombat = nil, false
            endAction("portal", token)
            if not success then releaseMovement() end
        end
    end)
    return true
end

local function requestFunction()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if fluxus and type(fluxus.request) == "function" then return fluxus.request end
end
local function httpGet(url)
    local requestFn = requestFunction()
    if not requestFn then return game:HttpGet(url) end
    local response = requestFn({ Url = url, Method = "GET", Headers = { Accept = "application/json" } })
    if type(response) == "string" then return response end
    if type(response) == "table" then
        local statusCode = tonumber(response.StatusCode or response.Status or 200) or 0
        if statusCode >= 200 and statusCode < 300 and type(response.Body) == "string" then
            return response.Body
        end
        error("HTTP " .. tostring(statusCode))
    end
    error("HTTP response khong hop le")
end
local function loadVisitedServers()
    local ordered, seen = {}, {}
    local ok, saved = pcall(function()
        return TeleportService:GetTeleportSetting("EventMagnetVisitedV2")
    end)
    if ok and type(saved) == "table" then
        for _, id in ipairs(saved) do
            if type(id) == "string" and not seen[id] then
                seen[id] = true; table.insert(ordered, id)
            end
        end
    end
    if game.JobId ~= "" and not seen[game.JobId] then
        seen[game.JobId] = true; table.insert(ordered, game.JobId)
    end
    return ordered, seen
end
local function saveVisitedServer(ordered, seen, id)
    if type(id) == "string" and not seen[id] then
        seen[id] = true; table.insert(ordered, id)
    end
    while #ordered > 30 do
        local removed = table.remove(ordered, 1)
        seen[removed] = nil
    end
    pcall(function() TeleportService:SetTeleportSetting("EventMagnetVisitedV2", ordered) end)
end
local function findHopCandidates(token)
    local ordered, seen = loadVisitedServers()
    local candidates, cursor, lastError = {}, nil, "Khong co server phu hop"
    for _ = 1, config.HopMaxPages do
        if not actionIsCurrent("hop", token) or hasLiveMagnetized() then return nil, ordered, seen, "Da huy" end
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100", game.PlaceId)
        if cursor and cursor ~= "" then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
        local response
        for attempt = 1, config.HopRequestRetries do
            local ok, value = pcall(function() return HttpService:JSONDecode(httpGet(url)) end)
            if ok and type(value) == "table" and type(value.data) == "table" then response = value; break end
            lastError = tostring(value)
            if attempt < config.HopRequestRetries then task.wait(attempt) end
        end
        if not response then break end
        for _, server in ipairs(response.data) do
            local id, playing, maximum = server.id, tonumber(server.playing), tonumber(server.maxPlayers)
            if type(id) == "string" and playing and maximum and playing < maximum
                and playing <= config.TargetExistingPlayers and not seen[id] then
                table.insert(candidates, { id = id, playing = playing,
                    ping = tonumber(server.ping) or math.huge, fps = tonumber(server.fps) or 0 })
            end
        end
        cursor = response.nextPageCursor
        if #candidates >= config.HopCandidates or not cursor or cursor == "" then break end
    end
    table.sort(candidates, function(a, b)
        if a.playing ~= b.playing then return a.playing < b.playing end
        if a.ping ~= b.ping then return a.ping < b.ping end
        return a.fps > b.fps
    end)
    if #candidates == 0 then return nil, ordered, seen, lastError end
    return candidates, ordered, seen
end
local function startHop()
    if hop.busy or hop.checked or action.kind then return false end
    local token = beginAction("hop")
    if not token then return false end
    hop.busy, hop.status = true, "Dang tim server <= " .. config.TargetExistingPlayers .. " nguoi"
    releaseMovement()
    task.spawn(function()
        local candidates, ordered, seen, findError = findHopCandidates(token)
        if not actionIsCurrent("hop", token) then return end
        if not candidates then
            hop.busy, hop.retryAt = false, os.clock() + config.HopRetryDelay
            hop.status = "Khong tim thay server: " .. short(findError, 80)
            log("HOP", hop.status)
            endAction("hop", token)
            return
        end
        local attempts = math.min(#candidates, config.HopCandidates)
        for index = 1, attempts do
            if not actionIsCurrent("hop", token) or hasLiveMagnetized()
                or #ownedFruitTools() > 0 then break end
            local candidate = candidates[index]
            saveVisitedServer(ordered, seen, candidate.id)
            hop.status = "Thu server " .. candidate.playing .. " nguoi"
            local failed, started, failureMessage = false, false, nil
            local failedConnection = TeleportService.TeleportInitFailed:Connect(function(who, _, message)
                if who == player then failed, failureMessage = true, message end
            end)
            local teleportConnection = player.OnTeleport:Connect(function(state)
                if state == Enum.TeleportState.Started or state == Enum.TeleportState.InProgress then started = true end
            end)
            local ok, callError = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, candidate.id, player)
            end)
            if not ok then failed, failureMessage = true, callError end
            local deadline = os.clock() + config.HopTeleportTimeout
            while actionIsCurrent("hop", token) and not failed and not started
                and os.clock() < deadline do task.wait(0.2) end
            failedConnection:Disconnect(); teleportConnection:Disconnect()
            if started then return end
            if not actionIsCurrent("hop", token) then return end
            if not failed then
                failureMessage = "Teleport timeout"
                break
            end
            log("HOP", "That bai: " .. short(failureMessage, 100))
        end
        if actionIsCurrent("hop", token) then
            hop.busy, hop.retryAt = false, os.clock() + config.HopRetryDelay
            hop.status = "Cho thu hop lai"
            endAction("hop", token)
        end
    end)
    return true
end

local islandMode = sea == 1 and config.Sea1IslandMode and config.Patrol
-- Explicit groups: a completed island cannot be re-added by a new spawn marker.
-- Sky regions at different elevations are separate stops to allow streaming.
local sea1Islands = {
    ["Bandit"] = "Starter Pirate",
    ["Monkey"] = "Jungle", ["Gorilla"] = "Jungle",
    ["Pirate"] = "Pirate Village", ["Brute"] = "Pirate Village",
    ["Desert Bandit"] = "Desert", ["Desert Officer"] = "Desert",
    ["Snow Bandit"] = "Frozen Village", ["Snowman"] = "Frozen Village",
    ["Chief Petty Officer"] = "Marine Fortress",
    ["Sky Bandit"] = "Skylands Lower", ["Dark Master"] = "Skylands Lower",
    ["God's Guard"] = "Skylands Lower",
    ["Prisoner"] = "Prison", ["Dangerous Prisoner"] = "Prison",
    ["Toga Warrior"] = "Colosseum", ["Gladiator"] = "Colosseum",
    ["Mil. Soldier"] = "Magma Village", ["Mil. Spy"] = "Magma Village",
    ["Fishman Warrior"] = "Underwater City", ["Fishman Commando"] = "Underwater City",
    ["Shanda"] = "Skylands Upper", ["Royal Squad"] = "Skylands Upper",
    ["Royal Soldier"] = "Skylands Upper",
    ["Galley Pirate"] = "Fountain City", ["Galley Captain"] = "Fountain City",
}
local function islandAt(position)
    local name, distance = nil, 1500
    for _, row in ipairs(seedRoutes[1]) do
        local delta = (row[2] - position).Magnitude
        if delta < distance then name, distance = sea1Islands[row[1]], delta end
    end
    -- Extra regions discovered from live markers use their own anchor.
    for _, point in ipairs(patrol.points) do
        local delta = (point.position - position).Magnitude
        if delta < distance then name, distance = point.name, delta end
    end
    return name
end
local function addPatrolPoint(name, position, source)
    if typeof(position) ~= "Vector3" then return false end
    for _, coordinate in ipairs({position.X, position.Y, position.Z}) do
        if coordinate ~= coordinate or math.abs(coordinate) == math.huge then return false end
    end
    if islandMode then
        name = sea1Islands[name] or islandAt(position) or ("Khu spawn " .. short(name, 30)
            .. " @" .. math.floor(position.X) .. "," .. math.floor(position.Z))
    end
    for _, point in ipairs(patrol.points) do
        if islandMode and point.name == name then return false end
        if (point.position - position).Magnitude < 35 then return false end
    end
    table.insert(patrol.points, { name = short(name, 80), position = position,
        source = source, visited = 0, retryAt = 0 })
    return true
end
function api.AddPatrolPoint(name, position)
    if not alive then return false end
    return addPatrolPoint(name, position, "manual")
end
function api.GetPatrol()
    local points, visited = {}, 0
    for _, point in ipairs(patrol.points) do
        if point.visited == patrol.pass then visited = visited + 1 end
        table.insert(points, { name = point.name, position = point.position,
            source = point.source, visited = point.visited == patrol.pass, retryAt = point.retryAt })
    end
    return { pass = patrol.pass, visited = visited, total = #points, points = points,
        current = patrol.current and patrol.current.name or nil,
        mode = islandMode and "island" or "camp" }
end
function api.GetState()
    local owned, blocked, waiting = getStoreSummary()
    return {
        alive = alive, enabled = enabled, sea = sea, action = action.kind,
        status = status, magnetized = #targets, worldFruits = #api.GetFruits(),
        ownedFruits = #owned, blockedFruits = blocked, waitingStore = waiting,
        portal = portal.lastResult, portalDestination = portal.destination,
        hopChecked = hop.checked, hopBusy = hop.busy, hopStatus = hop.status,
        playerCount = #Players:GetPlayers(), session = sessionSerial,
    }
end
for _, row in ipairs(seedRoutes[sea] or {}) do addPatrolPoint(row[1], row[2], "local database") end
local function refreshSpawnPoints()
    local origin = workspace:FindFirstChild("_WorldOrigin")
    local folder = origin and origin:FindFirstChild("EnemySpawns")
    if not folder then return end
    for _, instance in ipairs(folder:GetDescendants()) do
        if instance:IsA("BasePart") then
            addPatrolPoint(instance.Name, instance.Position, "EnemySpawns")
        elseif instance:IsA("Model") and instance:FindFirstChildWhichIsA("BasePart", true) then
            addPatrolPoint(instance.Name, instance:GetPivot().Position, "EnemySpawns")
        end
    end
end
refreshSpawnPoints()
local function finishPatrolPoint(reason, failed)
    local point = patrol.current
    if point then
        point.visited = patrol.pass
        if failed then point.retryAt = os.clock() + config.RetryDelay end
        log("PATROL", point.name .. ": " .. reason)
    end
    patrol.current, patrol.arrived, patrol.started = nil, nil, nil
    patrol.seenAt = nil
    patrol.best = math.huge
    releaseMovement()
end
local function patrolStep(root, humanoid, dt, now)
    if not config.Patrol then
        releaseMovement(); status = "Cho quai Magnetized; tuan tra dang tat"; return
    end
    if not patrol.current then
        local nearest, remaining = math.huge, false
        for _, point in ipairs(patrol.points) do
            if point.visited ~= patrol.pass then
                remaining = true
                local distance = (point.position - root.Position).Magnitude
                if point.retryAt <= now and distance < nearest then
                    patrol.current, nearest = point, distance
                end
            end
        end
        if not patrol.current then
            releaseMovement()
            if #patrol.points == 0 then
                status = "Chua co diem spawn; cho EnemySpawns hoac AddPatrolPoint"
            elseif not remaining then
                patrol.pass = patrol.pass + 1
                status = "Bat dau vong tuan tra " .. patrol.pass
            else
                status = "Cho cooldown cac bai bi ket..."
            end
            return
        end
        log("PATROL", "Den " .. patrol.current.name .. " | vong " .. patrol.pass)
    end
    local point = patrol.current
    local destination = point.position + Vector3.new(0, config.PatrolHeight, 0)
    local distance = (destination - root.Position).Magnitude
    if not patrol.started then
        patrol.started, patrol.progress, patrol.best = now, now, distance
        patrol.deadline = now + math.max(45, distance / config.Speed * 3 + 30)
    end
    if distance <= config.PatrolArrival then
        if not patrol.arrived then patrol.arrived = now end
        local elapsed = now - patrol.arrived
        local seenNPC = false
        for model in pairs(mobs) do
            local h, r = livingNPC(model)
            if h and (r.Position - point.position).Magnitude <= config.SpawnRadius then
                seenNPC = true; break
            end
        end
        status = "Quan sat " .. point.name .. " | " .. math.floor(elapsed)
            .. "s | " .. (seenNPC and "co quai" or "cho spawn")
        if seenNPC then patrol.seenAt = patrol.seenAt or now else patrol.seenAt = nil end
        local settleTime = islandMode and config.SpawnSettleTime or config.CampSettleTime
        local settled = patrol.seenAt and now - patrol.seenAt >= settleTime
        local waitTime = islandMode and config.IslandWait or config.CampSettleTime
        local timeout = islandMode and config.IslandSpawnTimeout or config.SpawnTimeout
        if elapsed >= timeout or (settled and elapsed >= waitTime) then
            local reason = islandMode and "khong con Magnetized hop le; bo qua dao trong vong nay"
                or (seenNPC and "da quan sat; sang bai tiep" or "het cho spawn; thu lai vong sau")
            finishPatrolPoint(reason)
            return
        end
        patrol.progress, patrol.best = now, distance
    else
        patrol.arrived = nil -- Server correction does not count as waiting at camp.
        patrol.seenAt = nil
        if distance < patrol.best - 2 then patrol.best, patrol.progress = distance, now end
        if now - patrol.progress > config.NoProgressTimeout or now > patrol.deadline then
            finishPatrolPoint("khong den duoc; tam bo qua", true); return
        end
        status = "Tuan tra " .. point.name .. " | " .. math.ceil(distance) .. " studs"
    end
    if distance > config.PatrolArrival and tryStartPortal(point.position, root, humanoid) then
        status = "Portal den gan " .. point.name
        return
    end
    flyTo(root, humanoid, destination, dt)
end

local function equip(character, humanoid)
    local function matches(tool)
        return tool:IsA("Tool") and (tool.ToolTip == config.Weapon or tool.Name == config.Weapon)
    end
    for _, tool in ipairs(character:GetChildren()) do
        if matches(tool) then return tool end
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if matches(tool) then humanoid:EquipTool(tool); return tool end
        end
    end
end
local function attack(mobRoot, tool)
    -- Same explicit combat remote names/argument shape used by auto_farm_level.lua.
    -- Server acceptance is not assumed; HP progress is monitored separately.
    local modules = RS:FindFirstChild("Modules")
    local net = modules and modules:FindFirstChild("Net")
    local register = net and net:FindFirstChild("RE/RegisterAttack")
    local hit = net and net:FindFirstChild("RE/RegisterHit")
    if register and register:IsA("RemoteEvent") and hit and hit:IsA("RemoteEvent") then
        register:FireServer(0)
        hit:FireServer(mobRoot, {})
    else
        tool:Activate()
    end
end

local function nearestFruit(root, now)
    local best, distance
    for instance, record in pairs(fruitRecords) do
        if instance:IsDescendantOf(workspace) and record.part and record.part.Parent
            and record.retryAt <= now then
            local candidateDistance = (record.part.Position - root.Position).Magnitude
            if not distance or candidateDistance < distance then
                best, distance = record, candidateDistance
            end
        end
    end
    return best, distance
end
local function failFruit(record, reason)
    record.attempts = record.attempts + 1
    if record.attempts >= config.FruitPickupAttempts then
        record.retryAt, record.attempts = os.clock() + config.FruitRetryDelay, 0
    end
    log("FRUIT", record.name .. ": " .. reason)
    fruitTask.target, fruitTask.started = nil, nil
    releaseMovement()
end
local function startFruitPickup(record, root, humanoid)
    local token = beginAction("pickup")
    if not token then return false end
    releaseMovement()
    task.spawn(function()
        local snapshot = {}
        for _, item in ipairs(ownedFruitTools()) do snapshot[item] = true end
        local oldCanTouch = {}
        local found, touched, aborted = nil, false, false
        local ok, runtimeError = xpcall(function()
            if not actionIsCurrent("pickup", token) or hasLiveMagnetized() then
                aborted = true; return
            end
            local character = player.Character
            if not character or not humanoid.Parent or not root.Parent then error("Character da thay doi") end
            pcall(function()
                humanoid:UnequipTools()
                humanoid.Sit, humanoid.PlatformStand = false, false
            end)
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    oldCanTouch[part] = part.CanTouch
                    pcall(function() part.CanTouch = true end)
                end
            end
            local handle = record.part
            touched = pcall(function()
                root.CFrame = handle.CFrame
                root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
                if type(firetouchinterest) == "function" then
                    firetouchinterest(root, handle, 0); task.wait(0.03); firetouchinterest(root, handle, 1)
                    local right = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")
                    local left = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
                    for _, foot in pairs({ right, left }) do
                        if foot then firetouchinterest(foot, handle, 0); task.wait(0.02); firetouchinterest(foot, handle, 1) end
                    end
                end
                humanoid.Jump = true
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.04)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
            if not touched then return end
            local deadline = os.clock() + config.FruitPickupConfirm
            while actionIsCurrent("pickup", token) and os.clock() < deadline do
                for _, item in ipairs(ownedFruitTools()) do
                    if not snapshot[item] and ownedFruitMatches(record, item) then found = item; break end
                end
                if found then break end
                task.wait(0.1)
            end
        end, function(err) return tostring(err) end)
        pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
        for part, oldValue in pairs(oldCanTouch) do
            if part.Parent then pcall(function() part.CanTouch = oldValue end) end
        end
        if not actionIsCurrent("pickup", token) then return end
        endAction("pickup", token)
        if aborted then return end
        if not ok then
            failFruit(record, "Loi pickup: " .. short(runtimeError, 80))
        elseif not touched then
            failFruit(record, "Khong kich hoat duoc touch")
        elseif found then
            log("FRUIT", "Da xac nhan nhat: " .. short(found.Name, 80))
            fruitTask.target, fruitTask.started = nil, nil
        else
            failFruit(record, "Da cham nhung chua vao inventory")
        end
    end)
    return true
end
local function fruitStep(root, humanoid, dt, now)
    if not config.FruitEnabled then return false end
    local record = fruitTask.target and fruitRecords[fruitTask.target]
    if not record or not record.instance:IsDescendantOf(workspace)
        or not record.part or not record.part.Parent then
        record = nearestFruit(root, now)
        fruitTask.target = record and record.instance or nil
        fruitTask.started, fruitTask.progress, fruitTask.best = now, now, math.huge
    end
    if not record then return false end
    local distance = (record.part.Position - root.Position).Magnitude
    if distance < fruitTask.best - 2 then
        fruitTask.best, fruitTask.progress = distance, now
    elseif now - fruitTask.progress > config.NoProgressTimeout then
        failFruit(record, "Di chuyen khong tien trien")
        return true
    end
    if distance <= config.FruitPickupDistance then
        status = "Dang nhat " .. short(record.name, 60)
        startFruitPickup(record, root, humanoid)
        return true
    end
    if tryStartPortal(record.part.Position, root, humanoid) then
        status = "Portal den Fruit " .. short(record.name, 50)
        return true
    end
    status = "Den Fruit " .. short(record.name, 55) .. " | " .. math.ceil(distance) .. " studs"
    flyTo(root, humanoid, record.part.Position + Vector3.new(0, 2, 0), dt)
    return true
end

local function farmStep(dt)
    if not enabled then return end
    local now = os.clock()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = rootOf(character)
    if not humanoid or humanoid.Health <= 0 or not root then
        resetTarget(); status = "Cho respawn..."; return
    end
    hop.readyAt = hop.readyAt or (now + config.StartupDelay)
    if humanoid.Sit or humanoid.SeatPart then
        resetTarget(); status = "Hay roi ghe/thuyen de farm"; return
    end
    if hasLiveMagnetized() and action.kind
        and not (action.kind == "portal" and portal.forCombat) then
        cancelAction("nhuong Magnetized")
    end
    if action.kind then
        status = action.kind == "portal" and ("Dang mo Portal: " .. tostring(portal.destination))
            or action.kind == "hop" and hop.status
            or action.kind == "store" and "Dang xac nhan luu Fruit"
            or "Dang xac nhan nhat Fruit"
        return
    end
    local mobHumanoid, mobRoot = livingNPC(target)
    if target and (not mobHumanoid or not isMagnetized(target, mobHumanoid)) then
        resetTarget("chet / mat muc tieu / het Magnetized (khong xac nhan reward)")
        mobHumanoid, mobRoot = nil, nil
    end
    if not target then
        -- Sea 1 remains island-scoped. Sea 2/3 may acquire any replicated
        -- Magnetized target and always preempt every lower-priority task.
        local nearest = math.huge
        if not islandMode or patrol.current then
            for _, model in ipairs(targets) do
                local h, r = livingNPC(model)
                local onCurrentIsland = not islandMode or (r and patrol.current
                    and islandAt(r.Position) == patrol.current.name)
                if h and onCurrentIsland and isMagnetized(model, h) and (skipped[model] or 0) <= now then
                    local distance = (r.Position - root.Position).Magnitude
                    if distance < nearest then target, nearest = model, distance end
                end
            end
        end
        if not target then
            local owned, blocked, waiting = getStoreSummary()
            if #owned > 0 and config.StoreFruit then
                for _, item in ipairs(owned) do
                    if startStore(item, false) then
                        status = "Dang luu " .. short(item.Name, 60)
                        return
                    end
                end
            end

            if not config.StartupHop then
                hop.checked, hop.status = true, "Hop dau phien dang tat"
            elseif not hop.checked then
                if now < hop.readyAt then
                    status = "Cho on dinh dau phien " .. math.ceil(hop.readyAt - now) .. "s"
                    return
                elseif #Players:GetPlayers() <= config.CurrentPlayerLimit then
                    hop.checked, hop.status = true, "Da o server <= " .. config.CurrentPlayerLimit .. " nguoi"
                    serverChoiceMemory[game.JobId] = true
                    log("HOP", hop.status)
                elseif #owned > 0 then
                    hop.status = "Chan hop: con " .. #owned .. " Fruit chua luu"
                    status = hop.status .. (blocked > 0 and " (can RetryStore sau khi xu ly kho)" or "")
                elseif now >= hop.retryAt and startHop() then
                    status = hop.status
                    return
                end
            end

            -- Do not collect more Fruit while an owned Fruit cannot be stored;
            -- patrol still continues so Magnetized farming is never blocked.
            if #owned == 0 and hop.checked and fruitStep(root, humanoid, dt, now) then return end
            patrolStep(root, humanoid, dt, now)
            return
        end
        patrol.arrived, patrol.started, patrol.best = nil, nil, math.huge
        patrol.seenAt = nil
        mobHumanoid, mobRoot = livingNPC(target)
        targetSince, lastDamage, lastProgress = now, now, now
        lastHP, bestDistance, attackSince = mobHumanoid.Health, math.huge, nil
        log("FARM", "Chon " .. target.Name)
    end
    if now - targetSince > config.TargetTimeout then
        resetTarget("timeout; tam bo qua", true); return
    end
    local distance = (mobRoot.Position - root.Position).Magnitude
    if mobHumanoid.Health < lastHP then lastDamage = now end
    lastHP = mobHumanoid.Health
    if distance < bestDistance - 2 then bestDistance, lastProgress = distance, now end
    if distance > config.AttackRange then
        attackSince = nil
        if now - lastProgress > config.NoProgressTimeout then
            resetTarget("di chuyen khong tien trien; tam bo qua", true); return
        end
    else
        lastProgress, bestDistance = now, distance
        if not attackSince then attackSince, lastDamage = now, now end
        if now - lastDamage > config.NoDamageTimeout then
            resetTarget("HP khong giam; kiem tra vu khi/combat/server", true); return
        end
    end
    local destination = mobRoot.Position + Vector3.new(0, config.HoverHeight, 2)
    if distance > config.AttackRange
        and tryStartPortal(mobRoot.Position, root, humanoid, true) then
        status = "Portal den Magnetized " .. short(target.Name, 45)
        return
    end
    flyTo(root, humanoid, destination, dt, mobRoot.Position)
    status = "Farm " .. short(target.Name, 65) .. " | HP " .. math.ceil(mobHumanoid.Health)
    attackClock = attackClock + dt
    if distance <= config.AttackRange and attackClock >= config.AttackInterval then
        attackClock = 0
        local tool = equip(character, humanoid)
        if tool then attack(mobRoot, tool) else status = "Khong tim thay vu khi: " .. config.Weapon end
    end
end

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "EventMagnetFarmUI", false, 100
local panel = Instance.new("Frame")
panel.Size, panel.Position = UDim2.fromOffset(400, 360), UDim2.new(0, 12, 0.5, -180)
panel.BackgroundColor3, panel.Parent = Color3.fromRGB(24, 28, 36), gui
local function label(y, height, size)
    local item = Instance.new("TextLabel")
    item.Position, item.Size = UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, height)
    item.BackgroundTransparency, item.TextSize = 1, size
    item.TextColor3, item.Font = Color3.fromRGB(225, 233, 245), Enum.Font.Code
    item.TextXAlignment, item.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
    item.TextWrapped, item.Parent = true, panel
    return item
end
label(10, 25, 17).Text = "MAGNETIZED FARM | 190 default"
local statusLabel, listLabel, eventLabel = label(40, 55, 14), label(100, 100, 13), label(205, 95, 12)
local function button(text, x, width)
    local item = Instance.new("TextButton")
    item.Text, item.Position, item.Size = text, UDim2.fromOffset(x, 318), UDim2.fromOffset(width, 30)
    item.BackgroundColor3, item.TextColor3 = Color3.fromRGB(45, 67, 85), Color3.new(1, 1, 1)
    item.TextSize, item.Parent = 14, panel
    return item
end
local toggle, close = button("DUNG FARM", 10, 230), button("THOAT", 250, 140)
function api.Destroy()
    if not alive then return end
    cancelAction("Destroy")
    alive, enabled = false, false
    resetTarget()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    for _, record in pairs(remotes) do
        if record.connection then record.connection:Disconnect() end
        record.rename:Disconnect(); record.destroy:Disconnect()
    end
    remotes, mobs, targets = {}, {}, {}
    local fruitInstances = {}
    for instance in pairs(fruitRecords) do table.insert(fruitInstances, instance) end
    for _, instance in ipairs(fruitInstances) do removeFruitRecord(instance) end
    gui:Destroy()
    if env.EventMagnetFarm == api then env.EventMagnetFarm = nil end
end
connect(toggle.MouseButton1Click, function() api.SetEnabled(not enabled) end)
connect(close.MouseButton1Click, api.Destroy)
connect(player.CharacterRemoving, function()
    cancelAction("CharacterRemoving"); resetTarget(); hop.readyAt = nil; status = "Cho respawn..."
end)
connect(player.CharacterAdded, function()
    cancelAction("CharacterAdded"); resetTarget(); scanClock = config.ScanInterval
end)
connect(RunService.Stepped, function()
    if not moveRoot or not enabled then return end
    local character = player.Character
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if collisionState[part] == nil then collisionState[part] = part.CanCollide end
            part.CanCollide = false
        end
    end
end)
connect(RunService.Heartbeat, function(dt)
    local ok, err = pcall(function()
        scanClock, uiClock = scanClock + dt, uiClock + dt
        fruitScanClock, fruitESPClock = fruitScanClock + dt, fruitESPClock + dt
        patrol.refresh = patrol.refresh + dt
        if patrol.refresh >= 5 then patrol.refresh = 0; refreshSpawnPoints() end
        if scanClock >= config.ScanInterval then scanClock = 0; scanMobs() end
        if fruitScanClock >= config.FruitScanInterval then fruitScanClock = 0; refreshFruits() end
        if fruitESPClock >= config.FruitESPUpdateInterval then
            fruitESPClock = 0
            updateFruitESP(rootOf(player.Character))
        end
        farmStep(dt)
        if uiClock >= 0.3 then
            uiClock = 0
            toggle.Text = enabled and "DUNG FARM (van do event)" or "BAT FARM"
            statusLabel.Text = status
            local visited = 0
            for _, point in ipairs(patrol.points) do
                if point.visited == patrol.pass then visited = visited + 1 end
            end
            local owned, blocked, waiting = getStoreSummary()
            local fruitCount = 0
            for _ in pairs(fruitRecords) do fruitCount = fruitCount + 1 end
            local rows = { "Vong " .. patrol.pass .. (islandMode and " | Dao " or " | Bai ") .. visited .. "/" .. #patrol.points,
                "Magnetized: " .. #targets .. " | Event: " .. eventCount .. " | Nhan: " .. deliveryCount,
                "Fruit map: " .. fruitCount .. " | Giu: " .. #owned
                    .. " | Cho/chan: " .. waiting .. "/" .. blocked,
                "Portal: " .. short(portal.lastResult, 52), "Hop: " .. short(hop.status, 55) }
            for i = 1, math.min(#targets, 2) do rows[#rows + 1] = short(targets[i].Name, 52) end
            listLabel.Text = table.concat(rows, "\n")
            local recent = {}
            for i = math.max(1, #logs - 2), #logs do
                recent[#recent + 1] = "[" .. logs[i].kind .. "] " .. short(logs[i].text, 80)
            end
            eventLabel.Text = table.concat(recent, "\n")
        end
    end)
    if not ok then
        api.SetEnabled(false)
        status = "Loi: da dung farm. Xem GetLogs()."
        statusLabel.Text = status
        if os.clock() - lastError > 5 then lastError = os.clock(); log("ERROR", err) end
    end
end)
-- No unbounded WaitForChild: a failed GUI setup must not leave an invisible farmer.
local playerGui = player:FindFirstChildOfClass("PlayerGui")
    or player:WaitForChild("PlayerGui", 15)
if not playerGui then api.Destroy(); error("PlayerGui chua san sang; hay chay lai sau khi vao game") end
gui.Parent = playerGui
log("INFO", "Chi quan sat event client; khong xac nhan reward hoac event rieng server")
return api
