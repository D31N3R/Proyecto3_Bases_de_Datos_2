/* =====================================================================
   Proyecto 3 - Bases de Datos II
   Script 02: Ajuste de Dim_Producto y Dim_Cliente para el SCD Tipo 2
   Para el DW que ya creaste con la version anterior del script 01.

   Cambios (en ambas dimensiones):
     - fecha_fin pasa a aceptar NULL (NULL = version vigente), sin valor por defecto.
     - es_actual pasa a ser una columna calculada: 1 si fecha_fin es NULL, 0 si no.
   Se puede ejecutar varias veces sin problema.
   ===================================================================== */

USE BikeStoresDW;
GO

/* ---------------- Dim_Producto ---------------- */
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID(N'dw.Dim_Producto') AND name = N'es_actual' AND is_computed = 0)
BEGIN
    DROP INDEX IX_Dim_Producto_negocio ON dw.Dim_Producto;
    ALTER TABLE dw.Dim_Producto DROP CONSTRAINT DF_Dim_Producto_actual;
    ALTER TABLE dw.Dim_Producto DROP COLUMN es_actual;
    ALTER TABLE dw.Dim_Producto DROP CONSTRAINT DF_Dim_Producto_fin;
    ALTER TABLE dw.Dim_Producto ALTER COLUMN fecha_fin DATE NULL;
    UPDATE dw.Dim_Producto SET fecha_fin = NULL WHERE fecha_fin = '9999-12-31';
    ALTER TABLE dw.Dim_Producto ADD es_actual AS
        (CASE WHEN fecha_fin IS NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END);
    CREATE INDEX IX_Dim_Producto_negocio ON dw.Dim_Producto (producto_id, fecha_fin);
END;
GO

/* ---------------- Dim_Cliente ---------------- */
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID(N'dw.Dim_Cliente') AND name = N'es_actual' AND is_computed = 0)
BEGIN
    DROP INDEX IX_Dim_Cliente_negocio ON dw.Dim_Cliente;
    ALTER TABLE dw.Dim_Cliente DROP CONSTRAINT DF_Dim_Cliente_actual;
    ALTER TABLE dw.Dim_Cliente DROP COLUMN es_actual;
    ALTER TABLE dw.Dim_Cliente DROP CONSTRAINT DF_Dim_Cliente_fin;
    ALTER TABLE dw.Dim_Cliente ALTER COLUMN fecha_fin DATE NULL;
    UPDATE dw.Dim_Cliente SET fecha_fin = NULL WHERE fecha_fin = '9999-12-31';
    ALTER TABLE dw.Dim_Cliente ADD es_actual AS
        (CASE WHEN fecha_fin IS NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END);
    CREATE INDEX IX_Dim_Cliente_negocio ON dw.Dim_Cliente (cliente_id, fecha_fin);
END;
GO

/* ---------------- Verificacion ---------------- */
SELECT OBJECT_NAME(c.object_id) AS tabla, c.name AS columna, c.is_nullable, c.is_computed
FROM sys.columns c
WHERE c.object_id IN (OBJECT_ID(N'dw.Dim_Producto'), OBJECT_ID(N'dw.Dim_Cliente'))
  AND c.name IN (N'fecha_fin', N'es_actual')
ORDER BY tabla, columna;
-- Esperado: fecha_fin con is_nullable = 1 y es_actual con is_computed = 1, en las dos tablas.
GO