-- =====================================================
-- 02. PEMBUATAN TABEL ANALISIS
-- Analisis Kinerja Bisnis Kimia Farma 2020-2023
-- =====================================================

-- Tujuan:
-- Menggabungkan data transaksi, cabang, dan produk serta menghitung metrik finansial.

CREATE
OR
REPLACE
TABLE `rakamin-kf-analytics-512604.kimia_farma.kf_analysis` AS

WITH transaksi AS (

-- -------------------------------------------------
-- 1. PENGGABUNGAN DATA
-- -------------------------------------------------
-- INNER JOIN digunakan berdasarkan hasil validasi:
-- ID master unik dan seluruh transaksi memiliki pasangan cabang serta produk.

SELECT
    trx.transaction_id,
    trx.date,
    trx.branch_id,
    cabang.branch_name,
    cabang.kota,
    cabang.provinsi,
    cabang.rating AS rating_cabang,
    trx.customer_name,
    trx.product_id,
    produk.product_name,
    trx.price AS actual_price,
    trx.discount_percentage,

-- ---------------------------------------------
-- 2. PENENTUAN GROSS PROFIT RATE
-- ---------------------------------------------
-- Persentase ditentukan berdasarkan harga transaksi.
-- 0.10 = 10%, 0.15 = 15%, dan seterusnya.

CASE
            WHEN trx.price <= 50000 THEN NUMERIC '0.10'
            WHEN trx.price <= 100000 THEN NUMERIC '0.15'
            WHEN trx.price <= 300000 THEN NUMERIC '0.20'
            WHEN trx.price <= 500000 THEN NUMERIC '0.25'
            ELSE NUMERIC '0.30'
        END AS persentase_gross_laba,

        trx.rating AS rating_transaksi

    FROM
        `rakamin-kf-analytics-512604.kimia_farma.kf_final_transaction` AS trx

    INNER JOIN
        `rakamin-kf-analytics-512604.kimia_farma.kf_kantor_cabang` AS cabang
        ON trx.branch_id = cabang.branch_id

    INNER JOIN
        `rakamin-kf-analytics-512604.kimia_farma.kf_product` AS produk
        ON trx.product_id = produk.product_id
)

-- -----------------------------------------------------
-- 3. PEMBENTUKAN TABEL ANALISIS
-- -----------------------------------------------------

SELECT
    transaction_id,
    date,
    branch_id,
    branch_name,
    kota,
    provinsi,
    rating_cabang,
    customer_name,
    product_id,
    product_name,
    actual_price,
    discount_percentage,
    persentase_gross_laba,

-- Asumsi:
-- Gross profit rate merupakan margin terhadap harga transaksi sebelum diskon.
-- Diskon mengurangi keuntungan sebelum diskon.
--
-- Rumus:
-- nett_sales  = price * (1 - discount)
-- nett_profit = price * (gross_rate - discount)

-- Penjualan setelah diskon.
ROUND(
    CAST(actual_price AS NUMERIC) * (
        NUMERIC '1' - discount_percentage
    ),
    2
) AS nett_sales,

-- Estimasi keuntungan setelah diskon.
ROUND(
    CAST(actual_price AS NUMERIC) * (
        persentase_gross_laba - discount_percentage
    ),
    2
) AS nett_profit,
rating_transaksi
FROM transaksi;