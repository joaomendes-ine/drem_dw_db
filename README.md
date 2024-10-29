# Data Warehouse - Portal de Estatística da Madeira (DREM)

Sistema de Data Warehouse desenvolvido para a Direção Regional de Estatística da Madeira (DREM), projetado para gerir e disponibilizar dados estatísticos da Região Autónoma da Madeira de forma eficiente e escalável.

## 📊 Visão Geral

Sistema completo de gestão de dados estatísticos com:
- Suporte a análises multidimensionais complexas
- Integração com IA e chatbots
- Interface multilíngue (PT/EN)
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

## 🚀 Quick Start

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
# ... continue com os demais scripts
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
│   ├── tables.md
│   ├── dimensions.md
│   └── maintenance.md
└── README.md
```

## 📚 Documentação

- [Arquitetura Detalhada](docs/architecture.md)
- [Estrutura das Tabelas](docs/tables.md)
- [Sistema Dimensional](docs/dimensions.md)
- [Diagrama ER](docs/diagram.md)
- [Manutenção](docs/maintenance.md)

## ⚙️ Configuração

Veja nossa [documentação de configuração](docs/configuration.md) para instruções detalhadas sobre:
- Configuração do PostgreSQL
- Otimizações para Azure
- Gestão de partições
- Configuração de índices

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
  - API para chatbots
  - Suporte a IA
  - Exportação flexível

## 🛠️ Manutenção

- **Arquivamento Automático**
- **Gestão de Partições**
- **Monitorização de Performance**
- **Backup e Recuperação**

## 📞 Contato

- Autor - joao.mendes@ine.pt
- DREM - drem@ine.pt
- Website - [https://estatistica.madeira.gov.pt/](https://estatistica.madeira.gov.pt/)
