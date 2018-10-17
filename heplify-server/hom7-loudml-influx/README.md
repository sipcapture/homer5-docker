Homer 7, heplify-server, TICK Stack + LoudML
========

#### BETA VERSION! PLEASE REPORT BUGS AND IMPROVEMENTS

## Setup

```bash
docker-compose up -d
```

to bring up:  

* HEPlify-server localhost:9060 (hep-only)
* Homer localhost:9080 (admin/sipcapture) 
* TICK Stack
  * Chronograf localhost:9090 (admin/admin)
  * InfluxDB
  * Kapacitor
  * Telegraf
* LoudML

For an example, see https://www.youtube.com/watch?v=qP910YmFpeQ

## Notes
When dealing with prometheus counters in InfluxDB, refer to the following example usage of `difference` and `derivative` functions when selecting:
```
SELECT difference(last("counter")) AS "mean_counter" FROM "homer"."autogen"."heplify_method_response" WHERE time > :dashboardTime: GROUP BY time(:interval:), "method", "response" FILL(null)
```
```
SELECT derivative(last("counter")) AS "mean_counter" FROM "homer"."autogen"."heplify_method_response" WHERE time > :dashboardTime: GROUP BY time(:interval:), "method", "response" FILL(null)
```

![image](https://user-images.githubusercontent.com/1423657/40862016-705d998a-65eb-11e8-8b03-e711b7b4498d.png)
