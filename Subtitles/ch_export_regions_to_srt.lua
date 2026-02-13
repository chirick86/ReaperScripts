-- @description Export regions to SRT
-- @author Chirick
-- @version 1.0.0
-- @changelog
--   + Initial release
--   + Export project regions to SRT file
--   + Creates standard SRT file with timecodes
-- @link https://github.com/chirick86/reaperscripts
-- @donation https://patreon.com/chirick
-- @about
--   # Export regions to SRT
--   
--   Export project regions to SRT subtitle file
--   
--   ## Features
--   * Exports all project regions
--   * Creates standard SRT file with timecodes
--   * Region names become subtitle text
--   * Quick way to create subtitles from project marking

-- ch_export_regions_to_srt.lua
-- Экспорт всех регионов в SRT файл

-- Функция форматирования времени в SRT (чч:мм:сс,мс)
local function format_srt_time(t)
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = math.floor(t % 60)
    local ms = math.floor((t - math.floor(t)) * 1000)
    return string.format("%02d:%02d:%02d,%03d", h, m, s, ms)
end

-- Собираем регионы
local regions = {}
local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
for i = 0, num_markers + num_regions - 1 do
    local ret, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    if isrgn then
        table.insert(regions, {
            start = pos,
            stop = rgnend,
            text = name ~= "" and name or ("Region " .. markrgnindexnumber)
        })
    end
end

if #regions == 0 then
    reaper.ShowMessageBox("Нет регионов для экспорта.", "Экспорт SRT", 0)
    return
end

-- Окно сохранения файла
if reaper.APIExists("JS_Dialog_BrowseForSaveFile") then
    retval, file_path = reaper.JS_Dialog_BrowseForSaveFile("Export to SRT", "", "", "SRT files (.srt)\0*.srt\0All Files (*.*)\0*.*\0")
else
    retval, file_path = reaper.GetUserFileNameForWrite("", "Export to SRT", ".srt")
end
if not retval or not file_path or file_path:match("^%s*$") then return end
if not file_path:lower():match("%.srt$") then file_path = file_path .. ".srt" end

-- Формируем содержимое файла
local srt_lines = {}
for i, r in ipairs(regions) do
    table.insert(srt_lines, tostring(i))
    table.insert(srt_lines, format_srt_time(r.start) .. " --> " .. format_srt_time(r.stop))
    table.insert(srt_lines, r.text)
    table.insert(srt_lines, "") -- пустая строка между субтитрами
end

-- Записываем файл
local f, err = io.open(file_path, "w")
if not f then
    reaper.ShowMessageBox("Ошибка записи файла:\n" .. tostring(err), "Экспорт SRT", 0)
    return
end
f:write(table.concat(srt_lines, "\n"))
f:close()
