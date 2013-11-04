module std.performance.array;

import std.range : isOutputRange;

struct Appender(T : string)
{
	private char[] mBuffer;
	private size_t nextI = 0;
	
	private void ensureSpace(size_t len) @safe pure nothrow
	{
		while (nextI + len >= mBuffer.length)
			mBuffer.length = (mBuffer.length ? mBuffer.length : 1) << 1;
	}
	
	@property string data() @trusted pure
	{
		return cast(string)mBuffer[0..nextI].dup;
	}
	
	void clear() @safe pure nothrow
	{
		nextI = 0;
		mBuffer[] = 0;
	}
	
	void put(string str) @safe pure nothrow
	{
		ensureSpace(str.length);
		mBuffer[nextI..str.length + nextI] = str[0..$];
		nextI += str.length;
	}
	
	void put(C)(C[] str) @safe pure nothrow
	{
		ensureSpace(str.length);
		mBuffer[nextI..str.length + nextI] = str[0..$];
		nextI += str.length;
	}
	
	void put(char c) @safe pure nothrow
	{
		ensureSpace(1);
		mBuffer[nextI] = c;
		nextI++;
	}
}
static assert(isOutputRange!(Appender!string, string));