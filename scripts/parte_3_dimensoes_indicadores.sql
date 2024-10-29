--
-- Script de criação do Data Warehouse DREM - Parte 3: Dimensões e Indicadores
-- Versão: 1.1
-- Autor: João Mendes
-- Data: 2024-10-28
-- Ambiente: Azure PostgreSQL
--

-- Register schema version
INSERT INTO schema_version (version, description, script_name)
VALUES ('1.1', 'Dimensions and indicators creation', 'dimensoes_indicadores.sql');

--
-- Tabela: dimensoes (Otimizada para Azure)
--
CREATE TABLE dimensoes (
    id_dimensao UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_parent UUID REFERENCES dimensoes(id_dimensao),
    tipo dimensao_tipo NOT NULL,
    codigo VARCHAR(50) NOT NULL,
    nome_pt VARCHAR(255) NOT NULL,
    nome_en VARCHAR(255),
    valor VARCHAR(255) NOT NULL,
    hierarquia ltree NOT NULL,
    nivel INTEGER NOT NULL DEFAULT 1,
    ordem INTEGER CHECK (ordem >= 0),
    data_inicio DATE,
    data_fim DATE,
    metadata JSONB DEFAULT '{}',
    ativo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(tipo, codigo),
    CONSTRAINT chk_datas CHECK (data_inicio <= data_fim),
    CONSTRAINT chk_nivel CHECK (nivel > 0),
    CONSTRAINT chk_codigo_dimensao CHECK (codigo ~ '^[A-Z0-9]+$'),
    CONSTRAINT chk_nome_pt_dim_not_empty CHECK (trim(nome_pt) <> ''),
    CONSTRAINT chk_valor_not_empty CHECK (trim(valor) <> '')
) WITH (
    fillfactor = 90,
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

-- Otimização: Criar índices eficientes com CONCURRENTLY
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_dimensoes_hierarquia ON dimensoes USING GIST (hierarquia);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_dimensoes_tipo_valor ON dimensoes (tipo, valor);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_dimensoes_datas 
    ON dimensoes (data_inicio, data_fim) 
    WHERE ativo = true 
    INCLUDE (tipo, codigo);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_dimensoes_parent 
    ON dimensoes (id_parent) 
    WHERE id_parent IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_dimensoes_busca ON dimensoes USING GIN (
    to_tsvector('portuguese', 
        coalesce(nome_pt, '') || ' ' || 
        valor || ' ' ||
        coalesce(metadata::text, '')
    )
);

--
-- Tabela: indicadores (Otimizada para Azure)
--
CREATE TABLE indicadores (
    id_indicador UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_area UUID NOT NULL REFERENCES areas(id_area) ON DELETE CASCADE,
    codigo VARCHAR(50) UNIQUE NOT NULL,
    nome_pt VARCHAR(255) NOT NULL,
    nome_en VARCHAR(255),
    descricao_pt TEXT,
    descricao_en TEXT,
    unidade VARCHAR(50) NOT NULL CHECK (unidade <> ''),
    tipo_valor valor_tipo NOT NULL,
    estado estado_indicador NOT NULL DEFAULT 'preliminar',
    periodicidade periodicidade_tipo NOT NULL,
    fonte VARCHAR(255) NOT NULL,
    metodologia_pt TEXT,
    metodologia_en TEXT,
    formula TEXT,
    dimensoes_aplicaveis UUID[] NOT NULL,
    metadata JSONB DEFAULT '{}',
    configuracao_visualizacao JSONB DEFAULT '{}',
    configuracao_olap JSONB DEFAULT '{}',
    palavras_chave_pt TEXT[],
    palavras_chave_en TEXT[],
    valor_minimo NUMERIC,
    valor_maximo NUMERIC,
    precision_scale INTEGER DEFAULT 2,
    frequencia_atualizacao INTERVAL,
    ultima_atualizacao TIMESTAMP WITH TIME ZONE,
    proxima_atualizacao TIMESTAMP WITH TIME ZONE,
    versao INTEGER DEFAULT 1,
    ativo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_precisao CHECK (precision_scale BETWEEN 0 AND 6),
    CONSTRAINT chk_palavras_chave_min CHECK (
        array_length(palavras_chave_pt, 1) >= 1 OR 
        array_length(palavras_chave_en, 1) >= 1
    ),
    CONSTRAINT chk_codigo_indicador CHECK (codigo ~ '^[A-Z0-9]+$'),
    CONSTRAINT chk_nome_pt_ind_not_empty CHECK (trim(nome_pt) <> ''),
    CONSTRAINT chk_tipo_valor_unidade CHECK (
        (tipo_valor = 'numero' AND unidade NOT IN ('%', '€')) OR
        (tipo_valor = 'percentagem' AND unidade = '%') OR
        (tipo_valor = 'moeda' AND unidade LIKE '€%') OR
        (tipo_valor = 'texto')
    )
) WITH (
    fillfactor = 90,
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

-- Otimização: Criar índices eficientes com CONCURRENTLY
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_indicadores_busca ON indicadores USING GIN (
    to_tsvector('portuguese', 
        nome_pt || ' ' || 
        COALESCE(descricao_pt, '') || ' ' || 
        COALESCE(array_to_string(palavras_chave_pt, ' '), '') || ' ' ||
        COALESCE(fonte, '')
    )
);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_indicadores_area ON indicadores (id_area, ativo) 
    WHERE ativo = true 
    INCLUDE (codigo, nome_pt, estado);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_indicadores_metadata ON indicadores USING GIN (metadata);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_indicadores_palavras_pt ON indicadores USING GIN (palavras_chave_pt);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_indicadores_palavras_en ON indicadores USING GIN (palavras_chave_en);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_indicadores_estado ON indicadores (estado, ativo) 
    WHERE ativo = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_indicadores_atualizacao ON indicadores (proxima_atualizacao) 
    WHERE ativo = true AND proxima_atualizacao IS NOT NULL;

--
-- Tabela: historico_estado_indicador
--
CREATE TABLE historico_estado_indicador (
    id_historico UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_indicador UUID NOT NULL REFERENCES indicadores(id_indicador),
    estado_anterior estado_indicador NOT NULL,
    estado_novo estado_indicador NOT NULL,
    data_mudanca TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    justificativa TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
) WITH (
    fillfactor = 90,
    autovacuum_vacuum_scale_factor = 0.2
);

-- Otimização: Índices para histórico
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_historico_estado_indicador 
    ON historico_estado_indicador (id_indicador, data_mudanca DESC)
    INCLUDE (estado_anterior, estado_novo);

-- Trigger otimizado para histórico de estados
CREATE OR REPLACE FUNCTION log_indicador_estado_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado IS DISTINCT FROM OLD.estado THEN
        INSERT INTO historico_estado_indicador (
            id_indicador,
            estado_anterior,
            estado_novo,
            justificativa,
            metadata
        ) VALUES (
            NEW.id_indicador,
            OLD.estado,
            NEW.estado,
            NEW.metadata->>'justificativa_mudanca_estado',
            jsonb_build_object(
                'alterado_por', current_user,
                'data_alteracao', current_timestamp,
                'metadata_original', NEW.metadata
            )
        );
        
        -- Log operation
        INSERT INTO dw_operation_log (
            operation_type,
            operation_details
        ) VALUES (
            'INDICADOR_ESTADO_CHANGE',
            jsonb_build_object(
                'id_indicador', NEW.id_indicador,
                'estado_anterior', OLD.estado,
                'estado_novo', NEW.estado
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Materialized view para estado dos indicadores
CREATE MATERIALIZED VIEW mv_indicadores_estado AS
SELECT 
    i.id_indicador,
    i.codigo,
    i.nome_pt,
    i.estado,
    i.updated_at as ultima_atualizacao,
    h.data_mudanca as data_ultima_mudanca_estado,
    h.estado_anterior,
    h.justificativa,
    i.metadata,
    a.nome_pt as area_nome,
    st.nome_pt as subtema_nome,
    t.nome_pt as tema_nome
FROM indicadores i
JOIN areas a ON a.id_area = i.id_area
JOIN sub_temas st ON st.id_sub_tema = a.id_sub_tema
JOIN temas t ON t.id_tema = st.id_tema
LEFT JOIN LATERAL (
    SELECT 
        estado_anterior,
        estado_novo,
        data_mudanca,
        justificativa
    FROM historico_estado_indicador hi
    WHERE hi.id_indicador = i.id_indicador
    ORDER BY data_mudanca DESC
    LIMIT 1
) h ON true
WHERE i.ativo = true
WITH DATA;

-- Índices para a materialized view
CREATE UNIQUE INDEX CONCURRENTLY idx_mv_indicadores_estado_id 
    ON mv_indicadores_estado (id_indicador);
CREATE INDEX CONCURRENTLY idx_mv_indicadores_estado_busca 
    ON mv_indicadores_estado USING GIN (
        to_tsvector('portuguese',
            codigo || ' ' ||
            nome_pt || ' ' ||
            area_nome || ' ' ||
            subtema_nome || ' ' ||
            tema_nome
        )
    );

-- Função para atualização da view materializada
CREATE OR REPLACE FUNCTION refresh_indicadores_estado()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_indicadores_estado;
END;
$$ LANGUAGE plpgsql;

-- Documentação atualizada
COMMENT ON MATERIALIZED VIEW mv_indicadores_estado 
IS 'Visão materializada do estado atual dos indicadores com informações contextuais';
COMMENT ON FUNCTION refresh_indicadores_estado() 
IS 'Atualiza a visão materializada do estado dos indicadores';