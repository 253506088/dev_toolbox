#ifndef DESKTOP_EMBED_H_
#define DESKTOP_EMBED_H_

#include <windows.h>

// Find WorkerW window handle
HWND FindWorkerW();

// Embed window to desktop (under WorkerW)
bool EmbedToDesktop(HWND hwnd);

// Detach window from desktop
bool DetachFromDesktop(HWND hwnd);

#endif  // DESKTOP_EMBED_H_
