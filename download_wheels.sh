#!/bin/bash
# ============================================================
# Wan2GP Docker wheels 准备脚本
# 复用 LongLive 的 wheels + 下载 Wan2GP 特有依赖
# 使用方法: bash download_wheels.sh
# ============================================================

set -e

WAN2GP_DIR="$(cd "$(dirname "$0")" && pwd)"
WHEELS_DIR="$WAN2GP_DIR/wheels"
LONGLIVE_WHEELS="/mnt/d/MyWork/Project/My/LongLive/wheels"

echo "============================================"
echo "  Wan2GP Docker wheels 准备"
echo "  目标: $WHEELS_DIR"
echo "  LongLive wheels: $LONGLIVE_WHEELS"
echo "============================================"
echo ""

# 创建 wheels 目录
mkdir -p "$WHEELS_DIR"

# ============================================================
# 步骤 1: 硬链接 LongLive 可复用的大型 wheels
# 硬链接不占额外磁盘空间，且 Docker 构建时能正确复制
# ============================================================
echo "--- 步骤 1: 硬链接 LongLive 可复用 wheels ---"

LINK_COUNT=0
SKIP_COUNT=0

link_wheel() {
    local src="$1"
    local filename=$(basename "$src")
    local dest="$WHEELS_DIR/$filename"

    if [ -f "$src" ]; then
        if [ -e "$dest" ]; then
            # 已存在（可能是之前链接的或已下载的）
            SKIP_COUNT=$((SKIP_COUNT + 1))
        else
            cp -l "$src" "$dest" 2>/dev/null || cp "$src" "$dest"
            LINK_COUNT=$((LINK_COUNT + 1))
            echo "  [LINK] $filename"
        fi
    else
        echo "  [MISS] $filename (LongLive 中不存在)"
    fi
}

# PyTorch 核心
for f in "$LONGLIVE_WHEELS"/torch-2.9.1+cu128-*.whl \
         "$LONGLIVE_WHEELS"/torchvision-0.24.1+cu128-*.whl \
         "$LONGLIVE_WHEELS"/torchaudio-2.9.1+cu128-*.whl; do
    [ -f "$f" ] && link_wheel "$f"
done

# NVIDIA CUDA cu12 全家桶
for f in "$LONGLIVE_WHEELS"/nvidia_*_cu12-*.whl; do
    [ -f "$f" ] && link_wheel "$f"
done

# triton + torchao
for f in "$LONGLIVE_WHEELS"/triton-*.whl \
         "$LONGLIVE_WHEELS"/torchao-*.whl; do
    [ -f "$f" ] && link_wheel "$f"
done

# flash-attn
for f in "$LONGLIVE_WHEELS"/flash_attn-*.whl; do
    [ -f "$f" ] && link_wheel "$f"
done

# PyTorch 基础依赖
for f in "$LONGLIVE_WHEELS"/setuptools-*.whl \
         "$LONGLIVE_WHEELS"/filelock-*.whl \
         "$LONGLIVE_WHEELS"/fsspec-*.whl \
         "$LONGLIVE_WHEELS"/jinja2-*.whl \
         "$LONGLIVE_WHEELS"/markupsafe-*.whl \
         "$LONGLIVE_WHEELS"/mpmath-*.whl \
         "$LONGLIVE_WHEELS"/networkx-*.whl \
         "$LONGLIVE_WHEELS"/sympy-*.whl \
         "$LONGLIVE_WHEELS"/typing_extensions-*.whl; do
    [ -f "$f" ] && link_wheel "$f"
done

# ML/AI 核心库
for f in "$LONGLIVE_WHEELS"/diffusers-*.whl \
         "$LONGLIVE_WHEELS"/transformers-*.whl \
         "$LONGLIVE_WHEELS"/tokenizers-*.whl \
         "$LONGLIVE_WHEELS"/accelerate-*.whl \
         "$LONGLIVE_WHEELS"/safetensors-*.whl \
         "$LONGLIVE_WHEELS"/huggingface_hub-*.whl \
         "$LONGLIVE_WHEELS"/sentencepiece-*.whl \
         "$LONGLIVE_WHEELS"/einops-*.whl \
         "$LONGLIVE_WHEELS"/timm-*.whl \
         "$LONGLIVE_WHEELS"/peft-*.whl; do
    [ -f "$f" ] && link_wheel "$f"
done

# 图像/视频/音频处理
for f in "$LONGLIVE_WHEELS"/opencv_python-*.whl \
         "$LONGLIVE_WHEELS"/pillow-*.whl \
         "$LONGLIVE_WHEELS"/av-*.whl \
         "$LONGLIVE_WHEELS"/imageio-*.whl \
         "$LONGLIVE_WHEELS"/imageio_ffmpeg-*.whl \
         "$LONGLIVE_WHEELS"/scipy-*.whl \
         "$LONGLIVE_WHEELS"/numpy-*.whl \
         "$LONGLIVE_WHEELS"/matplotlib-*.whl \
         "$LONGLIVE_WHEELS"/scikit_image-*.whl; do
    [ -f "$f" ] && link_wheel "$f"
done

# Web/网络/工具库
for f in "$LONGLIVE_WHEELS"/requests-*.whl \
         "$LONGLIVE_WHEELS"/urllib3-*.whl \
         "$LONGLIVE_WHEELS"/certifi-*.whl \
         "$LONGLIVE_WHEELS"/charset_normalizer-*.whl \
         "$LONGLIVE_WHEELS"/idna-*.whl \
         "$LONGLIVE_WHEELS"/httpx-*.whl \
         "$LONGLIVE_WHEELS"/httpcore-*.whl \
         "$LONGLIVE_WHEELS"/h11-*.whl \
         "$LONGLIVE_WHEELS"/anyio-*.whl \
         "$LONGLIVE_WHEELS"/sniffio-*.whl \
         "$LONGLIVE_WHEELS"/pyyaml-*.whl \
         "$LONGLIVE_WHEELS"/pydantic-*.whl \
         "$LONGLIVE_WHEELS"/pydantic_core-*.whl \
         "$LONGLIVE_WHEELS"/annotated_types-*.whl \
         "$LONGLIVE_WHEELS"/tqdm-*.whl \
         "$LONGLIVE_WHEELS"/rich-*.whl \
         "$LONGLIVE_WHEELS"/click-*.whl \
         "$LONGLIVE_WHEELS"/packaging-*.whl \
         "$LONGLIVE_WHEELS"/regex-*.whl \
         "$LONGLIVE_WHEELS"/ftfy-*.whl \
         "$LONGLIVE_WHEELS"/wcwidth-*.whl \
         "$LONGLIVE_WHEELS"/psutil-*.whl \
         "$LONGLIVE_WHEELS"/platformdirs-*.whl \
         "$LONGLIVE_WHEELS"/decorator-*.whl \
         "$LONGLIVE_WHEELS"/attrs-*.whl \
         "$LONGLIVE_WHEELS"/multidict-*.whl \
         "$LONGLIVE_WHEELS"/frozenlist-*.whl \
         "$LONGLIVE_WHEELS"/aiosignal-*.whl \
         "$LONGLIVE_WHEELS"/aiohappyeyeballs-*.whl \
         "$LONGLIVE_WHEELS"/aiohttp-*.whl \
         "$LONGLIVE_WHEELS"/propcache-*.whl \
         "$LONGLIVE_WHEELS"/yarl-*.whl; do
    [ -f "$f" ] && link_wheel "$f"
done

# 其他可能有用的包
for f in "$LONGLIVE_WHEELS"/omegaconf-*.whl \
         "$LONGLIVE_WHEELS"/hydra_core-*.whl \
         "$LONGLIVE_WHEELS"/easydict-*.whl \
         "$LONGLIVE_WHEELS"/xxhash-*.whl \
         "$LONGLIVE_WHEELS"/dill-*.whl \
         "$LONGLIVE_WHEELS"/multiprocess-*.whl \
         "$LONGLIVE_WHEELS"/datasets-*.whl \
         "$LONGLIVE_WHEELS"/pandas-*.whl \
         "$LONGLIVE_WHEELS"/pyarrow-*.whl \
         "$LONGLIVE_WHEELS"/fonttools-*.whl \
         "$LONGLIVE_WHEELS"/cycler-*.whl \
         "$LONGLIVE_WHEELS"/kiwisolver-*.whl \
         "$LONGLIVE_WHEELS"/pyparsing-*.whl \
         "$LONGLIVE_WHEELS"/python_dateutil-*.whl \
         "$LONGLIVE_WHEELS"/six-*.whl \
         "$LONGLIVE_WHEELS"/contourpy-*.whl \
         "$LONGLIVE_WHEELS"/tifffile-*.whl \
         "$LONGLIVE_WHEELS"/lazy_loader-*.whl \
         "$LONGLIVE_WHEELS"/networkx-*.whl; do
    [ -f "$f" ] && link_wheel "$f"
done

echo ""
echo "已链接: $LINK_COUNT 个, 跳过: $SKIP_COUNT 个"

# ============================================================
# 步骤 2: 下载 Wan2GP 特有依赖
# ============================================================
echo ""
echo "--- 步骤 2: 下载 Wan2GP 特有 wheels ---"
echo "（这一步需要联网，可能需要几分钟）"

# 创建临时 venv 用于 pip download
TEMP_VENV="/tmp/wan2gp_wheel_download"
python3 -m venv "$TEMP_VENV" 2>/dev/null || python -m venv "$TEMP_VENV"
source "$TEMP_VENV/bin/activate"

pip install --upgrade pip -q

# 下载 Wan2GP 特有包（只下载 wheel，不安装）
# 分批下载避免单次命令过长

echo "  [下载] 音频处理相关..."
pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    librosa==0.11.0 \
    sounddevice>=0.4.0 \
    soundfile \
    mutagen \
    pyloudnorm \
    speechbrain==1.0.3 \
    torchcodec==0.10.0 \
    2>/dev/null || echo "  ⚠️ 部分音频包下载失败"

echo "  [下载] Whisper + 音频分离..."
pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    openai-whisper==20250625 \
    audio-separator==0.36.1 \
    2>/dev/null || echo "  ⚠️ 部分 whisper 包下载失败"

echo "  [下载] Gradio UI..."
pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    gradio==5.29.0 \
    gradio_rangeslider \
    2>/dev/null || echo "  ⚠️ gradio 下载失败"

echo "  [下载] 视频/图像处理..."
pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    moviepy==1.0.3 \
    pygame>=2.1.0 \
    decord \
    rembg[gpu]==2.0.65 \
    segment-anything \
    2>/dev/null || echo "  ⚠️ 部分视频/图像包下载失败"

echo "  [下载] ONNX Runtime..."
pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    onnxruntime-gpu>=1.25.0 \
    2>/dev/null || pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    onnxruntime-gpu \
    2>/dev/null || echo "  ⚠️ onnxruntime-gpu 下载失败"

echo "  [下载] InsightFace + 人脸相关..."
pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    insightface==0.7.3 \
    facexlib==0.3.0 \
    2>/dev/null || echo "  ⚠️ insightface 下载失败"

echo "  [下载] Wan2GP 核心依赖..."
pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    mmgp==3.7.6 \
    num2words==0.5.14 \
    dashscope \
    loguru \
    ffmpeg-python \
    iopath>=0.1.10 \
    taichi \
    vector_quantize_pytorch==1.27.19 \
    torchdiffeq>=0.2.5 \
    tensordict>=0.6.1 \
    gguf==0.17.1 \
    2>/dev/null || echo "  ⚠️ 部分核心依赖下载失败"

echo "  [下载] flash-linear-attention..."
pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    flash-linear-attention==0.4.1 \
    2>/dev/null || echo "  ⚠️ flash-linear-attention 下载失败（可能需要从源码编译）"

echo "  [下载] 文本/NLP 工具..."
pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    misaki \
    phonemizer-fork \
    espeakng-loader \
    wetext==0.1.2 \
    markdown \
    munch \
    piexif \
    nvidia-ml-py \
    stringzilla==4.0.14 \
    2>/dev/null || echo "  ⚠️ 部分 NLP 包下载失败"

echo "  [下载] s3tokenizer + conformer + spacy..."
pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    s3tokenizer \
    conformer==0.3.2 \
    spacy_pkuseg \
    spacy \
    2>/dev/null || echo "  ⚠️ 部分 spacy 包下载失败"

echo "  [下载] 版本锁定包（强制指定版本）..."
pip download --dest "$WHEELS_DIR" --no-deps --only-binary=:all: \
    numpy==2.1.2 \
    transformers==4.54.0 \
    pydantic==2.10.6 \
    peft==0.17.0 \
    2>/dev/null || echo "  ⚠️ 部分版本锁定包下载失败"

# 清理冲突：删除 LongLive 的旧版本，保留 Wan2GP 指定版本
echo "  [清理] 删除 LongLive 中版本冲突的 wheels..."
for pkg in numpy transformers pydantic peft; do
    # 找到 Wan2GP 下载的实际文件（非硬链接目标）
    wanted=$(find "$WHEELS_DIR" -maxdepth 1 -name "${pkg}-[0-9]*.whl" -newer "$WHEELS_DIR" -print -quit 2>/dev/null)
    if [ -z "$wanted" ]; then
        # 如果找不到最新的，就找所有该包的文件
        wanted=$(find "$WHEELS_DIR" -maxdepth 1 -name "${pkg}-[0-9]*.whl" -print -quit 2>/dev/null)
    fi
    if [ -n "$wanted" ]; then
        wanted_name=$(basename "$wanted")
        # 删除该包的其他版本
        for f in "$WHEELS_DIR"/${pkg}-[0-9]*.whl; do
            if [ "$(basename "$f")" != "$wanted_name" ] && [ -f "$f" ]; then
                rm -f "$f" && echo "    [DEL] $(basename "$f") (旧版本)"
            fi
        done
    fi
done

echo "  [下载] GitHub wheel..."
curl -sL -o "$WHEELS_DIR/chumpy-0.71-py3-none-any.whl" \
    "https://github.com/deepbeepmeep/chumpy/releases/download/v0.71/chumpy-0.71-py3-none-any.whl" || echo "  ⚠️ chumpy 下载失败"
curl -sL -o "$WHEELS_DIR/smplfitter-0.2.10-py3-none-any.whl" \
    "https://github.com/deepbeepmeep/smplfitter/releases/download/v0.2.10/smplfitter-0.2.10-py3-none-any.whl" || echo "  ⚠️ smplfitter 下载失败"

# 清理临时 venv
deactivate
rm -rf "$TEMP_VENV"

# ============================================================
# 统计
# ============================================================
echo ""
echo "============================================"
TOTAL=$(find "$WHEELS_DIR" -name "*.whl" -o -name "*.tar.gz" | wc -l)
SYMLINKS=$(find "$WHEELS_DIR" -type l | wc -l)
REALFILES=$(find "$WHEELS_DIR" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$WHEELS_DIR" 2>/dev/null | cut -f1)
echo "  总计: $TOTAL 个文件"
echo "  硬链接(复用): $SYMLINKS 个（来自 LongLive，不占额外空间）"
echo "  新下载: $REALFILES 个（Wan2GP 特有）"
echo "  总大小: $TOTAL_SIZE"
echo "============================================"
echo ""
echo "完成！现在可以运行: docker-compose build"
