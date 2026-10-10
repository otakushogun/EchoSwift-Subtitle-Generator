# EchoSwift-Subtitle-Generator
This simple script comes with many parameters to control subititle generation for local video files.

# Whisper Subtitle Generator (faster-whisper)

A PowerShell + Python script that recursively scans folders containing TV show episodes or video files, detects speech using `faster-whisper`, and generates standard `.srt` subtitle files.

---

## Direct Execution Commands

### 1. Standard PowerShell Command
If running directly inside an open PowerShell window:

```powershell
.\generate-subtitles.ps1 -MediaFolder "E:\Media\TV Shows"
```

### 2. Command Prompt (CMD) or Shortcut Command
If executing from CMD, a desktop shortcut, or if PowerShell script execution is restricted on your system:

```cmd
powershell.exe -ExecutionPolicy Bypass -File "E:\G Apps\Subtitle Generator PY\generate-subtitles.ps1" -MediaFolder "E:\Media\TV Shows"
```

---

## Parameter Reference

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-MediaFolder` | String | `"."` (Current Dir) | Path to the directory containing TV episodes or videos. |
| `-ModelSize` | String | `"medium"` | Whisper model size: `tiny`, `base`, `small`, `medium`, `large-v3`. |
| `-Device` | String | `"auto"` | Hardware device to use: `auto`, `cuda`, or `cpu`. |
| `-ComputeType` | String | `"default"` | Precision mode: `float16`, `int8`, `int8_float16`, `float32`, or `default`. |
| `-Language` | String | `""` (Auto-detect) | Language code (e.g., `en` for English, `es` for Spanish). |
| `-Force` | Switch | `False` | Overwrite existing subtitle files even if they already exist. |

---

## Command Examples with Variables

### Specify GPU Acceleration (`cuda` + `float16`)
```cmd
powershell.exe -ExecutionPolicy Bypass -File "E:\G Apps\Subtitle Generator PY\generate-subtitles.ps1" -MediaFolder "E:\Media\TV Shows" -Device cuda -ComputeType float16
```

### Specify English Language (`en`)
```cmd
powershell.exe -ExecutionPolicy Bypass -File "E:\G Apps\Subtitle Generator PY\generate-subtitles.ps1" -MediaFolder "E:\Media\TV Shows" -Language en
```

### Overwrite Existing Subtitles (`-Force`)
```cmd
powershell.exe -ExecutionPolicy Bypass -File "E:\G Apps\Subtitle Generator PY\generate-subtitles.ps1" -MediaFolder "E:\Media\TV Shows" -Force
```

