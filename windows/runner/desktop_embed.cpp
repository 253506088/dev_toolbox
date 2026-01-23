#include "desktop_embed.h"
#include <iostream>

// Save original state
static LONG g_originalStyle = 0;
static LONG g_originalExStyle = 0;
static RECT g_originalRect = {0};
static bool g_isEmbedded = false;
static HWND g_originalOwner = NULL;

// Find Progman (desktop) window
static HWND FindProgman() {
    return FindWindow(L"Progman", NULL);
}

// Embed window to desktop mode
bool EmbedToDesktop(HWND hwnd) {
    if (hwnd == NULL) {
        std::cerr << "EmbedToDesktop: Invalid window handle" << std::endl;
        return false;
    }
    
    if (g_isEmbedded) {
        std::cout << "EmbedToDesktop: Already embedded" << std::endl;
        return true;
    }
    
    HWND progman = FindProgman();
    if (progman == NULL) {
        std::cerr << "EmbedToDesktop: Cannot find Progman" << std::endl;
        return false;
    }
    
    std::cout << "EmbedToDesktop: Found Progman: " << progman << std::endl;
    
    // Save original state
    g_originalStyle = GetWindowLong(hwnd, GWL_STYLE);
    g_originalExStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
    GetWindowRect(hwnd, &g_originalRect);
    g_originalOwner = GetWindow(hwnd, GW_OWNER);
    
    // Remove window decorations
    LONG style = g_originalStyle;
    style &= ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
    style &= ~WS_POPUP;  // Remove popup if present
    style |= WS_CHILD;   // Make it a child window
    SetWindowLong(hwnd, GWL_STYLE, style);
    
    // Set extended style
    LONG exStyle = g_originalExStyle;
    exStyle |= WS_EX_TOOLWINDOW;
    exStyle &= ~WS_EX_APPWINDOW;
    SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);
    
    // Set Progman as parent - this makes our window part of the desktop
    SetParent(hwnd, progman);
    
    // Get screen size
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    
    // Calculate position
    int width = g_originalRect.right - g_originalRect.left;
    int height = g_originalRect.bottom - g_originalRect.top;
    if (width <= 0) width = 800;
    if (height <= 0) height = 600;
    
    int x = screenWidth - width - 20;
    int y = screenHeight - height - 60;
    
    // Position the window
    SetWindowPos(hwnd, HWND_TOP, x, y, width, height,
                 SWP_FRAMECHANGED | SWP_SHOWWINDOW);
    
    // Force redraw
    InvalidateRect(hwnd, NULL, TRUE);
    UpdateWindow(hwnd);
    
    g_isEmbedded = true;
    std::cout << "EmbedToDesktop: Success (child of Progman)" << std::endl;
    
    return true;
}

// Detach window from desktop mode
bool DetachFromDesktop(HWND hwnd) {
    if (hwnd == NULL) {
        std::cerr << "DetachFromDesktop: Invalid window handle" << std::endl;
        return false;
    }
    
    if (!g_isEmbedded) {
        std::cout << "DetachFromDesktop: Not embedded" << std::endl;
        return true;
    }
    
    // Remove from Progman - set parent back to NULL (desktop)
    SetParent(hwnd, NULL);
    
    // Restore original styles
    SetWindowLong(hwnd, GWL_STYLE, g_originalStyle);
    SetWindowLong(hwnd, GWL_EXSTYLE, g_originalExStyle);
    
    // Restore original position
    int x = g_originalRect.left;
    int y = g_originalRect.top;
    int width = g_originalRect.right - g_originalRect.left;
    int height = g_originalRect.bottom - g_originalRect.top;
    
    if (width <= 0) width = 800;
    if (height <= 0) height = 600;
    if (x < 0) x = 100;
    if (y < 0) y = 100;
    
    SetWindowPos(hwnd, HWND_TOP, x, y, width, height,
                 SWP_FRAMECHANGED | SWP_SHOWWINDOW);
    
    InvalidateRect(hwnd, NULL, TRUE);
    UpdateWindow(hwnd);
    
    g_isEmbedded = false;
    std::cout << "DetachFromDesktop: Success" << std::endl;
    
    return true;
}

HWND FindWorkerW() {
    return FindProgman();
}
