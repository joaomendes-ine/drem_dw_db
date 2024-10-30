# Diagrama Multitemas

[![Download](https://img.shields.io/badge/Descarregar-2874a6?style=for-the-badge)](https://github.com/joaomendes-ine/drem_dw_db/blob/main/images/jm_tree_diagram_multitemas.png)

```mermaid
graph TB
   %% Main Theme
   M((Multitemas))
   
   %% Direct connections to main theme
   M --> A87[Área 87: Anuário]
   M --> A88[Área 88: Atlas]
   M --> A89[Área 89: Barómetro]
   M --> A90[Área 90: Boletim]
   M --> A91[Área 91: Equipamentos]
   M --> A92[Área 92: PT2020]
   M --> A93[Área 93: Madeira Números]

   %% Área connections
   A87 --> A87F[Em Focos<br>Notícias<br>Publicações]
   A88 --> A88F[Em Focos<br>Notícias<br>Publicações]
   A89 --> A89F[Em Focos<br>Notícias<br>Quadros]
   A90 --> A90F[Notícias<br>Publicações]
   A91 --> A91F[Em Focos<br>Informação geográfica<br>Notícias<br>Publicações]
   A92 --> A92F[Notícias<br>Sistema indicadores PT2020]
   A93 --> A93F[Notícias<br>Publicações]

   %% Styling
   classDef tema fill:#d4e6f1,stroke:#2874a6,stroke-width:3px
   classDef area fill:#fdebd0,stroke:#9c640c,stroke-width:1px
   classDef files fill:#f2d7d5,stroke:#943126,stroke-width:1px

   class M tema
   class A87,A88,A89,A90,A91,A92,A93 area
   class A87F,A88F,A89F,A90F,A91F,A92F,A93F files
```