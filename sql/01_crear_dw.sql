/* =====================================================================
   Proyecto 3 - Bases de Datos II
   Script 01: Creacion del Data Warehouse BikeStoresDW
   Origen:    BikeStores (SQL Server)
   Se puede ejecutar varias veces: no borra nada si los objetos ya existen.
   Ejecutar conectado a la instancia nueva (localhost) en SSMS, con F5.
   ===================================================================== */

USE master;
GO
IF DB_ID(N'BikeStoresDW') IS NULL
    CREATE DATABASE BikeStoresDW;
GO
USE BikeStoresDW;
GO

/* ---------------------------------------------------------------------
   Esquemas: stg = staging (copia del origen), dw = modelo dimensional
   --------------------------------------------------------------------- */
IF SCHEMA_ID(N'stg') IS NULL EXEC (N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'dw')  IS NULL EXEC (N'CREATE SCHEMA dw');
GO

/* =====================================================================
   STAGING (el ETL las vacia y las vuelve a llenar en cada ejecucion)
   ===================================================================== */
IF OBJECT_ID(N'stg.categories', N'U') IS NULL
CREATE TABLE stg.categories (
    category_id   INT          NOT NULL,
    category_name VARCHAR(255) NULL
);

IF OBJECT_ID(N'stg.brands', N'U') IS NULL
CREATE TABLE stg.brands (
    brand_id   INT          NOT NULL,
    brand_name VARCHAR(255) NULL
);

IF OBJECT_ID(N'stg.products', N'U') IS NULL
CREATE TABLE stg.products (
    product_id   INT           NOT NULL,
    product_name VARCHAR(255)  NULL,
    brand_id     INT           NULL,
    category_id  INT           NULL,
    model_year   SMALLINT      NULL,
    list_price   DECIMAL(10,2) NULL
);

IF OBJECT_ID(N'stg.customers', N'U') IS NULL
CREATE TABLE stg.customers (
    customer_id INT          NOT NULL,
    first_name  VARCHAR(255) NULL,
    last_name   VARCHAR(255) NULL,
    phone       VARCHAR(25)  NULL,
    email       VARCHAR(255) NULL,
    street      VARCHAR(255) NULL,
    city        VARCHAR(50)  NULL,
    state       VARCHAR(25)  NULL,
    zip_code    VARCHAR(5)   NULL
);

IF OBJECT_ID(N'stg.stores', N'U') IS NULL
CREATE TABLE stg.stores (
    store_id   INT          NOT NULL,
    store_name VARCHAR(255) NULL,
    phone      VARCHAR(25)  NULL,
    email      VARCHAR(255) NULL,
    street     VARCHAR(255) NULL,
    city       VARCHAR(255) NULL,
    state      VARCHAR(10)  NULL,
    zip_code   VARCHAR(5)   NULL
);

IF OBJECT_ID(N'stg.staffs', N'U') IS NULL
CREATE TABLE stg.staffs (
    staff_id   INT          NOT NULL,
    first_name VARCHAR(50)  NULL,
    last_name  VARCHAR(50)  NULL,
    email      VARCHAR(255) NULL,
    phone      VARCHAR(25)  NULL,
    active     TINYINT      NULL,
    store_id   INT          NULL,
    manager_id INT          NULL
);

IF OBJECT_ID(N'stg.orders', N'U') IS NULL
CREATE TABLE stg.orders (
    order_id      INT     NOT NULL,
    customer_id   INT     NULL,
    order_status  TINYINT NULL,
    order_date    DATE    NULL,
    required_date DATE    NULL,
    shipped_date  DATE    NULL,
    store_id      INT     NULL,
    staff_id      INT     NULL
);

IF OBJECT_ID(N'stg.order_items', N'U') IS NULL
CREATE TABLE stg.order_items (
    order_id   INT           NOT NULL,
    item_id    INT           NOT NULL,
    product_id INT           NULL,
    quantity   INT           NULL,
    list_price DECIMAL(10,2) NULL,
    discount   DECIMAL(4,2)  NULL
);

IF OBJECT_ID(N'stg.stocks', N'U') IS NULL
CREATE TABLE stg.stocks (
    store_id   INT NOT NULL,
    product_id INT NOT NULL,
    quantity   INT NULL
);
GO

/* =====================================================================
   DIMENSIONES
   ===================================================================== */

/* ---- Dim_Fecha (una fila por dia; clave = AAAAMMDD) ---- */
IF OBJECT_ID(N'dw.Dim_Fecha', N'U') IS NULL
CREATE TABLE dw.Dim_Fecha (
    fecha_key         INT         NOT NULL CONSTRAINT PK_Dim_Fecha PRIMARY KEY,
    fecha             DATE        NULL,
    anio              SMALLINT    NOT NULL,
    trimestre         TINYINT     NOT NULL,
    mes               TINYINT     NOT NULL,
    nombre_mes        VARCHAR(15) NOT NULL,
    dia               TINYINT     NOT NULL,
    dia_semana        TINYINT     NOT NULL,   -- 1 = Lunes ... 7 = Domingo
    nombre_dia        VARCHAR(15) NOT NULL,
    es_fin_de_semana  BIT         NOT NULL
);
GO

/* ---- Dim_Producto (SCD Tipo 2) ---- */
IF OBJECT_ID(N'dw.Dim_Producto', N'U') IS NULL
BEGIN
    CREATE TABLE dw.Dim_Producto (
        producto_key     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Producto PRIMARY KEY,
        producto_id      INT           NOT NULL,   -- clave de negocio
        producto_nombre  VARCHAR(255)  NOT NULL,
        marca_id         INT           NOT NULL,
        marca_nombre     VARCHAR(255)  NOT NULL,
        categoria_id     INT           NOT NULL,
        categoria_nombre VARCHAR(255)  NOT NULL,
        anio_modelo      SMALLINT      NOT NULL,
        precio_lista     DECIMAL(10,2) NOT NULL,
        fecha_inicio     DATE          NOT NULL,
        fecha_fin        DATE          NOT NULL CONSTRAINT DF_Dim_Producto_fin    DEFAULT ('9999-12-31'),
        es_actual        BIT           NOT NULL CONSTRAINT DF_Dim_Producto_actual DEFAULT (1)
    );
    CREATE INDEX IX_Dim_Producto_negocio ON dw.Dim_Producto (producto_id, es_actual);
END;
GO

/* ---- Dim_Cliente (SCD Tipo 2) ---- */
IF OBJECT_ID(N'dw.Dim_Cliente', N'U') IS NULL
BEGIN
    CREATE TABLE dw.Dim_Cliente (
        cliente_key     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Cliente PRIMARY KEY,
        cliente_id      INT          NOT NULL,   -- clave de negocio
        nombre_completo VARCHAR(511) NOT NULL,   -- "nombre apellidos"
        telefono        VARCHAR(25)  NULL,
        email           VARCHAR(255) NULL,
        calle           VARCHAR(255) NULL,
        ciudad          VARCHAR(50)  NULL,
        estado          VARCHAR(25)  NULL,
        codigo_postal   VARCHAR(5)   NULL,
        fecha_inicio    DATE         NOT NULL,
        fecha_fin       DATE         NOT NULL CONSTRAINT DF_Dim_Cliente_fin    DEFAULT ('9999-12-31'),
        es_actual       BIT          NOT NULL CONSTRAINT DF_Dim_Cliente_actual DEFAULT (1)
    );
    CREATE INDEX IX_Dim_Cliente_negocio ON dw.Dim_Cliente (cliente_id, es_actual);
END;
GO

/* ---- Dim_Sucursal (SCD Tipo 1) ---- */
IF OBJECT_ID(N'dw.Dim_Sucursal', N'U') IS NULL
BEGIN
    CREATE TABLE dw.Dim_Sucursal (
        sucursal_key    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Sucursal PRIMARY KEY,
        sucursal_id     INT          NOT NULL,   -- clave de negocio
        nombre          VARCHAR(255) NOT NULL,
        telefono        VARCHAR(25)  NULL,
        email           VARCHAR(255) NULL,
        calle           VARCHAR(255) NULL,
        ciudad          VARCHAR(255) NULL,
        estado          VARCHAR(10)  NULL,
        codigo_postal   VARCHAR(5)   NULL
    );
    CREATE UNIQUE INDEX UX_Dim_Sucursal_negocio ON dw.Dim_Sucursal (sucursal_id);
END;
GO

/* ---- Dim_Empleado (SCD Tipo 1) ---- */
IF OBJECT_ID(N'dw.Dim_Empleado', N'U') IS NULL
BEGIN
    CREATE TABLE dw.Dim_Empleado (
        empleado_key    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Empleado PRIMARY KEY,
        empleado_id     INT          NOT NULL,   -- clave de negocio
        nombre_completo VARCHAR(101) NOT NULL,   -- "nombre apellidos"
        email           VARCHAR(255) NULL,
        telefono        VARCHAR(25)  NULL,
        activo          BIT          NOT NULL,
        sucursal_id     INT          NULL,
        gerente_id      INT          NULL,
        gerente_nombre  VARCHAR(101) NULL
    );
    CREATE UNIQUE INDEX UX_Dim_Empleado_negocio ON dw.Dim_Empleado (empleado_id);
END;
GO

/* ---- Dim_Orden (SCD Tipo 1) ---- */
IF OBJECT_ID(N'dw.Dim_Orden', N'U') IS NULL
BEGIN
    CREATE TABLE dw.Dim_Orden (
        orden_key          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Dim_Orden PRIMARY KEY,
        orden_id           INT         NOT NULL,   -- clave de negocio (numero de factura)
        estado_codigo      TINYINT     NOT NULL,   -- 1,2,3,4
        estado_descripcion VARCHAR(20) NOT NULL    -- Pendiente, En proceso, Rechazada, Completada
    );
    CREATE UNIQUE INDEX UX_Dim_Orden_negocio ON dw.Dim_Orden (orden_id);
END;
GO

/* =====================================================================
   TABLAS DE HECHOS
   ===================================================================== */

/* ---- Fact_Ventas: una fila por linea de orden ---- */
IF OBJECT_ID(N'dw.Fact_Ventas', N'U') IS NULL
CREATE TABLE dw.Fact_Ventas (
    orden_key           INT           NOT NULL,
    item_id             INT           NOT NULL,   -- dimension degenerada
    fecha_orden_key     INT           NOT NULL,
    fecha_requerida_key INT           NOT NULL,
    fecha_envio_key     INT           NOT NULL,   -- -1 = "No enviado"
    producto_key        INT           NOT NULL,
    cliente_key         INT           NOT NULL,
    sucursal_key        INT           NOT NULL,
    empleado_key        INT           NOT NULL,
    cantidad            INT           NOT NULL,
    precio_lista        DECIMAL(10,2) NOT NULL,
    descuento_pct       DECIMAL(4,2)  NOT NULL,
    monto_bruto         DECIMAL(12,2) NOT NULL,   -- cantidad * precio_lista
    monto_descuento     DECIMAL(12,2) NOT NULL,   -- monto_bruto * descuento_pct
    monto_neto          DECIMAL(12,2) NOT NULL,   -- monto_bruto - monto_descuento
    CONSTRAINT PK_Fact_Ventas PRIMARY KEY (orden_key, item_id),
    CONSTRAINT FK_FV_Orden     FOREIGN KEY (orden_key)           REFERENCES dw.Dim_Orden (orden_key),
    CONSTRAINT FK_FV_FechaOrd  FOREIGN KEY (fecha_orden_key)     REFERENCES dw.Dim_Fecha (fecha_key),
    CONSTRAINT FK_FV_FechaReq  FOREIGN KEY (fecha_requerida_key) REFERENCES dw.Dim_Fecha (fecha_key),
    CONSTRAINT FK_FV_FechaEnv  FOREIGN KEY (fecha_envio_key)     REFERENCES dw.Dim_Fecha (fecha_key),
    CONSTRAINT FK_FV_Producto  FOREIGN KEY (producto_key)        REFERENCES dw.Dim_Producto (producto_key),
    CONSTRAINT FK_FV_Cliente   FOREIGN KEY (cliente_key)         REFERENCES dw.Dim_Cliente (cliente_key),
    CONSTRAINT FK_FV_Sucursal  FOREIGN KEY (sucursal_key)        REFERENCES dw.Dim_Sucursal (sucursal_key),
    CONSTRAINT FK_FV_Empleado  FOREIGN KEY (empleado_key)        REFERENCES dw.Dim_Empleado (empleado_key)
);
GO

/* ---- Fact_Inventario: foto del inventario por fecha, producto y sucursal ---- */
IF OBJECT_ID(N'dw.Fact_Inventario', N'U') IS NULL
CREATE TABLE dw.Fact_Inventario (
    fecha_key           INT NOT NULL,
    producto_key        INT NOT NULL,
    sucursal_key        INT NOT NULL,
    cantidad_inventario INT NOT NULL,
    CONSTRAINT PK_Fact_Inventario PRIMARY KEY (fecha_key, producto_key, sucursal_key),
    CONSTRAINT FK_FI_Fecha    FOREIGN KEY (fecha_key)    REFERENCES dw.Dim_Fecha (fecha_key),
    CONSTRAINT FK_FI_Producto FOREIGN KEY (producto_key) REFERENCES dw.Dim_Producto (producto_key),
    CONSTRAINT FK_FI_Sucursal FOREIGN KEY (sucursal_key) REFERENCES dw.Dim_Sucursal (sucursal_key)
);
GO

/* =====================================================================
   CARGA INICIAL DE Dim_Fecha (2015-01-01 a 2030-12-31)
   Incluye la fila -1 "No enviado" para ordenes sin fecha de envio.
   ===================================================================== */
IF NOT EXISTS (SELECT 1 FROM dw.Dim_Fecha WHERE fecha_key = -1)
    INSERT INTO dw.Dim_Fecha
        (fecha_key, fecha, anio, trimestre, mes, nombre_mes, dia, dia_semana, nombre_dia, es_fin_de_semana)
    VALUES
        (-1, NULL, 0, 0, 0, 'No enviado', 0, 0, 'No enviado', 0);
GO

IF NOT EXISTS (SELECT 1 FROM dw.Dim_Fecha WHERE fecha_key > 0)
BEGIN
    ;WITH n AS (
        SELECT TOP (DATEDIFF(DAY, '2015-01-01', '2030-12-31') + 1)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS i
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    ),
    d AS (
        SELECT DATEADD(DAY, i, CAST('2015-01-01' AS DATE)) AS fecha FROM n
    )
    INSERT INTO dw.Dim_Fecha
        (fecha_key, fecha, anio, trimestre, mes, nombre_mes, dia, dia_semana, nombre_dia, es_fin_de_semana)
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), fecha, 112)),
        fecha,
        YEAR(fecha),
        DATEPART(QUARTER, fecha),
        MONTH(fecha),
        CHOOSE(MONTH(fecha), 'Enero','Febrero','Marzo','Abril','Mayo','Junio',
                             'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'),
        DAY(fecha),
        (DATEDIFF(DAY, '19000101', fecha) % 7) + 1,      -- 1900-01-01 fue lunes
        CHOOSE((DATEDIFF(DAY, '19000101', fecha) % 7) + 1,
               'Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo'),
        CASE WHEN (DATEDIFF(DAY, '19000101', fecha) % 7) + 1 >= 6 THEN 1 ELSE 0 END
    FROM d;
END;
GO

/* =====================================================================
   VERIFICACION: debe listar 9 tablas en stg y 8 en dw
   ===================================================================== */
SELECT s.name AS esquema, t.name AS tabla
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name IN ('stg', 'dw')
ORDER BY s.name, t.name;

SELECT COUNT(*) AS filas_dim_fecha FROM dw.Dim_Fecha;   -- esperado: 5845 (5844 dias + fila -1)
GO