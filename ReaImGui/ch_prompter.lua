-- @description Prompter
-- @author Chirick
-- @version 1.0.0
-- @changelog
--   + Initial release
--   + Prompter for subtitles (regions/items) in REAPER
--   + Automatically highlights current line based on playback position
--   + Customizable fonts, colors and sizes
--   + Search functionality with highlighted results
--   + Smooth scrolling and current line magnification
-- @link https://github.com/chirick/reaperscripts
-- @donation https://patreon.com/chirick
-- @about
--   # Prompter
--   
--   Prompter for working with subtitles (regions/items) in REAPER
--   
--   ## Features
--   * Shows regions or text items as a scrollable list
--   * Automatically highlights current line based on playback position
--   * Quick navigation by clicking on a line (+ copies text to clipboard)
--   * Customizable fonts, colors and sizes for regions and items separately
--   * Search with highlighted results
--   * "All elements" mode - combines regions and items in one timeline-sorted list
--   * Smooth scrolling and current line magnification
--   
--   ## Requirements
--   * ReaImGui (install via ReaPack)
--   * JS_ReaScript Extensions (install via ReaPack)

--[[Prompter v0.0.5
    Зависимости:
        ReaImGui (через ReaPack → ReaTeam Extensions)
        Проверено на ReaImGui 0.10.0.2
        JS_ReaScript Extensions (через ReaPack → ReaTeam Extensions)
        
    ✅ Чеклист критически важных функций
        [✅] Источники данных
            [✅] Переключение между регионами и текстовыми итемами
            [✅] Сохранение выбранного источника при смене проекта
            [✅] Автообновление списков при изменении проекта
            [✅] Корректное отображение имен источников (регионы, треки)
        [✅] Синхронизация с проектом
            [✅] Отслеживание позиции курсора/плейхеда
            [✅] Подсветка текущей строки по времени
            [✅] Автоскролл к активной строке
            [✅] Переход к строке по клику
        [✅] Настройки и персистентность
            [✅] Сохранение настроек шрифтов и цветов
            [✅] Сохранение выбранного источника для каждого проекта
            [✅] Загрузка настроек при запуске и смене проекта
            [✅] Восстановление состояния после перезапуска
        [✅] UI и производительность
            [✅] Плавный скролл (если включен)
            [✅] Контекстное меню с настройками
            [✅] Автоперенос длинных строк
            [✅] Стабильная работа при частых обновлениях
        [✅] Критические сценарии
            [✅] Переключение между проектами с разными источниками
            [✅] Закрытие/открытие проекта
            [✅] Изменение количества треков/регионов в процессе работы
            [✅] Работа с пустыми проектами (без регионов/итемов)
        
        
    Другие скрипты:
        importSUB - игнорирование форматирования]]
        

if not reaper.ImGui_CreateContext then
    reaper.ShowMessageBox("ReaImGui не найден. Установите через ReaPack.", "Ошибка", 0)
    return
end

local debug_mode = false
local TITLE     = "Chirick Prompter"
local SETTINGS  = TITLE
local ctx       = reaper.ImGui_CreateContext(TITLE)
local proj_name = reaper.GetProjectName(0)
local proj_id   = reaper.EnumProjects(-1)
local proj_guid = tostring(proj_name .. tostring(proj_id):sub(-6))
local languages = {"EN", "DE", "FR", "RU", "UK"}
local lang = "EN"

-- Таблица для кэширования строк текущего языка
local str = {}

local i18n = {
    EN = {
        i_import    = "Import",
        i_overlay   = "Overlay",
        i_sources   = "No sources",
        i_empty     = "Load regions or text items",
        -- Source names
        i_regions = "regions",
        i_all_items = "all items",
        -- Tooltips for fonts
        t_region_font = "Font for displaying region lines",
        t_region_scale = "Region font size",
        t_item_font = "Font for displaying item lines",
        t_item_scale = "Item font size",
        -- Tooltips for central scaling
        t_central_scale_title = "Enable current line magnification\nRecommended to use with smooth scrolling",
        t_central_scale = "Magnification factor for the current highlighted line",
        -- Tooltips for functions
        t_smooth_scroll = "Enable smooth scrolling when jumping to the current line",
        t_auto_wrap = "Automatic word wrapping for long lines",
        t_ignore_newlines = "Ignore line break characters \\n",
        t_auto_update = "Automatically update lists when project changes",
        t_show_tooltips = "Show tooltips on hover",
        -- Context menu items - headers
        c_regions = "Regions:",
        c_items = "Items:",
        -- Context menu items - functions
        c_central_scale = "Current line scaling",
        c_smooth_scroll = "Smooth scrolling",
        c_auto_wrap = "Word wrapping",
        c_ignore_newlines = "Ignore line breaks",
        c_auto_update = "Auto-update",
        c_show_tooltips = "Tooltips",
        -- Context menu items - colors
        c_region_color = "Regions",
        c_region_highlight = "Current region",
        c_item_color = "Items",
        c_item_highlight = "Current item",
        c_search_highlight = "Search highlight"
    },
    DE = {
        i_import    = "Import",
        i_overlay   = "Überlagerung",
        i_sources   = "Keine Quellen",
        i_empty     = "Laden Sie Regionen oder Textelemente",
        -- Quellennamen
        i_regions = "Regionen",
        i_all_items = "alle Elemente",
        -- Tooltips für Schriftarten
        t_region_font = "Schriftart zum Anzeigen von Regionszeilen",
        t_region_scale = "Schriftgröße für Regionen",
        t_item_font = "Schriftart zum Anzeigen von Elementzeilen",
        t_item_scale = "Schriftgröße für Elemente",
        -- Tooltips für zentrale Skalierung
        t_central_scale_title = "Vergrößerung der aktuellen Zeile aktivieren\nWird empfohlen, mit sanftem Scrollen zu verwenden",
        t_central_scale = "Vergrößerungsfaktor für die aktuell markierte Zeile",
        -- Tooltips für Funktionen
        t_smooth_scroll = "Sanftes Scrollen beim Wechsel zur aktuellen Zeile aktivieren",
        t_auto_wrap = "Automatisches Umbruch für lange Zeilen",
        t_ignore_newlines = "Zeilenumbruchzeichen ignorieren \\n",
        t_auto_update = "Listen automatisch aktualisieren, wenn sich das Projekt ändert",
        t_show_tooltips = "Tooltips beim Hovern anzeigen",
        -- Kontextmenü-Einträge - Kopfzeilen
        c_regions = "Regionen:",
        c_items = "Elemente:",
        -- Kontextmenü-Einträge - Funktionen
        c_central_scale = "Skalierung der aktuellen Zeile",
        c_smooth_scroll = "Sanftes Scrollen",
        c_auto_wrap = "Zeilenumbruch",
        c_ignore_newlines = "Zeilenumbrüche ignorieren",
        c_auto_update = "Automatische Aktualisierung",
        c_show_tooltips = "Tooltips",
        -- Kontextmenü-Einträge - Farben
        c_region_color = "Regionen",
        c_region_highlight = "Aktuelle Region",
        c_item_color = "Elemente",
        c_item_highlight = "Aktuelles Element",
        c_search_highlight = "Suchmarkierung"
    },
    FR = {
        i_import    = "Importer",
        i_overlay   = "Superposé",
        i_sources   = "Pas de sources",
        i_empty     = "Chargez des régions ou des éléments de texte",
        -- Noms des sources
        i_regions = "régions",
        i_all_items = "tous les éléments",
        -- Info-bulles pour les polices
        t_region_font = "Police pour afficher les lignes de région",
        t_region_scale = "Taille de la police des régions",
        t_item_font = "Police pour afficher les lignes d'éléments",
        t_item_scale = "Taille de la police des éléments",
        -- Info-bulles pour la mise à l'échelle centrale
        t_central_scale_title = "Activer l'agrandissement de la ligne actuelle\nRecommandé d'utiliser avec le défilement fluide",
        t_central_scale = "Facteur d'agrandissement de la ligne actuellement surlignée",
        -- Info-bulles pour les fonctions
        t_smooth_scroll = "Activer le défilement fluide lors du passage à la ligne actuelle",
        t_auto_wrap = "Renvoi automatique à la ligne pour les lignes longues",
        t_ignore_newlines = "Ignorer les caractères de saut de ligne \\n",
        t_auto_update = "Mettre à jour automatiquement les listes lors de modifications du projet",
        t_show_tooltips = "Afficher les info-bulles au survol",
        -- Éléments du menu contextuel - En-têtes
        c_regions = "Régions:",
        c_items = "Éléments:",
        -- Éléments du menu contextuel - Fonctions
        c_central_scale = "Mise à l'échelle de la ligne actuelle",
        c_smooth_scroll = "Défilement fluide",
        c_auto_wrap = "Retour à la ligne",
        c_ignore_newlines = "Ignorer les sauts de ligne",
        c_auto_update = "Mise à jour automatique",
        c_show_tooltips = "Info-bulles",
        -- Éléments du menu contextuel - Couleurs
        c_region_color = "Régions",
        c_region_highlight = "Région actuelle",
        c_item_color = "Éléments",
        c_item_highlight = "Élément actuel",
        c_search_highlight = "Mise en évidence de la recherche"
    },
    RU = {
        i_import    = "Импорт",
        i_overlay   = "Оверлей",
        i_sources   = "Нет источников",
        i_empty     = "Подгрузите регионы или текстовые итемы",
        -- Названия источников
        i_regions = "регионы",
        i_all_items = "все элементы",
        -- Тултипы для шрифтов
        t_region_font = "Шрифт для отрисовки строк регионов",
        t_region_scale = "Размер шрифта регионов",
        t_item_font = "Шрифт для отрисовки строк итемов",
        t_item_scale = "Размер шрифта итемов",
        -- Тултипы для центрального масштаба
        t_central_scale_title = "Включить увеличение текущей подсвеченной строки\nРекомендуется использовать в связке с плавным скроллом",
        t_central_scale = "Коэффициент увеличения текущей подсвеченной строки",
        -- Тултипы для функций
        t_smooth_scroll = "Включить плавный скролл при переходе к текущей строке",
        t_auto_wrap = "Автоматический перенос длинных строк",
        t_ignore_newlines = "Игнорировать символы переноса строки \\n",
        t_auto_update = "Автоматически обновлять списки при изменении проекта",
        t_show_tooltips = "Показывать подсказки при наведении",
        -- Пункты контекстного меню - заголовки
        c_regions = "Регионы:",
        c_items = "Итемы:",
        -- Пункты контекстного меню - функции
        c_central_scale = "Скейл текущей строки",
        c_smooth_scroll = "Плавный скролл",
        c_auto_wrap = "Автоперенос",
        c_ignore_newlines = "Игнорировать подстроки",
        c_auto_update = "Автообновление",
        c_show_tooltips = "Подсказки",
        -- Пункты контекстного меню - цвета
        c_region_color = "Регионы",
        c_region_highlight = "Текущий регион",
        c_item_color = "Итемы",
        c_item_highlight = "Текущий итем",
        c_search_highlight = "Подсветка поиска"
    },
    UK = {
        i_import    = "Імпорт",
        i_overlay   = "Оверлей",
        i_sources   = "Немає джерел",
        i_empty     = "Завантажте регіони або текстові елементи",
        -- Назви джерел
        i_regions = "регіони",
        i_all_items = "всі елементи",
        -- Підказки для шрифтів
        t_region_font = "Шрифт для відображення рядків регіонів",
        t_region_scale = "Розмір шрифту регіонів",
        t_item_font = "Шрифт для відображення рядків елементів",
        t_item_scale = "Розмір шрифту елементів",
        -- Підказки для центрального масштабування
        t_central_scale_title = "Увімкнути збільшення поточного рядка\nРекомендується використовувати разом з плавним прокручуванням",
        t_central_scale = "Коефіцієнт збільшення поточного виділеного рядка",
        -- Підказки для функцій
        t_smooth_scroll = "Увімкнути плавне прокручування при переході на поточний рядок",
        t_auto_wrap = "Автоматичний перенос довгих рядків",
        t_ignore_newlines = "Ігнорувати символи розриву рядка \\n",
        t_auto_update = "Автоматично оновлювати списки при змінах проекту",
        t_show_tooltips = "Показувати підказки при наведенні",
        -- Пункти контекстного меню - заголовки
        c_regions = "Регіони:",
        c_items = "Елементи:",
        -- Пункти контекстного меню - функції
        c_central_scale = "Масштабування поточного рядка",
        c_smooth_scroll = "Плавне прокручування",
        c_auto_wrap = "Перенос рядків",
        c_ignore_newlines = "Ігнорувати розриви рядків",
        c_auto_update = "Автооновлення",
        c_show_tooltips = "Підказки",
        -- Пункти контекстного меню - кольори
        c_region_color = "Регіони",
        c_region_highlight = "Поточний регіон",
        c_item_color = "Елементи",
        c_item_highlight = "Поточний елемент",
        c_search_highlight = "Підсвітлення пошуку"
    }
}

-- время
local scroll_delay = 0.5
local hovered_time = 0
local target_scroll_y = nil
local last_highlighted_idx = nil
local last_scroll_source = nil
local last_central_y = nil  -- для отслеживания изменения позиции
local central_y = nil  -- позиция центрального элемента
local hours_enabled = false

-- кэширование
local _, _, last_CountRegions = reaper.CountProjectMarkers(0)
local cached_pos, cached_source_guid, cached_source_idx, cached_line_idx = nil, nil, nil, nil
local last_text_items_count = 0
local last_proj_guid = proj_guid
local last_ProjectStateChangeCount = 0
local last_CountTracks = 0
local last_BPM = reaper.Master_GetTempo()

-- UI состояние
local want_context_menu = false
local window_hovered = false

-- размеры UI
local ui_dimensions = {
    time_width = 0,
    space_width = 0,
    win_width = 0,
    win_height = 0
}

-- данные проекта
local cur_regions = {}
local cur_items_by_track = {}
local combo_sources = {}

-- индексы источников
local source_idx = 1  -- индекс источника в списке combo_sources
local source_guid = nil   -- уникальный идентификатор источника (например, "regions" или "items_<track_guid>")    

-- кэш для объединенного списка
local combined_items_cache = nil  -- кэшированный объединенный список
local combined_cache_valid = false  -- флаг валидности кэша    

-- ========= Шрифты =========
local font_names = {
    "Arial","Calibri","Roboto","Segoe UI","Tahoma","Verdana",
    "Cambria","CooperMediumC BT","Georgia","Times New Roman",
    "Consolas","Courier New"
}

local BASE_PT = 14
local fonts = {}
for i, name in ipairs(font_names) do
    local f = reaper.ImGui_CreateFont(name, BASE_PT)
    fonts[i] = f
    reaper.ImGui_Attach(ctx, f)
end

-- UI-шрифт (берём первый)
local ui_font   = fonts[1]
local ui_scale  = 14

-- Настройки шрифтов для разных типов элементов
local font_settings = {
    region = {
        idx = 1,
        scale = ui_scale,
        font = fonts[1]
    },
    item = {
        idx = 1,
        scale = ui_scale,
        font = fonts[1]
    }
}
local central_scale = 1.2
local central_scale_enabled = false
local auto_wrap_enabled = true      -- автоперенос длинных строк
local ignore_newlines   = false     -- замена \n на пробелы

-- цвета
local color_settings = {
    region = {
        normal = 0xFFFFFFFF,
        highlight = 0xFFFF00FF
    },
    item = {
        normal = 0x9999FFFF,
        highlight = 0x999900FF
    },
    search_highlight = 0xFF00FFFF
}
local search = ""  -- строка поиска

-- функции
local smooth_scroll_enabled = false
local scroll_speed = 0.05
local auto_update_enabled = false

-- подсказки
local show_tooltips    = true
local tooltip_delay    = 0.5
local tooltip_state    = {}  -- таблица состояний (по ключу текста подсказки)


-- 💾 Сохранение/загрузка настроек
local function save_settings()
    reaper.SetExtState(SETTINGS, "region_font_idx",   tostring(font_settings.region.idx), true)
    reaper.SetExtState(SETTINGS, "region_scale", tostring(font_settings.region.scale), true)
    reaper.SetExtState(SETTINGS, "item_font_idx",     tostring(font_settings.item.idx), true)
    reaper.SetExtState(SETTINGS, "item_scale",   tostring(font_settings.item.scale), true)
    reaper.SetExtState(SETTINGS, "central_scale", tostring(central_scale), true)
    reaper.SetExtState(SETTINGS, "central_scale_enabled", tostring(central_scale_enabled), true)
    reaper.SetExtState(SETTINGS, "region_color",     string.format("%08X", color_settings.region.normal), true)
    reaper.SetExtState(SETTINGS, "region_highlight", string.format("%08X", color_settings.region.highlight), true)
    reaper.SetExtState(SETTINGS, "item_color",       string.format("%08X", color_settings.item.normal), true)
    reaper.SetExtState(SETTINGS, "item_highlight",   string.format("%08X", color_settings.item.highlight), true)
    reaper.SetExtState(SETTINGS, "search_highlight", string.format("%08X", color_settings.search_highlight), true)
    reaper.SetExtState(SETTINGS, "smooth_scroll_enabled", tostring(smooth_scroll_enabled), true)
    reaper.SetExtState(SETTINGS, "show_tooltips",    tostring(show_tooltips), true)
    reaper.SetExtState(SETTINGS, "auto_wrap_enabled", tostring(auto_wrap_enabled), true)
    reaper.SetExtState(SETTINGS, "ignore_newlines",   tostring(ignore_newlines), true)
    reaper.SetExtState(SETTINGS, "time_width",   tostring(ui_dimensions.time_width), true)
    reaper.SetExtState(SETTINGS, "space_width",   tostring(ui_dimensions.space_width), true)
    reaper.SetExtState(SETTINGS, "auto_update_enabled", tostring(auto_update_enabled), true)
    reaper.SetExtState(SETTINGS, "lang", lang, true)

    -- Сохраняем выбранный источник в настройки проекта
    if combo_sources[source_idx] then
        reaper.SetProjExtState(0, SETTINGS, "source_guid", combo_sources[source_idx].guid)
    end
end

local function load_settings()
    local function read_bool(name, default_true_means_when_missing)
        local v = reaper.GetExtState(SETTINGS, name)
        if v == "" then
            return default_true_means_when_missing and true or false
        end
        return (v == "true")
    end

    local function read_num(name, fallback)
        local v = reaper.GetExtState(SETTINGS, name)
        if v == "" then return fallback end
        local n = tonumber(v)
        return n or fallback
    end

    local function read_color(name, fallback)
        local v = reaper.GetExtState(SETTINGS, name)
        if v == "" then return fallback end
        return tonumber(v, 16) or fallback
    end

    font_settings.region.idx   = math.max(1, math.min(#font_names, read_num("region_font_idx", font_settings.region.idx)))
    font_settings.item.idx     = math.max(1, math.min(#font_names, read_num("item_font_idx", font_settings.item.idx)))
    font_settings.region.scale = math.max(10, math.min(100, read_num("region_scale", font_settings.region.scale)))
    font_settings.item.scale   = math.max(10, math.min(100, read_num("item_scale", font_settings.item.scale)))
    
    -- Обновляем объекты шрифтов
    font_settings.region.font = fonts[font_settings.region.idx]
    font_settings.item.font = fonts[font_settings.item.idx]
    central_scale = math.max(1.0, math.min(2.5, read_num("central_scale", central_scale)))
    central_scale_enabled = read_bool("central_scale_enabled", central_scale_enabled)
    color_settings.region.normal     = read_color("region_color",     color_settings.region.normal)
    color_settings.region.highlight = read_color("region_highlight", color_settings.region.highlight)
    color_settings.item.normal       = read_color("item_color",       color_settings.item.normal)
    color_settings.item.highlight   = read_color("item_highlight",   color_settings.item.highlight)
    color_settings.search_highlight = read_color("search_highlight", color_settings.search_highlight)
    smooth_scroll_enabled = read_bool("smooth_scroll_enabled", smooth_scroll_enabled)
    show_tooltips    = read_bool("show_tooltips", true)
    auto_wrap_enabled = read_bool("auto_wrap_enabled", auto_wrap_enabled)
    ignore_newlines = read_bool("ignore_newlines", ignore_newlines)
    ui_dimensions.time_width = read_num("time_width", ui_dimensions.time_width)
    ui_dimensions.space_width = read_num("space_width", ui_dimensions.space_width)
    auto_update_enabled = read_bool("auto_update_enabled", auto_update_enabled)
    local stored_lang = reaper.GetExtState(SETTINGS, "lang")
    if stored_lang ~= "" then
        lang = stored_lang
    end
    -- Загружаем выбранный источник из настроек проекта
    local retval, local_source_guid = reaper.GetProjExtState(0, SETTINGS, "source_guid")
    if retval then
        source_guid = local_source_guid
    end

end


-- 🔧 Утилиты низкого уровня
local function utf8lower(str)
    -- корректное понижение регистра (рус/лат)
    local map = {
        -- русский
        ["А"]="а",["Б"]="б",["В"]="в",["Г"]="г",["Д"]="д",["Е"]="е",["Ё"]="е",
        ["Ж"]="ж",["З"]="з",["И"]="и",["Й"]="й",["К"]="к",["Л"]="л",["М"]="м",
        ["Н"]="н",["О"]="о",["П"]="п",["Р"]="р",["С"]="с",["Т"]="т",["У"]="у",
        ["Ф"]="ф",["Х"]="х",["Ц"]="ц",["Ч"]="ч",["Ш"]="ш",["Щ"]="щ",["Ъ"]="ъ",
        ["Ы"]="ы",["Ь"]="ь",["Э"]="э",["Ю"]="ю",["Я"]="я",
        
        -- дополнительные замены для поиска
        ["ё"]="е",  -- строчная ё тоже приводится к е

        -- украинский (добавлено)
        ["І"]="і",["I"]="і",["i"]="і", -- U+0406 → U+0456
        ["Ї"]="ї",
        ["Є"]="є",
        ["Ґ"]="ґ",
    }
    return (tostring(str or ""):gsub("[%z\1-\127\194-\244][\128-\191]*", function(c)
        return map[c] or c:lower()
    end))
end

local function format_time(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = math.floor(sec % 60)
    if h > 0 then
        hours_enabled = true
        return string.format("%d:%02d:%02d", h, m, s)
    else
        hours_enabled = false
        return string.format("%02d:%02d", m, s)
    end
end

local function calculate_time_width()
    local sc = central_scale_enabled and central_scale or 1
    local src = combo_sources[source_idx]
    
    if src and src.kind == "regions" then
        reaper.ImGui_PushFont(ctx, font_settings.region.font, font_settings.region.scale*sc)
    elseif src and src.kind == "combined" then
        -- Для объединенного источника используем максимальный скейл между регионами и итемами
        local max_scale = math.max(font_settings.region.scale, font_settings.item.scale) * sc
        reaper.ImGui_PushFont(ctx, font_settings.region.font, max_scale)
    else
        -- По умолчанию используем стиль итемов
        reaper.ImGui_PushFont(ctx, font_settings.item.font, font_settings.item.scale*sc)
    end
    
    if hours_enabled then
        ui_dimensions.time_width = reaper.ImGui_CalcTextSize(ctx, "0:00:00")
    else
        ui_dimensions.time_width = reaper.ImGui_CalcTextSize(ctx, "00:00")
    end
    ui_dimensions.space_width = reaper.ImGui_CalcTextSize(ctx, " >  ") -- время, пробелы
    reaper.ImGui_PopFont(ctx)
end

--  Загрузка всех строк для текущего языка (один раз при смене языка)
local function load_language_strings(lang_code)
    local trans = i18n[lang_code] or i18n["EN"]
    str.i_import         = trans.i_import
    str.i_overlay        = trans.i_overlay
    str.i_sources        = trans.i_sources
    str.i_empty          = trans.i_empty
    str.i_regions        = trans.i_regions
    str.i_all_items      = trans.i_all_items
    str.t_tooltips       = trans.t_tooltips
    str.c_contexts       = trans.c_contexts
    str.t_region_font    = trans.t_region_font
    str.t_region_scale   = trans.t_region_scale
    str.t_item_font      = trans.t_item_font
    str.t_item_scale     = trans.t_item_scale
    str.t_central_scale_title = trans.t_central_scale_title
    str.t_central_scale  = trans.t_central_scale
    str.t_smooth_scroll  = trans.t_smooth_scroll
    str.t_auto_wrap      = trans.t_auto_wrap
    str.t_ignore_newlines = trans.t_ignore_newlines
    str.t_auto_update    = trans.t_auto_update
    str.t_show_tooltips  = trans.t_show_tooltips
    str.c_regions        = trans.c_regions
    str.c_items          = trans.c_items
    str.c_central_scale  = trans.c_central_scale
    str.c_smooth_scroll  = trans.c_smooth_scroll
    str.c_auto_wrap      = trans.c_auto_wrap
    str.c_ignore_newlines = trans.c_ignore_newlines
    str.c_auto_update    = trans.c_auto_update
    str.c_show_tooltips  = trans.c_show_tooltips
    str.c_region_color   = trans.c_region_color
    str.c_region_highlight = trans.c_region_highlight
    str.c_item_color     = trans.c_item_color
    str.c_item_highlight = trans.c_item_highlight
    str.c_search_highlight = trans.c_search_highlight
end

-- 🔍 Функция поиска
local function search_filter(items, search_query)
    if not search_query or search_query == "" then
        return items  -- Если поиск пустой, возвращаем все элементы
    end
    
    local filtered = {}
    local query_lower = utf8lower(search_query)
    
    for _, item in ipairs(items) do
        local found = false
        
        -- Ищем в основном тексте
        local item_text = item.name or ""
        local item_lower = utf8lower(item_text)
        if string.find(item_lower, query_lower, 1, true) then
            found = true
        end
        
        -- Ищем в названии трека (если есть)
        if not found and item.track_name then
            local track_lower = utf8lower(item.track_name)
            if string.find(track_lower, query_lower, 1, true) then
                found = true
            end
        end
        
        if found then
            filtered[#filtered+1] = item
        end
    end
    
    return filtered
end


-- 📊 Работа с проектом
local function collect_regions()
    cur_regions = {}

    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = num_markers + num_regions

    for enum_i = 0, total - 1 do
        local _, isrgn, pos, rgnend, name, markrgnindex, color =
            reaper.EnumProjectMarkers3(0, enum_i)
        if isrgn then
            if ignore_newlines then name = string.gsub(name, "\n", " ") end
            cur_regions[#cur_regions+1] = {
                -- !!! сохраняем нативный индекс API
                api_idx    = markrgnindex,
                start_time = pos,
                end_time   = rgnend,
                start_str  = format_time(pos),
                end_str    = format_time(rgnend),
                name       = name or ("Region " .. tostring(markrgnindex)),
                color      = color,
                type       = "region"
            }
        end
    end
end

local function collect_text_items()
    cur_items_by_track = {}
    local num_tracks = reaper.CountTracks(0)
    for t = 0, num_tracks-1 do
        local track = reaper.GetTrack(0, t)
        local _, track_name = reaper.GetTrackName(track)
        local track_guid = reaper.GetTrackGUID(track)
        
        -- Проверяем, замьючен ли трек
        local is_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1
        if is_muted then
            -- будем помечать такой трек флагом
        end

        local items = {}
        local num_items = reaper.CountTrackMediaItems(track)
        for i = 0, num_items-1 do
            local it = reaper.GetTrackMediaItem(track, i)
            local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
            local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
            local _, notes = reaper.GetSetMediaItemInfo_String(it, "P_NOTES", "", false)
            if notes ~= "" then
                if ignore_newlines then notes = string.gsub(notes, "\n", " ") end
                items[#items+1] = {
                    start_time = pos,
                    end_time   = pos + len,
                    start_str  = format_time(pos),
                    end_str    = format_time(pos + len),
                    name       = notes,
                    track_name = track_name,
                    type       = "text_item",
                }
            end
        end

        -- Добавляем трек в список только если есть текстовые итемы
        if #items > 0 then
            table.sort(items, function(a,b) return a.start_time < b.start_time end)
            
            cur_items_by_track[#cur_items_by_track+1] = {
                track_guid = track_guid,
                track_id   = track,
                track_name = track_name,
                items      = items,
                is_muted   = is_muted  -- флаг замьюченого трека
            }
        end
        
        ::continue::
    end
end

local function create_combined_list()
    if combined_cache_valid and combined_items_cache then
        return combined_items_cache
    end
    
    local combined = {}
    
    -- Создаем маппинг источников к их порядку в комболисте
    local source_order = {}
    local order = 1
    
    -- Регионы всегда первые
    if #cur_regions > 0 then
        source_order["regions"] = order
        order = order + 1
    end
    
    -- Затем треки в порядке их добавления
    for _, track_data in ipairs(cur_items_by_track or {}) do
        if not track_data.is_muted then
            local track_guid = track_data.track_guid
            source_order["items_" .. tostring(track_guid)] = order
            order = order + 1
        end
    end
    
    -- Добавляем регионы
    for _, region in ipairs(cur_regions or {}) do
        combined[#combined+1] = {
            start_time = region.start_time,
            end_time = region.end_time,
            start_str = region.start_str,
            end_str = region.end_str,
            name = region.name,
            type = "region",
            source_type = "regions",
            source_order = source_order["regions"] or 999
        }
    end
    
    -- Добавляем итемы только с незамьюченых треков
    for _, track_data in ipairs(cur_items_by_track or {}) do
        -- Пропускаем замьюченые треки
        if not track_data.is_muted then
            local track_guid = track_data.track_guid
            local track_order = source_order["items_" .. tostring(track_guid)] or 999
            
            for _, item in ipairs(track_data.items or {}) do
                combined[#combined+1] = {
                    start_time = item.start_time,
                    end_time = item.end_time,
                    start_str = item.start_str,
                    end_str = item.end_str,
                    name = item.name,
                    track_name = item.track_name,
                    type = "text_item",
                    source_type = "text_items",
                    source_order = track_order
                }
            end
        end
    end
    
    -- Сортируем по времени начала, при равном времени - по порядку источников в комболисте
    table.sort(combined, function(a, b) 
        if a.start_time == b.start_time then
            -- При равном времени используем порядок источников в комболисте
            return a.source_order < b.source_order
        else
            return a.start_time < b.start_time
        end
    end)
    
    combined_items_cache = combined
    combined_cache_valid = true
    
    return combined
end

local function invalidate_combined_cache()
    combined_cache_valid = false
    combined_items_cache = nil
end

local function get_combo_list()
    combo_sources = {}

    -- регионы
    if #cur_regions > 0 then
        combo_sources[#combo_sources+1] = {
            guid = "regions",
            name = str.i_regions,
            kind = "regions",
            data = cur_regions
        }
    end

    -- итемы по трекам (только незамьюченые треки с итемами)
    for _, track_data in ipairs(cur_items_by_track) do
        local track_name = track_data.track_name
        local track_guid = track_data.track_guid
        local items_list = track_data.items
        local is_muted   = track_data.is_muted

        -- Показываем в комболисте только незамьюченые треки
        if not is_muted then
        local short_name = (#track_name > 9)
            and (string.sub(track_name, -9))
            or track_name

        combo_sources[#combo_sources+1] = {
            guid  = "items_" .. tostring(track_guid),
            name  = short_name,
            kind  = "text_items",
            track = track_name,  -- полное имя (для отладки)
            data  = items_list
        }
        end
    end

    -- Объединенный источник (только если есть более одного источника)
    if #combo_sources > 1 then
        local combined_data = create_combined_list()
        if #combined_data > 0 then
            combo_sources[#combo_sources+1] = {
                guid = "combined",
                name = str.i_all_items,
                kind = "combined",
                data = combined_data
            }
        end
    end

    -- Восстанавливаем выбранный источник или устанавливаем первый доступный
    if source_guid then
        local found = false
        for i, source in ipairs(combo_sources) do
            if source.guid == source_guid then 
                source_idx = i
                found = true
                break
            end
        end
        if not found then
            source_idx = 1
        end
    else
        source_idx = 1
    end

end

local function update()
    collect_regions()
    collect_text_items()
    get_combo_list()
end

local function get_current_index(pos, source)
    if not source or not source.data or #source.data == 0 then return nil end

    -- быстрый выход по кэшу
    if cached_pos and cached_source_guid == source.guid and math.abs(pos - cached_pos) < 1e-9 then
        return cached_line_idx
    end

    local data = source.data
    local idx_list = {}  -- список всех центральных индексов

    if source.kind == "combined" then
        -- Для объединенного списка собираем ВСЕ элементы, которые попадают под курсор/плейхед
        local elements_in_range = {}
        local closest_prev = nil
        local closest_prev_time = -math.huge
        
        for i = 1, #data do
            local r = data[i]
            -- Проверяем, попадает ли текущая позиция в диапазон элемента
            if pos >= r.start_time and pos <= r.end_time then
                elements_in_range[#elements_in_range + 1] = i
            elseif r.end_time < pos and r.end_time > closest_prev_time then
                -- Ищем ближайшие предыдущие элементы
                if r.end_time == closest_prev_time then
                    -- Элемент с таким же временем окончания - добавляем к списку
                    closest_prev[#closest_prev + 1] = i
                else
                    -- Нашли элемент ближе - начинаем новый список
                    closest_prev_time = r.end_time
                    closest_prev = {i}
                end
            end
        end
        
        if #elements_in_range > 0 then
            -- Есть элементы под плейхедом - используем их
            idx_list = elements_in_range
        elseif closest_prev then
            -- Плейхед между элементами - берем все ближайшие предыдущие со всех источников
            idx_list = closest_prev
        else
            -- Ничего не нашли - берем первый элемент
            idx_list[1] = 1
        end
    else
        -- Обычная логика для других источников - только один элемент
        local idx
        for i = 1, #data do
            if pos < data[i].start_time then
                idx = (i > 1) and (i-1) or 1
                break
            end
        end
        if not idx then idx = #data end
        idx_list[1] = idx
    end

    cached_pos, cached_source_guid, cached_line_idx = pos, source.guid, idx_list
    return idx_list
end

local function project_changed()
    proj_name = reaper.GetProjectName(0)
    proj_id   = reaper.EnumProjects(-1)
    proj_guid = tostring(proj_name .. tostring(proj_id):sub(-6))
    local ProjectStateChangeCount = reaper.GetProjectStateChangeCount(0)
    local CountTracks = reaper.CountTracks(0)
    local _, _, CountRegions = reaper.CountProjectMarkers(0)
    local text_items_count = 0

    if proj_guid ~= last_proj_guid then
        last_proj_guid = proj_guid
        load_settings()
        return true
    elseif ProjectStateChangeCount == last_ProjectStateChangeCount then
        return false
    end

    last_ProjectStateChangeCount = ProjectStateChangeCount
    if CountRegions ~= last_CountRegions then
        last_CountRegions = CountRegions
        return true
    end

    for _, track_data in ipairs(cur_items_by_track or {}) do
        local track_id = track_data.track_id
        -- Проверяем, что трек еще существует
        if track_id and reaper.ValidatePtr(track_id, "MediaTrack*") then
            -- Проверяем изменение статуса mute
            local current_mute_status = reaper.GetMediaTrackInfo_Value(track_id, "B_MUTE") == 1
            local stored_mute_status = track_data.is_muted
            
            -- Если статус mute изменился, это изменение проекта
            if current_mute_status ~= stored_mute_status then
                return true
            end
            
            -- Считаем итемы только для незамьюченых треков
            if not current_mute_status then
            text_items_count = text_items_count + reaper.CountTrackMediaItems(track_id)
            end
        end
    end
    
    if CountTracks ~= last_CountTracks then
        last_CountTracks = CountTracks
        return true
    elseif text_items_count ~= last_text_items_count then
        last_text_items_count = text_items_count
        return true
    end
    
    -- Проверяем изменение BPM
    local current_BPM = reaper.Master_GetTempo()
    if current_BPM ~= last_BPM then
        last_BPM = current_BPM
        return true
    end
    
    return false
end


-- 🪟 UI-служебные функции
local function tooltip(text)
    if not show_tooltips then return end
    if reaper.ImGui_IsItemHovered(ctx) then
        local now = reaper.time_precise()
        local st = tooltip_state[text]
        if not st then
            tooltip_state[text] = { start = now }
        else
            if now - st.start >= tooltip_delay then
                -- используют короткую форму для стабильности
                reaper.ImGui_SetTooltip(ctx, text)
            end
        end
    else
        tooltip_state[text] = nil
    end
end

local function smooth_scroll(target_scroll)
    local scroll_y = reaper.ImGui_GetScrollY(ctx)
    local scroll_max = reaper.ImGui_GetScrollMaxY(ctx)
    target_scroll = math.max(0, math.min(target_scroll, scroll_max))

    if math.abs(scroll_y - target_scroll) > 0.5 then
        -- Вычисляем адаптивную скорость на основе расстояния
        local distance = math.abs(target_scroll - scroll_y)
        local half_h = ui_dimensions.win_height * 0.5
        local adaptive_speed = scroll_speed
        
        -- Увеличиваем скорость кратно в зависимости от расстояния
        if ui_dimensions.win_height > 0 then
            if distance > half_h then
                adaptive_speed = scroll_speed * distance / half_h
            end
        end
        if adaptive_speed > 0.9 then
            adaptive_speed = 0.9
        end
        local new_scroll = scroll_y + (target_scroll - scroll_y) * adaptive_speed
        reaper.ImGui_SetScrollY(ctx, new_scroll)
        return true
    else
        reaper.ImGui_SetScrollY(ctx, target_scroll)
        return false
    end
end

local function scroll_to_center()
    if central_y and ui_dimensions.win_height > 0 then
        local target_scroll = central_y - (ui_dimensions.win_height * 0.5)
        local scroll_max = reaper.ImGui_GetScrollMaxY(ctx)
        target_scroll = math.max(0, math.min(target_scroll, scroll_max))
        
        -- Проверяем ручной скролл (колесико мыши или драг скроллбара)
        local wheel_delta = window_hovered and reaper.ImGui_GetMouseWheel and reaper.ImGui_GetMouseWheel(ctx) or 0
        local mouse_drag = window_hovered and (reaper.ImGui_IsMouseDragging(ctx, 0) or reaper.ImGui_IsMouseDragging(ctx, 1))
        local manual_scroll = (wheel_delta ~= 0) or mouse_drag
        
        -- Проверяем задержку автоскролла
        local allow_auto_scroll = (cur_time - hovered_time > scroll_delay)
        
        -- Проверяем, изменилась ли позиция центрального элемента
        local central_changed = (central_y ~= last_central_y)
        
        -- При ручном скролле немедленно прерываем автоскролл
        if manual_scroll then
            target_scroll_y = nil
        end
        
        if smooth_scroll_enabled then
            -- ПЛАВНЫЙ СКРОЛЛ
            if target_scroll_y then
                -- Скролл уже идет
                if manual_scroll then
                    -- Прерываем при ручном скролле
                    target_scroll_y = nil
                elseif central_changed and allow_auto_scroll then
                    -- Если позиция изменилась и прошла задержка, начинаем новый скролл
                    target_scroll_y = target_scroll
                else
                    -- Продолжаем текущий скролл
                    if not smooth_scroll(target_scroll_y) then
                        target_scroll_y = nil  -- скролл завершен
                    end
                end
            else
                -- Скролла нет - начинаем новый только если окно не накрыто и прошла задержка
                if not window_hovered and allow_auto_scroll then
                    target_scroll_y = target_scroll
                end
            end
        else
            -- МГНОВЕННЫЙ СКРОЛЛ - только если окно не накрыто и прошла задержка
            if not window_hovered and allow_auto_scroll then
                reaper.ImGui_SetScrollY(ctx, target_scroll)
            end
        end
        
        -- Запоминаем текущую позицию
        last_central_y = central_y
    end

end

local function draw_search_highlight(text, search_query, text_col_w)
    -- Функция отрисовывает текст с подсветкой найденного слова
    -- Работает с автопереносом и учитывает ignore_newlines
    -- ВАЖНО: вызывается ПОСЛЕ установки шрифта и позиции курсора!
    
    local query_lower = utf8lower(search_query or "")
    local norm = tostring(text or ""):gsub("\r\n","\n"):gsub("\r","\n")
    
    -- === ВСТРОЕННАЯ ЛОГИКА ПОСТРОЕНИЯ ВИЗУАЛЬНЫХ СТРОК ===
    local vlines = {}
    
    if auto_wrap_enabled and (text_col_w or 0) > 0 then
        -- Функция переноса абзаца
        local function wrap_paragraph(paragraph)
            local lines = {}
            local cur = ""
            local cur_w = 0
            
            for word, space in paragraph:gmatch("(%S+)(%s*)") do
                local segment = word .. space
                local seg_w = reaper.ImGui_CalcTextSize(ctx, segment)
                
                if seg_w > text_col_w and cur == "" then
                    -- Слово шире строки - режем по символам
                    for uchar in segment:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                        local ww = reaper.ImGui_CalcTextSize(ctx, uchar)
                        if cur_w + ww > text_col_w and cur ~= "" then
                            lines[#lines+1] = cur
                            cur, cur_w = "", 0
                        end
                        cur = cur .. uchar
                        cur_w = cur_w + ww
                    end
                elseif cur_w + seg_w > text_col_w and cur ~= "" then
                    -- Перенос на новую строку
                    lines[#lines+1] = cur
                    cur, cur_w = segment, seg_w
                else
                    cur = cur .. segment
                    cur_w = cur_w + seg_w
                end
            end
            lines[#lines+1] = cur
            return lines
        end
        
        -- Обработка текста с учетом ignore_newlines
        if ignore_newlines then
            -- Всё одним абзацем
            local chunk = norm:gsub("\n", " ")
            local wrapped = wrap_paragraph(chunk)
            for _, ln in ipairs(wrapped) do vlines[#vlines+1] = ln end
        else
            -- По абзацам
            for para in (norm .. "\n"):gmatch("([^\n]*)\n") do
                local wrapped = wrap_paragraph(para)
                for _, ln in ipairs(wrapped) do vlines[#vlines+1] = ln end
            end
            if #vlines == 0 then vlines[1] = "" end
        end
    else
        -- Без автопереноса
        if ignore_newlines then
            vlines[1] = norm:gsub("\n"," ")
        else
            for ln in (norm .. "\n"):gmatch("([^\n]*)\n") do
                vlines[#vlines+1] = ln
            end
            if #vlines == 0 then vlines[1] = "" end
        end
    end
    
    -- === ОТРИСОВКА С ПОДСВЕТКОЙ ===
    local start_x, start_y = reaper.ImGui_GetCursorPos(ctx)
    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    
    for li, line in ipairs(vlines) do
        local y_pos = start_y + (li - 1) * line_h
        reaper.ImGui_SetCursorPos(ctx, start_x, y_pos)
        
        -- Поиск совпадения
        local name_lower = utf8lower(line)
        local s_pos, e_pos = nil, nil
        if query_lower ~= "" then
            s_pos, e_pos = name_lower:find(query_lower, 1, true)
        end
        
        if s_pos then
            -- Найдено - разбиваем на 3 части
            local before = line:sub(1, s_pos - 1)
            local match = line:sub(s_pos, e_pos)
            local after = line:sub(e_pos + 1)
            
            -- Рисуем с подсветкой
            reaper.ImGui_Text(ctx, before)
            reaper.ImGui_SameLine(ctx, 0, 0)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), color_settings.search_highlight)
            reaper.ImGui_Text(ctx, match)
            reaper.ImGui_PopStyleColor(ctx)
            reaper.ImGui_SameLine(ctx, 0, 0)
            reaper.ImGui_Text(ctx, after)
        else
            -- Нет совпадения
            reaper.ImGui_Text(ctx, line)
        end
    end
    
    -- Устанавливаем курсор после последней строки
    reaper.ImGui_SetCursorPos(ctx, start_x, start_y + #vlines * line_h)
end


-- 🎨 Отрисовка элементов
local function topmenu()
    if reaper.ImGui_Button(ctx, str.i_import) then
        local info = debug.getinfo(1, "S")
        local base = (info.source:match("@?(.*[\\/])") or "")
        local p1 = base .. "ch_import_text_items_from_sub.lua"
        local p2 = base .. "ch_create_regions_from_text_items.lua"
        if reaper.file_exists(p1) then dofile(p1) end
        if reaper.file_exists(p2) then dofile(p2) end
    end

    reaper.ImGui_SameLine(ctx, 0, 10)
    -- Проверяем статус оверлея через ExtState
    local overlay_is_running = reaper.GetExtState("ChirickSubOverlay_Control", "running") == "true"
    local overlay_button_text = overlay_is_running and str.i_overlay .. " ●" or str.i_overlay
    if reaper.ImGui_Button(ctx, overlay_button_text) then
        if overlay_is_running then
            -- Останавливаем overlay - устанавливаем флаг закрытия
            reaper.SetExtState("ChirickSubOverlay_Control", "close_request", "true", false)
        else
            -- Запускаем overlay
            local info = debug.getinfo(1, "S")
            local base = (info.source:match("@?(.*[\\/])") or "")
            local p = base .. "ch_SubOverlay.lua"
            if reaper.file_exists(p) then
                dofile(p)
            end
        end
    end

    reaper.ImGui_SameLine(ctx, 0, 10)
    if reaper.ImGui_Button(ctx, "⟳") then
        update()
    end
    reaper.ImGui_SameLine(ctx, 0, 0)
    reaper.ImGui_PushItemWidth(ctx, 100)
    local preview = (combo_sources[source_idx] and combo_sources[source_idx].name) or str.i_sources
    if reaper.ImGui_BeginCombo(ctx, "##source_combo", preview) then
        for i, src in ipairs(combo_sources) do
            local selected = (i == source_idx)
            local label = (src.name or ("источник " .. i)) .. "##" .. tostring(src.track_guid or i)
            if reaper.ImGui_Selectable(ctx, label, selected) then
                source_idx = i
                source_guid = src.guid
                calculate_time_width()
                save_settings()  -- сохраняем настройки при смене источника
            end
        end
        reaper.ImGui_EndCombo(ctx)
    end
    reaper.ImGui_PopItemWidth(ctx)

    -- выбор языка
    reaper.ImGui_SameLine(ctx, 0, 10)
    if reaper.ImGui_Button(ctx, lang) then
        reaper.ImGui_OpenPopup(ctx, "lang_popup")
    end
    if reaper.ImGui_BeginPopup(ctx, "lang_popup") then
        for _, code in ipairs(languages) do
            if reaper.ImGui_Selectable(ctx, code, code == lang) then
                lang = code
                load_language_strings(lang)
                get_combo_list()  -- пересоздаём комбо список с новыми строками
            end
        end
        reaper.SetExtState(SETTINGS, "lang", lang, true)
        reaper.ImGui_EndPopup(ctx)
    end

    -- поле поиска
    reaper.ImGui_Text(ctx, "🔎")
    reaper.ImGui_SameLine(ctx, 0, 5)
    reaper.ImGui_PushItemWidth(ctx, 214)
    local changed, new_search = reaper.ImGui_InputText(ctx, "##search", search, 0)
    if changed then
        search = new_search
    end
    reaper.ImGui_PopItemWidth(ctx)


    reaper.ImGui_SameLine(ctx, 0, 0)
    if reaper.ImGui_Button(ctx, "⌫") then
        search = ""
    end



    reaper.ImGui_Dummy(ctx, 0, 2)
end

local function context_menu()
    if reaper.ImGui_BeginPopup(ctx, "ctx_menu") then 
        reaper.ImGui_PushItemWidth(ctx, 140)
        
        local ch = 0
        local function add_change(changed, new_value)
            if changed then ch = ch + 1 end
            return new_value
        end
        
        reaper.ImGui_Text(ctx, str.c_regions)
        -- Шрифт для регионов
        if reaper.ImGui_BeginCombo(ctx, "##region_font", font_names[font_settings.region.idx]) then
            for i, name in ipairs(font_names) do
                if reaper.ImGui_Selectable(ctx, name, i == font_settings.region.idx) then
                    font_settings.region.idx = add_change(i, i)
                    font_settings.region.font = fonts[font_settings.region.idx]
                end
            end
            reaper.ImGui_EndCombo(ctx)
        end
        tooltip(str.t_region_font)
        -- Масштаб для регионов
        font_settings.region.scale = add_change(reaper.ImGui_SliderInt(ctx, "##region_scale", font_settings.region.scale, 10, 100))
        tooltip(str.t_region_scale)
        
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, str.c_items)
        -- Шрифт для итемов
        if reaper.ImGui_BeginCombo(ctx, "##item_font", font_names[font_settings.item.idx]) then
            for i, name in ipairs(font_names) do
                if reaper.ImGui_Selectable(ctx, name, i == font_settings.item.idx) then
                    font_settings.item.idx = add_change(i, i)
                    font_settings.item.font = fonts[font_settings.item.idx]
                end
            end
            reaper.ImGui_EndCombo(ctx)
        end
        tooltip(str.t_item_font)
        -- Масштаб для итемов
        font_settings.item.scale = add_change(reaper.ImGui_SliderInt(ctx, "##item_scale", font_settings.item.scale, 10, 100))
        tooltip(str.t_item_scale)

        -- Центральный масштаб
        reaper.ImGui_Separator(ctx)
        central_scale_enabled = add_change(reaper.ImGui_Checkbox(ctx, str.c_central_scale, central_scale_enabled or false))
        tooltip(str.t_central_scale_title)
        if central_scale_enabled then
            central_scale = add_change(reaper.ImGui_SliderDouble(ctx, "##central_scale", central_scale, 1.0, 1.5, "%.2f"))
            tooltip(str.t_central_scale)
        end

        -- Цвета
        reaper.ImGui_Separator(ctx)
        local function color_edit(label, val)
            local changed
            changed, val = reaper.ImGui_ColorEdit4(
                ctx, label, val,
                reaper.ImGui_ColorEditFlags_NoInputs() | reaper.ImGui_ColorEditFlags_AlphaBar()
            )
            return add_change(changed, val)
        end
        
        color_settings.region.normal     = color_edit(str.c_region_color, color_settings.region.normal)
        color_settings.region.highlight = color_edit(str.c_region_highlight, color_settings.region.highlight)
        color_settings.item.normal       = color_edit(str.c_item_color, color_settings.item.normal)
        color_settings.item.highlight   = color_edit(str.c_item_highlight, color_settings.item.highlight)
        color_settings.search_highlight = color_edit(str.c_search_highlight, color_settings.search_highlight)

        -- Функции
        reaper.ImGui_Separator(ctx)
        smooth_scroll_enabled = add_change(reaper.ImGui_Checkbox(ctx, str.c_smooth_scroll, smooth_scroll_enabled))
        tooltip(str.t_smooth_scroll)
        auto_wrap_enabled = add_change(reaper.ImGui_Checkbox(ctx, str.c_auto_wrap, auto_wrap_enabled))
        tooltip(str.t_auto_wrap)
        
        local old_ignore_newlines = ignore_newlines
        ignore_newlines = add_change(reaper.ImGui_Checkbox(ctx, str.c_ignore_newlines, ignore_newlines))
        tooltip(str.t_ignore_newlines)
        if old_ignore_newlines ~= ignore_newlines then
            invalidate_combined_cache()
            update() -- пересобираем данные при изменении опции
        end

        auto_update_enabled = add_change(reaper.ImGui_Checkbox(ctx, str.c_auto_update, auto_update_enabled))
        tooltip(str.t_auto_update)

        -- Подсказки + задержка
        reaper.ImGui_Separator(ctx)
        show_tooltips = add_change(reaper.ImGui_Checkbox(ctx, str.c_show_tooltips, show_tooltips))
        tooltip(str.t_show_tooltips)
        
        
        -- Сохраняем настройки только если были изменения
        if ch > 0 then
            calculate_time_width()
            save_settings()
        end

        reaper.ImGui_PopItemWidth(ctx)
        reaper.ImGui_EndPopup(ctx)
    else
        want_context_menu = false
    end
end

local function draw_list()
    -- задаем количество центральных элементов
    local central_count = 0
    central_y = nil

    local display_data = (search and search ~= "") and search_filter(src.data, search) or src.data

    local pos = ((ps & 1) == 1) and playhead or cursor
    local idx_list
    
    if search and search ~= "" then
        -- Для поиска ищем индекс в отфильтрованных данных
        idx_list = get_current_index(pos, {data = display_data, kind = src.kind, guid = src.guid})
    else
        -- Без поиска ищем индекс в исходных данных
        idx_list = get_current_index(pos, src)
    end
    
    -- Создаем set для быстрой проверки
    local idx_set = {}
    if idx_list then
        for _, idx in ipairs(idx_list) do
            idx_set[idx] = true
        end
    end

    -- Если список пустой - ничего не рисуем
    if #display_data == 0 then
        return
    end

    -- Определяем базовые стили в зависимости от типа источника
    local base_font, base_scale, base_color, base_highlight
    if src.kind == "regions" then
        base_font, base_scale, base_color, base_highlight = font_settings.region.font, font_settings.region.scale, color_settings.region.normal, color_settings.region.highlight
    else
        base_font, base_scale, base_color, base_highlight = font_settings.item.font, font_settings.item.scale, color_settings.item.normal, color_settings.item.highlight
    end

    -- отрисовываем список
    for i, r in ipairs(display_data) do
        local time, line = r.start_str, (r.name or "")
        
        -- Проверяем, является ли элемент центральным
        local is_current = idx_set[i]
        
        -- Определяем стили для конкретного элемента (для combined источника)
        local element_font, element_scale, element_color, element_highlight = base_font, base_scale, base_color, base_highlight
        if src.kind == "combined" then
            if r.type == "region" then
                element_font = font_settings.region.font
                element_scale = font_settings.region.scale
                element_color = color_settings.region.normal
                element_highlight = color_settings.region.highlight
            elseif r.type == "text_item" then
                element_font = font_settings.item.font
                element_scale = font_settings.item.scale
                element_color = color_settings.item.normal
                element_highlight = color_settings.item.highlight
            end
        end
        
        -- Вычисляем central_scale ПОСЛЕ определения element_scale для конкретного типа
        local element_central_scale
        if central_scale_enabled then
            element_central_scale = element_scale*central_scale
        else
            element_central_scale = element_scale
        end
        
        -- считываем начало курсора
        local x1, y1 = reaper.ImGui_GetCursorPos(ctx)
        
        -- Применяем стили
        if is_current then
            central_count = central_count + 1
            reaper.ImGui_PushFont(ctx, element_font, element_central_scale)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), element_highlight)
        else
            reaper.ImGui_PushFont(ctx, element_font, element_scale)
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), element_color)
        end

        -- включаем автоперенос
        if auto_wrap_enabled then
            reaper.ImGui_PushTextWrapPos(ctx, ui_dimensions.win_width-10)
        end
    

        -- рисуем текст
        reaper.ImGui_Text(ctx, time)
        reaper.ImGui_SameLine(ctx)
        if is_current and central_count == 1 then
            reaper.ImGui_Text(ctx, ">   ")
            reaper.ImGui_SameLine(ctx)
        end
        
        -- Устанавливаем позицию для текста
        reaper.ImGui_SetCursorPosX(ctx, ui_dimensions.time_width + ui_dimensions.space_width)
        
        if search and search ~= "" then
            -- Отрисовка с подсветкой поиска
            local text_col_w = ui_dimensions.win_width - 10 - ui_dimensions.time_width - ui_dimensions.space_width
            draw_search_highlight(line, search, text_col_w)
        else
            -- Обычная отрисовка
            reaper.ImGui_Text(ctx, line)
        end

        -- отключаем стиль
        reaper.ImGui_PopStyleColor(ctx)
        reaper.ImGui_PopFont(ctx)
        

        -- считываем конец курсора
        local x2, y2 = reaper.ImGui_GetCursorPos(ctx)
        
        -- Запоминаем позицию первого центрального элемента
        if central_count == 1 and not central_y then
            central_y = y1 + (y2 - y1) * 0.5
        end
        
        -- рисуем кнопку
        reaper.ImGui_SetCursorPos(ctx, x1, y1)
        -- if reaper.ImGui_Button(ctx, "##row_"..i, -1, y2 - y1) then -- видимая кнопка
        --     reaper.SetEditCurPos(r.start_time or 0, true, true)
        -- end
        if reaper.ImGui_InvisibleButton(ctx, "##row_"..i, -1, y2 - y1) then
            -- Переходим на позицию
            reaper.SetEditCurPos(r.start_time or 0, true, true)
            -- Копируем текст с таймингом в буфер обмена
            reaper.ImGui_SetClipboardText(ctx, string.format("%s - %s", r.start_str or "", r.name or ""))
        end

    end
        
    -- отключаем шрифты и стили
    if auto_wrap_enabled then
        reaper.ImGui_PopTextWrapPos(ctx)
    end

end

local function debug_window()
    reaper.ImGui_SetNextWindowSize(ctx, 300, 200, reaper.ImGui_Cond_Always())
    local visible, open = reaper.ImGui_Begin(ctx, "Debug Info", true)
    if visible then
        reaper.ImGui_Text(ctx, "Project: " .. tostring(proj_name) .. " [" .. tostring(proj_guid) .. "]")
        reaper.ImGui_Text(ctx, "Tracks: " .. tostring(reaper.CountTracks(0)) .. ", Regions: " .. tostring(reaper.CountProjectMarkers(0)))
        reaper.ImGui_Text(ctx, "Source: " .. tostring((combo_sources[source_idx] and combo_sources[source_idx].name) or "nil"))
        reaper.ImGui_Text(ctx, "Cursor: " .. string.format("%.3f", cursor) .. ", Playhead: " .. string.format("%.3f", playhead) .. ", State: " .. tostring(ps))
        reaper.ImGui_Text(ctx, "Items by track: " .. tostring(#cur_items_by_track) .. ", Regions: " .. tostring(#cur_regions))
        reaper.ImGui_Text(ctx, "Combined cache valid: " .. tostring(combined_cache_valid))
    end
    reaper.ImGui_End(ctx)
end

-- 🚦 Основной цикл
local function loop()
    cursor = reaper.GetCursorPosition()                             -- позиция курсора
    playhead = reaper.GetPlayPosition()                             -- позиция плейхеда
    ps = reaper.GetPlayState()                                      -- проигрывается ли проект
    cur_time = reaper.time_precise()                                -- текущее время
    
    if auto_update_enabled and project_changed() then
        invalidate_combined_cache()
        update()
    end

    reaper.ImGui_PushFont(ctx, ui_font, ui_scale)
    reaper.ImGui_SetNextWindowSize(ctx, 600, 400, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_SetNextWindowPos(ctx, 300, 200, reaper.ImGui_Cond_FirstUseEver())
    local visible, open = reaper.ImGui_Begin(ctx, TITLE, true)
    if visible then
        -- Верхнее меню
        topmenu()

        -- Дочернее окно
        if reaper.ImGui_BeginChild(ctx, "child", 0, 0, 0) then
            ui_dimensions.win_width, ui_dimensions.win_height = reaper.ImGui_GetWindowSize(ctx)
            window_hovered = reaper.ImGui_IsWindowHovered(ctx)
            if window_hovered then hovered_time = cur_time end
            src = combo_sources[source_idx]
            if src then
                draw_list()
            else
                reaper.ImGui_TextWrapped( ctx, str.i_empty )
            end

            -- Скролл к центральному элементу
            scroll_to_center()

            -- ПКМ → контекстное меню
            if window_hovered and reaper.ImGui_IsMouseClicked(ctx, 1) then
                reaper.ImGui_OpenPopup(ctx, "ctx_menu")
                want_context_menu = true
            end
            if want_context_menu then context_menu() end

            reaper.ImGui_EndChild(ctx)
        end
        
        -- debug info
        if debug_mode then
            debug_window()
        end
        reaper.ImGui_End(ctx)
    end
    
    reaper.ImGui_PopFont(ctx)
    if open then reaper.defer(loop) end
end

load_settings()
load_language_strings(lang)
update()
reaper.defer(loop)
