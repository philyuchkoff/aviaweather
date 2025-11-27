#!/bin/bash

# ADSB Tracker - отслеживание самолетов вокруг аэропорта
# Совместимая версия для старых bash/sh

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции для работы с координатами аэропортов
get_airport_coords() {
    local icao=$1
    case $icao in
        "UUWW") echo "55.5960,37.2670" ;;
        "UUEE") echo "55.9722,37.4146" ;;
        "UUDD") echo "55.4083,37.9063" ;;
        "UHPP") echo "53.1679,158.4516" ;;
        "UHWW") echo "43.3983,132.1480" ;;
        "URSS") echo "43.4499,39.9566" ;;
        "USSS") echo "56.7431,60.8027" ;;
        "KJFK") echo "40.6399,-73.7787" ;;
        "EGLL") echo "51.4700,-0.4543" ;;
        "LFPG") echo "49.0097,2.5479" ;;
        "EDDF") echo "50.0333,8.5706" ;;
        *) echo "" ;;
    esac
}

to_uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

fetch_adsb_advanced() {
    local icao=$(to_uppercase "$1")
    local radius=${2:-50}  # радиус в км, по умолчанию 50км
    
    echo -e "${CYAN}🛫 Самолеты в радиусе ${radius}км от $icao${NC}"
    echo ""
    
    local coords=$(get_airport_coords "$icao")
    if [ -z "$coords" ]; then
        echo -e "${RED}❌ Координаты аэропорта $icao не найдены${NC}"
        return 1
    fi
    
    local lat=$(echo "$coords" | cut -d',' -f1)
    local lon=$(echo "$coords" | cut -d',' -f2)
    
    # Конвертируем км в градусы (примерно)
    local delta=$(echo "scale=4; $radius / 111" | bc)
    local lamin=$(echo "$lat - $delta" | bc)
    local lomin=$(echo "$lon - $delta" | bc) 
    local lamax=$(echo "$lat + $delta" | bc)
    local lomax=$(echo "$lon + $delta" | bc)
    
    echo -e "${YELLOW}📍 Центр: $lat°, $lon° | 📏 Радиус: ${radius}км${NC}"
    echo ""
    
    echo -e "${CYAN}📡 Запрос данных с OpenSky Network...${NC}"
    local response=$(curl -s --connect-timeout 10 \
        "https://opensky-network.org/api/states/all?lamin=$lamin&lomin=$lomin&lamax=$lamax&lomax=$lomax")
    
    if [ $? -ne 0 ] || [ -z "$response" ] || [ "$response" = "null" ]; then
        echo -e "${RED}❌ Ошибка получения данных${NC}"
        return 1
    fi
    
    # Проверяем наличие jq для парсинга JSON
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠️ jq не установлен, используем базовый парсинг${NC}"
        basic_json_parse "$response" "$coords"
        return 0
    fi
    
    local aircraft_count=$(echo "$response" | jq '.states | length' 2>/dev/null)
    
    if [ -z "$aircraft_count" ] || [ "$aircraft_count" = "null" ] || [ "$aircraft_count" -eq 0 ]; then
        echo -e "${YELLOW}✈️ Самолеты не обнаружены${NC}"
        return 0
    fi
    
    echo -e "${GREEN}📊 Найдено самолетов: $aircraft_count${NC}"
    echo ""
    
    # Парсим и форматируем вывод
    echo "$response" | jq -r '.states[] | select(.[1] != null) | [
        .[1],          # callsign
        .[2],          # country
        .[0],          # icao24
        .[6],          # longitude
        .[5],          # latitude  
        .[7],          # altitude
        .[9],          # velocity
        .[10],         # heading
        .[13]          # squawk
    ] | @csv' 2>/dev/null | \
    while IFS=, read -r callsign country icao24 lon lat altitude velocity heading squawk; do
        # Очистка кавычек и пробелов
        callsign=$(echo "$callsign" | sed 's/"//g' | sed 's/^ *//; s/ *$//')
        country=$(echo "$country" | sed 's/"//g')
        icao24=$(echo "$icao24" | sed 's/"//g')
        lon=$(echo "$lon" | sed 's/"//g')
        lat=$(echo "$lat" | sed 's/"//g')
        
        # Рассчет расстояния до аэропорта
        local airport_lat=$(echo "$coords" | cut -d',' -f1)
        local airport_lon=$(echo "$coords" | cut -d',' -f2)
        local distance=$(calculate_distance "$lat" "$lon" "$airport_lat" "$airport_lon")
        
        # Форматирование высоты
        if [ "$altitude" != "null" ] && [ -n "$altitude" ]; then
            altitude_feet=$(echo "scale=0; $altitude * 3.28084" | bc 2>/dev/null || echo "N/A")
            altitude_display="${altitude}m (${altitude_feet}ft)"
        else
            altitude_display="N/A"
        fi
        
        # Форматирование скорости
        if [ "$velocity" != "null" ] && [ -n "$velocity" ]; then
            velocity_kmh=$(echo "scale=0; $velocity * 3.6" | bc 2>/dev/null || echo "N/A")
            velocity_display="${velocity}m/s (${velocity_kmh}km/h)"
        else
            velocity_display="N/A"
        fi
        
        echo -e "${CYAN}🛩️  ${callsign:-"N/A"} | 🇺🇳 ${country:-"N/A"}${NC}"
        echo -e "   🏷️  ICAO24: ${icao24}"
        echo -e "   📍 Координаты: ${lat}°, ${lon}°"
        echo -e "   📏 Расстояние: ${distance}км"
        echo -e "   🏔️  Высота: ${altitude_display}"
        echo -e "   💨 Скорость: ${velocity_display}"
        echo -e "   🧭 Курс: ${heading}°"
        echo -e "   🔢 Squawk: ${squawk:-"N/A"}"
        echo ""
    done
}

# Базовый парсинг JSON без jq (на случай если jq не установлен)
basic_json_parse() {
    local response="$1"
    local coords="$2"
    local airport_lat=$(echo "$coords" | cut -d',' -f1)
    local airport_lon=$(echo "$coords" | cut -d',' -f2)
    
    echo -e "${YELLOW}⚠️ Используется базовый парсинг (установите jq для лучшего отображения)${NC}"
    echo ""
    
    # Простой подсчет самолетов по наличию "callsign"
    local aircraft_count=$(echo "$response" | grep -o '"callsign"' | wc -l)
    echo -e "${GREEN}📊 Найдено самолетов: $aircraft_count${NC}"
    echo ""
    
    # Извлекаем основные данные с помощью grep/sed/awk
    echo "$response" | grep -o '"callsign":"[^"]*"' | sed 's/"callsign":"//g' | sed 's/"//g' | \
    while read -r callsign; do
        if [ -n "$callsign" ]; then
            echo -e "${BLUE}🛩️  $callsign${NC}"
            echo -e "   📍 Самолет обнаружен"
            echo ""
        fi
    done
    
    if [ "$aircraft_count" -eq 0 ]; then
        echo -e "${YELLOW}✈️ Детальная информация недоступна без jq${NC}"
    fi
}

# Функция расчета расстояния (упрощенная)
calculate_distance() {
    local lat1=$1 lon1=$2 lat2=$3 lon2=$4
    
    # Проверяем наличие bc
    if ! command -v bc &> /dev/null; then
        echo "N/A"
        return 0
    fi
    
    # Простой расчет по разнице координат
    local lat_diff=$(echo "scale=4; $lat1 - $lat2" | bc | tr -d '-')
    local lon_diff=$(echo "scale=4; $lon1 - $lon2" | bc | tr -d '-')
    
    local distance=$(echo "scale=2; sqrt($lat_diff * $lat_diff + $lon_diff * $lon_diff) * 111" | bc 2>/dev/null)
    
    if [ -n "$distance" ]; then
        echo "$distance"
    else
        echo "N/A"
    fi
}

# Поиск конкретного самолета по позывному
find_aircraft() {
    local callsign=$(to_uppercase "$1")
    
    echo -e "${CYAN}🔍 Поиск самолета: $callsign${NC}"
    
    local response=$(curl -s "https://opensky-network.org/api/states/all")
    
    if [ "$response" = "null" ] || [ -z "$response" ]; then
        echo "Ошибка получения данных"
        return 1
    fi
    
    if echo "$response" | grep -q "$callsign"; then
        echo "Самолет найден в данных"
        # Здесь можно добавить более детальный парсинг
    else
        echo "Самолет не найден"
    fi
}

# Мониторинг в реальном времени
monitor_airport() {
    local icao=$(to_uppercase "$1")
    local interval=${2:-10}
    
    echo -e "${CYAN}📡 Мониторинг $icao (обновление каждые ${interval}с)${NC}"
    echo "Нажмите Ctrl+C для остановки"
    echo ""
    
    while true; do
        clear
        echo -e "${YELLOW}🕐 $(date)${NC}"
        echo ""
        fetch_adsb_advanced "$icao"
        sleep "$interval"
    done
}

# Показать список аэропортов
show_airports() {
    echo -e "${CYAN}Доступные аэропорты:${NC}"
    echo "• UUWW - Внуково, Москва"
    echo "• UUEE - Шереметьево, Москва"
    echo "• UUDD - Домодедово, Москва" 
    echo "• UHPP - Елизово, Петропавловск-Камчатский"
    echo "• UHWW - Владивосток"
    echo "• URSS - Сочи"
    echo "• USSS - Екатеринбург"
    echo "• KJFK - Кеннеди, Нью-Йорк"
    echo "• EGLL - Хитроу, Лондон"
    echo "• LFPG - Шарль-де-Голль, Париж"
    echo "• EDDF - Франкфурт-на-Майне"
}

show_airport_menu() {
    echo -e "${GREEN}=== ADSB Tracker ===${NC}"
    echo "1. Показать самолеты вокруг аэропорта"
    echo "2. Мониторинг в реальном времени" 
    echo "3. Поиск по позывному"
    echo "4. Список аэропортов"
    echo "0. Выход"
}

check_dependencies() {
    local missing=()
    
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    if ! command -v bc &> /dev/null; then
        missing+=("bc")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}❌ Установите необходимые пакеты:${NC}"
        echo "sudo apt install ${missing[*]}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠️ Для лучшего отображения установите jq:${NC}"
        echo "sudo apt install jq"
    fi
}

main() {
    # Проверка зависимостей
    check_dependencies
    
    while true; do
        show_airport_menu
        printf "Выберите опцию: "
        read choice
        
        case $choice in
            1)
                printf "Введите код ICAO: "
                read icao
                printf "Радиус (км, по умолчанию 50): "
                read radius
                fetch_adsb_advanced "$icao" "$radius"
                ;;
            2)
                printf "Введите код ICAO: "
                read icao
                printf "Интервал обновления (сек, по умолчанию 10): "
                read interval
                monitor_airport "$icao" "$interval"
                ;;
            3)
                printf "Введите позывной: "
                read callsign
                find_aircraft "$callsign"
                ;;
            4)
                show_airports
                ;;
            0)
                echo "До свидания!"
                exit 0
                ;;
            *)
                echo "Неверный выбор"
                ;;
        esac
        
        echo ""
        printf "Нажмите Enter для продолжения..."
        read
    done
}

# Запуск
main "$@"