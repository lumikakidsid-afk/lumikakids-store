-- ============================================================
-- SUPABASE SETUP DATABASE FOR E-COMMERCE DIGITAL PRODUCTS
-- ============================================================

-- ============================================================
-- 1. TABEL PROFILES (extends auth.users)
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT,
    phone TEXT,
    address TEXT,
    city TEXT,
    role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. AUTO-CREATE PROFILE ON SIGNUP
-- ============================================================
-- Function to create profile
-- NOTE: User PERTAMA yang mendaftar otomatis menjadi admin (superadmin).
-- User berikutnya otomatis menjadi member.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    admin_exists BOOLEAN;
BEGIN
    -- Cek apakah sudah ada admin di sistem
    SELECT EXISTS (SELECT 1 FROM public.profiles WHERE role = 'admin') INTO admin_exists;

    INSERT INTO public.profiles (id, full_name, phone, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        -- User pertama otomatis jadi admin, sisanya member
        CASE WHEN NOT admin_exists THEN 'admin' ELSE 'member' END
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create profile on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 3. TABEL PRODUCTS
-- ============================================================
CREATE TABLE IF NOT EXISTS products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT DEFAULT '',
    price BIGINT NOT NULL DEFAULT 0,
    sale_price BIGINT DEFAULT 0,
    category TEXT NOT NULL CHECK (category IN ('ebook', 'video', 'template', 'workshop', 'fisik')),
    type TEXT DEFAULT 'digital' CHECK (type IN ('digital', 'physical')),
    image_url TEXT DEFAULT '',
    file_url TEXT DEFAULT '',
    stock INTEGER DEFAULT 0,
    weight INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'draft')),
    featured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. TABEL ORDERS
-- ============================================================
CREATE TABLE IF NOT EXISTS orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_number TEXT UNIQUE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    customer_name TEXT,
    customer_email TEXT,
    customer_phone TEXT,
    total_amount BIGINT DEFAULT 0,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'processing', 'shipped', 'completed', 'cancelled')),
    payment_method TEXT DEFAULT 'transfer',
    payment_proof_url TEXT DEFAULT '',
    shipping_address TEXT,
    shipping_city TEXT,
    tracking_number TEXT,
    notes TEXT,
    has_physical_items BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. AUTO-GENERATE ORDER NUMBER
-- ============================================================
-- Function to generate order number format: INV-YYYYMMDD-XXXX
CREATE OR REPLACE FUNCTION public.generate_order_number()
RETURNS TRIGGER AS $$
DECLARE
    order_num TEXT;
    date_str TEXT;
    random_str TEXT;
BEGIN
    date_str := TO_CHAR(NOW(), 'YYYYMMDD');
    random_str := LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    order_num := 'INV-' || date_str || '-' || random_str;
    
    -- Ensure uniqueness
    WHILE EXISTS (SELECT 1 FROM orders WHERE order_number = order_num) LOOP
        random_str := LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
        order_num := 'INV-' || date_str || '-' || random_str;
    END LOOP;
    
    NEW.order_number := order_num;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate order number
DROP TRIGGER IF EXISTS on_order_insert ON orders;
CREATE TRIGGER on_order_insert
    BEFORE INSERT ON orders
    FOR EACH ROW
    WHEN (NEW.order_number IS NULL OR NEW.order_number = '')
    EXECUTE FUNCTION public.generate_order_number();

-- ============================================================
-- 6. TABEL ORDER ITEMS
-- ============================================================
CREATE TABLE IF NOT EXISTS order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    product_type TEXT NOT NULL,
    quantity INTEGER DEFAULT 1,
    price BIGINT DEFAULT 0,
    file_url TEXT
);

-- ============================================================
-- 7. TABEL STORE SETTINGS (single row)
-- ============================================================
-- JIKA DATABASE SUDAH ADA, jalankan query berikut untuk menambah kolom baru:
-- ALTER TABLE store_settings ADD COLUMN IF NOT EXISTS fb_pixel_id TEXT DEFAULT '';
-- ALTER TABLE store_settings ADD COLUMN IF NOT EXISTS ga4_measurement_id TEXT DEFAULT '';

CREATE TABLE IF NOT EXISTS store_settings (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    store_name TEXT DEFAULT 'Toko Digital',
    store_description TEXT DEFAULT 'Toko digital terpercaya untuk produk digital dan fisik',
    store_logo_url TEXT DEFAULT '',
    owner_avatar_url TEXT DEFAULT '',
    whatsapp_number TEXT DEFAULT '',
    instagram_url TEXT DEFAULT '',
    bank_name TEXT DEFAULT '',
    bank_account_number TEXT DEFAULT '',
    bank_account_name TEXT DEFAULT '',
    qris_image_url TEXT DEFAULT '',
    fb_pixel_id TEXT DEFAULT '',
    ga4_measurement_id TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 8. INSERT DEFAULT SETTINGS
-- ============================================================
INSERT INTO store_settings (
    id,
    store_name,
    store_description,
    store_logo_url,
    owner_avatar_url,
    whatsapp_number,
    instagram_url,
    bank_name,
    bank_account_number,
    bank_account_name,
    qris_image_url,
    fb_pixel_id,
    ga4_measurement_id
)
VALUES (
    1,
    'Toko Digital',
    'Toko digital terpercaya untuk produk digital dan fisik',
    '',
    '',
    '6281234567890',
    'https://instagram.com/tokodigital',
    'Bank BCA',
    '1234567890',
    'John Doe',
    '',
    '',
    ''
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 9. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_settings ENABLE ROW LEVEL SECURITY;

-- Helper function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --------------------------------------------------------
-- PROFILES POLICIES
-- --------------------------------------------------------
-- Public can view all profiles
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
CREATE POLICY "Profiles are viewable by everyone"
    ON profiles FOR SELECT
    USING (true);

-- Users can update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Admin can update any profile
DROP POLICY IF EXISTS "Admin can update any profile" ON profiles;
CREATE POLICY "Admin can update any profile"
    ON profiles FOR ALL
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- --------------------------------------------------------
-- PRODUCTS POLICIES
-- --------------------------------------------------------
-- Public can view active products
DROP POLICY IF EXISTS "Products are viewable by everyone" ON products;
CREATE POLICY "Products are viewable by everyone"
    ON products FOR SELECT
    USING (true);

-- Admin can insert products
DROP POLICY IF EXISTS "Admin can insert products" ON products;
CREATE POLICY "Admin can insert products"
    ON products FOR INSERT
    WITH CHECK (public.is_admin());

-- Admin can update products
DROP POLICY IF EXISTS "Admin can update products" ON products;
CREATE POLICY "Admin can update products"
    ON products FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Admin can delete products
DROP POLICY IF EXISTS "Admin can delete products" ON products;
CREATE POLICY "Admin can delete products"
    ON products FOR DELETE
    USING (public.is_admin());

-- --------------------------------------------------------
-- ORDERS POLICIES
-- --------------------------------------------------------
-- Users can view their own orders
DROP POLICY IF EXISTS "Users can view own orders" ON orders;
CREATE POLICY "Users can view own orders"
    ON orders FOR SELECT
    USING (auth.uid() = user_id OR public.is_admin());

-- Authenticated users can create orders
DROP POLICY IF EXISTS "Authenticated users can create orders" ON orders;
CREATE POLICY "Authenticated users can create orders"
    ON orders FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- Users can update their own orders (only status changes allowed in app)
DROP POLICY IF EXISTS "Users can update own orders" ON orders;
CREATE POLICY "Users can update own orders"
    ON orders FOR UPDATE
    USING (auth.uid() = user_id OR public.is_admin())
    WITH CHECK (auth.uid() = user_id OR public.is_admin());

-- Admin can delete orders
DROP POLICY IF EXISTS "Admin can delete orders" ON orders;
CREATE POLICY "Admin can delete orders"
    ON orders FOR DELETE
    USING (public.is_admin());

-- --------------------------------------------------------
-- ORDER ITEMS POLICIES
-- --------------------------------------------------------
-- Users can view their own order items
DROP POLICY IF EXISTS "Users can view own order items" ON order_items;
CREATE POLICY "Users can view own order items"
    ON order_items FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM orders 
            WHERE orders.id = order_items.order_id 
            AND (orders.user_id = auth.uid() OR public.is_admin())
        )
    );

-- Authenticated users can create order items
DROP POLICY IF EXISTS "Authenticated users can create order items" ON order_items;
CREATE POLICY "Authenticated users can create order items"
    ON order_items FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- Admin can update order items
DROP POLICY IF EXISTS "Admin can update order items" ON order_items;
CREATE POLICY "Admin can update order items"
    ON order_items FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Admin can delete order items
DROP POLICY IF EXISTS "Admin can delete order items" ON order_items;
CREATE POLICY "Admin can delete order items"
    ON order_items FOR DELETE
    USING (public.is_admin());

-- --------------------------------------------------------
-- STORE SETTINGS POLICIES
-- --------------------------------------------------------
-- Public can view store settings
DROP POLICY IF EXISTS "Store settings are viewable by everyone" ON store_settings;
CREATE POLICY "Store settings are viewable by everyone"
    ON store_settings FOR SELECT
    USING (true);

-- Admin can update store settings
DROP POLICY IF EXISTS "Admin can update store settings" ON store_settings;
CREATE POLICY "Admin can update store settings"
    ON store_settings FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================
-- 10. SEED DATA: 6 CONTOH PRODUK
-- ============================================================
INSERT INTO products (name, description, price, sale_price, category, type, image_url, file_url, stock, weight, status, featured) VALUES
(
    'Panduan Lengkap Digital Marketing 2024',
    'E-book lengkap tentang strategi digital marketing terbaru, SEO, social media marketing, dan email marketing. 200+ halaman dengan studi kasus nyata.',
    149000,
    99000,
    'ebook',
    'digital',
    'https://images.unsplash.com/photo-1553484771-047a44eee27b?w=800',
    '',
    999,
    0,
    'active',
    true
),
(
    'Kursus Video: UI/UX Design Masterclass',
    '50+ video tutorial lengkap belajar UI/UX design dari nol sampai mahir. Termasuk studi kasus real project dan file Figma.',
    499000,
    349000,
    'video',
    'digital',
    'https://images.unsplash.com/photo-1561070791-2526d30994b5?w=800',
    '',
    999,
    0,
    'active',
    true
),
(
    'Template Portfolio Website Developer',
    'Template website portfolio modern untuk developer. Built with React + Tailwind CSS. Responsive dan mudah dikustomisasi.',
    199000,
    149000,
    'template',
    'digital',
    'https://images.unsplash.com/photo-1517180102446-f3ece451e9d8?w=800',
    '',
    999,
    0,
    'active',
    false
),
(
    'Workshop Online: Jualan Digital Tanpa Ribet',
    'Live workshop 3 hari tentang cara memulai bisnis digital dari nol. Recording tersedia, dapat sertifikat.',
    299000,
    0,
    'workshop',
    'digital',
    'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?w=800',
    '',
    50,
    0,
    'active',
    true
),
(
    'Template CV Professional ATS-Friendly',
    '10 template CV profesional yang lolos ATS (Applicant Tracking System). Format Word dan PDF, mudah diedit.',
    79000,
    49000,
    'template',
    'digital',
    'https://images.unsplash.com/photo-1586281380349-632531db7ed4?w=800',
    '',
    999,
    0,
    'active',
    false
),
(
    'Notebook Premium Developer Edition',
    'Notebook eksklusif untuk developer dengan cheat sheet programming, halaman dotted, dan cover premium leather.',
    129000,
    0,
    'fisik',
    'physical',
    'https://images.unsplash.com/photo-1531346878377-a5be20888e57?w=800',
    '',
    100,
    500,
    'active',
    true
)
ON CONFLICT DO NOTHING;

-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_status ON products(status);
CREATE INDEX IF NOT EXISTS idx_products_featured ON products(featured);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

-- ============================================================
-- 11. DECREMENT STOCK FUNCTION (for physical products)
-- ============================================================
CREATE OR REPLACE FUNCTION public.decrement_stock(product_id UUID, quantity INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE products
    SET stock = stock - quantity
    WHERE id = product_id AND stock >= quantity;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- AUTO UPDATE updated_at TIMESTAMP
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for auto-updating updated_at
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_orders_updated_at ON orders;
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_store_settings_updated_at ON store_settings;
CREATE TRIGGER update_store_settings_updated_at
    BEFORE UPDATE ON store_settings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- 12. PROMOTE USER TO ADMIN (helper function)
-- ============================================================
-- Gunakan di SQL Editor Supabase untuk menambahkan admin:
-- SELECT promote_to_admin('email@contoh.com');
CREATE OR REPLACE FUNCTION public.promote_to_admin(user_email TEXT)
RETURNS TEXT AS $$
DECLARE
    target_id UUID;
BEGIN
    SELECT id INTO target_id FROM auth.users WHERE email = user_email;
    IF target_id IS NULL THEN
        RETURN 'Error: User dengan email ' || user_email || ' tidak ditemukan';
    END IF;
    UPDATE public.profiles SET role = 'admin' WHERE id = target_id;
    RETURN 'Berhasil: ' || user_email || ' sekarang menjadi admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 13. ADD YOUTUBE URL TO PRODUCTS
-- ============================================================
ALTER TABLE products ADD COLUMN IF NOT EXISTS youtube_url TEXT DEFAULT '';

-- ============================================================
-- SETUP COMPLETE
-- ============================================================
-- Tables created: profiles, products, orders, order_items, store_settings
-- Functions created: handle_new_user, generate_order_number, is_admin, update_updated_at_column, promote_to_admin
-- Triggers created: on_auth_user_created, on_order_insert, update_*_updated_at
-- RLS enabled with policies for all tables
-- Seed data: 6 sample products inserted
-- Indexes created for better query performance
--
-- SUPERADMIN: User pertama yang mendaftar otomatis menjadi admin.
-- Untuk menambahkan admin lain, jalankan: SELECT promote_to_admin('email@contoh.com');

-- ============================================================
-- 13B. MULTI-IMAGE & BANNER COLUMNS
-- ============================================================
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_urls JSONB DEFAULT '[]';
ALTER TABLE store_settings ADD COLUMN IF NOT EXISTS banner_urls JSONB DEFAULT '[]';

-- ============================================================
-- 14. STORAGE BUCKET POLICIES (WAJIB untuk upload)
-- ============================================================
-- JALANKAN QUERY INI DI SQL EDITOR SUPABASE
-- Pastikan bucket sudah dibuat di Storage:
-- product-images (public), product-files (private), store-assets (public), payment-proofs (private)

-- -------- product-images (Public bucket) --------
-- Semua orang bisa lihat gambar produk
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Public read product-images', 'product-images', 'SELECT', 'true'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Public read product-images' AND bucket_id = 'product-images');

-- Admin bisa upload gambar produk
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Admin upload product-images', 'product-images', 'INSERT', '(EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ''admin''))'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Admin upload product-images' AND bucket_id = 'product-images');

-- Admin bisa update gambar produk
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Admin update product-images', 'product-images', 'UPDATE', '(EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ''admin''))'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Admin update product-images' AND bucket_id = 'product-images');

-- Admin bisa hapus gambar produk
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Admin delete product-images', 'product-images', 'DELETE', '(EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ''admin''))'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Admin delete product-images' AND bucket_id = 'product-images');

-- -------- product-files (Private bucket) --------
-- Admin bisa upload file digital
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Admin upload product-files', 'product-files', 'INSERT', '(EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ''admin''))'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Admin upload product-files' AND bucket_id = 'product-files');

-- Admin bisa update file digital
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Admin update product-files', 'product-files', 'UPDATE', '(EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ''admin''))'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Admin update product-files' AND bucket_id = 'product-files');

-- Admin bisa hapus file digital
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Admin delete product-files', 'product-files', 'DELETE', '(EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ''admin''))'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Admin delete product-files' AND bucket_id = 'product-files');

-- -------- store-assets (Public bucket) --------
-- Semua orang bisa lihat assets toko
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Public read store-assets', 'store-assets', 'SELECT', 'true'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Public read store-assets' AND bucket_id = 'store-assets');

-- Admin bisa upload assets toko
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Admin upload store-assets', 'store-assets', 'INSERT', '(EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ''admin''))'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Admin upload store-assets' AND bucket_id = 'store-assets');

-- Admin bisa update assets toko
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Admin update store-assets', 'store-assets', 'UPDATE', '(EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ''admin''))'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Admin update store-assets' AND bucket_id = 'store-assets');

-- Admin bisa hapus assets toko
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Admin delete store-assets', 'store-assets', 'DELETE', '(EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ''admin''))'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Admin delete store-assets' AND bucket_id = 'store-assets');

-- -------- payment-proofs (Private bucket) --------
-- User yang login bisa upload bukti bayar
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Authenticated upload payment-proofs', 'payment-proofs', 'INSERT', '(auth.uid() IS NOT NULL)'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Authenticated upload payment-proofs' AND bucket_id = 'payment-proofs');

-- Admin bisa lihat semua bukti bayar
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Admin read payment-proofs', 'payment-proofs', 'SELECT', '(EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ''admin''))'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Admin read payment-proofs' AND bucket_id = 'payment-proofs');

-- Admin bisa hapus bukti bayar
INSERT INTO storage.policies (name, bucket_id, operation, definition)
SELECT 'Admin delete payment-proofs', 'payment-proofs', 'DELETE', '(EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = ''admin''))'
WHERE NOT EXISTS (SELECT 1 FROM storage.policies WHERE name = 'Admin delete payment-proofs' AND bucket_id = 'payment-proofs');
