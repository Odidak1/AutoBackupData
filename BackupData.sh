#!/bin/bash

# Konfigurasi
# Nama remote rclone
RCLONE_REMOTE_NAME="NamaRemote"
# Nama folder di cloud gdrive
GDRIVE_DIR="SistemBackup/BackupData"
# Url discord webhook
WEBHOOK_URL=""

# Konfigurasi Embed Discord
# Title
TITLE_STATUS="Status BackupData"
TITLE_START="Status BackupData"
# Description
DESCRIPTION_START="Backup data dimulai."
DESCRIPTION_STATUS="Backup data selesai."

# Color
COLOR_START=3447003
COLOR_STATUS=3066993
# Status
SUCCESS_COUNT=0
FAIL_COUNT=0

# Konfigurasi Direktori
BASE_DIR="/Folder/Yang/Dibackup" # Direktori dasar yang berisi subfolder untuk dibackup, jika untuk PTERODACTYL gunakan /var/lib/pterodactyl/volumes
EXCLUDE_FOLDERS=("folder_lewati1" "folder_lewati2") # Daftar folder yang dikecualikan

# Konfigurasi Lanjutan
TEMP_DIR="/tmp/BackupData"


mkdir -p "$TEMP_DIR" || { echo "Gagal membuat direktori $TEMP_DIR"; exit 1; }

curl -H "Content-Type: application/json" \
     -X POST \
     -d "{
           \"embeds\": [
             {
               \"title\": \"$TITLE_START\",
               \"description\": \"**[⚒️] | Status :** $DESCRIPTION_START\",
               \"color\": $COLOR_START
             }
           ]
         }" \
     "$WEBHOOK_URL"

is_excluded() {
  local folder_name="$1"
  for excluded in "${EXCLUDE_FOLDERS[@]}"; do
    if [[ "$folder_name" == "$excluded" ]]; then
      return 0
    fi
  done
  return 1
}

for folder in "$BASE_DIR"/*; do
  if [ -d "$folder" ]; then
    FOLDER_NAME=$(basename "$folder")

    if is_excluded "$FOLDER_NAME"; then
      echo "Melewati folder $FOLDER_NAME"
      continue
    fi

    BACKUP_FILE="$TEMP_DIR/${FOLDER_NAME}_$(date +"%d-%m-%Y-%H:%M").tar.gz"

    if tar -czf "$BACKUP_FILE" -C / "$folder"; then
      if rclone copy "$BACKUP_FILE" "$RCLONE_REMOTE_NAME:$GDRIVE_DIR" --progress --transfers=4 --checkers=8; then
        rm "$BACKUP_FILE"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      else
        FAIL_COUNT=$((FAIL_COUNT + 1))
      fi
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  fi
done

curl -H "Content-Type: application/json" \
     -X POST \
     -d "{
           \"embeds\": [
             {
               \"title\": \"$TITLE_STATUS\",
               \"description\": \"**[✅] | Status :** $DESCRIPTION_STATUS\\n**[📋] | Berhasil:** $SUCCESS_COUNT\\n**[📋] | Gagal:** $FAIL_COUNT\",
               \"color\": $COLOR_STATUS
             }
           ]
         }" \
     "$WEBHOOK_URL"
rm -r "$TEMP_DIR"
