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
# 步骤 3: 按项目 requirements.txt 安装全部剩余依赖
# （torch/nvidia 系已在步骤 1-2 由 wheels 离线装好，requirements 未列 torch，不会覆盖）
# ============================================================
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --timeout=1200 --retries=10 \
    -r /tmp/requirements.txt

# requirements.txt 未锁 torch，pip 会把 torch 升级到 cu130（宿主驱动 12.8 不支持）；
# 重装 wheels 中锁定的 torch 2.9.1+cu128 与配套 nvidia/triton 库，覆盖 PyPI 版本
RUN pip install --no-cache-dir --no-deps \
    /tmp/wheels/torch-*.whl \
    /tmp/wheels/torchvision-*.whl \
    /tmp/wheels/torchaudio-*.whl \
    /tmp/wheels/nvidia_*.whl \
    /tmp/wheels/triton-*.whl

# diffusers 0.36.0 bug：环境中存在 torchao>=0.7 但缺少新版 dtype 布局模块时，
# 导入期触发未定义 logger 崩溃；上游 requirements 不含 torchao，对齐之。
# 同时构建期断言 torch 版本，防止依赖解析悄悄升级。
RUN pip uninstall -y torchao && \
    python -c "import diffusers.loaders.single_file_model; import torch; assert torch.__version__.startswith('2.9.1+cu128'), torch.__version__"

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
