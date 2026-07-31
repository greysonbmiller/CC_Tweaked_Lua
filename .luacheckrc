-- luacheck configuration for CC:Tweaked turtle/computer scripts.
--
-- CC:Tweaked runs Cobalt, a Lua 5.1 VM, so the base standard is lua51 - NOT
-- 5.3/5.4. Here that governs which GLOBALS and library fields are known.
--
-- It does NOT govern syntax: luacheck's parser accepts Lua 5.3 constructs
-- (bitwise << >> & | ~, integer division //) whatever `std` is set to, and
-- those are hard syntax errors on a turtle. Verified - luacheck reports
-- audio/base64_dfpwm_music_player.lua as clean, and that file cannot load in
-- CC at all. So the two checks are complementary, not redundant:
--
--   syntax, true 5.1 gate:
--     luajit -e "local ok,err=loadfile[[FILE]]; print(ok and 'OK' or err)"
--   globals, typos, dead locals:
--     luacheck .
--
-- Run both. Neither one subsumes the other.

-- The CC:Tweaked API surface, layered on top of stock Lua 5.1. Declared as an
-- additional std rather than a flat globals list so that the tables CC EXTENDS
-- (os, table) merge with the 5.1 originals instead of replacing them - that way
-- os.pullEvent is known without os.date silently becoming unknown.
stds.cc = {
    read_globals = {
        -- Global functions CC adds to the sandbox.
        "sleep", "write", "printError", "read",
        "_HOST", "_CC_DEFAULT_SETTINGS", "_CC_DISABLE_LUA51_FEATURES",

        -- API tables.
        "colors", "colours", "commands", "disk", "fs", "gps", "help", "http",
        "keys", "multishell", "paintutils", "parallel", "peripheral", "pocket",
        "rednet", "redstone", "rs", "settings", "shell", "term", "textutils",
        "turtle", "vector", "window",

        -- Lua 5.1-era bit libraries CC exposes.
        "bit32", "bit",

        -- CC backports a few 5.2+ library functions into an otherwise-5.1 VM.
        table = { fields = { "unpack", "pack" } },

        -- CC's event loop, timers and computer identity all hang off os.
        os = {
            fields = {
                "pullEvent", "pullEventRaw", "queueEvent",
                "startTimer", "cancelTimer", "setAlarm", "cancelAlarm",
                "sleep", "day", "epoch",
                "getComputerID", "computerID",
                "getComputerLabel", "computerLabel", "setComputerLabel",
                "run", "loadAPI", "unloadAPI",
                "shutdown", "reboot", "version",
            },
        },
    },
}

std = "lua51+cc"

-- A turtle program is one chunk with no module boundary, and these scripts are
-- written in a direct style where a "global" is really just a variable. So a
-- global that IS assigned somewhere in the same file is fine and is not worth a
-- warning - that is what allow_defined does.
--
-- What survives that setting is the case actually worth hearing about: a name
-- that is READ but never assigned anywhere in the file. That is precisely the
-- my_item_table bug - runTurtleLogistics(my_item_table, ...) passed a name that
-- did not exist, so the mapping arrived nil. Keep this on.
allow_defined = true

ignore = {
    "212",  -- unused argument
    "213",  -- unused loop variable: `for i = 1, 9 do turtle.select(i) end` and
            -- `for _ = 1, n` are both idiomatic here, and neither is a defect.
    "611",  -- line contains only whitespace
    "612",  -- line contains trailing whitespace
    "614",  -- trailing whitespace in a comment
}

-- These files carry long explanatory comments on purpose.
max_line_length = false

exclude_files = {
    ".git",
    -- Vendored third-party code. It is loaded with os.loadAPI, which injects
    -- globals (flex, dig) that no static check can see, so every reference
    -- reads as undefined. Not our code and not our bug - skip it.
    "third_party",
    -- Kept intentionally broken as a reference of what not to do.
    "scratch/item_scanner_broken.lua",
    -- Notes/index file that happens to carry a .lua extension; not real code.
    "scratch/openperipheral_script_index.lua",
}
