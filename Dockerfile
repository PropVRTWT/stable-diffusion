FROM python:3.10

RUN apt update && apt install -y git wget libgl1

WORKDIR /app

RUN git clone https://github.com/PropVRTWT/stable-diffusion.git .

RUN pip install --upgrade pip
RUN pip install -r requirements_versions.txt

EXPOSE 8080

CMD ["python", "launch.py", "--listen", "--port", "8080", "--api"]