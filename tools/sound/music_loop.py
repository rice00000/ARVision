"""Cuts "Vaporware" (003_Vaporware.mp3 from OpenGameArt) into the seamless loop the Music module plays.

Run: python tools/sound/music_loop.py <003_Vaporware.mp3> modules/music/vaporware_loop.ogg
Bars are 3.2434 s from 1.73 s; the chords repeat every 4 bars, so bars 44-45 fade into bars 0-1 and the
loop goes on at bar 2 (loop_offset in the .import, printed below).
"""
import numpy as np, subprocess, soundfile as sf, pyloudnorm as pyln, sys
src, dst = sys.argv[1], sys.argv[2]
sr=44100
raw=subprocess.run(['ffmpeg','-v','error','-i',src,'-f','f32le','-ac','2','-ar',str(sr),'-'],capture_output=True).stdout
y=np.frombuffer(raw,np.float32).reshape(-1,2).astype(np.float64)
p,t0=3.2434,1.73
bar=lambda n:t0+p*n
S=1.55; L=bar(2); X=2*p; E=bar(46)
s=lambda t:int(round(t*sr))
out=y[s(S):s(E)].copy()
n=s(E)-s(E-X)
tt=np.linspace(0,1,n)[:,None]
tail=y[s(E-X):s(E)]*np.cos(tt*np.pi/2) + y[s(L-X):s(L-X)+n]*np.sin(tt*np.pi/2)
out[len(out)-n:]=tail
f=s(0.03); out[:f]*=np.linspace(0,1,f)[:,None]
off=s(L)-s(S)
print('loop offset', off/sr, 'length', len(out)/sr)
print('edge jump', np.abs(out[-1]-out[off]).max(), 'max step nearby', np.abs(np.diff(out[off-200:off+200],axis=0)).max())
m=pyln.Meter(sr); l=m.integrated_loudness(out); print('lufs before',l)
out*=10**((-18 - l)/20); print('peak',20*np.log10(np.abs(out).max()))
sf.write(dst+'.wav', out.astype(np.float32), sr, subtype='FLOAT'); subprocess.run(['ffmpeg','-v','error','-y','-i',dst+'.wav','-c:a','libvorbis','-q:a','6',dst],check=True); import os; os.remove(dst+'.wav')
print('written')
