/* =====================================================================
   ANALISIS BIAYA & EFISIENSI OPERASIONAL TAMBANG  (MySQL 8.0+)
   ---------------------------------------------------------------------
   Dataset (5 file CSV):
     1. site_cost_efficiency_summary.csv  -> ringkasan efisiensi per site
     2. site_cost_structure.csv           -> struktur biaya per site
     3. production_cost_relationship.csv  -> hubungan produksi vs biaya
     4. monthly_site_trends.csv           -> tren bulanan per site
     5. cost_model_predictions.csv        -> prediksi biaya harian (3 model)

   Isi dokumen:
     BAGIAN 1  Setup database, tabel, dan load data
     BAGIAN 2  Pengecekan kualitas data
     BAGIAN 3  Profil & peringkat efisiensi site
     BAGIAN 4  Biaya vs target (basis yang sebanding)
     BAGIAN 5  Struktur biaya
     BAGIAN 6  Biaya tetap vs variabel (operating leverage)
     BAGIAN 7  Tren bulanan
     BAGIAN 8  Evaluasi model prediksi biaya
     BAGIAN 9  View ringkasan KPI (untuk dashboard / visualisasi)

   Cara pakai:
     - Ganti path file CSV di BAGIAN 1 sesuai lokasi di komputer Anda.
     - Jika memakai Windows dan baris tidak terbaca, ganti '\n' menjadi '\r\n'.
     - Aktifkan local_infile:  SET GLOBAL local_infile = 1;
       dan konek dengan:       mysql --local-infile=1 -u root -p
   ===================================================================== */


/* =====================================================================
   BAGIAN 1 - SETUP DATABASE, TABEL, DAN LOAD DATA
   ===================================================================== */

CREATE DATABASE IF NOT EXISTS mining_cost_analysis;
USE mining_cost_analysis;

DROP VIEW  IF EXISTS vw_site_kpi;
DROP TABLE IF EXISTS cost_model_predictions;
DROP TABLE IF EXISTS monthly_site_trends;
DROP TABLE IF EXISTS production_cost_relationship;
DROP TABLE IF EXISTS site_cost_structure;
DROP TABLE IF EXISTS site_cost_efficiency_summary;

-- 1.1 Ringkasan efisiensi per site
CREATE TABLE site_cost_efficiency_summary (
    site_id                      VARCHAR(10) PRIMARY KEY,
    site_name                    VARCHAR(50),
    commodity                    VARCHAR(30),
    status                       VARCHAR(30),
    days                         INT,
    producing_days               INT,
    total_tonnes_mined           BIGINT,
    total_tonnes_processed       BIGINT,
    annual_target_tonnes         BIGINT,
    cost_per_unit_target_aud     DECIMAL(18,4),
    implied_units                DECIMAL(20,4),
    avg_plan_adherence_pct       DECIMAL(10,4),
    total_downtime_hours         DECIMAL(10,2),
    total_cost_aud               DECIMAL(20,2),
    target_attainment_pct        DECIMAL(10,4),
    cost_per_tonne_mined_aud     DECIMAL(18,4),
    cost_per_tonne_processed_aud DECIMAL(18,4),
    cost_per_reported_unit_aud   DECIMAL(18,4),
    unit_basis                   VARCHAR(40),
    cost_vs_target_per_unit_pct  DECIMAL(18,4),
    cost_vs_target_per_tonne_pct DECIMAL(18,4),
    target_basis                 VARCHAR(40),
    cost_vs_target_pct           DECIMAL(18,4),
    avg_daily_cost_aud           DECIMAL(18,4),
    share_of_tonnes_pct          DECIMAL(10,4),
    share_of_cost_pct            DECIMAL(10,4),
    production_rank              INT,
    cost_per_tonne_rank          DECIMAL(5,1)
);

-- 1.2 Struktur biaya per site
CREATE TABLE site_cost_structure (
    site_id               VARCHAR(10) PRIMARY KEY,
    labor_cost_aud        DECIMAL(20,2),
    equipment_cost_aud    DECIMAL(20,2),
    fuel_cost_aud         DECIMAL(20,2),
    maintenance_cost_aud  DECIMAL(20,2),
    consumables_cost_aud  DECIMAL(20,2),
    utilities_cost_aud    DECIMAL(20,2),
    admin_cost_aud        DECIMAL(20,2),
    total_cost_aud        DECIMAL(20,2),
    labor_share_pct       DECIMAL(10,4),
    equipment_share_pct   DECIMAL(10,4),
    fuel_share_pct        DECIMAL(10,4),
    maintenance_share_pct DECIMAL(10,4),
    consumables_share_pct DECIMAL(10,4),
    utilities_share_pct   DECIMAL(10,4),
    admin_share_pct       DECIMAL(10,4)
);

-- 1.3 Hubungan produksi vs biaya
CREATE TABLE production_cost_relationship (
    site_id                        VARCHAR(10) PRIMARY KEY,
    days                           INT,
    avg_daily_tonnes               DECIMAL(18,6),
    avg_daily_cost_aud             DECIMAL(18,6),
    corr_tonnes_vs_cost            DECIMAL(10,6),
    variable_cost_per_tonne_aud    DECIMAL(18,6),
    fixed_cost_per_day_aud         DECIMAL(18,6),
    fixed_cost_share_pct           DECIMAL(10,6),
    r2_linear_fit                  DECIMAL(10,6),
    corr_tonnes_vs_cost_per_tonne  DECIMAL(10,6),
    daily_cost_per_tonne_cv_pct    DECIMAL(10,6)
);

-- 1.4 Tren bulanan
CREATE TABLE monthly_site_trends (
    month_start          DATE,
    site_id              VARCHAR(10),
    days                 INT,
    tonnes_mined         BIGINT,
    total_cost_aud       DECIMAL(20,2),
    tonnes_per_day       DECIMAL(18,4),
    cost_per_day_aud     DECIMAL(18,4),
    cost_per_tonne_aud   DECIMAL(18,4),
    tonnes_per_day_index DECIMAL(10,4),
    cost_per_tonne_index DECIMAL(10,4),
    cost_per_day_index   DECIMAL(10,4),
    PRIMARY KEY (month_start, site_id)
);

-- 1.5 Prediksi biaya harian
CREATE TABLE cost_model_predictions (
    `date`                      DATE,
    site_id                     VARCHAR(10),
    tonnes_mined                BIGINT,
    actual_cost_aud             DECIMAL(18,2),
    predicted_site_average_aud  DECIMAL(18,4),
    predicted_linear_aud        DECIMAL(18,4),
    predicted_random_forest_aud DECIMAL(18,4),
    downtime_day                TINYINT(1),
    rf_error_aud                DECIMAL(18,4),
    rf_abs_pct_error            DECIMAL(10,4),
    PRIMARY KEY (`date`, site_id)
);

-- 1.6 Load data (nilai kosong -> NULL, True/False -> 1/0)
LOAD DATA LOCAL INFILE 'site_cost_efficiency_summary.csv'
INTO TABLE site_cost_efficiency_summary
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(site_id, site_name, commodity, status, days, producing_days,
 total_tonnes_mined, total_tonnes_processed, annual_target_tonnes,
 cost_per_unit_target_aud, implied_units, avg_plan_adherence_pct,
 total_downtime_hours, total_cost_aud, @target_attainment_pct,
 @cost_per_tonne_mined_aud, @cost_per_tonne_processed_aud,
 @cost_per_reported_unit_aud, @unit_basis, @cost_vs_target_per_unit_pct,
 @cost_vs_target_per_tonne_pct, @target_basis, @cost_vs_target_pct,
 avg_daily_cost_aud, share_of_tonnes_pct, share_of_cost_pct,
 production_rank, @cost_per_tonne_rank)
SET target_attainment_pct        = NULLIF(@target_attainment_pct, ''),
    cost_per_tonne_mined_aud     = NULLIF(@cost_per_tonne_mined_aud, ''),
    cost_per_tonne_processed_aud = NULLIF(@cost_per_tonne_processed_aud, ''),
    cost_per_reported_unit_aud   = NULLIF(@cost_per_reported_unit_aud, ''),
    unit_basis                   = NULLIF(@unit_basis, ''),
    cost_vs_target_per_unit_pct  = NULLIF(@cost_vs_target_per_unit_pct, ''),
    cost_vs_target_per_tonne_pct = NULLIF(@cost_vs_target_per_tonne_pct, ''),
    target_basis                 = NULLIF(@target_basis, ''),
    cost_vs_target_pct           = NULLIF(@cost_vs_target_pct, ''),
    cost_per_tonne_rank          = NULLIF(@cost_per_tonne_rank, '');

LOAD DATA LOCAL INFILE 'site_cost_structure.csv'
INTO TABLE site_cost_structure
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'production_cost_relationship.csv'
INTO TABLE production_cost_relationship
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(site_id, days, avg_daily_tonnes, avg_daily_cost_aud, @corr_tonnes_vs_cost,
 @variable_cost_per_tonne_aud, fixed_cost_per_day_aud, fixed_cost_share_pct,
 @r2_linear_fit, @corr_tonnes_vs_cost_per_tonne, @daily_cost_per_tonne_cv_pct)
SET corr_tonnes_vs_cost           = NULLIF(@corr_tonnes_vs_cost, ''),
    variable_cost_per_tonne_aud   = NULLIF(@variable_cost_per_tonne_aud, ''),
    r2_linear_fit                 = NULLIF(@r2_linear_fit, ''),
    corr_tonnes_vs_cost_per_tonne = NULLIF(@corr_tonnes_vs_cost_per_tonne, ''),
    daily_cost_per_tonne_cv_pct   = NULLIF(@daily_cost_per_tonne_cv_pct, '');

LOAD DATA LOCAL INFILE 'monthly_site_trends.csv'
INTO TABLE monthly_site_trends
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(month_start, site_id, days, tonnes_mined, total_cost_aud, tonnes_per_day,
 cost_per_day_aud, @cost_per_tonne_aud, @tonnes_per_day_index,
 @cost_per_tonne_index, cost_per_day_index)
SET cost_per_tonne_aud   = NULLIF(@cost_per_tonne_aud, ''),
    tonnes_per_day_index = NULLIF(@tonnes_per_day_index, ''),
    cost_per_tonne_index = NULLIF(@cost_per_tonne_index, '');

LOAD DATA LOCAL INFILE 'cost_model_predictions.csv'
INTO TABLE cost_model_predictions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(`date`, site_id, tonnes_mined, actual_cost_aud, predicted_site_average_aud,
 predicted_linear_aud, predicted_random_forest_aud, @downtime_day,
 rf_error_aud, rf_abs_pct_error)
SET downtime_day = (@downtime_day IN ('True', 'TRUE', 'true', '1'));


/* =====================================================================
   BAGIAN 2 - PENGECEKAN KUALITAS DATA
   ===================================================================== */

-- 2.1 Jumlah baris tiap tabel (harapan: 5, 5, 5, 60, 365)
SELECT 'site_cost_efficiency_summary' AS tabel, COUNT(*) AS jumlah_baris FROM site_cost_efficiency_summary
UNION ALL SELECT 'site_cost_structure',          COUNT(*) FROM site_cost_structure
UNION ALL SELECT 'production_cost_relationship', COUNT(*) FROM production_cost_relationship
UNION ALL SELECT 'monthly_site_trends',          COUNT(*) FROM monthly_site_trends
UNION ALL SELECT 'cost_model_predictions',       COUNT(*) FROM cost_model_predictions;

-- 2.2 Konsistensi total biaya antara tabel efisiensi dan tabel struktur biaya
SELECT e.site_id,
       e.total_cost_aud AS biaya_efisiensi,
       s.total_cost_aud AS biaya_struktur,
       ROUND(e.total_cost_aud - s.total_cost_aud, 2) AS selisih
FROM site_cost_efficiency_summary e
JOIN site_cost_structure s ON s.site_id = e.site_id;

-- 2.3 Total biaya bulanan (jumlah 12 bulan) vs total biaya tahunan per site
SELECT m.site_id,
       ROUND(SUM(m.total_cost_aud), 2) AS biaya_dari_bulanan,
       e.total_cost_aud                AS biaya_tahunan,
       ROUND(SUM(m.total_cost_aud) - e.total_cost_aud, 2) AS selisih
FROM monthly_site_trends m
JOIN site_cost_efficiency_summary e ON e.site_id = m.site_id
GROUP BY m.site_id, e.total_cost_aud;

-- 2.4 Nilai NULL pada metrik biaya per ton (wajar untuk site non-produksi)
SELECT site_id, site_name, status,
       cost_per_tonne_mined_aud IS NULL AS tanpa_cost_per_tonne
FROM site_cost_efficiency_summary;

-- 2.5 Rentang tanggal data prediksi & jumlah hari per site
SELECT site_id, MIN(`date`) AS tanggal_awal, MAX(`date`) AS tanggal_akhir,
       COUNT(*) AS jumlah_hari
FROM cost_model_predictions
GROUP BY site_id;

-- 2.6 Validasi kolom rf_abs_pct_error terhadap hitungan ulang (harapan: selisih ~ 0)
SELECT ROUND(MAX(ABS(rf_abs_pct_error -
         CASE WHEN actual_cost_aud = 0 THEN 0
              ELSE ABS(actual_cost_aud - predicted_random_forest_aud) / actual_cost_aud * 100 END)), 2)
       AS selisih_maks_pct_point
FROM cost_model_predictions;


/* =====================================================================
   BAGIAN 3 - PROFIL & PERINGKAT EFISIENSI SITE
   ===================================================================== */

-- 3.1 Profil operasional seluruh site
SELECT site_id, site_name, commodity, status,
       producing_days, total_tonnes_mined, total_tonnes_processed,
       ROUND(total_tonnes_processed / NULLIF(total_tonnes_mined, 0) * 100, 2) AS recovery_proses_pct,
       annual_target_tonnes,
       target_attainment_pct, avg_plan_adherence_pct,
       total_downtime_hours,
       ROUND(total_downtime_hours / (days * 24) * 100, 2) AS downtime_pct_dari_waktu_total
FROM site_cost_efficiency_summary
ORDER BY production_rank;

-- 3.2 Kontribusi tonase vs kontribusi biaya (site mana yang "mahal" relatif terhadap output)
SELECT site_id, site_name,
       share_of_tonnes_pct,
       share_of_cost_pct,
       ROUND(share_of_cost_pct - share_of_tonnes_pct, 2)               AS selisih_share_pct_point,
       ROUND(share_of_cost_pct / NULLIF(share_of_tonnes_pct, 0), 2)    AS rasio_biaya_terhadap_tonase
FROM site_cost_efficiency_summary
WHERE status = 'Operational'
ORDER BY rasio_biaya_terhadap_tonase DESC;

-- 3.3 Peringkat site berproduksi: tonase, biaya, dan biaya per ton
SELECT site_id, site_name, commodity,
       total_tonnes_mined,
       total_cost_aud,
       cost_per_tonne_mined_aud,
       cost_per_tonne_processed_aud,
       RANK() OVER (ORDER BY total_tonnes_mined DESC)      AS rank_produksi,
       RANK() OVER (ORDER BY cost_per_tonne_mined_aud)     AS rank_biaya_per_ton_termurah,
       RANK() OVER (ORDER BY avg_plan_adherence_pct DESC)  AS rank_kepatuhan_rencana
FROM site_cost_efficiency_summary
WHERE status = 'Operational';

-- 3.4 Ringkasan portofolio (seluruh site)
SELECT COUNT(*)                                          AS jumlah_site,
       SUM(status = 'Operational')                       AS site_operasional,
       SUM(status <> 'Operational')                      AS site_non_operasional,
       SUM(total_cost_aud)                               AS total_biaya_aud,
       SUM(total_downtime_hours)                         AS total_jam_downtime,
       ROUND(AVG(CASE WHEN status = 'Operational' THEN avg_plan_adherence_pct END), 2) AS rata2_kepatuhan_rencana_pct,
       ROUND(AVG(CASE WHEN status = 'Operational' THEN target_attainment_pct END), 2)  AS rata2_pencapaian_target_pct
FROM site_cost_efficiency_summary;


/* =====================================================================
   BAGIAN 4 - BIAYA VS TARGET
   Catatan penting: target biaya Lithium dan Copper dinyatakan dalam satuan
   logam (unit metal) sehingga TIDAK sebanding langsung dengan biaya per ton.
   Persentase seperti 11192% (Lithium per unit) atau 220349% (Copper per ton)
   adalah artefak perbedaan satuan, bukan kinerja sebenarnya. Query di bawah
   hanya memakai basis yang sebanding (kolom target_basis).
   ===================================================================== */

-- 4.1 Status biaya vs target pada basis yang sebanding
SELECT site_id, site_name, commodity, target_basis,
       cost_per_unit_target_aud AS target_biaya,
       CASE target_basis
            WHEN 'per tonne mined'    THEN cost_per_tonne_mined_aud
            WHEN 'per reported unit'  THEN cost_per_reported_unit_aud
       END AS biaya_aktual,
       cost_vs_target_pct,
       CASE WHEN cost_vs_target_pct IS NULL THEN 'Tidak sebanding (satuan berbeda)'
            WHEN cost_vs_target_pct <= -1   THEN 'Jauh di bawah target (hemat)'
            WHEN cost_vs_target_pct <=  1   THEN 'Sesuai target (+/- 1%)'
            ELSE 'Melebihi target (boros)' END AS status_biaya
FROM site_cost_efficiency_summary
WHERE status = 'Operational'
ORDER BY cost_vs_target_pct;

-- 4.2 Selisih biaya dalam AUD terhadap target (hanya basis sebanding)
SELECT site_id, site_name, target_basis,
       ROUND(total_cost_aud / (1 + cost_vs_target_pct / 100), 2)  AS biaya_pada_target_aud,
       total_cost_aud                                             AS biaya_aktual_aud,
       ROUND(total_cost_aud - total_cost_aud / (1 + cost_vs_target_pct / 100), 2) AS selisih_aud
FROM site_cost_efficiency_summary
WHERE cost_vs_target_pct IS NOT NULL
  AND target_basis IN ('per tonne mined', 'per reported unit');

-- 4.3 Pencapaian target produksi dan sisa kekurangan tonase
SELECT site_id, site_name, annual_target_tonnes, total_tonnes_mined,
       target_attainment_pct,
       annual_target_tonnes - total_tonnes_mined AS kekurangan_tonase,
       ROUND((annual_target_tonnes - total_tonnes_mined) * cost_per_tonne_mined_aud, 2)
           AS estimasi_biaya_variabel_kekurangan_aud
FROM site_cost_efficiency_summary
WHERE status = 'Operational'
ORDER BY target_attainment_pct;


/* =====================================================================
   BAGIAN 5 - STRUKTUR BIAYA
   ===================================================================== */

-- 5.1 Struktur biaya per site (nilai AUD dan persentase)
SELECT * FROM site_cost_structure;

-- 5.2 Struktur biaya total portofolio per kategori
SELECT kategori, ROUND(nilai_aud, 2) AS total_aud,
       ROUND(nilai_aud / SUM(nilai_aud) OVER () * 100, 2) AS share_pct
FROM (
    SELECT 'Labor'       AS kategori, SUM(labor_cost_aud)       AS nilai_aud FROM site_cost_structure
    UNION ALL SELECT 'Equipment',   SUM(equipment_cost_aud)   FROM site_cost_structure
    UNION ALL SELECT 'Fuel',        SUM(fuel_cost_aud)        FROM site_cost_structure
    UNION ALL SELECT 'Maintenance', SUM(maintenance_cost_aud) FROM site_cost_structure
    UNION ALL SELECT 'Consumables', SUM(consumables_cost_aud) FROM site_cost_structure
    UNION ALL SELECT 'Utilities',   SUM(utilities_cost_aud)   FROM site_cost_structure
    UNION ALL SELECT 'Admin',       SUM(admin_cost_aud)       FROM site_cost_structure
) k
ORDER BY nilai_aud DESC;

-- 5.3 Biaya per ton tambang untuk tiap kategori (site berproduksi)
SELECT e.site_id, e.site_name,
       ROUND(s.labor_cost_aud       / e.total_tonnes_mined, 4) AS labor_per_ton,
       ROUND(s.equipment_cost_aud   / e.total_tonnes_mined, 4) AS equipment_per_ton,
       ROUND(s.fuel_cost_aud        / e.total_tonnes_mined, 4) AS fuel_per_ton,
       ROUND(s.maintenance_cost_aud / e.total_tonnes_mined, 4) AS maintenance_per_ton,
       ROUND(s.consumables_cost_aud / e.total_tonnes_mined, 4) AS consumables_per_ton,
       ROUND(s.utilities_cost_aud   / e.total_tonnes_mined, 4) AS utilities_per_ton,
       ROUND(s.admin_cost_aud       / e.total_tonnes_mined, 4) AS admin_per_ton,
       ROUND(s.total_cost_aud       / e.total_tonnes_mined, 4) AS total_per_ton
FROM site_cost_efficiency_summary e
JOIN site_cost_structure s ON s.site_id = e.site_id
WHERE e.total_tonnes_mined > 0;

-- 5.4 Komponen biaya terbesar tiap site
SELECT site_id,
       CASE GREATEST(labor_share_pct, equipment_share_pct, fuel_share_pct,
                     maintenance_share_pct, consumables_share_pct,
                     utilities_share_pct, admin_share_pct)
            WHEN labor_share_pct       THEN 'Labor'
            WHEN equipment_share_pct   THEN 'Equipment'
            WHEN fuel_share_pct        THEN 'Fuel'
            WHEN maintenance_share_pct THEN 'Maintenance'
            WHEN consumables_share_pct THEN 'Consumables'
            WHEN utilities_share_pct   THEN 'Utilities'
            ELSE 'Admin' END AS komponen_terbesar,
       GREATEST(labor_share_pct, equipment_share_pct, fuel_share_pct,
                maintenance_share_pct, consumables_share_pct,
                utilities_share_pct, admin_share_pct) AS share_terbesar_pct
FROM site_cost_structure;

-- 5.5 Biaya "kontrol langsung" (labor + equipment + fuel) vs biaya pendukung
SELECT site_id,
       ROUND(labor_cost_aud + equipment_cost_aud + fuel_cost_aud, 2) AS biaya_inti_aud,
       ROUND((labor_cost_aud + equipment_cost_aud + fuel_cost_aud) / total_cost_aud * 100, 2) AS biaya_inti_pct,
       ROUND(total_cost_aud - (labor_cost_aud + equipment_cost_aud + fuel_cost_aud), 2) AS biaya_lainnya_aud
FROM site_cost_structure;


/* =====================================================================
   BAGIAN 6 - BIAYA TETAP VS VARIABEL (OPERATING LEVERAGE)
   ===================================================================== */

-- 6.1 Model biaya linear per site: Biaya Harian = Tetap + Variabel x Ton
SELECT site_id, avg_daily_tonnes, avg_daily_cost_aud,
       fixed_cost_per_day_aud, variable_cost_per_tonne_aud,
       fixed_cost_share_pct,
       corr_tonnes_vs_cost, r2_linear_fit,
       corr_tonnes_vs_cost_per_tonne, daily_cost_per_tonne_cv_pct
FROM production_cost_relationship
ORDER BY fixed_cost_share_pct DESC;

-- 6.2 Total biaya tetap setahun dan kekuatan hubungan
SELECT site_id,
       ROUND(fixed_cost_per_day_aud * days, 2) AS biaya_tetap_tahunan_aud,
       fixed_cost_share_pct,
       CASE WHEN r2_linear_fit IS NULL        THEN 'Tidak ada produksi'
            WHEN r2_linear_fit >= 0.95        THEN 'Sangat kuat (R2 >= 0.95)'
            WHEN r2_linear_fit >= 0.80        THEN 'Kuat'
            ELSE 'Lemah' END AS kekuatan_hubungan_produksi_biaya
FROM production_cost_relationship;

-- 6.3 Simulasi what-if: kenaikan produksi harian +5% dan -5%
SELECT site_id,
       avg_daily_tonnes,
       ROUND(fixed_cost_per_day_aud + variable_cost_per_tonne_aud * avg_daily_tonnes, 2)        AS biaya_harian_base,
       ROUND(fixed_cost_per_day_aud + variable_cost_per_tonne_aud * avg_daily_tonnes * 1.05, 2) AS biaya_harian_plus5,
       ROUND(fixed_cost_per_day_aud + variable_cost_per_tonne_aud * avg_daily_tonnes * 0.95, 2) AS biaya_harian_minus5,
       ROUND((fixed_cost_per_day_aud + variable_cost_per_tonne_aud * avg_daily_tonnes * 1.05) / (avg_daily_tonnes * 1.05)
           - (fixed_cost_per_day_aud + variable_cost_per_tonne_aud * avg_daily_tonnes) / avg_daily_tonnes, 4)
           AS perubahan_biaya_per_ton_plus5,
       ROUND((fixed_cost_per_day_aud + variable_cost_per_tonne_aud * avg_daily_tonnes * 0.95) / (avg_daily_tonnes * 0.95)
           - (fixed_cost_per_day_aud + variable_cost_per_tonne_aud * avg_daily_tonnes) / avg_daily_tonnes, 4)
           AS perubahan_biaya_per_ton_minus5
FROM production_cost_relationship
WHERE avg_daily_tonnes > 0;

-- 6.4 Biaya Nickel Point saat Care & Maintenance (seluruhnya biaya tetap)
SELECT e.site_id, e.site_name, e.status,
       r.fixed_cost_per_day_aud,
       ROUND(r.fixed_cost_per_day_aud * r.days, 2) AS biaya_tahunan_aud,
       ROUND(e.total_cost_aud / (SELECT SUM(total_cost_aud) FROM site_cost_efficiency_summary) * 100, 3)
           AS share_biaya_portofolio_pct
FROM site_cost_efficiency_summary e
JOIN production_cost_relationship r ON r.site_id = e.site_id
WHERE e.status <> 'Operational';


/* =====================================================================
   BAGIAN 7 - TREN BULANAN
   ===================================================================== */

-- 7.1 Biaya per ton per bulan beserta perubahan dari bulan sebelumnya (MoM)
SELECT SUBSTR(month_start, 1, 7) AS bulan,
       site_id,
       tonnes_mined,
       total_cost_aud,
       cost_per_tonne_aud,
       ROUND((cost_per_tonne_aud / LAG(cost_per_tonne_aud) OVER (PARTITION BY site_id ORDER BY month_start) - 1) * 100, 2)
           AS cost_per_ton_mom_pct,
       ROUND((tonnes_per_day / LAG(tonnes_per_day) OVER (PARTITION BY site_id ORDER BY month_start) - 1) * 100, 2)
           AS tonnes_per_day_mom_pct
FROM monthly_site_trends
WHERE site_id <> 'NICK001'
ORDER BY site_id, month_start;

-- 7.2 Moving average 3 bulan untuk biaya per ton
SELECT SUBSTR(month_start, 1, 7) AS bulan,
       site_id,
       cost_per_tonne_aud,
       ROUND(AVG(cost_per_tonne_aud) OVER (
             PARTITION BY site_id ORDER BY month_start
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 4) AS ma_3_bulan
FROM monthly_site_trends
WHERE site_id <> 'NICK001'
ORDER BY site_id, month_start;

-- 7.3 Bulan dengan biaya per ton tertinggi dan terendah per site
SELECT site_id, bulan, cost_per_tonne_aud, kategori
FROM (
    SELECT site_id, SUBSTR(month_start, 1, 7) AS bulan, cost_per_tonne_aud,
           CASE WHEN cost_per_tonne_aud = MAX(cost_per_tonne_aud) OVER (PARTITION BY site_id) THEN 'Tertinggi'
                WHEN cost_per_tonne_aud = MIN(cost_per_tonne_aud) OVER (PARTITION BY site_id) THEN 'Terendah' END AS kategori
    FROM monthly_site_trends
    WHERE site_id <> 'NICK001'
) t
WHERE kategori IS NOT NULL
ORDER BY site_id, kategori;

-- 7.4 Volatilitas bulanan: rata-rata, min, maks, dan rentang biaya per ton
SELECT site_id,
       ROUND(AVG(cost_per_tonne_aud), 4) AS rata2_cost_per_ton,
       ROUND(MIN(cost_per_tonne_aud), 4) AS min_cost_per_ton,
       ROUND(MAX(cost_per_tonne_aud), 4) AS max_cost_per_ton,
       ROUND((MAX(cost_per_tonne_aud) - MIN(cost_per_tonne_aud)) / AVG(cost_per_tonne_aud) * 100, 2)
           AS rentang_pct_dari_rata2
FROM monthly_site_trends
WHERE site_id <> 'NICK001'
GROUP BY site_id
ORDER BY rentang_pct_dari_rata2 DESC;

-- 7.5 Total biaya & produksi seluruh portofolio per bulan
SELECT SUBSTR(month_start, 1, 7) AS bulan,
       SUM(total_cost_aud)       AS total_biaya_aud,
       SUM(tonnes_mined)         AS total_tonnes,
       ROUND(SUM(total_cost_aud) / SUM(days) , 2) AS biaya_per_hari_gabungan
FROM monthly_site_trends
GROUP BY month_start
ORDER BY month_start;

-- 7.6 Bulan ketika produksi harian di atas rata-rata tahunan dan biaya per ton ikut turun
--     (indikasi efek skala / pembagian biaya tetap)
SELECT m.site_id, SUBSTR(m.month_start, 1, 7) AS bulan,
       m.tonnes_per_day_index, m.cost_per_tonne_index
FROM monthly_site_trends m
WHERE m.site_id <> 'NICK001'
  AND m.tonnes_per_day_index > 100
  AND m.cost_per_tonne_index < 100
ORDER BY m.site_id, m.month_start;


/* =====================================================================
   BAGIAN 8 - EVALUASI MODEL PREDIKSI BIAYA
   Model: (1) Site Average  (2) Linear  (3) Random Forest
   Error = aktual - prediksi (positif = prediksi terlalu rendah)
   ===================================================================== */

-- 8.1 Metrik akurasi keseluruhan - semua site
SELECT model,
       COUNT(*)                            AS n_observasi,
       ROUND(AVG(ABS(aktual - prediksi)), 2) AS mae_aud,
       ROUND(SQRT(AVG((aktual - prediksi) * (aktual - prediksi))), 2) AS rmse_aud,
       ROUND(AVG(ABS(aktual - prediksi) / aktual) * 100, 3) AS mape_pct
FROM (
    SELECT 'Site Average'  AS model, actual_cost_aud AS aktual, predicted_site_average_aud  AS prediksi FROM cost_model_predictions
    UNION ALL
    SELECT 'Linear',        actual_cost_aud, predicted_linear_aud         FROM cost_model_predictions
    UNION ALL
    SELECT 'Random Forest', actual_cost_aud, predicted_random_forest_aud  FROM cost_model_predictions
) x
GROUP BY model
ORDER BY mape_pct;

-- 8.2 Metrik akurasi - hanya site yang berproduksi (menghindari bias dari site Nickel
--     yang biayanya konstan sehingga mudah ditebak)
SELECT model,
       COUNT(*)                            AS n_observasi,
       ROUND(AVG(ABS(aktual - prediksi)), 2) AS mae_aud,
       ROUND(SQRT(AVG((aktual - prediksi) * (aktual - prediksi))), 2) AS rmse_aud,
       ROUND(AVG(ABS(aktual - prediksi) / aktual) * 100, 3) AS mape_pct
FROM (
    SELECT 'Site Average'  AS model, actual_cost_aud AS aktual, predicted_site_average_aud  AS prediksi
      FROM cost_model_predictions WHERE tonnes_mined > 0
    UNION ALL
    SELECT 'Linear',        actual_cost_aud, predicted_linear_aud
      FROM cost_model_predictions WHERE tonnes_mined > 0
    UNION ALL
    SELECT 'Random Forest', actual_cost_aud, predicted_random_forest_aud
      FROM cost_model_predictions WHERE tonnes_mined > 0
) x
GROUP BY model
ORDER BY mape_pct;

-- 8.3 MAPE per site per model + model terbaik
SELECT site_id,
       ROUND(AVG(ABS(actual_cost_aud - predicted_site_average_aud)  / actual_cost_aud) * 100, 3) AS mape_site_average,
       ROUND(AVG(ABS(actual_cost_aud - predicted_linear_aud)        / actual_cost_aud) * 100, 3) AS mape_linear,
       ROUND(AVG(ABS(actual_cost_aud - predicted_random_forest_aud) / actual_cost_aud) * 100, 3) AS mape_random_forest,
       CASE LEAST(AVG(ABS(actual_cost_aud - predicted_site_average_aud)  / actual_cost_aud),
                  AVG(ABS(actual_cost_aud - predicted_linear_aud)        / actual_cost_aud),
                  AVG(ABS(actual_cost_aud - predicted_random_forest_aud) / actual_cost_aud))
            WHEN AVG(ABS(actual_cost_aud - predicted_site_average_aud)  / actual_cost_aud) THEN 'Site Average'
            WHEN AVG(ABS(actual_cost_aud - predicted_linear_aud)        / actual_cost_aud) THEN 'Linear'
            ELSE 'Random Forest' END AS model_terbaik
FROM cost_model_predictions
GROUP BY site_id
ORDER BY site_id;

-- 8.4 Peningkatan akurasi Random Forest dibanding baseline Site Average (produksi saja)
SELECT site_id,
       ROUND(AVG(ABS(actual_cost_aud - predicted_site_average_aud)  / actual_cost_aud) * 100, 3) AS mape_baseline,
       ROUND(AVG(ABS(actual_cost_aud - predicted_random_forest_aud) / actual_cost_aud) * 100, 3) AS mape_rf,
       ROUND((1 - AVG(ABS(actual_cost_aud - predicted_random_forest_aud) / actual_cost_aud)
                / AVG(ABS(actual_cost_aud - predicted_site_average_aud)  / actual_cost_aud)) * 100, 2)
           AS peningkatan_akurasi_pct
FROM cost_model_predictions
WHERE tonnes_mined > 0
GROUP BY site_id
ORDER BY peningkatan_akurasi_pct DESC;

-- 8.5 Bias prediksi Random Forest (rata-rata error bertanda) per site
SELECT site_id,
       ROUND(AVG(rf_error_aud), 2)                  AS bias_rata2_aud,
       ROUND(AVG(rf_error_aud / actual_cost_aud) * 100, 3) AS bias_rata2_pct,
       CASE WHEN AVG(rf_error_aud) > 0 THEN 'Cenderung under-predict'
            WHEN AVG(rf_error_aud) < 0 THEN 'Cenderung over-predict'
            ELSE 'Netral' END AS arah_bias
FROM cost_model_predictions
GROUP BY site_id;

-- 8.6 Akurasi Random Forest pada hari downtime vs hari normal
SELECT site_id,
       CASE WHEN downtime_day = 1 THEN 'Downtime' ELSE 'Normal' END AS tipe_hari,
       COUNT(*)                               AS jumlah_hari,
       ROUND(AVG(rf_abs_pct_error), 3)        AS mape_rf_pct,
       ROUND(AVG(actual_cost_aud), 2)         AS rata2_biaya_aktual
FROM cost_model_predictions
GROUP BY site_id, downtime_day
ORDER BY site_id, downtime_day;

-- 8.7 Sepuluh prediksi Random Forest dengan error persentase terbesar
SELECT `date`, site_id, tonnes_mined, actual_cost_aud,
       ROUND(predicted_random_forest_aud, 2) AS prediksi_rf,
       ROUND(rf_error_aud, 2)                AS error_aud,
       rf_abs_pct_error
FROM cost_model_predictions
ORDER BY rf_abs_pct_error DESC
LIMIT 10;

-- 8.8 Proporsi hari dengan error RF di bawah ambang (<=2%, <=5%, <=10%) - site produksi
SELECT site_id,
       COUNT(*) AS jumlah_hari,
       ROUND(SUM(rf_abs_pct_error <= 2) * 100.0 / COUNT(*), 1) AS pct_hari_error_maks_2,
       ROUND(SUM(rf_abs_pct_error <= 5) * 100.0 / COUNT(*), 1) AS pct_hari_error_maks_5,
       ROUND(SUM(rf_abs_pct_error <= 10) * 100.0 / COUNT(*), 1) AS pct_hari_error_maks_10
FROM cost_model_predictions
WHERE tonnes_mined > 0
GROUP BY site_id;


/* =====================================================================
   BAGIAN 9 - VIEW RINGKASAN KPI (siap dipakai untuk dashboard/visualisasi)
   ===================================================================== */

CREATE VIEW vw_site_kpi AS
SELECT e.site_id,
       e.site_name,
       e.commodity,
       e.status,
       e.total_tonnes_mined,
       e.target_attainment_pct,
       e.avg_plan_adherence_pct,
       e.total_downtime_hours,
       e.total_cost_aud,
       e.cost_per_tonne_mined_aud,
       e.cost_vs_target_pct,
       e.share_of_tonnes_pct,
       e.share_of_cost_pct,
       s.labor_share_pct,
       s.equipment_share_pct,
       s.fuel_share_pct,
       r.fixed_cost_per_day_aud,
       r.variable_cost_per_tonne_aud,
       r.fixed_cost_share_pct,
       r.r2_linear_fit,
       (SELECT ROUND(AVG(p.rf_abs_pct_error), 3)
          FROM cost_model_predictions p
         WHERE p.site_id = e.site_id) AS mape_random_forest_pct
FROM site_cost_efficiency_summary e
LEFT JOIN site_cost_structure          s ON s.site_id = e.site_id
LEFT JOIN production_cost_relationship r ON r.site_id = e.site_id;

SELECT * FROM vw_site_kpi ORDER BY total_cost_aud DESC;

/* ========================= AKHIR DOKUMEN ========================= */
