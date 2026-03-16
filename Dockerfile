FROM python:3.10

RUN apt update && apt install -y git wget libgl1

WORKDIR /app

RUN git clone https://github.com/PropVRTWT/stable-diffusion.git .

RUN pip install --upgrade pip
RUN pip install -r requirements_versions.txt

# Pre-install CLIP and open_clip with --no-build-isolation so the build uses the
# main env's setuptools (avoids "No module named 'pkg_resources'" in pip's isolated build).
RUN pip install --no-build-isolation "https://github.com/openai/CLIP/archive/d50d76daa670286dd6cacf3bcd80b5e4823fc8e1.zip"
RUN pip install --no-build-isolation "https://github.com/mlfoundations/open_clip/archive/bb6e834e9c70d9c27d0dc3ecedeebeaeb1ffad6b.zip"

EXPOSE 8080

CMD ["python", "launch.py", "--listen", "--port", "8080", "--api"]