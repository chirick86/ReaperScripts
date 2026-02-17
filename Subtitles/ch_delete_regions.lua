-- @description Delete regions
-- @author Chirick
-- @version 1.0.0
-- @changelog
--   + Initial release
-- @links
--   Forum Thread       http://forum.cockos.com/showthread.php?t=169127
--   Github repository  https://github.com/chirick86/reaperscripts
--   Reddit thread      https://www.reddit.com/r/Reaper/
-- @donation
--   https://patreon.com/chirick
--   https://ko-fi.com/chirick
-- @about
--   # This script deletes all regions in the current project.

reaper.Undo_BeginBlock()
local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
for i = num_markers + num_regions - 1, 0, -1 do
	local ret, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
	if isrgn then
		reaper.DeleteProjectMarker(0, idx, true)
	end
end
reaper.Undo_EndBlock("Delete regions", -1)







