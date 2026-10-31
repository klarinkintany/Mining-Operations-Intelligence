/* =====================================================================
   DATA WAREHOUSE & ANALISIS TERINTEGRASI OPERASI TAMBANG  (MySQL 8.0+)
   Model data: STAR SCHEMA (2 dimensi + 4 tabel fakta)
   ---------------------------------------------------------------------
     dim_date            -> kalender 2025 (365 hari)
     dim_site            -> master site + parameter model biaya
     fact_cost_structure -> biaya tahunan per site per kategori (long format)
     fact_monthly        -> produksi & biaya bulanan per site
     fact_equipment      -> kinerja harian per alat (8.030 baris)
     fact_safety         -> insiden K3 (360 baris)

   Isi dokumen:
     BAGIAN 1   Setup database, skema bintang, dan load data
     BAGIAN 2   Pengecekan kualitas data & integritas relasi
     BAGIAN 3   View terintegrasi (scorecard site & data bulanan)
     BAGIAN 4   Ringkasan eksekutif
     BAGIAN 5   Produksi & biaya (bulanan, kuartalan)
     BAGIAN 6   Struktur biaya
     BAGIAN 7   Biaya tetap vs variabel
     BAGIAN 8   Kinerja alat berat
     BAGIAN 9   Keselamatan kerja (K3)
     BAGIAN 10  Analisis lintas domain (produksi - alat - K3)

   Cara pakai:
     - Ganti path file CSV di BAGIAN 1 sesuai lokasi di komputer Anda.
     - Jika memakai Windows dan baris tidak terbaca, ganti '\n' menjadi '\r\n'.
     - Aktifkan local_infile:  SET GLOBAL local_infile = 1;
       dan konek dengan:       mysql --local-infile=1 -u root -p
     - Urutan load penting: dimensi dulu, baru tabel fakta (karena foreign key).
   ===================================================================== */


/* =====================================================================
   BAGIAN 1 - SETUP DATABASE, SKEMA BINTANG, DAN LOAD DATA
   ===================================================================== */

CREATE DATABASE IF NOT EXISTS mining_dwh;
USE mining_dwh;

DROP VIEW  IF EXISTS vw_monthly_site;
DROP VIEW  IF EXISTS vw_site_scorecard;
DROP TABLE IF EXISTS fact_safety;
DROP TABLE IF EXISTS fact_equipment;
DROP TABLE IF EXISTS fact_monthly;
DROP TABLE IF EXISTS fact_cost_structure;
DROP TABLE IF EXISTS dim_site;
DROP TABLE IF EXISTS dim_date;

-- 1.1 Dimensi tanggal
CREATE TABLE dim_date (
    `Date`    DATE PRIMARY KEY,
    `Year`    SMALLINT,
    MonthNum  TINYINT,
    `Month`   CHAR(3),
    `Quarter` CHAR(2)
);

-- 1.2 Dimensi site
CREATE TABLE dim_site (
    site_id                     VARCHAR(10) PRIMARY KEY,
    site_name                   VARCHAR(50),
    commodity                   VARCHAR(30),
    status                      VARCHAR(30),
    annual_target_tonnes        BIGINT,
    tonnes_processed            BIGINT,
    avg_plan_adherence_pct      DECIMAL(10,4),
    corr_tonnes_vs_cost         DECIMAL(10,6),
    r2_linear_fit               DECIMAL(10,6),
    variable_cost_per_tonne_aud DECIMAL(18,6),
    fixed_cost_per_day_aud      DECIMAL(18,6)
);

-- 1.3 Fakta struktur biaya
CREATE TABLE fact_cost_structure (
    site_id       VARCHAR(10),
    cost_category VARCHAR(30),
    cost_aud      DECIMAL(20,2),
    PRIMARY KEY (site_id, cost_category),
    FOREIGN KEY (site_id) REFERENCES dim_site (site_id)
);

-- 1.4 Fakta bulanan
CREATE TABLE fact_monthly (
    month_start    DATE,
    site_id        VARCHAR(10),
    days           INT,
    tonnes_mined   BIGINT,
    total_cost_aud DECIMAL(20,2),
    PRIMARY KEY (month_start, site_id),
    FOREIGN KEY (month_start) REFERENCES dim_date (`Date`),
    FOREIGN KEY (site_id)     REFERENCES dim_site (site_id)
);

-- 1.5 Fakta alat berat (harian)
CREATE TABLE fact_equipment (
    `date`               DATE,
    site_id              VARCHAR(10),
    equipment_id         VARCHAR(20),
    equipment_type       VARCHAR(30),
    model                VARCHAR(40),
    operation_mode       VARCHAR(20),
    available_hours      DECIMAL(5,1),
    operating_hours      DECIMAL(5,1),
    idle_hours           DECIMAL(5,1),
    maintenance_hours    DECIMAL(5,1),
    breakdown_hours      DECIMAL(5,1),
    availability_pct     DECIMAL(6,2),
    utilization_pct      DECIMAL(6,2),
    oee_pct              DECIMAL(6,2),
    fuel_consumed_liters INT,
    maintenance_cost_aud DECIMAL(14,2),
    downtime_hours       DECIMAL(5,1),
    has_breakdown        TINYINT(1),
    day_type             VARCHAR(30),
    anomaly_score        DECIMAL(8,4),
    anomaly_status       VARCHAR(30),
    is_anomaly           TINYINT(1),
    PRIMARY KEY (`date`, equipment_id),
    INDEX idx_eq_site (site_id),
    INDEX idx_eq_type (equipment_type),
    FOREIGN KEY (`date`)  REFERENCES dim_date (`Date`),
    FOREIGN KEY (site_id) REFERENCES dim_site (site_id)
);

-- 1.6 Fakta keselamatan kerja
CREATE TABLE fact_safety (
    incident_id                VARCHAR(12) PRIMARY KEY,
    `date`                     DATE,
    site_id                    VARCHAR(10),
    incident_type              VARCHAR(50),
    severity                   VARCHAR(10),
    description                VARCHAR(60),
    days_lost                  INT,
    root_cause                 VARCHAR(30),
    investigation_status       VARCHAR(30),
    is_lost_time_injury        TINYINT(1),
    is_medical_treatment_injury TINYINT(1),
    is_open_investigation      TINYINT(1),
    incident_category          VARCHAR(40),
    INDEX idx_sf_site (site_id),
    FOREIGN KEY (`date`)  REFERENCES dim_date (`Date`),
    FOREIGN KEY (site_id) REFERENCES dim_site (site_id)
);

-- 1.7 Load data (dimensi lebih dulu)
LOAD DATA LOCAL INFILE 'dim_date.csv'
INTO TABLE dim_date
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'dim_site.csv'
INTO TABLE dim_site
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(site_id, site_name, commodity, status, annual_target_tonnes, tonnes_processed,
 avg_plan_adherence_pct, @corr_tonnes_vs_cost, @r2_linear_fit,
 @variable_cost_per_tonne_aud, fixed_cost_per_day_aud)
SET corr_tonnes_vs_cost           = NULLIF(@corr_tonnes_vs_cost, ''),
    r2_linear_fit                 = NULLIF(@r2_linear_fit, ''),
    variable_cost_per_tonne_aud   = NULLIF(@variable_cost_per_tonne_aud, '');

LOAD DATA LOCAL INFILE 'fact_cost_structure.csv'
INTO TABLE fact_cost_structure
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'fact_monthly.csv'
INTO TABLE fact_monthly
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'fact_equipment.csv'
INTO TABLE fact_equipment
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'fact_safety.csv'
INTO TABLE fact_safety
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;


/* =====================================================================
   BAGIAN 2 - PENGECEKAN KUALITAS DATA & INTEGRITAS RELASI
   ===================================================================== */

-- 2.1 Jumlah baris (harapan: 365, 5, 35, 60, 8030, 360)
SELECT 'dim_date' AS tabel, COUNT(*) AS jumlah_baris FROM dim_date
UNION ALL SELECT 'dim_site',            COUNT(*) FROM dim_site
UNION ALL SELECT 'fact_cost_structure', COUNT(*) FROM fact_cost_structure
UNION ALL SELECT 'fact_monthly',        COUNT(*) FROM fact_monthly
UNION ALL SELECT 'fact_equipment',      COUNT(*) FROM fact_equipment
UNION ALL SELECT 'fact_safety',         COUNT(*) FROM fact_safety;

-- 2.2 Data "yatim": baris fakta tanpa pasangan di dimensi (harapan: semua 0)
SELECT 'fact_monthly -> dim_site' AS relasi, COUNT(*) AS baris_yatim
FROM fact_monthly f LEFT JOIN dim_site s ON s.site_id = f.site_id WHERE s.site_id IS NULL
UNION ALL
SELECT 'fact_equipment -> dim_site', COUNT(*)
FROM fact_equipment f LEFT JOIN dim_site s ON s.site_id = f.site_id WHERE s.site_id IS NULL
UNION ALL
SELECT 'fact_safety -> dim_site', COUNT(*)
FROM fact_safety f LEFT JOIN dim_site s ON s.site_id = f.site_id WHERE s.site_id IS NULL
UNION ALL
SELECT 'fact_cost_structure -> dim_site', COUNT(*)
FROM fact_cost_structure f LEFT JOIN dim_site s ON s.site_id = f.site_id WHERE s.site_id IS NULL
UNION ALL
SELECT 'fact_equipment -> dim_date', COUNT(*)
FROM fact_equipment f LEFT JOIN dim_date d ON d.`Date` = f.`date` WHERE d.`Date` IS NULL
UNION ALL
SELECT 'fact_safety -> dim_date', COUNT(*)
FROM fact_safety f LEFT JOIN dim_date d ON d.`Date` = f.`date` WHERE d.`Date` IS NULL
UNION ALL
SELECT 'fact_monthly -> dim_date', COUNT(*)
FROM fact_monthly f LEFT JOIN dim_date d ON d.`Date` = f.month_start WHERE d.`Date` IS NULL;

-- 2.3 Rekonsiliasi total biaya: fact_monthly (12 bulan) vs fact_cost_structure (tahunan)
--     Selisih di bawah AUD 1 wajar akibat pembulatan per baris.
SELECT s.site_id,
       ROUND(m.biaya_bulanan, 2)    AS biaya_dari_bulanan,
       ROUND(c.biaya_struktur, 2)   AS biaya_dari_struktur,
       ROUND(m.biaya_bulanan - c.biaya_struktur, 2) AS selisih
FROM dim_site s
JOIN (SELECT site_id, SUM(total_cost_aud) AS biaya_bulanan FROM fact_monthly GROUP BY site_id) m
  ON m.site_id = s.site_id
JOIN (SELECT site_id, SUM(cost_aud) AS biaya_struktur FROM fact_cost_structure GROUP BY site_id) c
  ON c.site_id = s.site_id;

-- 2.4 Kelengkapan: jumlah bulan per site dan jumlah hari-unit per alat (harapan: 12 dan 365)
SELECT 'bulan_per_site' AS pemeriksaan, site_id AS kunci, COUNT(*) AS jumlah
FROM fact_monthly GROUP BY site_id
UNION ALL
SELECT 'hari_per_unit_alat', equipment_id, COUNT(*)
FROM fact_equipment GROUP BY equipment_id
HAVING COUNT(*) <> 365;

-- 2.5 Konsistensi jam alat: available = operating + idle ? dan downtime = maintenance + breakdown ?
--     (jumlah baris yang melanggar, toleransi 0,15 jam akibat pembulatan)
SELECT SUM(ABS(available_hours - (operating_hours + idle_hours)) > 0.15)               AS available_tidak_cocok,
       SUM(ABS(downtime_hours - (maintenance_hours + breakdown_hours)) > 0.15)         AS downtime_tidak_cocok,
       SUM(ABS(available_hours - (24 - downtime_hours)) > 0.15)                        AS available_vs_24_tidak_cocok,
       SUM(has_breakdown <> (breakdown_hours > 0))                                     AS flag_breakdown_tidak_cocok,
       SUM(is_anomaly <> (anomaly_status = 'Potential Anomaly'))                       AS flag_anomali_tidak_cocok
FROM fact_equipment;

-- 2.6 Konsistensi flag di fact_safety (harapan: semua 0)
SELECT SUM(is_lost_time_injury <> (incident_type = 'Lost Time Injury (LTI)'))              AS flag_lti_salah,
       SUM(is_medical_treatment_injury <> (incident_type = 'Medical Treatment Injury (MTI)')) AS flag_mti_salah,
       SUM(is_open_investigation <> (investigation_status = 'Under Investigation'))        AS flag_open_salah,
       SUM(is_lost_time_injury = 1 AND days_lost = 0)                                      AS lti_tanpa_hari_hilang,
       SUM(is_lost_time_injury = 0 AND days_lost > 0)                                      AS hari_hilang_bukan_lti
FROM fact_safety;

-- 2.7 Site tanpa insiden atau tanpa data alat (Nickel Point = Care & Maintenance)
SELECT s.site_id, s.site_name, s.status,
       (SELECT COUNT(*) FROM fact_equipment e WHERE e.site_id = s.site_id) AS baris_alat,
       (SELECT COUNT(*) FROM fact_safety    f WHERE f.site_id = s.site_id) AS jumlah_insiden
FROM dim_site s
ORDER BY s.site_id;


/* =====================================================================
   BAGIAN 3 - VIEW TERINTEGRASI
   ===================================================================== */

-- 3.1 Scorecard per site (satu baris per site, menggabungkan semua tabel fakta)
CREATE VIEW vw_site_scorecard AS
SELECT s.site_id,
       s.site_name,
       s.commodity,
       s.status,
       s.annual_target_tonnes,
       COALESCE(m.tonnes_mined, 0)                                        AS tonnes_mined,
       COALESCE(m.total_cost_aud, 0)                                      AS total_cost_aud,
       ROUND(m.total_cost_aud / NULLIF(m.tonnes_mined, 0), 4)             AS cost_per_tonne_aud,
       ROUND(m.tonnes_mined * 100.0 / NULLIF(s.annual_target_tonnes, 0), 2) AS target_attainment_pct,
       s.avg_plan_adherence_pct,
       ROUND(e.avg_oee_pct, 2)                                            AS avg_oee_pct,
       e.total_breakdown_hours,
       e.total_maintenance_cost_aud,
       e.anomaly_days,
       COALESCE(k.total_incidents, 0)                                     AS total_incidents,
       COALESCE(k.lti_count, 0)                                           AS lti_count,
       COALESCE(k.days_lost, 0)                                           AS days_lost,
       COALESCE(k.open_investigations, 0)                                 AS open_investigations
FROM dim_site s
LEFT JOIN (SELECT site_id, SUM(tonnes_mined) AS tonnes_mined, SUM(total_cost_aud) AS total_cost_aud
           FROM fact_monthly GROUP BY site_id) m ON m.site_id = s.site_id
LEFT JOIN (SELECT site_id, AVG(oee_pct) AS avg_oee_pct, SUM(breakdown_hours) AS total_breakdown_hours,
                  SUM(maintenance_cost_aud) AS total_maintenance_cost_aud, SUM(is_anomaly) AS anomaly_days
           FROM fact_equipment GROUP BY site_id) e ON e.site_id = s.site_id
LEFT JOIN (SELECT site_id, COUNT(*) AS total_incidents, SUM(is_lost_time_injury) AS lti_count,
                  SUM(days_lost) AS days_lost, SUM(is_open_investigation) AS open_investigations
           FROM fact_safety GROUP BY site_id) k ON k.site_id = s.site_id;

-- 3.2 Data bulanan per site (produksi + alat + K3) untuk analisis tren dan korelasi
CREATE VIEW vw_monthly_site AS
SELECT f.month_start,
       SUBSTR(f.month_start, 1, 7)                       AS bulan,
       d.`Quarter`                                       AS kuartal,
       f.site_id,
       f.days,
       f.tonnes_mined,
       f.total_cost_aud,
       ROUND(f.total_cost_aud / NULLIF(f.tonnes_mined, 0), 4) AS cost_per_tonne_aud,
       e.avg_oee_pct,
       e.breakdown_hours,
       e.breakdown_events,
       e.maintenance_cost_aud,
       COALESCE(k.incidents, 0)   AS incidents,
       COALESCE(k.lti, 0)         AS lti,
       COALESCE(k.days_lost, 0)   AS days_lost
FROM fact_monthly f
JOIN dim_date d ON d.`Date` = f.month_start
LEFT JOIN (SELECT site_id, SUBSTR(`date`, 1, 7) AS bulan,
                  ROUND(AVG(oee_pct), 2) AS avg_oee_pct,
                  SUM(breakdown_hours)   AS breakdown_hours,
                  SUM(has_breakdown)     AS breakdown_events,
                  SUM(maintenance_cost_aud) AS maintenance_cost_aud
           FROM fact_equipment GROUP BY site_id, SUBSTR(`date`, 1, 7)) e
       ON e.site_id = f.site_id AND e.bulan = SUBSTR(f.month_start, 1, 7)
LEFT JOIN (SELECT site_id, SUBSTR(`date`, 1, 7) AS bulan,
                  COUNT(*) AS incidents, SUM(is_lost_time_injury) AS lti, SUM(days_lost) AS days_lost
           FROM fact_safety GROUP BY site_id, SUBSTR(`date`, 1, 7)) k
       ON k.site_id = f.site_id AND k.bulan = SUBSTR(f.month_start, 1, 7);


/* =====================================================================
   BAGIAN 4 - RINGKASAN EKSEKUTIF
   ===================================================================== */

-- 4.1 Scorecard seluruh site
SELECT * FROM vw_site_scorecard ORDER BY total_cost_aud DESC;

-- 4.2 KPI portofolio satu baris
SELECT (SELECT SUM(tonnes_mined)    FROM fact_monthly)                     AS total_tonnes_mined,
       (SELECT SUM(total_cost_aud)  FROM fact_monthly)                     AS total_biaya_aud,
       (SELECT ROUND(AVG(oee_pct), 2) FROM fact_equipment)                 AS avg_oee_armada_pct,
       (SELECT ROUND(SUM(breakdown_hours), 1) FROM fact_equipment)         AS total_jam_breakdown,
       (SELECT COUNT(*) FROM fact_safety)                                  AS total_insiden,
       (SELECT SUM(is_lost_time_injury) FROM fact_safety)                  AS total_lti,
       (SELECT SUM(days_lost) FROM fact_safety)                            AS total_hari_hilang,
       (SELECT SUM(is_open_investigation) FROM fact_safety)                AS investigasi_terbuka;

-- 4.3 Share kontribusi tiap site: tonase, biaya, insiden, jam breakdown
SELECT site_id, site_name,
       ROUND(tonnes_mined * 100.0 / SUM(tonnes_mined) OVER (), 2)               AS share_tonase_pct,
       ROUND(total_cost_aud * 100.0 / SUM(total_cost_aud) OVER (), 2)           AS share_biaya_pct,
       ROUND(total_incidents * 100.0 / SUM(total_incidents) OVER (), 2)         AS share_insiden_pct,
       ROUND(total_breakdown_hours * 100.0 / SUM(total_breakdown_hours) OVER (), 2) AS share_jam_breakdown_pct
FROM vw_site_scorecard
WHERE status = 'Operational'
ORDER BY share_biaya_pct DESC;


/* =====================================================================
   BAGIAN 5 - PRODUKSI & BIAYA
   ===================================================================== */

-- 5.1 Biaya per ton dan pencapaian target per site (hanya site berproduksi)
SELECT site_id, site_name, commodity,
       annual_target_tonnes, tonnes_mined, target_attainment_pct,
       total_cost_aud, cost_per_tonne_aud,
       RANK() OVER (ORDER BY tonnes_mined DESC)       AS rank_produksi,
       RANK() OVER (ORDER BY target_attainment_pct DESC) AS rank_target
FROM vw_site_scorecard
WHERE tonnes_mined > 0;

-- 5.2 Tren kuartalan: tonase, biaya, biaya per ton per site
SELECT d.`Quarter` AS kuartal, f.site_id,
       SUM(f.tonnes_mined)                                          AS tonnes_mined,
       ROUND(SUM(f.total_cost_aud), 2)                              AS total_cost_aud,
       ROUND(SUM(f.total_cost_aud) / NULLIF(SUM(f.tonnes_mined), 0), 4) AS cost_per_tonne_aud,
       ROUND(SUM(f.tonnes_mined) / SUM(f.days), 1)                  AS tonnes_per_day
FROM fact_monthly f
JOIN dim_date d ON d.`Date` = f.month_start
WHERE f.site_id <> 'NICK001'
GROUP BY d.`Quarter`, f.site_id
ORDER BY f.site_id, kuartal;

-- 5.3 Perubahan bulan-ke-bulan biaya per ton dan produksi harian
SELECT bulan, site_id, tonnes_mined, total_cost_aud, cost_per_tonne_aud,
       ROUND((cost_per_tonne_aud / LAG(cost_per_tonne_aud) OVER (PARTITION BY site_id ORDER BY month_start) - 1) * 100, 2) AS cost_per_ton_mom_pct,
       ROUND((tonnes_mined * 1.0 / days) /
             (LAG(tonnes_mined * 1.0 / days) OVER (PARTITION BY site_id ORDER BY month_start)) * 100 - 100, 2) AS tonnes_per_day_mom_pct
FROM vw_monthly_site
WHERE site_id <> 'NICK001'
ORDER BY site_id, month_start;

-- 5.4 Total portofolio per bulan
SELECT bulan,
       SUM(tonnes_mined)               AS total_tonnes,
       ROUND(SUM(total_cost_aud), 2)   AS total_biaya_aud,
       SUM(incidents)                  AS total_insiden,
       ROUND(SUM(breakdown_hours), 1)  AS total_jam_breakdown
FROM vw_monthly_site
GROUP BY bulan
ORDER BY bulan;

-- 5.5 Bulan terbaik dan terburuk (biaya per ton) per site
SELECT site_id, bulan, cost_per_tonne_aud, kategori
FROM (
    SELECT site_id, bulan, cost_per_tonne_aud,
           CASE WHEN cost_per_tonne_aud = MAX(cost_per_tonne_aud) OVER (PARTITION BY site_id) THEN 'Tertinggi'
                WHEN cost_per_tonne_aud = MIN(cost_per_tonne_aud) OVER (PARTITION BY site_id) THEN 'Terendah' END AS kategori
    FROM vw_monthly_site
    WHERE site_id <> 'NICK001'
) t
WHERE kategori IS NOT NULL
ORDER BY site_id, kategori;

-- 5.6 Efek skala: bulan dengan produksi harian di atas rata-rata site dan biaya per ton di bawah rata-rata
SELECT x.site_id, x.bulan, ROUND(x.tpd, 1) AS tonnes_per_day, x.cost_per_tonne_aud
FROM (
    SELECT site_id, bulan, cost_per_tonne_aud, tonnes_mined * 1.0 / days AS tpd,
           AVG(tonnes_mined * 1.0 / days) OVER (PARTITION BY site_id) AS avg_tpd,
           AVG(cost_per_tonne_aud)        OVER (PARTITION BY site_id) AS avg_cpt
    FROM vw_monthly_site
    WHERE site_id <> 'NICK001'
) x
WHERE x.tpd > x.avg_tpd AND x.cost_per_tonne_aud < x.avg_cpt
ORDER BY x.site_id, x.bulan;


/* =====================================================================
   BAGIAN 6 - STRUKTUR BIAYA
   ===================================================================== */

-- 6.1 Matriks biaya per site x kategori (AUD)
SELECT site_id,
       SUM(CASE WHEN cost_category = 'Labor'       THEN cost_aud END) AS labor,
       SUM(CASE WHEN cost_category = 'Equipment'   THEN cost_aud END) AS equipment,
       SUM(CASE WHEN cost_category = 'Fuel'        THEN cost_aud END) AS fuel,
       SUM(CASE WHEN cost_category = 'Maintenance' THEN cost_aud END) AS maintenance,
       SUM(CASE WHEN cost_category = 'Consumables' THEN cost_aud END) AS consumables,
       SUM(CASE WHEN cost_category = 'Utilities'   THEN cost_aud END) AS utilities,
       SUM(CASE WHEN cost_category = 'Admin'       THEN cost_aud END) AS admin,
       SUM(cost_aud)                                                  AS total
FROM fact_cost_structure
GROUP BY site_id
ORDER BY total DESC;

-- 6.2 Persentase tiap kategori terhadap total biaya site
SELECT site_id, cost_category, ROUND(cost_aud, 2) AS cost_aud,
       ROUND(cost_aud * 100.0 / SUM(cost_aud) OVER (PARTITION BY site_id), 2) AS share_pct
FROM fact_cost_structure
ORDER BY site_id, cost_aud DESC;

-- 6.3 Struktur biaya portofolio per kategori
SELECT cost_category,
       ROUND(SUM(cost_aud), 2)                                       AS total_aud,
       ROUND(SUM(cost_aud) * 100.0 / SUM(SUM(cost_aud)) OVER (), 2)  AS share_pct
FROM fact_cost_structure
GROUP BY cost_category
ORDER BY total_aud DESC;

-- 6.4 Biaya per ton tambang untuk tiap kategori (site berproduksi)
SELECT c.site_id, c.cost_category,
       ROUND(c.cost_aud / m.tonnes, 4) AS biaya_per_ton_aud
FROM fact_cost_structure c
JOIN (SELECT site_id, SUM(tonnes_mined) AS tonnes FROM fact_monthly GROUP BY site_id) m
  ON m.site_id = c.site_id
WHERE m.tonnes > 0
ORDER BY c.site_id, biaya_per_ton_aud DESC;

-- 6.5 Biaya "inti" (Labor + Equipment + Fuel) vs lainnya
SELECT site_id,
       ROUND(SUM(CASE WHEN cost_category IN ('Labor', 'Equipment', 'Fuel') THEN cost_aud END), 2) AS biaya_inti_aud,
       ROUND(SUM(CASE WHEN cost_category IN ('Labor', 'Equipment', 'Fuel') THEN cost_aud END) * 100.0 / SUM(cost_aud), 2) AS biaya_inti_pct
FROM fact_cost_structure
GROUP BY site_id;

-- 6.6 Perbandingan biaya perawatan: kategori 'Maintenance' di struktur biaya vs biaya perawatan alat (fact_equipment)
--     Catatan: dua sumber berbeda cakupan, sehingga perbedaan nilai wajar
SELECT c.site_id,
       ROUND(c.cost_aud, 2)                  AS maintenance_di_struktur_biaya,
       ROUND(e.biaya_alat, 2)                AS biaya_perawatan_alat,
       ROUND(e.biaya_alat * 100.0 / c.cost_aud, 2) AS alat_sebagai_pct_dari_struktur
FROM fact_cost_structure c
JOIN (SELECT site_id, SUM(maintenance_cost_aud) AS biaya_alat FROM fact_equipment GROUP BY site_id) e
  ON e.site_id = c.site_id
WHERE c.cost_category = 'Maintenance';


/* =====================================================================
   BAGIAN 7 - BIAYA TETAP VS VARIABEL
   ===================================================================== */

-- 7.1 Parameter model biaya: Biaya Harian = Tetap + Variabel x Ton
SELECT s.site_id, s.site_name,
       s.fixed_cost_per_day_aud, s.variable_cost_per_tonne_aud,
       s.corr_tonnes_vs_cost, s.r2_linear_fit,
       ROUND(s.fixed_cost_per_day_aud * 365, 2) AS biaya_tetap_tahunan_aud,
       ROUND(s.fixed_cost_per_day_aud * 365 * 100.0 / sc.total_cost_aud, 3) AS share_biaya_tetap_pct
FROM dim_site s
JOIN vw_site_scorecard sc ON sc.site_id = s.site_id
ORDER BY share_biaya_tetap_pct DESC;

-- 7.2 Simulasi what-if produksi harian -10%, -5%, +5%, +10% terhadap biaya per ton
SELECT s.site_id,
       ROUND(m.avg_tpd, 1) AS tonnes_per_day,
       ROUND((s.fixed_cost_per_day_aud + s.variable_cost_per_tonne_aud * m.avg_tpd) / m.avg_tpd, 4)         AS cpt_base,
       ROUND((s.fixed_cost_per_day_aud + s.variable_cost_per_tonne_aud * m.avg_tpd * 0.90) / (m.avg_tpd * 0.90), 4) AS cpt_minus10,
       ROUND((s.fixed_cost_per_day_aud + s.variable_cost_per_tonne_aud * m.avg_tpd * 0.95) / (m.avg_tpd * 0.95), 4) AS cpt_minus5,
       ROUND((s.fixed_cost_per_day_aud + s.variable_cost_per_tonne_aud * m.avg_tpd * 1.05) / (m.avg_tpd * 1.05), 4) AS cpt_plus5,
       ROUND((s.fixed_cost_per_day_aud + s.variable_cost_per_tonne_aud * m.avg_tpd * 1.10) / (m.avg_tpd * 1.10), 4) AS cpt_plus10
FROM dim_site s
JOIN (SELECT site_id, SUM(tonnes_mined) * 1.0 / SUM(days) AS avg_tpd FROM fact_monthly GROUP BY site_id) m
  ON m.site_id = s.site_id
WHERE m.avg_tpd > 0;

-- 7.3 Biaya Nickel Point (Care & Maintenance) - seluruhnya biaya tetap
SELECT s.site_id, s.site_name, s.status,
       s.fixed_cost_per_day_aud,
       ROUND(SUM(f.total_cost_aud), 2) AS biaya_setahun_aud,
       ROUND(SUM(f.total_cost_aud) * 100.0 / (SELECT SUM(total_cost_aud) FROM fact_monthly), 3) AS share_biaya_portofolio_pct
FROM dim_site s
JOIN fact_monthly f ON f.site_id = s.site_id
WHERE s.status <> 'Operational'
GROUP BY s.site_id, s.site_name, s.status, s.fixed_cost_per_day_aud;


/* =====================================================================
   BAGIAN 8 - KINERJA ALAT BERAT
   ===================================================================== */

-- 8.1 Kinerja per tipe alat
SELECT equipment_type,
       COUNT(DISTINCT equipment_id)         AS unit,
       ROUND(AVG(availability_pct), 2)      AS avg_availability_pct,
       ROUND(AVG(utilization_pct), 2)       AS avg_utilization_pct,
       ROUND(AVG(oee_pct), 2)               AS avg_oee_pct,
       ROUND(SUM(breakdown_hours), 1)       AS total_jam_breakdown,
       ROUND(SUM(maintenance_cost_aud), 2)  AS total_biaya_perawatan_aud,
       ROUND(SUM(maintenance_cost_aud) / NULLIF(SUM(operating_hours), 0), 2) AS biaya_per_jam_operasi_aud,
       ROUND(SUM(fuel_consumed_liters) * 1.0 / NULLIF(SUM(operating_hours), 0), 2) AS liter_per_jam_operasi
FROM fact_equipment
GROUP BY equipment_type
ORDER BY avg_oee_pct DESC;

-- 8.2 Kinerja per model alat
SELECT model, equipment_type, operation_mode,
       COUNT(DISTINCT equipment_id)  AS unit,
       ROUND(AVG(oee_pct), 2)        AS avg_oee_pct,
       ROUND(SUM(breakdown_hours), 1) AS total_jam_breakdown,
       ROUND(SUM(maintenance_cost_aud) / COUNT(DISTINCT equipment_id), 2) AS biaya_per_unit_aud
FROM fact_equipment
GROUP BY model, equipment_type, operation_mode
ORDER BY avg_oee_pct DESC;

-- 8.3 Autonomous vs Conventional pada tipe alat yang sama
SELECT equipment_type, operation_mode,
       COUNT(DISTINCT equipment_id)    AS unit,
       ROUND(AVG(oee_pct), 2)          AS avg_oee_pct,
       ROUND(AVG(utilization_pct), 2)  AS avg_utilization_pct,
       ROUND(AVG(breakdown_hours), 3)  AS avg_jam_breakdown_per_hari,
       ROUND(AVG(maintenance_cost_aud), 2) AS avg_biaya_per_hari_aud
FROM fact_equipment
GROUP BY equipment_type, operation_mode
ORDER BY equipment_type, operation_mode;

-- 8.4 Tren kuartalan OEE dan breakdown
SELECT d.`Quarter` AS kuartal,
       ROUND(AVG(e.oee_pct), 2)        AS avg_oee_pct,
       ROUND(SUM(e.breakdown_hours), 1) AS total_jam_breakdown,
       SUM(e.has_breakdown)            AS kejadian_breakdown,
       ROUND(SUM(e.maintenance_cost_aud), 2) AS total_biaya_perawatan_aud
FROM fact_equipment e
JOIN dim_date d ON d.`Date` = e.`date`
GROUP BY d.`Quarter`
ORDER BY kuartal;

-- 8.5 Dampak breakdown: hari breakdown vs hari tanpa breakdown
SELECT CASE WHEN has_breakdown = 1 THEN 'Ada breakdown' ELSE 'Tanpa breakdown' END AS kondisi,
       COUNT(*)                              AS jumlah_hari_unit,
       ROUND(AVG(oee_pct), 2)                AS avg_oee_pct,
       ROUND(AVG(maintenance_cost_aud), 2)   AS avg_biaya_perawatan_aud,
       ROUND(AVG(fuel_consumed_liters), 0)   AS avg_bbm_liter
FROM fact_equipment
GROUP BY has_breakdown;

-- 8.6 Scorecard unit alat dan peringkat prioritas perhatian
SELECT equipment_id, equipment_type, model, site_id, operation_mode,
       ROUND(AVG(oee_pct), 2)               AS avg_oee_pct,
       ROUND(SUM(breakdown_hours), 1)       AS total_jam_breakdown,
       SUM(has_breakdown)                   AS hari_breakdown,
       ROUND(SUM(maintenance_cost_aud), 2)  AS total_biaya_perawatan_aud,
       SUM(is_anomaly)                      AS hari_anomali,
       RANK() OVER (ORDER BY SUM(breakdown_hours) DESC) AS rank_breakdown
FROM fact_equipment
GROUP BY equipment_id, equipment_type, model, site_id, operation_mode
ORDER BY total_jam_breakdown DESC;

-- 8.7 Kualitas deteksi anomali terhadap kejadian breakdown
SELECT SUM(has_breakdown = 1 AND is_anomaly = 1)  AS breakdown_terdeteksi,
       SUM(has_breakdown = 1 AND is_anomaly = 0)  AS breakdown_terlewat,
       SUM(has_breakdown = 0 AND is_anomaly = 1)  AS anomali_tanpa_breakdown,
       ROUND(SUM(has_breakdown = 1 AND is_anomaly = 1) * 100.0 / NULLIF(SUM(has_breakdown = 1), 0), 2) AS recall_pct,
       ROUND(SUM(has_breakdown = 1 AND is_anomaly = 1) * 100.0 / NULLIF(SUM(is_anomaly = 1), 0), 2)   AS presisi_pct
FROM fact_equipment;


/* =====================================================================
   BAGIAN 9 - KESELAMATAN KERJA (K3)
   ===================================================================== */

-- 9.1 Ringkasan per kategori dan jenis insiden
SELECT incident_category, incident_type, severity,
       COUNT(*)                                          AS jumlah,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS persen,
       SUM(days_lost)                                    AS hari_hilang,
       SUM(is_open_investigation)                        AS investigasi_terbuka
FROM fact_safety
GROUP BY incident_category, incident_type, severity
ORDER BY jumlah DESC;

-- 9.2 Piramida insiden per site (LTI > MTI > FAI > PSI > Near Miss > Environmental)
SELECT site_id,
       SUM(incident_type = 'Lost Time Injury (LTI)')                 AS lti,
       SUM(incident_type = 'Medical Treatment Injury (MTI)')         AS mti,
       SUM(incident_type = 'First Aid Injury (FAI)')                 AS fai,
       SUM(incident_type = 'Potential Significant Incident (PSI)')   AS psi,
       SUM(incident_type = 'Near Miss')                              AS near_miss,
       SUM(incident_type = 'Environmental Incident')                 AS environmental,
       COUNT(*)                                                      AS total
FROM fact_safety
GROUP BY site_id
ORDER BY total DESC;

-- 9.3 Tingkat insiden dinormalisasi terhadap produksi (per juta ton ditambang)
SELECT sc.site_id, sc.site_name, sc.tonnes_mined, sc.total_incidents, sc.lti_count,
       ROUND(sc.total_incidents * 1000000.0 / NULLIF(sc.tonnes_mined, 0), 2)  AS insiden_per_juta_ton,
       ROUND(sc.lti_count       * 1000000.0 / NULLIF(sc.tonnes_mined, 0), 3)  AS lti_per_juta_ton,
       sc.days_lost,
       ROUND(sc.days_lost * 1.0 / NULLIF(sc.lti_count, 0), 1)                 AS rata2_hari_hilang_per_lti
FROM vw_site_scorecard sc
WHERE sc.status = 'Operational'
ORDER BY insiden_per_juta_ton DESC;

-- 9.4 Tingkat insiden per unit alat (dinormalisasi terhadap ukuran armada site)
SELECT s.site_id,
       COUNT(DISTINCT e.equipment_id)                            AS unit_alat,
       COUNT(DISTINCT s.incident_id)                             AS total_insiden,
       ROUND(COUNT(DISTINCT s.incident_id) * 1.0 / COUNT(DISTINCT e.equipment_id), 2) AS insiden_per_unit_alat
FROM fact_safety s
JOIN fact_equipment e ON e.site_id = s.site_id
GROUP BY s.site_id
ORDER BY insiden_per_unit_alat DESC;

-- 9.5 Akar penyebab: keseluruhan dan menurut kategori insiden
SELECT root_cause,
       COUNT(*)                                            AS jumlah,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)  AS persen,
       SUM(incident_category = 'Injury')                   AS cedera,
       SUM(incident_category = 'Near miss or potential incident') AS near_miss_psi,
       SUM(incident_category = 'Environmental')            AS lingkungan,
       SUM(days_lost)                                      AS hari_hilang
FROM fact_safety
GROUP BY root_cause
ORDER BY jumlah DESC;

-- 9.6 Akar penyebab insiden yang menyebabkan hilang hari kerja (LTI)
SELECT root_cause, COUNT(*) AS jumlah_lti, SUM(days_lost) AS hari_hilang
FROM fact_safety
WHERE is_lost_time_injury = 1
GROUP BY root_cause
ORDER BY hari_hilang DESC;

-- 9.7 Daftar seluruh LTI
SELECT incident_id, `date`, site_id, description, days_lost, root_cause, investigation_status
FROM fact_safety
WHERE is_lost_time_injury = 1
ORDER BY days_lost DESC, `date`;

-- 9.8 Investigasi yang masih terbuka: per site, tingkat keparahan, dan umur (hari sejak kejadian
--     sampai akhir periode data 2025-12-31)
SELECT site_id, severity,
       COUNT(*)                                                       AS investigasi_terbuka,
       ROUND(AVG(DATEDIFF('2025-12-31', `date`)), 1)                  AS rata2_umur_hari,
       MAX(DATEDIFF('2025-12-31', `date`))                            AS umur_tertua_hari
FROM fact_safety
WHERE is_open_investigation = 1
GROUP BY site_id, severity
ORDER BY site_id, severity;

-- 9.9 Persentase investigasi terbuka per jenis insiden (penutupan insiden serius vs ringan)
SELECT incident_type,
       COUNT(*)                                                     AS jumlah,
       SUM(is_open_investigation)                                   AS terbuka,
       ROUND(SUM(is_open_investigation) * 100.0 / COUNT(*), 2)      AS pct_terbuka
FROM fact_safety
GROUP BY incident_type
ORDER BY pct_terbuka DESC;

-- 9.10 Tren kuartalan insiden
SELECT d.`Quarter` AS kuartal,
       COUNT(*)                         AS total_insiden,
       SUM(f.is_lost_time_injury)       AS lti,
       SUM(f.incident_category = 'Injury') AS cedera,
       SUM(f.days_lost)                 AS hari_hilang
FROM fact_safety f
JOIN dim_date d ON d.`Date` = f.`date`
GROUP BY d.`Quarter`
ORDER BY kuartal;

-- 9.11 Jenis kejadian (kolom description) paling sering per kategori insiden
SELECT incident_category, description, COUNT(*) AS jumlah
FROM fact_safety
GROUP BY incident_category, description
ORDER BY incident_category, jumlah DESC;


/* =====================================================================
   BAGIAN 10 - ANALISIS LINTAS DOMAIN (PRODUKSI - ALAT - K3)
   ===================================================================== */

-- 10.1 Perbandingan lintas domain per site dengan peringkat (1 = terbaik)
SELECT site_id, site_name,
       cost_per_tonne_aud,
       avg_oee_pct,
       total_breakdown_hours,
       ROUND(total_incidents * 1000000.0 / NULLIF(tonnes_mined, 0), 2) AS insiden_per_juta_ton,
       RANK() OVER (ORDER BY target_attainment_pct DESC)                AS rank_target_produksi,
       RANK() OVER (ORDER BY avg_oee_pct DESC)                          AS rank_oee,
       RANK() OVER (ORDER BY total_incidents * 1.0 / NULLIF(tonnes_mined, 0)) AS rank_k3
FROM vw_site_scorecard
WHERE status = 'Operational'
ORDER BY site_id;

-- 10.2 Apakah insiden lebih sering terjadi pada hari ketika site mengalami breakdown alat?
--      Dasar: satuan = hari-site (site x tanggal). Bandingkan laju insiden per hari-site.
SELECT CASE WHEN b.has_bd = 1 THEN 'Hari dengan breakdown alat' ELSE 'Hari tanpa breakdown alat' END AS kondisi,
       COUNT(*)                                       AS hari_site,
       SUM(COALESCE(i.jml, 0))                        AS total_insiden,
       ROUND(SUM(COALESCE(i.jml, 0)) * 1.0 / COUNT(*), 4) AS insiden_per_hari_site
FROM (SELECT `date`, site_id, MAX(has_breakdown) AS has_bd
      FROM fact_equipment GROUP BY `date`, site_id) b
LEFT JOIN (SELECT `date`, site_id, COUNT(*) AS jml
           FROM fact_safety GROUP BY `date`, site_id) i
       ON i.`date` = b.`date` AND i.site_id = b.site_id
GROUP BY b.has_bd;

-- 10.3 Sama seperti 10.2, khusus insiden cedera (Injury) dan insiden dengan akar penyebab Equipment Failure
SELECT CASE WHEN b.has_bd = 1 THEN 'Hari dengan breakdown alat' ELSE 'Hari tanpa breakdown alat' END AS kondisi,
       COUNT(*)                                        AS hari_site,
       SUM(COALESCE(i.cedera, 0))                      AS insiden_cedera,
       SUM(COALESCE(i.equip_failure, 0))               AS insiden_akar_equipment_failure
FROM (SELECT `date`, site_id, MAX(has_breakdown) AS has_bd
      FROM fact_equipment GROUP BY `date`, site_id) b
LEFT JOIN (SELECT `date`, site_id,
                  SUM(incident_category = 'Injury')      AS cedera,
                  SUM(root_cause = 'Equipment Failure')  AS equip_failure
           FROM fact_safety GROUP BY `date`, site_id) i
       ON i.`date` = b.`date` AND i.site_id = b.site_id
GROUP BY b.has_bd;

-- 10.4 Data bulanan gabungan per site (untuk dilihat langsung atau diekspor ke visualisasi)
SELECT bulan, site_id, tonnes_mined, cost_per_tonne_aud, avg_oee_pct,
       breakdown_hours, incidents, lti
FROM vw_monthly_site
WHERE site_id <> 'NICK001'
ORDER BY site_id, bulan;

-- 10.5 Korelasi (Pearson) antar indikator pada level site-bulan (48 titik)
--      Rumus: (E[xy] - E[x]E[y]) / (sd_x * sd_y)
SELECT pasangan, ROUND(r, 3) AS korelasi
FROM (
    SELECT 'Tonase vs insiden' AS pasangan,
           (AVG(tonnes_mined * incidents) - AVG(tonnes_mined) * AVG(incidents)) /
           NULLIF(SQRT(AVG(tonnes_mined * tonnes_mined) - AVG(tonnes_mined) * AVG(tonnes_mined)) *
                  SQRT(AVG(incidents * incidents) - AVG(incidents) * AVG(incidents)), 0) AS r
    FROM vw_monthly_site WHERE site_id <> 'NICK001'
    UNION ALL
    SELECT 'Jam breakdown vs insiden',
           (AVG(breakdown_hours * incidents) - AVG(breakdown_hours) * AVG(incidents)) /
           NULLIF(SQRT(AVG(breakdown_hours * breakdown_hours) - AVG(breakdown_hours) * AVG(breakdown_hours)) *
                  SQRT(AVG(incidents * incidents) - AVG(incidents) * AVG(incidents)), 0)
    FROM vw_monthly_site WHERE site_id <> 'NICK001'
    UNION ALL
    SELECT 'OEE vs biaya per ton',
           (AVG(avg_oee_pct * cost_per_tonne_aud) - AVG(avg_oee_pct) * AVG(cost_per_tonne_aud)) /
           NULLIF(SQRT(AVG(avg_oee_pct * avg_oee_pct) - AVG(avg_oee_pct) * AVG(avg_oee_pct)) *
                  SQRT(AVG(cost_per_tonne_aud * cost_per_tonne_aud) - AVG(cost_per_tonne_aud) * AVG(cost_per_tonne_aud)), 0)
    FROM vw_monthly_site WHERE site_id <> 'NICK001'
    UNION ALL
    SELECT 'Jam breakdown vs biaya perawatan alat',
           (AVG(breakdown_hours * maintenance_cost_aud) - AVG(breakdown_hours) * AVG(maintenance_cost_aud)) /
           NULLIF(SQRT(AVG(breakdown_hours * breakdown_hours) - AVG(breakdown_hours) * AVG(breakdown_hours)) *
                  SQRT(AVG(maintenance_cost_aud * maintenance_cost_aud) - AVG(maintenance_cost_aud) * AVG(maintenance_cost_aud)), 0)
    FROM vw_monthly_site WHERE site_id <> 'NICK001'
) k;

-- 10.6 Fokus perhatian: site-bulan dengan insiden di atas rata-rata site DAN breakdown di atas rata-rata site
SELECT x.site_id, x.bulan, x.incidents, ROUND(x.breakdown_hours, 1) AS jam_breakdown, x.lti
FROM (
    SELECT site_id, bulan, incidents, breakdown_hours, lti,
           AVG(incidents)       OVER (PARTITION BY site_id) AS avg_inc,
           AVG(breakdown_hours) OVER (PARTITION BY site_id) AS avg_bd
    FROM vw_monthly_site
    WHERE site_id <> 'NICK001'
) x
WHERE x.incidents > x.avg_inc AND x.breakdown_hours > x.avg_bd
ORDER BY x.site_id, x.bulan;

/* ========================= AKHIR DOKUMEN ========================= */
