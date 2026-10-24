class_name SoundSynth
extends RefCounted

## Builds the game's sounds as samples: soft, layered effects and a looping
## night-drive synth track (pad, bass, plucked arpeggio with echo, kick,
## snare and hat). Sine-based with envelopes, so nothing is harsh.

const RATE: int = 32000
const MUSIC_RATE: int = 22050
const BPM: float = 96.0
## Chords per bar (A minor): Am, F, C, G, then the same with a higher arpeggio.
const CHORDS: Array = [
	[220.0, 261.63, 329.63],
	[174.61, 220.0, 261.63],
	[261.63, 329.63, 392.0],
	[196.0, 246.94, 293.66],
]


static func effects() -> Dictionary:
	var sounds: Dictionary = {}
	sounds["boot"] = _make(1.6, func(t: float) -> float:
		var swell := minf(t / 0.7, 1.0) * (1.0 - t / 1.6)
		return swell * (0.5 * sin(TAU * 55.0 * t) + 0.25 * sin(TAU * 110.0 * t + 1.5 * sin(TAU * 2.0 * t)) + 0.12 * sin(TAU * 220.0 * t * (1.0 + t * 0.3))))
	sounds["glitch"] = _make(0.3, func(t: float) -> float:
		var gate := 1.0 if fmod(t * 31.0, 1.0) < 0.6 else 0.0
		var tone := sin(TAU * lerpf(900.0, 300.0, t / 0.3) * t)
		return gate * _crush(0.5 * tone + 0.3 * randf_range(-1.0, 1.0), 5) * (1.0 - t / 0.3) * 0.7)
	sounds["click"] = _make(0.05, func(t: float) -> float:
		return 0.4 * sin(TAU * 1500.0 * t) * exp(-t * 90.0))
	sounds["select"] = _make(0.14, func(t: float) -> float:
		var pitch := 660.0 if t < 0.06 else 990.0
		return 0.35 * (sin(TAU * pitch * t) + 0.25 * sin(TAU * pitch * 2.0 * t)) * exp(-fmod(t, 0.06) * 25.0) * (1.0 - t / 0.14))
	sounds["move"] = _make(0.4, _whoosh_wave(0.4, 0.5))
	sounds["teleport"] = _make(0.7, func(t: float) -> float:
		var pitch := lerpf(220.0, 1800.0, pow(t / 0.7, 1.8))
		return 0.4 * sin(TAU * pitch * t) * (0.7 + 0.3 * sin(TAU * 14.0 * t)) * sin(PI * t / 0.7))
	sounds["zap"] = _make(0.45, func(t: float) -> float:
		var crackle := randf_range(-1.0, 1.0) * (1.0 if randf() < 0.3 else 0.15)
		return (0.45 * crackle + 0.3 * sin(TAU * 1800.0 * t * (1.0 - t))) * exp(-t * 6.0))
	sounds["shot"] = _make(0.25, func(t: float) -> float:
		return 0.6 * randf_range(-1.0, 1.0) * exp(-t * 35.0) + 0.7 * sin(TAU * lerpf(220.0, 70.0, t / 0.25) * t) * exp(-t * 16.0))
	sounds["punch"] = _make(0.3, _impact_wave(0.3, 150.0, 45.0, 0.9))
	sounds["capture"] = _make(0.8, func(t: float) -> float:
		var thump := 0.8 * sin(TAU * lerpf(170.0, 38.0, minf(t / 0.5, 1.0)) * t) * exp(-t * 5.0)
		var crunch := _crush(randf_range(-1.0, 1.0), 4) * 0.4 * exp(-t * 18.0)
		var fall := 0.25 * sin(TAU * lerpf(700.0, 90.0, t / 0.8) * t) * exp(-t * 3.0)
		return thump + crunch + fall)
	sounds["signal"] = _make(1.1, func(t: float) -> float:
		var crack := randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.5
		var boom := sin(TAU * lerpf(110.0, 40.0, minf(t / 0.4, 1.0)) * t) * exp(-t * 6.0) * 0.7
		var ring := sin(TAU * 1320.0 * t) * exp(-t * 7.0) * 0.3
		var echo := sin(TAU * 1320.0 * (t - 0.25)) * exp(-(t - 0.25) * 7.0) * 0.14 if t > 0.25 else 0.0
		return crack + boom + ring + echo)
	sounds["emote"] = _make(0.22, func(t: float) -> float:
		var pitch := 1046.0 if t < 0.09 else 1568.0
		return 0.3 * sin(TAU * pitch * t) * exp(-fmod(t, 0.09) * 20.0))
	sounds["victory"] = _fanfare([523.25, 659.25, 783.99, 1046.5], 0.16, 1.1)
	sounds["defeat"] = _fanfare([392.0, 329.63, 261.63, 196.0], 0.24, 1.1)
	return sounds


## A looping track, built a slice per frame so start-up never stalls.
static func build_music(tree: SceneTree) -> AudioStreamWAV:
	var bar_seconds: float = 4.0 * 60.0 / BPM
	var seconds: float = bar_seconds * 8.0
	var count: int = int(seconds * MUSIC_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var noise_low: float = 0.0
	var index: int = 0
	while index < count:
		var end: int = mini(index + 3000, count)
		for i: int in range(index, end):
			var t: float = float(i) / MUSIC_RATE
			var noise: float = randf_range(-1.0, 1.0)
			noise_low += (noise - noise_low) * 0.25
			var sample: float = _music_sample(t, bar_seconds, noise, noise_low)
			data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 28000.0))
		index = end
		await tree.process_frame
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MUSIC_RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream


static func _music_sample(t: float, bar_seconds: float, noise: float, noise_low: float) -> float:
	var beat: float = 60.0 / BPM
	var bar: int = int(t / bar_seconds)
	var chord: Array = CHORDS[bar % CHORDS.size()]
	var in_bar: float = fmod(t, bar_seconds)
	var high: bool = bar >= 4
	# Pad: slow-swelling chord with slightly detuned partials.
	var pad_env: float = minf(in_bar / 0.8, 1.0) * minf((bar_seconds - in_bar) / 0.5, 1.0)
	var pad: float = 0.0
	for note: float in chord:
		pad += sin(TAU * note * t) + 0.5 * sin(TAU * note * 1.004 * t) + 0.25 * sin(TAU * note * 2.0 * t)
	pad *= 0.045 * pad_env
	# Bass: a plucked root on the eighths.
	var eighth: float = beat / 2.0
	var bass_local: float = fmod(t, eighth)
	var root: float = float(chord[0]) / 2.0
	var bass_on: float = 1.0 if int(t / eighth) % 4 != 3 else 0.0
	var bass: float = 0.2 * bass_on * (sin(TAU * root * t) + 0.3 * sin(TAU * root * 2.0 * t)) * exp(-bass_local * 6.0)
	# Arpeggio: bell-like plucks on the sixteenths, with an echo.
	var arp: float = _pluck(t, beat / 4.0, chord, 2.0 if high else 1.0)
	arp += 0.4 * _pluck(maxf(t - beat * 0.75, 0.0), beat / 4.0, chord, 2.0 if high else 1.0)
	# Drums.
	var beat_local: float = fmod(t, beat)
	var kick: float = 0.0
	if int(t / beat) % 2 == 0:
		kick = 0.55 * sin(TAU * lerpf(120.0, 42.0, minf(beat_local / 0.12, 1.0)) * beat_local) * exp(-beat_local * 11.0)
	var snare: float = 0.0
	if int(t / beat) % 2 == 1:
		snare = 0.16 * noise_low * exp(-beat_local * 14.0)
	var hat: float = 0.05 * (noise - noise_low) * exp(-fmod(t, eighth) * 45.0)
	return pad + bass + 0.5 * arp + kick + snare + hat


static func _pluck(t: float, step: float, chord: Array, octave: float) -> float:
	var slot: int = int(t / step)
	var local: float = fmod(t, step)
	var pattern: Array = [0, 1, 2, 1, 2, 1, 0, 2]
	var note: float = float(chord[pattern[slot % pattern.size()]]) * 2.0 * octave
	return 0.22 * (sin(TAU * note * t) + 0.35 * sin(TAU * note * 3.0 * t) * exp(-local * 30.0)) * exp(-local * 11.0)


static func _fanfare(pitches: Array, step: float, tail: float) -> AudioStreamWAV:
	var length: float = step * pitches.size() + tail
	return _make(length, func(t: float) -> float:
		var out: float = 0.0
		for slot: int in range(pitches.size()):
			var local: float = t - slot * step
			if local < 0.0:
				continue
			var pitch: float = float(pitches[slot])
			var decay: float = exp(-local * (4.0 if slot < pitches.size() - 1 else 2.2))
			out += 0.2 * (sin(TAU * pitch * t) + 0.4 * sin(TAU * pitch * 2.0 * t) + 0.15 * sin(TAU * pitch * 3.0 * t)) * decay
		return out)


static func _whoosh_wave(seconds: float, level: float) -> Callable:
	var state: Array = [0.0]
	return func(t: float) -> float:
		var cutoff: float = lerpf(0.04, 0.35, sin(PI * t / seconds))
		state[0] = float(state[0]) + (randf_range(-1.0, 1.0) - float(state[0])) * cutoff
		return level * float(state[0]) * sin(PI * t / seconds) * 2.0


static func _impact_wave(seconds: float, from_hz: float, to_hz: float, level: float) -> Callable:
	return func(t: float) -> float:
		return level * sin(TAU * lerpf(from_hz, to_hz, t / seconds) * t) * exp(-t * 12.0) + 0.35 * randf_range(-1.0, 1.0) * exp(-t * 70.0)


static func _make(seconds: float, wave: Callable) -> AudioStreamWAV:
	var count: int = int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index: int in range(count):
		var sample: float = clampf(float(wave.call(float(index) / RATE)), -1.0, 1.0)
		data.encode_s16(index * 2, int(sample * 24000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


## Bit-crush: fewer amplitude steps for a digital, broken sound.
static func _crush(value: float, bits: int) -> float:
	var steps: float = float(1 << bits)
	return roundf(value * steps) / steps
