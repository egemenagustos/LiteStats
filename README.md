# LiteStats

A tiny, fast system monitor for the macOS menu bar.

LiteStats shows CPU, memory, network speed and SSD usage in a single menu bar item. It is written in plain Swift and AppKit, has no dependencies, and is built to stay out of the way: about 240 KB on disk, around 15 MB of memory, and well under 1% CPU.

[Türkçe](#türkçe)

```
(fan) 12%   (chip) 58%   1.2M ↑   (pie) 62%
                          340K ↓
```

Each metric has a small icon that reacts to load: the CPU fan spins faster as load rises, the network arrows flow while there is traffic, and the RAM chip and SSD pie fill with usage. The whole item is about 215 pt wide, so it fits next to the notch on a MacBook Air.

## Features

- **CPU** total load (user + system), aggregated over all cores
- **Memory** used, calculated the same way as Activity Monitor's "Memory Used"
- **Network** upload and download speed, plus totals since launch
- **SSD** usage percentage, with used and free space in GB in the menu, matching what Finder reports
- Animated icons that follow the load, which can be turned off (they also stop when "Reduce motion" is on)
- Each metric can be shown or hidden, or the menu bar can show a single metric only
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

1. Download `LiteStats.zip` from the [latest release](https://github.com/egemenagustos/LiteStats/releases/latest).
2. Unzip it and move `LiteStats.app` to `/Applications`.
3. The app is not notarized, so macOS will block the first launch. Either right-click the app and choose **Open**, or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/LiteStats.app
   ```

## Building from source

Requires Xcode 15 or later (or the matching command line tools).

```sh
git clone https://github.com/egemenagustos/LiteStats.git
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
- Icon animations are Core Animation layers, so they run in the render server and the app does no work per frame. Redrawing the item from a timer instead cost 2 to 4% CPU.
- The menu's detail rows are only refreshed while the menu is open.
- Buffers are reused between samples.

## Settings

All settings are available from the menu:

- **Show in Menu Bar**: CPU, Memory, Network, SSD
- **Menu Bar Layout**: All Metrics, or only CPU, Memory, Network or SSD
- **Animated Icons**
- **Update Interval**: 1 s, 2 s, 5 s
- **Language**: System, English, Türkçe
- **Launch at Login**

Settings are stored in `~/Library/Preferences/io.github.litestats.plist`.

## Project layout

```
Sources/LiteStats/
  main.swift              App entry point
  AppDelegate.swift       Status item, menu and update loop
  StatusBarView.swift     Menu bar icons, values and animations
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

LiteStats; CPU, bellek, ağ hızı ve SSD kullanımını tek bir menü çubuğu öğesinde, yüke göre hareket eden ikonlarla gösterir: CPU fanı yük arttıkça hızlanır, trafik varken ağ okları akar, bellek çipi ve SSD dilimi doluluğa göre dolar. Öğe yaklaşık 215 pt genişliğindedir, MacBook Air'de çentiğin yanına sığar. Saf Swift ve AppKit ile yazılmıştır, hiçbir bağımlılığı yoktur ve arka planda sessizce çalışmak için tasarlanmıştır: diskte yaklaşık 240 KB, bellekte yaklaşık 15 MB ve %1'in çok altında CPU.

### Özellikler

- **CPU**: tüm çekirdeklerin toplam yükü (kullanıcı + sistem)
- **Bellek**: Etkinlik Monitörü'ndeki "Kullanılan Bellek" ile aynı hesaplama
- **Ağ**: anlık yükleme ve indirme hızı, açılıştan beri toplam veri
- **SSD**: doluluk yüzdesi; kullanılan ve boş alan menüde GB olarak, Finder ile aynı değer
- Yüke göre hareket eden ikonlar; kapatılabilir ("Hareketi azalt" açıkken de durur)
- Her metrik ayrı ayrı gösterilip gizlenebilir ya da menü çubuğunda yalnızca tek metrik gösterilebilir
- 1, 2 veya 5 saniyelik yenileme aralığı
- İngilizce ve Türkçe, yeniden başlatmadan değiştirilebilir
- Girişte otomatik başlatma
- Apple silicon ve Intel için universal uygulama

### Neden?

[Stats](https://github.com/exelban/stats) harika bir uygulama ve çok daha fazlasını yapıyor: grafikler, sensörler, pil, GPU, Bluetooth, widget'lar. LiteStats ise sadece sayıları görmek isteyenler için. Boyut ve kaynak karşılaştırması için yukarıdaki tabloya bakabilirsiniz.

### Gereksinimler

macOS 13 Ventura veya üzeri.

### Kurulum

1. [Son sürümden](https://github.com/egemenagustos/LiteStats/releases/latest) `LiteStats.zip` dosyasını indirin.
2. Zip'i açın ve `LiteStats.app` dosyasını `/Applications` klasörüne taşıyın.
3. Uygulama Apple tarafından noter onaylı (notarized) olmadığı için macOS ilk açılışı engeller. Uygulamaya sağ tıklayıp **Aç** deyin ya da şu komutu çalıştırın:

   ```sh
   xattr -dr com.apple.quarantine /Applications/LiteStats.app
   ```

### Kaynaktan derleme

Xcode 15 veya üzeri (ya da ilgili komut satırı araçları) gerekir.

```sh
git clone https://github.com/egemenagustos/LiteStats.git
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
- İkon animasyonları Core Animation katmanlarıdır; render sunucusunda çalıştıkları için uygulama her karede iş yapmaz. Öğeyi zamanlayıcıyla yeniden çizmek %2-4 CPU harcıyordu.
- Menüdeki detay satırları yalnızca menü açıkken güncellenir.
- Ölçümler arasında bellek tamponları yeniden kullanılır.

### Ayarlar

Tüm ayarlar menüden yapılır:

- **Menü Çubuğunda Göster**: CPU, Bellek, Ağ, SSD
- **Menü Çubuğu Düzeni**: Tüm Metrikler ya da yalnızca CPU, Bellek, Ağ veya SSD
- **Animasyonlu İkonlar**
- **Yenileme Aralığı**: 1 sn, 2 sn, 5 sn
- **Dil**: Sistem, English, Türkçe
- **Girişte Başlat**

Ayarlar `~/Library/Preferences/io.github.litestats.plist` dosyasında saklanır.

### Lisans

MIT. Ayrıntılar için [LICENSE](LICENSE) dosyasına bakın.
