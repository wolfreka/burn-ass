# burn-ass （快速开始版）

## 📥 下载 & 准备

- **Windows 用户**
   解压本项目，目录下已有 `ffmpeg\ffmpeg.exe` 和 `ffprobe.exe`，无需额外安装。

- **Linux 用户**

  ```bash
  sudo apt install ffmpeg     # Ubuntu/Debian
  sudo yum install ffmpeg     # CentOS/RHEL
  ```

- **macOS 用户**

  ```bash
  brew install ffmpeg
  ```

------

## ▶️ 使用方法

### Windows

```powershell
cd <脚本所在目录>
.\burn-ass.ps1 -In "input.mp4" -Ass "subtitle.ass"
```

### Linux/macOS

```bash
chmod +x burn-ass.sh
./burn-ass.sh -i input.mp4 -s subtitle.ass
```

------

## ⚙️ 可选参数

- **输出文件名**
   `-Out "out.mp4"`（Windows）
   `--out out.mp4`（Linux/macOS）
- **使用 H.265**（更小体积）
   `-Hevc`（Windows）
   `--hevc`（Linux/macOS）
- **编码速度预设**
   `-Preset slower` 或 `--preset slower`
   （`slow/slower/veryslow`，越慢越省体积）
- **字体目录**
   `-FontsDir "C:\Windows\Fonts"`
   `--fontsdir /usr/share/fonts`

------

## 📊 示例输出

```
=== Pass 1/2 ===
frame= 6945 fps=420 q=-1.0 Lsize= 213912KiB time=00:04:37.72 bitrate=6309.8kbits/s speed=17x

=== Pass 2/2 ===
frame= 6945 fps=132 q=-1.0 Lsize= 228287KiB time=00:04:37.72 bitrate=6733.9kbits/s speed=5.3x

Done ✓  Output: ./input.hardsub.mp4
Size: 223 MB
```

------

## 💡 小提示

- 本脚本不仅支持 **`.ass`**，还可以直接硬烧 **`.srt`** 和 **`.lrc`** 等常见字幕/歌词文件。
- **推荐**先将 `.srt/.lrc` 转换为 `.ass`，以保留字体样式和特效。

