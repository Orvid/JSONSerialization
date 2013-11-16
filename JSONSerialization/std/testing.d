module std.testing;

@property void assertStaticAndRuntime(alias expr, string errorMessage = "")()
{
	static if (errorMessage != "")
	{
		static assert(expr, errorMessage);
		assert(expr, errorMessage);
	}
	else
	{
		static assert(expr);
		assert(expr);
	}
}
// TODO: Figure out how on earth to write a unittest for this....