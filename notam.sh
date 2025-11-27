#!/bin/bash

# NOTAM Fetcher - получение NOTAM для аэропортов
# Использование: ./notam.sh UHPP

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# База данных аэропортов
get_airport_info() {
    case $1 in
        "UUEE") echo "Шереметьево, Москва, Россия" ;;
        "UUWW") echo "Внуково, Москва, Россия" ;;
        "UUDD") echo "Домодедово, Москва, Россия" ;;
        "UHPP") echo "Елизово, Петропавловск-Камчатский, Россия" ;;
        "UHWW") echo "Владивосток, Россия" ;;
        "URSS") echo "Сочи, Россия" ;;
        "USSS") echo "Кольцово, Екатеринбург, Россия" ;;
        "UAAA") echo "Алматы, Казахстан" ;;
        "UATT") echo "Астана, Казахстан" ;;
        "ZBAA") echo "Пекин Столичный, Китай" ;;
        "RJAA") echo "Нарита, Токио, Япония" ;;
        "KJFK") echo "Кеннеди, Нью-Йорк, США" ;;
        "KLAX") echo "Лос-Анджелес, США" ;;
        "EGLL") echo "Хитроу, Лондон, Великобритания" ;;
        "LFPG") echo "Шарль-де-Голль, Париж, Франция" ;;
        "EDDF") echo "Франкфурт-на-Майне, Германия" ;;
        *) echo "Информация отсутствует" ;;
    esac
}

# Функция для проверки валидности кода ICAO
is_valid_icao() {
    local icao=$1
    [[ ${#icao} -eq 4 ]] && [[ "$icao" =~ ^[A-Z]{4}$ ]]
}

# Функция для получения NOTAM из FAA (США)
fetch_notam_faa() {
    local icao=$1
    echo -e "${CYAN}🛫 Получение NOTAM из FAA (США)...${NC}" >&2
    
    local notam=$(curl -s --connect-timeout 10 \
        "https://notams.aim.faa.gov/notamSearch/nsApp.html#/search/icao/$icao" 2>/dev/null | \
        grep -oP '(?<=<div class="notam-text">)[^<]+' | head -10)
    
    if [[ -n "$notam" ]]; then
        echo "$notam"
    else
        echo ""
    fi
}

# Функция для получения NOTAM из Eurocontrol (Европа)
fetch_notam_eurocontrol() {
    local icao=$1
    echo -e "${CYAN}🌍 Получение NOTAM из Eurocontrol...${NC}" >&2
    
    local notam=$(curl -s --connect-timeout 10 \
        "https://www.eurocontrol.int/notams/airport/$icao" 2>/dev/null | \
        grep -A 5 "notam-item" | sed -n '2p' | sed 's/^[ \t]*//')
    
    if [[ -n "$notam" ]]; then
        echo "$notam"
    else
        echo ""
    fi
}

# Функция для получения NOTAM из российских источников
fetch_notam_russia() {
    local icao=$1
    echo -e "${CYAN}🇷🇺 Попытка получения NOTAM из российских источников...${NC}" >&2
    
    # Попробуем несколько источников
    local notam=""
    
    # Источник 1: aviationweather.gov (международный)
    notam=$(curl -s --connect-timeout 10 \
        "https://aviationweather.gov/api/data/notam?ids=$icao&format=raw" 2>/dev/null)
    
    if [[ -z "$notam" || "$notam" == *"No NOTAM"* ]]; then
        # Источник 2: сервис NOTAM API
        notam=$(curl -s --connect-timeout 10 \
            "https://api.aviationapi.com/v1/notams/apt?apt=$icao" 2>/dev/null | \
            jq -r '.[] | .Message' 2>/dev/null | head -5)
    fi
    
    if [[ -n "$notam" ]]; then
        echo "$notam"
    else
        echo ""
    fi
}

# Функция для парсинга и форматирования NOTAM
parse_notam() {
    local notam_text=$1
    local icao=$2
    
    if [[ -z "$notam_text" ]]; then
        echo -e "${YELLOW}❌ NOTAM для аэропорта $icao не найдены${NC}"
        return 1
    fi
    
    echo -e "${CYAN}=== NOTAM ДЛЯ $icao ===${NC}"
    echo ""
    
    # Разбиваем NOTAM на отдельные сообщения
    IFS=$'\n' read -ra notams <<< "$notam_text"
    
    local counter=1
    for notam in "${notams[@]}"; do
        if [[ -n "$notam" && ${#notam} -gt 10 ]]; then
            echo -e "${GREEN}📋 NOTAM #$counter:${NC}"
            echo -e "${WHITE}$notam${NC}"
            echo ""
            ((counter++))
        fi
    done
    
    if [[ $counter -eq 1 ]]; then
        echo -e "${YELLOW}⚠️  Активных NOTAM не найдено${NC}"
    fi
}

# Функция для получения NOTAM из нескольких источников
fetch_notam_comprehensive() {
    local icao=$1
    local all_notams=""
    
    echo -e "${CYAN}🔍 Поиск NOTAM для $icao из различных источников...${NC}"
    echo ""
    
    # Пробуем разные источники в зависимости от региона
    case ${icao:0:1} in
        "U")  # Россия и СНГ
            all_notams=$(fetch_notam_russia "$icao")
            ;;
        "E")  # Европа
            all_notams=$(fetch_notam_eurocontrol "$icao")
            ;;
        "K")  # США
            all_notams=$(fetch_notam_faa "$icao")
            ;;
        *)    # Остальные - пробуем все
            all_notams=$(fetch_notam_russia "$icao")
            if [[ -z "$all_notams" ]]; then
                all_notams=$(fetch_notam_eurocontrol "$icao")
            fi
            if [[ -z "$all_notams" ]]; then
                all_notams=$(fetch_notam_faa "$icao")
            fi
            ;;
    esac
    
    echo "$all_notams"
}

# Функция для показа примера NOTAM (если реальные данные недоступны)
show_sample_notam() {
    local icao=$1
    local airport_info=$(get_airport_info "$icao")
    
    echo -e "${CYAN}=== NOTAM ДЛЯ $icao ===${NC}"
    echo -e "${GREEN}🏢 Аэропорт: $airport_info${NC}"
    echo -e "${CYAN}🕐 Время запроса: $(date)${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Внимание: Реальные NOTAM временно недоступны${NC}"
    echo -e "${YELLOW}   Показываем пример формата NOTAM:${NC}"
    echo ""
    
    echo -e "${GREEN}📋 NOTAM #1:${NC}"
    echo -e "${WHITE}A $icao RWY 25L/07R CLSD DUE TO CONSTRUCTION WORK${NC}"
    echo -e "${WHITE}FROM: 261200Z TO: 271200Z${NC}"
    echo ""
    
    echo -e "${GREEN}📋 NOTAM #2:${NC}"
    echo -e "${WHITE}B $icao TWR FREQ 118.7 TEMPORARY U/S${NC}"
    echo -e "${WHITE}USE 121.5 FOR EMERGENCY ONLY${NC}"
    echo -e "${WHITE}FROM: 261000Z TO: 261800Z${NC}"
    echo ""
    
    echo -e "${GREEN}📋 NOTAM #3:${NC}"
    echo -e "${WHITE}C $icao ILS CAT I U/S${NC}"
    echo -e "${WHITE}MAINTENANCE IN PROGRESS${NC}"
    echo -e "${WHITE}FROM: 260800Z TO: 262000Z${NC}"
    echo ""
    
    echo -e "${CYAN}💡 Для получения реальных NOTAM обратитесь к официальным источникам:${NC}"
    echo -e "${WHITE}• FAA (США): https://notams.aim.faa.gov${NC}"
    echo -e "${WHITE}• Eurocontrol (Европа): https://www.eurocontrol.int${NC}"
    echo -e "${WHITE}• Российские NOTAM: через официальные каналы Аэронавигации${NC}"
}

# Главная функция
main() {
    # Проверяем наличие curl
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}❌ Ошибка: curl не установлен${NC}"
        echo "Установите curl:"
        echo "  macOS: brew install curl"
        echo "  Linux: sudo apt install curl"
        exit 1
    fi
    
    # Проверяем наличие jq для парсинга JSON
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠️  Предупреждение: jq не установлен${NC}"
        echo "Некоторые источники NOTAM могут не работать"
        echo "Установите jq:"
        echo "  macOS: brew install jq"
        echo "  Linux: sudo apt install jq"
        echo ""
    fi
    
    if [[ $# -eq 0 ]]; then
        echo "Использование: $0 [код ICAO]"
        echo "Пример: $0 UHPP"
        echo ""
        echo "Популярные коды:"
        echo "  UUEE - Шереметьево, Москва"
        echo "  UUWW - Внуково, Москва" 
        echo "  UHWW - Владивосток"
        echo "  UHPP - Елизово, Петропавловск-Камчатский"
        echo "  URSS - Сочи"
        echo "  KJFK - Кеннеди, Нью-Йорк"
        echo "  EGLL - Хитроу, Лондон"
        exit 1
    fi
    
    local icao=$1
    
    # Проверяем валидность кода ICAO
    if ! is_valid_icao "$icao"; then
        echo -e "${YELLOW}❌ Неверный код ICAO: $icao${NC}"
        echo "Код ICAO должен состоять из 4 латинских букв"
        exit 1
    fi
    
    # Информация об аэропорте
    local airport_info=$(get_airport_info "$icao")
    echo -e "${GREEN}🏢 Аэропорт: $airport_info${NC}"
    echo -e "${CYAN}🕐 Время запроса: $(date)${NC}"
    echo ""
    
    # Получаем NOTAM
    local notam_data=$(fetch_notam_comprehensive "$icao")
    
    if [[ -n "$notam_data" ]]; then
        parse_notam "$notam_data" "$icao"
    else
        show_sample_notam "$icao"
    fi
    
    echo -e "${CYAN}===============================${NC}"
    echo -e "${YELLOW}⚠️  Важно: NOTAM могут меняться${NC}"
    echo -e "${YELLOW}   Всегда проверяйте актуальные NOTAM перед полетом${NC}"
}

# Запуск скрипта
main "$@"
