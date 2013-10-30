module std.collections;

final class Stack(T)
{
	private T[] data;
	private size_t topIndex = -1;

	@property bool empty() @safe pure nothrow
	{
		return length == 0;
	}

	@property size_t length() @safe pure nothrow
	{
		return data.length;
	}

	this(size_t initialCapacity = 32) @safe pure nothrow
	{
		data = new T[initialCapacity];
		topIndex = -1;
	}
	
	void push(T val) @safe pure nothrow
	{
		if (topIndex + 1 > data.length)
			data.length = data.length << 1;
		data[++topIndex] = val;
	}
	
	T pop() @safe pure nothrow
	in
	{
		assert(!empty);
	}
	body
	{
		return data[topIndex--];
	}
}