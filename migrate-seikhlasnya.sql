-- ============================================================
-- MIGRATION: Tambah kolom allow_seikhlasnya ke tabel products
-- Jalankan sekali di Supabase SQL Editor kalau DB sudah ada
-- ============================================================

ALTER TABLE products
ADD COLUMN IF NOT EXISTS allow_seikhlasnya BOOLEAN DEFAULT FALSE;

-- Pastikan kolom sudah ada
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'products' AND column_name = 'allow_seikhlasnya';
