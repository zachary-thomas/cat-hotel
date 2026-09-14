"""Original synthesized purr and soft toy/bell sounds, using only the standard library."""
from pathlib import Path
import math
import random
import struct
import wave

destination = Path(__file__).resolve().parents[1] / "assets" / "audio"
rate = 22050
random.seed(197)

def write(name, duration, sound):
    values = []
    noise = 0.0
    for frame in range(int(duration * rate)):
        t = frame / rate
        noise = noise * 0.86 + random.uniform(-1, 1) * 0.14
        envelope = min(1, t / 0.18, (duration - t) / 0.35)
        sample = max(-0.9, min(0.9, sound(t, noise) * envelope))
        values.append(round(sample * 32767))
    with wave.open(str(destination / (name + ".wav")), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(struct.pack("<" + "h" * len(values), *values))

write("cat_purr", 4.0, lambda t, n: (0.22 * math.sin(2*math.pi*94*t) + 0.09*math.sin(2*math.pi*188*t) + n*0.3) * (0.4 + 0.6*max(0,math.sin(2*math.pi*25*t))) * (0.72 + 0.28*math.sin(2*math.pi*0.7*t)))
write("toy_rustle", 0.9, lambda t, n: n * 0.5 * math.exp(-t*4))
write("dinner_bell", 1.8, lambda t, n: (math.sin(2*math.pi*880*t) + 0.35*math.sin(2*math.pi*2354*t)) * math.exp(-t*3) * 0.3)
print("Generated original purr, toy and dinner-bell sounds.")
