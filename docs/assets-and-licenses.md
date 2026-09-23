# Assets, proveniência e licenças

| Recurso | Caminho esperado | Fonte conhecida | Estado nesta extração |
|---|---|---|---|
| MediaPipe Pose Landmarker Lite/Full | `ios/Sources/SquatCounter/Resources/Models/*.task` | URLs oficiais do Google em `ios/Scripts/download_models.sh` | Binários omitidos; script exige SHA-256 dos arquivos observados no projeto original em 2026-09-23. Conferir termos e versão antes de redistribuir. |
| Clipe de teste Pexels 8837118 | `ios/Sources/SquatCounter/Resources/pexels-8837118-1280w.mp4` | Projeto original o atribuía a MART PRODUCTION / Pexels; SHA-256 observado `cdc511a2b465d04c334ead1da374ecfb9e5a92c8625608e8eab91c6f2b582a3b` | Omitido. Autorização de redistribuição do arquivo específico não foi verificada nesta extração; fornecer manualmente apenas após conferência. App compila sem ele e informa ausência ao usar a opção. |
| Vídeo de fonte editorial | `video/public/source.mp4` | Cópia do clipe de teste no projeto original | Omitido; mesma revisão de direitos acima. |
| Captura de aparelho | `video/public/phone-full.mov` | Gravação do dispositivo do proprietário no projeto original | Omitida por conter conteúdo pessoal. Só usar arquivo autorizado pelo proprietário. |
| Imagens editoriais | `video/public/source-frame.png`, `source-frame-complete.png`, `phone-frame-complete.png` | Frames derivados dos vídeos acima | Omitidas; devem ser regeneradas a partir de mídia autorizada. `phone-result.png` não é referenciado pelo código. |
| Fontes Barlow Condensed e Atkinson Hyperlegible Next | Dependências npm no lockfile | Pacotes `@fontsource` | Omitidas de Git; instaladas por `npm ci`. Lockfile declara OFL-1.1; conferir avisos dos pacotes na distribuição. |

Os checksums dos modelos são uma checagem de integridade contra os binários presentes no protótipo, não uma atestação de licença ou segurança. O endpoint `latest` pode mudar. CocoaPods, npm e Remotion também trazem licenças próprias; consulte os manifests e termos do fornecedor. Nenhuma licença geral para este novo repositório foi escolhida.
