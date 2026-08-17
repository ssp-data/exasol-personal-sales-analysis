-- Raw landing zone. Loaded verbatim from data/E-Commerce Sales Analytics.csv.
--
-- Explicit types are a contract with the file: if the CSV drifts, the load
-- fails loudly instead of silently changing what a column means. order_date
-- stays VARCHAR on purpose — parsing is an interpretation, and interpretations
-- belong in staging where they are visible.

CREATE SCHEMA IF NOT EXISTS RAW_SALES;

CREATE OR REPLACE TABLE RAW_SALES.SALES_ORDERS (
    ORDER_ID          DECIMAL(18,0),
    ORDER_DATE        VARCHAR(10),
    CUSTOMER_ID       DECIMAL(18,0),
    PRODUCT_CATEGORY  VARCHAR(50),
    REGION            VARCHAR(50),
    QUANTITY          DECIMAL(9,0),
    UNIT_PRICE        DECIMAL(12,2),
    DISCOUNT          DECIMAL(6,4),
    PAYMENT_METHOD    VARCHAR(50),
    DELIVERY_DAYS     DECIMAL(5,0),
    CUSTOMER_RATING   DECIMAL(3,1),
    REVENUE           DECIMAL(18,2)
);

COMMENT ON TABLE RAW_SALES.SALES_ORDERS IS
    'E-Commerce Sales Analytics, 5000 orders (Kaggle, srisyra02). One row per order.';

COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.ORDER_ID         IS 'Order identifier, one row per order';
COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.ORDER_DATE       IS 'Order date as written in the file (M/D/YYYY)';
COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.CUSTOMER_ID      IS 'Customer identifier';
COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.PRODUCT_CATEGORY IS 'Beauty, Clothing, Electronics, Home';
COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.REGION           IS 'East, North, South, West';
COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.QUANTITY         IS 'Units ordered';
COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.UNIT_PRICE       IS 'List price per unit';
COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.DISCOUNT         IS 'Discount as a fraction, 0.28 = 28%';
COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.PAYMENT_METHOD   IS 'Card, COD, Wallet';
COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.DELIVERY_DAYS    IS 'Days from order to delivery';
COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.CUSTOMER_RATING  IS 'Customer rating, 1.0 - 5.0';
COMMENT ON COLUMN RAW_SALES.SALES_ORDERS.REVENUE          IS 'Net revenue as supplied by the source';
