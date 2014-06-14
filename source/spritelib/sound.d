module spritelib.sound;

private import std.string;

private import derelict.sfml2.audio;

struct SoundManager
{
	sfSound* output;
	sfSoundBuffer*[] sounds;
	
	const int opCmp(SoundManager manager) const
	{
		if(output != manager.output) {
			return output > manager.output ? 1 : -1;
		}
		if(sounds.length != manager.sounds.length) {
			return sounds.length > manager.sounds.length ? 1 : -1;
		}
		for(size_t i=0; i<sounds.length; ++i) {
			if(sounds[i] != manager.sounds[i]) {
				return sounds[i] > manager.sounds[i] ? 1 : -1;
			}
		}
		return 0;
	}
	private void releaseBuffers()
	{
		foreach(s; sounds) {
			sfSoundBuffer_destroy(s);
		}
	}
	void loadFiles(string[] files...)
	{
		releaseBuffers();
		sounds.length = files.length;
		for(size_t i=0; i<sounds.length; ++i) {
			sounds[i] = sfSoundBuffer_createFromFile(toStringz(files[i]));
		}

	}
	void play(size_t index)
	{
		sfSound_setBuffer(output, sounds[index]);
		sfSound_play(output);
	}
}

auto soundManager(string[] files...)
{
	auto manager = SoundManager(sfSound_create());
	manager.loadFiles(files);
	return manager;
}
void soundManagerFree(ref SoundManager manager)
{
	manager.releaseBuffers();
	sfSound_destroy(manager.output);
}