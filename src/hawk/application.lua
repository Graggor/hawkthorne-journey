local middle = require 'hawk/middleclass'
local json = require 'hawk/json'
local i18n = require 'hawk/i18n'
local gamesave = require 'hawk/gamesave'

local Application = middle.class('Application')

function Application:initialize()
  self.config = {}
  self.gamesaves = gamesave(3)
  self.i18n = i18n("locales")
end


local function stackmessage(msg, trace)
  local err = {}

  table.insert(err, msg.."\n\n")

  for l in string.gmatch(trace, "(.-)\n") do
    if not string.match(l, "boot.lua") then
      table.insert(err, l)
    end
  end

  local p = table.concat(err, "\n")

  p = string.gsub(p, "\t", "")
  p = string.gsub(p, "%[string \"(.-)\"%]", "%1")

  return p
end


function Application:errhand(msg)
  msg = tostring(msg)

  if not love.graphics or not love.event or not love.window.isOpen() then
    return
  end

  -- Load.
  if love.audio then love.audio.stop() end
  love.graphics.reset()
  love.graphics.setBackgroundColor(89/255, 157/255, 220/255)
  local font = love.graphics.newFont(14)
  love.graphics.setFont(font)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.clear()

  local trace = debug.traceback()
  local p = stackmessage(msg, trace)

  local function draw()
    love.graphics.clear()
    love.graphics.origin()
    love.graphics.printf(p, 70, 70, love.graphics.getWidth() - 70)
    love.graphics.present()
  end

  draw()

  local e, a, b, c
  while true do
    e, a, b, c = love.event.wait()

    if e == "quit" then
      return
    end
    if e == "keypressed" and a == "escape" then
      return
    end

    draw()

  end
end


function Application:releaseerrhand(msg)
  print("An error has occurred, the game has been stopped.")

  if not love.graphics or not love.event or not love.window.isOpen() then
    return
  end

  love.graphics.setCanvas()
  love.graphics.setPixelEffect()

  -- Load.
  if love.audio then love.audio.stop() end
  love.graphics.reset()
  love.graphics.setBackgroundColor(89/255, 157/255, 220/255)
  local font = love.graphics.newFont(14)
  love.graphics.setFont(font)

  love.graphics.setColor(1, 1, 1, 1)

  love.graphics.clear()

  local trace = debug.traceback()
  local report_msg = stackmessage(msg, trace)

  local release = love._release or {}

  p = string.format("Error has occurred that caused %s to stop.\nYou can notify %s about this%s.", release.title or "this game", release.author or "the author", release.url and " at " .. release.url or "")

  local function draw()
    love.graphics.clear()
    love.graphics.origin()
    love.graphics.printf(p, 70, 70, love.graphics.getWidth() - 70)
    love.graphics.present()
  end

  draw()

  local e, a, b, c
  while true do
    e, a, b, c = love.event.wait()

    if e == "quit" then
      return
    end
    if e == "keypressed" and a == "escape" then
      return
    end

    draw()

  end
end

return Application
