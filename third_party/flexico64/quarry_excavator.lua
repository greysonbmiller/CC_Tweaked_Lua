-- This is a replacement for the
-- 'excavate' program, as it can re-
-- cover from a reboot/unload event.
-- Also avoids destroying spawners!
-- <Flexico64@gmail.com>
-- Please email me if you have any
-- bugs or suggestions!

-----------------------------------
-- [¯¯] || || |¯\ [¯¯] ||   |¯¯] --
--  ||  ||_|| | /  ||  ||_  | ]  --
--  ||   \__| | \  ||  |__] |__] --
-----------------------------------
--  /¯\  || ||  /\  |¯\ |¯\ \\// --
-- | O | ||_|| |  | | / | /  \/  --
--  \_\\  \__| |||| | \ | \  ||  --
-----------------------------------

os.loadAPI("flex.lua")
os.loadAPI("dig.lua")
dig.doBlacklist() -- Avoid Protected Blocks
dig.doAttack() -- Attack entities that block the way
dig.setFuelSlot(1)
dig.setBlockSlot(2)
local world_height = 384


local args = {...}
if #args == 0 then
 flex.printColors(
   "quarry <length> [width] [depth]\n"..
   "[skip <layers>] [dump] [nolava] [nether]",
   colors.lightBlue)
 return
end --if


local reloaded = false
if dig.saveExists() then
 reloaded = true
 dig.loadCoords()
end --if
dig.makeStartup("quarry",args)


local zmax = tonumber(args[1])
local xmax = tonumber(args[2]) or zmax
local depth = world_height-1
if tonumber(args[2]) ~= nil then
 depth = tonumber(args[3]) or depth
end --if
local ymin = -depth --(1-depth)

if xmax == nil or zmax == nil then
 flex.send("Invalid dimensions,",colors.red)
 shell.run("rm startup.lua")
 return
end --if


local x
local skip = 0
local lava = true
local dodumps = false

for x=1,#args do
 
 if args[x] == "dump" then
  dodumps = true
 elseif args[x] == "nolava" then
  lava = false
 elseif args[x] == "nether" then
  dig.setBlockStacks(4)
 end --if
 
 if args[x] == "skip" then
  skip = tonumber(args[x+1])
  if skip == nil then
   flex.printColors("Please specify skip depth",
     colors.red)
   dig.saveClear()
   return
  end --if
  if dig.getymin() > -skip then
   dig.setymin(-skip)
  end --if
 end --if
 
end --for


if not lava then -- Block lava around edges of quarry
 dig.setBlockSlot(0)
 -- Always keep a stack of blocks
end --if




----------------------------------------------
-- |¯¯]|| |||\ || /¯][¯¯][¯¯] /¯\ |\ ||/¯¯\ --
-- | ] ||_||| \ || [  ||  ][ | O || \ |\_¯\ --
-- ||   \__||| \| \_] || [__] \_/ || \|\__/ --
----------------------------------------------

local location
local function gotoBase()
 local x = dig.getxlast()
 location = dig.location()
 if dig.gety() < -skip then dig.up() end
 dig.gotox(0)
 dig.gotoz(0)
 dig.gotor(180)
 dig.gotoy(0)
 dig.gotox(0)
 dig.setxlast(x)
 dig.gotoz(0)
 dig.gotor(180)
 return location
end --function

local function returnFromBase(loc)
 local loc = loc or location
 local x = dig.getxlast()
 dig.gotor(0)
 checkFuel()
 dig.gotoy(math.min(loc[2]+1,-skip))
 checkFuel()
 dig.gotoz(loc[3])
 checkFuel()
 dig.gotox(loc[1])
 dig.setxlast(x) -- Important for restoring
 checkFuel()
 dig.gotor(loc[4])
 checkFuel()
 dig.gotoy(loc[2])
end --function



local function checkHalt()
 if not rs.getInput("top") then
  return
 end --if
 if dig.gety() == 0 then
  return
 end --if
 
 local loc,x
 -- Manual halt; redstone signal from above
 flex.send("Manual halt initiated", colors.orange)
 flex.printColors("Press ENTER to resume mining\n"
   .."or SPACE to return to base",
   colors.pink)
 
 while true do
  x = flex.getKey()
  if x == keys.enter then return end
  if x == keys.space then break end
 end --while
 
 flex.send("Returning to base", colors.yellow)
 loc = gotoBase()
 print(" ")
 flex.printColors("Press ENTER to resume mining",
   colors.pink)
 while flex.getKey() ~= keys.enter do
  sleep(1)
 end --while
 
 if dodumps then dig.doDumpDown() end
 dig.dropNotFuel()
 flex.send("Resuming quarry",colors.yellow)
 returnFromBase(loc)
 
end --function



local function checkInv()
 if turtle.getItemCount(16) > 0 then
  
  if dodumps then
   dig.right(2)
   dig.doDump()
   dig.left(2)
  end --if
  
  if turtle.getItemCount(14) > 0 then
   local loc = gotoBase()
   dig.dropNotFuel()
   returnFromBase(loc)
  end --if
  
 end --if
end --function



function checkFuel()
 local a = turtle.getFuelLevel()
 local b = ( zmax + xmax + depth + 1 )*2
 local c = true
 
 while a < b and c do
  for x=1,16 do
   turtle.select(x)
   if turtle.refuel(1) then
    break
   end --if
   if x == 16 then
    c = false
   end --if
  end --for
  a = turtle.getFuelLevel()
 end --while
 
 if a < b then
  flex.send("Fuel low, returning to surface",
    colors.yellow)
  local loc = gotoBase()
  turtle.select(1)
  if dodumps then dig.doDumpDown() end
  while turtle.suckUp() do sleep(0) end
  dig.dropNotFuel()
  dig.refuel(b)
  flex.send("Fuel aquired!",colors.lightBlue)
  returnFromBase(loc)
 end --if
end --function



local dug = dig.getdug()
local ydeep = dig.getymin()
local function checkProgress()
 a = 1000 --report every <a> blocks dug
 b = 5 --report every <b> meters descended
 if math.floor(dug/a) < math.floor(dig.getdug()/a) then
  flex.send("Dug "..tostring(dig.getdug())..
    " blocks",colors.lightBlue)
 end --if
 if math.floor(-ydeep/b) < math.floor(-dig.gety()/b) then
  flex.send("Descended "..tostring(-dig.gety())..
    "m",colors.green)
 end --if
 dug = dig.getdug()
 ydeep = dig.gety()
end --function



local newlayer = false
function checkNewLayer()
 if newlayer then
  -- This encodes whether or not the turtle has
  --  started a new layer if at the edge
  dig.setr(dig.getr() % 360 + 360)
 else
  dig.setr(dig.getr() % 360)
 end --if
end --function



function lavax()
  if dig.getx() == 0 then
   dig.gotor(270)
   checkNewLayer()
   dig.blockLava()
  elseif dig.getx() == xmax-1 then
   dig.gotor(90)
   checkNewLayer()
   dig.blockLava()
  end --if/else
end --function

function lavaz()
  if dig.getz() == 0 then
   dig.gotor(180)
   checkNewLayer()
   dig.blockLava()
  elseif dig.getz() == zmax-1 then
   dig.gotor(0)
   checkNewLayer()
   dig.blockLava()
  end --if/else
end --function

function checkLava(n)
 if lava then
  local x
  local r = dig.getr() % 360
  
  if r == 0 or r == 180 then
   lavaz()
   lavax()
  else
   lavax()
   lavaz()
  end --if/else
  
  if dig.gety() == -skip then
   dig.blockLavaUp()
  end --if
  
  if dig.getx() == 0 and dig.getz() == 0
     and dig.gety() > -skip then
   for x=1,4 do
    dig.blockLava()
    dig.left()
    checkNewLayer()
   end --for
  end --if
  
  if n ~= 0 then
   dig.gotor(r)
   checkNewLayer()
  end --if
  
 end --if
end --function



function checkAll(n)
 checkNewLayer()
 checkProgress()
 checkFuel()
 checkInv()
 checkHalt()
 checkLava(n)
 dig.checkBlocks()
 checkNewLayer()
end --function




---------------------------------------
--      |\/|  /\  [¯¯] |\ ||         --
--      |  | |  |  ][  | \ |         --
--      |||| |||| [__] || \|         --
---------------------------------------
-- |¯\ |¯\  /¯\   /¯¯] |¯\  /\  |\/| --
-- | / | / | O | | [¯| | / |  | |  | --
-- ||  | \  \_/   \__| | \ |||| |||| --
---------------------------------------

local a,b,c,x,y,z,r,loc
local xdir, zdir = 1, 1

turtle.select(1)
if reloaded then
 
 flex.send("Resuming "..tostring(zmax).."x"
   ..tostring(xmax).." quarry",colors.yellow)
 
 if dig.gety()==dig.getymin() and dig.gety()~=0 then
  zdir = dig.getzlast()
  if zdir == 0 then zdir = 1 end
  xdir = dig.getxlast()
  if xdir == 0 then xdir = 1 end
  
  if dig.getr() >= 360 then
   -- This encodes whether or not the turtle has
   --  started a new layer if at the edge
   xdir = -xdir
   newlayer = true
  end --if
  
 else
  gotoBase()
  if dodumps then dig.doDumpDown() end
  dig.dropNotFuel()
  dig.gotor(0)
  checkFuel()
  dig.gotoy(dig.getymin())
 end --if
 
else
 
 flex.send("Starting "..tostring(zmax).."x"
   ..tostring(xmax).." quarry",colors.yellow)
 
 if skip > 0 then
  flex.send("Skipping "..tostring(skip)
    .."m", colors.lightGray)
 end --if
 
 if depth < world_height-1 then
  flex.send("Going "..tostring(-ymin)
    .."m deep", colors.lightGray)
 else
  flex.send("To bedrock!",colors.lightGray)
 end --if/else
 
end --if/else


while dig.gety() > -skip do
 checkFuel()
 dig.down()
 
 if dig.isStuck() then
  flex.send("Co-ordinates lost! Shutting down",
    colors.red)
  --rs.delete("startup.lua")
  return
 end --if
 
end --while



--------------------------
-- |\/|  /\  [¯¯] |\ || --
-- |  | |  |  ][  | \ | --
-- |||| |||| [__] || \| --
--------------------------
-- ||    /¯\   /¯\  |¯\ --
-- ||_  | O | | O | | / --
-- |__]  \_/   \_/  ||  --
--------------------------

local done = false
while not done and not dig.isStuck() do
 turtle.select(1)
 
 while not done do
  
  checkAll(0)
  if dig.getz()<=0 and zdir==-1 then break end
  if dig.getz()>=zmax-1 and zdir==1 then break end
  
  if zdir == 1 then dig.gotor(0)
  elseif zdir == -1 then dig.gotor(180)
  end --if/else
  checkNewLayer()
  
  dig.fwd()
  
  if dig.isStuck() then
   done = true
  end --if
  
 end --while (z loop)
 
 if done then break end
 
 zdir = -zdir
 newlayer = false
 
 if dig.getx()<=0 and xdir==-1 then
  newlayer = true
 elseif dig.getx()>=xmax-1 and xdir==1 then
  newlayer = true
 else
  checkAll(0)
  dig.gotox(dig.getx()+xdir)
 end --if/else
 
 if newlayer and not dig.isStuck() then
  xdir = -xdir
  if dig.getymin() <= ymin then break end
  checkAll(0)
  dig.down()
 end --if
 
end --while (cuboid dig loop)


flex.send("Digging completed, returning to surface",
  colors.yellow)
gotoBase()

flex.send("Descended "..tostring(-dig.getymin())..
    "m total",colors.green)
flex.send("Dug "..tostring(dig.getdug())..
    " blocks total",colors.lightBlue)

for x=1,16 do
 if dig.isBuildingBlock(x) then
  turtle.select(x)
  dig.placeDown()
  break
 end --if
end --for
turtle.select(1)

if dodumps then
 dig.gotor(0)
 dig.doDump()
 dig.gotor(180)
end
dig.dropNotFuel()
dig.gotor(0)

dig.clearSave()
flex.modemOff()
os.unloadAPI("dig.lua")
os.unloadAPI("flex.lua")
