# Mining Operations Dashboard (Power BI)

Link google drive file power bi : https://drive.google.com/drive/folders/1Y_Hlqi898V1GelleFMCI52BiG0aMfUNT?usp=sharing

5 halaman: Executive Overview · Production Analytics · Equipment Performance · Cost & Efficiency · Safety & Risk.
Model bintang: `DimSite`, `DimDate` → `FactMonthly`, `FactEquipment`, `FactSafety`, `FactCostStructure` (32 measure DAX, lihat `DAX_Measures.md`).

## Cara membuka
1. Ekstrak seluruh folder ini, mis. ke `C:\MiningDashboard\` (folder `data` ikut di dalamnya).
2. Power BI Desktop → File → Options → Preview features → aktifkan **Power BI Project (.pbip) save option** dan **Store reports using enhanced metadata format (PBIR)** (jika masih muncul), lalu restart.
3. Buka `MiningDashboard.pbip`.
4. **Home → Transform data → Edit parameters** → isi `DataFolder` dengan lokasi folder `data` (mis. `C:\MiningDashboard\data`) → Apply → Refresh.
5. Simpan sebagai `.pbix` lewat File → Save as bila ingin satu file.

## Bila proyek .pbip gagal terbuka (fallback ±20 menit)
Proyek dibuat tanpa bisa diuji langsung di Power BI Desktop. Jika error:
1. Get Data → Text/CSV → muat 6 file di `data/`; ubah kolom tanggal menjadi tipe Date.
2. Model view: hubungkan `site_id` (Fact* → DimSite), dan `month_start`/`date` (Fact* → DimDate[Date]); di DimDate urutkan `Month` berdasarkan `MonthNum`.
3. Salin measure dari `DAX_Measures.md`.
4. View → Themes → Browse for themes → `MiningTheme.json`.
5. Susun visual sesuai daftar halaman di bawah.

## Isi halaman
| Halaman | Isi utama |
|---|---|
| 01 Executive | 7 KPI, tren bulanan tonnes vs biaya, biaya per site, tabel ringkasan site |
| 02 Production | tonnes mined/processed, target attainment, plan adherence, tren per site |
| 03 Equipment | OEE per tipe, breakdown vs maintenance, tren OEE autonomous vs conventional, daftar OEE terendah, hari anomali |
| 04 Cost | tren biaya, komposisi biaya, cost/tonne per site, hubungan volume–biaya (regresi), kontribusi biaya |
| 05 Safety | insiden per severity/bulan, root cause, site, tipe, daftar risiko dengan investigasi terbuka |

Slicer Site berlaku di semua halaman (tersinkron); slicer Bulan di halaman 03 dan 05.

## Batasan data (perlu diketahui saat presentasi)
- Produksi hanya bulanan; tidak ada data harian/mingguan, **ore grade, maupun recovery rate**.
- Tonnes processed, target, dan plan adherence hanya tahunan (FY2025), jadi tidak ikut berubah per bulan.
- Cost per tonne antar-komoditas tidak sebanding (Iron Ore ≈ A$27/t vs Copper ≈ A$4.078/t); angka gabungan didominasi Iron Ore.
- Nickel Point berstatus Care & Maintenance: tanpa produksi, equipment, maupun insiden.
- Data bersifat sintetis (tercatat di `cost_model_metrics.json`).
