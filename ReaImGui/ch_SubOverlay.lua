-- @description SubOverlay
-- @author Chirick
-- @version 1.0.1
-- @changelog
--   + Added autostart option for Prompter startup
--   + Some minor optimizations and fixes
-- @link https://github.com/chirick86/reaperscripts
-- @donation https://patreon.com/chirick
-- @about
--   # SubOverlay
--   
--   Subtitle overlay over REAPER video window
--   
--   ## Features
--   * Shows text of current and next region/item during playback
--   * Can be attached to REAPER video window (automatically follows it)
--   * Customizable fonts, colors, shadows for each line
--   * Progress bar shows current region/item progress
--   * Smart line wrapping, vertical and horizontal alignment
--   * Transparent background, hide title bar - for minimalist display
--   * "Fill gaps" mode - shows nearest text even between regions
--   
--   ## Requirements
--   * ReaImGui (install via ReaPack)

--[[TODO:
-- check some moments in auto-wrap combined with auto-resize]]

if not reaper.ImGui_CreateContext then
    reaper.ShowMessageBox("ReaImGui not found. Install ReaImGui.", "Error", 0)
    return
end



-- Constants for ExtState control
local RUNNING_KEY = "running"
local AUTOSTART_KEY = "autostart_on_prompter"
local SETTINGS_SECTION = "ChirickSubOverlay"

local _, _, _, cmdID = reaper.get_action_context()
-- Return stable script identifier (_RS...)
local scriptID = "_" .. reaper.ReverseNamedCommandLookup(cmdID)
reaper.SetExtState(SETTINGS_SECTION, "scriptID", scriptID, true)  -- Store scriptID for autostart purposes


-- Read state
local already_running = reaper.GetExtState(SETTINGS_SECTION, RUNNING_KEY)


-- Set flag that script is running
reaper.SetExtState(SETTINGS_SECTION, RUNNING_KEY, "true", false)

-- Register cleanup function on exit (called on any exit)
reaper.atexit(function()
    reaper.DeleteExtState(SETTINGS_SECTION, RUNNING_KEY, true)
end)

local debug_mode = false
local ctx = reaper.ImGui_CreateContext("Sub Overlay")
local win_X, win_Y, win_w, win_h = 500, 500, 500, 300
local win_open = true
local close_requested = false

-- Simple cache for optimization
local last_pos = nil
local cached_current, cached_next, cached_start, cached_stop = nil, nil, nil, nil

-- Cache for video window coordinates
local video_cache_valid = false
local cached_video_x1, cached_video_y1, cached_video_x2, cached_video_y2 = nil, nil, nil, nil
local cached_attach_x, cached_attach_y, cached_attach_w = nil, nil, nil
local is_user_resizing = false          -- flag to track user resize
local show_wrap_guides = false          -- flag to show wrap guide lines


-- Font and scale settings
local BASE_FONT_SIZE = 14               -- base font size for creating font objects
local available_fonts = {
    "Arial","Calibri","Roboto","Segoe UI","Tahoma","Verdana",
    "Cambria","CooperMediumC BT","Georgia","Times New Roman",
    "Consolas","Courier New"
}
local font_objects = {}
for i, name in ipairs(available_fonts) do
    local f = reaper.ImGui_CreateFont(name, BASE_FONT_SIZE)
    font_objects[i] = f
    reaper.ImGui_Attach(ctx, f)
end

local ui_font = font_objects[1]         -- first font always for UI
local UI_FONT_SCALE = 14                -- fixed scale for interface
local CONTEXT_MENU_MIN_WIDTH = 100      -- minimum context menu width
local next_region_offset = 20           -- offset between current and next region
local show_progress = true              -- show progress bar
local progress_width = 400              -- default width
local progress_height = 4               -- default height
local progress_offset = 20              -- offset from first line
local padding_x = 6                     -- padding for background under text
local padding_y = 3                     -- padding for background under text
local current_font_index = 1            -- font index
local font_scale = 30                   -- font size
local text_color   = 0xFFBB00FF         -- text color
local shadow_color = 0x000000FF         -- shadow color
local second_font_index = 1             -- font index for second line
local second_font_scale = 22            -- second line size
local second_text_color = 0x99BB22FF    -- second line color
local second_shadow_color = 0x000000FF  -- second line shadow color
local source_mode = nil                 -- 0 = regions, >0 = track number with items
local window_bg_color = 0x00000088      -- background color black with transparency
local border = false                    -- draw background under text
local enable_wrap = true                -- wrap text by words
local wrap_margin = 0                   -- offset from window edge for auto-wrap (pixels)
local enable_second_line = true         -- show second line
local align_center = true               -- center alignment (horizontal, default on)
local align_vertical = false            -- vertical alignment (center content in window)
local fill_gaps = true                  -- show nearest region/item between objects
local show_tooltips = true              -- show tooltips
local tooltip_delay = 0.5
local tooltip_state = {}
local attach_to_video = false           -- attach to video window
local attach_bottom = false             -- attach mode: "bottom"
local attach_offset = 0                 -- offset in percents (0-100)
local ignore_newlines = false           -- ignore line break characters when reading
local autostart_on_prompter = false     -- autostart when Prompter starts



local flags = {
    NoTitle = false,
    NoResize = false,
    AlwaysAutoResize = false,
    NoDocking = true,
    HideBackground = false,
    NoMove = false
}

-- ========================
-- TRANSLATE SECTION (i18n)
-- ========================
local languages = {"EN", "DE", "FR", "RU", "UK"}
local str = {}

local i18n = {
    EN = {
        -- Errors
        err_reaimgui = "ReaImGui not found. Install ReaImGui.",
        -- Mode selection
        m_mode = "Mode",
        m_regions = "0: Regions",
        m_items = "%d: Items (track %d)",
        t_mode = "Allows you to select display mode based on available regions or items on tracks",
        -- Window flags
        c_pin = "Pin",
        t_pin = "Disables window dragging",
        c_hide_title = "Hide title",
        t_hide_title = "Disables window title",
        c_hide_bg = "Hide background",
        t_hide_bg = "Completely removes window background, making it transparent",
        c_border = "Border under text",
        t_border = "Enables background under each line. The color is the window background color",
        c_bg_color = "Window background color",
        t_bg_color = "Sets background and border color",
        c_h_center = "Horizontal center",
        t_h_center = "Aligns lines to the center of the window (horizontally)",
        c_v_center = "Vertical center",
        t_v_center = "Aligns lines vertically",
        c_wrap = "Text wrapping",
        t_wrap = "Does not allow lines to go outside the window, breaking them into equal segments",
        c_wrap_margin = "Wrap offset",
        t_wrap_margin = "Offset from edge when wrapping (pixels)\nApplied on both sides",
        c_ignore_nl = "Ignore breaks",
        t_ignore_nl = "Ignore line break characters \\n when reading text from regions/items",
        c_fill_gaps = "Fill gaps",
        t_fill_gaps = "Allows displaying lines outside regions/items",
        c_no_resize = "No resize",
        t_no_resize = "Disables window resizing",
        c_auto_resize = "Auto resize",
        t_auto_resize = "Automatically adjusts window size to text length and progress bar",
        c_attach_video = "Attach to video",
        t_attach_video = "Automatically positions window relative to REAPER video window\nRequires js_ReaScriptAPI",
        c_attach_bottom = "Attach to bottom",
        t_attach_bottom = "Choose attachment side",
        c_attach_offset = "Offset##attach",
        t_attach_offset = "Position as percentage of video window height",
        c_no_dock = "No docking",
        t_no_dock = "Disables embedding and snapping windows. Dragging must be done by title or top edge",
        c_tooltips = "Tooltips",
        t_tooltips = "Enables floating tooltips",
        -- First line styling
        h_first_line = "First line",
        c_font = "Font",
        c_scale = "Scale",
        c_color = "Color",
        c_shadow = "Shadow",
        -- Progress bar
        h_progress = "Progress bar",
        c_progress = "Progress bar",
        t_progress = "Enables current region/item duration animation",
        c_length = "Length",
        c_thickness = "Thickness",
        c_offset = "Offset",
        -- Second line styling
        h_second_line = "Second line",
        c_second_line = "Second line",
        t_second_line = "Enables displaying the next region/item line",
        c_font2 = "Font 2",
        c_scale2 = "Scale 2",
        c_offset2 = "Offset 2",
        c_color2 = "Color 2",
        c_shadow2 = "Shadow 2",
        -- Language
        c_language = "Language",
        t_language = "Click to select display language",
        -- Autostart
        c_autostart = "Autostart on Prompter",
        t_autostart = "Automatically launch SubOverlay when Prompter starts",
        -- Buttons
        b_close = "Close window"
    },
    DE = {
        err_reaimgui = "ReaImGui nicht gefunden. Installieren Sie ReaImGui.",
        m_mode = "Modus",
        m_regions = "0: Regionen",
        m_items = "%d: Elemente (Spur %d)",
        t_mode = "Ermöglicht die Auswahl des Anzeigemodus basierend auf verfügbaren Regionen oder Elementen auf Spuren",
        c_pin = "Befestigen",
        t_pin = "Deaktiviert das Verschieben von Fenstern",
        c_hide_title = "Titel verbergen",
        t_hide_title = "Deaktiviert den Fenstertitel",
        c_hide_bg = "Hintergrund verbergen",
        t_hide_bg = "Entfernt den Fensterhintergrund vollständig und macht ihn transparent",
        c_border = "Rand unter dem Text",
        t_border = "Aktiviert einen Hintergrund unter jeder Zeile. Die Farbe ist die Fensterhintergrundfarbe",
        c_bg_color = "Fensterhintergrundfarbe",
        t_bg_color = "Setzt Hintergrund- und Randfarbe",
        c_h_center = "Horizontale Zentrierung",
        t_h_center = "Richtet Zeilen zur Mitte des Fensters aus (horizontal)",
        c_v_center = "Vertikale Zentrierung",
        t_v_center = "Richtet Zeilen vertikal aus",
        c_wrap = "Textumbruch",
        t_wrap = "Verhindert, dass Zeilen die Grenzen des Fensters überschreiten",
        c_wrap_margin = "Umbruchabstand",
        t_wrap_margin = "Abstand vom Rand beim Umbruch (Pixel)\nWird auf beiden Seiten angewendet",
        c_ignore_nl = "Umbrüche ignorieren",
        t_ignore_nl = "Zeilenumbruchzeichen \\n beim Lesen von Text aus Regionen/Elementen ignorieren",
        c_fill_gaps = "Lücken füllen",
        t_fill_gaps = "Ermöglicht die Anzeige von Zeilen außerhalb von Regionen/Elementen",
        c_no_resize = "Keine Größenänderung",
        t_no_resize = "Deaktiviert die Fenstergrößenanpassung",
        c_auto_resize = "Automatische Größenanpassung",
        t_auto_resize = "Passt die Fenstergröße automatisch an die Textlänge und Fortschrittsleiste an",
        c_attach_video = "An Video anheften",
        t_attach_video = "Positioniert das Fenster automatisch relativ zum REAPER-Videofenster\nErfordert js_ReaScriptAPI",
        c_attach_bottom = "Am unten anheften",
        t_attach_bottom = "Anheftungsseite wählen",
        c_attach_offset = "Abstand##attach",
        t_attach_offset = "Position in Prozent der Videofensterhöhe",
        c_no_dock = "Kein Andocken",
        t_no_dock = "Deaktiviert das Einbetten und Einrasten von Fenstern",
        c_tooltips = "Tooltips",
        t_tooltips = "Aktiviert schwebende Tooltips",
        h_first_line = "Erste Zeile",
        c_font = "Schriftart",
        c_scale = "Skalierung",
        c_color = "Farbe",
        c_shadow = "Schatten",
        h_progress = "Fortschrittsleiste",
        c_progress = "Fortschrittsleiste",
        t_progress = "Aktiviert die Animationsanimation der aktuellen Region/Elementdauer",
        c_length = "Länge",
        c_thickness = "Dicke",
        c_offset = "Abstand",
        h_second_line = "Zweite Zeile",
        c_second_line = "Zweite Zeile",
        t_second_line = "Aktiviert die Anzeige der nächsten Region/Elementzeile",
        c_font2 = "Schriftart 2",
        c_scale2 = "Skalierung 2",
        c_offset2 = "Abstand 2",
        c_color2 = "Farbe 2",
        c_shadow2 = "Schatten 2",
        -- Sprache
        c_language = "Sprache",
        t_language = "Klicken Sie, um die Anzeigesprache auszuwählen",
        -- Autostart
        c_autostart = "Autostart bei Prompter",
        t_autostart = "SubOverlay automatisch starten, wenn Prompter startet",
        -- Schaltflächen
        b_close = "Fenster schließen"
    },
    FR = {
        err_reaimgui = "ReaImGui non trouvé. Installez ReaImGui.",
        m_mode = "Mode",
        m_regions = "0 : Régions",
        m_items = "%d : Éléments (piste %d)",
        t_mode = "Vous permet de sélectionner le mode d'affichage en fonction des régions ou éléments disponibles sur les pistes",
        c_pin = "Épingler",
        t_pin = "Désactive le déplacement de la fenêtre",
        c_hide_title = "Masquer le titre",
        t_hide_title = "Désactive le titre de la fenêtre",
        c_hide_bg = "Masquer le fond",
        t_hide_bg = "Supprime complètement l'arrière-plan de la fenêtre, le rendant transparent",
        c_border = "Bordure sous le texte",
        t_border = "Active un arrière-plan sous chaque ligne. La couleur est la couleur d'arrière-plan de la fenêtre",
        c_bg_color = "Couleur d'arrière-plan de la fenêtre",
        t_bg_color = "Définit la couleur d'arrière-plan et de bordure",
        c_h_center = "Centrage horizontal",
        t_h_center = "Aligne les lignes au centre de la fenêtre (horizontalement)",
        c_v_center = "Centrage vertical",
        t_v_center = "Aligne les lignes verticalement",
        c_wrap = "Retour à la ligne",
        t_wrap = "Empêche les lignes de dépasser les limites de la fenêtre",
        c_wrap_margin = "Décalage de retour",
        t_wrap_margin = "Décalage par rapport au bord lors du retour à la ligne (pixels)\nS'applique des deux côtés",
        c_ignore_nl = "Ignorer les sauts",
        t_ignore_nl = "Ignorer les caractères de saut de ligne \\n lors de la lecture du texte à partir des régions/éléments",
        c_fill_gaps = "Remplir les espaces",
        t_fill_gaps = "Permet d'afficher les lignes en dehors des régions/éléments",
        c_no_resize = "Pas de redimensionnement",
        t_no_resize = "Désactive le redimensionnement de la fenêtre",
        c_auto_resize = "Redimensionnement automatique",
        t_auto_resize = "Ajuste automatiquement la taille de la fenêtre à la longueur du texte et à la barre de progression",
        c_attach_video = "Joindre à la vidéo",
        t_attach_video = "Positionne automatiquement la fenêtre par rapport à la fenêtre vidéo REAPER\nNécessite js_ReaScriptAPI",
        c_attach_bottom = "Joindre au bas",
        t_attach_bottom = "Choisir le côté d'attachement",
        c_attach_offset = "Décalage##attach",
        t_attach_offset = "Position en pourcentage de la hauteur de la fenêtre vidéo",
        c_no_dock = "Pas d'amarrage",
        t_no_dock = "Désactive l'intégration et l'amarrage des fenêtres",
        c_tooltips = "Astuces",
        t_tooltips = "Active les astuces flottantes",
        h_first_line = "Première ligne",
        c_font = "Police",
        c_scale = "Échelle",
        c_color = "Couleur",
        c_shadow = "Ombre",
        h_progress = "Barre de progression",
        c_progress = "Barre de progression",
        t_progress = "Active l'animation de la durée de la région/élément actuelle",
        c_length = "Longueur",
        c_thickness = "Épaisseur",
        c_offset = "Décalage",
        h_second_line = "Deuxième ligne",
        c_second_line = "Deuxième ligne",
        t_second_line = "Active l'affichage de la ligne du prochain région/élément",
        c_font2 = "Police 2",
        c_scale2 = "Échelle 2",
        c_offset2 = "Décalage 2",
        c_color2 = "Couleur 2",
        c_shadow2 = "Ombre 2",
        -- Langue
        c_language = "Langue",
        t_language = "Cliquez pour sélectionner la langue d'affichage",
        -- Autostart
        c_autostart = "Démarrage auto sur Prompter",
        t_autostart = "Lancer automatiquement SubOverlay au démarrage de Prompter",
        -- Boutons
        b_close = "Fermer la fenêtre"
    },
    RU = {
        err_reaimgui = "ReaImGui не найден. Установите ReaImGui.",
        m_mode = "Режим",
        m_regions = "0: Регионы",
        m_items = "%d: Итемы (трек %d)",
        t_mode = "Позволяет выбрать режим отображения исходя из доступности регионов или итемов на треках",
        c_pin = "Закрепить",
        t_pin = "Отключает возможность перетаскивать окно",
        c_hide_title = "Скрыть заголовок",
        t_hide_title = "Отключает заголовок окна",
        c_hide_bg = "Скрыть фон",
        t_hide_bg = "Полностью убирает фон окна, делая его прозрачным",
        c_border = "Фон под текстом",
        t_border = "Включает подложку под каждой строкой. Цветом выступает цвет фона",
        c_bg_color = "Цвет фона окна",
        t_bg_color = "Задает цвет фона и подложки",
        c_h_center = "Центрирование по горизонтали",
        t_h_center = "Выравнивает строки по центру окна (горизонтально)",
        c_v_center = "Центрирование по вертикали",
        t_v_center = "Выравнивает строки по вертикали",
        c_wrap = "Перенос строк",
        t_wrap = "Не позволяет строкам вылезать за пределы окна, разбивая их на равные отрезки",
        c_wrap_margin = "отступ переноса",
        t_wrap_margin = "Отступ от края окна при автопереносе (пиксели)\nУчитывается с обеих сторон",
        c_ignore_nl = "Игнорировать переносы",
        t_ignore_nl = "Игнорировать символы переноса строки \\n при чтении текста из регионов/итемов",
        c_fill_gaps = "Заполнять пробелы",
        t_fill_gaps = "Позволяет отображать строки и за пределами регионов/итемов",
        c_no_resize = "Не менять размеры",
        t_no_resize = "Отключает возможность изменять размеры окна",
        c_auto_resize = "Авторесайз окна",
        t_auto_resize = "Автоматически подбирает размер окна под длину строк и прогрессбара",
        c_attach_video = "Привязать к видеоокну",
        t_attach_video = "Автоматически позиционирует окно относительно видеоокна REAPER\nТребуется js_ReaScriptAPI",
        c_attach_bottom = "Привязка к нижней границе",
        t_attach_bottom = "Выбор стороны привязки",
        c_attach_offset = "отступ##attach",
        t_attach_offset = "Позиция в процентах относительно высоты видеоокна",
        c_no_dock = "Не стыковать",
        t_no_dock = "Отключает возможность встраивания и прилипания окна. Перетаскивать необходимо за заголовок или верхнюю границу окна",
        c_tooltips = "Подсказки",
        t_tooltips = "Включает отображение всплывающих подсказок",
        h_first_line = "Первая строка",
        c_font = "шрифт",
        c_scale = "масштаб",
        c_color = "цвет",
        c_shadow = "тень",
        h_progress = "Прогрессбар",
        c_progress = "Прогрессбар",
        t_progress = "Включает анимацию длительности текущего региона/итема",
        c_length = "длина",
        c_thickness = "толщина",
        c_offset = "отступ",
        h_second_line = "Вторая строка",
        c_second_line = "Вторая строка",
        t_second_line = "Включает отображение строки следующего региона/итема",
        c_font2 = "шрифт 2",
        c_scale2 = "масштаб 2",
        c_offset2 = "отступ 2",
        c_color2 = "цвет 2",
        c_shadow2 = "тень 2",
        -- Язык
        c_language = "Language",
        t_language = "Click to select interface language",
        -- Autostart
        c_autostart = "Autostart with Prompter",
        t_autostart = "Automatically launch SubOverlay at Prompter startup",
        -- Buttons
        b_close = "Close window"
    },
    UK = {
        err_reaimgui = "ReaImGui не знайдено. Встановіть ReaImGui.",
        m_mode = "Режим",
        m_regions = "0: Регіони",
        m_items = "%d: Елементи (доріжка %d)",
        t_mode = "Дозволяє вибрати режим відображення на основі доступних регіонів або елементів на доріжках",
        c_pin = "Закріпити",
        t_pin = "Вимикає можливість перетягування вікна",
        c_hide_title = "Приховати заголовок",
        t_hide_title = "Вимикає заголовок вікна",
        c_hide_bg = "Приховати фон",
        t_hide_bg = "Повністю видаляє фон вікна, роблячи його прозорим",
        c_border = "Межа під текстом",
        t_border = "Включає фон під кожною строкою. Колір - це колір фону вікна",
        c_bg_color = "Колір фону вікна",
        t_bg_color = "Установлює колір фону та межі",
        c_h_center = "Центрування по горизонталі",
        t_h_center = "Вирівнює рядки до центру вікна (горизонтально)",
        c_v_center = "Центрування по вертикалі",
        t_v_center = "Вирівнює рядки вертикально",
        c_wrap = "Перенесення тексту",
        t_wrap = "Запобігає виходу рядків за межі вікна",
        c_wrap_margin = "Відступ переносу",
        t_wrap_margin = "Відступ від краю при переносі (пікселів)\nЗастосовується з обох сторін",
        c_ignore_nl = "Ігнорувати розриви",
        t_ignore_nl = "Ігнорувати символи розриву рядка \\n при зчитуванні тексту з регіонів/елементів",
        c_fill_gaps = "Заповнювати прогалини",
        t_fill_gaps = "Дозволяє відображувати рядки за межами регіонів/елементів",
        c_no_resize = "Без зміни розміру",
        t_no_resize = "Вимикає можливість змінювати розмір вікна",
        c_auto_resize = "Автоматична зміна розміру",
        t_auto_resize = "Автоматично підбирає розмір вікна під довжину тексту та смугу прогресу",
        c_attach_video = "Приєднати до відео",
        t_attach_video = "Автоматично позиціонує вікно відносно вікна відео REAPER\nВимагає js_ReaScriptAPI",
        c_attach_bottom = "Приєднати до нижньої межі",
        t_attach_bottom = "Оберіть сторону приєднання",
        c_attach_offset = "Відступ##attach",
        t_attach_offset = "Позиція у відсотках від висоти вікна відео",
        c_no_dock = "Не стикувати",
        t_no_dock = "Вимикає можливість вбудовування та прикріплення вікон",
        c_tooltips = "Підказки",
        t_tooltips = "Включає плаваючі підказки",
        h_first_line = "Перший рядок",
        c_font = "шрифт",
        c_scale = "масштаб",
        c_color = "колір",
        c_shadow = "тінь",
        h_progress = "Смуга прогресу",
        c_progress = "Смуга прогресу",
        t_progress = "Включає анімацію тривалості поточного регіону/елемента",
        c_length = "довжина",
        c_thickness = "товщина",
        c_offset = "відступ",
        h_second_line = "Другий рядок",
        c_second_line = "Другий рядок",
        t_second_line = "Включає відображення рядка наступного регіону/елемента",
        c_font2 = "шрифт 2",
        c_scale2 = "масштаб 2",
        c_offset2 = "відступ 2",
        c_color2 = "колір 2",
        c_shadow2 = "тінь 2",
        -- Мова
        c_language = "Language",
        t_language = "Click to select interface language",
        -- Autostart
        c_autostart = "Autostart with Prompter",
        t_autostart = "Автоматично запускати SubOverlay при старті Prompter",
        -- Кнопки
        b_close = "Закрити вікно"
    }
}


-- ===============
-- FUNCTIONS BLOCK
-- ===============

-- Function to load strings of the current language
local function load_language_strings(lang_code)
    local trans = i18n[lang_code] or i18n["EN"]
    str.err_reaimgui = trans.err_reaimgui
    str.m_mode = trans.m_mode
    str.m_regions = trans.m_regions
    str.m_items = trans.m_items
    str.t_mode = trans.t_mode
    str.c_pin = trans.c_pin
    str.t_pin = trans.t_pin
    str.c_hide_title = trans.c_hide_title
    str.t_hide_title = trans.t_hide_title
    str.c_hide_bg = trans.c_hide_bg
    str.t_hide_bg = trans.t_hide_bg
    str.c_border = trans.c_border
    str.t_border = trans.t_border
    str.c_bg_color = trans.c_bg_color
    str.t_bg_color = trans.t_bg_color
    str.c_h_center = trans.c_h_center
    str.t_h_center = trans.t_h_center
    str.c_v_center = trans.c_v_center
    str.t_v_center = trans.t_v_center
    str.c_wrap = trans.c_wrap
    str.t_wrap = trans.t_wrap
    str.c_wrap_margin = trans.c_wrap_margin
    str.t_wrap_margin = trans.t_wrap_margin
    str.c_ignore_nl = trans.c_ignore_nl
    str.t_ignore_nl = trans.t_ignore_nl
    str.c_fill_gaps = trans.c_fill_gaps
    str.t_fill_gaps = trans.t_fill_gaps
    str.c_no_resize = trans.c_no_resize
    str.t_no_resize = trans.t_no_resize
    str.c_auto_resize = trans.c_auto_resize
    str.t_auto_resize = trans.t_auto_resize
    str.c_attach_video = trans.c_attach_video
    str.t_attach_video = trans.t_attach_video
    str.c_attach_bottom = trans.c_attach_bottom
    str.t_attach_bottom = trans.t_attach_bottom
    str.c_attach_offset = trans.c_attach_offset
    str.t_attach_offset = trans.t_attach_offset
    str.c_no_dock = trans.c_no_dock
    str.t_no_dock = trans.t_no_dock
    str.c_tooltips = trans.c_tooltips
    str.t_tooltips = trans.t_tooltips
    str.h_first_line = trans.h_first_line
    str.c_font = trans.c_font
    str.c_scale = trans.c_scale
    str.c_color = trans.c_color
    str.c_shadow = trans.c_shadow
    str.h_progress = trans.h_progress
    str.c_progress = trans.c_progress
    str.t_progress = trans.t_progress
    str.c_length = trans.c_length
    str.c_thickness = trans.c_thickness
    str.c_offset = trans.c_offset
    str.h_second_line = trans.h_second_line
    str.c_second_line = trans.c_second_line
    str.t_second_line = trans.t_second_line
    str.c_font2 = trans.c_font2
    str.c_scale2 = trans.c_scale2
    str.c_offset2 = trans.c_offset2
    str.c_color2 = trans.c_color2
    str.c_shadow2 = trans.c_shadow2
    str.c_language = trans.c_language
    str.t_language = trans.t_language
    str.c_autostart = trans.c_autostart
    str.t_autostart = trans.t_autostart
    str.b_close = trans.b_close
end

-- Save/load settings
local function save_settings()
    reaper.SetExtState(SETTINGS_SECTION, "NoTitle", tostring(flags.NoTitle), true)
    reaper.SetExtState(SETTINGS_SECTION, "HideBackground", tostring(flags.HideBackground), true)
    reaper.SetExtState(SETTINGS_SECTION, "NoResize", tostring(flags.NoResize), true)
    reaper.SetExtState(SETTINGS_SECTION, "AlwaysAutoResize", tostring(flags.AlwaysAutoResize), true)
    reaper.SetExtState(SETTINGS_SECTION, "NoMove", tostring(flags.NoMove), true)
    reaper.SetExtState(SETTINGS_SECTION, "NoDocking", tostring(flags.NoDocking), true)  
    reaper.SetExtState(SETTINGS_SECTION, "current_font_index", tostring(current_font_index), true)
    reaper.SetExtState(SETTINGS_SECTION, "font_scale", tostring(font_scale), true)
    reaper.SetExtState(SETTINGS_SECTION, "text_color", string.format("%08X", text_color), true)
    reaper.SetExtState(SETTINGS_SECTION, "shadow_color", string.format("%08X", shadow_color), true)
    reaper.SetExtState(SETTINGS_SECTION, "second_font_index", tostring(second_font_index), true)
    reaper.SetExtState(SETTINGS_SECTION, "second_font_scale", tostring(second_font_scale), true)
    reaper.SetExtState(SETTINGS_SECTION, "next_region_offset", tostring(next_region_offset), true)
    reaper.SetExtState(SETTINGS_SECTION, "second_text_color", string.format("%08X", second_text_color), true)
    reaper.SetExtState(SETTINGS_SECTION, "second_shadow_color", string.format("%08X", second_shadow_color), true)
    reaper.SetExtState(SETTINGS_SECTION, "window_bg_color", string.format("%08X", window_bg_color), true)
    reaper.SetExtState(SETTINGS_SECTION, "border", tostring(border), true)
    reaper.SetExtState(SETTINGS_SECTION, "enable_wrap", tostring(enable_wrap), true)
    reaper.SetExtState(SETTINGS_SECTION, "wrap_margin", tostring(wrap_margin), true)
    reaper.SetExtState(SETTINGS_SECTION, "enable_second_line", tostring(enable_second_line), true)
    reaper.SetExtState(SETTINGS_SECTION, "show_progress", tostring(show_progress), true)
    reaper.SetExtState(SETTINGS_SECTION, "progress_width", tostring(progress_width), true)
    reaper.SetExtState(SETTINGS_SECTION, "progress_height", tostring(progress_height), true)
    reaper.SetExtState(SETTINGS_SECTION, "progress_offset", tostring(progress_offset), true)
    reaper.SetExtState(SETTINGS_SECTION, "align_center", tostring(align_center), true)
    reaper.SetExtState(SETTINGS_SECTION, "align_vertical", tostring(align_vertical), true)
    reaper.SetExtState(SETTINGS_SECTION, "fill_gaps", tostring(fill_gaps), true)
    reaper.SetExtState(SETTINGS_SECTION, "show_tooltips", tostring(show_tooltips), true)
    reaper.SetExtState(SETTINGS_SECTION, "attach_to_video", tostring(attach_to_video), true)
    reaper.SetExtState(SETTINGS_SECTION, "attach_bottom", tostring(attach_bottom), true)
    reaper.SetExtState(SETTINGS_SECTION, "attach_offset", tostring(attach_offset), true)
    reaper.SetExtState(SETTINGS_SECTION, "ignore_newlines", tostring(ignore_newlines), true)
    reaper.SetExtState(SETTINGS_SECTION, "lang", lang, true)
    -- Store autostart in common SETTINGS_SECTION for access from Prompter
    reaper.SetExtState(SETTINGS_SECTION, AUTOSTART_KEY, tostring(autostart_on_prompter), true)
    -- Store window height only if video attachment is enabled
    if attach_to_video then
        reaper.SetExtState(SETTINGS_SECTION, "win_h", tostring(win_h), true)
    end
    
    -- Invalidate cache coordinates on settings save
    video_cache_valid = false
end

local function load_settings()
    flags.NoTitle = reaper.GetExtState(SETTINGS_SECTION, "NoTitle") == "true"
    flags.HideBackground = reaper.GetExtState(SETTINGS_SECTION, "HideBackground") == "true"
    flags.NoResize = reaper.GetExtState(SETTINGS_SECTION, "NoResize") == "true"
    flags.AlwaysAutoResize = reaper.GetExtState(SETTINGS_SECTION, "AlwaysAutoResize") == "true"
    flags.NoMove = reaper.GetExtState(SETTINGS_SECTION, "NoMove") == "true"
    flags.NoDocking = reaper.GetExtState(SETTINGS_SECTION, "NoDocking") == "true"
    current_font_index = tonumber(reaper.GetExtState(SETTINGS_SECTION, "current_font_index")) or 1
    font_scale = tonumber(reaper.GetExtState(SETTINGS_SECTION, "font_scale")) or 30
    second_font_index = tonumber(reaper.GetExtState(SETTINGS_SECTION, "second_font_index")) or 1
    second_font_scale = tonumber(reaper.GetExtState(SETTINGS_SECTION, "second_font_scale")) or 30
    next_region_offset = tonumber(reaper.GetExtState(SETTINGS_SECTION, "next_region_offset")) or 40
    local txt_col = reaper.GetExtState(SETTINGS_SECTION, "text_color")
    if txt_col ~= "" then text_color = tonumber(txt_col,16) or text_color end
    local shd_col = reaper.GetExtState(SETTINGS_SECTION, "shadow_color")
    if shd_col ~= "" then shadow_color = tonumber(shd_col,16) or shadow_color end
    local txt2_col = reaper.GetExtState(SETTINGS_SECTION, "second_text_color")
    if txt2_col ~= "" then second_text_color = tonumber(txt2_col,16) or second_text_color end
    local shd2_col = reaper.GetExtState(SETTINGS_SECTION, "second_shadow_color")
    if shd2_col ~= "" then second_shadow_color = tonumber(shd2_col,16) or second_shadow_color end
    local winbg_col = reaper.GetExtState(SETTINGS_SECTION, "window_bg_color")
    if winbg_col ~= "" then window_bg_color = tonumber(winbg_col,16) or window_bg_color end
    border = (reaper.GetExtState(SETTINGS_SECTION, "border") == "true")
    enable_wrap = (reaper.GetExtState(SETTINGS_SECTION, "enable_wrap") ~= "false")
    wrap_margin = tonumber(reaper.GetExtState(SETTINGS_SECTION, "wrap_margin")) or 0
    enable_second_line = (reaper.GetExtState(SETTINGS_SECTION, "enable_second_line") == "true")
    show_progress = (reaper.GetExtState(SETTINGS_SECTION, "show_progress") == "true")
    progress_width = tonumber(reaper.GetExtState(SETTINGS_SECTION, "progress_width")) or 400
    progress_height = tonumber(reaper.GetExtState(SETTINGS_SECTION, "progress_height")) or 4
    progress_offset = tonumber(reaper.GetExtState(SETTINGS_SECTION, "progress_offset")) or 20
    align_center = (reaper.GetExtState(SETTINGS_SECTION, "align_center") ~= "false")
    align_vertical = (reaper.GetExtState(SETTINGS_SECTION, "align_vertical") == "true")
    fill_gaps = (reaper.GetExtState(SETTINGS_SECTION, "fill_gaps") ~= "false")
    show_tooltips = (reaper.GetExtState(SETTINGS_SECTION, "show_tooltips") ~= "false")
    attach_to_video = (reaper.GetExtState(SETTINGS_SECTION, "attach_to_video") == "true")
    attach_bottom = (reaper.GetExtState(SETTINGS_SECTION, "attach_bottom") == "true")
    attach_offset = tonumber(reaper.GetExtState(SETTINGS_SECTION, "attach_offset")) or 0
    ignore_newlines = (reaper.GetExtState(SETTINGS_SECTION, "ignore_newlines") == "true")
    lang = reaper.GetExtState(SETTINGS_SECTION, "lang")
    if lang == "" then lang = "EN" end
    load_language_strings(lang)
    -- Load autostart from common SETTINGS_SECTION
    local autostart_str = reaper.GetExtState(SETTINGS_SECTION, AUTOSTART_KEY)
    autostart_on_prompter = (autostart_str == "true")
    -- Load window height only if video attachment is enabled
    if attach_to_video then
        win_h = tonumber(reaper.GetExtState(SETTINGS_SECTION, "win_h")) or 300
    end
end

load_settings()

-- Function to collect list of sources
local function collect_source_modes()
    local modes = {}

    -- First check for regions
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    if num_regions > 0 then
        table.insert(modes, { id = 0, label = str.m_regions })
    end

    -- Loop through all tracks and search for items with text
    local track_count = reaper.CountTracks(0)
    for t = 0, track_count-1 do
        local tr = reaper.GetTrack(0, t)
        local items = reaper.CountTrackMediaItems(tr)
        local has_text = false
        for i = 0, items-1 do
            local it = reaper.GetTrackMediaItem(tr, i)
            local take = reaper.GetActiveTake(it)
            if not (take and reaper.ValidatePtr(take, "MediaItem_Take*")) then
                local notes = reaper.ULT_GetMediaItemNote(it)
                if notes and notes ~= "" then
                    has_text = true
                    break
                end
            end
        end
        if has_text then
            table.insert(modes, {
                id = t+1,
                label = string.format(str.m_items, t+1, t+1)
            })
        end
    end

    return modes
end

-- Ensure that selected source_mode is really available
local function ensure_valid_source_mode()
    local modes = collect_source_modes()
    local valid = false
    for _, m in ipairs(modes) do
        if m.id == source_mode then
            valid = true
            break
        end
    end
    if not valid then
        if #modes > 0 then
            source_mode = modes[1].id
        else
            source_mode = 0 -- fallback: nothing available
        end
    end
end
ensure_valid_source_mode()

-- Function to display tooltip
local function tooltip(text)
    if not show_tooltips then return end  -- global disable

    if reaper.ImGui_IsItemHovered(ctx) then
        local now = reaper.time_precise()
        local state = tooltip_state[text]

        if not state then
            -- first time hovering over this element
            tooltip_state[text] = { start = now }
        else
            -- check global delay
            if now - state.start >= tooltip_delay then
                reaper.ImGui_SetTooltip(ctx, text)
            end
        end
    else
        -- reset when mouse is away
        tooltip_state[text] = nil
    end
end

-- Context menu
local function draw_context_menu()
    if reaper.ImGui_BeginPopup(ctx, "context_menu",
        reaper.ImGui_WindowFlags_NoResize() | reaper.ImGui_WindowFlags_NoSavedSettings()) then
        reaper.ImGui_PushItemWidth(ctx, CONTEXT_MENU_MIN_WIDTH)

        local changes = 0
        local function add_change(changed, new_value)
            changes = changes + (changed and 1 or 0)
            return new_value
        end

        -- Source mode
        local label = (source_mode == 0) and str.m_regions
                    or string.format(str.m_items, source_mode, source_mode)

        if reaper.ImGui_BeginCombo(ctx, str.m_mode, label) then
            local modes = collect_source_modes() -- collect list here
            for _, mode in ipairs(modes) do
                if reaper.ImGui_Selectable(ctx, mode.label, source_mode == mode.id) then
                    source_mode = mode.id
                end
            end
            reaper.ImGui_EndCombo(ctx)
        end
        tooltip(str.t_mode)
        
        -- Language selection button (on the same line)
        reaper.ImGui_SameLine(ctx, 0, 10)
        if reaper.ImGui_Button(ctx, lang) then
            reaper.ImGui_OpenPopup(ctx, "lang_popup")
        end
        tooltip(str.t_language)
        
        if reaper.ImGui_BeginPopup(ctx, "lang_popup") then
            for _, code in ipairs(languages) do
                if reaper.ImGui_Selectable(ctx, code, code == lang) then
                    lang = code
                    load_language_strings(lang)
                    changes = 1
                end
            end
            reaper.SetExtState(SETTINGS_SECTION, "lang", lang, true)
            reaper.ImGui_EndPopup(ctx)
        end

        -- Window flags
        reaper.ImGui_Separator(ctx)
        flags.NoMove          = add_change(reaper.ImGui_Checkbox(ctx, str.c_pin, flags.NoMove))
        tooltip(str.t_pin)
        flags.NoTitle         = add_change(reaper.ImGui_Checkbox(ctx, str.c_hide_title, flags.NoTitle))
        tooltip(str.t_hide_title)
        flags.HideBackground  = add_change(reaper.ImGui_Checkbox(ctx, str.c_hide_bg, flags.HideBackground))
        tooltip(str.t_hide_bg)
        border                = add_change(reaper.ImGui_Checkbox(ctx, str.c_border, border))
        tooltip(str.t_border)
        window_bg_color       = add_change(reaper.ImGui_ColorEdit4(ctx, str.c_bg_color, window_bg_color, reaper.ImGui_ColorEditFlags_NoInputs() | reaper.ImGui_ColorEditFlags_AlphaBar()))
        tooltip(str.t_bg_color)
        align_center          = add_change(reaper.ImGui_Checkbox(ctx, str.c_h_center, align_center))
        tooltip(str.t_h_center)
        align_vertical        = add_change(reaper.ImGui_Checkbox(ctx, str.c_v_center, align_vertical))
        tooltip(str.t_v_center)
        enable_wrap           = add_change(reaper.ImGui_Checkbox(ctx, str.c_wrap, enable_wrap))
        tooltip(str.t_wrap)
        if enable_wrap then
            wrap_margin       = add_change(reaper.ImGui_SliderInt(ctx, str.c_wrap_margin, wrap_margin, 0, 300))
            tooltip(str.t_wrap_margin)
            -- Show guides if slider is active or mouse hovers over it
            show_wrap_guides = reaper.ImGui_IsItemActive(ctx) or reaper.ImGui_IsItemHovered(ctx)
        else
            show_wrap_guides = false
        end
        local old_ignore_newlines = ignore_newlines
        ignore_newlines       = add_change(reaper.ImGui_Checkbox(ctx, str.c_ignore_nl, ignore_newlines))
        tooltip(str.t_ignore_nl)
        if old_ignore_newlines ~= ignore_newlines then
            last_pos = nil -- Reset cache when option changes
        end
        fill_gaps             = add_change(reaper.ImGui_Checkbox(ctx, str.c_fill_gaps, fill_gaps))
        tooltip(str.t_fill_gaps)
        flags.NoResize        = add_change(reaper.ImGui_Checkbox(ctx, str.c_no_resize, flags.NoResize))
        tooltip(str.t_no_resize)
        flags.AlwaysAutoResize= add_change(reaper.ImGui_Checkbox(ctx, str.c_auto_resize, flags.AlwaysAutoResize))
        tooltip(str.t_auto_resize)
        attach_to_video       = add_change(reaper.ImGui_Checkbox(ctx, str.c_attach_video, attach_to_video))
        tooltip(str.t_attach_video)
        -- Additional attachment settings (show only if attach_to_video = true)
        if attach_to_video then
            -- Checkbox for attachment mode
            attach_bottom = add_change(reaper.ImGui_Checkbox(ctx, str.c_attach_bottom, attach_bottom))
            tooltip(str.t_attach_bottom)
            
            -- Offset slider
            attach_offset = add_change(reaper.ImGui_SliderInt(ctx, str.c_attach_offset, attach_offset, 0, 100))
            tooltip(str.t_attach_offset)
        end
        
        
        -- First line styling
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, str.h_first_line)
        if reaper.ImGui_BeginCombo(ctx, str.c_font, available_fonts[current_font_index]) then
            for i, name in ipairs(available_fonts) do
                if reaper.ImGui_Selectable(ctx, name, i == current_font_index) then
                    current_font_index = i
                    changes = 1
                end
            end
            reaper.ImGui_EndCombo(ctx)
        end
        font_scale      = add_change(reaper.ImGui_SliderInt(ctx, str.c_scale, font_scale, 10, 100))
        text_color      = add_change(reaper.ImGui_ColorEdit4(ctx, str.c_color, text_color, reaper.ImGui_ColorEditFlags_NoInputs() | reaper.ImGui_ColorEditFlags_AlphaBar()))
        shadow_color    = add_change(reaper.ImGui_ColorEdit4(ctx, str.c_shadow, shadow_color, reaper.ImGui_ColorEditFlags_NoInputs() | reaper.ImGui_ColorEditFlags_AlphaBar()))

        -- Progress bar
        reaper.ImGui_Separator(ctx)
        show_progress = add_change(reaper.ImGui_Checkbox(ctx, str.c_progress, show_progress))
        tooltip(str.t_progress)
        if show_progress then
            progress_width  = add_change(reaper.ImGui_SliderInt(ctx, str.c_length, progress_width, 200, 2000))
            progress_height = add_change(reaper.ImGui_SliderInt(ctx, str.c_thickness, progress_height, 1, 10))
            progress_offset = add_change(reaper.ImGui_SliderInt(ctx, str.c_offset, progress_offset, 0, 200))
        end
        
        -- Second line styling
        reaper.ImGui_Separator(ctx)
        enable_second_line = add_change(reaper.ImGui_Checkbox(ctx, str.c_second_line, enable_second_line))
        tooltip(str.t_second_line)
        if enable_second_line then
            if reaper.ImGui_BeginCombo(ctx, str.c_font2, available_fonts[second_font_index]) then
                for i, name in ipairs(available_fonts) do
                    if reaper.ImGui_Selectable(ctx, name, i == second_font_index) then
                        second_font_index = i
                        changes = 1
                    end
                end
                reaper.ImGui_EndCombo(ctx)
            end
            second_font_scale   = add_change(reaper.ImGui_SliderInt(ctx, str.c_scale2, second_font_scale, 10, 100))
            next_region_offset  = add_change(reaper.ImGui_SliderInt(ctx, str.c_offset2, next_region_offset, 0, 200))
            second_text_color   = add_change(reaper.ImGui_ColorEdit4(ctx, str.c_color2, second_text_color, reaper.ImGui_ColorEditFlags_NoInputs() | reaper.ImGui_ColorEditFlags_AlphaBar()))
            second_shadow_color = add_change(reaper.ImGui_ColorEdit4(ctx, str.c_shadow2, second_shadow_color, reaper.ImGui_ColorEditFlags_NoInputs() | reaper.ImGui_ColorEditFlags_AlphaBar()))
        end

        reaper.ImGui_Separator(ctx)
        flags.NoDocking = add_change(reaper.ImGui_Checkbox(ctx, str.c_no_dock, flags.NoDocking))
        tooltip(str.t_no_dock)
        autostart_on_prompter = add_change(reaper.ImGui_Checkbox(ctx, str.c_autostart, autostart_on_prompter))
        tooltip(str.t_autostart)
        show_tooltips   = add_change(reaper.ImGui_Checkbox(ctx, str.c_tooltips, show_tooltips))
        tooltip(str.t_tooltips)

        -- Save settings if there were changes
        if changes > 0 then save_settings() end

        -- close button
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, str.b_close) then
            close_requested = true
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        reaper.ImGui_PopItemWidth(ctx)
        reaper.ImGui_EndPopup(ctx)
    end
end

-- Function for balanced text wrapping
local function balanced_wrap(ctx, text, max_w)
    local words = {}
    for word in string.gmatch(text, "%S+") do
        table.insert(words, word)
    end
    if #words <= 1 then return {text} end

    -- if line fits completely → no wrap
    local total_w = reaper.ImGui_CalcTextSize(ctx, text)
    if total_w <= max_w then
        return {text}
    end

    -- find optimal break point
    local best_diff = math.huge
    local best_idx = nil
    for i = 1, #words-1 do
        local left = table.concat(words, " ", 1, i)
        local right = table.concat(words, " ", i+1, #words)
        local w_left = reaper.ImGui_CalcTextSize(ctx, left)
        local w_right = reaper.ImGui_CalcTextSize(ctx, right)

        -- both halves should have a chance to fit
        if w_left <= max_w and w_right <= max_w * 1.5 then
            local diff = math.abs(w_left - w_right)
            if diff < best_diff then
                best_diff = diff
                best_idx = i
            end
        end
    end

    if not best_idx then
        -- fallback: regular wrap by max_w
        local lines, current = {}, ""
        for _, word in ipairs(words) do
            local test_line = (current == "") and word or (current .. " " .. word)
            local w = reaper.ImGui_CalcTextSize(ctx, test_line)
            if w > max_w and current ~= "" then
                table.insert(lines, current)
                current = word
            else
                current = test_line
            end
        end
        if current ~= "" then table.insert(lines, current) end
        return lines
    end

    -- split line into two parts
    local left = table.concat(words, " ", 1, best_idx)
    local right = table.concat(words, " ", best_idx+1, #words)

    -- recursively process both parts
    local left_lines = balanced_wrap(ctx, left, max_w)
    local right_lines = balanced_wrap(ctx, right, max_w)

    -- combine
    for i = 1, #right_lines do table.insert(left_lines, right_lines[i]) end
    return left_lines
end

-- Function to draw centered text
local function draw_centered_text(ctx, text, font_index, font_scale, text_color, shadow_color, win_w)
    local font_to_push = font_objects[font_index] or font_objects[1]
    reaper.ImGui_PushFont(ctx, font_to_push, font_scale)

    local lines = {}
    for line in string.gmatch(text .. "\n", "(.-)\n") do
        if enable_wrap and line ~= "" then
            -- Account for padding and wrap_margin on both sides
            local max_wrap_width = win_w - padding_x*2 - wrap_margin*2
            local wrapped = balanced_wrap(ctx, line, max_wrap_width)
            for _, l in ipairs(wrapped) do
                table.insert(lines, l)
            end
        else
            table.insert(lines, line)
        end

    end
    if #lines == 0 then lines = {" "} end

    local max_w = 0
    for _, line in ipairs(lines) do
        local w = reaper.ImGui_CalcTextSize(ctx, line) or 0
        if w > max_w then max_w = w end
    end

    local shadow_offset = 2
    local line_h = reaper.ImGui_GetTextLineHeight(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)

    for _, line in ipairs(lines) do
        local w = reaper.ImGui_CalcTextSize(ctx, line) or 0
        local cur_y = reaper.ImGui_GetCursorPosY(ctx)
        local cur_x
        if align_center then
            cur_x = (win_w - max_w)/2 + (max_w - w)/2
        else
            cur_x = wrap_margin  -- Left alignment with offset
        end

        if line ~= "" then
            if border then
                local win_x, win_y = reaper.ImGui_GetWindowPos(ctx)
                local rect_x1 = win_x + cur_x - padding_x
                local rect_y1 = win_y + cur_y - padding_y
                local rect_x2 = rect_x1 + w + padding_x*2
                local rect_y2 = rect_y1 + line_h + padding_y*2
                reaper.ImGui_DrawList_AddRectFilled(draw_list, rect_x1, rect_y1, rect_x2, rect_y2, window_bg_color or 0x000000AA, 4)
            end

            reaper.ImGui_SetCursorPosX(ctx, cur_x + shadow_offset)
            reaper.ImGui_SetCursorPosY(ctx, cur_y + shadow_offset)
            reaper.ImGui_TextColored(ctx, shadow_color, line)

            reaper.ImGui_SetCursorPosX(ctx, cur_x)
            reaper.ImGui_SetCursorPosY(ctx, cur_y)
            reaper.ImGui_TextColored(ctx, text_color, line)
        else
            reaper.ImGui_Dummy(ctx, 1, line_h)
        end
    end

    reaper.ImGui_PopFont(ctx)
end

-- Get current and next region names
local function get_current_and_next_region_names()
    local play_state = reaper.GetPlayState()
    local pos = (play_state & 1) == 1 and reaper.GetPlayPosition() or reaper.GetCursorPosition()
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)

    local regions = {}
    for i = 0, (num_markers + num_regions) - 1 do
        local ret, isrgn, startpos, endpos, name = reaper.EnumProjectMarkers3(0, i)
        if isrgn then
            if ignore_newlines then name = string.gsub(name or "", "\n", " ") end
            table.insert(regions, {start = startpos, stop = endpos, name = name or ""})
        end
    end

    table.sort(regions, function(a,b) return a.start < b.start end)

    local current, nextreg = "", ""
    local nearest_dist = math.huge
    local nearest_idx = nil

    for i, r in ipairs(regions) do
        -- if inside region → it becomes current
        if pos >= r.start and pos < r.stop then
            current = r.name
            if regions[i+1] then
                nextreg = regions[i+1].name
            end
            return current, nextreg, r.start, r.stop
        end

        -- otherwise find nearest region by start/end
        local dist = math.min(math.abs(pos - r.start), math.abs(pos - r.stop))
        if dist < nearest_dist then
            nearest_dist = dist
            nearest_idx = i
        end
    end

    -- if not inside region → nearest becomes current
    if fill_gaps and nearest_idx then
        current = regions[nearest_idx].name
        if regions[nearest_idx+1] then
            nextreg = regions[nearest_idx+1].name
        end
        return current, nextreg, regions[nearest_idx].start, regions[nearest_idx].stop
    end

    -- fallback: no regions or fill_gaps is off
    return "", "", 0, 0
end

-- Get current and next text items on track
local function get_text_item_name(item)
    local take = reaper.GetActiveTake(item)
    if take and reaper.ValidatePtr(take, "MediaItem_Take*") then
        return nil
    end
    local notes = reaper.ULT_GetMediaItemNote(item)
    if notes and notes ~= "" then
        if ignore_newlines then notes = string.gsub(notes, "\n", " ") end
        return notes
    end
    return nil
end

-- Helper function to find next text item
local function find_next_text_item(track, start_idx)
    local items = reaper.CountTrackMediaItems(track)
    for j = start_idx, items-1 do
        local it = reaper.GetTrackMediaItem(track, j)
        local name = get_text_item_name(it)
        if name then
            return name
        end
    end
    return ""
end

local function get_current_and_next_items(track)
    local play_state = reaper.GetPlayState()
    local pos = (play_state & 1) == 1 and reaper.GetPlayPosition() or reaper.GetCursorPosition()
    local items = reaper.CountTrackMediaItems(track)
    local current, next_item = "", ""
    local nearest_dist, nearest_idx = math.huge, nil
    local start_pos, stop_pos = 0, 0

    for i = 0, items-1 do
        local it = reaper.GetTrackMediaItem(track, i)
        start_pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
        local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
        stop_pos = start_pos + len
        local name = get_text_item_name(it)

        if name then
            if pos >= start_pos and pos < stop_pos then
                current = name
                next_item = find_next_text_item(track, i+1)
                return current, next_item, start_pos, stop_pos
            end
            local dist = math.min(math.abs(pos - start_pos), math.abs(pos - stop_pos))
            if dist < nearest_dist then
                nearest_dist = dist
                nearest_idx = i
            end
        end
    end

    if fill_gaps and nearest_idx then
        local it = reaper.GetTrackMediaItem(track, nearest_idx)
        local name = get_text_item_name(it)
        if name then
            current = name
            next_item = find_next_text_item(track, nearest_idx+1)
            start_pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
            local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
            stop_pos = start_pos + len
        end
        return current, next_item, start_pos, stop_pos
    end

    return "", "", 0, 0
end

-- Function to get REAPER video window position
local function get_video_window_pos()
    if not reaper.JS_Window_Find then
        return nil, nil, nil, nil  -- js_ReaScriptAPI is not installed
    end
    
    -- Find Video Window
    local video_hwnd = reaper.JS_Window_Find("Video Window", true)
    
    if video_hwnd then
        local retval, x1, y1, x2, y2 = reaper.JS_Window_GetRect(video_hwnd)
        if retval then
            return x1, y1, x2, y2
        end
    end
    
    return nil, nil, nil, nil
end

-- Check if video window position has changed
local function check_video_window_moved()
    -- Get current video window coordinates
    local x1, y1, x2, y2 = get_video_window_pos()
    
    -- If no video window - exit
    if not x1 then
        video_cache_valid = false
        return false
    end
    
    -- Check if coordinates have changed
    if video_cache_valid and cached_video_x1 == x1 and cached_video_y1 == y1 and 
       cached_video_x2 == x2 and cached_video_y2 == y2 then
        -- Coordinates unchanged, use cache
        return true
    end
    
    -- Coordinates changed or cache invalid - пересчитываем позиции
    local video_width = x2 - x1
    local video_height = y2 - y1
    
    -- Window stretches to video window width
    attach_x = x1
    attach_w = video_width
    
    -- Calculate Y position depending on attachment mode
    -- Limit offset, чтобы окно не выходило за границы видеоокна
    local max_offset = math.max(0, video_height - win_h)
    local offset_pixels = math.min(attach_offset * video_height / 100, max_offset)
    
    if attach_bottom then
        -- Attach to bottom: y2 - window height - offset
        attach_y = y2 - win_h - offset_pixels
    else
        -- Attach to top: y1 + offset
        attach_y = y1 + offset_pixels
    end
    
    -- Save to cache
    cached_video_x1, cached_video_y1, cached_video_x2, cached_video_y2 = x1, y1, x2, y2
    cached_attach_x, cached_attach_y, cached_attach_w = attach_x, attach_y, attach_w
    video_cache_valid = true
    
    return true
end

local function debug_window()
    local debugger_visible, debugger_open = reaper.ImGui_Begin(ctx, "Debugger", true)
    if debugger_visible then
        reaper.ImGui_Text(ctx, "=== Video Window Coordinates ===")
        reaper.ImGui_Separator(ctx)
        
        local x1, y1, x2, y2 = get_video_window_pos()
        if x1 then
            local video_width = x2 - x1
            local video_height = y2 - y1
            reaper.ImGui_Text(ctx, string.format("Size: %.0f x %.0f", video_width, video_height))
            reaper.ImGui_Text(ctx, string.format("X: %.0f, %.0f", x1, x2))
            reaper.ImGui_Text(ctx, string.format("Y: %.0f, %.0f", y1, y2))
        else
            reaper.ImGui_Text(ctx, "Video Window NOT FOUND")
            reaper.ImGui_Separator(ctx)
            if not reaper.JS_Window_Find then
                reaper.ImGui_TextWrapped(ctx, "js_ReaScriptAPI not installed")
                reaper.ImGui_TextWrapped(ctx, "Install via ReaPack -> ReaTeam Extensions")
            else
                reaper.ImGui_TextWrapped(ctx, "Video Window is not open")
                reaper.ImGui_Text(ctx, "or window title is different")
            end
        end

        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, "=== Cache Status ===")
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, string.format("Video Cache: %s", video_cache_valid and "VALID (using cache)" or "INVALID (recalculating)"))
        reaper.ImGui_Text(ctx, string.format("User Resizing: %s", is_user_resizing and "YES (attach disabled)" or "NO"))
        reaper.ImGui_TextWrapped(ctx, "Cache invalidates on: 1st run, video window moved, settings changed, SubOverlay resized")
        
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, "=== Current SubOverlay Window ===")
        reaper.ImGui_Separator(ctx)
        if win_w and win_h then
            reaper.ImGui_Text(ctx, string.format("Position: %.0f x %.0f", win_X, win_Y))
            reaper.ImGui_Text(ctx, string.format("Size: %.0f x %.0f", win_w, win_h))
        else
            reaper.ImGui_Text(ctx, "Window size not available yet")
        end
        
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, "=== Current Attach Position ===")
        reaper.ImGui_Separator(ctx)
        if attach_x and attach_y then
            reaper.ImGui_Text(ctx, string.format("Attach X: %.0f", attach_x))
            reaper.ImGui_Text(ctx, string.format("Attach Y: %.0f", attach_y))
            reaper.ImGui_Text(ctx, string.format("Attach W: %.0f", attach_w or 0))
        else
            reaper.ImGui_Text(ctx, "Not attached or video window not found")
        end
        
        reaper.ImGui_End(ctx)
    end

end

-- =========================
-- Rest of main loop
-- =========================
local function loop()
    reaper.ImGui_PushFont(ctx, ui_font, UI_FONT_SCALE)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), window_bg_color)
    
    local window_flags = reaper.ImGui_WindowFlags_NoScrollbar()
    if flags.NoTitle then window_flags = window_flags | reaper.ImGui_WindowFlags_NoTitleBar() end
    if flags.NoResize then window_flags = window_flags | reaper.ImGui_WindowFlags_NoResize() end
    if flags.AlwaysAutoResize then window_flags = window_flags | reaper.ImGui_WindowFlags_AlwaysAutoResize() end
    if flags.NoDocking then window_flags = window_flags | reaper.ImGui_WindowFlags_NoDocking() end
    if flags.NoMove then window_flags = window_flags | reaper.ImGui_WindowFlags_NoMove() end

    if flags.HideBackground and reaper.ImGui_SetNextWindowBgAlpha then
        reaper.ImGui_SetNextWindowBgAlpha(ctx, 0)
    end

    -- Set initial window size and position (only on first run)
    reaper.ImGui_SetNextWindowSize(ctx, win_w, win_h, reaper.ImGui_Cond_FirstUseEver())
    reaper.ImGui_SetNextWindowPos(ctx, win_X, win_Y, reaper.ImGui_Cond_FirstUseEver())
    
    -- If video window attachment is enabled and user is NOT resizing - apply positions
    if attach_to_video and not is_user_resizing and check_video_window_moved() then
        reaper.ImGui_SetNextWindowPos(ctx, attach_x, attach_y)
        reaper.ImGui_SetNextWindowSize(ctx, attach_w, win_h)
    end

    local visible, open = reaper.ImGui_Begin(ctx, "SubOverlay", win_open, window_flags)

    if visible then
        local new_win_w, new_win_h = reaper.ImGui_GetWindowSize(ctx)
        
        -- Check if window size has changed
        local size_changed = (new_win_w ~= win_w or new_win_h ~= win_h)
        
        -- Determine if user is resizing the window (left button pressed + size changing)
        local mouse_down = reaper.ImGui_IsMouseDown(ctx, 0)
        
        if size_changed and mouse_down then
            -- User is resizing the window
            is_user_resizing = true
        elseif not mouse_down then
            -- Mouse button released - complete resize
            if is_user_resizing then
                is_user_resizing = false
                if attach_to_video then
                    video_cache_valid = false -- Invalidate cache for recalculation
                    save_settings() -- Save window height for video attachment
                end
            end
        end
        
        if size_changed then
            win_w, win_h = new_win_w, new_win_h
            if attach_to_video and not is_user_resizing then
                video_cache_valid = false -- Invalidate cache on size change
            end
        end
        
        ensure_valid_source_mode()

        
        -- Determine current playhead/cursor position
        local play_state = reaper.GetPlayState()
        local pos = (play_state & 1) == 1 and reaper.GetPlayPosition() or reaper.GetCursorPosition()
        
        -- Check if we need to update data
        local current, nextreg, start_pos, stop_pos
        if pos ~= last_pos then
            -- Position changed - update data
            last_pos = pos
            if source_mode == 0 then
                current, nextreg, start_pos, stop_pos = get_current_and_next_region_names()
            else
                local tr = reaper.GetTrack(0, source_mode-1)
                if tr then
                    current, nextreg, start_pos, stop_pos = get_current_and_next_items(tr)
                else
                    current, nextreg, start_pos, stop_pos = "", "", 0, 0
                end
            end
            -- Save to cache
            cached_current, cached_next, cached_start, cached_stop = current, nextreg, start_pos, stop_pos
        else
            -- Position unchanged - use cache
            current, nextreg, start_pos, stop_pos = cached_current, cached_next, cached_start, cached_stop
        end

        local progress = 0.0
        if start_pos and stop_pos and stop_pos > start_pos then
            if pos >= start_pos and pos <= stop_pos then
                local rel = (pos - start_pos) / (stop_pos - start_pos)
                progress = math.max(0, math.min(1, rel))
            end
        end

        -- Vertical alignment (if enabled)
        if align_vertical then
            -- Calculate total content height
            local total_height = 0
            
            -- First line height
            reaper.ImGui_PushFont(ctx, font_objects[current_font_index] or font_objects[1], font_scale)
            local calc_width = win_w - padding_x*2 - wrap_margin*2
            local _, first_line_height = reaper.ImGui_CalcTextSize(ctx, current or " ", 0, 0, false, calc_width)
            reaper.ImGui_PopFont(ctx)
            total_height = total_height + first_line_height
            
            -- Progress bar height (if enabled)
            if show_progress then
                total_height = total_height + progress_offset + progress_height
            end
            
            -- Second line height (if enabled)
            if enable_second_line then
                reaper.ImGui_PushFont(ctx, font_objects[second_font_index] or font_objects[1], second_font_scale)
                local _, second_line_height = reaper.ImGui_CalcTextSize(ctx, nextreg or " ", 0, 0, false, calc_width)
                reaper.ImGui_PopFont(ctx)
                total_height = total_height + next_region_offset + second_line_height
            end
            
            -- Set initial Y position для центрирования
            local start_y = math.max(0, (win_h - total_height) / 2)
            reaper.ImGui_SetCursorPosY(ctx, start_y)
        end
        
        -- draw text
        draw_centered_text(ctx, current, current_font_index, font_scale, text_color, shadow_color, win_w) -- first line

        -- progress bar
        if show_progress then
            local cur_y = reaper.ImGui_GetCursorPosY(ctx)
            reaper.ImGui_SetCursorPosY(ctx, cur_y + progress_offset)
            if progress > 0 then
                if align_center then
                    reaper.ImGui_SetCursorPosX(ctx, (win_w - progress_width) / 2)
                end
                reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)
                reaper.ImGui_ProgressBar(ctx, progress, progress_width, progress_height, "")
                reaper.ImGui_PopStyleVar(ctx)
            else
                -- if bar is "invisible" (between regions/items)
                reaper.ImGui_Dummy(ctx, progress_width, progress_height)
            end
        end

        if enable_second_line then -- check if second line is enabled
            local cur_y = reaper.ImGui_GetCursorPosY(ctx)
            reaper.ImGui_SetCursorPosY(ctx, cur_y + next_region_offset) -- offset to second line
            draw_centered_text(ctx, nextreg, second_font_index, second_font_scale, second_text_color, second_shadow_color, win_w) -- second line
        end


        
        win_X, win_Y = reaper.ImGui_GetWindowPos(ctx)
        local hovered = reaper.ImGui_IsWindowHovered(ctx)
        -- Close button in top right corner
        if flags.NoTitle then
            local button_size = 20
            local button_x = win_w - button_size - 10
            local button_y = 10
            reaper.ImGui_SetCursorPos(ctx, button_x, button_y)
            -- Transparent button with X
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000)  -- transparent
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xFF000088)  -- reddish on hover
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xFF0000FF)  -- red on click
            if reaper.ImGui_IsWindowHovered(ctx) then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFFFFFFFF)  -- white on hover
            else
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFFFFFF00)  -- semi-transparent
            end
            if reaper.ImGui_Button(ctx, "✕##close", button_size, button_size) then
                close_requested = true
            end
            reaper.ImGui_PopStyleColor(ctx, 4)
        end

        -- Open context menu on right-click
        if hovered and reaper.ImGui_IsMouseClicked(ctx, 1, false) then
            reaper.ImGui_SetNextWindowSize(ctx, 200, 0, reaper.ImGui_Cond_Appearing())
            reaper.ImGui_OpenPopup(ctx, "context_menu")
        end

        -- Draw guide lines for wrap offset
        if show_wrap_guides and wrap_margin > 0 then
            local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
            local guide_color = 0x00FFFFFF  -- bright cyan
            
            -- Left line
            local left_x = win_X + wrap_margin
            reaper.ImGui_DrawList_AddLine(draw_list, left_x, win_Y, left_x, win_Y + win_h, guide_color, 1.0)
            
            -- Right line
            local right_x = win_X + win_w - wrap_margin
            reaper.ImGui_DrawList_AddLine(draw_list, right_x, win_Y, right_x, win_Y + win_h, guide_color, 1.0)
        end
        
        if debug_mode then
            debug_window()
        end
        draw_context_menu()
        reaper.ImGui_End(ctx)
    end

    reaper.ImGui_PopStyleColor(ctx)
    reaper.ImGui_PopStyleVar(ctx)
    reaper.ImGui_PopFont(ctx)
    
    local continue_running = (open ~= false) and not close_requested
    if continue_running then
        reaper.defer(loop)
    else
        -- Clear flags on close
        reaper.DeleteExtState(SETTINGS_SECTION, RUNNING_KEY, true)
        close_requested = false
    end
end


reaper.defer(loop)

