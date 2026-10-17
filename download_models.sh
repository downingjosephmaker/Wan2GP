#!/bin/bash
# ============================================================
# Wan2GP 模型下载 - hf-mirror 加速
# 适配 RTX 5090D 24GB: int8量化版 + 小模型bf16版
# 辅助文件由程序首次运行时自动下载，无需手动处理
# 使用方法: bash download_models.sh
# ============================================================

CKPTS="D:/MyWork/Project/My/Wan2GP/ckpts"
MIRROR="https://hf-mirror.com"
FAILED=0

download_file() {
    local url="$1"
    local dest="$2"
    local filename=$(basename "$dest")

    # 获取远程文件大小
    local remote_size=$(curl -sI -L "$url" 2>&1 | grep -i "^content-length:" | tail -1 | tr -d '\r\n' | awk '{print $2}')
    if [ -z "$remote_size" ]; then
        echo "[ERR!] 无法获取远程大小: $filename"
        FAILED=$((FAILED+1))
        return 1
    fi

    # 检查已存在文件
    if [ -f "$dest" ]; then
        local local_size=$(stat -c%s "$dest" 2>/dev/null || stat -f%z "$dest" 2>/dev/null)
        if [ "$local_size" = "$remote_size" ]; then
            echo "[DONE] $filename (已完整, $(numfmt --to=iec $remote_size 2>/dev/null || echo "$remote_size bytes"))"
            return 0
        else
            echo "[PART] $filename (本地: $local_size / 远程: $remote_size) 尝试续传..."
        fi
    else
        echo "[DOWN] $filename (目标: $(numfmt --to=iec $remote_size 2>/dev/null || echo "$remote_size bytes"))"
    fi

    # 下载（支持断点续传）
    curl -L -C - --retry 3 --retry-delay 5 --connect-timeout 30 -# -o "$dest" "$url" 2>&1
    local curl_exit=$?

    if [ $curl_exit -ne 0 ]; then
        echo "[FAIL] $filename (curl 退出码: $curl_exit)"
        FAILED=$((FAILED+1))
        return 1
    fi

    # 校验文件大小
    local final_size=$(stat -c%s "$dest" 2>/dev/null || stat -f%z "$dest" 2>/dev/null)
    if [ "$final_size" != "$remote_size" ]; then
        echo "[WARN] $filename 大小不匹配! 本地: $final_size != 远程: $remote_size"
        echo "       删除损坏文件以便下次重新下载..."
        rm -f "$dest"
        FAILED=$((FAILED+1))
        return 1
    fi

    local human_size=$(numfmt --to=iec $final_size 2>/dev/null || echo "$final_size bytes")
    echo "[OK!!] $filename ($human_size)"
    return 0
}

echo "============================================"
echo "  Wan2GP 模型下载 - 24GB 显存适配版"
echo "  目标: $CKPTS"
echo "  镜像: $MIRROR"
echo "============================================"
echo ""

# ====== Wan 2.2 (int8 量化, mbf16 = mixed bf16) ======
echo "--- Wan 2.2 ---"
download_file "$MIRROR/DeepBeepMeep/Wan2.2/resolve/main/wan2.2_text2video_14B_high_quanto_mbf16_int8.safetensors" "$CKPTS/wan2.2_text2video_14B_high_quanto_mbf16_int8.safetensors"
download_file "$MIRROR/DeepBeepMeep/Wan2.2/resolve/main/wan2.2_text2video_14B_low_quanto_mbf16_int8.safetensors" "$CKPTS/wan2.2_text2video_14B_low_quanto_mbf16_int8.safetensors"
download_file "$MIRROR/DeepBeepMeep/Wan2.2/resolve/main/wan2.2_image2video_14B_high_quanto_mbf16_int8.safetensors" "$CKPTS/wan2.2_image2video_14B_high_quanto_mbf16_int8.safetensors"
download_file "$MIRROR/DeepBeepMeep/Wan2.2/resolve/main/wan2.2_image2video_14B_low_quanto_mbf16_int8.safetensors" "$CKPTS/wan2.2_image2video_14B_low_quanto_mbf16_int8.safetensors"
download_file "$MIRROR/DeepBeepMeep/Wan2.2/resolve/main/wan2.2_animate_14B_quanto_bf16_int8.safetensors" "$CKPTS/wan2.2_animate_14B_quanto_bf16_int8.safetensors"

# ====== Hunyuan Video (int8 量化) ======
echo "--- Hunyuan Video ---"
download_file "$MIRROR/DeepBeepMeep/HunyuanVideo/resolve/main/hunyuan_video_720_quanto_int8.safetensors" "$CKPTS/hunyuan_video_720_quanto_int8.safetensors"
download_file "$MIRROR/DeepBeepMeep/HunyuanVideo/resolve/main/hunyuan_video_custom_720_quanto_bf16_int8.safetensors" "$CKPTS/hunyuan_video_custom_720_quanto_bf16_int8.safetensors"
download_file "$MIRROR/DeepBeepMeep/HunyuanVideo/resolve/main/hunyuan_video_avatar_720_quanto_bf16_int8.safetensors" "$CKPTS/hunyuan_video_avatar_720_quanto_bf16_int8.safetensors"

# ====== LTX-2 (int8 量化) ======
echo "--- LTX-2 ---"
download_file "$MIRROR/DeepBeepMeep/LTX-2/resolve/main/ltx-2.3-22b-dev_diffusion_model_quanto_int8.safetensors" "$CKPTS/ltx-2.3-22b-dev_diffusion_model_quanto_int8.safetensors"
download_file "$MIRROR/DeepBeepMeep/LTX-2/resolve/main/ltx-2.3-22b-distilled_diffusion_model_quanto_int8.safetensors" "$CKPTS/ltx-2.3-22b-distilled_diffusion_model_quanto_int8.safetensors"

# ====== Flux (int8 量化) ======
echo "--- Flux ---"
download_file "$MIRROR/DeepBeepMeep/Flux/resolve/main/flux1-dev_quanto_bf16_int8.safetensors" "$CKPTS/flux1-dev_quanto_bf16_int8.safetensors"
download_file "$MIRROR/DeepBeepMeep/Flux2/resolve/main/flux2-dev_quanto_bf16_int8.safetensors" "$CKPTS/flux2-dev_quanto_bf16_int8.safetensors"

# ====== Kandinsky 5 ======
echo "--- Kandinsky 5 ---"
download_file "$MIRROR/DeepBeepMeep/Kandinsky5/resolve/main/kandinsky5lite_t2v_sft_5s_bf16.safetensors" "$CKPTS/kandinsky5lite_t2v_sft_5s_bf16.safetensors"
download_file "$MIRROR/DeepBeepMeep/Kandinsky5/resolve/main/kandinsky5pro_t2v_sft_5s_quanto_bf16_int8.safetensors" "$CKPTS/kandinsky5pro_t2v_sft_5s_quanto_bf16_int8.safetensors"

# ====== HiDream (int8) ======
echo "--- HiDream ---"
download_file "$MIRROR/DeepBeepMeep/HiDream/resolve/main/HiDreamO1Image_quanto_bf16_int8.safetensors" "$CKPTS/HiDreamO1Image_quanto_bf16_int8.safetensors"

# ====== Z-Image (6B 小模型) ======
echo "--- Z-Image ---"
download_file "$MIRROR/DeepBeepMeep/Z-Image/resolve/main/ZImageTurbo_bf16.safetensors" "$CKPTS/ZImageTurbo_bf16.safetensors"
download_file "$MIRROR/DeepBeepMeep/Z-Image/resolve/main/ZImageTurbo_quanto_bf16_int8.safetensors" "$CKPTS/ZImageTurbo_quanto_bf16_int8.safetensors"

# ====== LongCat (int8) ======
echo "--- LongCat ---"
download_file "$MIRROR/DeepBeepMeep/LongCat/resolve/main/longcat_avatar_single_quanto_bf16_int8.safetensors" "$CKPTS/longcat_avatar_single_quanto_bf16_int8.safetensors"

echo ""
echo "============================================"
if [ $FAILED -eq 0 ]; then
    echo "  全部下载完成!"
else
    echo "  完成! 但有 $FAILED 个文件失败"
fi
echo "============================================"
echo ""
echo "已下载文件:"
ls -lh "$CKPTS"/*.safetensors 2>/dev/null
