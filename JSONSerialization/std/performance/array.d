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
	
	void put(QE[] arr) @safe pure nothrow
	{
		ensureCreated();
		ensureSpace(arr.length);
		mData.mBuffer[mData.nextI..arr.length + mData.nextI] = arr[0..$];
		mData.nextI += arr.length;
	}

	void put(QE e) @safe pure nothrow
	{
		ensureCreated();
		ensureSpace(1);
		mData.mBuffer[mData.nextI] = e;
		mData.nextI++;
	}

	static if (!is(QE == E))
	{
		void put(E[] arr) @safe pure nothrow
		{
			ensureCreated();
			ensureSpace(arr.length);
			mData.mBuffer[mData.nextI..arr.length + mData.nextI] = arr[0..$];
			mData.nextI += arr.length;
		}

		void put(E e) @safe pure nothrow
		{
			ensureCreated();
			ensureSpace(1);
			mData.mBuffer[mData.nextI] = e;
			mData.nextI++;
		}
	}
}
static assert(isOutputRange!(Appender!string, string));
static assert(isOutputRange!(Appender!(ubyte[]), ubyte[]));