```sql
--
-- Script de criação do Data Warehouse DREM - Parte 4: Tabelas de Fatos e Bridge
-- Versão: 1.1
-- Autor: João Mendes
-- Data: 2024-10-28
-- Ambiente: Azure PostgreSQL
--

-- Register schema version
INSERT INTO schema_version (version, description, script_name)
VALUES ('1.1', 'Fact and bridge tables creation', 'drem_parte_4_fatos_bridge.sql');

--
-- Tabela de Fatos: dados_indicadores (Otimizada para Azure)
--
CREATE TABLE dados_indicadores (
    id_dado UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_indicador UUID NOT NULL REFERENCES indicadores(id_indicador),
    valor_numerico NUMERIC CHECK (valor_numerico IS NULL OR valor_numerico >= 0),
    valor_texto TEXT,
    valor_anterior NUMERIC,
    variacao_percentual NUMERIC GENERATED ALWAYS AS (
        CASE 
            WHEN valor_anterior > 0 AND valor_numerico IS NOT NULL 
            THEN ROUND(((valor_numerico - valor_anterior) / valor_anterior * 100)::numeric, 2)
            ELSE NULL 
        END
    ) STORED,
    intervalo_confianca_min NUMERIC,
    intervalo_confianca_max NUMERIC,
    flags TEXT[],
    fonte_especifica VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    periodo_referencia DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_valor_tipo CHECK (
        (valor_numerico IS NOT NULL AND valor_texto IS NULL) OR
        (valor_numerico IS NULL AND valor_texto IS NOT NULL)
    ),
    CONSTRAINT chk_intervalos CHECK (
        intervalo_confianca_min IS NULL OR 
        valor_numerico IS NULL OR
        (intervalo_confianca_min <= valor_numerico AND 
         valor_numerico <= intervalo_confianca_max)
    )
) PARTITION BY RANGE (periodo_referencia);

-- Otimização: Função melhorada para criar partições
CREATE OR REPLACE FUNCTION criar_particao_dados_indicadores(
    p_ano INTEGER,
    p_criar_indices BOOLEAN DEFAULT true
)
RETURNS void AS $$
DECLARE
    v_partition_name TEXT;
    v_start_date DATE;
    v_end_date DATE;
    v_index_name TEXT;
BEGIN
    -- Validar ano
    IF p_ano < 1900 OR p_ano > 2100 THEN
        RAISE EXCEPTION 'Ano inválido: %', p_ano;
    END IF;

    -- Definir datas e nomes
    v_partition_name := 'dados_indicadores_' || p_ano;
    v_start_date := make_date(p_ano, 1, 1);
    v_end_date := make_date(p_ano + 1, 1, 1);
    
    -- Log operation start
    INSERT INTO dw_operation_log (
        operation_type,
        operation_details,
        status
    ) VALUES (
        'CREATE_PARTITION',
        jsonb_build_object(
            'partition_name', v_partition_name,
            'year', p_ano,
            'start_date', v_start_date,
            'end_date', v_end_date
        ),
        'STARTED'
    );

    -- Criar partição
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = v_partition_name) THEN
        -- Criar partição
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I 
            PARTITION OF dados_indicadores 
            FOR VALUES FROM (%L) TO (%L)',
            v_partition_name, v_start_date, v_end_date
        );
        
        -- Configurar parâmetros da partição
        EXECUTE format(
            'ALTER TABLE %I SET (
                fillfactor = 90,
                autovacuum_vacuum_scale_factor = 0.1,
                autovacuum_analyze_scale_factor = 0.05,
                parallel_workers = 4
            )', v_partition_name
        );

        -- Criar índices se solicitado
        IF p_criar_indices THEN
            -- Índice principal
            v_index_name := 'idx_' || v_partition_name || '_indicador_periodo';
            EXECUTE format(
                'CREATE INDEX CONCURRENTLY IF NOT EXISTS %I ON %I 
                (id_indicador, periodo_referencia)
                INCLUDE (valor_numerico, valor_texto)',
                v_index_name, v_partition_name
            );

            -- Índice para valores numéricos
            v_index_name := 'idx_' || v_partition_name || '_valor';
            EXECUTE format(
                'CREATE INDEX CONCURRENTLY IF NOT EXISTS %I ON %I (valor_numerico) 
                WHERE valor_numerico IS NOT NULL',
                v_index_name, v_partition_name
            );

            -- Índice para busca por período
            v_index_name := 'idx_' || v_partition_name || '_periodo';
            EXECUTE format(
                'CREATE INDEX CONCURRENTLY IF NOT EXISTS %I ON %I 
                (periodo_referencia DESC)',
                v_index_name, v_partition_name
            );
        END IF;

        -- Log success
        UPDATE dw_operation_log 
        SET status = 'COMPLETED'
        WHERE operation_type = 'CREATE_PARTITION' 
        AND operation_details->>'partition_name' = v_partition_name
        AND status = 'STARTED';
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- Log error
    INSERT INTO dw_operation_log (
        operation_type,
        operation_details,
        status,
        error_message
    ) VALUES (
        'CREATE_PARTITION',
        jsonb_build_object(
            'partition_name', v_partition_name,
            'year', p_ano
        ),
        'ERROR',
        SQLERRM
    );
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- Criar partições iniciais
SELECT criar_particao_dados_indicadores(generate_series(2020, 2025));

--
-- Tabela Bridge Otimizada
--
CREATE TABLE indicador_dimensoes_bridge (
    id_bridge UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_dado UUID NOT NULL REFERENCES dados_indicadores(id_dado) ON DELETE CASCADE,
    id_dimensao UUID NOT NULL REFERENCES dimensoes(id_dimensao),
    tipo_dimensao dimensao_tipo NOT NULL,
    valor_dimensao VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_dado_dimensao UNIQUE(id_dado, id_dimensao)
) PARTITION BY LIST (tipo_dimensao);

-- Criar partições otimizadas
DO $$ 
DECLARE 
    dim_type dimensao_tipo;
BEGIN
    FOR dim_type IN 
        SELECT unnest(enum_range(NULL::dimensao_tipo))
    LOOP
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS indicador_dimensoes_bridge_%s 
            PARTITION OF indicador_dimensoes_bridge 
            FOR VALUES IN (%L)',
            dim_type, dim_type
        );
        
        -- Configurar partição
        EXECUTE format(
            'ALTER TABLE indicador_dimensoes_bridge_%s SET (
                fillfactor = 90,
                autovacuum_vacuum_scale_factor = 0.1,
                autovacuum_analyze_scale_factor = 0.05
            )', dim_type
        );
        
        -- Criar índices otimizados
        EXECUTE format(
            'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bridge_%s_dado 
            ON indicador_dimensoes_bridge_%s (id_dado)
            INCLUDE (id_dimensao, valor_dimensao)',
            dim_type, dim_type
        );
        
        EXECUTE format(
            'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bridge_%s_dimensao 
            ON indicador_dimensoes_bridge_%s (id_dimensao)
            INCLUDE (id_dado, valor_dimensao)',
            dim_type, dim_type
        );
    END LOOP;
END $$;

--
-- Views Materializadas Otimizadas
--
CREATE MATERIALIZED VIEW mv_dados_indicadores_anual AS
SELECT 
    di.id_indicador,
    i.codigo as codigo_indicador,
    i.nome_pt as nome_indicador,
    EXTRACT(YEAR FROM di.periodo_referencia) as ano,
    i.unidade,
    i.tipo_valor,
    COUNT(*) as total_registros,
    MIN(di.valor_numerico) as valor_minimo,
    MAX(di.valor_numerico) as valor_maximo,
    ROUND(AVG(di.valor_numerico)::numeric, 2) as valor_medio,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY di.valor_numerico) as mediana,
    ROUND(STDDEV(di.valor_numerico)::numeric, 2) as desvio_padrao,
    MIN(di.periodo_referencia) as primeiro_registro,
    MAX(di.periodo_referencia) as ultimo_registro
FROM dados_indicadores di
JOIN indicadores i ON i.id_indicador = di.id_indicador
WHERE di.valor_numerico IS NOT NULL
GROUP BY 
    di.id_indicador,
    i.codigo,
    i.nome_pt,
    EXTRACT(YEAR FROM di.periodo_referencia),
    i.unidade,
    i.tipo_valor
WITH DATA;

-- Índices otimizados para a view materializada
CREATE UNIQUE INDEX CONCURRENTLY idx_mv_dados_anuais_pk 
    ON mv_dados_indicadores_anual (id_indicador, ano);
CREATE INDEX CONCURRENTLY idx_mv_dados_anuais_busca 
    ON mv_dados_indicadores_anual (codigo_indicador, ano);

-- Função otimizada para atualização
CREATE OR REPLACE FUNCTION atualizar_views_materializadas()
RETURNS void AS $$
BEGIN
    -- Log start
    INSERT INTO dw_operation_log (
        operation_type,
        status
    ) VALUES (
        'REFRESH_MATERIALIZED_VIEWS',
        'STARTED'
    );

    -- Refresh views
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dados_indicadores_anual;
    
    -- Log completion
    UPDATE dw_operation_log 
    SET status = 'COMPLETED'
    WHERE operation_type = 'REFRESH_MATERIALIZED_VIEWS'
    AND status = 'STARTED';
EXCEPTION WHEN OTHERS THEN
    -- Log error
    INSERT INTO dw_operation_log (
        operation_type,
        status,
        error_message
    ) VALUES (
        'REFRESH_MATERIALIZED_VIEWS',
        'ERROR',
        SQLERRM
    );
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- View otimizada para dados recentes
CREATE OR REPLACE VIEW vw_dados_indicadores_recentes AS
WITH ultimos_dados AS (
    SELECT DISTINCT ON (id_indicador) 
        id_dado,
        id_indicador,
        valor_numerico,
        valor_texto,
        variacao_percentual,
        periodo_referencia,
        created_at,
        updated_at
    FROM dados_indicadores
    ORDER BY id_indicador, periodo_referencia DESC
)
SELECT 
    ud.id_dado,
    ud.id_indicador,
    i.codigo as codigo_indicador,
    i.nome_pt as nome_indicador,
    i.unidade,
    i.tipo_valor,
    i.estado,
    ud.valor_numerico,
    ud.valor_texto,
    ud.variacao_percentual,
    ud.periodo_referencia,
    ud.created_at,
    ud.updated_at
FROM ultimos_dados ud
JOIN indicadores i ON i.id_indicador = ud.id_indicador
WHERE i.ativo = true;

-- Documentação atualizada
COMMENT ON VIEW vw_dados_indicadores_recentes 
IS 'Visão otimizada dos dados mais recentes dos indicadores';

-- Criar função para manutenção de partições
CREATE OR REPLACE FUNCTION manter_particoes_dados_indicadores()
RETURNS void AS $$
DECLARE
    v_ano_atual INTEGER;
    v_ano_minimo INTEGER;
    v_ano_maximo INTEGER;
BEGIN
    v_ano_atual := EXTRACT(YEAR FROM CURRENT_DATE);
    v_ano_minimo := v_ano_atual - 5;  -- Manter 5 anos de histórico
    v_ano_maximo := v_ano_atual + 2;  -- Criar 2 anos futuros
    
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

-- Agendar manutenção (comentado - ajustar conforme necessidade)
-- SELECT cron.schedule('0 0 * * 0', $$SELECT manter_particoes_dados_indicadores()$$);
```