# Cluster Link Troubleshooting and Tuning


## Mirroring Lag

## Promotion Issues

### Stuck due to offset sync issues
If due to the amount of admin requests and/or high numer of consumer groups the final offset sync is stuck. During a running promotion, this shows up with mirror topics
staying in a `PENDING_STOPPED` state:
```shell
kafka-mirrors \
  --describe \
  --topics <TOPIC> \
  --bootstrap-server <DESTINATION_BOOTSTRAP> \
  --command-config <CLIENT_CONFIG>

kafka-mirrors \
  --list-state-transition-errors \
  --topics <TOPIC> \
  --bootstrap-server <DESTINATION_BOOTSTRAP> \
  --command-config <CLIENT_CONFIG>
```
Manually check the offsets and then turn off offset sync for the existing link:
```shell
kafka-configs \
  --bootstrap-server <DESTINATION_BOOTSTRAP> \
  --command-config <CLIENT_CONFIG> \
  --alter \
  --cluster-link <LINK_NAME> \
  --add-config consumer.offset.sync.enable=false
```
Double-check the sync task status becomes `NOT_CONFIGURED`:
```shell
confluent kafka link task list <LINK_NAME> \
  --cluster <DESTINATION_CLUSTER_ID>
```

### Stuck due to offset commits on new cluster or config changes
Promotion can leve mirror topics in `PENDING_STOPPED` state if there are offset commits in the destination cluster before final sync. In that case, follow the docuimentation for sync issues above, stop any conflicting consumers and let the process continue.
As a last resort, check the topics and consumer groups manually and force failover:
```shell
kafka-mirrors \
  --failover \
  --topics <TOPIC> \
  --bootstrap-server <DESTINATION_BOOTSTRAP> \
  --command-config <CLIENT_CONFIG>

```

## Throttling / Rate-limiting

### Source-Side Throttling
Create a dedicated principal/service account for the link, then apply a Kafka client quota to that principal - e.g. 10MB/s:
```bash
kafka-configs \
  --bootstrap-server <source-bootstrap-server> \
  --command-config <admin-client.properties> \
  --alter \
  --add-config 'consumer_byte_rate=10485760' \
  --entity-type users \
  --entity-name <cluster-link-principal>
```
Monitor the following:
* fetch-throttle-time-avg/max
* Cluster Link MaxLag
* FetcherStats.BytesPerSec
* link-fetcher-throttled-partition-count

### Destination-Side Throttling
On the destination brokers, set the property - e.g. 10MB/s:
```properties
confluent.cluster.link.io.max.bytes.per.second=10485760
```

### Admin rate issues and limiting
The amount of admin client requests during offsets sync might reach a point where the number of parallel requests cannot be served by the source brokers before timing out. This can leave your mirror topcis in `PENDING_STOPPED` during promotion and show up as `INTERNAL_ERROR` when listing state-transition errors.
Consider batching and limiting - e.g.
```properties
confluent.cluster.link.admin.request.batch.size=100
confluent.cluster.link.admin.max.in.flight.requests=10
```