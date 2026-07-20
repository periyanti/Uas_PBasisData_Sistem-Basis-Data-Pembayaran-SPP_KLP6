-- =====================================================================
-- PROJEK TUGAS AKHIR - PEMROGRAMAN BASIS DATA
-- Judul   : Sistem Basis Data Pembayaran SPP dengan Manajemen Transaksi
--           dan Exception Handling
-- DBMS    : MySQL / MariaDB (XAMPP)
-- =====================================================================


-- =====================================================================
-- 1. CREATE DATABASE
-- =====================================================================
DROP DATABASE IF EXISTS db_pembayaran_spp;
CREATE DATABASE db_pembayaran_spp;
USE db_pembayaran_spp;


-- =====================================================================
-- 2. CREATE TABLE (Desain Basis Data)
-- =====================================================================

-- Tabel kelas
CREATE TABLE kelas (
    id_kelas    INT AUTO_INCREMENT PRIMARY KEY,
    nama_kelas  VARCHAR(20) NOT NULL UNIQUE,
    tingkat     INT NOT NULL CHECK (tingkat BETWEEN 1 AND 12)
);

-- Tabel siswa
CREATE TABLE siswa (
    id_siswa      INT AUTO_INCREMENT PRIMARY KEY,
    nis           VARCHAR(20) NOT NULL UNIQUE,
    nama          VARCHAR(100) NOT NULL,
    id_kelas      INT NOT NULL,
    alamat        VARCHAR(255),
    no_hp         VARCHAR(15),
    status_aktif  ENUM('aktif','nonaktif') NOT NULL DEFAULT 'aktif',
    CONSTRAINT fk_siswa_kelas FOREIGN KEY (id_kelas)
        REFERENCES kelas(id_kelas)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Tabel petugas (bendahara/admin yang input pembayaran)
CREATE TABLE petugas (
    id_petugas  INT AUTO_INCREMENT PRIMARY KEY,
    nama        VARCHAR(100) NOT NULL,
    username    VARCHAR(50) NOT NULL UNIQUE,
    password    VARCHAR(255) NOT NULL,
    role        ENUM('admin','bendahara') NOT NULL DEFAULT 'bendahara'
);

-- Tabel tahun_ajaran (menyimpan nominal SPP per periode)
CREATE TABLE tahun_ajaran (
    id_tahun     INT AUTO_INCREMENT PRIMARY KEY,
    tahun        VARCHAR(9) NOT NULL,           -- contoh: 2025/2026
    semester     ENUM('ganjil','genap') NOT NULL,
    nominal_spp  DECIMAL(10,2) NOT NULL CHECK (nominal_spp > 0),
    UNIQUE KEY uq_tahun_semester (tahun, semester)
);

-- Tabel tagihan_spp
CREATE TABLE tagihan_spp (
    id_tagihan    INT AUTO_INCREMENT PRIMARY KEY,
    id_siswa      INT NOT NULL,
    id_tahun      INT NOT NULL,
    bulan         VARCHAR(15) NOT NULL,          -- contoh: Januari
    nominal       DECIMAL(10,2) NOT NULL CHECK (nominal > 0),
    jatuh_tempo   DATE NOT NULL,
    status        ENUM('belum_lunas','lunas','terlambat') NOT NULL DEFAULT 'belum_lunas',
    CONSTRAINT fk_tagihan_siswa FOREIGN KEY (id_siswa)
        REFERENCES siswa(id_siswa) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_tagihan_tahun FOREIGN KEY (id_tahun)
        REFERENCES tahun_ajaran(id_tahun) ON UPDATE CASCADE ON DELETE RESTRICT,
    UNIQUE KEY uq_tagihan (id_siswa, id_tahun, bulan)
);

-- Tabel pembayaran
CREATE TABLE pembayaran (
    id_pembayaran     INT AUTO_INCREMENT PRIMARY KEY,
    id_tagihan        INT NOT NULL,
    id_petugas        INT NOT NULL,
    tanggal_bayar     DATE NOT NULL DEFAULT (CURRENT_DATE),
    jumlah_bayar      DECIMAL(10,2) NOT NULL CHECK (jumlah_bayar > 0),
    metode_bayar      ENUM('tunai','transfer') NOT NULL DEFAULT 'tunai',
    status_pembayaran ENUM('sukses','dibatalkan') NOT NULL DEFAULT 'sukses',
    CONSTRAINT fk_pembayaran_tagihan FOREIGN KEY (id_tagihan)
        REFERENCES tagihan_spp(id_tagihan) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_pembayaran_petugas FOREIGN KEY (id_petugas)
        REFERENCES petugas(id_petugas) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Tabel audit_log
CREATE TABLE audit_log (
    id_log      INT AUTO_INCREMENT PRIMARY KEY,
    nama_tabel  VARCHAR(50) NOT NULL,
    aksi        VARCHAR(10) NOT NULL,           -- INSERT / UPDATE / DELETE
    data_lama   TEXT,
    data_baru   TEXT,
    waktu_aksi  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_db     VARCHAR(100)
);


-- =====================================================================
-- 3. INSERT DATA DUMMY
-- =====================================================================

INSERT INTO kelas (nama_kelas, tingkat) VALUES
('7A', 7), ('8A', 8), ('9A', 9);

INSERT INTO siswa (nis, nama, id_kelas, alamat, no_hp, status_aktif) VALUES
('2025001','Andi Saputra',1,'Jl. Melati No.1','081234560001','aktif'),
('2025002','Bunga Lestari',1,'Jl. Mawar No.2','081234560002','aktif'),
('2025003','Citra Ayu',2,'Jl. Kenanga No.3','081234560003','aktif'),
('2025004','Dedi Kurniawan',2,'Jl. Anggrek No.4','081234560004','aktif'),
('2025005','Eka Putri',3,'Jl. Dahlia No.5','081234560005','nonaktif');

INSERT INTO petugas (nama, username, password, role) VALUES
('Siti Bendahara','bendahara1','hashed_pw_1','bendahara'),
('Rudi Admin','admin1','hashed_pw_2','admin');

INSERT INTO tahun_ajaran (tahun, semester, nominal_spp) VALUES
('2025/2026','ganjil',250000.00),
('2025/2026','genap',250000.00);

-- Tagihan awal (dummy, sebagian akan digenerate lewat stored procedure)
INSERT INTO tagihan_spp (id_siswa, id_tahun, bulan, nominal, jatuh_tempo, status) VALUES
(1,1,'Juli',250000.00,'2025-07-10','belum_lunas'),
(2,1,'Juli',250000.00,'2025-07-10','belum_lunas'),
(3,1,'Juli',250000.00,'2025-07-10','belum_lunas');


-- =====================================================================
-- 4. STORED PROCEDURE (wajib minimal 3)
-- =====================================================================
DELIMITER $$

-- 4.1 sp_generate_tagihan_bulanan
-- Membuat tagihan SPP untuk seluruh siswa aktif pada bulan & tahun ajaran
-- tertentu. Menggunakan CURSOR untuk memproses data siswa satu per satu.
CREATE PROCEDURE sp_generate_tagihan_bulanan (
    IN p_id_tahun     INT,
    IN p_bulan        VARCHAR(15),
    IN p_jatuh_tempo  DATE
)
BEGIN
    DECLARE v_id_siswa   INT;
    DECLARE v_nominal    DECIMAL(10,2);
    DECLARE v_done       INT DEFAULT 0;
    DECLARE v_jumlah_dibuat INT DEFAULT 0;

    -- CURSOR: mengambil seluruh siswa aktif
    DECLARE cur_siswa CURSOR FOR
        SELECT id_siswa FROM siswa WHERE status_aktif = 'aktif';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    -- Exception handling: tahun ajaran tidak ditemukan
    IF NOT EXISTS (SELECT 1 FROM tahun_ajaran WHERE id_tahun = p_id_tahun) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tahun ajaran tidak ditemukan';
    END IF;

    SELECT nominal_spp INTO v_nominal
    FROM tahun_ajaran WHERE id_tahun = p_id_tahun;

    OPEN cur_siswa;
    baca_siswa: LOOP
        FETCH cur_siswa INTO v_id_siswa;
        IF v_done = 1 THEN
            LEAVE baca_siswa;
        END IF;

        -- Hindari duplikasi tagihan (constraint UNIQUE juga menjaga ini)
        IF NOT EXISTS (
            SELECT 1 FROM tagihan_spp
            WHERE id_siswa = v_id_siswa AND id_tahun = p_id_tahun AND bulan = p_bulan
        ) THEN
            INSERT INTO tagihan_spp (id_siswa, id_tahun, bulan, nominal, jatuh_tempo, status)
            VALUES (v_id_siswa, p_id_tahun, p_bulan, v_nominal, p_jatuh_tempo, 'belum_lunas');
            SET v_jumlah_dibuat = v_jumlah_dibuat + 1;
        END IF;
    END LOOP baca_siswa;
    CLOSE cur_siswa;

    SELECT CONCAT('Tagihan berhasil dibuat untuk ', v_jumlah_dibuat, ' siswa') AS hasil;
END $$


-- 4.2 sp_proses_pembayaran
-- Memproses pembayaran SPP dengan TRANSACTION CONTROL (COMMIT/ROLLBACK)
-- dan EXCEPTION HANDLING.
CREATE PROCEDURE sp_proses_pembayaran (
    IN  p_id_tagihan    INT,
    IN  p_id_petugas    INT,
    IN  p_jumlah_bayar  DECIMAL(10,2),
    IN  p_metode        ENUM('tunai','transfer')
)
BEGIN
    DECLARE v_status_tagihan  VARCHAR(20);
    DECLARE v_nominal         DECIMAL(10,2);
    DECLARE v_denda           DECIMAL(10,2);
    DECLARE v_total_wajib     DECIMAL(10,2);

    -- Exception handling: SQL error apapun akan di-rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Validasi: tagihan tidak ditemukan
    IF NOT EXISTS (SELECT 1 FROM tagihan_spp WHERE id_tagihan = p_id_tagihan) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tagihan tidak ditemukan';
    END IF;

    SELECT status, nominal INTO v_status_tagihan, v_nominal
    FROM tagihan_spp WHERE id_tagihan = p_id_tagihan;

    -- Validasi: tagihan sudah lunas (data duplikat pembayaran)
    IF v_status_tagihan = 'lunas' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tagihan ini sudah lunas';
    END IF;

    -- Validasi: input kosong / negatif
    IF p_jumlah_bayar IS NULL OR p_jumlah_bayar <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Jumlah bayar tidak valid';
    END IF;

    SET v_denda = fn_hitung_denda(p_id_tagihan);
    SET v_total_wajib = v_nominal + v_denda;

    -- Validasi: pembayaran kurang dari total wajib bayar
    IF p_jumlah_bayar < v_total_wajib THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Jumlah pembayaran kurang dari tagihan + denda';
    END IF;

    INSERT INTO pembayaran (id_tagihan, id_petugas, jumlah_bayar, metode_bayar, status_pembayaran)
    VALUES (p_id_tagihan, p_id_petugas, p_jumlah_bayar, p_metode, 'sukses');
    -- trigger trg_after_insert_pembayaran otomatis mengubah status tagihan menjadi 'lunas'

    COMMIT;
    SELECT 'Pembayaran berhasil diproses' AS hasil;
END $$


-- 4.3 sp_batalkan_pembayaran
-- Membatalkan pembayaran menggunakan SAVEPOINT.
CREATE PROCEDURE sp_batalkan_pembayaran (
    IN p_id_pembayaran INT
)
BEGIN
    DECLARE v_id_tagihan INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK TO sp_before_cancel;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM pembayaran WHERE id_pembayaran = p_id_pembayaran) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data pembayaran tidak ditemukan';
    END IF;

    START TRANSACTION;
    SAVEPOINT sp_before_cancel;

    SELECT id_tagihan INTO v_id_tagihan
    FROM pembayaran WHERE id_pembayaran = p_id_pembayaran;

    UPDATE pembayaran
    SET status_pembayaran = 'dibatalkan'
    WHERE id_pembayaran = p_id_pembayaran;

    UPDATE tagihan_spp
    SET status = 'belum_lunas'
    WHERE id_tagihan = v_id_tagihan;
    -- trigger audit akan mencatat perubahan status tagihan ini

    COMMIT;
    SELECT 'Pembayaran berhasil dibatalkan' AS hasil;
END $$


-- 4.4 sp_laporan_pembayaran_periode
-- Laporan pembayaran berdasarkan rentang tanggal tertentu.
CREATE PROCEDURE sp_laporan_pembayaran_periode (
    IN p_tanggal_awal  DATE,
    IN p_tanggal_akhir DATE
)
BEGIN
    IF p_tanggal_awal > p_tanggal_akhir THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tanggal awal tidak boleh lebih besar dari tanggal akhir';
    END IF;

    SELECT
        p.id_pembayaran, s.nama AS nama_siswa, k.nama_kelas,
        t.bulan, p.jumlah_bayar, p.metode_bayar, p.tanggal_bayar, pt.nama AS petugas
    FROM pembayaran p
    JOIN tagihan_spp t ON p.id_tagihan = t.id_tagihan
    JOIN siswa s        ON t.id_siswa = s.id_siswa
    JOIN kelas k        ON s.id_kelas = k.id_kelas
    JOIN petugas pt     ON p.id_petugas = pt.id_petugas
    WHERE p.tanggal_bayar BETWEEN p_tanggal_awal AND p_tanggal_akhir
      AND p.status_pembayaran = 'sukses'
    ORDER BY p.tanggal_bayar;
END $$

DELIMITER ;


-- =====================================================================
-- 5. FUNCTION (wajib minimal 2)
-- =====================================================================
DELIMITER $$

-- 5.1 fn_hitung_denda
-- Menghitung denda keterlambatan (Rp 5.000/hari) atas suatu tagihan.
CREATE FUNCTION fn_hitung_denda (p_id_tagihan INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_jatuh_tempo DATE;
    DECLARE v_status      VARCHAR(20);
    DECLARE v_hari_telat  INT DEFAULT 0;
    DECLARE v_denda       DECIMAL(10,2) DEFAULT 0;
    DECLARE v_denda_per_hari DECIMAL(10,2) DEFAULT 5000.00;

    SELECT jatuh_tempo, status INTO v_jatuh_tempo, v_status
    FROM tagihan_spp WHERE id_tagihan = p_id_tagihan;

    IF v_status = 'belum_lunas' AND CURDATE() > v_jatuh_tempo THEN
        SET v_hari_telat = DATEDIFF(CURDATE(), v_jatuh_tempo);
        SET v_denda = v_hari_telat * v_denda_per_hari;
    END IF;

    RETURN v_denda;
END $$


-- 5.2 fn_cek_status_tagihan
-- Menentukan status tagihan (Lunas / Belum Lunas / Terlambat).
CREATE FUNCTION fn_cek_status_tagihan (p_id_tagihan INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE v_status      VARCHAR(20);
    DECLARE v_jatuh_tempo DATE;
    DECLARE v_hasil       VARCHAR(20);

    SELECT status, jatuh_tempo INTO v_status, v_jatuh_tempo
    FROM tagihan_spp WHERE id_tagihan = p_id_tagihan;

    IF v_status = 'lunas' THEN
        SET v_hasil = 'Lunas';
    ELSEIF CURDATE() > v_jatuh_tempo THEN
        SET v_hasil = 'Terlambat';
    ELSE
        SET v_hasil = 'Belum Lunas';
    END IF;

    RETURN v_hasil;
END $$


-- 5.3 fn_total_tunggakan_siswa
-- Menjumlahkan total tunggakan (nominal + denda) seorang siswa.
CREATE FUNCTION fn_total_tunggakan_siswa (p_id_siswa INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(10,2) DEFAULT 0;

    SELECT COALESCE(SUM(nominal + fn_hitung_denda(id_tagihan)), 0) INTO v_total
    FROM tagihan_spp
    WHERE id_siswa = p_id_siswa AND status = 'belum_lunas';

    RETURN v_total;
END $$

DELIMITER ;


-- =====================================================================
-- 6. TRIGGER (wajib minimal 3: validasi, audit, perubahan otomatis)
-- =====================================================================
DELIMITER $$

-- 6.1 TRIGGER VALIDASI: menolak input pembayaran negatif/nol sebelum insert
CREATE TRIGGER trg_validasi_pembayaran
BEFORE INSERT ON pembayaran
FOR EACH ROW
BEGIN
    IF NEW.jumlah_bayar IS NULL OR NEW.jumlah_bayar <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Jumlah pembayaran tidak boleh kosong atau negatif';
    END IF;
END $$

-- 6.2 TRIGGER PERUBAHAN OTOMATIS: status tagihan otomatis jadi 'lunas'
-- setelah pembayaran sukses tercatat
CREATE TRIGGER trg_after_insert_pembayaran
AFTER INSERT ON pembayaran
FOR EACH ROW
BEGIN
    IF NEW.status_pembayaran = 'sukses' THEN
        UPDATE tagihan_spp
        SET status = 'lunas'
        WHERE id_tagihan = NEW.id_tagihan;
    END IF;
END $$

-- 6.3 TRIGGER AUDIT LOGGING: mencatat setiap perubahan status tagihan_spp
CREATE TRIGGER trg_audit_tagihan
AFTER UPDATE ON tagihan_spp
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO audit_log (nama_tabel, aksi, data_lama, data_baru, user_db)
        VALUES (
            'tagihan_spp', 'UPDATE',
            CONCAT('id_tagihan=', OLD.id_tagihan, ', status=', OLD.status),
            CONCAT('id_tagihan=', NEW.id_tagihan, ', status=', NEW.status),
            CURRENT_USER()
        );
    END IF;
END $$

-- 6.4 TRIGGER AUDIT tambahan: mencatat pembatalan pembayaran
CREATE TRIGGER trg_audit_pembayaran
AFTER UPDATE ON pembayaran
FOR EACH ROW
BEGIN
    IF OLD.status_pembayaran <> NEW.status_pembayaran THEN
        INSERT INTO audit_log (nama_tabel, aksi, data_lama, data_baru, user_db)
        VALUES (
            'pembayaran', 'UPDATE',
            CONCAT('id_pembayaran=', OLD.id_pembayaran, ', status=', OLD.status_pembayaran),
            CONCAT('id_pembayaran=', NEW.id_pembayaran, ', status=', NEW.status_pembayaran),
            CURRENT_USER()
        );
    END IF;
END $$

DELIMITER ;


-- =====================================================================
-- 7. TRANSACTION CONTROL - contoh skenario (COMMIT / ROLLBACK / SAVEPOINT)
-- =====================================================================

-- --- Skenario 1: transaksi BERHASIL -> COMMIT ---
-- (sp_proses_pembayaran sudah membungkus ini secara internal, contoh manual:)
START TRANSACTION;
    -- asumsikan tagihan id 1 nominal 250000, tanpa denda (belum jatuh tempo)
    UPDATE tagihan_spp SET status = 'lunas' WHERE id_tagihan = 1 AND status = 'belum_lunas';
COMMIT;

-- --- Skenario 2: transaksi GAGAL -> ROLLBACK ---
-- Contoh: mencoba memproses pembayaran untuk tagihan yang tidak ada (id 9999)
-- CALL sp_proses_pembayaran(9999, 1, 250000.00, 'tunai');
-- -> SIGNAL akan aktif, prosedur otomatis ROLLBACK melalui EXIT HANDLER.

-- --- Skenario 3: SAVEPOINT (pembatalan sebagian) ---
START TRANSACTION;
    SAVEPOINT sp_awal;
    UPDATE tagihan_spp SET status = 'lunas' WHERE id_tagihan = 2;
    SAVEPOINT sp_setelah_2;
    -- Simulasikan kondisi gagal pada langkah berikutnya, sehingga hanya
    -- perubahan setelah sp_setelah_2 yang dibatalkan, tagihan id 2 tetap lunas:
    -- ROLLBACK TO sp_setelah_2;
COMMIT;


-- =====================================================================
-- 8. CURSOR (contoh tambahan mandiri, di luar sp_generate_tagihan_bulanan)
-- Merekap total denda seluruh tagihan yang terlambat per siswa.
-- =====================================================================
DELIMITER $$

CREATE PROCEDURE sp_rekap_denda_terlambat ()
BEGIN
    DECLARE v_id_tagihan INT;
    DECLARE v_id_siswa   INT;
    DECLARE v_done       INT DEFAULT 0;

    DECLARE cur_terlambat CURSOR FOR
        SELECT id_tagihan, id_siswa FROM tagihan_spp
        WHERE status = 'belum_lunas' AND jatuh_tempo < CURDATE();
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    DROP TEMPORARY TABLE IF EXISTS tmp_rekap_denda;
    CREATE TEMPORARY TABLE tmp_rekap_denda (
        id_siswa INT,
        total_denda DECIMAL(10,2)
    );

    OPEN cur_terlambat;
    rekap_loop: LOOP
        FETCH cur_terlambat INTO v_id_tagihan, v_id_siswa;
        IF v_done = 1 THEN
            LEAVE rekap_loop;
        END IF;

        INSERT INTO tmp_rekap_denda (id_siswa, total_denda)
        VALUES (v_id_siswa, fn_hitung_denda(v_id_tagihan));
    END LOOP rekap_loop;
    CLOSE cur_terlambat;

    SELECT id_siswa, SUM(total_denda) AS total_denda_keseluruhan
    FROM tmp_rekap_denda
    GROUP BY id_siswa;
END $$

DELIMITER ;


-- =====================================================================
-- 9. INDEXING DAN OPTIMASI QUERY
-- =====================================================================

-- --- Query SEBELUM index dibuat ---
-- EXPLAIN SELECT * FROM tagihan_spp WHERE id_siswa = 1;
-- EXPLAIN SELECT * FROM pembayaran WHERE id_tagihan = 1;
-- Pada tahap ini MySQL melakukan full table scan (type: ALL) karena
-- belum ada index pada kolom foreign key tersebut.

CREATE INDEX idx_tagihan_siswa    ON tagihan_spp(id_siswa);
CREATE INDEX idx_pembayaran_tagihan ON pembayaran(id_tagihan);

-- --- Query SESUDAH index dibuat ---
-- EXPLAIN SELECT * FROM tagihan_spp WHERE id_siswa = 1;
-- EXPLAIN SELECT * FROM pembayaran WHERE id_tagihan = 1;
-- Setelah index dibuat, kolom "key" pada hasil EXPLAIN akan menunjukkan
-- idx_tagihan_siswa / idx_pembayaran_tagihan dan type berubah menjadi
-- "ref", menandakan MySQL langsung mencari lewat index (bukan full scan).
-- Kesimpulan: jumlah baris yang diperiksa (rows) menurun drastis,
-- sehingga query menjadi lebih efisien terutama saat data bertambah besar.


-- =====================================================================
-- CONTOH PEMANGGILAN (untuk pengujian / demo)
-- =====================================================================
-- CALL sp_generate_tagihan_bulanan(1, 'Agustus', '2025-08-10');
-- CALL sp_proses_pembayaran(1, 1, 250000.00, 'tunai');
-- CALL sp_batalkan_pembayaran(1);
-- CALL sp_laporan_pembayaran_periode('2025-07-01','2025-07-31');
-- CALL sp_rekap_denda_terlambat();
-- SELECT fn_hitung_denda(2);
-- SELECT fn_cek_status_tagihan(2);
-- SELECT fn_total_tunggakan_siswa(2);
-- SELECT * FROM audit_log;
