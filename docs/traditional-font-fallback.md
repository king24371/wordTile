# 繁體中文字型 fallback

模板提供的 Noto Sans SC 子集只承諾常用簡體字元。本遊戲以繁體中文為介面語言，因此保留既有 SC 字型並新增小型 Noto Sans TC fallback，讓繁體 UI、標題與載入提示能以 TC 字形呈現。Regular、Medium、Bold 三個子集各涵蓋本遊戲主程式、繁體 catalog 及載入頁的 241 個固定 CJK 字元；拉丁字母仍由模板 UI 字型提供。

TC 字型來自這個環境既有的 Noto Sans CJK TTC 地區 face，並依固定遊戲文案子集化為 WOFF2。字型副本與授權放在 `fonts/`；Godot UI 的 fallback 次序為 TC、SC。原有模板字型沒有修改。

來源：Noto CJK 上游 <https://github.com/notofonts/noto-cjk>；官方說明 CJK 地區代碼 `TC` 對應 Traditional Chinese。Noto 官方使用說明 <https://notofonts.github.io/noto-docs/website/use/> 說明 Noto 字型採 SIL Open Font License，可隨應用程式散布，並應隨附授權。完整套件版權及授權副本見 [NotoSansCJK-OFL.txt](../fonts/NotoSansCJK-OFL.txt)。
