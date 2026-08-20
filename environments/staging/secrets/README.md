# staging/secrets/ — resolved secret material (NOT in git)

Same layout and perms as `prod/secrets/` (see that README), but populated from
each `*-cd` repo's `config/application-staging.yaml` using the **HPR** secret
set. Staging must point at the staging-suffixed database and Kafka topics and a
**distinct consumer group id** so it never consumes production's messages.

`app-config.json` → `API_GATEWAY_URL` = `http://api-gateway:8080` (this env's
own internal gateway; project isolation keeps it separate from prod's).
