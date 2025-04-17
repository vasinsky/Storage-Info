local Config = require("config")

local paths = Config.PATHS
local excludedPaths = Config.EXCLUDED_PATHS

local currentPathIndex = 1  -- индекс текущего значения в таблице paths
local path = paths[currentPathIndex]  -- текущее значение path
local directories = {}  -- таблица для хранения директорий
local showDiagram = true  -- флаг для отображения диаграммы и таблицы

fontSize = 35
largeFont = love.graphics.newFont(fontSize)  -- создаем шрифт размером 35 пикселей для всех строк
local margin = 3 / 0.352778  -- внешний отступ в мм (преобразован в пиксели)
local padding = 3  -- внутренний отступ в пикселях
local scrollOffset = 0  -- смещение для скроллинга второй таблицы
local rowHeight = 50  -- высота строки таблицы
local smallFontSize = 28
local smallFont = love.graphics.newFont(smallFontSize)  -- создаем шрифт размером 26 пикселей для текста

-- Функция для логирования
local function log(message)
    print(message)
    local file = io.open("applog.txt", "a")
    if file then
        file:write(message .. "\n")
        file:close()
    else
        print("Failed to open log file for writing.")
    end
end

-- Функция для очистки лог файла при запуске
local function clearLogFile()
    local file = io.open("applog.txt", "w")
    if file then
        file:close()
    else
        print("Failed to open log file for clearing.")
    end
end

-- Функция для получения информации о дисковом пространстве
local function getDiskSpace(path)
    local total, used, free
    local command = "df -h " .. path .. " 2>&1"
    -- Используем команду df для получения информации о дисковом пространстве
    local handle = io.popen(command)
    if not handle then
        log("Error opening df handle for path: " .. path)
        return nil, nil, nil
    end

    local dfOutput = handle:read("*a")
    handle:close()
    log("df command: " .. command)
    log("df output for path " .. path .. ":\n" .. dfOutput)

    for line in dfOutput:gmatch("[^\r\n]+") do
        -- Пропускаем строку, если она содержит слово "Available"
        if not line:find("Available") then
            -- Заменяем все последовательные пробелы на ":::::"
            local modifiedLine = line:gsub("%s+", ":::::")
            log("Modified line: " .. modifiedLine)
            -- Разделяем строку по ":::::"
            local parts = {}
            for part in modifiedLine:gmatch("[^:::::]+") do
                table.insert(parts, part)
            end
            -- Проверяем, что у нас достаточно частей, чтобы получить значения
            if #parts >= 6 then
                total = parts[2]
                used = parts[3]
                free = parts[4]
                log("Disk space information: Total: " .. total .. ", Used: " .. used .. ", Free: " .. free)
            else
                log("Error parsing disk space information: " .. line)
            end
            break
        end
    end
    -- Логируем значения даже если они nil
    log("Final disk space values - Total: " .. tostring(total) .. ", Used: " .. tostring(used) .. ", Free: " .. tostring(free))
    return total, used, free
end

-- Функция для обновления информации о дисковом пространстве
local function updateDiskSpace()
    totalSpace, usedSpace, freeSpace = getDiskSpace(path)
    log("totalSpace: " .. tostring(totalSpace))
    log("usedSpace: " .. tostring(usedSpace))
    log("freeSpace: " .. tostring(freeSpace))
end

-- Функция для проверки доступности пути
local function isPathAvailable(newPath)
    local command = "df -h 2>&1"
    local handle = io.popen(command)
    if not handle then
        log("Error opening df handle")
        return false
    end
    local output = handle:read("*a")
    handle:close()
    log("df command: " .. command)
    log("df output:\n" .. output)
    -- Проверяем доступность нового пути
    for line in output:gmatch("[^\r\n]+") do
        if not line:find("Available") then
            return true
        end
    end
    return false
end

-- Функция для получения списка директорий и их размеров
local function getDirectories(path)
    local dirs = {}
    local command = "du -hd 1 " .. path .. " 2>&1"
    log("Running command: " .. command)
    local duHandle = io.popen(command)
    if duHandle then
        local duOutput = duHandle:read("*a")
        duHandle:close()
        log("du output for path " .. path .. ":\n" .. duOutput)
        for line in duOutput:gmatch("[^\r\n]+") do
            local size, name = line:match("(%S+)%s+(.+)")
            log("Parsed line: size=" .. tostring(size) .. ", name=" .. tostring(name))
            if size and name then
                local baseName = name:match("([^/]+)$")
                if baseName and baseName:sub(1, 1) ~= "." then
                    table.insert(dirs, {name = baseName, size = size})
                    log("Directory size: Name: " .. baseName .. ", Size: " .. size)
                end
            end
        end
    else
        local errHandle = io.popen(command)
        local errOutput = errHandle:read("*a")
        errHandle:close()
        log("Error opening du handle for path: " .. path .. ". Error: " .. errOutput)
    end
    return dirs
end

function love.load()
    clearLogFile()
    updateDiskSpace()
end

function love.keypressed(key)
    if key == "right" then
        log("Right arrow key pressed")
        local newPathIndex = (currentPathIndex % #paths) + 1
        local newPath = paths[newPathIndex]
        while not isPathAvailable(newPath) and newPathIndex ~= currentPathIndex do
            newPathIndex = (newPathIndex % #paths) + 1
            newPath = paths[newPathIndex]
        end
        if isPathAvailable(newPath) then
            currentPathIndex = newPathIndex
            path = newPath
            updateDiskSpace()
        else
            log("No available paths found")
        end
    elseif key == "left" then
        log("Left arrow key pressed")
        local newPathIndex = (currentPathIndex - 2 + #paths) % #paths + 1
        local newPath = paths[newPathIndex]
        while not isPathAvailable(newPath) and newPathIndex ~= currentPathIndex do
            newPathIndex = (newPathIndex - 2 + #paths) % #paths + 1
            newPath = paths[newPathIndex]
        end
        if isPathAvailable(newPath) then
            currentPathIndex = newPathIndex
            path = newPath
            updateDiskSpace()
        else
            log("No available paths found")
        end
    elseif key == "return" then
        log("Return key pressed")
        -- Проверяем, доступен ли просмотр второй таблицы
        if excludedPaths[path] then
            log("Viewing directory sizes is not available for path: " .. path)
        else
            directories = getDirectories(path)
            showDiagram = not showDiagram
            scrollOffset = 0  -- сбрасываем смещение при переключении таблиц
        end
    elseif key == "escape" then
        log("Escape key pressed")
        love.event.quit()
    elseif key == "up" and not showDiagram then
        scrollOffset = scrollOffset + rowHeight
        log("Scroll up")
    elseif key == "down" and not showDiagram then
        scrollOffset = scrollOffset - rowHeight
        log("Scroll down")
    end
end

-- Функция для рисования пунктирных линий
local function drawDashedLine(x1, y1, x2, y2, dashLength, gapLength)
    local dx = x2 - x1
    local dy = y2 - y1
    local dashGapLength = dashLength + gapLength
    local distance = math.sqrt(dx * dx + dy * dy)
    local dashCount = math.floor(distance / dashGapLength)
    local dashX = dx / distance * dashLength
    local dashY = dy / distance * dashLength
    local gapX = dx / distance * gapLength
    local gapY = dy / distance * gapLength

    for i = 0, dashCount - 1 do
        local startX = x1 + (dashX + gapX) * i
        local startY = y1 + (dashY + gapY) * i
        love.graphics.line(startX, startY, startX + dashX, startY + dashY)
    end
end

function love.draw()
    love.graphics.clear(46/255, 56/255, 66/255)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local centerX, centerY = screenWidth / 2 + 160, screenHeight / 2
    local radius = 200
    local cellPadding = 2 / 0.352778

    love.graphics.setFont(largeFont)

    if showDiagram then

        if totalSpace and usedSpace and freeSpace and totalSpace ~= path then
            local usedProportion = tonumber(usedSpace:match("(%d+%.?%d*)")) / tonumber(totalSpace:match("(%d+%.?%d*)"))
            local freeProportion = tonumber(freeSpace:match("(%d+%.?%d*)")) / tonumber(totalSpace:match("(%d+%.?%d*)"))

            love.graphics.setColor(243/255, 1/255, 2/255)
            love.graphics.arc("fill", centerX, centerY, radius, 0, usedProportion * 2 * math.pi)
            love.graphics.setColor(144/255, 209/255, 72/255)
            love.graphics.arc("fill", centerX, centerY, radius, usedProportion * 2 * math.pi, 2 * math.pi)

            -- Окантовка для диаграммы
            love.graphics.setColor(46/255, 56/255, 66/255)
            love.graphics.setLineWidth(15)
            love.graphics.arc("line", centerX, centerY, radius, 0, usedProportion * 2 * math.pi)
            love.graphics.arc("line", centerX, centerY, radius, usedProportion * 2 * math.pi, 2 * math.pi)

            local col2Width = 200
            local values = {path, totalSpace, usedSpace, freeSpace}
            for _, value in ipairs(values) do
                col2Width = math.max(col2Width, largeFont:getWidth(value) + 2 * cellPadding)
            end

            local labels = {"Path:", "Total:", "Used:", "Free:"}
            local col1Width = 100
            for _, label in ipairs(labels) do
                col1Width = math.max(col1Width, largeFont:getWidth(label) + 2 * cellPadding)
            end

            local tableX, tableY = margin, margin

            love.graphics.setFont(largeFont)
            for i = 1, #labels do
                --love.graphics.setColor(1, 1, 1)
                love.graphics.setColor(218/255, 242/255, 250/255)
                local labelX = tableX + padding
                local labelY = tableY + (i - 1) * rowHeight + padding
                love.graphics.setLineWidth(1)
                drawDashedLine(tableX, tableY + (i - 1) * rowHeight, tableX + col1Width, tableY + (i - 1) * rowHeight, 1, 5) -- верхняя граница первой ячейки
                drawDashedLine(tableX, tableY + i * rowHeight, tableX + col1Width, tableY + i * rowHeight, 1, 5) -- нижняя граница первой ячейки
                drawDashedLine(tableX, tableY + (i - 1) * rowHeight, tableX, tableY + i * rowHeight, 1, 5) -- левая граница первой ячейки
                drawDashedLine(tableX + col1Width, tableY + (i - 1) * rowHeight, tableX + col1Width, tableY + i * rowHeight, 1, 5) -- правая граница первой ячейки
                love.graphics.printf(labels[i], labelX, labelY + (rowHeight - fontSize) / 2, col1Width - 2 * padding, "left")

                drawDashedLine(tableX + col1Width, tableY + (i - 1) * rowHeight, tableX + col1Width + col2Width, tableY + (i - 1) * rowHeight, 1, 5) -- верхняя граница второй ячейки
                drawDashedLine(tableX + col1Width, tableY + i * rowHeight, tableX + col1Width + col2Width, tableY + i * rowHeight, 1, 5) -- нижняя граница второй ячейки
                drawDashedLine(tableX + col1Width, tableY + (i - 1) * rowHeight, tableX + col1Width, tableY + i * rowHeight, 1, 5) -- левая граница второй ячейки
                drawDashedLine(tableX + col1Width + col2Width, tableY + (i - 1) * rowHeight, tableX + col1Width + col2Width, tableY + i * rowHeight, 1, 5) -- правая граница второй ячейки
                local valueX = tableX + col1Width + padding
                local valueY = tableY + (i - 1) * rowHeight + padding
                love.graphics.printf(values[i], valueX, valueY + (rowHeight - fontSize) / 2, col2Width - 2 * padding, "center")
            end

            if not excludedPaths[path] then
                love.graphics.setFont(smallFont)
                love.graphics.setColor(1, 1, 1)
                love.graphics.print("Press A for details or left/right to switch", margin, screenHeight - smallFontSize - margin - 20)
            end
        else
            love.graphics.setFont(smallFont)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Error getting disk space information: " .. path, margin, margin)
        end
    else
        love.graphics.setFont(smallFont)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Press A to return", 0, margin + scrollOffset, screenWidth, "center")
        
        local dirTableX, dirTableY = margin, margin + scrollOffset + smallFontSize + 20

        local col1Width = 300  -- увеличиваем ширину первого столбца
        local col2Width = screenWidth - col1Width - 2 * margin  -- второй столбец занимает всю оставшуюся ширину экрана

        for i, dir in ipairs(directories) do
            love.graphics.setColor(218/255, 242/255, 250/255)
            local dirRowY = dirTableY + (i - 1) * rowHeight
            love.graphics.setLineWidth(1)
            drawDashedLine(dirTableX, dirRowY, dirTableX + col1Width, dirRowY, 1, 5) -- верхняя граница первой ячейки
            drawDashedLine(dirTableX, dirRowY + rowHeight, dirTableX + col1Width, dirRowY + rowHeight, 1, 5) -- нижняя граница первой ячейки
            drawDashedLine(dirTableX, dirRowY, dirTableX, dirRowY + rowHeight, 1, 5) -- левая граница первой ячейки
            drawDashedLine(dirTableX + col1Width, dirRowY, dirTableX + col1Width, dirRowY + rowHeight, 1, 5) -- правая граница первой ячейки
            love.graphics.printf(dir.size, dirTableX + cellPadding, dirRowY + (rowHeight - fontSize) / 2, col1Width - 2 * cellPadding, "center")

            drawDashedLine(dirTableX + col1Width, dirRowY, dirTableX + col1Width + col2Width, dirRowY, 1, 5) -- верхняя граница второй ячейки
            drawDashedLine(dirTableX + col1Width, dirRowY + rowHeight, dirTableX + col1Width + col2Width, dirRowY + rowHeight, 1, 5) -- нижняя граница второй ячейки
            drawDashedLine(dirTableX + col1Width, dirRowY, dirTableX + col1Width, dirRowY + rowHeight, 1, 5) -- левая граница второй ячейки
            drawDashedLine(dirTableX + col1Width + col2Width, dirRowY, dirTableX + col1Width + col2Width, dirRowY + rowHeight, 1, 5) -- правая граница второй ячейки
            local valueX = dirTableX + col1Width + cellPadding
            local valueY = dirRowY + (rowHeight - fontSize) / 2
            love.graphics.printf(dir.name, valueX, valueY, col2Width - 2 * cellPadding, "left")
        end

    end
end