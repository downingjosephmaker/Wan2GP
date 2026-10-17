ARG CUDA_ARCHITECTURES="12.0"

# ============================================================
# Stage 1: 编译 SageAttention（需要 CUDA devel 头文件）
# ============================================================
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04 AS builder

ARG CUDA_ARCHITECTURES

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-dev python3-pip git cmake ninja-build \
    && rm -rf /var/lib/apt/lists/*

# 清华源加速 pip（Builder 阶段）
RUN mkdir -p /root/.config/pip && \
    printf '[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple\ntrusted-host = pypi.tuna.tsinghua.edu.cn\n' > /root/.config/pip/pip.conf

RUN pip install --upgrade pip setuptools wheel

# 安装 PyTorch（编译 SageAttention 需要）
RUN pip install --no-cache-dir torch==2.9.1+cu128 --index-url https://download.pytorch.org/whl/cu128

# 编译 SageAttention（patch GPU 检测，支持指定架构）
ENV TORCH_CUDA_ARCH_LIST="${CUDA_ARCHITECTURES}"
ENV FORCE_CUDA="1"
ENV MAX_JOBS="8"

COPY <<EOF /tmp/patch_setup.py
import os
with open('setup.py', 'r') as f:
    content = f.read()

arch_list = os.environ.get('TORCH_CUDA_ARCH_LIST')
arch_set = '{' + ', '.join([f'"{arch}"' for arch in arch_list.split(';')]) + '}'

old_section = '''compute_capabilities = set()
device_count = torch.cuda.device_count()
for i in range(device_count):
    major, minor = torch.cuda.get_device_capability(i)
    if major < 8:
        warnings.warn(f"skipping GPU {i} with compute capability {major}.{minor}")
        continue
    compute_capabilities.add(f"{major}.{minor}")'''

new_section = 'compute_capabilities = ' + arch_set + '''
print(f"Manually set compute capabilities: {compute_capabilities}")'''

content = content.replace(old_section, new_section)

with open('setup.py', 'w') as f:
    f.write(content)
EOF

COPY third_party/SageAttention /tmp/sageattention
RUN cd /tmp/sageattention && \
    python3 /tmp/patch_setup.py && \
    pip install --no-build-isolation .

# ============================================================
# Stage 2: 运行时（轻量镜像 + 复用 wheels）
# ============================================================
FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV HF_ENDPOINT=https://hf-mirror.com

# 清华源加速 apt
RUN sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/debian.sources

# 清华源加速 pip
RUN mkdir -p /root/.config/pip && \
    echo '[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple\ntrusted-host = pypi.tuna.tsinghua.edu.cn' > /root/.config/pip/pip.conf

WORKDIR /workspace

# 系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    git build-essential curl wget \
    libgl1 libglib2.0-0 libjpeg-dev zlib1g-dev libpng-dev libffi-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# 复制 wheels（含 LongLive 可复用的 + Wan2GP 特有的）
COPY wheels/ /tmp/wheels/

# ============================================================
# 步骤 1: 安装大型基础库（来自 LongLive wheels，离线安装）
# ============================================================
RUN pip install --no-cache-dir --no-deps \
    /tmp/wheels/torch-*.whl \
    /tmp/wheels/torchvision-*.whl \
    /tmp/wheels/torchaudio-*.whl

# NVIDIA CUDA 依赖 + PyTorch 基础库
RUN pip install --no-cache-dir --no-deps \
    /tmp/wheels/nvidia_cublas_cu12-*.whl \
    /tmp/wheels/nvidia_cuda_cupti_cu12-*.whl \
    /tmp/wheels/nvidia_cuda_nvrtc_cu12-*.whl \
    /tmp/wheels/nvidia_cuda_runtime_cu12-*.whl \
    /tmp/wheels/nvidia_cudnn_cu12-*.whl \
    /tmp/wheels/nvidia_cufft_cu12-*.whl \
    /tmp/wheels/nvidia_cufile_cu12-*.whl \
    /tmp/wheels/nvidia_curand_cu12-*.whl \
    /tmp/wheels/nvidia_cusolver_cu12-*.whl \
    /tmp/wheels/nvidia_cusparse_cu12-*.whl \
    /tmp/wheels/nvidia_cusparselt_cu12-*.whl \
    /tmp/wheels/nvidia_nccl_cu12-*.whl \
    /tmp/wheels/nvidia_nvjitlink_cu12-*.whl \
    /tmp/wheels/nvidia_nvshmem_cu12-*.whl \
    /tmp/wheels/nvidia_nvtx_cu12-*.whl \
    /tmp/wheels/triton-*.whl \
    /tmp/wheels/torchao-*.whl \
    /tmp/wheels/setuptools-*.whl \
    /tmp/wheels/filelock-*.whl \
    /tmp/wheels/fsspec-*.whl \
    /tmp/wheels/jinja2-*.whl \
    /tmp/wheels/markupsafe-*.whl \
    /tmp/wheels/mpmath-*.whl \
    /tmp/wheels/networkx-*.whl \
    /tmp/wheels/sympy-*.whl \
    /tmp/wheels/typing_extensions-*.whl

# flash-attn（RTX 5090 Blackwell sm_120）
RUN pip install --no-cache-dir --no-deps \
    /tmp/wheels/flash_attn-*.whl

# ============================================================
# 步骤 2: 批量安装所有剩余 wheels（离线，--no-deps）
# download_wheels.sh 已确保版本冲突的包只有正确版本
# ============================================================
RUN pip install --no-cache-dir --no-deps /tmp/wheels/*.whl

# ============================================================
# 步骤 3: 安装 Wan2GP 特有依赖（从 PyPI 下载）
# ============================================================
RUN pip install --no-cache-dir --timeout=1200 --retries=10 \
    mmgp==3.7.6 \
    gradio==5.29.0 \
    moviepy==1.0.3 \
    pygame>=2.1.0 \
    sounddevice>=0.4.0 \
    soundfile \
    mutagen \
    pyloudnorm \
    librosa==0.11.0 \
    speechbrain==1.0.3 \
    openai-whisper==20250625 \
    audio-separator==0.36.1 \
    torchcodec==0.10.0 \
    dashscope \
    loguru \
    num2words==0.5.14 \
    ffmpeg-python \
    gradio_rangeslider \
    segment-anything \
    rembg[gpu]==2.0.65 \
    onnxruntime-gpu>=1.25.0 \
    decord \
    iopath>=0.1.10 \
    insightface==0.7.3 \
    facexlib==0.3.0 \
    taichi \
    vector_quantize_pytorch==1.27.19 \
    hydra-core \
    easydict \
    torchdiffeq>=0.2.5 \
    tensordict>=0.6.1 \
    gguf==0.17.1 \
    flash-linear-attention==0.4.1 \
    piexif \
    nvidia-ml-py \
    misaki \
    phonemizer-fork \
    espeakng-loader \
    gitdb==4.0.12 \
    gitpython==3.1.45 \
    stringzilla==4.0.14 \
    xxhash \
    munch \
    wetext==0.1.2 \
    markdown \
    av \
    diffusers \
    smplfitter \
    ftfy \
    pycocotools

# s3tokenizer + conformer（Wan2GP 特有）
RUN pip install --no-cache-dir --timeout=1200 \
    s3tokenizer \
    conformer==0.3.2 \
    spacy_pkuseg \
    spacy

# pyannote.audio（需要特殊处理，可能需要 huggingface token）
RUN pip install --no-cache-dir --timeout=1200 \
    pyannote.audio==3.3.2 || echo "⚠️ pyannote.audio 安装失败（可能需要 huggingface token），跳过"

# sherpa-onnx
RUN pip install --no-cache-dir --timeout=1200 \
    sherpa-onnx==1.13.2 || echo "⚠️ sherpa-onnx 安装失败，跳过"

# 清理 wheels
RUN rm -rf /tmp/wheels

# ============================================================
# 从 builder 阶段复制编译好的 SageAttention
# ============================================================
COPY --from=builder /usr/local/lib/python3.10/dist-packages/sageattention /usr/local/lib/python3.12/site-packages/sageattention

# 创建非 root 用户
RUN useradd -u 1000 -ms /bin/bash user && \
    chown -R user:user /workspace && \
    mkdir -p /home/user/.cache && \
    chown -R user:user /home/user/.cache

COPY entrypoint.sh /workspace/entrypoint.sh

ENTRYPOINT ["/workspace/entrypoint.sh"]
