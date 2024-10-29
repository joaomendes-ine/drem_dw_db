```sql
--
-- Script de criação do Data Warehouse DREM - Parte 5: Views e Índices Otimizados
-- Versão: 1.1
-- Autor: João Mendes
-- Data: 2024-10-28
-- Ambiente: Azure PostgreSQL
--

-- Register schema version
INSERT INTO schema_version (version, description, script_name)
VALUES ('1.1', 'Views and indexes creation', 'parte_5_views_indices.sql');

--
-- Views Materializadas Otimizadas
--

-- View materializada para estrutura hierárquica
CREATE MATERIALIZED VIEW mv_hierarquia_completa AS
WITH RECURSIVE full_hierarchy AS (
    SELECT 
        t.id_tema,
        t.codigo as codigo_tema,
        t.nome_pt as tema_pt,
        t.nome_en as tema_en,
        st.id_sub_tema,
        st.codigo as codigo_subtema,
        st.nome_pt as subtema_pt,
        st.nome_en as subtema_en,
        a.id_area,
        a.codigo as codigo_area,
        a.nome_pt as area_pt,
        a.nome_en as area_en,
        i.id_indicador,
        i.codigo as codigo_indicador,
        i.nome_pt as indicador_pt,
        i.nome_en as indicador_en,
        i.unidade,
        i.tipo_valor,
        i.estado,
        i.periodicidade,
        t.ordem as tema_ordem,
        st.ordem as subtema_ordem,
        a.ordem as area_ordem,
        array[t.nome_pt, st.nome_pt, a.nome_pt, i.nome_pt] as path_array
    FROM temas t
    JOIN sub_temas st ON st.id_tema = t.id_tema
    JOIN areas a ON a.id_sub_tema = st.id_sub_tema
    JOIN indicadores i ON i.id_area = a.id_area
    WHERE t.ativo AND st.ativo AND a.ativo AND i.ativo
)
SELECT 
    *,
    array_to_string(path_array, ' > ') as caminho_completo
FROM full_hierarchy
WITH DATA;

-- Índices otimizados para hierarquia
CREATE UNIQUE INDEX CONCURRENTLY idx_mv_hierarquia_pk 
    ON mv_hierarquia_completa (id_indicador);

CREATE INDEX CONCURRENTLY idx_mv_hierarquia_busca ON mv_hierarquia_completa 
USING GIN (to_tsvector('portuguese',
    coalesce(tema_pt, '') || ' ' || 
    coalesce(subtema_pt, '') || ' ' || 
    coalesce(area_pt, '') || ' ' || 
    coalesce(indicador_pt, '') || ' ' ||
    coalesce(caminho_completo, '')
));

CREATE INDEX CONCURRENTLY idx_mv_hierarquia_ordem 
    ON mv_hierarquia_completa (tema_ordem, subtema_ordem, area_ordem);

-- View materializada para estatísticas
CREATE MATERIALIZED VIEW mv_estatisticas_indicadores AS
WITH indicador_stats AS (
    SELECT 
        i.id_indicador,
        i.codigo,
        i.nome_pt,
        i.estado,
        i.periodicidade,
        COUNT(di.id_dado) as total_registros,
        MIN(di.periodo_referencia) as primeiro_registro,
        MAX(di.periodo_referencia) as ultimo_registro,
        MIN(di.valor_numerico) as valor_minimo,
        MAX(di.valor_numerico) as valor_maximo,
        ROUND(AVG(di.valor_numerico)::numeric, 2) as valor_medio,
        ROUND(STDDEV(di.valor_numerico)::numeric, 2) as desvio_padrao,
        COUNT(DISTINCT idb.id_dimensao) as total_dimensoes,
        MAX(di.updated_at) as ultima_atualizacao
    FROM indicadores i
    LEFT JOIN dados_indicadores di ON di.id_indicador = i.id_indicador
    LEFT JOIN indicador_dimensoes_bridge idb ON idb.id_dado = di.id_dado
    WHERE i.ativo = true
    GROUP BY i.id_indicador, i.codigo, i.nome_pt, i.estado, i.periodicidade
)
SELECT 
    s.*,
    h.caminho_completo,
    jsonb_build_object(
        'registros_ultimos_30_dias', (
            SELECT count(*) 
            FROM dados_indicadores d 
            WHERE d.id_indicador = s.id_indicador 
            AND d.periodo_referencia >= CURRENT_DATE - INTERVAL '30 days'
        ),
        'ultima_atualizacao', s.ultima_atualizacao,
        'dimensoes_utilizadas', s.total_dimensoes
    ) as metricas_adicionais
FROM indicador_stats s
JOIN mv_hierarquia_completa h ON h.id_indicador = s.id_indicador
WITH DATA;

-- Índices otimizados para estatísticas
CREATE UNIQUE INDEX CONCURRENTLY idx_mv_estatisticas_pk 
    ON mv_estatisticas_indicadores (id_indicador);
CREATE INDEX CONCURRENTLY idx_mv_estatisticas_busca 
    ON mv_estatisticas_indicadores (codigo, estado);

-- View otimizada para últimos valores
CREATE OR REPLACE VIEW vw_ultimos_valores AS
WITH latest_values AS (
    SELECT DISTINCT ON (id_indicador)
        id_indicador,
        id_dado,
        valor_numerico,
        valor_texto,
        variacao_percentual,
        periodo_referencia,
        updated_at
    FROM dados_indicadores
    ORDER BY id_indicador, periodo_referencia DESC
)
SELECT 
    i.codigo,
    i.nome_pt,
    i.unidade,
    i.estado,
    lv.valor_numerico,
    lv.valor_texto,
    lv.variacao_percentual,
    lv.periodo_referencia,
    h.caminho_completo,
    h.tema_pt as tema,
    h.subtema_pt as sub_tema,
    h.area_pt as area
FROM latest_values lv
JOIN indicadores i ON i.id_indicador = lv.id_indicador
JOIN mv_hierarquia_completa h ON h.id_indicador = i.id_indicador
WHERE i.ativo = true;

-- View otimizada para análise dimensional
CREATE OR REPLACE VIEW vw_indicadores_dimensoes AS
WITH RECURSIVE dim_hierarchy AS (
    SELECT 
        i.id_indicador,
        i.codigo,
        i.nome_pt as indicador,
        d.tipo as tipo_dimensao,
        d.nome_pt as dimensao,
        d.valor as valor_dimensao,
        d.hierarquia as hierarquia_dimensao,
        d.nivel
    FROM indicadores i
    CROSS JOIN UNNEST(i.dimensoes_aplicaveis) as dim_id
    JOIN dimensoes d ON d.id_dimensao = dim_id
    WHERE i.ativo = true
)
SELECT * FROM dim_hierarchy;

-- View otimizada para análise temporal
CREATE MATERIALIZED VIEW mv_analise_temporal AS
SELECT 
    i.codigo,
    i.nome_pt as indicador,
    i.unidade,
    i.estado,
    date_trunc('month', di.periodo_referencia) as periodo,
    COUNT(*) as total_registros,
    ROUND(AVG(di.valor_numerico)::numeric, 2) as media_valor,
    MIN(di.valor_numerico) as valor_minimo,
    MAX(di.valor_numerico) as valor_maximo,
    ROUND(STDDEV(di.valor_numerico)::numeric, 2) as desvio_padrao,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY di.valor_numerico) as mediana
FROM indicadores i
JOIN dados_indicadores di ON di.id_indicador = i.id_indicador
WHERE i.ativo = true
GROUP BY 
    i.codigo,
    i.nome_pt,
    i.unidade,
    i.estado,
    date_trunc('month', di.periodo_referencia)
WITH DATA;

-- Índices otimizados para análise temporal
CREATE UNIQUE INDEX CONCURRENTLY idx_mv_temporal_pk 
    ON mv_analise_temporal (codigo, periodo);
CREATE INDEX CONCURRENTLY idx_mv_temporal_periodo 
    ON mv_analise_temporal (periodo DESC);

-- Função de busca otimizada
CREATE OR REPLACE FUNCTION buscar_dw(
    termo TEXT,
    p_limit INTEGER DEFAULT 100,
    p_tipo TEXT DEFAULT NULL
)
RETURNS TABLE (
    tipo TEXT,
    id UUID,
    codigo VARCHAR(50),
    nome TEXT,
    descricao TEXT,
    caminho TEXT,
    relevancia FLOAT
) AS $$
DECLARE
    v_query tsquery;
BEGIN
    -- Preparar query de busca
    v_query := to_tsquery('portuguese', 
        string_agg(lexeme::text, ' & ') 
        FROM unnest(to_tsvector('portuguese', termo)) as lexeme
    );
    
    RETURN QUERY
    WITH unified_search AS (
        -- Busca em temas
        SELECT 
            'Tema'::TEXT as tipo,
            id_tema as id,
            codigo,
            nome_pt as nome,
            descricao_pt as descricao,
            nome_pt as caminho,
            ts_rank(to_tsvector('portuguese', 
                COALESCE(nome_pt, '') || ' ' || 
                COALESCE(descricao_pt, '')
            ), v_query) as relevancia
        FROM temas
        WHERE to_tsvector('portuguese', 
            COALESCE(nome_pt, '') || ' ' || 
            COALESCE(descricao_pt, '')
        ) @@ v_query
        AND ativo = true
        
        UNION ALL
        
        -- Demais buscas aqui...
        -- [Código similar para subtemas, áreas e indicadores]
    )
    SELECT *
    FROM unified_search
    WHERE p_tipo IS NULL OR tipo = p_tipo
    ORDER BY relevancia DESC, tipo, nome
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Função otimizada para atualização de views
CREATE OR REPLACE FUNCTION atualizar_todas_views_materializadas(
    p_force_refresh BOOLEAN DEFAULT false
)
RETURNS void AS $$
DECLARE
    v_last_update TIMESTAMP;
    v_threshold INTERVAL := INTERVAL '1 hour';
BEGIN
    -- Verificar última atualização
    SELECT max(updated_at)
    INTO v_last_update
    FROM dados_indicadores;
    
    -- Atualizar apenas se necessário
    IF p_force_refresh OR v_last_update > (
        SELECT max(last_refresh) 
        FROM mv_estatisticas_indicadores
    ) - v_threshold THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_hierarquia_completa;
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_estatisticas_indicadores;
        REFRESH MATERIALIZED VIEW CONCURRENTLY mv_analise_temporal;
        
        -- Log refresh
        INSERT INTO dw_operation_log (
            operation_type,
            operation_details
        ) VALUES (
            'REFRESH_VIEWS',
            jsonb_build_object(
                'forced', p_force_refresh,
                'last_update', v_last_update
            )
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Análises de performance
CREATE OR REPLACE FUNCTION analisar_performance_views()
RETURNS TABLE (
    view_name TEXT,
    last_refresh TIMESTAMP WITH TIME ZONE,
    estimated_rows BIGINT,
    index_usage_ratio FLOAT,
    cache_hit_ratio FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname || '.' || relname as view_name,
        last_refresh,
        n_live_tup::BIGINT as estimated_rows,
        COALESCE(idx_scan::FLOAT / nullif(seq_scan + idx_scan, 0), 0) as index_usage_ratio,
        COALESCE(heap_blks_hit::FLOAT / nullif(heap_blks_hit + heap_blks_read, 0), 0) as cache_hit_ratio
    FROM pg_stat_user_tables
    WHERE relname LIKE 'mv_%'
    ORDER BY n_live_tup DESC;
END;
$$ LANGUAGE plpgsql;
```