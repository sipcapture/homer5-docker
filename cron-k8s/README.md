# Homer cron image for Kubernetes

Use this image as the container for a Kubernetes `CronJob` that runs Homer MySQL table rotation.

## Example

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: homer-mysql-rotate
spec:
  schedule: "30 3 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: homer-cron
              image: sipcapture/homer-cron-k8s:latest
              envFrom:
                - secretRef:
                    name: homer-mysql
              env:
                - name: DB_HOST
                  value: mysql.example.svc.cluster.local
                - name: TZ
                  value: Europe/Berlin
```

The container waits for the bootstrap semaphore volume (same as the compose `cron` service), applies `rotation.ini` from environment variables, and runs `/opt/homer_mysql_rotate.pl`.

See https://github.com/sipcapture/homer5-docker/issues/61
