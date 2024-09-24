-- Débogueur Visual Studio Code tomblind.local-lua-debugger-vscode
if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

-- Cette ligne permet d'afficher des traces dans la console pendant l'éxécution
io.stdout:setvbuf("no")

function math.dist(x1,y1, x2,y2) return ((x2-x1)^2+(y2-y1)^2)^0.5 end

function math.angle(x1,y1, x2,y2) return math.atan2(y2-y1, x2-x1) end

screenWidth = 0
screenHeight = 0

local sprites = {}
local human = {}

local ZSTATES = {}
ZSTATES.NONE = ""
ZSTATES.WALK = "walk"
ZSTATES.ATTACK = "attack"
ZSTATES.BITE  = "bite"
ZSTATES.CHANGEDIR = "change"

local imgAlert = love.graphics.newImage("images/alert.png")
local imgDead = love.graphics.newImage("images/dead_1.png")

local lstBlood = {}
local imgBlood = love.graphics.newImage("images/blood.png")

--sons
local sndMorsure = love.audio.newSource("sons/morsure.wav","static")

function CreateSprite(pList, pType, psImageFile, pnFrames, pX, pY, pScale)
    local sprite = {}
    sprite.type = pType
    sprite.visible = true

    sprite.x = pX
    sprite.y = pY
    sprite.scale = pScale
    sprite.vx = 0
    sprite.vy = 0

    sprite.images = {}
    sprite.currentFrame = 1
    local i
    for i = 1,pnFrames do 
        sprite.images[i] = love.graphics.newImage("images/"..psImageFile.."_"..tostring(i)..".png")
    end   
    sprite.width = sprite.images[1]:getWidth()
    sprite.height = sprite.images[1]:getHeight()
    
    table.insert(pList, sprite)
    return sprite
end

function CreateZombie()
    local zombie = {}
    zombie.x = 0
    zombie.y = 0

    zombie = CreateSprite(sprites, "zombie", "monster", 2, zombie.x, zombie.y, 2)
    zombie.x = math.random(zombie.width, screenWidth - zombie.width)
    zombie.y = math.random(zombie.height, (screenHeight / 2) - zombie.height)    ---on les positionne uniquement dans la partie superieure
    
    zombie.state = ZSTATES.NONE
    zombie.speed = math.random(5,50) / 100   
    zombie.range = math.random(20, 150)         --distance de detection variable
    zombie.target = nil

    return zombie
end

function UpdateZombie(pZombie, pSprites)

    if pZombie.state == ZSTATES.NONE then
        pZombie.state = ZSTATES.CHANGEDIR

    elseif pZombie.state == ZSTATES.WALK then  
        --collision avec bords
        local bCollide = false                                                                          ---on l'empeche de sortir de l'ecran
        if pZombie.x < (pZombie.width ) or pZombie.x > (screenWidth - (pZombie.width / 2)) then
            bCollide = true
        end
        if pZombie.y < (pZombie.height) or pZombie.y > (screenHeight - (pZombie.height / 2)) then
            bCollide = true
        end
        if bCollide then
            pZombie.state = ZSTATES.CHANGEDIR
        end

        --si proche de humain ou autre alors ATTACK
        local i
        for i = 1, #pSprites do
            local sprite = pSprites[i]
            if sprite.type == "human" and sprite.visible and sprite.dead == false then
                if math.dist(pZombie.x, pZombie.y, sprite.x, sprite.y) < pZombie.range then
                    pZombie.state = ZSTATES.ATTACK
                    pZombie.target = sprite
                end
            end
        end

    elseif pZombie.state == ZSTATES.ATTACK then

        local  destX, destY
        destX = math.random(pZombie.target.x-10, pZombie.target.x+10)
        destY = math.random(pZombie.target.y-10, pZombie.target.y+10)
        local angle = math.angle(pZombie.x, pZombie.y, destX, destY)   --direction vers la cible ( a +/- 10 un peu d'aleatoire) en accelerant
        pZombie.vx = pZombie.speed * 2 * 60 * math.cos(angle)
        pZombie.vy = pZombie.speed * 2 * 60 * math.sin(angle)

         --si eloignement de humain ou autre 
        
        if math.dist(pZombie.x, pZombie.y, pZombie.target.x, pZombie.target.y) > pZombie.range then
            pZombie.state = ZSTATES.CHANGEDIR
            pZombie.target = nil
        elseif math.dist(pZombie.x, pZombie.y, pZombie.target.x, pZombie.target.y) < 5 then        --morsure
            pZombie.state = ZSTATES.BITE
            pZombie.vx = 0
            pZombie.vy = 0
        end
       

    elseif pZombie.state == ZSTATES.BITE then

        if pZombie.target.dead  then
            pZombie.target = nil
            pZombie.state = ZSTATES.CHANGEDIR
        else
            if math.dist(pZombie.x, pZombie.y, pZombie.target.x, pZombie.target.y) > 5 then
                pZombie.state = ZSTATES.ATTACK
            else
                if pZombie.target.Hurt() ~= nil  then
                    pZombie.target.Hurt()
                end
            end
        end       
               
    elseif pZombie.state == ZSTATES.CHANGEDIR then
        local angle = math.angle(pZombie.x, pZombie.y, math.random(0, screenWidth), math.random(0, screenHeight))   --direction aleatoire dans l'ecran
        pZombie.vx = pZombie.speed * 60 * math.cos(angle)
        pZombie.vy = pZombie.speed * 60 * math.sin(angle)

        pZombie.state = ZSTATES.WALK
    end
end

function CreateHuman()
    local human = {}
    human.x = screenWidth/2
    human.y = (screenHeight/6) * 5
    human = CreateSprite(sprites, "human", "player", 4, human.x, human.y, 2)
    human.speed = 2
    human.life = 100
    human.dead = false

    human.Hurt = function()            ---morsure
               
        human.life = human.life - 0.1
        
        if math.random(1,20) == 1 then
            sndMorsure:play()
            --particules de sang
            local blood = {}
            blood.x = human.x + math.random(-10, 10)
            blood.y = human.y + math.random(-10, 10)
            table.insert(lstBlood, blood)
        end

        if human.life < 0 then
            human.life  = 0
            human.dead = true 
        end
    end

    return human
end

function love.load()
    love.window.setTitle("Zombicide")

    screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()

    human = CreateHuman()

    local i
    for i = 1,50 do
        CreateZombie()
    end     
    
end

function love.update(dt)
    local i 
    for i =1,#sprites do
        local sprite = sprites[i]
        sprite.currentFrame = sprite.currentFrame + 5 * dt
        if sprite.currentFrame > (#sprite.images + 1) then  
            sprite.currentFrame = 1
        end

        if sprite.type == "zombie" then
            UpdateZombie(sprite, sprites)
        end

        sprite.x = sprite.x + (sprite.vx * dt)
        sprite.y = sprite.y + (sprite.vy * dt)
    end

    -- mouvement de human
    if love.keyboard.isDown("left") then
        human.x = human.x - human.speed
    end
    if love.keyboard.isDown("right") then
        human.x = human.x + human.speed
    end
    if love.keyboard.isDown("up") then
        human.y = human.y - human.speed
    end
    if love.keyboard.isDown("down") then
        human.y = human.y + human.speed
    end
end

function love.draw()
   
    local i

    for i = 1,#lstBlood do
        love.graphics.draw(imgBlood, lstBlood[i].x, lstBlood[i].y)
    end

    for i = 1,#sprites do
        local sprite = sprites[i]

        if sprite.visible then
            if sprite.type == "human" and sprite.dead then
                love.graphics.draw(imgDead, sprite.x - sprite.width/2, sprite.y - sprite.height/2,
                                                                        0, sprite.scale, sprite.scale, sprite.width/2, sprite.height/2)
            else
                love.graphics.draw(sprite.images[math.floor(sprite.currentFrame)], sprite.x - sprite.width/2, sprite.y - sprite.height/2,
                                                                        0, sprite.scale, sprite.scale, sprite.width/2, sprite.height/2)
            end
            
            if sprite.type == "zombie" and sprite.state == ZSTATES.ATTACK then
                love.graphics.draw(imgAlert, sprite.x - sprite.width, sprite.y - sprite.height*2 - imgAlert:getHeight(), 0, sprite.scale, sprite.scale)
            end
        end
    end

    love.graphics.print("LIFE: "..tostring(math.floor(human.life)), 1, 1)
  
end

function love.keypressed(key)
end
