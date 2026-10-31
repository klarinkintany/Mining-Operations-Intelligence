/* =====================================================================
   ANALISIS KINERJA, BREAKDOWN, DAN ANOMALI ALAT BERAT  (MySQL 8.0+)
   ---------------------------------------------------------------------
   Dataset (3 file CSV):
     1. equipment_anomaly_results.csv         -> data harian per alat (8.030 baris,
                                                 22 unit, 4 site, 1 tahun) + skor anomali
     2. equipment_type_summary.csv            -> ringkasan per tipe alat
     3. equipment_breakdown_level_summary.csv -> ringkasan per level breakdown

   Isi dokumen:
     BAGIAN 1   Setup database, tabel, dan load data
     BAGIAN 2   Pengecekan kualitas data & rekonsiliasi ringkasan
     BAGIAN 3   Profil armada
     BAGIAN 4   Kinerja: availability, utilization, OEE
     BAGIAN 5   Analisis breakdown & dampak biaya
     BAGIAN 6   Biaya perawatan & konsumsi BBM
     BAGIAN 7   Autonomous vs Conventional
     BAGIAN 8   Tren bulanan
     BAGIAN 9   Peringkat unit alat (prioritas perhatian)
     BAGIAN 10  Analisis deteksi anomali
     BAGIAN 11  View ringkasan KPI (untuk dashboard / visualisasi)

   Cara pakai:
     - Ganti path file CSV di BAGIAN 1 sesuai lokasi di komputer Anda.
     - Jika memakai Windows dan baris tidak terbaca, ganti '\n' menjadi '\r\n'.
     - Aktifkan local_infile:  SET GLOBAL local_infile = 1;
       dan konek dengan:       mysql --local-infile=1 -u root -p
   ===================================================================== */


/* =====================================================================
   BAGIAN 1 - SETUP DATABASE, TABEL, DAN LOAD DATA
   ===================================================================== */

CREATE DATABASE IF NOT EXISTS equipment_analysis;
USE equipment_analysis;

DROP VIEW  IF EXISTS vw_equipment_kpi;
DROP TABLE IF EXISTS equipment_anomaly_results;
DROP TABLE IF EXISTS equipment_type_summary;
DROP TABLE IF EXISTS equipment_breakdown_level_summary;

-- 1.1 Data harian per alat
CREATE TABLE equipment_anomaly_results (
    `date`               DATE,
    site_id              VARCHAR(10),
    site_name            VARCHAR(50),
    equipment_id         VARCHAR(20),
    equipment_type       VARCHAR(30),
    operation_mode       VARCHAR(20),
    availability_pct     DECIMAL(6,2),
    utilization_pct      DECIMAL(6,2),
    oee_pct              DECIMAL(6,2),
    breakdown_hours      DECIMAL(6,2),
    maintenance_hours    DECIMAL(6,2),
    maintenance_cost_aud DECIMAL(14,2),
    fuel_consumed_liters INT,
    day_type             VARCHAR(30),
    anomaly_score        DECIMAL(8,4),
    anomaly_status       VARCHAR(30),
    PRIMARY KEY (`date`, equipment_id),
    INDEX idx_type (equipment_type),
    INDEX idx_site (site_id),
    INDEX idx_status (anomaly_status)
);

-- 1.2 Ringkasan per tipe alat
CREATE TABLE equipment_type_summary (
    equipment_type                           VARCHAR(30) PRIMARY KEY,
    units                                    INT,
    records                                  INT,
    avg_availability_pct                     DECIMAL(6,2),
    avg_utilization_pct                      DECIMAL(6,2),
    avg_oee_pct                              DECIMAL(6,2),
    total_operating_hours                    DECIMAL(14,2),
    total_breakdown_hours                    DECIMAL(12,2),
    total_maintenance_cost_aud               DECIMAL(16,2),
    total_fuel_liters                        BIGINT,
    breakdown_hours_per_unit                 DECIMAL(10,2),
    maintenance_cost_per_unit_aud            DECIMAL(14,2),
    maintenance_cost_per_operating_hour_aud  DECIMAL(10,2),
    fuel_liters_per_operating_hour           DECIMAL(10,2)
);

-- 1.3 Ringkasan per level breakdown
CREATE TABLE equipment_breakdown_level_summary (
    breakdown_level              VARCHAR(30) PRIMARY KEY,
    record_count                 INT,
    average_oee_pct              DECIMAL(6,2),
    average_breakdown_hours      DECIMAL(6,2),
    average_maintenance_cost_aud DECIMAL(14,2)
);

-- 1.4 Load data
LOAD DATA LOCAL INFILE 'equipment_anomaly_results.csv'
INTO TABLE equipment_anomaly_results
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'equipment_type_summary.csv'
INTO TABLE equipment_type_summary
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'equipment_breakdown_level_summary.csv'
INTO TABLE equipment_breakdown_level_summary
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;


/* =====================================================================
   BAGIAN 2 - PENGECEKAN KUALITAS DATA & REKONSILIASI RINGKASAN
   ===================================================================== */

-- 2.1 Jumlah baris (harapan: 8030, 5, 3)
SELECT 'equipment_anomaly_results' AS tabel, COUNT(*) AS jumlah_baris FROM equipment_anomaly_results
UNION ALL SELECT 'equipment_type_summary',            COUNT(*) FROM equipment_type_summary
UNION ALL SELECT 'equipment_breakdown_level_summary', COUNT(*) FROM equipment_breakdown_level_summary;

-- 2.2 Cakupan data: rentang tanggal, jumlah hari, unit, site
SELECT MIN(`date`)                     AS tanggal_awal,
       MAX(`date`)                     AS tanggal_akhir,
       COUNT(DISTINCT `date`)          AS jumlah_hari,
       COUNT(DISTINCT equipment_id)    AS jumlah_unit,
       COUNT(DISTINCT site_id)         AS jumlah_site,
       COUNT(DISTINCT equipment_type)  AS jumlah_tipe_alat
FROM equipment_anomaly_results;

-- 2.3 Kelengkapan data: unit dengan jumlah hari tidak lengkap (harapan: 0 baris)
SELECT equipment_id, COUNT(*) AS jumlah_hari
FROM equipment_anomaly_results
GROUP BY equipment_id
HAVING COUNT(*) <> 365;

-- 2.4 Nilai di luar rentang wajar (harapan: semua 0)
SELECT SUM(availability_pct < 0 OR availability_pct > 100)   AS availability_di_luar_rentang,
       SUM(utilization_pct  < 0 OR utilization_pct  > 100)   AS utilization_di_luar_rentang,
       SUM(oee_pct          < 0 OR oee_pct          > 100)   AS oee_di_luar_rentang,
       SUM(breakdown_hours  < 0 OR breakdown_hours  > 24)    AS breakdown_di_luar_rentang,
       SUM(maintenance_cost_aud < 0)                         AS biaya_negatif,
       SUM(fuel_consumed_liters < 0)                         AS bbm_negatif
FROM equipment_anomaly_results;

-- 2.5 Validasi rumus OEE = availability x utilization / 100
--     (selisih maksimum, poin persen - harapan <= ~0,15 akibat pembulatan data sumber)
SELECT ROUND(MAX(ABS(oee_pct - availability_pct * utilization_pct / 100)), 2) AS selisih_oee_maks
FROM equipment_anomaly_results;

-- 2.6 Rekonsiliasi tabel ringkasan tipe alat terhadap data detail
--     (jam operasi = 24 jam x availability x utilization). Selisih kecil pada jam operasi
--     (di bawah 0,01%) wajar akibat pembulatan persentase di data sumber.
SELECT s.equipment_type,
       s.records                                   AS records_ringkasan,
       COUNT(*)                                    AS records_detail,
       s.total_maintenance_cost_aud                AS biaya_ringkasan,
       ROUND(SUM(d.maintenance_cost_aud), 2)       AS biaya_detail,
       s.total_breakdown_hours                     AS jam_breakdown_ringkasan,
       ROUND(SUM(d.breakdown_hours), 1)            AS jam_breakdown_detail,
       s.total_fuel_liters                         AS bbm_ringkasan,
       SUM(d.fuel_consumed_liters)                 AS bbm_detail,
       s.total_operating_hours                     AS jam_operasi_ringkasan,
       ROUND(SUM(24 * d.availability_pct / 100 * d.utilization_pct / 100), 1) AS jam_operasi_hitung_ulang
FROM equipment_type_summary s
JOIN equipment_anomaly_results d ON d.equipment_type = s.equipment_type
GROUP BY s.equipment_type, s.records, s.total_maintenance_cost_aud,
         s.total_breakdown_hours, s.total_fuel_liters, s.total_operating_hours;

-- 2.7 Rekonsiliasi tabel ringkasan level breakdown terhadap data detail
SELECT s.breakdown_level,
       s.record_count                            AS record_ringkasan,
       d.record_count                            AS record_detail,
       s.average_oee_pct                         AS oee_ringkasan,
       d.avg_oee                                 AS oee_detail,
       s.average_maintenance_cost_aud            AS biaya_ringkasan,
       d.avg_biaya                               AS biaya_detail
FROM equipment_breakdown_level_summary s
JOIN (
    SELECT CASE WHEN breakdown_hours = 0 THEN 'No breakdown'
                WHEN breakdown_hours <= 6 THEN 'Up to 6 hours'
                ELSE 'Over 6 hours' END AS level,
           COUNT(*)                             AS record_count,
           ROUND(AVG(oee_pct), 2)               AS avg_oee,
           ROUND(AVG(maintenance_cost_aud), 2)  AS avg_biaya
    FROM equipment_anomaly_results
    GROUP BY CASE WHEN breakdown_hours = 0 THEN 'No breakdown'
                  WHEN breakdown_hours <= 6 THEN 'Up to 6 hours'
                  ELSE 'Over 6 hours' END
) d ON d.level = s.breakdown_level;


/* =====================================================================
   BAGIAN 3 - PROFIL ARMADA
   ===================================================================== */

-- 3.1 Jumlah unit per tipe alat dan per site
SELECT equipment_type,
       COUNT(DISTINCT equipment_id) AS total_unit,
       COUNT(DISTINCT CASE WHEN site_id = 'COPP001' THEN equipment_id END) AS copper_hills,
       COUNT(DISTINCT CASE WHEN site_id = 'GOLD001' THEN equipment_id END) AS golden_valley,
       COUNT(DISTINCT CASE WHEN site_id = 'IRON001' THEN equipment_id END) AS iron_ridge,
       COUNT(DISTINCT CASE WHEN site_id = 'LITH001' THEN equipment_id END) AS lithium_creek
FROM equipment_anomaly_results
GROUP BY equipment_type
ORDER BY total_unit DESC;

-- 3.2 Jumlah unit per site dan mode operasi
SELECT site_id, site_name, operation_mode,
       COUNT(DISTINCT equipment_id) AS jumlah_unit
FROM equipment_anomaly_results
GROUP BY site_id, site_name, operation_mode
ORDER BY site_id, operation_mode;

-- 3.3 Daftar seluruh unit alat
SELECT DISTINCT equipment_id, equipment_type, site_id, operation_mode
FROM equipment_anomaly_results
ORDER BY site_id, equipment_type, equipment_id;


/* =====================================================================
   BAGIAN 4 - KINERJA: AVAILABILITY, UTILIZATION, OEE
   ===================================================================== */

-- 4.1 Kinerja per tipe alat (diurutkan dari OEE tertinggi)
SELECT equipment_type,
       COUNT(DISTINCT equipment_id)        AS unit,
       ROUND(AVG(availability_pct), 2)     AS avg_availability_pct,
       ROUND(AVG(utilization_pct), 2)      AS avg_utilization_pct,
       ROUND(AVG(oee_pct), 2)              AS avg_oee_pct,
       ROUND(100 - AVG(oee_pct), 2)        AS gap_ke_oee_100,
       RANK() OVER (ORDER BY AVG(oee_pct) DESC) AS rank_oee
FROM equipment_anomaly_results
GROUP BY equipment_type
ORDER BY avg_oee_pct DESC;

-- 4.2 Sumber kehilangan OEE per tipe: availability (rusak/perawatan) vs utilization (tidak dipakai)
SELECT equipment_type,
       ROUND(100 - AVG(availability_pct), 2) AS kehilangan_availability_poin,
       ROUND(100 - AVG(utilization_pct), 2)  AS kehilangan_utilization_poin,
       CASE WHEN (100 - AVG(utilization_pct)) > (100 - AVG(availability_pct))
            THEN 'Utilization (alat kurang dipakai)'
            ELSE 'Availability (alat tidak siap)' END AS penyebab_dominan
FROM equipment_anomaly_results
GROUP BY equipment_type
ORDER BY kehilangan_utilization_poin DESC;

-- 4.3 Kinerja per site
SELECT site_id, site_name,
       COUNT(DISTINCT equipment_id)    AS unit,
       ROUND(AVG(availability_pct), 2) AS avg_availability_pct,
       ROUND(AVG(utilization_pct), 2)  AS avg_utilization_pct,
       ROUND(AVG(oee_pct), 2)          AS avg_oee_pct
FROM equipment_anomaly_results
GROUP BY site_id, site_name
ORDER BY avg_oee_pct DESC;

-- 4.4 Matriks OEE rata-rata: site x tipe alat
SELECT site_id,
       ROUND(AVG(CASE WHEN equipment_type = 'Haul Truck'  THEN oee_pct END), 2) AS haul_truck,
       ROUND(AVG(CASE WHEN equipment_type = 'Excavator'   THEN oee_pct END), 2) AS excavator,
       ROUND(AVG(CASE WHEN equipment_type = 'Dozer'       THEN oee_pct END), 2) AS dozer,
       ROUND(AVG(CASE WHEN equipment_type = 'LHD Loader'  THEN oee_pct END), 2) AS lhd_loader,
       ROUND(AVG(CASE WHEN equipment_type = 'Jumbo Drill' THEN oee_pct END), 2) AS jumbo_drill
FROM equipment_anomaly_results
GROUP BY site_id
ORDER BY site_id;

-- 4.5 Persentase hari OEE di atas benchmark 85% (kelas dunia) per tipe alat
SELECT equipment_type,
       COUNT(*)                                              AS jumlah_hari_unit,
       ROUND(SUM(oee_pct >= 85) * 100.0 / COUNT(*), 2)       AS pct_hari_oee_85_ke_atas,
       ROUND(SUM(oee_pct <  60) * 100.0 / COUNT(*), 2)       AS pct_hari_oee_di_bawah_60
FROM equipment_anomaly_results
GROUP BY equipment_type
ORDER BY pct_hari_oee_85_ke_atas DESC;


/* =====================================================================
   BAGIAN 5 - ANALISIS BREAKDOWN & DAMPAK BIAYA
   ===================================================================== */

-- 5.1 Distribusi tipe hari (normal / breakdown / hanya perawatan)
SELECT day_type,
       COUNT(*)                                                      AS jumlah_hari_unit,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)            AS persen,
       ROUND(AVG(oee_pct), 2)                                        AS avg_oee_pct,
       ROUND(AVG(breakdown_hours), 2)                                AS avg_jam_breakdown,
       ROUND(AVG(maintenance_hours), 2)                              AS avg_jam_perawatan,
       ROUND(AVG(maintenance_cost_aud), 2)                           AS avg_biaya_perawatan_aud
FROM equipment_anomaly_results
GROUP BY day_type
ORDER BY jumlah_hari_unit DESC;

-- 5.2 Dampak level breakdown terhadap OEE dan biaya (dihitung dari data detail)
SELECT CASE WHEN breakdown_hours = 0 THEN '1. No breakdown'
            WHEN breakdown_hours <= 6 THEN '2. Up to 6 hours'
            ELSE '3. Over 6 hours' END           AS level_breakdown,
       COUNT(*)                                  AS jumlah_kejadian,
       ROUND(AVG(oee_pct), 2)                    AS avg_oee_pct,
       ROUND(AVG(breakdown_hours), 2)            AS avg_jam_breakdown,
       ROUND(AVG(maintenance_cost_aud), 2)       AS avg_biaya_aud,
       ROUND(SUM(maintenance_cost_aud), 2)       AS total_biaya_aud,
       ROUND(SUM(maintenance_cost_aud) * 100.0 /
             (SELECT SUM(maintenance_cost_aud) FROM equipment_anomaly_results), 2) AS share_total_biaya_pct
FROM equipment_anomaly_results
GROUP BY CASE WHEN breakdown_hours = 0 THEN '1. No breakdown'
              WHEN breakdown_hours <= 6 THEN '2. Up to 6 hours'
              ELSE '3. Over 6 hours' END
ORDER BY level_breakdown;

-- 5.3 Kelipatan biaya hari breakdown dibanding hari normal (tanpa breakdown)
SELECT ROUND(AVG(CASE WHEN breakdown_hours = 0 THEN maintenance_cost_aud END), 2) AS avg_biaya_tanpa_breakdown,
       ROUND(AVG(CASE WHEN breakdown_hours > 0 THEN maintenance_cost_aud END), 2) AS avg_biaya_dengan_breakdown,
       ROUND(AVG(CASE WHEN breakdown_hours > 0 THEN maintenance_cost_aud END) /
             AVG(CASE WHEN breakdown_hours = 0 THEN maintenance_cost_aud END), 1)  AS kelipatan_biaya,
       ROUND(AVG(CASE WHEN breakdown_hours = 0 THEN oee_pct END), 2)               AS avg_oee_tanpa_breakdown,
       ROUND(AVG(CASE WHEN breakdown_hours > 0 THEN oee_pct END), 2)               AS avg_oee_dengan_breakdown
FROM equipment_anomaly_results;

-- 5.4 Frekuensi dan jam breakdown per tipe alat
SELECT equipment_type,
       COUNT(DISTINCT equipment_id)                              AS unit,
       SUM(breakdown_hours > 0)                                  AS hari_breakdown,
       ROUND(SUM(breakdown_hours > 0) * 100.0 / COUNT(*), 2)     AS pct_hari_breakdown,
       ROUND(SUM(breakdown_hours), 1)                            AS total_jam_breakdown,
       ROUND(SUM(breakdown_hours) / COUNT(DISTINCT equipment_id), 2) AS jam_breakdown_per_unit,
       ROUND(SUM(breakdown_hours) / NULLIF(SUM(breakdown_hours > 0), 0), 2) AS rata2_jam_per_kejadian,
       SUM(breakdown_hours > 6)                                  AS kejadian_lebih_6_jam
FROM equipment_anomaly_results
GROUP BY equipment_type
ORDER BY jam_breakdown_per_unit DESC;

-- 5.5 Estimasi biaya tambahan akibat breakdown per tipe alat
--     (selisih biaya hari breakdown terhadap rata-rata hari tanpa breakdown tipe yang sama)
SELECT b.equipment_type,
       b.hari_breakdown,
       ROUND(b.biaya_breakdown, 2)                                   AS biaya_hari_breakdown_aud,
       ROUND(n.avg_normal, 2)                                        AS avg_biaya_hari_normal_aud,
       ROUND(b.biaya_breakdown - b.hari_breakdown * n.avg_normal, 2) AS estimasi_biaya_tambahan_aud
FROM (
    SELECT equipment_type, COUNT(*) AS hari_breakdown, SUM(maintenance_cost_aud) AS biaya_breakdown
    FROM equipment_anomaly_results
    WHERE breakdown_hours > 0
    GROUP BY equipment_type
) b
JOIN (
    SELECT equipment_type, AVG(maintenance_cost_aud) AS avg_normal
    FROM equipment_anomaly_results
    WHERE breakdown_hours = 0
    GROUP BY equipment_type
) n ON n.equipment_type = b.equipment_type
ORDER BY estimasi_biaya_tambahan_aud DESC;

-- 5.6 Breakdown per site
SELECT site_id, site_name,
       SUM(breakdown_hours > 0)                           AS hari_breakdown,
       ROUND(SUM(breakdown_hours), 1)                     AS total_jam_breakdown,
       ROUND(SUM(CASE WHEN breakdown_hours > 0 THEN maintenance_cost_aud END), 2) AS biaya_hari_breakdown_aud
FROM equipment_anomaly_results
GROUP BY site_id, site_name
ORDER BY total_jam_breakdown DESC;


/* =====================================================================
   BAGIAN 6 - BIAYA PERAWATAN & KONSUMSI BBM
   ===================================================================== */

-- 6.1 Biaya perawatan dan BBM per tipe alat (jam operasi = 24 x avail x util)
SELECT equipment_type,
       COUNT(DISTINCT equipment_id)                                         AS unit,
       ROUND(SUM(maintenance_cost_aud), 2)                                  AS total_biaya_perawatan_aud,
       ROUND(SUM(maintenance_cost_aud) / COUNT(DISTINCT equipment_id), 2)   AS biaya_per_unit_aud,
       ROUND(SUM(24 * availability_pct / 100 * utilization_pct / 100), 1)   AS total_jam_operasi,
       ROUND(SUM(maintenance_cost_aud) /
             SUM(24 * availability_pct / 100 * utilization_pct / 100), 2)   AS biaya_per_jam_operasi_aud,
       SUM(fuel_consumed_liters)                                            AS total_bbm_liter,
       ROUND(SUM(fuel_consumed_liters) /
             SUM(24 * availability_pct / 100 * utilization_pct / 100), 2)   AS liter_per_jam_operasi
FROM equipment_anomaly_results
GROUP BY equipment_type
ORDER BY total_biaya_perawatan_aud DESC;

-- 6.2 Kontribusi tiap tipe alat terhadap total biaya perawatan vs total jam operasi
SELECT equipment_type,
       ROUND(SUM(maintenance_cost_aud) * 100.0 /
             (SELECT SUM(maintenance_cost_aud) FROM equipment_anomaly_results), 2) AS share_biaya_pct,
       ROUND(SUM(24 * availability_pct / 100 * utilization_pct / 100) * 100.0 /
             (SELECT SUM(24 * availability_pct / 100 * utilization_pct / 100)
                FROM equipment_anomaly_results), 2)                               AS share_jam_operasi_pct,
       ROUND(SUM(fuel_consumed_liters) * 100.0 /
             (SELECT SUM(fuel_consumed_liters) FROM equipment_anomaly_results), 2) AS share_bbm_pct
FROM equipment_anomaly_results
GROUP BY equipment_type
ORDER BY share_biaya_pct DESC;

-- 6.3 Biaya perawatan per site
SELECT site_id, site_name,
       ROUND(SUM(maintenance_cost_aud), 2)               AS total_biaya_perawatan_aud,
       ROUND(AVG(maintenance_cost_aud), 2)               AS avg_biaya_per_hari_unit_aud,
       SUM(fuel_consumed_liters)                         AS total_bbm_liter
FROM equipment_anomaly_results
GROUP BY site_id, site_name
ORDER BY total_biaya_perawatan_aud DESC;

-- 6.4 Biaya perawatan: hari normal vs hari perawatan terjadwal vs hari breakdown
SELECT day_type,
       COUNT(*)                                  AS jumlah_hari_unit,
       ROUND(SUM(maintenance_cost_aud), 2)       AS total_biaya_aud,
       ROUND(SUM(maintenance_cost_aud) * 100.0 /
             (SELECT SUM(maintenance_cost_aud) FROM equipment_anomaly_results), 2) AS share_biaya_pct,
       ROUND(SUM(maintenance_hours), 1)          AS total_jam_perawatan
FROM equipment_anomaly_results
GROUP BY day_type
ORDER BY total_biaya_aud DESC;


/* =====================================================================
   BAGIAN 7 - AUTONOMOUS VS CONVENTIONAL
   ===================================================================== */

-- 7.1 Perbandingan mode operasi secara keseluruhan
SELECT operation_mode,
       COUNT(DISTINCT equipment_id)                          AS unit,
       COUNT(*)                                              AS jumlah_hari_unit,
       ROUND(AVG(availability_pct), 2)                       AS avg_availability_pct,
       ROUND(AVG(utilization_pct), 2)                        AS avg_utilization_pct,
       ROUND(AVG(oee_pct), 2)                                AS avg_oee_pct,
       ROUND(AVG(breakdown_hours), 3)                        AS avg_jam_breakdown_per_hari,
       ROUND(AVG(maintenance_cost_aud), 2)                   AS avg_biaya_per_hari_aud
FROM equipment_anomaly_results
GROUP BY operation_mode;

-- 7.2 Perbandingan mode operasi per tipe alat (agar adil: tipe yang sama)
SELECT equipment_type, operation_mode,
       COUNT(DISTINCT equipment_id)          AS unit,
       ROUND(AVG(oee_pct), 2)                AS avg_oee_pct,
       ROUND(AVG(utilization_pct), 2)        AS avg_utilization_pct,
       ROUND(AVG(breakdown_hours), 3)        AS avg_jam_breakdown_per_hari,
       ROUND(AVG(maintenance_cost_aud), 2)   AS avg_biaya_per_hari_aud
FROM equipment_anomaly_results
GROUP BY equipment_type, operation_mode
ORDER BY equipment_type, operation_mode;

-- 7.3 Sebaran mode operasi per site (untuk melihat apakah perbandingan bercampur dengan efek site)
SELECT site_id, operation_mode,
       COUNT(DISTINCT equipment_id)   AS unit,
       ROUND(AVG(oee_pct), 2)         AS avg_oee_pct
FROM equipment_anomaly_results
GROUP BY site_id, operation_mode
ORDER BY site_id, operation_mode;


/* =====================================================================
   BAGIAN 8 - TREN BULANAN
   ===================================================================== */

-- 8.1 Tren bulanan armada: OEE, breakdown, biaya, BBM, dan perubahan OEE dari bulan sebelumnya
SELECT bulan,
       avg_oee_pct,
       ROUND(avg_oee_pct - LAG(avg_oee_pct) OVER (ORDER BY bulan), 2) AS perubahan_oee_poin,
       total_jam_breakdown,
       hari_breakdown,
       total_biaya_perawatan_aud,
       total_bbm_liter
FROM (
    SELECT SUBSTR(`date`, 1, 7)                   AS bulan,
           ROUND(AVG(oee_pct), 2)                 AS avg_oee_pct,
           ROUND(SUM(breakdown_hours), 1)         AS total_jam_breakdown,
           SUM(breakdown_hours > 0)               AS hari_breakdown,
           ROUND(SUM(maintenance_cost_aud), 2)    AS total_biaya_perawatan_aud,
           SUM(fuel_consumed_liters)              AS total_bbm_liter
    FROM equipment_anomaly_results
    GROUP BY SUBSTR(`date`, 1, 7)
) m
ORDER BY bulan;

-- 8.2 Tren bulanan OEE per tipe alat
SELECT SUBSTR(`date`, 1, 7) AS bulan,
       ROUND(AVG(CASE WHEN equipment_type = 'Haul Truck'  THEN oee_pct END), 2) AS haul_truck,
       ROUND(AVG(CASE WHEN equipment_type = 'Excavator'   THEN oee_pct END), 2) AS excavator,
       ROUND(AVG(CASE WHEN equipment_type = 'Dozer'       THEN oee_pct END), 2) AS dozer,
       ROUND(AVG(CASE WHEN equipment_type = 'LHD Loader'  THEN oee_pct END), 2) AS lhd_loader,
       ROUND(AVG(CASE WHEN equipment_type = 'Jumbo Drill' THEN oee_pct END), 2) AS jumbo_drill
FROM equipment_anomaly_results
GROUP BY SUBSTR(`date`, 1, 7)
ORDER BY bulan;

-- 8.3 Bulan dengan breakdown terbanyak dan tersedikit
SELECT bulan, total_jam_breakdown, kategori
FROM (
    SELECT bulan, total_jam_breakdown,
           CASE WHEN total_jam_breakdown = MAX(total_jam_breakdown) OVER () THEN 'Tertinggi'
                WHEN total_jam_breakdown = MIN(total_jam_breakdown) OVER () THEN 'Terendah' END AS kategori
    FROM (
        SELECT SUBSTR(`date`, 1, 7) AS bulan, ROUND(SUM(breakdown_hours), 1) AS total_jam_breakdown
        FROM equipment_anomaly_results
        GROUP BY SUBSTR(`date`, 1, 7)
    ) x
) y
WHERE kategori IS NOT NULL;

-- 8.4 Pola hari-minggu tidak tersedia secara portabel di semua dialek, sehingga
--     dipakai rata-rata per hari-dalam-bulan sebagai pengecekan tren intra-bulan
SELECT CASE WHEN CAST(SUBSTR(`date`, 9, 2) AS UNSIGNED) <= 10 THEN '1. Tanggal 1-10'
            WHEN CAST(SUBSTR(`date`, 9, 2) AS UNSIGNED) <= 20 THEN '2. Tanggal 11-20'
            ELSE '3. Tanggal 21-akhir' END AS periode_bulan,
       ROUND(AVG(oee_pct), 2)           AS avg_oee_pct,
       ROUND(AVG(breakdown_hours), 3)   AS avg_jam_breakdown
FROM equipment_anomaly_results
GROUP BY CASE WHEN CAST(SUBSTR(`date`, 9, 2) AS UNSIGNED) <= 10 THEN '1. Tanggal 1-10'
              WHEN CAST(SUBSTR(`date`, 9, 2) AS UNSIGNED) <= 20 THEN '2. Tanggal 11-20'
              ELSE '3. Tanggal 21-akhir' END
ORDER BY periode_bulan;


/* =====================================================================
   BAGIAN 9 - PERINGKAT UNIT ALAT (PRIORITAS PERHATIAN)
   ===================================================================== */

-- 9.1 Scorecard per unit alat
SELECT equipment_id, equipment_type, site_id, operation_mode,
       ROUND(AVG(availability_pct), 2)        AS avg_availability_pct,
       ROUND(AVG(utilization_pct), 2)         AS avg_utilization_pct,
       ROUND(AVG(oee_pct), 2)                 AS avg_oee_pct,
       ROUND(SUM(breakdown_hours), 1)         AS total_jam_breakdown,
       SUM(breakdown_hours > 0)               AS hari_breakdown,
       ROUND(SUM(maintenance_cost_aud), 2)    AS total_biaya_perawatan_aud,
       SUM(anomaly_status = 'Potential Anomaly') AS hari_anomali
FROM equipment_anomaly_results
GROUP BY equipment_id, equipment_type, site_id, operation_mode
ORDER BY total_jam_breakdown DESC;

-- 9.2 Lima unit dengan jam breakdown terbanyak
SELECT equipment_id, equipment_type, site_id,
       ROUND(SUM(breakdown_hours), 1) AS total_jam_breakdown,
       SUM(breakdown_hours > 0)       AS hari_breakdown,
       RANK() OVER (ORDER BY SUM(breakdown_hours) DESC) AS peringkat
FROM equipment_anomaly_results
GROUP BY equipment_id, equipment_type, site_id
ORDER BY total_jam_breakdown DESC
LIMIT 5;

-- 9.3 Lima unit dengan biaya perawatan tertinggi
SELECT equipment_id, equipment_type, site_id,
       ROUND(SUM(maintenance_cost_aud), 2) AS total_biaya_perawatan_aud,
       ROUND(AVG(oee_pct), 2)              AS avg_oee_pct
FROM equipment_anomaly_results
GROUP BY equipment_id, equipment_type, site_id
ORDER BY total_biaya_perawatan_aud DESC
LIMIT 5;

-- 9.4 Lima unit dengan OEE terendah
SELECT equipment_id, equipment_type, site_id, operation_mode,
       ROUND(AVG(oee_pct), 2)          AS avg_oee_pct,
       ROUND(AVG(utilization_pct), 2)  AS avg_utilization_pct
FROM equipment_anomaly_results
GROUP BY equipment_id, equipment_type, site_id, operation_mode
ORDER BY avg_oee_pct
LIMIT 5;

-- 9.5 Unit yang lebih buruk dari rata-rata tipe alatnya (OEE lebih rendah DAN breakdown lebih tinggi)
SELECT u.equipment_id, u.equipment_type, u.site_id,
       u.avg_oee_pct,  ROUND(t.avg_oee_tipe, 2)    AS avg_oee_tipe,
       u.jam_breakdown, ROUND(t.avg_jam_tipe, 2)   AS avg_jam_breakdown_tipe
FROM (
    SELECT equipment_id, equipment_type, site_id,
           AVG(oee_pct) AS avg_oee_pct, SUM(breakdown_hours) AS jam_breakdown
    FROM equipment_anomaly_results
    GROUP BY equipment_id, equipment_type, site_id
) u
JOIN (
    SELECT equipment_type, AVG(avg_oee) AS avg_oee_tipe, AVG(jam) AS avg_jam_tipe
    FROM (
        SELECT equipment_id, equipment_type, AVG(oee_pct) AS avg_oee, SUM(breakdown_hours) AS jam
        FROM equipment_anomaly_results
        GROUP BY equipment_id, equipment_type
    ) per_unit
    GROUP BY equipment_type
) t ON t.equipment_type = u.equipment_type
WHERE u.avg_oee_pct < t.avg_oee_tipe
  AND u.jam_breakdown > t.avg_jam_tipe
ORDER BY u.jam_breakdown DESC;


/* =====================================================================
   BAGIAN 10 - ANALISIS DETEKSI ANOMALI
   anomaly_status: 'Normal' atau 'Potential Anomaly' (berdasarkan anomaly_score)
   ===================================================================== */

-- 10.1 Distribusi status anomali dan statistik skor
SELECT anomaly_status,
       COUNT(*)                                                 AS jumlah,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)       AS persen,
       ROUND(MIN(anomaly_score), 4)                             AS skor_min,
       ROUND(AVG(anomaly_score), 4)                             AS skor_rata2,
       ROUND(MAX(anomaly_score), 4)                             AS skor_maks
FROM equipment_anomaly_results
GROUP BY anomaly_status;

-- 10.2 Ambang skor yang tampak dipakai (skor tertinggi 'Normal' vs terendah 'Potential Anomaly')
SELECT ROUND(MAX(CASE WHEN anomaly_status = 'Normal'            THEN anomaly_score END), 4) AS skor_maks_normal,
       ROUND(MIN(CASE WHEN anomaly_status = 'Potential Anomaly' THEN anomaly_score END), 4) AS skor_min_anomali
FROM equipment_anomaly_results;

-- 10.3 Matriks tipe hari x status anomali (seberapa baik anomali menangkap breakdown)
SELECT day_type,
       COUNT(*)                                           AS jumlah,
       SUM(anomaly_status = 'Potential Anomaly')          AS ditandai_anomali,
       ROUND(SUM(anomaly_status = 'Potential Anomaly') * 100.0 / COUNT(*), 2) AS pct_ditandai
FROM equipment_anomaly_results
GROUP BY day_type
ORDER BY pct_ditandai DESC;

-- 10.4 Kualitas deteksi terhadap kejadian breakdown (breakdown_hours > 0)
SELECT SUM(breakdown_hours > 0 AND anomaly_status = 'Potential Anomaly')     AS breakdown_terdeteksi,
       SUM(breakdown_hours > 0 AND anomaly_status = 'Normal')                AS breakdown_terlewat,
       SUM(breakdown_hours = 0 AND anomaly_status = 'Potential Anomaly')     AS anomali_tanpa_breakdown,
       ROUND(SUM(breakdown_hours > 0 AND anomaly_status = 'Potential Anomaly') * 100.0 /
             NULLIF(SUM(breakdown_hours > 0), 0), 2)                         AS recall_breakdown_pct,
       ROUND(SUM(breakdown_hours > 0 AND anomaly_status = 'Potential Anomaly') * 100.0 /
             NULLIF(SUM(anomaly_status = 'Potential Anomaly'), 0), 2)        AS presisi_pct
FROM equipment_anomaly_results;

-- 10.5 Tingkat anomali per level breakdown
SELECT CASE WHEN breakdown_hours = 0 THEN '1. No breakdown'
            WHEN breakdown_hours <= 6 THEN '2. Up to 6 hours'
            ELSE '3. Over 6 hours' END                       AS level_breakdown,
       COUNT(*)                                              AS jumlah,
       SUM(anomaly_status = 'Potential Anomaly')             AS ditandai_anomali,
       ROUND(SUM(anomaly_status = 'Potential Anomaly') * 100.0 / COUNT(*), 2) AS pct_ditandai,
       ROUND(AVG(anomaly_score), 4)                          AS skor_rata2
FROM equipment_anomaly_results
GROUP BY CASE WHEN breakdown_hours = 0 THEN '1. No breakdown'
              WHEN breakdown_hours <= 6 THEN '2. Up to 6 hours'
              ELSE '3. Over 6 hours' END
ORDER BY level_breakdown;

-- 10.6 Tingkat anomali per tipe alat dan per site
SELECT equipment_type,
       COUNT(*)                                                               AS jumlah,
       SUM(anomaly_status = 'Potential Anomaly')                              AS anomali,
       ROUND(SUM(anomaly_status = 'Potential Anomaly') * 100.0 / COUNT(*), 2) AS pct_anomali,
       ROUND(AVG(anomaly_score), 4)                                           AS skor_rata2
FROM equipment_anomaly_results
GROUP BY equipment_type
ORDER BY pct_anomali DESC;

SELECT site_id,
       COUNT(*)                                                               AS jumlah,
       SUM(anomaly_status = 'Potential Anomaly')                              AS anomali,
       ROUND(SUM(anomaly_status = 'Potential Anomaly') * 100.0 / COUNT(*), 2) AS pct_anomali
FROM equipment_anomaly_results
GROUP BY site_id
ORDER BY pct_anomali DESC;

-- 10.7 Anomali yang terjadi TANPA breakdown (pada hari perawatan saja) - kandidat peringatan dini
--      atau alarm palsu yang perlu diselidiki. Tidak ada anomali pada 'Normal day'.
SELECT `date`, site_id, equipment_id, equipment_type, operation_mode,
       availability_pct, utilization_pct, oee_pct,
       maintenance_cost_aud, fuel_consumed_liters, anomaly_score
FROM equipment_anomaly_results
WHERE anomaly_status = 'Potential Anomaly'
  AND breakdown_hours = 0
  AND day_type = 'Maintenance-only day'
ORDER BY anomaly_score DESC
LIMIT 20;

-- 10.8 Dua puluh skor anomali tertinggi
SELECT `date`, site_id, equipment_id, equipment_type, day_type,
       breakdown_hours, oee_pct, maintenance_cost_aud, anomaly_score
FROM equipment_anomaly_results
ORDER BY anomaly_score DESC
LIMIT 20;

-- 10.9 Unit dengan jumlah hari anomali terbanyak
SELECT equipment_id, equipment_type, site_id,
       SUM(anomaly_status = 'Potential Anomaly')                              AS hari_anomali,
       ROUND(SUM(anomaly_status = 'Potential Anomaly') * 100.0 / COUNT(*), 2) AS pct_hari_anomali
FROM equipment_anomaly_results
GROUP BY equipment_id, equipment_type, site_id
ORDER BY hari_anomali DESC
LIMIT 10;

-- 10.10 Tren bulanan jumlah anomali
SELECT SUBSTR(`date`, 1, 7) AS bulan,
       SUM(anomaly_status = 'Potential Anomaly')                              AS anomali,
       ROUND(SUM(anomaly_status = 'Potential Anomaly') * 100.0 / COUNT(*), 2) AS pct_anomali,
       ROUND(AVG(anomaly_score), 4)                                           AS skor_rata2
FROM equipment_anomaly_results
GROUP BY SUBSTR(`date`, 1, 7)
ORDER BY bulan;


/* =====================================================================
   BAGIAN 11 - VIEW RINGKASAN KPI (siap dipakai untuk dashboard/visualisasi)
   ===================================================================== */

CREATE VIEW vw_equipment_kpi AS
SELECT equipment_id,
       equipment_type,
       site_id,
       site_name,
       operation_mode,
       COUNT(*)                                       AS hari_data,
       ROUND(AVG(availability_pct), 2)                AS avg_availability_pct,
       ROUND(AVG(utilization_pct), 2)                 AS avg_utilization_pct,
       ROUND(AVG(oee_pct), 2)                         AS avg_oee_pct,
       ROUND(SUM(breakdown_hours), 1)                 AS total_jam_breakdown,
       SUM(breakdown_hours > 0)                       AS hari_breakdown,
       ROUND(SUM(maintenance_hours), 1)               AS total_jam_perawatan,
       ROUND(SUM(maintenance_cost_aud), 2)            AS total_biaya_perawatan_aud,
       SUM(fuel_consumed_liters)                      AS total_bbm_liter,
       SUM(anomaly_status = 'Potential Anomaly')      AS hari_anomali,
       ROUND(AVG(anomaly_score), 4)                   AS skor_anomali_rata2
FROM equipment_anomaly_results
GROUP BY equipment_id, equipment_type, site_id, site_name, operation_mode;

SELECT * FROM vw_equipment_kpi ORDER BY total_jam_breakdown DESC;

/* ========================= AKHIR DOKUMEN ========================= */
