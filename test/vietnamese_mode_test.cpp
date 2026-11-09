// ============================================================
// vietnamese_mode_test.cpp - ベトナム語モード (VI) の設定読込・循環テスト
// POST_BUILD でコピーされた exe 隣の config.ini (Mode=Vietnamese) を使用する
// ============================================================

#include <windows.h>
#include <cstdio>
#include <string>

#include "config.h"

static int Fail(const char* message) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    return 1;
}

int main() {
    // カレントディレクトリではなく exe のあるディレクトリを基準にする
    char exePath[MAX_PATH];
    DWORD len = GetModuleFileNameA(nullptr, exePath, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) return Fail("cannot locate test executable");
    std::string baseDir(exePath, len);
    size_t slash = baseDir.rfind('\\');
    if (slash == std::string::npos) return Fail("unexpected executable path");
    baseDir.resize(slash + 1);

    config::Load(baseDir.c_str());
    if (config::GetTranslationMode() != TranslationMode::VI)
        return Fail("Vietnamese mode was not loaded from config.ini");

    // VI -> Off (循環の末尾)
    config::CycleTranslationMode();
    if (config::GetTranslationMode() != TranslationMode::Off) return Fail("VI must cycle to Off");

    // Off -> JA -> JAZ -> EN -> RU -> ZH -> KO -> VI と一周して VI に戻ること
    for (int i = 0; i < 7; ++i) config::CycleTranslationMode();
    if (config::GetTranslationMode() != TranslationMode::VI) return Fail("KO must cycle to VI");

    std::puts("PASS");
    return 0;
}
