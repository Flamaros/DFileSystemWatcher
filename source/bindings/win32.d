module bindings.win32;

public import std.c.windows.windows;

extern (Windows)
{
	alias void function(DWORD, DWORD, LPOVERLAPPED) LPOVERLAPPED_COMPLETION_ROUTINE;

	BOOL ReadDirectoryChangesW(HANDLE, PVOID, DWORD, BOOL, DWORD, PDWORD, LPOVERLAPPED, LPOVERLAPPED_COMPLETION_ROUTINE);
}
