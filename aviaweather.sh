#!/bin/bash

# AVIAWEATHER Decoder - совместимый с старыми версиями Bash
# Использование: ./aviaweather.sh UHPP

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

get_cloud_supplement() {
    case $1 in
        "CB") echo " (кучево-дождевые)" ;;
        "TCU") echo " (кучево-дождевые мощные)" ;;
        *) echo "" ;;
    esac
}

get_weather_phenomena() {
    case $1 in
        "DZ") echo "морось" ;;
        "RA") echo "дождь" ;;
        "SN") echo "снег" ;;
        "SG") echo "снежные зерна" ;;
        "IC") echo "ледяные иглы" ;;
        "PL") echo "ледяной дождь" ;;
        "GR") echo "град" ;;
        "GS") echo "мелкий град" ;;
        "UP") echo "неизвестные осадки" ;;
        "BR") echo "дымка" ;;
        "FG") echo "туман" ;;
        "FU") echo "дым" ;;
        "VA") echo "вулканический пепел" ;;
        "DU") echo "пыль" ;;
        "SA") echo "песок" ;;
        "HZ") echo "мгла" ;;
        "PY") echo "брызги" ;;
        "PO") echo "пыльные/песчаные вихри" ;;
        "SQ") echo "шквал" ;;
        "FC") echo "воронкообразное облако" ;;
        "SS") echo "песчаная буря" ;;
        "DS") echo "пыльная буря" ;;
        "TS") echo "гроза" ;;
        "SH") echo "ливень" ;;
        "FZ") echo "переохлажденный" ;;
        "MI") echo "мелкий" ;;
        "PR") echo "частичный" ;;
        "BC") echo "поземок" ;;
        "BL") echo "низовая метель" ;;
        "DR") echo "поземная пыль/песок" ;;
        *) echo "" ;;
    esac
}

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

# Функция для декодирования направления ветра
decode_wind_direction() {
    local deg=$1
    # Убираем ведущие нули, чтобы избежать восьмеричной интерпретации
    deg=$(echo "$deg" | sed 's/^0*//')
    deg=${deg:-0}  # Если строка пустая, устанавливаем 0
    
    # Преобразуем в число
    deg=$((deg))
    
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
    # Убираем ведущие нули для избежания восьмеричной интерпретации
    vis=$(echo "$vis" | sed 's/^0*//')
    vis=${vis:-0}
    
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

# Функция для декодирования состояния ВПП
decode_runway_state() {
    local code=$1
    local runway=$(echo "$code" | grep -o '^R[0-9LCRA]*/' | sed 's|/$||')
    local state=$(echo "$code" | sed "s|^$runway/||")
    
    local result="🛬 ВПП ${runway:1}: "
    
    if [[ -z "$state" || "$state" == "$code" ]]; then
        result+="Информация о состоянии ВПП"
        echo "$result"
        return
    fi
    
    # Декодируем состояние ВПП по цифрам
    if [[ ${#state} -ge 6 ]]; then
        local deposit=${state:0:1}    # 2 - отложения
        local extent=${state:1:1}     # 9 - покрытие
        local depth=${state:2:2}      # 00 - глубина
        local friction=${state:4:2}   # 50 - трение
        
        case $deposit in
            "0") result+="Чистая и сухая" ;;
            "1") result+="Влажная" ;;
            "2") result+="Мокрая" ;;
            "3") result+="Иней/изморозь" ;;
            "4") result+="Сухой снег" ;;
            "5") result+="Мокрый снег" ;;
            "6") result+="Слякоть" ;;
            "7") result+="Лед" ;;
            "8") result+="Укатанный снег" ;;
            "9") result+="Замерзшие колеи" ;;
            "/") result+="Информация отсутствует" ;;
            *) result+="Неизвестное состояние" ;;
        esac
        
        result+=", покрытие: "
        case $extent in
            "1") result+="1-10%" ;;
            "2") result+="11-25%" ;;
            "5") result+="26-50%" ;;
            "9") result+="51-100%" ;;
            "/") result+="не указано" ;;
            *) result+="неизвестно" ;;
        esac
        
        if [[ $depth != "//" && $depth != "00" ]]; then
            # Убираем ведущие нули
            depth=$(echo "$depth" | sed 's/^0*//')
            depth=${depth:-0}
            result+=", глубина: ${depth}мм"
        fi
        
        if [[ $friction != "//" ]]; then
            # Убираем ведущие нули
            friction=$(echo "$friction" | sed 's/^0*//')
            friction=${friction:-0}
            result+=", трение: 0.${friction}"
        fi
    else
        result+="Состояние: $state"
    fi
    
    echo "$result"
}

# Функция для декодирования NOTAM кодов
decode_notam_code() {
    local notam_code=$1
    
    case $notam_code in
        "QBB"*)
            echo "NOTAM Германия - информация о воздушном пространстве" ;;
        "QFE"*)
            echo "Давление на уровне аэродрома" ;;
        "QNH"*)
            echo "Давление на уровне моря" ;;
        "QNE"*)
            echo "Высота по давлению" ;;
        "RVR"*)
            echo "Видимость на ВПП" ;;
        "WS"*)
            echo "Сдвиг ветра" ;;
        "RWY"*)
            echo "Состояние ВПП" ;;
        "SFC"*)
            echo "Состояние поверхности" ;;
        "CLD"*)
            echo "Облачность" ;;
        "WX"*)
            echo "Погодные явления" ;;
        "TMP"*)
            echo "Температура" ;;
        "VIS"*)
            echo "Видимость" ;;
        "WIND"*)
            echo "Ветер" ;;
        "APCH"*)
            echo "Заход на посадку" ;;
        "DEP"*)
            echo "Вылет" ;;
        "ENR"*)
            echo "Маршрут" ;;
        "ADC"*)
            echo "Аэродромные данные" ;;
        "RAC"*)
            echo "Правила полетов и обслуживания" ;;
        "COM"*)
            echo "Связь" ;;
        "NAV"*)
            echo "Навигация" ;;
        "OAT"*)
            echo "Наружная температура" ;;
        "SIG"*)
            echo "Значительные явления" ;;
        "SPECI"*)
            echo "Специальный отчет" ;;
        "METAR"*)
            echo "Стандартный отчет" ;;
        "TAF"*)
            echo "Прогноз" ;;
        *)
            echo "Служебный код NOTAM" ;;
    esac
}

# Функция для декодирования комбинированных погодных явлений
decode_complex_weather() {
    local code=$1
    local result=""
    
    # Определяем интенсивность
    local intensity=""
    local main_code=$code
    
    if [[ ${code:0:1} == "+" ]]; then
        intensity="Сильный "
        main_code=${code:1}
    elif [[ ${code:0:1} == "-" ]]; then
        intensity="Слабый "
        main_code=${code:1}
    else
        intensity=""
        main_code=$code
    fi
    
    result="$intensity"
    
    # Разбираем комбинированные коды
    local temp_code=$main_code
    local found_valid=0
    
    while [[ ${#temp_code} -ge 2 ]]; do
        local phenomenon=$(get_weather_phenomena "${temp_code:0:2}")
        if [[ -n "$phenomenon" ]]; then
            result+="$phenomenon, "
            found_valid=1
            temp_code=${temp_code:2}
        else
            # Если не нашли совпадение из 2 символов, пробуем 1 символ
            local single_char=$(get_weather_phenomena "${temp_code:0:1}")
            if [[ -n "$single_char" ]]; then
                result+="$single_char, "
                found_valid=1
                temp_code=${temp_code:1}
            else
                # Пропускаем неизвестные символы
                temp_code=${temp_code:1}
            fi
        fi
    done
    
    # Убираем последнюю запятую и пробел
    result=${result%, }
    
    if [[ $found_valid -eq 0 ]]; then
        echo ""
    else
        echo "$result"
    fi
}

# Функция для декодирования облачности
decode_clouds() {
    local code=$1
    local type=${code:0:3}
    local height=${code:3:3}
    local supplement=""
    
    # Проверяем наличие дополнения (CB, TCU)
    if [[ ${#code} -gt 6 ]]; then
        supplement=$(get_cloud_supplement "${code:6}")
    fi
    
    # Убираем ведущие нули из высоты
    height=$(echo "$height" | sed 's/^0*//')
    height=${height:-0}
    
    case $type in
        FEW|SCT|BKN|OVC)
            local cloud_text=$(get_cloud_type "$type")
            echo "$cloud_text на высоте $((height * 30)) метров$supplement"
            ;;
        VV)
            echo "Вертикальная видимость ${height}00 метров"
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
    
    # Источник: aviationweather.gov
    taf=$(curl -s --connect-timeout 10 "https://aviationweather.gov/api/data/taf?ids=$icao&format=raw" 2>/dev/null)
    
    if [[ -n "$taf" && ${#taf} -gt 10 && "$taf" != *"404"* && "$taf" != *"No TAF"* ]]; then
        echo "$taf"
    else
        echo ""
    fi
}

# Функция для проверки валидности кода ICAO
is_valid_icao() {
    local icao=$1
    [[ ${#icao} -eq 4 ]] && [[ "$icao" =~ ^[A-Z]{4}$ ]]
}

# Функция для обработки температуры (безопасная версия)
parse_temperature() {
    local part=$1
    local temp_part=${part%/*}
    local dew_part=${part#*/}
    
    # Обработка температуры
    if [[ ${temp_part:0:1} == "M" ]]; then
        local temp="-${temp_part:1}"
    else
        local temp="$temp_part"
    fi
    
    # Обработка точки росы
    if [[ ${dew_part:0:1} == "M" ]]; then
        local dew="-${dew_part:1}"
    else
        local dew="$dew_part"
    fi
    
    echo -e "${GREEN}🌡 Температура: ${temp}°C, Точка росы: ${dew}°C${NC}"
    
    # Простая проверка на одинаковые температуры
    if [[ "$temp" == "$dew" ]]; then
        echo -e "${YELLOW}⚠️  Высокая вероятность тумана (температура равна точке росы)${NC}"
    fi
}

# Функция для проверки является ли код погодным явлением
is_weather_code() {
    local code=$1
    # Проверяем коды с интенсивностью (+RA, -SN, etc) и комбинированные коды
    if [[ $code =~ ^[+-]?[A-Z]{2,}$ ]]; then
        local weather_text=$(decode_complex_weather "$code")
        if [[ -n "$weather_text" ]]; then
            return 0
        fi
    fi
    return 1
}

# Функция для проверки является ли код информацией о ВПП
is_runway_code() {
    local code=$1
    [[ $code =~ ^R[0-9][0-9].*/.* ]]
}

# Функция для проверки является ли код QFE
is_qfe_code() {
    local code=$1
    [[ $code =~ ^QFE[0-9].* ]]
}

# Функция для разбора METAR
parse_metar() {
    local metar=$1
    echo -e "${CYAN}=== ДЕКОДИРОВАНИЕ METAR ===${NC}"
    echo -e "${WHITE}Исходный METAR: $metar${NC}"
    echo ""
    
    # Разбиваем на компоненты
    IFS=' ' read -ra parts <<< "$metar"
    
    for part in "${parts[@]}"; do
        # Сначала проверяем специальные коды
        if is_runway_code "$part"; then
            local runway_info=$(decode_runway_state "$part")
            echo -e "${CYAN}$runway_info${NC}"
            continue
        fi
        
        if is_qfe_code "$part"; then
            if [[ $part == *"/"* ]]; then
                # Формат QFE757/1009
                local qfe_part=${part:3}
                local qfe_mm=${qfe_part%/*}
                local qfe_hpa=${qfe_part#*/}
                echo -e "${CYAN}📊 Давление на ВПП (QFE): $qfe_mm мм рт.ст. ($qfe_hpa гПа)${NC}"
            else
                # Простой формат QFE
                local qfe_value=${part:3}
                echo -e "${CYAN}📊 Давление на ВПП (QFE): $qfe_value гПа${NC}"
            fi
            continue
        fi
        
        # Затем стандартные коды
        case $part in
            # Типы METAR
            "METAR"|"SPECI")
                echo -e "${CYAN}📊 Тип: $part${NC}"
                ;;
            
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
            [0-9][0-9][0-9][0-9][0-9]KT|[0-9][0-9][0-9][0-9][0-9]MPS|[0-9][0-9][0-9][0-9][0-9]G[0-9][0-9]*|VRB[0-9][0-9]*)
                if [[ $part == VRB* ]]; then
                    # Переменный ветер
                    local speed=$(echo "$part" | grep -o '[0-9]*' | head -1)
                    local unit=$(echo "$part" | grep -o '[A-Z]*$')
                    # Убираем ведущие нули из скорости
                    speed=$(echo "$speed" | sed 's/^0*//')
                    speed=${speed:-0}
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
                    # Убираем ведущие нули из направления и скорости
                    dir=$(echo "$dir" | sed 's/^0*//')
                    dir=${dir:-0}
                    speed=$(echo "$speed" | sed 's/^0*//')
                    speed=${speed:-0}
                    gust=$(echo "$gust" | sed 's/^0*//')
                    gust=${gust:-0}
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
                    # Убираем ведущие нули из направления и скорости
                    dir=$(echo "$dir" | sed 's/^0*//')
                    dir=${dir:-0}
                    speed=$(echo "$speed" | sed 's/^0*//')
                    speed=${speed:-0}
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
            
            # Облачность (включая облака с дополнениями CB/TCU)
            FEW[0-9][0-9][0-9]*|SCT[0-9][0-9][0-9]*|BKN[0-9][0-9][0-9]*|OVC[0-9][0-9][0-9]*|VV[0-9][0-9][0-9]*)
                local cloud_text=$(decode_clouds "$part")
                echo -e "${CYAN}☁️  Облачность: $cloud_text${NC}"
                ;;
            
            # Температура/роса (универсальная обработка)
            */*)
                if [[ $part =~ ^[M]?[0-9]{1,2}/[M]?[0-9]{1,2}$ ]]; then
                    parse_temperature "$part"
                else
                    echo -e "${YELLOW}❓ Неизвестный код: $part${NC}"
                fi
                ;;
            
            # Давление
            Q[0-9][0-9][0-9][0-9])
                local pressure=${part:1}
                local pressure_mm=$((pressure * 3 / 4))
                echo -e "${GREEN}📊 Давление: $pressure гПа (~$pressure_mm мм рт.ст.)${NC}"
                ;;
            
            # Тренд (для METAR)
            NOSIG|BECMG|TEMPO)
                case $part in
                    NOSIG) echo -e "${GREEN}📈 Тренд: Без значительных изменений${NC}" ;;
                    BECMG) echo -e "${YELLOW}📈 Тренд: Постепенные изменения${NC}" ;;
                    TEMPO) echo -e "${YELLOW}📈 Тренд: Временные изменения${NC}" ;;
                esac
                ;;
            
            # Примечания (RMK)
            "RMK")
                echo -e "${CYAN}📝 Примечания: следующие коды являются дополнительной информацией${NC}"
                ;;
            
            # Коды для пропуска
            COR|AUTO)
                # Игнорируем служебные коды
                ;;
            
            *)
                # Проверяем является ли код погодным явлением
                if is_weather_code "$part"; then
                    local weather_text=$(decode_complex_weather "$part")
                    echo -e "${YELLOW}🌧 Погодные явления: $weather_text${NC}"
                elif [[ $part == Q* ]] && [[ ${#part} -ge 4 ]]; then
                    # Обработка NOTAM кодов (начинаются с Q)
                    local notam_info=$(decode_notam_code "$part")
                    echo -e "${PURPLE}📋 NOTAM: $notam_info${NC}"
                else
                    # Неизвестные коды
                    echo -e "${YELLOW}❓ Неизвестный код: $part${NC}"
                fi
                ;;
        esac
    done
}

# Функция для разбора TAF
parse_taf() {
    local taf=$1
    echo -e "${CYAN}=== ДЕКОДИРОВАНИЕ TAF ===${NC}"
    echo -e "${WHITE}Исходный TAF: $taf${NC}"
    echo ""
    
    # Разбиваем на компоненты
    IFS=' ' read -ra parts <<< "$taf"
    
    local current_section="main"
    local period_start=""
    local period_end=""
    local is_first_line=true

    for part in "${parts[@]}"; do
        # Пропускаем пустые элементы
        if [[ -z "$part" ]]; then
            continue
        fi

        # Обработка первой строки TAF (основная информация)
        if $is_first_line; then
            case $part in
                "TAF")
                    echo -e "${GREEN}📊 Тип: TAF (Terminal Aerodrome Forecast)${NC}"
                    ;;
                "AMD")
                    echo -e "${YELLOW}🔄 Исправленный TAF${NC}"
                    ;;
                [A-Z][A-Z][A-Z][A-Z])
                    echo -e "${GREEN}📍 Станция: $part${NC}"
                    ;;
                [0-9][0-9][0-9][0-9][0-9][0-9]Z)
                    local day=${part:0:2}
                    local time="${part:2:2}:${part:4:2}"
                    echo -e "${GREEN}📅 Дата выпуска: ${day}-е число, время: ${time} UTC${NC}"
                    ;;
                [0-9][0-9][0-9][0-9]/[0-9][0-9][0-9][0-9])
                    period_start="${part:0:2}:${part:2:2}"
                    period_end="${part:5:2}:${part:7:2}"
                    echo -e "${PURPLE}📅 Период действия: с ${period_start}Z по ${period_end}Z${NC}"
                    ;;
                *)
                    # Если это не служебное слово, пробуем распарсить как погодный элемент
                    parse_taf_component "$part" "$current_section"
                    ;;
            esac
            
            # Проверяем, закончилась ли первая строка
            if [[ $part =~ [0-9]{4}/[0-9]{4} ]]; then
                is_first_line=false
            fi
            continue
        fi

        # Обработка временных групп (после первой строки)
        case $part in
            "BECMG")
                echo ""
                echo -e "${BLUE}🔄 Постепенное изменение${NC}"
                current_section="becmg"
                ;;
            "TEMPO")
                echo ""
                echo -e "${YELLOW}⏱️ Временные изменения${NC}"
                current_section="tempo"
                ;;
            "FM"*)
                # С какого времени
                if [[ $part =~ ^FM[0-9]{4}$ ]]; then
                    local time="${part:2:2}:${part:4:2}"
                    echo ""
                    echo -e "${CYAN}🕐 С $timeZ${NC}"
                    current_section="fm"
                else
                    parse_taf_component "$part" "$current_section"
                fi
                ;;
            "TL"*)
                # До какого времени
                if [[ $part =~ ^TL[0-9]{4}$ ]]; then
                    local time="${part:2:2}:${part:4:2}"
                    echo -e "${CYAN}🕐 До $timeZ${NC}"
                else
                    parse_taf_component "$part" "$current_section"
                fi
                ;;
            "AT"*)
                # В определенное время
                if [[ $part =~ ^AT[0-9]{4}$ ]]; then
                    local time="${part:2:2}:${part:4:2}"
                    echo -e "${CYAN}🕐 В $timeZ${NC}"
                else
                    parse_taf_component "$part" "$current_section"
                fi
                ;;
            "PROB"*)
                # Вероятность
                if [[ $part =~ ^PROB[0-9]{2}$ ]]; then
                    local prob=${part:4:2}
                    echo -e "${PURPLE}🎲 Вероятность: ${prob}%${NC}"
                else
                    parse_taf_component "$part" "$current_section"
                fi
                ;;
            "TX"*|"TN"*)
                # Экстремальные температуры
                parse_temperature_extreme "$part"
                ;;
            *)
                # Обработка погодных компонентов
                parse_taf_component "$part" "$current_section"
                ;;
        esac
    done
}

# Функция для обработки экстремальных температур в TAF
parse_temperature_extreme() {
    local part=$1
    
    if [[ $part == TX* ]]; then
        # Максимальная температура
        local temp_part=${part:2}
        local temp=${temp_part%/*}
        local time=${temp_part#*/}
        time="${time:0:2}:${time:2:2}"
        
        if [[ ${temp:0:1} == "M" ]]; then
            local temp_value="-${temp:1}"
        else
            local temp_value="$temp"
        fi
        
        echo -e "${GREEN}🔥 Максимальная температура: ${temp_value}°C (в ${time}Z)${NC}"
        
    elif [[ $part == TN* ]]; then
        # Минимальная температура
        local temp_part=${part:2}
        local temp=${temp_part%/*}
        local time=${temp_part#*/}
        time="${time:0:2}:${time:2:2}"
        
        if [[ ${temp:0:1} == "M" ]]; then
            local temp_value="-${temp:1}"
        else
            local temp_value="$temp"
        fi
        
        echo -e "${BLUE}❄️  Минимальная температура: ${temp_value}°C (в ${time}Z)${NC}"
    fi
}

# Функция для обработки компонентов TAF
parse_taf_component() {
    local part=$1
    local section=$2
    
    # Используем существующие функции декодирования с небольшими модификациями
    
    # Ветер
    if [[ $part =~ ^[0-9]{5}(G[0-9]+)?(KT|MPS)$ ]] || [[ $part =~ ^VRB[0-9]{2}(G[0-9]+)?(KT|MPS)$ ]]; then
        if [[ $part == VRB* ]]; then
            local speed=$(echo "$part" | grep -o '[0-9]*' | head -1)
            local unit=$(echo "$part" | grep -o '[A-Z]*$')
            speed=$(echo "$speed" | sed 's/^0*//')
            speed=${speed:-0}
            if [[ $unit == "MPS" ]]; then
                echo -e "${GREEN}💨 Ветер: Переменный $speed м/с${NC}"
            else
                echo -e "${GREEN}💨 Ветер: Переменный $speed узлов${NC}"
            fi
        elif [[ $part == *"G"* ]]; then
            local dir=${part:0:3}
            local speed=${part:3:2}
            local gust=$(echo "$part" | grep -o 'G[0-9]*' | sed 's/G//')
            local unit=$(echo "$part" | grep -o '[A-Z]*$')
            dir=$(echo "$dir" | sed 's/^0*//')
            dir=${dir:-0}
            speed=$(echo "$speed" | sed 's/^0*//')
            speed=${speed:-0}
            gust=$(echo "$gust" | sed 's/^0*//')
            gust=${gust:-0}
            local direction_text=$(decode_wind_direction "$dir")
            if [[ $unit == "MPS" ]]; then
                echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed м/с с порывами до $gust м/с${NC}"
            else
                echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed узлов с порывами до $gust узлов${NC}"
            fi
        else
            local dir=${part:0:3}
            local speed=${part:3:2}
            local unit=${part:5}
            dir=$(echo "$dir" | sed 's/^0*//')
            dir=${dir:-0}
            speed=$(echo "$speed" | sed 's/^0*//')
            speed=${speed:-0}
            local direction_text=$(decode_wind_direction "$dir")
            if [[ $unit == "MPS" ]]; then
                echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed м/с${NC}"
            else
                local speed_kmh=$((speed * 2))
                echo -e "${GREEN}💨 Ветер: $direction_text ($dir°) $speed узлов (~$speed_kmh км/ч)${NC}"
            fi
        fi
    
    # Видимость (включая значения менее 1000 метров)
    elif [[ $part == "9999" ]] || [[ $part == "CAVOK" ]] || [[ $part =~ ^[0-9]{4}$ ]] || [[ $part =~ ^[0-9]{3}$ ]]; then
        if [[ $part == "CAVOK" ]]; then
            echo -e "${GREEN}👁 Видимость: Отличная (CAVOK)${NC}"
            echo -e "${GREEN}☁️  Облачность: Нет облаков ниже 5000 футов${NC}"
            echo -e "${GREEN}🌤 Погода: Нет значительных явлений${NC}"
        elif [[ $part == "9999" ]]; then
            echo -e "${GREEN}👁 Видимость: 10+ км (отличная видимость)${NC}"
        else
            local vis_text=$(decode_visibility "$part")
            echo -e "${GREEN}👁 Видимость: $vis_text${NC}"
        fi
    
    # Облачность
    elif [[ $part =~ ^(FEW|SCT|BKN|OVC|VV)[0-9]{3} ]]; then
        local cloud_text=$(decode_clouds "$part")
        echo -e "${CYAN}☁️  Облачность: $cloud_text${NC}"
    
    # Погодные явления
    elif is_weather_code "$part"; then
        local weather_text=$(decode_complex_weather "$part")
        echo -e "${YELLOW}🌧 Погодные явления: $weather_text${NC}"
    
    # Температура (для основной части TAF)
    elif [[ $part =~ ^[M]?[0-9]{2}/[M]?[0-9]{2}$ ]]; then
        parse_temperature "$part"
    
    # Давление
    elif [[ $part =~ ^Q[0-9]{4}$ ]]; then
        local pressure=${part:1}
        local pressure_mm=$((pressure * 3 / 4))
        echo -e "${GREEN}📊 Давление: $pressure гПа (~$pressure_mm мм рт.ст.)${NC}"
    
    else
        # Неизвестные коды в TAF
        echo -e "${YELLOW}❓ Неизвестный код TAF: $part${NC}"
    fi
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
    
    if [[ $# -eq 0 ]]; then
        echo "Использование: $0 [код ICAO]"
        echo "Пример: $0 UHWW"
        echo ""
        echo "Популярные коды:"
        echo "  UUEE - Шереметьево, Москва"
        echo "  UUWW - Внуково, Москва" 
        echo "  UHWW - Владивосток, Россия"
        echo "  UHPP - Елизово, Петропавловск-Камчатский"
        echo "  URSS - Сочи"
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
    
    # Выбор типа данных
    echo "Выберите тип данных:"
    echo "1. METAR (текущая погода)"
    echo "2. TAF (прогноз погоды)"
    read -p "Ваш выбор [1]: " data_type
    data_type=${data_type:-1}
    
    if [[ $data_type -eq 1 ]]; then
        # Получаем и декодируем METAR
        local metar=$(fetch_metar "$icao")
        if [[ -n "$metar" ]]; then
            parse_metar "$metar"
        else
            echo -e "${YELLOW}❌ Не удалось получить METAR для $icao${NC}"
            echo -e "${YELLOW}Проверьте:"
            echo -e "  • Соединение с интернетом"
            echo -e "  • Корректность кода ICAO"
            echo -e "  • Доступность метеосервисов${NC}"
            exit 1
        fi
    elif [[ $data_type -eq 2 ]]; then
        # Получаем и декодируем TAF
        local taf=$(fetch_taf "$icao")
        if [[ -n "$taf" ]]; then
            parse_taf "$taf"
        else
            echo -e "${YELLOW}❌ Не удалось получить TAF для $icao${NC}"
            echo -e "${YELLOW}Проверьте:"
            echo -e "  • Соединение с интернетом"
            echo -e "  • Корректность кода ICAO"
            echo -e "  • Доступность TAF для этого аэропорта${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Неверный выбор${NC}"
        exit 1
    fi
}

# Запуск скрипта
main "$@"