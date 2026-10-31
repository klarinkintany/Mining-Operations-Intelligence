

<div align="center">

#  Mining Operations Intelligence

### An End-to-End Data Analytics, Machine Learning & Operational Perfomance Project

Analytics covering data preparation, exploratory data analysis (EDA), SQL-based analysis, equipment anomaly detection, operational cost modeling, and interactive Power BI dashboards across five mining sites throughout FY2025.

<img src="Images\1 Executive Overview.png" alt="Executive Overview Dashboard" width="95%">

</div>

---

## Daftar Isi

- [Ringkasan Proyek](#-ringkasan-proyek)
- [Temuan Utama](#-temuan-utama)
- [Dashboard Power BI](#-dashboard-power-bi)
- [Notebook Python (Google Colab)](#-notebook-python-google-colab)
- [Analisis SQL](#-analisis-sql)
- [Model Data & DAX](#-model-data--dax)
- [Pemodelan Biaya (Machine Learning)](#-pemodelan-biaya-machine-learning)
- [Struktur Repositori](#-struktur-repositori)
- [Cara Menjalankan](#-cara-menjalankan)
- [Keterbatasan Data](#-keterbatasan-data)
- [Sumber Data & Kredit](#-sumber-data--kredit)
- [Penulis](#-penulis)

---

## Ringkasan Proyek

Proyek ini menjawab pertanyaan bisnis yang biasa dihadapi manajemen operasi tambang:

| Pertanyaan | Dijawab di |
|---|---|
| Seberapa baik produksi tiap lokasi terhadap target tahunan? | Notebook 02 & 06 · Dashboard hal. 02 |
| Lokasi mana yang paling mahal, dan apa penyusun biayanya? | Notebook 06 · SQL biaya · Dashboard hal. 04 |
| Alat berat mana yang kinerjanya paling rendah, dan kapan anomali terjadi? | Notebook 05 · SQL equipment · Dashboard hal. 03 |
| Di mana risiko keselamatan kerja terbesar? | Notebook 04 · Dashboard hal. 05 |
| Seberapa akurat biaya harian dapat diperkirakan dari volume produksi? | Notebook 06 (Random Forest vs regresi linear) |

**Alur kerja (pipeline):**

```
SQLite Database ──► Audit Kualitas Data ──► Data Preparation ──► EDA
   (6 tabel,            (Notebook 01)        (Notebook 03-04)   (Notebook 02)
   12.049 baris)                                                     │
                                                                     ▼
Dashboard Power BI ◄── Star Schema + DAX ◄── Analisis Lanjutan (Notebook 05-06)
        ▲                                        + Anomali & Model Biaya
        └────────────── Query SQL (MySQL) ◄──────────────┘
```

---

## Temuan Utama

### Angka Kunci FY2025

| Metrik | Nilai |
|---|---|
| Total tonnes mined | **59,7 juta ton** |
| Total biaya operasi | **A$2,74 miliar** |
| Biaya per ton (gabungan) | **A$45,83** |
| Pencapaian target tahunan | **93,7%** (target 63,72 juta ton) |
| Rata-rata OEE armada | **76,2%** |
| Total jam breakdown | **1.203,8 jam** |
| Total insiden keselamatan | **360** (8 LTI · 111 hari hilang) |

### Insight

**Produksi**
- Iron Ridge dan Golden Valley menyumbang sekitar **99%** total ton ditambang.
- Semua lokasi produksi berada di **92,5% – 93,9%** dari target tahunan; tidak ada yang mencapai 100%.
- Hari downtime (8–10 hari per lokasi) mengurangi produksi tahunan sekitar **1,5% – 1,8%**, dan jatuh pada tanggal yang sama di semua lokasi (15–16 Maret, Juni, September, Desember), pola yang lebih mirip penghentian terjadwal.

**Biaya**
- Biaya per ton sangat berbeda antar lokasi: **A$27,05** (Iron Ridge) sampai **A$4.078** (Copper Hills). Angka ini mencerminkan komoditas dan skala, **bukan** ukuran efisiensi antar lokasi.
- Tenaga kerja, peralatan, dan bahan bakar membentuk sekitar **86%** biaya.
- Biaya harian hampir sepenuhnya mengikuti volume produksi (korelasi **0,975 – 0,980**).
- Nickel Point (*Care & Maintenance*) tidak berproduksi tetapi tetap mengeluarkan **A$8.500/hari** (A$3,1 juta/tahun).

**Peralatan**
- OEE berbeda menurut **jenis alat**, bukan unit: Haul Truck **84,2%** vs Jumbo Drill **49,6%**. Availability sama (~98%), jadi selisih berasal dari utilization.
- Hari *breakdown* hanya ±1,9% dari catatan, tetapi menyumbang sekitar **34%** biaya perawatan alat.
- Truk otonom (Iron Ridge) mencapai OEE **±91,6%** vs ±79–81% untuk truk konvensional.
- Isolation Forest menandai **161 hari-alat** anomali, terutama hari breakdown dan perawatan berbiaya tinggi.

**Keselamatan**
- Setiap lokasi mencatat 90 insiden; perbedaan TRIFR berasal dari jumlah pekerja: Copper Hills **8,15**, Lithium Creek **5,07**, Iron Ridge **2,69**, Golden Valley **1,90**.
- Insiden *High* hanya 8 (2,2%) tetapi menyumbang **seluruh 111 hari kerja hilang**.
- **26,9%** investigasi masih terbuka, termasuk 2 LTI di Golden Valley.

---

## Dashboard Power BI

Dashboard 5 halaman dengan tema kustom (`MiningTheme.json`), slicer **Site** yang tersinkron di semua halaman, serta slicer **Bulan** pada halaman Equipment dan Safety.

### 01 — Executive Overview
7 KPI utama, tren bulanan tonnes vs biaya, biaya per site, dan tabel ringkasan site.

<img src="Images\2. executive overview.png" alt="Executive Overview" width="100%">

### 02 — Production Analytics
Produksi vs target, plan adherence, processing ratio, dan tren produksi per site.

<img src="Images\1.Production Analystic.png" alt="Production Analytics" width="100%">

### 03 — Equipment Performance
OEE per tipe alat, breakdown vs maintenance, tren OEE autonomous vs conventional, unit dengan OEE terendah, dan hari anomali.

<img src="Images\3.1 equipment perfomance.png" alt="Equipment Performance" width="100%">

### 04 — Cost & Efficiency
Tren biaya, komposisi biaya, cost per tonne per site, dan hubungan volume–biaya (regresi linear harian).

<img src="Images/4. cost & efficiency.png" alt="Cost and Efficiency" width="100%">

### 05 — Safety & Risk Monitoring
Insiden per severity/bulan, root cause, site, jenis insiden, dan daftar risiko dengan investigasi terbuka.

<img src="Images\5.safety & risk monitoring.png" alt="Safety and Risk Monitoring" width="100%">

<details>
<summary><b>🖼️ Tampilan tambahan (dengan filter/slicer)</b></summary>
<br>

| Executive (filter Iron Ridge) | Production (filter) | Equipment (detail) |
|:---:|:---:|:---:|
| <img src="images/01b_executive_overview_filter.png" width="100%"> | <img src="images/02b_production_analytics_filter.png" width="100%"> | <img src="images/03b_equipment_performance_detail.png" width="100%"> |

</details>

> **Membuka file Power BI:** buka link google drive Data Power BI : | [`Mining Operations Intelligence_PowerBI`](https://drive.google.com/drive/folders/1Y_Hlqi898V1GelleFMCI52BiG0aMfUNT?usp=drive_link) |  `Power_BI/MiningDashboard.pbip` di Power BI Desktop, lalu isi parameter `DataFolder` (lihat [Cara Menjalankan](#-cara-menjalankan)).

---

##  Notebook Python (Google Colab)

Enam notebook disusun berurutan, dari audit mentah hingga model prediksi. Klik tombol untuk membukanya langsung di Google Colab.

| # | Notebook | Isi Utama | Colab |
|---|---|---|---|
| 01 | `01_Mining_Operations_Database_Audit_clean` | Audit database SQLite: struktur, nilai kosong, duplikat, rekonsiliasi produksi–biaya, 27 aturan validasi | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://github.com/klarinkintany/Mining-Operations-Intelligence/blob/main/Code/notebooks/01_Mining_Operations_Database_Audit_clean.ipynb) |
| 02 | `02_Mining_Operations_EDA_clean` | EDA produksi, biaya, alat, keselamatan; analisis shift, grade/recovery, bahan bakar, anomali produksi | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://github.com/klarinkintany/Mining-Operations-Intelligence/blob/main/Code/notebooks/02_Mining_Operations_EDA_clean.ipynb) |
| 03 | `03_Mining_Operations_Data_Preparation_clean` | Integrasi tabel, rekonsiliasi biaya, feature engineering (lag/rolling tanpa kebocoran data), data dictionary | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://github.com/klarinkintany/Mining-Operations-Intelligence/blob/main/Code/notebooks/03_Mining_Operations_Data_Preparation_clean.ipynb) |
| 04 | `04_Equipment_Safety_Data_Preparation_clean` | Audit 14 aturan peralatan dan 10 aturan keselamatan; dataset siap analisis | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://github.com/klarinkintany/Mining-Operations-Intelligence/blob/main/Code/notebooks/04_Equipment_Safety_Data_Preparation_clean.ipynb) |
| 05 | `05_Equipment_Performance_Analytics_clean` | OEE, breakdown, biaya perawatan, autonomous vs conventional, **Isolation Forest** | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://github.com/klarinkintany/Mining-Operations-Intelligence/blob/main/Code/notebooks/05_Equipment_Performance_Analytics_clean.ipynb) |
| 06 | `06_Production_Cost_Efficiency_clean` | Struktur biaya, biaya tetap vs variabel, tren bulanan, **model estimasi biaya** | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://github.com/klarinkintany/Mining-Operations-Intelligence/blob/main/Code/notebooks/06_Production_Cost_Efficiency_clean.ipynb) |

**Library:** `pandas` · `numpy` · `matplotlib` · `scikit-learn` · `sqlite3` · `joblib`

>  Notebook membaca database SQLite (lihat [Sumber Data](https://drive.google.com/drive/folders/1wX7wQakPch7WY26-ySGEieoPggcF27ns?usp=sharing)). Saat dijalankan di Colab, unggah file database ke sesi Colab atau mount Google Drive, lalu sesuaikan path pada sel koneksi database.

---

## 🗄️ Analisis SQL

Tiga skrip **MySQL 8.0+** berstruktur per bagian (setup → pengecekan kualitas → analisis → view KPI):

| File | Database | Cakupan |
|---|---|---|
| [`analisis_star_schema.sql`](SQL\SQL\analisis_biaya_tambang.sql) | `mining_dwh` | Data warehouse **star schema** (2 dimensi + 4 fakta), view terintegrasi, ringkasan eksekutif, analisis lintas domain produksi–alat–K3 |
| [`analisis_biaya_tambang.sql`](SQL\SQL\analisis_equipment.sql) | `mining_cost_analysis` | Efisiensi biaya, biaya vs target, biaya tetap vs variabel (*operating leverage*), tren bulanan, evaluasi model prediksi |
| [`analisis_equipment.sql`](SQL\SQL\analisis_star_schema.sql) | `equipment_analysis` | Profil armada, OEE, dampak breakdown, BBM, autonomous vs conventional, peringkat unit, analisis anomali |

Teknik SQL yang dipakai: `CTE`, `window function`, agregasi bertingkat, `VIEW`, `PRIMARY/FOREIGN KEY`, dan pengecekan integritas relasi.

---

##  Model Data & DAX

Model bintang (*star schema*) di Power BI:

```
            DimDate ───┐
                       ├──► FactMonthly         (produksi & biaya bulanan)
            DimSite ───┤──► FactEquipment       (8.030 baris, 22 unit × 365 hari)
                       ├──► FactSafety          (360 insiden)
                       └──► FactCostStructure   (biaya per kategori)
```

**32 measure DAX** dikelompokkan menjadi Cost, Equipment, Production, dan Safety. Dokumentasi lengkap ada di [`Power_BI/DAX_Measures.md`](https://drive.google.com/file/d/12_NIvVz7RVv_w5bW93qztiscKHSbz3H_/view?usp=sharing). Contoh:

```dax
Cost per Tonne Mined (AUD) =
    DIVIDE ( [Total Operating Cost (AUD)], [Total Tonnes Mined] )

Target Attainment % =
    DIVIDE (
        CALCULATE ( [Total Tonnes Mined], ALL ( DimDate ) ),
        [Annual Target Tonnes]
    )

Anomaly Rate % =
    DIVIDE ( [Anomaly Days], COUNTROWS ( FactEquipment ) )
```

---

##  Pemodelan Biaya (Machine Learning)

Model memperkirakan **biaya operasi harian** dari lokasi, kalender, dan tonnes mined (target: `total_cost_aud`; pembagian data berdasarkan waktu, 80% latih / 20% uji, periode uji 20 Okt – 31 Des 2025).

| Model | MAE (A$) | RMSE (A$) | R² | WAPE |
|---|---:|---:|---:|---:|
| A. Rata-rata per site (baseline) | 138.207 | 300.964 | 0,9531 | 9,25% |
| **B. Regresi linear per site** | **37.038** | **57.361** | **0,9983** | **2,48%** |
| C. Random Forest | 44.412 | 78.916 | 0,9968 | 2,97% |

**Catatan interpretasi:**
- Baseline sederhana saja sudah menghasilkan R² 0,953 karena skala biaya antar lokasi berbeda ribuan kali lipat, sehingga R² gabungan **tidak cukup** untuk menilai model. Karena itu MAPE per lokasi (Random Forest: 2,7% – 4,2%) ikut dilaporkan.
- Regresi linear sedikit mengungguli Random Forest karena biaya pada data ini hampir linear terhadap tonase.
- Model ini adalah **estimasi biaya untuk volume tertentu** (misalnya anggaran skenario), bukan peramalan masa depan.

---

##  Struktur Repositori

```
📦 Mining-Operations-Intelligence
├── 📂 Code
│   └── 📂 notebooks                  # 6 notebook Python (Google Colab)
├── 📂 Data
│   ├── 📂 prepared_data              # dataset siap analisis + data dictionary + audit kualitas
│   ├── 📂 equipment_analytics        # hasil analisis & deteksi anomali alat
│   └── 📂 production_cost_results    # hasil analisis biaya, prediksi, model .joblib, metrik
├── 📂 SQL                            # 3 skrip MySQL
├── 📂 Power_BI
│   ├── MiningDashboard.pbip          # proyek Power BI (PBIR)
│   ├── MiningDashboard.Report        # definisi halaman & visual
│   ├── MiningDashboard.SemanticModel # model data (TMDL)
│   ├── MiningTheme.json              # tema kustom
│   ├── DAX_Measures.md               # dokumentasi 32 measure DAX
│   └── 📂 Data                       # 6 CSV sumber untuk dashboard
├── 📂 images                         # screenshot dashboard
├── 📂 Database                       # mining_operations.db
└── 📄 README.md
```

---

## Cara Menjalankan

### 1. Dashboard Power BI
1. Unduh/clone repositori ini, simpan di lokasi tanpa spasi, mis. `C:\MiningDashboard\`.
2. Di Power BI Desktop: **File → Options → Preview features** → aktifkan **Power BI Project (.pbip) save option** dan **PBIR**, lalu restart.
3. Buka `Power_BI/MiningDashboard.pbip`.
4. **Home → Transform data → Edit parameters** → isi `DataFolder` dengan path folder `Power_BI/Data` → **Apply → Refresh**.
5. Opsional: **File → Save as** untuk menyimpan sebagai `.pbix`.

<details>
<summary><b>Jika .pbip gagal terbuka (cara manual)</b></summary>

1. **Get Data → Text/CSV** → muat 6 file di `Power_BI/Data/`; ubah kolom tanggal menjadi tipe *Date*.
2. Hubungkan `site_id` (Fact → DimSite) dan `month_start`/`date` (Fact → DimDate[Date]); urutkan `Month` berdasarkan `MonthNum`.
3. Salin measure dari `DAX_Measures.md`.
4. **View → Themes → Browse for themes** → pilih `MiningTheme.json`.

link google drive Data Power BI : | [`Mining Operations Intelligence_PowerBI`](https://drive.google.com/drive/folders/1Y_Hlqi898V1GelleFMCI52BiG0aMfUNT?usp=drive_link) | 

</details>

### 2. Notebook Python
```bash
git clone https://github.com/klarinkintany/Mining-Operations-Intelligence.git
cd Mining-Operations-Intelligence
pip install pandas numpy matplotlib scikit-learn joblib jupyter
jupyter notebook Code/notebooks/
```
Atau klik tombol **Open in Colab** pada [bagian notebook](https://github.com/klarinkintany/Mining-Operations-Intelligence/tree/main/Code).

### 3. Skrip SQL (MySQL 8.0+)
```sql
SET GLOBAL local_infile = 1;
-- Konek dengan: mysql --local-infile=1 -u root -p
-- Ubah path CSV pada BAGIAN 1 di setiap skrip, lalu jalankan berurutan.
-- Muat tabel dimensi lebih dulu, baru tabel fakta (foreign key).
```

---

##  Keterbatasan Data

Poin berikut dicatat agar hasil dibaca dengan tepat, terutama saat presentasi:

- **Data sintetis.** Temuan tidak mewakili kondisi tambang nyata maupun tolok ukur industri.
- Data produksi pada dashboard bersifat **bulanan**; tidak ada data ore grade dan recovery rate pada model Power BI.
- *Tonnes processed*, target, dan *plan adherence* hanya tersedia **tahunan** (FY2025), sehingga tidak berubah per bulan.
- **Cost per tonne tidak sebanding antar komoditas** (Iron Ore ≈ A$27/t vs Copper ≈ A$4.078/t); angka gabungan didominasi Iron Ore.
- **Nickel Point** berstatus *Care & Maintenance*: tanpa produksi, peralatan, maupun insiden, sehingga dikecualikan dari analisis berbasis tonase.
- OEE pada dataset ini dihitung dari **availability × utilization** saja, sehingga korelasinya dengan utilization sudah pasti (bukan temuan).
- Komposisi biaya per kategori adalah persentase tetap dari total biaya, sehingga tidak mencerminkan struktur biaya tambang nyata.

---

## Sumber Data & Kredit

Database SQLite sintetis operasi tambang yang dianalisis dalam proyek ini bersumber dari repositori
[**FlavioColtellacci/Mining-Operations-Dashboard**](https://github.com/FlavioColtellacci/Mining-Operations-Dashboard).
Seluruh audit, persiapan data, analisis, model, query SQL, dan dashboard Power BI dalam repositori ini adalah pekerjaan saya sendiri.

---

## 👤 Penulis

Klarin Kintany

Project Mining Operations Intelligence

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0A66C2?logo=linkedin&logoColor=white)](www.linkedin.com/in/klarin-kintany)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-181717?logo=github&logoColor=white)](https://github.com/klarinkintany)

---

<div align="center">

⭐ Jika proyek ini bermanfaat, silakan beri bintang pada repositori ini.

<sub>Data bersifat sintetis dan digunakan untuk tujuan portofolio dan edukasi.</sub>

</div>
