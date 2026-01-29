#!/bin/sh 

# depends on python, json, os, and feedgnuplot

zip="$1"
hours="$2"

# color codes: https://i.sstatic.net/9UVnC.png
ansi_reset="\033[0m"
ansi_green="\033[92m"
ansi_orange="\033[33m"
ansi_red="\033[31m"

# wanrs against invalid zip codes
if [ "${#1}" != 5 ] || ! [[ "$1" =~ [0-9]{5} ]]; then 
    echo "First argument must use a five-digit zip code."
    exit
fi;

if (( "$hours" > 155 )) ; then
    echo "Second argument must use a 1-155 future hour scale."
    exit
fi;

clear
echo -e "$ansi_green▓▓▓▓▓╣   ⏾   Weatherm   ⚡  ╠▓▓▓▓▓$ansi_reset"
echo -e "  1)$ansi_red Zip Code: $zip... $ansi_reset"

latlng=$(curl -s "https://nominatim.openstreetmap.org/search?postalcode=$zip&country=US&format=json&limit=1&addressdetails=1" | sed -E 's/,/\n/g' | grep -Eo "^\"(lat|lon)\":\"-?[0-9]+\.[0-9]+\"" | grep -Eo "(-)?[0-9]+\.([0-9]{4})" | tr -s '\n', ',')

echo -e "  2)$ansi_orange LatLng: $latlng...$ansi_reset"

# output contains several columns:
# 1. DateTime of Forecast
# 2. Temperature
# 3. % probability of precipitation
# 4. short forecast 
# 5. detailed forecast 
# 6. wind speed (and mph)
# 7. wind direction
output=`python scraper.py "$latlng" $hours`

metadata=`echo "$output" | head -n 1`

limited_output=`echo -E "$output" | tail -n +2 | head -n $hours | awk -F ',' '{ print $1 " " $2 " " $3 }'`

# -- find the temps --  
temps=`echo -E "$output" | grep -E "^\"" | awk -F ',' '{print $2}' | sort -n`
min_temp=`echo -E "$temps" | head -n 1 | xargs -I{} bash -c "echo '{} - 5'| bc"`
max_temp=`echo -E "$temps" | tail -n 1 | xargs -I{} bash -c "echo '{} + 5'| bc"`

# -- find the precipitation likelihood --
prec=`echo -E "$output" | grep -E "^\"" | awk -F ',' '{print $3}' | sort -n`
min_prec=`echo -E "$prec" | head -n 1 | xargs -I{} bash -c "echo '{} - 0.05'| bc"`
max_prec=`echo -E "$prec" | tail -n 1 | xargs -I{} bash -c "echo '{} + 0.05'| bc"`

shortForecast=`echo -E "$output" | grep -E "^\"" | awk -F ',' '{print $4}' | sort -n`
wind=`echo -E "$output" | grep -E "^\"" | awk -F ',' '{print $5 " " $6}' | sort -n`

table=`echo -E "$output" | tail -n +2 \
    | grep -E "^\"" \
    | head -n "$hours" \
    | awk -F ',' '
        BEGIN {
            sunny = "\033[93m ◯ "
            yellow = "\033[91m"
            cloudy = "\033[36m ≋ "
            rain = "\033[34m ∴ "
            snow = "\033[1;37m ✶ "
            clear = "\033[27m ⍜ "
            reset = "\033[0m"
            green = "\033[32m"
            n = "↑"
            nw = "↖"
            w = "←"
            ne = "↗"
            e = "→"
            s = "↓"
            se = "↘"
            sw = "↙"
        }
        { print green }
        { system("date -d" $1 " +%a_%I_%p") }
        { print reset "," yellow $2 reset "°F," "\033[36m" $3 reset " %," }
        { 
            if (index($4, "Sunny") > 0) { c = sunny }
            else if (index($4, "Cloudy") > 0) { c = cloudy }
            else if (index($4, "Clear") > 0) { c = clear }
            else if (index($4, "Rain") > 0) { c = rain }
            else if (index($4, "Snow") > 0 || index($4, "Ice") > 0) { c = snow }
            else { c = reset }
            printf "%s%s%s", c, $4, reset
        }
        {
            if (index($6, "NE") > 0) { d = ne } 
            else if (index($6, "NW") > 0) { d = nw }
            else if (index($6, "SE") > 0) { d = se }
            else if (index($6, "SW") > 0) { d = sw }
            else if (index($6, "N") == 1) { d = n }
            else if (index($6, "W") > 0) { d = w }
            else if (index($6, "E") > 0) { d = e }
            else { d = s }

            print ",\033[34m" d " " $5 " " $6 reset
        }' \
    | tr -s '\n' ':' \
    | sed -E 's/0.0 /0 /g; s/-,/,/g; s/_/ /g; s/([A-Z])-/\1/g; s/:([A-Z])/\n\1/g; s/://g;s/0\.0?//g' \
    | column -s ',' -o '   ' -t \
    --table-columns " Time of Day,Temp,Precip,Description,Wind" \
    --table-right 1,2,3 | sed -E 's/(\s+[A-Z][a-z]{2} 12 AM)/\n\1/g'`

# echo "$output" > output.txt
# echo -E "$min_temp" "$max_temp" "$min_prec" "$max_prec"
descs=`echo -E "$output" | grep -E "^\"" | awk '{print $4}'`

# -- find the current terminal size --
rows=`tput lines | xargs -I{} bash -c "echo {} / 1.5 | bc"`
cols=`tput cols | xargs -I{} bash -c "echo {} - 2 | bc"`

# -- output the graph
graph=`echo -e "$limited_output"| feedgnuplot \
    --domain \
    --y2 1 \
    --terminal "dumb $cols,$rows ansi enhanced" \
    --lines --points \
    --unset grid \
    --timefmt '"%Y-%m-%dT%H:%M:%S"'\
    --set 'format x "%a\n%I %p"' \
    --title "$hours-hour Forecast" \
    --xlabel "\nTime of Day" \
    --ylabel "Temp" \
    --y2label " Precip\n Chance" \
    --legend "Degrees (°F)" 1\
    --legend "Precip (%)" 2\
    --ymin 0 --ymax "$max_temp" \
    --y2min 0 --y2max "$max_prec" \
    --legend 0 "Temp" \
    --legend 1 "Precip" \
    --exit`

echo -e "  3)$ansi_green $metadata$ansi_reset"
sleep 1

echo -e "\n\n$table$graph"
