#!/bin/sh 

# depends on python, json, os, and feedgnuplot

zip="$1"
hours="$2"
summary="$3"

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

if ! [[ "$3" =~ (yes|no) ]]; then
    echo "Third argument must be yes for summary or no for details."
    exit
fi;

# clear
echo -e "\n$ansi_green▓▓▓▓▓╣   ⏾   Weatherm   ⚡  ╠▓▓▓▓▓$ansi_reset"
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

# make this a single script by embedding some python
python_code=$(cat << EOF
import json, os, sys

# variables
latlng = ",".join(i[:7] for i in sys.argv[1].split(",") if i != ",")
summary=(sys.argv[3] == "yes")
hour_cutoff = min(int(sys.argv[2]), 13 if summary else 155)

# use the lat_lng to find the govt api url to query
info = json.loads(os.popen(f"curl -s https://api.weather.gov/points/{sys.argv[1][:-1]}").read())

# in the style of:
# https://api.weather.gov/points/37.4137,-79.1424
# https://api.weather.gov/gridpoints/RNK/102,79/forecast/hourly

location = info["properties"]["relativeLocation"]["properties"]
loc_str = f'{location["city"]}, {location["state"]}'
output = f"{loc_str}\n"

if not summary:
    target_url = info["properties"]["forecastHourly"]
    response = json.loads(os.popen(f"curl -s {target_url}").read())

    for i in response["properties"]["periods"][:hour_cutoff]:
        output += ",".join([
            '"' + i["startTime"][:19]+ '"',
            str(i["temperature"]),
            str(i["probabilityOfPrecipitation"]["value"]/100),
            i["shortForecast"],
            i["windSpeed"],
            i["windDirection"],
            ""
        ]) + "\n"
else:
    target_url = info["properties"]["forecast"]
    response = json.loads(os.popen(f"curl -s {target_url}").read())

    for i in response["properties"]["periods"][:hour_cutoff]:
        output += ",".join([
            '"' + i["startTime"][:19]+ '"',
            str(i["temperature"]),
            str(i["probabilityOfPrecipitation"]["value"]/100),
            i["shortForecast"],
            i["windSpeed"],
            i["windDirection"],
            i["detailedForecast"].replace(",", " ")
        ]) + "\n"

print(output)
EOF
)

output=`python -c "$python_code" "$latlng" $hours $summary`

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

table_cols=" Time of Day,Temp,Description"
table_align="1,2"

if [[ "$3" =~ (no) ]]; then
    table_cols=" Time of Day,Temp,Precip,Description,Wind"
    table_align="1,2,3"
fi;

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
        { print reset "," yellow $2 reset "°F," }
        { 
            if (length($7) == 0) {
                print "\033[36m" $3 reset " %," 
            }
        }
        {
            if (length($7) == 0) { str = $4 }
            else { str = $7 }

            if (index(toupper(str), "SUNNY") > 0) { c = sunny }
            else if (index(toupper(str), "CLOUD") > 0) { c = cloudy }
            else if (index(toupper(str), "CLEAR") > 0) { c = clear }
            else if (index(toupper(str), "RAIN") > 0) { c = rain }
            else if (index(toupper(str), "SNOW") > 0 || index(toupper(str), "ICE") > 0) { c = snow }
            else { c = reset }
            printf "%s%s%s", c, str, reset
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

            if (length($7) == 0)
            {
                print ",\033[34m" d " " $5 " " $6 reset
            }
        }' \
    | tr -s '\n' ':' \
    | sed -E 's/0.0 /0 /g; s/-,/,/g; s/_/ /g; s/([A-Z])-/\1/g; s/:([A-Z])/\n\1/g; s/://g;s/0\.0?//g' \
    | column -s ',' -o '   ' -t \
    --table-columns "$table_cols" \
    --table-right $table_align | sed -E 's/(\s+[A-Z][a-z]{2} 12 AM)/\n\1/g'`

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

echo -e "\n\n$table"
if [[ "$3" =~ (no) ]]; then
   echo -e "$graph"
else
    echo
fi;
