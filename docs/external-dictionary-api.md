# 外部字典查核

Word Tiles 不以 AI、拼字猜測或本機清單判定單字。遊戲先查 Datamuse，再於主來源沒有精確條目或遇到連線錯誤時回退至 Free Dictionary API；兩者都以外部回應為準。

Datamuse 使用官方 `/words` 端點與精確 `sp=<word>` 拼字查詢，要求 definitions metadata（`md=d`）。遊戲只接受回應中 `word` 與玩家提交的 A–Z 字串完全一致，而且有 definitions 的條目。官方文件將其描述為 word-finding query API，也說明 definitions 來源包含 WordNet/Wiktionary 等詞彙資料；公開應用需標註 API，遊戲標題頁與本文件已標註來源。官方文件目前說明免金鑰服務至 **2027-01-01**；屆時 API key 將成為請求條件，若要在該日期後繼續使用，需更新此 API 設定或採用當時可用的字典端點。

Datamuse 官方規格：<https://www.datamuse.com/api/>。Free Dictionary API 備援使用 <https://api.dictionaryapi.dev/api/v2/entries/en/<word>>，只接受 HTTP 200 JSON 陣列中 `word` 完全匹配且 `meanings` 非空的項目；HTTP 404 才快取為外部字典未找到。官方頁面：<https://dictionaryapi.dev/>。

查詢非同步進行、最多四個字並行；相同待查字會合併請求。主來源沒有確認時只嘗試一次備援。任何 timeout、網路／API 錯誤、格式錯誤或兩者皆未提供有效定義，都不當成有效單字；傳輸失敗不存成無效快取，玩家可稍後重試。空白牌由玩家先指定代表字母，之後對組成的完整單字做相同字典查核。

2026-10-09 的即時端點檢查：Datamuse 為 HTTPS 200、約 2.5 秒並回傳 `game` 的定義；`api.dictionaryapi.dev` 在 Sandbox 測試逾時。這是當次 Sandbox 結果，不保證玩家瀏覽器網路狀況。若遊戲端兩個來源均不可達，UI 明確顯示未確認，且該單字不能和牌。
