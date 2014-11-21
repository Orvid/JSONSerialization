module std.performance.array;

import std.range : isOutputRange;
import std.traitsExt : Dequal;

@trusted pure struct Appender(A : QE[], QE)
{
	alias E = Dequal!QE;

	private static class InnerData
	{
		E[] mBuffer;
		size_t nextI = 0;
	}
	private InnerData mData;

	private void ensureCreated() @trusted pure nothrow
	{
		if (!mData)
			mData = new InnerData();
	}
	
	private void ensureSpace(size_t len) @trusted pure nothrow
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

	void reset() @trusted pure nothrow
	{
		ensureCreated();
		mData.nextI = 0;
	}

	void clear() @trusted pure nothrow
	{
		ensureCreated();
		mData.nextI = 0;
		mData.mBuffer[] = E.init;
	}
	
	void put(QE[] arr) @trusted pure nothrow
	{
		ensureCreated();
		ensureSpace(arr.length);
		// This is required due to a compiler bug somewhere.....
		if (__ctfe && !is(E == char))
		{
			for (auto i = mData.nextI, i2 = 0; i < arr.length + mData.nextI; i++, i2++)
				mData.mBuffer[i] = arr[i2];
		}
		else
			mData.mBuffer[mData.nextI..arr.length + mData.nextI] = cast(E[])arr[];
		mData.nextI += arr.length;
	}

	void put(QE e) @trusted pure nothrow
	{
		ensureCreated();
		ensureSpace(1);
		mData.mBuffer[mData.nextI] = e;
		mData.nextI++;
	}

	static if (!is(QE == E))
	{
		void put(E[] arr) @trusted pure nothrow
		{
			ensureCreated();
			ensureSpace(arr.length);
			mData.mBuffer[mData.nextI..arr.length + mData.nextI] = arr[0..$];
			mData.nextI += arr.length;
		}

		void put(E e) @trusted pure nothrow
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