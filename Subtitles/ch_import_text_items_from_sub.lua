-- @description Import text items from subtitles
-- @author Chirick
-- @version 1.0.1
-- @changelog
--   + Added text scaling
-- @link https://github.com/chirick86/reaperscripts
-- @donation https://patreon.com/chirick
-- @about
--   # Import text items from subtitles
--   
--   Import SRT/ASS subtitles as text items in REAPER
--   
--   ## Features
--   * Supports SRT and ASS formats (multiple file selection)
--   * Auto-detects encoding (UTF-8, CP1251, CP866)
--   * For ASS files with roles - creates separate track for each role
--   * Tracks are named by filename (or "filename - role" for ASS with roles)
--   * Items are created with precise timecode and text in Notes

-- ch_import_text_items_from_sub_multi.lua

-- Проверка на существование файла
local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true else return false end
end

-- Вспомогательная функция: очистка текста от тегов
local function clean_text(text)
    -- Убираем теги формата {....}
    text = text:gsub("{\\.-}", "")
    text = text:gsub("{.-}", "")
    -- Убираем HTML-теги <...>
    text = text:gsub("<.->", "")
    -- Заменяем переносы строк \N на \n
    text = text:gsub("\\N", "\n")
    -- Обрезаем лишние пробелы
    text = text:gsub("%s+$", "")    -- убираем пробелы в конце строки
    text = text:gsub("^%s+", "")    -- убираем пробелы в начале строки
    return text
end

-- Универсальный парсер времени: поддержка H:MM:SS(.|,)ms, MM:SS(.|,)ms, H:MM:SS, MM:SS
local function parse_time_generic(t)
    -- HH:MM:SS[.,]frac
    local h, m, s, frac = t:match("^(%d+):(%d+):(%d+)[%.,](%d+)$")
    if h and m and s and frac then
        local frac_seconds = (#frac == 3) and (tonumber(frac) / 1000)
                           or (#frac == 2) and (tonumber(frac) / 100)
                           or (#frac == 1) and (tonumber(frac) / 10)
                           or (tonumber(frac) / 1000)
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + frac_seconds
    end

    -- MM:SS[.,]frac
    local mm, ss, f2 = t:match("^(%d+):(%d+)[%.,](%d+)$")
    if mm and ss and f2 then
        local frac_seconds = (#f2 == 3) and (tonumber(f2) / 1000)
                           or (#f2 == 2) and (tonumber(f2) / 100)
                           or (#f2 == 1) and (tonumber(f2) / 10)
                           or (tonumber(f2) / 1000)
        return tonumber(mm) * 60 + tonumber(ss) + frac_seconds
    end

    -- HH:MM:SS
    local hh, mi, se = t:match("^(%d+):(%d+):(%d+)$")
    if hh and mi and se then
        return tonumber(hh) * 3600 + tonumber(mi) * 60 + tonumber(se)
    end

    -- MM:SS
    local m2, s2 = t:match("^(%d+):(%d+)$")
    if m2 and s2 then
        return tonumber(m2) * 60 + tonumber(s2)
    end

    return nil
end

-- Простейший парсер SRT, возвращает массив {start, stop, text}
local function parse_srt(filepath)
    local items = {}
    local f = io.open(filepath, "r")
    if not f then return items end
    
    -- Читаем весь файл и нормализуем переносы строк для кросс-платформенности
    local content = f:read("*all")
    f:close()
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")
    
    -- Парсим построчно для более надёжного результата
    local lines = {}
    for line in content:gmatch("([^\n]*)") do
        table.insert(lines, line)
    end
    
    local i = 1
    while i <= #lines do
        -- Ищем строку с таймкодом
        local line = lines[i]
        local sh, sm, ss, sms, eh, em, es, ems =
            line:match("(%d+):(%d+):(%d+),(%d+)%s*%-%->%s*(%d+):(%d+):(%d+),(%d+)")
        
        if sh and sm and ss and sms and eh and em and es and ems then
            local start_time = tonumber(sh)*3600 + tonumber(sm)*60 + tonumber(ss) + tonumber(sms)/1000
            local end_time   = tonumber(eh)*3600 + tonumber(em)*60 + tonumber(es) + tonumber(ems)/1000
            
            -- Собираем текст до следующей пустой строки или следующего таймкода
            local text_lines = {}
            local j = i + 1
            while j <= #lines do
                local next_line = lines[j]
                -- Прерываемся если пустая строка или новый таймкод
                if next_line == "" then
                    break
                elseif next_line:match("^%d+:%d+:%d+,%d+%s*%-%->") then
                    break
                else
                    table.insert(text_lines, next_line)
                    j = j + 1
                end
            end
            
            if #text_lines > 0 then
                local text = table.concat(text_lines, "\n")
                text = clean_text(text)
                if text ~= "" then
                    table.insert(items, {start=start_time, stop=end_time, text=text})
                end
            end
            
            i = j + 1  -- Переходим к следующему блоку
        else
            i = i + 1
        end
    end
    
    return items
end

-- Парсер ASS (берем только строки Dialogue, возвращаем items с полем role)
local function parse_ass(filepath)
    local items = {}
    local f = io.open(filepath, "r")
    if not f then return items end
    
    -- Читаем весь файл и нормализуем переносы строк для кросс-платформенности
    local content = f:read("*all")
    f:close()
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")
    
    for line in content:gmatch("([^\n]+)") do
        if line:match("^Dialogue:") then
            -- Формат: Dialogue: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
            -- Находим 9-ю запятую, после которой идёт текст
            local comma_count = 0
            local text_start_pos = nil
            
            for i = 1, #line do
                if line:sub(i, i) == "," then
                    comma_count = comma_count + 1
                    if comma_count == 9 then
                        text_start_pos = i + 1
                        break
                    end
                end
            end
            
            if text_start_pos then
                -- Извлекаем первые 5 полей для получения времени и роли
                local after_dialogue = line:match("^Dialogue:%s*(.*)")
                if after_dialogue then
                    local layer, start_str, end_str, style, name = 
                        after_dialogue:match("^([^,]*),%s*([^,]*),%s*([^,]*),%s*([^,]*),%s*([^,]*)")
                    
                    if start_str and end_str and name then
                        -- Парсим время
                        local start_h, start_m, start_s, start_cs = start_str:match("(%d+):(%d+):(%d+)%.(%d+)")
                        local end_h, end_m, end_s, end_cs = end_str:match("(%d+):(%d+):(%d+)%.(%d+)")
                        
                        if start_h and end_h then
                            local start_time = tonumber(start_h)*3600 + tonumber(start_m)*60 + tonumber(start_s) + tonumber(start_cs)/100
                            local end_time   = tonumber(end_h)*3600 + tonumber(end_m)*60 + tonumber(end_s) + tonumber(end_cs)/100
                            
                            -- Извлекаем текст
                            local text = line:sub(text_start_pos)
                            
                            -- Очищаем текст от тегов
                            text = clean_text(text)
                            
                            -- Нормализуем name (убираем пробелы по краям) - это и есть роль
                            name = name:match("^%s*(.-)%s*$") or name
                            
                            table.insert(items, {start=start_time, stop=end_time, text=text, role=name})
                        end
                    end
                end
            end
        end
    end
    return items
end

-- Парсер кастомного "XML" формата: строки вида "Marker|Region <start>, <end>, <text>"
local function parse_xml(filepath)
    local items = {}
    local f = io.open(filepath, "r")
    if not f then return items end
    local content = f:read("*all")
    f:close()
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")

    for line in content:gmatch("([^\n]+)") do
        -- Пример: Marker 0:08:41.628, 0:08:42.628,"Text"
        local kind, start_str, end_str, text = line:match("^(%S+)%s+([0-9]+:[0-9]+:[0-9]+[%.,][0-9]+)%s*,%s*([0-9]+:[0-9]+:[0-9]+[%.,][0-9]+)%s*,%s*(.+)$")
        if kind and start_str and end_str and text then
            local start_time = parse_time_generic(start_str)
            local end_time = parse_time_generic(end_str)
            if start_time and end_time then
                -- Снимаем обрамляющие кавычки, если есть
                if text:sub(1,1) == '"' and text:sub(-1) == '"' then
                    text = text:sub(2, -2)
                end
                text = clean_text(text)
                if text ~= "" then
                    -- Для итемов делаем длину > 0: если конец == старт, добавим 1 секунду
                    if end_time == start_time then end_time = start_time + 1 end
                    table.insert(items, {start=start_time, stop=end_time, text=text})
                end
            end
        end
    end
    return items
end

-- Парсер CSV (простой): игнорируем первую строку (заголовок)
local function parse_csv(filepath)
    local items = {}
    local f = io.open(filepath, "r")
    if not f then return items end
    local content = f:read("*all")
    f:close()
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")

    local header_skipped = false
    for line in content:gmatch("([^\n]+)") do
        if not header_skipped then
            header_skipped = true
        else
            -- Сплит по запятой с учётом кавычек и "" внутри
            local cols = {}
            local field, in_quotes = "", false
            local i = 1
            while i <= #line do
                local ch = line:sub(i,i)
                if ch == '"' then
                    if in_quotes and line:sub(i+1,i+1) == '"' then
                        field = field .. '"'
                        i = i + 1
                    else
                        in_quotes = not in_quotes
                    end
                elseif ch == ',' and not in_quotes then
                    table.insert(cols, field)
                    field = ""
                else
                    field = field .. ch
                end
                i = i + 1
            end
            table.insert(cols, field)

            for idx = 1, #cols do
                local part = cols[idx]
                part = part:gsub("^%s+", ""):gsub("%s+$", "")
                if part:sub(1,1) == '"' and part:sub(-1) == '"' then
                    part = part:sub(2, -2):gsub('""','"')
                end
                cols[idx] = part
            end

            if #cols >= 4 then
                local kind_raw = cols[1] or ""
                local kind = kind_raw:lower()
                if kind == "" and kind_raw:match("^[Rr]") then kind = "region" end
                if kind == "" and kind_raw:match("^[Mm]") then kind = "marker" end
                local text = cols[2] or ""
                local start_str = cols[3] or ""
                local end_str = cols[4] or ""

                local start_time = parse_time_generic(start_str)
                local end_time = parse_time_generic(end_str)

                if start_time then
                    text = clean_text(text)
                    if text ~= "" then
                        -- Для итемов: маркеры превращаем в регионы (1 секунда от старта)
                        if kind == "marker" then
                            end_time = start_time + 1
                        end
                        -- Если конец отсутствует или равен старту — тоже делаем 1 сек
                        if not end_time or end_time == start_time then
                            end_time = start_time + 1
                        end
                        table.insert(items, {start=start_time, stop=end_time, text=text})
                    end
                end
            end
        end
    end
    return items
end

-- 1) ВАЛИДАТОР UTF-8 (как раньше)
local function is_valid_utf8(str)
    local i, len = 1, #str
    while i <= len do
        local c = str:byte(i)
        if c < 0x80 then
            i = i + 1
        elseif c >= 0xC2 and c <= 0xDF then
            if i+1 > len then return false end
            local c2 = str:byte(i+1)
            if not (c2 >= 0x80 and c2 <= 0xBF) then return false end
            i = i + 2
        elseif c >= 0xE0 and c <= 0xEF then
            if i+2 > len then return false end
            local c2, c3 = str:byte(i+1), str:byte(i+2)
            if not (c2 >= 0x80 and c2 <= 0xBF and c3 >= 0x80 and c3 <= 0xBF) then return false end
            i = i + 3
        elseif c >= 0xF0 and c <= 0xF4 then
            if i+3 > len then return false end
            local c2, c3, c4 = str:byte(i+1), str:byte(i+2), str:byte(i+3)
            if not (c2 >= 0x80 and c2 <= 0xBF and c3 >= 0x80 and c3 <= 0xBF and c4 >= 0x80 and c4 <= 0xBF) then return false end
            i = i + 4
        else
            return false
        end
    end
    return true
end

-- 2) CP1251 -> UTF-8
local function cp1251_to_utf8(str)
    local map = {
        [0x80]="Ђ",[0x81]="Ѓ",[0x82]="‚",[0x83]="ѓ",[0x84]="„",[0x85]="…",[0x86]="†",[0x87]="‡",
        [0x88]="€",[0x89]="‰",[0x8A]="Љ",[0x8B]="‹",[0x8C]="Њ",[0x8D]="Ќ",[0x8E]="Ћ",[0x8F]="Џ",
        [0x90]="ђ",[0x91]="‘",[0x92]="’",[0x93]="“",[0x94]="”",[0x95]="•",[0x96]="–",[0x97]="—",
        [0x98]="",[0x99]="™",[0x9A]="љ",[0x9B]="›",[0x9C]="њ",[0x9D]="ќ",[0x9E]="ћ",[0x9F]="џ",
        [0xA0]=" ",[0xA8]=utf8.char(0x0401), [0xAB]="«", [0xB8]=utf8.char(0x0451), [0xBB]="»"
    }
    for i=0xC0,0xFF do map[i] = utf8.char(0x0410 + (i-0xC0)) end
    for i=0xA1,0xAA do map[i] = map[i] or utf8.char(0x0400 + (i-0xA0)) end  -- пропускаем 0xA0 и 0xAB
    for i=0xAC,0xAF do map[i] = map[i] or utf8.char(0x0400 + (i-0xA0)) end  -- продолжаем после 0xAB
    for i=0xB0,0xBA do map[i] = map[i] or utf8.char(0x0450 + (i-0xB0)) end  -- пропускаем 0xBB
    for i=0xBC,0xBF do map[i] = map[i] or utf8.char(0x0450 + (i-0xB0)) end  -- продолжаем после 0xBB
    return (str:gsub(".", function(c)
        local b = c:byte()
        if b < 0x80 then return c end
        return map[b] or c
    end))
end

-- 3) CP866 -> UTF-8
local function cp866_to_utf8(str)
    local map = {
        -- А..Я
        [0x80]=0x0410,[0x81]=0x0411,[0x82]=0x0412,[0x83]=0x0413,[0x84]=0x0414,[0x85]=0x0415,[0x86]=0x0416,[0x87]=0x0417,
        [0x88]=0x0418,[0x89]=0x0419,[0x8A]=0x041A,[0x8B]=0x041B,[0x8C]=0x041C,[0x8D]=0x041D,[0x8E]=0x041E,[0x8F]=0x041F,
        [0x90]=0x0420,[0x91]=0x0421,[0x92]=0x0422,[0x93]=0x0423,[0x94]=0x0424,[0x95]=0x0425,[0x96]=0x0426,[0x97]=0x0427,
        [0x98]=0x0428,[0x99]=0x0429,[0x9A]=0x042A,[0x9B]=0x042B,[0x9C]=0x042C,[0x9D]=0x042D,[0x9E]=0x042E,[0x9F]=0x042F,
        -- а..п
        [0xA0]=0x0430,[0xA1]=0x0431,[0xA2]=0x0432,[0xA3]=0x0433,[0xA4]=0x0434,[0xA5]=0x0435,[0xA6]=0x0436,[0xA7]=0x0437,
        [0xA8]=0x0438,[0xA9]=0x0439,[0xAA]=0x043A,[0xAB]=0x043B,[0xAC]=0x043C,[0xAD]=0x043D,[0xAE]=0x043E,[0xAF]=0x043F,
        -- р..я
        [0xE0]=0x0440,[0xE1]=0x0441,[0xE2]=0x0442,[0xE3]=0x0443,[0xE4]=0x0444,[0xE5]=0x0445,[0xE6]=0x0446,[0xE7]=0x0447,
        [0xE8]=0x0448,[0xE9]=0x0449,[0xEA]=0x044A,[0xEB]=0x044B,[0xEC]=0x044C,[0xED]=0x044D,[0xEE]=0x044E,[0xEF]=0x044F,
        [0xF0]=0x0401, -- Ё
        [0xF1]=0x0451, -- ё
    }
    return (str:gsub(".", function(c)
        local b = c:byte()
        if b < 0x80 then return c end
        local cp = map[b]
        return cp and utf8.char(cp) or c
    end))
end

-- 4) ДЕТЕКТОР CP1251 vs CP866 ПО ПЕРВЫМ 3 СТРОКАМ (для items)
local function detect_legacy_encoding_first3(items)
    local n = math.min(3, #items)
    local s1251, s866 = 0, 0
    for i = 1, n do
        local s = items[i].text or ""
        for j = 1, #s do
            local b = s:byte(j)
            if b then
                if b == 0xA8 or b == 0xB8 or (b >= 0xC0 and b <= 0xFF) then s1251 = s1251 + 1 end
                if (b >= 0x80 and b <= 0xAF) or (b >= 0xE0 and b <= 0xF1) then s866 = s866 + 1 end
            end
        end
    end
    if s1251 == 0 and s866 == 0 then return nil end
    return (s1251 >= s866) and "cp1251" or "cp866"
end

-- 5) НОРМАЛИЗАЦИЯ КОДИРОВКИ ВСЕГО МАССИВА (для items)
local function normalize_encoding(items)
    local n = math.min(3, #items)
    local all_utf8 = true
    for i = 1, n do
        if not is_valid_utf8(items[i].text or "") then
            all_utf8 = false
            break
        end
    end
    if all_utf8 then return items end

    local which = detect_legacy_encoding_first3(items)
    if which == "cp1251" then
        for _, r in ipairs(items) do r.text = cp1251_to_utf8(r.text) end
        return items
    elseif which == "cp866" then
        for _, r in ipairs(items) do r.text = cp866_to_utf8(r.text) end
        return items
    else
        reaper.ShowMessageBox("Не удалось определить кодировку: UTF-8/CP1251/CP866.", "Import Subs", 0)
        return nil
    end
end

-- Вспомогательная функция: выбрать только указанный трек
local function select_only_track(target_track)
    local num = reaper.CountTracks(0)
    for i = 0, num-1 do
        local tr = reaper.GetTrack(0, i)
        if tr == target_track then
            reaper.SetTrackSelected(tr, true)
        else
            reaper.SetTrackSelected(tr, false)
        end
    end
end

-- Создаем текстовый итем на указанном треке
local function create_text_item(track, start_time, end_time, text)
    if not track then return end
    -- Создаем итем напрямую через API, без использования команды
    local item = reaper.AddMediaItemToTrack(track)
    if item then
        -- Если конец совпадает со стартом, увеличим конец на 1 секунду
        if end_time == start_time then end_time = start_time + 1 end
        reaper.SetMediaItemPosition(item, start_time, false)
        reaper.SetMediaItemLength(item, end_time - start_time, false)
        reaper.GetSetMediaItemInfo_String(item, "P_NOTES", text, true)
        reaper.SetMediaItemInfo_Value(item, "C_LANEDISP", 3) -- Stretch image/text
    end
end

-- Утилита: разбирает возвращённую строку путей в таблицу
local function split_paths(multi)
    if not multi or multi == "" then return {} end
    -- JS_Dialog_BrowseForOpenFiles часто возвращает пути через '|'
    local paths = {}
    -- сначала попробуем разделить по '|'
    for p in string.gmatch(multi, "([^|]+)") do
        if p ~= "" then table.insert(paths, p) end
    end
    if #paths > 1 then return paths end
    -- пробуем разделить по '\0' или '\n' если '|' не использовался
    paths = {}
    for p in string.gmatch(multi, "([^\0\n]+)") do
        if p ~= "" then table.insert(paths, p) end
    end
    return paths
end

-- Получаем только имя файла из пути
local function filename_from_path(path)
    return path:match("([^\\/]-)%.?[^%.\\/]*$") or path
end

-- Группировка итемов по ролям (только для ASS)
local function group_by_role(items)
    local groups = {}
    local has_non_default = false
    
    for _, item in ipairs(items) do
        local role = item.role or "Default"
        
        -- Проверяем, есть ли роли отличные от Default (пустая строка считается за Default)
        if role ~= "" and role ~= "Default" then
            has_non_default = true
        end
        
        if not groups[role] then
            groups[role] = {}
        end
        table.insert(groups[role], item)
    end
    
    return groups, has_non_default
end



-- Главная функция: поддержка множественного выбора файлов
local function import_subs_multi()
    local paths = {}

    -- Если есть JS-диалог — можно выбрать несколько файлов сразу
    if reaper.APIExists("JS_Dialog_BrowseForOpenFiles") then
        local retval, sel = reaper.JS_Dialog_BrowseForOpenFiles(
            "Select subtitle file(s)",
            "",
            "",
            "Subtitle files\0*.srt;*.ass;*.xml;*.csv\0All files (*.*)\0*.*\0\0",
            true -- разрешаем множественный выбор
        )
        if retval and sel and sel ~= "" then
            paths = split_paths(sel)
        end
    else
        -- Fallback: позволим выбирать файлы по очереди до отмены
        while true do
            local retval, file_path = reaper.GetUserFileNameForRead("", "Select subtitle file (Cancel to finish)", "srt;ass;xml;csv;SRT;ASS;XML;CSV")
            if not retval or not file_path or file_path == "" then break end
            table.insert(paths, file_path)
        end
    end

    if #paths == 0 then return end

    -- Начинаем Undo блок
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    local orig_cursor = reaper.GetCursorPosition()

    for _, file_path in ipairs(paths) do
        local lower = file_path:lower()

        -- пропускаем всё, что не srt/ass
        if lower:match("%.srt$") or lower:match("%.ass$") or lower:match("%.xml$") or lower:match("%.csv$") then
            if not file_exists(file_path) then
                reaper.ShowMessageBox("File not found: " .. file_path, "Import Subs", 0)
            else
                local items = {}
                local is_ass = false
                
                if lower:match("%.srt$") then
                    items = parse_srt(file_path)
                elseif lower:match("%.ass$") then
                    items = parse_ass(file_path)
                    is_ass = true
                elseif lower:match("%.xml$") then
                    items = parse_xml(file_path)
                elseif lower:match("%.csv$") then
                    items = parse_csv(file_path)
                end

                if #items == 0 then
                    reaper.ShowMessageBox("No valid subtitles found in: " .. file_path, "Import Subs", 0)
                else
                    items = normalize_encoding(items)
                    if items then
                        local fname = filename_from_path(file_path)
                        
                        -- Если ASS файл, проверяем наличие ролей
                        if is_ass then
                            local groups, has_non_default = group_by_role(items)
                            
                            if has_non_default then
                                -- Создаём отдельный трек для каждой роли
                                for role, role_items in pairs(groups) do
                                    reaper.Main_OnCommand(40001, 0) -- Insert new track
                                    local track = reaper.GetSelectedTrack(0, 0)
                                    if track then
                                        local track_name = fname .. " - " .. role
                                        reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_name, true)
                                        for _, it in ipairs(role_items) do
                                            create_text_item(track, it.start, it.stop, it.text)
                                        end
                                    end
                                end
                            else
                                -- Все роли Default, создаём один трек
                                reaper.Main_OnCommand(40001, 0) -- Insert new track
                                local track = reaper.GetSelectedTrack(0, 0)
                                if track then
                                    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", fname, true)
                                    for _, it in ipairs(items) do
                                        create_text_item(track, it.start, it.stop, it.text)
                                    end
                                end
                            end
                        else
                            -- SRT файл, создаём один трек как обычно
                            reaper.Main_OnCommand(40001, 0) -- Insert new track
                            local track = reaper.GetSelectedTrack(0, 0)
                            if track then
                                reaper.GetSetMediaTrackInfo_String(track, "P_NAME", fname, true)
                                for _, it in ipairs(items) do
                                    create_text_item(track, it.start, it.stop, it.text)
                                end
                            end
                        end
                    else
                        reaper.ShowMessageBox("Failed to normalize encoding for: " .. file_path, "Import Subs", 0)
                    end
                end
            end
        end
    end

    reaper.SetEditCurPos(orig_cursor, true, true)
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Import subtitles as text items (multiple files)", -1)
end

import_subs_multi()
