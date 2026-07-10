## Qt GUI for ComfyUI
--------

For the \*new\* [comfy-inference-server](https://github.com/arenasys/comfy-inference-server) backend, built on [ComfyUI](https://github.com/comfy-org/comfyui).

Things to know:
- Primary goal is to get access to [ComfyUI](https://github.com/comfy-org/comfyui)'s extensive model support via my [qDiffusion](https://github.com/arenasys/qDiffusion) interface. 
- Only core functions kept: Txt2Img, Img2Img, Inpainting, Upscaling, LoRA, Previews, Prompt weighting + scheduling, and Model upload/download. Only core tabs kept: Generate, Explorer, History.
- qComfy is remote only, similar to ComfyUI itself except the UI is local. It requires running comfy-inference-server manually. You can run qComfy and comfy-inference-server on the same machine of course.
- comfy-inference-server requires a working ComfyUI install and venv. It will be using the code, venv and models from this install. NOTE that ComfyUI is blocked on most free compute platforms (Kaggle, Colab, etc).
- \*All\* models that ComfyUI can load and run in the standard manner are supported (Stable diffusion, Anima, ZImage, Krea2, etc). Meaning all models that load through normal means and run with a KSampler node.
- Supports Checkpoint mode (diffusion_model) or Component mode (diffusion_model + text_encoder + vae).
- Model subfolders recommended for organization, Ex. `Anima` folder inside the ComfyUI `lora` model folder. It will show up throughout qComfy.

![example](https://github.com/arenasys/qDiffusion/raw/master/source/screenshot.png)

### Install

Brief instruction for install to `~`, assumes ComfyUI is installed and working at `~/ComfyUI`, its venv at `~/ComfyUI/venv`, and its model folder at `~/ComfyUI/models`.

TLDR, run comfy-inference-server in the ComfyUI venv, make sure its requirements.txt are installed, point it at ComfyUI. And for qComfy, its the same as before but only Remote mode is accessible.

```
# INSTALL qComfy
cd ~
git clone https://github.com/arenasys/qComfy

# RUN qComfy
cd ~/qComfy
bash source/start.sh

# INSTALL comfy-inference-server
cd ~
git clone https://github.com/arenasys/comfy-inference-server
cd comfy-inference-server
. ~/ComfyUI/venv/bin/activate
pip install -r requirements.txt

# RUNNING comfy-inference-server
cd ~/comfy-inference-server
. ~/ComfyUI/venv/bin/activate
python server.py --comfyui ~/ComfyUI --bind 127.0.0.1:28888

# CONNECT qComfy to ws://127.0.0.1:28888
```

### Windows

For qComfy, download this repo and run the executable, should still work fine.
It can connect to any [comfy-inference-server](https://github.com/arenasys/comfy-inference-server), just change bind to 0.0.0.0:28888, etc.