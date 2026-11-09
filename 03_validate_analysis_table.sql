-- =====================================================
-- 02. VALIDASI TABEL ANALISIS
-- =====================================================

-- Memastikan jumlah baris, identitas, dan nilai penjualan tidak berubah setelah JOIN.

WITH
    sumber AS (
        SELECT
            COUNT(*) AS jumlah_baris,
            COUNT(DISTINCT transaction_id) AS transaksi_unik,
            COUNT(DISTINCT branch_id) AS cabang_unik,
            COUNT(DISTINCT product_id) AS produk_unik,
            SUM(CAST(price AS NUMERIC)) AS total_harga,
            SUM(
                ROUND(
                    CAST(price AS NUMERIC) * (1 - discount_percentage),
                    2
                )
            ) AS total_nett_sales
        FROM
            `rakamin-kf-analytics-512604.kimia_farma.kf_final_transaction`
    ),
    hasil AS (
        SELECT
            COUNT(*) AS jumlah_baris,
            COUNT(DISTINCT transaction_id) AS transaksi_unik,
            COUNT(DISTINCT branch_id) AS cabang_unik,
            COUNT(DISTINCT product_id) AS produk_unik,
            SUM(CAST(actual_price AS NUMERIC)) AS total_harga,
            SUM(nett_sales) AS total_nett_sales
        FROM
            `rakamin-kf-analytics-512604.kimia_farma.kf_analysis`
    )
SELECT
    sumber.jumlah_baris AS source_rows,
    hasil.jumlah_baris AS analysis_rows,
    hasil.jumlah_baris - sumber.jumlah_baris AS row_difference,
    hasil.transaksi_unik - sumber.transaksi_unik AS transaction_difference,
    hasil.cabang_unik - sumber.cabang_unik AS branch_difference,
    hasil.produk_unik - sumber.produk_unik AS product_difference,
    hasil.total_harga - sumber.total_harga AS price_difference,
    hasil.total_nett_sales - sumber.total_nett_sales AS nett_sales_difference
FROM sumber
    CROSS JOIN hasil;