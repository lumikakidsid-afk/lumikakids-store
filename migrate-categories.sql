-- ================================================
-- MIGRATION: Dynamic Categories
-- Jalankan script ini di Supabase SQL Editor
-- ================================================

-- 1. Buat tabel categories
CREATE TABLE IF NOT EXISTS categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL,
    icon TEXT DEFAULT 'tag',
    type TEXT DEFAULT 'digital' CHECK (type IN ('digital', 'physical')),
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Seed kategori lama
INSERT INTO categories (slug, label, icon, type, sort_order) VALUES
    ('ebook', 'Ebook', 'book-open', 'digital', 1),
    ('video', 'Video', 'play-circle', 'digital', 2),
    ('template', 'Template', 'layout', 'digital', 3),
    ('workshop', 'Workshop', 'users', 'digital', 4),
    ('fisik', 'Produk Fisik', 'package', 'physical', 5)
ON CONFLICT (slug) DO NOTHING;

-- 3. Hapus CHECK constraint lama di products.category
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_category_check;

-- 4. RLS policies for categories
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- Public read (semua orang bisa lihat kategori)
CREATE POLICY "Categories are viewable by everyone"
    ON categories FOR SELECT
    USING (true);

-- Admin only write
CREATE POLICY "Admin can insert categories"
    ON categories FOR INSERT
    WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Admin can update categories"
    ON categories FOR UPDATE
    USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Admin can delete categories"
    ON categories FOR DELETE
    USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );
