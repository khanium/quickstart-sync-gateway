docker compose down
sqlite3 grafana.db '.clone grafana-new.db'
pushd /Users/josecortesdiaz/batcave/quickstart-sync-gateway/grafana/data
mv grafana.db grafana-old.db
mv grafana-new.db grafana.db
popd
bash cleanup-data.sh
docker compose up