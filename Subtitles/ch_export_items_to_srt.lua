-- @description Export items to SRT
-- @author Chirick
-- @version 1.0.0
-- @changelog
--   + Initial release
--   + Export text items from selected track to SRT file
--   + Creates standard SRT file with timecodes
-- @link https://github.com/chirick86/reaperscripts
-- @donation https://patreon.com/chirick
-- @about
--   # Export items to SRT
--   
--   Export text items from selected track to SRT subtitle file
--   
--   ## Features
--   * Exports all items from selected track
--   * Creates standard SRT file with timecodes
--   * Text is taken from Notes of each item
--   * Suitable for transferring subtitles to other programs

-- ch_export_items_to_srt.lua
-- Экспорт всех медиа-итемов на выбранном треке в SRT

-- Проверка выделенного трека
local track = reaper.GetSelectedTrack(0, 0)
if not track then
    reaper.ShowMessageBox("Нет выбранного трека.", "Ошибка", 0)
    return
end

-- Сбор всех итемов на треке
local num_items = reaper.CountTrackMediaItems(track)
if num_items == 0 then
    reaper.ShowMessageBox("На выбранном треке нет медиа-итемов.", "Ошибка", 0)
    return
end

local items = {}
for i = 0, num_items - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local stop = pos + len
    local retval, note = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
    note = note or ""
    -- убираем переносы и лишние символы
    -- note = note:gsub("\r\n", "  "):gsub("\n", "  "):gsub("\r", "  ")
    table.insert(items, {start=pos, stop=stop, text=note})
end

-- Форматирование времени в SRT
local function format_srt_time(t)
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = math.floor(t % 60)
    local ms = math.floor((t - math.floor(t)) * 1000)
    return string.format("%02d:%02d:%02d,%03d", h, m, s, ms)
end

-- Диалог сохранения
if reaper.APIExists("JS_Dialog_BrowseForSaveFile") then
    retval, file_path = reaper.JS_Dialog_BrowseForSaveFile("Export to SRT", "", "", "SRT files (.srt)\0*.srt\0All Files (*.*)\0*.*\0")
else
    retval, file_path = reaper.GetUserFileNameForWrite("", "Export to SRT", ".srt")
end
if not retval or not file_path or file_path:match("^%s*$") then return end
if not file_path:lower():match("%.srt$") then file_path = file_path .. ".srt" end

-- Формируем строки SRT
local srt_lines = {}
for i, it in ipairs(items) do
    table.insert(srt_lines, tostring(i))
    local start_time = tonumber(it.start) or 0
    local stop_time  = tonumber(it.stop)  or 0
    table.insert(srt_lines, format_srt_time(start_time) .. " --> " .. format_srt_time(stop_time))
    local text = it.text or ""
    table.insert(srt_lines, text)
    table.insert(srt_lines, "")
end

-- Сохраняем файл
local f = io.open(file_path, "w")
if not f then
    reaper.ShowMessageBox("Не удалось создать файл для записи.", "Ошибка", 0)
    return
end
f:write(table.concat(srt_lines, "\n"))
f:close()

reaper.ShowMessageBox("Экспорт завершен.", "Chirick Export Items to SRT", 0)
