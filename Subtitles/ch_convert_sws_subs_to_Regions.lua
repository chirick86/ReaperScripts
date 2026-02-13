-- @description Convert SWS subtitles to regions
-- @author Chirick
-- @version 1.0.0
-- @changelog
--   + Initial release
--   + Convert SWS S&M subtitles to full timeline regions
--   + Fixed standalone script
-- @link https://github.com/chirick86/reaperscripts
-- @donation https://patreon.com/chirick
-- @about
--   # Convert SWS subtitles to regions
--   
--   Convert SWS S&M subtitles to full timeline regions
--   
--   ## Features
--   * Reads currently open (saved) project .rpp file
--   * Extracts <S&M_SUBTITLE blocks from <EXTENSIONS> and maps them to marker indices
--   * Uses marker timing pairs (MARKER lines) to create regions with full subtitle text
--   * Deletes all existing timeline regions and recreates them with full texts
--   
--   ## Usage
--   * Save your project in REAPER, run this script from Actions → ReaScript
--   * Script will abort if the project is not saved
--   
--   **Note:** Backup project before running!

--[[
  Chirick: Convert SWS S&M subtitles to full regions (fixed standalone script)
  - Reads the currently open (saved) project .rpp
  - Extracts <S&M_SUBTITLE blocks from <EXTENSIONS and maps them to marker indices
  - Uses marker timing pairs (MARKER lines) to create regions with full subtitle text
  - Deletes all existing timeline regions and recreates them with full texts

  Usage:
  - Save your project in REAPER, run this script from Actions -> ReaScript
  - Script will abort if the project is not saved

  Note: backup project before running.
]]

local reaper = reaper

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then return nil, err end
  local s = f:read("*a")
  f:close()
  return s
end

local function trim(s)
  if not s then return "" end
  return (s:gsub("^%s+",""):gsub("%s+$",""))
end

-- Extract S&M subtitle blocks (returns map by marker_idx: {marker_idx -> text})
local function extract_sm_subtitles_from_rpp(rpp_text)
  local subs_by_idx = {}
  
  -- Find all S&M_SUBTITLE blocks
  local pos = 1
  while true do
    local s, e, id = rpp_text:find("<S&M_SUBTITLE%s+(%d+)", pos)
    if not s then break end
    
    -- Find the closing > for this block
    local block_end = rpp_text:find("\n    >", e)
    if not block_end then block_end = rpp_text:find("\n  >", e) end
    if not block_end then block_end = rpp_text:find("\n>", e) end
    
    if block_end then
      local block_content = rpp_text:sub(e, block_end)
      
      -- Extract all lines starting with |
      local lines = {}
      for line in block_content:gmatch("([^\n]+)") do
        local piped = line:match("^%s*|%s*(.*)")
        if piped and piped ~= "" then
          table.insert(lines, piped)
        end
      end
      
      local text = table.concat(lines, "\n")
      local numeric_id = tonumber(id)
      
      if numeric_id then
        local marker_idx = numeric_id - 1073741824
        subs_by_idx[marker_idx] = trim(text)
      end
      
      pos = block_end + 1
    else
      break
    end
  end

  return subs_by_idx
end

-- Parse marker lines from .rpp and group by marker index
local function parse_markers_from_rpp(rpp_text)
  local markers_by_idx = {}
  for line in rpp_text:gmatch("([^\n]*)\n") do
    local idx, pos, txt = line:match("^%s*MARKER%s+(%d+)%s+([%d%.%-]+)%s+\"(.-)\"")
    if idx and pos then
      idx = tonumber(idx)
      pos = tonumber(pos)
      if not markers_by_idx[idx] then markers_by_idx[idx] = {} end
      table.insert(markers_by_idx[idx], {pos = pos})
    end
  end
  return markers_by_idx
end

-- Build region_list from markers_by_idx (use first two positions as start/end, NO text!)
local function build_region_list_from_markers(markers_map)
  local region_list = {}
  for idx, arr in pairs(markers_map) do
    if #arr >= 2 then
      table.sort(arr, function(a,b) return a.pos < b.pos end)
      local start = arr[1].pos
      local ending = arr[2].pos
      table.insert(region_list, {start = start, ['end'] = ending, idx = idx})
    end
  end
  table.sort(region_list, function(a,b) return a.start < b.start end)
  return region_list
end

-- Map subtitles to regions: use subs_by_idx map to get full text by marker index
local function map_subtitles_to_regions(subs_by_idx, region_list)
  local mapped = {}
  for i, r in ipairs(region_list) do
    local fulltext = ""
    if r.idx and subs_by_idx[r.idx] then
      fulltext = subs_by_idx[r.idx]
    end
    mapped[i] = {start = r.start, ['end'] = r['end'], text = fulltext}
  end
  return mapped
end

-- Safe delete wrapper for ReaScript variants
local function delete_project_marker_safe(proj, idx, isRegion)
  if reaper.DeleteProjectMarkerEx then
    return reaper.DeleteProjectMarkerEx(proj, idx, isRegion)
  elseif reaper.DeleteProjectMarker then
    return reaper.DeleteProjectMarker(proj, idx, isRegion)
  elseif reaper.DeleteProjectMarker2 then
    return reaper.DeleteProjectMarker2(proj, idx, isRegion)
  else
    reaper.ShowMessageBox("API функция удаления маркера/региона не найдена в вашем ReaScript окружении.", "Ошибка API", 0)
    return false
  end
end

-- Main
local function main()
  local proj = 0
  local _, proj_path = reaper.EnumProjects(-1, "")
  if not proj_path or proj_path == "" then
    reaper.ShowMessageBox("Текущий проект не сохранён. Сохраните проект в .rpp и запустите скрипт снова.", "Chirick: S&M -> Regions", 0)
    return
  end

  local content, err = read_file(proj_path)
  if not content then
    reaper.ShowMessageBox("Failed to read file: " .. (err or ""), "Error", 0)
    return
  end

  local subs_by_idx = extract_sm_subtitles_from_rpp(content)
  local sub_count = 0
  for k, v in pairs(subs_by_idx) do 
    sub_count = sub_count + 1
  end
  
  if sub_count == 0 then
    return
  end

  local markers_map = parse_markers_from_rpp(content)
  local region_list = build_region_list_from_markers(markers_map)
  if #region_list == 0 then
    return
  end

  local mapped = map_subtitles_to_regions(subs_by_idx, region_list)

  reaper.Undo_BeginBlock2(proj)
  -- delete all timeline regions
  local _, num_markers, num_regions = reaper.CountProjectMarkers(proj)
  local total = (num_markers or 0) + (num_regions or 0)
  local del_indices = {}
  for i = 0, (total>0 and total-1 or -1) do
    local retval, isrgn, pos, rgnend, name, markrgnindex, color = reaper.EnumProjectMarkers2(proj, i)
    if retval and isrgn and markrgnindex then table.insert(del_indices, markrgnindex) end
  end
  table.sort(del_indices, function(a,b) return a > b end)
  for _, idx in ipairs(del_indices) do delete_project_marker_safe(proj, idx, true) end

  -- add regions with FULL text from S&M
  for i = 1, #mapped do
    local r = mapped[i]
    reaper.AddProjectMarker2(proj, true, r.start, r['end'], r.text, -1, 0)
  end

  reaper.Undo_EndBlock2(proj, "Import S&M subtitles as full regions", -1)
  reaper.UpdateArrange()
end

main()
