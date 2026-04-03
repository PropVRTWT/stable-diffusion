FROM python:3.10

RUN apt update && apt install -y git wget libgl1

WORKDIR /app

RUN git clone https://github.com/PropVRTWT/stable-diffusion.git .

# Override with local modules (CompVis compat + CPU/no-CUDA safe).
COPY modules/sd_models.py /app/modules/sd_models.py
COPY modules/sd_hijack.py /app/modules/sd_hijack.py
COPY modules/sd_hijack_unet.py /app/modules/sd_hijack_unet.py
COPY modules/processing.py /app/modules/processing.py
COPY modules/devices.py /app/modules/devices.py

RUN pip install --upgrade pip
RUN pip install -r requirements_versions.txt

# Pre-install CLIP and open_clip with --no-build-isolation so the build uses the
# main env's setuptools (avoids "No module named 'pkg_resources'" in pip's isolated build).
RUN pip install --no-build-isolation "https://github.com/openai/CLIP/archive/d50d76daa670286dd6cacf3bcd80b5e4823fc8e1.zip"
RUN pip install --no-build-isolation "https://github.com/mlfoundations/open_clip/archive/bb6e834e9c70d9c27d0dc3ecedeebeaeb1ffad6b.zip"

# Stability-AI/stablediffusion is 404; use CompVis/stable-diffusion (same ldm structure). Set env so launch.py skips cloning.
ENV STABLE_DIFFUSION_REPO=https://github.com/CompVis/stable-diffusion.git
ENV STABLE_DIFFUSION_COMMIT_HASH=21f890f9da3cfbeaba8e2ac3c425ee9e998d5229

# Pre-clone repositories so launch.py does not need git at runtime (avoids "could not read Username" in containers).
# Commit hashes must match env/defaults so launch.py skips cloning.
RUN mkdir -p repositories && \
    git clone --config core.filemode=false https://github.com/AUTOMATIC1111/stable-diffusion-webui-assets.git repositories/stable-diffusion-webui-assets && \
    git -C repositories/stable-diffusion-webui-assets checkout 6f7db241d2f8ba7457bac5ca9753331f0c266917 && \
    git clone --config core.filemode=false https://github.com/CompVis/stable-diffusion.git repositories/stable-diffusion-stability-ai && \
    git -C repositories/stable-diffusion-stability-ai checkout 21f890f9da3cfbeaba8e2ac3c425ee9e998d5229 && \
    git clone --config core.filemode=false https://github.com/Stability-AI/generative-models.git repositories/generative-models && \
    git -C repositories/generative-models checkout 45c443b316737a4ab6e40413d7794a7f5657c19f && \
    git clone --config core.filemode=false https://github.com/crowsonkb/k-diffusion.git repositories/k-diffusion && \
    git -C repositories/k-diffusion checkout ab527a9a6d347f364e3d185ba6d714e22d80cb3c && \
    git clone --config core.filemode=false https://github.com/salesforce/BLIP.git repositories/BLIP && \
    git -C repositories/BLIP checkout 48211a1594f1321b00f14c9f7a5b4813144b2fb9 && \
    git clone --config core.filemode=false https://github.com/CompVis/taming-transformers.git repositories/taming-transformers

# CompVis/stable-diffusion ldm imports taming (VQModel etc.); make it importable at runtime.
ENV PYTHONPATH=/app/repositories/taming-transformers

# Clarity Upscaler: Tiled Diffusion + Tiled VAE extensions (optional; install from UI if this fails).
RUN apt install -y --no-install-recommends unzip && mkdir -p extensions && \
    (wget -q --no-check-certificate "https://github.com/pkuliyi2015/sd-webui-tiled-diffusion/archive/refs/heads/master.zip" -O /tmp/td.zip && \
     unzip -q -o /tmp/td.zip -d extensions && (mv extensions/sd-webui-tiled-diffusion-master extensions/sd-webui-tiled-diffusion 2>/dev/null || mv extensions/sd-webui-tiled-diffusion-main extensions/sd-webui-tiled-diffusion) && rm -f /tmp/td.zip) || true && \
    (wget -q --no-check-certificate "https://github.com/pkuliyi2015/sd-webui-tiled-vae/archive/refs/heads/master.zip" -O /tmp/tv.zip && \
     unzip -q -o /tmp/tv.zip -d extensions && (mv extensions/sd-webui-tiled-vae-master extensions/sd-webui-tiled-vae 2>/dev/null || mv extensions/sd-webui-tiled-vae-main extensions/sd-webui-tiled-vae) && rm -f /tmp/tv.zip) || true

# Clarity Upscaler: model dirs and optional pre-download (comment out wget lines to use a volume instead).
RUN mkdir -p models/Stable-diffusion models/ESRGAN models/Lora models/ControlNet embeddings
RUN wget -q -O models/Stable-diffusion/juggernaut_reborn.safetensors \
    "https://huggingface.co/dantea1118/juggernaut_reborn/resolve/main/juggernaut_reborn.safetensors" && \
    wget -q -O models/ESRGAN/4x-UltraSharp.pth \
    "https://huggingface.co/philz1337x/upscaler/resolve/main/4x-UltraSharp.pth" && \
    wget -q -O embeddings/JuggernautNegative-neg.pt \
    "https://huggingface.co/philz1337x/embeddings/resolve/main/JuggernautNegative-neg.pt" && \
    wget -q -O models/Lora/SDXLrender_v2.0.safetensors \
    "https://huggingface.co/philz1337x/loras/resolve/main/SDXLrender_v2.0.safetensors" && \
    wget -q -O models/Lora/more_details.safetensors \
    "https://huggingface.co/philz1337x/loras/resolve/main/more_details.safetensors" && \
    wget -q -O models/ControlNet/control_v11f1e_sd15_tile.pth \
    "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1e_sd15_tile.pth"

EXPOSE 8080

CMD ["python", "launch.py", "--listen", "--port", "8080", "--skip-torch-cuda-test"]