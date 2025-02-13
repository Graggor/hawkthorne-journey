local utils = require 'utils'
local app = require 'app'

local tween = require 'vendor/tween'
local Gamestate = require 'vendor/gamestate'
local sound = require 'vendor/TEsound'
local timer = require 'vendor/timer'
local cli = require 'vendor/cliargs'

local debugger = require 'debugger'
local camera = require 'camera'
local fonts = require 'fonts'
local window = require 'window'
local controls = require('inputcontroller').get()
local hud = require 'hud'
local character = require 'character'
local cheat = require 'cheat'
local player = require 'player'
local Dialog = require 'dialog'
local Prompt = require 'prompt'

local testing = false
local paused = false

function love.load(arg)
  -- Check if this is the correct version of LOVE
  local version = love.getVersion()

  if version < 11 then
    error("Love 11 or later is required")
  end

  local state, door, position = 'update', nil, nil

  -- set settings
  local options = require 'options'
  options:init()

  cli:add_option("--console", "Displays print info")
  cli:add_option("--fused", "Passed in when the app is running in fused mode")
  cli:add_option("--reset-saves", "Resets all the saves")
  cli:add_option("-b, --bbox", "Draw all bounding boxes ( enables memory debugger )")
  cli:add_option("-c, --character=NAME", "The character to use in the game")
  cli:add_option("-d, --debug", "Enable Memory Debugger")
  cli:add_option("-l, --level=NAME", "The level to display")
  cli:add_option("-m, --money=COINS", "Give your character coins ( requires level flag )")
  cli:add_option("-n, --locale=LOCALE", "Local, defaults to en-US")
  cli:add_option("-o, --costume=NAME", "The costume to use in the game")
  cli:add_option("-p, --position=X,Y", "The positions to jump to ( requires level )")
  cli:add_option("-r, --door=NAME", "The door to jump to ( requires level )")
  cli:add_option("-t, --test", "Run all the unit tests")
  cli:add_option("-w, --wait", "Wait for three seconds")
  cli:add_option("-v, --vol-mute=CHANNEL", "Disable sound: all, music, sfx")
  cli:add_option("-x, --cheat=ALL/CHEAT1,CHEAT2", "Enable certain cheats ( some require level to function, else will crash with collider is nil )")

  local args = cli:parse(arg)

  if not args then
    error("Could not parse command line arguments")
  end

  if args["test"] then
    local lovetest = require 'test/lovetest'
    testing = true
    lovetest.run()
    return
  end

  if args["wait"] then
    -- Wait to for other game to quit
    love.timer.sleep(3)
  end

  if args["level"] ~= "" then
    state = args["level"]
    -- If we're jumping to a level, then we need to be 
    -- sure to set the Gamestate.home variable
    Gamestate.home = "update"
  end

  if args["door"] ~= "" then
    door = args["door"]
  end

  if args["position"] ~= "" then
    position = args["position"]
  end
  

  -- Choose character and costume
  local char = "abed"
  local costume = "base"

  if args["character"] ~= "" then
    char = args["c"]
  end

  if args["costume"] ~= "" then
    costume = args["o"]
  end

  character.pick(char, costume)

  if args["vol-mute"] == 'all' then
    sound.disabled = true
  elseif args["vol-mute"] == 'music' then
    sound.volume('music',0)
  elseif args["vol-mute"] == 'sfx' then
    sound.volume('sfx',0)
  end

  if args["money"] ~= "" then
    player.startingMoney = tonumber(args["money"])
  end

  if args["d"] then
    debugger.set(true, false)
  end

  if args["b"] then
    debugger.set(true, true)
  end
  
  if args["reset-saves"] then
    options:reset_saves()
  end

  if args["locale"] ~= "" then
    app.i18n:setLocale(args.locale)
  end

  local argcheats = false
  local cheats = { }
  if args["cheat"] ~= "" then
    argcheats = true

    if string.find(args["cheat"],",") then
      local from  = 1
      local delim_from, delim_to = string.find( args["cheat"], ",", from  )
      while delim_from do
        table.insert( cheats, string.sub( args["cheat"], from , delim_from-1 ) )
        from  = delim_to + 1
        delim_from, delim_to = string.find( args["cheat"], ",", from  )
      end
      table.insert( cheats, string.sub( args["cheat"], from  ) )
    else
      if args["cheat"] == "all" then
        cheats = {'jump_high','super_speed','god','slide_attack','give_money','max_health','give_gcc_key','give_weapons', 'give_materials','give_potions','give_scrolls','give_taco_meat','unlock_levels','give_master_key', 'give_armor', 'give_recipes'}
      else
        cheats = {args["cheat"]}
      end
    end
  end

  love.graphics.setDefaultFilter('nearest', 'nearest')

  Gamestate.switch(state,door,position)

  if argcheats then
    for k,arg in ipairs(cheats) do
      cheat:on(arg)
    end
  end

end

function love.update(dt)
  if paused or testing then return end
  if debugger.on then debugger:update(dt) end
  dt = math.min(0.033333333, dt)
  if Prompt.currentPrompt then
    Prompt.currentPrompt:update(dt)
  end
  if Dialog.currentDialog then
    Dialog.currentDialog:update(dt)
  end

  Gamestate.update(dt)
  tween.update(dt > 0 and dt or 0.001)
  timer.update(dt)
  sound.cleanup()

  if debugger.on then
    collectgarbage("collect")
  end
end

function buttonreleased(key)
  if testing then return end
  local action = controls:getAction(key)
  if action then Gamestate.keyreleased(action) end

  if not action then return end

  if Prompt.currentPrompt or Dialog.currentDialog then
    --bypass
  else
    Gamestate.keyreleased(action)
  end
end

function buttonpressed(key)
  if testing then return end
  if controls:isRemapping() then Gamestate.keypressed(key) return end
  if key == "f5" then debugger:toggle() end
  if key == "f6" and debugger.on then debug.debug() end
  local action = controls:getAction(key)
  local state = Gamestate.currentState().name or ""

  if not action and state ~= "welcome" then return end
  if Prompt.currentPrompt then
    Prompt.currentPrompt:keypressed(action)
  elseif Dialog.currentDialog then
    Dialog.currentDialog:keypressed(action)
  else
    Gamestate.keypressed(action)
  end
end

function love.keyreleased(key, scancode)
  buttonreleased(key)
end

function love.keypressed(key, scancode, isrepeat)
  controls:switch()
  buttonpressed(key)
end

function love.gamepadreleased(joystick, key)
  buttonreleased(key)
end

function love.gamepadpressed(joystick, key)
  controls:switch(joystick)
  buttonpressed(key)
end

function love.joystickremoved(joystick)
  controls:switch()
end

function love.joystickreleased(joystick, key)
  if joystick:isGamepad() then return end
  buttonreleased(tostring(key))
end

function love.joystickpressed(joystick, key)
  if joystick:isGamepad() then return end
  controls:switch(joystick)
  buttonpressed(tostring(key))
end

function love.joystickaxis(joystick, axis, value)
  if joystick:isGamepad() then return end
  axisDir1, axisDir2, _ = joystick:getAxes()
  controls:switch(joystick)
  if axisDir1 < 0 then buttonpressed('dpleft') end
  if axisDir1 > 0 then buttonpressed('dpright') end
  if axisDir2 < 0 then buttonpressed('dpup') end
  if axisDir2 > 0 then buttonpressed('dpdown') end
end

function love.draw()
  if testing then return end

  camera:set()
  Gamestate.draw()
  fonts.set('arial')
  if Dialog.currentDialog then
    Dialog.currentDialog:draw()
  end
  if Prompt.currentPrompt then
    Prompt.currentPrompt:draw()
  end
  fonts.revert()
  camera:unset()

  if paused then
    love.graphics.setColor(75/255, 75/255, 75/255, 125/255)
    love.graphics.rectangle('fill', 0, 0, love.graphics:getWidth(),
    love.graphics:getHeight())
    love.graphics.setColor(1, 1, 1, 1)
  end

  if debugger.on then debugger:draw() end
  -- If the user has turned the FPS display on AND a screenshot is not being taken
  if window.showfps and window.dressing_visible then
    love.graphics.setColor( 1, 1, 1, 1 )
    fonts.set('big')
    love.graphics.print( love.timer.getFPS() .. ' FPS', love.graphics.getWidth() - 100, 5, 0, 1, 1 )
    fonts.revert()
  end
end

-- Override the default screenshot functionality so we can disable the fps before taking it
local captureScreenshot = love.graphics.captureScreenshot
function love.graphics.captureScreenshot( callback )
  window.dressing_visible = false
  love.draw()
  captureScreenshot( callback )
  window.dressing_visible = true
end
