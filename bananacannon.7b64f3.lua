-- =========================================================================
-- the fresh prince's bananacannon 2.0
-- =========================================================================
-- a portable tabletop simulator tile for kibo, uktabi prince
--   * spawns banana tokens from a self-contained json template (no external
--     object needed) and fires them from a cannon mod on the table
--   * auto-discovers the cannon by name/description keyword + button scan;
--     supports a guid override for pinned setups
--   * audio system: per-clip durations, sequential first pass, shuffled
--     each cycle after that, with a mute toggle
--   * BANANAPOCALYPSE: 1500 bananas. cannon volleys. only tested on monster
--     hardware lmao. two-click confirmation required. you've been warned.
-- designed as a saved object — drop it on any table with a compatible cannon.
-- project lives at https://github.com/infomanc3r/bananacannon star it pls
-- =========================================================================


-- ====================== CONFIGURATION ====================================

-- cannon settings
local CANNON_GUID_OVERRIDE = ""    -- set to a guid to skip auto-discovery
local FIRE_FN              = "FireCannon"

local MUZZLE_OFFSET_LOW  = {x = -0.2, y = 5.2, z = 0.8}
local MUZZLE_OFFSET_HIGH = {x =  0.2, y = 5.6, z = 2.1}

local CANNON_KEYWORDS = {"cannon", "mortar", "launcher"}

local NUM_BANANAS = 4
local SPREAD      = 0.15
local FIRE_DELAY  = 1.2

-- bananapocalypse settings
local APOC_TOTAL_BANANAS   = 1500
local APOC_BATCH_SIZE      = 10
local APOC_BATCH_INTERVAL  = 0.06
local APOC_SPAWN_HEIGHT    = 35
local APOC_SPAWN_RADIUS    = 45
local APOC_LAUNCH_POWER    = 45
local APOC_CANNON_VOLLEYS  = 6
local APOC_VOLLEY_INTERVAL = 0.5


-- ====================== DATA TABLES ======================================

local FIRE_CLIPS = {
    -- sequential on the first pass, shuffled each cycle after that
    {url = "https://steamusercontent-a.akamaihd.net/ugc/17464361856288791916/912500A2908AEA5554CF3145D2DF39A6A387C675/", duration = 9.0},
    {url = "https://steamusercontent-a.akamaihd.net/ugc/15284110437615992279/2E0AA61003500EAEAA2591295EA8263D64BAD273/", duration = 8.0},
    {url = "https://steamusercontent-a.akamaihd.net/ugc/12444951192700314982/38F88E9843FCBB00B80D073D47935D1B6B7C3298/", duration = 8.0},
    {url = "https://steamusercontent-a.akamaihd.net/ugc/11497068278698600664/6492946E0C8DDB6D55B8B4954B7A19C0E31C7603/", duration = 0.8},
    {url = "https://steamusercontent-a.akamaihd.net/ugc/16915126186584143656/A0508F46B9FE683513EA58048E040363D1815F1E/", duration = 1.0},
    {url = "https://steamusercontent-a.akamaihd.net/ugc/13072222960545550689/AB079C66F1714FAFF4DF7CD68850F5197E8A59C8/", duration = 3.0}
}

local APOC_CLIPS = {
    {url = "https://steamusercontent-a.akamaihd.net/ugc/12976938159338610524/142F7E594CFFC4161E34D23D522B95D311533A78/", duration = 2.0}
}

local BANANA_JSON = [[
{
  "Name": "Custom_Model",
  "Transform": {
    "posX": 0, "posY": 0, "posZ": 0,
    "rotX": 0, "rotY": 0, "rotZ": 0,
    "scaleX": 10.25, "scaleY": 10.25, "scaleZ": 10.25
  },
  "Nickname": "Banana",
  "Description": "",
  "ColorDiffuse": { "r": 1.0, "g": 1.0, "b": 1.0 },
  "Locked": false,
  "Grid": true,
  "Snap": true,
  "Autoraise": true,
  "Sticky": true,
  "Tooltip": true,
  "CustomMesh": {
    "MeshURL": "https://steamusercontent-a.akamaihd.net/ugc/16310998189366510187/B312355CF13D5089CEDA85021FA9AB2D8974E3F0/",
    "DiffuseURL": "https://steamusercontent-a.akamaihd.net/ugc/15233023863853110705/47FEF21118301E27B1EEF7CC87606773E6EC1D4E/",
    "NormalURL": "",
    "ColliderURL": "https://steamusercontent-a.akamaihd.net/ugc/10867500380038650254/385C05A0B6A6D0087B815EACFD5FE6F476BAD791/",
    "Convex": true,
    "MaterialIndex": 3,
    "TypeIndex": 0,
    "CustomShader": {
      "SpecularColor": { "r": 1.0, "g": 1.0, "b": 1.0 },
      "SpecularIntensity": 0.0,
      "SpecularSharpness": 2.0,
      "FresnelStrength": 0.0
    },
    "CastShadows": true
  }
}
]]


-- ====================== MODULE STATE =====================================

local cachedCannon       = nil
local audioMuted         = false
local fireQueue          = {}
local fireFirstCycleDone = false
local apocQueue          = {}
local apocFirstCycleDone = false
local apocConfirming     = false
local apocRunning        = false


-- ====================== BUTTON LAYOUT ====================================
-- landscape tile: long axis is X, short axis is Z.
-- 3 columns at x = -0.75, 0, 0.75
-- 3 rows at z = -0.6, 0, 0.6
-- button size: 550 x 260 (tuned to fit a 745x460 landscape tile image)

function onLoad()

    self.setName("bananacannon")
    self.setDescription("[b]the fresh prince's[/b]\nbananacannon 2.0")

    -- top row: FIRE BANANAS! (the star of the show)
    self.createButton({
        click_function = "fireBananas",
        function_owner = self,
        label          = "FIRE\nBANANAS!",
        position       = {-0.75, 0.5, -0.6},
        width = 550, height = 260,
        font_size      = 95,
        color          = {0.1, 0.05, 0, 0.9},
        font_color     = {1, 0.85, 0.1, 1},
        tooltip        = "Spawn " .. NUM_BANANAS .. " bananas in the cannon and fire!"
    })

    -- top row right
    self.createButton({
        click_function = "spawnOne",
        function_owner = self,
        label          = "Spawn One",
        position       = {0.75, 0.5, -0.6},
        width = 550, height = 260,
        font_size      = 95,
        color          = {0, 0, 0, 0.9}, font_color = {1, 1, 1, 1},
        tooltip        = "Spawn a single banana (e.g., for mana production)"
    })

    -- middle row
    self.createButton({
        click_function = "rediscover",
        function_owner = self,
        label          = "Find Cannon",
        position       = {-0.75, 0.5, 0},
        width = 550, height = 260,
        font_size      = 95,
        color          = {0, 0, 0, 0.9}, font_color = {1, 1, 1, 1},
        tooltip        = "Re-scan the table for the cannon"
    })

    -- middle row right
    self.createButton({
        click_function = "spawnPile",
        function_owner = self,
        label          = "Spawn Pile",
        position       = {0.75, 0.5, 0},
        width = 550, height = 260,
        font_size      = 95,
        color          = {0, 0, 0, 0.9}, font_color = {1, 1, 1, 1},
        tooltip        = "Spawn " .. NUM_BANANAS .. " bananas next to this panel"
    })

    -- bottom row
    self.createButton({
        click_function = "toggleMute",
        function_owner = self,
        label          = "Mute Audio",
        position       = {-0.75, 0.5, 0.6},
        width = 550, height = 260,
        font_size      = 95,
        color          = {0, 0, 0, 0.9}, font_color = {1, 1, 1, 1},
        tooltip        = "Toggle banana cannon sound effects on/off"
    })

    --[[aim at me shelved for now
    self.createButton({
        click_function = "aimAtMe",
        function_owner = self,
        label          = "Aim At Me",
        position       = {-0.75, 0.5, 0.6},
        width = 550, height = 260,
        font_size      = 95,
        color          = {0, 0, 0, 0.9}, font_color = {1, 1, 1, 1},
        tooltip        = "Rotate the cannon to point at this panel"
    })
    --]]

    -- bottom row right
    self.createButton({
        click_function = "cleanupBananas",
        function_owner = self,
        label          = "Clean Up",
        position       = {0.75, 0.5, 0.6},
        width = 550, height = 260,
        font_size      = 95,
        color          = {0, 0, 0, 0.9}, font_color = {1, 1, 1, 1},
        tooltip        = "Destroy all bananas on the table"
    })

    -- flip side: bananapocalypse (the secret star of the show)
    self.createButton({
        click_function = "tryBananapocalypse",
        function_owner = self,
        label          = "BANANAPOCALYPSE",
        position       = {0, -0.05, 0},
        rotation       = {0, 0, 180},
        width = 1600, height = 500,
        font_size      = 180,
        color          = {0.6, 0, 0, 1},
        font_color     = {1, 1, 0, 1},
        tooltip        = "DO NOT PRESS UNLESS YOU HAVE WON WITH KIBO."
    })

end


-- ============== PRIMARY ACTIONS ==========================================

function fireBananas(_obj, player_color, _alt_click)
    playFireClip()
    if cachedCannon == nil then discoverCannon() end

    if cachedCannon == nil then
        broadcastToAll(
            "[Kibo Cannon] No cannon found. Spawning a pile instead.",
            {1, 0.7, 0.3}
        )
        spawnPile(_obj, player_color, _alt_click)
        return
    end

    broadcastToAll("Kibo summons " .. NUM_BANANAS .. " bananas!", {1, 0.85, 0.1})

    if not cachedCannon.getLock() then
        cachedCannon.setLock(true)
    end

    spawnBananasInMuzzle(cachedCannon, NUM_BANANAS)

    Wait.time(function()
        local cannon = cachedCannon
        if cannon == nil then return end
        local ok, err = pcall(function() cannon.call(FIRE_FN) end)
        if not ok then
            broadcastToAll("[Kibo Cannon] FireCannon failed: " .. tostring(err), {1, 0.4, 0.4})
        end
    end, FIRE_DELAY)
end


function spawnPile(_obj, _color, _alt_click)
    local pos = self.getPosition()
    local target = {x = pos.x, y = pos.y + 2, z = pos.z + 4}
    broadcastToAll("Everybody grab a banana!", {1, 0.85, 0.1})
    spawnBananaPile(target, NUM_BANANAS)
end


function spawnOne(_obj, _color, _alt_click)
    local pos = self.getPosition()
    local target = {
        x = pos.x,
        y = pos.y + 3,
        z = pos.z + 2.5
    }
    spawnOneBanana(target, math.random() * 360)
end


--[[ NOT CURRENTLY IN USE
function aimAtMe(_obj, _color, _alt_click)
    if cachedCannon == nil then discoverCannon() end
    if cachedCannon == nil then
        broadcastToAll("[Kibo Cannon] No cannon to aim.", {1, 0.7, 0.3})
        return
    end

    local cpos = cachedCannon.getPosition()
    local mpos = self.getPosition()
    local dx = mpos.x - cpos.x
    local dz = mpos.z - cpos.z

    local angleRad = math.atan2(dx, dz)
    local angleDeg = math.deg(angleRad)

    cachedCannon.setLock(false)
    cachedCannon.setRotationSmooth({0, angleDeg, 0}, false, true)

    Wait.time(function()
        if cachedCannon then cachedCannon.setLock(true) end
    end, 1.0)

    broadcastToAll("Cannon aimed at the banana panel.", {0.5, 0.8, 1})
end
]]--


function rediscover(_obj, _color, _alt_click)
    cachedCannon = nil
    discoverCannon()
    if cachedCannon then
        broadcastToAll(
            "[Kibo Cannon] Found cannon: '" .. cachedCannon.getName() .. "'",
            {0.3, 0.9, 0.3}
        )
    else
        broadcastToAll("[Kibo Cannon] No cannon found on this table.", {1, 0.7, 0.3})
    end
end


function cleanupBananas(_obj, _color, _alt_click)
    local count = 0
    for _, obj in ipairs(getObjectsWithTag("kibo_banana")) do
        obj.destruct()
        count = count + 1
    end
    if count > 0 then
        broadcastToAll(
            "[Kibo Cannon] Cleaned up " .. count .. " banana" ..
            (count == 1 and "" or "s") .. ".",
            {0.5, 0.8, 0.5}
        )
    else
        broadcastToAll("[Kibo Cannon] No bananas to clean up.", {0.7, 0.7, 0.7})
    end
end


-- ============== APOCALYPSE FUNCTIONS =====================================

function tryBananapocalypse(_obj, _player_color, _alt_click)
    if apocRunning then
        broadcastToAll("[BANANAPOCALYPSE] Already in progress. Behold.", {1, 0.3, 0.3})
        return
    end

    if not apocConfirming then
        -- first click: arm it and require a second click within 4 seconds
        apocConfirming = true
        broadcastToAll(
            "BANANAPOCALYPSE armed. Click again within 4 seconds to UNLEASH.",
            {1, 0.6, 0}
        )
        Wait.time(function()
            if apocConfirming then
                apocConfirming = false
                broadcastToAll("[BANANAPOCALYPSE] Stand-down. Crisis averted.", {0.7, 0.7, 0.7})
            end
        end, 4.0)
        return
    end

    -- second click within the window: full send
    apocConfirming = false
    bananapocalypse()
end


function bananapocalypse()
    apocRunning = true
    playApocClip()
    broadcastToAll(
        "[UKTABI HAS DECREED] THE BANANAPOCALYPSE BEGINS",
        {1, 0.85, 0.1}
    )

    local batches = math.ceil(APOC_TOTAL_BANANAS / APOC_BATCH_SIZE)
    for batchIdx = 0, batches - 1 do
        local thisBatchSize = math.min(
            APOC_BATCH_SIZE,
            APOC_TOTAL_BANANAS - (batchIdx * APOC_BATCH_SIZE)
        )
        Wait.time(function()
            spawnApocBatch(thisBatchSize)
        end, batchIdx * APOC_BATCH_INTERVAL)
    end

    -- cannon volleys during the rain
    if cachedCannon == nil then discoverCannon() end
    if cachedCannon then
        for volleyIdx = 1, APOC_CANNON_VOLLEYS do
            Wait.time(function()
                fireCannonVolley()
            end, 1.0 + (volleyIdx - 1) * APOC_VOLLEY_INTERVAL)
        end
    end

    -- mark apocalypse over after all batches + buffer
    local totalDuration = (batches * APOC_BATCH_INTERVAL) + 5.0
    Wait.time(function()
        apocRunning = false
        broadcastToAll(
            "[BANANAPOCALYPSE] The rain has ceased. Tally your dead.",
            {0.7, 0.7, 0.7}
        )
    end, totalDuration)
end


function spawnApocBatch(count)
    for i = 1, count do
        -- 25% chance to be a horizontal flinger
        local isFlinger = (math.random(1, 4) == 1)

        local angle = math.random() * 2 * math.pi
        local r     = math.random() * APOC_SPAWN_RADIUS
        local pos   = {
            x = math.cos(angle) * r,
            y = isFlinger and (5 + math.random() * 8) or (APOC_SPAWN_HEIGHT + math.random() * 5),
            z = math.sin(angle) * r
        }
        local rotY = math.random() * 360

        local json = string.gsub(BANANA_JSON, '"posX": 0, "posY": 0, "posZ": 0',
            string.format('"posX": %f, "posY": %f, "posZ": %f', pos.x, pos.y, pos.z))
        json = string.gsub(json, '"rotX": 0, "rotY": 0, "rotZ": 0',
            string.format('"rotX": 0, "rotY": %f, "rotZ": 0', rotY))

        spawnObjectJSON({
            json     = json,
            position = pos,
            sound    = false,
            callback_function = function(spawned)
                spawned.addTag("kibo_banana")
                spawned.addTag("apoc_banana")

                -- defer velocity until the object is physics-ready
                Wait.time(function()
                    if spawned == nil then return end

                    if isFlinger then
                        spawned.addTag("apoc_flinger")
                        local flingAngle = math.random() * 2 * math.pi
                        local flingPower = APOC_LAUNCH_POWER * 1.8
                        spawned.setVelocity({
                            x = math.cos(flingAngle) * flingPower,
                            y = math.random() * 8,
                            z = math.sin(flingAngle) * flingPower
                        })
                        spawned.setAngularVelocity({
                            x = (math.random() - 0.5) * 200,
                            y = (math.random() - 0.5) * 200,
                            z = (math.random() - 0.5) * 200
                        })
                    else
                        spawned.setVelocity({
                            x = (math.random() - 0.5) * APOC_LAUNCH_POWER,
                            y = (math.random() - 0.7) * APOC_LAUNCH_POWER * 0.5,
                            z = (math.random() - 0.5) * APOC_LAUNCH_POWER
                        })
                        spawned.setAngularVelocity({
                            x = (math.random() - 0.5) * 50,
                            y = (math.random() - 0.5) * 50,
                            z = (math.random() - 0.5) * 50
                        })
                    end
                end, 0.5)
            end
        })
    end
end


function fireCannonVolley()
    if cachedCannon == nil then return end

    -- rotate to a random horizontal direction, then load and fire
    cachedCannon.setRotationSmooth({0, math.random() * 360, 0}, false, true)

    Wait.time(function()
        if cachedCannon == nil then return end
        if not cachedCannon.getLock() then
            cachedCannon.setLock(true)
        end

        spawnBananasInMuzzle(cachedCannon, 6)  -- bigger volley than normal

        Wait.time(function()
            if cachedCannon == nil then return end
            pcall(function() cachedCannon.call(FIRE_FN) end)
        end, 0.6)
    end, 0.3)
end


-- ============== AUDIO ====================================================

function playClipFromList(clipList, indexUpdater)
    if audioMuted then return end
    if clipList == nil or #clipList == 0 then return end

    local clip = clipList[indexUpdater()]
    if clip == nil or clip.url == nil or clip.url == "" then return end

    -- clear playlist so there's no fallback music after our clip
    MusicPlayer.setPlaylist({})

    MusicPlayer.setCurrentAudioclip({
        url          = clip.url,
        title        = "Kibo Cannon SFX",
        url_creator  = "",
        title_creator = ""
    })

    -- 0.3s buffer lets short clips finish loading before play
    Wait.time(function()
        MusicPlayer.play()
        Wait.time(function()
            MusicPlayer.pause()
        end, clip.duration)
    end, 0.3)
end


function playFireClip()
    if #fireQueue == 0 then
        for i = 1, #FIRE_CLIPS do table.insert(fireQueue, i) end

        if fireFirstCycleDone then
            for i = #fireQueue, 2, -1 do
                local j = math.random(1, i)
                fireQueue[i], fireQueue[j] = fireQueue[j], fireQueue[i]
            end
        else
            fireFirstCycleDone = true
        end
    end

    local clipIdx = table.remove(fireQueue, 1)
    playClipFromList(FIRE_CLIPS, function() return clipIdx end)
end


function playApocClip()
    if #apocQueue == 0 then
        for i = 1, #APOC_CLIPS do table.insert(apocQueue, i) end

        if apocFirstCycleDone then
            for i = #apocQueue, 2, -1 do
                local j = math.random(1, i)
                apocQueue[i], apocQueue[j] = apocQueue[j], apocQueue[i]
            end
        else
            apocFirstCycleDone = true
        end
    end

    local clipIdx = table.remove(apocQueue, 1)
    playClipFromList(APOC_CLIPS, function() return clipIdx end)
end


function toggleMute(_obj, _player_color, _alt_click)
    audioMuted = not audioMuted

    local buttons = self.getButtons() or {}
    for _, btn in ipairs(buttons) do
        if btn.click_function == "toggleMute" then
            self.editButton({
                index = btn.index,
                label = audioMuted and "Unmute Audio" or "Mute Audio",
                color = audioMuted and {0.3, 0, 0, 0.95} or {0, 0, 0, 0.95}
            })
            break
        end
    end

    if audioMuted then MusicPlayer.pause() end

    broadcastToAll(
        "[Kibo Cannon] Audio " .. (audioMuted and "MUTED" or "UNMUTED"),
        {0.7, 0.7, 0.7}
    )
end


-- ============== SPAWN HELPERS ============================================

function spawnBananasInMuzzle(cannon, count)
    for i = 1, count do
        local t = math.random()
        local localOffset = {
            x = MUZZLE_OFFSET_LOW.x + math.random() * (MUZZLE_OFFSET_HIGH.x - MUZZLE_OFFSET_LOW.x),
            y = MUZZLE_OFFSET_LOW.y + t * (MUZZLE_OFFSET_HIGH.y - MUZZLE_OFFSET_LOW.y),
            z = MUZZLE_OFFSET_LOW.z + t * (MUZZLE_OFFSET_HIGH.z - MUZZLE_OFFSET_LOW.z),
        }
        localOffset.x = localOffset.x + (math.random() - 0.5) * SPREAD
        localOffset.z = localOffset.z + (math.random() - 0.5) * SPREAD
        localOffset.y = localOffset.y + (i * 0.15)

        spawnOneBanana(cannon.positionToWorld(localOffset), i * 47)
    end
end


function spawnBananaPile(centerPos, count)
    for i = 1, count do
        local offsetX = (((i - 1) % 2) - 0.5) * 0.4
        local offsetZ = (math.floor((i - 1) / 2) - 0.5) * 0.4
        local pos = {
            x = centerPos.x + offsetX,
            y = centerPos.y + 4 + (i * 0.2),
            z = centerPos.z + offsetZ,
        }
        spawnOneBanana(pos, i * 30)
    end
end


function spawnOneBanana(pos, rotY)
    local json = string.gsub(BANANA_JSON, '"posX": 0, "posY": 0, "posZ": 0',
        string.format('"posX": %f, "posY": %f, "posZ": %f', pos.x, pos.y, pos.z))
    json = string.gsub(json, '"rotX": 0, "rotY": 0, "rotZ": 0',
        string.format('"rotX": 0, "rotY": %f, "rotZ": 0', rotY))

    spawnObjectJSON({
        json     = json,
        position = pos,
        sound    = false,
        callback_function = function(spawned)
            spawned.addTag("kibo_banana")
        end
    })
end


-- ============== AUTO-DISCOVERY ===========================================

function discoverCannon()
    if CANNON_GUID_OVERRIDE ~= "" then
        local obj = getObjectFromGUID(CANNON_GUID_OVERRIDE)
        if obj then
            cachedCannon = obj
            return
        end
    end

    -- first pass: keyword match on name/description, then verify it has FireCannon
    for _, obj in ipairs(getAllObjects()) do
        local name    = string.lower(obj.getName() or "")
        local desc    = string.lower(obj.getDescription() or "")
        local matched = false

        for _, kw in ipairs(CANNON_KEYWORDS) do
            if string.find(name, kw) or string.find(desc, kw) then
                matched = true
                break
            end
        end

        if matched then
            local buttons = obj.getButtons() or {}
            for _, btn in ipairs(buttons) do
                if btn.click_function == FIRE_FN then
                    cachedCannon = obj
                    return
                end
            end
        end
    end

    -- fallback: anything on the table that has a FireCannon button
    for _, obj in ipairs(getAllObjects()) do
        local buttons = obj.getButtons() or {}
        for _, btn in ipairs(buttons) do
            if btn.click_function == FIRE_FN then
                cachedCannon = obj
                return
            end
        end
    end
end
