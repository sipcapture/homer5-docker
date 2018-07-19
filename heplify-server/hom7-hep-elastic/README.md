Homer 7, heplify-server, Elastic stack
========

#### BETA VERSION! PLEASE REPORT BUGS AND IMPROVEMENTS

## Setup

```bash
docker-compose up
```

to bring up:  

* HEPlify-server localhost:9060 (hep-only)
* Homer localhost:9080 (admin/test123) 
* Kibana localhost:9090 (admin/admin)
  * Elasticsearch (hep-*)
  * Telegraf

### Notes
#### Timelion CPS and RPS
The following Timelion expression can be used to graph CPS and RPS from HOMER statistics stored in Elasticsearch:
```
 .es(index=hepmetrics-, timefield=@timestamp,q='measurement_name:"heplify_method_response" AND tag.method:"REGISTER" AND tag.response:"200"', metric=max:heplify_method_response.counter).derivative().abs().mvavg(1m).scale_interval(1s).yaxis(min=0).color(orange).lines(fill=2,width=1).label("RPS").legend(position=nw,showTime=true), .es(index=hepmetrics-, timefield=@timestamp,q='measurement_name:"heplify_method_response" AND tag.method:"INVITE" AND tag.response:"200"', metric=max:heplify_method_response.counter).derivative().mvavg(1m).scale_interval(1s).yaxis(min=0).color(green).lines(fill=1,width=1).label("CPS")
 ```
 <img src="https://user-images.githubusercontent.com/39862433/42957981-366a966a-8b52-11e8-81fc-a8d386153f1d.png">
