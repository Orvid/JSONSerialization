module std.performance.array;

import std.range : isOutputRange;
import std.traitsExt : Dequal;

struct Appender(A : QE[], QE)
{
	alias E = Dequal!QE;

	private static class InnerData
	{
		E[] mBuffer;
		size_t nextI = 0;
	}
	private InnerData mData = new InnerData();
	
	private void ensureSpace(size_t len) @safe pure nothrow
	{
		while (mData.nextI + len >= mData.mBuffer.length)
			mData.mBuffer.length = (mData.mBuffer.length ? mData.mBuffer.length : 1) << 1;
	}
	
	@property A data() @trusted pure
	{
		return cast(A)mData.mBuffer[0..mData.nextI].dup;
	}

	void clear() @safe pure nothrow
	{
		mData.nextI = 0;
		mData.mBuffer[] = E.init;
	}
	
	void put(A str) @safe pure nothrow
	{
		ensureSpace(str.length);
		mData.mBuffer[mData.nextI..str.length + mData.nextI] = str[0..$];
		mData.nextI += str.length;
	}
	
	void put(C)(C[] str) @safe pure nothrow
	{
		ensureSpace(str.length);
		mData.mBuffer[mData.nextI..str.length + mData.nextI] = str[0..$];
		mData.nextI += str.length;
	}
	
	void put(E c) @safe pure nothrow
	{
		ensureSpace(1);
		mData.mBuffer[mData.nextI] = c;
		mData.nextI++;
	}
}
static assert(isOutputRange!(Appender!string, string));