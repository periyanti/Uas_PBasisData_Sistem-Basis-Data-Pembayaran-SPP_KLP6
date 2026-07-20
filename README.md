# Uas_PBasisData_Sistem-Basis-Data-Pembayaran-SPP_KLP6


**Anggota Kelompok 6:**

| Nama                     | NIM        |
|--------------------------|------------|
| Periyanti Rayo           | IK2411006  |
| Hijryanti                | IK2411015  |
| Hasriani                 | IK2411040  |
| Nur Afni Ishar           | IK2411046  |

---

## 📌 Deskripsi Projek

**Sistem Basis Data Pembayaran SPP** adalah projek tugas akhir mata kuliah Pemrograman Basis Data yang mengimplementasikan sistem manajemen pembayaran SPP (Sumbangan Pembinaan Pendidikan) sekolah. Sistem ini dirancang menggunakan **MySQL/MariaDB** dan mencakup manajemen transaksi, exception handling, stored procedure, function, trigger, cursor, serta optimasi query menggunakan index.

Database ini memungkinkan pengelolaan data siswa, kelas, tahun ajaran, tagihan SPP, pembayaran, hingga pencatatan log audit secara otomatis dan aman.

---

## 🗄️ DBMS yang Digunakan

- MySQL / MariaDB (disarankan dijalankan melalui **XAMPP**)

---

## 🧩 Struktur Basis Data

Database bernama `db_pembayaran_spp` terdiri dari tabel-tabel berikut:

| Tabel          | Keterangan                                                       |
|----------------|-------------------------------------------------------------------|
| `kelas`        | Menyimpan data kelas dan tingkat                                  |
| `siswa`        | Menyimpan data siswa beserta status keaktifan                     |
| `petugas`      | Menyimpan data admin/bendahara yang menginput pembayaran          |
| `tahun_ajaran` | Menyimpan nominal SPP per tahun ajaran dan semester                |
| `tagihan_spp`  | Menyimpan tagihan SPP bulanan tiap siswa                          |
| `pembayaran`   | Mencatat transaksi pembayaran SPP                                 |
| `audit_log`    | Mencatat riwayat perubahan data (audit trail) secara otomatis     |

### Relasi Antar Tabel

- `siswa.id_kelas` → `kelas.id_kelas`
- `tagihan_spp.id_siswa` → `siswa.id_siswa`
- `tagihan_spp.id_tahun` → `tahun_ajaran.id_tahun`
- `pembayaran.id_tagihan` → `tagihan_spp.id_tagihan`
- `pembayaran.id_petugas` → `petugas.id_petugas`

---

## ⚙️ Fitur Utama

### 1. Stored Procedure

| Procedure                          | Fungsi                                                                 |
|-------------------------------------|-------------------------------------------------------------------------|
| `sp_generate_tagihan_bulanan`       | Membuat tagihan SPP untuk seluruh siswa aktif menggunakan **CURSOR**    |
| `sp_proses_pembayaran`              | Memproses pembayaran dengan **transaction control** (`COMMIT`/`ROLLBACK`) dan validasi |
| `sp_batalkan_pembayaran`            | Membatalkan pembayaran menggunakan **SAVEPOINT**                        |
| `sp_laporan_pembayaran_periode`     | Menampilkan laporan pembayaran berdasarkan rentang tanggal               |
| `sp_rekap_denda_terlambat`          | Merekap total denda keterlambatan per siswa menggunakan **CURSOR**       |

### 2. Function

| Function                     | Fungsi                                                             |
|-------------------------------|-----------------------------------------------------------------------|
| `fn_hitung_denda`             | Menghitung denda keterlambatan (Rp 5.000/hari)                        |
| `fn_cek_status_tagihan`       | Menentukan status tagihan (Lunas / Belum Lunas / Terlambat)           |
| `fn_total_tunggakan_siswa`    | Menghitung total tunggakan (nominal + denda) seorang siswa            |

### 3. Trigger

| Trigger                           | Jenis                | Fungsi                                                             |
|-------------------------------------|-----------------------|-----------------------------------------------------------------------|
| `trg_validasi_pembayaran`          | Validasi (BEFORE INSERT) | Menolak input pembayaran yang kosong atau negatif                   |
| `trg_after_insert_pembayaran`      | Perubahan otomatis (AFTER INSERT) | Mengubah status tagihan menjadi `lunas` setelah pembayaran sukses |
| `trg_audit_tagihan`                | Audit (AFTER UPDATE)   | Mencatat perubahan status pada tabel `tagihan_spp`                   |
| `trg_audit_pembayaran`             | Audit (AFTER UPDATE)   | Mencatat perubahan status pada tabel `pembayaran`                    |

### 4. Transaction Control

Sistem mengimplementasikan `START TRANSACTION`, `COMMIT`, `ROLLBACK`, dan `SAVEPOINT` untuk menjaga konsistensi data, terutama pada proses pembayaran dan pembatalan pembayaran.

### 5. Exception Handling

Menggunakan `SIGNAL SQLSTATE`, `DECLARE EXIT HANDLER FOR SQLEXCEPTION`, dan `RESIGNAL` untuk menangani error seperti:
- Data tidak ditemukan
- Input tidak valid (kosong/negatif)
- Tagihan yang sudah lunas dibayar ulang
- Jumlah pembayaran kurang dari total tagihan + denda

### 6. Indexing & Optimasi Query

Index dibuat pada kolom foreign key untuk mempercepat proses pencarian data:
```sql
CREATE INDEX idx_tagihan_siswa ON tagihan_spp(id_siswa);
CREATE INDEX idx_pembayaran_tagihan ON pembayaran(id_tagihan);
```
Penggunaan `EXPLAIN` menunjukkan bahwa tipe akses berubah dari *full table scan* (`ALL`) menjadi pencarian melalui index (`ref`), sehingga jumlah baris yang diperiksa berkurang signifikan.

---

## 🚀 Cara Menjalankan

1. Buka **phpMyAdmin** atau **MySQL client** melalui XAMPP.
2. Import atau jalankan file `sistem_pembayaran_spp.sql` secara berurutan dari awal hingga akhir.
3. Database `db_pembayaran_spp` beserta seluruh tabel, data dummy, stored procedure, function, dan trigger akan terbentuk otomatis.

### Contoh Pemanggilan Procedure & Function

```sql
-- Membuat tagihan bulan Agustus untuk seluruh siswa aktif
CALL sp_generate_tagihan_bulanan(1, 'Agustus', '2025-08-10');

-- Memproses pembayaran SPP
CALL sp_proses_pembayaran(1, 1, 250000.00, 'tunai');

-- Membatalkan pembayaran
CALL sp_batalkan_pembayaran(1);

-- Menampilkan laporan pembayaran periode tertentu
CALL sp_laporan_pembayaran_periode('2025-07-01', '2025-07-31');

-- Merekap denda keterlambatan
CALL sp_rekap_denda_terlambat();

-- Menghitung denda suatu tagihan
SELECT fn_hitung_denda(2);

-- Mengecek status suatu tagihan
SELECT fn_cek_status_tagihan(2);

-- Menghitung total tunggakan siswa
SELECT fn_total_tunggakan_siswa(2);

-- Melihat log audit
SELECT * FROM audit_log;
```

---

## 📂 Struktur File

```
├── sistem_pembayaran_spp.sql   # Script lengkap: database, tabel, data dummy,
│                                 stored procedure, function, trigger, index
└── README.md                    # Dokumentasi projek
```

---

## 📝 Catatan

- Password pada tabel `petugas` bersifat contoh (dummy) dan belum di-hash menggunakan algoritma keamanan yang sesungguhnya; pada implementasi nyata wajib menggunakan hashing seperti bcrypt.
- Denda keterlambatan dihitung otomatis sebesar Rp 5.000 per hari melalui `fn_hitung_denda`.
- Seluruh perubahan status tagihan dan pembayaran tercatat otomatis pada tabel `audit_log` melalui trigger.
