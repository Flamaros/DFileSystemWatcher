module bindings.win32;

public import std.c.windows.windows;

extern (Windows)
{
	alias void function(DWORD, DWORD, LPOVERLAPPED) LPOVERLAPPED_COMPLETION_ROUTINE;

    struct FILE_NOTIFY_INFORMATION {
        DWORD NextEntryOffset;
        DWORD Action;
        DWORD FileNameLength;
        WCHAR[1] FileName;
    }
    alias FILE_NOTIFY_INFORMATION* PFILE_NOTIFY_INFORMATION;

	BOOL ReadDirectoryChangesW(HANDLE, PVOID, DWORD, BOOL, DWORD, PDWORD, LPOVERLAPPED, LPOVERLAPPED_COMPLETION_ROUTINE);
	BOOL GetOverlappedResult(HANDLE, LPOVERLAPPED, PDWORD, BOOL);
	HANDLE CreateEventW(LPSECURITY_ATTRIBUTES lpEventAttributes, BOOL bManualReset, BOOL bInitialState, LPCWSTR lpName);
}
