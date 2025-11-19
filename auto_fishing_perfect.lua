    -- ============================================
    -- ИДЕАЛЬНАЯ АВТОМАТИЧЕСКАЯ РЫБАЛКА
    -- ============================================
    -- Версия: 4.4.1 (Perfect Edition)
    -- Основано на реальном дампе сервера
    -- Максимально точная реализация
    -- Улучшено на основе данных анализатора
    -- ============================================
    -- РАНЕЕ v4.3.1:
    -- • УЛУЧШЕННЫЙ ANTI SCREEN GRAB - МОМЕНТАЛЬНОЕ скрытие!
    -- • Тройной перехват скриншотов:
    --   1. HUDPaint hook (каждый кадр - максимальная скорость)
    --   2. PlayerBindPress hook (перехват команд screenshot/jpeg)
    --   3. Think hook (проверка клавиш F12/PrintScreen/SysRq)
    -- • Скрытие всех окон (меню + логи) одновременно
    -- • Восстановление через 0.3-0.5 сек после скриншота
    -- ============================================
    -- УЛУЧШЕНИЯ v4.3.0:
    -- • РЕЖИМ ЗАПИСИ ДЕЙСТВИЙ ИГРОКА
    -- • Запись нажатий WASD во время мини-игры
    -- • Запись состояния рыбы (направление, расстояние до центра)
    -- • Автоматическое начало/конец записи при мини-игре
    -- • Экспорт записей в JSON для анализа и улучшения алгоритма
    -- • В режиме записи - ручное управление, автоматика отключена
    -- ============================================
    -- УЛУЧШЕНИЯ v4.2.0:
    -- • Ожидание перезарядки удочки перед закидыванием (настраиваемо)
    -- • Упрощенная логика управления стрелкой:
    --   - Стрелка идет К ЦЕНТРУ → не тянуть
    --   - Стрелка идет ОТ ЦЕНТРА → тянуть активно
    --   - Стрелка идет в СТОРОНУ → легкая коррекция
    -- • Более точное определение безопасной зоны (белый круг)
    -- ============================================
    -- УЛУЧШЕНИЯ v4.1.2:
    -- • Автоматический забор пойманной рыбы (ЛКМ при scale 1.01)
    -- • Удержание ЛКМ 1.5 секунды для надежного забора
    -- • Логирование событий забора рыбы
    -- ============================================
    -- УЛУЧШЕНИЯ v4.1.1:
    -- • Отдельное GUI окно логов в реальном времени
    -- • Полное логирование всех событий рыбалки (сеть, поклевки, управление)
    -- • Цветное форматирование логов по типам событий
    -- • Автопрокрутка и автообновление окна логов
    -- • Кнопка быстрого доступа к логам из главного меню
    -- • Расширенный перехват сетевых сообщений рыбалки
    -- ============================================
    -- УЛУЧШЕНИЯ v4.1:
    -- • Адаптивный порог управления (зависит от расстояния до границы)
    -- • Улучшенное предсказание движения рыбы (с учетом ускорения)
    -- • Более агрессивная защита от выхода за границы зоны
    -- • Плавное смешивание направлений при приближении к границе
    -- • Ускоренное обновление при опасности выхода за границы
    -- • Гарантированное сохранение данных зоны для анализатора
    -- ============================================

    if CLIENT then
        -- Глобальное хранение для инжектора
        _AutoFishPerfect = _AutoFishPerfect or {}
        local AutoFish = _AutoFishPerfect
        
        -- Функция выгрузки скрипта
        local function UnloadScript()
            -- Удаляем хуки
        hook.Remove("Think", "AutoFish_Perfect_Think")
        hook.Remove("HUDPaint", "AutoFish_Perfect_HUD")
            hook.Remove("HUDPaint", "AutoFish_Perfect_AntiGrab")
            hook.Remove("PlayerBindPress", "AutoFish_Perfect_ScreenshotBlock")
            hook.Remove("PostDrawTranslucentRenderables", "AutoFish_Perfect_ZoneVisualization")
            hook.Remove("OnPlayerChat", "AutoFish_Perfect_CatchTracker")
            
            -- Закрываем меню
            if IsValid(AutoFish.MenuFrame) then
                AutoFish.MenuFrame:Remove()
            end
            
            -- Закрываем окно логов
            if IsValid(AutoFish.LogWindowFrame) then
                AutoFish.LogWindowFrame:Remove()
            end
            
            
            -- Удаляем все таймеры (безопасно)
            if AutoFish.CurrentTimerName then
                timer.Remove(AutoFish.CurrentTimerName)
                AutoFish.CurrentTimerName = nil
            end
            if AutoFish.MenuFrame then
                local timerName = "AutoFish_UpdateStatus_" .. tostring(AutoFish.MenuFrame)
                timer.Remove(timerName)
            end
            
            -- Отпускаем клавиши
            local ply = LocalPlayer()
            if IsValid(ply) then
                ply:ConCommand("-forward")
                ply:ConCommand("-back")
                ply:ConCommand("-moveright")
                ply:ConCommand("-moveleft")
            end
            
            -- Очищаем данные
            AutoFish.Enabled = false
            AutoFish.MenuOpen = false
            AutoFish.Initialized = false
            
            print("[AutoFish Perfect] Скрипт выгружен")
        end
        
        -- Проверка на повторную загрузку
        if AutoFish.Initialized then
            print("[AutoFish Perfect] Уже загружен, выгружаем старую версию...")
            
            -- Вызываем функцию выгрузки если она существует
            if AutoFish.Unload then
                AutoFish.Unload()
            else
                -- Если функции нет, выгружаем вручную
                hook.Remove("Think", "AutoFish_Perfect_Think")
                hook.Remove("HUDPaint", "AutoFish_Perfect_HUD")
                hook.Remove("PostDrawTranslucentRenderables", "AutoFish_Perfect_ZoneVisualization")
                if IsValid(AutoFish.MenuFrame) then
                    AutoFish.MenuFrame:Remove()
                end
                if IsValid(AutoFish.LogWindowFrame) then
                    AutoFish.LogWindowFrame:Remove()
                end
                local ply = LocalPlayer()
                if IsValid(ply) then
                    ply:ConCommand("-forward")
                    ply:ConCommand("-back")
                    ply:ConCommand("-moveright")
                    ply:ConCommand("-moveleft")
                end
            end
            
            -- Очищаем состояние
            AutoFish.Initialized = false
            AutoFish.Enabled = false
            AutoFish.MenuOpen = false
        end
        
        AutoFish.Initialized = true
        AutoFish.Enabled = false
        AutoFish.LastCast = 0
        AutoFish.LastUpdate = 0
        AutoFish.UpdateInterval = 0.01
        AutoFish.MenuOpen = false
        AutoFish.MenuFrame = nil
        AutoFish.LogWindowOpen = false
        AutoFish.LogWindowFrame = nil
        AutoFish.EndKeyPressed = false
        AutoFish.EndKeyLastCheck = 0
        
        -- Система записи действий игрока
        AutoFish.Recording = false
        AutoFish.RecordedSession = {
            startTime = 0,
            endTime = 0,
            fishID = "",
            result = "unknown", -- "caught", "escaped", "cancelled"
            actions = {},
        }
        AutoFish.RecordingSessions = {} -- История записей
        AutoFish.WaitingForStart = false -- Ожидание начала мини-игры (ЛКМ)
        AutoFish.LastHookAttempt = 0 -- Время последней попытки подсечки
        AutoFish.LastBiteReport = 0 -- Время последнего сообщения о поклевке
        AutoFish.LastScaleReport = 0 -- Время последнего отчета о scale
        AutoFish.LastCollectAttempt = 0 -- Время последней попытки забора рыбы (ЛКМ)
        AutoFish.CollectingFish = false -- Флаг процесса забора рыбы
        AutoFish.LastFishCollected = 0 -- Время когда забрали последнюю рыбу
        AutoFish.RodCooldown = 3 -- Задержка перезарядки удочки (секунды)
        AutoFish.DebugDisabledShown = false -- Флаг для показа сообщения о выключенном скрипте
        AutoFish.CurrentTimerName = nil -- Имя текущего таймера для удаления
        AutoFish.LastZoneData = nil -- Данные зоны для визуализации
        AutoFish.LastBobberScale = nil -- Последний scale поплавка для отслеживания изменений
        AutoFish.LastPlyDir = Vector(0, 0, 0) -- Последнее направление движения игрока (для Lerp)
        AutoFish.LastHookScale = nil -- Последний scale, при котором была подсечка (для предотвращения двойной подсечки)
    AutoFish.LastMinigameStartAttempt = 0 -- Время последней попытки начать мини-игру (после подсечки)
    AutoFish.MinigameStartAttempted = false -- Флаг, что попытка начать мини-игру уже была сделана
        
        
        -- Система логирования
        AutoFish.Logging = {
            enabled = true,
            events = {},              -- Массив всех событий
            networkMessages = {},     -- Перехваченные сетевые сообщения
            bobberStates = {},        -- История состояний поплавка
            fishStates = {},          -- История состояний рыбы
            controlActions = {},      -- Действия управления
            errors = {},              -- Ошибки
            maxEvents = 10000,        -- Максимум событий в памяти
            sessionStartTime = nil,   -- Время начала текущей сессии
        }
        
        -- Функция загрузки настроек из файла
        local function LoadSettings()
            local settingsFile = "autofish_perfect_settings.txt"
            local settingsData = file.Read(settingsFile, "DATA")
            
            if settingsData then
                local success, settings = pcall(function()
                    return util.JSONToTable(settingsData)
                end)
                if success and settings then
                    return settings
                end
            end
            
            -- Настройки по умолчанию
            return {
                autoCast = true,
                castDelay = 2,
                prediction = true,
                debugMode = false,
                zoneMargin = 0.8,
                antiScreenGrab = true,
                autoStartMinigame = true,
                zoneSize = 250,
                innerZoneSize = 200,
                logging = true,
                logNetworkMessages = true,
                recordingMode = false,
                rodCooldown = 3,
            }
        end
        
        -- Функция сохранения настроек в файл (доступна глобально в AutoFish)
        AutoFish.SaveSettings = function()
            local settingsFile = "autofish_perfect_settings.txt"
            local settingsToSave = {
                autoCast = AutoFish.Settings.autoCast,
                castDelay = AutoFish.Settings.castDelay,
                prediction = AutoFish.Settings.prediction,
                debugMode = AutoFish.Settings.debugMode,
                zoneMargin = AutoFish.Settings.zoneMargin,
                antiScreenGrab = AutoFish.Settings.antiScreenGrab,
                autoStartMinigame = AutoFish.Settings.autoStartMinigame,
                zoneSize = AutoFish.Settings.zoneSize,
                innerZoneSize = AutoFish.Settings.innerZoneSize,
                logging = AutoFish.Settings.logging,
                logNetworkMessages = AutoFish.Settings.logNetworkMessages,
                recordingMode = AutoFish.Settings.recordingMode,
                rodCooldown = AutoFish.RodCooldown, -- Сохраняем перезарядку удочки
            }
            
            local json = util.TableToJSON(settingsToSave, true)
            if json then
                file.Write(settingsFile, json)
            end
        end
        local SaveSettings = AutoFish.SaveSettings -- Локальная ссылка для удобства
        
        -- Загружаем настройки
        local defaultSettings = LoadSettings()
        
        -- Настройки (на основе реального кода + улучшения из анализатора)
        AutoFish.Settings = {
            autoCast = defaultSettings.autoCast ~= false, -- По умолчанию true
            castDelay = defaultSettings.castDelay or 2,
            prediction = defaultSettings.prediction ~= false, -- По умолчанию true
            debugMode = defaultSettings.debugMode or false,
            zoneMargin = defaultSettings.zoneMargin or 0.8,
            antiScreenGrab = defaultSettings.antiScreenGrab ~= false, -- По умолчанию true
            autoStartMinigame = defaultSettings.autoStartMinigame ~= false, -- По умолчанию true
            zoneSize = defaultSettings.zoneSize or 250,
            innerZoneSize = defaultSettings.innerZoneSize or 200,
            logging = defaultSettings.logging ~= false, -- По умолчанию true
            logNetworkMessages = defaultSettings.logNetworkMessages ~= false, -- По умолчанию true
            recordingMode = defaultSettings.recordingMode or false,
        }
        
        -- Загружаем перезарядку удочки из настроек
        AutoFish.RodCooldown = defaultSettings.rodCooldown or 3
        
        -- Кэш несуществующих сообщений (чтобы не спамить ошибками)
        -- AutoFish.InvalidNetMessages = AutoFish.InvalidNetMessages or {}
        
        -- Ограничение частоты вывода отладочных сообщений (чтобы не спамить консоль)
        --[[
        AutoFish.DebugPrintThrottle = AutoFish.DebugPrintThrottle or {}
        local function ThrottledDebugPrint(key, message, throttleTime)
            throttleTime = throttleTime or 0.5 -- По умолчанию не чаще раза в 0.5 секунды
            local now = CurTime()
            if not AutoFish.DebugPrintThrottle[key] or (now - AutoFish.DebugPrintThrottle[key]) >= throttleTime then
                print(message)
                AutoFish.DebugPrintThrottle[key] = now
            end
        end
        
        
        -- Функции логирования
        local function LogEvent(eventType, data)
            if not AutoFish.Settings.logging then return end
            
            local event = {
                time = CurTime(),
                type = eventType,
                data = data or {},
            }
            
            table.insert(AutoFish.Logging.events, event)
            
            -- Ограничиваем размер массива
            if #AutoFish.Logging.events > AutoFish.Logging.maxEvents then
                table.remove(AutoFish.Logging.events, 1)
            end
            
            -- Обновляем GUI окно логов если оно открыто
            if AutoFish.AddLogLineToGUI and AutoFish.LogWindowOpen then
                local text, color = FormatLogForGUI(event)
                AutoFish.AddLogLineToGUI(text, color)
            end
        end
        
        local function LogBobberState(bobber)
            if not AutoFish.Settings.logging or not IsValid(bobber) then return end
            
            local state = {
                time = CurTime(),
                scale = math.Round(bobber:GetModelScale(), 3),
                pos = bobber:GetPos(),
                fishID = bobber:GetFishID() or "",
                fishDir = bobber:GetFishDir() or Vector(0, 0, 0),
            }
            
            table.insert(AutoFish.Logging.bobberStates, state)
            
            if #AutoFish.Logging.bobberStates > 1000 then
                table.remove(AutoFish.Logging.bobberStates, 1)
            end
        end
        
        local function LogControlAction(action, details)
            if not AutoFish.Settings.logging then return end
            
            local control = {
                time = CurTime(),
                action = action,
                details = details or {},
            }
            
            table.insert(AutoFish.Logging.controlActions, control)
            
            if #AutoFish.Logging.controlActions > 1000 then
                table.remove(AutoFish.Logging.controlActions, 1)
            end
            
            -- Обновляем GUI окно логов если оно открыто
            if AutoFish.AddLogLineToGUI and AutoFish.LogWindowOpen then
                local logEntry = {type = "movement", time = control.time, data = control.details}
                local text, color = FormatLogForGUI(logEntry)
                AutoFish.AddLogLineToGUI(text, color)
            end
        end
        
        local function LogNetworkMessage(name, data)
            if not AutoFish.Settings.logging or not AutoFish.Settings.logNetworkMessages then return end
            
            local msg = {
                time = CurTime(),
                name = name,
                data = data or {},
            }
            
            table.insert(AutoFish.Logging.networkMessages, msg)
            
            if #AutoFish.Logging.networkMessages > 500 then
                table.remove(AutoFish.Logging.networkMessages, 1)
            end
            
            -- Обновляем GUI окно логов если оно открыто
            if AutoFish.AddLogLineToGUI and AutoFish.LogWindowOpen then
                local logEntry = {type = "network", time = msg.time, data = {name = msg.name}}
                local text, color = FormatLogForGUI(logEntry)
                AutoFish.AddLogLineToGUI(text, color)
            end
        end
        
        local function LogError(errorMsg, details)
            if not AutoFish.Settings.logging then return end
            
            local error = {
                time = CurTime(),
                message = errorMsg,
                details = details or {},
            }
            
            table.insert(AutoFish.Logging.errors, error)
            
            if #AutoFish.Logging.errors > 100 then
                table.remove(AutoFish.Logging.errors, 1)
            end
            
            -- Обновляем GUI окно логов если оно открыто
            if AutoFish.AddLogLineToGUI and AutoFish.LogWindowOpen then
                local logEntry = {type = "error", time = error.time, data = {message = error.message}}
                local text, color = FormatLogForGUI(logEntry)
                AutoFish.AddLogLineToGUI(text, color)
            end
        end
        --]]
        
        -- Экспорт лога в JSON
        local function ExportLog()
            local logData = {
                version = "4.1",
                exportTime = os.time(),
                exportTimeFormatted = os.date("%Y-%m-%d %H:%M:%S"),
                sessionStartTime = AutoFish.Logging.sessionStartTime,
                sessionDuration = AutoFish.Logging.sessionStartTime and (CurTime() - AutoFish.Logging.sessionStartTime) or 0,
                events = AutoFish.Logging.events,
                networkMessages = AutoFish.Logging.networkMessages,
                bobberStates = AutoFish.Logging.bobberStates,
                controlActions = AutoFish.Logging.controlActions,
                errors = AutoFish.Logging.errors,
                stats = {
                    totalEvents = #AutoFish.Logging.events,
                    totalNetworkMessages = #AutoFish.Logging.networkMessages,
                    totalBobberStates = #AutoFish.Logging.bobberStates,
                    totalControlActions = #AutoFish.Logging.controlActions,
                    totalErrors = #AutoFish.Logging.errors,
                }
            }
            
            local json = util.TableToJSON(logData, true)
            return json
        end
        
        -- Сохранение лога в буфер обмена
        local function CopyLogToClipboard()
            local json = ExportLog()
            if json then
                SetClipboardText(json)
                return true
            end
            return false
        end
        
        -- Форматирование лога для GUI отображения
        local function FormatLogForGUI(logEntry)
            local timestamp = string.format("[%.2f]", logEntry.time or 0)
            local typeColors = {
                cast = Color(100, 200, 255),           -- Голубой
                bite_detected = Color(255, 200, 0),    -- Желтый
                hook_attempt = Color(255, 150, 0),     -- Оранжевый
                minigame_started = Color(0, 255, 0),   -- Зеленый
                fish_caught = Color(0, 255, 100),      -- Ярко-зеленый
                collect_fish = Color(100, 255, 200),   -- Бирюзовый
                minigame_bypass = Color(255, 255, 100), -- Ярко-желтый (байпас)
                scale_changed = Color(200, 200, 200),  -- Серый
                movement = Color(150, 150, 255),       -- Светло-синий
                network = Color(100, 150, 255),        -- Синий
                error = Color(255, 50, 50),            -- Красный
                warning = Color(255, 200, 0),          -- Желтый
                default = Color(200, 200, 200),        -- Серый по умолчанию
            }
            
            local color = typeColors[logEntry.type] or typeColors.default
            local text = timestamp .. " [" .. (logEntry.type or "unknown") .. "] "
            
            -- Форматируем данные в зависимости от типа
            if logEntry.type == "network" then
                text = text .. (logEntry.data.name or "unknown")
            elseif logEntry.type == "bite_detected" then
                text = text .. string.format("ПОКЛЕВКА! Scale: %.3f", logEntry.data.scale or 0)
            elseif logEntry.type == "hook_attempt" then
                text = text .. string.format("Подсечка (scale: %.3f)", logEntry.data.scale or 0)
            elseif logEntry.type == "fish_caught" then
                text = text .. "Рыба поймана! " .. (logEntry.data.fishID or "")
            elseif logEntry.type == "collect_fish" then
                text = text .. string.format("Забираю рыбу (ЛКМ) - %s", logEntry.data.fishID or "")
            elseif logEntry.type == "minigame_bypass" then
                text = text .. string.format("БАЙПАС [%s] - %s", logEntry.data.type or "unknown", logEntry.data.message or "")
            elseif logEntry.type == "minigame_started" then
                text = text .. "Мини-игра началась"
            elseif logEntry.type == "cast" then
                text = text .. "Закинута удочка"
            elseif logEntry.type == "scale_changed" then
                text = text .. string.format("%.3f -> %.3f", logEntry.data.oldScale or 0, logEntry.data.newScale or 0)
            elseif logEntry.data then
                -- Общий формат для других типов
                local dataStr = ""
                for k, v in pairs(logEntry.data) do
                    if type(v) ~= "table" then
                        dataStr = dataStr .. k .. "=" .. tostring(v) .. " "
                    end
                end
                text = text .. dataStr
            end
            
            return text, color
        end
        
        -- === СИСТЕМА ЗАПИСИ ДЕЙСТВИЙ ИГРОКА ===
        
        -- Начать запись новой сессии
        local function StartRecording(fishID)
            AutoFish.Recording = true
            AutoFish.RecordedSession = {
                startTime = CurTime(),
                endTime = 0,
                fishID = fishID or "unknown",
                result = "unknown",
                actions = {},
            }
            print("[AutoFish Recording] ЗАПИСЬ НАЧАТА! Управляйте вручную WASD")
            chat.AddText(Color(255, 0, 0), "[AutoFish] ", Color(255, 255, 255), "ЗАПИСЬ ВКЛЮЧЕНА - управляйте вручную!")
        end
        
        -- Остановить запись
        local function StopRecording(result)
            if not AutoFish.Recording then return end
            
            AutoFish.Recording = false
            AutoFish.RecordedSession.endTime = CurTime()
            AutoFish.RecordedSession.result = result or "unknown"
            
            -- Сохраняем в историю
            table.insert(AutoFish.RecordingSessions, AutoFish.RecordedSession)
            
            -- Ограничиваем историю до 10 последних записей
            if #AutoFish.RecordingSessions > 10 then
                table.remove(AutoFish.RecordingSessions, 1)
            end
            
            local duration = AutoFish.RecordedSession.endTime - AutoFish.RecordedSession.startTime
            print(string.format("[AutoFish Recording] ЗАПИСЬ ОСТАНОВЛЕНА! Длительность: %.1f сек, Действий: %d, Результат: %s",
                duration, #AutoFish.RecordedSession.actions, result or "unknown"))
            chat.AddText(Color(255, 100, 0), "[AutoFish] ", Color(255, 255, 255), 
                string.format("Запись сохранена: %.1f сек, %d действий", duration, #AutoFish.RecordedSession.actions))
        end
        
        -- Записать действие игрока
        local function RecordAction(keys, bobber, fishDir, centerPos, distanceFromCenter, fishToCenterDot)
            if not AutoFish.Recording then return end
            if not IsValid(bobber) then return end
            
            local action = {
                time = CurTime() - AutoFish.RecordedSession.startTime, -- Относительное время
                keys = {
                    forward = keys.forward or false,
                    back = keys.back or false,
                    right = keys.right or false,
                    left = keys.left or false,
                },
                fishDir = {x = fishDir.x, y = fishDir.y}, -- Направление стрелки
                bobberPos = bobber:GetPos(),
                centerPos = centerPos,
                distanceFromCenter = distanceFromCenter,
                fishToCenterDot = fishToCenterDot, -- Направление относительно центра
            }
            
            table.insert(AutoFish.RecordedSession.actions, action)
        end
        
        -- Экспорт всех записей в JSON
        local function ExportRecordings()
            local exportData = {
                version = "4.4.0",
                exportTime = os.time(),
                exportTimeFormatted = os.date("%Y-%m-%d %H:%M:%S"),
                totalSessions = #AutoFish.RecordingSessions,
                sessions = AutoFish.RecordingSessions,
            }
            
            local json = util.TableToJSON(exportData, true)
            return json
        end
        
        -- Копировать записи в буфер обмена
        local function CopyRecordingsToClipboard()
            if #AutoFish.RecordingSessions == 0 then
                print("[AutoFish Recording] Нет записей для экспорта")
                return false
            end
            
            local json = ExportRecordings()
            if not json or json == "" then
                print("[AutoFish Recording] Ошибка формирования JSON")
                return false
            end
            
            -- Проверяем размер данных
            local jsonSize = string.len(json)
            print(string.format("[AutoFish Recording] Размер данных: %d байт (%.2f KB)", jsonSize, jsonSize / 1024))
            
            -- Пробуем скопировать в буфер обмена
            local success = pcall(function()
                SetClipboardText(json)
            end)
            
            if success then
                print("[AutoFish Recording] Данные скопированы в буфер обмена!")
                print(string.format("[AutoFish Recording] Экспортировано сессий: %d", #AutoFish.RecordingSessions))
                
                -- Выводим краткую информацию о каждой сессии
                for i, session in ipairs(AutoFish.RecordingSessions) do
                    local duration = session.endTime - session.startTime
                    print(string.format("  [%d] %s: %.1f сек, %d действий, результат: %s", 
                        i, session.fishID, duration, #session.actions, session.result))
                end
                return true
            else
                print("[AutoFish Recording] Ошибка копирования в буфер обмена")
                
                -- Попытка альтернативного метода через консоль
                print("[AutoFish Recording] Альтернатива: данные выведены в консоль ниже")
                print("========== JSON START ==========")
                print(json)
                print("========== JSON END ==========")
                print("[AutoFish Recording] Скопируйте JSON из консоли вручную")
                return false
            end
        end
        
        -- История движения
        AutoFish.History = {
            fishDir = {},
            bobberPos = {},
            maxHistory = 10,
        }
        
        -- Получение удочки
        local function GetFishingRod()
            local ply = LocalPlayer()
            if not IsValid(ply) then return nil end
            local wep = ply:GetActiveWeapon()
            if not IsValid(wep) then return nil end
            if string.find(wep:GetClass(), "fisher_rod") then
                return wep
            end
            return nil
        end
        
        -- Получение поплавка
        local function GetBobber()
            local rod = GetFishingRod()
            if not rod then return nil end
            return rod:GetBobber()
        end
        
        
        -- Anti Screen Grab (Улучшенная версия - моментальное скрытие)
        local lastScreenGrabCheck = 0
        local screenshotKeyPressed = false
        local screenshotHideTime = 0
        AutoFish.IsScreenshotActive = false -- Глобальный флаг для всех визуальных элементов
        
        -- Функция проверки скриншота (возвращает true если скриншот активен)
        -- Делаем доступной глобально для использования в хуках
        AutoFish.IsScreenshotActiveFunc = function()
            if not AutoFish.Settings.antiScreenGrab then return false end
            return AutoFish.IsScreenshotActive or screenshotKeyPressed
        end
        local IsScreenshotActive = AutoFish.IsScreenshotActiveFunc
        
        local function AntiScreenGrab()
            if not AutoFish.Settings.antiScreenGrab then 
                AutoFish.IsScreenshotActive = false
                return 
            end
            
            local currentTime = CurTime()
            
            -- МОМЕНТАЛЬНАЯ проверка без задержки для быстрой реакции
            local isF12 = false
            local isSysRq = false
            local isPrint = false
            
            -- Безопасная проверка клавиш через pcall
            if type(KEY_F12) == "number" then
                local success, result = pcall(function() return input.IsKeyDown(KEY_F12) end)
                if success then isF12 = result end
            end
            if type(KEY_SYSRQ) == "number" then
                local success, result = pcall(function() return input.IsKeyDown(KEY_SYSRQ) end)
                if success then isSysRq = result end
            end
            if type(KEY_PRINT) == "number" then
                local success, result = pcall(function() return input.IsKeyDown(KEY_PRINT) end)
                if success then isPrint = result end
            end
            
            local isScreenshotKey = isF12 or isSysRq or isPrint
            
            -- Если клавиша нажата - МОМЕНТАЛЬНО скрываем всё
            if isScreenshotKey and not screenshotKeyPressed then
                screenshotKeyPressed = true
                AutoFish.IsScreenshotActive = true -- Устанавливаем глобальный флаг
                screenshotHideTime = currentTime
                
                -- Скрываем ГЛАВНОЕ МЕНЮ
                if IsValid(AutoFish.MenuFrame) then
                    AutoFish.MenuFrame:SetAlpha(0)
                    AutoFish.MenuFrame:SetVisible(false)
                    AutoFish.MenuFrame:SetMouseInputEnabled(false)
                    AutoFish.MenuFrame:SetKeyboardInputEnabled(false)
                end
                
                -- Скрываем ОКНО ЛОГОВ
                if IsValid(AutoFish.LogWindowFrame) then
                    AutoFish.LogWindowFrame:SetAlpha(0)
                    AutoFish.LogWindowFrame:SetVisible(false)
                    AutoFish.LogWindowFrame:SetMouseInputEnabled(false)
                    AutoFish.LogWindowFrame:SetKeyboardInputEnabled(false)
                end
                
                
                if AutoFish.Settings.debugMode then
                    print("[AutoFish Anti-Grab] 📸 Скриншот! Все визуальные элементы скрыты")
                end
            end
            
            -- Если клавиша отпущена - восстанавливаем через 0.5 сек
            if not isScreenshotKey and screenshotKeyPressed then
                screenshotKeyPressed = false
                
                timer.Simple(0.5, function()
                    AutoFish.IsScreenshotActive = false -- Сбрасываем глобальный флаг
                    
                    -- Восстанавливаем ГЛАВНОЕ МЕНЮ
                    if IsValid(AutoFish.MenuFrame) and AutoFish.MenuOpen then
                        AutoFish.MenuFrame:SetAlpha(255)
                        AutoFish.MenuFrame:SetVisible(true)
                        AutoFish.MenuFrame:SetMouseInputEnabled(true)
                        AutoFish.MenuFrame:SetKeyboardInputEnabled(true)
                    end
                    
                    -- Восстанавливаем ОКНО ЛОГОВ
                    if IsValid(AutoFish.LogWindowFrame) and AutoFish.LogWindowOpen then
                        AutoFish.LogWindowFrame:SetAlpha(255)
                        AutoFish.LogWindowFrame:SetVisible(true)
                        AutoFish.LogWindowFrame:SetMouseInputEnabled(true)
                        AutoFish.LogWindowFrame:SetKeyboardInputEnabled(true)
                    end
                    
                    
                    if AutoFish.Settings.debugMode then
                        print("[AutoFish Anti-Grab] Все визуальные элементы восстановлены")
                    end
                end)
            end
        end
        
        -- Добавление в историю
        local function AddToHistory(key, value)
            if not AutoFish.History[key] then
                AutoFish.History[key] = {}
            end
            table.insert(AutoFish.History[key], value)
            if #AutoFish.History[key] > AutoFish.History.maxHistory then
                table.remove(AutoFish.History[key], 1)
            end
        end
        
        -- Предсказание направления (УЛУЧШЕННАЯ версия)
        local function PredictFishDirection()
            if not AutoFish.Settings.prediction then return nil end
            if #AutoFish.History.fishDir < 2 then return nil end
            
            local history = AutoFish.History.fishDir
            local last = history[#history]
            local prev = history[#history - 1]
            
            -- Базовое линейное предсказание (скорость изменения)
            local velocity = last - prev
            velocity:Normalize()
            
            -- Если есть больше истории - используем более точное предсказание
            if #history >= 3 then
                local prev2 = history[#history - 2]
                local accel = (last - prev) - (prev - prev2) -- Ускорение
                accel:Normalize()
                
                -- Смешиваем скорость и ускорение для более точного предсказания
                local predicted = last + velocity * 0.15 + accel * 0.05
                predicted:Normalize()
                return predicted
            else
                -- Простое предсказание на основе скорости
                local predicted = last + velocity * 0.1
                predicted:Normalize()
                return predicted
            end
        end
        
        -- Вычисление оптимального направления (ИСПРАВЛЕННАЯ логика из реального кода)
        local function CalculateOptimalDirection(bobber, fishDir, zoneSize, currentPlyDir)
            if not IsValid(bobber) then return Vector(0, 0, 0) end
            
            local ply = LocalPlayer()
            if not IsValid(ply) then return Vector(0, 0, 0) end
            
            -- Используем предсказание если доступно (УЛУЧШЕННАЯ версия)
            local predictedDir = PredictFishDirection()
            if predictedDir then
                -- Более агрессивное использование предсказания для лучшей реакции
                -- Смешиваем текущее направление с предсказанным
                local predictionStrength = 0.4 -- Сила предсказания (увеличена)
                fishDir = LerpVector(1.0 - predictionStrength, fishDir, predictedDir)
            end
            
            fishDir.z = 0
            fishDir:Normalize()
            
            -- Позиция поплавка
            local bobberPos = bobber:GetPos()
            
            -- ИСПРАВЛЕНО: Центр зоны - это позиция поплавка (зеленая точка на скриншоте)
            -- Красная стрелка показывает направление рыбы (fishDir)
            -- Нужно тянуть в противоположную сторону от рыбы, чтобы удерживать стрелку в центре
            -- Красная зона - это граница (maxZoneRadius), которую нельзя пересекать
            
            -- Центр зоны = позиция поплавка (зеленая точка)
            local centerPos = bobberPos
            
            -- Вычисляем текущее направление движения игрока из клавиш (для визуализации и будущего использования)
            local plyDir = Vector(0, 0, 0)
            local forward = ply:GetForward()
            local right = ply:GetRight()
            forward.z = 0
            right.z = 0
            forward:Normalize()
            right:Normalize()
            
            -- Если есть текущее направление, используем его, иначе вычисляем из клавиш
            if currentPlyDir then
                plyDir = currentPlyDir
            else
                -- Вычисляем направление из текущих нажатых клавиш (для предсказания)
                -- Но это будет вычислено позже в AutoControlBobber
                plyDir = Vector(0, 0, 0)
            end
            
            plyDir.z = 0
            if plyDir:Length() > 0 then
                plyDir:Normalize()
            end
            
            -- Размер зоны: size = 200, size+50 = 250 (из реального кода)
            local innerZoneSize = AutoFish.Settings.innerZoneSize -- 200
            local maxZoneRadius = innerZoneSize + 50 -- 250 (полный радиус зоны - ГРАНИЦА!)
            local safeMargin = innerZoneSize * AutoFish.Settings.zoneMargin -- безопасный отступ (по умолчанию 160)
            
            -- Вычисляем позицию красной стрелки (направление рыбы от поплавка)
            -- Красная стрелка находится в: bobberPos + fishDir * 50
            local arrowPos = bobberPos + fishDir * 50
            
            -- Вычисляем расстояние от центра зоны (поплавка) до красной стрелки
            local distanceFromCenterToArrow = (arrowPos - centerPos):Length()
            
            -- Вычисляем вектор от красной стрелки к центру зоны (поплавку)
            local toCenter = centerPos - arrowPos
            toCenter.z = 0
            local distanceToCenter = toCenter:Length()
            
            -- Также вычисляем расстояние от поплавка до центра (для совместимости)
            local distanceFromCenterToBobber = 0 -- Поплавок И ЕСТЬ центр, поэтому 0
            
            local targetDir = Vector(0, 0, 0)
            
            -- КРИТИЧНО: Проверяем, не выходит ли КРАСНАЯ СТРЕЛКА за границы зоны
            -- Расстояние от центра зоны (поплавка) до красной стрелки не должно превышать maxZoneRadius (250)
            if distanceFromCenterToArrow > maxZoneRadius then
                -- Красная стрелка за границей зоны - СРОЧНО тянем к центру с максимальной силой
                -- Тянем в противоположную сторону от рыбы (к центру)
                targetDir = toCenter:GetNormalized()
                --[[
                if AutoFish.Settings.debugMode then
                    ThrottledDebugPrint("out_of_bounds", string.format("[AutoFish] ВЫХОД ЗА ГРАНИЦУ! Стрелка на расстоянии: %.1f > %.1f", distanceFromCenterToArrow, maxZoneRadius), 1.0)
                end
                --]]
            -- Если красная стрелка слишком далеко от центра зоны (но еще в пределах границы)
            elseif distanceToCenter > safeMargin then
                -- Близко к границе - ПРИОРИТЕТ: возврат к центру, но с учетом движения рыбы
                -- Смешиваем направление к центру с противоположным направлением рыбы
                local toCenterNormalized = toCenter:GetNormalized()
                local antiFishDir = fishDir * -1
                
                -- Чем ближе к границе - тем больше приоритет центру
                local edgeDistance = maxZoneRadius - distanceFromCenterToArrow
                local edgeRatio = math.Clamp(edgeDistance / (maxZoneRadius - safeMargin), 0, 1)
                
                -- Смешиваем: 70% к центру, 30% против рыбы (если далеко от границы)
                -- Если очень близко к границе - 100% к центру
                local centerWeight = math.max(0.7, 1.0 - edgeRatio * 0.3)
                targetDir = LerpVector(1.0 - centerWeight, toCenterNormalized, antiFishDir)
                targetDir:Normalize()
        else
            -- УПРОЩЕННАЯ ЛОГИКА: В безопасной зоне (зеленая зона)
            -- Красная стрелка всегда на расстоянии 50 единиц от центра
            -- Управляем по расстоянию до границы зоны
            
            -- Расстояние от стрелки до границы красной зоны
            local distanceToEdge = maxZoneRadius - distanceFromCenterToArrow
            
            -- Получаем предыдущее направление рыбы из истории для определения тренда
            local prevFishDir = nil
            if #AutoFish.History.fishDir >= 2 then
                prevFishDir = AutoFish.History.fishDir[#AutoFish.History.fishDir - 1]
            end
            
            -- Определяем, движется ли стрелка к центру или от центра
            local isMovingToCenter = false
            if prevFishDir then
                -- Вычисляем изменение направления рыбы
                local dirChange = (fishDir - prevFishDir):Length()
                -- Если направление меняется быстро - рыба активна, нужно тянуть
                -- Если направление стабильное - можно не тянуть или тянуть слабо
                isMovingToCenter = dirChange < 0.1
            end
            
            -- УПРОЩЕННАЯ ЛОГИКА: Всегда тянем в противоположную сторону от рыбы
            -- Сила зависит от расстояния до границы, но ВСЕГДА тянем (никогда не останавливаемся)
            if distanceToEdge < 20 then
                -- Очень близко к границе - тянем максимально
                targetDir = fishDir * -1
                targetDir:Normalize()
                
                --[[
                if AutoFish.Settings.debugMode then
                    ThrottledDebugPrint("arrow_edge", string.format("[AutoFish] Близко к границе (dist: %.1f) - тянем максимально", 
                        distanceToEdge), 0.5)
                end
                --]]
            elseif distanceToEdge < 50 then
                -- Близко к границе - тянем активно
                targetDir = fishDir * -1
                targetDir:Normalize()
            else
                -- Средняя и дальняя зона - тянем постоянно, но с меньшей силой
                -- ВСЕГДА тянем, чтобы круг двигался
                targetDir = fishDir * -1
                targetDir:Normalize()
            end
        end
        
        return targetDir, centerPos, maxZoneRadius, safeMargin, distanceFromCenterToArrow, plyDir
    end
    
    -- Управление клавишами (точная реализация из кода)
    local function SmoothKeyControl(keys, fishID)
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- Обработка witch_fish (инвертированные клавиши)
        if fishID == "witch_fish" then
            if keys.forward then ply:ConCommand("+back") else ply:ConCommand("-back") end
            if keys.back then ply:ConCommand("+forward") else ply:ConCommand("-forward") end
            if keys.right then ply:ConCommand("+moveleft") else ply:ConCommand("-moveleft") end
            if keys.left then ply:ConCommand("+moveright") else ply:ConCommand("-moveright") end
        else
            if keys.forward then ply:ConCommand("+forward") else ply:ConCommand("-forward") end
            if keys.back then ply:ConCommand("+back") else ply:ConCommand("-back") end
            if keys.right then ply:ConCommand("+moveright") else ply:ConCommand("-moveright") end
            if keys.left then ply:ConCommand("+moveleft") else ply:ConCommand("-moveleft") end
        end
        
        -- Логируем действия управления
        --[[
        LogControlAction("movement", {
            forward = keys.forward,
            back = keys.back,
            right = keys.right,
            left = keys.left,
            forwardDot = forwardDot,
            rightDot = rightDot,
            targetDir = targetDir,
            distanceFromCenter = distanceFromCenter,
            zoneData = AutoFish.LastZoneData,
        })
        --]]
    end
    
    -- Автоматическое управление поплавком (на основе реального кода)
    local function AutoControlBobber()
            if not AutoFish.Enabled then 
                -- Диагностика: скрипт выключен
                if not AutoFish.DebugDisabledShown then
                    print("[AutoFish Perfect] Скрипт ВЫКЛЮЧЕН! Включите в меню (END) или командой: autofish_perfect_enable")
                    AutoFish.DebugDisabledShown = true
                end
                return 
            end
            AutoFish.DebugDisabledShown = false
            
            local bobber = GetBobber()
            if not IsValid(bobber) then 
                -- Если запись была активна - рыба упущена
                if AutoFish.Recording then
                    StopRecording("escaped")
                end
                -- Поплавок не найден - это нормально, когда удочка не закинута
                return 
            end
            
            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            
            -- Проверяем scale (из реального кода):
            -- 1.02 = экран "Нажми ЛКМ чтобы начать" (DrawHUD в fisher_rod_base)
            -- 1.03 = мини-игра активна (нужно управлять поплавком)
            -- 1.01 = рыба поймана
            local rawScale = bobber:GetModelScale()
            local scale = math.Round(rawScale, 2)
            
            -- Выводим scale только при изменении или важных состояниях (не спамим при scale = 1.00)
            --[[
            if scale ~= 1.00 then
                if not AutoFish.LastScaleReport or (CurTime() - AutoFish.LastScaleReport) > 2.0 then
                    ThrottledDebugPrint("bobber_scale", string.format("[AutoFish Perfect] Поплавок найден! Scale: %.3f (округлено: %.2f) | LastScale: %s", 
                        rawScale, scale, tostring(AutoFish.LastBobberScale)), 2.0)
                    AutoFish.LastScaleReport = CurTime()
                end
            end
            --]]
            
            -- Отладочный вывод для диагностики (если включен режим отладки)
            if AutoFish.Settings.debugMode and scale ~= 1.00 and scale ~= 1.01 and scale ~= 1.03 then
                print(string.format("[AutoFish Debug] Scale: %.3f (округлено: %.2f) | LastScale: %s", 
                    rawScale, scale, tostring(AutoFish.LastBobberScale)))
            end
            
            -- Отслеживаем изменение scale для подсечки (ПЕРЕД обновлением)
            local lastScale = AutoFish.LastBobberScale
            -- ИСПРАВЛЕНО: scaleChanged теперь учитывает случай когда поплавок только создан
            local scaleChanged = false
            if lastScale == nil then
                -- Поплавок только создан - инициализируем scale
                -- Если scale сразу 1.02 - это поклевка!
                if scale == 1.02 then
                    scaleChanged = true
                end
            elseif lastScale ~= scale then
                -- Scale изменился - логируем
                --[[
                LogEvent("scale_changed", {
                    oldScale = lastScale,
                    newScale = scale,
                    rawScale = rawScale,
                    fishID = bobber:GetFishID() or "",
                })
                --]]
                
                -- РАСШИРЕННОЕ ЛОГИРОВАНИЕ для поиска мини-игры (ВСЕГДА, не только в debugMode)
                print(string.format("[AutoFish Debug] SCALE ИЗМЕНИЛСЯ: %.2f -> %.2f (raw: %.3f) | fishID: %s", 
                    lastScale, scale, rawScale, bobber:GetFishID() or "нет"))
                
                -- Проверяем возможные значения мини-игры
                if scale == 1.03 or scale == 1.02 or (rawScale >= 1.015 and rawScale < 1.035) then
                    if AutoFish.Settings.debugMode then
                        print(string.format("[AutoFish Debug] ВОЗМОЖНАЯ МИНИ-ИГРА! Scale: %.2f (raw: %.3f)", 
                            scale, rawScale))
                    end
                end
                
                if scale == 1.02 then
                    -- Изменился на 1.02 - это поклевка!
                    scaleChanged = true
                end
            end
            
            -- Если мини-игра еще не началась (scale == 1.02), ждем и нажимаем ЛКМ
            -- Проверяем точное значение 1.02 или близкое к нему (1.015-1.025, но не 1.01 и не 1.03)
            local isBiteScale = (scale == 1.02) or (rawScale >= 1.015 and rawScale < 1.025 and scale ~= 1.01 and scale ~= 1.03)
            
            if isBiteScale then
                -- Логируем поклевку ТОЛЬКО при изменении scale на 1.02 (чтобы избежать дублирования)
                --[[
                if scaleChanged or (lastScale ~= 1.02 and scale == 1.02) then
                    LogEvent("bite_detected", {
                        scale = rawScale,
                        roundedScale = scale,
                        lastScale = lastScale,
                        waitingForStart = AutoFish.WaitingForStart,
                        autoStartEnabled = AutoFish.Settings.autoStartMinigame,
                        scaleChanged = scaleChanged,
                    })
                end
                --]]
                
                -- Всегда выводим информацию о поклевке для диагностики
                if not AutoFish.LastBiteReport or (CurTime() - AutoFish.LastBiteReport) > 0.5 then
                    print(string.format("[AutoFish Perfect] ПОКЛЕВКА ОБНАРУЖЕНА! Scale: %.3f (%.2f) | LastScale: %s | WaitingForStart: %s | autoStart: %s", 
                        rawScale, scale, tostring(lastScale), tostring(AutoFish.WaitingForStart), tostring(AutoFish.Settings.autoStartMinigame)))
                    AutoFish.LastBiteReport = CurTime()
                end
                -- Автоматически начинаем мини-игру (подсекаем)
                if AutoFish.Settings.autoStartMinigame then
                    -- УПРОЩЕННАЯ ЛОГИКА: scale == 1.02 = поклевка, подсекаем сразу!
                    local timeSinceLastHook = CurTime() - (AutoFish.LastHookAttempt or 0)
                    local fishID = bobber:GetFishID()
                    
                    -- ИСПРАВЛЕНО: Проверяем, не подсекали ли мы уже для этого scale
                    -- Это предотвращает двойную подсечку
                    local alreadyHookedForThisScale = (AutoFish.LastHookScale == scale)
                    
                    -- УПРОЩЕННАЯ ЛОГИКА: подсекаем если не ждем и прошло минимум 0.1 сек
                    -- ИЛИ если scale только что изменился - подсекаем немедленно
                    local shouldHook = false
                    
                    if scaleChanged and not alreadyHookedForThisScale then
                        -- Scale изменился на 1.02 - подсекаем НЕМЕДЛЕННО! (только если еще не подсекали)
                        shouldHook = not AutoFish.WaitingForStart
                    elseif AutoFish.LastHookAttempt == 0 and not alreadyHookedForThisScale then
                        -- Еще не пытались подсечь в этой сессии - подсекаем!
                        shouldHook = not AutoFish.WaitingForStart
                    elseif not AutoFish.WaitingForStart and timeSinceLastHook >= 0.3 and not alreadyHookedForThisScale then
                        -- Прошло достаточно времени (увеличено до 0.3 сек) - подсекаем (повторная попытка)
                        shouldHook = true
                    end
                    
                    if shouldHook then
                        AutoFish.WaitingForStart = true
                        AutoFish.LastHookAttempt = CurTime()
                        AutoFish.LastHookScale = scale -- Сохраняем scale, при котором подсекали
                        
                        -- Логируем подсечку
                        --[[
                        LogEvent("hook_attempt", {
                            scale = rawScale,
                            roundedScale = scale,
                            lastScale = lastScale,
                            fishID = fishID,
                            scaleChanged = scaleChanged,
                            timeSinceLastHook = timeSinceLastHook,
                        })
                        --]]
                        
                        -- Нажимаем ЛКМ для подсечки (используем несколько методов для надежности)
                        ply:ConCommand("+attack")
                        RunConsoleCommand("+attack")
                        
                        -- Дополнительно используем прямой вызов через LocalPlayer
                        timer.Simple(0.01, function()
                            if IsValid(ply) then
                                ply:ConCommand("+attack")
                            end
                        end)
                        
                        -- Всегда выводим сообщение о подсечке (для диагностики)
                        print(string.format("[AutoFish Perfect] ПОДСЕКАЮ! Scale: %.3f (%.2f) | Last: %s | fishID: %s | changed: %s", 
                            rawScale, scale, tostring(lastScale), fishID or "нет", tostring(scaleChanged)))
                        
                        if AutoFish.Settings.debugMode then
                            print(string.format("[AutoFish Perfect] Детали: timeSince=%.2f, WaitingForStart=%s", 
                                timeSinceLastHook, tostring(AutoFish.WaitingForStart)))
                        end
                        
                        -- Отпускаем через короткое время
                        timer.Simple(0.1, function()
                            if IsValid(ply) then
                                RunConsoleCommand("-attack")
                                ply:ConCommand("-attack")
                            end
                            -- Даем время на обработку перед следующим нажатием
                            timer.Simple(0.2, function()
                                AutoFish.WaitingForStart = false
                            end)
                        end)
                        
                        -- ИСПРАВЛЕНО: После подсечки ждем появления экрана мини-игры и нажимаем ЛКМ еще раз
                        -- Экран появляется через ~0.3-0.5 секунды после подсечки
                        AutoFish.MinigameStartAttempted = false
                        timer.Simple(0.4, function()
                            if not IsValid(ply) then return end
                            local checkBobber = GetBobber()
                            if IsValid(checkBobber) then
                                local checkScale = math.Round(checkBobber:GetModelScale(), 2)
                                -- Если scale все еще 1.02 - экран мини-игры висит, нужно нажать ЛКМ
                                if checkScale == 1.02 and not AutoFish.MinigameStartAttempted then
                                    AutoFish.MinigameStartAttempted = true
                                    AutoFish.LastMinigameStartAttempt = CurTime()
                                    
                                    print("[AutoFish Perfect] Начинаю мини-игру (ЛКМ на экране)")
                                    
                                    -- Нажимаем ЛКМ для начала мини-игры
                                    ply:ConCommand("+attack")
                                    RunConsoleCommand("+attack")
                                    
                                    -- Отпускаем через короткое время
                                    timer.Simple(0.15, function()
                                        if IsValid(ply) then
                                            RunConsoleCommand("-attack")
                                            ply:ConCommand("-attack")
                                        end
                                    end)
                                end
                            end
                        end)
                    -- Убрано отладочное сообщение "Не подсекаю" для уменьшения спама
                    end
                end
            end
            
            -- ДОПОЛНИТЕЛЬНО: Если scale 1.02 держится долго (экран мини-игры висит), периодически нажимаем ЛКМ
            if scale == 1.02 and AutoFish.Settings.autoStartMinigame then
                local timeSinceLastStart = CurTime() - AutoFish.LastMinigameStartAttempt
                -- Если прошло больше 1 секунды с последней попытки и еще не пытались - пробуем еще раз
                if timeSinceLastStart >= 1.0 and not AutoFish.MinigameStartAttempted then
                    AutoFish.MinigameStartAttempted = true
                    AutoFish.LastMinigameStartAttempt = CurTime()
                    
                    local ply = LocalPlayer()
                    if IsValid(ply) then
                        print("[AutoFish Perfect] Повторная попытка начать мини-игру (ЛКМ)")
                        
                        -- Нажимаем ЛКМ для начала мини-игры
                        ply:ConCommand("+attack")
                        RunConsoleCommand("+attack")
                        
                        -- Отпускаем через короткое время
                        timer.Simple(0.15, function()
                            if IsValid(ply) then
                                RunConsoleCommand("-attack")
                                ply:ConCommand("-attack")
                            end
                        end)
                    end
                end
            end
            
            -- Сбрасываем флаг при переходе на другой scale
            if scale ~= 1.02 then
                AutoFish.MinigameStartAttempted = false
            end
            
            -- Обновляем scale ПОСЛЕ проверки
            AutoFish.LastBobberScale = scale
            return
        end
        
        -- Обновляем scale для других состояний
        
        -- Если рыба поймана (scale == 1.01), нажимаем ЛКМ для забора улова
        if scale == 1.01 then
            -- Останавливаем запись если была активна
            if AutoFish.Recording then
                StopRecording("caught")
            end
            
            -- Логируем только при переходе на 1.01 (чтобы избежать дублирования)
            if lastScale and lastScale ~= 1.01 then
                local fishID = bobber:GetFishID() or ""
                
                --[[
                LogEvent("fish_caught", {
                    scale = scale,
                    rawScale = rawScale,
                    fishID = fishID,
                    previousScale = lastScale,
                })
                --]]
                
                
                -- ИСПРАВЛЕНО: Сохраняем время забора рыбы СРАЗУ при обнаружении scale = 1.01
                -- Это нужно для правильного расчета перезарядки удочки
                AutoFish.LastFishCollected = CurTime()
                
                -- НОВАЯ ЛОГИКА: Автоматически забираем рыбу левой кнопкой мыши
                local timeSinceLastCollect = CurTime() - AutoFish.LastCollectAttempt
                
                -- Нажимаем ЛКМ только если не собираем уже и прошло достаточно времени
                if not AutoFish.CollectingFish and timeSinceLastCollect >= 0.5 then
                    AutoFish.CollectingFish = true
                    AutoFish.LastCollectAttempt = CurTime()
                    
                    -- Логируем попытку забора
                    --[[
                    LogEvent("collect_fish", {
                        scale = scale,
                        rawScale = rawScale,
                        fishID = bobber:GetFishID() or "",
                        timeSinceLastCollect = timeSinceLastCollect,
                    })
                    --]]
                    
                    -- Нажимаем ЛКМ (+attack)
                    ply:ConCommand("+attack")
                    RunConsoleCommand("+attack")
                    
                    --[[
                    ThrottledDebugPrint("collect_fish", string.format("[AutoFish Perfect] ЗАБИРАЮ РЫБУ (ЛКМ)! Scale: %.3f (%.2f) | fishID: %s", 
                        rawScale, scale, bobber:GetFishID() or "нет"), 1.0)
                    --]]
                    
                    -- Удерживаем ЛКМ 1.5 секунды
                    timer.Simple(1.5, function()
                        if IsValid(ply) then
                            RunConsoleCommand("-attack")
                            ply:ConCommand("-attack")
                            if AutoFish.Settings.debugMode then
                                print("[AutoFish Perfect] ЛКМ отпущена, рыба забрана")
                            end
                        end
                        -- Сбрасываем флаг через небольшую задержку
                        timer.Simple(0.5, function()
                            AutoFish.CollectingFish = false
                        end)
                    end)
                -- Убрано отладочное сообщение для уменьшения спама
                end
            end
            return
        end
        
        
        -- Если мини-игра не активна (scale != 1.03), выходим
        if scale != 1.03 then
            return
        end

end

        -- Логируем начало мини-игры (scale == 1.03) - только при переходе с другого scale
        if lastScale and lastScale ~= 1.03 and scale == 1.03 then
            --[[
            LogEvent("minigame_started", {
                scale = scale,
                rawScale = rawScale,
                fishID = bobber:GetFishID() or "",
                previousScale = lastScale,
            })
            --]]
            
            -- Автоматически начинаем запись если режим записи включен
            if AutoFish.Enabled and AutoFish.Settings.recordingMode and not AutoFish.Recording then
                StartRecording(bobber:GetFishID() or "unknown")
            end
        end
        
        local fishID = bobber:GetFishID()
        if not fishID then return end
        
        -- Получаем направление рыбы (из NetworkVar)
        local fishDir = bobber:GetFishDir()
        fishDir.z = 0
        fishDir:Normalize()
        
        -- Логируем состояние поплавка
        --[[
        LogBobberState(bobber)
        --]]
        
        -- Добавляем в историю
        AddToHistory("fishDir", fishDir)
        AddToHistory("bobberPos", bobber:GetPos())
        
        -- Размер зоны из реального кода: size = 200, size+50 = 250
        local zoneSize = AutoFish.Settings.zoneSize
        
        -- ВАЖНО: Поплавок должен ТЯНУТЬ в ПРОТИВОПОЛОЖНУЮ сторону от рыбы
        -- Это удерживает рыбу в центре зоны
        -- Если перетягивает - всегда стремиться к центру
        
        -- Получаем векторы направления игрока
        local forward = ply:GetForward()
        local right = ply:GetRight()
        forward.z = 0
        right.z = 0
        forward:Normalize()
        right:Normalize()
        
        -- Используем предыдущее направление движения игрока (с Lerp как в реальном коде)
        -- Это позволяет избежать циклической зависимости
        local prevPlyDir = AutoFish.LastPlyDir
        if prevPlyDir:Length() == 0 then
            prevPlyDir = Vector(0, 0, 0)
        end
        
        -- Вычисляем оптимальное направление с учетом предыдущего направления игрока
        local targetDir, centerPos, maxZoneRadius, safeMargin, distanceFromCenter, calculatedPlyDir = CalculateOptimalDirection(bobber, fishDir, zoneSize, prevPlyDir)
        
        -- Логируем данные зоны
        -- distanceFromCenter теперь означает расстояние от центра (поплавка) до красной стрелки
        AutoFish.LastZoneData = {
            centerPos = centerPos,
            maxZoneRadius = maxZoneRadius,
            safeMargin = safeMargin,
            distanceFromCenter = distanceFromCenter, -- Расстояние от центра до красной стрелки
            targetDir = targetDir,
            fishDir = fishDir,
            calculatedPlyDir = calculatedPlyDir,
        }
        
        -- Вычисляем проекции целевого направления на векторы игрока
        local forwardDot = targetDir:Dot(forward)
        local rightDot = targetDir:Dot(right)
        
        -- УПРОЩЕННЫЙ ПОРОГ: всегда используем низкий порог для активного управления
        -- Это обеспечивает постоянное движение круга
        local adaptiveThreshold = 0.05 -- Низкий порог для активного управления
        
        -- Если очень близко к границе - еще более агрессивное управление
        if distanceFromCenter > maxZoneRadius then
            adaptiveThreshold = 0.02 -- Минимальный порог для срочного возврата
        elseif distanceFromCenter > safeMargin then
            -- Близко к границе - более активное управление
            adaptiveThreshold = 0.03
        end
        
        -- РЕЖИМ ЗАПИСИ: Читаем действия игрока вместо автоматического управления
        local keys = {}
        if AutoFish.Recording then
            -- Читаем реальные нажатия клавиш игрока
            keys = {
                forward = input.IsKeyDown(KEY_W),
                back = input.IsKeyDown(KEY_S),
                right = input.IsKeyDown(KEY_D),
                left = input.IsKeyDown(KEY_A),
            }
        else
            -- Автоматическое управление (как обычно)
            keys = {
                forward = forwardDot > adaptiveThreshold,
                back = forwardDot < -adaptiveThreshold,
                right = rightDot > adaptiveThreshold,
                left = rightDot < -adaptiveThreshold,
            }
        end
        
        -- Вычисляем новое направление движения игрока из нажатых клавиш (как в реальном коде)
        local newPlyDir = Vector(0, 0, 0)
        if fishID == "witch_fish" then
            if keys.forward then newPlyDir:Sub(forward) end
            if keys.back then newPlyDir:Add(forward) end
            if keys.right then newPlyDir:Sub(right) end
            if keys.left then newPlyDir:Add(right) end
        else
            if keys.forward then newPlyDir:Add(forward) end
            if keys.back then newPlyDir:Sub(forward) end
            if keys.right then newPlyDir:Add(right) end
            if keys.left then newPlyDir:Sub(right) end
        end
        
        newPlyDir.z = 0
        if newPlyDir:Length() > 0 then
            newPlyDir:Normalize()
        end
        
        -- Обновляем направление движения игрока с Lerp (как в реальном коде: Lerp(FrameTime()*5, ...))
        -- УЛУЧШЕННЫЙ Lerp для более плавного управления
        local lerpFactor = FrameTime() * 5
        -- Если близко к границе - более быстрое обновление для быстрой реакции
        if distanceFromCenter > safeMargin then
            lerpFactor = lerpFactor * 1.5 -- Ускоряем обновление при опасности
        end
        
        if prevPlyDir:Length() > 0 then
            AutoFish.LastPlyDir = LerpVector(lerpFactor, prevPlyDir, newPlyDir)
        else
            AutoFish.LastPlyDir = newPlyDir
        end
        AutoFish.LastPlyDir:Normalize()
        
        -- ВСЕГДА сохраняем данные для визуализации и анализатора
        -- Это критично для работы анализатора!
        -- distanceFromCenter = расстояние от центра (поплавка) до красной стрелки
        AutoFish.LastZoneData = {
            centerPos = centerPos, -- Центр зоны = позиция поплавка (зеленая точка)
            maxZoneRadius = maxZoneRadius, -- Радиус красной зоны (граница)
            safeMargin = safeMargin, -- Радиус зеленой зоны (безопасная зона)
            distanceFromCenter = distanceFromCenter, -- Расстояние от центра до красной стрелки
            bobberPos = bobber:GetPos(), -- Позиция поплавка (центр зоны)
            fishDir = fishDir, -- Направление рыбы (направление красной стрелки)
            plyDir = AutoFish.LastPlyDir, -- Направление движения игрока
            isOutOfBounds = distanceFromCenter > maxZoneRadius, -- Флаг: красная стрелка за границей
            distanceToEdge = maxZoneRadius - distanceFromCenter, -- Расстояние от красной стрелки до края красной зоны
        }
        
        -- ЗАПИСЬ ДЕЙСТВИЙ ИГРОКА (если включена)
        if AutoFish.Recording then
            -- Вычисляем fishToCenterDot для записи
            -- Центр зоны = позиция поплавка, красная стрелка = bobberPos + fishDir * 50
            local arrowPos = bobber:GetPos() + fishDir * 50
            local toCenter = centerPos - arrowPos -- Вектор от красной стрелки к центру (поплавку)
            toCenter.z = 0
            local toCenterNormalized = toCenter:GetNormalized()
            -- fishDir - это направление ОТ поплавка, поэтому инвертируем для правильного dot product
            local fishToCenterDot = fishDir:Dot(toCenterNormalized * -1)
            
            RecordAction(keys, bobber, fishDir, centerPos, distanceFromCenter, fishToCenterDot)
        end
        
        -- Управление клавишами (с учетом witch_fish)
        SmoothKeyControl(keys, fishID)
        
        --[[
        if AutoFish.Settings.debugMode then
            local dist = (bobber:GetPos() + fishDir * 50 - bobber:GetPos()):Length()
            ThrottledDebugPrint("bobber_control", string.format("[AutoFish Perfect] Scale: %.2f | Dist: %.1f | F:%.2f R:%.2f | W:%s S:%s D:%s A:%s", 
                scale, dist, forwardDot, rightDot,
                tostring(keys.forward), tostring(keys.back),
                tostring(keys.right), tostring(keys.left)), 0.2)
        end
        --]]
    end
        
    -- Автоматическое закидывание
    local function AutoCast()
        if not AutoFish.Enabled or not AutoFish.Settings.autoCast then return end
        
        local rod = GetFishingRod()
        if not rod then return end
        
        local bobber = GetBobber()
        
        -- Если поплавка нет, закидываем
        if not IsValid(bobber) then
            local timeSinceLastCast = CurTime() - AutoFish.LastCast
            local timeSinceLastCollect = CurTime() - AutoFish.LastFishCollected
            
            -- Проверяем перезарядку удочки (ждем после забора рыбы)
            if AutoFish.LastFishCollected > 0 and timeSinceLastCollect < AutoFish.RodCooldown then
                -- Удочка еще перезаряжается
                --[[
                if AutoFish.Settings.debugMode then
                    ThrottledDebugPrint("rod_cooldown", string.format("[AutoFish] Ожидание перезарядки удочки: %.1f / %.1f сек", 
                        timeSinceLastCollect, AutoFish.RodCooldown), 2.0)
                end
                --]]
                return
            end
            
            -- ИСПРАВЛЕНО: Добавлена защита от повторного закидывания
            -- Проверяем, что прошло достаточно времени с последнего закидывания
            if timeSinceLastCast >= AutoFish.Settings.castDelay then
                local ply = LocalPlayer()
                if IsValid(ply) then
                    -- Выводим сообщение только если перезарядка еще идет, иначе просто закидываем
                    --[[
                    if AutoFish.LastFishCollected > 0 and timeSinceLastCollect < AutoFish.RodCooldown then
                        ThrottledDebugPrint("cast_cooldown", string.format("[AutoFish Perfect] Закидываю удочку (перезарядка %.1f / %.1f сек)", 
                            timeSinceLastCollect, AutoFish.RodCooldown), 2.0)
                        else
                            ThrottledDebugPrint("cast", "[AutoFish Perfect] Закидываю удочку", 1.0)
                    end
                    --]]
                    ply:ConCommand("+attack")
                    timer.Simple(0.1, function()
                        if IsValid(ply) then
                            ply:ConCommand("-attack")
                        end
                    end)
                end
                AutoFish.LastCast = CurTime()
                
                -- Логируем закидывание
                --[[
                LogEvent("cast", {
                    timeSinceLastCast = timeSinceLastCast,
                })
                --]]
                
                -- Начинаем новую сессию логирования
                if not AutoFish.Logging.sessionStartTime then
                    AutoFish.Logging.sessionStartTime = CurTime()
                end
                
                -- Очищаем историю и состояние подсечки
                AutoFish.History.fishDir = {}
                AutoFish.History.bobberPos = {}
                AutoFish.WaitingForStart = false
                AutoFish.LastHookAttempt = 0
                AutoFish.LastHookScale = nil -- Сбрасываем scale подсечки
                AutoFish.LastBiteReport = 0
                AutoFish.CollectingFish = false
                AutoFish.LastCollectAttempt = 0
                AutoFish.LastBobberScale = nil -- Сбрасываем для правильного определения изменения scale
            end
        end
    end
        
    -- ============================================
    -- СИСТЕМА ОТСЛЕЖИВАНИЯ И УПРАВЛЕНИЯ РЫБАМИ
    -- ============================================
    
    -- Кэш несуществующих сетевых сообщений (чтобы не спамить ошибками)
    AutoFish.InvalidNetMessages = AutoFish.InvalidNetMessages or {}
    AutoFish.InvalidNetMessagesLogged = AutoFish.InvalidNetMessagesLogged or {}
    
    -- Безопасная отправка сетевых сообщений (с обработкой ошибок)
    local function SafeNetSend(messageName)
        -- Проверяем кэш - если сообщение уже известно как несуществующее, не пытаемся отправлять
        if AutoFish.InvalidNetMessages[messageName] then
            return false
        end
        
        local success, err = pcall(function()
            net.Start(messageName)
            net.SendToServer()
        end)
        if not success then
            -- Сохраняем в кэш, чтобы не пытаться снова
            AutoFish.InvalidNetMessages[messageName] = true
            -- Логируем только первый раз
            if not AutoFish.InvalidNetMessagesLogged[messageName] then
                if AutoFish.Settings.debugMode then
                    print(string.format("[AutoFish] Сообщение '%s' не существует на сервере (больше не буду пытаться)", messageName))
                end
                AutoFish.InvalidNetMessagesLogged[messageName] = true
            end
            return false
        end
        return true
    end
    
    -- Создание GUI меню
    local function CreateMenu()
        if IsValid(AutoFish.MenuFrame) then
            AutoFish.MenuFrame:Remove()
        end
        
        local frame = vgui.Create("DFrame")
            frame:SetSize(400, 840)
            frame:Center()
            frame:SetTitle("AutoFish Perfect")
            frame:SetDraggable(true)
            frame:ShowCloseButton(true)
            frame:MakePopup()
            
            frame.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 35, 250))
                draw.RoundedBox(8, 0, 0, w, 30, Color(40, 100, 200, 255))
                draw.RoundedBox(0, 0, 0, w, 2, Color(60, 150, 255, 255))
                draw.RoundedBox(0, 0, h-2, w, 2, Color(60, 150, 255, 255))
                draw.RoundedBox(0, 0, 0, 2, h, Color(60, 150, 255, 255))
                draw.RoundedBox(0, w-2, 0, 2, h, Color(60, 150, 255, 255))
            end
            
            AutoFish.MenuFrame = frame
            
            -- Статус
            local statusLabel = vgui.Create("DLabel", frame)
            statusLabel:SetPos(20, 40)
            statusLabel:SetSize(360, 30)
            statusLabel:SetText("Статус: " .. (AutoFish.Enabled and "ВКЛЮЧЕНО" or "ВЫКЛЮЧЕНО"))
            statusLabel:SetTextColor(Color(255, 255, 255))
            statusLabel:SetFont("DermaDefaultBold")
            
            -- Кнопка включения/выключения
            local toggleBtn = vgui.Create("DButton", frame)
            toggleBtn:SetPos(20, 80)
            toggleBtn:SetSize(360, 40)
            toggleBtn:SetText(AutoFish.Enabled and "ВЫКЛЮЧИТЬ" or "ВКЛЮЧИТЬ")
            toggleBtn:SetTextColor(Color(255, 255, 255))
            toggleBtn.Paint = function(self, w, h)
                local col = AutoFish.Enabled and Color(200, 50, 50) or Color(50, 200, 50)
                draw.RoundedBox(4, 0, 0, w, h, col)
            end
            toggleBtn.DoClick = function()
                AutoFish.Enabled = not AutoFish.Enabled
                statusLabel:SetText("Статус: " .. (AutoFish.Enabled and "ВКЛЮЧЕНО" or "ВЫКЛЮЧЕНО"))
                toggleBtn:SetText(AutoFish.Enabled and "ВЫКЛЮЧИТЬ" or "ВКЛЮЧИТЬ")
                
                if AutoFish.Enabled then
                    AutoFish.DebugDisabledShown = false
                    print("[AutoFish Perfect] Скрипт ВКЛЮЧЕН! Закиньте удочку и ждите поклевку.")
                    print("[AutoFish Perfect] При поклевке вы увидите сообщения в консоли.")
                else
                    local ply = LocalPlayer()
                    if IsValid(ply) then
                        ply:ConCommand("-forward")
                        ply:ConCommand("-back")
                        ply:ConCommand("-moveright")
                        ply:ConCommand("-moveleft")
                    end
                    print("[AutoFish Perfect] Скрипт ВЫКЛЮЧЕН") 
                end
            end
            
            -- Разделитель
            local line = vgui.Create("DPanel", frame)
            line:SetPos(20, 140)
            line:SetSize(360, 2)
            line.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(100, 100, 100))
            end
            
            -- Логирование
            local loggingLabel = vgui.Create("DLabel", frame)
            loggingLabel:SetPos(20, 150)
            loggingLabel:SetSize(360, 20)
            loggingLabel:SetText("ЛОГИРОВАНИЕ")
            loggingLabel:SetTextColor(Color(200, 200, 200))
            loggingLabel:SetFont("DermaDefaultBold")
            
            -- Статистика логов
            local logStatsLabel = vgui.Create("DLabel", frame)
            logStatsLabel:SetPos(20, 175)
            logStatsLabel:SetSize(360, 40)
            logStatsLabel:SetText("")
            logStatsLabel:SetTextColor(Color(200, 200, 200))
            logStatsLabel:SetWrap(true)
            
            local function UpdateLogStats()
                local stats = string.format(
                    "Событий: %d | Сетевых: %d | Поплавок: %d | Управление: %d | Ошибок: %d",
                    #AutoFish.Logging.events,
                    #AutoFish.Logging.networkMessages,
                    #AutoFish.Logging.bobberStates,
                    #AutoFish.Logging.controlActions,
                    #AutoFish.Logging.errors
                )
                logStatsLabel:SetText(stats)
            end
            UpdateLogStats()
            
            -- Кнопка экспорта лога
            local exportBtn = vgui.Create("DButton", frame)
            exportBtn:SetPos(20, 220)
            exportBtn:SetSize(175, 30)
            exportBtn:SetText("Экспорт лога")
            exportBtn:SetTextColor(Color(255, 255, 255))
            exportBtn.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(50, 150, 50))
            end
            exportBtn.DoClick = function()
                if CopyLogToClipboard() then
                    chat.AddText(Color(0, 255, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Лог скопирован в буфер обмена!")
                    print("[AutoFish Perfect] Лог экспортирован и скопирован в буфер обмена")
                    UpdateLogStats()
                else
                    chat.AddText(Color(255, 0, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Ошибка экспорта лога!")
                end
            end
            
            -- Кнопка очистки лога
            local clearBtn = vgui.Create("DButton", frame)
            clearBtn:SetPos(205, 220)
            clearBtn:SetSize(175, 30)
            clearBtn:SetText("Очистить лог")
            clearBtn:SetTextColor(Color(255, 255, 255))
            clearBtn.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(150, 50, 50))
            end
            clearBtn.DoClick = function()
                AutoFish.Logging.events = {}
                AutoFish.Logging.networkMessages = {}
                AutoFish.Logging.bobberStates = {}
                AutoFish.Logging.controlActions = {}
                AutoFish.Logging.errors = {}
                AutoFish.Logging.sessionStartTime = nil
                chat.AddText(Color(255, 200, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Лог очищен")
                UpdateLogStats()
            end
            
            -- Кнопка открытия окна логов
            local openLogsBtn = vgui.Create("DButton", frame)
            openLogsBtn:SetPos(20, 255)
            openLogsBtn:SetSize(360, 35)
            openLogsBtn:SetText("Открыть окно логов в реальном времени")
            openLogsBtn:SetTextColor(Color(255, 255, 255))
            openLogsBtn.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(50, 100, 200))
            end
            openLogsBtn.DoClick = function()
                ToggleLogWindow()
            end
            
            -- Включить/выключить логирование
            local loggingCheck = vgui.Create("DCheckBoxLabel", frame)
            loggingCheck:SetPos(20, 300)
            loggingCheck:SetSize(360, 25)
            loggingCheck:SetText("Включить логирование")
            loggingCheck:SetTextColor(Color(255, 255, 255))
            loggingCheck:SetChecked(AutoFish.Settings.logging)
        loggingCheck.OnChange = function(self, val)
            AutoFish.Settings.logging = val
            AutoFish.SaveSettings() -- Сохраняем настройки
        end
            
            -- Логировать сетевые сообщения
            local networkLogCheck = vgui.Create("DCheckBoxLabel", frame)
            networkLogCheck:SetPos(20, 325)
            networkLogCheck:SetSize(360, 25)
            networkLogCheck:SetText("Логировать сетевые сообщения")
            networkLogCheck:SetTextColor(Color(255, 255, 255))
            networkLogCheck:SetChecked(AutoFish.Settings.logNetworkMessages)
        networkLogCheck.OnChange = function(self, val)
            AutoFish.Settings.logNetworkMessages = val
            AutoFish.SaveSettings() -- Сохраняем настройки
        end
            
            -- Разделитель
            local line2 = vgui.Create("DPanel", frame)
            line2:SetPos(20, 360)
            line2:SetSize(360, 2)
            line2.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(100, 100, 100))
            end
            
            -- Настройки
            local settingsLabel = vgui.Create("DLabel", frame)
            settingsLabel:SetPos(20, 380)
            settingsLabel:SetSize(360, 20)
            settingsLabel:SetText("НАСТРОЙКИ")
            settingsLabel:SetTextColor(Color(200, 200, 200))
            settingsLabel:SetFont("DermaDefaultBold")
            
            -- Автозакидывание
            local autoCastCheck = vgui.Create("DCheckBoxLabel", frame)
            autoCastCheck:SetPos(20, 410)
            autoCastCheck:SetSize(360, 25)
            autoCastCheck:SetText("Автоматическое закидывание")
            autoCastCheck:SetTextColor(Color(255, 255, 255))
            autoCastCheck:SetChecked(AutoFish.Settings.autoCast)
        autoCastCheck.OnChange = function(self, val)
            AutoFish.Settings.autoCast = val
            AutoFish.SaveSettings() -- Сохраняем настройки
        end
            
            -- Автозапуск мини-игры
            local autoStartCheck = vgui.Create("DCheckBoxLabel", frame)
            autoStartCheck:SetPos(20, 435)
            autoStartCheck:SetSize(360, 25)
            autoStartCheck:SetText("Автоматически начинать мини-игру (ЛКМ)")
            autoStartCheck:SetTextColor(Color(255, 255, 255))
            autoStartCheck:SetChecked(AutoFish.Settings.autoStartMinigame)
            autoStartCheck.OnChange = function(self, val)
                AutoFish.Settings.autoStartMinigame = val
            end
            
            -- Режим записи действий
            local recordingCheck = vgui.Create("DCheckBoxLabel", frame)
            recordingCheck:SetPos(20, 460)
            recordingCheck:SetSize(360, 25)
            recordingCheck:SetText("Режим записи действий (управление вручную)")
            recordingCheck:SetTextColor(Color(255, 255, 255))
            recordingCheck:SetChecked(AutoFish.Settings.recordingMode)
            recordingCheck.OnChange = function(self, val)
                AutoFish.Settings.recordingMode = val
                if val then
                    chat.AddText(Color(255, 0, 0), "[AutoFish] ", Color(255, 255, 255), "Режим записи ВКЛЮЧЕН - управляйте WASD вручную!")
                    else
                        chat.AddText(Color(0, 255, 0), "[AutoFish] ", Color(255, 255, 255), "Автоматическое управление восстановлено")
                end
            end
            
            -- Кнопка экспорта записей
            local exportRecBtn = vgui.Create("DButton", frame)
            exportRecBtn:SetPos(20, 487)
            exportRecBtn:SetSize(360, 30)
            exportRecBtn:SetText(string.format("Экспорт записей (%d сессий)", #AutoFish.RecordingSessions))
            exportRecBtn:SetTextColor(Color(255, 255, 255))
            exportRecBtn.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(150, 50, 150))
            end
            exportRecBtn.DoClick = function()
                print("============================================")
                print("[AutoFish Perfect] ЭКСПОРТ ЗАПИСЕЙ (из меню)")
                print("============================================")
                
                if #AutoFish.RecordingSessions == 0 then
                    chat.AddText(Color(255, 200, 0), "[AutoFish] ", Color(255, 255, 255), "Нет записей для экспорта")
                    print("[AutoFish Recording] Записи отсутствуют")
                    print("Включите режим записи и поймайте рыбу вручную")
                else
                    print(string.format("Найдено записей: %d", #AutoFish.RecordingSessions))
                    local success = CopyRecordingsToClipboard()
                    
                    if success then
                        chat.AddText(Color(0, 255, 0), "[AutoFish] ", Color(255, 255, 255), 
                            string.format("Экспортировано %d записей!", #AutoFish.RecordingSessions))
                    else
                        chat.AddText(Color(255, 200, 0), "[AutoFish] ", Color(255, 255, 255), 
                            "Данные в консоли - скопируйте вручную")
                    end
                end
                print("============================================")
            end
            
            -- Разделитель
            local line4 = vgui.Create("DPanel", frame)
            line4:SetPos(20, 522)
            line4:SetSize(360, 2)
            line4.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(60, 150, 255, 100))
            end
            
            -- Разделитель
            local line5 = vgui.Create("DPanel", frame)
            line5:SetPos(20, 560)
            line5:SetSize(360, 2)
            line5.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(60, 150, 255, 100))
            end
            
            -- Задержка закидывания
            local delayLabel = vgui.Create("DLabel", frame)
            delayLabel:SetPos(20, 568)
            delayLabel:SetSize(200, 20)
            delayLabel:SetText("Задержка закидывания (сек):")
            delayLabel:SetTextColor(Color(255, 255, 255))
            
            local delayEntry = vgui.Create("DTextEntry", frame)
            delayEntry:SetPos(220, 566)
            delayEntry:SetSize(160, 25)
            delayEntry:SetValue(tostring(AutoFish.Settings.castDelay))
            delayEntry.OnEnter = function(self)
                local val = tonumber(self:GetValue())
                if val and val > 0 then
                    AutoFish.Settings.castDelay = val
                    AutoFish.SaveSettings() -- Сохраняем настройки
                end
            end
            delayEntry.OnChange = function(self)
                local val = tonumber(self:GetValue())
                if val and val > 0 then
                    AutoFish.Settings.castDelay = val
                    AutoFish.SaveSettings() -- Сохраняем настройки при изменении
                end
            end
            
            -- Перезарядка удочки
            local cooldownLabel = vgui.Create("DLabel", frame)
            cooldownLabel:SetPos(20, 596)
            cooldownLabel:SetSize(200, 20)
            cooldownLabel:SetText("Перезарядка удочки (сек):")
            cooldownLabel:SetTextColor(Color(255, 255, 255))
            
            local cooldownEntry = vgui.Create("DTextEntry", frame)
            cooldownEntry:SetPos(220, 594)
            cooldownEntry:SetSize(160, 25)
            cooldownEntry:SetValue(tostring(AutoFish.RodCooldown))
            cooldownEntry.OnEnter = function(self)
                local val = tonumber(self:GetValue())
                if val and val >= 0 then
                    AutoFish.RodCooldown = val
                    AutoFish.SaveSettings() -- Сохраняем настройки
                end
            end
            cooldownEntry.OnChange = function(self)
                local val = tonumber(self:GetValue())
                if val and val >= 0 then
                    AutoFish.RodCooldown = val
                    AutoFish.SaveSettings() -- Сохраняем настройки при изменении
                end
            end
            
            -- Предсказание движения
            local predictionCheck = vgui.Create("DCheckBoxLabel", frame)
            predictionCheck:SetPos(20, 626)
            predictionCheck:SetSize(360, 25)
            predictionCheck:SetText("Предсказание движения рыбы")
            predictionCheck:SetTextColor(Color(255, 255, 255))
            predictionCheck:SetChecked(AutoFish.Settings.prediction)
        predictionCheck.OnChange = function(self, val)
            AutoFish.Settings.prediction = val
            AutoFish.SaveSettings() -- Сохраняем настройки
        end
            
            -- Отступ зоны
            local marginLabel = vgui.Create("DLabel", frame)
            marginLabel:SetPos(20, 656)
            marginLabel:SetSize(200, 20)
            marginLabel:SetText("Отступ зоны (%):")
            marginLabel:SetTextColor(Color(255, 255, 255))
            
            local marginSlider = vgui.Create("DNumSlider", frame)
            marginSlider:SetPos(20, 676)
            marginSlider:SetSize(360, 25)
            marginSlider:SetMin(10)
            marginSlider:SetMax(100)
            marginSlider:SetValue(AutoFish.Settings.zoneMargin * 100)
            marginSlider:SetDecimals(0)
            marginSlider.OnValueChanged = function(self, val)
                AutoFish.Settings.zoneMargin = val / 100
                AutoFish.SaveSettings() -- Сохраняем настройки
            end
            
            -- Режим отладки
            local debugCheck = vgui.Create("DCheckBoxLabel", frame)
            debugCheck:SetPos(20, 711)
            debugCheck:SetSize(360, 25)
            debugCheck:SetText("Режим отладки")
            debugCheck:SetTextColor(Color(255, 255, 255))
            debugCheck:SetChecked(AutoFish.Settings.debugMode)
        debugCheck.OnChange = function(self, val)
            AutoFish.Settings.debugMode = val
            AutoFish.SaveSettings() -- Сохраняем настройки
        end
            
            -- Anti Screen Grab
            local antiGrabCheck = vgui.Create("DCheckBoxLabel", frame)
            antiGrabCheck:SetPos(20, 736)
            antiGrabCheck:SetSize(360, 25)
            antiGrabCheck:SetText("Anti Screen Grab")
            antiGrabCheck:SetTextColor(Color(255, 255, 255))
            antiGrabCheck:SetChecked(AutoFish.Settings.antiScreenGrab)
        antiGrabCheck.OnChange = function(self, val)
            AutoFish.Settings.antiScreenGrab = val
            AutoFish.SaveSettings() -- Сохраняем настройки
        end
            
            -- Разделитель
            local line3 = vgui.Create("DPanel", frame)
            line3:SetPos(20, 771)
            line3:SetSize(360, 2)
            line3.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(100, 100, 100))
            end
            
            -- Информация
            local infoLabel = vgui.Create("DLabel", frame)
            infoLabel:SetPos(20, 781)
            infoLabel:SetSize(360, 50)
            infoLabel:SetText("END - меню | F12/SYSRQ - скриншот\nautofish_perfect_show_logs - окно логов\nautofish_perfect_export_log - экспорт\nautofish_perfect_clear_log - очистить")
            infoLabel:SetTextColor(Color(200, 200, 200))
            infoLabel:SetWrap(true)
            
            -- Сохраняем имя таймера для этого меню
            local timerName = "AutoFish_UpdateStatus_" .. tostring(frame)
            AutoFish.CurrentTimerName = timerName
            
            -- Обновление статуса
            timer.Create(timerName, 0.5, 0, function()
                if IsValid(statusLabel) and IsValid(toggleBtn) and IsValid(frame) then
                    statusLabel:SetText("Статус: " .. (AutoFish.Enabled and "ВКЛЮЧЕНО" or "ВЫКЛЮЧЕНО"))
                    toggleBtn:SetText(AutoFish.Enabled and "ВЫКЛЮЧИТЬ" or "ВКЛЮЧИТЬ")
                else
                    -- Если элементы удалены, удаляем таймер
                    timer.Remove(timerName)
                end
            end)
            
            frame.OnClose = function()
                AutoFish.MenuOpen = false
                timer.Remove(timerName)
                AutoFish.CurrentTimerName = nil
            end
            
            AutoFish.MenuOpen = true
    end
    
    -- Переключение меню
    local function ToggleMenu()
        if AutoFish.MenuOpen then
            if IsValid(AutoFish.MenuFrame) then
                AutoFish.MenuFrame:Remove()
            end
            AutoFish.MenuOpen = false
        else
            CreateMenu()
        end
    end
    
    -- Создание окна логов
    local function CreateLogWindow()
        if IsValid(AutoFish.LogWindowFrame) then
            AutoFish.LogWindowFrame:Remove()
        end
        
        local frame = vgui.Create("DFrame")
        frame:SetSize(800, 600)
        frame:Center()
        frame:SetTitle("AutoFish Perfect - Логи рыбалки")
        frame:SetDraggable(true)
        frame:ShowCloseButton(true)
        frame:MakePopup()
        
        frame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 35, 250))
            draw.RoundedBox(8, 0, 0, w, 30, Color(40, 100, 200, 255))
            draw.RoundedBox(0, 0, 0, w, 2, Color(60, 150, 255, 255))
            draw.RoundedBox(0, 0, h-2, w, 2, Color(60, 150, 255, 255))
            draw.RoundedBox(0, 0, 0, 2, h, Color(60, 150, 255, 255))
            draw.RoundedBox(0, w-2, 0, 2, h, Color(60, 150, 255, 255))
        end
        
        AutoFish.LogWindowFrame = frame
        
        -- Текстовое поле с прокруткой
        local logList = vgui.Create("DListView", frame)
        logList:SetPos(10, 40)
        logList:SetSize(780, 500)
        logList:SetMultiLine(false)
        logList:AddColumn("Логи")
        
        -- Функция добавления строки лога
        local function AddLogLine(text, color)
            local line = logList:AddLine(text)
            if line then
                line.Paint = function(self, w, h)
                    if self:IsSelected() then
                        draw.RoundedBox(0, 0, 0, w, h, Color(60, 100, 150, 100))
                    end
                end
                -- Применяем цвет к тексту
                if color then
                    line:SetTextColor(color)
                end
            end
            
            -- Автопрокрутка вниз
            timer.Simple(0.01, function()
                if IsValid(logList) then
                    logList:GetCanvas():SetPos(0, -logList:GetCanvas():GetTall())
                end
            end)
        end
        
        -- Сохраняем функцию для обновления извне
        AutoFish.AddLogLineToGUI = AddLogLine
        
        -- Загружаем существующие логи (последние 500)
        local allLogs = {}
        for _, event in ipairs(AutoFish.Logging.events) do
            table.insert(allLogs, {type = event.type, time = event.time, data = event.data, category = "event"})
        end
        for _, msg in ipairs(AutoFish.Logging.networkMessages) do
            table.insert(allLogs, {type = "network", time = msg.time, data = {name = msg.name}, category = "network"})
        end
        for _, action in ipairs(AutoFish.Logging.controlActions) do
            table.insert(allLogs, {type = "movement", time = action.time, data = action.details, category = "control"})
        end
        for _, err in ipairs(AutoFish.Logging.errors) do
            table.insert(allLogs, {type = "error", time = err.time, data = {message = err.message}, category = "error"})
        end
        
        -- Сортируем по времени
        table.sort(allLogs, function(a, b) return (a.time or 0) < (b.time or 0) end)
        
        -- Берем последние 500 записей
        local startIdx = math.max(1, #allLogs - 499)
        for i = startIdx, #allLogs do
            local log = allLogs[i]
            local text, color = FormatLogForGUI(log)
            AddLogLine(text, color)
        end
        
        -- Статистика
        local statsLabel = vgui.Create("DLabel", frame)
        statsLabel:SetPos(10, 545)
        statsLabel:SetSize(780, 20)
        statsLabel:SetText(string.format("Всего событий: %d | Сетевых: %d | Управление: %d | Ошибок: %d", 
            #AutoFish.Logging.events,
            #AutoFish.Logging.networkMessages,
            #AutoFish.Logging.controlActions,
            #AutoFish.Logging.errors))
        statsLabel:SetTextColor(Color(200, 200, 200))
        
        -- Кнопки
        local clearBtn = vgui.Create("DButton", frame)
        clearBtn:SetPos(10, 570)
        clearBtn:SetSize(180, 25)
        clearBtn:SetText("Очистить логи")
        clearBtn:SetTextColor(Color(255, 255, 255))
        clearBtn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(150, 50, 50))
        end
        clearBtn.DoClick = function()
            logList:Clear()
            AutoFish.Logging.events = {}
            AutoFish.Logging.networkMessages = {}
            AutoFish.Logging.controlActions = {}
            AutoFish.Logging.errors = {}
            statsLabel:SetText("Всего событий: 0 | Сетевых: 0 | Управление: 0 | Ошибок: 0")
            chat.AddText(Color(255, 200, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Логи очищены")
        end
        
        local exportBtn = vgui.Create("DButton", frame)
        exportBtn:SetPos(200, 570)
        exportBtn:SetSize(180, 25)
        exportBtn:SetText("Экспорт в буфер")
        exportBtn:SetTextColor(Color(255, 255, 255))
        exportBtn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(50, 150, 50))
        end
        exportBtn.DoClick = function()
            if CopyLogToClipboard() then
                chat.AddText(Color(0, 255, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Логи скопированы в буфер обмена!")
            else
                chat.AddText(Color(255, 0, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Ошибка экспорта!")
            end
        end
        
        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetPos(390, 570)
        closeBtn:SetSize(180, 25)
        closeBtn:SetText("Закрыть")
        closeBtn:SetTextColor(Color(255, 255, 255))
        closeBtn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(100, 100, 100))
        end
        closeBtn.DoClick = function()
            frame:Remove()
        end
        
        -- Обновление статистики каждые 0.5 сек
        local timerName = "AutoFish_LogWindow_Update_" .. tostring(frame)
        timer.Create(timerName, 0.5, 0, function()
            if IsValid(statsLabel) and IsValid(frame) then
                statsLabel:SetText(string.format("Всего событий: %d | Сетевых: %d | Управление: %d | Ошибок: %d", 
                    #AutoFish.Logging.events,
                    #AutoFish.Logging.networkMessages,
                    #AutoFish.Logging.controlActions,
                    #AutoFish.Logging.errors))
            else
                timer.Remove(timerName)
            end
        end)
        
        frame.OnClose = function()
            AutoFish.LogWindowOpen = false
            AutoFish.AddLogLineToGUI = nil
            timer.Remove(timerName)
        end
        
        AutoFish.LogWindowOpen = true
    end
    
    -- Переключение окна логов
    local function ToggleLogWindow()
        if AutoFish.LogWindowOpen then
            if IsValid(AutoFish.LogWindowFrame) then
                AutoFish.LogWindowFrame:Remove()
            end
            AutoFish.LogWindowOpen = false
        else
            CreateLogWindow()
        end
    end
    
    -- Хук для МАКСИМАЛЬНО быстрой реакции на скриншот (вызывается каждый кадр)
    hook.Add("HUDPaint", "AutoFish_Perfect_AntiGrab", function()
        if AutoFish.Settings.antiScreenGrab then
            AntiScreenGrab()
        end
    end)
    
    -- Перехват чата для отслеживания пойманных рыб
    hook.Add("OnPlayerChat", "AutoFish_Perfect_CatchTracker", function(ply, text, teamChat, dead)
        if not IsValid(ply) or ply ~= LocalPlayer() then return end
        
        -- Ищем сообщения о поимке рыбы: "Вы поймали" или "Рыболовля | Вы поймали"
        local lowerText = string.lower(text)
        if string.find(lowerText, "вы поймали") or string.find(lowerText, "поймал") then
            -- Пытаемся извлечь название рыбы из сообщения
            -- Формат обычно: "Вы поймали "Линь" ($455)" или "Рыболовля | Вы поймали "Треска" ($516)"
            local fishName = string.match(text, '"([^"]+)"')
            if fishName and AutoFish.Settings.debugMode then
                -- Конвертируем название в fishID (обычно это lowercase с подчеркиванием)
                local fishID = string.lower(string.gsub(fishName, " ", "_"))
                print(string.format("[AutoFish] Отслежена пойманная рыба из чата: %s (ID: %s)", fishName, fishID))
            end
        end
    end)
    
    -- Хук для перехвата клавиш напрямую (самый быстрый метод)
    hook.Add("PlayerBindPress", "AutoFish_Perfect_ScreenshotBlock", function(ply, bind, pressed)
        if not AutoFish.Settings.antiScreenGrab then return end
        if not pressed then return end
        
        -- Перехватываем команды скриншота
        if bind == "screenshot" or bind == "jpeg" then
            -- МОМЕНТАЛЬНО устанавливаем флаг для всех визуальных элементов
            AutoFish.IsScreenshotActive = true
            
            -- МОМЕНТАЛЬНО скрываем всё GUI
            if IsValid(AutoFish.MenuFrame) then
                AutoFish.MenuFrame:SetAlpha(0)
                AutoFish.MenuFrame:SetVisible(false)
            end
            if IsValid(AutoFish.LogWindowFrame) then
                AutoFish.LogWindowFrame:SetAlpha(0)
                AutoFish.LogWindowFrame:SetVisible(false)
            end
            
            -- Восстанавливаем через 0.3 сек
            timer.Simple(0.3, function()
                AutoFish.IsScreenshotActive = false -- Сбрасываем флаг
                
                if IsValid(AutoFish.MenuFrame) and AutoFish.MenuOpen then
                    AutoFish.MenuFrame:SetAlpha(255)
                    AutoFish.MenuFrame:SetVisible(true)
                end
                if IsValid(AutoFish.LogWindowFrame) and AutoFish.LogWindowOpen then
                    AutoFish.LogWindowFrame:SetAlpha(255)
                    AutoFish.LogWindowFrame:SetVisible(true)
                end
            end)
            
            if AutoFish.Settings.debugMode then
                print("[AutoFish Anti-Grab] Команда скриншота перехвачена! Все визуальные элементы скрыты")
            end
        end
    end)
    
    -- Основной цикл
    hook.Add("Think", "AutoFish_Perfect_Think", function()
        -- Проверка клавиши END
        local currentTime = CurTime()
        if currentTime - AutoFish.EndKeyLastCheck > 0.2 then
            AutoFish.EndKeyLastCheck = currentTime
            
            if input.IsKeyDown(KEY_END) then
                if not AutoFish.EndKeyPressed then
                    AutoFish.EndKeyPressed = true
                    ToggleMenu()
                end
            else
                AutoFish.EndKeyPressed = false
            end
        end
        
        -- Anti Screen Grab (дублирование для надежности)
        AntiScreenGrab()
        
        -- Проверка и закрытие окон мини-игры (работает даже если скрипт выключен) - ЗАКОММЕНТИРОВАНО
        -- CheckAndCloseMinigameWindows()
        
        if not AutoFish.Enabled then return end
        
        -- КРИТИЧНО: Проверяем поклевку БЕЗ задержки для немедленной реакции
        local bobber = GetBobber()
        if IsValid(bobber) then
            local scale = math.Round(bobber:GetModelScale(), 2)
            local rawScale = bobber:GetModelScale()
            -- Если поклевка (scale 1.02) - проверяем немедленно, без задержки
            if scale == 1.02 or (rawScale >= 1.015 and rawScale < 1.025) then
                -- Вызываем проверку подсечки немедленно
                AutoControlBobber()
            end
        end
        
        -- Обычное обновление с интервалом
        if currentTime - AutoFish.LastUpdate < AutoFish.UpdateInterval then return end
        AutoFish.LastUpdate = currentTime
        
        AutoCast()
        AutoControlBobber()
    end)
    
    -- Визуализация зоны в 3D
    hook.Add("PostDrawTranslucentRenderables", "AutoFish_Perfect_ZoneVisualization", function()
        -- Anti Screen Grab: не рисуем во время скриншота
        if AutoFish.IsScreenshotActiveFunc and AutoFish.IsScreenshotActiveFunc() then return end
        
        if not AutoFish.Enabled then return end
        
        local bobber = GetBobber()
        if not IsValid(bobber) then return end
        
        local scale = math.Round(bobber:GetModelScale(), 2)
        if scale != 1.03 then return end -- Только во время мини-игры
        
        local zoneData = AutoFish.LastZoneData
        if not zoneData then return end
        
        local centerPos = zoneData.centerPos
        local maxZoneRadius = zoneData.maxZoneRadius
        local safeMargin = zoneData.safeMargin
        local distanceFromCenter = zoneData.distanceFromCenter
        local bobberPos = zoneData.bobberPos
        local plyDir = zoneData.plyDir or Vector(0, 0, 0)
        
        -- Получаем up вектор для ориентации круга
        local upVec = bobber:GetUp() * 10
        
        -- Центр зоны = позиция поплавка (зеленая точка)
        -- Не нужно пересчитывать, centerPos уже = bobberPos
        
        -- Цвет границы зоны (красный если выходит за границу)
        local zoneColor = distanceFromCenter > maxZoneRadius and Color(255, 0, 0, 200) or Color(0, 255, 0, 200)
        local safeZoneColor = Color(255, 255, 0, 150) -- Желтый для безопасной зоны
        
        cam.IgnoreZ(true)
        
        -- Рисуем границу зоны (полный радиус 250)
        local ang = Angle()
        cam.Start3D2D(centerPos + upVec, ang, 0.1)
        -- Внешний круг (граница зоны)
        draw.NoTexture()
        surface.SetDrawColor(zoneColor)
        for i = 0, 360, 5 do
            local rad = math.rad(i)
            local x1 = math.cos(rad) * maxZoneRadius
            local y1 = math.sin(rad) * maxZoneRadius
            local x2 = math.cos(math.rad(i + 5)) * maxZoneRadius
            local y2 = math.sin(math.rad(i + 5)) * maxZoneRadius
            surface.DrawLine(x1, y1, x2, y2)
        end
        -- Безопасная зона (отступ)
        surface.SetDrawColor(safeZoneColor)
        for i = 0, 360, 5 do
            local rad = math.rad(i)
            local x1 = math.cos(rad) * safeMargin
            local y1 = math.sin(rad) * safeMargin
            local x2 = math.cos(math.rad(i + 5)) * safeMargin
            local y2 = math.sin(math.rad(i + 5)) * safeMargin
            surface.DrawLine(x1, y1, x2, y2)
        end
        cam.End3D2D()
        
        -- Рисуем линию от поплавка к центру зоны
        render.DrawLine(bobberPos + upVec, centerPos + upVec, Color(255, 255, 255, 100), true)
        
        cam.IgnoreZ(false)
    end)
    
    -- Визуальная отладка
    hook.Add("HUDPaint", "AutoFish_Perfect_HUD", function()
        -- Anti Screen Grab: не рисуем во время скриншота
        if AutoFish.IsScreenshotActiveFunc and AutoFish.IsScreenshotActiveFunc() then return end
        
        if not AutoFish.Enabled or not AutoFish.Settings.debugMode then return end
        
        local bobber = GetBobber()
        if not IsValid(bobber) then return end
        
        local scale = math.Round(bobber:GetModelScale(), 2)
        -- Показываем HUD только во время мини-игры (scale == 1.03)
        if scale != 1.03 then return end
        
        local fishDir = bobber:GetFishDir()
        local targetDir, centerPos, maxZoneRadius, safeMargin, distanceFromCenter = CalculateOptimalDirection(bobber, fishDir, AutoFish.Settings.zoneSize)
        local predicted = PredictFishDirection()
        
        local zoneData = AutoFish.LastZoneData
        
        local y = 10
        draw.SimpleText("AutoFish Perfect: АКТИВНО", "DermaDefault", 10, y, Color(0, 255, 0), TEXT_ALIGN_LEFT)
        y = y + 20
        draw.SimpleText(string.format("Scale: %.2f (1.03=игра, 1.02=ожидание, 1.01=поймано)", scale), "DermaDefault", 10, y, Color(255, 255, 255), TEXT_ALIGN_LEFT)
        y = y + 20
        draw.SimpleText(string.format("FishDir: (%.2f, %.2f)", fishDir.x, fishDir.y), "DermaDefault", 10, y, Color(255, 255, 255), TEXT_ALIGN_LEFT)
        y = y + 20
        if predicted then
            draw.SimpleText(string.format("Predicted: (%.2f, %.2f)", predicted.x, predicted.y), "DermaDefault", 10, y, Color(255, 200, 0), TEXT_ALIGN_LEFT)
            y = y + 20
        end
        draw.SimpleText(string.format("TargetDir: (%.2f, %.2f)", targetDir.x, targetDir.y), "DermaDefault", 10, y, Color(0, 255, 255), TEXT_ALIGN_LEFT)
        y = y + 20
        
        if zoneData then
            local distColor = zoneData.distanceFromCenter > maxZoneRadius and Color(255, 0, 0) or Color(0, 255, 0)
            draw.SimpleText(string.format("Dist from center: %.1f / %.1f (max: %.1f)", 
                zoneData.distanceFromCenter, safeMargin, maxZoneRadius), 
                "DermaDefault", 10, y, distColor, TEXT_ALIGN_LEFT)
            y = y + 20
            if zoneData.distanceFromCenter > maxZoneRadius then
                draw.SimpleText("ВЫХОД ЗА ГРАНИЦУ ЗОНЫ!", "DermaDefault", 10, y, Color(255, 0, 0), TEXT_ALIGN_LEFT)
            end
        end
    end)
    
    -- Перехват сетевых сообщений для логирования
    if AutoFish.Settings.logNetworkMessages then
        -- Перехватываем основные сетевые сообщения рыбалки
        if net.Receive then
            -- Перехватываем известные сообщения
            local fishingNetMessages = {
                "SlashModules.Fishing.Projectile",
                "SlashModules.Fishing.SyncStocks",
                "SlashModules.Fishing.SyncDelivery",
                "SlashModules.Fishing.GetBoats",
                "SlashModules.Inventory.MoveSlot",
                "SlashModules.Inventory.RecycleTrash",
                "SlashModules.Fishing.StockSell",
            }
            
            for _, msgName in ipairs(fishingNetMessages) do
                if util.NetworkStringToID(msgName) then
                    net.Receive(msgName, function(len)
                        --[[
                        LogNetworkMessage(msgName, {
                            length = len,
                            timestamp = CurTime(),
                        })
                        --]]
                    end)
                end
            end
        end
    end
    
    -- Команды консоли
    concommand.Add("autofish_perfect_toggle", function()
        ToggleMenu()
    end)
    
    -- Команда для открытия окна логов
    concommand.Add("autofish_perfect_show_logs", function()
        if not AutoFish.LogWindowOpen then
            CreateLogWindow()
            chat.AddText(Color(0, 255, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Окно логов открыто")
        else
            ToggleLogWindow()
        end
    end)
    
    -- Команда для экспорта лога
    concommand.Add("autofish_perfect_export_log", function()
        if CopyLogToClipboard() then
            chat.AddText(Color(0, 255, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Лог скопирован в буфер обмена!")
            print("[AutoFish Perfect] Лог экспортирован и скопирован в буфер обмена")
            print(string.format("[AutoFish Perfect] Событий: %d | Сетевых сообщений: %d | Состояний поплавка: %d", 
                #AutoFish.Logging.events, 
                #AutoFish.Logging.networkMessages, 
                #AutoFish.Logging.bobberStates))
        else
            chat.AddText(Color(255, 0, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Ошибка экспорта лога!")
        end
    end)
    
    -- Команда для очистки лога
    concommand.Add("autofish_perfect_clear_log", function()
        AutoFish.Logging.events = {}
        AutoFish.Logging.networkMessages = {}
        AutoFish.Logging.bobberStates = {}
        AutoFish.Logging.controlActions = {}
        AutoFish.Logging.errors = {}
        AutoFish.Logging.sessionStartTime = nil
        chat.AddText(Color(255, 200, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Лог очищен")
        print("[AutoFish Perfect] Лог очищен")
    end)
    
    concommand.Add("autofish_perfect_enable", function()
        AutoFish.Enabled = true
        AutoFish.DebugDisabledShown = false
        chat.AddText(Color(0, 255, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "ВКЛЮЧЕНО")
        print("[AutoFish Perfect] Скрипт ВКЛЮЧЕН! Закиньте удочку и ждите поклевку.")
        print("[AutoFish Perfect] При поклевке вы увидите сообщения в консоли.")
    end)
    
    concommand.Add("autofish_perfect_disable", function()
        AutoFish.Enabled = false
        local ply = LocalPlayer()
        if IsValid(ply) then
            ply:ConCommand("-forward")
            ply:ConCommand("-back")
            ply:ConCommand("-moveright")
            ply:ConCommand("-moveleft")
        end
        chat.AddText(Color(255, 0, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "ВЫКЛЮЧЕНО")
        print("[AutoFish Perfect] Скрипт ВЫКЛЮЧЕН")
    end)
    
    -- Команда для проверки состояния поплавка
    concommand.Add("autofish_perfect_check", function()
        local bobber = GetBobber()
        if IsValid(bobber) then
            local scale = bobber:GetModelScale()
            local roundedScale = math.Round(scale, 2)
            local fishID = bobber:GetFishID()
            chat.AddText(Color(100, 255, 255), "[AutoFish Perfect] ", Color(255, 255, 255), 
                string.format("Scale: %.3f (округлено: %.2f) | FishID: %s | LastScale: %s", 
                scale, roundedScale, fishID or "нет", tostring(AutoFish.LastBobberScale)))
            print(string.format("[AutoFish Perfect] Scale: %.3f (%.2f) | FishID: %s | WaitingForStart: %s | LastHookAttempt: %.2f", 
                scale, roundedScale, fishID or "нет", tostring(AutoFish.WaitingForStart), AutoFish.LastHookAttempt))
        else
            chat.AddText(Color(255, 200, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Поплавок не найден")
        end
    end)
    
    -- Команда для принудительной подсечки
    concommand.Add("autofish_perfect_hook", function()
        local bobber = GetBobber()
        if IsValid(bobber) then
            local ply = LocalPlayer()
            if IsValid(ply) then
                ply:ConCommand("+attack")
                timer.Simple(0.1, function()
                    if IsValid(ply) then
                        ply:ConCommand("-attack")
                    end
                end)
                chat.AddText(Color(0, 255, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Принудительная подсечка выполнена")
                print("[AutoFish Perfect] Принудительная подсечка выполнена")
            end
        else
            chat.AddText(Color(255, 200, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Поплавок не найден")
        end
    end)
    
    -- Команда для экспорта записей
    concommand.Add("autofish_perfect_export_recordings", function()
        print("============================================")
        print("[AutoFish Perfect] ЭКСПОРТ ЗАПИСЕЙ ДЕЙСТВИЙ")
        print("============================================")
        
        if #AutoFish.RecordingSessions == 0 then
            chat.AddText(Color(255, 200, 0), "[AutoFish] ", Color(255, 255, 255), "Нет записей для экспорта")
            print("[AutoFish Recording] Записи отсутствуют")
            print("Включите режим записи в меню (END) и поймайте рыбу вручную")
            print("============================================")
        else
            print(string.format("Найдено записей: %d", #AutoFish.RecordingSessions))
            
            -- Пробуем экспортировать
            local success = CopyRecordingsToClipboard()
            
            if success then
                chat.AddText(Color(0, 255, 0), "[AutoFish] ", Color(255, 255, 255), 
                    string.format("Экспортировано %d записей в буфер обмена!", #AutoFish.RecordingSessions))
            else
                chat.AddText(Color(255, 200, 0), "[AutoFish] ", Color(255, 255, 255), 
                    "Данные выведены в консоль - скопируйте вручную")
            end
            print("============================================")
        end
    end)
    
    -- Команда для сохранения записей в файл
    concommand.Add("autofish_perfect_save_recordings", function()
        print("============================================")
        print("[AutoFish Perfect] СОХРАНЕНИЕ ЗАПИСЕЙ В ФАЙЛ")
        print("============================================")
        
        if #AutoFish.RecordingSessions == 0 then
            chat.AddText(Color(255, 200, 0), "[AutoFish] ", Color(255, 255, 255), "Нет записей для сохранения")
            print("[AutoFish Recording] Записи отсутствуют")
            print("============================================")
            return
        end
        
        local json = ExportRecordings()
        if not json or json == "" then
            chat.AddText(Color(255, 0, 0), "[AutoFish] ", Color(255, 255, 255), "Ошибка формирования данных")
            print("[AutoFish Recording] Ошибка формирования JSON")
            print("============================================")
            return
        end
        
        -- Формируем имя файла с датой и временем
        local filename = string.format("autofish_recordings_%s.json", os.date("%Y%m%d_%H%M%S"))
        local filepath = "data/" .. filename
        
        -- Пробуем сохранить в файл
        local success = pcall(function()
            file.Write(filepath, json)
        end)
        
        if success then
            chat.AddText(Color(0, 255, 0), "[AutoFish] ", Color(255, 255, 255), 
                string.format("Записи сохранены в файл: %s", filename))
            print(string.format("[AutoFish Recording] Файл сохранен: garrysmod/data/%s", filename))
            print(string.format("[AutoFish Recording] Размер: %.2f KB", string.len(json) / 1024))
            print(string.format("[AutoFish Recording] Сессий: %d", #AutoFish.RecordingSessions))
        else
            chat.AddText(Color(255, 0, 0), "[AutoFish] ", Color(255, 255, 255), "Ошибка сохранения файла")
            print("[AutoFish Recording] Не удалось сохранить файл")
            print("[AutoFish Recording] Попробуйте команду: autofish_perfect_export_recordings")
        end
        print("============================================")
    end)
    
    -- Команда для выгрузки скрипта
    concommand.Add("autofish_perfect_unload", function()
        UnloadScript()
        chat.AddText(Color(255, 200, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Скрипт выгружен")
    end)
    
    -- Сохраняем функцию выгрузки для повторной инжекции (глобально)
    AutoFish.Unload = UnloadScript
    _AutoFishPerfect.Unload = UnloadScript
    
    -- Информация при загрузке
    chat.AddText(Color(0, 255, 0), "[AutoFish Perfect] ", Color(255, 255, 255), "Загружен! Нажмите END для меню")
    
    print("============================================")
    print("AUTOFISH PERFECT ЗАГРУЖЕН")
    print("Основано на реальном дампе сервера")
    print("Версия 4.4.1")
    print("============================================")
    print("Клавиши:")
    print("  END - открыть/закрыть меню")
    print("Команды:")
    print("  autofish_perfect_toggle - меню")
    print("  autofish_perfect_show_logs - окно логов в реальном времени")
    print("  autofish_perfect_enable - включить")
    print("  autofish_perfect_disable - выключить")
    print("  autofish_perfect_export_log - экспорт лога в буфер обмена")
    print("  autofish_perfect_export_recordings - экспорт записей в буфер")
    print("  autofish_perfect_save_recordings - сохранить записи в файл")
    print("  autofish_perfect_clear_log - очистить лог")
    print("  autofish_perfect_check - проверить состояние поплавка")
    print("  autofish_perfect_hook - принудительная подсечка")
    print("  autofish_perfect_unload - выгрузить скрипт")
    print("============================================")
    print("РАНЕЕ v4.3.1:")
    print("  Улучшенный Anti Screen Grab")
    print("  Исправлен экспорт записей")
    print("============================================")
    print("РАНЕЕ v4.3.0:")
    print("  Режим записи действий игрока")
    print("============================================")
    print("РАНЕЕ v4.2.0:")
    print("  • Перезарядка удочки + умная логика управления")
    print("============================================")
    print("При повторной инжекции скрипт автоматически выгрузится")
    print("============================================")
end

