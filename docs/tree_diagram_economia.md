# Diagrama Economia

[![Download](https://img.shields.io/badge/Descarregar-2874a6?style=for-the-badge)](https://github.com/joaomendes-ine/drem_dw_db/blob/main/images/jm_tree_diagram_economia.png)

```mermaid
graph TB
   %% Main Theme
   E((Economia))
   
   %% Direct connections to main theme
   E --> ST1[Sub-tema 1: Administração Pública]
   E --> ST2[Sub-tema 2: Agricultura]
   E --> ST3[Sub-tema 3: Comércio]
   E --> ST4[Sub-tema 4: Conjuntura]
   E --> ST5[Sub-tema 5: Construção]
   E --> ST6[Sub-tema 6: Contas Económicas]
   E --> ST7[Sub-tema 7: Empresas]
   E --> ST8[Sub-tema 8: Indústria]
   E --> ST9[Sub-tema 9: Inovação]
   E --> ST10[Sub-tema 10: Monetário]
   E --> ST11[Sub-tema 11: Transportes]
   E --> ST12[Sub-tema 12: Turismo]

   %% Sub-tema 1: Administração Pública
   ST1 --> A1[Área 1: Administração Local]
   A1 --> A1F[Em Focos<br>Notícias<br>Quadros<br>Série]
   A1F --> A2[Área 2: Dívida Pública]
   A2 --> A2F[Notícias<br>Série]
   A2F --> A3[Área 3: Emprego Público]
   A3 --> A3F[Em Focos<br>Notícias<br>Série]
   A3F --> A4[Área 4: Défices]
   A4 --> A4F[Em Focos<br>Notícias<br>Série]
   A4F --> A5[Área 5: Receita]
   A5 --> A5F[Em Focos<br>Notícias<br>Série]
   A5F --> A6[Área 6: Fiscais]
   A6 --> A6F[Em Focos<br>Notícias<br>Série]

   %% Sub-tema 2: Agricultura
   ST2 --> A7[Área 7: Banana]
   A7 --> A7F[Notícias<br>Quadros<br>Série]
   A7F --> A8[Área 8: Estatísticas]
   A8 --> A8F[Em Focos<br>Notícias<br>Publicações<br>Quadros<br>Série]
   A8F --> A9[Área 9: Floresta]
   A9 --> A9F[Quadros]
   A9F --> A10[Área 10: Floricultura]
   A10 --> A10F[Em Focos<br>Notícias<br>Quadros]
   A10F --> A11[Área 11: Produção animal]
   A11 --> A11F[Notícias<br>Quadros<br>Série]
   A11F --> A12[Área 12: Recenseamentos]
   A12 --> A12F[Em Focos<br>Notícias<br>Publicações<br>Quadros<br>Série]

   %% Sub-tema 3: Comércio
   ST3 --> A13[Área 13: Produtos Madeira]
   A13 --> A13F[Dashboard<br>Notícias<br>Quadros<br>Série]
   A13F --> A14[Área 14: Comércio Internacional]
   A14 --> A14F[Em Focos<br>Notícias<br>Publicações<br>Quadros<br>Série]
   A14F --> A15[Área 15: Comércio interno]
   A15 --> A15F[Em Focos<br>Notícias<br>Quadros<br>Série]

   %% Sub-tema 4: Conjuntura
   ST4 --> A16[Área 16: COVID-19/Guerra]
   A16 --> A16F[Em Focos<br>Notícias<br>Quadros]
   A16F --> A17[Área 17: Inquéritos]
   A17 --> A17F[Dashboard<br>Em Focos<br>Notícias<br>Quadros]
   A17F --> A18[Área 18: Indicadores]
   A18 --> A18F[Em Focos<br>Notícias<br>Quadros<br>Série]

   %% Sub-tema 5: Construção
   ST5 --> A19[Área 19: Crédito habitação]
   A19 --> A19F[Em Focos<br>Notícias<br>Série]
   A19F --> A20[Área 20: Estatísticas]
   A20 --> A20F[Dashboard<br>Em Focos<br>Notícias<br>Publicações<br>Série]
   A20F --> A21[Área 21: Habitação Social]
   A21 --> A21F[Em Focos<br>Notícias<br>Série]
   A21F --> A22[Área 22: Indicadores construção]
   A22 --> A22F[Notícias<br>Série]
   A22F --> A23[Área 23: Licenciamento]
   A23 --> A23F[Notícias<br>Quadros<br>Série]
   A23F --> A24[Área 24: Operações imóveis]
   A24 --> A24F[Em Focos<br>Notícias<br>Série]
   A24F --> A25[Área 25: Preços habitação]
   A25 --> A25F[Em Focos<br>Mapa<br>Notícias<br>Série]
   A25F --> A26[Área 26: Venda alojamentos]
   A26 --> A26F[Em Focos<br>Notícias<br>Série]
   A26F --> A27[Área 27: Venda cimento]
   A27 --> A27F[Notícias<br>Série]

   %% Sub-tema 6: Contas Económicas
   ST6 --> A28[Área 28: Contas Agricultura]
   A28 --> A28F[Notícias<br>Série]
   A28F --> A29[Área 29: Contas Regionais]
   A29 --> A29F[Em Focos<br>Notícias<br>Série]
   A29F --> A30[Área 30: Conta Mar]
   A30 --> A30F[Em Focos<br>Notícias<br>Quadros]
   A30F --> A31[Área 31: Conta Turismo]
   A31 --> A31F[Em Focos<br>Notícias<br>Publicações<br>Quadros]
   A31F --> A32[Área 32: Investimento]
   A32 --> A32F[Notícias<br>Série]
   A32F --> A33[Área 33: Matriz input-output]
   A33 --> A33F[Em Focos<br>Notícias<br>Publicações<br>Quadros]

   %% Sub-tema 7: Empresas
   ST7 --> A34[Área 34: Contas empresas]
   A34 --> A34F[Em Focos<br>Notícias<br>Publicações<br>Quadros<br>Série]
   A34F --> A35[Área 35: Custos contexto]
   A35 --> A35F[Em Focos<br>Notícias<br>Quadros]
   A35F --> A36[Área 36: Qualificações]
   A36 --> A36F[Notícias<br>Quadros]
   A36F --> A37[Área 37: Práticas gestão]
   A37 --> A37F[Em Focos<br>Notícias<br>Quadros]
   A37F --> A38[Área 38: Serviços empresas]
   A38 --> A38F[Notícias<br>Série]
   A38F --> A39[Área 39: Sociedades]
   A39 --> A39F[Notícias<br>Quadros<br>Série]

   %% Sub-tema 8: Indústria
   ST8 --> A40[Área 40: Balanço energético]
   A40 --> A40F[Notícias<br>Quadros<br>Série]
   A40F --> A41[Área 41: Combustíveis]
   A41 --> A41F[Notícias<br>Quadros<br>Série]
   A41F --> A42[Área 42: Consumo energia]
   A42 --> A42F[Em Focos<br>Notícias<br>Quadros]
   A42F --> A43[Área 43: Energia elétrica]
   A43 --> A43F[Em Focos<br>Notícias<br>Quadros<br>Série]
   A43F --> A44[Área 44: Indústria]
   A44 --> A44F[Em Focos<br>Notícias]

   %% Sub-tema 9: Inovação
   ST9 --> A45[Área 45: Inovação]
   A45 --> A45F[Em Focos<br>Notícias<br>Quadros]
   A45F --> A46[Área 46: I&D]
   A46 --> A46F[Notícias<br>Série]
   A46F --> A47[Área 47: Sociedade informação]
   A47 --> A47F[Em Focos<br>Notícias<br>Quadros<br>Série]
   A47F --> A48[Área 48: Preços Consumidor]
   A48 --> A48F[Em Focos<br>Notícias<br>Publicações<br>Quadros<br>Série]

   %% Sub-tema 10: Monetário
   ST10 --> A49[Área 49: Banca/seguros]
   A49 --> A49F[Notícias<br>Série]
   A49F --> A50[Área 50: Empréstimos]
   A50 --> A50F[Notícias<br>Série]
   A50F --> A51[Área 51: Rede SIBS]
   A51 --> A51F[Notícias<br>Quadros<br>Série]

   %% Sub-tema 11: Transportes
   ST11 --> A52[Área 52: Comunicações]
   A52 --> A52F[Notícias<br>Série]
   A52F --> A53[Área 53: Transportes]
   A53 --> A53F[Em Focos<br>Notícias<br>Publicações<br>Quadros<br>Série]

   %% Sub-tema 12: Turismo
   ST12 --> A54[Área 54: Oferta turística]
   A54 --> A54F[Dashboards<br>Em Focos<br>Notícias<br>Publicações<br>Quadros<br>Série]
   A54F --> A55[Área 55: Gastos turísticos]
   A55 --> A55F[Em Focos<br>Notícias]

   %% Styling
   classDef tema fill:#d4e6f1,stroke:#2874a6,stroke-width:3px
   classDef subtema fill:#d5f5e3,stroke:#196f3d,stroke-width:2px
   classDef area fill:#fdebd0,stroke:#9c640c,stroke-width:1px
   classDef files fill:#f2d7d5,stroke:#943126,stroke-width:1px

   class E tema
   class ST1,ST2,ST3,ST4,ST5,ST6,ST7,ST8,ST9,ST10,ST11,ST12 subtema
   class A1,A2,A3,A4,A5,A6,A7,A8,A9,A10,A11,A12,A13,A14,A15,A16,A17,A18,A19,A20,A21,A22,A23,A24,A25,A26,A27,A28,A29,A30,A31,A32,A33,A34,A35,A36,A37,A38,A39,A40,A41,A42,A43,A44,A45,A46,A47,A48,A49,A50,A51,A52,A53,A54,A55 area
   class A1F,A2F,A3F,A4F,A5F,A6F,A7F,A8F,A9F,A10F,A11F,A12F,A13F,A14F,A15F,A16F,A17F,A18F,A19F,A20F,A21F,A22F,A23F,A24F,A25F,A26F,A27F,A28F,A29F,A30F,A31F,A32F,A33F,A34F,A35F,A36F,A37F,A38F,A39F,A40F,A41F,A42F,A43F,A44F,A45F,A46F,A47F,A48F,A49F,A50F,A51F,A52F,A53F,A54F,A55F files
```