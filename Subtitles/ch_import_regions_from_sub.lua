-- @description Import regions from subtitles
-- @author Chirick
-- @version 1.0.0
-- @changelog
--   + Initial release
--   + Import subtitles to regions
--   + Supports SRT and ASS formats
--   + Auto-detects encoding (UTF-8, CP1251, CP866)
--   + For ASS files with roles - assigns unique color to each role
-- @link https://github.com/chirick86/reaperscripts
-- @donation https://patreon.com/chirick
-- @about
--   # Import regions from subtitles
--   
--   Import SRT/ASS subtitles as project regions in REAPER
--   
--   ## Features
--   * Supports SRT and ASS formats
--   * Auto-detects encoding (UTF-8, CP1251, CP866)
--   * For ASS files with roles - assigns unique color to each role (20 bright colors)
--   * Regions are created with subtitle text as names and precise timecode
--   * Convenient for quick project marking by subtitles

-- ch_import_regions_from_sub.lua
-- Импорт субтитров (SRT/ASS) напрямую в регионы

--[[ todo:
    --добавить поддержку импорта cp866 и win1251 кодировок
    --добавить поддержку импорта кастомного XML формата
    --добавить поддержку импорта CSV (простая реализация, игнорируем первую строку)
]]--

-- Вспомогательная функция: очистка текста от тегов
local function clean_text(text)
    -- Убираем теги формата {....}
    text = text:gsub("{\\.-}", "")
    -- Убираем HTML-теги <...>
    text = text:gsub("<.->", "")
    -- Заменяем переносы строк \N на \n
    text = text:gsub("\\N", "\n")
    -- Обрезаем лишние пробелы
    --text = text:gsub("%s+", " ")    -- убираем двойные пробелы
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
        return tonumber(h)*3600 + tonumber(m)*60 + tonumber(s) + frac_seconds
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

-- Вспомогательная функция: преобразование времени в секунды
local function parse_time_srt(t)
    local h, m, s, ms = t:match("(%d+):(%d+):(%d+),(%d+)")
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + tonumber(ms) / 1000
end

local function parse_time_ass(t)
    local h, m, s, cs = t:match("(%d+):(%d+):(%d+)%.(%d+)")
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + tonumber(cs) / 100
end

-- Парсер SRT: устойчив к отсутствию финальной пустой строкы
local function parse_srt(file_path)
    local regions = {}
    local f = io.open(file_path, "r")
    if not f then return regions end
    local content = f:read("*all")
    f:close()

    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")

    local lines = {}
    for line in content:gmatch("([^\n]*)") do
        table.insert(lines, line)
    end

    local i = 1
    while i <= #lines do
        local line = lines[i]
        local sh, sm, ss, sms, eh, em, es, ems =
            line:match("(%d+):(%d+):(%d+),(%d+)%s*%-%->%s*(%d+):(%d+):(%d+),(%d+)")

        if sh and sm and ss and sms and eh and em and es and ems then
            local start_time = tonumber(sh)*3600 + tonumber(sm)*60 + tonumber(ss) + tonumber(sms)/1000
            local end_time   = tonumber(eh)*3600 + tonumber(em)*60 + tonumber(es) + tonumber(ems)/1000

            local text_lines = {}
            local j = i + 1
            while j <= #lines do
                local next_line = lines[j]
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
                    table.insert(regions, {start_time, end_time, text})
                end
            end

            i = j + 1
        else
            i = i + 1
        end
    end

    return regions
end

-- Парсер ASS с извлечением роли
local function parse_ass(file_path)
    local regions = {}
    local f = io.open(file_path, "r")
    if not f then return regions end
    local content = f:read("*all")
    f:close()

    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")

    for l in content:gmatch("[^\n]+") do
        if l:match("^Dialogue:") then
            local comma_count = 0
            local text_start_pos = nil

            for i = 1, #l do
                if l:sub(i, i) == "," then
                    comma_count = comma_count + 1
                    if comma_count == 9 then
                        text_start_pos = i + 1
                        break
                    end
                end
            end

            if text_start_pos then
                local after_dialogue = l:match("^Dialogue:%s*(.*)")
                if after_dialogue then
                    local layer, start_str, end_str, style, name =
                        after_dialogue:match("^([^,]*),%s*([^,]*),%s*([^,]*),%s*([^,]*),%s*([^,]*)")

                    if start_str and end_str and name then
                        local start_time = parse_time_ass(start_str)
                        local end_time = parse_time_ass(end_str)
                        local text = l:sub(text_start_pos)
                        text = clean_text(text or "")

                        name = name:match("^%s*(.-)%s*$") or name

                        if text ~= "" then
                            table.insert(regions, {start_time, end_time, text, role = name})
                        end
                    end
                end
            end
        end
    end

    return regions
end

-- Парсер кастомного "XML" формата: строки вида "Marker|Region <start>, <end>, <text>"
local function parse_xml(file_path)
    local regions = {}
    local f = io.open(file_path, "r")
    if not f then return regions end
    local content = f:read("*all")
    f:close()
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")

    for line in content:gmatch("([^\n]+)") do
        local kind, start_str, end_str, text = line:match("^(%S+)%s+([0-9]+:[0-9]+:[0-9]+[%.,][0-9]+)%s*,%s*([0-9]+:[0-9]+:[0-9]+[%.,][0-9]+)%s*,%s*(.+)$")
        if kind and start_str and end_str and text then
            local start_time = parse_time_generic(start_str)
            local end_time = parse_time_generic(end_str)
            if start_time and end_time then
                if text:sub(1,1) == '"' and text:sub(-1) == '"' then
                    text = text:sub(2, -2)
                end
                text = clean_text(text)
                if text ~= "" then
                    table.insert(regions, {start_time, end_time, text})
                end
            end
        end
    end

    return regions
end

-- Парсер CSV (простой): игнорируем первую строку (заголовок)
local function parse_csv(file_path)
    local regions = {}
    local f = io.open(file_path, "r")
    if not f then return regions end
    local content = f:read("*all")
    f:close()
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")

    local header_skipped = false
    for line in content:gmatch("([^\n]+)") do
        if not header_skipped then
            header_skipped = true
        else
            -- Разбиение по запятой с учётом кавычек и удвоенных кавычек внутри
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

                text = clean_text(text)
                if start_time and text ~= "" then
                    end_time = end_time or start_time
                    table.insert(regions, {start_time, end_time, text, kind = kind})
                end
            end
        end
    end

    return regions
end

-- 1) ВАЛИДАТОР UTF-8
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

-- 2) CP1251 -> UTF-8 (твоя рабочая версия)
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

-- 3) CP866 -> UTF-8 (короткая рабочая версия)
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

-- 4) ДЕТЕКТОР CP1251 vs CP866 ПО ПЕРВЫМ 3 СТРОКАМ (без конвертации)
local function detect_legacy_encoding_first3(regions)
    local n = math.min(3, #regions)
    local s1251, s866 = 0, 0
    for i = 1, n do
        local s = regions[i][3] or ""
        for j = 1, #s do
            local b = s:byte(j)
            if b then
                if b == 0xA8 or b == 0xB8 or (b >= 0xC0 and b <= 0xFF) then s1251 = s1251 + 1 end
                if (b >= 0x80 and b <= 0xAF) or (b >= 0xE0 and b <= 0xF1) then s866 = s866 + 1 end
            end
        end
    end
    if s1251 == 0 and s866 == 0 then return nil end  -- похоже на чистый ASCII/UTF-8
    return (s1251 >= s866) and "cp1251" or "cp866"
end

-- 5) НОРМАЛИЗАЦИЯ КОДИРОВКИ ВСЕГО МАССИВА
local function normalize_encoding(regions)
    local n = math.min(3, #regions)
    local all_utf8 = true
    for i = 1, n do
        if not is_valid_utf8(regions[i][3] or "") then
            all_utf8 = false
            break
        end
    end
    if all_utf8 then return regions end

    local which = detect_legacy_encoding_first3(regions)
    if which == "cp1251" then
        for _, r in ipairs(regions) do r[3] = cp1251_to_utf8(r[3]) end
        return regions
    elseif which == "cp866" then
        for _, r in ipairs(regions) do r[3] = cp866_to_utf8(r[3]) end
        return regions
    else
        reaper.ShowMessageBox("Не удалось определить кодировку: UTF-8/CP1251/CP866.", "Импорт субтитров", 0)
        return nil
    end
end

-- 6) ГЕНЕРАЦИЯ ЦВЕТОВ ДЛЯ РОЛЕЙ
local function generate_role_colors()
    return {
        0x4169E1, -- Royal Blue
        0x32CD32, -- Lime Green
        0xFF4500, -- Orange Red
        0xFF1493, -- Deep Pink
        0x00CED1, -- Dark Turquoise
        0xFFD700, -- Gold
        0x9370DB, -- Medium Purple
        0xFF6347, -- Tomato
        0x20B2AA, -- Light Sea Green
        0xFFA500, -- Orange
        0x9932CC, -- Dark Orchid
        0x00FA9A, -- Medium Spring Green
        0xFF69B4, -- Hot Pink
        0x1E90FF, -- Dodger Blue
        0xADFF2F, -- Green Yellow
        0xFF8C00, -- Dark Orange
        0x8A2BE2, -- Blue Violet
        0x00FF7F, -- Spring Green
        0xDC143C, -- Crimson
        0x4682B4, -- Steel Blue
    }
end

-- 7) НАЗНАЧЕНИЕ ЦВЕТОВ РОЛЯМ
local function assign_colors_to_roles(regions)
    local roles = {}
    local role_set = {}
    
    -- Собираем уникальные роли
    for _, r in ipairs(regions) do
        local role = r.role or "Default"
        if role ~= "" and role ~= "Default" and not role_set[role] then
            role_set[role] = true
            table.insert(roles, role)
        end
    end
    
    -- Если нет ролей или только Default, возвращаем пустую таблицу
    if #roles == 0 then
        return {}
    end
    
    local colors = generate_role_colors()
    local role_colors = {}
    
    for i, role in ipairs(roles) do
        -- Циклически используем цвета, если ролей больше чем цветов
        local color_index = ((i - 1) % #colors) + 1
        role_colors[role] = colors[color_index]
    end
    
    return role_colors
end



-- Основная функция
local function import_subs_to_regions()
    local retval, file_path
    if reaper.APIExists("JS_Dialog_BrowseForOpenFiles") then
        retval, file_path = reaper.JS_Dialog_BrowseForOpenFiles(
            "Select subtitle file", 
            "", 
            "", 
            "Subtitle files\0*.srt;*.ass;*.xml;*.csv\0All files (*.*)\0*.*\0\0", 
            false
        )
    else
        retval, file_path = reaper.GetUserFileNameForRead("", "Select subtitle file", "srt;ass;xml;csv;SRT;ASS;XML;CSV")
    end

    if not retval or not file_path or file_path == "" then return end

    local regions = {}
    local lower = file_path:lower()

    if lower:match("%.srt$") then
        regions = parse_srt(file_path)
    elseif lower:match("%.ass$") then
        regions = parse_ass(file_path)
    elseif lower:match("%.xml$") then
        regions = parse_xml(file_path)
    elseif lower:match("%.csv$") then
        regions = parse_csv(file_path)
    end

    regions = normalize_encoding(regions)
    
    if not regions then return end

    -- Определяем, нужно ли назначать цвета по ролям (только для ASS файлов с ролями)
    local role_colors = {}
    if file_path:lower():match("%.ass$") then
        role_colors = assign_colors_to_roles(regions)
    end
    
    local has_roles = next(role_colors) ~= nil

    -- Добавляем регионы в проект
    reaper.Undo_BeginBlock()
    for _, r in ipairs(regions) do
        local color = 0  -- цвет по умолчанию (используется REAPER default)

        if has_roles and r.role then
            local role = r.role
            if role ~= "" and role ~= "Default" then
                local base_color = role_colors[role] or 0
                -- Добавляем флаг 0x1000000 для кастомного цвета
                color = base_color | 0x1000000
            end
        end

        -- Всегда ориентируемся только на тайминги: end == start -> маркер, иначе регион
        local is_region = (r[2] ~= r[1])
        reaper.AddProjectMarker2(0, is_region, r[1], r[2], r[3], -1, color)
    end
    reaper.Undo_EndBlock("Импорт субтитров в регионы", -1)
end

-- Запуск
import_subs_to_regions()
