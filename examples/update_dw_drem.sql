```sql
--
-- Script de Atualização do Data Warehouse DREM
-- Versão: 1.1
-- Autor: João Mendes
-- Data: 2024-10-28
-- Ambiente: Azure PostgreSQL
--
-- INSTRUÇÕES DE UTILIZAÇÃO:
-- 1. Este script serve como exemplo para inserir novos dados via DB no DW
-- 2. Para adicionar novos indicadores, siga a estrutura abaixo
-- 3. Modifique os valores conforme necessário
-- 4. Execute o script completo em uma única transação
--

-- Início da transação - IMPORTANTE: Não remover
BEGIN;

--
-- PASSO 1: Verificar se o tema já existe
-- Se o tema não existir, criar novo tema
-- Se existir, usar o ID existente
--
DO $$
DECLARE
    v_id_tema UUID;
BEGIN
    SELECT id_tema INTO v_id_tema 
    FROM temas 
    WHERE codigo = 'ECO';
    
    IF NOT FOUND THEN
        INSERT INTO temas (
            codigo,
            nome_pt,
            nome_en,
            descricao_pt,
            descricao_en,
            icone,
            cor_tema,
            ordem,
            metadata
        ) VALUES (
            'ECO',                        -- Código único do tema
            'Economia',                   -- Nome em português
            'Economy',                    -- Nome em inglês
            'Indicadores económicos...',  -- Descrição em português
            'Economic indicators...',     -- Descrição em inglês
            'chart-line',                -- Ícone (opcional)
            '#2E7D32',                   -- Cor do tema
            1,                           -- Ordem de apresentação
            jsonb_build_object(
                'fonte_principal', 'DREM',
                'contato', 'drem@ine.pt'
            )
        ) RETURNING id_tema INTO v_id_tema;
    END IF;
END $$;

--
-- PASSO 2: Verificar/Criar Sub-tema
--
DO $$
DECLARE
    v_id_tema UUID;
    v_id_sub_tema UUID;
BEGIN
    SELECT id_tema INTO v_id_tema FROM temas WHERE codigo = 'ECO';
    
    SELECT id_sub_tema INTO v_id_sub_tema 
    FROM sub_temas 
    WHERE codigo = 'TUR';
    
    IF NOT FOUND THEN
        INSERT INTO sub_temas (
            id_tema,
            codigo,
            nome_pt,
            nome_en,
            path,
            ordem,
            metadata
        ) VALUES (
            v_id_tema,
            'TUR',
            'Turismo',
            'Tourism',
            'eco.tur',
            1,
            jsonb_build_object(
                'setor_responsavel', 'DREM',
                'contato', 'drem@ine.pt'
            )
        );
    END IF;
END $$;

--
-- PASSO 3: Verificar/Criar Área
--
DO $$
DECLARE
    v_id_sub_tema UUID;
    v_id_area UUID;
BEGIN
    SELECT id_sub_tema INTO v_id_sub_tema 
    FROM sub_temas 
    WHERE codigo = 'TUR';
    
    SELECT id_area INTO v_id_area 
    FROM areas 
    WHERE codigo = 'OFT';
    
    IF NOT FOUND THEN
        INSERT INTO areas (
            id_sub_tema,
            codigo,
            nome_pt,
            nome_en,
            path,
            ordem,
            metadata
        ) VALUES (
            v_id_sub_tema,
            'OFT',
            'Oferta Turística',
            'Tourism Supply',
            'eco.tur.oft',
            1,
            jsonb_build_object(
                'tipo_dados', 'Quantitativos',
                'fonte', 'DREM'
            )
        );
    END IF;
END $$;

--
-- PASSO 4: Verificar/Criar Dimensões Temporais
-- NOTA: Adicione os meses necessários
--
DO $$
DECLARE
    v_id_ano UUID;
BEGIN
    -- Criar ano se não existir
    INSERT INTO dimensoes (
        tipo,
        codigo,
        nome_pt,
        nome_en,
        valor,
        hierarquia,
        nivel,
        ordem
    ) VALUES
        ('temporal', 'ANO2023', '2023', '2023', '2023', 'tempo.2023', 1, 1)
    ON CONFLICT (tipo, codigo) DO NOTHING
    RETURNING id_dimensao INTO v_id_ano;

    -- Criar meses
    IF v_id_ano IS NOT NULL THEN
        INSERT INTO dimensoes (
            id_parent,
            tipo,
            codigo,
            nome_pt,
            nome_en,
            valor,
            hierarquia,
            nivel,
            ordem
        ) VALUES
            (v_id_ano, 'temporal', '202310', 'Outubro 2023', 'October 2023', '10/2023', 'tempo.2023.10', 2, 10)
        ON CONFLICT (tipo, codigo) DO NOTHING;
    END IF;
END $$;

--
-- PASSO 5: Inserir/Atualizar Indicador
--
DO $$
DECLARE
    v_id_area UUID;
    v_id_indicador UUID;
    v_dimensoes UUID[];
BEGIN
    -- Obter IDs necessários
    SELECT id_area INTO v_id_area FROM areas WHERE codigo = 'OFT';
    SELECT ARRAY_AGG(id_dimensao) INTO v_dimensoes 
    FROM dimensoes 
    WHERE tipo IN ('temporal', 'geografica') 
    AND nivel = 1;

    -- Inserir ou atualizar indicador
    INSERT INTO indicadores (
        id_area,
        codigo,
        nome_pt,
        nome_en,
        unidade,
        tipo_valor,
        estado,
        periodicidade,
        fonte,
        dimensoes_aplicaveis,
        metadata
    ) VALUES (
        v_id_area,
        'HOSP_EST',
        'Hóspedes nos estabelecimentos de alojamento turístico',
        'Guests in tourist accommodation establishments',
        'Nº',
        'numero',
        'definitivo',
        'mensal',
        'DREM',
        v_dimensoes,
        jsonb_build_object(
            'fonte', 'DREM',
            'contato', 'drem@ine.pt',
            'ultima_atualizacao', CURRENT_DATE
        )
    )
    ON CONFLICT (codigo) 
    DO UPDATE SET 
        estado = EXCLUDED.estado,
        metadata = jsonb_set(
            indicadores.metadata, 
            '{ultima_atualizacao}', 
            to_jsonb(CURRENT_DATE)
        );
END $$;

--
-- PASSO 6: Inserir Novos Dados
-- NOTA: Adicione seus dados aqui
--
DO $$
DECLARE
    v_id_indicador UUID;
    v_id_dado UUID;
BEGIN
    -- Obter ID do indicador
    SELECT id_indicador INTO v_id_indicador 
    FROM indicadores 
    WHERE codigo = 'HOSP_EST';

    -- Inserir novo dado
    INSERT INTO dados_indicadores (
        id_indicador,
        valor_numerico,
        periodo_referencia,
        metadata
    ) VALUES
        (v_id_indicador, 235674, '2023-10-01', '{"fonte": "DREM", "estado": "definitivo"}')
    RETURNING id_dado INTO v_id_dado;

    -- Inserir relações dimensionais
    INSERT INTO indicador_dimensoes_bridge (
        id_dado,
        id_dimensao,
        tipo_dimensao,
        valor_dimensao
    )
    SELECT 
        v_id_dado,
        d.id_dimensao,
        d.tipo,
        d.valor
    FROM dimensoes d
    WHERE d.id_dimensao = ANY(
        SELECT unnest(dimensoes_aplicaveis)
        FROM indicadores
        WHERE id_indicador = v_id_indicador
    );
END $$;

-- Atualizar views materializadas
SELECT atualizar_todas_views_materializadas();

-- Commit da transação
COMMIT;

-- Verificar dados inseridos
SELECT 
    i.nome_pt as indicador,
    to_char(di.periodo_referencia, 'Month YYYY') as periodo,
    di.valor_numerico as valor,
    i.unidade,
    i.estado
FROM dados_indicadores di
JOIN indicadores i ON i.id_indicador = di.id_indicador
WHERE i.codigo = 'HOSP_EST'
ORDER BY di.periodo_referencia DESC
LIMIT 5;
```