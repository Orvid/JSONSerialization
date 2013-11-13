module std.performance.bitmanip;

import core.bitop : bt, bts, btr;

struct BitArray(int length)
{
	enum bitsPerSizeT = size_t.sizeof * 8;
	enum dataLength = (length + (bitsPerSizeT - 1)) / bitsPerSizeT;
	size_t[dataLength] data;

	this(size_t[dataLength] initialData)
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

	BitArray!length opOpAssign(string op : "&")(BitArray!length a2)
	{
		this.data[] &= a2.data[];
		return this;
	}
}