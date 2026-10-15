# sipcapture/homer-cron

Homer 5 MySQL rotation sidecar. Runs `homer_mysql_rotate.pl` on a daily cron schedule.

```bash
docker build -t sipcapture/homer-cron .
```

Requires the bootstrap semaphore volume and MySQL credentials from `homer.env`.
