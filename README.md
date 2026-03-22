# ShadowClone - AI残像カメラ

<p align="center">
  <img src="screenShot/appicon.png" width="120" alt="ShadowClone App Icon"/>
</p>

Apple Vision フレームワークを活用したリアルタイム人物セグメンテーションにより、動画に残像（分身）エフェクトを生成するiOSカメラアプリです。

An iOS camera app that creates afterimage (shadow clone) effects on videos using Apple's Vision framework for real-time person segmentation.

[![App Store](https://img.shields.io/badge/App_Store-Available-blue?logo=apple)](https://apps.apple.com/jp/app/shadowclone-ai%E6%AE%8B%E5%83%8F%E3%82%AB%E3%83%A1%E3%83%A9/id6443941131)
[![Platform](https://img.shields.io/badge/Platform-iOS_15.0+-lightgrey?logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)](https://swift.org/)

## Features

- **Video Conversion** - 既存の動画を選択して残像エフェクトを適用 / Apply afterimage effects to existing videos from your photo library
- **Realtime Camera** - リアルタイムで残像エフェクトを適用しながら撮影 / Record with live afterimage effects using the camera
- **AI Person Segmentation** - Apple Vision による高精度な人物検出 / Accurate person detection powered by Apple Vision framework
- **Adjustable Settings** - 残像の間隔・数・AI品質を調整可能 / Customize interval, clone count, and AI quality level

## How It Works

1. カメラまたは動画から各フレームをキャプチャ
2. Vision フレームワーク (`VNGeneratePersonSegmentationRequest`) で人物マスクを生成
3. `CIBlendWithMask` で背景を透明化し人物のみを抽出
4. 過去N フレーム分の人物シルエットを `CISourceOverCompositing` で合成
5. 残像（分身）エフェクトとして表示・保存

## Requirements

- iOS 15.0+
- A11 Bionic chip or later (iPhone 8+, iPad 8th gen+) for Neural Engine acceleration
- Xcode 14.0+
- CocoaPods

## Setup

```bash
git clone https://github.com/ToshihideMatsuda/AfterImage.git
cd AfterImage
pod install
open ShadowClone.xcworkspace
```

> **Note:** Always open `.xcworkspace`, not `.xcodeproj`.

## Project Structure

```
AfterImage/
├── ViewController.swift              # ホーム画面 / Home screen
├── CameraViewController.swift        # リアルタイム撮影 / Live camera capture
├── VideoViewController.swift         # 動画変換処理 / Video file processing
├── CompositImageViewController.swift # 画像合成ベースクラス / Image composition base
├── Manager/
│   ├── AVCaptureManager.swift        # カメラ・オーディオ管理 / Camera & audio I/O
│   ├── VisionManager.swift           # 人物セグメンテーション / Person segmentation
│   └── StoreManager.swift            # アプリ内課金 / In-app purchases
├── Util/                             # ユーティリティ拡張 / Utility extensions
└── Resources/                        # ローカライゼーション / Localization strings
```

## Settings

| Setting | Range | Default | Description |
|---------|-------|---------|-------------|
| Interval (間隔) | 0.1–3.0s | 0.1s | フレーム追加間隔 / Time between afterimage frames |
| Clone Count (残像数) | 2–10 | 10 | 残像フレーム数 / Number of afterimage frames |
| AI Quality | Accurate / Balanced / Fast | Balanced | セグメンテーション品質 / Segmentation quality |

## Supported Languages

日本語, English, Español, Français, 简体中文 (+ regional variants)

## Tech Stack

- **UIKit** + **SwiftUI** (hybrid)
- **AVFoundation** - Camera capture & video processing
- **Vision** - `VNGeneratePersonSegmentationRequest` for person segmentation
- **CoreImage** - `CIFilter` pipeline for image composition
- **StoreKit** - In-app purchases
- **Google Mobile Ads SDK** - AdMob integration
- **CocoaPods** - Dependency management

## License

All rights reserved. This source code is provided for reference purposes.

## Author

Toshihide Matsuda ([@ToshihideMatsuda](https://github.com/ToshihideMatsuda))
