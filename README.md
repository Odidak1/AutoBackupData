# Panduan Instalasi Skrip BackupData

Skrip ini digunakan untuk membackup folder di direktori lokal ke Google Drive menggunakan rclone dan mengirimkan notifikasi status ke Discord melalui webhook. Berikut adalah petunjuk untuk menginstal dan menjalankan skrip ini.
![Screenshot](Screenshot_20240819-200133.png)

### 1. **Upload Skrip**
   Upload skrip BackupData.sh di folder root server/vps Anda.
### 2. **Instalasi Dependensi**
   Install dependensi yabg dibutuhkan skrip ini di server/vps anda dengan mengetik:
  `sudo apt-get install curl tar rclone`
### 3. **Setup Rclone**
   Anda harus mengonfigurasi rclone di server/VPS Anda. Ikuti panduan [rclone configuration](https://rclone.org/docs/) untuk menyiapkan remote dengan nama yang sesuai dengan konfigurasi.
### 4. **Ubah Konfigurasi**
   Edit konfigurasi skrip BackupData.sh untuk menyesuaikan konfigurasi
### 5. **Beri Izin Eksekusi**
   Ubah izin file agar skrip dapat dijalankan:
   `chmod +x /root/BackupData.sh`
### 6. **Jalankan Skrip**
   Jalankan skrip dengan mengetik command:
   `bash /root/BackupData.sh`
### 7. **Setup Crontab**
   Untuk menjalankan skrip secara otomatis, ketik `crontab -e` lalu masukkan baris berikut:
   `0 0,12 * * * bash /root/BackupData.sh`
