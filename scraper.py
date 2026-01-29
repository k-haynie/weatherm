import json, os, sys

latlng = ",".join(i[:7] for i in sys.argv[1].split(",") if i != ",")

hour_cutoff = min(int(sys.argv[2]), 155)

# use the lat_lng to find the govt api url to query
target_url = json.loads(os.popen(f"curl -s https://api.weather.gov/points/{sys.argv[1][:-1]}").read())["properties"]["forecastHourly"]

# in the style of:
# https://api.weather.gov/points/37.4137,-79.1424

# target url style:
# url = "https://api.weather.gov/gridpoints/RNK/102,79/forecast/hourly"

response = json.loads(os.popen(f"curl -s {target_url}").read())

output = ""

for i in response["properties"]["periods"][:hour_cutoff]:
    output += ",".join([
        '"' + i["startTime"][:19]+ '"',
        str(i["temperature"]),
        str(i["probabilityOfPrecipitation"]["value"]/100),
        i["shortForecast"],
        i["windSpeed"],
        i["windDirection"]
    ]) + "\n"

print(output)

