module std.performance.bitmanip;

import core.bitop : bt, bts, btr;
import std.traitsExt : Dequal;

// TODO: Unittest.
struct BitArray(int length)
{
	enum bitsPerSizeT = size_t.sizeof * 8;
	enum dataLength = (length + (bitsPerSizeT - 1)) / bitsPerSizeT;
	size_t[dataLength] data;

	this(scope size_t[dataLength] initialData)
	{
		this.data = initialData;
	}

	/**********************************************
     * Gets the $(D i)'th bit in the $(D BitArray).
     */
	bool opIndex(size_t i) const @trusted pure nothrow
	in
	{
		assert(i < length);
	}
	body
	{
		return cast(bool)bt(data.ptr, i);
	}
	
	/**********************************************
     * Sets the $(D i)'th bit in the $(D BitArray).
     */
	bool opIndexAssign(bool b, size_t i) @trusted pure nothrow
	in
	{
		assert(i < length);
	}
	body
	{
		if (__ctfe)
		{
			if (b)
				data[i / bitsPerSizeT] |= (1 << (i & (bitsPerSizeT - 1)));
			else
				data[i / bitsPerSizeT] &= ~(1 << (i & (bitsPerSizeT - 1)));
		}
		else
		{
			if (b)
				bts(data.ptr, i);
			else
				btr(data.ptr, i);
		}
		return b;
	}

	BitArray!length opOpAssign(string op : "&", Barr)(ref Barr a2) @safe pure nothrow
		if (is(Dequal!Barr == BitArray!length))
	{
		static if (dataLength == 1)
		{
			data[0] &= a2.data[0];
		}
		else
		{
			this.data[] &= a2.data[];
		}
		return this;
	}
	
	BitArray!length opOpAssign(string op : "&", Barr)(scope Barr a2) @safe pure nothrow
		if (is(Dequal!Barr == BitArray!length))
	{
		static if (dataLength == 1)
		{
			data[0] &= a2.data[0];
		}
		else
		{
			this.data[] &= a2.data[];
		}
		return this;
	}

	bool opEquals(Barr)(ref Barr a2) @trusted pure nothrow
		if (is(Dequal!Barr == BitArray!length))
	{
		static if (dataLength == 1)
		{
			return data[0] == a2.data[0];
		}
		else
		{
			if (__ctfe)
			{
				for (auto i = 0; i < dataLength; i++)
				{
					if (data[i] != a2.data[i])
						return false;
				}
				return true;
			}
			else
			{
				import std.c.string : memcmp;

				return !memcmp(this.data.ptr, a2.data.ptr, dataLength);
			}
		}
	}
	
	bool opEquals(Barr)(scope Barr a2) @trusted pure nothrow
		if (is(Dequal!Barr == BitArray!length))
	{
		static if (dataLength == 1)
		{
			return data[0] == a2.data[0];
		}
		else
		{
			if (__ctfe)
			{
				for (auto i = 0; i < dataLength; i++)
				{
					if (data[i] != a2.data[i])
						return false;
				}
				return true;
			}
			else
			{
				import std.c.string : memcmp;
				
				return !memcmp(this.data.ptr, a2.data.ptr, dataLength);
			}
		}
	}
}