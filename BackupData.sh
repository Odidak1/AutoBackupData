#!/bin/bash

# =========================
# Konfigurasi
# =========================

# Nama remote rclone
RCLONE_REMOTE_NAME="NamaRemote"

# Nama folder di cloud gdrive
GDRIVE_DIR="SistemBackup/BackupData"

# URL Discord webhook (jika kosong atau tidak valid, webhook tidak akan digunakan)
WEBHOOK_URL=""

# Konfigurasi Embed Discord
TITLE_STATUS="Status BackupData"
TITLE_START="Status BackupData"
DESCRIPTION_START="Backup data dimulai."
DESCRIPTION_STATUS="Backup data selesai."
COLOR_START=3447003
COLOR_STATUS=3066993

# Konfigurasi Format ukuran
SIZE_FORMAT="MB" # Bisa diubah ke KB, MB, GB

# Konfigurasi Format Backup
BACKUP_FORMAT="tar.gz" # Pilih antara "zip", "tar.gz", atau "tgz"

# Konfigurasi Direktori/Folder
BASE_DIR="/Folder/Yang/Dibackup" # Direktori dasar yang berisi subfolder untuk dibackup
EXCLUDE_FOLDERS=("Contoh1") # Folder yang dilewat


# =========================
# Skrip Utama | Jangan disentuh
# =========================
TEMP_DIR="/tmp/BackupData"
DATE_DIR=$(date +"%d-%m-%Y_%H:%M:%S")
GDRIVE_DATE_DIR="$GDRIVE_DIR/$DATE_DIR"

mkdir -p "$TEMP_DIR" || { echo "Gagal membuat direktori $TEMP_DIR"; exit 1; }
if ! rclone lsf "$RCLONE_REMOTE_NAME:$GDRIVE_DIR" | grep -q "$DATE_DIR"; then
  if ! rclone mkdir "$RCLONE_REMOTE_NAME:$GDRIVE_DATE_DIR"; then
    echo "Gagal membuat folder $GDRIVE_DATE_DIR di Google Drive"
    exit 1
  fi
fi

if [[ -n "$WEBHOOK_URL" ]]; then
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
fi

is_excluded() {
  local folder_name="$1"
  for excluded in "${EXCLUDE_FOLDERS[@]}"; do
    if [[ "$folder_name" == "$excluded" ]]; then
      return 0
    fi
  done
  return 1
}

convert_size() {
  local size=$1
  case "$SIZE_FORMAT" in
    KB)
      echo "scale=2; $size / 1024" | bc
      ;;
    MB)
      echo "scale=2; $size / 1024 / 1024" | bc
      ;;
    GB)
      echo "scale=2; $size / 1024 / 1024 / 1024" | bc
      ;;
    *)
      echo "Invalid format"
      return 1
      ;;
  esac
}

backup_folder() {
  local folder="$1"
  local backup_file="$2"

  case "$BACKUP_FORMAT" in
    zip)
      zip -r "$backup_file" "$folder"
      ;;
    tar.gz)
      tar -czf "$backup_file" "$folder"
      ;;
    tgz)
      tar -czf "$backup_file" "$folder"
      ;;
    *)
      echo "Format backup tidak valid!"
      return 1
      ;;
  esac
}

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_FOLDERS=""
TOTAL_SIZE=0

for folder in "$BASE_DIR"/*; do
  if [ -d "$folder" ]; then
    FOLDER_NAME=$(basename "$folder")

    if is_excluded "$FOLDER_NAME"; then
      echo "Melewati folder $FOLDER_NAME"
      continue
    fi

    BACKUP_FILE="$TEMP_DIR/${FOLDER_NAME}.$BACKUP_FORMAT"

    if backup_folder "$folder" "$BACKUP_FILE"; then
      FILE_SIZE=$(stat -c%s "$BACKUP_FILE")
      TOTAL_SIZE=$((TOTAL_SIZE + FILE_SIZE))

      if rclone copy "$BACKUP_FILE" "$RCLONE_REMOTE_NAME:$GDRIVE_DATE_DIR/${FOLDER_NAME}.$BACKUP_FORMAT" --progress --transfers=4 --checkers=8; then
        rm "$BACKUP_FILE"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_FOLDERS+="- $FOLDER_NAME\\n"
      fi
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      FAILED_FOLDERS+="- $FOLDER_NAME\\n"
    fi
  fi
done

FAILED_FOLDERS=$(echo -e "$FAILED_FOLDERS" | sed '/^$/d')

if [ -z "$FAILED_FOLDERS" ]; then
  FAILED_FOLDERS="null"
fi

TOTAL_SIZE_FORMATTED=$(convert_size "$TOTAL_SIZE")

if [[ -n "$WEBHOOK_URL" ]]; then
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{
             \"embeds\": [
               {
                 \"title\": \"$TITLE_STATUS\",
                 \"description\": \"**[✅] | Status :** $DESCRIPTION_STATUS\\n**[📋] | Berhasil:** $SUCCESS_COUNT\\n**[📋] | Gagal:** $FAIL_COUNT\\n**[📊] | Total Size:** ${TOTAL_SIZE_FORMATTED} $SIZE_FORMAT\\n**[📂] | Folder Gagal:** $FAILED_FOLDERS\",
                 \"color\": $COLOR_STATUS
               }
             ]
           }" \
       "$WEBHOOK_URL"
fi

rm -r "$TEMP_DIR"
