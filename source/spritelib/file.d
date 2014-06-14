module spritelib.file;

private import yaml;
private import spritelib = spritelib.game;

auto fileLoader(string file)
{
	auto loader = Loader(file);
	auto constructor = new Constructor;
	loader.constructor = constructor;
	
	constructor.addConstructorMapping("!rectangle", &loadRectangle);
	constructor.addConstructorMapping("!vector", &loadVector);
	constructor.addConstructorMapping("!rectangle-shape", &loadRectangleShape);
	constructor.addConstructorMapping("!color", &loadColor);
	constructor.addConstructorMapping("!texture", &loadTexture);
	constructor.addConstructorMapping("!animation", &loadAnimation);
	constructor.addConstructorMapping("!sounds", &loadSounds);
	
	return loader;
}

spritelib.SoundManager loadSounds(ref Node node)
{
	string[] files;
	foreach(string file; node["files"]) {
		files ~= file;
	}
	spritelib.GameEngine.instance.sound.loadFiles(files);
	return spritelib.GameEngine.instance.sound;
}
spritelib.Animation loadAnimation(ref Node node)
{
	auto doesRepeat = (node["repeat"].as!int) > 0;
	spritelib.Animation.Sequence[] sequence;
	auto game = spritelib.GameEngine.instance;
	foreach(Node seq; node["sequence"]) {
		auto texture = game.texture(seq["texture"].as!string);
		spritelib.ClipRect clip;
		try {
			clip.left = seq["left"].as!int;
			clip.top = seq["top"].as!int;
			clip.width = seq["width"].as!int;
			clip.height = seq["height"].as!int;
		} catch(YAMLException e) {
			clip = spritelib.ClipRect(0, 0, 0, 0);
		}
		sequence ~= spritelib.Animation.Sequence(texture, clip, seq["duration"].as!float);
	}
	return spritelib.Animation(sequence, doesRepeat);
}
spritelib.Texture loadTexture(ref Node node)
{
	auto name = node["name"].as!string;
	auto path = node["path"].as!string;
	return spritelib.loadTexture(path, name);
}
spritelib.Rectangle loadRectangle(ref Node node)
{
	auto left = node["left"].as!float;
	auto top = node["top"].as!float;
	auto width = node["width"].as!float;
	auto height = node["height"].as!float;
	return spritelib.Rectangle(left, top, width, height);
}
spritelib.Vector loadVector(ref Node node)
{
	auto x = node["x"].as!float;
	auto y = node["y"].as!float;
	return spritelib.Vector(x, y);
}
spritelib.Color loadColor(ref Node node)
{
	auto r = node["r"].as!ubyte;
	auto g = node["g"].as!ubyte;
	auto b = node["b"].as!ubyte;
	try {
		auto a = node["a"].as!ubyte;
		return spritelib.Color(r, g, b, a);
	} catch(YAMLException e) {
		return spritelib.Color(r, g, b, 255);
	}
}
spritelib.RectangleNode loadRectangleShape(ref Node node)
{
	auto game = spritelib.GameEngine.instance;
	auto bounds = node["bounds"].as!(spritelib.Rectangle);
	spritelib.RectangleNode rectangle;
	// Try to instantiate with a mass, if available.
	try {
		auto mass = node["mass"].as!float;
		rectangle = new spritelib.RectangleNode(bounds, mass);
	} catch(YAMLException e) {
		rectangle = new spritelib.RectangleNode(bounds);
	}
	// Set the texture if available.
	try {
		auto texture = node["texture"].as!string;
		rectangle.texture(game.texture(texture));
	} catch(YAMLException e) {}
	// Set the color if available.
	try {
		auto color = node["color"].as!(spritelib.Color);
		rectangle.color = color;
	} catch(YAMLException e) {}
	return rectangle;
}