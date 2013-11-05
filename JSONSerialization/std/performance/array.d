module std.performance.array;

import std.range : isOutputRange;
import std.traitsExt : Dequal;

@safe pure struct Appender(A : QE[], QE)
{
	alias E = Dequal!QE;

	private static class InnerData
	{
		E[] mBuffer;
		size_t nextI = 0;
	}
	private InnerData mData;

	private void ensureCreated() @safe pure nothrow
	{
		if (!mData)
			mData = new InnerData();
	}
	
	private void ensureSpace(size_t len) @safe pure nothrow
	{
		ensureCreated();
		while (mData.nextI + len >= mData.mBuffer.length)
			mData.mBuffer.length = (mData.mBuffer.length ? mData.mBuffer.length : 1) << 1;
	}
	
	@property A data() @trusted pure
	{
		ensureCreated();
		return cast(A)mData.mBuffer[0..mData.nextI].dup;
	}

	void clear() @safe pure nothrow
	{
		ensureCreated();
		mData.nextI = 0;
		mData.mBuffer[] = E.init;
	}
	
	void put(A str) @safe pure nothrow
	{
		ensureCreated();
		ensureSpace(str.length);
		mData.mBuffer[mData.nextI..str.length + mData.nextI] = str[0..$];
		mData.nextI += str.length;
	}

	void put(E)(E[] str) @safe pure nothrow
	{
		ensureCreated();
		ensureSpace(str.length);
		mData.mBuffer[mData.nextI..str.length + mData.nextI] = str[0..$];
		mData.nextI += str.length;
	}
	
	void put(E c) @safe pure nothrow
	{
		ensureCreated();
		ensureSpace(1);
		mData.mBuffer[mData.nextI] = c;
		mData.nextI++;
	}
}
static assert(isOutputRange!(Appender!string, string));