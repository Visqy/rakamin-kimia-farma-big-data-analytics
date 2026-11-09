-- =====================================================
-- 01. DATA VALIDATION
-- Analisis Kinerja Bisnis Kimia Farma 2020-2023
-- =====================================================

-- Tujuan:
-- Memastikan data layak digunakan untuk menghitung metrik dan menjawab Business Questions.
--
-- Pendekatan:
-- 1. Coverage
-- 2. Integrity
-- 3. Granularity
-- 4. Metric Validity

-- =====================================================
-- 1. COVERAGE
-- =====================================================

-- Memeriksa cakupan waktu dan jumlah catatan untuk mendukung analisis tren tahunan.

SELECT
    EXTRACT(
        YEAR
        FROM date
    ) AS tahun,
    MIN(date) AS tanggal_awal,
    MAX(date) AS tanggal_akhir,
    COUNT(*) AS jumlah_baris,
    COUNT(DISTINCT transaction_id) AS transaksi_unik,
    COUNT(
        DISTINCT EXTRACT(
            MONTH
            FROM date
        )
    ) AS bulan_tercatat
FROM
    `rakamin-kf-analytics-512604.kimia_farma.kf_final_transaction`
GROUP BY
    tahun
ORDER BY tahun;

-- =====================================================
-- 2. INTEGRITY
-- =====================================================

-- -----------------------------------------------------
-- 2A. KEUNIKAN ID MASTER
-- -----------------------------------------------------

-- Memastikan setiap ID pada tabel master unik. ID yang berulang dapat menyebabkan penggandaan nilai transaksi setelah JOIN.

WITH
    master_check AS (
        SELECT
            'cabang' AS sumber,
            COUNT(*) AS total_baris,
            COUNTIF (
                branch_id IS NULL
                OR TRIM(branch_id) = ''
            ) AS id_kosong,
            COUNT(
                DISTINCT NULLIF(TRIM(branch_id), '')
            ) AS id_unik
        FROM
            `rakamin-kf-analytics-512604.kimia_farma.kf_kantor_cabang`
        UNION ALL
        SELECT
            'produk' AS sumber,
            COUNT(*) AS total_baris,
            COUNTIF (
                product_id IS NULL
                OR TRIM(product_id) = ''
            ) AS id_kosong,
            COUNT(
                DISTINCT NULLIF(TRIM(product_id), '')
            ) AS id_unik
        FROM
            `rakamin-kf-analytics-512604.kimia_farma.kf_product`
    )
SELECT
    *,
    total_baris - id_kosong - id_unik AS baris_id_duplikat
FROM master_check;

-- -----------------------------------------------------
-- 2B. KESESUAIAN RELASI TRANSAKSI
-- -----------------------------------------------------

-- Memeriksa apakah ID cabang dan produk pada transaksi tersedia pada tabel master.

SELECT
    COUNT(*) AS total_baris,
    COUNTIF (
        ft.branch_id IS NULL
        OR TRIM(ft.branch_id) = ''
    ) AS branch_id_kosong,
    COUNTIF (
        ft.branch_id IS NOT NULL
        AND TRIM(ft.branch_id) <> ''
        AND kc.branch_id IS NULL
    ) AS cabang_tidak_ditemukan,
    COUNTIF (
        ft.product_id IS NULL
        OR TRIM(ft.product_id) = ''
    ) AS product_id_kosong,
    COUNTIF (
        ft.product_id IS NOT NULL
        AND TRIM(ft.product_id) <> ''
        AND kp.product_id IS NULL
    ) AS produk_tidak_ditemukan
FROM
    `rakamin-kf-analytics-512604.kimia_farma.kf_final_transaction` AS ft
    LEFT JOIN (
        SELECT DISTINCT
            branch_id
        FROM
            `rakamin-kf-analytics-512604.kimia_farma.kf_kantor_cabang`
    ) AS kc ON ft.branch_id = kc.branch_id
    LEFT JOIN (
        SELECT DISTINCT
            product_id
        FROM
            `rakamin-kf-analytics-512604.kimia_farma.kf_product`
    ) AS kp ON ft.product_id = kp.product_id;

-- =====================================================
-- 3. GRANULARITY
-- =====================================================

-- Memahami apakah satu transaction_id hanya memiliki satu baris atau dapat muncul pada beberapa baris.
--
-- ID berulang tidak otomatis berarti data duplikat.
-- Hasilnya menentukan cara menghitung transaksi serta menginterpretasikan nilai dan rating.

WITH
    per_transaksi AS (
        SELECT
            transaction_id,
            COUNT(*) AS jumlah_baris,
            COUNT(DISTINCT product_id) AS jumlah_produk,
            COUNT(DISTINCT branch_id) AS jumlah_cabang,
            COUNT(DISTINCT date) AS jumlah_tanggal
        FROM
            `rakamin-kf-analytics-512604.kimia_farma.kf_final_transaction`
        WHERE
            transaction_id IS NOT NULL
            AND TRIM(transaction_id) <> ''
        GROUP BY
            transaction_id
    )
SELECT
    COUNT(*) AS transaksi_unik,
    COUNTIF (jumlah_baris > 1) AS id_berulang,
    SUM(jumlah_baris - 1) AS baris_ekstra,
    MAX(jumlah_baris) AS maksimal_baris_per_id,
    COUNTIF (jumlah_produk > 1) AS id_multi_produk,
    COUNTIF (jumlah_cabang > 1) AS id_multi_cabang,
    COUNTIF (jumlah_tanggal > 1) AS id_multi_tanggal
FROM per_transaksi;

-- =====================================================
-- 4. METRIC VALIDITY
-- =====================================================

-- -----------------------------------------------------
-- 4A. VALIDASI NILAI TRANSAKSI
-- -----------------------------------------------------

-- Memeriksa input utama untuk Nett Sales, Total Transactions, dan Rating.
--
-- Diskon diasumsikan dalam bentuk desimal 0-1.
-- Harga nonpositif ditandai untuk ditinjau, bukan otomatis dihapus.

SELECT
    COUNT(*) AS total_baris,
    COUNTIF (date IS NULL) AS tanggal_kosong,
    COUNTIF (
        transaction_id IS NULL
        OR TRIM(transaction_id) = ''
    ) AS id_transaksi_kosong,
    COUNTIF (price IS NULL) AS harga_kosong,
    COUNTIF (price <= 0) AS harga_nonpositif,
    MIN(price) AS harga_min,
    MAX(price) AS harga_max,
    COUNTIF (discount_percentage IS NULL) AS diskon_kosong,
    COUNTIF (
        discount_percentage < 0
        OR discount_percentage > 1
    ) AS diskon_di_luar_rentang,
    MIN(discount_percentage) AS diskon_min,
    MAX(discount_percentage) AS diskon_max,
    COUNTIF (rating IS NULL) AS rating_transaksi_kosong,
    MIN(rating) AS rating_min,
    MAX(rating) AS rating_max
FROM
    `rakamin-kf-analytics-512604.kimia_farma.kf_final_transaction`;

-- -----------------------------------------------------
-- 4B. VALIDASI ATRIBUT CABANG DAN PRODUK
-- -----------------------------------------------------

-- Memastikan informasi untuk analisis wilayah, perbandingan rating, dan identifikasi produk tersedia pada tabel referensi.

WITH
    cabang AS (
        SELECT
            COUNTIF (
                provinsi IS NULL
                OR TRIM(provinsi) = ''
            ) AS provinsi_kosong,
            COUNTIF (rating IS NULL) AS rating_cabang_kosong,
            MIN(rating) AS rating_cabang_min,
            MAX(rating) AS rating_cabang_max
        FROM
            `rakamin-kf-analytics-512604.kimia_farma.kf_kantor_cabang`
    ),
    produk AS (
        SELECT COUNTIF (
                product_name IS NULL
                OR TRIM(product_name) = ''
            ) AS nama_produk_kosong
        FROM
            `rakamin-kf-analytics-512604.kimia_farma.kf_product`
    )
SELECT *
FROM cabang
    CROSS JOIN produk;