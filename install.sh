#!/bin/bash

# =========================
# Auto Installer untuk Backup Script
# =========================

# Banner
echo "======================================="
echo "      Backup Script Auto Installer"
echo "             Versi V2.0"
echo "          by Odidak"
echo "======================================="

# Tanyakan input untuk konfigurasi
read -p "Masukkan nama remote rclone: " RCLONE_REMOTE_NAME
read -p "Masukkan nama folder di cloud (contoh: SistemBackup/BackupData): " GDRIVE_DIR
read -p "Masukkan direktori utama yang akan dibackup (contoh: /Folder/Yang/Dibackup): " BASE_DIR

read -p "Masukkan URL Discord webhook (kosongkan jika tidak menggunakan): " WEBHOOK_URL

# Excluded folders
echo "Masukkan nama folder yang akan dilewatkan (dipisah dengan spasi, kosongkan jika tidak ada):"
read -p "Contoh: Folder1 Folder2 Folder3: " EXCLUDED_FOLDERS

# Format Backup
echo "Pilih format backup:"
echo "1) zip"
echo "2) tar.gz"
echo "3) tgz"
read -p "Masukkan pilihan Anda (1/2/3): " BACKUP_FORMAT_CHOICE

case $BACKUP_FORMAT_CHOICE in
  1)
    BACKUP_FORMAT="zip"
    ;;
  2)
    BACKUP_FORMAT="tar.gz"
    ;;
  3)
    BACKUP_FORMAT="tgz"
    ;;
  *)
    echo "Pilihan tidak valid, menggunakan format default 'tar.gz'"
    BACKUP_FORMAT="tar.gz"
    ;;
esac

# Format Ukuran
echo "Pilih format ukuran yang ingin digunakan:"
echo "1) KB"
echo "2) MB"
echo "3) GB"
read -p "Masukkan pilihan Anda (1/2/3): " SIZE_FORMAT_CHOICE

case $SIZE_FORMAT_CHOICE in
  1)
    SIZE_FORMAT="KB"
    ;;
  2)
    SIZE_FORMAT="MB"
    ;;
  3)
    SIZE_FORMAT="GB"
    ;;
  *)
    echo "Pilihan tidak valid, menggunakan format default 'MB'"
    SIZE_FORMAT="MB"
    ;;
esac

# Jadwal crontab
read -p "Atur jadwal backup (format: menit jam * * * - contoh: 0 2 * * * untuk jam 2 pagi): " CRON_SCHEDULE

# Membuat folder BackupData
mkdir -p BackupData

# Membuat file config.sh
cat <<EOL > BackupData/config.sh
#!/bin/bash

# =========================
# Konfigurasi
# =========================

# Nama remote rclone
RCLONE_REMOTE_NAME="$RCLONE_REMOTE_NAME"

# Nama folder di cloud gdrive
GDRIVE_DIR="$GDRIVE_DIR"

# URL Discord webhook (jika kosong atau tidak valid, webhook tidak akan digunakan)
WEBHOOK_URL="$WEBHOOK_URL"

# Konfigurasi Embed Discord
TITLE_STATUS="Status BackupData"
TITLE_START="Status BackupData"
DESCRIPTION_START="Backup data dimulai."
DESCRIPTION_STATUS="Backup data selesai."
DESCRIPTION_FAIL_ALL="Backup data gagal karena semua folder gagal di-backup."
COLOR_START=3447003
COLOR_STATUS=3066993
COLOR_FAIL_ALL=15158332

# Konfigurasi Format ukuran
SIZE_FORMAT="$SIZE_FORMAT" # Bisa diubah ke KB, MB, GB

# Konfigurasi Format Backup
BACKUP_FORMAT="$BACKUP_FORMAT" # Pilih antara "zip", "tar.gz", atau "tgz"

# Konfigurasi Direktori/Folder
BASE_DIR="$BASE_DIR" # Direktori dasar yang berisi subfolder untuk dibackup

# Folder yang dikecualikan dari backup
EXCLUDE_FOLDERS=(${EXCLUDED_FOLDERS[@]})
EOL

# Membuat file backup.sh
cat <<'EOL' > BackupData/backup.sh
#!/bin/bash

# Memuat konfigurasi dari file config.sh
source "$(pwd)/BackupData/config.sh"

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

# Mengirim pemberitahuan mulai backup jika URL webhook tersedia
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

if [[ "$SUCCESS_COUNT" -eq 0 && "$FAIL_COUNT" -gt 0 ]]; then
  # Semua folder gagal di-backup
  if [[ -n "$WEBHOOK_URL" ]]; then
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{
               \"embeds\": [
                 {
                   \"title\": \"$TITLE_STATUS\",
                   \"description\": \"**[❌] | Status :** $DESCRIPTION_FAIL_ALL\",
                   \"color\": $COLOR_FAIL_ALL
                 }
               ]
             }" \
         "$WEBHOOK_URL"
  fi
else
  # Sebagian berhasil atau semuanya berhasil
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
fi

# Menghapus direktori sementara
rm -rf "$TEMP_DIR"
EOL

# Memberikan izin eksekusi untuk file backup.sh
chmod +x BackupData/backup.sh

# Membuat crontab
(crontab -l ; echo "$CRON_SCHEDULE bash $(pwd)/BackupData/backup.sh") | crontab -

# Menampilkan informasi selesai
echo "======================================="
echo "   Instalasi Selesai!"
echo " Script versi V2.0 buatan Odidak"
echo " Untuk menjalankan, gunakan perintah: bash $(pwd)/BackupData/backup.sh"
echo " Anda dapat mengedit konfigurasi di file: $(pwd)/BackupData/config.sh"
echo " Crontab telah diatur untuk menjalankan backup sesuai jadwal yang Anda tentukan."
echo "======================================="
