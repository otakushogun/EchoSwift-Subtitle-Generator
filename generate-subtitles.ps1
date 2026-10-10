<#
.SYNOPSIS
    Recursively generates SRT subtitles for TV episodes and video files using faster-whisper.

.DESCRIPTION
    Scans a target directory recursively for media files (.mkv, .mp4, .avi, etc.)
    and generates SRT subtitles using faster-whisper (default model: medium).
    If a subtitle file (.srt, .en.srt, etc.) already exists for an episode, it will be skipped.

.PARAMETER MediaFolder
    Path to the folder containing video or audio files. Defaults to current directory.

.PARAMETER ModelSize
    Whisper model size to use: tiny, base, small, medium, large-v3. Default: large-v3.

.PARAMETER Device
    Inference device: cuda, cpu, or auto. Default: auto.

.PARAMETER ComputeType
    Quantization / precision: float16, int8, int8_float16, float32, or default. Default: default.

.PARAMETER Language
    Language code (e.g. 'en', 'es'). If omitted, language is auto-detected.

.PARAMETER Force
    If specified, overwrites existing subtitle files.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File "E:\G Apps\Subtitle Generator PY\generate-subtitles.ps1" -MediaFolder "E:\Media\TV Shows"

.EXAMPLE
    .\generate-subtitles.ps1 -MediaFolder "E:\Media\TV Shows" -ModelSize "medium" -Device "cuda"
#>

param(
    [string]$MediaFolder = ".",
    [string]$ModelSize = "medium",
    [string]$Device = "auto",
    [string]$ComputeType = "default",
    [string]$Language = "",
    [switch]$Force
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Whisper Subtitle Generator (faster-whisper)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Target Directory : $MediaFolder" -ForegroundColor Yellow
Write-Host " Model Size       : $ModelSize" -ForegroundColor Yellow
Write-Host " Device           : $Device" -ForegroundColor Yellow
Write-Host " Compute Type     : $ComputeType" -ForegroundColor Yellow
if ($Language) {
    Write-Host " Language         : $Language" -ForegroundColor Yellow
} else {
    Write-Host " Language         : Auto-detect" -ForegroundColor Yellow
}
Write-Host "==========================================================" -ForegroundColor Cyan

$forceBool = if ($Force.IsPresent) { "True" } else { "False" }

$pythonCode = @"
import os
import sys
import site
import glob
from pathlib import Path

# Suppress Hugging Face symlink warning on Windows
os.environ["HF_HUB_DISABLE_SYMLINKS_WARNING"] = "1"

# Enable CUDA 12 & cuDNN DLL loading on Windows for NVIDIA pip packages
if sys.platform == "win32":
    site_dirs = site.getsitepackages()
    user_site = site.getusersitepackages()
    if isinstance(user_site, str):
        site_dirs.append(user_site)
    for s in site_dirs:
        for bin_dir in glob.glob(os.path.join(s, "nvidia", "*", "bin")):
            if os.path.exists(bin_dir):
                try:
                    os.add_dll_directory(bin_dir)
                except Exception:
                    pass
                os.environ["PATH"] = bin_dir + os.path.pathsep + os.environ.get("PATH", "")

# Fix for older versions of PyAV (av) package where av.open() doesn't accept metadata_errors
try:
    import av
    _orig_av_open = av.open
    def _patched_av_open(*args, **kwargs):
        try:
            return _orig_av_open(*args, **kwargs)
        except TypeError as e:
            if "metadata_errors" in str(e):
                kwargs.pop("metadata_errors", None)
                return _orig_av_open(*args, **kwargs)
            raise
    av.open = _patched_av_open
except Exception:
    pass

try:
    from faster_whisper import WhisperModel
except ImportError:
    print("Error: 'faster-whisper' is not installed in the active Python environment.", file=sys.stderr)
    print("Install it with: pip install faster-whisper", file=sys.stderr)
    sys.exit(1)

media_folder = r"$MediaFolder"
model_size = "$ModelSize"
device_setting = "$Device"
compute_setting = "$ComputeType"
language = "$Language" if "$Language" else None
force = $forceBool

target_dir = Path(media_folder).resolve()
if not target_dir.exists() or not target_dir.is_dir():
    print(f"Error: Target directory does not exist: {target_dir}", file=sys.stderr)
    sys.exit(1)

MEDIA_EXTS = {'.mkv', '.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.m2ts', '.mp3', '.wav', '.flac', '.m4a'}

print(f"Scanning '{target_dir}' recursively for media files...")

media_files = []
for p in target_dir.rglob("*"):
    if p.is_file() and p.suffix.lower() in MEDIA_EXTS:
        media_files.append(p)

media_files.sort()

if not media_files:
    print("No media files found.")
    sys.exit(0)

print(f"Found {len(media_files)} media file(s).")

def format_timestamp(seconds: float) -> str:
    millis = int(round(seconds * 1000))
    hours = millis // (3600 * 1000)
    millis %= (3600 * 1000)
    minutes = millis // (60 * 1000)
    millis %= (60 * 1000)
    secs = millis // 1000
    millis %= 1000
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"

to_process = []
skipped = 0

for media_path in media_files:
    stem = media_path.stem
    parent = media_path.parent
    
    srt_standard = parent / f"{stem}.srt"
    srt_en = parent / f"{stem}.en.srt"
    vtt = parent / f"{stem}.vtt"
    
    subtitle_exists = srt_standard.exists() or srt_en.exists() or vtt.exists()
    
    if subtitle_exists and not force:
        skipped += 1
    else:
        to_process.append((media_path, srt_standard))

print(f"Skipped {skipped} file(s) with existing subtitles.")

if not to_process:
    print("All episodes already have subtitles! Nothing to process.")
    sys.exit(0)

active_device = "cuda" if device_setting in ["auto", "cuda"] else "cpu"
active_compute = compute_setting if compute_setting != "default" else ("float16" if active_device == "cuda" else "int8")

print(f"\nLoading faster-whisper model '{model_size}' (device={active_device}, compute_type={active_compute})...")

try:
    model = WhisperModel(model_size, device=active_device, compute_type=active_compute)
except Exception as e:
    if active_device == "cuda":
        print(f"Warning: Could not initialize CUDA GPU model ({e}). Falling back to CPU...")
        active_device = "cpu"
        active_compute = "int8"
        model = WhisperModel(model_size, device="cpu", compute_type="int8")
    else:
        print(f"Error loading WhisperModel: {e}", file=sys.stderr)
        sys.exit(1)

print(f"\nStarting transcription for {len(to_process)} file(s)...\n" + "-" * 60)

for idx, (media_path, srt_out) in enumerate(to_process, start=1):
    rel_path = media_path.relative_to(target_dir)
    print(f"[{idx}/{len(to_process)}] Processing: {rel_path}")
    
    try:
        segments, info = model.transcribe(str(media_path), language=language, beam_size=5)
        segment_list = list(segments)
    except Exception as e:
        err_str = str(e)
        if ("cublas" in err_str.lower() or "cuda" in err_str.lower() or "cudnn" in err_str.lower()) and active_device != "cpu":
            print(f"  [CUDA error] {err_str}")
            print(f"  Switching to CPU engine...")
            active_device = "cpu"
            active_compute = "int8"
            try:
                model = WhisperModel(model_size, device="cpu", compute_type="int8")
                segments, info = model.transcribe(str(media_path), language=language, beam_size=5)
                segment_list = list(segments)
            except Exception as cpu_e:
                print(f"  [ERROR] CPU transcription failed for {media_path.name}: {cpu_e}\n", file=sys.stderr)
                continue
        else:
            print(f"  [ERROR] Failed to transcribe {media_path.name}: {e}\n", file=sys.stderr)
            continue

    print(f"  Detected Language: '{info.language}' (confidence: {info.language_probability:.2f})")
    print(f"  Writing subtitle : {srt_out.name}")
    
    with open(srt_out, "w", encoding="utf-8") as f:
        for s_idx, segment in enumerate(segment_list, start=1):
            start_str = format_timestamp(segment.start)
            end_str = format_timestamp(segment.end)
            text = segment.text.strip()
            f.write(f"{s_idx}\n{start_str} --> {end_str}\n{text}\n\n")
            
    print("  Finished successfully!\n")

print("Batch transcription completed.")
"@

# Write Python code to temporary file and execute reliably
$tempPyFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "whisper_subtitles_temp.py")
Set-Content -Path $tempPyFile -Value $pythonCode -Encoding UTF8

try {
    & python $tempPyFile
} finally {
    if (Test-Path $tempPyFile) {
        Remove-Item $tempPyFile -Force -ErrorAction SilentlyContinue
    }
}