-- Smoke test for the probe scripts.
--
-- The probes cannot be unit tested against real hardware, but they CAN be run
-- under the mock to prove they execute end to end rather than merely parsing.
-- Every earlier probe bug in this project was a runtime one - a nil call, a
-- missing method - that a syntax check happily accepted.
--
--   luajit mining/tests/probe_smoke.lua

local here = (arg[0] or ""):match("^(.*[/\\])") or ""
local mock = dofile(here .. "ccmock.lua")

local pass, fail = 0, 0
local function assertThat(label, cond, detail)
    if cond then pass = pass + 1; print(string.format("  %-46s PASS", label))
    else fail = fail + 1; print(string.format("  %-46s FAIL", label))
         if detail then print("        " .. detail) end end
end

local function runProbe(path, opts)
    opts = opts or {}
    opts.preInv = opts.preInv or mock.fullKit()
    opts.budget = opts.budget or 20000
    return mock.run(path, opts)
end

print("probe smoke test")
print(string.rep("=", 56))

print("\n[1] geo scanner probe runs to completion")
local r = runProbe("mining/geo_scanner_probe.lua")
assertThat("did not error", r.ok, r.err)
assertThat("wrote its log file", r.files["geoprobe.txt"] ~= nil,
           "files: " .. tostring(next(r.files)))
local log = r.files["geoprobe.txt"] or ""
assertThat("log reached the summary",
           log:find("=== summary ===", 1, true) ~= nil,
           log:sub(-200))
assertThat("log records the cooldown",
           log:find("cooldown between scans", 1, true) ~= nil, log:sub(-200))
assertThat("log records the radius ceiling",
           log:find("largest radius accepted", 1, true) ~= nil, log:sub(-200))
assertThat("scanner was put back", r.inv[15] ~= nil and
           r.inv[15].name == mock.SCANNER,
           "slot 15 = " .. tostring(r.inv[15] and r.inv[15].name))

print("\n[2] geo probe survives having no scanner at all")
local noScanner = mock.fullKit(); noScanner[15] = nil
r = runProbe("mining/geo_scanner_probe.lua", { preInv = noScanner })
assertThat("did not error", r.ok, r.err)
assertThat("said so in the log",
           (r.files["geoprobe.txt"] or ""):find("NO GEO SCANNER", 1, true) ~= nil,
           r.files["geoprobe.txt"])

print("\n[3] chat box probe runs to completion")
r = runProbe("mining/chat_box_probe.lua", {
    chats = { { msg = "$ore 1" }, { msg = "hello" } } })
assertThat("did not error", r.ok, r.err)
assertThat("chat box was put back", r.inv[10] ~= nil and
           r.inv[10].name == mock.CHATBOX,
           "slot 10 = " .. tostring(r.inv[10] and r.inv[10].name))

print("\n" .. string.rep("=", 56))
print(string.format("%d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
