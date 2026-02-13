-- @description Create text items from regions
-- @author Chirick
-- @version 1.0.0
-- @changelog
--   + Initial release
--   + Convert project regions to text items on new track
-- @link https://github.com/chirick/reaperscripts
-- @donation https://patreon.com/chirick
-- @about
--   # Create text items from regions
--   
--   Convert project regions to text items
--   
--   ## Features
--   * Creates new track with text items based on all project regions
--   * Region names are transferred to item Notes
--   * Item timing matches regions
--   * Convenient for transferring marking to tracks

-- ch_create_text_items_from_regions.lua
-- Создание текстовых итемов из всех регионов проекта на новом треке

-- Получаем все регионы проекта
local regions = {}
local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
for i = 0, num_markers + num_regions - 1 do
    local ret, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if isrgn then
        table.insert(regions, {start=pos, stop=rgnend, name=name})
    end
end

if #regions == 0 then
    reaper.ShowMessageBox("В проекте нет регионов.", "Информация", 0)
    return
end

-- Начинаем Undo блок
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- Создаем новый трек под текущим
reaper.Main_OnCommand(40001, 0) -- Insert new track
local track = reaper.GetSelectedTrack(0, 0)

-- Сохраняем текущую позицию курсора
local cur_pos = reaper.GetCursorPosition()

-- Создаем текстовые итемы для каждого региона
for _, r in ipairs(regions) do
    -- вставка без изменения loop selection
    reaper.Main_OnCommand(40142, 0) -- Insert empty item
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
        reaper.SetMediaItemPosition(item, r.start, true)
        reaper.SetMediaItemLength(item, r.stop - r.start, true)
        reaper.GetSetMediaItemInfo_String(item, "P_NOTES", r.name, true)
    end
end

-- Восстанавливаем курсор
reaper.SetEditCurPos(cur_pos, true, true)


reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Создать текстовые итемы из регионов", -1)
