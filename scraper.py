import json, os

url = "https://api.weather.gov/gridpoints/RNK/102,79/forecast/hourly"

response = json.loads(os.popen(f"curl -s {url}").read())

output = ""

for i in response["properties"]["periods"][:24]:
    output += ",".join([
        '"' + i["startTime"][:19]+ '"',
        str(i["temperature"]),
        str(i["probabilityOfPrecipitation"]["value"]/100),
        i["shortForecast"],
        i["windSpeed"],
        i["windDirection"]
    ]) + "\n"

print(output)

