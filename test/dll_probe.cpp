#include <windows.h>
#include <cstdio>
#include <cwchar>

int wmain(int argc, wchar_t** argv) {
    if (argc != 3) {
        std::fprintf(stderr, "Usage: dll_probe.exe <absolute DLL path> <proxy|worker>\n");
        return 2;
    }
    const bool proxy = wcscmp(argv[2], L"proxy") == 0;
    if (!proxy && wcscmp(argv[2], L"worker") != 0) return 2;
    if (proxy) SetEnvironmentVariableW(L"CHAT_TRANSLATOR_PROBE", L"1");
    HMODULE module = LoadLibraryExW(argv[1], nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (!module) {
        std::fprintf(stderr, "FAIL: LoadLibraryEx error=%lu\n", GetLastError());
        return 1;
    }
    const char* name = proxy ? "GetFileVersionInfoSizeW" : "WorkerInit";
    FARPROC entry = GetProcAddress(module, name);
    if (!entry) {
        std::fprintf(stderr, "FAIL: missing export %s\n", name);
        return 1;
    }
    if (proxy) {
        wchar_t path[MAX_PATH];
        GetSystemDirectoryW(path, MAX_PATH);
        wcscat_s(path, L"\\kernel32.dll");
        DWORD ignored = 0;
        auto query = reinterpret_cast<DWORD (WINAPI*)(LPCWSTR, LPDWORD)>(entry);
        if (!query(path, &ignored)) {
            std::fprintf(stderr, "FAIL: proxy call error=%lu\n", GetLastError());
            return 1;
        }
    }
    std::puts("PASS: DLL load and entry point. Game integration NOT tested.");
    // プロセス終了で解放する。ゲーム用フックやワーカーは起動しない。
    return 0;
}
