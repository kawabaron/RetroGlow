const fs = require('fs');
const path = require('path');

const targetDir = path.resolve(__dirname, '../modules/city-pop-processor/ios');
const targetFile = path.join(targetDir, 'IllustrationAI.mlmodel');

console.log(`
======================================================
[INFO] AIイラスト化モデル（Core ML）の配置について
======================================================
商用利用可能な「高品質イラスト風変換」のCoreMLモデルは、
ファイルサイズが大きく（数MB〜数十MB）、直接の自動ダウンロードが
サーバー側（HuggingFace等）で制限されているため、
手動でダウンロードして配置していただく必要があります。

【推奨モデル（MIT/Apache 2.0等 商用利用無料）】
おすすめ1: Anime2Sketch.mlmodel (オープンソースの線画抽出モデル)
おすすめ2: FNS-Candy.mlmodel / FNS-Udnie.mlmodel (Apple公式 スタイル変換)
おすすめ3: Photo2Cartoon (実写風似顔絵) など...

ご自身で見つけたお好きな ".mlmodel" 形式の画風変換モデルを
ダウンロードしてください。

【配置手順】
ダウンロードしたファイルを以下の名前に変更し、
指定の場所に配置してください。

対象ファイル名: IllustrationAI.mlmodel
配置先フォルダ: ${targetDir}
======================================================
`);

if (fs.existsSync(targetFile)) {
    console.log('[SUCCESS] IllustrationAI.mlmodel が見つかりました。ビルド可能です！');
} else {
    console.log('[WAITING] モデルファイルを見つけて配置してください。配置後、再度アプリのビルド（npx expo run:ios -d）を実行してください。');
}
