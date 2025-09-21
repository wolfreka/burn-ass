# burn-ass

一个跨平台脚本，使用 **FFmpeg** 将 `.ass` 字幕**硬烧**进视频。

- **Windows**：脚本自带 `ffmpeg/` 文件夹（无需另装）。
- **Linux/macOS**：使用系统安装的 `ffmpeg`（用户通过包管理器安装）。

功能特性：

- 两遍编码（2-pass ABR），自动读取源片视频码率，输出体积接近原片
- 音频直拷贝（不转码）
- 支持 H.264（libx264）/ H.265（libx265，可选）
- 支持指定 `fontsdir`（libass 字体目录）
- Linux/macOS 支持**批量同名处理**（`foo.mp4` + `foo.ass` → `foo.hardsub.mp4`）
- 输出实时进度（`frame/fps/size/time/bitrate/speed`）

------

## 目录结构

```
project-root/
├─ README.md
├─ burn-ass.ps1         # Windows (PowerShell)
├─ burn-ass.sh          # Linux/macOS (Bash)
└─ ffmpeg/              # 仅 Windows 使用；Linux/macOS 忽略此目录
   ├─ ffmpeg.exe
   └─ ffprobe.exe
```

> Windows 版脚本会固定调用脚本同级的 `ffmpeg\ffmpeg.exe` 与 `ffmpeg\ffprobe.exe`。
> Linux/macOS 版脚本直接调用系统里的 `ffmpeg/ffprobe`。

------

## Windows（PowerShell）

### 准备

- 确保 `ffmpeg\ffmpeg.exe` 与 `ffmpeg\ffprobe.exe` 位于脚本同级的 `ffmpeg\` 目录中（仓库已自带）。
- 建议在 **PowerShell 7+** 下执行（Windows PowerShell 5 也可）。

### 单文件用法

```powershell
cd <脚本所在目录>
# 硬烧 ASS 字幕
.\burn-ass.ps1 -In "input.mp4" -Ass "subtitle.ass"

# 硬烧 SRT 字幕
.\burn-ass.ps1 -In "input.mp4" -Ass "subtitle.srt"

# 硬烧 LRC 歌词
.\burn-ass.ps1 -In "mv.mp4" -Ass "lyrics.lrc"
```

### 常用参数

- `-Out "output.mp4"`：指定输出文件名（默认生成 `input.hardsub.mp4`）
- `-Hevc`：使用 H.265（libx265），更慢、体积通常更小
- `-Preset slower`：更慢预设，目标码率贴合更好（可用 `slow/slower/veryslow`）
- `-FontsDir "C:\Windows\Fonts"`：指定字体目录（ASS 中用到的字体不在系统时可设置）

> 提示：如果输出体积偏小，可尝试把 `-Preset` 调慢（`slower`/`veryslow`）。

------

## Linux / macOS（Bash）

### 安装 FFmpeg（系统级）

- Ubuntu/Debian：

  ```bash
  sudo apt update && sudo apt install -y ffmpeg
  ```

- CentOS/RHEL：

  ```bash
  sudo yum install -y ffmpeg
  ```

- macOS（Homebrew）：

  ```bash
  brew install ffmpeg
  ```

> 脚本会直接调用系统里的 `ffmpeg` 与 `ffprobe`，**不会**使用项目目录的 `ffmpeg/`。

### 赋予执行权限

```bash
chmod +x burn-ass.sh
# 硬烧 ASS 字幕
./burn-ass.sh -i input.mp4 -s subtitle.ass

# 硬烧 SRT 字幕
./burn-ass.sh -i input.mp4 -s subtitle.srt

# 硬烧 LRC 歌词
./burn-ass.sh -i mv.mp4 -s lyrics.lrc
```

### 单文件用法

```bash
./burn-ass.sh -i input.mp4 -s subtitle.ass
```

### 批量同名处理（推荐把视频和同名 `.ass` 放在同一目录）

```bash
./burn-ass.sh -D ./videos
# 将处理 ./videos 下的 *.mp4|*.mkv|*.mov，
# 与同名 .ass 配对生成 *.hardsub.mp4
```

### 常用参数

- `--out output.mp4`：指定输出文件名
- `--hevc`：使用 H.265（libx265）
- `--preset slower`：更慢预设，目标码率贴合更好
- `--fontsdir /usr/share/fonts`：指定字体目录（Linux 通常无需设置，macOS 可指向自定义字体路径）
- `--vbv`：启用 VBV（含 `-maxrate/-bufsize`），码率更稳但平均码率可能略低于目标
- `--buf-factor N`：配合 `--vbv`：`bufsize = 目标码率 * N`（默认 2）

------

## 进度显示示例

```
=== Pass 1/2 ===
frame= 6945 fps=420 q=-1.0 Lsize= 213912KiB time=00:04:37.72 bitrate=6309.8kbits/s speed=17x

=== Pass 2/2 ===
frame= 6945 fps=132 q=-1.0 Lsize= 228287KiB time=00:04:37.72 bitrate=6733.9kbits/s speed=5.3x

Done ✓  Output: /path/to/input.hardsub.mp4
Size: 223M
```

------

## 支持的字幕格式

本工具调用 FFmpeg 的 `subtitles` 滤镜（基于 **libass**），因此支持多种外挂字幕文件：

- **ASS / SSA**：完整支持（特效、样式、字体等）
- **SRT (SubRip)**：常见的纯文本字幕，可直接使用，但样式固定（白字无特效）
- **LRC (歌词)**：支持时间轴+文本显示，适合 MV/卡拉OK
- **MicroDVD `.sub`**、**MPL2 `.mpl`**、**WebVTT `.vtt`** 等其他常见格式

### 注意事项

- **样式与特效**

  - `.ass` 保留完整样式，推荐优先使用
  - `.srt/.lrc` 等纯文本字幕会按 libass 默认字体渲染（通常是白色小字）
  - 如果需要自定义样式，建议先将 `.srt/.lrc` 转换为 `.ass`

- **编码**

  - 字幕文件需保存为 **UTF-8 编码**，否则可能出现中文乱码

- **外挂字幕 vs 内封字幕**

  - 本脚本支持 **外挂字幕文件**（磁盘上的 `.ass/.srt/.lrc`）

  - 对于 MKV/MP4 内封字幕轨道，可先用以下命令提取：

    ```bash
    ffmpeg -i input.mkv -map 0:s:0 subs.srt
    ```

    再用脚本进行硬烧

------

## 常见问题（FAQ）

**Q1：硬字幕能“无损”吗？**
 A：硬字幕是把文字/图形绘制进视频帧，必须重新编码，严格意义上不可能完全无损。脚本通过 **两遍 ABR** 让输出体积与清晰度尽量接近源片。

**Q2：字幕特效/字体丢失？**
 A：确保字幕使用到的字体已安装在系统；或在参数中指定 `FontsDir`/`--fontsdir` 到你的字体目录（libass 会按此目录查找）。

**Q3：输出体积与原片差异较大？**
 A：尝试更慢的编码预设（`slower`/`veryslow`）；或在 Linux/macOS 版添加 `--vbv --buf-factor 3` 提高码率稳定性；反之想更贴近目标大小可去掉 `--vbv`（默认即关闭）。

**Q4：macOS 提示权限问题？**
 A：确保脚本有执行权限：`chmod +x burn-ass.sh`。如遇 Gatekeeper 限制，右键“打开”或在“安全性与隐私”中允许。

------

## License

本项目基于 **MIT License** 开源。你可以自由使用、修改和分发本项目（包含商用），但需保留版权与许可声明。
