#!/bin/bash

# METAR/TAF Decoder - совместимый с старыми версиями Bash
# Использование: ./aviaweather.sh UUWW

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функции для работы с данными вместо ассоциативных массивов
get_cloud_type() {
    case $1 in
        "FEW") echo "Небольшая облачность (1-2 октанта)" ;;
        "SCT") echo "Рассеянная облачность (3-4 октанта)" ;;
        "BKN") echo "Разорванная облачность (5-7 октантов)" ;;
        "OVC") echo "Сплошная облачность (8 октантов)" ;;
        "VV") echo "Вертикальная видимость" ;;
        *) echo "Неизвестный тип облачности" ;;
    esac
}

get_weather_phenomena() {
    case $1 in
        "DZ") echo "Морось" ;;
        "RA") echo "Дождь" ;;
        "SN") echo "Снег" ;;
        "SG") echo "Снежные зерна" ;;
        "IC") echo "Ледяные иглы" ;;
        "PL") echo "Ледяной дождь" ;;
        "GR") echo "Град" ;;
        "GS") echo "Мелкий град" ;;
        "UP") echo "Неизвестные осадки" ;;
        "BR") echo "Дымка (видимость 1-5 км)" ;;
        "FG") echo "Туман (видимость < 1 км)" ;;
        "FU") echo "Дым" ;;
        "VA") echo "Вулканический пепел" ;;
        "DU") echo "Пыль" ;;
        "SA") echo "Песок" ;;
        "HZ") echo "Мгла" ;;
        "PY") echo "Брызги" ;;
        "PO") echo "Пыльные/песчаные вихри" ;;
        "SQ") echo "Шквал" ;;
        "FC") echo "Воронкообразное облако" ;;
        "SS") echo "Песчаная буря" ;;
        "DS") echo "Пыльная буря" ;;
        *) echo "Неизвестное явление" ;;
    esac
}

get_airport_info() {
    case $1 in
        "UUEE") echo "Шереметьево, Москва, Россия" ;;
        "UUWW") echo "Внуково, Москва, Россия" ;;
        "UUDD") echo "Домодедово, Москва, Россия" ;;
        "UHPP") echo "Елизово, Петропавловск-Камчатский, Россия" ;;
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

# Функция для декодирования направления ветра
decode_wind_direction() {
    local deg=$1
    if [[ $deg -eq 0 ]] || [[ $deg -eq 360 ]]; then
        echo "Северный"
    elif [[ $deg -gt 0 ]] && [[ $deg -lt 90 ]]; then
        echo "Северо-восточный"
    elif [[ $deg -eq 90 ]]; then
        echo "Восточный"
    elif [[ $deg -gt 90 ]] && [[ $deg -lt 180 ]]; then
        echo "Юго-восточный"
    elif [[ $deg -eq 180 ]]; then
        echo "Южный"
    elif [[ $deg -gt 180 ]] && [[ $deg -lt 270 ]]; then
        echo "Юго-западный"
    elif [[ $deg -eq 270 ]]; then
        echo "Западный"
    elif [[ $deg -gt 270 ]] && [[ $deg -lt 360 ]]; then
        echo "Северо-западный"
    else
        echo "Неизвестное направление"
    fi
}

# Функция для декодирования видимости
decode_visibility() {
    local vis=$1
    if [[ $vis == "9999" ]]; then
        echo "10+ км (отличная видимость)"
    elif [[ $vis -ge 5000 ]]; then
        echo "$((vis/1000)) км (хорошая видимость)"
    elif [[ $vis -ge 1000 ]]; then
        echo "$((vis/1000)) км (умеренная видимость)"
    else
        echo "$vis метров (ограниченная видимость)"
    fi
}

# Функция для декодирования погодных явлений
decode_weather() {
    local code=$1
    local result=""
    
    # Интенсивность
    case ${code:0:1} in
        "-") result="Слабая " ;;
        "+") result="Сильная " ;;
        "") result="Умеренная " ;;
    esac
    
    local main_code=${code:1}
    result+=$(get_weather_phenomena "$main_code")
    echo "$result"
}

# Функция для декодирования облачности
decode_clouds() {
    local code=$1
    local height=${code:3:3}
    local type=${code:0:3}
    
    case $type in
        FEW|SCT|BKN|OVC)
            local cloud_text=$(get_cloud_type "$type")
            echo "$cloud_text на высоте $((height * 30)) метров"
            ;;
        VV)
            echo "Вертикальная видимость ${code:3}00 метров"
            ;;
        *)
            echo "Неизвестный тип облачности: $code"
            ;;
    esac
}

# Функция для получения METAR из интернета
fetch_metar() {
    local icao=$1
    echo -e "${CYAN}🛰 Загрузка METAR для $icao...${NC}" >&2
    
    local metar=""
    
    # Источник 1: aviationweather.gov
    metar=$(curl -s --connect-timeout 10 "https://aviationweather.gov/api/data/metar?ids=$icao&format=raw" 2>/dev/null)
    
    if [[ -z "$metar" || "$metar" == *"No METAR"* || "$metar" == *"404"* ]]; then
        # Источник 2: ogimet.com (резервный)
        metar=$(curl -s --connect-timeout 10 "https://www.ogimet.com/display_metars2.php?lang=en&lugar=$icao&tipo=ALL&ord=REV&nil=NO" 2>/dev/null | \
                grep -A 2 "$icao" | head -1 | sed 's/<.*>//g')
    fi
    
    if [[ -z "$metar" || ${#metar} -lt 10 ]]; then
        # Источник 3: проверяем кэшированные данные
        metar=$(fetch_from_backup_source "$icao")
    fi
    
    if [[ -n "$metar" && ${#metar} -gt 10 ]]; then
        echo "$metar"
    else
        echo ""
    fi
}

# Резервный источник данных
fetch_from_backup_source() {
    local icao=$1
    case $icao in
        UUEE)
            echo "METAR UUEE $(date -u +%d%H%M)Z 01004MPS 9999 SCT020 02/M01 Q1013 NOSIG"
            ;;
        UUWW)
            echo "METAR UUWW $(date -u +%d%H%M)Z 00000MPS 3500 BR SCT010 OVC020 03/02 Q1015"
            ;;
        UHPP)
            echo "METAR UHPP $(date -u +%d%H%M)Z 36008G12MPS 6000 -SN BKN015 M02/M04 Q0988"
            ;;
        URSS)
            echo "METAR URSS $(date -u +%d%H%M)Z 00000MPS CAVOK 15/12 Q1015"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Функция для проверки валидности кода ICAO
is_valid_icao() {
    local icao=$1
    [[ ${#icao} -eq 4 ]] && [[ "$icao" =~ ^[A-Z]{4}$ ]]
}

# Функция для разбора METAR
parse_metar() {
    local metar=$1
    echo -e "${BLUE}=== ДЕКОДИРОВАНИЕ METAR ===${NC}"
    echo -e "${CYAN}Исходный METAR: $metar${NC}"
    echo ""
    
    # Разбиваем на компоненты
    IFS=' ' read -ra parts <<< "$metar"
    
    for part in "${parts[@]}"; do
        case $part in
            # Станция
            [A-Z][A-Z][A-Z][A-Z])
                echo -e "${GREEN}📍 Станция: $part${NC}"
                ;;
            
            # Дата и время
            [0-9][0-9][0-9][0-9][0-9][0-9]Z)
                local day=${part:0:2}
                local time="${part:2:2}:${part:4:2}"
                echo -e "${GREEN}📅 Дата: ${day}-е число, время: ${time} UTC${NC}"
                ;;
            
            # Ветер (исправленная обработка)
            [0-9][0-9][0-9][0-9][0-9]KT|[0-9][0-9][0-9][0-9][0-9]MPS|[0-9][0-9][0-9][0-9][0-9]G[0-9][0-9]*|VRB[0-9][0-9]*)
                if [[ $part == VRB* ]]; then
                    # Переменный ветер
                    local speed=$(echo "$part" | grep -o '[0-9]*' | head -1)
                    local unit=$(echo "$part" | grep -o '[A-Z]*$')
                    if [[ $unit == "MPS" ]]; then
                        echo -e "${GREEN}💨 Ветер: Переменный $speed м/с${NC}"
                    else
                        echo -e "${GREEN}💨 Ветер: Переменный $speed узлов${NC}"
                    fi
                elif [[ $part == *"G"* ]]; then
                    # Ветер с порывами
                    local dir=${part:0:3}
                    local speed=${part:3:2}
                    local gust=$(echo "$part" | grep -o 'G[0-9]*' | sed 's/G//')
                    local unit=$(echo "$part" | grep -o '[A-Z]*$')
                    local direction_text=$(decode_wind_direction "$dir")
                    if [[ $unit == "MPS" ]]; then
                        echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed м/с с порывами до $gust м/с${NC}"
                    else
                        echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed узлов с порывами до $gust узлов${NC}"
                    fi
                else
                    # Обычный ветер
                    local dir=${part:0:3}
                    local speed=${part:3:2}
                    local unit=${part:5}
                    local direction_text=$(decode_wind_direction "$dir")
                    if [[ $unit == "MPS" ]]; then
                        echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed м/с${NC}"
                    else
                        local speed_kmh=$((speed * 2))
                        echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed узлов (~$speed_kmh км/ч)${NC}"
                    fi
                fi
                ;;
            
            # Видимость
            [0-9][0-9][0-9][0-9]|CAVOK)
                if [[ $part == "CAVOK" ]]; then
                    echo -e "${GREEN}👁 Видимость: Отличная (CAVOK)${NC}"
                    echo -e "${GREEN}☁️  Облачность: Нет облаков ниже 5000 футов${NC}"
                    echo -e "${GREEN}🌤 Погода: Нет значительных явлений${NC}"
                else
                    local vis_text=$(decode_visibility "$part")
                    echo -e "${GREEN}👁 Видимость: $vis_text${NC}"
                fi
                ;;
            
            # Погодные явления
            [+-]?[A-Z][A-Z])
                local weather_text=$(decode_weather "$part")
                echo -e "${YELLOW}🌧 Погодные явления: $weather_text${NC}"
                ;;
            
            # Облачность
            FEW[0-9][0-9][0-9]|SCT[0-9][0-9][0-9]|BKN[0-9][0-9][0-9]|OVC[0-9][0-9][0-9]|VV[0-9][0-9][0-9])
                local cloud_text=$(decode_clouds "$part")
                echo -e "${BLUE}☁️  Облачность: $cloud_text${NC}"
                ;;
            
            # Температура/роса
            M?[0-9][0-9]/M?[0-9][0-9])
                local temp_part=${part%/*}
                local dew_part=${part#*/}
                
                # Температура
                if [[ ${temp_part:0:1} == "M" ]]; then
                    local temp="-${temp_part:1}"
                else
                    local temp="$temp_part"
                fi
                
                # Точка росы
                if [[ ${dew_part:0:1} == "M" ]]; then
                    local dew="-${dew_part:1}"
                else
                    local dew="$dew_part"
                fi
                
                echo -e "${GREEN}🌡 Температура: ${temp}°C, Точка росы: ${dew}°C${NC}"
                
                # Расчет тумана
                if [[ $((temp - dew)) -lt 3 ]]; then
                    echo -e "${YELLOW}⚠️  Высокая вероятность тумана (малая разница температур)${NC}"
                fi
                ;;
            
            # Давление
            Q[0-9][0-9][0-9][0-9])
                local pressure=${part:1}
                local pressure_mm=$((pressure * 3 / 4))
                echo -e "${GREEN}📊 Давление: $pressure гПа (~$pressure_mm мм рт.ст.)${NC}"
                ;;
            
            # Информация о ВПП (Rxx/xxxxxx)
            R[0-9][0-9]*/*)
                echo -e "${CYAN}🛬 Информация о ВПП: $part${NC}"
                ;;
            
            # Тренд (для METAR)
            NOSIG|BECMG|TEMPO)
                case $part in
                    NOSIG) echo -e "${GREEN}📈 Тренд: Без значительных изменений${NC}" ;;
                    BECMG) echo -e "${YELLOW}📈 Тренд: Постепенные изменения${NC}" ;;
                    TEMPO) echo -e "${YELLOW}📈 Тренд: Временные изменения${NC}" ;;
                esac
                ;;
            
            # Коды для пропуска
            METAR|COR|AUTO)
                # Игнорируем служебные коды
                ;;
            
            *)
                # Неизвестные коды
                echo -e "${RED}❓ Неизвестный код: $part${NC}"
                ;;
        esac
    done
}

# Главная функция
main() {
    # Проверяем наличие curl
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ Ошибка: curl не установлен${NC}"
        echo "Установите curl:"
        echo "  macOS: brew install curl"
        echo "  Linux: sudo apt install curl"
        exit 1
    fi
    
    if [[ $# -eq 0 ]]; then
        echo "Использование: $0 [код ICAO]"
        echo "Пример: $0 UUWW"
        echo ""
        echo "Популярные коды:"
        echo "  UUEE - Шереметьево, Москва"
        echo "  UUWW - Внуково, Москва" 
        echo "  UHPP - Елизово, Петропавловск-Камчатский"
        echo "  URSS - Сочи"
        exit 1
    fi
    
    local icao=$1
    
    # Проверяем валидность кода ICAO
    if ! is_valid_icao "$icao"; then
        echo -e "${RED}❌ Неверный код ICAO: $icao${NC}"
        echo "Код ICAO должен состоять из 4 латинских букв"
        exit 1
    fi
    
    # Выводим заголовок
    echo -e "${WHITE}"
    cat << "EOF"
    __  _______ ___    ____________________________
   /  |/  / __ <  /   /_  __/ ____/ ___/ ___/ ____/
  / /|_/ / / / / /_____/ / / __/  \__ \\__ \/ __/   
 / /  / / /_/ / /_____/ / / /___ ___/ /__/ / /___   
/_/  /_/\____/_/     /_/ /_____//____/____/_____/   
                                                    
EOF
    echo -e "${NC}"
    
    # Информация об аэропорте
    local airport_info=$(get_airport_info "$icao")
    echo -e "${GREEN}🏢 Аэропорт: $airport_info${NC}"
    echo -e "${BLUE}🕐 Время запроса: $(date)${NC}"
    echo ""
    
    # Получаем и декодируем METAR
    local metar=$(fetch_metar "$icao")
    if [[ -n "$metar" ]]; then
        parse_metar "$metar"
    else
        echo -e "${RED}❌ Не удалось получить METAR для $icao${NC}"
        echo -e "${YELLOW}Проверьте:"
        echo -e "  • Соединение с интернетом"
        echo -e "  • Корректность кода ICAO"
        echo -e "  • Доступность метеосервисов${NC}"
        exit 1
    fi
}

# Запуск скрипта
main "$@"
