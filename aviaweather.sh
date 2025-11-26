#!/bin/bash

# AVIAWEATHER Decoder - совместимый с старыми версиями Bash
# Использование: ./aviaweather.sh UUWW

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
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
    local runway=${code:0:4}  # R34L
    local state=${code:5}     # 490233
    
    echo -e "${CYAN}🛬 ВПП ${runway}: "
    
    # Декодируем состояние ВПП по цифрам
    if [[ ${#state} -ge 6 ]]; then
        local deposit=${state:0:1}    # 4 - отложения
        local extent=${state:1:1}     # 9 - покрытие
        local depth=${state:2:2}      # 02 - глубина
        local friction=${state:4:2}   # 33 - трение
        
        case $deposit in
            "0") echo -n "Чистая и сухая" ;;
            "1") echo -n "Влажная" ;;
            "2") echo -n "Мокрая" ;;
            "3") echo -n "Иней/изморозь" ;;
            "4") echo -n "Сухой снег" ;;
            "5") echo -n "Мокрый снег" ;;
            "6") echo -n "Слякоть" ;;
            "7") echo -n "Лед" ;;
            "8") echo -n "Укатанный снег" ;;
            "9") echo -n "Замерзшие колеи" ;;
            "/") echo -n "Информация отсутствует" ;;
            *) echo -n "Неизвестное состояние" ;;
        esac
        
        echo -n ", покрытие: "
        case $extent in
            "1") echo -n "1-10%" ;;
            "2") echo -n "11-25%" ;;
            "5") echo -n "26-50%" ;;
            "9") echo -n "51-100%" ;;
            "/") echo -n "не указано" ;;
            *) echo -n "неизвестно" ;;
        esac
        
        if [[ $depth != "//" ]]; then
            echo -n ", глубина: ${depth}мм"
        fi
        
        if [[ $friction != "//" ]]; then
            echo -n ", трение: 0.${friction}"
        fi
    else
        echo -n "Информация о состоянии ВПП"
    fi
    
    echo -e "${NC}"
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

# Функция для проверки валидности кода ICAO
is_valid_icao() {
    local icao=$1
    [[ ${#icao} -eq 4 ]] && [[ "$icao" =~ ^[A-Z]{4}$ ]]
}

# Функция для обработки температуры
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
    
    # Расчет вероятности тумана
    local temp_num=$(echo "$temp" | sed 's/[^0-9-]//g')
    local dew_num=$(echo "$dew" | sed 's/[^0-9-]//g')
    
    if [[ "$temp" == -* ]] || [[ "$temp" == M* ]]; then
        temp_num="-$temp_num"
    fi
    if [[ "$dew" == -* ]] || [[ "$dew" == M* ]]; then
        dew_num="-$dew_num"
    fi
    
    # Преобразуем в числа для вычислений (убираем ведущие нули)
    temp_num=$(echo "$temp_num" | sed 's/^0*//')
    dew_num=$(echo "$dew_num" | sed 's/^0*//')
    temp_num=${temp_num:-0}
    dew_num=${dew_num:-0}
    
    local diff=$((temp_num - dew_num))
    if [[ $diff -lt 0 ]]; then
        diff=$(( -diff ))
    fi
    
    if [[ $diff -lt 3 ]]; then
        echo -e "${YELLOW}⚠️  Высокая вероятность тумана (малая разница температур)${NC}"
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

# Функция для разбора METAR
parse_metar() {
    local metar=$1
    echo -e "${CYAN}=== ДЕКОДИРОВАНИЕ METAR ===${NC}"
    echo -e "${WHITE}Исходный METAR: $metar${NC}"
    echo ""
    
    # Разбиваем на компоненты
    IFS=' ' read -ra parts <<< "$metar"
    
    for part in "${parts[@]}"; do
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
            
            # Ветер (исправленная обработка)
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
            
            # Информация о состоянии ВПП (Rxx/xxxxxx)
            R[0-9][0-9]*/*)
                decode_runway_state "$part"
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
            
            # QFE - давление на уровне аэродрома (формат QFE757/1009)
            QFE[0-9]*/*)
                local qfe_mm=${part:3:3}
                local qfe_hpa=${part:7}
                echo -e "${CYAN}📊 Давление на ВПП (QFE): $qfe_mm мм рт.ст. ($qfe_hpa гПа)${NC}"
                ;;
            
            # QFE - давление на уровне аэродрома (простой формат)
            QFE[0-9]*)
                local qfe_value=${part:3}
                echo -e "${CYAN}📊 Давление на ВПП (QFE): $qfe_value гПа${NC}"
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
                else
                    # Неизвестные коды
                    echo -e "${YELLOW}❓ Неизвестный код: $part${NC}"
                fi
                ;;
        esac
    done
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
}

# Запуск скрипта
main "$@"
