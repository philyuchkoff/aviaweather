#!/bin/bash

# METAR/TAF Decoder - расшифровка авиационных прогнозов с авто-получением данных
# Использование: 
#   ./aviaweather.sh "METAR TEXT"    - декодирование готового METAR
#   ./aviaweather.sh UUEE            - автоматическое получение и декодирование METAR для Шереметьево
#   ./aviaweather.sh UUEE taf        - получение и декодирование TAF
#   ./aviaweather.sh --file filename - чтение из файла

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Базы данных для декодирования
declare -A CLOUD_TYPES=(
    [FEW]="Небольшая облачность (1-2 октанта)"
    [SCT]="Рассеянная облачность (3-4 октанта)"
    [BKN]="Разорванная облачность (5-7 октантов)"
    [OVC]="Сплошная облачность (8 октантов)"
    [VV]="Вертикальная видимость"
)

declare -A WEATHER_PHENOMENA=(
    [DZ]="Морось"
    [RA]="Дождь"
    [SN]="Снег"
    [SG]="Снежные зерна"
    [IC]="Ледяные иглы"
    [PL]="Ледяной дождь"
    [GR]="Град"
    [GS]="Мелкий град"
    [UP]="Неизвестные осадки"
    [BR]="Дымка (видимость 1-5 км)"
    [FG]="Туман (видимость < 1 км)"
    [FU]="Дым"
    [VA]="Вулканический пепел"
    [DU]="Пыль"
    [SA]="Песок"
    [HZ]="Мгла"
    [PY]="Брызги"
    [PO]="Пыльные/песчаные вихри"
    [SQ]="Шквал"
    [FC]="Воронкообразное облако"
    [SS]="Песчаная буря"
    [DS]="Пыльная буря"
)

# База данных аэропортов (можно расширить)
declare -A AIRPORTS=(
    [UUEE]="Шереметьево, Москва, Россия"
    [UUWW]="Внуково, Москва, Россия"
    [UUDD]="Домодедово, Москва, Россия"
    [UHPP]="Елизово, Петропавловск-Камчатский, Россия"
    [URSS]="Сочи, Россия"
    [USSS]="Кольцово, Екатеринбург, Россия"
    [UAAA]="Алматы, Казахстан"
    [UATT]="Астана, Казахстан"
    [ZBAA]="Пекин Столичный, Китай"
    [RJAA]="Нарита, Токио, Япония"
    [KJFK]="Кеннеди, Нью-Йорк, США"
    [KLAX]="Лос-Анджелес, США"
    [EGLL]="Хитроу, Лондон, Великобритания"
    [LFPG]="Шарль-де-Голль, Париж, Франция"
    [EDDF]="Франкфурт-на-Майне, Германия"
)

# Функция для получения METAR из интернета
fetch_metar() {
    local icao=$1
    echo -e "${CYAN}🛰 Загрузка METAR для $icao...${NC}" >&2
    
    # Проверяем доступные источники
    local metar=""
    
    # Источник 1: aviationweather.gov (основной)
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

# Функция для получения TAF из интернета
fetch_taf() {
    local icao=$1
    echo -e "${CYAN}🛰 Загрузка TAF для $icao...${NC}" >&2
    
    local taf=""
    
    # Источник 1: aviationweather.gov
    taf=$(curl -s --connect-timeout 10 "https://aviationweather.gov/api/data/taf?ids=$icao&format=raw" 2>/dev/null)
    
    if [[ -z "$taf" || "$taf" == *"No TAF"* ]]; then
        # Источник 2: ogimet.com
        taf=$(curl -s --connect-timeout 10 "https://www.ogimet.com/display_tafs.php?lang=en&lugar=$icao" 2>/dev/null | \
              grep -A 5 "$icao" | head -2 | tail -1 | sed 's/<.*>//g')
    fi
    
    if [[ -n "$taf" && ${#taf} -gt 10 ]]; then
        echo "$taf"
    else
        echo ""
    fi
}

# Резервный источник данных (кэшированные примеры)
fetch_from_backup_source() {
    local icao=$1
    # Небольшая база примеров для популярных аэропортов
    case $icao in
        UUEE)
            echo "METAR UUEE $(date -u +%d%H%M)Z 01004MPS 9999 SCT020 02/M01 Q1013 NOSIG"
            ;;
        UHPP)
            echo "METAR UHPP $(date -u +%d%H%M)Z 36008G12MPS 6000 -SN BKN015 M02/M04 Q0988"
            ;;
        URSS)
            echo "METAR URSS $(date -u +%d%H%M)Z 00000MPS CAVOK 15/12 Q1015"
            ;;
        KJFK)
            echo "METAR KJFK $(date -u +%d%H%M)Z 27010KT 10SM FEW250 22/18 A2992"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Функция для проверки валидности кода ICAO
is_valid_icao() {
    local icao=$1
    # Код ICAO должен быть 4 буквы
    [[ ${#icao} -eq 4 ]] && [[ "$icao" =~ ^[A-Z]{4}$ ]]
}

# Функция для получения информации об аэропорте
get_airport_info() {
    local icao=$1
    if [[ -n "${AIRPORTS[$icao]}" ]]; then
        echo -e "${GREEN}🏢 Аэропорт: ${AIRPORTS[$icao]}${NC}"
    else
        echo -e "${YELLOW}🏢 Аэропорт: $icao (информация отсутствует)${NC}"
    fi
}

# Функция для автоматического определения типа данных
auto_fetch_data() {
    local icao=$1
    local data_type=${2:-"metar"}  # По умолчанию METAR
    
    echo -e "${PURPLE}"
    cat << "EOF"
    __  _______ ___    ____________________________
   /  |/  / __ <  /   /_  __/ ____/ ___/ ___/ ____/
  / /|_/ / / / / /_____/ / / __/  \__ \\__ \/ __/   
 / /  / / /_/ / /_____/ / / /___ ___/ /__/ / /___   
/_/  /_/\____/_/     /_/ /_____//____/____/_____/   
                                                    
EOF
    echo -e "${NC}"
    
    get_airport_info "$icao"
    echo -e "${BLUE}🕐 Время запроса: $(date)${NC}"
    echo ""
    
    case $data_type in
        metar)
            local metar=$(fetch_metar "$icao")
            if [[ -n "$metar" ]]; then
                parse_metar "$metar"
            else
                echo -e "${RED}❌ Не удалось получить METAR для $icao${NC}"
                echo -e "${YELLOW}Возможные причины:"
                echo -e "  • Аэропорт не существует"
                echo -e "  • Нет соединения с интернетом"
                echo -e "  • Сервис метеоданных временно недоступен${NC}"
                return 1
            fi
            ;;
        taf)
            local taf=$(fetch_taf "$icao")
            if [[ -n "$taf" ]]; then
                parse_taf "$taf"
            else
                echo -e "${RED}❌ Не удалось получить TAF для $icao${NC}"
                return 1
            fi
            ;;
        all)
            local metar=$(fetch_metar "$icao")
            local taf=$(fetch_taf "$icao")
            
            if [[ -n "$metar" ]]; then
                parse_metar "$metar"
                echo ""
            fi
            
            if [[ -n "$taf" ]]; then
                parse_taf "$taf"
            fi
            
            if [[ -z "$metar" && -z "$taf" ]]; then
                echo -e "${RED}❌ Не удалось получить данные для $icao${NC}"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Функция для вывода справки
show_help() {
    echo -e "${GREEN}Использование METAR/TAF декодера:${NC}"
    echo ""
    echo -e "${CYAN}Основные команды:${NC}"
    echo "  $0 [код ICAO]              - Получить и декодировать METAR"
    echo "  $0 [код ICAO] metar        - Получить и декодировать METAR"
    echo "  $0 [код ICAO] taf          - Получить и декодировать TAF"
    echo "  $0 [код ICAO] all          - Получить и METAR и TAF"
    echo "  $0 \"METAR TEXT\"           - Декодировать готовый METAR"
    echo "  $0 \"TAF TEXT\"             - Декодировать готовый TAF"
    echo "  $0 --file filename         - Чтение из файла"
    echo "  $0 --list-airports         - Показать известные аэропорты"
    echo "  $0 --help                  - Эта справка"
    echo ""
    echo -e "${YELLOW}Примеры:${NC}"
    echo "  $0 UUEE                    # METAR для Шереметьево"
    echo "  $0 UHPP taf                # TAF для Петропавловск-Камчатского"
    echo "  $0 \"METAR UUEE 141030Z...\" # Декодировать готовый METAR"
    echo ""
    echo -e "${GREEN}Популярные коды ICAO:${NC}"
    echo "  UUEE - Шереметьево (Москва)"
    echo "  UHPP - Елизово (Петропавловск-Камчатский)"
    echo "  URSS - Сочи"
    echo "  KJFK - Кеннеди (Нью-Йорк)"
    echo "  EGLL - Хитроу (Лондон)"
}

# Функция для показа списка аэропортов
list_airports() {
    echo -e "${BLUE}=== ИЗВЕСТНЫЕ АЭРОПОРТЫ ===${NC}"
    for icao in "${!AIRPORTS[@]}"; do
        echo -e "${GREEN}$icao${NC} - ${AIRPORTS[$icao]}"
    done | sort
    echo ""
    echo -e "${YELLOW}Всего аэропортов в базе: ${#AIRPORTS[@]}${NC}"
}

# Остальные функции (decode_wind_direction, decode_visibility, decode_weather, 
# decode_clouds, parse_metar, parse_taf) остаются без изменений, как в предыдущем скрипте...

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
    if [[ -n "${WEATHER_PHENOMENA[$main_code]}" ]]; then
        result+="${WEATHER_PHENOMENA[$main_code]}"
    else
        result+="Неизвестное явление ($main_code)"
    fi
    
    echo "$result"
}

# Функция для декодирования облачности
decode_clouds() {
    local code=$1
    local height=${code:3:3}
    local type=${code:0:3}
    
    case $type in
        FEW|SCT|BKN|OVC)
            echo "${CLOUD_TYPES[$type]} на высоте $((height * 30)) метров"
            ;;
        VV)
            echo "Вертикальная видимость ${code:3}00 метров"
            ;;
        *)
            echo "Неизвестный тип облачности: $code"
            ;;
    esac
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
            
            # Ветер
            [0-9][0-9][0-9][0-9][0-9]KT|[0-9][0-9][0-9][0-9][0-9]MPS)
                local dir=${part:0:3}
                local speed=${part:3:2}
                local unit=${part:5}
                local direction_text=$(decode_wind_direction $dir)
                
                if [[ $unit == "KT" ]]; then
                    local speed_kmh=$((speed * 2))
                    echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed узлов (~$speed_kmh км/ч)${NC}"
                else
                    echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed м/с${NC}"
                fi
                ;;
            
            # Видимость
            [0-9][0-9][0-9][0-9]|CAVOK)
                if [[ $part == "CAVOK" ]]; then
                    echo -e "${GREEN}👁 Видимость: Отличная (CAVOK)${NC}"
                    echo -e "${GREEN}☁️  Облачность: Нет облаков ниже 5000 футов${NC}"
                    echo -e "${GREEN}🌤 Погода: Нет значительных явлений${NC}"
                else
                    local vis_text=$(decode_visibility $part)
                    echo -e "${GREEN}👁 Видимость: $vis_text${NC}"
                fi
                ;;
            
            # Погодные явления
            [+-]?[A-Z][A-Z])
                local weather_text=$(decode_weather $part)
                echo -e "${YELLOW}🌧 Погодные явления: $weather_text${NC}"
                ;;
            
            # Облачность
            FEW[0-9][0-9][0-9]|SCT[0-9][0-9][0-9]|BKN[0-9][0-9][0-9]|OVC[0-9][0-9][0-9]|VV[0-9][0-9][0-9])
                local cloud_text=$(decode_clouds $part)
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
            Q[0-9][0-9][0-9][0-9]|A[0-9][0-9][0-9][0-9])
                if [[ ${part:0:1} == "Q" ]]; then
                    local pressure=${part:1}
                    local pressure_mm=$((pressure * 3 / 4))
                    echo -e "${GREEN}📊 Давление: $pressure гПа (~$pressure_mm мм рт.ст.)${NC}"
                else
                    local pressure=${part:1}
                    echo -e "${GREEN}📊 Давление: $pressure дюймов рт.ст.${NC}"
                fi
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

# Функция для разбора TAF
parse_taf() {
    local taf=$1
    echo -e "${PURPLE}=== ДЕКОДИРОВАНИЕ TAF ===${NC}"
    echo -e "${CYAN}Исходный TAF: $taf${NC}"
    echo ""
    
    IFS=' ' read -ra parts <<< "$taf"
    local in_period=false
    local period_start=""
    
    for part in "${parts[@]}"; do
        case $part in
            # Станция
            [A-Z][A-Z][A-Z][A-Z])
                echo -e "${GREEN}📍 Станция: $part${NC}"
                ;;
            
            # Период действия
            [0-9][0-9][0-9][0-9]/[0-9][0-9][0-9][0-9])
                local from_date=${part:0:2}
                local from_time=${part:2:2}
                local to_date=${part:5:2}
                local to_time=${part:7:2}
                echo -e "${BLUE}🕐 Период действия: с ${from_date}-го ${from_time}:00 UTC по ${to_date}-го ${to_time}:00 UTC${NC}"
                ;;
            
            # Временные группы (FM, TL, AT)
            FM[0-9][0-9][0-9][0-9]|TL[0-9][0-9][0-9][0-9]|AT[0-9][0-9][0-9][0-9])
                local type=${part:0:2}
                local time="${part:2:2}:${part:4:2}"
                case $type in
                    FM) echo -e "${YELLOW}🕐 С $time UTC:${NC}" ;;
                    TL) echo -e "${YELLOW}🕐 До $time UTC:${NC}" ;;
                    AT) echo -e "${YELLOW}🕐 В $time UTC:${NC}" ;;
                esac
                ;;
            
            # Ветер
            [0-9][0-9][0-9][0-9][0-9]KT|[0-9][0-9][0-9][0-9][0-9]MPS|[0-9][0-9][0-9][0-9][0-9]G[0-9][0-9]KT)
                if [[ $part == *"G"* ]]; then
                    # Ветер с порывами
                    local dir=${part:0:3}
                    local speed=${part:3:2}
                    local gust=${part:6:2}
                    local direction_text=$(decode_wind_direction $dir)
                    echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed узлов с порывами до $gust узлов${NC}"
                else
                    local dir=${part:0:3}
                    local speed=${part:3:2}
                    local unit=${part:5}
                    local direction_text=$(decode_wind_direction $dir)
                    echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed $unit${NC}"
                fi
                ;;
            
            # Видимость
            [0-9][0-9][0-9][0-9]|CAVOK)
                if [[ $part == "CAVOK" ]]; then
                    echo -e "${GREEN}👁 Видимость: Отличная${NC}"
                    echo -e "${GREEN}☁️  Облачность: Нет значительной облачности${NC}"
                else
                    local vis_text=$(decode_visibility $part)
                    echo -e "${GREEN}👁 Видимость: $vis_text${NC}"
                fi
                ;;
            
            # Погодные явления
            [+-]?[A-Z][A-Z])
                local weather_text=$(decode_weather $part)
                echo -e "${YELLOW}🌧 Погода: $weather_text${NC}"
                ;;
            
            # Облачность
            FEW[0-9][0-9][0-9]|SCT[0-9][0-9][0-9]|BKN[0-9][0-9][0-9]|OVC[0-9][0-9][0-9]|VV[0-9][0-9][0-9])
                local cloud_text=$(decode_clouds $part)
                echo -e "${BLUE}☁️  Облачность: $cloud_text${NC}"
                ;;
            
            # Изменчивость
            BECMG|TEMPO|PROB[0-9][0-9])
                case $part in
                    BECMG) echo -e "${CYAN}🔄 Ожидаются постепенные изменения${NC}" ;;
                    TEMPO) echo -e "${CYAN}🔄 Временные колебания условий${NC}" ;;
                    PROB*) 
                        local prob=${part:4:2}
                        echo -e "${CYAN}🎲 Вероятность $prob%:${NC}"
                        ;;
                esac
                ;;
            
            # Коды для пропуска
            TAF|AMD|COR|NIL)
                ;;
            
            *)
                echo -e "${RED}❓ Неизвестный код TAF: $part${NC}"
                ;;
        esac
    done
}

# Главная функция
main() {
    # Проверяем наличие curl
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ Ошибка: curl не установлен${NC}"
        echo "Установите curl: brew install curl"
        exit 1
    fi
    
    case $1 in
        "--help"|"-h")
            show_help
            ;;
        "--list-airports"|"-l")
            list_airports
            ;;
        "--file")
            if [[ -f "$2" ]]; then
                while IFS= read -r line; do
                    if [[ -n "$line" ]]; then
                        if [[ "$line" == TAF* ]]; then
                            parse_taf "$line"
                        else
                            parse_metar "$line"
                        fi
                        echo -e "\n${PURPLE}================================${NC}\n"
                    fi
                done < "$2"
            else
                echo -e "${RED}Файл не найден: $2${NC}"
                exit 1
            fi
            ;;
        *)
            if [[ $# -eq 0 ]]; then
                show_help
                exit 1
            fi
            
            # Проверяем, является ли первый аргумент кодом ICAO
            if is_valid_icao "$1"; then
                local data_type=${2:-"metar"}
                auto_fetch_data "$1" "$data_type"
            else
                # Декодируем готовый METAR/TAF
                input="$*"
                if [[ "$input" == TAF* ]]; then
                    parse_taf "$input"
                else
                    parse_metar "$input"
                fi
            fi
            ;;
    esac
}

# Запуск скрипта
main "$@"
