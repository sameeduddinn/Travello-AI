-- ================================================================
-- TABLE: drivers
-- Pool of mock drivers per city
-- ================================================================
CREATE TABLE IF NOT EXISTS drivers (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT        NOT NULL,
    phone           TEXT        NOT NULL,
    vehicle_type    TEXT        NOT NULL CHECK (vehicle_type IN ('Sedan', 'SUV', 'Van')),
    vehicle_make    TEXT        NOT NULL,
    vehicle_model   TEXT        NOT NULL,
    vehicle_plate   TEXT        NOT NULL UNIQUE,
    vehicle_color   TEXT        NOT NULL,
    rating          NUMERIC(2,1) DEFAULT 4.5,
    city            TEXT        NOT NULL,
    is_active       BOOLEAN     DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE drivers DROP COLUMN city;


-- ================================================================
-- TABLE: car_bookings
-- One row per transfer leg booked by a user
-- booking_id is nullable — supports future standalone bookings
-- ================================================================
CREATE TABLE IF NOT EXISTS car_bookings (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id          UUID        REFERENCES bookings(id) ON DELETE SET NULL,
    user_id             UUID        NOT NULL,
    driver_id           UUID        REFERENCES drivers(id),
    transfer_type       TEXT        NOT NULL CHECK (transfer_type IN (
                                        'departure',         -- home → airport
                                        'arrival',           -- airport → destination
                                        'return_departure',  -- hotel → return airport
                                        'return_arrival'     -- return airport → home
                                    )),
    pickup_location     TEXT        NOT NULL,
    vehicle_type        TEXT        NOT NULL,
    pickup_datetime     TIMESTAMPTZ,
    verification_code   TEXT        NOT NULL,
    contact_email       TEXT        NOT NULL,
    status              TEXT        NOT NULL DEFAULT 'confirmed'
                                    CHECK (status IN ('confirmed','completed','cancelled')),
    total_amount        NUMERIC(10,2) DEFAULT 0,
    currency            TEXT        DEFAULT 'PKR',
    created_at          TIMESTAMPTZ DEFAULT now()
);

-- ================================================================
-- RLS
-- ================================================================
ALTER TABLE drivers    ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_bookings ENABLE ROW LEVEL SECURITY;

-- Drivers: any authenticated user can read active drivers
CREATE POLICY "read_active_drivers" ON drivers
    FOR SELECT TO authenticated
    USING (is_active = true);

-- Car bookings: users see and create only their own rows
CREATE POLICY "read_own_car_bookings" ON car_bookings
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "insert_own_car_bookings" ON car_bookings
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Service role can do everything (backend uses supabase_admin)
CREATE POLICY "service_role_all_drivers" ON drivers
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_car_bookings" ON car_bookings
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ================================================================
-- MOCK DRIVERS — 3 per vehicle type per major city
-- ================================================================
INSERT INTO drivers (name, phone, vehicle_type, vehicle_make, vehicle_model, vehicle_plate, vehicle_color, rating) VALUES

-- Sedans
('Muhammad Asif',   '+92-321-1234567', 'Sedan', 'Toyota', 'Corolla', 'ABC-3421', 'White',  4.8),
('Ali Hassan',      '+92-333-9876543', 'Sedan', 'Honda',  'City',    'DEF-7892', 'Silver', 4.7),
('Farhan Siddiqui', '+92-311-2223334', 'Sedan', 'Suzuki', 'Ciaz',    'GHI-1045', 'Grey',   4.6),
('Bilal Ahmed',     '+92-300-2345678', 'Sedan', 'Honda',  'Civic',   'JKL-8821', 'White',  4.9),
('Usman Malik',     '+92-321-8765432', 'Sedan', 'Toyota', 'Corolla', 'MNO-3341', 'Silver', 4.7),
('Hamza Chaudhry',  '+92-333-1234321', 'Sedan', 'Suzuki', 'Ciaz',    'PQR-6612', 'Grey',   4.8),
('Kamran Ali',      '+92-345-9988776', 'Sedan', 'Honda',  'City',    'STU-5543', 'White',  4.6),
('Adnan Raza',      '+92-321-3344556', 'Sedan', 'Honda',  'Civic',   'VWX-8834', 'Silver', 4.7),
('Salman Yousaf',   '+92-312-1122334', 'Sedan', 'Toyota', 'Corolla', 'YZA-4412', 'White',  4.8),
('Kashif Sultan',   '+92-313-5566778', 'Sedan', 'Honda',  'City',    'BCD-2234', 'Grey',   4.7),
('Naveed Akhtar',   '+92-347-6677889', 'Sedan', 'Toyota', 'Corolla', 'EFG-7789', 'White',  4.6),
('Ijaz Cheema',     '+92-315-2233445', 'Sedan', 'Honda',  'Civic',   'HIJ-3345', 'Silver', 4.9),

-- SUVs
('Tariq Mahmood',   '+92-311-5554321', 'SUV', 'Toyota', 'Fortuner',     'KLM-1156', 'Black', 4.9),
('Junaid Rehman',   '+92-345-4445556', 'SUV', 'Honda',  'BR-V',         'NOP-8823', 'White', 4.7),
('Noman Farooq',    '+92-300-6667778', 'SUV', 'Kia',    'Sportage',     'QRS-5534', 'Grey',  4.8),
('Shahid Iqbal',    '+92-333-1122334', 'SUV', 'Toyota', 'Fortuner',     'TUV-9967', 'Black', 4.6),
('Waqas Javed',     '+92-311-9988776', 'SUV', 'Toyota', 'Land Cruiser', 'WXY-4423', 'White', 4.9),
('Arslan Butt',     '+92-345-5566778', 'SUV', 'Kia',    'Sportage',     'ZAB-7751', 'Grey',  4.7),
('Zeeshan Butt',    '+92-333-6655443', 'SUV', 'Toyota', 'Fortuner',     'CDE-4467', 'Black', 4.8),
('Asad Karim',      '+92-311-4455667', 'SUV', 'Honda',  'BR-V',         'FGH-2231', 'White', 4.7),
('Waseem Baig',     '+92-303-7788990', 'SUV', 'Kia',    'Sportage',     'IJK-4456', 'Black', 4.9),
('Nasir Khan',      '+92-302-3344556', 'SUV', 'Toyota', 'Fortuner',     'LMN-3321', 'Grey',  4.8),

-- Vans
('Imran Khan',      '+92-345-6781234', 'Van', 'Toyota', 'Hiace',       'OPQ-4453', 'White',  4.6),
('Shahbaz Anwar',   '+92-321-7778889', 'Van', 'Suzuki', 'APV',         'RST-2267', 'Silver', 4.5),
('Aamir Qureshi',   '+92-333-8889990', 'Van', 'Toyota', 'Hiace Grand', 'UVW-9981', 'White',  4.7),
('Faisal Mehmood',  '+92-311-4433221', 'Van', 'Suzuki', 'APV',         'XYZ-2278', 'Silver', 4.5),
('Zubair Hussain',  '+92-300-3344556', 'Van', 'Toyota', 'Hiace',       'ABC-5543', 'White',  4.6),
('Saad Nawaz',      '+92-321-6677889', 'Van', 'Toyota', 'Hiace Grand', 'DEF-1190', 'White',  4.8),
('Omar Farhan',     '+92-300-8899001', 'Van', 'Toyota', 'Hiace',       'GHI-3345', 'White',  4.6),
('Sohail Ahmed',    '+92-321-9900112', 'Van', 'Suzuki', 'APV',         'JKL-7723', 'Silver', 4.5),
('Tahir Gondal',    '+92-325-8899001', 'Van', 'Toyota', 'Hiace',       'MNO-1123', 'White',  4.7),
('Jawad Afridi',    '+92-324-4455667', 'Van', 'Toyota', 'Hiace Grand', 'PQR-6645', 'White',  4.5);
ALTER TABLE car_bookings ADD COLUMN IF NOT EXISTS dropoff_location TEXT;

ALTER TABLE car_bookings DROP CONSTRAINT IF EXISTS car_bookings_transfer_type_check;
ALTER TABLE car_bookings ADD CONSTRAINT car_bookings_transfer_type_check
  CHECK (transfer_type IN ('departure','arrival','return_departure','return_arrival','standalone'));
