# Data Warehouse - Portal de Estatística da Madeira (DREM)

Sistema de Data Warehouse desenvolvido para a Direção Regional de Estatística da Madeira (DREM), projetado para gerir e disponibilizar dados estatísticos da Região Autónoma da Madeira de forma eficiente e escalável.

## 📊 Visão Geral
Sistema completo de gestão de dados estatísticos com:
- Suporte a análises multidimensionais complexas
- Integração com IA e chatbots
- Interface multilíngua (PT/EN)
- Estrutura hierárquica flexível
- Otimização para Azure PostgreSQL

### Estatísticas
- 4 Temas principais
- 18 Sub-temas
- 93 Áreas especializadas
- Suporte a milhares de indicadores

## 🏗️ Arquitetura
Modelo híbrido que combina:
- Esquema Estrela
- Esquema Floco de Neve
- Bridge Tables para dimensões dinâmicas

```
Temas
└── Sub-temas
    └── Áreas
        └── Indicadores
            └── Dados dos Indicadores
                └── Dimensões (via Bridge Table)
```

## 🚀 Início
1. **Pré-requisitos**
```sql
-- Requisitos mínimos
PostgreSQL 14+
Extensions necessárias:
- uuid-ossp
- ltree
- pgcrypto
- pg_stat_statements
- pg_trgm
```

2. **Instalação**
```bash
# Clone o repositório
git clone https://github.com/joaomendes-ine/drem_dw_db.git

# Execute os scripts na ordem correta
- Os scripts devem ser executados sequencialmente (parte 1 a parte 6)
- Cada script valida a sua própria execução e dependências
- O script de exemplo de atualização serve como referência para futuras atualizações
```

## 📁 Estrutura do Repositório
```
drem_dw_db/
├── scripts/
│   ├── parte_1_estrutura_base.sql
│   ├── parte_2_tabelas_principais.sql
│   ├── parte_3_dimensoes_indicadores.sql
│   ├── parte_4_fatos_bridge.sql
│   ├── parte_5_views_indices.sql
│   └── parte_6_funcoes_manutencao.sql
├── examples/
│   └── update_dw_drem.sql
├── azure/
│   └── azure_otimizations.sql
├── docs/
│   ├── architecture.md
│   ├── configuration.md
│   ├── diagram.md
│   ├── diagram_fluxo.md
│   ├── dimensions.md
│   ├── maintenance.md
│   ├── tables.md
│   ├── tree_stats.md
│   ├── tree_diagram_principal.md
│   ├── tree_diagram_economia.md
│   ├── tree_diagram_social.md
│   ├── tree_diagram_regiao.md
│   └── tree_diagram_multitemas.md
├── pdf/
│   └── jm_doc_drem_dw_db.pdf
├── images/
│   └── jm_diagram_er_dw_db.png
│   └── jm_diagram_fluxo.png
│   └── jm_tree_diagram_principal.png
│   └── jm_tree_diagram_principal.png
│   └── jm_tree_diagram_economia.png
│   └── jm_tree_diagram_social.png
│   └── jm_tree_diagram_regiao.png
│   └── jm_tree_diagram_multitemas.png
└── README.md
```

## 📚 Documentação
### Documentação Técnica
- [Arquitetura Detalhada](./docs/architecture.md)
- [Estrutura das Tabelas](./docs/tables.md)
- [Sistema Dimensional](./docs/dimensions.md)
- [Manutenção](./docs/maintenance.md)
- [Configuração](./docs/configuration.md)
- [Árvore de Estatística](./docs/tree_stats.md)
- [Documentação geral](./pdf/jm_doc_drem_dw_db.pdf)

### Diagramas do Sistema
#### Diagramas de Base de Dados
- [Diagrama ER](./docs/diagram.md) - Estrutura relacional completa
- [Diagrama de Fluxo](./docs/diagram_fluxo.md) - Fluxo de População do Data Warehouse

#### Árvore de Estatística
- [Visão Geral](./docs/tree_diagram_principal.md) - Estrutura principal
- [Economia](./docs/tree_diagram_economia.md)
- [Social](./docs/tree_diagram_social.md)
- [Região](./docs/tree_diagram_regiao.md)
- [Multitemas](./docs/tree_diagram_multitemas.md)

## ⚙️ Configuração
Veja a [documentação de configuração](./docs/configuration.md) para instruções sobre:
- [Configuração PostgreSQL](./docs/configuration.md#1-configurações-base)
- [Otimizações Azure](./docs/configuration.md#2-otimizações-azure)
- [Gestão de Partições](./docs/configuration.md#3-gestão-de-partições)
- [Índices e Desempenho](./docs/configuration.md#4-índices-e-performance)
- [Monitorização](./docs/configuration.md#5-monitorização)
- [Manutenção](./docs/configuration.md#6-manutenção)
- [Resolução de Problemas](./docs/configuration.md#7-resolução-de-problemas)

## 🔍 Características Principais
- **Análise de Dados**
  - Estruturas OLAP otimizadas
  - Análises multidimensionais
  - Consultas eficientes
- **Escalabilidade**
  - Particionamento automático
  - Gestão eficiente de grandes volumes
  - Estrutura modular expansível
- **Integração**
  - API REST
  - Suporte a IA
  - Exportação flexível

## 🛠️ Manutenção
- **Arquivamento Automático**
- **Gestão de Partições**
- **Monitorização de Desempenho**
- **Backup e Recuperação**

## 📞 Contato
- Autor - joao.mendes@ine.pt
- DREM - drem@ine.pt
- Website - [https://estatistica.madeira.gov.pt/](https://estatistica.madeira.gov.pt/)