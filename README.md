* Configure the file generated in cfg/sourcemod

* You can add your links (one per line) with advertisements in addons/sourcemod/configs/franug_adverts.txt (MAX 10 LINKS)

* Add a entry in databases.cfg
```
"multiadvers"
{
"driver" "sqlite"
"database" "multiadvers"
} 
```


You can add the following words to the links for auto replace:
```
{NAME} - Name of the client that view the advert
{IP} - Ip of your server
{PORT} - Port of your server
{STEAMID} - steamid of the client that view the advert
{GAME} - Game directory
```

You can set each X seconds reproduce that link and if show in background or no.
```
<link> <time> <yes|no>
```

Example links for motdgd:
```
http://motdgd.com/motd/?user=10696&ip={IP}&pt={PORT}&v=2.5.2&st={STEAMID}&gm={GAME}&name={NAME} 650 no
```

Example link for pinion:
```
http://motd.pinion.gg/motd/playelectronicsports/{GAME}/motd.html 650 no
```

Example link for vppgamingnetwork:
```
http://vppgamingnetwork.com/Client/Content/1288 650 no
```