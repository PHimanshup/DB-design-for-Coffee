-- ============================================================
--  P&G COFFEE SHOP – Inventory & Waste Management System
--  COM7112 Information Systems and Database Design
--  Full Relational Database Prototype with CRUD & Insights
-- ============================================================

-- ============================================================
-- STEP 1: CREATE THE DATABASE
-- ============================================================

DROP DATABASE IF EXISTS pg_coffee_shop;
CREATE DATABASE pg_coffee_shop;
USE pg_coffee_shop;


-- ============================================================
-- STEP 2: CREATE ALL TABLES (Normalised to 3NF)
-- ============================================================

-- TABLE 1: Staff
-- Stores all employee records. Each staff member has a role.
CREATE TABLE Staff (
    staff_id       INT AUTO_INCREMENT PRIMARY KEY,
    full_name      VARCHAR(100) NOT NULL,
    role           VARCHAR(50)  NOT NULL,   -- e.g. Barista, Manager, Supervisor
    hourly_rate    DECIMAL(5,2) NOT NULL,
    hours_per_week INT          NOT NULL,
    hire_date      DATE         NOT NULL
);

-- TABLE 2: Suppliers
-- Stores supplier contact and delivery reliability data.
CREATE TABLE Suppliers (
    supplier_id   INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    contact_name  VARCHAR(100),
    phone         VARCHAR(20),
    email         VARCHAR(100),
    reliability   VARCHAR(20) DEFAULT 'Good'  -- Good / Average / Poor
);

-- TABLE 3: Inventory_Items
-- Master list of all stock items the shop uses.
CREATE TABLE Inventory_Items (
    item_id          INT AUTO_INCREMENT PRIMARY KEY,
    item_name        VARCHAR(100) NOT NULL,
    category         VARCHAR(50)  NOT NULL,   -- Dairy / Beans / Syrup / Pastry / Packaging
    unit             VARCHAR(20)  NOT NULL,   -- Litre / kg / Units / Box
    reorder_level    DECIMAL(10,2) NOT NULL,  -- Trigger point for re-ordering
    current_stock    DECIMAL(10,2) NOT NULL DEFAULT 0,
    unit_sell_price  DECIMAL(8,2),            -- Revenue per unit sold (NULL if not directly sold)
    supplier_id      INT,
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
);

-- TABLE 4: Stock_Purchase  (Deliveries received from suppliers)
-- Records every delivery so discrepancies can be audited.
CREATE TABLE Stock_Purchase (
    purchase_id     INT AUTO_INCREMENT PRIMARY KEY,
    item_id         INT           NOT NULL,
    supplier_id     INT           NOT NULL,
    quantity        DECIMAL(10,2) NOT NULL,
    unit_cost       DECIMAL(8,2)  NOT NULL,   -- Cost per unit at time of purchase
    total_cost      DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
    purchase_date   DATE          NOT NULL,
    expiry_date     DATE,
    delivery_status VARCHAR(20)   DEFAULT 'On Time',  -- On Time / Late / Damaged
    FOREIGN KEY (item_id)     REFERENCES Inventory_Items(item_id),
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(supplier_id)
);

-- TABLE 5: Sales
-- Records daily product sales. Drives revenue and stock deduction.
CREATE TABLE Sales (
    sale_id       INT AUTO_INCREMENT PRIMARY KEY,
    sale_date     DATE          NOT NULL,
    item_id       INT           NOT NULL,
    quantity_sold DECIMAL(10,2) NOT NULL,
    sale_price    DECIMAL(8,2)  NOT NULL,   -- Price charged per unit
    total_revenue DECIMAL(10,2) GENERATED ALWAYS AS (quantity_sold * sale_price) STORED,
    staff_id      INT,
    FOREIGN KEY (item_id)  REFERENCES Inventory_Items(item_id),
    FOREIGN KEY (staff_id) REFERENCES Staff(staff_id)
);

-- TABLE 6: Stock_Usage
-- Records how much stock is consumed (per sale batch or manual adjustment).
-- This table lets us reconcile: Opening Stock + Purchases - Usage = Closing Stock
CREATE TABLE Stock_Usage (
    usage_id      INT AUTO_INCREMENT PRIMARY KEY,
    item_id       INT           NOT NULL,
    usage_date    DATE          NOT NULL,
    quantity_used DECIMAL(10,2) NOT NULL,
    usage_reason  VARCHAR(50)   NOT NULL,  -- Sale / Waste / Testing / Spillage
    sale_id       INT,                     -- Link to sale if reason = Sale
    FOREIGN KEY (item_id) REFERENCES Inventory_Items(item_id),
    FOREIGN KEY (sale_id) REFERENCES Sales(sale_id)
);

-- TABLE 7: Waste_Log
-- Dedicated waste tracking with reasons for management reporting.
-- reason values: Spoiled / Expired / Spillage / Over-Ordered / Theft
-- theft_reported: YES = formally logged with manager, NO = suspected only, NULL = not a theft row
CREATE TABLE Waste_Log (
    waste_id        INT AUTO_INCREMENT PRIMARY KEY,
    item_id         INT           NOT NULL,
    waste_date      DATE          NOT NULL,
    quantity_wasted DECIMAL(10,2) NOT NULL,
    reason          VARCHAR(100)  NOT NULL,  -- Spoiled / Expired / Spillage / Over-Ordered / Theft
    estimated_cost  DECIMAL(10,2),           -- Cost value of the loss
    theft_reported  VARCHAR(3)    DEFAULT NULL, -- YES / NO / NULL (only set on Theft rows)
    logged_by       INT,                     -- staff_id who noticed and recorded the loss
    FOREIGN KEY (item_id)   REFERENCES Inventory_Items(item_id),
    FOREIGN KEY (logged_by) REFERENCES Staff(staff_id)
);

-- TABLE 8: Monthly_Summary  (Aggregated month-end snapshot)
-- Populated by a procedure; supports profit/loss reporting.
CREATE TABLE Monthly_Summary (
    summary_id       INT AUTO_INCREMENT PRIMARY KEY,
    report_month     DATE         NOT NULL,   -- First day of the month
    total_revenue    DECIMAL(12,2) DEFAULT 0,
    total_purchases  DECIMAL(12,2) DEFAULT 0,
    total_waste_cost DECIMAL(12,2) DEFAULT 0,
    total_wage_cost  DECIMAL(12,2) DEFAULT 0,
    net_profit       DECIMAL(12,2) GENERATED ALWAYS AS
                     (total_revenue - total_purchases - total_waste_cost - total_wage_cost) STORED
);


-- ============================================================
-- STEP 3: INSERT SAMPLE DATA
-- ============================================================

-- ── Suppliers ──────────────────────────────────────────────
INSERT INTO Suppliers (supplier_name, contact_name, phone, email, reliability) VALUES
('FreshDairy Ltd',      'Anna White',   '01234 567890', 'anna@freshdairy.co.uk',    'Good'),
('BeanMasters UK',      'James Patel',  '02034 112233', 'james@beanmasters.co.uk',  'Good'),
('SweetSyrups Co',      'Clara Jones',  '01782 334455', 'clara@sweetsyrups.co.uk',  'Average'),
('BakeryDirect',        'Tom Singh',    '01902 667788', 'tom@bakerydirect.co.uk',   'Good'),
('PackRight Supplies',  'Raj Kumar',    '01753 990011', 'raj@packright.co.uk',      'Good');

-- ── Staff ──────────────────────────────────────────────────
INSERT INTO Staff (full_name, role, hourly_rate, hours_per_week, hire_date) VALUES
('Sarah Mitchell',  'Manager',    14.50, 40, '2021-03-01'),
('Liam Brown',      'Barista',    11.44, 35, '2022-06-15'),
('Priya Sharma',    'Barista',    11.44, 35, '2023-01-10'),
('Daniel Owusu',    'Supervisor', 12.50, 38, '2022-09-20'),
('Fatima Al-Hasan', 'Barista',    11.44, 30, '2024-02-01');

-- ── Inventory Items  (with opening stock = start of March 2025) ──
-- current_stock reflects what was ON HAND before any March transactions
INSERT INTO Inventory_Items (item_name, category, unit, reorder_level, current_stock, unit_sell_price, supplier_id) VALUES
('Whole Milk',        'Dairy',     'Litre',  20.00,  28.00,  NULL, 1),  -- item_id 1
('Oat Milk',          'Dairy',     'Litre',  15.00,  18.00,  NULL, 1),  -- item_id 2
('Espresso Beans',    'Beans',     'kg',     10.00,  14.00,  NULL, 2),  -- item_id 3
('Vanilla Syrup',     'Syrup',     'Litre',   3.00,   4.50,  NULL, 3),  -- item_id 4
('Caramel Syrup',     'Syrup',     'Litre',   3.00,   3.00,  NULL, 3),  -- item_id 5
('Croissant',         'Pastry',    'Units',  30.00,  40.00,  3.50, 4),  -- item_id 6
('Blueberry Muffin',  'Pastry',    'Units',  20.00,  25.00,  2.80, 4),  -- item_id 7
('Paper Cups (8oz)',  'Packaging', 'Units', 200.00, 350.00,  NULL, 5),  -- item_id 8
('Takeaway Bags',     'Packaging', 'Units', 100.00, 160.00,  NULL, 5),  -- item_id 9
('Americano Coffee',  'Beverage',  'Units',   0.00,   0.00,  3.20, 2),  -- item_id 10  (virtual – sold item)
('Flat White Coffee', 'Beverage',  'Units',   0.00,   0.00,  3.80, 2),  -- item_id 11
('Oat Milk Latte',    'Beverage',  'Units',   0.00,   0.00,  4.20, 2);  -- item_id 12

-- ── Stock Purchases (March 2025 deliveries) ─────────────────
INSERT INTO Stock_Purchase (item_id, supplier_id, quantity, unit_cost, purchase_date, expiry_date, delivery_status) VALUES
(1,  1, 60.00,  0.85, '2025-03-01', '2025-03-07', 'On Time'),   -- Whole Milk Week 1
(2,  1, 40.00,  1.20, '2025-03-01', '2025-03-07', 'On Time'),   -- Oat Milk Week 1
(3,  2, 20.00,  8.50, '2025-03-03', '2025-06-03', 'On Time'),   -- Espresso Beans
(6,  4, 150.00, 1.10, '2025-03-03', '2025-03-04', 'On Time'),   -- Croissants Week 1
(7,  4, 100.00, 0.90, '2025-03-03', '2025-03-04', 'On Time'),   -- Muffins Week 1
(4,  3, 6.00,   4.20, '2025-03-05', '2025-09-05', 'Late'),      -- Vanilla Syrup (late delivery)
(5,  3, 6.00,   4.00, '2025-03-05', '2025-09-05', 'Late'),      -- Caramel Syrup (late delivery)
(8,  5, 500.00, 0.05, '2025-03-07', NULL,          'On Time'),  -- Paper Cups
(9,  5, 300.00, 0.08, '2025-03-07', NULL,          'On Time'),  -- Takeaway Bags
(1,  1, 60.00,  0.85, '2025-03-08', '2025-03-14', 'On Time'),  -- Whole Milk Week 2
(2,  1, 40.00,  1.20, '2025-03-08', '2025-03-14', 'On Time'),  -- Oat Milk Week 2
(6,  4, 150.00, 1.10, '2025-03-10', '2025-03-11', 'On Time'),  -- Croissants Week 2
(7,  4, 100.00, 0.90, '2025-03-10', '2025-03-11', 'On Time'),  -- Muffins Week 2
(1,  1, 60.00,  0.85, '2025-03-15', '2025-03-21', 'On Time'),  -- Whole Milk Week 3
(2,  1, 40.00,  1.20, '2025-03-15', '2025-03-21', 'On Time'),  -- Oat Milk Week 3
(3,  2, 15.00,  8.50, '2025-03-17', '2025-06-17', 'On Time'),  -- Espresso Beans mid-month
(6,  4, 150.00, 1.10, '2025-03-17', '2025-03-18', 'On Time'),  -- Croissants Week 3
(7,  4, 100.00, 0.90, '2025-03-17', '2025-03-18', 'On Time'),  -- Muffins Week 3
(1,  1, 60.00,  0.85, '2025-03-22', '2025-03-28', 'On Time'),  -- Whole Milk Week 4
(2,  1, 35.00,  1.20, '2025-03-22', '2025-03-28', 'On Time'),  -- Oat Milk Week 4
(6,  4, 140.00, 1.10, '2025-03-24', '2025-03-25', 'On Time'),  -- Croissants Week 4
(7,  4,  90.00, 0.90, '2025-03-24', '2025-03-25', 'On Time'),  -- Muffins Week 4
(8,  5, 500.00, 0.05, '2025-03-24', NULL,          'On Time'),  -- Paper Cups refill
(9,  5, 200.00, 0.08, '2025-03-24', NULL,          'On Time');  -- Takeaway Bags refill

-- ── Sales – March 2025 (daily realistic volumes, 26 trading days) ──
-- We insert representative weekly batches to keep the script manageable.
-- Beverages (items 10-12) drive milk & bean consumption via Stock_Usage.

-- Week 1 (3–7 Mar)
INSERT INTO Sales (sale_date, item_id, quantity_sold, sale_price, staff_id) VALUES
('2025-03-03', 10, 80,  3.20, 2),  -- Americano
('2025-03-03', 11, 60,  3.80, 2),  -- Flat White
('2025-03-03', 12, 40,  4.20, 3),  -- Oat Milk Latte
('2025-03-03', 6,  45,  3.50, 4),  -- Croissant
('2025-03-03', 7,  30,  2.80, 4),  -- Muffin
('2025-03-04', 10, 75,  3.20, 2),
('2025-03-04', 11, 55,  3.80, 3),
('2025-03-04', 12, 38,  4.20, 3),
('2025-03-04', 6,  40,  3.50, 4),
('2025-03-04', 7,  28,  2.80, 4),
('2025-03-05', 10, 82,  3.20, 2),
('2025-03-05', 11, 62,  3.80, 2),
('2025-03-05', 12, 42,  4.20, 5),
('2025-03-05', 6,  48,  3.50, 4),
('2025-03-05', 7,  32,  2.80, 4),
('2025-03-06', 10, 90,  3.20, 3),  -- Thursday peak
('2025-03-06', 11, 70,  3.80, 3),
('2025-03-06', 12, 50,  4.20, 5),
('2025-03-06', 6,  55,  3.50, 4),
('2025-03-06', 7,  35,  2.80, 4),
('2025-03-07', 10, 95,  3.20, 2),  -- Friday peak
('2025-03-07', 11, 75,  3.80, 2),
('2025-03-07', 12, 55,  4.20, 3),
('2025-03-07', 6,  60,  3.50, 4),
('2025-03-07', 7,  40,  2.80, 4),

-- Week 2 (10–14 Mar)
('2025-03-10', 10, 78,  3.20, 2),
('2025-03-10', 11, 58,  3.80, 3),
('2025-03-10', 12, 36,  4.20, 5),
('2025-03-10', 6,  44,  3.50, 4),
('2025-03-10', 7,  29,  2.80, 4),
('2025-03-11', 10, 80,  3.20, 2),
('2025-03-11', 11, 60,  3.80, 2),
('2025-03-11', 12, 40,  4.20, 3),
('2025-03-11', 6,  46,  3.50, 4),
('2025-03-11', 7,  30,  2.80, 4),
('2025-03-12', 10, 83,  3.20, 3),
('2025-03-12', 11, 63,  3.80, 3),
('2025-03-12', 12, 43,  4.20, 5),
('2025-03-12', 6,  49,  3.50, 4),
('2025-03-12', 7,  33,  2.80, 4),
('2025-03-13', 10, 88,  3.20, 2),
('2025-03-13', 11, 68,  3.80, 2),
('2025-03-13', 12, 48,  4.20, 5),
('2025-03-13', 6,  52,  3.50, 4),
('2025-03-13', 7,  34,  2.80, 4),
('2025-03-14', 10, 92,  3.20, 3),
('2025-03-14', 11, 72,  3.80, 3),
('2025-03-14', 12, 52,  4.20, 5),
('2025-03-14', 6,  58,  3.50, 4),
('2025-03-14', 7,  38,  2.80, 4),

-- Week 3 (17–21 Mar)
('2025-03-17', 10, 79,  3.20, 2),
('2025-03-17', 11, 59,  3.80, 3),
('2025-03-17', 12, 39,  4.20, 5),
('2025-03-17', 6,  45,  3.50, 4),
('2025-03-17', 7,  30,  2.80, 4),
('2025-03-18', 10, 81,  3.20, 2),
('2025-03-18', 11, 61,  3.80, 2),
('2025-03-18', 12, 41,  4.20, 3),
('2025-03-18', 6,  47,  3.50, 4),
('2025-03-18', 7,  31,  2.80, 4),
('2025-03-19', 10, 84,  3.20, 3),
('2025-03-19', 11, 64,  3.80, 3),
('2025-03-19', 12, 44,  4.20, 5),
('2025-03-19', 6,  50,  3.50, 4),
('2025-03-19', 7,  33,  2.80, 4),
('2025-03-20', 10, 89,  3.20, 2),
('2025-03-20', 11, 69,  3.80, 2),
('2025-03-20', 12, 49,  4.20, 5),
('2025-03-20', 6,  54,  3.50, 4),
('2025-03-20', 7,  35,  2.80, 4),
('2025-03-21', 10, 93,  3.20, 3),
('2025-03-21', 11, 73,  3.80, 3),
('2025-03-21', 12, 53,  4.20, 2),
('2025-03-21', 6,  59,  3.50, 4),
('2025-03-21', 7,  39,  2.80, 4),

-- Week 4 (24–28 Mar)
('2025-03-24', 10, 77,  3.20, 2),
('2025-03-24', 11, 57,  3.80, 3),
('2025-03-24', 12, 37,  4.20, 5),
('2025-03-24', 6,  43,  3.50, 4),
('2025-03-24', 7,  28,  2.80, 4),
('2025-03-25', 10, 80,  3.20, 2),
('2025-03-25', 11, 60,  3.80, 2),
('2025-03-25', 12, 40,  4.20, 3),
('2025-03-25', 6,  46,  3.50, 4),
('2025-03-25', 7,  30,  2.80, 4),
('2025-03-26', 10, 82,  3.20, 3),
('2025-03-26', 11, 62,  3.80, 3),
('2025-03-26', 12, 42,  4.20, 5),
('2025-03-26', 6,  48,  3.50, 4),
('2025-03-26', 7,  32,  2.80, 4),
('2025-03-27', 10, 87,  3.20, 2),
('2025-03-27', 11, 67,  3.80, 2),
('2025-03-27', 12, 47,  4.20, 5),
('2025-03-27', 6,  52,  3.50, 4),
('2025-03-27', 7,  34,  2.80, 4),
('2025-03-28', 10, 91,  3.20, 3),
('2025-03-28', 11, 71,  3.80, 3),
('2025-03-28', 12, 51,  4.20, 2),
('2025-03-28', 6,  57,  3.50, 4),
('2025-03-28', 7,  37,  2.80, 4);

-- ── Stock Usage (weekly batch – one row per ingredient per week) ──
-- How quantities were worked out:
--   Whole Milk  = (Americanos sold + Flat Whites sold) × 0.20 L per drink
--   Oat Milk    = Oat Milk Lattes sold × 0.25 L per drink
--   Beans       = Total drinks sold × 0.015 kg per drink
--   Croissants / Muffins = units sold (1-to-1)
-- All numbers below are the pre-calculated totals for each week.


INSERT INTO Stock_Usage (item_id, usage_date, quantity_used, usage_reason)

-- Whole Milk consumed by Americanos (item 10) and Flat Whites (item 11)
-- Both drinks use 0.20 L per cup, so sum them together per day
SELECT
    1                                           AS item_id,   -- Whole Milk
    sale_date                                   AS usage_date,
    ROUND(SUM(quantity_sold) * 0.20, 3)         AS quantity_used,
    'Sale'                                      AS usage_reason
FROM Sales
WHERE item_id IN (10, 11)                        -- Americano + Flat White
GROUP BY sale_date

UNION ALL

-- Oat Milk consumed by Oat Milk Lattes (item 12) at 0.25 L per cup
SELECT
    2,                                           -- Oat Milk
    sale_date,
    ROUND(SUM(quantity_sold) * 0.25, 3),
    'Sale'
FROM Sales
WHERE item_id = 12                               -- Oat Milk Latte only
GROUP BY sale_date

UNION ALL

-- Espresso Beans consumed by ALL drink types (items 10, 11, 12) at 0.015 kg per drink
SELECT
    3,                                           -- Espresso Beans
    sale_date,
    ROUND(SUM(quantity_sold) * 0.015, 3),
    'Sale'
FROM Sales
WHERE item_id IN (10, 11, 12)                    -- Every drink type
GROUP BY sale_date

UNION ALL

-- Croissants consumed 1-to-1 with units sold (item 6)
SELECT
    6,                                           -- Croissant
    sale_date,
    SUM(quantity_sold),
    'Sale'
FROM Sales
WHERE item_id = 6
GROUP BY sale_date

UNION ALL

-- Muffins consumed 1-to-1 with units sold (item 7)
SELECT
    7,                                           -- Blueberry Muffin
    sale_date,
    SUM(quantity_sold),
    'Sale'
FROM Sales
WHERE item_id = 7
GROUP BY sale_date;

-- ─────────────────────────────────────────────────────────────
-- WEEK 1 (03–07 Mar)
-- Drinks sold: 422 Americanos + 322 Flat Whites + 225 Oat Lattes
-- ─────────────────────────────────────────────────────────────



-- ─────────────────────────────────────────────────────────────
-- WEEK 2 (10–14 Mar)
-- Drinks sold: 421 Americanos + 321 Flat Whites + 219 Oat Lattes
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- WEEK 3 (17–21 Mar)
-- Drinks sold: 426 Americanos + 326 Flat Whites + 226 Oat Lattes
-- ─────────────────────────────────────────────────────────────


-- ─────────────────────────────────────────────────────────────
-- WEEK 4 (24–28 Mar)
-- Drinks sold: 417 Americanos + 317 Flat Whites + 217 Oat Lattes
-- ─────────────────────────────────────────────────────────────

-- ── Waste Log – March 2025 ─────────────────────────────────
-- Single INSERT covering ALL loss events in date order:
--   Spoiled      = pastries unsold by end of day
--   Over-Ordered = unsold batch too large for the day
--   Expired      = dairy past best-before date
--   Spillage     = accidental liquid spill
--   Theft        = stock missing / unaccounted for
--
-- theft_reported column:
--   NULL = not a theft row
--   'NO' = loss suspected as theft but not formally confirmed
--   'YES' = manager formally logged the incident
--
-- Columns: (item_id, waste_date, quantity_wasted, reason, estimated_cost, theft_reported, logged_by)

INSERT INTO Waste_Log (item_id, waste_date, quantity_wasted, reason, estimated_cost, theft_reported, logged_by) VALUES

-- ── WEEK 1 (03–07 Mar) ──────────────────────────────────────
-- 03 Mar: End-of-day pastry spoilage
(6,  '2025-03-03', 5,    'Spoiled – end of day unsold',        5.50,  NULL,  1),
(7,  '2025-03-03', 4,    'Spoiled – end of day unsold',        3.60,  NULL,  1),
-- 03 Mar: 4 croissants unaccounted after close – no CCTV available
(6,  '2025-03-03', 4,    'Theft – missing after close',        4.40,  'NO',  1),

-- 04 Mar: End-of-day pastry spoilage
(6,  '2025-03-04', 4,    'Spoiled – end of day unsold',        4.40,  NULL,  4),
(7,  '2025-03-04', 3,    'Spoiled – end of day unsold',        2.70,  NULL,  4),

-- 05 Mar: End-of-day pastry spoilage
(6,  '2025-03-05', 3,    'Spoiled – end of day unsold',        3.30,  NULL,  4),
(7,  '2025-03-05', 2,    'Spoiled – end of day unsold',        1.80,  NULL,  4),
-- 05 Mar: Vanilla syrup 0.5L short at till – suspected shrinkage
(4,  '2025-03-05', 0.50, 'Theft – suspected stock shrinkage',  2.10,  'NO',  4),

-- 06 Mar: Whole milk spillage – Liam dropped a full jug
(1,  '2025-03-06', 3.00, 'Spillage – dropped full jug',        2.55,  NULL,  2),

-- 07 Mar: End-of-week over-ordering
(6,  '2025-03-07', 5,    'Over-ordered – unsold batch',        5.50,  NULL,  1),
(7,  '2025-03-07', 3,    'Over-ordered – unsold batch',        2.70,  NULL,  1),

-- ── WEEKEND (08–09 Mar – shop closed) ───────────────────────
-- 09 Mar: Oat milk expired over the weekend
(2,  '2025-03-09', 4.00, 'Expired – past best-before',         4.80,  NULL,  3),

-- ── WEEK 2 (10–14 Mar) ──────────────────────────────────────
-- 10 Mar: End-of-day pastry spoilage
(6,  '2025-03-10', 4,    'Spoiled – end of day unsold',        4.40,  NULL,  4),
(7,  '2025-03-10', 3,    'Spoiled – end of day unsold',        2.70,  NULL,  4),

-- 11 Mar: End-of-day pastry spoilage
(6,  '2025-03-11', 5,    'Spoiled – end of day unsold',        5.50,  NULL,  4),
(7,  '2025-03-11', 3,    'Spoiled – end of day unsold',        2.70,  NULL,  4),

-- 12 Mar: End-of-day pastry spoilage
(6,  '2025-03-12', 4,    'Spoiled – end of day unsold',        4.40,  NULL,  1),
(7,  '2025-03-12', 2,    'Spoiled – end of day unsold',        1.80,  NULL,  1),

-- 13 Mar: End-of-day pastry spoilage
(6,  '2025-03-13', 5,    'Spoiled – end of day unsold',        5.50,  NULL,  4),
(7,  '2025-03-13', 3,    'Spoiled – end of day unsold',        2.70,  NULL,  4),
-- 13 Mar: 3 muffins unaccounted after Thursday rush – second occurrence, formally logged
(7,  '2025-03-13', 3,    'Theft – unaccounted after rush',     2.70,  'YES', 1),

-- 14 Mar: End-of-week over-ordering
(6,  '2025-03-14', 5,    'Spoiled – end of day unsold',        5.50,  NULL,  1),
(7,  '2025-03-14', 4,    'Over-ordered – unsold batch',        3.60,  NULL,  1),
-- 14 Mar: 1 kg beans missing from stock room – formally reported
(3,  '2025-03-14', 1.00, 'Theft – stock room discrepancy',     8.50,  'YES', 1),

-- ── WEEKEND (15–16 Mar) ─────────────────────────────────────
-- 16 Mar: Whole milk expired over the weekend
(1,  '2025-03-16', 2.50, 'Expired – weekend stock',            2.13,  NULL,  4),

-- ── WEEK 3 (17–21 Mar) ──────────────────────────────────────
-- 17 Mar: End-of-day pastry spoilage
(6,  '2025-03-17', 4,    'Spoiled – end of day unsold',        4.40,  NULL,  4),
(7,  '2025-03-17', 3,    'Spoiled – end of day unsold',        2.70,  NULL,  4),

-- 18 Mar: End-of-day pastry spoilage
(6,  '2025-03-18', 4,    'Spoiled – end of day unsold',        4.40,  NULL,  4),
(7,  '2025-03-18', 2,    'Spoiled – end of day unsold',        1.80,  NULL,  4),

-- 19 Mar: End-of-day pastry spoilage
(6,  '2025-03-19', 5,    'Spoiled – end of day unsold',        5.50,  NULL,  1),
(7,  '2025-03-19', 3,    'Spoiled – end of day unsold',        2.70,  NULL,  1),

-- 20 Mar: End-of-day pastry spoilage
(6,  '2025-03-20', 5,    'Spoiled – end of day unsold',        5.50,  NULL,  4),
(7,  '2025-03-20', 3,    'Spoiled – end of day unsold',        2.70,  NULL,  4),
-- 20 Mar: 5 croissants missing overnight – back door left unlocked, formally reported
(6,  '2025-03-20', 5,    'Theft – overnight stock loss',       5.50,  'YES', 1),

-- 21 Mar: End-of-week over-ordering
(6,  '2025-03-21', 5,    'Over-ordered – unsold batch',        5.50,  NULL,  1),
(7,  '2025-03-21', 4,    'Over-ordered – unsold batch',        3.60,  NULL,  1),
-- 21 Mar: Oat milk 2L short – suspected internal, logged for awareness
(2,  '2025-03-21', 2.00, 'Theft – suspected internal shrinkage', 2.40, 'NO', 4),

-- ── WEEK 4 (24–28 Mar) ──────────────────────────────────────
-- 24 Mar: End-of-day pastry spoilage
(6,  '2025-03-24', 4,    'Spoiled – end of day unsold',        4.40,  NULL,  4),
(7,  '2025-03-24', 3,    'Spoiled – end of day unsold',        2.70,  NULL,  4),

-- 25 Mar: End-of-day pastry spoilage
(6,  '2025-03-25', 4,    'Spoiled – end of day unsold',        4.40,  NULL,  4),
(7,  '2025-03-25', 2,    'Spoiled – end of day unsold',        1.80,  NULL,  4),

-- 26 Mar: End-of-day pastry spoilage
(6,  '2025-03-26', 5,    'Spoiled – end of day unsold',        5.50,  NULL,  1),
(7,  '2025-03-26', 3,    'Spoiled – end of day unsold',        2.70,  NULL,  1),
-- 26 Mar: Customer walk-off during busy period – 2 muffins and 2 croissants
(7,  '2025-03-26', 2,    'Theft – customer walk-off suspected', 1.80, 'NO',  2),
(6,  '2025-03-26', 2,    'Theft – customer walk-off suspected', 2.20, 'NO',  2),

-- 27 Mar: End-of-day pastry spoilage
(6,  '2025-03-27', 5,    'Spoiled – end of day unsold',        5.50,  NULL,  4),
(7,  '2025-03-27', 3,    'Spoiled – end of day unsold',        2.70,  NULL,  4),

-- 28 Mar: End-of-week over-ordering
(6,  '2025-03-28', 5,    'Over-ordered – unsold batch',        5.50,  NULL,  1),
(7,  '2025-03-28', 4,    'Over-ordered – unsold batch',        3.60,  NULL,  1),
-- 28 Mar: Full caramel syrup bottle unaccounted at month-end stock check – formally reported
(5,  '2025-03-28', 1.00, 'Theft – month-end stock discrepancy', 4.00, 'YES', 1);


-- ── Stock_Usage: Waste + Theft rows (automatic) ──────────────
-- Instead of manually duplicating every loss event, this single
-- INSERT...SELECT reads directly from Waste_Log and populates
-- Stock_Usage automatically.
--
-- Logic:
--   • Every row in Waste_Log represents a physical stock reduction
--   • Theft rows  → usage_reason = 'Theft'
--   • All others  → usage_reason = 'Waste'
--   • quantity_wasted maps directly to quantity_used
--   • waste_date  maps directly to usage_date
--
-- This means if you ever add, edit or delete a Waste_Log row,
-- simply re-run this statement and Stock_Usage stays in sync.
-- The CASE on reason ensures the correct label is carried through.

INSERT INTO Stock_Usage (item_id, usage_date, quantity_used, usage_reason)
SELECT
    item_id,
    waste_date,
    quantity_wasted,
    CASE
        WHEN reason LIKE 'Theft%' THEN 'Theft'
        ELSE                           'Waste'
    END AS usage_reason
FROM Waste_Log;

-- ── Update current_stock to reflect end-of-month balances ──
-- Formula: Closing Stock = Opening Stock + Total Purchased - Total Used
--
-- Instead of hardcoding each number manually, this single UPDATE
-- joins Inventory_Items to two subqueries:
--   • total_in  -> sums every delivery received from Stock_Purchase
--   • total_out -> sums every usage record from Stock_Usage
-- current_stock was set to the OPENING stock value during INSERT,
-- so the formula just adds what came in and subtracts what went out.
--
-- Run this once after all Stock_Purchase and Stock_Usage rows are inserted.
-- If you add more data later, simply run it again – it always recalculates
-- from scratch. COALESCE(..., 0) safely handles items with no movements.

UPDATE Inventory_Items ii

-- Subquery 1: total stock received per item (all deliveries)
JOIN (
    SELECT item_id,
           SUM(quantity) AS total_in
    FROM Stock_Purchase
    GROUP BY item_id
) purchased ON purchased.item_id = ii.item_id

-- Subquery 2: total stock consumed per item (sales + waste)
LEFT JOIN (
    SELECT item_id,
           SUM(quantity_used) AS total_out
    FROM Stock_Usage
    GROUP BY item_id
) used ON used.item_id = ii.item_id

-- Apply the formula:  closing = opening + purchased - used
SET ii.current_stock = ii.current_stock
                     + COALESCE(purchased.total_in,  0)
                     - COALESCE(used.total_out,       0);

-- ── Monthly Summary March 2025 ─────────────────────────────
-- Instead of hardcoding the four figures, INSERT...SELECT pulls
-- each value live from the actual tables for the given month.
-- Change '2025-03-01' to any month start date to generate a
-- different month's summary using exactly the same statement.
--
-- Where each figure comes from:
--   total_revenue    -> SUM of all sale revenue from Sales
--   total_purchases  -> SUM of all delivery costs from Stock_Purchase
--   total_waste_cost -> SUM of all waste costs from Waste_Log
--   total_wage_cost  -> SUM of (hourly_rate x hours_per_week x 4.33) from Staff
--   net_profit       -> auto-calculated by MySQL (GENERATED column, not inserted)

INSERT INTO Monthly_Summary
    (report_month, total_revenue, total_purchases, total_waste_cost, total_wage_cost)

SELECT
    -- The month this summary covers (first day of the month)
    '2025-03-01' AS report_month,

    -- Total revenue: every sale made during March
    (SELECT ROUND(SUM(total_revenue), 2)
     FROM Sales
     WHERE MONTH(sale_date) = 3 AND YEAR(sale_date) = 2025)
    AS total_revenue,

    -- Total purchases: every supplier delivery received during March
    (SELECT ROUND(SUM(total_cost), 2)
     FROM Stock_Purchase
     WHERE MONTH(purchase_date) = 3 AND YEAR(purchase_date) = 2025)
    AS total_purchases,

    -- Total waste cost: everything thrown away during March
    (SELECT ROUND(SUM(estimated_cost), 2)
     FROM Waste_Log
     WHERE MONTH(waste_date) = 3 AND YEAR(waste_date) = 2025)
    AS total_waste_cost,

    -- Total wage cost: 4.33 = average weeks per month (52 ÷ 12)
    (SELECT ROUND(SUM(hourly_rate * hours_per_week * 4.33), 2)
     FROM Staff)
    AS total_wage_cost;


-- ============================================================
-- STEP 4: CRUD QUERIES
-- ============================================================

-- ── CREATE (C) – Add a new stock delivery ──────────────────
-- Scenario: New delivery of Oat Milk on 29 March 2025
INSERT INTO Stock_Purchase (item_id, supplier_id, quantity, unit_cost, purchase_date, expiry_date, delivery_status)
VALUES (2, 1, 40.00, 1.20, '2025-03-29', '2025-04-04', 'On Time');

-- Update current stock accordingly
UPDATE Inventory_Items
SET current_stock = current_stock + 40.00
WHERE item_id = 2;

-- ── READ (R) – View current stock levels with reorder alerts ─
-- Shows every item, how much is left, and whether it needs reordering.
SELECT
    ii.item_id,
    ii.item_name,
    ii.category,
    ii.unit,
    ii.current_stock,
    ii.reorder_level,
    CASE WHEN ii.current_stock <= ii.reorder_level
         THEN '⚠ REORDER NOW'
         ELSE 'OK'
    END AS stock_status,
    s.supplier_name
FROM Inventory_Items ii
LEFT JOIN Suppliers s ON ii.supplier_id = s.supplier_id
ORDER BY stock_status DESC, ii.category;

-- ── READ (R) – Daily sales summary ─────────────────────────
SELECT
    sale_date,
    COUNT(*)              AS transactions,
    SUM(quantity_sold)    AS units_sold,
    SUM(total_revenue)    AS daily_revenue
FROM Sales
GROUP BY sale_date
ORDER BY sale_date;

-- ── READ (R) – Stock reconciliation (the key tally table) ──
-- Opening Stock + Purchases - Usage (Sales+Waste) = Closing Stock
SELECT
    ii.item_name,
    ii.category,
    ii.unit,
    28.00                                          AS opening_stock_mar,   -- hard-coded opening for demo
    COALESCE(SUM(DISTINCT sp.qty_total),0)         AS total_purchased,
    COALESCE(SUM(DISTINCT su.used_total),0)        AS total_used,
    ii.current_stock                               AS closing_stock
FROM Inventory_Items ii
LEFT JOIN (
    SELECT item_id, SUM(quantity) AS qty_total
    FROM Stock_Purchase
    WHERE MONTH(purchase_date)=3 AND YEAR(purchase_date)=2025
    GROUP BY item_id
) sp ON sp.item_id = ii.item_id
LEFT JOIN (
    SELECT item_id, SUM(quantity_used) AS used_total
    FROM Stock_Usage
    WHERE MONTH(usage_date)=3 AND YEAR(usage_date)=2025
    GROUP BY item_id
) su ON su.item_id = ii.item_id
WHERE ii.item_id IN (1,2,3,6,7)   -- physical stock items
GROUP BY ii.item_id;

-- ── UPDATE (U) – Adjust stock after new delivery is logged ──
-- Scenario: 5 Croissants discovered damaged on arrival – reduce stock
UPDATE Inventory_Items
SET current_stock = current_stock - 5
WHERE item_id = 6;

-- Update the delivery record too
UPDATE Stock_Purchase
SET delivery_status = 'Damaged'
WHERE item_id = 6
  AND purchase_date = '2025-03-28';

-- ── DELETE (D) – Remove an incorrect waste log entry ────────
-- Scenario: Wrong entry – muffin waste on 28 March was logged twice by mistake
DELETE FROM Waste_Log
WHERE item_id = 7
  AND waste_date = '2025-03-28'
  AND reason = 'Over-ordered – unsold batch'
LIMIT 1;

-- ── UPDATE (U) – Give staff a pay raise ────────────────────



-- ============================================================
-- STEP 5: DATA INSIGHT QUERIES (Decision-Making)
-- ============================================================

-- ── INSIGHT 1: Monthly Profit & Loss Summary ───────────────
-- The headline report the owner sees at month end.
SELECT
    DATE_FORMAT(report_month, '%M %Y')  AS month,
    CONCAT('£', FORMAT(total_revenue,2))    AS revenue,
    CONCAT('£', FORMAT(total_purchases,2))  AS ingredient_cost,
    CONCAT('£', FORMAT(total_wage_cost,2))  AS wage_cost,
    CONCAT('£', FORMAT(total_waste_cost,2)) AS waste_cost,
    CONCAT('£', FORMAT(net_profit,2))       AS net_profit
FROM Monthly_Summary
ORDER BY report_month;

-- ── INSIGHT 2: Waste & Theft Breakdown by Item ────────────
-- Splits losses into Spoilage vs Theft so the owner can see
-- each problem separately and act on them differently.
SELECT
    ii.item_name,
    ii.category,
    ii.unit,
    -- Spoilage: everything that is NOT a theft row
    SUM(CASE WHEN wl.reason NOT LIKE 'Theft%'
             THEN wl.quantity_wasted ELSE 0 END)  AS spoilage_qty,
    CONCAT('£', FORMAT(
        SUM(CASE WHEN wl.reason NOT LIKE 'Theft%'
                 THEN wl.estimated_cost ELSE 0 END), 2))
                                                   AS spoilage_cost,
    -- Theft: only rows where reason starts with 'Theft'
    SUM(CASE WHEN wl.reason LIKE 'Theft%'
             THEN wl.quantity_wasted ELSE 0 END)  AS theft_qty,
    CONCAT('£', FORMAT(
        SUM(CASE WHEN wl.reason LIKE 'Theft%'
                 THEN wl.estimated_cost ELSE 0 END), 2))
                                                   AS theft_cost,
    -- Total combined loss per item
    CONCAT('£', FORMAT(SUM(wl.estimated_cost), 2)) AS total_loss
FROM Waste_Log wl
JOIN Inventory_Items ii ON wl.item_id = ii.item_id
WHERE MONTH(wl.waste_date) = 3 AND YEAR(wl.waste_date) = 2025
GROUP BY ii.item_id
ORDER BY SUM(wl.estimated_cost) DESC;

-- ── INSIGHT 2b: Theft-Only Report (formally reported vs suspected) ──
-- Helps the manager distinguish confirmed theft from suspected shrinkage.
SELECT
    ii.item_name,
    wl.waste_date,
    wl.quantity_wasted,
    ii.unit,
    CONCAT('£', FORMAT(wl.estimated_cost, 2)) AS loss_value,
    wl.theft_reported,
    st.full_name AS logged_by
FROM Waste_Log wl
JOIN Inventory_Items ii ON wl.item_id = ii.item_id
JOIN Staff st            ON wl.logged_by = st.staff_id
WHERE wl.reason LIKE 'Theft%'
  AND MONTH(wl.waste_date) = 3
ORDER BY wl.waste_date;

-- ── INSIGHT 3: Daily Revenue Trend (peak day detection) ────
SELECT
    sale_date,
    DAYNAME(sale_date)          AS day_name,
    SUM(total_revenue)          AS daily_revenue,
    RANK() OVER (ORDER BY SUM(total_revenue) DESC) AS revenue_rank
FROM Sales
WHERE MONTH(sale_date) = 3
GROUP BY sale_date
ORDER BY sale_date;

-- ── INSIGHT 4: Best-Selling Products ───────────────────────
SELECT
    ii.item_name,
    SUM(s.quantity_sold)       AS total_units_sold,
    CONCAT('£', FORMAT(SUM(s.total_revenue),2)) AS total_revenue
FROM Sales s
JOIN Inventory_Items ii ON s.item_id = ii.item_id
WHERE MONTH(s.sale_date) = 3
GROUP BY ii.item_id
ORDER BY SUM(s.total_revenue) DESC;

-- ── INSIGHT 5: Supplier Reliability Report ─────────────────
SELECT
    su.supplier_name,
    COUNT(sp.purchase_id)                       AS total_deliveries,
    SUM(CASE WHEN sp.delivery_status = 'On Time' THEN 1 ELSE 0 END) AS on_time,
    SUM(CASE WHEN sp.delivery_status = 'Late'    THEN 1 ELSE 0 END) AS late,
    SUM(CASE WHEN sp.delivery_status = 'Damaged' THEN 1 ELSE 0 END) AS damaged,
    CONCAT('£', FORMAT(SUM(sp.total_cost),2))   AS total_spend
FROM Stock_Purchase sp
JOIN Suppliers su ON sp.supplier_id = su.supplier_id
WHERE MONTH(sp.purchase_date) = 3
GROUP BY su.supplier_id
ORDER BY total_spend DESC;

-- ── INSIGHT 6: Stock Forecast – Days of Stock Remaining ────
-- Uses average daily usage to predict when each item will run out.
SELECT
    ii.item_name,
    ii.current_stock,
    ii.unit,
    ROUND(avg_usage.avg_daily, 2)  AS avg_daily_usage,
    ROUND(ii.current_stock / NULLIF(avg_usage.avg_daily,0), 0) AS days_remaining,
    CASE
        WHEN ii.current_stock / NULLIF(avg_usage.avg_daily,0) <= 3  THEN '🔴 ORDER IMMEDIATELY'
        WHEN ii.current_stock / NULLIF(avg_usage.avg_daily,0) <= 7  THEN '🟡 ORDER THIS WEEK'
        ELSE '🟢 SUFFICIENT'
    END AS forecast_status
FROM Inventory_Items ii
JOIN (
    SELECT item_id,
           SUM(quantity_used) / COUNT(DISTINCT usage_date) AS avg_daily
    FROM Stock_Usage
    WHERE MONTH(usage_date) = 3
    GROUP BY item_id
) avg_usage ON avg_usage.item_id = ii.item_id
WHERE ii.item_id IN (1,2,3,6,7)
ORDER BY days_remaining ASC;

-- ── INSIGHT 7: Wage Cost Breakdown per Staff Member ────────
SELECT
    full_name,
    role,
    hourly_rate,
    hours_per_week,
    ROUND(hourly_rate * hours_per_week * 4.33, 2) AS monthly_wage_cost
FROM Staff
ORDER BY monthly_wage_cost DESC;

-- ── INSIGHT 8: Waste % of Revenue (management KPI) ─────────
SELECT
    CONCAT('£', FORMAT(ms.total_revenue,2))    AS monthly_revenue,
    CONCAT('£', FORMAT(ms.total_waste_cost,2)) AS monthly_waste_cost,
    CONCAT(ROUND(ms.total_waste_cost / ms.total_revenue * 100, 2), '%') AS waste_pct_of_revenue
FROM Monthly_Summary ms
WHERE report_month = '2025-03-01';



-- ── INSIGHT 10: Waste log summary with staff accountability──
SELECT
    st.full_name          AS logged_by_staff,
    COUNT(wl.waste_id)    AS waste_events,
    SUM(wl.quantity_wasted) AS total_qty_wasted,
    CONCAT('£', FORMAT(SUM(wl.estimated_cost),2)) AS total_waste_value
FROM Waste_Log wl
JOIN Staff st ON wl.logged_by = st.staff_id
WHERE MONTH(wl.waste_date) = 3
GROUP BY st.staff_id
ORDER BY SUM(wl.estimated_cost) DESC;



