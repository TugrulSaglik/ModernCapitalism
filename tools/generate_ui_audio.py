"""Original restrained PCM tones. No samples or third-party assets."""
import math, struct, wave
from pathlib import Path

root = Path(__file__).resolve().parents[1] / 'assets/audio'
root.mkdir(parents=True, exist_ok=True)
for name, notes in dict(click=[660], success=[523,784], error=[240,180], construction=[330,494,660], research=[523,659,784], tutorial=[587,784,988]).items():
    samples=[]
    duration=0.045 if name=='click' else 0.09
    for frequency in notes:
        for i in range(int(22050*duration)):
            t=i/22050
            envelope=min(1,t/0.008)*max(0,1-t/duration)**2
            samples.append(struct.pack('<h',int(7000*envelope*math.sin(2*math.pi*frequency*t))))
    with wave.open(str(root/(name+'.wav')),'wb') as f:
        f.setparams((1,2,22050,0,'NONE','not compressed'))
        f.writeframes(b''.join(samples))
