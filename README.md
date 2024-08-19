# Panduan Instalasi Skrip BackupData

Skrip ini digunakan untuk membackup folder di direktori lokal ke Google Drive menggunakan rclone dan mengirimkan notifikasi status ke Discord melalui webhook. Berikut adalah petunjuk untuk menginstal dan menjalankan skrip ini.
![Screenshot](Screenshot_20240819-200133.png)

## Instalasi
1. **Upload Skrip**
   Upload skrip BackupData.sh di folder root server/vps Anda.
2. **Instalasi Dependensi**
   Install dependensi yabg dibutuhkan skrip ini di server/vps anda dengan mengetik:
  `sudo apt-get install curl tar rclone`
3. **Setup Rclone**
   Anda harus setup rclone di server/vps dan di komputer/hp anda
4. **Ubah Konfigurasi**
   Edit konfigurasi skrip BackupData.sh untuk menyesuaikan konfigurasi
5. **Beri Izin Eksekusi**
   Ubah izin file agar skrip dapat dijalankan:
   `chmod +x /root/BackupData.sh`
6. **Jalankan Skrip**
   Jalankab skrip dengan mengetik command:
   `bash /root/BackupData.sh`
7. **Setup Crontab**
   Ketik `crontab -e` lalu masukan kode:
   `0 0 * * * bash /root/BackupData.sh`
