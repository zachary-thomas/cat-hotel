"""Original Purrington soundtrack and cartoon Foley, generated reproducibly.
No samples or third-party compositions. 22.05 kHz PCM keeps phone memory modest.
"""
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
SR = 22050
rng = np.random.default_rng(7314)

def write(name, signal, peak=0.66):
    signal = np.asarray(signal)
    signal *= peak / max(peak, np.max(np.abs(signal)))
    pcm = np.round(np.clip(signal, -0.98, 0.98) * 32767).astype('<i2')
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
        out.setnchannels(1 if pcm.ndim == 1 else pcm.shape[1])
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(pcm.tobytes())
    print(f'{name}: {len(pcm)/SR:.2f}s, peak {np.abs(signal).max():.3f}, rms {np.sqrt(np.mean(signal**2)):.3f}')

def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)

def tone(midi, seconds, instrument='pluck'):
    t = np.arange(int(seconds * SR)) / SR
    f = hz(midi)
    if instrument == 'pad':
        result = (np.sin(2*np.pi*f*t) + .28*np.sin(2*np.pi*f*2*t) + .12*np.sin(2*np.pi*f*3*t))
        env = np.minimum(1, t/.35) * np.minimum(1, (seconds-t)/.7)
        return result * env * .13
    if instrument == 'bass':
        result = np.sin(2*np.pi*f*t) + .25*np.sin(2*np.pi*f*2*t)
        return result * (1-np.exp(-t*65)) * np.exp(-t*2.4) * .26
    result = sum((.65**h)*np.sin(2*np.pi*f*(h+1)*t)*np.exp(-t*(2.1+h*1.4)) for h in range(5))
    result += .1*np.sin(2*np.pi*f*2.76*t)*np.exp(-t*11)
    return result * (1-np.exp(-t*220)) * np.minimum(1,(seconds-t)/.08) * .30

def music(name, bpm, transpose=0):
    beat = 60 / bpm
    length = int(round(64 * beat * SR))
    song = np.zeros((length, 2))
    def add(signal, when, gain=1, pan=0):
        idx = (np.arange(len(signal)) + int(round(when*SR))) % length
        song[idx, 0] += signal * gain * np.sqrt((1-pan)/2)
        song[idx, 1] += signal * gain * np.sqrt((1+pan)/2)
    chords = [(50,54,57,61),(47,50,54,57),(43,47,50,54),(45,49,52,57),
              (50,54,57,61),(47,50,54,57),(43,47,50,54),(45,49,52,57),
              (43,47,50,54),(50,54,57,61),(47,50,54,57),(45,49,52,57),
              (43,47,50,54),(45,49,52,57),(50,54,57,61),(45,49,52,57)]
    # Original call-and-response melody; rests leave space for the cats and coins.
    melody = [[(0,74),(1.5,78),(2.5,76)],[(.5,73),(2,74)],[(0,71),(1,74),(3,78)],[(.5,76),(2.5,73)],
              [(0,74),(1,78),(2,81)],[(1,78),(2.5,74)],[(0,71),(2,69),(3,71)],[(1,73),(3,69)],
              [(0,74),(1.5,71)],[(.5,69),(2,66),(3,69)],[(0,71),(2,74),(3,73)],[(1,69),(2.5,73)],
              [(0,71),(1,74),(3,78)],[(.5,76),(2,73)],[(0,74),(2,69)],[(1,73),(3,76)]]
    for bar, chord in enumerate(chords):
        start = bar * 4 * beat
        for note in chord:
            add(tone(note+transpose, 4.7*beat, 'pad'), start, .25, -.15)
        for tick in range(8):
            note = chord[[0,2,1,3,0,2,1,2][tick]] + 12 + transpose
            add(tone(note, 1.6), start + tick*.5*beat, .27, -.35 if tick%2==0 else .35)
        for tick in [0,2]:
            add(tone(chord[0]-12+transpose, 1.5, 'bass'), start+tick*beat, .50, 0)
        for offset, note in melody[bar]:
            add(tone(note+transpose, 2.1), start+offset*beat, .60, .14)
        # A soft brushed pulse, rather than a prominent drum kit.
        for tick in [1,3]:
            t = np.arange(int(.16*SR))/SR
            noise = rng.normal(0,1,len(t))
            noise = np.convolve(noise, np.ones(7)/7, 'same')
            add(noise*np.exp(-t*28)*(1-np.exp(-t*200))*.027, start+tick*beat)
    # Wrapped delay tails make a musically continuous loop, including the seam.
    song += np.roll(song, int(.19*SR),axis=0)[:,::-1]*.14 + np.roll(song, int(.37*SR),axis=0)*.07
    write(name, song, .58)
    print('  loop sample discontinuity:', np.max(np.abs(song[-1]-song[0])))

music('meadow_lullaby', 80)
music('seaside_waltz', 88, 2)

def chimes(name, notes, interval, gain=.55):
    out = np.zeros(int((len(notes)*interval+1.0)*SR))
    for i,n in enumerate(notes):
        t = np.arange(int(.8*SR))/SR
        f = hz(n)
        sig = (np.sin(2*np.pi*f*t)*np.exp(-t*8) + .4*np.sin(2*np.pi*f*2.71*t)*np.exp(-t*14))
        sig *= np.minimum(1,t/.002)*gain
        start = int(i*interval*SR)
        out[start:start+len(sig)] += sig
    write(name, out)
chimes('coin_idle', [88,95], .055, .38)
chimes('coin_spend', [90,85,81], .055)
chimes('coin_collect', [81,85,88,93,97,100], .07)
chimes('hotel_open', [74,78,81,86], .14)
chimes('room_built', [69,74,78,81,86], .10)
chimes('ui_tap', [81], .02, .22)

for variant in range(3):
    duration = [.63,.84,.72][variant]
    t = np.arange(int(duration*SR))/SR
    u = t/duration
    pitch = np.interp(u,[0,.12,.30,.63,1],[530,730,790,540,370])*(1+variant*.055)
    pitch *= 1 + .018*np.sin(2*np.pi*6*t)
    phase = np.cumsum(pitch)/SR*2*np.pi
    f1 = np.interp(u,[0,.3,.65,1],[1000,1500,850,480])
    f2 = np.interp(u,[0,.4,1],[2600,2100,1000])
    voice = np.zeros_like(t)
    for h in range(1,11):
        spectral = .13/h + np.exp(-.5*((h*pitch-f1)/350)**2)*.7 + np.exp(-.5*((h*pitch-f2)/500)**2)*.30
        voice += np.sin(phase*h)*spectral/h**.35
    breath = np.convolve(rng.normal(0,1,len(t)),np.ones(5)/5,'same')*.025
    envelope = np.minimum(1,t/.025)*np.minimum(1,(duration-t)/.19)*np.sin(np.pi*np.clip(u,0,1))**.4
    write(f'meow_{variant+1}', (voice+breath)*envelope*.26, .64)
