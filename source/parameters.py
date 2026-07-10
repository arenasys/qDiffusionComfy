import os
import re
import random
import copy
import json

import PIL.Image
import PIL.PngImagePlugin

from PyQt5.QtCore import pyqtSlot, pyqtProperty, pyqtSignal, QObject, Qt, QVariant, QSize
from PyQt5.QtQml import qmlRegisterUncreatableType, qmlRegisterType

IDX = -1

LABELS = [
    ("prompt", "Prompt"),
    ("negative_prompt", "Negative prompt"),
    ("steps", "Steps"),
    ("sampler", "Sampler"),
    ("scheduler", "Scheduler"),
    ("scale", "CFG scale"),
    ("seed", "Seed"),
    ("size", "Size"),
    ("model", "Model"),
    ("UNET", "UNET"),
    ("VAE", "VAE"),
    ("CLIP", "CLIP"),
    ("clip_type", "CLIP type"),
    ("model_mode", "Model mode"),
    ("mode", "Mode"),
    ("inputs", "Inputs"),
    ("strength", "Denoising strength"),
    ("upscaler", "Upscaler")
]

SETTABLE = [
    "size", "prompt", "negative_prompt", "steps", "sampler", "scheduler", "scale", "seed", "width", "height",
    "model", "UNET", "VAE", "CLIP", "clip_type", "model_mode", "model", "strength", "upscaler",
]

def formatParameters(json):
    if json == None:
        return ""
    
    json = copy.deepcopy(json)

    formatted = ""
    if "prompt" in json:
        formatted = json["prompt"] + "\n"
        formatted += "Negative prompt: " + json["negative_prompt"] + "\n"

    if "mode" in json:
        json["mode"] = json["mode"].capitalize().replace("Txt2img", "Txt2Img").replace("Img2img", "Img2Img")

    if "inputs" in json:
        json["inputs"] = " + ".join([i.capitalize().replace("Controlnet", "ControlNet") for i in json["inputs"]])

    json["size"] = f"{json['width']}x{json['height']}"

    params = []
    for k, label in LABELS:
        if k == "prompt" or k == "negative_prompt":
            continue
        if k in json:
            v = json[k]
            if type(v) == list:
                v = ", ".join([str(i) for i in v])

            params += [f"{label}: {v}"]
    formatted += ', '.join(params)
    return formatted

def parseParameters(formatted):
    params, positive, negative = "", "", ""

    blocks = re.split(r"^(?=[\w\s]+:)", "Prompt: "+formatted, flags=re.MULTILINE)
    for b in blocks:
        if not b:
            continue
        d = b.split(":",1)[-1].strip()
        if b.startswith("Prompt:"):
            positive = d
        if b.startswith("Negative prompt:"):
            negative = d
        if b.startswith("Steps:"):
            params = b
    
    json = {}
    json["prompt"] = positive
    json["negative_prompt"] = negative

    p = params.split(":")
    for i in range(1, len(p)):
        label = p[i-1].rsplit(",", 1)[-1].strip()
        if i == len(p)-1:
            value = p[i].strip()
        else:
            value = p[i].rsplit(",", 1)[0].strip()
        name = None
        for n, l in LABELS:
            if l == label:
                name = n
        if name:
            json[name] = value
    
    return json

def getParameters(img):
    params = img.text("parameters")
    if not params and img.text("Description"):
        desc = img.text("Description").replace("(","\\(").replace(")","\\)").replace("{","(").replace("}",")")
        data = json.loads(img.text("Comment"))
        uc = data['uc'].replace("(","\\(").replace(")","\\)").replace("{","(").replace("}",")")
        params = f"{desc}\nNegative prompt: {uc}\nSteps: {data['steps']}, Sampler: {data['sampler']}, CFG scale: {data['scale']}, Seed: {data['seed']}"
        if "strength" in data:
            params += f", Denoising strength: {data['strength']}"
    return params

def formatRecipe(metadata):
    if metadata == None:
        return ""

    checkpoint_recipe = metadata.get("merge_checkpoint_recipe","")
    lora_recipe = metadata.get("merge_lora_recipe","")
    lora_strength = metadata.get("merge_lora_strength","")
    if lora_recipe and lora_strength:
        recipe = {
            "type": "LoRA",
            "operations": lora_recipe,
            "strength": lora_strength
        }
    elif checkpoint_recipe:
        recipe = {
            "type": "Checkpoint",
            "operations": checkpoint_recipe
        }
    else:
        return ""
    
    return json.dumps(recipe)

def getIndex(folder):
    def get_idx(filename):
        try:
            return int(filename.split(".")[0].split("-")[0])
        except Exception:
            return 0

    idx = max([get_idx(f) for f in os.listdir(folder)] + [0]) + 1
    return idx

def getExtent(bound, padding, src, wrk):
    if padding == None or padding < 0:
        padding = 10240

    wrk_w, wrk_h = wrk
    src_w, src_h = src

    x1, y1, x2, y2 = bound

    ar = wrk_w/wrk_h
    cx,cy = x1 + (x2-x1)//2, y1 + (y2-y1)//2
    rw,rh = min(src_w, (x2-x1)+padding), min(src_h, (y2-y1)+padding)

    if wrk_w/rw < wrk_h/rh:
        w = rw
        h = int(w/ar)
        if h > src_h:
            h = src_h
            w = int(h*ar)
    else:
        h = rh
        w = int(h*ar)
        if w > src_w:
            w = src_w
            h = int(w/ar)

    x1 = cx - w//2
    x2 = cx + w - (w//2)

    if x1 < 0:
        x2 += -x1
        x1 = 0
    if x2 > src_w:
        x1 -= x2-src_w
        x2 = src_w

    y1 = cy - h//2
    y2 = cy + h - (h//2)

    if y1 < 0:
        y2 += -y1
        y1 = 0
    if y2 > src_h:
        y1 -= y2-src_h
        y2 = src_h

    return int(x1), int(y1), int(x2), int(y2)

class VariantMap(QObject):
    updating = pyqtSignal(str, 'QVariant', 'QVariant')
    updated = pyqtSignal(str)
    def __init__(self, parent=None, map = {}, strict=False):
        super().__init__(parent)
        self._map = map
        self._strict = strict

    @pyqtSlot(str, result='QVariant')
    def get(self, key, default=QVariant()):
        if key in self._map:
            return self._map[key]
        return default
    
    @pyqtSlot(str, 'QVariant')
    def set(self, key, value):
        if key in self._map and self._map[key] == value:
            return

        if key in self._map:
            if self._strict:
                try:
                    value = type(self._map[key])(value)
                except Exception:
                    pass
            self.updating.emit(key, self._map[key], value)
        else:
            self.updating.emit(key, QVariant(), value)

        self._map[key] = value
        self.updated.emit(key)

class ParametersItem(QObject):
    updated = pyqtSignal()
    def __init__(self, parent=None, name="", label="", value=""):
        super().__init__(parent)
        self._name = name
        self._label = label
        self._value = value
        self._checked = True

    @pyqtProperty(str, notify=updated)
    def name(self):
        return self._name

    @pyqtProperty(str, notify=updated)
    def label(self):
        return self._label
            
    @pyqtProperty(str, notify=updated)
    def value(self):
        return self._value

    @pyqtProperty(bool, notify=updated)
    def checked(self):
        return self._checked
    
    @checked.setter
    def checked(self, checked):
        self._checked = checked
        self.updated.emit()

class ParametersParser(QObject):
    updated = pyqtSignal()
    success = pyqtSignal()
    def __init__(self, parent=None, formatted=None, json=None):
        super().__init__(parent)
        self._parameters = []

        if formatted:
            self._formatted = formatted
            self.parseFormatted()
        else:
            self._formatted = ""

        if json:
            self._json = json
            self.parseJson()
        else:
            self._json = {}

    @pyqtProperty(str, notify=updated)
    def formatted(self):
        return self._formatted

    @formatted.setter
    def formatted(self, formatted):
        if formatted != self._formatted:
            self._formatted = formatted
            self.parseFormatted()
            
    @pyqtProperty(object, notify=updated)
    def json(self):
        return self._json

    @json.setter
    def json(self, json):
        if json != self._json:
            self._json = json
            self._parseJson()
    
    @pyqtProperty(list, notify=updated)
    def parameters(self):
        return self._parameters
    
    def parseFormatted(self):
        self._json = parseParameters(self._formatted)
        if len(self._json) == 2:
            return False

        self._parameters = []

        for n, v in self._json.items():
            l = None
            for name, label in LABELS:
                if name == n and name in SETTABLE:
                    l = label
                    break
            else:
                continue
            self._parameters += [ParametersItem(self, n, l, v)]

        reset = ParametersItem(self, "reset", "Reset others?", "")
        reset._checked = False

        self._parameters += [reset]

        self.updated.emit()

        if self._parameters != []:
            self.success.emit()
            return True
        else:
            return False
    
class Parameters(QObject):
    updated = pyqtSignal()
    def __init__(self, parent=None, source=None):
        super().__init__(parent)
        
        self.gui = parent
        if self.gui:
            self.gui.optionsUpdated.connect(self.optionsUpdated)

        self._client_only = [
            "models", "samplers", "UNETs", "CLIPs", "VAEs", "LoRAs", "LoRA",
            "device", "devices", "preview_modes", "schedulers",
            "network_modes", "model", "output_folder", 
            "model_types", "model_modes", "clip_types",
            "upscalers"
        ]

        self._adv_only = [
            
        ]
        self._default_values = {
            "prompt":"", "negative_prompt":"", "width": 512, "height": 512, "steps": 25, "scale": 7.0, "strength": 0.5, "seed": -1,
            "padding": -1, "mask_blur": 4, "mask_expand": 0,
            "sampler": "", "samplers":[], "model":"", "models":[], "UNET":"", "UNETs":[], "CLIP":"", "CLIPs":[], "VAE":"", "VAEs":[], "LoRA":[], "LoRAs":[],
            "upscaler": "default", "upscalers": ["default"],
            "device":"", "devices":[], "scheduler": "", "schedulers": [],
            "preview_mode": "Enabled", "preview_modes": ["Disabled", "Enabled"],
            "output_folder": "", "model_types": {},
            "model_mode": "checkpoint", "model_modes": ["checkpoint", "component"],
            "clip_type": "stable_diffusion", "clip_types": [],
        }

        if source:
            self._default_values = source._values._map.copy()

        self._values = VariantMap(self, self._default_values.copy(), strict=True)
        self._values.updating.connect(self.mapsUpdating)
        self._values.updated.connect(self.onUpdated)
        self._availableNetworks = []
        self._activeNetworks = []
        self._active = []

    def resolution(self):
        w, h = self.values.get("width"), self.values.get("height")
        return QSize(w,h)

    @pyqtSlot()
    def promptsChanged(self):
        positive = self._values.get("prompt")
        negative = self._values.get("negative_prompt")

        netre = r"<@?(lora):([^:>]+)(?::([-\d.]+))?(?::([-\d.]+))?>"

        nets = re.findall(netre, positive) + re.findall(netre, negative)
        self._activeNetworks = []
        for net in nets:
            for a in self._availableNetworks:
                if net[1] + "." in a:
                    self._activeNetworks += [a]
                    break
        self.updated.emit()

    @pyqtProperty(list, notify=updated)
    def availableNetworks(self):
        return self._availableNetworks

    @pyqtProperty(list, notify=updated)
    def activeNetworks(self):
        return self._activeNetworks
    
    @pyqtProperty(list, notify=updated)
    def active(self):
        return self._active
    
    @pyqtSlot(str)
    def addNetwork(self, net):
        if not net in self._availableNetworks:
            return
        if net in self._activeNetworks:
            return
        
        name = self.gui.modelName(net)        
        self._values.set("prompt", self._values.get("prompt") + f"<lora:{name}:1.0>")   

    @pyqtSlot(int)
    def deleteNetwork(self, index):
        net = self._activeNetworks[index]
        name = self.gui.modelName(net)

        netre = fr"(?:\s)?<@?(lora):({name})(?::([-\d.]+))?(?::([-\d.]+))?>"
        positive = re.sub(netre,'',self._values.get("prompt"))
        negative = re.sub(netre,'',self._values.get("negative_prompt"))

        self._values.set("prompt", positive)
        self._values.set("negative_prompt", negative)
    
    @pyqtProperty(VariantMap, notify=updated)
    def values(self):
        return self._values

    @pyqtSlot(str, 'QVariant', 'QVariant')
    def mapsUpdating(self, key, prev, curr):
        return

    @pyqtSlot(str)
    def onUpdated(self, key):
        self.getActive()

    @pyqtSlot()
    def optionsUpdated(self):
        if not self.gui._options:
            return

        for k in self.gui._options:
            kk = k + "s"
            if kk in self._values._map:
                opts = self.gui._options[k]
                if k == "upscaler":
                    opts = ["default"] + sorted(opts, key=lambda m: self.gui.modelName(m.lower()))
                    self._values.set(kk, opts)
                    if self._values.get(k) not in opts:
                        self._values.set(k, "default")
                    continue
                if k in {"UNET", "CLIP", "VAE", "LoRA"}:
                    opts = sorted(opts, key=lambda m: self.gui.modelName(m.lower()))
                self._values.set(kk, opts)
                if (not self._values.get(k) or not self._values.get(k) in self.gui._options[k]) and self.gui._options[k]:                   
                    if k in {"UNET", "CLIP", "VAE"} and self._values.get("model"):
                        self._values.set("model", "")
                    if k in self._default_values and self._default_values[k] in self.gui._options[k]:
                        self._values.set(k, self._default_values[k])
                    else:
                        self._values.set(k, self.gui._options[k][0])
        models = []
        for k in self.gui._options["UNET"]:
            if k in self.gui._options["CLIP"] and k in self.gui._options["VAE"]:
                models += [k]
        self._values.set("models", models)

        self._values.set("model_types", self.gui._options.get("model_types", {}))

        clip_types = self.gui._options.get("clip_mode", [])
        self._values.set("clip_types", clip_types)
        if not self._values.get("clip_type") and clip_types:
            self._values.set("clip_type", clip_types[0])

        self._values.set("model_modes", ["checkpoint", "component"])

        unets = self._values.get("UNETs")
        unets = [u for u in unets if not u in models] + [u for u in unets if u in models]
        self._values.set("UNETs", unets)

        vaes = self._values.get("VAEs")
        vaes = [v for v in vaes if not v in models] + [v for v in vaes if v in models]
        self._values.set("VAEs", vaes)

        clips = self._values.get("CLIPs")
        clips = [c for c in clips if not c in models] + [c for c in clips if c in models]
        self._values.set("CLIPs", clips)

        if models and (not self._values.get("model") or not self._values.get("model") in models):
            model = self.gui.filterFavourites(models)[0]
            self._values.set("model", model)
            self._values.set("UNET", model)
            self._values.set("VAE", model)
            self._values.set("CLIP", model)
            self.gui.getBasicTab().applyDefaults()

        self._availableNetworks = self._values.get("LoRAs")
        self._activeNetworks = [n for n in self._activeNetworks if n in self._availableNetworks]

        config = [
            ("device", "device", "devices"),
            ("previews", "preview_mode", "preview_modes"),
            ("output_folder", "output_folder", None)
        ]

        remote = self.gui.config.get("mode", "").lower() == "remote"
        for cfg, key, opts in config:
            val = self.gui.config.get(cfg, None)
            if val and (not opts or val in self._values.get(opts)):
                self._values.set(key, val)

        self._values.set("samplers", self._values.get("samplers"))

        self.updated.emit()

    def buildPrompts(self, batch_size=1, seed=-1):
        pos = self.parsePrompt(self._values._map['prompt'], batch_size, seed)
        neg = self.parsePrompt(self._values._map['negative_prompt'], batch_size, seed)
        return list(zip(pos, neg))

    def buildRequest(self, batch_size, seed, images=[], masks=[], areas=[], control=[]):
        request = {}
        data = {}

        for k, v in self._values._map.items():
            if not k in self._client_only:
                data[k] = v

        data['seed'] = seed

        if (data["steps"] == 0 or data["strength"] == 0.0) and images:
            request["type"] = "upscale"
            data["image"] = [images[0]]
            if any(masks):
                data["mask"] = [masks[0]]
        elif images:
            request["type"] = "img2img"
            data["image"] = [images[0]]
            if any(masks):
                data["mask"] = [masks[0]]
        else:
            request["type"] = "txt2img"

        if not request["type"] == "img2img":
            del data["mask_blur"]
            del data["mask_expand"]

        if data["padding"] == -1:
            del data["padding"]

        data["device_name"] = self._values.get("device")

        if request["type"] != "img2img" and "strength" in data:
            del data["strength"]

        data["preview"] = data["preview_mode"] == "Enabled"
        del data["preview_mode"]

        if request["type"] == "upscale":
            for k in list(data.keys()):
                if not k in {"width", "height", "image", "mask", "mask_blur", "padding", "device_name", "upscaler"}:
                    del data[k]

        # Remove upscaler from txt2img requests and when Default is selected.
        if request["type"] == "txt2img" or data.get("upscaler") == "default":
            data.pop("upscaler", None)

        # Model loading: checkpoint mode sends a single "checkpoint" key (the
        # UNET value, since all checkpoints are unets).  Component mode sends
        # unet/clip/vae/clip_type separately.
        model_mode = data.pop("model_mode", "checkpoint")
        if request["type"] != "upscale":
            if model_mode == "checkpoint":
                data["checkpoint"] = data.pop("UNET", "")
                for k in ("CLIP", "VAE", "clip_type"):
                    data.pop(k, None)
            else:
                data["clip_type"] = data.get("clip_type", "stable_diffusion")

        data = {k.lower():v for k,v in data.items()}

        request["data"] = data

        return request

    @pyqtSlot()
    def reset(self):
        pass

    @pyqtSlot(list)
    def sync(self, params):
        processed = {}

        for p in params:
            entries = {p._name: (p._value, p._checked)}

            if p._name == "size":
                w,h = p._value.split("x")

                entries = {
                    "width": (int(w), p._checked),
                    "height": (int(h), p._checked),
                }
            
            if p._name == "hr_resize":
                hr_w, hr_h = p._value.split("x")
                hr_w, hr_h = int(hr_w), int(hr_h)

                if "width" in processed and processed["width"][1]:
                    w,h = self.processed["width"][0], self.processed["height"][0]
                else:
                    w,h = self.values.get("width"), self.values.get("height")

                f = (((hr_w/w) + (hr_h/h))/2)
                f = int(f / 0.005) * 0.005

                entries = {
                    "hr_factor": (f, p._checked)
                }
            
            if p._name == "sampler":
                if p._value in self._values._map["samplers"]:
                    entries = {
                        "sampler": (p._value, p._checked),
                    }
                else:
                    del entries["sampler"]

            if p._name == "scheduler":
                if p._value in self._values._map["schedulers"]:
                    entries = {
                        "scheduler": (p._value, p._checked),
                    }
                else:
                    del entries["scheduler"]
            
            if p._name == "model":
                entries = {
                    "UNET": (p._value, p._checked),
                    "CLIP": (p._value, p._checked),
                    "VAE": (p._value, p._checked)
                }
            
            for n in entries:
                processed[n] = entries[n]
        
        reset = processed["reset"][1]
        del processed["reset"]

        # Switch model mode based on which model keys were loaded: component
        # mode if UNET/CLIP/VAE keys are present, checkpoint mode otherwise.
        loaded_names = {p._name for p in params}
        if any(k in loaded_names for k in ("UNET", "CLIP", "VAE")):
            processed["model_mode"] = ("component", True)
        elif "model" in loaded_names:
            processed["model_mode"] = ("checkpoint", True)

        for k in ["UNET", "CLIP", "VAE"]:
            if not k in processed:
                continue

            value, checked = processed[k]

            a = k + "s"
            if not a in self._values._map:
                a = "UNETs"

            available = self._values._map[a]
            closest_match = self.gui.closestModel(value, available)
            processed[k] = (closest_match, checked)

        if not "model" in processed and "UNET" in processed:
            value, checked = processed["UNET"]
            processed["model"] = (value, checked)

        for k in ["upscaler"]:
            if not k in processed:
                continue

            value, checked = processed[k]
            available = self._values._map[k+"s"]
            if value in available:
                continue
            closest_match = self.gui.closestModel(value, available)
            if not closest_match and available:
                closest_match = available[0]
            processed[k] = (closest_match, checked)
        
        for name in SETTABLE:
            value = None

            if name in processed and processed[name][1]:
                value = processed[name][0]
            
            if value == None and reset:
                if name in self._default_values:
                    value = self._default_values.get(name)

            if value == None:
                continue

            try:
                value = type(self.values.get(name))(value)
                self.values.set(name, value)
            except Exception as e:
                pass

        self.updated.emit()

    def parsePrompt(self, prompt, batch_size, seed):
        wildcards = self.gui.wildcards._wildcards
        counter = self.gui.wildcards._counter
        prompts = []
        file_pattern = re.compile(r"@?__([^\s]+?)__(?!___)")
        inline_pattern = re.compile(r"{([^{}|]+(?:\|[^{}|]+)*)}")
        seed = random.randrange(2147483646) if seed == -1 else seed
        
        for i in range(batch_size):
            roll = random.Random(seed+i)

            sp = self.parseSubprompts(str(prompt))
            for j in range(len(sp)):
                p = sp[j]

                while m := inline_pattern.search(p):
                    p = list(p)
                    s,e = m.span(0)
                    options = m.group(1).split("|")
                    p[s:e] = roll.choice(options)
                    p = ''.join(p)

                while m := file_pattern.search(p):
                    s,e = m.span(0)
                    name = m.group(1)
                    p = list(p)
                    c = []
                    if name in wildcards:
                        if p[s] == "@":
                            if not name in counter:
                                counter[name] = 0
                            c = wildcards[name][counter[name]%len(wildcards[name])]
                            counter[name] += 1
                        else:
                            c = roll.choice(wildcards[name])
                    p[s:e] = c
                    p = ''.join(p)
                sp[j] = p
            prompts += [sp]
        return prompts
    
    def parseSubprompts(self, p):
        return [s.replace('\n','').replace('\r', '').strip() for s in re.split(r"\sAND\s", p + " ")]
    
    @pyqtProperty(list, notify=updated)
    def subprompts(self):
        p = self._values.get("prompt")
        p = self.parseSubprompts(p)
        if len(p) <= 1:
            return []
        return p[1:]

    @pyqtSlot()
    def getActive(self):
        last = set(self._active)
        self._active = []

        prompt = self._values.get("prompt") + " " + self._values.get("negative_prompt")

        for lora_match in re.findall(r"<@?lora:([^:>]+)([^>]+)?>", prompt):
            for lora in self._values.get("LoRAs"):
                if lora_match[0] == lora.rsplit(os.path.sep,1)[-1].rsplit(".",1)[0]:
                    self._active += [lora]

        for model in [self._values.get(m) for m in ["UNET", "VAE", "CLIP", "upscaler"]]:
            if model and not model in self._active:
                self._active += [model]

        if set(self._active) != last:
            self.updated.emit()

    @pyqtSlot(str)
    def doActivate(self, file, model_type=None):
        def append(s, key="prompt"):
            prompt = self._values.get(key)
            if prompt:
                s = ", " + s
            self._values.set(key, prompt + s)
        
        name = self.gui.modelName(file)

        if file in self._values.get("LoRAs"):
            append(f"<lora:{name}>")
            return

        if file in self._values.get("upscalers"):
            self._values.set("upscaler", file)
            return

        if model_type == "checkpoint":
            self._values.set("model_mode", "checkpoint")
            self._values.set("UNET", file)
            self._values.set("CLIP", file)
            self._values.set("VAE", file)
        else:
            self._values.set("model_mode", "component")
            for m in ["UNET", "VAE", "CLIP"]:
                opts = self._values.get(m + "s")
                if file in opts:
                    self._values.set(m, file)
                else:
                    self._values.set(m, opts[0])
        
    @pyqtSlot(str)
    def doDeactivate(self, file):
        def remove(m):
            m = fr"(,*\s*{m})"
            c = r"(^,*\s*)|(,*\s*$)"
            pos = re.sub(c,'',re.sub(m,'',self._values.get("prompt")))
            neg = re.sub(c,'',re.sub(m,'',self._values.get("negative_prompt")))
            self._values.set("prompt", pos)
            self._values.set("negative_prompt", neg)
        
        name = self.gui.modelName(file)

        if file in self._values.get("VAEs"):
            self._values.set("VAE", self._values.get("UNET"))

        if file in self._values.get("LoRAs"):
            remove(fr"<@?lora:({re.escape(name)})(?::([-\d.]+))?(?::([-\d.]+))?>")

        if file == self._values.get("upscaler"):
            self._values.set("upscaler", "default")

    @pyqtSlot(str, str)
    def doToggle(self, file, model_type=None):
        if file in self._active:
            self.doDeactivate(file)
        else:
            self.doActivate(file, model_type)
        
        self.getActive()

    def copy(self):
        out = Parameters(None, self)
        out.gui = self.gui
        return out
        
def registerTypes():
    qmlRegisterUncreatableType(Parameters, "gui", 1, 0, "ParametersMap", "Not a QML type")
    qmlRegisterUncreatableType(VariantMap, "gui", 1, 0, "VariantMap", "Not a QML type")
    qmlRegisterUncreatableType(ParametersItem, "gui", 1, 0, "ParametersItem", "Not a QML type")
    qmlRegisterType(ParametersParser, "gui", 1, 0, "ParametersParser")