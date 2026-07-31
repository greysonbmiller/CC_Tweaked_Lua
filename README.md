# CC_Tweaked_Lua

ComputerCraft / CC:Tweaked programs written for Minecraft turtles and computers, recovered from a decade of worlds (oldest file 2013, newest 2025) and sorted by what they do.

`154` files: `109` runnable programs plus scratch experiments, boot shims and audio assets. Everything here actually ran in a world at some point.


## Layout

| Directory | Files | What's in it |
|---|--:|---|
| [`mining/`](mining/) | 28 | Quarries, tunnels, ore scanners and block harvesters. |
| [`farming/`](farming/) | 19 | Crop, tree and resource farms that run unattended. |
| [`fuel/`](fuel/) | 8 | Refuelling loops - lava buckets, bulk refuel, fuel monitoring. |
| [`inventory/`](inventory/) | 15 | Sorting, counting, and moving items between chests and turtles. |
| [`mobs/`](mobs/) | 6 | Mob farms, attack loops, drop collection. |
| [`crafting/`](crafting/) | 3 | Turtle crafting loops and alloy/ESS automation. |
| [`remote_control/`](remote_control/) | 17 | Driving a turtle from elsewhere - wireless modems, item signals, player detectors. |
| [`audio/`](audio/) | 10 | DFPWM playback on a speaker, plus the PC-side encoder and the audio assets. |
| [`lib/`](lib/) | 3 | Reusable helpers loaded by other programs. |
| [`tools/`](tools/) | 2 | PC-side helpers and one-off utilities. |
| [`third_party/flexico64/`](third_party/flexico64/) | 4 | Not my code. Flex's turtle APIs and quarry, credited to <Flexico64@gmail.com>. |
| [`third_party/cruor/`](third_party/cruor/) | 1 | Not my code. OpenPeripheral Twitter HUD by Cruor. |
| [`third_party/openperipheral/`](third_party/openperipheral/) | 1 | Bundled OpenPeripheral library, origin unverified. |
| [`scratch/`](scratch/) | 14 | One-liners, tests and aborted experiments, kept for completeness. |
| [`scratch/startup/`](scratch/startup/) | 23 | `startup.lua` boot shims - each is a single `shell.run(...)`. |

## The substantial ones

| Program | Size | What it does |
|---|--:|---|
| [`dig_movement_api.lua`](third_party/flexico64/dig_movement_api.lua) | 34.2 KB | Full-featured turtle movement/mining API tracking position, auto-refueling, block blacklisting, and save/load state. |
| [`base64_dfpwm_music_player.lua`](audio/base64_dfpwm_music_player.lua) | 16.8 KB | Decodes an embedded Base64 DFPWM audio blob and streams it to a speaker peripheral. |
| [`quarry_full_no_gps.lua`](mining/quarry_full_no_gps.lua) | 14.7 KB | Full square quarry to bedrock with lava/water handling, hole-filling, auto-refuel, and deposit; no GPS. |
| [`allthemodium_ore_scanner_miner.lua`](mining/allthemodium_ore_scanner_miner.lua) | 12.4 KB | Full mining bot: geo-scans for allthemodium ore, navigates to it, warps out a full inventory via a waystone plate, and refuels. |
| [`flex_utility_library.lua`](third_party/flexico64/flex_utility_library.lua) | 12.3 KB | General-purpose helper API: colored/multicolor printing, modem broadcast+log, inventory condense, block/item inspection helpers. |
| [`geo_scanner_ore_mining_bot.lua`](mining/geo_scanner_ore_mining_bot.lua) | 12.1 KB | Geo Scanner ore bot: finds nearest lapis ore, mines it, loops, and periodically warps home via warp plate. |
| [`twitter_glasses_hud_watcher.lua`](third_party/cruor/twitter_glasses_hud_watcher.lua) | 12.0 KB | Polls Twitter profile pages and shows new tweets as toast notifications on an OpenPeripheral glasses HUD. |
| [`quarry_excavator.lua`](third_party/flexico64/quarry_excavator.lua) | 10.3 KB | Full-featured resumable quarry program with fuel checks, lava blocking, redstone halt, and dump/skip options. |
| [`allthemodium_geo_scanner_navigate.lua`](mining/allthemodium_geo_scanner_navigate.lua) | 7.4 KB | Geo-scans a radius for allthemodium ore and navigates the turtle to sit directly above the nearest match using relative coordinates. |
| [`ancient_debris_geo_scanner.lua`](mining/ancient_debris_geo_scanner.lua) | 6.5 KB | Repeatedly scans with a Geo Scanner and prints coordinates whenever ancient debris is found nearby. |
| [`hash_item_sorter.lua`](inventory/hash_item_sorter.lua) | 5.7 KB | Scans turtle slots and a front chest, sorting known items into fixed output slots by name/NBT hash. |
| [`ancient_debris_seeker_and_depositor.lua`](mining/ancient_debris_seeker_and_depositor.lua) | 4.8 KB | Scans for ancient debris with a Geo Scanner, tunnels to it, chats an alert, deposits ore, and self-refuels in a loop. |
| [`item_scan_link_side_chest.lua`](remote_control/item_scan_link_side_chest.lua) | 3.7 KB | Maps items from a 'weakAutomata' peripheral scan to turtle moves, a sand IO routine, or an inventory link. |
| [`item_scan_flint_link.lua`](remote_control/item_scan_flint_link.lua) | 3.3 KB | Polls a weakAutomata peripheral's detected items and runs turtle movement or sand/flint routines when clay is present. |

## Mod dependencies

Most programs are plain CC:Tweaked and need nothing extra. Counts below are from grepping the sources, so they are what the code actually references:

- **Advanced Peripherals** &mdash; 3 files: `geo_scanner` for ore scanning, `chat_box` for in-game status pings
- **Applied Energistics 2** &mdash; 3 files: certus quartz cluster harvesters
- **Allthemodium** &mdash; 5 files: ore ids for the ATM ore-seeking bots
- **Mob Grinding Utils** &mdash; 4 files: absorption/vacuum hopper in the sorter bots
- **Waystones** &mdash; 3 files: warp plate for the teleport-home mining loop
- **a `weakAutomata` peripheral** &mdash; 10 files: **unidentified mod** - the item-scan controllers all call `scanItems()` on it, and I could not pin down which mod provides it

## Third-party code

[`third_party/`](third_party/) is **not my work** and is kept separate with its original attribution headers intact:

- **[`flexico64/`](third_party/flexico64/)** &mdash; the `dig`/`flex` turtle APIs, the resumable `quarry` program and its modem logger, credited in-file to `<Flexico64@gmail.com>`. `quarry_excavator.lua` needs both APIs present as `dig.lua` and `flex.lua` on the same computer.
- **[`cruor/`](third_party/cruor/)** &mdash; an OpenPeripheral glasses Twitter HUD by Cruor. Long dead against the modern site markup; kept as a period piece.
- **[`openperipheral/`](third_party/openperipheral/)** &mdash; a 2013-era OpenPeripheral library with no author header. Origin unverified.

No license is asserted over any of it. If you are one of these authors and want something removed, open an issue.


## Running these

Drop a file into a computer or turtle's directory and run it by name. Many programs assume a **specific inventory slot layout** or a specific block placed in front of / above / below the turtle &mdash; read the top of the file before running it, and check the `Notes` column in [`docs/PROVENANCE.md`](docs/PROVENANCE.md), which flags every program with hardcoded slots or known bugs.

Two programs hardcode the player name `veganradiation` for chat-box pings. Several hardcode chest NBT hashes from the world they were built in; those will not match your chests.


## Provenance

These came from CurseForge, MultiMC and AT Launcher instances going back to a 2013 TPPI world, plus a VS Code dev folder. The same worlds were backed up two or three times over; duplicates were resolved by content hash, so each file here is unique. [`docs/PROVENANCE.md`](docs/PROVENANCE.md) maps every file back to the world and computer id it was pulled from.

