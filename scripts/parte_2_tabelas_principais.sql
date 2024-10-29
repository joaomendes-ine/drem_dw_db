--
-- Script de criação do Data Warehouse DREM - Parte 2: Tabelas Principais
-- Versão: 1.1
-- Autor: João Mendes
-- Data: 2024-10-28
-- Ambiente: Azure PostgreSQL
--

-- Register schema version
INSERT INTO schema_version (version, description, script_name)
VALUES ('1.1', 'Main tables creation', 'parte_2_tabelas_principais.sql');

--
-- Tabela: temas
--
CREATE TABLE temas (
    -- Identificação
    id_tema UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo VARCHAR(50) UNIQUE NOT NULL,
    
    -- Informações básicas
    nome_pt VARCHAR(255) NOT NULL,
    nome_en VARCHAR(255),
    descricao_pt TEXT,
    descricao_en TEXT,
    
    -- Apresentação
    icone VARCHAR(100),
    cor_tema VARCHAR(7),
    
    -- Metadados e controle
    metadata JSONB DEFAULT '{}',
    ordem INTEGER CHECK (ordem >= 0),
    ativo BOOLEAN DEFAULT true,
    
    -- Slugs para URLs amigáveis
    slug_pt VARCHAR(255) GENERATED ALWAYS AS (
        lower(regexp_replace(nome_pt, '[^a-zA-Z0-9]+', '-', 'g'))
    ) STORED,
    slug_en VARCHAR(255) GENERATED ALWAYS AS (
        lower(regexp_replace(COALESCE(nome_en, nome_pt), '[^a-zA-Z0-9]+', '-', 'g'))
    ) STORED,
    
    -- Auditoria
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Restrições
    CONSTRAINT chk_codigo_tema CHECK (codigo ~ '^[A-Z0-9]+$'),
    CONSTRAINT chk_nome_pt_not_empty CHECK (trim(nome_pt) <> '')
) WITH (
    fillfactor = 90,
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

-- Otimização: Criar índices eficientes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_temas_busca ON temas USING GIN (
    to_tsvector('portuguese', 
        coalesce(nome_pt, '') || ' ' || 
        coalesce(descricao_pt, '')
    )
);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_temas_metadata ON temas USING GIN (metadata);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_temas_ativo_ordem ON temas (ativo, ordem) 
    WHERE ativo = true;

--
-- Tabela: sub_temas
--
CREATE TABLE sub_temas (
    -- Identificação e relacionamentos
    id_sub_tema UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_tema UUID NOT NULL REFERENCES temas(id_tema) ON DELETE CASCADE,
    codigo VARCHAR(50) UNIQUE NOT NULL,
    
    -- Informações básicas
    nome_pt VARCHAR(255) NOT NULL,
    nome_en VARCHAR(255),
    descricao_pt TEXT,
    descricao_en TEXT,
    
    -- Estrutura hierárquica
    path ltree NOT NULL,
    
    -- Metadados e controle
    metadata JSONB DEFAULT '{}',
    ordem INTEGER CHECK (ordem >= 0),
    ativo BOOLEAN DEFAULT true,
    
    -- Slugs para URLs amigáveis
    slug_pt VARCHAR(255) GENERATED ALWAYS AS (
        lower(regexp_replace(nome_pt, '[^a-zA-Z0-9]+', '-', 'g'))
    ) STORED,
    slug_en VARCHAR(255) GENERATED ALWAYS AS (
        lower(regexp_replace(COALESCE(nome_en, nome_pt), '[^a-zA-Z0-9]+', '-', 'g'))
    ) STORED,
    
    -- Auditoria
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Restrições
    CONSTRAINT chk_codigo_subtema CHECK (codigo ~ '^[A-Z0-9]+$'),
    CONSTRAINT chk_nome_pt_subtema_not_empty CHECK (trim(nome_pt) <> '')
) WITH (
    fillfactor = 90,
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

-- Otimização: Criar índices eficientes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_temas_path_gist ON sub_temas USING GIST (path);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_temas_path_btree ON sub_temas USING btree (path);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_temas_tema_ordem ON sub_temas (id_tema, ordem) 
    WHERE ativo = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sub_temas_busca ON sub_temas USING GIN (
    to_tsvector('portuguese', 
        coalesce(nome_pt, '') || ' ' || 
        coalesce(descricao_pt, '')
    )
);

--
-- Tabela: areas
--
CREATE TABLE areas (
    -- Identificação e relacionamentos
    id_area UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_sub_tema UUID NOT NULL REFERENCES sub_temas(id_sub_tema) ON DELETE CASCADE,
    codigo VARCHAR(50) UNIQUE NOT NULL,
    
    -- Informações básicas
    nome_pt VARCHAR(255) NOT NULL,
    nome_en VARCHAR(255),
    descricao_pt TEXT,
    descricao_en TEXT,
    
    -- Apresentação
    icone VARCHAR(100),
    
    -- Estrutura hierárquica
    path ltree,
    
    -- Metadados e controle
    metadata JSONB DEFAULT '{}',
    ordem INTEGER CHECK (ordem >= 0),
    ativo BOOLEAN DEFAULT true,
    
    -- Slugs para URLs amigáveis
    slug_pt VARCHAR(255) GENERATED ALWAYS AS (
        lower(regexp_replace(nome_pt, '[^a-zA-Z0-9]+', '-', 'g'))
    ) STORED,
    slug_en VARCHAR(255) GENERATED ALWAYS AS (
        lower(regexp_replace(COALESCE(nome_en, nome_pt), '[^a-zA-Z0-9]+', '-', 'g'))
    ) STORED,
    
    -- Auditoria
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Restrições
    CONSTRAINT chk_codigo_area CHECK (codigo ~ '^[A-Z0-9]+$'),
    CONSTRAINT chk_nome_pt_area_not_empty CHECK (trim(nome_pt) <> '')
) WITH (
    fillfactor = 90,
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

-- Otimização: Criar índices eficientes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_areas_busca ON areas USING GIN (
    to_tsvector('portuguese', 
        coalesce(nome_pt, '') || ' ' || 
        coalesce(descricao_pt, '')
    )
);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_areas_path ON areas USING GIST (path);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_areas_subtema_ordem ON areas (id_sub_tema, ordem) 
    WHERE ativo = true;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_areas_metadata ON areas USING GIN (metadata);

-- Triggers com logging
CREATE TRIGGER update_temas_modtime 
    BEFORE UPDATE ON temas 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sub_temas_modtime 
    BEFORE UPDATE ON sub_temas 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_areas_modtime 
    BEFORE UPDATE ON areas 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- View otimizada para hierarquia
CREATE MATERIALIZED VIEW mv_hierarquia_temas AS
SELECT 
    t.id_tema,
    t.codigo as codigo_tema,
    t.nome_pt as tema_pt,
    t.nome_en as tema_en,
    st.id_sub_tema,
    st.codigo as codigo_subtema,
    st.nome_pt as sub_tema_pt,
    st.nome_en as sub_tema_en,
    a.id_area,
    a.codigo as codigo_area,
    a.nome_pt as area_pt,
    a.nome_en as area_en,
    t.ativo as tema_ativo,
    st.ativo as sub_tema_ativo,
    a.ativo as area_ativa,
    t.ordem as tema_ordem,
    st.ordem as subtema_ordem,
    a.ordem as area_ordem
FROM temas t
LEFT JOIN sub_temas st ON st.id_tema = t.id_tema
LEFT JOIN areas a ON a.id_sub_tema = st.id_sub_tema
WHERE t.ativo = true
WITH DATA;

-- Índices para a view materializada
CREATE UNIQUE INDEX idx_mv_hierarquia_temas_id ON mv_hierarquia_temas (id_tema, id_sub_tema, id_area);
CREATE INDEX idx_mv_hierarquia_temas_busca ON mv_hierarquia_temas USING GIN (
    to_tsvector('portuguese',
        coalesce(tema_pt, '') || ' ' ||
        coalesce(sub_tema_pt, '') || ' ' ||
        coalesce(area_pt, '')
    )
);

-- Função para atualizar a view materializada
CREATE OR REPLACE FUNCTION refresh_hierarquia_temas()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_hierarquia_temas;
END;
$$ LANGUAGE plpgsql;

-- Comentários atualizados
COMMENT ON MATERIALIZED VIEW mv_hierarquia_temas IS 'Visão materializada da estrutura hierárquica completa';
COMMENT ON FUNCTION refresh_hierarquia_temas() IS 'Atualiza a visão materializada da hierarquia';