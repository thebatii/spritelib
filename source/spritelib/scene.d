module spritelib.scene;

private import std.math;

private import dchip.all;

private import spritelib.physics;
private import spritelib.sprite;
private import spritelib.spritenode;
private import spritelib.util;
private import derelict.sfml2.graphics;
private import derelict.sfml2.system;
private import derelict.sfml2.window;

private import spritelib.window;

interface SceneNode : Sprite
{
	@property cpSpace* physics() pure @safe nothrow;
	void update(cpFloat);
}

class SceneGraph : SceneNode
{
	private SpriteNode[] _sprites;
	private size_t[string] _names;
	private bool _isDebug;
	private cpSpace* _physics;
	@property cpSpace* physics() pure @safe nothrow { return _physics; }
	@property bool isDebug() pure @safe nothrow const { return _isDebug; }
	@property void isDebug(bool d)
	{
		if(d != _isDebug) {
			foreach(sprite; _sprites) {
				sprite.isDebug = d;
			}
			_isDebug = d;
		}
	}
	private sfVector2f _size;
	private Vector _position;
	@property Vector position() const { return _position; }
	@property void position(in Vector p) { _position = p; }
	@property Vector origin() const { return _position; }
	@property void color(Color c) {}
	struct AnimationList
	{
		SpriteNodeAnimation[] active;
		SpriteNodeAnimation[] paused;
	}
	AnimationList _animations;

	this()
	{
		_position = Vector(0, 0);
		_size = sfVector2f(0, 0);
		_physics = cpSpaceNew();
	}
	~this()
	{
		cpSpaceFree(_physics);
	}
	Rectangle globalBounds()
	{
		return Rectangle(_position.x, _position.y, _size.x, _size.y);
	}
	void update(cpFloat deltaTime)
	{
		SpriteNodeAnimation[] stillActive;
		foreach(animation; _animations.active) {
			if(animation(deltaTime) >= 0.0) {
				stillActive ~= animation;
			}
		}
		_animations.active = stillActive;
		foreach(sprite; _sprites) {
			sprite.update(deltaTime);
		}
	}
	void addAnimation(SpriteNodeAnimation animation)
	{
		_animations.active ~= animation;
	}
	void pauseAnimation(SpriteNodeAnimation animation)
	{
		SpriteNodeAnimation[] stillActive;
		foreach(active; _animations.active) {
			if(active != animation) {
				stillActive ~= active;
			} else {
				_animations.paused ~= active;
			}
		}
		_animations.active = stillActive;
	}
	void draw(Window window, sfRenderStates* states)
	{
		sfRenderStates* childStates;
		sfRenderStates state;
		childStates = &state;
		if(states is null) {
			childStates.transform = sfTransform_Identity;
		} else {
			state.transform = states.transform;
		}
		sfTransform_translate(&(childStates.transform), _position.x, _position.y);

		foreach(sprite; _sprites) {
			sprite.update();
			sprite.draw(window, childStates);
		}
	}
	private void calculateSize()
	{
		foreach(sprite; _sprites) {
			calculateSize(sprite);
		}
	}
	private void calculateSize(Sprite sprite)
	{
			auto bounds = sprite.globalBounds();
			auto left = bounds.left;
			auto right = bounds.left+bounds.width;
			auto top = bounds.top;
			auto bottom = bounds.top+bounds.height;
			if(left < -_size.x/2.0)
				_size.x = abs(left*2.0);
			if(right > _size.x/2.0)
				_size.x = abs(right*2.0);

			if(top < -_size.y/2.0)
				_size.y = abs(top*2.0);
			if(bottom > _size.y/2.0)
				_size.y = abs(bottom*2.0);
	}
	auto add(SpriteNode sprite)
	{
		_sprites ~= sprite;
		calculateSize(sprite);
		sprite.scene = this;
		return sprite;
	}
	auto add(SpriteNode sprite, string name)
	{
		auto s = this.add(sprite);
		_names[name] = _sprites.length-1;
		return s;
	}
	auto sprite(string name)
	{
		auto index = name in _names;
		if(index is null)
			return null;
		return _sprites[*index];
	}
	void remove(SpriteNode node)
	{
		SpriteNode[] newNodes;
		foreach(s; _sprites) {
			if(s != node) {
				newNodes ~= s;
			} else {
				if(node.physics() !is null && node.physics() != _physics.staticBody) {
					cpSpaceAddPostStepCallback(_physics, &removeBody, node.physics(), _physics);
				}
			}
		}
		_sprites = newNodes;
	}
	@property void texture(Texture t) { }
	@property void textureRect(ClipRect r) {}
	@property ClipRect textureRect() @trusted const { return ClipRect(0, 0, 0, 0); }
	void rotation(float r) {}
}
unittest {
	auto scene = new SceneGraph();
	assert(scene._size == sfVector2f(0, 0));
}