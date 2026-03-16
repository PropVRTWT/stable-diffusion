FROM python:3.10

RUN apt update && apt install -y git wget libgl1

WORKDIR /app

RUN git clone https://github.com/PropVRTWT/stable-diffusion.git .

# Override with local modules (CompVis compat + CPU/no-CUDA safe).
COPY modules/sd_models.py /app/modules/sd_models.py
COPY modules/sd_hijack.py /app/modules/sd_hijack.py
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

EXPOSE 8080

CMD ["python", "launch.py", "--listen", "--port", "8080", "--api", "--skip-torch-cuda-test"]