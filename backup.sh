echo "-- create backup --"
echo -e "custom tag"
read tag

echo $(date)

creation_date=$(date +"%Y%m%d")
backup_path="backup/data_$creation_date$tag.pack"
data_path="data/"

echo "-- creating backup --"
tar -zcf $backup_path $data_path

echo "-- backup ready --"

