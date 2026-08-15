-- @description Set BPM
-- @author Chirick
-- @version 1.0.0
-- @changelog
--   + Initial release
-- @link https://github.com/chirick86/reaperscripts
-- @donation https://patreon.com/chirick
-- @about
--   # SET BPM
--   
--   Set BPM to a specific value
--   
--   ## Usage
--   Just run the script from Actions
--   Type new BPM value in the prompt

local current = reaper.Master_GetTempo()
local ok, input = reaper.GetUserInputs("Set BPM", 1, "New BPM:,extrawidth=50", string.format("%d", math.floor(current + 0.5)))

if not ok then return end

local bpm = tonumber(input)

if not bpm or bpm ~= math.floor(bpm) or bpm < 1 or bpm > 960 then
  reaper.MB("Enter a whole number between 1 and 960.", "Invalid BPM", 0)
  return
end

reaper.Undo_BeginBlock()
reaper.SetCurrentBPM(0, bpm, true)
reaper.Undo_EndBlock("Set BPM to " .. bpm, -1)

