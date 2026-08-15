-- @description Switch BPM to 120/240/360
-- @author Chirick
-- @version 1.0.0
-- @changelog
--   + Initial release
-- @link https://github.com/chirick86/reaperscripts
-- @donation https://patreon.com/chirick
-- @about
--   # BPM Switcher
--   
--   Switch BPM to 120/240/360
--   
--   ## Usage
--   Just run the script from Actions

local current = reaper.Master_GetTempo()
local next_bpm = 120

if math.abs(current - 120) < 0.001 then
  next_bpm = 240
elseif math.abs(current - 240) < 0.001 then
  next_bpm = 360
end

reaper.Undo_BeginBlock()
reaper.SetCurrentBPM(0, next_bpm, true)
reaper.Undo_EndBlock("Switch BPM to " .. next_bpm, -1)

