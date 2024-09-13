-- Débogueur Visual Studio Code tomblind.local-lua-debugger-vscode
if pcall(require, "lldebugger") then
    require("lldebugger").start()
end

-- Cette ligne permet d'afficher des traces dans la console pendant l'éxécution
io.stdout:setvbuf("no")

largeur = 0
hauteur = 0

function love.load()
    largeur = love.graphics.getWidth()
    hauteur = love.graphics.getHeight()
end

function love.update(dt)
end

function love.draw()
end

function love.keypressed(key)
end
