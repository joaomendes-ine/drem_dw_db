--
-- Azure PostgreSQL Optimization Script for DREM Data Warehouse
-- Versão: 1.0
-- Autor: João Mendes
-- Data: 2024-10-28
--

-- 1. Database Level Configurations
ALTER DATABASE drem_dw SET timezone TO 'UTC';
ALTER DATABASE drem_dw SET statement_timeout TO '3600000';  -- 1 hour
ALTER DATABASE drem_dw SET idle_in_transaction_session_timeout TO '3600000';
ALTER DATABASE drem_dw SET work_mem TO '64MB';
ALTER DATABASE drem_dw SET maintenance_work_mem TO '256MB';
ALTER DATABASE drem_dw SET random_page_cost TO 1.1;
ALTER DATABASE drem_dw SET effective_cache_size TO '4GB';
ALTER DATABASE drem_dw SET default_statistics_target TO 1000;

-- 2. Performance Monitoring Table
CREATE TABLE azure_performance_metrics (
    metric_id SERIAL PRIMARY KEY,
    metric_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metric_type TEXT,
    metric_value NUMERIC,
    metric_details JSONB
);

-- 3. Resource Management Functions
CREATE OR REPLACE FUNCTION monitor_azure_resources()
RETURNS void AS $$
BEGIN
    -- Monitor connection count
    INSERT INTO azure_performance_metrics (metric_type, metric_value, metric_details)
    SELECT 
        'connections',
        count(*),
        jsonb_build_object(
            'active_connections', count(*),
            'max_connections', current_setting('max_connections')::int
        )
    FROM pg_stat_activity;

    -- Monitor table sizes
    INSERT INTO azure_performance_metrics (metric_type, metric_value, metric_details)
    SELECT 
        'table_size',
        pg_total_relation_size(schemaname || '.' || tablename) / 1024.0 / 1024.0,
        jsonb_build_object(
            'table_name', schemaname || '.' || tablename,
            'size_mb', pg_total_relation_size(schemaname || '.' || tablename) / 1024.0 / 1024.0,
            'last_vacuum', last_vacuum,
            'last_analyze', last_analyze
        )
    FROM pg_stat_user_tables;

    -- Monitor cache hit ratio
    INSERT INTO azure_performance_metrics (metric_type, metric_value, metric_details)
    SELECT 
        'cache_hit_ratio',
        sum(heap_blks_hit) / nullif(sum(heap_blks_hit + heap_blks_read), 0) * 100,
        jsonb_build_object(
            'heap_hits', sum(heap_blks_hit),
            'heap_reads', sum(heap_blks_read)
        )
    FROM pg_statio_user_tables;
END;
$$ LANGUAGE plpgsql;

-- 4. Table Optimizations
ALTER TABLE dados_indicadores SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05,
    autovacuum_vacuum_threshold = 1000,
    autovacuum_analyze_threshold = 1000,
    parallel_workers = 4
);

-- 5. Azure Backup Management
CREATE TABLE azure_backup_control (
    backup_id SERIAL PRIMARY KEY,
    backup_start TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    backup_end TIMESTAMP WITH TIME ZONE,
    backup_type TEXT,
    status TEXT,
    details JSONB
);

-- 6. Connection Pooling Management
CREATE OR REPLACE FUNCTION manage_azure_connections()
RETURNS trigger AS $$
BEGIN
    -- Check current connection count
    IF (SELECT count(*) FROM pg_stat_activity) > current_setting('max_connections')::int * 0.9 THEN
        -- Log warning
        INSERT INTO azure_performance_metrics (
            metric_type,
            metric_value,
            metric_details
        ) VALUES (
            'connection_warning',
            (SELECT count(*) FROM pg_stat_activity),
            jsonb_build_object(
                'warning', 'Near connection limit',
                'current_connections', (SELECT count(*) FROM pg_stat_activity),
                'max_connections', current_setting('max_connections')::int
            )
        );
        
        -- Terminate idle connections
        WITH idle_transactions AS (
            SELECT pid 
            FROM pg_stat_activity 
            WHERE state = 'idle in transaction'
            AND state_change < current_timestamp - interval '30 minutes'
        )
        SELECT pg_terminate_backend(pid) FROM idle_transactions;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 7. Index Optimization
CREATE OR REPLACE FUNCTION optimize_azure_indexes()
RETURNS void AS $$
DECLARE
    v_index_name text;
    v_table_name text;
BEGIN
    -- Find unused indexes
    FOR v_index_name, v_table_name IN
        SELECT 
            schemaname || '.' || indexrelname as index_name,
            schemaname || '.' || tablename as table_name
        FROM pg_stat_user_indexes
        WHERE idx_scan = 0
        AND indexrelname NOT LIKE '%_pkey'
        AND indexrelname NOT LIKE '%_unique'
    LOOP
        -- Log unused index
        INSERT INTO azure_performance_metrics (
            metric_type,
            metric_details
        ) VALUES (
            'unused_index',
            jsonb_build_object(
                'index_name', v_index_name,
                'table_name', v_table_name,
                'action', 'consider dropping'
            )
        );
    END LOOP;

    -- Reindex frequently used indexes
    FOR v_index_name IN
        SELECT schemaname || '.' || indexrelname
        FROM pg_stat_user_indexes
        WHERE idx_scan > 10000
    LOOP
        EXECUTE 'REINDEX INDEX CONCURRENTLY ' || v_index_name;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 8. Materialized View Optimization
ALTER MATERIALIZED VIEW mv_indicadores_resumo SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);

-- 9. Query Performance Monitoring
CREATE OR REPLACE FUNCTION analyze_query_performance()
RETURNS TABLE (
    query_id BIGINT,
    total_exec_time DOUBLE PRECISION,
    mean_exec_time DOUBLE PRECISION,
    rows_processed BIGINT,
    cache_hit_ratio DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        queryid,
        total_exec_time,
        mean_exec_time,
        rows,
        shared_blks_hit::float / nullif(shared_blks_hit + shared_blks_read, 0) as cache_ratio
    FROM pg_stat_statements
    WHERE total_exec_time > 1000  -- queries taking more than 1 second
    ORDER BY total_exec_time DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- 10. Schedule Maintenance Tasks
CREATE OR REPLACE FUNCTION schedule_azure_maintenance()
RETURNS void AS $$
BEGIN
    -- Update statistics
    ANALYZE VERBOSE;
    
    -- Clean up old monitoring data
    DELETE FROM azure_performance_metrics 
    WHERE metric_time < current_timestamp - interval '30 days';
    
    -- Refresh materialized views during low-usage period
    IF extract(hour from current_timestamp) BETWEEN 1 AND 5 THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_indicadores_resumo;
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_estatisticas_indicadores;
    END IF;
    
    -- Optimize tables
    VACUUM (ANALYZE, VERBOSE);
END;
$$ LANGUAGE plpgsql;

-- Create maintenance schedule
COMMENT ON FUNCTION schedule_azure_maintenance() IS 
'Execute during maintenance window (1 AM - 5 AM) via Azure Automation';