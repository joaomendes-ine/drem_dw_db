# Configuração e Otimização do Data Warehouse DREM

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-blue)](https://www.postgresql.org/)
[![Azure](https://img.shields.io/badge/Azure-PostgreSQL-0078D4)](https://azure.microsoft.com/)

## Índice

1. [Configurações Base](#1-configurações-base)
2. [Otimizações Azure](#2-otimizações-azure)
3. [Gestão de Partições](#3-gestão-de-partições)
4. [Índices e Performance](#4-índices-e-performance)
5. [Monitorização](#5-monitorização)
6. [Manutenção](#6-manutenção)
7. [Resolução de Problemas](#7-resolução-de-problemas)

## 1. Configurações Base

### 1.1 Requisitos do Sistema

```plaintext
- PostgreSQL 14 ou superior
- Azure Database for PostgreSQL - Flexible Server recomendado
- Mínimo 4 vCores
- Mínimo 16GB RAM
- Armazenamento: SSD Premium (recomendado)
```

### 1.2 Configurações Iniciais da Base de Dados

```sql
-- Configurações essenciais
ALTER DATABASE drem_dw SET timezone TO 'UTC';
ALTER DATABASE drem_dw SET client_encoding TO 'UTF8';
ALTER DATABASE drem_dw SET default_tablespace TO '';
ALTER DATABASE drem_dw SET default_with_oids TO false;

-- Otimizações de performance
ALTER DATABASE drem_dw SET statement_timeout TO '3600000';           -- 1 hora
ALTER DATABASE drem_dw SET lock_timeout TO '1800000';               -- 30 minutos
ALTER DATABASE drem_dw SET idle_in_transaction_session_timeout TO '3600000';
ALTER DATABASE drem_dw SET work_mem TO '64MB';
ALTER DATABASE drem_dw SET maintenance_work_mem TO '256MB';
ALTER DATABASE drem_dw SET effective_io_concurrency TO 200;         -- Para SSDs
ALTER DATABASE drem_dw SET random_page_cost TO 1.1;                 -- Otimizado para SSD
ALTER DATABASE drem_dw SET effective_cache_size TO '4GB';
ALTER DATABASE drem_dw SET default_statistics_target TO 1000;

-- Configurações de paralelismo
ALTER DATABASE drem_dw SET max_parallel_workers_per_gather TO 4;
ALTER DATABASE drem_dw SET max_parallel_workers TO 8;
ALTER DATABASE drem_dw SET max_parallel_maintenance_workers TO 4;
```

### 1.3 Extensões Necessárias

```sql
-- Extensões fundamentais
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";           -- Suporte a UUIDs
CREATE EXTENSION IF NOT EXISTS "ltree";              -- Hierarquias
CREATE EXTENSION IF NOT EXISTS "pgcrypto";           -- Funções criptográficas
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";  -- Monitorização de queries
CREATE EXTENSION IF NOT EXISTS "pg_trgm";            -- Pesquisa textual
CREATE EXTENSION IF NOT EXISTS "tablefunc";          -- Funções de tabela
CREATE EXTENSION IF NOT EXISTS "intarray";           -- Operações com arrays

-- Verificar instalação
SELECT extname, extversion 
FROM pg_extension;
```

## 2. Otimizações Azure

### 2.1 Configurações de Performance Azure

```sql
-- Tabela de métricas de performance
CREATE TABLE azure_performance_metrics (
    metric_id BIGSERIAL PRIMARY KEY,
    metric_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metric_type TEXT NOT NULL,
    metric_value NUMERIC,
    metric_details JSONB,
    server_name TEXT,
    database_name TEXT,
    resource_group TEXT
);

-- Índices para métricas
CREATE INDEX idx_metrics_time ON azure_performance_metrics(metric_time DESC);
CREATE INDEX idx_metrics_type ON azure_performance_metrics(metric_type);
```

### 2.2 Monitorização de Recursos Azure

```sql
-- Função de monitorização de recursos
CREATE OR REPLACE FUNCTION monitor_azure_resources()
RETURNS void AS $$
DECLARE
    v_server_name TEXT;
    v_database_name TEXT;
    v_resource_group TEXT;
BEGIN
    -- Obter informações do servidor
    SELECT current_database() INTO v_database_name;
    
    -- Monitorizar conexões
    INSERT INTO azure_performance_metrics (
        metric_type, 
        metric_value, 
        metric_details,
        server_name,
        database_name
    )
    SELECT 
        'connections',
        count(*),
        jsonb_build_object(
            'active_connections', count(*),
            'max_connections', current_setting('max_connections')::int,
            'idle_connections', sum(CASE WHEN state = 'idle' THEN 1 ELSE 0 END)
        ),
        v_server_name,
        v_database_name
    FROM pg_stat_activity;

    -- Monitorizar espaço em disco
    INSERT INTO azure_performance_metrics (
        metric_type,
        metric_value,
        metric_details,
        server_name,
        database_name
    )
    SELECT 
        'database_size',
        pg_database_size(current_database()) / 1024.0 / 1024.0,  -- Size in MB
        jsonb_build_object(
            'database', current_database(),
            'size_mb', pg_database_size(current_database()) / 1024.0 / 1024.0,
            'tables_count', (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public')
        ),
        v_server_name,
        v_database_name;

EXCEPTION WHEN OTHERS THEN
    -- Log error
    INSERT INTO dw_operation_log (
        operation_type,
        status,
        error_message
    ) VALUES (
        'AZURE_MONITORING',
        'ERROR',
        SQLERRM
    );
END;
$$ LANGUAGE plpgsql;
```

### 2.3 Gestão de Conexões Azure

```sql
-- Função para gestão de conexões
CREATE OR REPLACE FUNCTION manage_azure_connections()
RETURNS trigger AS $$
BEGIN
    -- Verificar limite de conexões
    IF (SELECT count(*) FROM pg_stat_activity) > current_setting('max_connections')::int * 0.9 THEN
        -- Log warning
        INSERT INTO dw_operation_log (
            operation_type,
            status,
            operation_details
        ) VALUES (
            'CONNECTION_WARNING',
            'WARNING',
            jsonb_build_object(
                'current_connections', (SELECT count(*) FROM pg_stat_activity),
                'max_connections', current_setting('max_connections')::int
            )
        );
        
        -- Terminar conexões inativas antigas
        WITH idle_transactions AS (
            SELECT pid 
            FROM pg_stat_activity 
            WHERE state = 'idle in transaction'
            AND state_change < current_timestamp - interval '30 minutes'
        )
        SELECT pg_terminate_backend(pid) 
        FROM idle_transactions;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger para monitorização de conexões
CREATE TRIGGER trg_connection_monitor
    AFTER INSERT ON azure_performance_metrics
    FOR EACH ROW
    WHEN (NEW.metric_type = 'connections')
    EXECUTE FUNCTION manage_azure_connections();
```

## 3. Gestão de Partições

### 3.1 Configuração de Particionamento

```sql
-- Função para criar partições automaticamente
CREATE OR REPLACE FUNCTION criar_particao_dados_indicadores(
    p_ano INTEGER,
    p_criar_indices BOOLEAN DEFAULT true
)
RETURNS void AS $$
DECLARE
    v_partition_name TEXT;
    v_start_date DATE;
    v_end_date DATE;
BEGIN
    -- Validar ano
    IF p_ano < 1900 OR p_ano > 2100 THEN
        RAISE EXCEPTION 'Ano inválido: %', p_ano;
    END IF;

    -- Definir datas e nomes
    v_partition_name := 'dados_indicadores_' || p_ano;
    v_start_date := make_date(p_ano, 1, 1);
    v_end_date := make_date(p_ano + 1, 1, 1);

    -- Criar partição
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = v_partition_name) THEN
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I 
            PARTITION OF dados_indicadores 
            FOR VALUES FROM (%L) TO (%L)',
            v_partition_name, v_start_date, v_end_date
        );

        -- Configurar partição
        EXECUTE format(
            'ALTER TABLE %I SET (
                fillfactor = 90,
                autovacuum_vacuum_scale_factor = 0.1,
                autovacuum_analyze_scale_factor = 0.05,
                parallel_workers = 4
            )', v_partition_name
        );

        -- Criar índices
        IF p_criar_indices THEN
            EXECUTE format(
                'CREATE INDEX CONCURRENTLY IF NOT EXISTS %I ON %I 
                (id_indicador, periodo_referencia)',
                'idx_' || v_partition_name || '_indicador_periodo',
                v_partition_name
            );

            EXECUTE format(
                'CREATE INDEX CONCURRENTLY IF NOT EXISTS %I ON %I 
                (valor_numerico) WHERE valor_numerico IS NOT NULL',
                'idx_' || v_partition_name || '_valor',
                v_partition_name
            );
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

### 3.2 Manutenção de Partições

```sql
-- Função para manutenção de partições
CREATE OR REPLACE FUNCTION manter_particoes(
    p_manter_anos INTEGER DEFAULT 5,
    p_criar_futuro INTEGER DEFAULT 2
)
RETURNS void AS $$
DECLARE
    v_ano_atual INTEGER;
    v_ano_minimo INTEGER;
    v_ano_maximo INTEGER;
BEGIN
    v_ano_atual := EXTRACT(YEAR FROM CURRENT_DATE);
    v_ano_minimo := v_ano_atual - p_manter_anos;
    v_ano_maximo := v_ano_atual + p_criar_futuro;
    
    -- Criar partições futuras
    FOR i IN v_ano_atual..v_ano_maximo LOOP
        PERFORM criar_particao_dados_indicadores(i);
    END LOOP;
    
    -- Log maintenance
    INSERT INTO dw_operation_log (
        operation_type,
        operation_details
    ) VALUES (
        'PARTITION_MAINTENANCE',
        jsonb_build_object(
            'ano_atual', v_ano_atual,
            'ano_minimo', v_ano_minimo,
            'ano_maximo', v_ano_maximo
        )
    );
END;
$$ LANGUAGE plpgsql;
```

## 4. Índices e Performance

### 4.1 Otimização de Índices

```sql
-- Função para otimização de índices
CREATE OR REPLACE FUNCTION otimizar_indices()
RETURNS void AS $$
DECLARE
    v_index_name TEXT;
    v_table_name TEXT;
BEGIN
    -- Identificar índices não utilizados
    FOR v_index_name, v_table_name IN
        SELECT 
            schemaname || '.' || indexrelname,
            schemaname || '.' || tablename
        FROM pg_stat_user_indexes
        WHERE 
            idx_scan = 0 
            AND indexrelname NOT LIKE '%_pkey'
            AND indexrelname NOT LIKE '%_unique'
    LOOP
        -- Log índice não utilizado
        INSERT INTO dw_operation_log (
            operation_type,
            operation_details
        ) VALUES (
            'INDEX_UNUSED',
            jsonb_build_object(
                'index_name', v_index_name,
                'table_name', v_table_name
            )
        );
    END LOOP;

    -- Reindexar índices muito utilizados
    FOR v_index_name IN
        SELECT schemaname || '.' || indexrelname
        FROM pg_stat_user_indexes
        WHERE idx_scan > 10000
    LOOP
        EXECUTE 'REINDEX INDEX CONCURRENTLY ' || v_index_name;
        
        -- Log reindexação
        INSERT INTO dw_operation_log (
            operation_type,
            operation_details
        ) VALUES (
            'INDEX_REINDEX',
            jsonb_build_object('index_name', v_index_name)
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```

### 4.2 Análise de Performance

```sql
-- Função para análise de performance
CREATE OR REPLACE FUNCTION analisar_performance(
    p_dias INTEGER DEFAULT 7
)
RETURNS TABLE (
    tipo_operacao TEXT,
    total_execucoes BIGINT,
    tempo_medio_ms NUMERIC,
    tempo_maximo_ms NUMERIC,
    percentagem_cache_hit NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        operation_type,
        count(*),
        avg(EXTRACT(EPOCH FROM duration) * 1000),
        max(EXTRACT(EPOCH FROM duration) * 1000),
        sum(CASE WHEN status = 'CACHE_HIT' THEN 1 ELSE 0 END)::NUMERIC / count(*) * 100
    FROM dw_operation_log
    WHERE operation_time >= current_timestamp - interval '1 day' * p_dias
    GROUP BY operation_type
    ORDER BY count(*) DESC;
END;
$$ LANGUAGE plpgsql;
```

## 5. Monitorização

### 5.1 Sistema de Alertas

```sql
-- Tabela de alertas
CREATE TABLE dw_alerts (
    alert_id BIGSERIAL PRIMARY KEY,
    alert_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    alert_type TEXT NOT NULL,
    alert_level TEXT NOT NULL,
    alert_message TEXT,
    alert_details JSONB,
    resolved BOOLEAN DEFAULT false,
    resolved_time TIMESTAMP WITH TIME ZONE,
    resolution_notes TEXT
);

-- Função para gerar alertas
CREATE OR REPLACE FUNCTION gerar_alerta(
    p_tipo TEXT,
    p_nivel TEXT,
    p_mensagem TEXT,
    p_detalhes JSONB DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    INSERT INTO dw_alerts (
        alert_type,
        alert_level,
        alert_message,
        alert_details
    ) VALUES (
        p_tipo,
        p_nivel,
        p_mensagem,
        p_detalhes
    );
END;
$$ LANGUAGE plpgsql;
```

### 5.2 Monitorização de Performance

```sql
-- View para monitorização de performance
CREATE MATERIALIZED VIEW mv_performance_summary AS
SELECT 
    date_trunc('hour', operation_time) as hora,
    operation_type,
    count(*) as total_operacoes,
    avg(EXTRACT(EPOCH FROM duration)) as tempo_medio_segundos,
    sum(affected_rows) as total_registros_afetados,
    sum(CASE WHEN status = 'ERROR' THEN 1 ELSE
I'll continue from where we left off in the `configuration.md` file.

```sql
-- Continuation of mv_performance_summary view
    sum(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) as total_erros,
    jsonb_object_agg(
        COALESCE(error_message, 'success'),
        count(*)
    ) as distribuicao_erros
FROM dw_operation_log
GROUP BY 
    date_trunc('hour', operation_time),
    operation_type
WITH DATA;

-- Índices para a view materializada
CREATE UNIQUE INDEX idx_mv_performance_summary_pk 
    ON mv_performance_summary (hora, operation_type);
```

### 5.3 Dashboards de Monitorização

```sql
-- View para dashboard de performance
CREATE OR REPLACE VIEW vw_performance_dashboard AS
WITH metricas_hora AS (
    SELECT 
        date_trunc('hour', operation_time) as hora,
        count(*) as total_operacoes,
        sum(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) as total_erros,
        avg(EXTRACT(EPOCH FROM duration)) as tempo_medio_segundos,
        percentile_cont(0.95) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM duration)
        ) as p95_tempo_segundos
    FROM dw_operation_log
    WHERE operation_time >= current_timestamp - interval '24 hours'
    GROUP BY date_trunc('hour', operation_time)
)
SELECT 
    hora,
    total_operacoes,
    total_erros,
    round(tempo_medio_segundos::numeric, 2) as tempo_medio_segundos,
    round(p95_tempo_segundos::numeric, 2) as p95_tempo_segundos,
    round((total_erros::numeric / total_operacoes * 100), 2) as taxa_erro_percentual
FROM metricas_hora
ORDER BY hora DESC;
```

## 6. Manutenção

### 6.1 Rotinas de Manutenção

```sql
-- Função para execução de manutenção diária
CREATE OR REPLACE FUNCTION executar_manutencao_diaria()
RETURNS void AS $$
BEGIN
    -- Atualizar estatísticas
    ANALYZE VERBOSE;
    
    -- Reindexar índices fragmentados
    PERFORM otimizar_indices();
    
    -- Atualizar views materializadas
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_performance_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_hierarquia_completa;
    
    -- Manter partições
    PERFORM manter_particoes();
    
    -- Limpar logs antigos
    DELETE FROM dw_operation_log 
    WHERE operation_time < current_timestamp - interval '90 days';
    
    -- Registar execução
    INSERT INTO dw_operation_log (
        operation_type,
        status,
        operation_details
    ) VALUES (
        'DAILY_MAINTENANCE',
        'COMPLETED',
        jsonb_build_object(
            'executed_at', current_timestamp,
            'executed_by', current_user
        )
    );
END;
$$ LANGUAGE plpgsql;
```

### 6.2 Gestão de Espaço em Disco

```sql
-- Função para monitorizar espaço em disco
CREATE OR REPLACE FUNCTION monitorizar_espaco_disco()
RETURNS TABLE (
    schema_name TEXT,
    table_name TEXT,
    total_size_mb NUMERIC,
    index_size_mb NUMERIC,
    total_rows BIGINT,
    last_vacuum TIMESTAMP,
    last_analyze TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname::TEXT,
        relname::TEXT,
        pg_total_relation_size(schemaname || '.' || relname) / 1024.0 / 1024.0,
        pg_indexes_size(schemaname || '.' || relname) / 1024.0 / 1024.0,
        n_live_tup::BIGINT,
        last_vacuum,
        last_analyze
    FROM pg_stat_user_tables
    ORDER BY pg_total_relation_size(schemaname || '.' || relname) DESC;
END;
$$ LANGUAGE plpgsql;
```

## 7. Resolução de Problemas

### 7.1 Problemas Comuns e Soluções

#### Problema 1: Performance Degradada
```sql
-- Identificar queries lentas
SELECT 
    substring(query, 1, 50) as query_preview,
    round(total_exec_time::numeric / 1000 / 60, 2) as total_minutes,
    calls,
    round(mean_exec_time::numeric / 1000 / 60, 2) as avg_minutes,
    round((100 * total_exec_time / sum(total_exec_time) over ())::numeric, 2) as percent_total
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

#### Problema 2: Bloqueios
```sql
-- Identificar bloqueios
CREATE OR REPLACE VIEW vw_locks_ativos AS
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_query
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.GRANTED;
```

### 7.2 Procedimentos de Recovery

```sql
-- Função para recovery de transações pendentes
CREATE OR REPLACE FUNCTION resolver_transacoes_pendentes(
    p_timeout_segundos INTEGER DEFAULT 3600
)
RETURNS TABLE (
    pid INTEGER,
    usename TEXT,
    query TEXT,
    action_taken TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH pending_transactions AS (
        SELECT 
            pid,
            usename,
            query,
            EXTRACT(EPOCH FROM (now() - query_start)) as duration_seconds
        FROM pg_stat_activity
        WHERE state = 'active'
        AND EXTRACT(EPOCH FROM (now() - query_start)) > p_timeout_segundos
    )
    SELECT 
        pt.pid,
        pt.usename,
        pt.query,
        CASE 
            WHEN pg_terminate_backend(pt.pid) THEN 'terminated'
            ELSE 'failed_to_terminate'
        END as action_taken
    FROM pending_transactions pt;
END;
$$ LANGUAGE plpgsql;
```

### 7.3 Boas Práticas

1. **Manutenção Regular**
   - Executar `executar_manutencao_diaria()` diariamente
   - Monitorizar alertas através da tabela `dw_alerts`
   - Verificar logs de operações em `dw_operation_log`

2. **Monitorização**
   - Consultar regularmente `vw_performance_dashboard`
   - Verificar espaço em disco com `monitorizar_espaco_disco()`
   - Analisar métricas Azure através de `azure_performance_metrics`

3. **Performance**
   - Manter estatísticas atualizadas com `ANALYZE`
   - Verificar índices não utilizados
   - Monitorizar tempos de resposta das queries

4. **Backup e Recovery**
   - Manter backup point-in-time
   - Testar procedimentos de recovery periodicamente
   - Documentar todas as alterações significativas

## Conclusão

Esta documentação fornece as configurações e procedimentos necessários para manter o Data Warehouse DREM otimizado no ambiente Azure PostgreSQL.

---

Para mais informações, consultar a [documentação oficial do PostgreSQL](https://www.postgresql.org/docs/) e a [documentação do Azure Database for PostgreSQL](https://docs.microsoft.com/azure/postgresql/).