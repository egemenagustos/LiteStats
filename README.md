# LiteStats

A tiny, fast system monitor for the macOS menu bar.

LiteStats shows CPU, memory, network speed and SSD usage in a single menu bar item. It is written in plain Swift and AppKit, has no dependencies, and is built to stay out of the way: about 240 KB on disk, around 15 MB of memory, and well under 1% CPU.

[Türkçe](#türkçe)

```
CPU 12%   RAM 58%   ↑ 1.2 MB/s ↓  340 KB/s   SSD 62% · 180 GB
```

## Features

- **CPU** total load (user + system), aggregated over all cores
- **Memory** used, calculated the same way as Activity Monitor's "Memory Used"
- **Network** upload and download speed, plus totals since launch
- **SSD** usage percentage and free space in GB, matching what Finder reports
- Each metric can be shown or hidden
- Update interval of 1, 2 or 5 seconds
- English and Turkish, switchable at runtime
- Launch at login
- Universal binary for Apple silicon and Intel

## Why another one?

[Stats](https://github.com/exelban/stats) is excellent and does far more: charts, sensors, battery, GPU, Bluetooth, widgets. LiteStats is for people who only want the numbers.

|                     | LiteStats            | Stats                  |
| ------------------- | -------------------- | ---------------------- |
| App size            | ~240 KB              | ~18 MB                 |
| Memory footprint    | ~15 MB               | 100+ MB                |
| Frameworks          | AppKit only          | 11 bundled modules     |
| Menu bar items      | 1                    | 1 per module           |
| Charts and history  | No                   | Yes                    |
| Sensors, GPU, battery | No                 | Yes                    |

Measured on an Apple silicon Mac running macOS 27 with all four metrics visible.

## Requirements

macOS 13 Ventura or later.

## Installation

1. Download `LiteStats.zip` from the [latest release](https://github.com/egmnagsts/LiteStats/releases/latest).
2. Unzip it and move `LiteStats.app` to `/Applications`.
3. The app is not notarized, so macOS will block the first launch. Either right-click the app and choose **Open**, or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/LiteStats.app
   ```

## Building from source

Requires Xcode 15 or later (or the matching command line tools).

```sh
git clone https://github.com/egmnagsts/LiteStats.git
cd LiteStats
./scripts/build-app.sh
open build/LiteStats.app
```

The script builds a universal release binary, assembles `build/LiteStats.app`, signs it ad hoc, and creates `build/LiteStats.zip` for distribution.

For quick iteration you can also run `swift run`, although launch at login only works from the `.app` bundle.

## How the numbers are measured

| Metric  | Source | Notes |
| ------- | ------ | ----- |
| CPU     | `host_statistics(HOST_CPU_LOAD_INFO)` | One call per update, difference of tick counters |
| Memory  | `host_statistics64(HOST_VM_INFO64)` | App memory + wired + compressed, same as Activity Monitor |
| Network | `sysctl(NET_RT_IFLIST2)` | 64-bit byte counters; only physical interfaces (`en*`, `pdp_ip*`) so VPN traffic is not counted twice |
| SSD     | `volumeAvailableCapacityForImportantUsage` | Startup volume; includes purgeable space, same as Finder |

Disk capacity is refreshed every 30 seconds and whenever the menu is opened, because it rarely changes and is the most expensive query.

## Performance notes

- One timer drives everything, with tolerance so macOS can coalesce wakeups.
- The status item has a fixed width, computed from the widest possible text. A variable-width item forces the whole menu bar to relayout on every update; fixing the width alone cut CPU usage by about 85%.
- The menu bar text is drawn directly with Core Text instead of through `NSButtonCell`.
- The menu's detail rows are only refreshed while the menu is open.
- Buffers are reused between samples.

## Settings

All settings are available from the menu:

- **Show in Menu Bar**: CPU, Memory, Network, SSD
- **Update Interval**: 1 s, 2 s, 5 s
- **Language**: System, English, Türkçe
- **Launch at Login**

Settings are stored in `~/Library/Preferences/io.github.litestats.plist`.

## Project layout

```
Sources/LiteStats/
  main.swift              App entry point
  AppDelegate.swift       Status item, menu and update loop
  StatusTextView.swift    Menu bar text rendering
  Monitors/               CPU, memory, network and disk readers
  Settings.swift          User preferences
  L10n.swift              English and Turkish strings
  Format.swift            Number formatting
Resources/Info.plist
scripts/build-app.sh
```

## License

MIT. See [LICENSE](LICENSE).

---

## Türkçe

macOS menü çubuğu için küçük ve hızlı bir sistem monitörü.

LiteStats; CPU, bellek, ağ hızı ve SSD kullanımını tek bir menü çubuğu öğesinde gösterir. Saf Swift ve AppKit ile yazılmıştır, hiçbir bağımlılığı yoktur ve arka planda sessizce çalışmak için tasarlanmıştır: diskte yaklaşık 240 KB, bellekte yaklaşık 15 MB ve %1'in çok altında CPU.

### Özellikler

- **CPU**: tüm çekirdeklerin toplam yükü (kullanıcı + sistem)
- **Bellek**: Etkinlik Monitörü'ndeki "Kullanılan Bellek" ile aynı hesaplama
- **Ağ**: anlık yükleme ve indirme hızı, açılıştan beri toplam veri
- **SSD**: doluluk yüzdesi ve GB cinsinden boş alan, Finder ile aynı değer
- Her metrik ayrı ayrı gösterilip gizlenebilir
- 1, 2 veya 5 saniyelik yenileme aralığı
- İngilizce ve Türkçe, yeniden başlatmadan değiştirilebilir
- Girişte otomatik başlatma
- Apple silicon ve Intel için universal uygulama

### Neden?

[Stats](https://github.com/exelban/stats) harika bir uygulama ve çok daha fazlasını yapıyor: grafikler, sensörler, pil, GPU, Bluetooth, widget'lar. LiteStats ise sadece sayıları görmek isteyenler için. Boyut ve kaynak karşılaştırması için yukarıdaki tabloya bakabilirsiniz.

### Gereksinimler

macOS 13 Ventura veya üzeri.

### Kurulum

1. [Son sürümden](https://github.com/egmnagsts/LiteStats/releases/latest) `LiteStats.zip` dosyasını indirin.
2. Zip'i açın ve `LiteStats.app` dosyasını `/Applications` klasörüne taşıyın.
3. Uygulama Apple tarafından noter onaylı (notarized) olmadığı için macOS ilk açılışı engeller. Uygulamaya sağ tıklayıp **Aç** deyin ya da şu komutu çalıştırın:

   ```sh
   xattr -dr com.apple.quarantine /Applications/LiteStats.app
   ```

### Kaynaktan derleme

Xcode 15 veya üzeri (ya da ilgili komut satırı araçları) gerekir.

```sh
git clone https://github.com/egmnagsts/LiteStats.git
cd LiteStats
./scripts/build-app.sh
open build/LiteStats.app
```

Script universal bir release derlemesi yapar, `build/LiteStats.app` paketini oluşturur, ad hoc imzalar ve dağıtım için `build/LiteStats.zip` dosyasını hazırlar.

### Değerler nasıl ölçülüyor

| Metrik | Kaynak | Not |
| ------ | ------ | --- |
| CPU    | `host_statistics(HOST_CPU_LOAD_INFO)` | Her güncellemede tek çağrı, tick sayaçlarının farkı |
| Bellek | `host_statistics64(HOST_VM_INFO64)` | Uygulama belleği + wired + sıkıştırılmış, Etkinlik Monitörü ile aynı |
| Ağ     | `sysctl(NET_RT_IFLIST2)` | 64-bit sayaçlar; yalnızca fiziksel arayüzler (`en*`, `pdp_ip*`), böylece VPN trafiği iki kez sayılmaz |
| SSD    | `volumeAvailableCapacityForImportantUsage` | Başlangıç diski; temizlenebilir alan dahil, Finder ile aynı |

Disk kapasitesi nadiren değiştiği ve en pahalı sorgu olduğu için 30 saniyede bir ve menü her açıldığında güncellenir.

### Performans

- Her şeyi tek bir zamanlayıcı yönetir; toleransı sayesinde macOS uyanmaları birleştirebilir.
- Menü çubuğu öğesinin genişliği sabittir ve olası en geniş metne göre bir kez hesaplanır. Değişken genişlik her güncellemede tüm menü çubuğunun yeniden yerleşmesine yol açar; yalnızca genişliği sabitlemek CPU kullanımını yaklaşık %85 azalttı.
- Menü çubuğu metni `NSButtonCell` yerine doğrudan Core Text ile çizilir.
- Menüdeki detay satırları yalnızca menü açıkken güncellenir.
- Ölçümler arasında bellek tamponları yeniden kullanılır.

### Ayarlar

Tüm ayarlar menüden yapılır:

- **Menü Çubuğunda Göster**: CPU, Bellek, Ağ, SSD
- **Yenileme Aralığı**: 1 sn, 2 sn, 5 sn
- **Dil**: Sistem, English, Türkçe
- **Girişte Başlat**

Ayarlar `~/Library/Preferences/io.github.litestats.plist` dosyasında saklanır.

### Lisans

MIT. Ayrıntılar için [LICENSE](LICENSE) dosyasına bakın.
