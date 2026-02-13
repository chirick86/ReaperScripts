-- @description Create regions from text items
-- @author Chirick
-- @version 1.0.0
-- @changelog
--   + Initial release
--   + Convert text items to project regions
-- @link https://github.com/chirick/reaperscripts
-- @donation https://patreon.com/chirick
-- @about
--   # Create regions from text items
--   
--   Convert text items to project regions
--   
--   ## Features
--   * Creates regions from all items on selected track
--   * Item Notes are transferred to region names
--   * Region timing matches items
--   * Useful for converting track content to timeline marking

-- Получаем текущий выбранный трек
local track = reaper.GetSelectedTrack(0, 0)
if not track then
    reaper.ShowMessageBox("Нет выбранного трека.", "Ошибка", 0)
    return
end

-- Выделяем все итемы на треке
local num_items_on_track = reaper.CountTrackMediaItems(track)
if num_items_on_track == 0 then
    reaper.ShowMessageBox("На выбранном треке нет медиа-итемов.", "Ошибка", 0)
    return
end

-- Снимаем выделение со всех итемов в проекте
reaper.Main_OnCommand(40289, 0) -- Unselect all items

-- Выделяем все итемы на треке
for i = 0, num_items_on_track - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    reaper.SetMediaItemSelected(item, true)
end

-- Начинаем Undo-блок
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- Создаём регионы из выделенных итемов
local num_selected_items = reaper.CountSelectedMediaItems(0)
for i = 0, num_selected_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then
        -- Позиция и длина итема
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local end_pos = pos + len

        -- Получаем текст итема (notes)
        local retval, item_chunk = reaper.GetItemStateChunk(item, "", false)
        local item_note = ""
        local note = item_chunk:match("<NOTES\n(.-)\n>")
        if note then
            item_note = note:gsub("|", "")
        end


        if item_note == "" then
            item_note = "Region"
        end

        -- Создаем регион
        reaper.AddProjectMarker2(0, true, pos, end_pos, item_note, -1, 0)
    end
end

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Создать регионы из текстовых итемов на треке", -1)
