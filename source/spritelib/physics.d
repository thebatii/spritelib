module spritelib.physics;

private import std.math;
private import std.traits;
private import dchip.all;
private import spritelib.scene;
private import spritelib.spritenode;
private import spritelib.util;

interface PhysicsNode
{
	Rectangle globalBounds() @trusted;
	Vector positionAtTime(float);
	Rectangle globalBoundsAtTime(float);
	void advance(float);
	bool collidesWithBounds(Rectangle);
}

void removeShape(cpSpace *space, void *obj, void *data)
{
	cpSpaceRemoveShape(space, cast(cpShape*)obj);
	cpShapeFree(cast(cpShape*)obj);
}
void removeBody(cpSpace* space, void* obj, void* data)
{
	auto body_ = cast(cpBody*)obj;
	cpBodyEachShape(body_, &removeShapesIterator, space);
	if(space !is null && cpSpaceContainsBody(space, body_)) {
		cpSpaceRemoveBody(space, body_);
	}
}
void removeShapesIterator(cpBody *body_, cpShape *shape, void *data)
{
	auto space = (data is null ? cpShapeGetSpace(shape) : cast(cpSpace*)data);
	if(space !is null && cpSpaceContainsShape(space, shape)) {
		cpSpaceRemoveShape(space, shape);
	}
}

void removeShapeA(cpArbiter* arb, cpSpace* space, void* data)
{
	auto scene = cast(SceneGraph*)data;
	cpShape* a;
	cpShape* b;
	cpArbiterGetShapes(arb, &a, &b);
	auto node = cast(SpriteNodeRef*)(a.data);
	scene.remove(node.node);
	cpSpaceAddPostStepCallback(space, &removeShape, a, null);
}
void removeShapeB(cpArbiter* arb, cpSpace* space, void* data)
{
	auto scene = cast(SceneGraph*)data;
	cpShape* a;
	cpShape* b;
	cpArbiterGetShapes(arb, &a, &b);
	auto node = cast(SpriteNodeRef*)(b.data);
	scene.remove(node.node);
	cpSpaceAddPostStepCallback(space, &removeShape, b, null);
}
void removeShapeAB(cpArbiter* arb, cpSpace* space, void* data)
{
	auto scene = cast(SceneGraph*)data;
	cpShape* a;
	cpShape* b;
	cpArbiterGetShapes(arb, &a, &b);
	auto nodeA = cast(SpriteNodeRef*)(a.data);
	scene.remove(nodeA.node);
	cpSpaceAddPostStepCallback(space, &removeShape, a, null);
	auto nodeB = cast(SpriteNodeRef*)(b.data);
	scene.remove(nodeB.node);
	cpSpaceAddPostStepCallback(space, &removeShape, b, null);
}

T degreesToRadians(T)(T degrees)
{
	return PI*degrees/180;
}
T radiansToDegrees(T)(T radians)
{
	return radians*180/PI;
}

struct PhysicsBody
{
	cpBody* body_;
	alias body_ this;
	SpriteNode parent;
}
enum ShapeType
{
	Circle,
	Polygon,
	Segment
}
struct PhysicsShape
{
	ShapeType type;
	cpShape* shape;
	SpriteNode parent;
	alias shape this;
}
private auto initializeShape(SpriteNode node, PhysicsShape* shape, cpSpace* space)
{
	shape.shape.data = shape;
	if(space !is null) {
		cpSpaceAddShape(space, shape.shape);
	}
	node.addShape(shape);
	return shape;
}
auto circleShape(SpriteNode node, cpSpace* space, cpBody* body_, cpFloat radius, cpVect offset=cpVect(0, 0))
{
	return initializeShape(node, new PhysicsShape(ShapeType.Circle, cpCircleShapeNew(body_, radius, offset), node), space);
}
auto rectangleShape(SpriteNode node, cpSpace* space, cpBody* body_, Rectangle bounds)
{
	return initializeShape(node, new PhysicsShape(ShapeType.Polygon, cpBoxShapeNew2(body_, cpBB(bounds.left, bounds.top, bounds.left+bounds.width, bounds.top+bounds.height)), node), space);
}